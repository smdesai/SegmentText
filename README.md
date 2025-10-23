## Project Overview
This is a Swift command-line tool and a package for use in iOS/macOS for sentence segmentation/tokenization using Google's SentencePiece library and segment-any-text/sat-3l-sm model. The project is structured as a Swift Package Manager
executable that wraps the SentencePiece C++ library through a custom Swift bridge.

## Prerequisites
1. Follow the environment and model creation steps in coreml-conversion/README.md
2. Once complete, the framework is ready to build

## Build Commands
```bash
sh ./build_framework.sh
```

## Integration Steps
### Step 1: Prepare the Package
1. **Locate the built package**:
```
./build/SegmentTextKit-Package.zip
```
2. **Extract the package**:
- Unzip `SegmentTextKit-Package.zip` to your project
- Recommended: Place it in your project's parent directory or a dedicated "Packages" folder
- Example: `~/Projects/MyApp/Packages/SegmentTextKit-Package/`

### Step 2: Add to Xcode Project
#### Local Swift Package
1. **Open your Xcode project**

2. **Add the package**:
- In Xcode, go to **File → Add Package Dependencies...**
- Click the **"Add Local..."** button at the bottom
- Navigate to and select the `SegmentTextKit-Package` folder
- Click **"Add Package"**

3. **Configure the package**:
- In the dialog that appears, ensure your app target is selected
- Click **"Add Package"**

ZG **Verify integration**:
- In your project navigator, you should see the package under "Package Dependencies"
- The package icon should show without any errors

## Local CLI Usage
1. Build the command-line tool in release mode:
   ```bash
   swift build -c release
   ```
2. Run the executable from the build directory. The available subcommands match those defined in `Sources/SegmentTextCLI/main.swift`:
   - `tokenize <text>`
   - `split <text> [--threshold <value>] [--strip-whitespace]`
   - `stream <text> [--threshold <value>] [--strip-whitespace] [--delay <milliseconds>]`
   - `verify-splitter`
   - `benchmark [--iterations <count>]`

   Examples:
   - Tokenize:
     ```bash
     .build/release/segmenttext tokenize "Hello world."
     ```
   - Split:
     ```bash
     .build/release/segmenttext split "This is a sentence this is another sentence" --threshold 0.2 --strip-whitespace
     ```
   - Stream:
     ```bash
     .build/release/segmenttext stream "Streaming text across multiple sentences." --threshold 0.05 --delay 150
     ```
   - Verify Splitter:
     ```bash
     .build/release/segmenttext verify-splitter
     ```
   - Benchmark:
     ```bash
     .build/release/segmenttext benchmark --iterations 500
     ```
