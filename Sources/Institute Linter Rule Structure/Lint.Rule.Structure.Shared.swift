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

/// Returns true if `name` is the institute `Protocol` sentinel — a
/// member name reserved for the hoisted-protocol pattern per
/// [API-IMPL-009] / [PKG-NAME-001]. The sentinel can appear either
/// raw (`Protocol`) or backtick-escaped (`` `Protocol` ``); both forms
/// signal the same intent.
///
/// Citation: [RULE-EXEMPT-5] (Protocol-sentinel) in
/// the rule-exemptions skill.
///
/// Deliberate per-pack copy of the canonical contract stated on
/// `Lint.Rule.isProtocolSentinel(_:)` (`Lint.Rule.Naming.Shared.swift`).
/// Rule packs are independently consumable library products; the
/// contract is copied, never re-derived. See #17.
internal func structureIsProtocolSentinelName(_ name: Swift.String) -> Swift.Bool {
  return name == "Protocol" || name == "`Protocol`"
}

/// The SwiftSyntax visitor-family base classes whose subclasses are
/// exempt from the structure-pack rules per [RULE-EXEMPT-7]
/// (syntax-visitor-subclass). The set covers the open base classes a
/// rule-pack visitor legitimately extends:
///
/// - `SyntaxVisitor` — most common; per-syntax-kind visit hooks.
/// - `SyntaxAnyVisitor` — any-syntax visit hook (catch-all dispatch).
/// - `SyntaxRewriter` — visit + rewrite (returns replacement syntax).
///
/// Leaf-name semantics: both bare (`SyntaxVisitor`) and qualified
/// (`SwiftSyntax.SyntaxVisitor`) inheritance forms resolve to the
/// same leaf string in the inheritance clause walk.
internal let structureSyntaxVisitorFamilyNames: Swift.Set<Swift.String> = [
  "SyntaxVisitor",
  "SyntaxAnyVisitor",
  "SyntaxRewriter",
]

/// Returns true if `clause` lists any member of the SwiftSyntax
/// visitor family (`SyntaxVisitor`, `SyntaxAnyVisitor`,
/// `SyntaxRewriter`) as an inherited type. Used by
/// `Lint.Rule.Structure.MinimalTypeBody` to skip the type-body check
/// on rule-pack visitor subclasses, whose `override func visit(_:)`
/// hooks are protocol-shaped members dictated by the base class.
///
/// Citation: [RULE-EXEMPT-7] (syntax-visitor-subclass) in
/// the rule-exemptions skill.
///
/// Leaf-name lookup mirrors `namingInheritanceLeafNames` semantics —
/// both `IdentifierTypeSyntax` (bare `SyntaxVisitor`) and
/// `MemberTypeSyntax` (qualified `SwiftSyntax.SyntaxVisitor`) resolve
/// to the visitor's name.
/// Returns true if `node` is an `AccessorBlockSyntax` in its shorthand-
/// getter form (`var x: Int { 0 }`, with no explicit `get { }`).
///
/// A short-form computed-property or subscript getter parses as
/// `AccessorBlockSyntax.getter(CodeBlockItemListSyntax)` — there is no
/// `AccessorDeclSyntax` node at all. Rules that track a function-like
/// body boundary (init body, explicit accessor body, closure body,
/// deinit body, subscript body) by testing `AccessorDeclSyntax` alone
/// miss this shorthand form entirely.
///
/// Deliberate per-pack copy of `namingIsShorthandGetterAccessorBlock`
/// from `Lint.Rule.Naming.Shared.swift`. Rule packs are independently
/// consumable library products; the contract is copied, never
/// re-derived — there is no universal/institute tier boundary between
/// two targets of this package. See #17. Semantics match.
internal func structureIsShorthandGetterAccessorBlock(_ node: Syntax) -> Swift.Bool {
  guard let block = node.as(AccessorBlockSyntax.self) else { return false }
  if case .getter = block.accessors { return true }
  return false
}

internal func structureExtendsSyntaxVisitor(_ clause: InheritanceClauseSyntax?) -> Swift.Bool {
  guard let clause else { return false }
  for inherited in clause.inheritedTypes {
    let type = inherited.type
    let leaf: Swift.String?
    if let identifier = type.as(IdentifierTypeSyntax.self) {
      leaf = identifier.name.text
    } else if let member = type.as(MemberTypeSyntax.self) {
      leaf = member.name.text
    } else {
      leaf = nil
    }
    if let leaf, structureSyntaxVisitorFamilyNames.contains(leaf) {
      return true
    }
  }
  return false
}
