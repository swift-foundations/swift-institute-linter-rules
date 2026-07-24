// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-primitives-linter-rules project authors
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

@testable import Institute_Linter_Rule_Foundation

extension Lint.Rule {
  @Suite
  struct `foundation import Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
  }
}

extension Lint.Rule.`foundation import Tests` {
  static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`foundation import`.findings(parsed, .warning)
  }
}

extension Lint.Rule.`foundation import Tests`.Unit {
  @Test
  func `bare Foundation import is flagged`() {
    let source = "import Foundation"
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    let count = findings.count
    #expect(count == 1)
    if count == 1 {
      #expect(findings[0].identifier == "foundation import")
      #expect(findings[0].severity == .warning)
    }
  }

  @Test
  func `FoundationEssentials import is flagged`() {
    let source = "import FoundationEssentials"
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `Foundation submodule import is flagged`() {
    let source = "import Foundation.NSURL"
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `Foundation alongside other imports flags only Foundation`() {
    let source = """
      import Time_Primitives
      import Foundation
      import Binary_Primitives
      """
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `public import of Foundation is flagged`() {
    let source = "public import Foundation"
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `FoundationNetworking import is flagged`() {
    // FoundationNetworking is where URLSession lives on Linux. Omitting it
    // left the rule blind on exactly the axis it exists to guard.
    let source = "import FoundationNetworking"
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `exported import of FoundationNetworking is flagged`() {
    // The live shape that motivated closing the hole: a package re-exporting
    // FoundationNetworking to every consumer while passing the rule clean.
    // Observed at swift-urlrequest-handler exports.swift:4 on 2026-07-24.
    let source = "@_exported import FoundationNetworking"
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `FoundationNetworking guarded by canImport is still flagged`() {
    // The conditional does not make the import Foundation-free; it only makes
    // it platform-conditional. Observed shape at DefaultSessionKey.swift:11-13.
    let source = """
      #if canImport(FoundationNetworking)
          import FoundationNetworking
      #endif
      """
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `FoundationXML import is flagged`() {
    let source = "import FoundationXML"
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `every Foundation family member is flagged exactly once`() {
    let source = """
      import Foundation
      import FoundationEssentials
      import FoundationNetworking
      import FoundationXML
      """
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.count == 4)
  }
}

extension Lint.Rule.`foundation import Tests`.`Edge Case` {
  @Test
  func `institute primitives imports are NOT flagged`() {
    let source = """
      import Time_Primitives
      import Binary_Primitives
      import Cardinal_Primitives
      """
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `Swift stdlib imports are NOT flagged`() {
    let source = """
      import Swift
      import Synchronization
      """
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `module with Foundation in name (not Foundation framework) is NOT flagged`() {
    // A package named e.g. swift-html-foundation would be imported as
    // Html_Foundation — not the Apple Foundation framework. Only the
    // first path component is checked.
    let source = "import HTML_Foundation"
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `empty source produces no findings`() {
    let source = ""
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `family name in a non-leading position is NOT flagged`() {
    // Widening the family must not widen the non-leading-component exemption.
    // Server_Foundation is an institute package, not the Apple framework.
    let source = """
      import HTML_Foundation
      import Server_Foundation
      """
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `a longer module name merely PREFIXED by a family member is NOT flagged`() {
    // The match is exact on the first path component, not a prefix test.
    // FoundationNetworkingHelpers is a different module from
    // FoundationNetworking and must not be flagged by widening the family.
    let source = """
      import FoundationNetworkingHelpers
      import FoundationalTypes
      """
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `FoundationNetworking submodule import is flagged`() {
    let source = "import FoundationNetworking.NSURLSession"
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.count == 1)
  }
}
