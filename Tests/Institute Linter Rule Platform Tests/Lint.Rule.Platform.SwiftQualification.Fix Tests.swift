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

@testable import Institute_Linter_Rule_Platform

extension Lint.Rule {
  @Suite
  struct `swift protocol qualification fix Tests` {
    @Suite struct `Round Trip` {}
    @Suite struct `Not Fixable` {}
  }
}

extension Lint.Rule.`swift protocol qualification fix Tests` {
  static func fixed(_ source: String, file: String = "test.swift") -> String? {
    let parsed = Lint.Source.parsed(from: source, file: file)
    guard let fix = Lint.Rule.`swift protocol qualification`.fix else { return nil }
    return fix(parsed)
  }

  static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`swift protocol qualification`.findings(parsed, .warning)
  }

  /// The self-round-trip property: flagged before, rewritten, parses, and
  /// silent afterwards.
  static func roundTrips(
    _ source: String,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
  ) {
    #expect(
      !findings(in: source).isEmpty,
      "fixture must fire before it can round-trip",
      sourceLocation: sourceLocation
    )
    guard let output = fixed(source) else {
      Issue.record("expected a rewrite", sourceLocation: sourceLocation)
      return
    }
    #expect(
      !Parser.parse(source: output).hasError,
      "rewrite must parse: \(output)",
      sourceLocation: sourceLocation
    )
    #expect(
      findings(in: output).isEmpty,
      "rewrite must re-lint clean: \(output)",
      sourceLocation: sourceLocation
    )
  }
}

extension Lint.Rule.`swift protocol qualification fix Tests`.`Round Trip` {
  @Test
  func `a generic parameter constraint is qualified`() {
    let source = """
      func op<E: Error>(_ error: E) {}
      """
    Lint.Rule.`swift protocol qualification fix Tests`.roundTrips(source)
    let output = Lint.Rule.`swift protocol qualification fix Tests`.fixed(source)
    #expect(output?.contains("<E: Swift.Error>") == true)
  }

  @Test
  func `an opaque parameter constraint is qualified with its generic argument`() {
    let source = """
      func op(_ bytes: some Sequence<UInt8>) {}
      """
    Lint.Rule.`swift protocol qualification fix Tests`.roundTrips(source)
    #expect(
      Lint.Rule.`swift protocol qualification fix Tests`
        .fixed(source)?.contains("some Swift.Sequence<UInt8>") == true
    )
  }

  @Test
  func `an inherited type is qualified`() {
    let source = """
      struct Bag: Collection {}
      """
    Lint.Rule.`swift protocol qualification fix Tests`.roundTrips(source)
    let output = Lint.Rule.`swift protocol qualification fix Tests`.fixed(source)
    #expect(output?.contains(": Swift.Collection") == true)
  }

  @Test
  func `a where-clause conformance requirement is qualified`() {
    let source = """
      func op<T>(_ value: T) where T: Sequence {}
      """
    Lint.Rule.`swift protocol qualification fix Tests`.roundTrips(source)
  }

  @Test
  func `every leaf of a composition is qualified`() {
    let source = """
      func op<T: Sequence & Collection>(_ value: T) {}
      """
    Lint.Rule.`swift protocol qualification fix Tests`.roundTrips(source)
    let output = Lint.Rule.`swift protocol qualification fix Tests`.fixed(source)
    #expect(output?.contains("Swift.Sequence & Swift.Collection") == true)
  }

  @Test
  func `surrounding text is preserved verbatim`() {
    let source = """
      /// Doc comment.
      public func op<E: Error>(_ error: E) -> Swift.Bool {
          return true
      }
      """
    let output = Lint.Rule.`swift protocol qualification fix Tests`.fixed(source)
    #expect(output?.contains("/// Doc comment.\n") == true)
    #expect(output?.contains("    return true\n") == true)
  }
}

extension Lint.Rule.`swift protocol qualification fix Tests`.`Not Fixable` {
  @Test
  func `an already-qualified reference is not rewritten`() {
    let source = """
      func op<E: Swift.Error>(_ error: E) {}
      """
    #expect(Lint.Rule.`swift protocol qualification fix Tests`.findings(in: source).isEmpty)
    #expect(Lint.Rule.`swift protocol qualification fix Tests`.fixed(source) == nil)
  }

  @Test
  func `an extension on a stdlib type keeps the exemption`() {
    // [RULE-EXEMPT-6] (stdlib-shadow): inside `extension Array`, the
    // qualified form does not resolve, so writing it would turn a warning
    // into a compile error. The rule does not fire, and the fix must not
    // fire either — the two must agree on every input.
    let source = """
      extension Array {
          func op<E: Error>(_ error: E) {}
      }
      """
    #expect(Lint.Rule.`swift protocol qualification fix Tests`.findings(in: source).isEmpty)
    #expect(Lint.Rule.`swift protocol qualification fix Tests`.fixed(source) == nil)
  }
}
