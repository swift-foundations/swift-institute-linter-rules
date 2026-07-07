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
  + "`any Error`, which the institute convention forbids."

/// External-protocol conformance allowlist (§C3, 2026-07-07).
///
/// Some external protocols the institute must conform to declare a requirement
/// with *untyped* `throws`; the conforming method's signature is then forced to
/// use untyped throws too, and [API-ERR-001] cannot be satisfied without
/// breaking the conformance. Each entry names a `(protocol, method)` pair whose
/// signature-position untyped throws are conformance-forced and therefore
/// exempt. Extend this list — in this one place — when another such external
/// protocol surfaces; matching is by the protocol's simple (last) name so both
/// `TestScoping` and `Testing.TestScoping` inheritance-clause spellings match.
///
/// Only untyped throws in the conforming method's SIGNATURE (its effect
/// specifiers and parameter-clause closure types — all dictated by the external
/// requirement) are exempt; untyped throws written inside the method BODY still
/// fire, preserving [API-ERR-001] enforcement everywhere the conformance does
/// not force the shape.
@usableFromInline
internal let throwsConformanceForcedAllowlist:
  [(protocolSuffix: Swift.String, method: Swift.String)] = [
    (protocolSuffix: "TestScoping", method: "provideScope")
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

  /// True when `node` is a signature-position untyped `throws` on a method
  /// whose signature is forced by an allowlisted external protocol
  /// (`throwsConformanceForcedAllowlist`, §C3). Syntax-visible: the enclosing
  /// extension/type's inheritance clause names the external protocol and the
  /// enclosing function's name matches the allowlisted requirement. Untyped
  /// throws inside the method body are NOT exempt.
  static func isConformanceForcedUntypedThrows(_ node: ThrowsClauseSyntax) -> Swift.Bool {
    var enclosingFunction: FunctionDeclSyntax? = nil
    var inheritedTypeSuffixes: Swift.Set<Swift.String> = []
    var cursor: Syntax? = node.parent
    while let current = cursor {
      if enclosingFunction == nil, let function = current.as(FunctionDeclSyntax.self) {
        enclosingFunction = function
      }
      if let clause = Self.inheritanceClause(of: current) {
        for inherited in clause.inheritedTypes {
          inheritedTypeSuffixes.insert(Self.lastNameComponent(inherited.type))
        }
      }
      cursor = current.parent
    }
    guard let function = enclosingFunction else { return false }
    // Restrict to the function's own signature (effect specifiers +
    // parameter-clause closure types) — untyped throws in the body still fire.
    let signature = function.signature
    guard
      node.position >= signature.position,
      node.endPosition <= signature.endPosition
    else {
      return false
    }
    let methodName = function.name.text
    for entry in throwsConformanceForcedAllowlist
    where entry.method == methodName && inheritedTypeSuffixes.contains(entry.protocolSuffix) {
      return true
    }
    return false
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
