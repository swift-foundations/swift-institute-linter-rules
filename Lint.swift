// swift-linter-tools-version: 0.1
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

// Foundation-up dogfeed continuation (Thread B). swift-institute-linter-rules
// is the institute-rules pack — its own Bundle.institute composes the
// universal bundle plus institute-tier rules (Naming.*, Throws.*,
// SWIFT-TEST-*, etc.). Self-lint catches both universal and institute
// defects in the pack's own source.

import Linter
import Linter_Institute_Rules

Lint.run(dependencies: [
    .package(
        path: ".",
        products: ["Linter Institute Rules"]
    ),
]) {
    Lint.Rule.Bundle.institute
}
