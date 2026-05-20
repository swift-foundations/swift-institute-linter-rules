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

/// Stdlib-interop `@_disfavoredOverload` UInt8 forwarders MUST live in
/// `* Standard Library Integration` modules, NOT in byte-domain primary
/// modules. The forwarder bridges `[Byte]`-typed primary API to stdlib
/// `[UInt8]` callers; its host module belongs to SLI.
/// Citation: `[API-BYTE-007]`.
extension Lint.Rule {
    public static let `stdlib forwarder outside sli` = Lint.Rule(
        id: "stdlib forwarder outside sli",
        default: .warning,
        findings: { source, severity in
            let visitor = ByteStdlibForwarderOutsideSLIVisitor(
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
internal let byteStdlibForwarderOutsideSLIMessage: Swift.String =
    "[stdlib forwarder outside sli] [API-BYTE-007]: function or initializer "
    + "carries `@_disfavoredOverload` and references `UInt8` in its surface "
    + "(parameter, return, or generic constraint), but lives in a byte-domain "
    + "primary module. Stdlib-interop UInt8 forwarders MUST live in the "
    + "package's `* Standard Library Integration` target (the forwarder "
    + "delegates to the `[Byte]`-typed primary via `.lazy.map(Byte.init)` "
    + "or `[Byte](uint8s)`). Move this declaration to a sibling target "
    + "named `<Package> Standard Library Integration`."

internal final class ByteStdlibForwarderOutsideSLIVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    /// True when the source file's host target is a Standard Library
    /// Integration module — rule does not fire there.
    private let hostIsSLI: Swift.Bool

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.hostIsSLI = byteStdlibForwarderHostIsSLI(source.filePath)
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard !hostIsSLI else { return .visitChildren }
        guard byteStdlibForwarderHasDisfavoredOverload(node.attributes) else { return .visitChildren }
        if byteStdlibForwarderFunctionMentionsUInt8(node) {
            emit(at: node.funcKeyword.positionAfterSkippingLeadingTrivia)
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard !hostIsSLI else { return .visitChildren }
        guard byteStdlibForwarderHasDisfavoredOverload(node.attributes) else { return .visitChildren }
        if byteStdlibForwarderInitializerMentionsUInt8(node) {
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
            identifier: "stdlib forwarder outside sli",
            message: byteStdlibForwarderOutsideSLIMessage
        ))
    }
}

/// Returns true when `filePath` indicates the source is in a target whose
/// name ends in `Standard Library Integration`. The host target name is
/// the path component immediately following `Sources/`.
private func byteStdlibForwarderHostIsSLI(_ filePath: Swift.String) -> Swift.Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true).map(Swift.String.init)
    for index in components.indices where components[index] == "Sources" {
        let targetIndex = components.index(after: index)
        guard targetIndex < components.endIndex else { return false }
        return components[targetIndex].hasSuffix("Standard Library Integration")
    }
    return false
}

private func byteStdlibForwarderHasDisfavoredOverload(_ attributes: AttributeListSyntax) -> Swift.Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        if attr.attributeName.trimmedDescription == "_disfavoredOverload" {
            return true
        }
    }
    return false
}

private func byteStdlibForwarderFunctionMentionsUInt8(_ node: FunctionDeclSyntax) -> Swift.Bool {
    for parameter in node.signature.parameterClause.parameters {
        if byteStdlibForwarderTypeMentionsUInt8(parameter.type) {
            return true
        }
    }
    if let returnClause = node.signature.returnClause {
        if byteStdlibForwarderTypeMentionsUInt8(returnClause.type) {
            return true
        }
    }
    if let whereClause = node.genericWhereClause {
        if byteStdlibForwarderWhereClauseMentionsUInt8(whereClause) {
            return true
        }
    }
    return false
}

private func byteStdlibForwarderInitializerMentionsUInt8(_ node: InitializerDeclSyntax) -> Swift.Bool {
    for parameter in node.signature.parameterClause.parameters {
        if byteStdlibForwarderTypeMentionsUInt8(parameter.type) {
            return true
        }
    }
    if let whereClause = node.genericWhereClause {
        if byteStdlibForwarderWhereClauseMentionsUInt8(whereClause) {
            return true
        }
    }
    return false
}

private func byteStdlibForwarderWhereClauseMentionsUInt8(_ whereClause: GenericWhereClauseSyntax) -> Swift.Bool {
    for requirement in whereClause.requirements {
        if let sameType = requirement.requirement.as(SameTypeRequirementSyntax.self) {
            let right = byteStdlibForwarderStripBackticks(sameType.rightType.trimmedDescription)
            if right == "UInt8" || right == "Swift.UInt8" {
                return true
            }
            let left = byteStdlibForwarderStripBackticks(sameType.leftType.trimmedDescription)
            if left == "UInt8" || left == "Swift.UInt8" {
                return true
            }
        }
    }
    return false
}

private func byteStdlibForwarderTypeMentionsUInt8(_ type: TypeSyntax) -> Swift.Bool {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        let leaf = byteStdlibForwarderStripBackticks(identifier.name.text)
        if leaf == "UInt8" {
            return true
        }
        if let genericArgs = identifier.genericArgumentClause {
            for arg in genericArgs.arguments {
                if let inner = arg.argument.as(TypeSyntax.self),
                   byteStdlibForwarderTypeMentionsUInt8(inner) {
                    return true
                }
            }
        }
        return false
    }
    if let memberType = type.as(MemberTypeSyntax.self) {
        let leaf = byteStdlibForwarderStripBackticks(memberType.name.text)
        if leaf == "UInt8" {
            return true
        }
        return false
    }
    if let arrayType = type.as(ArrayTypeSyntax.self) {
        return byteStdlibForwarderTypeMentionsUInt8(arrayType.element)
    }
    if let optionalType = type.as(OptionalTypeSyntax.self) {
        return byteStdlibForwarderTypeMentionsUInt8(optionalType.wrappedType)
    }
    if let implicitlyUnwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return byteStdlibForwarderTypeMentionsUInt8(implicitlyUnwrapped.wrappedType)
    }
    if let attributedType = type.as(AttributedTypeSyntax.self) {
        return byteStdlibForwarderTypeMentionsUInt8(attributedType.baseType)
    }
    return false
}

private func byteStdlibForwarderStripBackticks(_ name: Swift.String) -> Swift.String {
    var s = name
    if s.hasPrefix("`") { s.removeFirst() }
    if s.hasSuffix("`") { s.removeLast() }
    return s
}
