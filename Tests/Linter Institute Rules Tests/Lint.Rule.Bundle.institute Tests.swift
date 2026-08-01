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

import Linter_Primitives
import Linter_Rules
import Testing

@testable import Linter_Institute_Rules

/// Converts every rule declared across the 17 institute rule packs to a
/// hand-maintained master list. This is the same enumeration the #1
/// source-level review performed by hand, since amended: 90 declared
/// rules at #26 origination, +3 (#29/#30/#31 — sending return conditional
/// sendable state, protocol sentinel under generic front door, foundation
/// integration leaf target) landed enabled without a matching update
/// here, discovered and backfilled here — 93 declared rules, 92 enabled +
/// 1 deliberate exclusion — this test converts that receipt into a
/// standing gate: whoever adds or removes a rule from a pack MUST update
/// this list in the same change, or the composition-drift test below
/// fails and says exactly which id is missing or extra.
///
/// NOTE: this list is deliberately NOT derived by any form of runtime
/// reflection — Swift has none for static members — so it is exactly as
/// current as the last person who touched a rule pack kept it. That is
/// the property this test exists to enforce.
private let allDeclaredRuleIDs: Swift.Set<Swift.String> = [
  "ad hoc box class",
  "bare string dependency",
  "benchmark timed required",
  "binary serializable rawvalue uint8",
  "binary serializable uint8 witness",
  "bitpattern rawvalue chain",
  "bool public parameter",
  "borrowing self short circuit",
  "bounded index static capacity",
  "byte conforms to arithmetic protocol",
  "c type in public api",
  "callback result over throws thunk",
  "canimport conditional",
  "chained rawvalue access",
  "closure typed throws annotation",
  "compound identifier",
  "compound platform namespace root",
  "compound suite name",
  "compound type name",
  "configuration before content",
  "convention c representability",
  "count minus one",
  "counter loop iteration",
  "dead case per platform",
  "do throws for typed catch",
  "do throws for typed catch with throw",
  "enumerated with subscript",
  "existential throws",
  "extension file naming",
  "extension noncopyable constraint",
  "file name nested path",
  "foundation import",
  "foundation integration leaf target",
  "generic throws missing never",
  "hoisted error in public throws",
  "hoisted protocol alias",
  "int public parameter",
  "intermediate binding then return",
  "leaf body typealias missing",
  "lifecycle order",
  "lifecycle typealias review",
  "minimal type body",
  "namespace adoption typealias",
  "nested tag",
  "noncopyable error",
  "nonisolated unsafe without invariant",
  "optimize suppression attribute",
  "optionset shell pattern",
  "parameter position",
  "performance suite serialized",
  "phantom generic error in typed throws",
  "phantom suppression",
  "pointer advanced by",
  "property named flags",
  "protocol sentinel under generic front door",
  "raw value access",
  "redundant prefix",
  "result wrapper for rethrows shim",
  "safe attribute undocumented",
  "sendable struct with class member",
  "sending return conditional sendable state",
  "single type namespace",
  "single type per file",
  "sli literal",
  "stdlib forwarder outside sli",
  "string utf8 scanning",
  "suite categories",
  "swift protocol qualification",
  "system subdomain",
  "tag suffix",
  "tagged extension public init",
  "tagged unchecked with typed alternative",
  "test display name string",
  "test file suffix",
  "test function naming",
  "throwing wrapper init",
  "try optional",
  "type transform placement",
  "typealiased namespace bridge",
  "typed throws cannot use self error",
  "uint8 ascii extension",
  "uint8 conforms to byte protocol",
  "uint8 forwarder missing disfavored",
  "unchecked call site",
  "unchecked sendable revalidation anchor",
  "unification typealias",
  "unknown default",
  "unlabeled lifecycle closure",
  "unsafe assignment granularity",
  "untyped throws",
  "variable named impl",
  "wrapper backing exposed",
  "xctest import",
  "zero or one literal",
]

/// Rule ids declared in the package that are deliberately NOT enabled in
/// `Lint.Rule.Bundle.institute`, with the citation to why. Distinguishes
/// "deliberately deferred" from "accidentally dropped" — nothing else in
/// the source tells a reader which one a missing id means.
private let deliberateExclusions: Swift.Set<Swift.String> = [
  // [BENCH-003] deferred 2026-05-18 — depends on swift-testing's
  // `.timed()` trait, which isn't production-ready yet. See the
  // re-enable condition documented at the `.enable` call site's comment
  // in Lint.Rule.Bundle.institute.swift.
  "benchmark timed required"
]

@Suite
struct `Lint Rule Bundle institute Tests` {
  @Suite struct `Composition` {}
  @Suite struct `Id integrity` {}
}

/// `Lint.Rule.Bundle.institute` is `Lint.Rule.Bundle.universal + [...]` —
/// the FULL enabled-id set therefore always contains every universal id
/// too, by construction. Every test below that means to reason about
/// "what THIS package's 17 rule packs contribute" first subtracts the
/// universal tier's own ids back out, or it would be comparing the
/// master list against a set it can never equal.
private func instituteContributedEnabledIDs() -> Swift.Set<Swift.String> {
  let universalIDs = Swift.Set(Lint.Rule.Bundle.universal.map(\.rule.id.underlying))
  let enabledIDs = Swift.Set(
    Lint.Rule.Bundle.institute
      .filter { $0.mode == .enabled }
      .map(\.rule.id.underlying)
  )
  return enabledIDs.subtracting(universalIDs)
}

extension `Lint Rule Bundle institute Tests`.`Composition` {
  @Test
  func `every declared rule is either enabled in the bundle or a deliberate exclusion`() {
    let accountedFor = instituteContributedEnabledIDs().union(deliberateExclusions)
    let missing = allDeclaredRuleIDs.subtracting(accountedFor)
    #expect(
      missing.isEmpty,
      "Declared rule(s) neither enabled in Lint.Rule.Bundle.institute nor listed as a deliberate exclusion — update the master list in this test if this is a new rule, or enable/exclude it in the bundle: \(missing.sorted())"
    )
  }

  @Test
  func `every id this test tracks is actually declared by some rule in the package`() {
    // Regression guard on the master list itself: an id that's been
    // renamed or removed from a pack but not updated here would let the
    // composition-drift test above pass for the wrong reason (both sides
    // silently missing the same stale id).
    let accountedFor = instituteContributedEnabledIDs().union(deliberateExclusions)
    let extra = accountedFor.subtracting(allDeclaredRuleIDs)
    #expect(
      extra.isEmpty,
      "Bundle enables (or this test excludes) id(s) not in the master list — the master list is stale: \(extra.sorted())"
    )
  }

  @Test
  func `the one deliberate exclusion is absent from the enabled bundle`() {
    let enabledIDs = instituteContributedEnabledIDs()
    for excluded in deliberateExclusions {
      #expect(
        !enabledIDs.contains(excluded),
        "'\(excluded)' is documented as a deliberate exclusion but is enabled in the bundle — either the exclusion has been lifted (update this test) or it was re-enabled by accident before its stated condition was met."
      )
    }
  }
}

extension `Lint Rule Bundle institute Tests`.`Id integrity` {
  @Test
  func `institute bundle rule ids are unique`() {
    let ids = Lint.Rule.Bundle.institute.map(\.rule.id.underlying)
    let unique = Swift.Set(ids)
    #expect(
      ids.count == unique.count,
      "Duplicate rule id(s) in Lint.Rule.Bundle.institute — consumers write these ids in suppression directives and configuration; a collision is silently ambiguous."
    )
  }

  @Test
  func `institute-declared ids do not collide with the universal-tier bundle`() {
    // Compares the 17 institute packs' OWN declared ids (not the
    // concatenated bundle, which trivially contains every universal id)
    // against the universal tier.
    let universalIDs = Swift.Set(Lint.Rule.Bundle.universal.map(\.rule.id.underlying))
    let collisions = allDeclaredRuleIDs.intersection(universalIDs)
    #expect(
      collisions.isEmpty,
      "Institute-tier id(s) collide with the universal tier — an upstream rename could produce this without either side's own test suite noticing: \(collisions.sorted())"
    )
  }
}
