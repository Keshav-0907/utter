// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Utter",
    platforms: [.macOS(.v26)],
    dependencies: [
        // 2.31.x is the newest line that builds with Swift 6.2 (later releases need tools 6.3).
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "2.31.3"),
        // Parakeet speech recognition (CoreML). No traits: speech recognition only.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.18.3", traits: []),
    ],
    targets: [
        .executableTarget(
            name: "Utter",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Sources/Utter",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
