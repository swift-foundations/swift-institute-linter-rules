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

/// Predicates and vocabulary shared across the Platform pack's rules.
///
/// The Institute's platform-identity vocabulary. This is *the* place a new
/// platform is added — several rules in this pack previously maintained
/// their own copy of this list and drifted (#21 finding 2's Android/WASI/
/// FreeBSD/BSD gap is the recorded example).
internal let platformPlatformTokens: Swift.Set<Swift.String> = [
    "Darwin", "Linux", "Windows", "Android", "WASI", "FreeBSD", "OpenBSD",
    "NetBSD", "BSD",
]

internal func platformIsPublicAPI(_ modifiers: DeclModifierListSyntax) -> Swift.Bool {
    for modifier in modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.public), .keyword(.open):
            return true

        default:
            continue
        }
    }
    return false
}

/// Returns true if `node`'s *effective* visibility is `public`/`open`
/// — either it carries the modifier itself, or it declares no access
/// modifier and is a member of a `public`/`open extension`. In Swift,
/// a member of a `public extension` is public API without carrying
/// the keyword; every rule in this pack that is explicitly scoped to
/// public API by its own doc/message is silently defeated by moving
/// the `public` keyword to the enclosing extension. Shared between
/// `c type in public api` and `dead case per platform`.
internal func platformIsPublicAPIEffective(
    _ node: Syntax,
    modifiers: DeclModifierListSyntax
) -> Swift.Bool {
    if platformIsPublicAPI(modifiers) {
        return true
    }
    var current: Syntax? = node.parent
    while let candidate = current {
        if let ext = candidate.as(ExtensionDeclSyntax.self) {
            return platformIsPublicAPI(ext.modifiers)
        }
        current = candidate.parent
    }
    return false
}
