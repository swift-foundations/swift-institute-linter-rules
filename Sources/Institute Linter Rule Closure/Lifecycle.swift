internal import SwiftSyntax

/// Classifies a closure parameter's lifecycle tier from its label.
///
/// Both the external argument label (`parameter.firstName`, when not an
/// anonymous `_`) and the internal parameter name
/// (`parameter.secondName`) are checked against the known label sets.
internal func tier(of parameter: FunctionParameterSyntax) -> Tier {
    let external: Swift.String? =
        parameter.firstName.tokenKind == .wildcard ? nil : parameter.firstName.text
    let internalName: Swift.String? = parameter.secondName?.text

    for candidate in [external, internalName].compactMap({ $0 }) {
        if setupTierLabels.contains(candidate) {
            return .setup
        }
        if completionTierLabels.contains(candidate) {
            return .completion
        }
        if bodyTierLabels.contains(candidate) {
            return .body
        }
    }
    return .other
}
