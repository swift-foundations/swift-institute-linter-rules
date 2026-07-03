// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-primitives-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Linter_Primitives
internal import SwiftSyntax

/// Primitives packages MUST NOT import Foundation or FoundationEssentials.
/// Citation: `[PRIM-FOUND-001]`. Composes with `[ARCH-LAYER-007]`
/// (ecosystem-wide Foundation-free policy extending the primitives
/// rule to all five layers).
extension Lint.Rule {
  public static let `foundation import` = Lint.Rule(
    id: "foundation import",
    default: .warning,
    findings: { source, severity in
      let visitor = FoundationImportVisitor(
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
internal let foundationImportMessage: Swift.String =
  "[foundation import] [PRIM-FOUND-001]: primitives source MUST NOT import "
  + "Foundation or FoundationEssentials. Use institute primitives "
  + "(`Time_Primitives`, `Binary_Primitives`, etc.) instead. Foundation-adjacent "
  + "interop belongs in a separately-declared `* Foundation Integration` "
  + "subtarget per `[ARCH-LAYER-007]`, not the main target."

internal final class FoundationImportVisitor: SyntaxVisitor {
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

  override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
    let pathText = node.path.trimmedDescription
    guard foundationImportIsFoundationModule(pathText) else {
      return .visitChildren
    }
    let location = converter.location(for: node.path.positionAfterSkippingLeadingTrivia)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "foundation import",
        message: foundationImportMessage
      ))
    return .visitChildren
  }
}

/// Returns true if `pathText` is `Foundation` or `FoundationEssentials`.
/// Submodule imports (`Foundation.NSURL`) are also caught — any path
/// whose first component is `Foundation` / `FoundationEssentials`
/// pulls in the framework and counts as a violation.
private func foundationImportIsFoundationModule(_ pathText: Swift.String) -> Swift.Bool {
  let firstComponent = pathText.split(separator: ".").first.map(Swift.String.init) ?? pathText
  return firstComponent == "Foundation" || firstComponent == "FoundationEssentials"
}
