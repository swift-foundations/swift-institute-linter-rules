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

/// Reviews `@Sendable` requirements at public/package API boundaries whose
/// syntax already carries a one-shot ownership, lifetime, or isolation signal.
///
/// The predicate is deliberately narrower than “every `@Sendable` closure”.
/// SwiftSyntax cannot prove whether an arbitrary closure is stored or invoked
/// concurrently. It can establish two useful surfaces:
///
/// - a nonescaping closure parameter is scoped to the call;
/// - `consuming`, `sending`, `isolated`, `~Copyable`, and `~Escapable` spell an
///   ownership/region boundary in the declaration itself.
///
/// A finding therefore requests design review; it never claims that deleting
/// `@Sendable` is mechanically equivalent, and the rule intentionally has no
/// fix. The preference order is scoped borrowing/non-escape, then
/// consuming/sending transfer, then isolated/region transfer, with `@Sendable`
/// reserved for independently concurrent sharing.
///
/// Justified sharing uses the existing `.next` suppression channel. For this
/// rule, the adjacent reason must contain a recognized `CATEGORY:` and a
/// non-empty `SHARING:` proof. This rule checks those fields' syntax, not the
/// truth of the proof.
extension Lint.Rule {
  public static let `sendable sharing requirement` = Lint.Rule(
    id: "sendable sharing requirement",
    default: .warning,
    suppression: .next,
    findings: { source, severity in
      let visitor = MemorySendableSharingRequirementVisitor(
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
internal let memorySendableSharingRequirementMessage: Swift.String =
  "[sendable sharing requirement] [MEM-SEND-007]: public/package API requires "
  + "an `@Sendable` closure at a structurally one-shot ownership or region "
  + "boundary. Review in order: scoped borrowing/non-escape; consuming/sending "
  + "ownership transfer; isolated/region transfer; retain `@Sendable` only for "
  + "independently concurrent sharing. This diagnostic requests adjudication; "
  + "it does not claim that removing `@Sendable` is mechanically equivalent, "
  + "and no autofix is offered."

@usableFromInline
internal let memorySendableSharingRequirementStrongMessage: Swift.String =
  memorySendableSharingRequirementMessage
  + " STRONG PRIORITY: this declaration also spells `~Copyable`, `~Escapable`, "
  + "`consuming`, `sending`, or `isolated`, directly expressing single-use or "
  + "region transfer."

@usableFromInline
internal let memorySendableSharingRequirementSuppressionMessage: Swift.String =
  "[sendable sharing requirement] [MEM-SEND-007]: suppression is not justified. "
  + "Use `REASON: CATEGORY: <multi-task-storage|concurrent-cancellation|"
  + "shared-endpoint|actor-independent-reuse|captureless-os-callback>; SHARING: "
  + "<concise proof naming the independently concurrent users or storage boundary>.`"

private let memorySendableSharingCategories: Swift.Set<Swift.String> = [
  "multi-task-storage",
  "concurrent-cancellation",
  "shared-endpoint",
  "actor-independent-reuse",
  "captureless-os-callback",
]

internal final class MemorySendableSharingRequirementVisitor: SyntaxVisitor {
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
    guard memorySendableSharingIsPublicOrPackageEffective(Syntax(node), node.modifiers) else {
      return .visitChildren
    }

    let declarationHasStrongSignal =
      memorySendableSharingHasOwnershipSignal(Syntax(node.signature))
      || memorySendableSharingHasOwnershipSignal(
        node.genericParameterClause.map { Syntax($0) })
      || memorySendableSharingHasOwnershipSignal(
        node.genericWhereClause.map { Syntax($0) })
      || node.modifiers.contains(where: { modifier in
        switch modifier.name.tokenKind {
        case .keyword(.consuming): true
        default: false
        }
      })
    for parameter in node.signature.parameterClause.parameters {
      guard memorySendableSharingContainsSendableClosure(parameter.type) else { continue }
      let isNonescaping = !memorySendableSharingTypeHasAttribute(parameter.type, named: "escaping")
      guard isNonescaping || declarationHasStrongSignal else { continue }
      emit(
        declaration: Syntax(node),
        at: parameter.type.positionAfterSkippingLeadingTrivia,
        strong: declarationHasStrongSignal
      )
    }

    if let returnType = node.signature.returnClause?.type,
      memorySendableSharingContainsSendableClosure(returnType),
      declarationHasStrongSignal
    {
      emit(
        declaration: Syntax(node),
        at: returnType.positionAfterSkippingLeadingTrivia,
        strong: true
      )
    }
    return .visitChildren
  }

  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    guard memorySendableSharingIsPublicOrPackageEffective(Syntax(node), node.modifiers) else {
      return .visitChildren
    }
    for binding in node.bindings {
      guard let type = binding.typeAnnotation?.type,
        memorySendableSharingContainsSendableClosure(type),
        memorySendableSharingHasOwnershipSignal(Syntax(type))
      else { continue }
      emit(declaration: Syntax(node), at: type.positionAfterSkippingLeadingTrivia, strong: true)
    }
    return .visitChildren
  }

  override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
    guard memorySendableSharingIsPublicOrPackageEffective(Syntax(node), node.modifiers) else {
      return .visitChildren
    }
    let type = node.initializer.value
    guard memorySendableSharingContainsSendableClosure(type),
      (
        memorySendableSharingHasOwnershipSignal(Syntax(type))
          || memorySendableSharingHasOwnershipSignal(
            node.genericParameterClause.map { Syntax($0) })
          || memorySendableSharingHasOwnershipSignal(
            node.genericWhereClause.map { Syntax($0) })
      )
    else { return .visitChildren }
    emit(declaration: Syntax(node), at: type.positionAfterSkippingLeadingTrivia, strong: true)
    return .visitChildren
  }

  private func emit(declaration: Syntax, at position: AbsolutePosition, strong: Swift.Bool) {
    switch memorySendableSharingSuppression(in: declaration.leadingTrivia) {
    case .none:
      append(at: position, message: strong
        ? memorySendableSharingRequirementStrongMessage
        : memorySendableSharingRequirementMessage)
    case .valid:
      return
    case .invalid:
      append(at: position, message: memorySendableSharingRequirementSuppressionMessage)
    }
  }

  private func append(at position: AbsolutePosition, message: Swift.String) {
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
        identifier: "sendable sharing requirement",
        message: message
      ))
  }
}

private enum MemorySendableSharingSuppressionDisposition {
  case none
  case valid
  case invalid
}

private func memorySendableSharingSuppression(in trivia: Trivia)
  -> MemorySendableSharingSuppressionDisposition
{
  let directive = "// swift-linter:disable:next sendable sharing requirement"
  var hasDirective = false
  var reason: Swift.String?
  for piece in trivia {
    guard case .lineComment(let text) = piece else { continue }
    if text == directive { hasDirective = true }
    if hasDirective, text.hasPrefix("// REASON:") {
      reason = Swift.String(text.dropFirst("// REASON:".count))
    }
  }
  guard hasDirective else { return .none }
  guard let reason, memorySendableSharingReasonIsValid(reason) else {
    return .invalid
  }
  return .valid
}

private func memorySendableSharingReasonIsValid(_ reason: Swift.String) -> Swift.Bool {
  guard let categoryRange = reason.range(of: "CATEGORY:") else { return false }
  let afterCategory = reason[categoryRange.upperBound...]
  guard let separator = afterCategory.firstIndex(of: ";") else { return false }
  let categorySlice = afterCategory[..<separator]
  let category = Swift.String(
    categorySlice.drop(while: { $0 == " " || $0 == "\t" })
      .reversed().drop(while: { $0 == " " || $0 == "\t" }).reversed()
  )
  guard memorySendableSharingCategories.contains(category) else { return false }
  let afterSeparator = afterCategory[afterCategory.index(after: separator)...]
  guard let sharingRange = afterSeparator.range(of: "SHARING:") else { return false }
  return afterSeparator[sharingRange.upperBound...].contains(where: { !$0.isWhitespace && $0 != "." })
}

private func memorySendableSharingIsPublicOrPackageEffective(
  _ node: Syntax,
  _ modifiers: DeclModifierListSyntax
) -> Swift.Bool {
  if memorySendableSharingHasPublicOrPackage(modifiers) { return true }
  var current = node.parent
  while let candidate = current {
    if let ext = candidate.as(ExtensionDeclSyntax.self) {
      return memorySendableSharingHasPublicOrPackage(ext.modifiers)
    }
    current = candidate.parent
  }
  return false
}

private func memorySendableSharingHasPublicOrPackage(_ modifiers: DeclModifierListSyntax)
  -> Swift.Bool
{
  modifiers.contains { modifier in
    switch modifier.name.tokenKind {
    case .keyword(.public), .keyword(.open), .keyword(.package): true
    default: false
    }
  }
}

private func memorySendableSharingContainsSendableClosure(_ type: TypeSyntax) -> Swift.Bool {
  if let attributed = type.as(AttributedTypeSyntax.self) {
    let sendable = attributed.attributes.contains { element in
      guard let attribute = element.as(AttributeSyntax.self) else { return false }
      return attribute.attributeName.trimmedDescription == "Sendable"
    }
    if sendable, memorySendableSharingStrippedType(attributed.baseType).is(FunctionTypeSyntax.self) {
      return true
    }
    return memorySendableSharingContainsSendableClosure(attributed.baseType)
  }
  if let optional = type.as(OptionalTypeSyntax.self) {
    return memorySendableSharingContainsSendableClosure(optional.wrappedType)
  }
  if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    return memorySendableSharingContainsSendableClosure(iuo.wrappedType)
  }
  if let tuple = type.as(TupleTypeSyntax.self) {
    return tuple.elements.contains { memorySendableSharingContainsSendableClosure($0.type) }
  }
  return false
}

private func memorySendableSharingStrippedType(_ type: TypeSyntax) -> TypeSyntax {
  var current = type
  while true {
    if let attributed = current.as(AttributedTypeSyntax.self) {
      current = attributed.baseType
    } else if let optional = current.as(OptionalTypeSyntax.self) {
      current = optional.wrappedType
    } else if let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
      current = iuo.wrappedType
    } else {
      return current
    }
  }
}

private func memorySendableSharingTypeHasAttribute(_ type: TypeSyntax, named name: Swift.String)
  -> Swift.Bool
{
  guard let attributed = type.as(AttributedTypeSyntax.self) else { return false }
  return attributed.attributes.contains { element in
    guard let attribute = element.as(AttributeSyntax.self) else { return false }
    return attribute.attributeName.trimmedDescription == name
  }
}

private func memorySendableSharingHasOwnershipSignal(_ syntax: Syntax) -> Swift.Bool {
  for token in syntax.tokens(viewMode: .sourceAccurate) {
    switch token.tokenKind {
    case .keyword(.consuming), .keyword(.sending), .keyword(.isolated): return true
    case .identifier(let text) where text == "Copyable" || text == "Escapable":
      if token.previousToken(viewMode: .sourceAccurate)?.tokenKind == .prefixOperator("~") {
        return true
      }
    default: continue
    }
  }
  return false
}

private func memorySendableSharingHasOwnershipSignal(_ syntax: Syntax?) -> Swift.Bool {
  guard let syntax else { return false }
  return memorySendableSharingHasOwnershipSignal(syntax)
}
