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
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Structure

extension Lint.Rule {
  @Suite
  struct `raw value access Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
  }
}

extension Lint.Rule.`raw value access Tests` {
  static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`raw value access`.findings(parsed, .warning)
  }

  /// Findings against a run whose brand pre-pass stamped `declaredTypeNames`.
  static func findings(
    in source: String,
    declaredTypeNames: Set<String>
  ) -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, declaredTypeNames: declaredTypeNames)
    return Lint.Rule.`raw value access`.findings(parsed, .warning)
  }
}

extension Lint.Rule.`raw value access Tests`.`Edge Case` {
  @Test
  func `brand-owner run self-suppresses raw value access (§A)`() {
    // The run's own sources declare `Cardinal` (∈ numeric vocabulary), so
    // same-package `.rawValue` boundary access is legitimate — zero findings.
    let findings = Lint.Rule.`raw value access Tests`.findings(
      in: "func op(tag: MyTag) { let raw = tag.rawValue; use(raw) }",
      declaredTypeNames: ["Cardinal"]
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `consumer run still fires raw value access (§A)`() {
    // The run declares no brand from the vocabulary — cross-package firing
    // is preserved by construction.
    let findings = Lint.Rule.`raw value access Tests`.findings(
      in: "func op(tag: MyTag) { let raw = tag.rawValue; use(raw) }",
      declaredTypeNames: ["SomeConsumerType"]
    )
    #expect(findings.count == 1)
  }
}

extension Lint.Rule.`raw value access Tests`.Unit {
  @Test
  func `rawValue access inside function body is flagged`() {
    let source = """
      func op(tag: MyTag) {
          let raw = tag.rawValue
          use(raw)
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.count == 1)
    if findings.count == 1 {
      #expect(findings[0].identifier == "raw value access")
    }
  }

  @Test
  func `position access inside function body is flagged`() {
    let source = """
      func op(index: MyIndex) {
          let p = index.position
          use(p)
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.count == 1)
  }
}

extension Lint.Rule.`raw value access Tests`.`Edge Case` {
  @Test
  func `rawValue at top-level type scope is NOT flagged`() {
    // `bodyDepth == 0`: the access sits directly in a stored-property
    // initializer at type scope, outside any function-like body, so the
    // gate exempts it regardless of accessor name.
    let source = """
      struct Foo {
          static let max = MyTag.rawValue
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `rawValue access inside a shorthand computed getter is flagged`() {
    // A short-form getter (`{ tag.rawValue }`, no explicit `get { }`)
    // parses as `AccessorBlockSyntax.getter` — there is no
    // `AccessorDeclSyntax` node. The rule must not depend on which of the
    // two equivalent spellings the author used.
    let source = """
      struct Wrapper {
          var stripped: Int32 { tag.rawValue }
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `rawValue access inside a shorthand subscript getter is flagged`() {
    let source = """
      struct Wrapper {
          subscript(index: Int) -> Int32 { tags[index].rawValue }
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `unrelated member access is NOT flagged`() {
    let source = """
      func op(tag: MyTag) {
          let n = tag.name
          use(n)
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  // Receiver-pattern disambiguation — Swift.enum.rawValue (i.e.,
  // `Type.case.rawValue`) is RawRepresentable territory, not the
  // Tagged-newtype consumer access this rule targets. Per the
  // foundation-up dogfeed (A2), these MUST NOT fire.
  // See Research/2026-05-12-foundation-up-dogfeed-triage.md §A2.

  @Test
  func `Type case rawValue is NOT flagged - enum case access disambiguation`() {
    let source = """
      func op() {
          let s = Visibility.public.rawValue
          use(s)
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `qualified Type case rawValue is NOT flagged`() {
    let source = """
      func op() {
          let s = Lint.Visibility.public.rawValue
          use(s)
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `instance rawValue is still flagged - Tagged consumer access`() {
    // Positive case: the rule's target is Tagged consumer access.
    let source = """
      func op(tag: MyTag) {
          let r = tag.rawValue
          use(r)
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `self tag rawValue is still flagged`() {
    let source = """
      struct Holder {
          var tag: MyTag
          func op() {
              let r = self.tag.rawValue
              use(r)
          }
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.count == 1)
  }
}

// #16 Option C ledger, Entry II.1 (DECISION 2026-07-23): the
// initializer-boundary reserve. The rule's message reserves the flagged
// accessors for "extension initializers (the brand-newtype's own
// boundary)"; the implementation now honors that reserve.
extension Lint.Rule.`raw value access Tests`.`Edge Case` {
  @Test
  func `self rawValue assignment inside declaring init is NOT flagged`() {
    // The swift-iso-9945 `ISO 9945.Kernel.Process.ID` shape.
    let source = """
      public struct ID: RawRepresentable {
          public let rawValue: Int32
          public init(rawValue: Int32) {
              self.rawValue = rawValue
          }
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `brand rawValue consumption inside adapter extension init is NOT flagged`() {
    // The swift-sockets-ip-address `Kernel.Socket.Address.IPv4+IP` shape
    // (#16 Entry III.f): the extension initializer IS the conversion
    // boundary.
    let source = """
      extension Kernel.Socket.Address.IPv4 {
          public init(ip: IPv4.Address, port: UInt16 = 0) {
              let address: UInt32 = ip.rawValue
              self.init(address: address.bigEndian, port: port)
          }
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `rawValue inside a closure nested in an init is still flagged`() {
    // Only the directly-enclosing initializer context is the boundary;
    // a closure inside it is ordinary consumer code.
    let source = """
      struct Holder {
          init(tags: [MyTag]) {
              self.values = tags.map { tag in tag.rawValue }
          }
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `rawValue in ordinary function body is still flagged after II-1`() {
    // Positive control: the consumer-call-site signal is preserved.
    let source = """
      func send(tag: MyTag) {
          transmit(tag.rawValue)
      }
      """
    let findings = Lint.Rule.`raw value access Tests`.findings(in: source)
    #expect(findings.count == 1)
  }
}
