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

@testable import Institute_Linter_Rule_Byte

// MARK: - Helpers

private func findings(
  in source: String,
  rule: Lint.Rule,
  file: String = "test.swift"
) -> [Diagnostic.Record] {
  let parsed = Lint.Source.parsed(from: source, file: file)
  return rule.findings(parsed, .warning)
}

// MARK: - Rule 1: uint8 conforms to byte protocol

extension Lint.Rule {
  @Suite
  struct `uint8 conforms to byte protocol Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
  }
}

extension Lint.Rule.`uint8 conforms to byte protocol Tests`.Unit {
  @Test
  func `extension UInt8 conforming to Byte Protocol is flagged`() {
    let source = """
      extension UInt8: Byte.`Protocol` {}
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 conforms to byte protocol`)
    #expect(result.count == 1)
    if result.count == 1 {
      #expect(result[0].identifier == "uint8 conforms to byte protocol")
    }
  }

  @Test
  func `extension Swift dot UInt8 conforming to Byte Protocol is flagged`() {
    let source = """
      extension Swift.UInt8: Byte.`Protocol` {}
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 conforms to byte protocol`)
    #expect(result.count == 1)
  }

  @Test
  func `extension UInt8 conforming via fully-qualified Byte_Primitives is flagged`() {
    let source = """
      extension UInt8: Byte_Primitives.Byte.`Protocol` {}
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 conforms to byte protocol`)
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`uint8 conforms to byte protocol Tests`.`Edge Case` {
  @Test
  func `extension UInt8 with no Byte Protocol conformance is NOT flagged`() {
    let source = """
      extension UInt8 {
          public var asciiUppercase: UInt8 { self & 0xDF }
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 conforms to byte protocol`)
    #expect(result.isEmpty)
  }

  @Test
  func `extension Byte conforming to Byte Protocol is NOT flagged`() {
    let source = """
      extension Byte: Byte.`Protocol` {}
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 conforms to byte protocol`)
    #expect(result.isEmpty)
  }

  @Test
  func `extension UInt8 conforming to other protocol is NOT flagged`() {
    let source = """
      extension UInt8: Sendable {}
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 conforms to byte protocol`)
    #expect(result.isEmpty)
  }
}

extension Lint.Rule.`uint8 conforms to byte protocol Tests`.Integration {
  @Test
  func `mixed file with one violation flags exactly once`() {
    let source = """
      extension Byte: Byte.`Protocol` {}
      extension UInt8: Byte.`Protocol` {}
      extension Int: Sendable {}
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 conforms to byte protocol`)
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`uint8 conforms to byte protocol Tests`.Performance {
  @Test
  func `large file with no violations runs quickly`() {
    let source = String(repeating: "extension Int: Sendable {}\n", count: 200)
    let result = findings(in: source, rule: Lint.Rule.`uint8 conforms to byte protocol`)
    #expect(result.isEmpty)
  }
}

// MARK: - Rule 2: byte conforms to arithmetic protocol

extension Lint.Rule {
  @Suite
  struct `byte conforms to arithmetic protocol Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
  }
}

extension Lint.Rule.`byte conforms to arithmetic protocol Tests`.Unit {
  @Test
  func `Byte conforming to AdditiveArithmetic is flagged`() {
    let source = """
      extension Byte: AdditiveArithmetic {}
      """
    let result = findings(in: source, rule: Lint.Rule.`byte conforms to arithmetic protocol`)
    #expect(result.count == 1)
  }

  @Test
  func `Byte conforming to Numeric is flagged`() {
    let source = """
      extension Byte: Numeric {}
      """
    let result = findings(in: source, rule: Lint.Rule.`byte conforms to arithmetic protocol`)
    #expect(result.count == 1)
  }

  @Test
  func `Byte conforming to BinaryInteger is flagged`() {
    let source = """
      extension Byte: BinaryInteger {}
      """
    let result = findings(in: source, rule: Lint.Rule.`byte conforms to arithmetic protocol`)
    #expect(result.count == 1)
  }

  @Test
  func `Byte conforming to FixedWidthInteger is flagged`() {
    let source = """
      extension Byte: FixedWidthInteger {}
      """
    let result = findings(in: source, rule: Lint.Rule.`byte conforms to arithmetic protocol`)
    #expect(result.count == 1)
  }

  @Test
  func `Byte conforming to Strideable is flagged`() {
    let source = """
      extension Byte: Strideable {}
      """
    let result = findings(in: source, rule: Lint.Rule.`byte conforms to arithmetic protocol`)
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`byte conforms to arithmetic protocol Tests`.`Edge Case` {
  @Test
  func `Byte conforming to Equatable Hashable Comparable is NOT flagged`() {
    let source = """
      extension Byte: Equatable {}
      extension Byte: Hashable {}
      extension Byte: Comparable {}
      extension Byte: Sendable {}
      extension Byte: Codable {}
      extension Byte: CustomStringConvertible {}
      """
    let result = findings(in: source, rule: Lint.Rule.`byte conforms to arithmetic protocol`)
    #expect(result.isEmpty)
  }

  @Test
  func `UInt8 conforming to BinaryInteger is NOT flagged`() {
    // Rule scoped to Byte; UInt8 already conforms in stdlib.
    let source = """
      extension UInt8: BinaryInteger {}
      """
    let result = findings(in: source, rule: Lint.Rule.`byte conforms to arithmetic protocol`)
    #expect(result.isEmpty)
  }

  @Test
  func `Byte conforming via Swift dot Numeric is flagged`() {
    let source = """
      extension Byte: Swift.Numeric {}
      """
    let result = findings(in: source, rule: Lint.Rule.`byte conforms to arithmetic protocol`)
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`byte conforms to arithmetic protocol Tests`.Integration {
  @Test
  func `multiple arithmetic conformances in one extension fire per-protocol`() {
    let source = """
      extension Byte: AdditiveArithmetic, Numeric {}
      """
    let result = findings(in: source, rule: Lint.Rule.`byte conforms to arithmetic protocol`)
    #expect(result.count == 2)
  }
}

extension Lint.Rule.`byte conforms to arithmetic protocol Tests`.Performance {
  @Test
  func `large file with byte-domain conformances runs quickly`() {
    let source = String(repeating: "extension Byte: Equatable {}\n", count: 200)
    let result = findings(in: source, rule: Lint.Rule.`byte conforms to arithmetic protocol`)
    #expect(result.isEmpty)
  }
}

// MARK: - Rule 3: binary serializable uint8 witness

extension Lint.Rule {
  @Suite
  struct `binary serializable uint8 witness Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
  }
}

extension Lint.Rule.`binary serializable uint8 witness Tests`.Unit {
  @Test
  func `serialize where Buffer Element equals UInt8 is flagged`() {
    let source = """
      extension RFC_791.TypeOfService: Binary.Serializable {
          public static func serialize<Buffer: RangeReplaceableCollection>(
              _ tos: Self, into buffer: inout Buffer
          ) where Buffer.Element == UInt8 {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.count == 1)
  }

  @Test
  func `parse where Source Element equals UInt8 is flagged`() {
    let source = """
      extension RFC_791.Flags: Binary.Parseable {
          public static func parse<Source: Collection>(
              _ source: Source
          ) -> Self where Source.Element == UInt8 { fatalError() }
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.count == 1)
  }

  // Arc G Phase 7 addendum (2026-05-20): default-impl-extension shape.
  // Default impls on `Binary.Serializable` / `Binary.Parseable` are witness
  // implementations too — for any conformer without an override. The rule's
  // gate covers BOTH the conformer-extension shape (above) AND this shape.

  @Test
  func `default-impl on Binary Serializable where Buffer Element equals UInt8 is flagged`() {
    let source = """
      extension Binary.Serializable {
          public func serialize<Buffer: RangeReplaceableCollection>(
              into buffer: inout Buffer
          ) where Buffer.Element == UInt8 {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.count == 1)
  }

  @Test
  func `default-impl on Binary Parseable where Source Element equals UInt8 is flagged`() {
    let source = """
      extension Binary.Parseable {
          public static func parse<Source: Collection>(
              _ source: Source
          ) -> Self where Source.Element == UInt8 { fatalError() }
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.count == 1)
  }

  @Test
  // swiftlint:disable:next function_name_whitespace
  func
    `conditional default-impl on Binary Serializable where Buffer Element equals UInt8 is flagged`()
  {
    let source = """
      extension Binary.Serializable where Self: RawRepresentable {
          public func serialize<Buffer: RangeReplaceableCollection>(
              into buffer: inout Buffer
          ) where Buffer.Element == UInt8 {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`binary serializable uint8 witness Tests`.`Edge Case` {
  @Test
  func `serialize where Buffer Element equals Byte is NOT flagged`() {
    let source = """
      extension RFC_791.TypeOfService: Binary.Serializable {
          public static func serialize<Buffer: RangeReplaceableCollection>(
              _ tos: Self, into buffer: inout Buffer
          ) where Buffer.Element == Byte {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.isEmpty)
  }

  @Test
  func `disfavored UInt8 forwarder in Binary Serializable extension is NOT flagged`() {
    let source = """
      extension RFC_791.TypeOfService: Binary.Serializable {
          @_disfavoredOverload
          public static func serialize<Buffer: RangeReplaceableCollection>(
              _ tos: Self, into buffer: inout Buffer
          ) where Buffer.Element == UInt8 {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.isEmpty)
  }

  @Test
  func `serialize outside Binary Serializable extension is NOT flagged`() {
    let source = """
      extension Array where Element == UInt8 {
          public static func serialize(_ x: Self) where Buffer.Element == UInt8 {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.isEmpty)
  }

  // Arc G Phase 7 addendum (2026-05-20): default-impl-extension shape — negative cases.

  @Test
  func `default-impl on Binary Serializable with Byte where-clause is NOT flagged`() {
    let source = """
      extension Binary.Serializable {
          public func serialize<Buffer: RangeReplaceableCollection>(
              into buffer: inout Buffer
          ) where Buffer.Element == Byte {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.isEmpty)
  }

  @Test
  func `disfavored UInt8 default-impl forwarder on Binary Serializable is NOT flagged`() {
    let source = """
      extension Binary.Serializable {
          @_disfavoredOverload
          public func serialize<Buffer: RangeReplaceableCollection>(
              into buffer: inout Buffer
          ) where Buffer.Element == UInt8 {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.isEmpty)
  }

  @Test
  func `default-impl on Binary Parseable with Byte where-clause is NOT flagged`() {
    let source = """
      extension Binary.Parseable {
          public static func parse<Source: Collection>(
              _ source: Source
          ) -> Self where Source.Element == Byte { fatalError() }
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.isEmpty)
  }
}

extension Lint.Rule.`binary serializable uint8 witness Tests`.Integration {
  @Test
  func `module-qualified Binary Serializable conformance is recognized`() {
    let source = """
      extension Foo: Binary.Serializable {
          public static func serialize<Buffer: RangeReplaceableCollection>(
              _ x: Self, into buffer: inout Buffer
          ) where Buffer.Element == UInt8 {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`binary serializable uint8 witness Tests`.Performance {
  @Test
  func `non-Binary-Serializable extensions skip cheaply`() {
    let source = String(repeating: "extension Foo: Sendable {}\n", count: 200)
    let result = findings(in: source, rule: Lint.Rule.`binary serializable uint8 witness`)
    #expect(result.isEmpty)
  }
}

// MARK: - Rule 4: binary serializable rawvalue uint8

extension Lint.Rule {
  @Suite
  struct `binary serializable rawvalue uint8 Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
  }
}

extension Lint.Rule.`binary serializable rawvalue uint8 Tests`.Unit {
  @Test
  func `struct with rawValue UInt8 conforming on header is flagged`() {
    let source = """
      public struct TypeOfService: Binary.Serializable {
          public let rawValue: UInt8
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable rawvalue uint8`)
    #expect(result.count == 1)
  }

  @Test
  func `struct with rawValue UInt8 with conformance in extension is flagged`() {
    let source = """
      public struct TypeOfService {
          public let rawValue: UInt8
      }
      extension TypeOfService: Binary.Serializable {}
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable rawvalue uint8`)
    #expect(result.count == 1)
  }

  @Test
  func `enum with rawValue UInt8 conforming to Binary Parseable is flagged`() {
    let source = """
      public enum Foo: Binary.Parseable {
          public var rawValue: UInt8 { 0 }
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable rawvalue uint8`)
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`binary serializable rawvalue uint8 Tests`.`Edge Case` {
  @Test
  func `rawValue Byte is NOT flagged`() {
    let source = """
      public struct Flags: Binary.Serializable {
          public let rawValue: Byte
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable rawvalue uint8`)
    #expect(result.isEmpty)
  }

  @Test
  func `rawValue UInt16 is NOT flagged`() {
    let source = """
      public struct HeaderChecksum: Binary.Serializable {
          public let rawValue: UInt16
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable rawvalue uint8`)
    #expect(result.isEmpty)
  }

  @Test
  func `struct with rawValue UInt8 NOT conforming to Binary is NOT flagged`() {
    let source = """
      public struct Foo {
          public let rawValue: UInt8
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable rawvalue uint8`)
    #expect(result.isEmpty)
  }
}

extension Lint.Rule.`binary serializable rawvalue uint8 Tests`.Integration {
  @Test
  func `multiple conformers in one file all flagged`() {
    let source = """
      public struct A: Binary.Serializable { public let rawValue: UInt8 }
      public struct B: Binary.Serializable { public let rawValue: UInt8 }
      public struct C: Binary.Serializable { public let rawValue: Byte }
      """
    let result = findings(in: source, rule: Lint.Rule.`binary serializable rawvalue uint8`)
    #expect(result.count == 2)
  }
}

extension Lint.Rule.`binary serializable rawvalue uint8 Tests`.Performance {
  @Test
  func `large file with no Binary conformers runs quickly`() {
    let source = String(repeating: "public struct X { let x: UInt8 = 0 }\n", count: 200)
    let result = findings(in: source, rule: Lint.Rule.`binary serializable rawvalue uint8`)
    #expect(result.isEmpty)
  }
}

// MARK: - Rule 5: uint8 ascii extension

extension Lint.Rule {
  @Suite
  struct `uint8 ascii extension Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
  }
}

extension Lint.Rule.`uint8 ascii extension Tests`.Unit {
  @Test
  func `extension UInt8 dot ASCII is flagged`() {
    let source = """
      extension UInt8.ASCII {
          public static let lf: UInt8 = 0x0A
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 ascii extension`)
    #expect(result.count == 1)
  }

  @Test
  func `extension UInt8 with static var ascii is flagged`() {
    let source = """
      extension UInt8 {
          public static var ascii: Self { 0 }
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 ascii extension`)
    #expect(result.count == 1)
  }

  @Test
  func `extension UInt8 with nested ASCII enum is flagged`() {
    let source = """
      extension UInt8 {
          public enum ASCII {
              public static let lf: UInt8 = 0x0A
          }
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 ascii extension`)
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`uint8 ascii extension Tests`.`Edge Case` {
  @Test
  func `extension ASCII Code is NOT flagged`() {
    let source = """
      extension ASCII.Code {
          public static let lf: ASCII.Code = 0x0A
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 ascii extension`)
    #expect(result.isEmpty)
  }

  @Test
  func `extension UInt8 with non-ascii members is NOT flagged`() {
    let source = """
      extension UInt8 {
          public static var max: UInt8 { 0xFF }
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 ascii extension`)
    #expect(result.isEmpty)
  }

  @Test
  func `extension Byte dot ASCII is NOT flagged`() {
    let source = """
      extension Byte.ASCII {}
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 ascii extension`)
    #expect(result.isEmpty)
  }
}

extension Lint.Rule.`uint8 ascii extension Tests`.Integration {
  @Test
  func `module-qualified Swift dot UInt8 dot ASCII is flagged`() {
    let source = """
      extension Swift.UInt8.ASCII {}
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 ascii extension`)
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`uint8 ascii extension Tests`.Performance {
  @Test
  func `large file without UInt8 ascii extensions runs quickly`() {
    let source = String(repeating: "extension Foo: Sendable {}\n", count: 200)
    let result = findings(in: source, rule: Lint.Rule.`uint8 ascii extension`)
    #expect(result.isEmpty)
  }
}

// MARK: - Rule 6: uint8 forwarder missing disfavored

extension Lint.Rule {
  @Suite
  struct `uint8 forwarder missing disfavored Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
  }
}

extension Lint.Rule.`uint8 forwarder missing disfavored Tests`.Unit {
  @Test
  func `function in extension on Byte array taking UInt8 is flagged`() {
    let source = """
      extension Array where Element == Byte {
          public func append(_ value: UInt8) {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 forwarder missing disfavored`)
    #expect(result.count == 1)
  }

  @Test
  func `function on bracket-Byte returning UInt8 array is flagged`() {
    let source = """
      extension [Byte] {
          public func raw() -> [UInt8] { [] }
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 forwarder missing disfavored`)
    #expect(result.count == 1)
  }

  @Test
  func `initializer in byte-domain extension taking UInt8 is flagged`() {
    let source = """
      extension Array where Element == Byte {
          public init(byte: UInt8) { self = [] }
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 forwarder missing disfavored`)
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`uint8 forwarder missing disfavored Tests`.`Edge Case` {
  @Test
  func `function with disfavored overload is NOT flagged`() {
    let source = """
      extension Array where Element == Byte {
          @_disfavoredOverload
          public func append(_ value: UInt8) {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 forwarder missing disfavored`)
    #expect(result.isEmpty)
  }

  @Test
  func `Byte-typed function in byte-domain extension is NOT flagged`() {
    let source = """
      extension Array where Element == Byte {
          public func append(_ value: Byte) {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 forwarder missing disfavored`)
    #expect(result.isEmpty)
  }

  @Test
  func `function in non-byte-domain extension taking UInt8 is NOT flagged`() {
    let source = """
      extension Array where Element == Int {
          public func append(_ value: UInt8) {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 forwarder missing disfavored`)
    #expect(result.isEmpty)
  }

  @Test
  func `function in extension on UInt8 array is NOT flagged`() {
    let source = """
      extension Array where Element == UInt8 {
          public func append(_ value: UInt8) {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 forwarder missing disfavored`)
    #expect(result.isEmpty)
  }
}

extension Lint.Rule.`uint8 forwarder missing disfavored Tests`.Integration {
  @Test
  func `multiple UInt8 forwarders are all flagged independently`() {
    let source = """
      extension [Byte] {
          public func one(_ value: UInt8) {}
          public func two(_ value: UInt8) {}
          @_disfavoredOverload
          public func three(_ value: UInt8) {}
      }
      """
    let result = findings(in: source, rule: Lint.Rule.`uint8 forwarder missing disfavored`)
    #expect(result.count == 2)
  }
}

extension Lint.Rule.`uint8 forwarder missing disfavored Tests`.Performance {
  @Test
  func `large file with no byte-domain extensions runs quickly`() {
    let source = String(repeating: "extension Foo { func bar() {} }\n", count: 200)
    let result = findings(in: source, rule: Lint.Rule.`uint8 forwarder missing disfavored`)
    #expect(result.isEmpty)
  }
}

// MARK: - Rule 7: stdlib forwarder outside sli

extension Lint.Rule {
  @Suite
  struct `stdlib forwarder outside sli Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
  }
}

extension Lint.Rule.`stdlib forwarder outside sli Tests`.Unit {
  @Test
  func `disfavored Array UInt8 init in primary module is flagged`() {
    let source = """
      extension Array where Element == UInt8 {
          @_disfavoredOverload
          public init<S: Binary.Serializable>(_ s: S) {
              self = []
          }
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.count == 1)
    if result.count == 1 {
      #expect(result[0].identifier == "stdlib forwarder outside sli")
    }
  }

  @Test
  func `disfavored ContiguousArray UInt8 init in primary module is flagged`() {
    let source = """
      extension ContiguousArray where Element == UInt8 {
          @_disfavoredOverload
          public init<S: Binary.Serializable>(_ s: S) {
              self = []
          }
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.count == 1)
  }

  @Test
  func `disfavored Swift Array explicit qualifier UInt8 init in primary module is flagged`() {
    let source = """
      extension Swift.Array where Element == UInt8 {
          @_disfavoredOverload
          public init<S: Binary.Serializable>(_ s: S) {
              self = []
          }
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.count == 1)
  }

  @Test
  func `disfavored RangeReplaceableCollection UInt8 append in primary module is flagged`() {
    let source = """
      extension RangeReplaceableCollection where Element == UInt8 {
          @_disfavoredOverload
          public mutating func append<S: Binary.Serializable>(_ s: S) {}
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`stdlib forwarder outside sli Tests`.`Edge Case` {
  @Test
  func `disfavored Array UInt8 in Standard Library Integration module is NOT flagged`() {
    let source = """
      extension Array where Element == UInt8 {
          @_disfavoredOverload
          public init<S: Binary.Serializable>(_ s: S) {
              self = []
          }
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo Standard Library Integration/Bar.swift"
    )
    #expect(result.isEmpty)
  }

  @Test
  func `Array UInt8 init without disfavoredOverload is NOT flagged`() {
    let source = """
      extension Array where Element == UInt8 {
          public init<S: Binary.Serializable>(_ s: S) {
              self = []
          }
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.isEmpty)
  }

  @Test
  func `disfavored Array Byte function without UInt8 surface is NOT flagged`() {
    let source = """
      extension Array where Element == Byte {
          @_disfavoredOverload
          public func bar(_ value: Byte) {}
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.isEmpty)
  }

  @Test
  func `extension on institute type Byte Input with disfavored UInt8 init is NOT flagged`() {
    // [API-BYTE-007] scope: only extensions on STDLIB types belong in SLI.
    // Extensions on institute types (Byte.Input here) that take UInt8 as
    // a stdlib-bridge convenience legitimately live in the primary module.
    let source = """
      extension Byte.Input {
          @_disfavoredOverload
          public init<Bytes: Swift.Collection>(_ bytes: Bytes) where Bytes.Element == UInt8 {
              self.init(Swift.Array(bytes))
          }
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.isEmpty)
  }

  @Test
  func `extension on institute type Foo with disfavored UInt8 ArraySlice init is NOT flagged`() {
    let source = """
      extension Foo {
          @_disfavoredOverload
          public init(_ bytes: ArraySlice<UInt8>) {}
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.isEmpty)
  }

  @Test
  func `extension on RFC namespaced type with disfavored UInt8 init is NOT flagged`() {
    let source = """
      extension RFC_4122.UUID {
          @_disfavoredOverload
          public init(_ data: [UInt8]) {}
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.isEmpty)
  }

  @Test
  func `disfavored Array UInt8 init with Optional in primary module is flagged`() {
    let source = """
      extension Array where Element == UInt8? {
          @_disfavoredOverload
          public init<S: Binary.Serializable>(_ s: S) {
              self = []
          }
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.count == 1)
  }

  @Test
  func `top-level disfavored UInt8 function is NOT flagged`() {
    // Not inside an extension at all — rule scope is extensions only.
    let source = """
      @_disfavoredOverload
      public func bar(_ value: UInt8) {}
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.isEmpty)
  }
}

extension Lint.Rule.`stdlib forwarder outside sli Tests`.Integration {
  @Test
  func `multiple disfavored UInt8 forwarders in stdlib type extension are all flagged`() {
    let source = """
      extension Array where Element == UInt8 {
          @_disfavoredOverload
          public init<S: Binary.Serializable>(_ s: S) { self = [] }
          @_disfavoredOverload
          public func bytes() -> [UInt8] { [] }
          public func unrelated() {}
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.count == 2)
  }

  @Test
  func `mixed primary and SLI fixtures separate independently`() {
    // Each `findings(...)` call is independent — this test confirms the
    // module-detection logic doesn't leak between calls.
    let primarySource = """
      extension Array where Element == UInt8 {
          @_disfavoredOverload
          public init<S: Binary.Serializable>(_ s: S) { self = [] }
      }
      """
    let primary = findings(
      in: primarySource,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    let sli = findings(
      in: primarySource,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo Standard Library Integration/Bar.swift"
    )
    #expect(primary.count == 1)
    #expect(sli.isEmpty)
  }

  @Test
  func `mixed institute and stdlib extensions in same file fire selectively`() {
    // [API-BYTE-007] scope discrimination: only the stdlib-type extension fires.
    let source = """
      extension Byte.Input {
          @_disfavoredOverload
          public init(_ bytes: ArraySlice<UInt8>) {}
      }
      extension Array where Element == UInt8 {
          @_disfavoredOverload
          public init<S: Binary.Serializable>(_ s: S) { self = [] }
      }
      """
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.count == 1)
  }
}

extension Lint.Rule.`stdlib forwarder outside sli Tests`.Performance {
  @Test
  func `large file with no disfavored UInt8 surfaces runs quickly`() {
    let source = String(repeating: "extension Foo { func bar() {} }\n", count: 200)
    let result = findings(
      in: source,
      rule: Lint.Rule.`stdlib forwarder outside sli`,
      file: "/pkg/Sources/Foo/Bar.swift"
    )
    #expect(result.isEmpty)
  }
}
