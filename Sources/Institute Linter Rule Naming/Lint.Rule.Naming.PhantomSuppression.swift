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

/// A phantom generic parameter — a pure compile-time discriminator over
/// `Tagged` / `Index` / `Property` — MUST be bound `~Copyable & ~Escapable`,
/// not bare and not `~Copyable`-only. Citation: `[API-NAME-010b]`.
///
/// ADVISORY (non-gating, `.warning`). Conservative by design: it flags the
/// two cleanest shapes and never a stored-value parameter.
///   1. `extension Tagged where … <P>: ~Copyable { … }` (and `Index` /
///      `Property` extensions) — the extended type's first parameter is
///      definitionally phantom, so a `~Copyable`-only bound under-suppresses.
///   2. A `func` / `init` / `subscript` / `typealias` generic parameter
///      `<P: ~Copyable>` that appears as the FIRST type-argument of a
///      `Tagged<P,…>` / `Index<P>` / `Property<P,…>` in the declaration AND
///      never as a stored / by-value position (`: P`, `[P]`, `-> P`, `P?`,
///      `consuming`/`borrowing`/`inout P`).
/// The bare-`<P>` form and the `extension Tagged where … Tag: ~Copyable`
/// associatedtype/conditional-conformance companions are intentionally out of
/// this conservative scope — see the outcome record.
extension Lint.Rule {
  public static let `phantom suppression` = Lint.Rule(
    id: "phantom suppression",
    default: .warning,
    findings: { source, severity in
      let visitor = NamingPhantomSuppressionVisitor(
        source: source.file,
        severity: severity,
        converter: source.converter
      )
      visitor.walk(source.tree)
      return visitor.matches
    }
  )
}

private let namingPhantomSuppressionMessage: Swift.String =
  "[phantom suppression] [API-NAME-010b]: phantom generic parameter (a pure "
  + "Tagged/Index/Property discriminator, never stored) is under-suppressed — "
  + "bind it `~Copyable & ~Escapable`, not `~Copyable`-only or bare. A marker "
  + "requirement on a phantom is vacuous over-constraint (Reynolds parametricity)."

internal final class NamingPhantomSuppressionVisitor: SyntaxVisitor {
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

  // Shape 1 — `extension Tagged/Index/Property where <phantom>: ~Copyable`.
  //
  // Only the wrapper's PHANTOM parameter is in scope (`Tag` for
  // `Tagged`/`Property`, `Element` for `Index` — the first parameter,
  // definitionally phantom). Other where-clause identifiers (`Underlying`,
  // `Base`, …) name STORED / value parameters, where a `~Copyable`-only
  // bound is correct — firing there was a false-positive class surfaced
  // on swift-tagged-primitives' own surface (Tagged.swift `Underlying:
  // ~Copyable` extensions, 2026-07-07 tower-validation follow-up).
  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let wrapper = phantomWrapperBaseName(node.extendedType) else { return .visitChildren }
    guard let whereClause = node.genericWhereClause else { return .visitChildren }
    for requirement in whereClause.requirements {
      guard case .conformanceRequirement(let conformance) = requirement.requirement else {
        continue
      }
      guard let left = conformance.leftType.as(IdentifierTypeSyntax.self) else { continue }
      guard left.name.text == phantomParameterName(ofWrapper: wrapper) else { continue }
      if constraintIsCopyableOnly(conformance.rightType) {
        emit(at: conformance.rightType.positionAfterSkippingLeadingTrivia)
      }
    }
    return .visitChildren
  }

  // Shape 2 — generic parameter `<P: ~Copyable>` used as a Tagged/Index/Property
  // first-arg discriminator and never stored.
  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    checkGenericParameters(node.genericParameterClause, in: Syntax(node))
    return .visitChildren
  }
  override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    checkGenericParameters(node.genericParameterClause, in: Syntax(node))
    return .visitChildren
  }
  override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
    checkGenericParameters(node.genericParameterClause, in: Syntax(node))
    return .visitChildren
  }
  override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
    checkGenericParameters(node.genericParameterClause, in: Syntax(node))
    return .visitChildren
  }

  private func checkGenericParameters(_ clause: GenericParameterClauseSyntax?, in decl: Syntax) {
    guard let clause else { return }
    let body = decl.description
    for parameter in clause.parameters {
      let name = parameter.name.text
      // Only `<P: ~Copyable>` (bare `<P>` is out of this conservative scope —
      // its phantom-ness can't be confirmed without whole-type analysis here).
      guard let inherited = parameter.inheritedType, constraintIsCopyableOnly(inherited) else {
        continue
      }
      guard usedAsPhantomDiscriminator(name, in: body), !usedAsStoredValue(name, in: body) else {
        continue
      }
      emit(at: parameter.name.positionAfterSkippingLeadingTrivia)
    }
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
        identifier: "phantom suppression",
        message: namingPhantomSuppressionMessage
      ))
  }
}

/// The phantom (first) generic parameter's canonical name for each
/// supported wrapper: `Tagged<Tag, Underlying>` / `Property<Tag, …>` →
/// `Tag`; `Index<Element> = Tagged<Element, Ordinal>` → `Element`.
/// Shape 1 only inspects requirements on this parameter — the wrapper's
/// remaining parameters are stored/value positions.
private func phantomParameterName(ofWrapper leaf: Swift.String) -> Swift.String {
  leaf == "Index" ? "Element" : "Tag"
}

/// The wrapper's leaf name if `type` is `Tagged` / `Index` / `Property`
/// (bare or member-qualified, e.g. `Index_Primitives.Index`), else nil.
private func phantomWrapperBaseName(_ type: TypeSyntax) -> Swift.String? {
  let leaf: Swift.String?
  if let identifier = type.as(IdentifierTypeSyntax.self) {
    leaf = identifier.name.text
  } else if let member = type.as(MemberTypeSyntax.self) {
    leaf = member.name.text
  } else {
    leaf = nil
  }
  guard let leaf, leaf == "Tagged" || leaf == "Index" || leaf == "Property" else { return nil }
  return leaf
}

/// True when `type` is `~Copyable` (a lone suppressed `Copyable`) and is NOT a
/// composition that already includes `~Escapable`.
private func constraintIsCopyableOnly(_ type: TypeSyntax) -> Swift.Bool {
  if let suppressed = type.as(SuppressedTypeSyntax.self) {
    return suppressedIsCopyable(suppressed)
  }
  if let composition = type.as(CompositionTypeSyntax.self) {
    var sawCopyable = false
    var sawEscapable = false
    for element in composition.elements {
      if let suppressed = element.type.as(SuppressedTypeSyntax.self) {
        if suppressedIsCopyable(suppressed) { sawCopyable = true }
        if suppressedLeaf(suppressed) == "Escapable" { sawEscapable = true }
      }
    }
    return sawCopyable && !sawEscapable
  }
  return false
}

private func suppressedIsCopyable(_ suppressed: SuppressedTypeSyntax) -> Swift.Bool {
  suppressedLeaf(suppressed) == "Copyable"
}

private func suppressedLeaf(_ suppressed: SuppressedTypeSyntax) -> Swift.String? {
  suppressed.type.as(IdentifierTypeSyntax.self)?.name.text
}

/// Text heuristic: `name` appears as the first type-argument of a phantom wrapper.
private func usedAsPhantomDiscriminator(_ name: Swift.String, in body: Swift.String) -> Swift.Bool {
  for wrapper in ["Tagged<", "Index<", "Property<"] {
    if body.contains(wrapper + name + ",") || body.contains(wrapper + name + ">") { return true }
  }
  return false
}

/// Text heuristic: `name` appears in a stored / by-value position. Conservative —
/// any hit suppresses the flag (we never warn on a possible stored param).
private func usedAsStoredValue(_ name: Swift.String, in body: Swift.String) -> Swift.Bool {
  for marker in [
    "[" + name + "]", "-> " + name, ": " + name + ")", ": " + name + " ",
    ": " + name + ",", ": " + name + "\n", name + "?",
    "consuming " + name, "borrowing " + name, "inout " + name,
  ] where body.contains(marker) {
    return true
  }
  return false
}
