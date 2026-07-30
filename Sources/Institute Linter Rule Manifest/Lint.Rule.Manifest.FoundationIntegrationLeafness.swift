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

/// A target whose name ends in `Foundation Integration` MUST be a
/// leaf: declared as a `.library` product of its own, and depended on
/// by no other target.
///
/// The architecture doctrine's Foundation-freedom exception has three
/// conditions: the target must (a) be named `* Foundation
/// Integration`, (b) be a leaf product of its own, and (c) have no
/// core target depend on it directly or transitively. The companion
/// Tier 2 SwiftLint carve-out (`swift-primitives/.github@498f76a`)
/// checks only (a) — a source-path regex exclusion has no view of
/// `Package.swift`'s target graph, so it cannot see (b) or (c). This
/// rule mechanizes what the manifest CAN prove: (b) directly (is
/// there a dedicated `.library` product?), and one edge of (c) (does
/// any OTHER target list it in `dependencies:`?) — the manifest states
/// direct edges; a fully transitive closure would additionally need
/// this package's dependencies' own manifests, out of scope for a
/// single-file rule.
///
/// Reference sanctioned shape:
/// `swift-primitives/swift-structured-queries-primitives`'s
/// `Structured Queries Primitives Foundation Integration` — declared
/// as its own `.library` product, and appears in no other target's
/// `dependencies:` array (it may depend outward on the core target;
/// only INCOMING edges are checked).
///
/// Citation: `swift-primitives/swift-structured-queries-primitives#2`
/// (coordinator ruling, 2026-07-30) — companion to the Tier 2
/// amendment; filed as `swift-institute-linter-rules#31`.
///
/// ADVISORY at introduction, per the standing graduation discipline
/// (issue #11) — promote to `.error` only after fleet validation.
extension Lint.Rule {
  /// Flags a `* Foundation Integration` target that is not its own leaf `.library` product, or that another target depends on ([swift-structured-queries-primitives#2]).
  public static let `foundation integration leaf target` = Lint.Rule(
    id: "foundation integration leaf target",
    default: .warning,
    findings: { source, severity in
      guard manifestIsPackageManifest(source.file.filePath) else { return [] }
      let visitor = ManifestFoundationIntegrationLeafnessVisitor(
        source: source.file,
        severity: severity,
        converter: source.converter
      )
      visitor.walk(source.tree)
      return visitor.resolvedMatches()
    }
  )
}

private let manifestFoundationIntegrationLeafnessMessage: Swift.String =
  "[foundation integration leaf target]: a target named `* Foundation "
  + "Integration` must be a LEAF — declared as a `.library` product of "
  + "its own, and depended on by no other target. A name-based "
  + "exclusion (the Tier 2 SwiftLint carve-out) grants the "
  + "Foundation-freedom exception on the name alone and cannot see "
  + "this. Either declare a dedicated `.library` product exposing only "
  + "this target, or remove it from whichever other target's "
  + "`dependencies:` still lists it (per "
  + "swift-structured-queries-primitives#2)."

/// The target-declaring manifest factory members this rule inspects
/// for both the FI-suffixed target's own declaration and every other
/// target's `dependencies:` array.
private let manifestFoundationIntegrationTargetFactories: Swift.Set<Swift.String> = [
  "target", "testTarget", "executableTarget", "macro", "plugin",
]

private let manifestFoundationIntegrationSuffix = " Foundation Integration"

internal final class ManifestFoundationIntegrationLeafnessVisitor: SyntaxVisitor {
  let source: Source.File
  let severity: Diagnostic.Severity
  let converter: SourceLocationConverter
  private var matches: [Diagnostic.Record] = []

  private struct FoundationIntegrationTarget {
    let name: Swift.String
    let position: AbsolutePosition
  }
  private var foundationIntegrationTargets: [FoundationIntegrationTarget] = []

  /// Depender target name -> set of local target/product names it
  /// references in its own `dependencies:` array (bare string,
  /// `.target(name:)`, or `.byName(name:)` spellings only — a
  /// `.product(name:package:)` reference names an EXTERNAL package's
  /// product and can never alias a local target name).
  private var dependencyEdgesByDepender: [Swift.String: Swift.Set<Swift.String>] = [:]

  /// Each `.library(name:targets:)` product's `targets:` array,
  /// verbatim (order and duplicates preserved) — used to test for an
  /// exact single-element match.
  private var libraryProductTargetLists: [[Swift.String]] = []

  init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
    self.source = source
    self.severity = severity
    self.converter = converter
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else {
      return .visitChildren
    }
    let calleeName = member.declName.baseName.text
    if calleeName == "library" {
      recordLibraryProduct(node)
    } else if manifestFoundationIntegrationTargetFactories.contains(calleeName) {
      recordTargetDecl(node)
    }
    return .visitChildren
  }

  private func recordLibraryProduct(_ node: FunctionCallExprSyntax) {
    for argument in node.arguments where argument.label?.text == "targets" {
      guard let array = argument.expression.as(ArrayExprSyntax.self) else { continue }
      var names: [Swift.String] = []
      for element in array.elements {
        guard let literal = element.expression.as(StringLiteralExprSyntax.self),
          let text = manifestFoundationIntegrationStringLiteralText(literal)
        else { continue }
        names.append(text)
      }
      libraryProductTargetLists.append(names)
    }
  }

  private func recordTargetDecl(_ node: FunctionCallExprSyntax) {
    guard
      let nameArgument = node.arguments.first(where: { $0.label?.text == "name" }),
      let nameLiteral = nameArgument.expression.as(StringLiteralExprSyntax.self),
      let name = manifestFoundationIntegrationStringLiteralText(nameLiteral)
    else { return }

    if name.hasSuffix(manifestFoundationIntegrationSuffix) {
      foundationIntegrationTargets.append(
        FoundationIntegrationTarget(
          name: name,
          position: nameLiteral.positionAfterSkippingLeadingTrivia
        ))
    }

    var referenced: Swift.Set<Swift.String> = []
    for argument in node.arguments where argument.label?.text == "dependencies" {
      guard let array = argument.expression.as(ArrayExprSyntax.self) else { continue }
      for element in array.elements {
        if let literal = element.expression.as(StringLiteralExprSyntax.self),
          let text = manifestFoundationIntegrationStringLiteralText(literal)
        {
          referenced.insert(text)
          continue
        }
        if let call = element.expression.as(FunctionCallExprSyntax.self),
          let callMember = call.calledExpression.as(MemberAccessExprSyntax.self),
          callMember.declName.baseName.text == "target" || callMember.declName.baseName.text
            == "byName",
          let innerNameArgument =
            call.arguments.first(where: { $0.label?.text == "name" || $0.label == nil }),
          let innerLiteral = innerNameArgument.expression.as(StringLiteralExprSyntax.self),
          let innerText = manifestFoundationIntegrationStringLiteralText(innerLiteral)
        {
          referenced.insert(innerText)
          continue
        }
      }
    }
    dependencyEdgesByDepender[name, default: []].formUnion(referenced)
  }

  /// Cross-references collected FI-suffixed targets against the
  /// (possibly later-in-file) product/dependency data.
  internal func resolvedMatches() -> [Diagnostic.Record] {
    for target in foundationIntegrationTargets {
      let isLeafProduct = libraryProductTargetLists.contains { $0 == [target.name] }
      let hasIncomingEdge = dependencyEdgesByDepender.contains { depender, referenced in
        depender != target.name && referenced.contains(target.name)
      }
      guard !isLeafProduct || hasIncomingEdge else { continue }
      let location = converter.location(for: target.position)
      matches.append(
        Diagnostic.Record(
          location: Source.Location(
            fileID: source.fileID,
            filePath: source.filePath,
            line: location.line,
            column: location.column
          ),
          severity: severity,
          identifier: "foundation integration leaf target",
          message: manifestFoundationIntegrationLeafnessMessage
        ))
    }
    return matches
  }
}

/// Returns a string literal's plain text when it is a simple
/// single-segment literal with no interpolation — the only shape a
/// manifest's target/product names are ever written as.
private func manifestFoundationIntegrationStringLiteralText(_ literal: StringLiteralExprSyntax)
  -> Swift.String?
{
  guard literal.segments.count == 1,
    let segment = literal.segments.first,
    let stringSegment = segment.as(StringSegmentSyntax.self)
  else { return nil }
  return stringSegment.content.text
}
