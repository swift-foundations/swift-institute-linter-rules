// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-institute-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-institute-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Linter_Primitives
internal import SwiftSyntax

/// A target's dependencies must be spelled through the typed accessors
/// (`.target(name:)`, `.product(name:package:)`), never as bare strings.
///
/// SwiftPM resolves a bare string as `.byName`, which binds to whatever
/// it resolves first and silently produces a different graph than the
/// author intended. The bare-string form is the idiom in most external
/// Swift material, so it arrives with copied code.
///
/// The rule's surface is a package manifest (`Package.swift`, including
/// versioned `Package@swift-*.swift` variants and nested test
/// manifests). It fires on each string-literal element of the
/// `dependencies:` array of a target-declaring call — resolving
/// through a `.byName(name:)` wrapper, a file-scope constant
/// (`let owner = "Owner"`), a file-scope array constant
/// (`let sharedDeps: [Target.Dependency] = [...]`), and a `+`-
/// concatenated `SequenceExprSyntax` of such arrays, since a
/// SwiftPM manifest is a single file by construction and every one
/// of those bindings is declared in the file the rule is already
/// parsing (#24 section A). The canonical fix names the typed
/// accessor: `.target(name:)` for a same-package target,
/// `.product(name:package:)` for a product of a declared package
/// dependency.
///
/// Computed or otherwise unhandled dependency shapes produce an
/// unmeasured observation; they can never silently establish a clean result.
extension Lint.Rule {
  public static let `bare string dependency` = Lint.Rule(
    id: "bare string dependency",
    default: .warning,
    controls: [
      .init(
        id: "bare string dependency manifest string",
        source: "let target = Target.target(name: \"Consumer\", dependencies: [\"Owner\"])",
        path: "Package.swift",
        expectation: .findings(1)
      ),
      .init(
        id: "bare string dependency manifest target",
        source: "let target = Target.target(name: \"Consumer\", "
          + "dependencies: [.target(name: \"Owner\")])",
        path: "Package.swift",
        expectation: .clean
      ),
      .init(
        id: "bare string dependency nonmanifest",
        source: "let target = Target.target(name: \"Consumer\", dependencies: [\"Owner\"])",
        path: "Sources/Consumer/Graph.swift",
        expectation: .clean
      ),
    ],
    observe: { source, severity in
      guard manifestIsPackageManifest(source.file.filePath) else {
        return Lint.Rule.Observation(
          findings: [],
          coverage: .measured,
          applicability: .inapplicable
        )
      }
      let visitor = ManifestBareStringDependencyVisitor(
        source: source.file,
        severity: severity,
        converter: source.converter
      )
      // Pre-pass: collect every file-scope binding before walking, so
      // a target call that references a constant declared later in the
      // file (or earlier) still resolves (#24 section A).
      visitor.collectFileScopeBindings(source.tree)
      visitor.walk(source.tree)
      let coverage: Lint.Rule.Coverage =
        visitor.unhandledSourceShape.map {
          .unmeasured(.unsupportedSourceShape($0))
        } ?? .measured
      return Lint.Rule.Observation(findings: visitor.matches, coverage: coverage)
    }
  )
}

/// Returns true when `filePath` names a SwiftPM package manifest:
/// `Package.swift` or a versioned `Package@swift-*.swift` variant.
@usableFromInline
internal func manifestIsPackageManifest(_ filePath: Swift.String) -> Swift.Bool {
  guard let filename = filePath.split(separator: "/", omittingEmptySubsequences: true).last
  else { return false }
  if filename == "Package.swift" { return true }
  return filename.hasPrefix("Package@swift-") && filename.hasSuffix(".swift")
}

@usableFromInline
internal let manifestBareStringDependencyMessage: Swift.String =
  "[bare string dependency]: a target dependency must use a typed "
  + "accessor — `.target(name:)` for a same-package target, "
  + "`.product(name:package:)` for a product — never a bare string. "
  + "SwiftPM resolves a bare string as `.byName`, which binds to "
  + "whatever it resolves first."

/// The target-declaring manifest factory members whose `dependencies:`
/// arrays the rule inspects.
private let manifestTargetFactories: Swift.Set<Swift.String> = [
  "target", "testTarget", "executableTarget", "macro", "plugin",
]

internal final class ManifestBareStringDependencyVisitor: SyntaxVisitor {
  let source: Source.File
  let severity: Diagnostic.Severity
  let converter: SourceLocationConverter
  var matches: [Diagnostic.Record] = []
  var unhandledSourceShape: Swift.String?

  /// File-scope `let`/`var` bindings, keyed by the pattern's
  /// identifier text, mapped to their initializer expression. Built by
  /// ``collectFileScopeBindings(_:)`` before the walk, so a target
  /// call that references a constant is resolvable regardless of
  /// declaration order (#24 section A).
  private var fileScopeBindings: [Swift.String: ExprSyntax] = [:]

  init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
    self.source = source
    self.severity = severity
    self.converter = converter
    super.init(viewMode: .sourceAccurate)
  }

  /// Collects every file-scope `VariableDeclSyntax` binding's
  /// identifier → initializer into ``fileScopeBindings``. Goes through
  /// `Lint.Syntax.Conditional.statements(_:)` so a manifest with a
  /// top-level `#if` is covered too.
  internal func collectFileScopeBindings(_ file: SourceFileSyntax) {
    for statement in Lint.Syntax.Conditional.statements(file.statements) {
      guard let variable = statement.item.as(VariableDeclSyntax.self) else { continue }
      for binding in variable.bindings {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
          let initializer = binding.initializer?.value
        else { continue }
        fileScopeBindings[pattern.identifier.text] = initializer
      }
    }
  }

  /// Resolves `expression` to the list of dependency-array element
  /// expressions it denotes: an array literal's own elements; a
  /// reference to a file-scope array constant, resolved recursively
  /// (bounded by `visited` to stop a cycle); or a `+`-concatenated
  /// `SequenceExprSyntax` of such arrays, whose non-operator operands
  /// are each resolved and concatenated. Anything else — a computed
  /// value such as a function call or `.map` — resolves to no
  /// elements. Anything else marks the observation unmeasured.
  private func resolvedElements(
    of expression: ExprSyntax,
    visited: Swift.Set<Swift.String> = []
  ) -> [ExprSyntax] {
    if let array = expression.as(ArrayExprSyntax.self) {
      return array.elements.map(\.expression)
    }
    if let reference = expression.as(DeclReferenceExprSyntax.self) {
      let name = reference.baseName.text
      guard !visited.contains(name), let bound = fileScopeBindings[name] else {
        unhandledSourceShape = "unresolved dependency array reference '\(name)'"
        return []
      }
      return resolvedElements(of: bound, visited: visited.union([name]))
    }
    if let sequence = expression.as(SequenceExprSyntax.self) {
      var result: [ExprSyntax] = []
      for element in sequence.elements where element.as(BinaryOperatorExprSyntax.self) == nil {
        result.append(contentsOf: resolvedElements(of: element, visited: visited))
      }
      return result
    }
    unhandledSourceShape =
      "computed dependency array '\(expression.trimmedDescription)'"
    return []
  }

  /// Resolves a single dependency-array element to the position at
  /// which a finding should be emitted, if it denotes a bare string:
  /// the element itself if it is a string literal or `.byName(name:)`
  /// call, or — if it is a reference to a file-scope string constant —
  /// the *reference's* position, not the constant's, since the author
  /// fixes the use site.
  private func flaggedPosition(
    of element: ExprSyntax,
    visited: Swift.Set<Swift.String> = []
  ) -> AbsolutePosition? {
    if let literal = element.as(StringLiteralExprSyntax.self) {
      return literal.positionAfterSkippingLeadingTrivia
    }
    // `.byName(name: "Owner")` is the exact harm the rule's own
    // message names ("SwiftPM resolves a bare string as `.byName`,
    // which binds to whatever it resolves first") — an explicit
    // spelling of the same resolution ambiguity a bare string
    // produces, not a safer alternative to it.
    if let call = element.as(FunctionCallExprSyntax.self),
      let member = call.calledExpression.as(MemberAccessExprSyntax.self),
      member.declName.baseName.text == "byName"
    {
      return call.positionAfterSkippingLeadingTrivia
    }
    if let reference = element.as(DeclReferenceExprSyntax.self) {
      let name = reference.baseName.text
      guard !visited.contains(name), let bound = fileScopeBindings[name] else {
        unhandledSourceShape = "unresolved target dependency reference '\(name)'"
        return nil
      }
      guard bound.is(StringLiteralExprSyntax.self) else {
        unhandledSourceShape =
          "computed target dependency '\(bound.trimmedDescription)'"
        return nil
      }
      return reference.positionAfterSkippingLeadingTrivia
    }
    if let call = element.as(FunctionCallExprSyntax.self),
      let member = call.calledExpression.as(MemberAccessExprSyntax.self),
      ["target", "product", "plugin"].contains(member.declName.baseName.text)
    {
      return nil
    }
    unhandledSourceShape =
      "unhandled target dependency '\(element.trimmedDescription)'"
    return nil
  }

  override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    guard
      let member = node.calledExpression.as(MemberAccessExprSyntax.self),
      manifestTargetFactories.contains(member.declName.baseName.text)
    else {
      return .visitChildren
    }
    for argument in node.arguments where argument.label?.text == "dependencies" {
      for element in resolvedElements(of: argument.expression) {
        guard let position = flaggedPosition(of: element) else { continue }
        emit(at: position)
      }
    }
    return .visitChildren
  }

  private func emit(at position: AbsolutePosition) {
    let location = converter.location(for: position)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "bare string dependency",
        message: manifestBareStringDependencyMessage
      )
    )
  }
}
