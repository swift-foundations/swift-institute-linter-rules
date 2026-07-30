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
  struct `extension file naming Tests` {
    @Suite struct Positive {}
    @Suite struct Negative {}
    @Suite struct Edge {}
    @Suite struct Exemption {}
    @Suite struct `Near Miss` {}
    @Suite struct `Self Firing` {}
  }
}

extension Lint.Rule.`extension file naming Tests` {
  static func findings(in source: String, file: String) -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`extension file naming`.findings(parsed, .warning)
  }
}

// MARK: - Positive (one per class, plus the 497-shape and mixed-base)

extension Lint.Rule.`extension file naming Tests`.Positive {
  @Test
  func `conformance-adding extension with wrong or missing plus segment fires`() {
    let findings = Lint.Rule.`extension file naming Tests`.findings(
      in: "extension Iterator: Sendable {}",
      file: "Sources/X/Iterator.swift"
    )
    #expect(findings.count == 1)
    if findings.count == 1 {
      #expect(findings[0].identifier == "extension file naming")
      #expect(findings[0].message.contains("Iterator+Sendable.swift"))
    }
  }

  @Test
  func `where-clause discriminated extension with wrong basename fires`() {
    let findings = Lint.Rule.`extension file naming Tests`.findings(
      in: "extension Iterator where Element: Comparable {}",
      file: "Sources/X/Iterator.swift"
    )
    #expect(findings.count == 1)
    if findings.count == 1 {
      #expect(findings[0].message.contains("Iterator where <discriminator>.swift"))
    }
  }

  @Test
  func `bare member-only extension file - the 497-finding shape - fires`() {
    let source = """
      extension Iterator {
          func next() -> Element? { nil }
      }
      """
    let findings = Lint.Rule.`extension file naming Tests`.findings(
      in: source,
      file: "Sources/X/Iterator.swift"
    )
    #expect(findings.count == 1)
    if findings.count == 1 {
      #expect(findings[0].message.contains("+<Topic>"))
    }
  }

  @Test
  func `mixed-base extension file fires`() {
    let source = """
      extension Iterator {
          func next() -> Element? { nil }
      }
      extension Cursor {
          func advance() {}
      }
      """
    let findings = Lint.Rule.`extension file naming Tests`.findings(
      in: source,
      file: "Sources/X/Wrong.swift"
    )
    #expect(findings.count == 1)
    if findings.count == 1 {
      #expect(findings[0].message.contains("mixes extensions on different base types"))
    }
  }
}

// MARK: - Negative (one per class)

extension Lint.Rule.`extension file naming Tests`.Negative {
  @Test
  func `conformance-adding extension with correct plus segment is permitted`() {
    let findings = Lint.Rule.`extension file naming Tests`.findings(
      in: "extension Iterator: Sendable {}",
      file: "Sources/X/Iterator+Sendable.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `where-clause discriminated extension with correct shape is permitted`() {
    let findings = Lint.Rule.`extension file naming Tests`.findings(
      in: "extension Iterator where Element: Comparable {}",
      file: "Sources/X/Iterator where Element Comparable.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `member-only extension with a topic segment is permitted`() {
    let source = """
      extension Iterator {
          func next() -> Element? { nil }
      }
      """
    let findings = Lint.Rule.`extension file naming Tests`.findings(
      in: source,
      file: "Sources/X/Iterator+Iteration.swift"
    )
    #expect(findings.isEmpty)
  }
}

// MARK: - Edge

extension Lint.Rule.`extension file naming Tests`.Edge {
  @Test
  // swiftlint:disable:next function_name_whitespace
  func
    `conditional conformance restated on a conditional extension classifies as conformance-adding`()
  {
    let source = "extension Iterator: Sequence where Element: Comparable {}"
    let matching = Lint.Rule.`extension file naming Tests`.findings(
      in: source,
      file: "Sources/X/Iterator+Sequence.swift"
    )
    #expect(matching.isEmpty)

    let whereShaped = Lint.Rule.`extension file naming Tests`.findings(
      in: source,
      file: "Sources/X/Iterator where Element Comparable.swift"
    )
    #expect(whereShaped.count == 1)
    if whereShaped.count == 1 {
      #expect(whereShaped[0].message.contains("+Sequence.swift"))
    }
  }

  @Test
  func `multiple conformances in one file - matching any added conformance satisfies the rule`() {
    let source = """
      extension Iterator: Sendable {}
      extension Iterator: Equatable {}
      """
    let sendable = Lint.Rule.`extension file naming Tests`.findings(
      in: source,
      file: "Sources/X/Iterator+Sendable.swift"
    )
    #expect(sendable.isEmpty)

    let equatable = Lint.Rule.`extension file naming Tests`.findings(
      in: source,
      file: "Sources/X/Iterator+Equatable.swift"
    )
    #expect(equatable.isEmpty)
  }
}

// MARK: - Exemption (bundle-mechanism placement is out of this rule's scope;
// this rule's own out-of-surface predicates)

extension Lint.Rule.`extension file naming Tests`.Exemption {
  @Test
  func `file with a primary nominal type is 006's surface, not fired here`() {
    let source = """
      struct Iterator {}
      extension Iterator: Sendable {}
      """
    let findings = Lint.Rule.`extension file naming Tests`.findings(
      in: source,
      file: "Sources/X/Wrong.swift"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `type nested via a top-level extension shell is still 006's surface`() {
    let source = """
      extension Outer {
          struct Inner {}
      }
      extension Outer.Inner: Sendable {}
      """
    let findings = Lint.Rule.`extension file naming Tests`.findings(
      in: source,
      file: "Sources/X/Wrong.swift"
    )
    #expect(findings.isEmpty)
  }
}

// MARK: - Near-miss for every exemption

extension Lint.Rule.`extension file naming Tests`.`Near Miss` {
  @Test
  func `non-spec-mirroring name still fires wherever the rule is active`() {
    // No standards-layer exemption applies in a plain Sources/ fixture —
    // the shape must still be enforced.
    let findings = Lint.Rule.`extension file naming Tests`.findings(
      in: "extension Iterator: Sendable {}",
      file: "Sources/X/Iterator+NotTheRightConformance.swift"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `Tests path scope-excluded`() {
    let findings = Lint.Rule.`extension file naming Tests`.findings(
      in: "extension Iterator: Sendable {}",
      file: "Tests/X Tests/Wrong.swift"
    )
    #expect(findings.isEmpty)
  }
}

// MARK: - Self-firing

extension Lint.Rule.`extension file naming Tests`.`Self Firing` {
  @Test
  // swiftlint:disable:next function_name_whitespace
  func
    `self-firing control - a synthetic mismatch of this rule's own extension shape fires and its corrected name does not`()
  {
    let source = "extension Institute: Sendable {}"

    let mismatched = Lint.Rule.`extension file naming Tests`.findings(
      in: source,
      file: "Sources/X/Wrong.swift"
    )
    #expect(mismatched.count == 1)

    let corrected = Lint.Rule.`extension file naming Tests`.findings(
      in: source,
      file: "Sources/X/Institute+Sendable.swift"
    )
    #expect(corrected.isEmpty)
  }
}
