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

/// Closures inside a `throws(E)` context MUST carry an explicit
/// `throws(E)` annotation when they contain `try`. Citation: `[API-ERR-004]`.
extension Lint.Rule {
    public static let `closure typed throws annotation` = Lint.Rule(
        id: "closure typed throws annotation",
        default: .warning,
        findings: { source, severity in
            let visitor = ThrowsClosureAnnotationVisitor(
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
internal let throwsClosureAnnotationMessage: Swift.String =
    "[closure typed throws annotation] [API-ERR-004]: closure inside a "
    + "`throws(E)` context contains `try` but lacks an explicit "
    + "`throws(E)` annotation — Swift 6.2 infers `any Error` and erases "
    + "the typed throw."

internal func throwsIsTypedThrows(_ clause: ThrowsClauseSyntax?) -> Swift.Bool {
    guard let clause else { return false }
    return clause.type != nil
}

/// Returns true if `node` is the trailing closure of a `#expect(throws:)`
/// macro expansion. The macro's `throws:` argument signature carries the
/// expected error; the closure body's job is to throw — Swift Testing
/// then asserts that the body threw the expected error. The macro's
/// contract takes `any Error` by design, so annotating the closure with
/// `() throws(E) in` is semantically meaningless: the macro already knows
/// which `E` to assert against from its labeled argument.
///
/// Additionally, on Swift 6.3.2 the annotation triggers a SIL crash in
/// `LifetimeDependenceDiagnostics` when the closure body holds
/// `~Copyable` lifetime-dependent types (e.g., `Binary.Cursor`). The
/// carve-out preserves correct typed-throws coverage at the macro
/// boundary without forcing source through a compiler-blocked corner.
///
/// Citation: [API-ERR-004] (rule's primary statement);
/// [RULE-EXEMPT-4]-shaped attribute/macro carve-out.
///
/// Detection: walks one level up to `MacroExpansionExprSyntax`,
/// checks the macro name is `expect`, and verifies the argument list
/// contains a `throws:` labeled argument.
internal func throwsClosureIsInsideExpectThrows(_ node: ClosureExprSyntax) -> Swift.Bool {
    guard let parent = node.parent else { return false }
    guard let macro = parent.as(MacroExpansionExprSyntax.self) else { return false }
    guard macro.macroName.text == "expect" else { return false }
    for argument in macro.arguments {
        if argument.label?.text == "throws" {
            return true
        }
    }
    return false
}

/// Returns true if the node is inside an enclosing `DoStmtSyntax` whose
/// `catchClauses` contain at least one catch body that ends with a
/// `return` of a value (the Result-materialization shape). Stops the
/// walk at any enclosing `ClosureExprSyntax` — the closure boundary.
internal func throwsClosureTryIsInsideMaterializingDoCatch(_ node: Syntax) -> Swift.Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
        if let doStmt = candidate.as(DoStmtSyntax.self) {
            // Check whether any catch body has a return-with-value
            // (the materialization signature). Empty catchClauses or
            // catches that re-throw / propagate without returning a
            // value don't materialize — fall through to scan further.
            for catchClause in doStmt.catchClauses {
                if throwsClosureCatchReturnsValue(catchClause) {
                    return true
                }
            }
        }
        if candidate.is(ClosureExprSyntax.self) { return false }
        current = candidate.parent
    }
    return false
}

/// Returns true if the catch clause's body materializes the error
/// rather than propagating it. Materialization takes one of two
/// shapes in the [IMPL-109] pattern:
///
/// 1. Return-form: `catch { return .failure(error) }` — the catch
///    returns a Result/Optional/etc. value to the enclosing scope.
/// 2. Side-effect-form: `catch { result = .failure(error) }` — the
///    catch assigns to a captured variable; the outer scope reads
///    the variable after the closure returns.
///
/// Both shapes mean the closure itself doesn't propagate the error.
/// A catch that contains a `ThrowStmt` IS propagating and DOES need
/// the closure to be annotated. Detection: a catch is materializing
/// iff its body contains NO `ThrowStmt` at any depth (excluding
/// nested closures, which have their own boundary).
private func throwsClosureCatchReturnsValue(_ clause: CatchClauseSyntax) -> Swift.Bool {
    let finder = ThrowsClosureCatchThrowFinder(viewMode: .sourceAccurate)
    finder.walk(clause.body)
    return !finder.foundThrow
}

internal final class ThrowsClosureAnnotationVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []
    var typedThrowsDepth: Swift.Int = 0

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    private func emit(at position: AbsolutePosition) {
        let location = converter.location(for: position)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "closure typed throws annotation",
            message: throwsClosureAnnotationMessage
        ))
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if throwsIsTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
            typedThrowsDepth += 1
        }
        return .visitChildren
    }
    override func visitPost(_ node: FunctionDeclSyntax) {
        if throwsIsTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
            typedThrowsDepth -= 1
        }
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if throwsIsTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
            typedThrowsDepth += 1
        }
        return .visitChildren
    }
    override func visitPost(_ node: InitializerDeclSyntax) {
        if throwsIsTypedThrows(node.signature.effectSpecifiers?.throwsClause) {
            typedThrowsDepth -= 1
        }
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        guard typedThrowsDepth > 0 else { return .visitChildren }
        if let signature = node.signature,
           throwsIsTypedThrows(signature.effectSpecifiers?.throwsClause)
        { return .visitChildren }
        // Carve-out: `#expect(throws:)` macro expansion. The macro's
        // `throws:` argument carries the expected error; the closure
        // annotation is semantically meaningless. Additionally, the
        // annotation triggers a Swift 6.3.2 SIL crash when the body
        // holds ~Copyable lifetime-dependent types. See
        // `throwsClosureIsInsideExpectThrows` for full rationale and
        // citation.
        if throwsClosureIsInsideExpectThrows(node) {
            return .visitChildren
        }
        let finder = ThrowsClosureTryFinder(viewMode: .sourceAccurate)
        for statement in node.statements {
            finder.walk(statement)
            if finder.found { break }
        }
        guard finder.found else { return .visitChildren }
        let position: AbsolutePosition
        if let signature = node.signature {
            position = signature.positionAfterSkippingLeadingTrivia
        } else {
            position = node.leftBrace.positionAfterSkippingLeadingTrivia
        }
        emit(at: position)
        return .visitChildren
    }
}
