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

/// Multi-closure signatures MUST order closures by lifecycle:
/// setup → body → completion / teardown. Citation: `[API-IMPL-013]`.
extension Lint.Rule {
  public static let `lifecycle order` = Lint.Rule(
    id: "lifecycle order",
    default: .warning,
    findings: { source, severity in
      let visitor = ClosureLifecycleOrderVisitor(
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
internal let closureLifecycleOrderMessage: Swift.String =
  "[lifecycle order] [API-IMPL-013]: closure parameters "
  + "MUST follow lifecycle order setup → body → completion / teardown. "
  + "A closure parameter of a later tier (a setup-tier label like "
  + "`setup:`/`prepare:`; a body-tier label like `body:`/`perform:` or "
  + "the unlabelled `_`; a completion-tier label like `completion:`, "
  + "`onError:`, `cleanup:`, `teardown:`, `finalize:`) appears BEFORE a "
  + "parameter of an earlier tier — reorder so setup precedes body "
  + "precedes completion."

internal let setupTierLabels: Swift.Set<Swift.String> = [
  "setup",
  "prepare",
  "onStart",
  "before",
  "configure",
  "arrange",
]

internal let completionTierLabels: Swift.Set<Swift.String> = [
  "completion",
  "onError",
  "onComplete",
  "onCompletion",
  "onFinish",
  "finalize",
  "finally",
  "cleanup",
  "teardown",
  "close",
  "dispose",
]

internal let bodyTierLabels: Swift.Set<Swift.String> = [
  "body",
  "perform",
  "operation",
  "work",
  "action",
  "transform",
]

internal final class ClosureLifecycleOrderVisitor: SyntaxVisitor {
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

  private func emit(at position: AbsolutePosition) {
    let location = converter.location(for: position)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "lifecycle order",
        message: closureLifecycleOrderMessage
      ))
  }

  /// Walks the closure-typed parameters in declaration order, tracking
  /// every earlier-tier parameter still "pending" (not yet confirmed
  /// in-order). When a parameter of tier `t` is reached, every pending
  /// parameter of a *later* tier than `t` is now confirmed out of
  /// order — it appeared before something that must precede it — and
  /// is flagged at its own position. `other`-tier parameters carry no
  /// lifecycle signal and don't participate.
  private func checkParameters(_ parameters: FunctionParameterListSyntax) {
    var pending: [LifecycleTier: [AbsolutePosition]] = [:]
    for parameter in parameters {
      guard isClosureType(parameter.type) else { continue }
      let tier = lifecycleTier(of: parameter)
      guard tier != .other else { continue }

      for laterTier in LifecycleTier.allCases
      where laterTier != .other && laterTier.rank > tier.rank {
        guard let positions = pending[laterTier], !positions.isEmpty else { continue }
        for position in positions {
          emit(at: position)
        }
        pending[laterTier] = []
      }
      pending[tier, default: []].append(parameter.firstName.positionAfterSkippingLeadingTrivia)
    }
  }

  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    checkParameters(node.signature.parameterClause.parameters)
    return .visitChildren
  }

  override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    checkParameters(node.signature.parameterClause.parameters)
    return .visitChildren
  }
}
