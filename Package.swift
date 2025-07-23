// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "segmenttext",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SegmentTextKit",
            targets: ["SegmentTextKit"]
        ),
        .executable(
            name: "segmenttext",
            targets: ["segmenttext"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "0.1.22"),
    ],
    targets: [
        .binaryTarget(
            name: "SentencePiece",
            path: "Frameworks/SentencePiece.xcframework"
        ),
        .target(
            name: "SentencePieceWrapper",
            dependencies: ["SentencePiece"],
            linkerSettings: [
                .linkedFramework("SentencePiece", .when(platforms: [.macOS]))
            ]
        ),
        .target(
            name: "SegmentTextKit",
            dependencies: [
                .product(name: "Transformers", package: "swift-transformers"),
                "SentencePieceWrapper"
            ],
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "segmenttext",
            dependencies: [
               .product(name: "ArgumentParser", package: "swift-argument-parser"),
               .product(name: "Transformers", package: "swift-transformers"),
               "SentencePieceWrapper",
               "SegmentTextKit"
            ],
            path: "Sources/SegmentTextCLI",
            resources: [
                .copy("../SegmentTextKit/Resources")
            ]
        )
    ]
)
