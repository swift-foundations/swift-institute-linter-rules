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

/// In byte-domain extensions (`extension [Byte]`, `extension Array where
/// Element == Byte`, `extension ContiguousArray where Element == Byte`,
/// `extension ArraySlice where Element == Byte`, `extension
/// RangeReplaceableCollection where Element == Byte`), any function or
/// initializer that takes a `UInt8` parameter or returns `[UInt8]` /
/// `Array<UInt8>` / `ContiguousArray<UInt8>` MUST carry the
/// `@_disfavoredOverload` attribute. These are stdlib-interop forwarders;
/// the primary path is byte-typed and the forwarders exist only to bridge
/// for stdlib callers. Without `@_disfavoredOverload` the forwarder
/// competes with the Byte-typed primary at overload resolution.
/// Citation: `[API-BYTE-006]`.
extension Lint.Rule {
    public static let `uint8 forwarder missing disfavored` = Lint.Rule(
        id: "uint8 forwarder missing disfavored",
        default: .warning,
        findings: { source, severity in
            let visitor = ByteUInt8ForwarderMissingDisfavoredVisitor(
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
internal let byteUInt8ForwarderMissingDisfavoredMessage: Swift.String =
    "[uint8 forwarder missing disfavored] [API-BYTE-006]: function in a "
    + "byte-domain extension takes a `UInt8` parameter or returns "
    + "`[UInt8]` without `@_disfavoredOverload`. The primary path is "
    + "`Byte`-typed; the `UInt8` forwarder MUST carry "
    + "`@_disfavoredOverload` so the stdlib-interop bridge does not "
    + "compete with the Byte primary at overload resolution. Either add "
    + "`@_disfavoredOverload` or remove the UInt8-typed companion."

internal final class ByteUInt8ForwarderMissingDisfavoredVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    /// Stack of byte-domain context markers (true when inside an
    /// extension whose extended type is `[Byte]` or an extension on a
    /// stdlib collection with a `where Element == Byte` clause).
    private var contextStack: [Swift.Bool] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        contextStack.append(byteExtensionIsByteDomain(node))
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        if !contextStack.isEmpty {
            contextStack.removeLast()
        }
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard contextStack.last == true else { return .visitChildren }
        guard !byteFunctionHasDisfavoredOverload(node.attributes) else { return .visitChildren }
        if byteFunctionMentionsUInt8(node) {
            emit(at: node.funcKeyword.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard contextStack.last == true else { return .visitChildren }
        guard !byteFunctionHasDisfavoredOverload(node.attributes) else { return .visitChildren }
        if byteInitializerMentionsUInt8(node) {
            emit(at: node.initKeyword.positionAfterSkippingLeadingTrivia)
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
            identifier: "uint8 forwarder missing disfavored",
            message: byteUInt8ForwarderMissingDisfavoredMessage
        ))
    }
}

/// Stdlib collection type names whose `where Element == Byte` extension
/// brings us into byte-domain context.
private let byteCollectionTypeNames: Swift.Set<Swift.String> = [
    "Array",
    "ContiguousArray",
    "ArraySlice",
    "RangeReplaceableCollection",
    "Collection",
    "Sequence",
]

/// Returns true when the extension's extended type and where-clause
/// indicate byte-domain context (i.e., `extension [Byte]`, `extension
/// Array<Byte>`, `extension Array where Element == Byte`, etc.).
private func byteExtensionIsByteDomain(_ node: ExtensionDeclSyntax) -> Swift.Bool {
    if byteTypeIsArrayOfByte(node.extendedType) {
        return true
    }
    if byteTypeIsStdlibCollectionWithByteElement(node.extendedType, whereClause: node.genericWhereClause) {
        return true
    }
    return false
}

/// `extension [Byte]` / `extension Array<Byte>` / `extension
/// ContiguousArray<Byte>` shapes.
private func byteTypeIsArrayOfByte(_ type: TypeSyntax) -> Swift.Bool {
    if let arrayType = type.as(ArrayTypeSyntax.self) {
        return byteTypeIsByteToken(arrayType.element)
    }
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        let leaf = byteStripBackticks(identifier.name.text)
        if byteCollectionTypeNames.contains(leaf),
           let genericArgs = identifier.genericArgumentClause {
            for arg in genericArgs.arguments {
                if let argType = arg.argument.as(TypeSyntax.self),
                   byteTypeIsByteToken(argType) {
                    return true
                }
            }
        }
        return false
    }
    return false
}

/// `extension Array where Element == Byte` shape.
private func byteTypeIsStdlibCollectionWithByteElement(
    _ type: TypeSyntax,
    whereClause: GenericWhereClauseSyntax?
) -> Swift.Bool {
    guard let identifier = type.as(IdentifierTypeSyntax.self) else { return false }
    guard byteCollectionTypeNames.contains(byteStripBackticks(identifier.name.text)) else { return false }
    guard let whereClause else { return false }
    for requirement in whereClause.requirements {
        if byteRequirementIsElementEqualsByte(requirement) {
            return true
        }
    }
    return false
}

private func byteTypeIsByteToken(_ type: TypeSyntax) -> Swift.Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return byteStripBackticks(identifier.name.text) == "Byte"
    }
    if let memberType = type.as(MemberTypeSyntax.self) {
        return byteStripBackticks(memberType.name.text) == "Byte"
    }
    return false
}

private func byteRequirementIsElementEqualsByte(_ requirement: GenericRequirementSyntax) -> Swift.Bool {
    guard let sameType = requirement.requirement.as(SameTypeRequirementSyntax.self) else { return false }
    let left = byteStripBackticks(sameType.leftType.trimmedDescription)
    guard left == "Element" else { return false }
    let right = byteStripBackticks(sameType.rightType.trimmedDescription)
    return right == "Byte" || right.hasSuffix(".Byte")
}

/// Returns true when `node` has any parameter typed `UInt8` (or `[UInt8]`
/// / `Array<UInt8>` / etc.) OR a return type involving `UInt8`.
private func byteFunctionMentionsUInt8(_ node: FunctionDeclSyntax) -> Swift.Bool {
    for parameter in node.signature.parameterClause.parameters {
        if byteTypeMentionsUInt8(parameter.type) {
            return true
        }
    }
    if let returnClause = node.signature.returnClause {
        if byteTypeMentionsUInt8(returnClause.type) {
            return true
        }
    }
    return false
}

private func byteInitializerMentionsUInt8(_ node: InitializerDeclSyntax) -> Swift.Bool {
    for parameter in node.signature.parameterClause.parameters {
        if byteTypeMentionsUInt8(parameter.type) {
            return true
        }
    }
    return false
}

/// Returns true when `type` contains a `UInt8` token at any depth
/// (`UInt8`, `[UInt8]`, `Array<UInt8>`, `Swift.UInt8`, `inout UInt8`,
/// `Optional<UInt8>`, `Span<UInt8>`).
private func byteTypeMentionsUInt8(_ type: TypeSyntax) -> Swift.Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        if byteStripBackticks(identifier.name.text) == "UInt8" {
            return true
        }
        if let genericArgs = identifier.genericArgumentClause {
            for arg in genericArgs.arguments {
                if let inner = arg.argument.as(TypeSyntax.self), byteTypeMentionsUInt8(inner) {
                    return true
                }
            }
        }
        return false
    }
    if let memberType = type.as(MemberTypeSyntax.self) {
        if byteStripBackticks(memberType.name.text) == "UInt8" {
            return true
        }
        return false
    }
    if let arrayType = type.as(ArrayTypeSyntax.self) {
        return byteTypeMentionsUInt8(arrayType.element)
    }
    if let optionalType = type.as(OptionalTypeSyntax.self) {
        return byteTypeMentionsUInt8(optionalType.wrappedType)
    }
    if let implicitlyUnwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return byteTypeMentionsUInt8(implicitlyUnwrapped.wrappedType)
    }
    if let attributedType = type.as(AttributedTypeSyntax.self) {
        return byteTypeMentionsUInt8(attributedType.baseType)
    }
    return false
}
