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
  /// `swift-institute/Skills/rule-exemptions/SKILL.md`.
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

  fileprivate static func inheritanceLeaves(_ clause: InheritanceClauseSyntax?) -> [Swift.String]
  {
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
  /// `swift-institute/Skills/rule-exemptions/SKILL.md`.
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
