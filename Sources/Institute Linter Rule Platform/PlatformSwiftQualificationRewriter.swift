internal import SwiftSyntax

internal final class PlatformSwiftQualificationRewriter: SyntaxRewriter {
    /// Whether any qualification was applied.
    ///
    /// Tracked rather than compared after the fact: a rewriter that reported
    /// change by diffing its own output against its input would call a
    /// round-trip formatting difference a fix.
    var changed: Swift.Bool = false

    /// The shadowed-protocol names this file declares itself, which the
    /// rewriter must not retarget.
    private let declared: Swift.Set<Swift.String>

    init(declared: Swift.Set<Swift.String>) {
        self.declared = declared
        super.init()
    }

    private func qualify(_ type: TypeSyntax, at node: Syntax) -> TypeSyntax? {
        // Exempt per [RULE-EXEMPT-6] (stdlib-shadow): inside an extension on a
        // stdlib type the qualified form is structurally inexpressible, so
        // writing it would turn a warning into a compile error.
        guard !platformSwiftQualificationIsInsideStdlibExtension(node) else { return nil }
        guard let qualified = platformSwiftQualificationQualified(type, declared: declared) else {
            return nil
        }
        changed = true
        return qualified
    }

    override func visit(_ node: InheritedTypeSyntax) -> InheritedTypeSyntax {
        guard let qualified = qualify(node.type, at: Syntax(node)) else {
            return super.visit(node)
        }
        return node.with(\.type, qualified)
    }

    override func visit(_ node: GenericParameterSyntax) -> GenericParameterSyntax {
        guard let inherited = node.inheritedType,
            let qualified = qualify(inherited, at: Syntax(node))
        else {
            return super.visit(node)
        }
        return node.with(\.inheritedType, qualified)
    }

    override func visit(_ node: ConformanceRequirementSyntax) -> ConformanceRequirementSyntax {
        guard let qualified = qualify(node.rightType, at: Syntax(node)) else {
            return super.visit(node)
        }
        return node.with(\.rightType, qualified)
    }

    override func visit(_ node: SomeOrAnyTypeSyntax) -> TypeSyntax {
        guard let qualified = qualify(node.constraint, at: Syntax(node)) else {
            return super.visit(node)
        }
        return TypeSyntax(node.with(\.constraint, qualified))
    }
}
