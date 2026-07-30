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

internal final class ThrowsDoCatchTryFinder: SyntaxVisitor {
  var found = false
  override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
    guard node.questionOrExclamationMark == nil else {
      return .visitChildren
    }
    found = true
    return .skipChildren
  }
  override func visit(_: DoStmtSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }
  // A `try` inside a nested closure is not at the `do` body's own
  // effect scope — the closure has its own (possibly non-throwing)
  // call boundary. Without this, `do { register { try handler() };
  // throw E.x }` false-positives here AND its twin
  // (`ThrowsDoCatchTypedThrowTryFinder` in DoCatchTypedThrow.TryFinder.swift,
  // which already skips closures) correctly stays silent, producing
  // two diagnostics on the same site where the rules are meant to be
  // mutually exclusive.
  override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
}
