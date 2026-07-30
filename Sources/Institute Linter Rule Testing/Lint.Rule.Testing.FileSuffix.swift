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

/// Requires test filenames ending in `Tests` to separate that suffix from the
/// tested type path with a space.
///
/// Citation: `[TEST-009]`.
extension Lint.Rule {
  public static let `test file suffix` = Lint.Rule(
    id: "test file suffix",
    default: .warning,
    findings: { source, severity in
      let filePath = source.file.filePath
      let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
      guard components.contains("Tests") else { return [] }
      for component in components {
        if component.hasPrefix(".")
          || component == "Support"
          || component == "Fixtures"
        {
          return []
        }
      }
      guard
        let filename = components.last,
        filename.hasSuffix(".swift")
      else {
        return []
      }
      let basename = Swift.String(filename.dropLast(".swift".count))
      guard
        basename != "Package",
        basename != "exports",
        basename != "Exports",
        !basename.contains("+"),
        !basename.contains(" where "),
        !basename.hasSuffix(" where"),
        basename.hasSuffix("Tests"),
        !basename.hasSuffix(" Tests")
      else {
        return []
      }
      let location = source.converter.location(
        for: source.tree.positionAfterSkippingLeadingTrivia
      )
      return [
        Diagnostic.Record(
          location: Source.Location(
            fileID: source.file.fileID,
            filePath: filePath,
            line: location.line,
            column: location.column
          ),
          severity: severity,
          identifier: "test file suffix",
          message: testingFileSuffixMessage
        )
      ]
    }
  )
}

@usableFromInline
internal let testingFileSuffixMessage: Swift.String =
  "[test file suffix] [TEST-009]: a test filename ending in `Tests` must "
  + "mirror the tested type path and separate the `Tests` suffix with a "
  + "space (for example, `File.Directory Tests.swift`)."
