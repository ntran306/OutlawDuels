// swift-tools-version: 6.0
import PackageDescription

// Pure-Swift game logic (PLAN.md §3). Foundation only: no simd, ARKit, RealityKit,
// Network, UIKit or CoreHaptics, so it builds and tests on Windows and Linux.
let package = Package(
    name: "Core",
    products: [
        .library(name: "Core", targets: ["Core"])
    ],
    targets: [
        .target(name: "Core", path: "Sources/Core"),
        .testTarget(name: "CoreTests", dependencies: ["Core"], path: "Tests/CoreTests"),
    ]
)
