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
  struct `source file type path Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
  }
}

extension Lint.Rule.`source file type path Tests` {
  static func findings(
    in source: Swift.String,
    file: Swift.String
  ) -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`source file type path`.findings(parsed, .warning)
  }
}

extension Lint.Rule.`source file type path Tests`.Unit {
  @Test
  func `compound basename without matching declaration is flagged`() {
    let findings = Lint.Rule.`source file type path Tests`.findings(
      in: "struct Walk {}",
      file: "Sources/File System/FileDirectoryWalk.swift"
    )
    #expect(findings.count == 1)
    #expect(findings.first?.identifier == "source file type path")
    #expect(findings.first?.severity == .warning)
  }

  @Test
  func `matching top-level declaration is permitted`() {
    let findings = Lint.Rule.`source file type path Tests`.findings(
      in: "struct FileDirectoryWalk {}",
      file: "Sources/File System/FileDirectoryWalk.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `matching top-level extension target is permitted`() {
    let findings = Lint.Rule.`source file type path Tests`.findings(
      in: "extension FileDirectoryWalk { var value: Int { 0 } }",
      file: "Sources/File System/FileDirectoryWalk.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `matching typealias declaration is permitted`() {
    let findings = Lint.Rule.`source file type path Tests`.findings(
      in: "typealias FileDirectoryWalk = File.Directory.Walk",
      file: "Sources/File System/FileDirectoryWalk.swift"
    )
    #expect(findings.isEmpty)
  }
}

extension Lint.Rule.`source file type path Tests`.`Edge Case` {
  @Test
  func `dotted nested type path is outside the narrow candidate set`() {
    let findings = Lint.Rule.`source file type path Tests`.findings(
      in: "extension File.Directory { struct Walk {} }",
      file: "Sources/File System/File.Directory.Walk.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `specification namespace basename is exempt`() {
    let findings = Lint.Rule.`source file type path Tests`.findings(
      in: "enum Other {}",
      file: "Sources/RFC/RFC_4122.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `acronym to word boundary is a compound candidate`() {
    let findings = Lint.Rule.`source file type path Tests`.findings(
      in: "extension IO.Error {}",
      file: "Sources/IO/IOError.swift"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `canonical extension repair suppresses redundant type path finding`() {
    let findings = Lint.Rule.`source file type path Tests`.findings(
      in: "public extension Namespace.Value where Element: Sequence {}",
      file: "Sources/Value/ValueConvertible.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `member-only extension keeps independent type path finding`() {
    let findings = Lint.Rule.`source file type path Tests`.findings(
      in: "extension EnvVars { var value: String { \"value\" } }",
      file: "Sources/Environment/EnvironmentVariables.swift"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `mixed extension causes keep independent type path finding`() {
    let source = """
      extension Query.Expression where Value == String {}
      extension SQLQueryExpression {}
      """
    let findings = Lint.Rule.`source file type path Tests`.findings(
      in: source,
      file: "Sources/Query/QueryHelpers.swift"
    )
    #expect(findings.count == 1)
  }
}

extension Lint.Rule.`source file type path Tests`.Integration {
  @Test
  func `build-system and excluded-tree paths are exempt`() {
    let exports = Lint.Rule.`source file type path Tests`.findings(
      in: "public import Dependency",
      file: "Sources/Product/exports.swift"
    )
    let tests = Lint.Rule.`source file type path Tests`.findings(
      in: "struct Other {}",
      file: "Sources/Product/Tests/FileDirectoryWalk.swift"
    )
    let benchmarks = Lint.Rule.`source file type path Tests`.findings(
      in: "struct Other {}",
      file: "Sources/Product/Benchmarks/FileDirectoryWalk.swift"
    )
    #expect(exports.isEmpty)
    #expect(tests.isEmpty)
    #expect(benchmarks.isEmpty)
  }

  @Test
  func `self-firing control catches this rule identifier in an undotted filename`() {
    let source = """
      extension Lint.Rule {
        static let fixture = 0
      }
      """
    let findings = Lint.Rule.`source file type path Tests`.findings(
      in: source,
      file: "Sources/Rules/SourceFileTypePath.swift"
    )
    #expect(findings.count == 1)
  }
}
