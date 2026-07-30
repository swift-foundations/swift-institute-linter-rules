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

/// Wave 3 (mechanization-program) — `@convention(c)` function types
/// MUST NOT take `UnsafeMutablePointer<UserType>?` parameters where
/// `UserType` is a Swift-defined struct.
///
/// Citation: `[PLAT-ARCH-005b]` (platform skill — `@convention(c)`
/// representability pre-check).
extension Lint.Rule {
  public static let `convention c representability` = Lint.Rule(
    id: "convention c representability",
    default: .warning,
    findings: { source, severity in
      let visitor = PlatformConventionCRepresentabilityVisitor(
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
internal let platformConventionCRepresentabilityMessage: Swift.String =
  "[convention c representability] [PLAT-ARCH-005b]: `@convention(c)` "
  + "function type takes `UnsafeMutablePointer<UserType>?` for a "
  + "Swift-defined struct — pure Swift structs (including @safe "
  + "wrappers) are NOT C-representable and the compiler rejects "
  + "them in @convention(c) signatures. Use `OpaquePointer?` or "
  + "`UnsafeMutableRawPointer?` in the callback signature; bind the "
  + "typed wrapper at the callback's first line."

internal func platformConventionCRepresentabilityHasConventionC(_ attributes: AttributeListSyntax)
  -> Swift.Bool
{
  for attribute in attributes {
    guard let attr = attribute.as(AttributeSyntax.self) else { continue }
    guard attr.attributeName.trimmedDescription == "convention" else { continue }
    if let arguments = attr.arguments,
      case .argumentList(let labeled) = arguments
    {
      if let first = labeled.first,
        let identifier = first.expression.as(DeclReferenceExprSyntax.self),
        identifier.baseName.text == "c"
      {
        return true
      }
    }
  }
  return false
}

/// Returns true when `type` (after stripping optional / IUO /
/// attributed wrappers) is `UnsafeMutablePointer<X>` /
/// `UnsafePointer<X>` where `X` is a Swift-defined struct — i.e. NOT
/// itself an `UnsafeMutablePointer`/`UnsafePointer` type, and NOT a
/// type reached through a known C-interop module qualifier
/// (`Darwin.kevent`, `Glibc.stat`, etc. — genuinely C-representable,
/// and the house style for reaching such types in exactly the
/// platform code this rule targets).
///
/// Both a bare bare `MyStruct` (`IdentifierTypeSyntax`) and a
/// Swift-namespace-qualified `MyNamespace.MyStruct`
/// (`MemberTypeSyntax` whose root is NOT a C-interop module) count as
/// Swift-defined; only a `MemberTypeSyntax` rooted at a recognized
/// C-interop module is exempt.
internal func platformConventionCRepresentabilityIsUnsafePointerToUserType(_ type: TypeSyntax)
  -> Swift.Bool
{
  var current = type
  while let optional = current.as(OptionalTypeSyntax.self) {
    current = optional.wrappedType
  }
  while let iuo = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
    current = iuo.wrappedType
  }
  while let attributed = current.as(AttributedTypeSyntax.self) {
    current = attributed.baseType
  }
  guard let identifier = current.as(IdentifierTypeSyntax.self) else {
    return false
  }
  guard
    identifier.name.text == "UnsafeMutablePointer"
      || identifier.name.text == "UnsafePointer"
  else { return false }
  guard let genericArgs = identifier.genericArgumentClause,
    let argument = genericArgs.arguments.first
  else { return false }
  return !platformConventionCRepresentabilityIsCInteropReference(argument.argument)
}

/// True when `type` is a `MemberTypeSyntax` rooted at a recognized
/// C-interop module (`Darwin`, `Glibc`, `Musl`, `Bionic`, `Android`,
/// `WASILibc`, `WinSDK`, `ucrt`, `CRT` — the same module set
/// `canimport conditional` treats as genuine C-library availability).
/// A bare identifier (no qualifier at all) is never a C-interop
/// reference — it's exactly the documented "Swift-defined struct"
/// case this rule exists to catch.
private func platformConventionCRepresentabilityIsCInteropReference(_ type: TypeSyntax) -> Swift.Bool
{
  guard let member = type.as(MemberTypeSyntax.self) else { return false }
  var base = member.baseType
  while let nested = base.as(MemberTypeSyntax.self) { base = nested.baseType }
  guard let root = base.as(IdentifierTypeSyntax.self) else { return false }
  return platformPlatformConditionalCLibraryModules.contains(root.name.text)
}

internal final class PlatformConventionCRepresentabilityVisitor: SyntaxVisitor {
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

  override func visit(_ node: AttributedTypeSyntax) -> SyntaxVisitorContinueKind {
    guard platformConventionCRepresentabilityHasConventionC(node.attributes) else {
      return .visitChildren
    }
    guard let function = node.baseType.as(FunctionTypeSyntax.self) else {
      return .visitChildren
    }
    for parameter in function.parameters {
      guard
        platformConventionCRepresentabilityIsUnsafePointerToUserType(
          parameter.type
        )
      else { continue }
      let location = converter.location(for: parameter.type.positionAfterSkippingLeadingTrivia)
      matches.append(
        Diagnostic.Record(
          location: Source.Location(
            fileID: source.fileID,
            filePath: source.filePath,
            line: location.line,
            column: location.column
          ),
          severity: severity,
          identifier: "convention c representability",
          message: platformConventionCRepresentabilityMessage
        ))
    }
    return .visitChildren
  }
}
