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

/// `extension UInt8` MUST NOT declare members under the `.ascii` namespace
/// (static var ascii, static func ascii(...), nested type `UInt8.ASCII`,
/// etc.). The `UInt8+ASCII.swift` wrapper is being phased out in Wave 4
/// of the broader L2/L3 byte-typing arc; consumers MUST route through
/// `ASCII.Code` (the canonical typed substrate per
/// `byte-protocol-capability-marker.md` v1.1.0 and
/// `byte-arithmetic-conformance.md` v1.0.0).
///
/// Detection covers two shapes:
/// - `extension UInt8 { static var ascii ... }` (or `static func ascii`)
/// - `extension UInt8.ASCII { ... }` (extending the ASCII subspace on UInt8)
///
/// Citation: `[API-BYTE-005]`.
extension Lint.Rule {
  public static let `uint8 ascii extension` = Lint.Rule(
    id: "uint8 ascii extension",
    default: .warning,
    findings: { source, severity in
      let visitor = ByteUInt8AsciiExtensionVisitor(
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
internal let byteUInt8AsciiExtensionMessage: Swift.String =
  "[uint8 ascii extension] [API-BYTE-005]: `extension UInt8` declares "
  + "members under the `.ascii` namespace (or extends `UInt8.ASCII` "
  + "directly). The `UInt8+ASCII.swift` wrapper is phased out in Wave 4 "
  + "of the broader L2/L3 byte-typing arc. Migrate consumers to "
  + "`ASCII.Code` substrate (e.g., `ASCII.Code.lf` instead of "
  + "`UInt8.ascii.lf`)."

internal final class ByteUInt8AsciiExtensionVisitor: SyntaxVisitor {
  let source: Source.File
  let severity: Diagnostic.Severity
  let converter: SourceLocationConverter
  var matches: [Diagnostic.Record] = []

  init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
    self.source = source
    self.severity = severity
    self.converter = converter
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    if extensionExtendsUInt8DotASCII(node.extendedType) {
      emit(at: node.extensionKeyword.positionAfterSkippingLeadingTrivia)
      return .visitChildren
    }
    if extensionIsOnUInt8(node.extendedType),
      memberBlockDeclaresAsciiNamespaceMember(node.memberBlock)
    {
      emit(at: node.extensionKeyword.positionAfterSkippingLeadingTrivia)
    }
    return .visitChildren
  }

  private func emit(at position: AbsolutePosition) {
    let location = converter.location(for: position)
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "uint8 ascii extension",
        message: byteUInt8AsciiExtensionMessage
      ))
  }
}

/// Returns true when `type` is `UInt8.ASCII` (or `Swift.UInt8.ASCII`).
private func extensionExtendsUInt8DotASCII(_ type: TypeSyntax) -> Swift.Bool {
  guard let memberType = type.as(MemberTypeSyntax.self) else { return false }
  let trailing = byteStripBackticks(memberType.name.text)
  guard trailing == "ASCII" else { return false }
  if let identifier = memberType.baseType.as(IdentifierTypeSyntax.self) {
    return byteStripBackticks(identifier.name.text) == "UInt8"
  }
  if let nestedMember = memberType.baseType.as(MemberTypeSyntax.self) {
    let nestedTrailing = byteStripBackticks(nestedMember.name.text)
    guard nestedTrailing == "UInt8" else { return false }
    if let swiftBase = nestedMember.baseType.as(IdentifierTypeSyntax.self) {
      return byteStripBackticks(swiftBase.name.text) == "Swift"
    }
    return false
  }
  return false
}

/// Returns true when the extension on `UInt8` declares any member under
/// the `.ascii` name (static var, static func, or nested type named
/// `ASCII`).
private func memberBlockDeclaresAsciiNamespaceMember(_ block: MemberBlockSyntax) -> Swift.Bool {
  for member in block.members {
    if let variable = member.decl.as(VariableDeclSyntax.self) {
      for binding in variable.bindings {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
        if byteStripBackticks(pattern.identifier.text) == "ascii" {
          return true
        }
      }
    }
    if let function = member.decl.as(FunctionDeclSyntax.self) {
      if byteStripBackticks(function.name.text) == "ascii" {
        return true
      }
    }
    if let nestedEnum = member.decl.as(EnumDeclSyntax.self) {
      if byteStripBackticks(nestedEnum.name.text) == "ASCII" {
        return true
      }
    }
    if let nestedStruct = member.decl.as(StructDeclSyntax.self) {
      if byteStripBackticks(nestedStruct.name.text) == "ASCII" {
        return true
      }
    }
  }
  return false
}

/// Local `extensionIsOnUInt8` re-implementation (the public one in
/// `Lint.Rule.Byte.UInt8ConformsToByteProtocol.swift` is `private`).
private func extensionIsOnUInt8(_ type: TypeSyntax) -> Swift.Bool {
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
