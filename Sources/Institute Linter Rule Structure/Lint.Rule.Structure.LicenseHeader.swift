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

public import Linter_Primitives
internal import SwiftSyntax

/// A Swift source beneath `Sources/` mentions Apache and 2.0 within its
/// first 30 lines.
///
/// This is the native owner of the former γ-1b Stage 1 license-header audit.
/// It deliberately preserves that audit's permissive recognition predicate:
/// spelling and layout may vary, but both case-insensitive tokens must occur
/// in the bounded header region. Package manifests, tests, and other trees are
/// outside the rule's surface because only `Sources/**/*.swift` is linted.
extension Lint.Rule {
  public static let `license header` = Lint.Rule(
    id: "license header",
    default: .warning,
    findings: { source, severity in
      let path = source.path.underlying
      guard path.hasPrefix("Sources/") || path.contains("/Sources/") else {
        return []
      }

      let header = source.tree.description
        .split(separator: "\n", omittingEmptySubsequences: false)
        .prefix(30)
        .joined(separator: "\n")
        .lowercased()
      guard !header.contains("apache") || !header.contains("2.0") else {
        return []
      }

      return [
        Diagnostic.Record(
          location: Source.Location(
            fileID: source.file.fileID,
            filePath: source.file.filePath,
            line: 1,
            column: 1
          ),
          severity: severity,
          identifier: "license header",
          message:
            "[license header]: Sources/**/*.swift must mention Apache and 2.0 within its first 30 lines"
        )
      ]
    }
  )
}
