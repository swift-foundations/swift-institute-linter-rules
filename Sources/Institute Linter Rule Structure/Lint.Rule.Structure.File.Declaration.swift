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

/// File-level declaration facts shared by the filename/type-path and
/// extension-discriminator rules.
internal final class StructureFileDeclarationVisitor: SyntaxVisitor {
  private(set) var topLevelNames: Swift.Set<Swift.String> = []
  private(set) var topLevelExtensionCount: Swift.Int = 0
  private(set) var topLevelExtensionsAreDiscriminated: Swift.Bool = true
  private(set) var hasTopLevelNonExtensionDeclaration: Swift.Bool = false
  private(set) var hasTypeDeclaration: Swift.Bool = false

  init() {
    super.init(viewMode: .sourceAccurate)
  }

  var isPureExtensionFile: Swift.Bool {
    topLevelExtensionCount > 0
      && !hasTopLevelNonExtensionDeclaration
      && !hasTypeDeclaration
  }

  var canonicalExtensionRepairSupersedesTypePathFinding: Swift.Bool {
    isPureExtensionFile && topLevelExtensionsAreDiscriminated
  }

  private func isTopLevel(_ syntax: Syntax) -> Swift.Bool {
    var ancestor = syntax.parent
    while let current = ancestor {
      if current.is(SourceFileSyntax.self) {
        return true
      }
      if current.is(MemberBlockSyntax.self) || current.is(CodeBlockSyntax.self) {
        return false
      }
      ancestor = current.parent
    }
    return false
  }

  private func recordType(name: TokenSyntax, syntax: Syntax) {
    hasTypeDeclaration = true
    guard isTopLevel(syntax) else { return }
    hasTopLevelNonExtensionDeclaration = true
    topLevelNames.insert(name.text)
  }

  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    recordType(name: node.name, syntax: Syntax(node))
    return .visitChildren
  }

  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    recordType(name: node.name, syntax: Syntax(node))
    return .visitChildren
  }

  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    recordType(name: node.name, syntax: Syntax(node))
    return .visitChildren
  }

  override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
    recordType(name: node.name, syntax: Syntax(node))
    return .visitChildren
  }

  override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
    recordType(name: node.name, syntax: Syntax(node))
    return .visitChildren
  }

  override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
    recordType(name: node.name, syntax: Syntax(node))
    return .visitChildren
  }

  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    if isTopLevel(Syntax(node)) {
      hasTopLevelNonExtensionDeclaration = true
    }
    return .visitChildren
  }

  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    if isTopLevel(Syntax(node)) {
      hasTopLevelNonExtensionDeclaration = true
    }
    return .visitChildren
  }

  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    guard isTopLevel(Syntax(node)) else { return .visitChildren }
    topLevelExtensionCount += 1
    var target = node.extendedType.trimmedDescription
    if let genericStart = target.firstIndex(of: "<") {
      target = Swift.String(target[..<genericStart])
    }
    if target.hasPrefix("`"), target.hasSuffix("`"), target.count >= 2 {
      target = Swift.String(target.dropFirst().dropLast())
    }
    topLevelNames.insert(target)
    if node.inheritanceClause == nil && node.genericWhereClause == nil {
      topLevelExtensionsAreDiscriminated = false
    }
    return .visitChildren
  }
}
