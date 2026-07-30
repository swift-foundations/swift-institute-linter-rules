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

/// Wave 2b finalization (2026-05-10) — `Error`-conforming types MUST
/// NOT also suppress `Copyable`.
///
/// Citation: `[MEM-COPY-002]` (memory-safety skill, the ownership note).
///
/// `Swift.Error` requires `Copyable` (the protocol's existential
/// boxing relies on the value being copyable). A type declared
/// `~Copyable` cannot conform to `Error`. The fix is to use a
/// non-throwing outcome type carrying the move-only value, or to
/// keep the error type `Copyable` and refer to the move-only value
/// through a copyable handle.
extension Lint.Rule {
  public static let `noncopyable error` = Lint.Rule(
    id: "noncopyable error",
    default: .warning,
    findings: { source, severity in
      // `~Copyable` can only be suppressed on the primary declaration,
      // but `Error` can be added by a same-file extension (#25 defect
      // 5) — a pre-pass collects every extension's inherited leaf
      // names, keyed by the extended type's dotted path, so the
      // visitor can check "declaration clause OR any same-file
      // extension".
      let collector = MemoryErrorNoncopyableExtensionCollector(viewMode: .sourceAccurate)
      collector.walk(source.tree)
      let visitor = MemoryErrorNoncopyableVisitor(
        source: source.file,
        severity: severity,
        converter: source.converter,
        extensionConformances: collector.conformances
      )
      visitor.walk(source.tree)
      return visitor.matches
    }
  )
}

@usableFromInline
internal let memoryErrorNoncopyableMessage: Swift.String =
  "[noncopyable error] [MEM-COPY-002]: `Error`-conforming types MUST NOT "
  + "suppress `Copyable`. `Swift.Error`'s existential boxing requires `Copyable`. "
  + "A `~Copyable` Error type fails to compile or to interoperate with the "
  + "throwing protocol surface. Use a non-throwing `Outcome` enum (`.success`/"
  + "`.failure`) carrying the move-only value, or hold the move-only state in "
  + "a copyable handle and reference it from the error."

/// Collects, for each `extension <Name>` in the file, the union of its
/// inheritance-clause leaf names, keyed by the extension's own
/// (unresolved) extended-type text. Used so `conformsToError` can be
/// satisfied by a same-file `extension E: Error {}` sibling to `struct
/// E: ~Copyable {}`, not only by the declaration's own clause (#25
/// defect 5).
internal final class MemoryErrorNoncopyableExtensionCollector: SyntaxVisitor {
  var conformances: [Swift.String: Swift.Set<Swift.String>] = [:]

  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let clause = node.inheritanceClause else { return .visitChildren }
    let key = node.extendedType.trimmedDescription
    var leaves = conformances[key] ?? []
    for inherited in clause.inheritedTypes {
      var current = inherited.type
      while let attributed = current.as(AttributedTypeSyntax.self) {
        current = attributed.baseType
      }
      if let identifier = current.as(IdentifierTypeSyntax.self) {
        leaves.insert(identifier.name.text)
      }
      if let member = current.as(MemberTypeSyntax.self) {
        leaves.insert(member.name.text)
      }
    }
    conformances[key] = leaves
    return .visitChildren
  }
}

internal final class MemoryErrorNoncopyableVisitor: SyntaxVisitor {
  let source: Source.File
  let severity: Diagnostic.Severity
  let converter: SourceLocationConverter
  let extensionConformances: [Swift.String: Swift.Set<Swift.String>]
  var matches: [Diagnostic.Record] = []

  init(
    source: Source.File,
    severity: Diagnostic.Severity,
    converter: SourceLocationConverter,
    extensionConformances: [Swift.String: Swift.Set<Swift.String>]
  ) {
    self.source = source
    self.severity = severity
    self.converter = converter
    self.extensionConformances = extensionConformances
    super.init(viewMode: .sourceAccurate)
  }

  private func conformsToError(
    name: TokenSyntax,
    inheritanceClause: InheritanceClauseSyntax?
  ) -> Bool {
    if let inheritanceClause {
      for inherited in inheritanceClause.inheritedTypes {
        var current = inherited.type
        while let attributed = current.as(AttributedTypeSyntax.self) {
          current = attributed.baseType
        }
        // Base-blind fix (#25 defect 5 point 3): a `MemberTypeSyntax`
        // leaf named `Error` must be rooted at the bare `Swift` module,
        // or a nested non-stdlib `Module.Error` false-positives.
        if let identifier = current.as(IdentifierTypeSyntax.self),
          identifier.name.text == "Error"
        {
          return true
        }
        if let member = current.as(MemberTypeSyntax.self),
          member.name.text == "Error",
          let base = member.baseType.as(IdentifierTypeSyntax.self),
          base.name.text == "Swift"
        {
          return true
        }
      }
    }
    if extensionConformances[name.text]?.contains("Error") == true {
      return true
    }
    return false
  }

  private func suppressesCopyable(_ inheritanceClause: InheritanceClauseSyntax) -> Bool {
    for inherited in inheritanceClause.inheritedTypes {
      if let suppressed = inherited.type.as(SuppressedTypeSyntax.self) {
        let typeName = suppressed.type.trimmedDescription
        if typeName == "Copyable" || typeName.hasSuffix(".Copyable") {
          return true
        }
      }
    }
    return false
  }

  private func check(name: TokenSyntax, inheritanceClause: InheritanceClauseSyntax?) {
    guard conformsToError(name: name, inheritanceClause: inheritanceClause) else { return }
    // `~Copyable` can only be suppressed on the primary declaration's
    // own clause — an extension cannot re-suppress a conformance.
    guard let inheritanceClause, suppressesCopyable(inheritanceClause) else { return }
    let location = converter.location(for: name.positionAfterSkippingLeadingTrivia)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "noncopyable error",
        message: memoryErrorNoncopyableMessage
      ))
  }

  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    check(name: node.name, inheritanceClause: node.inheritanceClause)
    return .visitChildren
  }
  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    check(name: node.name, inheritanceClause: node.inheritanceClause)
    return .visitChildren
  }
  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    check(name: node.name, inheritanceClause: node.inheritanceClause)
    return .visitChildren
  }
  override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
    // `protocol Failure: Error, ~Copyable {}` is the same [MEM-COPY-002]
    // violation in the same single-clause shape (#25 defect 5).
    check(name: node.name, inheritanceClause: node.inheritanceClause)
    return .visitChildren
  }
}
