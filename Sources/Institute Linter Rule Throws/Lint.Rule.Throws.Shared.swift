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

/// Predicates shared across the Throws pack's rules.
///
/// Moved off `ThrowsUntypedVisitor` (#25 ruling on #19) so a second rule in
/// this pack — `existential throws` — can share the same predicates instead
/// of reproducing them, which had already diverged once (#19 defect 2).

/// The labeled selector of an initializer — `init(from:)` for
/// `init(from decoder: any Decoder)`. Each parameter contributes its argument
/// label (the `firstName` token: the external label, or `_` when the parameter
/// is unlabeled), matching Swift's own selector spelling so an allowlist entry
/// can name an initializer requirement precisely.
internal func throwsInitializerSelector(_ node: InitializerDeclSyntax) -> Swift.String {
  var selector = "init("
  for parameter in node.signature.parameterClause.parameters {
    selector += parameter.firstName.text
    selector += ":"
  }
  selector += ")"
  return selector
}

/// True when a member's parameter list is the canonical witness shape for an
/// allowlisted Codable protocol, so the exemption holds even when the
/// conformance is declared on a *separate* extension or file rather than the
/// one holding the witness (the common `// MARK: - Codable` bare-extension
/// pattern). A `Decodable` witness takes a sole `Decoder` parameter; an
/// `Encodable` witness a sole `Encoder` parameter. Only the Codable pair has a
/// canonical signature shape; `provideScope` returns `false` here and relies
/// on its enclosing `TestScoping` conformance clause.
internal func throwsIsCanonicalWitnessSignature(
  protocolSuffix: Swift.String,
  parameters: FunctionParameterListSyntax
) -> Swift.Bool {
  guard parameters.count == 1, let parameter = parameters.first else { return false }
  let parameterTypeSuffix = throwsLastNameComponent(throwsUnwrappedConstraint(parameter.type))
  switch protocolSuffix {
  case "Decodable": return parameterTypeSuffix == "Decoder"
  case "Encodable": return parameterTypeSuffix == "Encoder"
  default: return false
  }
}

/// Strips a leading `any`/`some` existential/opaque marker to expose the
/// underlying constraint type — `any Decoder` → `Decoder`.
internal func throwsUnwrappedConstraint(_ type: TypeSyntax) -> TypeSyntax {
  if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) { return someOrAny.constraint }
  return type
}

/// The inheritance clause of any nominal-type or extension declaration.
internal func throwsInheritanceClause(of node: Syntax) -> InheritanceClauseSyntax? {
  if let decl = node.as(ExtensionDeclSyntax.self) { return decl.inheritanceClause }
  if let decl = node.as(StructDeclSyntax.self) { return decl.inheritanceClause }
  if let decl = node.as(ClassDeclSyntax.self) { return decl.inheritanceClause }
  if let decl = node.as(EnumDeclSyntax.self) { return decl.inheritanceClause }
  if let decl = node.as(ActorDeclSyntax.self) { return decl.inheritanceClause }
  if let decl = node.as(ProtocolDeclSyntax.self) { return decl.inheritanceClause }
  return nil
}

/// The last name component of a (possibly member-qualified) type — e.g.
/// `TestScoping` for both `TestScoping` and `Testing.TestScoping`.
internal func throwsLastNameComponent(_ type: TypeSyntax) -> Swift.String {
  if let member = type.as(MemberTypeSyntax.self) { return member.name.text }
  if let identifier = type.as(IdentifierTypeSyntax.self) { return identifier.name.text }
  return type.trimmedDescription
}
