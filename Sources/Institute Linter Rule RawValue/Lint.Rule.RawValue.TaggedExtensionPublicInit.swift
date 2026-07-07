// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Linter_Primitives
internal import SwiftSyntax

/// Wave 2b finalization (2026-05-10) — extensions on `Tagged` MUST NOT
/// expose public initializers.
///
/// Citation: `[PATTERN-019]` (implementation skill, patterns.md).
///
/// `Tagged<Tag, RawValue>` carries bounded invariants in its `Tag` —
/// brand-newtypes encode "this `String` is a `User.ID`, not a free
/// string". Extending `Tagged` with a `public init` that takes a
/// `RawValue` (or anything else) bypasses the type's bounded
/// construction surface: callers who go through the extension init
/// have not crossed any validation gate the brand owner controls.
///
/// AST shape: `ExtensionDeclSyntax` whose extended type starts with
/// `Tagged` (covers `Tagged<...>`, `Tagged where ...`, etc.) AND whose
/// member block contains an `InitializerDeclSyntax` with a `public`
/// modifier. Each public init in the extension is flagged.
extension Lint.Rule {
    /// Flags `public init` declarations in extensions on `Tagged`, which bypass the brand owner's bounded construction surface ([PATTERN-019]).
    ///
    /// Extensions declaring conformance to a protocol whose contract requires
    /// the init (literal protocols, `RawRepresentable`, hoisted `` `Protocol` ``
    /// witnesses) and free-generic-`Tag` domain extensions are exempt.
    public static let `tagged extension public init` = Lint.Rule(
        id: "tagged extension public init",
        default: .warning,
        findings: { source, severity in
            // §A brand-owner recognizer: a brand owner's own
            // `extension Tagged where Tag == <its brand> { public init }`
            // domain extension is legitimate-by-construction. Retires the
            // per-package `.excluding(rules:)` stopgap ([LINT-EXCLUDE-*]).
            if Lint.Brand.owned(Lint.Brand.numericBoundaryVocabulary, in: source) { return [] }
            let visitor = RawValueTaggedExtensionPublicInitVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let taggedExtensionPublicInitMessage: Swift.String =
    "[tagged extension public init] [PATTERN-019]: extensions on `Tagged` "
    + "MUST NOT provide `public init` — bypasses the brand's bounded invariants. "
    + "Callers reaching through an extension init never cross the validation gate "
    + "the tag owner controls. Drop the init, or move construction behind a "
    + "validating factory at the brand owner's layer."

/// Stdlib / institute protocols whose `public init(...)` requirement
/// is the protocol contract — the conformer MUST provide the init or
/// the conformance is impossible.
///
/// The validation gate IS the protocol
/// requirement (each init's body still delegates to the underlying
/// type's literal-protocol witness for actual validation). Exempt
/// these inits from the brand-bypass rule when declared inside an
/// extension conforming to the named protocol.
///
/// Implements [RULE-EXEMPT-2] (protocol-witness-citation-dict): the
/// dict is the citation surface — each entry pairs a witness name
/// with the specific protocol whose contract dictates it. Composes
/// with [RULE-EXEMPT-5] (Protocol-sentinel) via the `"Protocol"` and
/// `` "`Protocol`" `` entries, which exempt the institute hoisted-
/// protocol pattern ([API-IMPL-009] / [PKG-NAME-001]) — extensions
/// conforming to a nested `Carrier.\`Protocol\`` /
/// `Ordering.\`Protocol\`` witness alias. The backtick-escaped form
/// is load-bearing: bare `Carrier.Protocol` parses as
/// `MetatypeTypeSyntax` (Swift's `.Protocol` metatype keyword) and is
/// not captured by the inheritance-leaf walker; the institute idiom
/// always uses the escaped spelling. The bare `"Protocol"` dict entry
/// is retained for defense-in-depth against future SwiftSyntax
/// behavior changes.
///
/// Citation discipline: each entry names the specific protocol whose
/// init contract justifies the exemption. Adding an entry without a
/// citation is indefensible at review time.
///
/// Skill home: swift-institute/Skills/rule-exemptions/SKILL.md.
private let taggedExtensionPublicInitProtocolWitnessCitations: [Swift.String: Swift.String] = [
    "ExpressibleByIntegerLiteral": "Swift.ExpressibleByIntegerLiteral — init(integerLiteral:) protocol witness",
    "ExpressibleByFloatLiteral": "Swift.ExpressibleByFloatLiteral — init(floatLiteral:) protocol witness",
    "ExpressibleByUnicodeScalarLiteral": "Swift.ExpressibleByUnicodeScalarLiteral — init(unicodeScalarLiteral:) protocol witness",
    "ExpressibleByExtendedGraphemeClusterLiteral": "Swift.ExpressibleByExtendedGraphemeClusterLiteral — init(extendedGraphemeClusterLiteral:) protocol witness",
    "ExpressibleByStringLiteral": "Swift.ExpressibleByStringLiteral — init(stringLiteral:) protocol witness",
    "ExpressibleByBooleanLiteral": "Swift.ExpressibleByBooleanLiteral — init(booleanLiteral:) protocol witness",
    "ExpressibleByStringInterpolation": "Swift.ExpressibleByStringInterpolation — init(stringInterpolation:) protocol witness",
    "ExpressibleByArrayLiteral": "Swift.ExpressibleByArrayLiteral — init(arrayLiteral:) protocol witness",
    "ExpressibleByDictionaryLiteral": "Swift.ExpressibleByDictionaryLiteral — init(dictionaryLiteral:) protocol witness",
    "ExpressibleByNilLiteral": "Swift.ExpressibleByNilLiteral — init(nilLiteral:) protocol witness",
    "LosslessStringConvertible": "Swift.LosslessStringConvertible — init?(_:) protocol witness",
    "RawRepresentable": "Swift.RawRepresentable — init?(rawValue:) protocol witness",
    "Decodable": "Swift.Decodable — init(from:) protocol witness",
    "Codable": "Swift.Codable — Decodable.init(from:) protocol witness",
    "Protocol": "Institute hoisted-protocol witness ([API-IMPL-009] pattern; e.g., Carrier.Protocol)",
    "`Protocol`": "Institute hoisted-protocol witness ([API-IMPL-009] pattern; e.g., Carrier.`Protocol`)",
]

internal final class RawValueTaggedExtensionPublicInitVisitor: SyntaxVisitor {
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

    private func extendsTagged(_ extendedType: TypeSyntax) -> Bool {
        // Match `Tagged`, `Tagged<...>`, `Tagged_Primitives.Tagged`, or any
        // qualified path ending in `.Tagged`. Use trimmed description as
        // the canonical form; check first identifier or last segment.
        let text = extendedType.trimmedDescription
        if text == "Tagged" || text.hasPrefix("Tagged<") || text.hasPrefix("Tagged ") {
            return true
        }
        // Qualified: `Tagging.Tagged`, `Foo.Bar.Tagged<...>`.
        if let lastSegment = text.split(separator: ".").last {
            let segment = String(lastSegment)
            if segment == "Tagged" || segment.hasPrefix("Tagged<") || segment.hasPrefix("Tagged ") {
                return true
            }
        }
        return false
    }

    private func hasPublicModifier(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            if modifier.name.tokenKind == .keyword(.public) || modifier.name.tokenKind == .keyword(.open) {
                return true
            }
        }
        return false
    }

    /// Returns the leaf protocol names from the extension's inheritance
    /// clause.
    ///
    /// Used to gate the protocol-witness exemption.
    private func inheritanceLeafNames(_ clause: InheritanceClauseSyntax?) -> [Swift.String] {
        guard let clause else { return [] }
        var names: [Swift.String] = []
        for inherited in clause.inheritedTypes {
            if let identifier = inherited.type.as(IdentifierTypeSyntax.self) {
                names.append(identifier.name.text)
            } else if let member = inherited.type.as(MemberTypeSyntax.self) {
                names.append(member.name.text)
            }
        }
        return names
    }

    /// Returns true when the where clause binds `Underlying` to a
    /// concrete type via `SameTypeRequirementSyntax` AND does NOT bind
    /// `Tag` to a concrete type via the same.
    ///
    /// The first condition signals
    /// "this extension is a domain extension on the Underlying axis";
    /// the second signals "Tag is free / generic / constrained but not
    /// bound." Together they identify the free-generic-Tag domain
    /// extension shape where the per-Tag validation gate is structurally
    /// inexpressible.
    private func isFreeGenericTagDomainExtension(_ clause: GenericWhereClauseSyntax?) -> Swift.Bool {
        guard let clause else { return false }
        var bindsUnderlying = false
        var bindsTag = false
        for requirement in clause.requirements {
            guard let sameType = requirement.requirement.as(SameTypeRequirementSyntax.self) else {
                continue
            }
            let lhs = sameType.leftType.trimmedDescription
            if lhs == "Underlying" {
                bindsUnderlying = true
            } else if lhs == "Tag" {
                bindsTag = true
            }
        }
        return bindsUnderlying && !bindsTag
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard extendsTagged(node.extendedType) else {
            return .visitChildren
        }
        // Exempt per [RULE-EXEMPT-2] (protocol-witness-citation-dict):
        // if the extension declares conformance to a protocol whose
        // init contract requires the public init, the protocol IS the
        // validation gate. Skip the entire extension's init checks in
        // that case. Composes with [RULE-EXEMPT-5] (Protocol-sentinel)
        // via the `"Protocol"` / `` "`Protocol`" `` dict entries,
        // covering the institute hoisted-protocol pattern
        // ([API-IMPL-009] / [PKG-NAME-001]). Skill home:
        // swift-institute/Skills/rule-exemptions/SKILL.md.
        let conformingProtocols = inheritanceLeafNames(node.inheritanceClause)
        let isProtocolWitnessExtension = conformingProtocols.contains { proto in
            taggedExtensionPublicInitProtocolWitnessCitations[proto] != nil
        }
        if isProtocolWitnessExtension {
            return .visitChildren
        }
        // Free-generic-Tag domain extension admit: when the extension
        // binds `Underlying` to a concrete type but leaves `Tag` free
        // (no `where Tag == <concrete>` requirement), there is no
        // specific tag owner at which the validation gate could live.
        // The institute pattern uses this shape for typed bridges
        // between numerics-domain primitives (Cardinal ↔ Ordinal ↔
        // Vector etc.); the construction does pass through the
        // underlying type's own typed factory (`Cardinal.init(_:)`,
        // `Ordinal.init(_:)`), which IS the validation gate for the
        // Underlying axis — tag-specific invariants are out of scope
        // because Tag is free by construction.
        if isFreeGenericTagDomainExtension(node.genericWhereClause) {
            return .visitChildren
        }
        for member in node.memberBlock.members {
            guard let initDecl = member.decl.as(InitializerDeclSyntax.self) else {
                continue
            }
            guard hasPublicModifier(initDecl.modifiers) else {
                continue
            }
            let location = converter.location(for: initDecl.initKeyword.positionAfterSkippingLeadingTrivia)
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "tagged extension public init",
                    message: taggedExtensionPublicInitMessage
                )
            )
        }
        return .visitChildren
    }
}
