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

/// #19 defect 3: renamed from `ThrowsClosureCatchThrowFinder` and extended to
/// see non-`throw` propagation. A catch clause that forwards the error via
/// `try fallback()` (a call that can itself throw) propagates just as much as
/// an explicit `throw` — the closure it sits in still needs the annotation.
internal final class ThrowsClosureCatchPropagationFinder: SyntaxVisitor {
  var foundPropagation = false
  override func visit(_: ThrowStmtSyntax) -> SyntaxVisitorContinueKind {
    foundPropagation = true
    return .skipChildren
  }
  override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
    if node.questionOrExclamationMark == nil {
      foundPropagation = true
    }
    return .skipChildren
  }
  override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
    // Nested closures have their own boundary.
    return .skipChildren
  }
}
