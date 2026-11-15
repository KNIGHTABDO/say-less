// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SayLessEngine",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SayLessEngine", targets: ["SayLessEngine"]),
        .executable(name: "smoke", targets: ["smoke"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", exact: "1.1.1"),
    ],
    targets: [
        .binaryTarget(
            name: "LlamaFramework",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b12424/llama-b12424-xcframework.zip",
            checksum: "fc67693b9f261068d1490e5e42c8c9e2d11d661bb2b5682d7fdd3c6c50056028"
        ),
        .target(
            name: "SayLessEngine",
            dependencies: [
                "LlamaFramework",
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "TTSKit", package: "WhisperKit"),
            ]
        ),
        .executableTarget(name: "smoke", dependencies: ["SayLessEngine"]),
    ],
    swiftLanguageModes: [.v5]
)
