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
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Memory

extension Lint.Rule {
  @Suite
  struct `sendable sharing requirement Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
  }
}

extension Lint.Rule.`sendable sharing requirement Tests` {
  static func findings(in source: Swift.String) -> [Diagnostic.Record] {
    let file = Source.File(contents: source, path: "Fixture.swift")
    let tree = Parser.parse(source: source)
    let parsed = Lint.Source.Parsed(file: file, tree: tree)
    return Lint.Rule.`sendable sharing requirement`.findings(parsed, .warning)
  }
}

extension Lint.Rule.`sendable sharing requirement Tests`.Unit {
  @Test
  func `public scoped Sendable closure is the self-firing positive control`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "public func use(_ operation: @Sendable () -> Void) {}"
    )
    #expect(findings.count == 1)
    #expect(findings.first?.severity == .warning)
    #expect(findings.first?.message.contains("scoped borrowing/non-escape") == true)
  }

  @Test
  func `package scoped Sendable closure is diagnosed`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "package func use(_ operation: @Sendable () -> Void) {}"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `escaping closure without ownership signal is not diagnosed`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "public func store(_ operation: @escaping @Sendable () -> Void) {}"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `consuming closure receives strong-priority diagnostic`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "public func use(_ operation: consuming @Sendable () -> Void) {}"
    )
    #expect(findings.count == 1)
    #expect(findings.first?.message.contains("STRONG PRIORITY") == true)
  }

  @Test
  func `sending closure result receives strong-priority diagnostic`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "public func take() -> sending @Sendable () -> Void { fatalError() }"
    )
    #expect(findings.count == 1)
    #expect(findings.first?.message.contains("STRONG PRIORITY") == true)
  }

  @Test
  func `sending argument makes escaping Sendable closure reviewable`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "public func send<T>(_ value: sending T, operation: @escaping @Sendable () -> Void) {}"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `noncopyable generic surface receives strong-priority diagnostic`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "public func move<T: ~Copyable>(_ value: consuming T, operation: @Sendable () -> Void) {}"
    )
    #expect(findings.count == 1)
    #expect(findings.first?.message.contains("~Copyable") == true)
  }

  @Test
  func `nonescapable generic surface receives strong-priority diagnostic`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "public func borrow<T: ~Escapable>(_ value: borrowing T, operation: @Sendable () -> Void) {}"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `isolated actor boundary receives strong-priority diagnostic`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "public func run(on actor: isolated Worker, operation: @escaping @Sendable () -> Void) {}"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `ownership-bearing closure property is diagnosed`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "public var operation: sending @Sendable () -> Void"
    )
    #expect(findings.count == 1)
  }

  @Test
  func `ownership-bearing public closure typealias is diagnosed`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "public typealias Transfer<T: ~Copyable> = @Sendable (consuming T) -> Void"
    )
    #expect(findings.count == 1)
  }

  @Test(arguments: [
    "multi-task-storage",
    "concurrent-cancellation",
    "shared-endpoint",
    "actor-independent-reuse",
    "captureless-os-callback",
  ])
  func `recognized sharing categories justify Sendable`(category: Swift.String) {
    let source = """
      // swift-linter:disable:next sendable sharing requirement
      // REASON: CATEGORY: \(category); SHARING: two independently concurrent users share this callback.
      public func register(_ callback: @Sendable () -> Void) {}
      """
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(in: source)
    #expect(findings.isEmpty)
  }
}

extension Lint.Rule.`sendable sharing requirement Tests`.`Edge Case` {
  @Test
  func `private API is outside the public-package contract`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "private func use(_ operation: @Sendable () -> Void) {}"
    )
    #expect(findings.isEmpty)
  }

  @Test
  func `plain public stored shared closure is not guessed to be one-shot`() {
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(
      in: "public var operation: @Sendable () -> Void"
    )
    #expect(findings.isEmpty)
  }

  @Test(arguments: [
    "// REASON: CATEGORY: unknown; SHARING: two tasks.",
    "// REASON: CATEGORY: shared-endpoint; SHARING: .",
    "// REASON: SHARING: two tasks.",
    "// REASON: CATEGORY: shared-endpoint;",
    "// REASON: needed for concurrency.",
  ])
  func `missing unknown or empty suppression fields are rejected`(reason: Swift.String) {
    let source = """
      // swift-linter:disable:next sendable sharing requirement
      \(reason)
      public func register(_ callback: @Sendable () -> Void) {}
      """
    let findings = Lint.Rule.`sendable sharing requirement Tests`.findings(in: source)
    #expect(findings.count == 1)
    #expect(findings.first?.message.contains("suppression is not justified") == true)
  }

  @Test
  func `rule offers no autofix`() {
    #expect(Lint.Rule.`sendable sharing requirement`.fix == nil)
  }

  @Test
  func `rule sanctions only next-line suppression`() {
    #expect(Lint.Rule.`sendable sharing requirement`.suppression.sanctions(.next))
    #expect(!Lint.Rule.`sendable sharing requirement`.suppression.sanctions(.line))
  }
}
