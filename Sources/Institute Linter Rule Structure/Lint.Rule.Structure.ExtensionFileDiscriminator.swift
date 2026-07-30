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

/// Requires a pure-extension source filename to carry a `+` conformance or
/// ` where ` specialization discriminator.
///
/// Citation: `[API-IMPL-007]`.
extension Lint.Rule {
  public static let `extension file discriminator` = Lint.Rule(
    id: "extension file discriminator",
    default: .warning,
    findings: { source, severity in
      let filePath = source.file.filePath
      guard
        structureFileIsInSourceNamingScope(filePath),
        let basename = structureSwiftBasename(filePath),
        !structureFileBasenameIsExempt(basename),
        !basename.contains("+"),
        !basename.contains(" where ")
      else {
        return []
      }
      let visitor = StructureFileDeclarationVisitor()
      visitor.walk(source.tree)
      guard visitor.isPureExtensionFile else { return [] }
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
          identifier: "extension file discriminator",
          message: structureExtensionFileDiscriminatorMessage
        )
      ]
    }
  )
}

@usableFromInline
internal let structureExtensionFileDiscriminatorMessage: Swift.String =
  "[extension file discriminator] [API-IMPL-007]: a source file containing "
  + "only extension declarations must name the extended type plus a `+` "
  + "conformance discriminator (for example, `Foo+Sequence.swift`) or a "
  + "` where ` specialization discriminator (for example, "
  + "`Carrier where Underlying == Self.swift`)."
