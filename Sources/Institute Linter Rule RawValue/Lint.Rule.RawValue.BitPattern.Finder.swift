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

internal final class RawValueBitPatternFinder: SyntaxVisitor {
    // #23 nit 4: the only consumer (`RawValue.BitPattern.swift:108`) tests
    // `finder.match != nil` — the matched node itself is never read. Replaced
    // with a plain flag, and the walk now stops once the answer is known
    // instead of continuing over the rest of the subtree.
    var found: Swift.Bool = false

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        if node.declName.baseName.text == "rawValue" {
            found = true
            return .skipChildren
        }
        return .visitChildren
    }
}
