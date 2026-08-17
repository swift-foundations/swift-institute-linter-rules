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

/// Wave 3 (mechanization-program) — assignment to unsafe storage MUST
/// wrap the entire assignment expression in `unsafe (…)`; placing the
/// `unsafe` keyword on the RHS alone leaves the destination
/// unacknowledged.
///
/// Citation: `[PATTERN-005b]` / `[MEM-SAFE-002]` (platform skill, memory-
/// safety skill — expression granularity of unsafe).
extension Lint.Rule {
    public static let `unsafe assignment granularity` = Lint.Rule(
        id: "unsafe assignment granularity",
        default: .warning,
        findings: { source, severity in
            let visitor = MemoryUnsafeAssignmentGranularityVisitor(
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
internal let memoryUnsafeAssignmentGranularityMessage: Swift.String =
    "[unsafe assignment granularity] [PATTERN-005b]/[MEM-SAFE-002]: "
    + "`<lvalue> = unsafe <expr>` marks only the RHS as unsafe, and `<lvalue>` "
    + "is itself an unsafe destination (a `.pointee` store, a pointer "
    + "subscript, or an already `unsafe`-marked sub-expression) — the "
    + "assignment to `<lvalue>` is uncovered. Wrap the entire "
    + "expression: `unsafe (<lvalue> = <expr>)`. Each unsafe operation "
    + "requires its own `unsafe` acknowledgment; expression granularity."

/// Returns true when `lhs` itself contains an unsafe access — a `.pointee`
/// store, a pointer subscript, or an already `unsafe`-marked
/// sub-expression. Under SE-0458 an assignment whose destination is safe
/// storage (`count = unsafe pointer.pointee`) is already fully covered by
/// the RHS's own `unsafe` acknowledgment; only an unsafe *destination*
/// widens the region that needs covering.
private func memoryUnsafeAssignmentGranularityLHSIsUnsafeDestination(
    _ lhs: ExprSyntax
) -> Swift.Bool {
    let finder = MemoryUnsafeAssignmentLHSFinder(viewMode: .sourceAccurate)
    finder.walk(lhs)
    return finder.isUnsafeDestination
}

private final class MemoryUnsafeAssignmentLHSFinder: SyntaxVisitor {
    var isUnsafeDestination = false

    override func visit(_ node: UnsafeExprSyntax) -> SyntaxVisitorContinueKind {
        isUnsafeDestination = true
        return .skipChildren
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        if node.declName.baseName.text == "pointee" {
            isUnsafeDestination = true
            return .skipChildren
        }
        return .visitChildren
    }

    override func visit(_ node: SubscriptCallExprSyntax) -> SyntaxVisitorContinueKind {
        let baseText = node.calledExpression.trimmedDescription.lowercased()
        if baseText.contains("pointer") || baseText.contains("unsafe") {
            isUnsafeDestination = true
            return .skipChildren
        }
        return .visitChildren
    }
}

internal final class MemoryUnsafeAssignmentGranularityVisitor: SyntaxVisitor {
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

    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        let elements = Array(node.elements)
        for index in elements.indices.dropLast() where index > elements.indices.startIndex {
            guard elements[index].is(AssignmentExprSyntax.self) else { continue }
            let lhs = elements[index - 1]
            // If the destination itself is already top-level `unsafe`-wrapped
            // (`unsafe pointer.pointee = unsafe other.pointee`), its unsafe
            // access is separately acknowledged by its own `unsafe` keyword —
            // expression granularity is satisfied on both sides independently,
            // nothing is left uncovered.
            guard !lhs.is(UnsafeExprSyntax.self) else { continue }
            guard memoryUnsafeAssignmentGranularityLHSIsUnsafeDestination(lhs) else { continue }
            let rhs = elements[index + 1]
            guard rhs.is(UnsafeExprSyntax.self) else { continue }
            let location = converter.location(
                for: rhs.positionAfterSkippingLeadingTrivia
            )
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "unsafe assignment granularity",
                    message: memoryUnsafeAssignmentGranularityMessage
                )
            )
        }
        return .visitChildren
    }
}
