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
internal enum LifecycleTier: CaseIterable {
  case setup
  case body
  case completion
  case other

  /// Position in the documented order. Lower sorts earlier.
  /// `other` has no position in the order and must not be compared.
  var rank: Swift.Int {
    switch self {
    case .setup: return 0
    case .body: return 1
    case .completion: return 2
    case .other: return 0
    }
  }
}

/// Classifies a closure parameter's lifecycle tier from its label.
///
/// Both the external argument label (`parameter.firstName`, when not an
/// anonymous `_`) and the internal parameter name
/// (`parameter.secondName`) are checked against the known label sets —
/// the external label is the primary signal, but an anonymous parameter
/// (`_ completion: ...`) carries its only textual hint on the internal
/// name, and a parameter with a non-canonical external label paired
/// with a canonical internal name (`to completion: ...`) still reads as
/// what its internal name says.
internal func lifecycleTier(of parameter: FunctionParameterSyntax) -> LifecycleTier {
  let external: Swift.String? =
    parameter.firstName.tokenKind == .wildcard ? nil : parameter.firstName.text
  let internalName: Swift.String? = parameter.secondName?.text

  for candidate in [external, internalName].compactMap({ $0 }) {
    if setupTierLabels.contains(candidate) {
      return .setup
    }
    if completionTierLabels.contains(candidate) {
      return .completion
    }
    if bodyTierLabels.contains(candidate) {
      return .body
    }
  }
  return .other
}
