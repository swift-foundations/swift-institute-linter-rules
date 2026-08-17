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

/// Predicates shared across the Memory pack's rules.

/// Walks `trivia` backwards from its end and returns `true` if a
/// contiguous, adjacent comment block contains a line comment whose body
/// satisfies `isWanted` — e.g. a `// SAFETY:` / `// WHY:` prefix. Consumed
/// by `nonisolated unsafe without invariant`, `pointer advanced by`, and
/// `safe attribute undocumented`, whose three independent copies of this
/// walk had already diverged into two shipped bugs before consolidation
/// (a CRLF-counting miscount, and a whitespace-only "blank" line that
/// broke adjacency when it should not have).
///
/// Semantics:
///   - Newline-like pieces (`.newlines`, `.carriageReturns`,
///     `.carriageReturnLineFeeds`) accumulate a run count ACROSS pieces —
///     intervening whitespace pieces do not reset the run. A run of 2 or
///     more breaks adjacency and the walk returns `false`.
///   - A `.lineComment` resets the run to zero. If its body satisfies
///     `isWanted`, the walk succeeds immediately. Otherwise the walk
///     continues past it (a non-matching line comment does not break
///     adjacency — the institute idiom mixes invariant disclosure with
///     metadata comments such as `// TRACKING:`).
///   - A `.docLineComment` / `.docBlockComment` / `.blockComment` is
///     content, not a break: the walk resets the run and continues. A
///     `/// doc` comment sitting between a `// SAFETY:` line and the
///     declaration does not separate them.
internal func memoryTriviaHasAdjacentComment(
    _ trivia: Trivia,
    matching isWanted: (Swift.String) -> Swift.Bool
) -> Swift.Bool {
    var newlineRun = 0
    for piece in Swift.Array(trivia).reversed() {
        switch piece {
        case .newlines(let count), .carriageReturns(let count), .carriageReturnLineFeeds(let count):
            newlineRun += count
            if newlineRun >= 2 { return false }

        case .lineComment(let text):
            newlineRun = 0
            let trimmed = text.trimmingPrefix("//")
            let body = trimmed.drop(while: { $0 == " " || $0 == "\t" })
            if isWanted(Swift.String(body)) {
                return true
            }
            continue

        case .docLineComment, .docBlockComment, .blockComment:
            newlineRun = 0
            continue

        case .spaces, .tabs:
            continue

        default:
            continue
        }
    }
    return false
}

/// Returns true if `clause` carries an explicit positive `Copyable`
/// conformance requirement on any generic parameter. The author has
/// deliberately scoped the surface to copyable element types — rules
/// that fire on absence of `~Copyable`-related signals MUST treat this
/// as an authoritative opt-in, not silent shrinkage.
///
/// Citation: [RULE-EXEMPT-1] (positive-Copyable) in
/// the rule-exemptions skill.
///
/// Matches both:
///   - Standalone form: `where Base: Copyable`
///   - Composition form: `where Element: Comparison.Protocol & Copyable`
///
/// Tilde-prefixed `~Copyable` is excluded — only the *positive* form
/// trips this predicate. The `Swift.Copyable` qualified form is
/// recognized when the base identifier is the bare token `Swift`.
internal func memoryWhereClauseHasPositiveCopyable(
    _ clause: GenericWhereClauseSyntax?
)
    -> Swift.Bool
{
    guard let clause else { return false }
    for requirement in clause.requirements {
        guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) else {
            continue
        }
        if memoryTypeMentionsPositiveCopyable(conformance.rightType) {
            return true
        }
    }
    return false
}

/// Structural analogue of ``memoryWhereClauseHasPositiveCopyable(_:)``
/// for the SUPPRESSED (`~Copyable`) form (#25 defect 7): a `where`
/// clause requirement is a `ConformanceRequirementSyntax` whose
/// `rightType` is a `SuppressedTypeSyntax` naming `Copyable` — directly
/// or inside a `CompositionTypeSyntax` — rather than a textual
/// `.contains("~Copyable")` check on the requirement's description,
/// which matches inside an unrelated comment or string.
internal func memoryWhereClauseHasNoncopyable(
    _ clause: GenericWhereClauseSyntax?
)
    -> Swift.Bool
{
    guard let clause else { return false }
    for requirement in clause.requirements {
        guard let conformance = requirement.requirement.as(ConformanceRequirementSyntax.self) else {
            continue
        }
        if memoryTypeMentionsSuppressedCopyable(conformance.rightType) {
            return true
        }
    }
    return false
}

private func memoryTypeMentionsSuppressedCopyable(_ type: TypeSyntax) -> Swift.Bool {
    if let suppressed = type.as(SuppressedTypeSyntax.self) {
        // `memoryTypeMentionsPositiveCopyable` already recognizes both the
        // bare `Copyable` and qualified `Swift.Copyable` spellings of the
        // *name* — reuse it on the suppressed type's inner type.
        return memoryTypeMentionsPositiveCopyable(suppressed.type)
    }
    if let composition = type.as(CompositionTypeSyntax.self) {
        for element in composition.elements {
            if memoryTypeMentionsSuppressedCopyable(element.type) {
                return true
            }
        }
    }
    return false
}

/// Walks a type syntax for any positive `Copyable` mention. Composition
/// types (`Element: Comparison.Protocol & Copyable`) are descended into
/// so the constraint is recognized regardless of how the author wrote it.
///
/// Internal helper — call `memoryWhereClauseHasPositiveCopyable(_:)`
/// from rule visitors.
internal func memoryTypeMentionsPositiveCopyable(_ type: TypeSyntax) -> Swift.Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self),
        identifier.name.text == "Copyable"
    {
        return true
    }
    if let member = type.as(MemberTypeSyntax.self),
        member.name.text == "Copyable",
        let base = member.baseType.as(IdentifierTypeSyntax.self),
        base.name.text == "Swift"
    {
        return true
    }
    if let composition = type.as(CompositionTypeSyntax.self) {
        for element in composition.elements {
            if memoryTypeMentionsPositiveCopyable(element.type) {
                return true
            }
        }
    }
    return false
}
