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
  struct `extension file discriminator Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
  }
}

extension Lint.Rule.`extension file discriminator Tests` {
  static func findings(
    in source: Swift.String,
    file: Swift.String
  ) -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`extension file discriminator`.findings(parsed, .warning)
  }
}

extension Lint.Rule.`extension file discriminator Tests`.Unit {
  @Test
  func `pure extension file without discriminator is flagged`() {
    let findings = Lint.Rule.`extension file discriminator Tests`.findings(
      in: "extension Foo { var value: Int { 0 } }",
      file: "Sources/Foo/Foo.swift"
    )
    #expect(findings.count == 1)
    #expect(findings.first?.identifier == "extension file discriminator")
    #expect(findings.first?.severity == .warning)
  }

  @Test
  func `plus conformance discriminator is permitted`() {
    let findings = Lint.Rule.`extension file discriminator Tests`.findings(
      in: "extension Foo: Sequence {}",
      file: "Sources/Foo/Foo+Sequence.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `where specialization discriminator is permitted`() {
    let findings = Lint.Rule.`extension file discriminator Tests`.findings(
      in: "extension Carrier where Underlying == Self {}",
      file: "Sources/Carrier/Carrier where Underlying == Self.swift"
    )
    #expect(findings.isEmpty)
  }
}

extension Lint.Rule.`extension file discriminator Tests`.`Edge Case` {
  @Test
  func `nested type declaration makes file type-declaring`() {
    let source = """
      extension Namespace {
        struct Value {}
      }
      """
    let findings = Lint.Rule.`extension file discriminator Tests`.findings(
      in: source,
      file: "Sources/Namespace/Namespace.Value.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `top-level typealias makes file type-declaring`() {
    let source = """
      typealias Value = Namespace.Value
      extension Namespace.Value {}
      """
    let findings = Lint.Rule.`extension file discriminator Tests`.findings(
      in: source,
      file: "Sources/Namespace/Value.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `top-level function makes file mixed rather than pure extension`() {
    let source = """
      func fixture() {}
      extension Namespace.Value {}
      """
    let findings = Lint.Rule.`extension file discriminator Tests`.findings(
      in: source,
      file: "Sources/Namespace/Value.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `source conformance does not replace filename discriminator`() {
    let findings = Lint.Rule.`extension file discriminator Tests`.findings(
      in: "extension Foo: Sequence {}",
      file: "Sources/Foo/Foo.swift"
    )
    #expect(findings.count == 1)
  }
}

extension Lint.Rule.`extension file discriminator Tests`.Integration {
  @Test
  func `build-system and excluded-tree paths are exempt`() {
    let exports = Lint.Rule.`extension file discriminator Tests`.findings(
      in: "extension Dependency {}",
      file: "Sources/Product/exports.swift"
    )
    let examples = Lint.Rule.`extension file discriminator Tests`.findings(
      in: "extension Demo {}",
      file: "Sources/Product/Examples/Demo.swift"
    )
    #expect(exports.isEmpty)
    #expect(examples.isEmpty)
  }

  @Test
  func `self-firing control catches an undiscriminated rule extension file`() {
    let findings = Lint.Rule.`extension file discriminator Tests`.findings(
      in: "extension Lint.Rule { static let fixture = 0 }",
      file: "Sources/Rules/LintRuleExtension.swift"
    )
    #expect(findings.count == 1)
  }
}
