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

/// `do { try ... } catch` MUST use typed-throws specifier
/// `do throws(E) { try ... } catch { }`. Citation: `[IMPL-075]`.
extension Lint.Rule {
  public static let `do throws for typed catch` = Lint.Rule(
    id: "do throws for typed catch",
    default: .warning,
    findings: { source, severity in
      let visitor = ThrowsDoCatchTypedVisitor(
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
internal let throwsDoCatchTypedMessage: Swift.String =
  "[do throws for typed catch] [IMPL-075]: bare `do { try ... } catch { }` "
  + "erases the concrete error type. Use `do throws(E) { try ... } catch { }` "
  + "to preserve `E` in the catch binding."
  + " If the callee throws UNTYPED (cross-module APIs such as "
  + "`FileManager.removeItem(at:)` or `try await task.value`) there is no `E` "
  + "to name and no construct satisfies every rule — `try?` fires [API-ERR-001] "
  + "and `do throws(any Error)` fires [API-ERR-006]. Apply "
  + "`// swift-linter:disable:next do throws for typed catch` with a `// REASON:` "
  + "naming the untyped callee. Where a typed `E` DOES exist both rules are "
  + "satisfiable together, so this rule is not softened for the typed case."

internal final class ThrowsDoCatchTypedVisitor: SyntaxVisitor {
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

  override func visit(_ node: DoStmtSyntax) -> SyntaxVisitorContinueKind {
    if node.throwsClause != nil { return .visitChildren }
    guard !node.catchClauses.isEmpty else { return .visitChildren }
    let finder = ThrowsDoCatchTryFinder(viewMode: .sourceAccurate)
    finder.walk(node.body)
    guard finder.found else { return .visitChildren }
    let location = converter.location(for: node.doKeyword.positionAfterSkippingLeadingTrivia)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "do throws for typed catch",
        message: throwsDoCatchTypedMessage
      ))
    return .visitChildren
  }
}
