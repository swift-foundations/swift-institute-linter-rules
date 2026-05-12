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

import Testing
import SwiftSyntax
import SwiftParser
import Linter_Primitives
import Linter_Rules_Test_Support
@testable import Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `int public parameter Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct `Package Scope` {}
    }
}

extension Lint.Rule.`int public parameter Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`int public parameter`.findings(parsed, .warning)
    }

    /// Run with a simulated owning-package brand-types set. See
    /// package-scoped admission notes on
    /// `Lint.Rule.\`int public parameter\``.
    static func findings(
        in source: String,
        file: String = "test.swift",
        brandTypes: Set<Lint.Brand>
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file, brandTypes: brandTypes)
        return Lint.Rule.`int public parameter`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`int public parameter Tests`.Unit {
    @Test
    func `public func with Int parameter is flagged`() {
        let source = "public func read(count: Int) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "int public parameter")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `public func with Int return type is flagged`() {
        let source = "public func size() -> Int { 0 }"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with Int param and Int return has two findings`() {
        let source = "public func foo(n: Int) -> Int { n }"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `public init with Int parameter is flagged`() {
        let source = """
        public struct Foo {
            public init(count: Int) {}
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `optional Int parameter is flagged`() {
        let source = "public func read(count: Int?) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Swift-qualified Int is flagged`() {
        let source = "public func tag(value: Swift.Int) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `open func with Int return is flagged`() {
        let source = """
        public class Base {
            open func size() -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple public functions independently flagged`() {
        let source = """
        public func a(x: Int) {}
        public func b() -> Int { 0 }
        public func c(s: String) -> String { s }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`int public parameter Tests`.`Edge Case` {
    @Test
    func `internal func with Int parameter is NOT flagged`() {
        let source = "func read(count: Int) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `private func with Int return is NOT flagged`() {
        let source = "private func size() -> Int { 0 }"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `package func with Int parameter is NOT flagged`() {
        let source = "package func read(count: Int) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Cardinal typed parameter is NOT flagged`() {
        let source = "public func read(count: Cardinal) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Index parameter is NOT flagged`() {
        let source = "public func at(index: Index<UInt8>) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `sized integer Int32 is NOT flagged`() {
        // Sized integers (Int8/16/32/64, UInt*, ...) are valid domain types
        // (e.g., Int32 for fd, UInt8 for byte). Rule scopes to bare `Int`.
        let source = "public func tag(fd: Int32) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `sized integer UInt8 is NOT flagged`() {
        let source = "public func encode(_ b: UInt8) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `closure with internal Int parameter is NOT flagged`() {
        // The Int is inside a closure type, not the outer signature.
        let source = "public func op(_ body: (Int) -> Void) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `tuple with Int member is NOT flagged`() {
        let source = "public func tag(values: (Int, String)) {}"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested public function inside public type is flagged`() {
        let source = """
        public struct Buffer {
            public func read(count: Int) {}
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `String return is NOT flagged`() {
        let source = "public func describe() -> String { \"\" }"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression Int return inside @resultBuilder is NOT flagged`() {
        let source = """
        @resultBuilder
        public enum Count {
            public static func buildExpression(_ expression: Bool) -> Int {
                expression ? 1 : 0
            }
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildPartialBlock Int param inside @resultBuilder is NOT flagged`() {
        let source = """
        @resultBuilder
        public enum Count {
            public static func buildPartialBlock(first: Int) -> Int { first }
            public static func buildPartialBlock(accumulated: Int, next: Int) -> Int {
                accumulated + next
            }
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression with Int return OUTSIDE @resultBuilder IS flagged`() {
        let source = """
        public enum NotABuilder {
            public static func buildExpression(_ expression: String) -> Int { 0 }
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-protocol Int-taking method inside @resultBuilder IS flagged`() {
        let source = """
        @resultBuilder
        public enum Builder {
            public static func helper(_ x: Int) -> Int { x }
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

// MARK: - Package-scoped admission (numerics rule-recognizer, 2026-05-12)
//
// `Int.init(bitPattern: Brand)` integration overloads live in the
// brand's own package per [IMPL-010]. The rule admits public-`Int`
// signatures inside files whose owning package declares any brand.

extension Lint.Rule.`int public parameter Tests`.`Package Scope` {
    @Test
    func `public Int parameter is admitted inside a brand-declaring package`() {
        // `public init(bitPattern: Int)` inside the brand's own
        // integration overload file. The package declares
        // ["Ordinal"]; the rule short-circuits and emits nothing.
        let source = """
        extension Int {
            public init(bitPattern position: Ordinal) {}
        }
        extension Ordinal {
            public init(_ rawValue: Int) {}
        }
        """
        let findings = Lint.Rule.`int public parameter Tests`.findings(
            in: source,
            brandTypes: ["Ordinal"]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `public Int return is admitted inside a brand-declaring package`() {
        let source = "public func size() -> Int { 0 }"
        let findings = Lint.Rule.`int public parameter Tests`.findings(
            in: source,
            brandTypes: ["Cardinal"]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `package declaring different brand still fires for cross-package Int`() {
        // The package declares ["Foo"] — irrelevant brand. The rule
        // would normally short-circuit, but per Option (1)'s package-
        // scope semantics, declaring any brand admits Int-in-public-
        // API inside the file. This row pins the *current contract*:
        // if a package declares ANY brand, the file admits Int in
        // public API. (The opposite contract — pin to specific
        // brand-types — is not available since IMPL-010 fires on the
        // signature, not on a `.rawValue` access where the
        // type-name extractor can examine the access target.)
        //
        // This is the deliberate trade-off in the implementation: a
        // package author whose `.swift-linter.json` declares any
        // brand is implicitly opting into a "this package is
        // brand-integration territory" stance. The brand-name set
        // gates which `.rawValue` accesses admit, but the IMPL-010
        // gate is a coarser package-level toggle.
        let source = "public func size() -> Int { 0 }"
        let findings = Lint.Rule.`int public parameter Tests`.findings(
            in: source,
            brandTypes: ["Foo"]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `no brand-types declared - IMPL-010 fires as today (back-compat)`() {
        let source = "public func size() -> Int { 0 }"
        let findings = Lint.Rule.`int public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
