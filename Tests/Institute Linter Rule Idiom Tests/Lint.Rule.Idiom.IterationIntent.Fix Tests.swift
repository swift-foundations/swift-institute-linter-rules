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

@testable import Institute_Linter_Rule_Idiom

extension Lint.Rule {
  @Suite
  struct `counter loop iteration fix Tests` {
    @Suite struct `Round Trip` {}
    @Suite struct `Not Fixable` {}
  }
}

extension Lint.Rule.`counter loop iteration fix Tests` {
  /// The rewritten text, or `nil` when the rule declines to rewrite.
  static func fixed(_ source: String, file: String = "test.swift") -> String? {
    let parsed = Lint.Source.parsed(from: source, file: file)
    guard let fix = Lint.Rule.`counter loop iteration`.fix else { return nil }
    return fix(parsed)
  }

  /// Findings the rule reports for `source`.
  static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`counter loop iteration`.findings(parsed, .warning)
  }

  /// Asserts the self-round-trip property: `source` is flagged, the fix
  /// rewrites it, the rewrite parses without error, and re-linting the
  /// rewrite reports nothing for this rule.
  ///
  /// This is the whole contract a rewriter-backed rule owes the engine. A
  /// fix that produced unparseable text would be refused at run time; a fix
  /// whose output still fires would loop the fleet forever.
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

extension Lint.Rule.`counter loop iteration fix Tests`.`Round Trip` {
  @Test
  func `half-open counter loop climbs to forEach`() {
    let source = """
      func op(_ items: [Int]) {
          for i in 0..<items.count {
              handle(items[i])
          }
      }
      """
    Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
    #expect(
      Lint.Rule.`counter loop iteration fix Tests`
        .fixed(source)?.contains("(0..<items.count).forEach { i in") == true
    )
  }

  @Test
  func `closed counter loop climbs to forEach`() {
    let source = """
      func op(_ first: Int, _ last: Int) {
          for byte in first...last {
              consume(byte)
          }
      }
      """
    Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
  }

  @Test
  func `reversed range needs no second parenthesis`() {
    let source = """
      func op(_ n: Int) {
          for index in (0..<n).reversed() {
              process(index)
          }
      }
      """
    Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
    #expect(
      Lint.Rule.`counter loop iteration fix Tests`.fixed(source)?.contains("((0..<n)") == false
    )
  }

  @Test
  func `a multi-statement body is carried over verbatim`() {
    let source = """
      func op(_ n: Int) {
          for index in 0..<n {
              let doubled = index * 2
              record(doubled)
          }
      }
      """
    Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
    let output = Lint.Rule.`counter loop iteration fix Tests`.fixed(source)
    #expect(output?.contains("let doubled = index * 2") == true)
    #expect(output?.contains("record(doubled)") == true)
  }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable` {
  /// Asserts the rule still fires but declines to rewrite — the loop stays
  /// a finding for a person to restructure.
  static func declines(
    _ source: String,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
  ) {
    #expect(
      !Lint.Rule.`counter loop iteration fix Tests`.findings(in: source).isEmpty,
      sourceLocation: sourceLocation
    )
    #expect(
      Lint.Rule.`counter loop iteration fix Tests`.fixed(source) == nil,
      sourceLocation: sourceLocation
    )
  }

  @Test
  func `a body containing break is left alone`() {
    Self.declines(
      """
      func op(_ n: Int) {
          for index in 0..<n {
              if done(index) { break }
              process(index)
          }
      }
      """
    )
  }

  @Test
  func `a body containing continue is left alone`() {
    Self.declines(
      """
      func op(_ n: Int) {
          for index in 0..<n {
              if skip(index) { continue }
              process(index)
          }
      }
      """
    )
  }

  @Test
  func `a body containing return is left alone`() {
    Self.declines(
      """
      func op(_ n: Int) -> Int? {
          for index in 0..<n {
              if match(index) { return index }
          }
          return nil
      }
      """
    )
  }

  @Test
  func `a body containing try is left alone`() {
    Self.declines(
      """
      func op(_ n: Int) throws {
          for index in 0..<n {
              try process(index)
          }
      }
      """
    )
  }

  @Test
  func `a body containing await is left alone`() {
    Self.declines(
      """
      func op(_ n: Int) async {
          for index in 0..<n {
              await process(index)
          }
      }
      """
    )
  }

  @Test
  func `a where clause is left alone`() {
    Self.declines(
      """
      func op(_ n: Int) {
          for index in 0..<n where index.isMultiple(of: 2) {
              process(index)
          }
      }
      """
    )
  }

  @Test
  func `a labelled loop is left alone`() {
    Self.declines(
      """
      func op(_ n: Int) {
          outer: for index in 0..<n {
              process(index)
          }
      }
      """
    )
  }

  @Test
  func `a typed-throws loop neither fires nor is rewritten`() {
    let source = """
      func op(_ n: Int) throws(Failure) {
          for index in 0..<n {
              try process(index)
          }
      }
      """
    #expect(Lint.Rule.`counter loop iteration fix Tests`.findings(in: source).isEmpty)
    #expect(Lint.Rule.`counter loop iteration fix Tests`.fixed(source) == nil)
  }

  @Test
  func `a non-range loop is not touched`() {
    let source = """
      func op(_ items: [Int]) {
          for item in items {
              handle(item)
          }
      }
      """
    #expect(Lint.Rule.`counter loop iteration fix Tests`.findings(in: source).isEmpty)
    #expect(Lint.Rule.`counter loop iteration fix Tests`.fixed(source) == nil)
  }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Round Trip` {
  @Test
  func `a single-line body climbs too`() {
    let source = """
      func op(_ n: Int) {
          var sum = 0
          for i in 0..<n { sum += i }
      }
      """
    Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
  }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable` {
  @Test
  func `a loop in a builder-attributed body is not rewritten`() {
    let source = """
      struct Page {
          @ViewBuilder
          func rows(_ n: Int) -> Body {
              for i in 0..<n {
                  Row(i)
              }
          }
      }
      """
    Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable`.declines(source)
  }

  @Test
  func `a loop in an opaque-result body is not rewritten`() {
    let source = """
      struct Page {
          var body: some View {
              for i in 0..<count {
                  Row(i)
              }
          }
      }
      """
    Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable`.declines(source)
  }

  @Test
  func `a loop in a bare trailing closure is not rewritten`() {
    let source = """
      func page(_ n: Int) {
          Stack(.vertical) {
              for i in 0..<n {
                  Row(i)
              }
          }
      }
      """
    Lint.Rule.`counter loop iteration fix Tests`.`Not Fixable`.declines(source)
  }
}

extension Lint.Rule.`counter loop iteration fix Tests`.`Round Trip` {
  @Test
  func `a loop in a plain closure inside a builder body still climbs`() {
    let source = """
      struct Page {
          @ViewBuilder
          func rows(_ n: Int) -> Body {
              Row(measure { size in
                  for i in 0..<n {
                      size.widen(i)
                  }
              })
          }
      }
      """
    Lint.Rule.`counter loop iteration fix Tests`.roundTrips(source)
  }
}
