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

internal final class MemoryExtensionNoncopyableOwnershipFinder: SyntaxVisitor {
  var found = false
  /// Stack of method-local generic parameter names for the current
  /// function / initializer / subscript context. Parameters whose
  /// type is a single identifier matching a method-local generic
  /// carry method-scoped ownership, not type-scoped — the rule's
  /// "add `where Element: ~Copyable` to the extension" requirement
  /// does not apply when the consumed type is not a type-level
  /// generic of the extended type.
  private var genericsStack: [Swift.Set<Swift.String>] = []
  // Skip nested type declarations: ownership modifiers on a nested
  // type's members belong to that nested type, not to the enclosing
  // extension's namespace. Without this skip, an extension on a
  // non-generic namespace (e.g., `extension Ownership { struct
  // Indirect<Value: ~Copyable> { init(consuming Value) } }`) is
  // mis-flagged as needing `where ... ~Copyable` on `Ownership`,
  // which has no generic parameter to constrain.
  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }
  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }
  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }
  override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }
  override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
    // Look for `consuming` / `borrowing` modifier on the type.
    if let attributed = node.type.as(AttributedTypeSyntax.self) {
      for specifier in attributed.specifiers {
        if let simple = specifier.as(SimpleTypeSpecifierSyntax.self) {
          let kind = simple.specifier.tokenKind
          if kind == .keyword(.consuming) || kind == .keyword(.borrowing) {
            // Method-local-generic exemption: a `consuming T`
            // parameter where T is a method-local generic
            // (declared by the enclosing function / init /
            // subscript, not by the extended type) is
            // method-scoped ownership. The rule's premise —
            // that the extension needs a `where Element:
            // ~Copyable` constraint — does not apply: there
            // is no type-level generic to constrain.
            if let identifier = attributed.baseType.as(IdentifierTypeSyntax.self),
              identifier.genericArgumentClause == nil,
              let top = genericsStack.last,
              top.contains(identifier.name.text)
            {
              return .skipChildren
            }
            found = true
            return .skipChildren
          }
        }
      }
    }
    return .visitChildren
  }
  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    // `consuming func` / `borrowing func` modifiers on the func itself
    // (i.e., consuming-self / borrowing-self).
    //
    // Method-local-generic exemption (Thread 2 extension): when the
    // function declares its own generic parameter clause AND its
    // consuming-self/borrowing-self modifier is paired with a
    // method-scoped generic surface (typical shape: a non-generic
    // extended type with method-local generic methods like
    // `consuming func consume<T>(_ type: T.Type)`), the ownership
    // signal is method-scoped, not type-scoped. The rule's
    // "add `where Element: ~Copyable`" prescription is
    // inexpressible — the extended type has no type-level generic
    // to constrain — so the rule does not fire.
    //
    // The heuristic: own-generic-params on the function paired
    // with consuming-self is the structural signal. This is more
    // permissive than strict (would also skip consuming-self on
    // generic extended types when the method happens to have its
    // own generics), but the rule already trades precision for
    // simplicity via the allowlist mechanism, and the alternative
    // (full-program type-info access) is out of scope for an AST
    // visitor. Symmetric with Thread 2's parameter-shape
    // exemption.
    // Push unconditionally, matching the unconditional pop in
    // `visitPost` — the previous early `.skipChildren` returns below
    // left the stack unbalanced whenever an ownership-bearing function
    // was nested inside another generic context (#25 nit: unbalanced
    // stack pop).
    genericsStack.append(Self.genericNames(node.genericParameterClause))
    for modifier in node.modifiers {
      let kind = modifier.name.tokenKind
      if kind == .keyword(.consuming) || kind == .keyword(.borrowing) {
        // #25 defect 7: the `.skipChildren` return here previously
        // suppressed the parameter scan as well as the self-modifier
        // scan — so `consuming func f(_ element: consuming Element)`
        // on a function with its own generics never saw the
        // `consuming Element` parameter, which is unambiguously
        // type-level ownership even though the self-modifier itself
        // is method-scoped. Keep the method-generic guard for the
        // SELF modifier only; scan the parameters for an ownership
        // specifier whose type is NOT one of the function's own
        // generic parameter names before returning.
        if node.genericParameterClause == nil {
          found = true
          return .skipChildren
        }
        let ownGenerics = Self.genericNames(node.genericParameterClause)
        if parametersCarryTypeLevelOwnership(
          node.signature.parameterClause.parameters,
          excluding: ownGenerics
        ) {
          found = true
        }
        return .skipChildren
      }
    }
    return .visitChildren
  }

  /// Scans `parameters` for a `consuming` / `borrowing` specifier
  /// whose type is not a bare identifier naming one of `excluding`
  /// (the enclosing function's own generic parameters) — such a
  /// parameter carries type-level ownership even when the function's
  /// self-modifier is method-scoped (#25 defect 7).
  private func parametersCarryTypeLevelOwnership(
    _ parameters: FunctionParameterListSyntax,
    excluding: Swift.Set<Swift.String>
  ) -> Swift.Bool {
    for parameter in parameters {
      guard let attributed = parameter.type.as(AttributedTypeSyntax.self) else { continue }
      for specifier in attributed.specifiers {
        guard let simple = specifier.as(SimpleTypeSpecifierSyntax.self) else { continue }
        let kind = simple.specifier.tokenKind
        guard kind == .keyword(.consuming) || kind == .keyword(.borrowing) else { continue }
        if let identifier = attributed.baseType.as(IdentifierTypeSyntax.self),
          identifier.genericArgumentClause == nil,
          excluding.contains(identifier.name.text)
        {
          continue
        }
        return true
      }
    }
    return false
  }
  override func visitPost(_ node: FunctionDeclSyntax) {
    if !genericsStack.isEmpty { genericsStack.removeLast() }
  }
  override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    genericsStack.append(Self.genericNames(node.genericParameterClause))
    return .visitChildren
  }
  override func visitPost(_ node: InitializerDeclSyntax) {
    if !genericsStack.isEmpty { genericsStack.removeLast() }
  }
  override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
    genericsStack.append(Self.genericNames(node.genericParameterClause))
    return .visitChildren
  }
  override func visitPost(_ node: SubscriptDeclSyntax) {
    if !genericsStack.isEmpty { genericsStack.removeLast() }
  }
  private static func genericNames(_ clause: GenericParameterClauseSyntax?)
    -> Swift.Set<Swift.String>
  {
    guard let clause else { return [] }
    var names: Swift.Set<Swift.String> = []
    for parameter in clause.parameters {
      names.insert(parameter.name.text)
    }
    return names
  }
}
