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
    "[test function naming] [SWIFT-TEST-005]: `@Test` function name is "
    + "CamelCase (internal uppercase letters). CamelCase names are the "
    + "legacy XCTest pattern (`testInitCreatesEmptyBuffer`) and don't read "
    + "as documentation in test reports. "
    + "**Acceptable forms**: "
    + "(a) backticked descriptive multi-word — `\\`construction from UInt\\``, "
    + "`\\`init creates empty buffer\\`` (preferred when the test scenario "
    + "has compound subject); "
    + "(b) backticked single-word — `\\`comparison\\``, `\\`equality\\`` (used "
    + "when the test subject is itself a single concept AND backticks add "
    + "documentation framing); "
    + "(c) plain single-word identifier — `comparison`, `equality` (when "
    + "backticks add no value because the identifier is already a valid "
    + "Swift name without whitespace/special-char/keyword conflict). "
    + "Rule fires ONLY on CamelCase non-backticked names; both backticked "
    + "forms and plain non-CamelCase identifiers pass."

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
        // Backtick-escape exemption: any backticked name (multi-word or
        // single-word) passes. The author opted into backticks, which
        // signals declarative-narrative naming regardless of word count.
        //
        // Backtick-detection: `TokenSyntax.text` strips backticks from the
        // unescaped identifier; `trimmedDescription` preserves them. Same
        // technique as `Naming.isBackticked` in the institute Naming pack
        // (Lint.Rule.Naming.Shared.swift) — inlined here to avoid cross-pack
        // dependency for a 1-line check.
        if node.name.trimmedDescription.hasPrefix("`") {
            return .visitChildren
        }
        // CamelCase detection: the rule's actual anti-pattern is CamelCase
        // names (legacy XCTest pattern: `testInitCreatesEmptyBuffer`).
        // Plain single-word identifiers like `comparison` or `equality` are
        // valid Swift names that don't need backticks — backticks would add
        // no value because the identifier is already a clean descriptive
        // name without whitespace/special-char/keyword conflict. Rule fires
        // ONLY when internal uppercase letters appear (CamelCase signature).
        //
        // First character's case is ignored: Swift convention is lowercase
        // for func names but `Comparison` as a single capitalized word
        // isn't camelCase. The rule's target is COMPOUND camelCase, not
        // identifier-capitalization style.
        let name = node.name.text
        let hasInternalUppercase = name.dropFirst().contains(where: { $0.isUppercase })
        if hasInternalUppercase {
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
