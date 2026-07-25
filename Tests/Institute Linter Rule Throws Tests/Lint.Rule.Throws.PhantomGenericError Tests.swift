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

@testable import Institute_Linter_Rule_Throws

extension Lint.Rule {
  @Suite
  struct `phantom generic error in typed throws Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    /// Reduced forms of the four real manifestations of swiftlang/swift#89617,
    /// each in BOTH its pre-fix and post-fix shape. The pre-fix forms must fire
    /// (a clean run over them is a broken predicate, not a clean ecosystem —
    /// same medicine as `Lint.Rule.Foundation.Import`'s named
    /// `@_exported import` tests); the post-fix forms must NOT, or the rule
    /// punishes the four packages that already did the right thing.
    @Suite struct Integration {}
  }
}

extension Lint.Rule.`phantom generic error in typed throws Tests` {
  static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic
    .Record]
  {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`phantom generic error in typed throws`.findings(parsed, .warning)
  }
}

// MARK: - Unit

extension Lint.Rule.`phantom generic error in typed throws Tests`.Unit {
  @Test
  func `phantom Error nested in generic struct is flagged`() {
    let source = """
      public struct Parse<Input> {
          public enum Error: Swift.Error {
              case expectedPeriod
          }
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    let count = findings.count
    #expect(count == 1)
    if count == 1 {
      #expect(findings[0].identifier == "phantom generic error in typed throws")
      #expect(findings[0].severity == .warning)
    }
  }

  @Test
  func `phantom Error in extension of same-file generic type is flagged`() {
    let source = """
      public struct Parse<Input> {}
      extension Parse {
          public enum Error: Swift.Error {
              case emptySegment
          }
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `typealias Failure naming a generic-argument-bearing Error is flagged`() {
    // Detector B: the enum itself lives in another file.
    let source = """
      extension RFC_9110.Parse.Token: Parser.`Protocol` {
          public typealias Failure = RFC_9110.Parse.Token<Input>.Error
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `throws clause naming a generic-argument-bearing Error is flagged`() {
    let source = "func op<Input>() throws(Parse<Input>.Error) {}"
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `transitively phantom case is flagged`() {
    // `Input` appears, but ONLY inside another type's generic arguments, so the
    // payload is itself a phantom error. This is the swift-iso-8601
    // Interval/RecurringInterval shape that a naive "body mentions the
    // parameter" test drops.
    let source = """
      public struct Parse<Input> {
          public enum Error: Swift.Error {
              case dateTimeError(DateTime.Parse<Input>.Error)
              case expectedSlash
          }
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `Failure-named phantom enum is flagged`() {
    let source = """
      public struct Parse<Input> {
          public enum Failure: Swift.Error {
              case bad
          }
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.count == 1)
  }
}

// MARK: - Edge Case

extension Lint.Rule.`phantom generic error in typed throws Tests`.`Edge Case` {
  @Test
  func `genuinely generic Error using the parameter is NOT flagged`() {
    let source = """
      public struct Parse<Input> {
          public enum Error: Swift.Error {
              case unexpected(Input)
          }
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `Error nested in a NON-generic type is NOT flagged`() {
    let source = """
      public struct Parse {
          public enum Error: Swift.Error {
              case expectedPeriod
          }
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `caseless namespace enum in a generic type is NOT flagged`() {
    // `Parser<Input>.Consume` and friends are namespaces, not error types.
    // Without the has-cases guard these dominate the findings.
    let source = """
      public struct Parser<Input> {
          public enum Error {}
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `enum with its own generic parameter is NOT flagged`() {
    let source = """
      public struct Parse<Input> {
          public enum Error<T>: Swift.Error {
              case bad(T)
          }
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `non-error nested enum is NOT flagged`() {
    let source = """
      public struct Lexer<Input> {
          internal enum State {
              case initial
          }
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `non-generic Error path in a throws clause is NOT flagged`() {
    let source = "func op() throws(Parse.Error) {}"
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `extension of a generic type NOT declared in this file is not resolvable`() {
    // Documents the known per-file limitation: with no declaration of `Parse`
    // in this file, the declaration-site detector cannot know it is generic.
    // The use-site detector is what covers this case in practice.
    let source = """
      extension Some.Other.Parse {
          public enum Error: Swift.Error {
              case bad
          }
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `both detectors on one type report once, not twice`() {
    let source = """
      public struct Parse<Input> {
          public enum Error: Swift.Error {
              case expectedPeriod
          }
      }
      extension Parse {
          public typealias Failure = Parse<Input>.Error
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.count == 1)
  }
}

// MARK: - Integration: the four real manifestations, pre-fix and post-fix

extension Lint.Rule.`phantom generic error in typed throws Tests`.Integration {
  @Test
  func `swift-rfc-7519 pre-fix shape is flagged`() {
    let source = """
      extension RFC_7519.JWT {
          public struct Parse<Input: Collection.Slice.`Protocol`>: Sendable {}
      }
      extension RFC_7519.JWT.Parse {
          public enum Error: Swift.Error, Sendable, Equatable {
              case expectedPeriod
              case emptySegment
          }
      }
      extension RFC_7519.JWT.Parse: Parser.`Protocol` {
          public typealias Failure = RFC_7519.JWT.Parse<Input>.Error
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `swift-rfc-7519 post-fix shape is NOT flagged`() {
    let source = """
      public enum __JWTParserError: Swift.Error, Sendable, Equatable {
          case expectedPeriod
          case emptySegment
      }
      extension RFC_7519.JWT.Parse {
          public typealias Error = __JWTParserError
      }
      extension RFC_7519.JWT.Parse: Parser.`Protocol` {
          public typealias Failure = __JWTParserError
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `swift-iso-8601 split-file pre-fix shape is flagged at the use site`() {
    // The enum lives in ISO_8601.DateTime.Parse.Error.swift; this is the
    // parser file, which is where the phantom spelling is visible.
    let source = """
      extension ISO_8601.DateTime {
          public struct Parse<Input>: Sendable {}
      }
      extension ISO_8601.DateTime.Parse: Parser.`Protocol` {
          public typealias Failure = ISO_8601.DateTime.Parse<Input>.Error
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `swift-iso-8601 post-fix shape is NOT flagged`() {
    let source = """
      extension ISO_8601.DateTime {
          public struct Parser<Input>: Sendable {}
      }
      extension ISO_8601.DateTime.Parser: Parser.`Protocol` {
          public typealias Failure = __DateTimeParserError
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `swift-w3c-xml pre-fix shape with BARE throws is flagged`() {
    // w3c-xml spells its throws clauses `throws(Error)` — no generic arguments
    // anywhere — so ONLY the declaration-site detector catches it. Deleting
    // that detector silently re-opens this manifestation.
    let source = """
      extension W3C_XML {
          public struct Lexer<Input>: ~Copyable {
              public enum Error: Swift.Error, Sendable, Hashable {
                  case invalidCharacter
                  case unexpectedEndOfInput
              }
              public mutating func next() throws(Error) -> W3C_XML.Token? { nil }
          }
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `swift-w3c-xml post-fix shape is NOT flagged`() {
    let source = """
      public enum __W3CXMLLexerError: Swift.Error, Sendable, Hashable {
          case invalidCharacter
      }
      extension W3C_XML {
          public struct Lexer<Input>: ~Copyable {
              public typealias Error = __W3CXMLLexerError
              public mutating func next() throws(Error) -> W3C_XML.Token? { nil }
          }
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `Digit fixture pre-fix shape is flagged`() {
    let source = """
      struct Digit<Input: Collection.Slice.`Protocol`>: Sendable {
          enum Error: Swift.Error, Sendable, Equatable {
              case expectedDigit
          }
      }
      extension Digit: Parser.`Protocol` {
          typealias Failure = Digit<Input>.Error
      }
      """
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `Digit fixture post-fix shape is NOT flagged`() {
    let source = """
      enum __DigitError: Swift.Error, Sendable, Equatable {
          case expectedDigit
      }
      struct Digit<Input: Collection.Slice.`Protocol`>: Sendable {}
      extension Digit { typealias Error = __DigitError }
      extension Digit: Parser.`Protocol` {
          typealias Failure = Digit<Input>.Error
      }
      """
    // This post-fix form still SPELLS `Digit<Input>.Error`. The alias makes it
    // resolve to a non-generic type — no crash — but the spelling is stale, so
    // the use-site detector fires with the use-site message, whose remedy is
    // "name the hoisted type directly", not "hoist it". Measured on the real
    // ecosystem: 4 such residuals survive remediation (swift-iso-8601's
    // Duration / Interval / RecurringInterval, swift-w3c-xml's Parser.fragment),
    // and swift-iso-8601 is internally inconsistent — its DateTime parser
    // already spells `typealias Failure = __DateTimeParserError`. Recorded, not
    // silently tolerated.
    let findings = Lint.Rule.`phantom generic error in typed throws Tests`.findings(in: source)
    #expect(findings.count == 1)
  }
}
