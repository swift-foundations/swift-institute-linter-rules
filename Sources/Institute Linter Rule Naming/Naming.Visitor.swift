internal import SwiftSyntax

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

  internal static func inheritanceLeaves(_ clause: InheritanceClauseSyntax?) -> [Swift.String] {
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
