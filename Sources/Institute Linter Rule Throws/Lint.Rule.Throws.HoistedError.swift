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

/// Hoisted error types in public-API throws clauses. Citation: `[API-ERR-007]`.
extension Lint.Rule {
  public static let `hoisted error in public throws` = Lint.Rule(
    id: "hoisted error in public throws",
    default: .warning,
    findings: { source, severity in
      let visitor = ThrowsHoistedErrorVisitor(
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
internal let throwsHoistedErrorMessage: Swift.String =
  "[hoisted error in public throws] [API-ERR-007]: public-API "
  + "`throws(T)` clauses MUST reference the canonical public path, "
  + "never the `__`-prefixed hoisted internal type."

private func hoistedIsPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
  for modifier in modifiers {
    switch modifier.name.tokenKind {
    case .keyword(.public), .keyword(.open): return true
    default: continue
    }
  }
  return false
}

/// Returns true if `node`'s *effective* visibility is `public`/`open`
/// — either it carries the modifier itself, or it declares no access
/// modifier and is a member of a `public`/`open extension`. In
/// Swift, a member of a `public extension` is public API without
/// carrying the keyword; this rule is explicitly scoped to public API
/// by its own doc/message and was silently defeated by moving the
/// `public` keyword to the enclosing extension.
private func hoistedIsPublicOrOpenEffective(
  _ node: Syntax,
  modifiers: DeclModifierListSyntax
) -> Swift.Bool {
  if hoistedIsPublicOrOpen(modifiers) {
    return true
  }
  var current: Syntax? = node.parent
  while let candidate = current {
    if let ext = candidate.as(ExtensionDeclSyntax.self) {
      return hoistedIsPublicOrOpen(ext.modifiers)
    }
    current = candidate.parent
  }
  return false
}

private func hoistedLeafIdentifier(of type: TypeSyntax) -> Swift.String? {
  var current = type
  while let optional = current.as(OptionalTypeSyntax.self) { current = optional.wrappedType }
  while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    current = iuo.wrappedType
  }
  while let attributed = current.as(AttributedTypeSyntax.self) { current = attributed.baseType }
  if let identifier = current.as(IdentifierTypeSyntax.self) { return identifier.name.text }
  if let member = current.as(MemberTypeSyntax.self) { return member.name.text }
  return nil
}

internal final class ThrowsHoistedErrorVisitor: SyntaxVisitor {
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

  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    guard hoistedIsPublicOrOpenEffective(Syntax(node), modifiers: node.modifiers) else {
      return .visitChildren
    }
    checkThrowsClause(node.signature.effectSpecifiers?.throwsClause)
    return .visitChildren
  }

  override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    guard hoistedIsPublicOrOpenEffective(Syntax(node), modifiers: node.modifiers) else {
      return .visitChildren
    }
    checkThrowsClause(node.signature.effectSpecifiers?.throwsClause)
    return .visitChildren
  }

  private func checkThrowsClause(_ clause: ThrowsClauseSyntax?) {
    guard let clause, let type = clause.type else { return }
    guard let leaf = hoistedLeafIdentifier(of: type) else { return }
    guard leaf.hasPrefix("__") else { return }
    let location = converter.location(for: type.positionAfterSkippingLeadingTrivia)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "hoisted error in public throws",
        message: throwsHoistedErrorMessage
      ))
  }
}
