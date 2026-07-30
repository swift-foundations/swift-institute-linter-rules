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

/// Strips optional (`T?`), implicitly-unwrapped-optional (`T!`), and
/// attribute (`@escaping T`, `@Sendable T`, …) wrappers from `type`,
/// leaving the underlying type syntax. Shared by every predicate in
/// this pack that needs to classify a parameter's type past its
/// surface spelling (#24 nit: this loop previously existed as three
/// separate copies — `isClosureType`, `isConfigurationType`, and
/// `Idiom`'s `idiomIsRawIntType` — one per call site. Consolidated
/// here for the two call sites that share this module; `Idiom`'s copy
/// stays separate because the two packs are independent SwiftPM
/// targets with no dependency on one another — sharing across packs
/// would require introducing a new common target, which is an
/// architecture decision outside this pass's authority, not a
/// mechanical fix).
internal func closureStrippingWrapperTypes(_ type: TypeSyntax) -> TypeSyntax {
  var current = type
  while let optional = current.as(OptionalTypeSyntax.self) {
    current = optional.wrappedType
  }
  while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    current = iuo.wrappedType
  }
  while let attributed = current.as(AttributedTypeSyntax.self) {
    current = attributed.baseType
  }
  return current
}
