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

internal import SwiftSyntax

/// Finds a *substantive* use of a generic parameter inside an enum body.
///
/// Uses inside a generic-argument list are skipped: a case referencing the
/// parameter only as `Other<Input>.Error` is transitively phantom (its payload
/// is itself a phantom error), which is how swift-iso-8601's
/// `Interval`/`RecurringInterval` escaped an earlier hand-rolled scan.
internal final class ThrowsPhantomParameterUseFinder: SyntaxVisitor {
  let parameter: Swift.String
  var found = false

  init(parameter: Swift.String) {
    self.parameter = parameter
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_: GenericArgumentClauseSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }

  override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
    if node.name.text == parameter { found = true }
    return .visitChildren
  }
}
