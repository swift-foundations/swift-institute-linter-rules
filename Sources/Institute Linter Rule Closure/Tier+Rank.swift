extension Tier {
    /// Position in the documented order. Lower sorts earlier.
    /// `other` has no position in the order and must not be compared.
    var rank: Swift.Int {
        switch self {
        case .setup: return 0
        case .body: return 1
        case .completion: return 2
        case .other: return 0
        }
    }
}
