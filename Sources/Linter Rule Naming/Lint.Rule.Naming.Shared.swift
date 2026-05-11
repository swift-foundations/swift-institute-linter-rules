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

/// Returns true if any enclosing type declaration of `node` carries the
/// `@resultBuilder` attribute. Walks up the `parent` chain and stops at
/// the first `struct` / `class` / `enum` / `actor` declaration — those
/// are the only decl kinds Swift permits `@resultBuilder` on. Nested
/// extensions are crossed without consuming the search (a method inside
/// `extension Builder` inside an outer `@resultBuilder enum Builder`
/// still finds the attribute on the enum).
internal func namingIsInsideResultBuilderType(_ node: Syntax) -> Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
        if let typeDecl = candidate.as(StructDeclSyntax.self) {
            return namingHasResultBuilderAttribute(typeDecl.attributes)
        }
        if let typeDecl = candidate.as(EnumDeclSyntax.self) {
            return namingHasResultBuilderAttribute(typeDecl.attributes)
        }
        if let typeDecl = candidate.as(ClassDeclSyntax.self) {
            return namingHasResultBuilderAttribute(typeDecl.attributes)
        }
        if let typeDecl = candidate.as(ActorDeclSyntax.self) {
            return namingHasResultBuilderAttribute(typeDecl.attributes)
        }
        current = candidate.parent
    }
    return false
}

internal func namingHasResultBuilderAttribute(_ attributes: AttributeListSyntax) -> Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "resultBuilder" {
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
