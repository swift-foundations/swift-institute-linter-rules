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

// TEMPORARY — Arc G validation harness (delete after closeout).
// Walks /Users/coen/Developer/swift-primitives/swift-*-primitives/Sources/
// via FileManager, parses each .swift with SwiftParser, runs each of the
// 7 [API-BYTE-*] rules, writes per-rule per-package findings to
// /tmp/byte-lint-validation-arc-g.md.

import Foundation
import Linter_Primitives
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Byte

@Suite(.serialized)
struct `Arc G byte-lint validation` {
  @Test
  func `validate All Packages Across All Seven Rules`() throws {
    let workspaceRoot = "/Users/coen/Developer/swift-primitives"
    let fileManager = FileManager.default
    let allEntries = try fileManager.contentsOfDirectory(atPath: workspaceRoot)
    let packages =
      allEntries
      .filter { entry in
        guard entry.hasPrefix("swift-") else { return false }
        let sourcesPath = "\(workspaceRoot)/\(entry)/Sources"
        return fileManager.fileExists(atPath: sourcesPath)
      }
      .sorted()

    let rules: [(id: String, rule: Lint.Rule)] = [
      ("API-BYTE-001", Lint.Rule.`uint8 conforms to byte protocol`),
      ("API-BYTE-002", Lint.Rule.`byte conforms to arithmetic protocol`),
      ("API-BYTE-003", Lint.Rule.`binary serializable uint8 witness`),
      ("API-BYTE-004", Lint.Rule.`binary serializable rawvalue uint8`),
      ("API-BYTE-005", Lint.Rule.`uint8 ascii extension`),
      ("API-BYTE-006", Lint.Rule.`uint8 forwarder missing disfavored`),
      ("API-BYTE-007", Lint.Rule.`stdlib forwarder outside sli`),
    ]

    var output = "# Arc G: swift-primitives byte-lint validation findings\n\n"
    output += "Workspace root: \(workspaceRoot)\n"
    output += "Packages enumerated: \(packages.count)\n"
    output += "Rules run: \(rules.count)\n\n"

    // Per-rule, per-package findings
    var perRuleTotals: [String: Int] = [:]
    var perRulePackagesWithFindings: [String: [String]] = [:]

    for (ruleID, rule) in rules {
      output += "## \(ruleID)\n\n"
      var ruleTotal = 0
      var packagesHit: [String] = []

      for package in packages {
        let sourcesPath = "\(workspaceRoot)/\(package)/Sources"
        guard
          let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: sourcesPath),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
          )
        else { continue }

        // Preserve typed line/column from text-primitives — Source.Location.line is
        // Text.Line.Number and .column is Text.Line.Column. Stringifying at the
        // formatter is fine (both conform to CustomStringConvertible); stringifying
        // at the storage site discards the typed identity.
        var perPackageFindings: [(file: String, line: Text.Line.Number, column: Text.Line.Column)] =
          []

        for case let fileURL as URL in enumerator
        where fileURL.pathExtension == "swift" {
          // Skip .build artifacts and worktrees.
          let pathString = fileURL.path
          if pathString.contains("/.build/") { continue }
          if pathString.contains("/.claude/worktrees/") { continue }

          guard let data = try? Data(contentsOf: fileURL),
            let source = String(data: data, encoding: .utf8)
          else { continue }

          let parsed = Lint.Source.parsed(from: source, file: pathString)
          let findings = rule.findings(parsed, .warning)
          for finding in findings {
            perPackageFindings.append(
              (file: pathString, line: finding.location.line, column: finding.location.column)
            )
          }
        }

        if !perPackageFindings.isEmpty {
          packagesHit.append(package)
          ruleTotal += perPackageFindings.count
          output += "### \(package) (\(perPackageFindings.count))\n\n"
          for finding in perPackageFindings {
            let rel = finding.file.replacingOccurrences(
              of: "\(workspaceRoot)/\(package)/",
              with: ""
            )
            output += "- \(rel):\(finding.line):\(finding.column)\n"
          }
          output += "\n"
        }
      }

      perRuleTotals[ruleID] = ruleTotal
      perRulePackagesWithFindings[ruleID] = packagesHit
      output +=
        "**\(ruleID) total**: \(ruleTotal) finding(s) across \(packagesHit.count) package(s)\n\n"
    }

    // Summary table
    output += "## Summary\n\n"
    output += "| Rule | Findings | Packages |\n"
    output += "|------|----------|----------|\n"
    for (ruleID, _) in rules {
      let total = perRuleTotals[ruleID] ?? 0
      let pkgCount = perRulePackagesWithFindings[ruleID]?.count ?? 0
      output += "| \(ruleID) | \(total) | \(pkgCount) |\n"
    }

    let outputPath = "/tmp/byte-lint-validation-arc-g.md"
    try output.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("Validation output written to \(outputPath)")
    print("--- SUMMARY ---")
    for (ruleID, _) in rules {
      let total = perRuleTotals[ruleID] ?? 0
      let pkgCount = perRulePackagesWithFindings[ruleID]?.count ?? 0
      print("\(ruleID): \(total) finding(s) across \(pkgCount) package(s)")
    }
  }
}
