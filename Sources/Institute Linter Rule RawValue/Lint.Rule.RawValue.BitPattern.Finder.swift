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
  var match: MemberAccessExprSyntax? = nil

  override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
    if node.declName.baseName.text == "rawValue", match == nil {
      match = node
    }
    return .visitChildren
  }
}
