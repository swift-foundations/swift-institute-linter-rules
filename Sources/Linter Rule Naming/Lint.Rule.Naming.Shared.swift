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

internal import SwiftSyntax

/// Result-builder protocol method names per Swift's `@resultBuilder`
/// attribute. A function declared inside a type marked `@resultBuilder`
/// and named one of these is protocol-required — its name and parameter
/// / return types are dictated by the builder protocol's accumulator
/// and expression types. The Naming pack treats these as spec-mirroring
/// at the attribute level (see [API-NAME-003] semantics): the
/// `@resultBuilder` attribute IS the specification.
@usableFromInline
internal let namingResultBuilderProtocolMethods: Swift.Set<Swift.String> = [
    "buildExpression",
    "buildBlock",
    "buildPartialBlock",
    "buildOptional",
    "buildEither",
    "buildArray",
    "buildLimitedAvailability",
    "buildFinalResult",
]

/// Returns true if any enclosing type declaration of `node` carries an
/// extension-pattern attribute (`@resultBuilder` or `@Suite`). Walks up
/// the `parent` chain and stops at the first `struct` / `class` / `enum`
/// / `actor` declaration — those are the decl kinds Swift permits these
/// attributes on. Nested extensions are crossed without consuming the
/// search (a method inside `extension Builder` inside an outer
/// `@resultBuilder enum Builder` still finds the attribute on the enum).
///
/// Implements [RULE-EXEMPT-4] (extension-pattern attribute) for naming
/// rules whose firing on members must yield to the protocol-witness
/// shape these attributes impose: SE-0289 builder method names for
/// `@resultBuilder`, swift-testing's nested-suite shape for `@Suite`.
internal func namingIsInsideExtensionPatternType(_ node: Syntax) -> Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
        if let typeDecl = candidate.as(StructDeclSyntax.self) {
            return namingHasExtensionPatternAttribute(typeDecl.attributes)
        }
        if let typeDecl = candidate.as(EnumDeclSyntax.self) {
            return namingHasExtensionPatternAttribute(typeDecl.attributes)
        }
        if let typeDecl = candidate.as(ClassDeclSyntax.self) {
            return namingHasExtensionPatternAttribute(typeDecl.attributes)
        }
        if let typeDecl = candidate.as(ActorDeclSyntax.self) {
            return namingHasExtensionPatternAttribute(typeDecl.attributes)
        }
        current = candidate.parent
    }
    return false
}

/// Returns true if `attributes` includes either of the extension-pattern
/// attributes — `@resultBuilder` (SE-0289 builder protocol) or `@Suite`
/// (swift-testing's extension-pattern, which legitimately holds nested
/// `@Suite` substructures as its body members). See [RULE-EXEMPT-4].
internal func namingHasExtensionPatternAttribute(_ attributes: AttributeListSyntax) -> Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        let name = attr.attributeName.trimmedDescription
        if name == "resultBuilder" || name == "Suite" {
            return true
        }
    }
    return false
}

/// Returns true if `node` is declared inside an enclosing context that
/// introduces a protocol conformance — either an extension with a
/// non-empty inheritance clause, or a type declaration (struct, class,
/// enum, actor) with a non-empty inheritance clause. Typealiases
/// declared in such a context typically satisfy an associatedtype
/// requirement of the adopted protocol (`Collection.Index`,
/// `Sequence.Element`, `Ownership.Borrow.Protocol.Borrowed`) — they
/// share the protocol's name by requirement, not by discretionary
/// choice. The walk-up stops at the first decl context.
internal func namingIsInsideConformingContext(_ node: Syntax) -> Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
        if let ext = candidate.as(ExtensionDeclSyntax.self) {
            return ext.inheritanceClause != nil
        }
        if let typeDecl = candidate.as(StructDeclSyntax.self) {
            return typeDecl.inheritanceClause != nil
        }
        if let typeDecl = candidate.as(ClassDeclSyntax.self) {
            return typeDecl.inheritanceClause != nil
        }
        if let typeDecl = candidate.as(EnumDeclSyntax.self) {
            return typeDecl.inheritanceClause != nil
        }
        if let typeDecl = candidate.as(ActorDeclSyntax.self) {
            return typeDecl.inheritanceClause != nil
        }
        current = candidate.parent
    }
    return false
}

/// Returns the leaf names of every protocol in the nearest enclosing
/// extension / type-decl's inheritance clause. Used by rule visitors
/// that need to gate on which protocol the enclosing extension adopts
/// (e.g., "is this `init(integerLiteral:)` declared inside an
/// `extension Tagged: ExpressibleByIntegerLiteral`?"). Returns an
/// empty array if the enclosing context has no inheritance clause or
/// if no enclosing decl exists.
///
/// Leaf-name semantics: `Swift.Sequence` and `Sequence` both yield
/// `"Sequence"`. Citation-dict consumers key on the leaf name so they
/// don't need to enumerate every possible qualification.
internal func namingConformanceProtocolNames(_ node: Syntax) -> [Swift.String] {
    var current: Syntax? = node.parent
    while let candidate = current {
        if let ext = candidate.as(ExtensionDeclSyntax.self) {
            return namingInheritanceLeafNames(ext.inheritanceClause)
        }
        if let typeDecl = candidate.as(StructDeclSyntax.self) {
            return namingInheritanceLeafNames(typeDecl.inheritanceClause)
        }
        if let typeDecl = candidate.as(ClassDeclSyntax.self) {
            return namingInheritanceLeafNames(typeDecl.inheritanceClause)
        }
        if let typeDecl = candidate.as(EnumDeclSyntax.self) {
            return namingInheritanceLeafNames(typeDecl.inheritanceClause)
        }
        if let typeDecl = candidate.as(ActorDeclSyntax.self) {
            return namingInheritanceLeafNames(typeDecl.inheritanceClause)
        }
        current = candidate.parent
    }
    return []
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
/// Used by name-shape rules that would otherwise flag the sentinel as
/// a rename-bridge typealias (`UnificationTypealias`) or as a
/// non-minimal type-body member (`MinimalTypeBody`). The institute
/// pattern intentionally hoists the protocol witness through the
/// nested-namespace alias `Carrier.Protocol`, `Ordering.Protocol`,
/// `Equation.Protocol`, etc. — naming rules that target rename-bridge
/// or extraction-from-body must skip this exact name.
internal func namingIsProtocolSentinelName(_ name: Swift.String) -> Swift.Bool {
    return name == "Protocol" || name == "`Protocol`"
}

private func namingInheritanceLeafNames(_ clause: InheritanceClauseSyntax?) -> [Swift.String] {
    guard let clause else { return [] }
    var names: [Swift.String] = []
    for inherited in clause.inheritedTypes {
        let type = inherited.type
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            names.append(identifier.name.text)
        } else if let member = type.as(MemberTypeSyntax.self) {
            names.append(member.name.text)
        }
    }
    return names
}

/// Returns true if `modifiers` includes a `fileprivate` or `private`
/// access-level modifier. Direct check of the declaration's own
/// modifier list — does not walk up the parent chain. Use
/// `namingHasFileprivateOrPrivateEffectiveVisibility(_:)` when the
/// caller needs effective visibility (which considers enclosing-type
/// access).
internal func namingHasFileprivateOrPrivateModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
    for modifier in modifiers {
        let kind = modifier.name.tokenKind
        if kind == .keyword(.fileprivate) || kind == .keyword(.private) {
            return true
        }
    }
    return false
}

/// Returns true if `node`'s *effective* visibility is `fileprivate`
/// or `private` — either because the declaration itself carries the
/// modifier, or because an enclosing type declaration (struct, class,
/// enum, actor) carries it. Used by naming rules that exempt
/// non-consumer-observable surface (decls invisible across the file
/// boundary) per the [API-NAME-002] visibility-scope amendment.
///
/// Swift access semantics: a member's effective access is the
/// minimum of its declared access and the enclosing type's access.
/// A `let` field without modifiers inside a `fileprivate struct`
/// is effectively `fileprivate`, even though `node.modifiers` is
/// empty. Walking up the parent chain captures that case.
///
/// Walk-up stops at the first enclosing type / extension boundary
/// that carries a `fileprivate` or `private` modifier. If none is
/// found before the file root, returns the direct-modifier result
/// on `node`.
internal func namingHasFileprivateOrPrivateEffectiveVisibility(
    _ node: Syntax,
    modifiers: DeclModifierListSyntax
) -> Bool {
    if namingHasFileprivateOrPrivateModifier(modifiers) {
        return true
    }
    var current: Syntax? = node.parent
    while let candidate = current {
        if let typeDecl = candidate.as(StructDeclSyntax.self) {
            if namingHasFileprivateOrPrivateModifier(typeDecl.modifiers) { return true }
        } else if let typeDecl = candidate.as(ClassDeclSyntax.self) {
            if namingHasFileprivateOrPrivateModifier(typeDecl.modifiers) { return true }
        } else if let typeDecl = candidate.as(EnumDeclSyntax.self) {
            if namingHasFileprivateOrPrivateModifier(typeDecl.modifiers) { return true }
        } else if let typeDecl = candidate.as(ActorDeclSyntax.self) {
            if namingHasFileprivateOrPrivateModifier(typeDecl.modifiers) { return true }
        } else if let ext = candidate.as(ExtensionDeclSyntax.self) {
            if namingHasFileprivateOrPrivateModifier(ext.modifiers) { return true }
        }
        current = candidate.parent
    }
    return false
}
