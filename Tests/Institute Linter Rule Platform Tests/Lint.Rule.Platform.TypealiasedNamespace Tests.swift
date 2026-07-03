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

@testable import Institute_Linter_Rule_Platform

extension Lint.Rule {
  @Suite
  struct `typealiased namespace bridge Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
  }
}

extension Lint.Rule.`typealiased namespace bridge Tests` {
  static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic
    .Record]
  {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`typealiased namespace bridge`.findings(parsed, .warning)
  }
}

extension Lint.Rule.`typealiased namespace bridge Tests`.Unit {
  @Test
  func `cross-module typealias keeping leaf name is flagged`() {
    let source = """
      extension ISO_9945 {
          public typealias Kernel = Kernel_Primitives_Core.Kernel
      }
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.count == 1)
    if findings.count == 1 {
      #expect(findings[0].identifier == "typealiased namespace bridge")
      #expect(findings[0].severity == .warning)
    }
  }

  @Test
  func `simple file-scope namespace-bridge typealias is flagged`() {
    let source = """
      typealias Socket = Foundation.Socket
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `deep member chain ending in matching leaf is flagged`() {
    let source = """
      typealias Descriptor = A.B.C.D.Descriptor
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.count == 1)
  }
}

extension Lint.Rule.`typealiased namespace bridge Tests`.`Edge Case` {
  @Test
  func `typealias with different LHS-RHS leaf names is NOT flagged`() {
    let source = """
      typealias Storage = Internal.Buffer
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `typealias to bare identifier is NOT flagged`() {
    let source = """
      typealias Foo = Int
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `typealias to generic specialization NOT a member type is NOT flagged`() {
    let source = """
      typealias Bytes = Array<UInt8>
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `typealias to Self dot Foo (no namespace bridge) is NOT flagged`() {
    // `Self.Foo` is a regular dotted member, not a namespace bridge —
    // though LHS-name equality could match if leaf coincides. The
    // detection's narrow-scope is intentional: same-name bridging
    // pattern is the canonical [PLAT-ARCH-018] shape.
    let source = """
      extension Holder {
          typealias Foo = OtherType.Foo
      }
      """
    // This DOES match the pattern (leaf names equal). Rule flags it
    // — correctly, because consumers calling `Holder.Foo.X` would
    // resolve through to `OtherType.Foo.X`.
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `multiple typealiases in same extension each evaluated`() {
    let source = """
      extension POSIX {
          typealias Kernel = Kernel_Primitives.Kernel
          typealias Socket = Net_Primitives.Socket
          typealias Mode = Other.Different
      }
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    // First two flagged (leaf match), third not (different leaf).
    #expect(findings.count == 2)
  }

  // Exemption shape: [RULE-EXEMPT-3] (conformance-context). A
  // typealias inside an extension with a non-empty inheritance clause
  // satisfies an associatedtype requirement of the conformed protocol;
  // the LHS name is dictated by the protocol shape, not by a
  // discretionary foreign-namespace bridge.

  @Test
  func `typealias inside conforming extension is exempt per RULE-EXEMPT-3`() {
    // `typealias Index = Underlying.Index` inside
    // `extension Tagged: Collection` satisfies `Collection.Index`.
    let source = """
      extension Tagged: Collection {
          typealias Index = Underlying.Index
      }
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `typealias outside conforming extension is still flagged`() {
    // Same shape, but no inheritance clause — purely a namespace
    // bridge; rule MUST fire.
    let source = """
      extension Tagged {
          typealias Index = Underlying.Index
      }
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  // Case (c): the conformance is on the original type declaration
  // nested inside another extension; the typealias lives in a sibling
  // extension at file scope. The conformance walk-up MUST cross the
  // extension boundary and find the conformance on the sibling decl.

  @Test
  func
    `typealias in sibling extension is exempt when conformance is on nested struct in another extension`()
  {
    // Pattern surfaced by the Phase 1B [API-IMPL-008] migration:
    // the conformance is declared on the original struct decl
    // `struct Iterator: Sequence.Iterator.\`Protocol\`` inside
    // `extension Sequence.Drop.First`; the protocol-witness
    // typealias was extracted to a sibling methods extension on
    // `Sequence.Drop.First.Iterator`. The cross-file walk must
    // resolve `Sequence.Drop.First.Iterator` back to the original
    // struct decl carrying the conformance.
    let source = """
      extension Sequence.Drop.First {
          public struct Iterator: Sequence.Iterator.`Protocol` {
              let _base: Int
          }
      }

      extension Sequence.Drop.First.Iterator {
          public typealias Element = Base.Element
      }
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `typealias in sibling extension is exempt when conformance is on sibling extension`() {
    // Mirror of the above where the conformance lives on a sibling
    // `extension Foo: Bar` rather than on the original struct decl.
    let source = """
      struct Container {
          let value: Int
      }

      extension Container: Sequence {
          // ... conformance witnesses
      }

      extension Container {
          typealias Element = Underlying.Element
      }
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `typealias in protocol body is exempt as associatedtype default`() {
    // A `typealias` declared inside a protocol body is the default
    // value for an associatedtype — definitively a conformance-
    // context shape.
    let source = """
      public protocol Container {
          associatedtype Element
          typealias Default = Array.Element
      }
      """
    let findings = Lint.Rule.`typealiased namespace bridge Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }
}
