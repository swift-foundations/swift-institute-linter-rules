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

/// Foundation-free string scanning at L1 / L2 MUST default to the UTF-8
/// byte view, not `unicodeScalars`. Citation: `[IMPL-089]`.
///
/// #24 defect 7 scoping: "Foundation-free" is the rule's own stated
/// scope, and it is mechanically checkable the same way
/// `Lint.Rule.Foundation.Import` checks it — by whether the file
/// imports a Foundation-family module. A file that imports Foundation
/// (or `FoundationEssentials`/`FoundationNetworking`/`FoundationXML`)
/// is not attempting Foundation-free scanning in the first place, so
/// `.unicodeScalars` there is not the harm this rule exists to catch;
/// such files are exempt. Full receiver-type resolution (distinguishing
/// a `String`'s `.unicodeScalars` from an unrelated type's
/// same-named member) is NOT implemented — a syntax-only rule has no
/// type checker, and that limitation is unchanged by this scoping
/// pass. A false positive on a non-`String` receiver is suppressible
/// with this engine's own `// swift-linter:disable:next string utf8 scanning`
/// directive (not a SwiftLint directive — the wrong tool for this
/// engine).
extension Lint.Rule {
  public static let `string utf8 scanning` = Lint.Rule(
    id: "string utf8 scanning",
    default: .warning,
    findings: { source, severity in
      guard !idiomFileImportsFoundation(source.tree) else {
        return []
      }
      let visitor = IdiomStringUTF8ScanningVisitor(
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
internal let idiomStringUTF8ScanningMessage: Swift.String =
  "[string utf8 scanning] [IMPL-089]: `.unicodeScalars` access is "
  + "the wrong code-unit view for Foundation-free string scanning. "
  + "Use `.utf8` — byte-literal matching is O(n), no Unicode table "
  + "dependency, and the correct semantics for newline discovery, "
  + "substring search, percent decoding, path component splitting. "
  + "Suppress a confirmed non-`String` receiver with a "
  + "`// swift-linter:disable:next string utf8 scanning` and `// REASON:` "
  + "continuation."

/// The Foundation module family — mirrors
/// `Lint.Rule.Foundation.Import`'s `foundationModuleFamily`, kept as a
/// local, independent copy: this rule pack has no dependency on the
/// Foundation rule pack's module.
private let idiomFoundationModuleFamily: Swift.Set<Swift.String> = [
  "Foundation",
  "FoundationEssentials",
  "FoundationNetworking",
  "FoundationXML",
]

/// Returns true if `tree` contains a top-level `import` of a
/// Foundation-family module (a submodule import such as
/// `Foundation.NSURL` also counts — its first path component is the
/// family member).
internal func idiomFileImportsFoundation(_ tree: SourceFileSyntax) -> Swift.Bool {
  for statement in tree.statements {
    guard let importDecl = statement.item.as(ImportDeclSyntax.self) else { continue }
    let firstComponent =
      importDecl.path.trimmedDescription.split(separator: ".").first.map(Swift.String.init)
      ?? importDecl.path.trimmedDescription
    if idiomFoundationModuleFamily.contains(firstComponent) {
      return true
    }
  }
  return false
}

internal final class IdiomStringUTF8ScanningVisitor: SyntaxVisitor {
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

  override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
    guard node.declName.baseName.text == "unicodeScalars" else { return .visitChildren }
    let location = converter.location(
      for: node.declName.baseName.positionAfterSkippingLeadingTrivia
    )
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "string utf8 scanning",
        message: idiomStringUTF8ScanningMessage
      ))
    return .visitChildren
  }
}
