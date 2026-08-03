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

@testable import Institute_Linter_Rule_Framework

extension Lint.Rule {
  @Suite
  struct `suite categories Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
  }
}

extension Lint.Rule.`suite categories Tests` {
  static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`suite categories`.findings(parsed, .warning)
  }
}

extension Lint.Rule.`suite categories Tests`.Unit {
  @Test
  func `canonical three-category structure passes`() {
    // Canonical post-2026-05-15: three sub-suites required
    // (Unit, `Edge Case`, Integration). Performance is OUT of the
    // test-framework scope (separate benchmark packages per
    // `benchmark` skill).
    let source = """
      @Suite
      struct `Foo Buffer Tests` {
          @Suite struct Unit {}
          @Suite struct `Edge Case` {}
          @Suite struct Integration {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `four-category structure (legacy with Performance extra) still passes`() {
    // Regression guard: pre-2026-05-15 test code carries the
    // four-category structure with Performance. The rule still
    // accepts this — extras are fine, the rule only fires on
    // missing canonical categories.
    let source = """
      @Suite
      struct `Foo Buffer Tests` {
          @Suite struct Unit {}
          @Suite struct `Edge Case` {}
          @Suite struct Integration {}
          @Suite(.serialized) struct Performance {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `legacy flat shape with no categories is flagged`() {
    let source = """
      @Suite
      struct `Foo Buffer Tests` {
          @Test func basic() {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    let count = findings.count
    #expect(count == 1)
    if count == 1 {
      #expect(findings[0].identifier == "suite categories")
      #expect(findings[0].severity == .warning)
    }
  }

  @Test
  func `Performance omitted is permitted (no longer required)`() {
    // Post-2026-05-15: Performance is no longer required. The
    // canonical 3-category structure (without Performance) passes.
    // Performance benchmarking is OUT of the test-framework scope.
    let source = """
      @Suite
      struct `Foo Tests` {
          @Suite struct Unit {}
          @Suite struct `Edge Case` {}
          @Suite struct Integration {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `partial conformance missing two categories is flagged`() {
    let source = """
      @Suite
      struct `Foo Tests` {
          @Suite struct Unit {}
          @Suite struct `Edge Case` {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `top-level @Suite enum (not struct) is not the rule's target`() {
    // The rule scopes to `struct` declarations; the canonical test
    // surface always uses `struct`. An @Suite-annotated enum is rare
    // and not the rule's intended target.
    let source = """
      @Suite
      enum FooTests {
          @Test func basic() {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }
}

extension Lint.Rule.`suite categories Tests`.`Edge Case` {
  @Test
  func `extension-form file (no top-level @Suite struct) is not flagged`() {
    // Extension form contributes tests via `extension X.Test.Unit`.
    // The four-category declaration lives elsewhere in the package;
    // this file isn't a top-level @Suite struct declaration, so it's
    // out of the rule's per-file scope.
    let source = """
      import Testing

      extension Foo.Test.Unit {
          @Test func basic() {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `nested @Suite struct (not top-level) is not flagged`() {
    // The rule only fires on TOP-LEVEL @Suite struct decls. Nested
    // ones (sub-suites of an outer @Suite) are members of the parent
    // and don't independently need the four categories.
    let source = """
      @Suite
      struct `Foo Tests` {
          @Suite struct Unit {}
          @Suite struct `Edge Case` {}
          @Suite struct Integration {}
          @Suite(.serialized) struct Performance {}
      }

      extension `Foo Tests`.Unit {
          @Test func basic() {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `struct without @Suite attribute is not flagged`() {
    let source = """
      struct PlainStruct {
          let value: Int
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `@Suite(.serialized) trait variant counts as @Suite`() {
    // Trait-variant detection regression guard: `@Suite(.serialized)`
    // (or any other trait-argument form) is still recognized as a
    // @Suite attribute. Demonstrated here on a category to confirm
    // the trait-detection logic in `suiteCategoriesHasSuiteAttribute`
    // continues to work across attribute variants.
    let source = """
      @Suite
      struct `Foo Tests` {
          @Suite struct Unit {}
          @Suite(.serialized) struct `Edge Case` {}
          @Suite struct Integration {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `empty source produces no findings`() {
    let source = ""
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `house suite idiom - extension-declared suite missing categories is flagged`() {
    // The repository's own idiom: `extension Lint.Rule { @Suite struct
    // \`X Tests\` { ... } }`. The extension IS the declaration site, so
    // a suite declared this way with only one sub-suite must still be
    // caught.
    let source = """
      extension Lint.Rule {
          @Suite
          struct `Foo Tests` {
              @Suite struct Unit {}
          }
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.count == 1)
    if findings.count == 1 {
      #expect(findings[0].message.contains("Edge Case"))
      #expect(findings[0].message.contains("Integration"))
    }
  }

  @Test
  func `house suite idiom - extension-declared suite with all three categories passes`() {
    let source = """
      extension Lint.Rule {
          @Suite
          struct `Foo Tests` {
              @Suite struct Unit {}
              @Suite struct `Edge Case` {}
              @Suite struct Integration {}
          }
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `qualified @Testing_Suite spelling missing categories is flagged`() {
    // Bug #45: the qualified `Testing.Suite` spelling must be
    // recognized wherever the bare `Suite` spelling is, in the rule
    // gate as well as the declared-category collection.
    let source = """
      @Testing.Suite
      struct `Foo Tests` {
          @Suite struct Unit {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.count == 1)
    if findings.count == 1 {
      #expect(findings[0].message.contains("Edge Case"))
      #expect(findings[0].message.contains("Integration"))
    }
  }

  @Test
  func `qualified @Testing_Suite spelled category structs count as declared`() {
    // Bug #45: category structs spelled with the qualified attribute
    // must count as declared, not just the bare `@Suite` spelling.
    let source = """
      @Suite
      struct `Foo Tests` {
          @Testing.Suite struct Unit {}
          @Testing.Suite struct `Edge Case` {}
          @Testing.Suite struct Integration {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `attribute name merely ending in Suite is not mistaken for qualified Suite`() {
    // Suffix-based matching on the qualified form must not false-positive
    // on an unrelated attribute whose bare name happens to end in
    // `Suite` (e.g. `MySuite`), since that isn't the `.Suite` qualified
    // suffix.
    let source = """
      @MySuite
      struct `Foo Tests` {
          @Test func basic() {}
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `suite declared inside a non-extension nominal type stays out of scope`() {
    // Only ExtensionDeclSyntax is transparent. A @Suite struct nested
    // inside an ordinary struct/class/enum/actor is genuinely nested,
    // not an idiomatic declaration site, and stays out of scope.
    let source = """
      struct Namespace {
          @Suite
          struct `Foo Tests` {
              @Suite struct Unit {}
          }
      }
      """
    let findings = Lint.Rule.`suite categories Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }
}
