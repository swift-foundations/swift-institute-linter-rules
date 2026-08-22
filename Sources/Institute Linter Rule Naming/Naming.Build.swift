extension Naming {
    /// Result-builder protocol method names per Swift's `@resultBuilder`
    /// attribute (SE-0289). A function declared inside a type marked
    /// `@resultBuilder` and named one of these is protocol-required —
    /// its name and parameter / return types are dictated by the
    /// builder protocol's accumulator and expression types. The Naming
    /// pack treats these as spec-mirroring at the attribute level
    /// (see [API-NAME-003] semantics): the `@resultBuilder` attribute
    /// IS the specification.
    internal enum Build {}
}

extension Naming.Build {
    @usableFromInline
    internal static let methods: Swift.Set<Swift.String> = [
        "buildExpression",
        "buildBlock",
        "buildPartialBlock",
        "buildOptional",
        "buildEither",
        "buildArray",
        "buildLimitedAvailability",
        "buildFinalResult",
    ]
}
