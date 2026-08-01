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

internal import Linter_Primitives
internal import SwiftSyntax

/// The canonical fix for `[IMPL-033]`: climb the range loop to
/// `(<range>).forEach { <name> in … }`.
///
/// The fix is narrower than the finding, deliberately and permanently. A
/// `for` body is a statement context and a `forEach` body is a closure, and
/// the two differ in every construct that transfers control out of the
/// loop: `break` and `continue` have no closure spelling at all, `return`
/// returns from the closure rather than the enclosing function — silently,
/// and with the opposite meaning — and `try`, `throw`, and `await` cross a
/// `rethrows`, non-`async` boundary that erases or rejects them.
///
/// A loop containing any of those is therefore NOT autofixable, and this
/// leaves it exactly as it found it. It remains a finding, for a person to
/// resolve by restructuring rather than by translation. That is the whole
/// discipline of a rewriter-backed rule: the rewriter takes the subset it
/// can transform with certainty, and hands back the rest unchanged rather
/// than guessing. A fix that translated `return` into a `forEach` body
/// would compile and silently change what the program does, which is the
/// one outcome worse than not fixing it.
///
/// The scan is subtree-wide and does not stop at nested closures or nested
/// function declarations, where those constructs would be harmless. That
/// over-refuses, and it should: the cost of refusing a fixable loop is that
/// a person fixes it, and the cost of accepting an unfixable one is a
/// behaviour change nobody reviewed.
internal func idiomIterationIntentFixed(
  _ source: borrowing Lint.Source.Parsed
) -> Swift.String? {
  let rewriter = IdiomIterationIntentRewriter()
  let rewritten = rewriter.visit(source.tree)
  guard rewriter.changed else { return nil }
  return rewritten.description
}

/// Whether `loop` may be translated to `forEach` without changing meaning.
///
/// Mirrors the detector's own guards first — the fix must never fire where
/// the finding does not — and then applies the closure-boundary
/// restrictions the detector has no reason to know about.
internal func idiomIterationIntentIsFixable(_ loop: ForStmtSyntax) -> Swift.Bool {
  guard loop.pattern.is(IdentifierPatternSyntax.self) else { return false }
  guard idiomIsRangeExpression(loop.sequence) else { return false }
  guard !idiomLoopPreservesTypedThrows(loop) else { return false }
  // A `where` clause is a filter, and a type annotation is an explicit
  // parameter type. Both are expressible in a closure, and neither is
  // expressible without deciding how — so neither is translated here.
  guard loop.whereClause == nil, loop.typeAnnotation == nil else { return false }
  // A labelled loop's label can only be the target of a `break`/`continue`
  // that names it, and neither survives the translation.
  guard loop.parent?.as(LabeledStmtSyntax.self) == nil else { return false }
  return !idiomIterationIntentBodyEscapes(Syntax(loop.body))
}

/// Whether `node`'s subtree holds any construct whose meaning differs
/// inside a closure.
private func idiomIterationIntentBodyEscapes(_ node: Syntax) -> Swift.Bool {
  if node.is(BreakStmtSyntax.self) { return true }
  if node.is(ContinueStmtSyntax.self) { return true }
  if node.is(ReturnStmtSyntax.self) { return true }
  if node.is(ThrowStmtSyntax.self) { return true }
  if node.is(TryExprSyntax.self) { return true }
  if node.is(AwaitExprSyntax.self) { return true }
  // A `yield` in an accessor, likewise: it belongs to the accessor, not to
  // whatever closure it is nested in.
  if node.is(YieldStmtSyntax.self) { return true }
  for child in node.children(viewMode: .sourceAccurate) {
    if idiomIterationIntentBodyEscapes(child) { return true }
  }
  return false
}

/// Builds `(<sequence>).forEach { <name> in <body> }` for a fixable loop.
internal func idiomIterationIntentCall(for loop: ForStmtSyntax) -> ExprSyntax? {
  guard let pattern = loop.pattern.as(IdentifierPatternSyntax.self) else { return nil }

  // A bare range is parenthesized so `.forEach` binds to the range rather
  // than to its upper bound. A sequence that is already a call —
  // `(a..<b).reversed()` — needs no second pair, and adding one would make
  // every fixed line noisier than the rule that asked for it.
  let receiver: ExprSyntax
  let bare = loop.sequence.with(\.leadingTrivia, []).with(\.trailingTrivia, [])
  if bare.is(SequenceExprSyntax.self) || bare.is(InfixOperatorExprSyntax.self) {
    receiver = ExprSyntax(
      TupleExprSyntax(
        elements: LabeledExprListSyntax([LabeledExprSyntax(expression: bare)])
      )
    )
  } else {
    receiver = bare
  }

  // The whitespace between the loop's `{` and its first statement is
  // attached to whichever token owns it: everything up to the end of the
  // line is the brace's TRAILING trivia, and the rest is the statement's
  // leading trivia. So a single-line body `{ sum += i }` keeps its only
  // space on the brace, and moving the statements alone would emit
  // `{ i insum += i }`. The `in` keyword inherits that trivia, and
  // supplies a space itself only when neither side has any — the
  // multi-line case must NOT gain one, or every fixed loop would carry a
  // trailing space before its newline.
  let braceTrailing = loop.body.leftBrace.trailingTrivia
  let firstLeading = loop.body.statements.first?.leadingTrivia ?? []
  let inTrailing: Trivia =
    braceTrailing.isEmpty && firstLeading.isEmpty ? .space : braceTrailing
  let closure = ClosureExprSyntax(
    leftBrace: .leftBraceToken(leadingTrivia: .space),
    signature: ClosureSignatureSyntax(
      parameterClause: .simpleInput(
        ClosureShorthandParameterListSyntax([
          ClosureShorthandParameterSyntax(
            name: pattern.identifier.with(\.leadingTrivia, .space).with(\.trailingTrivia, [])
          )
        ])
      ),
      inKeyword: .keyword(.in, leadingTrivia: .space, trailingTrivia: inTrailing)
    ),
    statements: loop.body.statements,
    rightBrace: loop.body.rightBrace.with(\.leadingTrivia, loop.body.rightBrace.leadingTrivia)
  )

  let call = FunctionCallExprSyntax(
    calledExpression: ExprSyntax(
      MemberAccessExprSyntax(base: receiver, name: .identifier("forEach"))
    ),
    leftParen: nil,
    arguments: LabeledExprListSyntax([]),
    rightParen: nil,
    trailingClosure: closure
  )
  return ExprSyntax(call)
    .with(\.leadingTrivia, loop.leadingTrivia)
    .with(\.trailingTrivia, loop.trailingTrivia)
}

/// Replaces each fixable range loop with its `forEach` spelling.
///
/// The swap happens at ``CodeBlockItemSyntax`` rather than at
/// ``ForStmtSyntax`` because the replacement is an expression where the
/// original was a statement, and only the item knows how to hold either.
internal final class IdiomIterationIntentRewriter: SyntaxRewriter {
  var changed: Swift.Bool = false

  override func visit(_ node: CodeBlockItemSyntax) -> CodeBlockItemSyntax {
    guard case .stmt(let statement) = node.item,
      let loop = statement.as(ForStmtSyntax.self),
      idiomIterationIntentIsFixable(loop),
      let call = idiomIterationIntentCall(for: loop)
    else {
      return super.visit(node)
    }
    changed = true
    // The rewritten item is re-visited so a nested fixable loop inside the
    // body climbs too, in the same pass.
    return super.visit(node.with(\.item, .expr(call)))
  }
}
