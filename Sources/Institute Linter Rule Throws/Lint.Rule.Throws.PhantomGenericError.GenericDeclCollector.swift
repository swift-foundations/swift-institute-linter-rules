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

/// Collects generic type declarations in ONE file, so an
/// `extension Foo.Bar { enum Error { … } }` can resolve `Bar`'s parameters when
/// `Bar` is declared in that same file. Cross-file resolution is out of reach
/// for a per-file rule; that gap is why the use-site detector exists.
internal final class ThrowsPhantomGenericDeclCollector: SyntaxVisitor {
    var generics: [Swift.String: [Swift.String]] = [:]

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.genericParameterClause)
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.genericParameterClause)
        return .visitChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.genericParameterClause)
        return .visitChildren
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.genericParameterClause)
        return .visitChildren
    }

    private func record(_ name: Swift.String, _ clause: GenericParameterClauseSyntax?) {
        let parameters = throwsPhantomGenericParameterNames(clause)
        if !parameters.isEmpty { generics[name] = parameters }
    }
}
