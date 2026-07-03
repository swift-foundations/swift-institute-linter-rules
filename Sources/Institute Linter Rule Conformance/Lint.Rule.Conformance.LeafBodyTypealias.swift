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

/// Leaf conformers to `Parser.Protocol` / `Serializer.Protocol` /
/// `Coder.Protocol` MUST declare `public typealias Body = Never`
/// explicitly. Without it, witness-table emission for generic
/// conformers fails at link time with `Undefined symbols ... protocol
/// witness for body.getter`. Citation: `[API-IMPL-020]`.
extension Lint.Rule {
  public static let `leaf body typealias missing` = Lint.Rule(
    id: "leaf body typealias missing",
    default: .warning,
    findings: { source, severity in
      let visitor = ConformanceLeafBodyTypealiasVisitor(
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
internal let conformanceLeafBodyTypealiasMessage: Swift.String =
  "[leaf body typealias missing] [API-IMPL-020]: leaf conformer to "
  + "`Parser.\\`Protocol\\`` / `Serializer.\\`Protocol\\`` / "
  + "`Coder.\\`Protocol\\`` MUST declare `public typealias Body = Never` "
  + "explicitly. Generic leaf conformers without it fail at link time "
  + "with `Undefined symbols ... protocol witness for body.getter`; "
  + "non-generic leaf conformers SHOULD include it as the minimum-safe "
  + "pattern. Add `public typealias Body = Never` next to the other "
  + "associatedtype typealiases in the conformance."

internal final class ConformanceLeafBodyTypealiasVisitor: SyntaxVisitor {
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
    guard let inheritance = node.inheritanceClause else {
      return .visitChildren
    }
    guard inheritanceContainsLeafBodyProtocol(inheritance) else {
      return .visitChildren
    }
    if memberBlockHasBodyProperty(node.memberBlock) {
      return .visitChildren
    }
    if memberBlockHasBodyNeverTypealias(node.memberBlock) {
      return .visitChildren
    }
    emit(at: node.extensionKeyword.positionAfterSkippingLeadingTrivia)
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
        identifier: "leaf body typealias missing",
        message: conformanceLeafBodyTypealiasMessage
      ))
  }
}

/// The trailing path components of every protocol whose conformance
/// triggers the leaf-body-typealias requirement. Pairs are
/// `(host-namespace, protocol-name)` matched against the last two
/// segments of an inherited type's qualified name.
private let leafBodyProtocolPairs: [(host: Swift.String, name: Swift.String)] = [
  ("Parser", "Protocol"),
  ("Serializer", "Protocol"),
  ("Coder", "Protocol"),
]

/// Returns true when any inherited type in `clause` matches one of the
/// leaf-body-protocol pairs. Matching tolerates arbitrary leading
/// module / namespace qualification (e.g.,
/// `Parser_Primitives_Core.Parser.\`Protocol\``) by inspecting only the
/// trailing two path segments.
private func inheritanceContainsLeafBodyProtocol(_ clause: InheritanceClauseSyntax) -> Swift.Bool {
  for inherited in clause.inheritedTypes {
    if typeMatchesLeafBodyProtocol(inherited.type) {
      return true
    }
  }
  return false
}

/// Returns true when `type` is a `MemberTypeSyntax` whose trailing
/// `(baseTypeName, memberName)` pair (after stripping backticks) matches
/// any entry in `leafBodyProtocolPairs`.
private func typeMatchesLeafBodyProtocol(_ type: TypeSyntax) -> Swift.Bool {
  guard let memberType = type.as(MemberTypeSyntax.self) else { return false }
  let trailingName = stripBackticks(memberType.name.text)
  let baseName: Swift.String
  if let identifier = memberType.baseType.as(IdentifierTypeSyntax.self) {
    baseName = stripBackticks(identifier.name.text)
  } else if let nestedMember = memberType.baseType.as(MemberTypeSyntax.self) {
    baseName = stripBackticks(nestedMember.name.text)
  } else {
    return false
  }
  for pair in leafBodyProtocolPairs where pair.host == baseName && pair.name == trailingName {
    return true
  }
  return false
}

/// Returns true if `block` declares any binding named `body`.
/// Detection covers stored and computed forms; a `body` binding signals
/// the conformer delegates parsing/serialization to a sub-Parser/
/// Serializer body rather than implementing `parse(_:)` /
/// `serialize(_:)` directly.
private func memberBlockHasBodyProperty(_ block: MemberBlockSyntax) -> Swift.Bool {
  for member in block.members {
    guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
    for binding in variable.bindings {
      guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
      if stripBackticks(pattern.identifier.text) == "body" {
        return true
      }
    }
  }
  return false
}

/// Returns true if `block` declares `typealias Body = Never` (or
/// `Swift.Never`). Backticked variants on either side of `=` are
/// tolerated.
private func memberBlockHasBodyNeverTypealias(_ block: MemberBlockSyntax) -> Swift.Bool {
  for member in block.members {
    guard let typealiasDecl = member.decl.as(TypeAliasDeclSyntax.self) else { continue }
    guard stripBackticks(typealiasDecl.name.text) == "Body" else { continue }
    let value = typealiasDecl.initializer.value
    if let identifier = value.as(IdentifierTypeSyntax.self) {
      if stripBackticks(identifier.name.text) == "Never" {
        return true
      }
    }
    if let memberType = value.as(MemberTypeSyntax.self) {
      if stripBackticks(memberType.name.text) == "Never" {
        return true
      }
    }
  }
  return false
}

private func stripBackticks(_ text: Swift.String) -> Swift.String {
  guard text.hasPrefix("`") && text.hasSuffix("`") && text.count >= 2 else { return text }
  return Swift.String(text.dropFirst().dropLast())
}
