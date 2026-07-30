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

/// A target's dependencies must be spelled through the typed accessors
/// (`.target(name:)`, `.product(name:package:)`), never as bare strings.
///
/// SwiftPM resolves a bare string as `.byName`, which binds to whatever
/// it resolves first and silently produces a different graph than the
/// author intended. The bare-string form is the idiom in most external
/// Swift material, so it arrives with copied code.
///
/// The rule's surface is a package manifest (`Package.swift`, including
/// versioned `Package@swift-*.swift` variants and nested test
/// manifests). It fires on each string-literal element of the
/// `dependencies:` array of a target-declaring call. The canonical fix
/// names the typed accessor: `.target(name:)` for a same-package
/// target, `.product(name:package:)` for a product of a declared
/// package dependency.
///
/// Citation: `swift-institute-linter-rules#4`.
extension Lint.Rule {
  public static let `bare string dependency` = Lint.Rule(
    id: "bare string dependency",
    default: .warning,
    findings: { source, severity in
      guard manifestIsPackageManifest(source.file.filePath) else { return [] }
      let visitor = ManifestBareStringDependencyVisitor(
        source: source.file,
        severity: severity,
        converter: source.converter
      )
      visitor.walk(source.tree)
      return visitor.matches
    }
  )
}

/// Returns true when `filePath` names a SwiftPM package manifest:
/// `Package.swift` or a versioned `Package@swift-*.swift` variant.
@usableFromInline
internal func manifestIsPackageManifest(_ filePath: Swift.String) -> Swift.Bool {
  guard let filename = filePath.split(separator: "/", omittingEmptySubsequences: true).last
  else { return false }
  if filename == "Package.swift" { return true }
  return filename.hasPrefix("Package@swift-") && filename.hasSuffix(".swift")
}

@usableFromInline
internal let manifestBareStringDependencyMessage: Swift.String =
  "[bare string dependency]: a target dependency must use a typed "
  + "accessor — `.target(name:)` for a same-package target, "
  + "`.product(name:package:)` for a product — never a bare string. "
  + "SwiftPM resolves a bare string as `.byName`, which binds to "
  + "whatever it resolves first."

/// The target-declaring manifest factory members whose `dependencies:`
/// arrays the rule inspects.
private let manifestTargetFactories: Swift.Set<Swift.String> = [
  "target", "testTarget", "executableTarget", "macro", "plugin",
]

internal final class ManifestBareStringDependencyVisitor: SyntaxVisitor {
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

  override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    guard
      let member = node.calledExpression.as(MemberAccessExprSyntax.self),
      manifestTargetFactories.contains(member.declName.baseName.text)
    else {
      return .visitChildren
    }
    for argument in node.arguments where argument.label?.text == "dependencies" {
      guard let array = argument.expression.as(ArrayExprSyntax.self) else { continue }
      for element in array.elements {
        if let literal = element.expression.as(StringLiteralExprSyntax.self) {
          emit(at: literal.positionAfterSkippingLeadingTrivia)
          continue
        }
        // `.byName(name: "Owner")` is the exact harm the rule's own
        // message names ("SwiftPM resolves a bare string as
        // `.byName`, which binds to whatever it resolves first") —
        // an explicit spelling of the same resolution ambiguity a
        // bare string produces, not a safer alternative to it.
        if let call = element.expression.as(FunctionCallExprSyntax.self),
          let member = call.calledExpression.as(MemberAccessExprSyntax.self),
          member.declName.baseName.text == "byName"
        {
          emit(at: call.positionAfterSkippingLeadingTrivia)
          continue
        }
      }
    }
    return .visitChildren
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
        identifier: "bare string dependency",
        message: manifestBareStringDependencyMessage
      ))
  }
}
