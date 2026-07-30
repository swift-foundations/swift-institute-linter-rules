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

/// A file's basename equals the declared type's full nested dotted path
/// (e.g. `Array.Dynamic.Iterator.swift` for `Array.Dynamic.Iterator`).
///
/// Citation: `[API-IMPL-006]`. Adjudicated on
/// swift-institute-linter-rules#6 (ruling D1, 2026-07-30); implemented
/// per swift-institute-linter-rules#8. Every design decision below
/// mirrors that issue verbatim.
///
/// The rule's surface is a source file under `Sources/` whose top-level
/// declarations declare exactly one primary nominal type (`struct`,
/// `enum`, `class`, `actor`, or `protocol`), whether declared directly
/// at top level or as the single nominal declaration nested inside a
/// top-level `extension Outer { … }` shell. The primary type's dotted
/// path is its full nesting chain: the enclosing extension's dotted
/// extended-type path, plus any enclosing namespace-enum shells, plus
/// its own name. The rule fires when the basename does not equal that
/// dotted path exactly (case-sensitive, `.`-separated).
///
/// Excluded from the surface (not exemptions — out of scope by
/// predicate):
/// - Basenames matching an `[API-IMPL-007]` shape (a `+` segment, or a
///   ` where ` clause discriminator) — 007's surface exclusively.
/// - Files with zero primary nominal types (extension-only files —
///   007's surface) or more than one top-level primary type (the
///   one-type-per-file rule's surface — `[API-IMPL-005]` /
///   `single type per file`).
/// - `Tests`, `Experiments`, and `Examples` path scope, mirroring
///   `single type per file`'s exclusion.
///
/// Cascade suppression (D1, the proven predicate from the
/// diagnostic-precedence record, adopted verbatim): when the file also
/// contains top-level extensions other than the one nesting the
/// primary type, this rule suppresses its finding only when exact
/// parsing proves that EVERY one of those other top-level extensions
/// carries a conformance clause or a `where` clause discriminator —
/// the canonical `[API-IMPL-007]` repair for those extensions
/// necessarily moves the file into 007's own excluded shape. A single
/// bare, member-only extension among them defeats the suppression and
/// this rule still fires.
///
/// Known false positives prevented by resolution, not exemption:
/// - The hoisted-`Protocol` idiom (a module-scope protocol declared
///   directly at top level, paired with a top-level extension
///   containing `public typealias \`Protocol\` = <the protocol>`)
///   resolves to the owning extension's dotted path plus `.Protocol`,
///   not the hoisted spelling — matching the real precedent
///   (`Array.Protocol.swift` declaring `protocol __ArrayProtocol` at
///   top level alongside `extension __Array { typealias \`Protocol\`
///   = __ArrayProtocol }`).
/// - A namespace-enum shell declaring exactly one nested type (no
///   cases, only typealiases besides the one nested type — the same
///   shape `single type namespace` flags) resolves through to the
///   nested type's path: `enum A { enum B { struct C {} } }` resolves
///   to `A.B.C`, not `A`.
///
/// The diagnostic is located at the primary type's own name (so
/// editors surface it in-file). The canonical fix is a file rename;
/// no source edit.
extension Lint.Rule {
  public static let `file name nested path` = Lint.Rule(
    id: "file name nested path",
    default: .warning,
    findings: { source, severity in
      let path = source.file.filePath
      for excluded in ["Tests", "Experiments", "Examples"] {
        if path == excluded
          || path.hasPrefix("\(excluded)/")
          || path.contains("/\(excluded)/")
        {
          return []
        }
      }
      guard let slashIndex = path.lastIndex(of: "/") else {
        return structureFileNameNestedPathFindings(
          basename: path,
          source: source.file,
          severity: severity,
          converter: source.converter,
          tree: source.tree
        )
      }
      let filename = Swift.String(path[path.index(after: slashIndex)...])
      return structureFileNameNestedPathFindings(
        basename: filename,
        source: source.file,
        severity: severity,
        converter: source.converter,
        tree: source.tree
      )
    }
  )
}

private func structureFileNameNestedPathFindings(
  basename filename: Swift.String,
  source: Source.File,
  severity: Diagnostic.Severity,
  converter: SourceLocationConverter,
  tree: SourceFileSyntax
) -> [Diagnostic.Record] {
  guard filename.hasSuffix(".swift") else { return [] }
  let basename = Swift.String(filename.dropLast(".swift".count))

  // Excluded from the surface — [API-IMPL-007]'s shapes exclusively.
  if basename.contains("+") || basename.contains(" where ") { return [] }

  let collector = StructureFileNameNestedPathCollector()
  collector.walk(tree)

  guard collector.primaryTypes.count == 1 else { return [] }
  let primary = collector.primaryTypes[0]

  let resolvedOwnPath = structureFileNameNestedPathResolve(primary.node)
  var dottedPath =
    primary.extensionPrefix.isEmpty
    ? resolvedOwnPath
    : "\(primary.extensionPrefix).\(resolvedOwnPath)"

  // Hoisted-`Protocol` idiom: a top-level protocol paired with a
  // top-level extension's `typealias \`Protocol\` = <thisProtocol>`
  // resolves to the extension's dotted path + ".Protocol", not the
  // hoisted spelling.
  if let protocolDecl = primary.node.as(ProtocolDeclSyntax.self) {
    let protocolName = protocolDecl.name.text
    for extensionDecl in collector.topLevelExtensions {
      guard
        let carrierPath = structureHoistedProtocolAliasDottedName(
          of: extensionDecl.extendedType
        )
      else { continue }
      for member in extensionDecl.memberBlock.members {
        guard let alias = member.decl.as(TypeAliasDeclSyntax.self) else { continue }
        guard structureStripBackticks(alias.name.text) == "Protocol" else { continue }
        guard
          let aliasedName = structureHoistedProtocolAliasDottedName(of: alias.initializer.value)
        else { continue }
        guard aliasedName == protocolName else { continue }
        dottedPath = "\(carrierPath).Protocol"
      }
    }
  }

  guard basename != dottedPath else { return [] }

  // Cascade suppression (D1): every OTHER top-level extension (not the
  // one nesting the primary type, if any) must carry a conformance or
  // where-clause discriminator to suppress this finding.
  let wrappingPosition = primary.wrappingExtension?.position
  let others = collector.topLevelExtensions.filter { $0.position != wrappingPosition }
  if !others.isEmpty {
    let allDiscriminated = others.allSatisfy { extensionDecl in
      let hasConformance =
        extensionDecl.inheritanceClause.map { !$0.inheritedTypes.isEmpty } ?? false
      let hasWhere = extensionDecl.genericWhereClause != nil
      return hasConformance || hasWhere
    }
    if allDiscriminated { return [] }
  }

  let location = converter.location(for: primary.namePosition)
  return [
    Diagnostic.Record(
      location: Source.Location(
        fileID: source.fileID,
        filePath: source.filePath,
        line: location.line,
        column: location.column
      ),
      severity: severity,
      identifier: "file name nested path",
      message: structureFileNameNestedPathMessage(basename: basename, dottedPath: dottedPath)
    )
  ]
}

@usableFromInline
internal func structureFileNameNestedPathMessage(
  basename: Swift.String,
  dottedPath: Swift.String
) -> Swift.String {
  "[file name nested path] [API-IMPL-006]: file name '\(basename).swift' does not match "
    + "the declared type's nested path '\(dottedPath)'; rename to '\(dottedPath).swift'"
}

/// Resolves a namespace-enum-shell chain to its innermost leaf path:
/// `enum A { enum B { struct C {} } }` resolves to `A.B.C`. A shell is
/// a caseless enum whose only members (besides any number of
/// typealiases) are exactly one nested type declaration — the same
/// shape `single type namespace` flags as an anti-pattern.
private func structureFileNameNestedPathResolve(_ node: DeclSyntax) -> Swift.String {
  guard let enumDecl = node.as(EnumDeclSyntax.self) else {
    return structureFileNameNestedPathOwnName(node) ?? ""
  }
  var nestedTypes: [DeclSyntax] = []
  for member in enumDecl.memberBlock.members {
    if member.decl.is(EnumCaseDeclSyntax.self) {
      // Has cases — not a shell.
      return enumDecl.name.text
    }
    if member.decl.is(TypeAliasDeclSyntax.self) { continue }
    if structureFileNameNestedPathIsPrimaryTypeDecl(member.decl) {
      nestedTypes.append(member.decl)
      continue
    }
    // Any other member (function, property, ...) disqualifies the shell.
    return enumDecl.name.text
  }
  guard nestedTypes.count == 1 else {
    return enumDecl.name.text
  }
  return "\(enumDecl.name.text).\(structureFileNameNestedPathResolve(nestedTypes[0]))"
}

private func structureFileNameNestedPathOwnName(_ node: DeclSyntax) -> Swift.String? {
  if let d = node.as(StructDeclSyntax.self) { return d.name.text }
  if let d = node.as(ClassDeclSyntax.self) { return d.name.text }
  if let d = node.as(ActorDeclSyntax.self) { return d.name.text }
  if let d = node.as(ProtocolDeclSyntax.self) { return d.name.text }
  if let d = node.as(EnumDeclSyntax.self) { return d.name.text }
  return nil
}

private func structureFileNameNestedPathIsPrimaryTypeDecl(_ decl: DeclSyntax) -> Swift.Bool {
  decl.is(StructDeclSyntax.self)
    || decl.is(ClassDeclSyntax.self)
    || decl.is(EnumDeclSyntax.self)
    || decl.is(ActorDeclSyntax.self)
    || decl.is(ProtocolDeclSyntax.self)
}

/// One top-level primary nominal type found by the collector, together
/// with the enclosing extension's dotted prefix (empty if declared
/// directly at top level) and the wrapping extension node itself (used
/// to exclude it from cascade suppression's "other extensions" set).
private struct StructureFileNameNestedPathPrimary {
  let node: DeclSyntax
  let namePosition: AbsolutePosition
  let extensionPrefix: Swift.String
  let wrappingExtension: ExtensionDeclSyntax?
}

/// Walks top-level statements only (does not descend into type or
/// extension bodies beyond one level) collecting:
/// - every top-level `extension` declaration, and
/// - every top-level primary nominal type, whether declared directly
///   or as the sole nominal member of a top-level extension.
private final class StructureFileNameNestedPathCollector: SyntaxVisitor {
  var primaryTypes: [StructureFileNameNestedPathPrimary] = []
  var topLevelExtensions: [ExtensionDeclSyntax] = []

  init() { super.init(viewMode: .sourceAccurate) }

  override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
    for item in node.statements {
      guard case .decl(let decl) = item.item else { continue }
      if let extensionDecl = decl.as(ExtensionDeclSyntax.self) {
        topLevelExtensions.append(extensionDecl)
        let prefix = structureHoistedProtocolAliasDottedName(of: extensionDecl.extendedType) ?? ""
        var nominalMembers: [DeclSyntax] = []
        for member in extensionDecl.memberBlock.members
        where structureFileNameNestedPathIsPrimaryTypeDecl(member.decl) {
          nominalMembers.append(member.decl)
        }
        if nominalMembers.count == 1 {
          let nominal = nominalMembers[0]
          primaryTypes.append(
            StructureFileNameNestedPathPrimary(
              node: nominal,
              namePosition: structureFileNameNestedPathNamePosition(nominal),
              extensionPrefix: prefix,
              wrappingExtension: extensionDecl
            ))
        }
        continue
      }
      guard structureFileNameNestedPathIsPrimaryTypeDecl(decl) else { continue }
      primaryTypes.append(
        StructureFileNameNestedPathPrimary(
          node: decl,
          namePosition: structureFileNameNestedPathNamePosition(decl),
          extensionPrefix: "",
          wrappingExtension: nil
        ))
    }
    return .skipChildren
  }
}

private func structureFileNameNestedPathNamePosition(_ node: DeclSyntax) -> AbsolutePosition {
  if let d = node.as(StructDeclSyntax.self) { return d.name.positionAfterSkippingLeadingTrivia }
  if let d = node.as(ClassDeclSyntax.self) { return d.name.positionAfterSkippingLeadingTrivia }
  if let d = node.as(EnumDeclSyntax.self) { return d.name.positionAfterSkippingLeadingTrivia }
  if let d = node.as(ActorDeclSyntax.self) { return d.name.positionAfterSkippingLeadingTrivia }
  if let d = node.as(ProtocolDeclSyntax.self) { return d.name.positionAfterSkippingLeadingTrivia }
  return node.positionAfterSkippingLeadingTrivia
}
