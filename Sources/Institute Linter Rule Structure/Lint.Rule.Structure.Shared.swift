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

internal import SwiftSyntax

/// Flattens a top-level `CodeBlockItemListSyntax` (e.g.
/// `SourceFileSyntax.statements`) into the declarations it contains,
/// descending into `IfConfigDeclSyntax` (`#if os(...) ... #endif`)
/// clauses recursively so that a type or extension declared inside a
/// top-level `#if` is visible to a by-hand top-level-declaration scan.
///
/// Platform-conditional top-level declarations are ordinary under the
/// Institute cross-platform mandate. Rules that dispatch through
/// per-syntax-kind `visit` overrides see `#if` contents automatically
/// via the source-accurate view; the two rules that instead enumerate
/// `SourceFileSyntax.statements` by hand (`file name nested path`,
/// `extension file naming`) do not, since `IfConfigDeclSyntax` matches
/// `case .decl` but is neither a primary-type decl nor an extension —
/// without this helper it silently drops through. Every clause's
/// elements are included (not just the first / active one): the file
/// judged here compiles under several distinct configurations, and any
/// of them could hold the type or extension in question.
internal func structureFlattenTopLevelItems(
  _ statements: CodeBlockItemListSyntax
) -> [CodeBlockItemSyntax] {
  var result: [CodeBlockItemSyntax] = []
  for item in statements {
    guard case .decl(let decl) = item.item,
      let ifConfig = decl.as(IfConfigDeclSyntax.self)
    else {
      result.append(item)
      continue
    }
    for clause in ifConfig.clauses {
      guard let elements = clause.elements?.as(CodeBlockItemListSyntax.self) else { continue }
      result.append(contentsOf: structureFlattenTopLevelItems(elements))
    }
  }
  return result
}

/// Returns true if `name` is the institute `Protocol` sentinel — a
/// member name reserved for the hoisted-protocol pattern per
/// [API-IMPL-009] / [PKG-NAME-001]. The sentinel can appear either
/// raw (`Protocol`) or backtick-escaped (`` `Protocol` ``); both forms
/// signal the same intent.
///
/// Citation: [RULE-EXEMPT-5] (Protocol-sentinel) in
/// `swift-institute/Skills/rule-exemptions/SKILL.md`.
///
/// Pack-local duplicate of `namingIsProtocolSentinelName` from
/// `Lint.Rule.Naming.Shared.swift` (institute pack) — cross-pack
/// visibility isn't available across the universal/institute tier
/// boundary, so the helper is duplicated; semantics match. Used by
/// `Lint.Rule.Structure.MinimalTypeBody` to skip the typealias-name
/// check on `Protocol`-named members.
internal func structureIsProtocolSentinelName(_ name: Swift.String) -> Swift.Bool {
  return name == "Protocol" || name == "`Protocol`"
}

/// Strips a single pair of surrounding backticks from a token's `.text`
/// (which, unlike `.trimmedDescription`, includes the backticks for an
/// escaped identifier). `` `Protocol` `` becomes `Protocol`; `Protocol`
/// is returned unchanged.
internal func structureStripBackticks(_ text: Swift.String) -> Swift.String {
  var slice = Swift.Substring(text)
  if slice.hasPrefix("`") { slice = slice.dropFirst() }
  if slice.hasSuffix("`") { slice = slice.dropLast() }
  return Swift.String(slice)
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
@usableFromInline
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
/// `swift-institute/Skills/rule-exemptions/SKILL.md`.
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
/// Pack-local duplicate of `namingIsShorthandGetterAccessorBlock` from
/// `Lint.Rule.Naming.Shared.swift` (institute pack) — cross-pack
/// visibility isn't available across the universal/institute tier
/// boundary, so the helper is duplicated; semantics match.
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
