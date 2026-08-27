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

public import Linter
internal import SwiftSyntax

/// `@Suite` types MUST follow the extension-pattern naming, not compound
/// names. Citation: `[SWIFT-TEST-002]`.
///
/// Relocated from `swift-linter-rules` (universal tier) to
/// `swift-institute-linter-rules` (institute tier) 2026-05-15: the rule's
/// `[SWIFT-TEST-002]` citation makes it institute-specific by construction
/// — the `extension Foo { @Suite struct Test {} }` shape is the institute's
/// test-organization convention, not a universal Swift convention.
extension Lint.Rule {
    public static let `compound suite name` = Lint.Rule(
        id: "compound suite name",
        default: .warning,
        controls: [
            .init(
                id: "compound suite name compound suite",
                source: "@Suite struct MemoryBufferTests {}",
                path: "Sources/Naming Core/CompoundSuite.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "compound suite name leaf suite",
                source: "@Suite struct Test {}",
                path: "Sources/Naming Core/LeafSuite.swift",
                expectation: .clean
            ),
            .init(
                id: "compound suite name narrative suite",
                source: "@Suite struct `Memory Buffer Tests` {}",
                path: "Sources/Naming Core/NarrativeSuite.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingCompoundSuiteVisitor(
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
internal let namingCompoundSuiteMessage: Swift.String =
    "[compound suite name] [SWIFT-TEST-002]: `@Suite` types MUST use the "
    + "extension-pattern nested name (`extension Foo { @Suite struct Test {} }`), "
    + "not a compound name like `FooTests`."

private func compoundSuiteHasSuiteAttribute(_ attributes: AttributeListSyntax) -> Swift.Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "Suite" { return true }
    }
    return false
}

private func compoundSuiteIsCompound(_ name: Swift.String) -> Swift.Bool {
    var uppercaseRuns = 0
    var prevWasLower = false
    for (offset, character) in name.enumerated() {
        if offset == 0 {
            guard character.isUppercase else { return false }
            uppercaseRuns = 1
            continue
        }
        if character.isUppercase, prevWasLower { uppercaseRuns += 1 }
        prevWasLower = character.isLowercase
    }
    return uppercaseRuns >= 2
}

internal final class NamingCompoundSuiteVisitor: SyntaxVisitor {
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

    private func checkSuite(attributes: AttributeListSyntax, name: TokenSyntax) {
        guard compoundSuiteHasSuiteAttribute(attributes) else { return }
        // Backtick-escape exemption: see `Naming.isBackticked` for the
        // full rationale. The cohort uses backticked narrative names
        // for @Suite scaffolds (`` struct `compound identifier Tests` ``,
        // `` struct `Edge Case` ``) per [SWIFT-TEST-002] / [TEST-005] —
        // those opt out of the compound-name convention this rule enforces.
        if Naming.isBackticked(name) { return }
        guard compoundSuiteIsCompound(name.text) else { return }
        let location = converter.location(for: name.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "compound suite name",
                message: namingCompoundSuiteMessage
            )
        )
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSuite(attributes: node.attributes, name: node.name)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSuite(attributes: node.attributes, name: node.name)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSuite(attributes: node.attributes, name: node.name)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        checkSuite(attributes: node.attributes, name: node.name)
        return .visitChildren
    }
}
