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

/// Wave 4 (mechanization-program) — `struct: @unchecked Sendable`
/// wrapping a class stored property is the anti-pattern.
///
/// Class-ness is resolved structurally: every `ClassDeclSyntax` declared
/// anywhere in the file is collected in a pre-pass (bare name and the
/// dotted path from its enclosing type/extension chain), plus a small
/// allowlist of known-imported class types
/// (`memoryStructSendableClassMemberKnownClassNames`). A class imported
/// from another module and absent from that allowlist is not detected —
/// a real per-file limit, and the allowlist is the intended extension
/// point.
///
/// The predicate cannot tell whether the wrapped class is itself
/// `Sendable`, so the message prescribes both remedies: drop
/// `@unchecked` if the class is `Sendable`; otherwise replace the class
/// storage with a value type or move the mutable state behind an actor
/// or a `Mutex`.
///
/// Citation: `[IMPL-076]` (implementation skill, the concurrency note — no
/// @unchecked Sendable on struct-wrapping-class).
extension Lint.Rule {
  public static let `sendable struct with class member` = Lint.Rule(
    id: "sendable struct with class member",
    default: .error,
    findings: { source, severity in
      let collector = MemoryStructSendableClassMemberClassCollector(viewMode: .sourceAccurate)
      collector.walk(source.tree)
      let visitor = MemoryStructSendableClassMemberVisitor(
        source: source.file,
        severity: severity,
        converter: source.converter,
        declaredClassNames: collector.names
      )
      visitor.walk(source.tree)
      return visitor.matches
    }
  )
}

@usableFromInline
internal let memoryStructSendableClassMemberMessage: Swift.String =
  "[sendable struct with class member] [IMPL-076]: `struct: @unchecked Sendable` "
  + "wrapping a class-typed stored property asserts a safety property the "
  + "compiler cannot check. If the wrapped class is itself `Sendable`, the "
  + "`@unchecked` is redundant — drop it and conform to plain `Sendable`. If "
  + "it is not, the assertion is unsound: replace the class storage with a "
  + "value type, or move the mutable state behind an actor or a `Mutex`."

@usableFromInline
internal let memoryStructSendableClassMemberKnownClassNames: Swift.Set<Swift.String> = [
  "NSObject", "Thread", "DispatchQueue", "AnyObject",
]

/// Collects every `ClassDeclSyntax` name declared anywhere in the file,
/// both bare and as a dotted path from its enclosing type/extension
/// chain, so `memoryStructSendableClassMemberIsClassType` can resolve
/// same-file class storage structurally.
internal final class MemoryStructSendableClassMemberClassCollector: SyntaxVisitor {
  var names: Swift.Set<Swift.String> = []

  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    names.insert(node.name.text)

    var path = node.name.text
    var context: Syntax? = Syntax(node).parent
    while let ctx = context {
      if let ext = ctx.as(ExtensionDeclSyntax.self) {
        path = "\(ext.extendedType.trimmedDescription).\(path)"
      } else if let cls = ctx.as(ClassDeclSyntax.self) {
        path = "\(cls.name.text).\(path)"
      } else if let str = ctx.as(StructDeclSyntax.self) {
        path = "\(str.name.text).\(path)"
      } else if let enm = ctx.as(EnumDeclSyntax.self) {
        path = "\(enm.name.text).\(path)"
      } else if let act = ctx.as(ActorDeclSyntax.self) {
        path = "\(act.name.text).\(path)"
      }
      context = ctx.parent
    }
    names.insert(path)

    return .visitChildren
  }
}

internal func memoryStructSendableClassMemberIsClassType(
  _ name: Swift.String,
  in declared: Swift.Set<Swift.String>
) -> Swift.Bool {
  declared.contains(name) || memoryStructSendableClassMemberKnownClassNames.contains(name)
}

internal func memoryStructSendableClassMemberUncheckedSendable(_ clause: InheritanceClauseSyntax?)
  -> Swift.Bool
{
  guard let clause else { return false }
  for inherited in clause.inheritedTypes {
    guard let attributed = inherited.type.as(AttributedTypeSyntax.self)
    else { continue }
    var hasUnchecked = false
    for attribute in attributed.attributes {
      if case .attribute(let attr) = attribute,
        let name = attr.attributeName.as(IdentifierTypeSyntax.self),
        name.name.text == "unchecked"
      {
        hasUnchecked = true
      }
    }
    guard hasUnchecked else { continue }
    if let identifier = attributed.baseType.as(IdentifierTypeSyntax.self),
      identifier.name.text == "Sendable"
    {
      return true
    }
    if let member = attributed.baseType.as(MemberTypeSyntax.self),
      member.name.text == "Sendable",
      let base = member.baseType.as(IdentifierTypeSyntax.self),
      base.name.text == "Swift"
    {
      return true
    }
  }
  return false
}

internal func memoryStructSendableClassMemberIsComputed(_ node: VariableDeclSyntax) -> Swift.Bool {
  for binding in node.bindings {
    if let accessors = binding.accessorBlock {
      switch accessors.accessors {
      case .accessors(let list):
        for accessor in list {
          switch accessor.accessorSpecifier.tokenKind {
          case .keyword(.get), .keyword(.set):
            return true

          default: break
          }
        }

      case .getter:
        return true
      }
    }
  }
  return false
}

internal final class MemoryStructSendableClassMemberVisitor: SyntaxVisitor {
  let source: Source.File
  let severity: Diagnostic.Severity
  let converter: SourceLocationConverter
  let declaredClassNames: Swift.Set<Swift.String>
  var matches: [Diagnostic.Record] = []

  init(
    source: Source.File,
    severity: Diagnostic.Severity,
    converter: SourceLocationConverter,
    declaredClassNames: Swift.Set<Swift.String>
  ) {
    self.source = source
    self.severity = severity
    self.converter = converter
    self.declaredClassNames = declaredClassNames
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    guard memoryStructSendableClassMemberUncheckedSendable(node.inheritanceClause) else {
      return .visitChildren
    }
    for member in node.memberBlock.members {
      guard let variable = member.decl.as(VariableDeclSyntax.self) else {
        continue
      }
      // Stored properties only.
      if memoryStructSendableClassMemberIsComputed(variable) {
        continue
      }
      for binding in variable.bindings {
        guard let annotation = binding.typeAnnotation else { continue }
        var isClassType = false
        if let identifier = annotation.type.as(IdentifierTypeSyntax.self) {
          isClassType = memoryStructSendableClassMemberIsClassType(
            identifier.name.text, in: declaredClassNames
          )
        } else if let memberType = annotation.type.as(MemberTypeSyntax.self) {
          let dotted = memberType.trimmedDescription
          isClassType =
            memoryStructSendableClassMemberIsClassType(dotted, in: declaredClassNames)
            || memoryStructSendableClassMemberIsClassType(
              memberType.name.text, in: declaredClassNames
            )
        }
        if isClassType {
          let location = converter.location(
            for: variable.bindingSpecifier.positionAfterSkippingLeadingTrivia
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
              identifier: "sendable struct with class member",
              message: memoryStructSendableClassMemberMessage
            ))
        }
      }
    }
    return .visitChildren
  }
}
