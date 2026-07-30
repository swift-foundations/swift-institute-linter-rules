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

@testable import Institute_Linter_Rule_Testing

extension Lint.Rule {
  @Suite
  struct `test file suffix Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
  }
}

extension Lint.Rule.`test file suffix Tests` {
  static func findings(file: Swift.String) -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(
      from: "@Test func `fixture`() {}",
      file: file
    )
    return Lint.Rule.`test file suffix`.findings(parsed, .warning)
  }
}

extension Lint.Rule.`test file suffix Tests`.Unit {
  @Test
  func `joined Tests suffix is flagged`() {
    let findings = Lint.Rule.`test file suffix Tests`.findings(
      file: "Tests/File Tests/FileDirectoryTests.swift"
    )
    #expect(findings.count == 1)
    #expect(findings.first?.identifier == "test file suffix")
    #expect(findings.first?.severity == .warning)
  }

  @Test
  func `space-separated Tests suffix is permitted`() {
    let findings = Lint.Rule.`test file suffix Tests`.findings(
      file: "Tests/File Tests/File.Directory Tests.swift"
    )
    #expect(findings.isEmpty)
  }
}

extension Lint.Rule.`test file suffix Tests`.`Edge Case` {
  @Test
  func `dot-separated Tests suffix remains nonconforming`() {
    let findings = Lint.Rule.`test file suffix Tests`.findings(
      file: "Tests/File Tests/File.Directory.Tests.swift"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `helper filename not ending in Tests is outside the predicate`() {
    let findings = Lint.Rule.`test file suffix Tests`.findings(
      file: "Tests/File Tests/Fixture.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `plus and where extension test files are exempt`() {
    let plus = Lint.Rule.`test file suffix Tests`.findings(
      file: "Tests/File Tests/File+SequenceTests.swift"
    )
    let constrained = Lint.Rule.`test file suffix Tests`.findings(
      file: "Tests/File Tests/File where Value == IntTests.swift"
    )
    #expect(plus.isEmpty)
    #expect(constrained.isEmpty)
  }
}

extension Lint.Rule.`test file suffix Tests`.Integration {
  @Test
  func `Support Fixtures and non-Test paths are exempt`() {
    let support = Lint.Rule.`test file suffix Tests`.findings(
      file: "Tests/Support/SupportTests.swift"
    )
    let fixtures = Lint.Rule.`test file suffix Tests`.findings(
      file: "Tests/File Tests/Fixtures/FixtureTests.swift"
    )
    let source = Lint.Rule.`test file suffix Tests`.findings(
      file: "Sources/File/FileTests.swift"
    )
    #expect(support.isEmpty)
    #expect(fixtures.isEmpty)
    #expect(source.isEmpty)
  }

  @Test
  func `self-firing control catches the legacy joined suffix`() {
    let findings = Lint.Rule.`test file suffix Tests`.findings(
      file: "Tests/Linter Tests/TestFileSuffixTests.swift"
    )
    #expect(findings.count == 1)
  }
}
