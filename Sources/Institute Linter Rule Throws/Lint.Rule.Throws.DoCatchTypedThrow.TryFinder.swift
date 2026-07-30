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

internal final class ThrowsDoCatchTypedThrowTryFinder: SyntaxVisitor {
  var found = false
  override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
    guard node.questionOrExclamationMark == nil else {
      return .visitChildren
    }
    found = true
    return .skipChildren
  }
  override func visit(_: DoStmtSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
  override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
}
