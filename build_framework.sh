#!/bin/bash

# Simple build script for SegmentTextKit
# Creates a package that can be used in other projects

set -e

# Configuration
FRAMEWORK_NAME="SegmentTextKit"
OUTPUT_DIR="./build/SegmentTextKit-Package"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$OUTPUT_DIR"
rm -f ./build/SegmentTextKit-Package.zip
mkdir -p "$OUTPUT_DIR"

# Step 1: Build the library
echo "🔨 Building SegmentTextKit..."
swift build --target SegmentTextKit -c release

# Step 2: Create the package structure
echo "📦 Creating package structure..."

# Copy source files
mkdir -p "$OUTPUT_DIR/Sources/SegmentTextKit"
cp Sources/SegmentTextKit/*.swift "$OUTPUT_DIR/Sources/SegmentTextKit/"

# Copy resources
mkdir -p "$OUTPUT_DIR/Sources/SegmentTextKit/Resources"
cp -r Sources/SegmentTextKit/Resources/* "$OUTPUT_DIR/Sources/SegmentTextKit/Resources/"

# Copy SentencePieceWrapper
mkdir -p "$OUTPUT_DIR/Sources/SentencePieceWrapper/include"
cp Sources/SentencePieceWrapper/SentencePieceWrapper.cpp "$OUTPUT_DIR/Sources/SentencePieceWrapper/"
cp Sources/SentencePieceWrapper/include/SentencePieceWrapper.h "$OUTPUT_DIR/Sources/SentencePieceWrapper/include/"

# Copy the SentencePiece.xcframework
cp -r Frameworks/SentencePiece.xcframework "$OUTPUT_DIR/"

# Create Package.swift
cat >"$OUTPUT_DIR/Package.swift" <<'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SegmentTextKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SegmentTextKit",
            targets: ["SegmentTextKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "1.1.0"))
    ],
    targets: [
        .binaryTarget(
            name: "SentencePiece",
            path: "SentencePiece.xcframework"
        ),
        .target(
            name: "SentencePieceWrapper",
            dependencies: ["SentencePiece"],
            path: "Sources/SentencePieceWrapper",
            publicHeadersPath: "include",
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
            path: "Sources/SegmentTextKit",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
EOF

# Create README
cat >"$OUTPUT_DIR/README.md" <<'EOF'
# SegmentTextKit

A Swift framework for sentence segmentation and tokenization using CoreML and SentencePiece.

## Features

- Sentence splitting using CoreML model (WTPSplit)
- Text tokenization using SentencePiece
- Optimized for performance with caching and batch processing
- Support for iOS 17+ and macOS 14+

## Installation

### Swift Package Manager

1. In Xcode, go to File > Add Package Dependencies
2. Click "Add Local..." and select this directory
3. Add `SegmentTextKit` to your target

### Manual Integration

1. Copy this entire directory to your project
2. Add the package as a local Swift Package

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 5.9+

## Included Components

- **SegmentTextKit**: Main framework with public API
- **SentencePiece.xcframework**: Tokenization library
- **Resources**: Tokenizer (sentencepiece.bpe.model)
- **Model**: Downloaded from Huggingface
EOF

# Create archive
echo "📦 Creating distribution archive..."
cd build
zip -r "SegmentTextKit-Package.zip" "SegmentTextKit-Package" -x "*.DS_Store"
cd ..

echo "✅ Build complete!"
echo ""
echo "📍 Package location: $OUTPUT_DIR"
echo "📦 Archive: ./build/SegmentTextKit-Package.zip"
echo ""
echo "To use in your project:"
echo "1. Unzip the archive"
echo "2. In Xcode: File > Add Package Dependencies > Add Local"
echo "3. Select the SegmentTextKit-Package directory"
echo "4. Import SegmentTextKit in your code"
