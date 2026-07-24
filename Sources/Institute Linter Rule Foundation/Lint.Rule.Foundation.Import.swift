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

/// No package's main target imports the Foundation module family, at any of
/// the five layers. Citation: `[ARCH-LAYER-007]`; `[PRIM-FOUND-001]` is the
/// Layer-1 specialization of the same discipline.
///
/// The family is `Foundation`, `FoundationEssentials`, `FoundationNetworking`
/// and `FoundationXML`. `FoundationNetworking` matters disproportionately: it
/// is where `URLSession` lives on Linux, so omitting it leaves the rule blind
/// on precisely the axis it exists to guard.
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
  "[foundation import] [ARCH-LAYER-007]: no package's main target may import "
  + "the Foundation module family (`Foundation`, `FoundationEssentials`, "
  + "`FoundationNetworking`, `FoundationXML`) — at ANY of the five layers, not "
  + "just primitives. Use institute primitives (`Time_Primitives`, "
  + "`Binary_Primitives`, etc.) instead. Foundation-adjacent interop belongs in "
  + "a separately-declared `* Foundation Integration` subtarget that consumers "
  + "opt into, never the main target. (`[PRIM-FOUND-001]` is the Layer-1 "
  + "specialization of this rule; it is not a primitives-only rule.)"

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

/// The Foundation module family this rule flags.
///
/// `FoundationNetworking` and `FoundationXML` are the corelibs-Foundation
/// modules on Linux; importing either pulls in Foundation just as surely as
/// importing `Foundation` itself does.
private let foundationModuleFamily: Swift.Set<Swift.String> = [
  "Foundation",
  "FoundationEssentials",
  "FoundationNetworking",
  "FoundationXML",
]

/// Returns true if `pathText` names a module in the Foundation family.
/// Submodule imports (`Foundation.NSURL`) are also caught — any path whose
/// FIRST component is a family member pulls in the framework and counts as a
/// violation. Modules with a family name in a NON-leading position
/// (`HTML_Foundation`, `Server_Foundation`) are deliberately not flagged.
private func foundationImportIsFoundationModule(_ pathText: Swift.String) -> Swift.Bool {
  let firstComponent = pathText.split(separator: ".").first.map(Swift.String.init) ?? pathText
  return foundationModuleFamily.contains(firstComponent)
}
