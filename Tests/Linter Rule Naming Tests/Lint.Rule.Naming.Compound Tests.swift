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
    struct `compound identifier Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`compound identifier Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`compound identifier`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`compound identifier Tests`.Unit {
    @Test
    func `func openWrite is flagged`() {
        let source = "func openWrite() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "compound identifier")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `func walkFiles is flagged`() {
        let source = "func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `var firstName is flagged`() {
        let source = "var firstName: String = \"\""
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `let lastError is flagged`() {
        let source = "let lastError: Int = 0"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multi-camel name parseManifestFile is flagged`() {
        let source = "func parseManifestFile() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending decls are all flagged`() {
        let source = """
        func openWrite() {}
        func walkFiles() {}
        var firstName: String = ""
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 3)
    }
}

extension Lint.Rule.`compound identifier Tests`.`Edge Case` {
    @Test
    func `func open is NOT flagged`() {
        let source = "func open() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `boolean isEmpty is NOT flagged`() {
        let source = "var isEmpty: Bool = false"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `boolean hasValue is NOT flagged`() {
        let source = "var hasValue: Bool = false"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `boolean shouldRetry is NOT flagged`() {
        let source = "var shouldRetry: Bool = false"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stdlib idiom rawValue is NOT flagged`() {
        let source = "var rawValue: Int = 0"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `SE-0517 mutableSpan computed property is NOT flagged`() {
        let source = """
        extension Buffer {
            public var mutableSpan: MutableSpan<Value> { fatalError() }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `SE-0517 span computed property is NOT flagged`() {
        let source = """
        extension Buffer {
            public var span: Span<Value> { fatalError() }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `CustomStringConvertible description is NOT flagged`() {
        let source = """
        struct X: CustomStringConvertible {
            var description: String { "x" }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `package-scoped compound is NOT flagged`() {
        let source = "package func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `package-scoped var is NOT flagged`() {
        let source = "package var firstName: String = \"\""
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `function parameter labels are NOT flagged`() {
        let source = "func read(atOffset: Int) {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        // The rule visits decl names, not parameter labels. The decl name `read`
        // is not compound. Parameter `atOffset` is exempt per scope choice.
        #expect(findings.isEmpty)
    }

    @Test
    func `single underscore name is NOT flagged`() {
        let source = "var _x: Int = 0"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression inside @resultBuilder enum is NOT flagged`() {
        let source = """
        @resultBuilder
        public enum Builder {
            public static func buildExpression(_ x: Int) -> [Int] { [x] }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildPartialBlock inside @resultBuilder enum is NOT flagged`() {
        let source = """
        @resultBuilder
        public enum Builder {
            public static func buildPartialBlock(first: Int) -> [Int] { [first] }
            public static func buildPartialBlock(accumulated: [Int], next: Int) -> [Int] {
                accumulated + [next]
            }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression OUTSIDE @resultBuilder IS flagged`() {
        let source = """
        public enum NotABuilder {
            public static func buildExpression(_ x: Int) -> [Int] { [x] }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-protocol compound method inside @resultBuilder IS flagged`() {
        let source = """
        @resultBuilder
        public enum Builder {
            public static func openWrite() {}
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - Visibility scope ([API-NAME-002] amendment 2026-05-11)
    //
    // Per `Research/api-name-002-private-surface-applicability.md`
    // (DECISION 2026-05-11, Option B): the rule fires on `public`,
    // `package`, `internal`, and `open` decls but exempts `fileprivate`
    // and `private` — including members whose *effective* visibility is
    // reduced by an enclosing fileprivate / private type. Decls invisible
    // across the file boundary have no consumer-observable surface even
    // within the module.

    @Test
    func `fileprivate compound func is NOT flagged`() {
        let source = "fileprivate func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `private compound func is NOT flagged`() {
        let source = "private func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `fileprivate compound var is NOT flagged`() {
        let source = "fileprivate var firstName: String = \"\""
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `private compound var is NOT flagged`() {
        let source = "private var firstName: String = \"\""
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `internal compound func IS still flagged`() {
        let source = "internal func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public compound func IS still flagged`() {
        let source = "public func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `unannotated compound func at file scope IS still flagged`() {
        // No explicit access modifier — defaults to `internal`. Rule fires.
        let source = "func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `compound field of fileprivate struct is NOT flagged`() {
        // Reproduces the Ownership.Transfer.Erased.Outgoing.Header
        // residual: fields with no explicit modifier inside a
        // fileprivate struct. Effective visibility is fileprivate.
        let source = """
        fileprivate struct Header {
            let destroyPayload: (Int) -> Void
            let payloadOffset: Int
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `compound field of private struct is NOT flagged`() {
        let source = """
        private struct Header {
            let destroyPayload: (Int) -> Void
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `compound method of fileprivate struct is NOT flagged`() {
        let source = """
        fileprivate struct Internal {
            func walkFiles() {}
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `compound field of internal struct IS still flagged`() {
        // Sanity: the enclosing-type walk-up must NOT short-circuit
        // on an internal type. `internal` decls remain in scope.
        let source = """
        internal struct Header {
            let destroyPayload: (Int) -> Void
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `compound field of public struct IS still flagged`() {
        let source = """
        public struct Header {
            let destroyPayload: (Int) -> Void
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `compound member of private nested in public type is NOT flagged`() {
        // Outer is public but the inner type is private — effective
        // visibility of the field is private; rule must NOT fire.
        let source = """
        public struct Outer {
            private struct Inner {
                let destroyPayload: (Int) -> Void
            }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `compound method in fileprivate extension is NOT flagged`() {
        let source = """
        fileprivate extension Existing {
            func walkFiles() {}
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Ownership-Transfer-Erased-Outgoing-Header residual closes`() {
        // Verbatim reproduction of the Wave 2 leaf-triage residual
        // closed by Wave 3 Thread 4: a fileprivate struct nested inside
        // an extension, with let-bindings whose modifier list is empty
        // but whose effective visibility is fileprivate.
        let source = """
        extension Ownership.Transfer.Erased.Outgoing {
            @safe
            fileprivate struct Header {
                let destroyPayload: (UnsafeMutableRawPointer, Int) -> Void
                let payloadOffset: Int
            }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Exemption shape: [RULE-EXEMPT-2] (protocol-witness-citation-dict).
    // Protocol-required witness method names declared inside an
    // extension conforming to the corresponding protocol are exempt.
    // The dict is the citation surface; the conformance-context gate
    // ensures the same name outside the conformance still fires.

    @Test
    func `makeIterator inside Sequence conformance is exempt per RULE-EXEMPT-2`() {
        let source = """
        extension MyType: Sequence {
            func makeIterator() -> MyIterator { fatalError() }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `encodeAtomicRepresentation inside AtomicRepresentable conformance is exempt per RULE-EXEMPT-2`() {
        let source = """
        extension Tagged: AtomicRepresentable {
            static func encodeAtomicRepresentation(_ value: consuming Self) -> AtomicRepresentation { fatalError() }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `makeIterator outside conformance context is still flagged`() {
        let source = """
        extension MyType {
            func makeIterator() -> MyIterator { fatalError() }
        }
        """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
