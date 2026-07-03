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

@testable import Institute_Linter_Rule_Naming

extension Lint.Rule {
  @Suite
  struct `phantom suppression Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
  }
}

extension Lint.Rule.`phantom suppression Tests` {
  static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`phantom suppression`.findings(parsed, .warning)
  }
}

extension Lint.Rule.`phantom suppression Tests`.Unit {
  @Test
  func `extension Tagged where Tag is ~Copyable-only is flagged`() {
    let source = """
      extension Tagged where Underlying == Ordinal, Tag: ~Copyable {
          public var probe: Int { 0 }
      }
      """
    let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
    #expect(findings.count == 1)
    if findings.count == 1 {
      #expect(findings[0].identifier == "phantom suppression")
      #expect(findings[0].severity == .warning)
    }
  }

  @Test
  func `init generic Tag used as Tagged discriminator is flagged`() {
    let source = """
      extension Int {
          public init<Tag: ~Copyable>(_ x: Tagged<Tag, Ordinal>) { self = 0 }
      }
      """
    let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `typealias Index phantom Element is flagged`() {
    let source = "public typealias Index<Element: ~Copyable> = Tagged<Element, Ordinal>"
    let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `extension Property where Tag is ~Copyable-only is flagged`() {
    let source = """
      extension Property where Tag: ~Copyable {
          public var probe: Int { 0 }
      }
      """
    let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
    #expect(findings.count == 1)
  }
}

extension Lint.Rule.`phantom suppression Tests`.`Edge Case` {
  @Test
  func `already-maximal ~Copyable and ~Escapable is NOT flagged`() {
    let source = """
      extension Tagged where Underlying == Ordinal, Tag: ~Copyable & ~Escapable {
          public var probe: Int { 0 }
      }
      """
    let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `stored Element parameter is NOT flagged`() {
    // Element is the stored payload (Array element), not a phantom discriminator.
    let source = """
      extension Sequence {
          public func collect<Element: ~Copyable>(_ x: [Element]) {}
      }
      """
    let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `param both phantom and stored is conservatively NOT flagged`() {
    // Tag is used as a Tagged discriminator AND as a by-value parameter — the
    // rule never warns when the param appears in any stored position.
    let source = """
      extension Int {
          public init<Tag: ~Copyable>(_ x: Tagged<Tag, Ordinal>, raw: Tag) { self = 0 }
      }
      """
    let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `extension of a non-wrapper type is NOT flagged`() {
    let source = """
      extension MyContainer where Element: ~Copyable {
          public var probe: Int { 0 }
      }
      """
    let findings = Lint.Rule.`phantom suppression Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }
}
