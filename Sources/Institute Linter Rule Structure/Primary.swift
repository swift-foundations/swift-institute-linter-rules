internal import SwiftSyntax

/// One top-level primary nominal type found by the collector.
internal struct Primary {
    let node: DeclSyntax
    let namePosition: AbsolutePosition
    let extensionPrefix: Swift.String
    let wrappingExtension: ExtensionDeclSyntax?
}
