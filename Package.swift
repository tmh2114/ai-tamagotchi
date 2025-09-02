// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AITamagotchi",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AITamagotchiCore",
            targets: ["AITamagotchiCore"]
        ),
        .library(
            name: "AITamagotchiUI",
            targets: ["AITamagotchiUI"]
        ),
        .library(
            name: "AITamagotchiAI",
            targets: ["AITamagotchiAI"]
        ),
        .library(
            name: "AITamagotchiData",
            targets: ["AITamagotchiData"]
        )
    ],
    dependencies: [
        // No external dependencies initially - using native frameworks only
    ],
    targets: [
        // Core business logic and models
        .target(
            name: "AITamagotchiCore",
            dependencies: [],
            path: "Sources/Core",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),
        
        // UI components and views
        .target(
            name: "AITamagotchiUI",
            dependencies: ["AITamagotchiCore"],
            path: "Sources/UI",
            resources: [
                .process("Resources")
            ]
        ),
        
        // AI and machine learning components
        .target(
            name: "AITamagotchiAI",
            dependencies: ["AITamagotchiCore"],
            path: "Sources/AI",
            resources: [
                .process("Models")
            ]
        ),
        
        // Data persistence and synchronization
        .target(
            name: "AITamagotchiData",
            dependencies: ["AITamagotchiCore"],
            path: "Sources/Data"
        ),
        
        // Test targets
        .testTarget(
            name: "AITamagotchiCoreTests",
            dependencies: ["AITamagotchiCore"],
            path: "Tests/CoreTests"
        ),
        
        .testTarget(
            name: "AITamagotchiUITests",
            dependencies: ["AITamagotchiUI"],
            path: "Tests/UITests"
        ),
        
        .testTarget(
            name: "AITamagotchiAITests",
            dependencies: ["AITamagotchiAI"],
            path: "Tests/AITests"
        ),
        
        .testTarget(
            name: "AITamagotchiDataTests",
            dependencies: ["AITamagotchiData"],
            path: "Tests/DataTests"
        )
    ]
)