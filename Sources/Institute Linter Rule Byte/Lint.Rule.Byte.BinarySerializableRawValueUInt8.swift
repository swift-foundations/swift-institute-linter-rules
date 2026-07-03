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

/// Conformers to `Binary.Serializable` / `Binary.Parseable` with a
/// `rawValue: UInt8` storage property surface a per-site discrimination
/// decision per the W2 discrimination rubric
/// (`broader-l2-l3-byte-typing-gap-plan.md` § Wave 2). Two patterns:
///
/// 1. *Byte-domain* — rawValue is pure bit-field / kind-tag / opaque-byte
///    (no arithmetic). RETYPE storage to `Byte`.
/// 2. *Arithmetic-domain* — rawValue participates in arithmetic
///    (`- 1`, `* 4`, modular roll-over). KEEP storage as `UInt8`; bridge
///    via `.underlying` at the conformance boundary; the witness signature
///    still retypes to `Buffer.Element == Byte`.
///
/// The rule fires whenever the pattern surfaces; per-site disposition is
/// the writer's. AST cannot mechanically detect arithmetic usage on
/// `rawValue` (cross-function-body analysis). Each finding is a review
/// prompt — classify the rawValue's domain per the rubric, then apply
/// the matching pattern.
/// Citation: `[API-BYTE-004]`.
extension Lint.Rule {
  public static let `binary serializable rawvalue uint8` = Lint.Rule(
    id: "binary serializable rawvalue uint8",
    default: .warning,
    findings: { source, severity in
      let visitor = ByteBinarySerializableRawValueUInt8Visitor(
        source: source.file,
        severity: severity,
        converter: source.converter
      )
      visitor.walk(source.tree)
      return visitor.matches
    }
  )
}

@usableFromInline
internal let byteBinarySerializableRawValueUInt8Message: Swift.String =
  "[binary serializable rawvalue uint8] [API-BYTE-004]: type conforms "
  + "to `Binary.Serializable` / `Binary.Parseable` and stores "
  + "`rawValue: UInt8`. Per the W2 discrimination rubric (broader-l2-l3"
  + "-byte-typing-gap-plan.md § Wave 2): if rawValue participates in "
  + "arithmetic, KEEP `UInt8` and bridge via `.underlying`; if it's a "
  + "bit-field / kind-tag / opaque byte, RETYPE storage to `Byte`."

internal final class ByteBinarySerializableRawValueUInt8Visitor: SyntaxVisitor {
  let source: Source.File
  let severity: Diagnostic.Severity
  let converter: SourceLocationConverter
  var matches: [Diagnostic.Record] = []

  /// Set of nominal-type names whose declaration carries a
  /// `Binary.Serializable` (or sibling) conformance on the type-decl
  /// header. Populated in pass 1; queried in pass 2.
  private var conformingTypeNames: Swift.Set<Swift.String> = []
  private var typesWithRawValueUInt8: [(name: Swift.String, position: AbsolutePosition)] = []

  init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
    self.source = source
    self.severity = severity
    self.converter = converter
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    recordTypeDecl(name: node.name, inheritance: node.inheritanceClause)
    recordRawValueUInt8(name: node.name, members: node.memberBlock)
    return .visitChildren
  }

  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    recordTypeDecl(name: node.name, inheritance: node.inheritanceClause)
    recordRawValueUInt8(name: node.name, members: node.memberBlock)
    return .visitChildren
  }

  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    if let inheritance = node.inheritanceClause,
      inheritanceContainsSerializableLikeProtocol(inheritance),
      let typeName = byteExtensionExtendedLeafName(node.extendedType)
    {
      conformingTypeNames.insert(typeName)
    }
    return .visitChildren
  }

  private func recordTypeDecl(name: TokenSyntax, inheritance: InheritanceClauseSyntax?) {
    let typeName = byteStripBackticks(name.text)
    if let inheritance, inheritanceContainsSerializableLikeProtocol(inheritance) {
      conformingTypeNames.insert(typeName)
    }
  }

  private func recordRawValueUInt8(name: TokenSyntax, members: MemberBlockSyntax) {
    let typeName = byteStripBackticks(name.text)
    for member in members.members {
      guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
      for binding in variable.bindings {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
        if byteStripBackticks(pattern.identifier.text) != "rawValue" { continue }
        guard let typeAnnotation = binding.typeAnnotation else { continue }
        if byteTypeAnnotationIsUInt8(typeAnnotation.type) {
          typesWithRawValueUInt8.append(
            (typeName, pattern.identifier.positionAfterSkippingLeadingTrivia))
        }
      }
    }
  }

  override func visitPost(_ node: SourceFileSyntax) {
    for entry in typesWithRawValueUInt8 where conformingTypeNames.contains(entry.name) {
      let location = converter.location(for: entry.position)
      matches.append(
        Diagnostic.Record(
          location: Source.Location(
            fileID: source.fileID,
            filePath: source.filePath,
            line: location.line,
            column: location.column
          ),
          severity: severity,
          identifier: "binary serializable rawvalue uint8",
          message: byteBinarySerializableRawValueUInt8Message
        ))
    }
  }
}

/// Returns true when a type annotation reads as `UInt8` or `Swift.UInt8`.
internal func byteTypeAnnotationIsUInt8(_ type: TypeSyntax) -> Swift.Bool {
  if let identifier = type.as(IdentifierTypeSyntax.self) {
    return byteStripBackticks(identifier.name.text) == "UInt8"
  }
  if let memberType = type.as(MemberTypeSyntax.self) {
    let leaf = byteStripBackticks(memberType.name.text)
    guard leaf == "UInt8" else { return false }
    if let base = memberType.baseType.as(IdentifierTypeSyntax.self) {
      return byteStripBackticks(base.name.text) == "Swift"
    }
    return false
  }
  return false
}

/// Returns true when the inheritance clause names a Binary serializable-
/// family protocol (`Binary.Serializable`, `Binary.Parseable`).
internal func inheritanceContainsSerializableLikeProtocol(_ clause: InheritanceClauseSyntax)
  -> Swift.Bool
{
  for inherited in clause.inheritedTypes {
    if byteTypeIsSerializableLike(inherited.type) {
      return true
    }
  }
  return false
}

internal func byteTypeIsSerializableLike(_ type: TypeSyntax) -> Swift.Bool {
  guard let memberType = type.as(MemberTypeSyntax.self) else { return false }
  let trailingName = byteStripBackticks(memberType.name.text)
  guard trailingName == "Serializable" || trailingName == "Parseable" else { return false }
  if let identifier = memberType.baseType.as(IdentifierTypeSyntax.self) {
    return byteStripBackticks(identifier.name.text) == "Binary"
  }
  if let nestedMember = memberType.baseType.as(MemberTypeSyntax.self) {
    return byteStripBackticks(nestedMember.name.text) == "Binary"
  }
  return false
}

/// Returns the leaf component of an extension's extended type — e.g.,
/// `RFC_791.TypeOfService` → `"TypeOfService"`; bare `Foo` → `"Foo"`.
internal func byteExtensionExtendedLeafName(_ type: TypeSyntax) -> Swift.String? {
  if let identifier = type.as(IdentifierTypeSyntax.self) {
    return byteStripBackticks(identifier.name.text)
  }
  if let memberType = type.as(MemberTypeSyntax.self) {
    return byteStripBackticks(memberType.name.text)
  }
  return nil
}
