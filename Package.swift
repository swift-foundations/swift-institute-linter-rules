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
            name: "Institute Linter Rule Naming",
            targets: ["Institute Linter Rule Naming"]
        ),
        .library(
            name: "Institute Linter Rule Foundation",
            targets: ["Institute Linter Rule Foundation"]
        ),
        .library(
            name: "Institute Linter Rule Framework",
            targets: ["Institute Linter Rule Framework"]
        ),
        .library(
            name: "Institute Linter Rule Byte",
            targets: ["Institute Linter Rule Byte"]
        ),
        .library(
            name: "Institute Linter Rule Conformance",
            targets: ["Institute Linter Rule Conformance"]
        ),
        // Wave 3 (2026-05-15) — relocated from swift-linter-rules per
        // three-tier-linter-rules-partition.md.
        .library(
            name: "Institute Linter Rule Closure",
            targets: ["Institute Linter Rule Closure"]
        ),
        .library(
            name: "Institute Linter Rule Idiom",
            targets: ["Institute Linter Rule Idiom"]
        ),
        .library(
            name: "Institute Linter Rule Memory",
            targets: ["Institute Linter Rule Memory"]
        ),
        .library(
            name: "Institute Linter Rule Platform",
            targets: ["Institute Linter Rule Platform"]
        ),
        .library(
            name: "Institute Linter Rule Structure",
            targets: ["Institute Linter Rule Structure"]
        ),
        .library(
            name: "Institute Linter Rule Testing",
            targets: ["Institute Linter Rule Testing"]
        ),
        .library(
            name: "Institute Linter Rule Throws",
            targets: ["Institute Linter Rule Throws"]
        ),
        .library(
            name: "Institute Linter Rule Try",
            targets: ["Institute Linter Rule Try"]
        ),
        .library(
            name: "Institute Linter Rule Unchecked",
            targets: ["Institute Linter Rule Unchecked"]
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
        .package(path: "../../swift-primitives/swift-cardinal-primitives"),
        .package(path: "../../swift-primitives/swift-byte-primitives"),
        .package(path: "../swift-linter-rules"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
    ],
    targets: [
        .target(
            name: "Institute Linter Rule Naming",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Foundation",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Framework",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Byte",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Conformance",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Closure",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Idiom",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Memory",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Platform",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Structure",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Testing",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Throws",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Try",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Institute Linter Rule Unchecked",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Linter Institute Rules",
            dependencies: [
                .product(name: "Linter Primitives", package: "swift-linter-primitives"),
                "Institute Linter Rule Naming",
                "Institute Linter Rule Foundation",
                "Institute Linter Rule Framework",
                "Institute Linter Rule Byte",
                "Institute Linter Rule Conformance",
                "Institute Linter Rule Closure",
                "Institute Linter Rule Idiom",
                "Institute Linter Rule Memory",
                "Institute Linter Rule Platform",
                "Institute Linter Rule Structure",
                "Institute Linter Rule Testing",
                "Institute Linter Rule Throws",
                "Institute Linter Rule Try",
                "Institute Linter Rule Unchecked",
                .product(name: "Linter Rules", package: "swift-linter-rules"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Naming Tests",
            dependencies: [
                "Institute Linter Rule Naming",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Foundation Tests",
            dependencies: [
                "Institute Linter Rule Foundation",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Framework Tests",
            dependencies: [
                "Institute Linter Rule Framework",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Byte Tests",
            dependencies: [
                "Institute Linter Rule Byte",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Conformance Tests",
            dependencies: [
                "Institute Linter Rule Conformance",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Closure Tests",
            dependencies: [
                "Institute Linter Rule Closure",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Idiom Tests",
            dependencies: [
                "Institute Linter Rule Idiom",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Memory Tests",
            dependencies: [
                "Institute Linter Rule Memory",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Platform Tests",
            dependencies: [
                "Institute Linter Rule Platform",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Structure Tests",
            dependencies: [
                "Institute Linter Rule Structure",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Testing Tests",
            dependencies: [
                "Institute Linter Rule Testing",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Throws Tests",
            dependencies: [
                "Institute Linter Rule Throws",
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Try Tests",
            dependencies: [
                "Institute Linter Rule Try",
                .product(name: "Byte Primitives", package: "swift-byte-primitives"),
                .product(name: "Linter Rules Test Support", package: "swift-linter-rules"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "Institute Linter Rule Unchecked Tests",
            dependencies: [
                "Institute Linter Rule Unchecked",
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
