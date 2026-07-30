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

/// `for index in 0..<n` index-counted iteration is mechanism, not
/// intent. Citation: `[IMPL-033]`.
extension Lint.Rule {
  public static let `counter loop iteration` = Lint.Rule(
    id: "counter loop iteration",
    default: .warning,
    findings: { source, severity in
      let visitor = IdiomIterationIntentVisitor(
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
internal let idiomIterationIntentMessage: Swift.String =
  "[counter loop iteration] [IMPL-033]: `for <name> in <a>..<<b>` "
  + "(or `.reversed()` of the same range) is mechanism, not intent. "
  + "This fires on any identifier-pattern range iteration, not only an "
  + "unused numeric counter — `for byte in first...last` is also "
  + "mechanism, not intent, even though `byte` is a meaningful name. "
  + "Climb the iteration ladder: `items.forEach { … }` (per-element), "
  + "`items.indices.forEach { … }` (when the index is needed), or a "
  + "typed-while inside iteration infrastructure if you're authoring "
  + "the infrastructure itself."

/// Returns true for a bare `<a>..<<b>` / `<a>...<b>` range expression,
/// or that same shape wrapped in a single trailing `.reversed()` call
/// (`(<a>..<<b>).reversed()`) — the loop-direction inversion doesn't
/// change what's being iterated.
internal func idiomIsRangeExpression(_ expression: ExprSyntax) -> Swift.Bool {
  if idiomIsBareRangeExpression(expression) {
    return true
  }
  if let call = expression.as(FunctionCallExprSyntax.self),
    call.arguments.isEmpty,
    call.trailingClosure == nil,
    let member = call.calledExpression.as(MemberAccessExprSyntax.self),
    member.declName.baseName.text == "reversed"
  {
    return idiomIsBareRangeExpression(member.base?.unwrappingParens ?? ExprSyntax(call))
  }
  return false
}

private func idiomIsBareRangeExpression(_ expression: ExprSyntax) -> Swift.Bool {
  if let sequence = expression.as(SequenceExprSyntax.self) {
    for element in sequence.elements {
      if let binary = element.as(BinaryOperatorExprSyntax.self) {
        let text = binary.operator.text
        if text == "..<" || text == "..." { return true }
      }
    }
    return false
  }
  if let infix = expression.as(InfixOperatorExprSyntax.self) {
    if let binary = infix.operator.as(BinaryOperatorExprSyntax.self) {
      let text = binary.operator.text
      if text == "..<" || text == "..." { return true }
    }
  }
  return false
}

extension ExprSyntax {
  /// Strips a single layer of enclosing parentheses, if present.
  fileprivate var unwrappingParens: ExprSyntax {
    if let tuple = self.as(TupleExprSyntax.self), tuple.elements.count == 1,
      let onlyElement = tuple.elements.first, onlyElement.label == nil
    {
      return onlyElement.expression
    }
    return self
  }
}

internal final class IdiomIterationIntentVisitor: SyntaxVisitor {
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

  override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
    guard node.pattern.is(IdentifierPatternSyntax.self) else { return .visitChildren }
    guard idiomIsRangeExpression(node.sequence) else { return .visitChildren }
    let location = converter.location(for: node.forKeyword.positionAfterSkippingLeadingTrivia)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "counter loop iteration",
        message: idiomIterationIntentMessage
      ))
    return .visitChildren
  }
}
