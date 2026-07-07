// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Linter_Primitives
internal import SwiftSyntax

/// R3 — chained `.rawValue.X` member access.
///
/// Subsumes the regex pair `chained_rawvalue_access_anti_pattern` +
/// `chained_rawvalue_access_paren_evasion`. The AST predicate is a
/// `MemberAccessExprSyntax` whose base, after peeling parenthesized
/// wrappers, is itself a `MemberAccessExprSyntax` whose member name is
/// `rawValue`.
///
/// Paren-wrap evasion `(x.rawValue).foo()` collapses into the same
/// predicate: `TupleExprSyntax` wrapping a single expression is
/// semantically transparent, so peeling it yields the same
/// `MemberAccessExprSyntax(base: x, name: rawValue)` shape.
///
/// References:
/// - `swift-institute/Research/cardinal-ordinal-vector-enforcement-design.md`
///   §"R3. `.rawValue.` chains"
/// - `swift-institute/Research/swiftsyntax-based-custom-linter-investigation.md`
///   §"Q2 — Evasion-class closure matrix" (paren-wrap row)
extension Lint.Rule {
    /// Flags chained `.rawValue.member` access, including the paren-wrapped `(x.rawValue).member` form, which escapes the typed system ([CONV-016]).
    public static let `chained rawvalue access` = Lint.Rule(
        id: "chained rawvalue access",
        default: .warning,
        findings: { source, severity in
            // §A brand-owner recognizer: same-package `.rawValue.<member>`
            // chains on the owner's brand are legitimate-by-construction.
            // Retires the per-package `.excluding(rules:)` stopgap
            // ([LINT-EXCLUDE-*]).
            if Lint.Brand.owned(Lint.Brand.numericBoundaryVocabulary, in: source) { return [] }
            let visitor = RawValueChainVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let chainedRawvalueAccessMessage: Swift.String =
    "[chained rawvalue access] [CONV-016]: chaining `.rawValue.method()` (or "
    + "paren-wrapped `(x.rawValue).method()`, which is semantically identical) escapes "
    + "the typed system. Prefer `.retag()` (Tier 1) / `.map()` (Tier 2) / `Type.min(a, b)` "
    + "/ a typed accessor exposed by the wrapper, per [INFRA-103]. If the wrapper IS "
    + "what this site implements (typed-system bottom-out), escalate to supervisor and "
    + "apply `// swiftlint:disable:next chained_rawvalue_access  // reason: <citation>`."

internal final class RawValueChainVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        guard let base = node.base else { return .visitChildren }
        let unwrapped = Self.peelParens(base)
        guard let baseAccess = unwrapped.as(MemberAccessExprSyntax.self),
            baseAccess.declName.baseName.text == "rawValue"
        else { return .visitChildren }
        let token = node.declName.baseName
        let location = converter.location(for: token.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "chained rawvalue access",
                message: chainedRawvalueAccessMessage
            )
        )
        return .visitChildren
    }

    private static func peelParens(_ expr: ExprSyntax) -> ExprSyntax {
        var current = expr
        while let tuple = current.as(TupleExprSyntax.self),
            tuple.elements.count == 1,
            let only = tuple.elements.first?.expression,
            tuple.elements.first?.label == nil
        {
            current = only
        }
        return current
    }
}
