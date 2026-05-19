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

/// `Binary.Serializable` / `Binary.Parseable` (and sibling-family
/// protocols like `Binary.ASCII.Serializable`) witness implementations
/// MUST use `Buffer.Element == Byte` (or `Source.Element == Byte`),
/// NOT `== UInt8`. The protocol surface was retyped to `Byte` at
/// `swift-binary-primitives@b121c0e` (Wave 2 of the broader L2/L3 byte-
/// typing gap arc). The only legitimate `Buffer.Element == UInt8` shapes
/// are the explicit `@_disfavoredOverload` stdlib-interop forwarders
/// allowlisted in the W2 6-forwarder set; consumer-side witnesses MUST
/// retype.
/// Citation: `[API-BYTE-003]`.
extension Lint.Rule {
    public static let `binary serializable uint8 witness` = Lint.Rule(
        id: "binary serializable uint8 witness",
        default: .warning,
        findings: { source, severity in
            let visitor = ByteBinarySerializableUInt8WitnessVisitor(
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
internal let byteBinarySerializableUInt8WitnessMessage: Swift.String =
    "[binary serializable uint8 witness] [API-BYTE-003]: `Binary."
    + "Serializable` / `Binary.Parseable` witness uses `Buffer.Element == "
    + "UInt8` (or `Source.Element == UInt8`). The protocol surface is now "
    + "Byte-typed (Wave 2, swift-binary-primitives@b121c0e). Retype the "
    + "where-clause to `== Byte`. If this is a stdlib-interop forwarder, "
    + "add `@_disfavoredOverload` per [API-BYTE-006]."

/// Sibling-family protocols whose witness signatures take `Buffer.Element`
/// / `Source.Element` / `Bytes.Element` typed parameters. Detection on
/// the extension's inheritance clause; leaf-segment match per
/// [API-IMPL-020] convention.
private let byteSerializableLikeProtocolPairs: [(host: Swift.String, name: Swift.String)] = [
    ("Binary", "Serializable"),
    ("Binary", "Parseable"),
]

/// Witness associated-type names whose `== UInt8` constraint is what
/// the rule flags. Constraint shape is `<TypeParam>.Element == UInt8`.
private let byteWitnessElementTypeParameterNames: Swift.Set<Swift.String> = [
    "Buffer",
    "Bytes",
    "Source",
    "Sequence",
    "Collection",
]

internal final class ByteBinarySerializableUInt8WitnessVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    /// Stack of "inside a Binary.Serializable / Binary.Parseable
    /// extension" markers. We push on entering a qualifying extension
    /// and pop on leaving so that nested types do not inherit the gate.
    private var contextStack: [Swift.Bool] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let isQualifying = extensionConformsToSerializableLike(node)
        contextStack.append(isQualifying)
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        if !contextStack.isEmpty {
            contextStack.removeLast()
        }
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard contextStack.last == true else { return .visitChildren }
        let baseName = byteStripBackticks(node.name.text)
        guard byteWitnessFunctionNames.contains(baseName) else { return .visitChildren }
        if byteFunctionHasDisfavoredOverload(node.attributes) {
            return .visitChildren
        }
        guard let whereClause = node.genericWhereClause else { return .visitChildren }
        for requirement in whereClause.requirements {
            if byteRequirementIsElementEqualsUInt8(requirement) {
                emit(at: requirement.positionAfterSkippingLeadingTrivia)
                return .visitChildren
            }
        }
        return .visitChildren
    }

    private func emit(at position: AbsolutePosition) {
        let location = converter.location(for: position)
        matches.append(Diagnostic.Record(
            location: Source.Location(
                fileID: source.fileID,
                filePath: source.filePath,
                line: location.line,
                column: location.column
            ),
            severity: severity,
            identifier: "binary serializable uint8 witness",
            message: byteBinarySerializableUInt8WitnessMessage
        ))
    }
}

/// Witness function names the rule inspects for Element-equals-UInt8
/// where-clauses.
internal let byteWitnessFunctionNames: Swift.Set<Swift.String> = [
    "serialize",
    "parse",
    "init",
]

/// Returns true when the extension's inheritance clause names any of
/// `byteSerializableLikeProtocolPairs`. Matching tolerates leaf-segment-
/// only via `MemberTypeSyntax`.
internal func extensionConformsToSerializableLike(_ node: ExtensionDeclSyntax) -> Swift.Bool {
    guard let inheritance = node.inheritanceClause else { return false }
    for inherited in inheritance.inheritedTypes {
        if byteTypeMatchesSerializableLike(inherited.type) {
            return true
        }
    }
    return false
}

private func byteTypeMatchesSerializableLike(_ type: TypeSyntax) -> Swift.Bool {
    guard let memberType = type.as(MemberTypeSyntax.self) else { return false }
    let trailingName = byteStripBackticks(memberType.name.text)
    let baseName: Swift.String
    if let identifier = memberType.baseType.as(IdentifierTypeSyntax.self) {
        baseName = byteStripBackticks(identifier.name.text)
    } else if let nestedMember = memberType.baseType.as(MemberTypeSyntax.self) {
        baseName = byteStripBackticks(nestedMember.name.text)
    } else {
        return false
    }
    for pair in byteSerializableLikeProtocolPairs where pair.host == baseName && pair.name == trailingName {
        return true
    }
    return false
}

/// Returns true if a function carries `@_disfavoredOverload`.
internal func byteFunctionHasDisfavoredOverload(_ attributes: AttributeListSyntax) -> Swift.Bool {
    for element in attributes {
        guard let attribute = element.as(AttributeSyntax.self) else { continue }
        guard let identifier = attribute.attributeName.as(IdentifierTypeSyntax.self) else { continue }
        if byteStripBackticks(identifier.name.text) == "_disfavoredOverload" {
            return true
        }
    }
    return false
}

/// Returns true for `where <TypeParam>.Element == UInt8` shapes.
private func byteRequirementIsElementEqualsUInt8(_ requirement: GenericRequirementSyntax) -> Swift.Bool {
    guard let sameType = requirement.requirement.as(SameTypeRequirementSyntax.self) else { return false }
    let left = sameType.leftType.trimmedDescription
    let right = sameType.rightType.trimmedDescription
    // LHS: `<TypeParam>.Element` where TypeParam is in the recognized set.
    let leftIsElement: Swift.Bool = {
        let parts = left.split(separator: ".")
        guard parts.count == 2 else { return false }
        guard byteStripBackticks(Swift.String(parts[1])) == "Element" else { return false }
        return byteWitnessElementTypeParameterNames.contains(byteStripBackticks(Swift.String(parts[0])))
    }()
    guard leftIsElement else { return false }
    // RHS: `UInt8` or `Swift.UInt8`.
    return right == "UInt8" || right == "Swift.UInt8"
}
