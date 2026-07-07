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

import Linter_Primitives
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_RawValue

extension Lint.Rule {
    @Suite
    struct `tagged extension public init Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`tagged extension public init Tests` {
    static func findings(in source: Swift.String, file: Swift.String = "Sources/X/Test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`tagged extension public init`.findings(parsed, .warning)
    }
}

extension Lint.Rule.`tagged extension public init Tests`.Unit {
    @Test
    func `extension on bare Tagged with public init is flagged`() {
        let source = """
            extension Tagged {
                public init(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "tagged extension public init")
        }
    }

    @Test
    func `extension on Tagged generic specialization with public init is flagged`() {
        let source = """
            extension Tagged<UserTag, String> {
                public init(_ s: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension on Tagged with internal init is permitted`() {
        let source = """
            extension Tagged {
                init(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on non-Tagged type with public init is permitted`() {
        let source = """
            extension MyType {
                public init(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Tagged with multiple public inits flags each`() {
        let source = """
            extension Tagged {
                public init(_ s: String) { fatalError() }
                public init(value: Int) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `extension on Tagged with public method but no public init is permitted`() {
        let source = """
            extension Tagged {
                public func foo() {}
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`tagged extension public init Tests`.`Edge Case` {
    @Test
    func `extension on qualified Tagging Tagged is flagged`() {
        let source = """
            extension Tagging.Tagged {
                public init(_ s: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension on Tagged with where clause is flagged`() {
        let source = """
            extension Tagged where RawValue == String {
                public init(_ s: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension on TaggedFoo (compound name) is not flagged`() {
        let source = """
            extension TaggedFoo {
                public init(_ s: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Exemption shape: [RULE-EXEMPT-2] (protocol-witness-citation-dict).
    // Extensions on `Tagged` that conform to a stdlib literal protocol
    // are exempt — the protocol's `init(...)` requirement IS the
    // validation gate; the conformer cannot drop the public init and
    // still satisfy the contract. The dict pairs each witness key with
    // its specific protocol.

    @Test
    func `extension on Tagged conforming to ExpressibleByIntegerLiteral is exempt per RULE-EXEMPT-2`() {
        let source = """
            extension Tagged: ExpressibleByIntegerLiteral {
                public init(integerLiteral value: Int) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Tagged conforming to Decodable is exempt per RULE-EXEMPT-2`() {
        let source = """
            extension Tagged: Decodable {
                public init(from decoder: any Decoder) throws { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Tagged conforming to RawRepresentable is exempt per RULE-EXEMPT-2`() {
        let source = """
            extension Tagged: RawRepresentable {
                public init?(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Exemption shape: [RULE-EXEMPT-5] (Protocol-sentinel) composed
    // with [RULE-EXEMPT-2]. The `` `Protocol` `` key in the dict
    // encodes the institute hoisted-protocol pattern per [API-IMPL-009]
    // / [PKG-NAME-001]: `extension Tagged: Carrier.\`Protocol\`` —
    // the conformer satisfies the nested-namespace protocol witness
    // and inherits its init contract. The backtick-escaped form is
    // load-bearing: bare `Carrier.Protocol` parses as a
    // `MetatypeTypeSyntax` (Swift's `.Protocol` metatype keyword),
    // so the institute pattern always uses the escaped spelling.
    // Inheritance-leaf walking captures the trailing identifier as
    // `` `Protocol` ``, which matches the dict entry.

    @Test
    func `extension on Tagged conforming to backtick-escaped Protocol sentinel is exempt per RULE-EXEMPT-5`() {
        let source = """
            extension Tagged: Carrier.`Protocol` {
                public init(value: Int) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Tagged conforming to non-witness protocol is still flagged`() {
        let source = """
            extension Tagged: CustomStringConvertible {
                public init(_ s: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `free-generic-Tag domain extension with Underlying binding is admitted`() {
        let source = """
            extension Tagged where Underlying == Cardinal, Tag: ~Copyable {
                public init(_ uint: UInt) { fatalError() }
                public init(_ int: Int) throws(Cardinal.Error) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        // Free generic Tag has no specific owner at which a per-tag
        // validation gate could live. The Underlying binding (==
        // Cardinal) signals "domain extension on Underlying axis",
        // which the institute uses for typed bridges between
        // numerics-domain primitives. Tag-specific invariants are out
        // of scope by construction.
        #expect(findings.isEmpty)
    }

    @Test
    func `free-generic-Tag domain extension with Underlying binding (single init) is admitted`() {
        let source = """
            extension Tagged where Underlying == Cardinal, Tag: ~Copyable {
                public init(_ index: Tagged<Tag, Ordinal>) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension binding both Underlying and Tag is still flagged (Tag bound)`() {
        let source = """
            extension Tagged where Underlying == Cardinal, Tag == MySpecificTag {
                public init(_ raw: Cardinal) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        // Tag is bound to a concrete (MySpecificTag) so a per-tag
        // validation gate IS expressible here — the rule's intent
        // applies and the init should still fire.
        #expect(findings.count == 1)
    }

    @Test
    func `bare extension on Tagged with no where clause is still flagged`() {
        let source = """
            extension Tagged {
                public init(raw: RawValue) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        // No Underlying binding signals no domain intent. Both axes
        // are free generically, but the absence of Underlying ==
        // signals this is not a deliberate domain bridge — the rule
        // should still fire to surface the bypass.
        #expect(findings.count == 1)
    }
}
