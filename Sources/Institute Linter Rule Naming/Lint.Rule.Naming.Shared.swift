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

internal import SwiftSyntax

/// Pack-internal namespace for cross-file naming-rule helpers.
///
/// Cross-rule helpers live as static members on `Naming` (or nested
/// sub-namespaces `Naming.Build`, `Naming.Visitor`). The
/// `Naming` prefix on the namespace replaces the prior `naming*`
/// free-function corpus, which was prefix-disambiguated to avoid
/// cross-helper name collisions at file scope but tripped
/// [API-NAME-002] (compound identifier) on every helper. Nested
/// accessors give each leaf a single-word, non-compound shape (or a
/// boolean-prefix-exempt form like `isInsideExtensionPattern` /
/// `hasFileprivateOrPrivate`) per the rule's documented exemptions.
internal enum Naming {}

extension Naming {
  /// Result-builder protocol method names per Swift's `@resultBuilder`
  /// attribute (SE-0289). A function declared inside a type marked
  /// `@resultBuilder` and named one of these is protocol-required —
  /// its name and parameter / return types are dictated by the
  /// builder protocol's accumulator and expression types. The Naming
  /// pack treats these as spec-mirroring at the attribute level
  /// (see [API-NAME-003] semantics): the `@resultBuilder` attribute
  /// IS the specification.
  internal enum Build {}
}

extension Naming.Build {
  @usableFromInline
  internal static let methods: Swift.Set<Swift.String> = [
    "buildExpression",
    "buildBlock",
    "buildPartialBlock",
    "buildOptional",
    "buildEither",
    "buildArray",
    "buildLimitedAvailability",
    "buildFinalResult",
  ]
}

extension Naming {
  /// SwiftSyntax visitor-family base classes whose subclasses are
  /// exempt from the naming-pack rules per [RULE-EXEMPT-7]
  /// (syntax-visitor-subclass). The set covers the open base classes
  /// a rule-pack visitor legitimately extends — `SyntaxVisitor`,
  /// `SyntaxAnyVisitor`, `SyntaxRewriter`. The SwiftSyntax convention
  /// names these subclasses `<Subject>Visitor`, which trips
  /// [API-NAME-001] (compound type name) even though the suffix is
  /// dictated by the framework's idiom.
  ///
  /// Mirrors `Structure.Visitor.family` in the structure pack;
  /// cross-pack visibility isn't yet available across the
  /// universal/institute tier boundary, so the set is duplicated.
  internal enum Visitor {}
}

extension Naming.Visitor {
  @usableFromInline
  internal static let family: Swift.Set<Swift.String> = [
    "SyntaxVisitor",
    "SyntaxAnyVisitor",
    "SyntaxRewriter",
  ]

  /// Returns true if `clause` lists any member of the SwiftSyntax
  /// visitor family (`SyntaxVisitor`, `SyntaxAnyVisitor`,
  /// `SyntaxRewriter`) as an inherited type. Used by
  /// `Lint.Rule.Naming.CompoundType` to skip the compound-name
  /// check on rule-pack visitor subclasses whose `<Subject>Visitor`
  /// naming is dictated by the SwiftSyntax framework's idiom.
  ///
  /// Citation: [RULE-EXEMPT-7] (syntax-visitor-subclass) in
  /// the rule-exemptions skill.
  ///
  /// Leaf-name lookup mirrors `Naming.Visitor.inheritanceLeaves`
  /// semantics — both `IdentifierTypeSyntax` (bare `SyntaxVisitor`)
  /// and `MemberTypeSyntax` (qualified
  /// `SwiftSyntax.SyntaxVisitor`) resolve to the visitor's name.
  internal static func extends(_ clause: InheritanceClauseSyntax?) -> Swift.Bool {
    guard let clause else { return false }
    for inherited in clause.inheritedTypes {
      let type = inherited.type
      let leaf: Swift.String?
      if let identifier = type.as(IdentifierTypeSyntax.self) {
        leaf = identifier.name.text
      } else if let member = type.as(MemberTypeSyntax.self) {
        leaf = member.name.text
      } else {
        leaf = nil
      }
      if let leaf, family.contains(leaf) {
        return true
      }
    }
    return false
  }

  fileprivate static func inheritanceLeaves(_ clause: InheritanceClauseSyntax?) -> [Swift.String] {
    guard let clause else { return [] }
    var names: [Swift.String] = []
    for inherited in clause.inheritedTypes {
      let type = inherited.type
      if let identifier = type.as(IdentifierTypeSyntax.self) {
        names.append(identifier.name.text)
      } else if let member = type.as(MemberTypeSyntax.self) {
        names.append(member.name.text)
      }
    }
    return names
  }
}

extension Naming {
  /// Returns true if any enclosing type declaration of `node` carries
  /// an extension-pattern attribute (`@resultBuilder` or `@Suite`).
  /// Walks up the `parent` chain and stops at the first `struct` /
  /// `class` / `enum` / `actor` declaration — those are the decl
  /// kinds Swift permits these attributes on. Nested extensions are
  /// crossed without consuming the search (a method inside
  /// `extension Builder` inside an outer `@resultBuilder enum Builder`
  /// still finds the attribute on the enum).
  ///
  /// Implements [RULE-EXEMPT-4] (extension-pattern attribute) for
  /// naming rules whose firing on members must yield to the
  /// protocol-witness shape these attributes impose: SE-0289 builder
  /// method names for `@resultBuilder`, swift-testing's nested-suite
  /// shape for `@Suite`.
  internal static func isInsideExtensionPattern(_ node: Syntax) -> Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
      if let typeDecl = candidate.as(StructDeclSyntax.self) {
        return hasExtensionPattern(typeDecl.attributes)
      }
      if let typeDecl = candidate.as(EnumDeclSyntax.self) {
        return hasExtensionPattern(typeDecl.attributes)
      }
      if let typeDecl = candidate.as(ClassDeclSyntax.self) {
        return hasExtensionPattern(typeDecl.attributes)
      }
      if let typeDecl = candidate.as(ActorDeclSyntax.self) {
        return hasExtensionPattern(typeDecl.attributes)
      }
      current = candidate.parent
    }
    return false
  }

  /// Returns true if `attributes` includes either of the
  /// extension-pattern attributes — `@resultBuilder` (SE-0289 builder
  /// protocol) or `@Suite` (swift-testing's extension-pattern, which
  /// legitimately holds nested `@Suite` substructures as its body
  /// members). See [RULE-EXEMPT-4].
  internal static func hasExtensionPattern(_ attributes: AttributeListSyntax) -> Bool {
    for attribute in attributes {
      guard let attr = attribute.as(AttributeSyntax.self) else { continue }
      let name = attr.attributeName.trimmedDescription
      if name == "resultBuilder" || name == "Suite" {
        return true
      }
    }
    return false
  }

  /// Returns true if `node` is declared inside an enclosing context
  /// that introduces a protocol conformance — either an extension
  /// with a non-empty inheritance clause, or a type declaration
  /// (struct, class, enum, actor) with a non-empty inheritance
  /// clause. Typealiases declared in such a context typically
  /// satisfy an associatedtype requirement of the adopted protocol
  /// (`Collection.Index`, `Sequence.Element`,
  /// `Ownership.Borrow.Protocol.Borrowed`) — they share the
  /// protocol's name by requirement, not by discretionary choice.
  /// The walk-up stops at the first decl context.
  internal static func isInsideConformingContext(_ node: Syntax) -> Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
      if let ext = candidate.as(ExtensionDeclSyntax.self) {
        return ext.inheritanceClause != nil
      }
      if let typeDecl = candidate.as(StructDeclSyntax.self) {
        return typeDecl.inheritanceClause != nil
      }
      if let typeDecl = candidate.as(ClassDeclSyntax.self) {
        return typeDecl.inheritanceClause != nil
      }
      if let typeDecl = candidate.as(EnumDeclSyntax.self) {
        return typeDecl.inheritanceClause != nil
      }
      if let typeDecl = candidate.as(ActorDeclSyntax.self) {
        return typeDecl.inheritanceClause != nil
      }
      current = candidate.parent
    }
    return false
  }

  /// Returns the leaf names of every protocol in the nearest
  /// enclosing extension / type-decl's inheritance clause. Used by
  /// rule visitors that need to gate on which protocol the enclosing
  /// extension adopts (e.g., "is this `init(integerLiteral:)`
  /// declared inside an `extension Tagged: ExpressibleByIntegerLiteral`?").
  ///
  /// Leaf-name semantics: `Swift.Sequence` and `Sequence` both yield
  /// `"Sequence"`. Citation-dict consumers key on the leaf name so
  /// they don't need to enumerate every possible qualification.
  ///
  /// Recognised contexts:
  ///
  /// - Extension / type declaration with a non-empty inheritance
  ///   clause: returns the inherited protocol leaves.
  /// - **Protocol body**: returns the protocol's own name as a
  ///   single-element sentinel. A method declared inside `protocol P
  ///   { func foo() }` IS the protocol's own requirement; the
  ///   protocol-witness exemption should fire for stdlib-vocabulary
  ///   names whose semantics belong to the protocol's contract.
  /// - **Sibling extension / nested type with conformance** (case (c)):
  ///   when the immediate enclosing extension has no inheritance
  ///   clause, walk the source file for declarations of the same
  ///   extended type carrying a conformance. The conformance may
  ///   live on the original `struct X: P { … }` nested inside another
  ///   extension (`extension Outer { struct X: P { … } }`), or on a
  ///   sibling `extension X: P { … }` at file scope. This recovers
  ///   the cross-decl protocol-witness shape that Phase 1B
  ///   [API-IMPL-008] extractions introduced — methods moved out of
  ///   the conforming struct body into sibling methods extensions.
  ///
  /// Returns an empty array only when no relevant context exists.
  internal static func conformances(_ node: Syntax) -> [Swift.String] {
    var current: Syntax? = node.parent
    var immediateExtension: ExtensionDeclSyntax? = nil
    while let candidate = current {
      if let ext = candidate.as(ExtensionDeclSyntax.self) {
        immediateExtension = ext
        break
      }
      if let typeDecl = candidate.as(StructDeclSyntax.self) {
        return Visitor.inheritanceLeaves(typeDecl.inheritanceClause)
      }
      if let typeDecl = candidate.as(ClassDeclSyntax.self) {
        return Visitor.inheritanceLeaves(typeDecl.inheritanceClause)
      }
      if let typeDecl = candidate.as(EnumDeclSyntax.self) {
        return Visitor.inheritanceLeaves(typeDecl.inheritanceClause)
      }
      if let typeDecl = candidate.as(ActorDeclSyntax.self) {
        return Visitor.inheritanceLeaves(typeDecl.inheritanceClause)
      }
      if let protocolDecl = candidate.as(ProtocolDeclSyntax.self) {
        // Method/typealias inside a protocol body — the decl IS
        // a requirement of this protocol. Return the protocol's
        // own name as a single-element sentinel so the
        // exemption gate evaluates non-empty.
        return [protocolDecl.name.text]
      }
      current = candidate.parent
    }
    guard let ext = immediateExtension else { return [] }
    let leaves = Visitor.inheritanceLeaves(ext.inheritanceClause)
    if !leaves.isEmpty {
      return leaves
    }
    // Case (c): file-scope walk for cross-decl conformance.
    return Self.fileScopeConformances(
      for: ext.extendedType.trimmedDescription,
      origin: node
    )
  }

  /// Walks the enclosing source file for declarations of `targetPath`
  /// that carry an inheritance clause; returns the union of inherited
  /// protocol leaves. Used by ``conformances(_:)`` to recover
  /// cross-decl protocol-witness context.
  fileprivate static func fileScopeConformances(
    for targetPath: Swift.String,
    origin: Syntax
  ) -> [Swift.String] {
    var current: Syntax? = origin
    while let candidate = current {
      if let file = candidate.as(SourceFileSyntax.self) {
        var collected: [Swift.String] = []
        for statement in file.statements {
          Self.collectConformances(
            from: statement.item,
            targetPath: targetPath,
            currentPrefix: "",
            into: &collected
          )
        }
        return collected
      }
      current = candidate.parent
    }
    return []
  }

  /// Recursive collection: matches `targetPath` against the composed
  /// type path while descending through nested extensions and type
  /// declarations. Appends inherited protocol leaves into `collected`
  /// for every matching decl that carries an inheritance clause.
  fileprivate static func collectConformances(
    from item: CodeBlockItemSyntax.Item,
    targetPath: Swift.String,
    currentPrefix: Swift.String,
    into collected: inout [Swift.String]
  ) {
    if let ext = item.as(ExtensionDeclSyntax.self) {
      let extendedType = ext.extendedType.trimmedDescription
      let fullPath =
        currentPrefix.isEmpty
        ? extendedType
        : currentPrefix + "." + extendedType
      if fullPath == targetPath {
        collected.append(contentsOf: Visitor.inheritanceLeaves(ext.inheritanceClause))
      }
      for member in ext.memberBlock.members {
        Self.collectConformancesFromDecl(
          member.decl,
          targetPath: targetPath,
          currentPrefix: fullPath,
          into: &collected
        )
      }
      return
    }
    if let structDecl = item.as(StructDeclSyntax.self) {
      Self.collectFromTypeDecl(
        name: structDecl.name.text,
        inheritanceClause: structDecl.inheritanceClause,
        memberBlock: structDecl.memberBlock,
        targetPath: targetPath,
        currentPrefix: currentPrefix,
        into: &collected
      )
      return
    }
    if let classDecl = item.as(ClassDeclSyntax.self) {
      Self.collectFromTypeDecl(
        name: classDecl.name.text,
        inheritanceClause: classDecl.inheritanceClause,
        memberBlock: classDecl.memberBlock,
        targetPath: targetPath,
        currentPrefix: currentPrefix,
        into: &collected
      )
      return
    }
    if let enumDecl = item.as(EnumDeclSyntax.self) {
      Self.collectFromTypeDecl(
        name: enumDecl.name.text,
        inheritanceClause: enumDecl.inheritanceClause,
        memberBlock: enumDecl.memberBlock,
        targetPath: targetPath,
        currentPrefix: currentPrefix,
        into: &collected
      )
      return
    }
    if let actorDecl = item.as(ActorDeclSyntax.self) {
      Self.collectFromTypeDecl(
        name: actorDecl.name.text,
        inheritanceClause: actorDecl.inheritanceClause,
        memberBlock: actorDecl.memberBlock,
        targetPath: targetPath,
        currentPrefix: currentPrefix,
        into: &collected
      )
      return
    }
  }

  /// Member-level variant of ``collectConformances(from:targetPath:currentPrefix:into:)``
  /// operating on `DeclSyntax` (the shape inside a `MemberBlockSyntax`).
  fileprivate static func collectConformancesFromDecl(
    _ decl: DeclSyntax,
    targetPath: Swift.String,
    currentPrefix: Swift.String,
    into collected: inout [Swift.String]
  ) {
    if let structDecl = decl.as(StructDeclSyntax.self) {
      Self.collectFromTypeDecl(
        name: structDecl.name.text,
        inheritanceClause: structDecl.inheritanceClause,
        memberBlock: structDecl.memberBlock,
        targetPath: targetPath,
        currentPrefix: currentPrefix,
        into: &collected
      )
      return
    }
    if let classDecl = decl.as(ClassDeclSyntax.self) {
      Self.collectFromTypeDecl(
        name: classDecl.name.text,
        inheritanceClause: classDecl.inheritanceClause,
        memberBlock: classDecl.memberBlock,
        targetPath: targetPath,
        currentPrefix: currentPrefix,
        into: &collected
      )
      return
    }
    if let enumDecl = decl.as(EnumDeclSyntax.self) {
      Self.collectFromTypeDecl(
        name: enumDecl.name.text,
        inheritanceClause: enumDecl.inheritanceClause,
        memberBlock: enumDecl.memberBlock,
        targetPath: targetPath,
        currentPrefix: currentPrefix,
        into: &collected
      )
      return
    }
    if let actorDecl = decl.as(ActorDeclSyntax.self) {
      Self.collectFromTypeDecl(
        name: actorDecl.name.text,
        inheritanceClause: actorDecl.inheritanceClause,
        memberBlock: actorDecl.memberBlock,
        targetPath: targetPath,
        currentPrefix: currentPrefix,
        into: &collected
      )
      return
    }
  }

  fileprivate static func collectFromTypeDecl(
    name: Swift.String,
    inheritanceClause: InheritanceClauseSyntax?,
    memberBlock: MemberBlockSyntax,
    targetPath: Swift.String,
    currentPrefix: Swift.String,
    into collected: inout [Swift.String]
  ) {
    let fullPath =
      currentPrefix.isEmpty
      ? name
      : currentPrefix + "." + name
    if fullPath == targetPath {
      collected.append(contentsOf: Visitor.inheritanceLeaves(inheritanceClause))
    }
    for member in memberBlock.members {
      Self.collectConformancesFromDecl(
        member.decl,
        targetPath: targetPath,
        currentPrefix: fullPath,
        into: &collected
      )
    }
  }

  /// Returns true if `name` is the institute `Protocol` sentinel — a
  /// member name reserved for the hoisted-protocol pattern per
  /// [API-IMPL-009] / [PKG-NAME-001]. The sentinel can appear either
  /// raw (`Protocol`) or backtick-escaped (`` `Protocol` ``); both
  /// forms signal the same intent.
  ///
  /// Citation: [RULE-EXEMPT-5] (Protocol-sentinel) in
  /// the rule-exemptions skill.
  ///
  /// Used by name-shape rules that would otherwise flag the sentinel
  /// as a rename-bridge typealias (`UnificationTypealias`) or as a
  /// non-minimal type-body member (`MinimalTypeBody`). The institute
  /// pattern intentionally hoists the protocol witness through the
  /// nested-namespace alias `Carrier.Protocol`, `Ordering.Protocol`,
  /// `Equation.Protocol`, etc. — naming rules that target
  /// rename-bridge or extraction-from-body must skip this exact
  /// name.
  internal static func isProtocolSentinel(_ name: Swift.String) -> Swift.Bool {
    return name == "Protocol" || name == "`Protocol`"
  }

  /// Returns true if `modifiers` includes a `fileprivate` or
  /// `private` access-level modifier. Direct check of the
  /// declaration's own modifier list — does not walk up the parent
  /// chain. Use ``hasFileprivateOrPrivateEffective(_:modifiers:)``
  /// when the caller needs effective visibility (which considers
  /// enclosing-type access).
  internal static func hasFileprivateOrPrivate(_ modifiers: DeclModifierListSyntax) -> Bool {
    for modifier in modifiers {
      let kind = modifier.name.tokenKind
      if kind == .keyword(.fileprivate) || kind == .keyword(.private) {
        return true
      }
    }
    return false
  }

  /// Returns true if `node`'s *effective* visibility is `fileprivate`
  /// or `private` — either because the declaration itself carries
  /// the modifier, or because an enclosing type declaration (struct,
  /// class, enum, actor) carries it. Used by naming rules that
  /// exempt non-consumer-observable surface (decls invisible across
  /// the file boundary) per the [API-NAME-002] visibility-scope
  /// amendment.
  ///
  /// Swift access semantics: a member's effective access is the
  /// minimum of its declared access and the enclosing type's access.
  /// A `let` field without modifiers inside a `fileprivate struct`
  /// is effectively `fileprivate`, even though `node.modifiers` is
  /// empty. Walking up the parent chain captures that case.
  ///
  /// Walk-up stops at the first enclosing type / extension boundary
  /// that carries a `fileprivate` or `private` modifier. If none is
  /// found before the file root, returns the direct-modifier result
  /// on `node`.
  internal static func hasFileprivateOrPrivateEffective(
    _ node: Syntax,
    modifiers: DeclModifierListSyntax
  ) -> Bool {
    if hasFileprivateOrPrivate(modifiers) {
      return true
    }
    var current: Syntax? = node.parent
    while let candidate = current {
      if let typeDecl = candidate.as(StructDeclSyntax.self) {
        if hasFileprivateOrPrivate(typeDecl.modifiers) { return true }
      } else if let typeDecl = candidate.as(ClassDeclSyntax.self) {
        if hasFileprivateOrPrivate(typeDecl.modifiers) { return true }
      } else if let typeDecl = candidate.as(EnumDeclSyntax.self) {
        if hasFileprivateOrPrivate(typeDecl.modifiers) { return true }
      } else if let typeDecl = candidate.as(ActorDeclSyntax.self) {
        if hasFileprivateOrPrivate(typeDecl.modifiers) { return true }
      } else if let ext = candidate.as(ExtensionDeclSyntax.self) {
        if hasFileprivateOrPrivate(ext.modifiers) { return true }
        // An `extension T { … }` that carries no access modifier is NOT
        // automatically public — its members' effective access is capped
        // by `T`'s own access. When `T` is declared `private`/`fileprivate`
        // in this same file, every member added by the extension (and every
        // member of a type nested inside it) is effectively fileprivate and
        // has no consumer-observable surface. The modifier-only walk-up
        // missed this: the extension has no modifier and the extended type's
        // declaration is a SIBLING node, not an ancestor.
        //
        // Confirmed instance (2026-08-01, swift-institute/.github#90
        // comment 5150641576): compound `Codable` payload properties inside
        // `extension BulkTrackJob { struct Payload { let identityId … } }`
        // where `private struct BulkTrackJob` is declared earlier in the
        // same file still fired API-NAME-002.
        if extendsFilePrivateType(ext) { return true }
      }
      current = candidate.parent
    }
    return false
  }

  /// True when `ext` extends a type whose declaration in the SAME file
  /// carries `private` or `fileprivate`.
  ///
  /// Only the root segment of the extended type is resolved
  /// (`extension A.B.C` → `A`): in Swift a nested type can never be more
  /// visible than its outermost enclosing type, so a private root caps the
  /// whole chain. Cross-file resolution is deliberately not attempted — a
  /// syntax-only rule cannot see another file, and `private`/`fileprivate`
  /// types are file-scoped by definition, so same-file resolution is
  /// complete for this access level.
  private static func extendsFilePrivateType(_ ext: ExtensionDeclSyntax) -> Bool {
    guard let root = extendedTypeRootName(ext.extendedType) else { return false }
    return filePrivateTypeNames(in: ext.root).contains(root)
  }

  /// The leftmost identifier segment of an extended type
  /// (`A` for `A`, `A.B`, and `A.B.C`).
  private static func extendedTypeRootName(_ type: TypeSyntax) -> Swift.String? {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
      return identifier.name.text
    }
    if let member = type.as(MemberTypeSyntax.self) {
      return extendedTypeRootName(member.baseType)
    }
    return nil
  }

  /// Names of every `private` / `fileprivate` nominal type declared
  /// anywhere in `root`'s file.
  private static func filePrivateTypeNames(in root: Syntax) -> Swift.Set<Swift.String> {
    var names: Swift.Set<Swift.String> = []
    func collect(_ node: Syntax) {
      if let decl = node.as(StructDeclSyntax.self), hasFileprivateOrPrivate(decl.modifiers) {
        names.insert(decl.name.text)
      } else if let decl = node.as(ClassDeclSyntax.self), hasFileprivateOrPrivate(decl.modifiers) {
        names.insert(decl.name.text)
      } else if let decl = node.as(EnumDeclSyntax.self), hasFileprivateOrPrivate(decl.modifiers) {
        names.insert(decl.name.text)
      } else if let decl = node.as(ActorDeclSyntax.self), hasFileprivateOrPrivate(decl.modifiers) {
        names.insert(decl.name.text)
      }
      for child in node.children(viewMode: .sourceAccurate) { collect(child) }
    }
    collect(root)
    return names
  }

  /// Returns true if `modifiers` includes a `public` or `open`
  /// access-level modifier. Direct check of the declaration's own
  /// modifier list — does not walk up the parent chain. Use
  /// ``hasPublicOrOpenEffective(_:modifiers:)`` when the caller needs
  /// effective visibility (which considers an enclosing `public
  /// extension`).
  internal static func hasPublicOrOpen(_ modifiers: DeclModifierListSyntax) -> Bool {
    for modifier in modifiers {
      let kind = modifier.name.tokenKind
      if kind == .keyword(.public) || kind == .keyword(.open) {
        return true
      }
    }
    return false
  }

  /// Returns true if `node`'s *effective* visibility is `public` (or
  /// `open`) — either because the declaration itself carries the
  /// modifier, or because it is a member of a `public`/`open`
  /// `extension` and declares no access modifier of its own. In
  /// Swift, a member of a `public extension` is public API without
  /// carrying the keyword — public-API-scoped rules that check only
  /// `node.modifiers` are silently defeated by moving the `public`
  /// keyword to the extension. This is the mirror image of
  /// ``hasFileprivateOrPrivateEffective(_:modifiers:)``.
  ///
  /// Only the nearest enclosing `ExtensionDeclSyntax` is consulted —
  /// a member's own explicit modifier (if any) always wins, matching
  /// `hasPublicOrOpen(modifiers)` when the declaration is not
  /// implicitly public via its extension.
  internal static func hasPublicOrOpenEffective(
    _ node: Syntax,
    modifiers: DeclModifierListSyntax
  ) -> Bool {
    if hasPublicOrOpen(modifiers) {
      return true
    }
    var current: Syntax? = node.parent
    while let candidate = current {
      if let ext = candidate.as(ExtensionDeclSyntax.self) {
        return hasPublicOrOpen(ext.modifiers)
      }
      current = candidate.parent
    }
    return false
  }
}

extension Naming {
  /// Returns true if `token`'s source-level text is backtick-escaped
  /// (e.g., the identifier was written `` `construction from UInt` ``
  /// or `` `1` `` rather than as a bare camelCase / digit-leading /
  /// keyword token).
  ///
  /// Used by the compound-family rules (``Lint/Rule/compound identifier``,
  /// ``Lint/Rule/compound type name``, and the relocated-to-institute
  /// ``Lint/Rule/compound suite name``) to short-circuit before invoking
  /// their respective compound-predicates. Backticks are a syntactic
  /// opt-out from standard identifier conventions:
  ///
  /// - Narrative test names per [SWIFT-TEST-005]
  ///   (e.g., `` `construction from UInt` ``, `` `next emits objectStart` ``).
  /// - Non-identifier-character content (`` `1` `` for enum cases,
  ///   `` `+` `` / `` `-` `` for operator-name escapes).
  /// - Swift-keyword conflicts (`` `func` ``, `` `default` ``).
  ///
  /// `TokenSyntax.text` strips backticks from the unescaped identifier
  /// before the rule's predicate sees them; this helper consults
  /// `trimmedDescription` instead, which preserves the backticks but
  /// strips surrounding trivia.
  @inlinable
  package static func isBackticked(_ token: TokenSyntax) -> Swift.Bool {
    token.trimmedDescription.hasPrefix("`")
  }
}

/// Returns true if `node` is an `AccessorBlockSyntax` in its shorthand-
/// getter form (`var x: Int { 0 }`, with no explicit `get { }`).
///
/// A short-form computed-property or subscript getter parses as
/// `AccessorBlockSyntax.getter(CodeBlockItemListSyntax)` — there is no
/// `AccessorDeclSyntax` node at all. Rules that walk the parent chain
/// looking for a function-like body boundary (init body, explicit
/// accessor body, closure body, deinit body, subscript body) via
/// `candidate.is(AccessorDeclSyntax.self)` alone miss this shorthand
/// form entirely, since the walk never encounters an `AccessorDeclSyntax`
/// for it — it passes straight through to the enclosing
/// `VariableDeclSyntax`/`SubscriptDeclSyntax` and beyond.
///
/// Pack-local duplicate of `structureIsShorthandGetterAccessorBlock`
/// from `Lint.Rule.Structure.Shared.swift` — cross-pack visibility isn't
/// available across the universal/institute tier boundary, so the
/// helper is duplicated; semantics match.
internal func namingIsShorthandGetterAccessorBlock(_ node: Syntax) -> Swift.Bool {
  guard let block = node.as(AccessorBlockSyntax.self) else { return false }
  if case .getter = block.accessors { return true }
  return false
}

/// Returns true if `block` declares any non-computed, non-`static` stored
/// property. Computed properties (an accessor block) do not count as
/// stored, and neither does `static let` / `static var` — the rules
/// consuming this helper (`tag suffix`, `nested tag`) test for *instance*
/// storage that would make the tag/newtype carry a runtime payload;
/// `static let raw = 1` is a type-level constant, not instance state.
/// Shared by `Lint.Rule.Naming.Tag.swift` and
/// `Lint.Rule.Naming.NestedTag.swift`; previously duplicated in both
/// (see issue #17).
internal func namingHasStoredInstanceProperty(_ block: MemberBlockSyntax) -> Swift.Bool {
  for member in block.members {
    guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
    if variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) { continue }
    for binding in variable.bindings {
      if binding.accessorBlock == nil { return true }
    }
  }
  return false
}

/// Returns true if `block` declares any enum case. Shared by
/// `Lint.Rule.Naming.Tag.swift` and `Lint.Rule.Naming.NestedTag.swift`;
/// previously duplicated in both (see issue #17).
internal func namingHasEnumCase(_ block: MemberBlockSyntax) -> Swift.Bool {
  for member in block.members where member.decl.is(EnumCaseDeclSyntax.self) { return true }
  return false
}

/// Returns true when `filePath` names a SwiftPM package manifest:
/// `Package.swift` or a versioned `Package@swift-<version>.swift` variant.
///
/// Scan-scope gate for the compound-identifier family ([API-NAME-002] /
/// [API-NAME-001]): a package manifest is BUILD CONFIGURATION, not API
/// surface. Its `extension String` / `extension Target.Dependency`
/// name-vocabulary constants (`static let multipartFormCoding`,
/// `static var htmlFormCoderMultipart`) are SwiftPM identifiers for
/// products and targets — they cannot be restructured into nested
/// accessors, because `PackageDescription` dictates the shape. Confirmed
/// instance: swift-institute/.github#90 comment 5150641576 (3 findings on
/// one manifest).
///
/// Whole-filename matching only — `PackageInfo.swift`, `MyPackage.swift`
/// and any file inside a directory literally named `Package.swift` are NOT
/// manifests and remain in scope. The check is applied BEFORE the visitor
/// walks, so nothing inside a manifest is ever visited.
///
/// Pack-local duplicate of `manifestIsPackageManifest` from the Manifest
/// rule pack — cross-pack visibility isn't available across the target
/// boundary; semantics match.
internal func namingIsPackageManifest(_ filePath: Swift.String) -> Swift.Bool {
  guard let filename = filePath.split(separator: "/", omittingEmptySubsequences: true).last
  else { return false }
  if filename == "Package.swift" { return true }
  return filename.hasPrefix("Package@swift-") && filename.hasSuffix(".swift")
}
