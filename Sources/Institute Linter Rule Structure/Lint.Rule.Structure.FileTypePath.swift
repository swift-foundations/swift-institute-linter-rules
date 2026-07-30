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

/// Requires a candidate compound source filename to match a file-level
/// declaration or extension target.
///
/// Citation: `[API-IMPL-006]`.
extension Lint.Rule {
  public static let `source file type path` = Lint.Rule(
    id: "source file type path",
    default: .warning,
    findings: { source, severity in
      let filePath = source.file.filePath
      guard
        structureFileIsInSourceNamingScope(filePath),
        let basename = structureSwiftBasename(filePath),
        structureFileBasenameIsCompound(basename)
      else {
        return []
      }
      let visitor = StructureFileDeclarationVisitor()
      visitor.walk(source.tree)
      guard !visitor.topLevelNames.contains(basename) else { return [] }

      // A pure-extension file whose every extension already carries a
      // conformance or where-clause discriminator has one canonical repair:
      // API-IMPL-007 renames (or splits and renames) it to the target plus
      // discriminator. Do not emit an independent type-path finding for the
      // same occurrence.
      if visitor.canonicalExtensionRepairSupersedesTypePathFinding {
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
          identifier: "source file type path",
          message: structureFileTypePathMessage
        )
      ]
    }
  )
}

@usableFromInline
internal let structureFileTypePathMessage: Swift.String =
  "[source file type path] [API-IMPL-006]: this source file has an undotted "
  + "compound basename that matches no file-level type declaration or "
  + "extension target. Name a type-declaring file for the type's full nested "
  + "path with dots (for example, `Array.Dynamic.swift`), or name an "
  + "extension-only file with its `[API-IMPL-007]` discriminator."
