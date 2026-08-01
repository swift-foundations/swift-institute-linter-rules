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

/// Wave 4 (mechanization-program) — `.rawValue` and `.position` accesses
/// at consumer call sites bypass typed-conversion ladders.
///
/// Citation: `[PATTERN-017]` (implementation skill, the patterns note).
extension Lint.Rule {
  public static let `raw value access` = Lint.Rule(
    id: "raw value access",
    default: .warning,
    findings: { source, severity in
      // §A brand-owner recognizer: when the run's own sources declare a
      // numeric brand, same-package `.rawValue` boundary access is
      // legitimate-by-construction. Retires the per-package
      // `.excluding(rules:)` stopgap ([LINT-EXCLUDE-*]).
      if Lint.Brand.owned(Lint.Brand.numericBoundaryVocabulary, in: source) { return [] }
      let visitor = StructureRawValueAccessVisitor(
        source: source.file,
        severity: severity,
        converter: source.converter
      )
      // Whole-file pre-pass before the walk, so the `.position` gate does
      // not depend on declaration order within the file.
      visitor.fileDeclaresPositionMember = structureDeclaresPositionMember(Syntax(source.tree))
      visitor.walk(source.tree)
      return visitor.matches
    }
  )
}

@usableFromInline
internal let structureRawValueAccessMessage: Swift.String =
  "[raw value access] [PATTERN-017]: `.rawValue` / `.position` at a "
  + "consumer call site bypasses the typed-conversion ladder. These "
  + "accessors are reserved for the brand-newtype's own initializers — "
  + "the typed-conversion boundary the ladder terminates in — and "
  + "same-package implementations. Only the directly enclosing "
  + "initializer counts; a closure or nested function inside an "
  + "initializer is ordinary consumer code and still fires. Prefer the "
  + "typed operation. `.position` does NOT fire in a file that declares "
  + "its own `position` member — there the name is the file's own domain "
  + "vocabulary, not a foreign brand's raw accessor. Otherwise suppress with "
  + "`// swift-linter:disable:next raw value access` and a `// REASON:` "
  + "continuation for legitimate same-package use."

internal let structureRawValueAccessFlaggedAccessors: Swift.Set<Swift.String> = [
  "rawValue", "position",
]

/// True when the file rooted at `node` declares a member named `position` —
/// a stored/computed property binding, a function, an enum case, or a
/// parameter's internal name. See the `.position` gate in
/// ``StructureRawValueAccessVisitor``.
internal func structureDeclaresPositionMember(_ node: Syntax) -> Swift.Bool {
  if let variable = node.as(VariableDeclSyntax.self) {
    for binding in variable.bindings {
      if let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
        pattern.identifier.text == "position"
      {
        return true
      }
    }
  }
  if let function = node.as(FunctionDeclSyntax.self), function.name.text == "position" {
    return true
  }
  if let enumCase = node.as(EnumCaseElementSyntax.self), enumCase.name.text == "position" {
    return true
  }
  for child in node.children(viewMode: .sourceAccurate)
  where structureDeclaresPositionMember(child) {
    return true
  }
  return false
}

internal final class StructureRawValueAccessVisitor: SyntaxVisitor {
  let source: Source.File
  let severity: Diagnostic.Severity
  let converter: SourceLocationConverter
  var matches: [Diagnostic.Record] = []
  var bodyDepth: Swift.Int = 0
  /// True once the walk has seen a declaration named `position` anywhere in
  /// this file — see the `.position` gate in `visit(_: MemberAccessExprSyntax)`.
  /// Computed as a whole-file pre-pass by ``walk(_:)`` below, so declaration
  /// order inside the file does not change the result.
  var fileDeclaresPositionMember: Swift.Bool = false

  init(
    source: Source.File,
    severity: Diagnostic.Severity,
    converter: SourceLocationConverter
  ) {
    self.source = source
    self.severity = severity
    self.converter = converter
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    bodyDepth += 1
    return .visitChildren
  }
  override func visitPost(_: FunctionDeclSyntax) {
    bodyDepth -= 1
  }
  override func visit(_: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    bodyDepth += 1
    return .visitChildren
  }
  override func visitPost(_: InitializerDeclSyntax) {
    bodyDepth -= 1
  }
  // #28 nit 2: `deinit { x.rawValue }` was previously invisible to
  // this rule — nothing bumped `bodyDepth` for a `DeinitializerDeclSyntax`
  // body, so the `guard bodyDepth > 0` in the member-access visit
  // below short-circuited before `isDirectlyInsideInitializer`'s
  // `Deinitializer` walk-stopper guard was ever reached. The ruled
  // fixture (`deinit { x.rawValue }` → 1 finding) requires this bump
  // to exist at all.
  override func visit(_: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    bodyDepth += 1
    return .visitChildren
  }
  override func visitPost(_: DeinitializerDeclSyntax) {
    bodyDepth -= 1
  }
  override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
    bodyDepth += 1
    return .visitChildren
  }
  override func visitPost(_: ClosureExprSyntax) {
    bodyDepth -= 1
  }
  override func visit(_: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
    bodyDepth += 1
    return .visitChildren
  }
  override func visitPost(_: AccessorDeclSyntax) {
    bodyDepth -= 1
  }
  override func visit(_ node: AccessorBlockSyntax) -> SyntaxVisitorContinueKind {
    // A short-form getter (`var x: Int { tag.rawValue }`) parses as
    // `.getter`, with no `AccessorDeclSyntax` at all — the override above
    // never fires for it. Without this, `.rawValue` access inside a
    // shorthand computed property or subscript getter silently escapes
    // the rule.
    if structureIsShorthandGetterAccessorBlock(Syntax(node)) {
      bodyDepth += 1
    }
    return .visitChildren
  }
  override func visitPost(_ node: AccessorBlockSyntax) {
    if structureIsShorthandGetterAccessorBlock(Syntax(node)) {
      bodyDepth -= 1
    }
  }

  override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
    guard bodyDepth > 0 else { return .visitChildren }
    let name = node.declName.baseName.text
    guard structureRawValueAccessFlaggedAccessors.contains(name) else {
      return .visitChildren
    }
    // Initializer-boundary reserve (#16 Option C ledger, Entry II.1 DECISION
    // 2026-07-23): the rule's own message reserves these accessors for
    // "extension initializers (the brand-newtype's own boundary)" — an
    // initializer IS the typed-conversion boundary the ladder terminates in
    // (`init(rawValue:)` assigning its stored raw value; an adapter init
    // consuming the brand's raw form exactly once). The implementation
    // previously fired there anyway (e.g. `self.rawValue = rawValue` inside
    // the declaring `init(rawValue:)`, swift-iso-9945
    // `ISO 9945.Kernel.Process.ID.swift`), contradicting the message text.
    // Only the DIRECTLY enclosing function-like context counts: a closure or
    // nested function inside an initializer is ordinary consumer code and
    // still fires.
    if isDirectlyInsideInitializer(Syntax(node)) {
      return .visitChildren
    }
    // Disambiguate Swift.enum.rawValue from Tagged-newtype rawValue
    // via receiver-pattern recognition: `Lint.Visibility.public.rawValue`
    // looks like `<TypeChain>.<member>.rawValue`, where TypeChain is
    // one or more uppercase-leading identifier segments. Skip those —
    // they are `RawRepresentable.rawValue` access, outside the rule's
    // Tagged-newtype-targeting scope. The known false-negative on
    // `Module.staticTagInstance.rawValue` is accepted (uncommon for
    // Tagged consumer access). See the 2026-05-12 foundation-up dogfeed triage note
    // §A2 for the architectural rationale.
    if let receiver = node.base, receiverLooksLikeEnumCaseAccess(receiver) {
      return .visitChildren
    }
    // `.position` false-positive class (ruled swift-institute/.github#90
    // comment 5150641576 item 1, sourced from the batch-1 backlog, comment
    // 5150595934, W2-D entry: "PATTERN-017 matches plain stored property
    // named `position` as a Tagged/Index raw-accessor").
    //
    // `rawValue` is reserved vocabulary — `RawRepresentable`'s and the
    // brand-newtype's, never an author's ordinary noun. `position` is not:
    // it is ordinary domain vocabulary (a cursor's offset, a node's
    // location, a layout coordinate). This rule targets access to a
    // FOREIGN brand's raw accessor. When the file under analysis declares
    // its own member named `position`, `.position` in that file is that
    // member — the file owns the vocabulary and there is no ladder to
    // bypass.
    //
    // Known false negative (accepted): a file that declares its own
    // `position` AND separately consumes a foreign brand's `.position`.
    // Known false positive (retained, suppressible with
    // `// swift-linter:disable:next raw value access`): `.position` on an
    // imported library's type in a file that declares no `position` of its
    // own (e.g. SwiftSyntax's `node.position`) — a syntax-only rule has no
    // type checker, and no stable syntactic property separates that from a
    // brand access.
    if name == "position", fileDeclaresPositionMember { return .visitChildren }
    let location = converter.location(
      for: node.declName.baseName.positionAfterSkippingLeadingTrivia
    )
    matches.append(
      Diagnostic.Record(
        location: Source.Location(
          fileID: source.fileID,
          filePath: source.filePath,
          line: location.line,
          column: location.column
        ),
        severity: severity,
        identifier: "raw value access",
        message: structureRawValueAccessMessage
      ))
    return .visitChildren
  }

  /// True when the nearest enclosing function-like context of `node` is an
  /// `InitializerDeclSyntax` — the typed-conversion boundary the rule's
  /// message reserves. The walk stops at the FIRST function-like ancestor
  /// (function, accessor, or closure), so raw access inside a closure or
  /// helper nested within an init is not exempt.
  private func isDirectlyInsideInitializer(_ node: Syntax) -> Swift.Bool {
    var current: Syntax? = node.parent
    while let candidate = current {
      if candidate.is(InitializerDeclSyntax.self) { return true }
      if candidate.is(FunctionDeclSyntax.self)
        || candidate.is(AccessorDeclSyntax.self)
        || structureIsShorthandGetterAccessorBlock(candidate)
        || candidate.is(ClosureExprSyntax.self)
        || candidate.is(DeinitializerDeclSyntax.self)
        || candidate.is(SubscriptDeclSyntax.self)
      {
        return false
      }
      current = candidate.parent
    }
    return false
  }

  /// True if `base` parses as `<TypeChain>.<member>` — i.e. an enum
  /// case access shape (`Foo.bar`, `Lint.Visibility.public`) rather
  /// than a Tagged-newtype instance access (`tag`, `self.tag`).
  private func receiverLooksLikeEnumCaseAccess(_ base: ExprSyntax) -> Swift.Bool {
    guard let caseAccess = base.as(MemberAccessExprSyntax.self),
      let typeBase = caseAccess.base
    else { return false }
    return isTypeChain(typeBase)
  }

  /// True if `expr` is one or more uppercase-leading identifier
  /// segments joined by `.` — i.e. a type qualifier like `Lint`,
  /// `Lint.Visibility`, or `Module.Sub.Type`. Lowercase-leading
  /// segments (instance refs like `self`, `tag`) return false.
  private func isTypeChain(_ expr: ExprSyntax) -> Swift.Bool {
    if let ref = expr.as(DeclReferenceExprSyntax.self) {
      return ref.baseName.text.first?.isUppercase ?? false
    }
    if let member = expr.as(MemberAccessExprSyntax.self),
      let base = member.base
    {
      return isTypeChain(base)
        && (member.declName.baseName.text.first?.isUppercase ?? false)
    }
    return false
  }
}
