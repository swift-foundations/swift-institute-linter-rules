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

internal import Linter_Primitives
internal import SwiftSyntax

/// The canonical fix for `[PLAT-ARCH-022]`: qualify the bare stdlib
/// protocol reference.
///
/// This rule is the archetype of a mechanizable one. Its finding names a
/// single token, its fix is one qualification of that token, and the
/// qualified form is the only correct one — there is no judgment left for a
/// reader to apply. Everything the rewriter must be careful about is
/// already encoded in the detector: the same four syntactic positions, the
/// same stdlib-shadow exemption, the same composition-descending walk. The
/// rewriter mirrors the visitor rather than reimplementing its predicate,
/// so the two cannot drift into disagreeing about what is a finding.
///
/// Trivia is preserved by construction: the base and dot are synthesized
/// with none of their own, and the original identifier's leading trivia
/// moves to the base while its trailing trivia stays on the name. A fix
/// that reflowed comments or indentation would make every review of a fix
/// commit a diff review rather than a spot check.
internal func platformSwiftQualificationFixed(
  _ source: borrowing Lint.Source.Parsed
) -> Swift.String? {
  let rewriter = PlatformSwiftQualificationRewriter()
  let rewritten = rewriter.visit(source.tree)
  guard rewriter.changed else { return nil }
  return rewritten.description
}

/// Returns `type` with every bare shadowed-protocol leaf qualified, or
/// `nil` when it holds none.
///
/// Descends exactly the shapes the detector descends — optionals, implicitly
/// unwrapped optionals, attributed types, compositions, and `some`/`any`
/// constraints — and stops at anything else. A shape the detector does not
/// look inside is a shape this must not rewrite inside either.
internal func platformSwiftQualificationQualified(_ type: TypeSyntax) -> TypeSyntax? {
  if let optional = type.as(OptionalTypeSyntax.self) {
    guard let inner = platformSwiftQualificationQualified(optional.wrappedType) else { return nil }
    return TypeSyntax(optional.with(\.wrappedType, inner))
  }
  if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    guard let inner = platformSwiftQualificationQualified(iuo.wrappedType) else { return nil }
    return TypeSyntax(iuo.with(\.wrappedType, inner))
  }
  if let attributed = type.as(AttributedTypeSyntax.self) {
    guard let inner = platformSwiftQualificationQualified(attributed.baseType) else { return nil }
    return TypeSyntax(attributed.with(\.baseType, inner))
  }
  if let composition = type.as(CompositionTypeSyntax.self) {
    var elements = composition.elements
    var changed = false
    for index in elements.indices {
      guard let inner = platformSwiftQualificationQualified(elements[index].type) else { continue }
      elements[index] = elements[index].with(\.type, inner)
      changed = true
    }
    guard changed else { return nil }
    return TypeSyntax(composition.with(\.elements, elements))
  }
  if let someAny = type.as(SomeOrAnyTypeSyntax.self) {
    guard let inner = platformSwiftQualificationQualified(someAny.constraint) else { return nil }
    return TypeSyntax(someAny.with(\.constraint, inner))
  }
  guard let identifier = type.as(IdentifierTypeSyntax.self),
    platformSwiftQualificationShadowedProtocols.contains(identifier.name.text)
  else {
    return nil
  }
  let base = IdentifierTypeSyntax(
    name: .identifier("Swift", leadingTrivia: identifier.leadingTrivia)
  )
  let member = MemberTypeSyntax(
    baseType: TypeSyntax(base),
    name: identifier.name.with(\.leadingTrivia, []),
    genericArgumentClause: identifier.genericArgumentClause
  )
  return TypeSyntax(member)
}

/// Applies ``platformSwiftQualificationQualified(_:)`` at exactly the four
/// positions ``PlatformSwiftQualificationVisitor`` reports on, under the
/// same `[RULE-EXEMPT-6]` stdlib-shadow exemption.
internal final class PlatformSwiftQualificationRewriter: SyntaxRewriter {
  /// Whether any qualification was applied.
  ///
  /// Tracked rather than compared after the fact: a rewriter that reported
  /// change by diffing its own output against its input would call a
  /// round-trip formatting difference a fix.
  var changed: Swift.Bool = false

  private func qualify(_ type: TypeSyntax, at node: Syntax) -> TypeSyntax? {
    // Exempt per [RULE-EXEMPT-6] (stdlib-shadow): inside an extension on a
    // stdlib type the qualified form is structurally inexpressible, so
    // writing it would turn a warning into a compile error.
    guard !platformSwiftQualificationIsInsideStdlibExtension(node) else { return nil }
    guard let qualified = platformSwiftQualificationQualified(type) else { return nil }
    changed = true
    return qualified
  }

  override func visit(_ node: InheritedTypeSyntax) -> InheritedTypeSyntax {
    guard let qualified = qualify(node.type, at: Syntax(node)) else {
      return super.visit(node)
    }
    return node.with(\.type, qualified)
  }

  override func visit(_ node: GenericParameterSyntax) -> GenericParameterSyntax {
    guard let inherited = node.inheritedType,
      let qualified = qualify(inherited, at: Syntax(node))
    else {
      return super.visit(node)
    }
    return node.with(\.inheritedType, qualified)
  }

  override func visit(_ node: ConformanceRequirementSyntax) -> ConformanceRequirementSyntax {
    guard let qualified = qualify(node.rightType, at: Syntax(node)) else {
      return super.visit(node)
    }
    return node.with(\.rightType, qualified)
  }

  override func visit(_ node: SomeOrAnyTypeSyntax) -> TypeSyntax {
    guard let qualified = qualify(node.constraint, at: Syntax(node)) else {
      return super.visit(node)
    }
    return TypeSyntax(node.with(\.constraint, qualified))
  }
}
