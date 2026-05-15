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

/// `@Test` functions MUST use backticked descriptive names, not camelCase
/// identifiers. Citation: `[SWIFT-TEST-005]`.
extension Lint.Rule {
    public static let `test function naming` = Lint.Rule(
        id: "test function naming",
        default: .warning,
        findings: { source, severity in
            let visitor = TestingFunctionNamingVisitor(
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
internal let testingFunctionNamingMessage: Swift.String =
    "[test function naming] [SWIFT-TEST-005]: `@Test` functions MUST use a "
    + "backticked name — either a multi-word descriptive sentence "
    + "(`\\`construction from UInt\\``) or a single-word backticked term "
    + "(`\\`comparison\\``). CamelCase names without backticks are the "
    + "legacy XCTest pattern and don't read as documentation in test reports. "
    + "Multi-word descriptive names are preferred when the test's scenario "
    + "is non-trivial; single-word backticked names are acceptable when the "
    + "test's subject is itself a single concept (`comparison`, `equality`)."

private func functionNamingHasTestAttribute(_ attributes: AttributeListSyntax) -> Swift.Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "Test" { return true }
    }
    return false
}

internal final class TestingFunctionNamingVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard functionNamingHasTestAttribute(node.attributes) else { return .visitChildren }
        // Backtick-escape exemption: `\`comparison\``, `\`equality\``, etc. —
        // single-word backticked names satisfy the rule's intent (descriptive,
        // not CamelCase). The author opted into the backtick form, which signals
        // declarative-narrative naming even when the test's subject is a single
        // concept. The predicate `name.contains(" ")` alone would force authors
        // to invent multi-word names for single-concept tests (e.g., `comparison
        // operators` instead of `comparison`), which hurts readability without
        // semantic gain.
        //
        // Backtick-detection: `TokenSyntax.text` strips backticks from the
        // unescaped identifier; `trimmedDescription` preserves them. Same
        // technique as `Naming.isBackticked` in the institute Naming pack
        // (Lint.Rule.Naming.Shared.swift) — inlined here to avoid cross-pack
        // dependency for a 1-line check.
        if node.name.trimmedDescription.hasPrefix("`") {
            return .visitChildren
        }
        let name = node.name.text
        if !name.contains(" ") {
            let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
            matches.append(Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "test function naming",
                message: testingFunctionNamingMessage
            ))
        }
        return .visitChildren
    }
}
