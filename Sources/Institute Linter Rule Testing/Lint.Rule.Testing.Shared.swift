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

internal import SwiftSyntax

/// Predicates shared across the Testing pack's rules.

/// True when `attributes` carries an attribute named `name` — either bare
/// (`@Test`) or qualified (`@Testing.Test`), matching on the qualified
/// spelling's leaf. `test file suffix` already had the right form; the
/// other rules in this pack compared `trimmedDescription` against the bare
/// name only, so a qualified `@Testing.Test` was invisible to them.
internal func testingHasAttribute(
  _ attributes: AttributeListSyntax,
  named name: Swift.String
) -> Swift.Bool {
  for attribute in attributes {
    guard case .attribute(let attr) = attribute else { continue }
    let attributeName = attr.attributeName.trimmedDescription
    if attributeName == name || attributeName.hasSuffix(".\(name)") {
      return true
    }
  }
  return false
}
