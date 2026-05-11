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
public import Linter_Rule_Naming
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
            .enable(.`compound type name`),
            .enable(.`variable named impl`),
            .enable(.`int public parameter`),
            .enable(.`namespace adoption typealias`),
            .enable(.`property named flags`),
            .enable(.`redundant prefix`),
            .enable(.`single type namespace`),
            .enable(.`tag suffix`),
            .enable(.`unification typealias`),
        ]
}
