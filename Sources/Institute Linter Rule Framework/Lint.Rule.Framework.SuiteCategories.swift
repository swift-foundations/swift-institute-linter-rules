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

/// Top-level `@Suite struct X` declarations MUST contain all four
/// canonical sub-suites as nested `@Suite struct` members:
/// `Unit`, `` `Edge Case` ``, `Integration`, `Performance`.
/// Citation: `[TEST-005]`. Extension-form files (`extension Y.Test.Z`)
/// are out of scope — they extend an existing Test namespace declared
/// elsewhere; per-file checking only applies to files declaring a
/// top-level `@Suite struct`.
extension Lint.Rule {
    public static let `suite categories` = Lint.Rule(
        id: "suite categories",
        default: .warning,
        findings: { source, severity in
            let visitor = FrameworkSuiteCategoriesVisitor(
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
internal let frameworkSuiteCategoriesMessage: Swift.String =
    "[suite categories] [TEST-005]: top-level `@Suite struct` MUST contain "
    + "all four canonical sub-suites declared via nested "
    + "`@Suite struct (Unit | \\`Edge Case\\` | Integration | Performance)`. "
    + "Fixed categories enable cross-package grep-ability per `[TEST-005]`."

internal final class FrameworkSuiteCategoriesVisitor: SyntaxVisitor {
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

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        guard suiteCategoriesHasSuiteAttribute(node.attributes) else {
            return .visitChildren
        }
        guard suiteCategoriesIsTopLevel(Syntax(node)) else {
            return .visitChildren
        }
        let missing = suiteCategoriesMissingFromBody(node.memberBlock)
        if !missing.isEmpty {
            emit(at: node.name.positionAfterSkippingLeadingTrivia, missing: missing)
        }
        return .visitChildren
    }

    private func emit(at position: AbsolutePosition, missing: [Swift.String]) {
        let location = converter.location(for: position)
        let missingList = missing.joined(separator: ", ")
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "suite categories",
            message: frameworkSuiteCategoriesMessage + " Missing: \(missingList)."
        ))
    }
}

/// Returns true if `attrs` contains a `@Suite` attribute (with or without
/// trait arguments).
internal func suiteCategoriesHasSuiteAttribute(_ attrs: AttributeListSyntax) -> Swift.Bool {
    for attr in attrs {
        guard case .attribute(let a) = attr else { continue }
        if a.attributeName.trimmedDescription == "Suite" {
            return true
        }
    }
    return false
}

/// Returns true if `node` is declared at source-file scope (its ancestor
/// chain contains no struct/class/enum/actor/extension).
internal func suiteCategoriesIsTopLevel(_ node: Syntax) -> Swift.Bool {
    var current = node.parent
    while let parent = current {
        if parent.is(StructDeclSyntax.self)
            || parent.is(EnumDeclSyntax.self)
            || parent.is(ClassDeclSyntax.self)
            || parent.is(ActorDeclSyntax.self)
            || parent.is(ExtensionDeclSyntax.self) {
            return false
        }
        current = parent.parent
    }
    return true
}

private let suiteCategoriesCanonical: [Swift.String] = [
    "Unit", "`Edge Case`", "Integration", "Performance",
]

/// Returns the list of canonical category names that are NOT declared as
/// nested `@Suite struct` members within `memberBlock`. Names are
/// returned in canonical order.
internal func suiteCategoriesMissingFromBody(_ memberBlock: MemberBlockSyntax) -> [Swift.String] {
    var declared = Set<Swift.String>()
    for member in memberBlock.members {
        guard let structDecl = member.decl.as(StructDeclSyntax.self) else { continue }
        guard suiteCategoriesHasSuiteAttribute(structDecl.attributes) else { continue }
        let raw = structDecl.name.text
        // Backticked identifiers carry the backticks in `.text`; normalize.
        let stripped: Swift.String
        if raw.hasPrefix("`") && raw.hasSuffix("`") && raw.count >= 2 {
            stripped = Swift.String(raw.dropFirst().dropLast())
        } else {
            stripped = raw
        }
        switch stripped {
        case "Unit": declared.insert("Unit")
        case "Edge Case": declared.insert("`Edge Case`")
        case "Integration": declared.insert("Integration")
        case "Performance": declared.insert("Performance")
        default: continue
        }
    }
    return suiteCategoriesCanonical.filter { !declared.contains($0) }
}
