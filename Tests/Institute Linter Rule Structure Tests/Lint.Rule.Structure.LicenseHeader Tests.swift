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
import Testing

@testable import Institute_Linter_Rule_Structure

extension Lint.Rule {
  @Suite
  struct `license header Tests` {
    static func findings(
      in source: Swift.String,
      file: Swift.String = "Sources/Example/Example.swift"
    ) -> [Diagnostic.Record] {
      let parsed = Lint.Source.parsed(from: source, file: file)
      return Lint.Rule.`license header`.findings(parsed, .warning)
    }

    @Test
    func `Apache 2 point 0 header is accepted`() {
      let source = """
        // Copyright Example
        // Licensed under Apache License v2.0
        public struct Example {}
        """

      #expect(Self.findings(in: source).isEmpty)
    }

    @Test
    func `missing header is reported`() {
      let findings = Self.findings(in: "public struct Example {}")

      #expect(findings.count == 1)
      #expect(findings.first?.identifier == "license header")
    }

    @Test
    func `Apache without version is reported`() {
      let source = """
        // Licensed under Apache
        public struct Example {}
        """

      #expect(Self.findings(in: source).count == 1)
    }

    @Test
    func `header after line thirty is reported`() {
      let prefix = Swift.Array(repeating: "// spacer", count: 30)
        .joined(separator: "\n")
      let source = prefix + "\n// Licensed under Apache License v2.0\npublic struct Example {}"

      #expect(Self.findings(in: source).count == 1)
    }

    @Test
    func `file outside Sources is out of scope`() {
      #expect(
        Self.findings(
          in: "public struct Example {}",
          file: "Tests/Example Tests/Example Tests.swift"
        ).isEmpty
      )
    }
  }
}
