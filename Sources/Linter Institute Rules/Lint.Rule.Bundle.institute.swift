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

public import Institute_Linter_Rule_Byte
public import Institute_Linter_Rule_Cardinal
public import Institute_Linter_Rule_Closure
public import Institute_Linter_Rule_Conformance
public import Institute_Linter_Rule_Foundation
public import Institute_Linter_Rule_Framework
public import Institute_Linter_Rule_Idiom
public import Institute_Linter_Rule_Memory
public import Institute_Linter_Rule_Naming
public import Institute_Linter_Rule_Platform
public import Institute_Linter_Rule_RawValue
public import Institute_Linter_Rule_Structure
public import Institute_Linter_Rule_Testing
public import Institute_Linter_Rule_Throws
public import Institute_Linter_Rule_Try
public import Institute_Linter_Rule_Unchecked
public import Linter_Primitives
public import Linter_Rules

/// Institute-tier rule bundle.
///
/// Equals the universal-tier bundle plus institute-tier rules currently
/// living in `swift-institute-linter-rules`. A consumer that pulls this
/// bundle by name receives the full union without enumerating
/// individual rules:
///
/// ```swift
/// let configuration = Lint.Configuration {
///     Lint.Rule.Bundle.institute
/// }
/// ```
///
/// As mixed packs are split out of `swift-linter-rules` into this
/// package, this bundle's content grows; the universal bundle's
/// content sharpens. Consumers continue to reference
/// `Lint.Rule.Bundle.institute` and pick up the migration
/// automatically.
extension Lint.Rule.Bundle {
  public static let institute: [Lint.Rule.Configuration] =
    Lint.Rule.Bundle.universal + [
      // Naming pack
      .enable(.`bool public parameter`),
      .enable(.`ad hoc box class`),
      .enable(.`compound identifier`),
      .enable(.`compound suite name`),
      .enable(.`compound type name`),
      .enable(.`variable named impl`),
      .enable(.`int public parameter`),
      .enable(.`namespace adoption typealias`),
      .enable(.`property named flags`),
      .enable(.`redundant prefix`),
      .enable(.`single type namespace`),
      .enable(.`tag suffix`),
      .enable(.`nested tag`),
      // [API-NAME-010b] — validated 2026-07-07 against the ADT tower
      // (tree-keyed 1, slab 5, buffer-slab 2 = 8 true-positive findings on
      // phantom `<E: ~Copyable>` Index discriminators; the dominant fleet
      // convention binds such phantoms `~Copyable & ~Escapable`, 99 sites).
      // Receipt: Research/promote-phantom-suppression-tower-validation-2026-07-07.md.
      .enable(.`phantom suppression`),
      .enable(.`unification typealias`),
      // Foundation pack
      .enable(.`foundation import`),
      // Framework pack
      .enable(.`xctest import`),
      .enable(.`suite categories`),
      // Byte pack (Wave 1 of Post-W2 swift-linter arc, 2026-05-19)
      // — encodes the W2 UInt8/Byte discrimination rubric per
      // broader-l2-l3-byte-typing-gap-plan.md § Wave 2.
      .enable(.`uint8 conforms to byte protocol`),
      .enable(.`byte conforms to arithmetic protocol`),
      .enable(.`binary serializable uint8 witness`),
      .enable(.`binary serializable rawvalue uint8`),
      .enable(.`uint8 ascii extension`),
      .enable(.`uint8 forwarder missing disfavored`),
      .enable(.`stdlib forwarder outside sli`),
      // Conformance pack
      .enable(.`leaf body typealias missing`),
      // Closure pack (Wave 3 2026-05-15)
      .enable(.`configuration before content`),
      .enable(.`lifecycle order`),
      .enable(.`unlabeled lifecycle closure`),
      .enable(.`parameter position`),
      // Idiom pack (Wave 3 2026-05-15)
      .enable(.`bounded index static capacity`),
      .enable(.`enumerated with subscript`),
      .enable(.`intermediate binding then return`),
      .enable(.`counter loop iteration`),
      .enable(.`string utf8 scanning`),
      .enable(.`sli literal`),  // [IDX-019] (/promote-rule 2026-07-06)
      // Memory pack (Wave 3 2026-05-15)
      .enable(.`borrowing self short circuit`),
      .enable(.`noncopyable error`),
      .enable(.`extension noncopyable constraint`),
      .enable(.`nonisolated unsafe without invariant`),
      .enable(.`safe attribute undocumented`),
      .enable(.`pointer advanced by`),
      .enable(.`sendable struct with class member`),
      .enable(.`unchecked sendable revalidation anchor`),
      .enable(.`unsafe assignment granularity`),
      // Platform pack (Wave 3 2026-05-15)
      .enable(.`c type in public api`),
      .enable(.`convention c representability`),
      .enable(.`dead case per platform`),
      .enable(.`compound platform namespace root`),
      .enable(.`optimize suppression attribute`),  // [ISSUE-008] (/promote-rule 2026-07-06)
      .enable(.`optionset shell pattern`),
      .enable(.`canimport conditional`),
      .enable(.`swift protocol qualification`),
      .enable(.`system subdomain`),
      .enable(.`typealiased namespace bridge`),
      // Structure pack (Wave 3 2026-05-15)
      .enable(.`hoisted protocol alias`),
      .enable(.`minimal type body`),
      .enable(.`raw value access`),
      .enable(.`single type per file`),
      .enable(.`throwing wrapper init`),
      .enable(.`type transform placement`),
      .enable(.`wrapper backing exposed`),
      // Testing pack (Wave 3 2026-05-15)
      // `benchmark timed required` ([BENCH-003]) deferred 2026-05-18:
      // depends on swift-testing's `.timed()` trait which isn't
      // production-ready; benchmarks are moving to separate
      // /Benchmarks/ packages per the `benchmark` skill, so the rule's
      // target audience (in-tree Performance @Suites) is going away.
      // Re-enable when (a) swift-testing's `.timed()` ships stable OR
      // (b) we readopt in-tree Performance @Suites with a different
      // measurement primitive. The rule definition stays in the
      // Institute_Linter_Rule_Testing module for re-enable convenience.
      // .enable(.`benchmark timed required`),
      .enable(.`test function naming`),
      .enable(.`performance suite serialized`),
      // Throws pack (Wave 3 2026-05-15)
      .enable(.`closure typed throws annotation`),
      .enable(.`do throws for typed catch`),
      .enable(.`do throws for typed catch with throw`),
      .enable(.`existential throws`),
      .enable(.`generic throws missing never`),
      .enable(.`hoisted error in public throws`),
      .enable(.`lifecycle typealias review`),
      .enable(.`callback result over throws thunk`),
      .enable(.`result wrapper for rethrows shim`),
      .enable(.`typed throws cannot use self error`),
      .enable(.`untyped throws`),
      // Try pack (Wave 3 2026-05-15)
      .enable(.`try optional`),
      // Unchecked pack (Wave 3 2026-05-15)
      .enable(.`unchecked call site`),
      // A5 move (2026-07-07, principal ruling) — brand-consumer rule packs
      // relocated from swift-primitives-linter-rules so they enforce at L2/L3
      // too (brands are defined at L1 but consumed everywhere). Precedent:
      // [PRIM-FOUND-001] made the same primitives→institute move mid-pilot.
      // Cardinal pack (Wave 3 2026-05-15)
      .enable(.`zero or one literal`),
      .enable(.`count minus one`),
      // RawValue pack
      .enable(.`bitpattern rawvalue chain`),
      .enable(.`chained rawvalue access`),
      .enable(.`tagged extension public init`),
      // [CONV-015] — promoted 2026-07-07 (principal ruling, option a)
      // from swift-tagged-primitives' nested Lint/ PoC
      // (Lint.Rule.TaggedDomainAudit); map/retag/@Test exemptions
      // preserved. Receipt:
      // Research/promote-tagged-unchecked-validation-2026-07-07.md.
      .enable(.`tagged unchecked with typed alternative`),
    ]
}
