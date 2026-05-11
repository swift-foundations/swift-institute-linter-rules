// swift-tools-version: 6.3.1

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

import PackageDescription

let package = Package(
    name: "swift-institute-linter-rules",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "Linter Rule Naming",
            targets: ["Linter Rule Naming"]
        ),

        // Aggregate bundle — re-exports every pack in this package and
        // the upstream universal bundle, publishing
        // `Lint.Rule.Bundle.institute`. Consumers that want the full
        // institute-tier rule set pull this product alone.
        .library(
            name: "Linter Institute Rules",
            targets: ["Linter Institute Rules"]
        ),
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-linter-primitives"),
        .package(path: "../swift-linter-rules"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
    ],
    targets: [
        .target(
            name: "Linter Rule Naming",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Linter Institute Rules",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                "Linter Rule Naming",
                .product(name: "Linter Rules", package: "swift-linter-rules"),
            ]
        ),
        .testTarget(
            name: "Linter Rule Naming Tests",
            dependencies: [
                "Linter Rule Naming",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
