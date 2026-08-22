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

/// The three tiers of the documented `setup → body → completion` order.
/// `other` closures carry no lifecycle signal and are excluded from
/// ordering checks entirely — the rule can't disambiguate intent
/// without an anchor.
internal enum Tier: CaseIterable {
    case setup
    case body
    case completion
    case other

}
