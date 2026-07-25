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

  @Suite struct `Foundation Integration carve-out` {}
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

// The dedicated, opt-in `* Foundation Integration` subtarget is the
// sanctioned Foundation boundary ([PRIM-FOUND-001]); a file inside one must
// NOT fire, while every core target at every layer STILL fires. Controlled
// in both directions — an over-skip is as bad as a never-fire. Real target
// dir names verified 2026-07-25: swift-json `JSON Foundation Integration`,
// swift-structured-queries-primitives
// `Structured Queries Primitives Foundation Integration`.
extension Lint.Rule.`foundation import Tests`.`Foundation Integration carve-out` {
  // MARK: - Negative controls (inside an FI target → must NOT fire)

  @Test
  func `Foundation import inside an FI target is NOT flagged`() {
    let source = "import Foundation"
    let findings = Lint.Rule.`foundation import Tests`.findings(
      in: source,
      file: "Sources/JSON Foundation Integration/JSON.Foundation.Coder.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `every Foundation family member inside an FI target is NOT flagged`() {
    let source = """
      import Foundation
      public import Foundation
      @_exported import FoundationNetworking
      import FoundationXML
      """
    let findings = Lint.Rule.`foundation import Tests`.findings(
      in: source,
      file: "Sources/Structured Queries Primitives Foundation Integration/Bridge.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `FI target at the source-tree root (no Sources prefix) is NOT flagged`() {
    // The carve-out keys on the directory segment, not on a `Sources/`
    // prefix, so a file located directly under the FI target dir is exempt.
    let source = "import Foundation"
    let findings = Lint.Rule.`foundation import Tests`.findings(
      in: source,
      file: "JSON Foundation Integration/exports.swift"
    )
    #expect(findings.isEmpty)
  }

  // MARK: - Positive controls (core targets → must STILL fire)

  @Test
  func `Foundation import in a core target still fires`() {
    let source = "import Foundation"
    let findings = Lint.Rule.`foundation import Tests`.findings(
      in: source,
      file: "Sources/JSON/JSON.Value.swift"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `every detection shape in a core target still fires`() {
    // Preserves the rule's named detections — bare, public, @_exported
    // FoundationNetworking, FoundationXML — in a NON-FI (core) path.
    let source = """
      import Foundation
      public import Foundation
      @_exported import FoundationNetworking
      import FoundationXML
      """
    let findings = Lint.Rule.`foundation import Tests`.findings(
      in: source,
      file: "Sources/JSON/Core.swift"
    )
    #expect(findings.count == 4)
  }

  @Test
  func `default test path (no directory) still fires`() {
    // The default `file: "test.swift"` has no directory segment; the
    // carve-out must not swallow it, or every existing fixture goes blind.
    let source = "import Foundation"
    let findings = Lint.Rule.`foundation import Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  // MARK: - Over-skip guards (look-alike core dirs → must STILL fire)

  @Test
  func `core target merely named with Foundation still fires`() {
    // `HTML Foundation` is a core institute target, not an FI subtarget —
    // its dir does not end in ` Foundation Integration`, so it must fire.
    let source = "import Foundation"
    let findings = Lint.Rule.`foundation import Tests`.findings(
      in: source,
      file: "Sources/HTML Foundation/Renderer.swift"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `no-space prefix before Foundation Integration still fires`() {
    // The required leading space means a segment without a real brand-token
    // boundary (`XFoundation Integration`) is not the sanctioned shape.
    let source = "import Foundation"
    let findings = Lint.Rule.`foundation import Tests`.findings(
      in: source,
      file: "Sources/XFoundation Integration/File.swift"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `filename ending in Foundation Integration inside a core dir still fires`() {
    // Only DIRECTORY segments qualify; a source file whose name ends in
    // `… Foundation Integration.swift` inside a core target is not exempt.
    let source = "import Foundation"
    let findings = Lint.Rule.`foundation import Tests`.findings(
      in: source,
      file: "Sources/JSON/My Foundation Integration.swift"
    )
    #expect(findings.count == 1)
  }
}
