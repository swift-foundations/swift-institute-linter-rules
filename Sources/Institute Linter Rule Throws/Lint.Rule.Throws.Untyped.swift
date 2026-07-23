// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Linter_Primitives
internal import SwiftSyntax

/// Wave-1 — `throws` without a typed-throws specifier.
///
/// Citation: [API-ERR-001].
extension Lint.Rule {
  public static let `untyped throws` = Lint.Rule(
    id: "untyped throws",
    default: .warning,
    findings: { source, severity in
      let visitor = ThrowsUntypedVisitor(
        source: source.file,
        severity: severity,
        converter: source.converter
      )
      visitor.walk(source.tree)
      return visitor.matches
    }
  )
}

@usableFromInline
internal let throwsUntypedMessage: Swift.String =
  "[untyped throws] [API-ERR-001]: bare `throws` erases the error type. Use "
  + "`throws(SpecificError)` so callers know which errors are possible at compile "
  + "time and the error path stays exhaustive. Untyped throws boxes the error as "
  + "`any Error`, which the institute convention forbids. `@Test` and "
  + "`@Suite`-member declarations are exempt (#16 Option C ledger, Entry III.c "
  + "— a test rethrows to the runner and has no API surface)."

/// External-protocol conformance allowlist (§C3, 2026-07-07; `Codable` witness
/// pair added by the remediation arc, 2026-07-07 per Table A #3).
///
/// Some external protocols the institute must conform to declare a requirement
/// with *untyped* `throws`; the conforming member's signature is then forced to
/// use untyped throws too, and [API-ERR-001] cannot be satisfied without
/// breaking the conformance. Each entry names a `(protocol, method)` pair whose
/// signature-position untyped throws are conformance-forced and therefore
/// exempt. Extend this list — in this one place — when another such external
/// protocol surfaces; matching is by the protocol's simple (last) name so both
/// `TestScoping` and `Testing.TestScoping` inheritance-clause spellings match.
///
/// `method` is the enclosing member's selector: a function's base name
/// (`provideScope`, `encode`), or — because initializers have no base name — an
/// initializer's labeled selector `init(label:)` (`init(from:)`). The `Codable`
/// pair covers hand-written `Decodable.init(from:)` / `Encodable.encode(to:)`
/// witnesses, whose only caller is type-erased coder machinery: the rule's
/// caller-exhaustiveness intent does not apply, and wrapping `DecodingError`
/// into a domain error would degrade coding-path diagnostics.
///
/// Only untyped throws in the conforming member's SIGNATURE (its effect
/// specifiers and parameter-clause closure types — all dictated by the external
/// requirement) are exempt; untyped throws written inside the member BODY still
/// fire, preserving [API-ERR-001] enforcement everywhere the conformance does
/// not force the shape.
@usableFromInline
internal let throwsConformanceForcedAllowlist:
  [(protocolSuffix: Swift.String, method: Swift.String)] = [
    (protocolSuffix: "TestScoping", method: "provideScope"),
    (protocolSuffix: "Encodable", method: "encode"),
    (protocolSuffix: "Decodable", method: "init(from:)"),
  ]

internal final class ThrowsUntypedVisitor: SyntaxVisitor {
  let source: Source.File
  let severity: Diagnostic.Severity
  let converter: SourceLocationConverter
  var matches: [Diagnostic.Record] = []

  init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
    self.source = source
    self.severity = severity
    self.converter = converter
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: ThrowsClauseSyntax) -> SyntaxVisitorContinueKind {
    guard node.throwsSpecifier.tokenKind == .keyword(.throws) else {
      return .visitChildren
    }
    guard node.type == nil else {
      return .visitChildren
    }
    if Self.isConformanceForcedUntypedThrows(node) {
      return .visitChildren
    }
    // @Test / @Suite-member exemption (#16 Option C ledger, Entry III.c
    // DECISION 2026-07-23): a test declaration rethrows arbitrary
    // harness/SUT errors to the swift-testing runner and has no API
    // surface — [API-ERR-001] is an API-surface rule ("Throwing
    // functions use typed throws", workspace API-quality section), and
    // no SWIFT-TEST rule requires typed test throws ([SWIFT-TEST-005]
    // governs naming only). Published precedent is uniform (gh-http
    // 759330b, sockets ca79bb8, identities-github 0205e7f). Non-@Test
    // helper functions in test FILES that are neither @Suite members
    // nor inside a @Test function still fire — they have callers and
    // can adopt typed throws.
    if Self.isTestScoped(node) {
      return .visitChildren
    }
    let location = converter.location(for: node.throwsSpecifier.positionAfterSkippingLeadingTrivia)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "untyped throws",
        message: throwsUntypedMessage
      ))
    return .visitChildren
  }

  /// True when `node` is a signature-position untyped `throws` on a member
  /// (function or initializer) whose signature is forced by an allowlisted
  /// external protocol (`throwsConformanceForcedAllowlist`, §C3). Syntax-visible:
  /// the enclosing extension/type's inheritance clause names the external
  /// protocol and the enclosing member's selector matches the allowlisted
  /// requirement. Untyped throws inside the member body are NOT exempt.
  static func isConformanceForcedUntypedThrows(_ node: ThrowsClauseSyntax) -> Swift.Bool {
    var enclosingSelector: Swift.String? = nil
    var enclosingSignature: FunctionSignatureSyntax? = nil
    var inheritedTypeSuffixes: Swift.Set<Swift.String> = []
    var cursor: Syntax? = node.parent
    while let current = cursor {
      if enclosingSelector == nil {
        if let function = current.as(FunctionDeclSyntax.self) {
          enclosingSelector = function.name.text
          enclosingSignature = function.signature
        } else if let initializer = current.as(InitializerDeclSyntax.self) {
          enclosingSelector = Self.initializerSelector(initializer)
          enclosingSignature = initializer.signature
        }
      }
      if let clause = Self.inheritanceClause(of: current) {
        for inherited in clause.inheritedTypes {
          inheritedTypeSuffixes.insert(Self.lastNameComponent(inherited.type))
        }
      }
      cursor = current.parent
    }
    guard let selector = enclosingSelector, let signature = enclosingSignature else {
      return false
    }
    // Restrict to the enclosing member's own signature (effect specifiers +
    // parameter-clause closure types) — untyped throws in the body still fire.
    guard
      node.position >= signature.position,
      node.endPosition <= signature.endPosition
    else {
      return false
    }
    // A member matches an allowlist entry when its selector matches AND it
    // witnesses the entry's protocol. Witnessing is proven EITHER by an
    // enclosing inheritance clause naming the protocol (the `provideScope` and
    // same-extension `: Codable` spellings) OR by the member's canonical witness
    // signature (the Codable pair, so a witness in a *bare* extension whose
    // conformance is declared separately — e.g. the `// MARK: - Codable`
    // extension in swift-rfc-9110 `HTTP.Headers.swift` — is still exempt).
    for entry in throwsConformanceForcedAllowlist where entry.method == selector {
      if inheritedTypeSuffixes.contains(entry.protocolSuffix) { return true }
      if Self.isCanonicalWitnessSignature(
        protocolSuffix: entry.protocolSuffix,
        parameters: signature.parameterClause.parameters
      ) {
        return true
      }
    }
    return false
  }

  /// True when `node` sits in test scope (#16 Entry III.c): lexically
  /// inside a function carrying the `@Test` attribute, inside a type
  /// declaration carrying `@Suite`, or inside an extension whose
  /// extended type is declared `@Suite` in the SAME file (the
  /// swift-testing extension-pattern per [SWIFT-TEST-002] declares
  /// `@Suite enum Tests {}` and hangs members on
  /// `extension …Tests { … }`). Cross-file @Suite declarations are not
  /// visible to a per-file AST rule; such members keep firing and stay
  /// accept-as-warning per Entry III.g's gate vocabulary.
  static func isTestScoped(_ node: ThrowsClauseSyntax) -> Swift.Bool {
    var suiteExtensionTargets: [Swift.String] = []
    var cursor: Syntax? = node.parent
    var sourceFile: SourceFileSyntax? = nil
    while let current = cursor {
      if let function = current.as(FunctionDeclSyntax.self),
        Self.hasAttribute(function.attributes, named: "Test")
      {
        return true
      }
      if let decl = current.as(StructDeclSyntax.self),
        Self.hasAttribute(decl.attributes, named: "Suite")
      {
        return true
      }
      if let decl = current.as(EnumDeclSyntax.self),
        Self.hasAttribute(decl.attributes, named: "Suite")
      {
        return true
      }
      if let decl = current.as(ClassDeclSyntax.self),
        Self.hasAttribute(decl.attributes, named: "Suite")
      {
        return true
      }
      if let decl = current.as(ActorDeclSyntax.self),
        Self.hasAttribute(decl.attributes, named: "Suite")
      {
        return true
      }
      if let ext = current.as(ExtensionDeclSyntax.self) {
        suiteExtensionTargets.append(ext.extendedType.trimmedDescription)
      }
      if let file = current.as(SourceFileSyntax.self) {
        sourceFile = file
      }
      cursor = current.parent
    }
    guard !suiteExtensionTargets.isEmpty, let file = sourceFile else { return false }
    var suitePaths: [Swift.String] = []
    for statement in file.statements {
      Self.collectSuitePaths(from: Syntax(statement.item), prefix: "", into: &suitePaths)
    }
    for target in suiteExtensionTargets where suitePaths.contains(target) {
      return true
    }
    return false
  }

  static func hasAttribute(_ attributes: AttributeListSyntax, named name: Swift.String)
    -> Swift.Bool
  {
    for attribute in attributes {
      guard let attr = attribute.as(AttributeSyntax.self) else { continue }
      // `@Test`, `@Suite`, and argumented forms (`@Suite(.serialized)`,
      // `@Test("name", arguments: …)`) all match on the attribute name;
      // qualified spellings (`Testing.Suite`) match on the leaf.
      let attrName = attr.attributeName.trimmedDescription
      if attrName == name { return true }
      if attrName.hasSuffix(".\(name)") { return true }
    }
    return false
  }

  /// Collects the dotted full paths of every `@Suite`-attributed type
  /// declaration in the file, descending through nested extensions and
  /// type bodies (`extension Sockets.TCP.Listener { @Suite enum Tests {} }`
  /// yields `Sockets.TCP.Listener.Tests`).
  static func collectSuitePaths(
    from node: Syntax,
    prefix: Swift.String,
    into collected: inout [Swift.String]
  ) {
    func joined(_ name: Swift.String) -> Swift.String {
      prefix.isEmpty ? name : prefix + "." + name
    }
    if let ext = node.as(ExtensionDeclSyntax.self) {
      let path = joined(ext.extendedType.trimmedDescription)
      for member in ext.memberBlock.members {
        Self.collectSuitePaths(from: Syntax(member.decl), prefix: path, into: &collected)
      }
      return
    }
    var name: Swift.String? = nil
    var attributes: AttributeListSyntax? = nil
    var members: MemberBlockSyntax? = nil
    if let decl = node.as(StructDeclSyntax.self) {
      name = decl.name.text
      attributes = decl.attributes
      members = decl.memberBlock
    } else if let decl = node.as(EnumDeclSyntax.self) {
      name = decl.name.text
      attributes = decl.attributes
      members = decl.memberBlock
    } else if let decl = node.as(ClassDeclSyntax.self) {
      name = decl.name.text
      attributes = decl.attributes
      members = decl.memberBlock
    } else if let decl = node.as(ActorDeclSyntax.self) {
      name = decl.name.text
      attributes = decl.attributes
      members = decl.memberBlock
    }
    guard let name, let attributes, let members else { return }
    let path = joined(name)
    if Self.hasAttribute(attributes, named: "Suite") {
      collected.append(path)
    }
    for member in members.members {
      Self.collectSuitePaths(from: Syntax(member.decl), prefix: path, into: &collected)
    }
  }

  /// The labeled selector of an initializer — `init(from:)` for
  /// `init(from decoder: any Decoder)`. Each parameter contributes its argument
  /// label (the `firstName` token: the external label, or `_` when the parameter
  /// is unlabeled), matching Swift's own selector spelling so an allowlist entry
  /// can name an initializer requirement precisely.
  static func initializerSelector(_ node: InitializerDeclSyntax) -> Swift.String {
    var selector = "init("
    for parameter in node.signature.parameterClause.parameters {
      selector += parameter.firstName.text
      selector += ":"
    }
    selector += ")"
    return selector
  }

  /// True when a member's parameter list is the canonical witness shape for an
  /// allowlisted Codable protocol, so the exemption holds even when the
  /// conformance is declared on a *separate* extension or file rather than the
  /// one holding the witness (the common `// MARK: - Codable` bare-extension
  /// pattern). A `Decodable` witness takes a sole `Decoder` parameter; an
  /// `Encodable` witness a sole `Encoder` parameter. Only the Codable pair has a
  /// canonical signature shape; `provideScope` returns `false` here and relies
  /// on its enclosing `TestScoping` conformance clause.
  static func isCanonicalWitnessSignature(
    protocolSuffix: Swift.String,
    parameters: FunctionParameterListSyntax
  ) -> Swift.Bool {
    guard parameters.count == 1, let parameter = parameters.first else { return false }
    let parameterTypeSuffix = Self.lastNameComponent(Self.unwrappedConstraint(parameter.type))
    switch protocolSuffix {
    case "Decodable": return parameterTypeSuffix == "Decoder"
    case "Encodable": return parameterTypeSuffix == "Encoder"
    default: return false
    }
  }

  /// Strips a leading `any`/`some` existential/opaque marker to expose the
  /// underlying constraint type — `any Decoder` → `Decoder`.
  static func unwrappedConstraint(_ type: TypeSyntax) -> TypeSyntax {
    if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) { return someOrAny.constraint }
    return type
  }

  /// The inheritance clause of any nominal-type or extension declaration.
  static func inheritanceClause(of node: Syntax) -> InheritanceClauseSyntax? {
    if let decl = node.as(ExtensionDeclSyntax.self) { return decl.inheritanceClause }
    if let decl = node.as(StructDeclSyntax.self) { return decl.inheritanceClause }
    if let decl = node.as(ClassDeclSyntax.self) { return decl.inheritanceClause }
    if let decl = node.as(EnumDeclSyntax.self) { return decl.inheritanceClause }
    if let decl = node.as(ActorDeclSyntax.self) { return decl.inheritanceClause }
    if let decl = node.as(ProtocolDeclSyntax.self) { return decl.inheritanceClause }
    return nil
  }

  /// The last name component of a (possibly member-qualified) type — e.g.
  /// `TestScoping` for both `TestScoping` and `Testing.TestScoping`.
  static func lastNameComponent(_ type: TypeSyntax) -> Swift.String {
    if let member = type.as(MemberTypeSyntax.self) { return member.name.text }
    if let identifier = type.as(IdentifierTypeSyntax.self) { return identifier.name.text }
    return type.trimmedDescription
  }
}
