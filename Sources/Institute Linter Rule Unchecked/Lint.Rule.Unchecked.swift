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

/// R5 — `__unchecked:` argument label appearing at a call site.
///
/// Distinguishes call-site uses (anti-pattern per [CONV-016] tier 5) from
/// declaration-site uses (legitimate extension-init machinery per [CONV-001]).
/// The distinction is structural: call-site arguments parse as
/// `LabeledExprSyntax` (a `LabeledExprSyntax.label` token whose text equals
/// `__unchecked`); declaration-site parameters parse as
/// `FunctionParameterSyntax` (a `FunctionParameterSyntax.firstName` token).
/// This rule visits only the former.
///
/// References:
/// - the cardinal/ordinal/vector enforcement design note
///   §"R5. `__unchecked:` use at call sites" — the original DEFER rationale.
/// - the SwiftSyntax-based custom-linter investigation note
///   §"Q3 — Deferred AST-rule unblocking matrix" — R5 is unblocked by this tool.
///
/// Whole-run self-suppression: when the run's own sources declare a
/// `Lint.Brand.numericBoundaryVocabulary` type at namespace root, the run
/// owns the brand and `__unchecked:` is the owner's own boundary
/// ([CONV-001]) — the rule returns no findings for the whole run. Retires
/// the per-package `.excluding(rules:)` stopgap.
extension Lint.Rule {
  public static let `unchecked call site` = Lint.Rule(
    id: "unchecked call site",
    default: .warning,
    findings: { source, severity in
      // §A brand-owner recognizer: `Brand(__unchecked:)` is the canonical
      // typed-system bottom-out for a brand owner's own domain-validated
      // construction ([CONV-001] same-package use). Retires the per-package
      // `.excluding(rules:)` stopgap ([LINT-EXCLUDE-*]).
      if Lint.Brand.owned(Lint.Brand.numericBoundaryVocabulary, in: source) { return [] }
      let visitor = UncheckedVisitor(
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
internal let uncheckedCallSiteMessage: Swift.String =
  "[unchecked call site] [CONV-016]: `__unchecked:` at a call site is a Tier-5 "
  + "last-resort bypass of the typed system. Prefer `.retag()` (Tier 1) or `.map()` "
  + "(Tier 2) before resorting to `__unchecked:`. If this site is the typed-system "
  + "bottom-out (extension-init internals, [CONV-001] permitted same-package use), "
  + "escalate to supervisor and apply "
  + "`// swift-linter:disable:next unchecked call site` with a "
  + "`// REASON: <citation>` continuation."

internal final class UncheckedVisitor: SyntaxVisitor {
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

  override func visit(_ node: LabeledExprSyntax) -> SyntaxVisitorContinueKind {
    guard let label = node.label, label.text == "__unchecked" else {
      return .visitChildren
    }
    // A `LabeledExprSyntax` also matches a labeled TUPLE element
    // (`let t = (__unchecked: value)`), which is not a call site. Require
    // the enclosing labeled-expr LIST to itself sit inside a
    // `FunctionCallExprSyntax` — a call's argument list — not a
    // `TupleExprSyntax`.
    guard node.parent?.parent?.is(FunctionCallExprSyntax.self) == true else {
      return .visitChildren
    }
    let location = converter.location(for: label.positionAfterSkippingLeadingTrivia)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "unchecked call site",
        message: uncheckedCallSiteMessage
      ))
    return .visitChildren
  }
}
