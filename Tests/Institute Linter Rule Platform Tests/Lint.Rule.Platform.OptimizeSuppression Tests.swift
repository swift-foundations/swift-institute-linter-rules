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

@testable import Institute_Linter_Rule_Platform

extension Lint.Rule {
  @Suite
  struct `optimize suppression attribute Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
  }
}

extension Lint.Rule.`optimize suppression attribute Tests` {
  static func findings(in source: Swift.String, file: Swift.String = "test.swift") -> [Diagnostic
    .Record]
  {
    let parsed = Lint.Source.parsed(from: source, file: file)
    return Lint.Rule.`optimize suppression attribute`.findings(parsed, .warning)
  }
}

extension Lint.Rule.`optimize suppression attribute Tests`.Unit {
  @Test
  func `optimize none on a function is flagged`() {
    let source = """
      @_optimize(none) func f() {}
      """
    let findings = Lint.Rule.`optimize suppression attribute Tests`.findings(in: source)
    #expect(findings.count == 1)
    if findings.count == 1 {
      #expect(findings[0].identifier == "optimize suppression attribute")
      #expect(findings[0].severity == .warning)
    }
  }

  @Test
  func `optimize none on an accessor is flagged`() {
    let source = """
      struct S {
          var x: Int {
              @_optimize(none) get { 0 }
          }
      }
      """
    let findings = Lint.Rule.`optimize suppression attribute Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `optimize size on a function is flagged`() {
    let source = """
      @_optimize(size) func g() {}
      """
    let findings = Lint.Rule.`optimize suppression attribute Tests`.findings(in: source)
    #expect(findings.count == 1)
  }

  @Test
  func `semantics optimize no crossmodule on a function is flagged`() {
    let source = """
      @_semantics("optimize.no.crossmodule") func h() {}
      """
    let findings = Lint.Rule.`optimize suppression attribute Tests`.findings(in: source)
    #expect(findings.count == 1)
  }
}

extension Lint.Rule.`optimize suppression attribute Tests`.`Edge Case` {
  @Test
  func `plain function is NOT flagged`() {
    let source = """
      func f() {}
      """
    let findings = Lint.Rule.`optimize suppression attribute Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `inline never is NOT flagged`() {
    let source = """
      @inline(never) func f() {}
      """
    let findings = Lint.Rule.`optimize suppression attribute Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `semantics array check_subscript is NOT flagged`() {
    let source = """
      @_semantics("array.check_subscript") func f() {}
      """
    let findings = Lint.Rule.`optimize suppression attribute Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `optimize none inside a string literal is NOT flagged`() {
    let source = """
      let s = "@_optimize(none) func f() {}"
      """
    let findings = Lint.Rule.`optimize suppression attribute Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }

  @Test
  func `optimize none inside a comment is NOT flagged`() {
    let source = """
      // @_optimize(none) func f() {}
      func f() {}
      """
    let findings = Lint.Rule.`optimize suppression attribute Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }
}
