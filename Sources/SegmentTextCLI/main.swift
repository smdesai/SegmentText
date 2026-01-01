import Accelerate
import ArgumentParser
import CoreML
import Foundation
import SegmentTextKit
import SentencePieceWrapper

struct Main: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "SaT - Tokenization and sentence segmentation tools",
        subcommands: [Tokenize.self, Split.self, Stream.self, VerifySplitter.self, Benchmark.self, Download.self],
        defaultSubcommand: Tokenize.self
    )
}

struct Tokenize: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Tokenize text using SentencePiece",
        discussion: "This tool uses SentencePiece to tokenize input text."
    )

    @Argument(help: "The text to tokenize")
    var text: String

    func run() async throws {
        guard
            let modelURL = Bundle.module.url(
                forResource: "sentencepiece.bpe", withExtension: "model", subdirectory: "Resources")
        else {
            throw ValidationError("Could not find sentencepiece.bpe.model in Resources")
        }

        let tokenizer = try SentencePieceTokenizer(modelPath: modelURL.path)
        let (encodedTokens, offsetMapping) = tokenizer.encodeWithOffset(text: text)

        print("Encoded tokens: \(encodedTokens)")

        let tokenPieces = tokenizer.tokenize(text: text)
        print("Token pieces: \(tokenPieces)")
        print("Offset mapping: \(offsetMapping)")

        // Print detailed mapping for clarity
        print("\nDetailed token mapping:")
        for (i, (piece, (start, end))) in zip(tokenPieces, offsetMapping).enumerated() {
            let substring = String(
                text[
                    text.index(text.startIndex, offsetBy: start)
                        ..< text.index(text.startIndex, offsetBy: end)])
            print("  Token \(i): '\(piece)' -> '\(substring)' [position \(start):\(end)]")
        }

        //let clsToken = tokenizer.convertTokenToId("<s>")
        //let sepToken = tokenizer.convertTokenToId("</s>")
        //let padToken = tokenizer.convertTokenToId("<pad>")
        //print("CLS token ID: \(String(describing: clsToken))")
        //print("SEP token ID: \(String(describing: sepToken))")
        //print("PAD token ID: \(String(describing: padToken))")
    }
}

struct Split: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Split text into sentences using the CoreML model",
        discussion:
            "This command uses the CoreML model to identify sentence boundaries and split text."
    )

    @Argument(help: "The text to split into sentences")
    var text: String

    @Option(name: .long, help: "Probability threshold for sentence boundaries (default: 0.2)")
    var threshold: Float?

    @Flag(name: .long, help: "Strip whitespace from sentences")
    var stripWhitespace: Bool = false

    func run() async throws {
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            let splitter = try SentenceSplitter(bundle: Bundle.module)

            let sentences = splitter.split(
                text: text,
                threshold: threshold,
                stripWhitespace: stripWhitespace)

            for (i, sentence) in sentences.enumerated() {
                print("    [\(i + 1)]: \"\(sentence)\"")
            }
        }
    }
}

struct Stream: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Split streamed text into sentences using the CoreML model",
        discussion:
            "This command uses the CoreML model to identify sentence boundaries and split text."
    )

    @Argument(help: "The text to split into sentences")
    var text: String

    @Option(name: .long, help: "Probability threshold for sentence boundaries (default: 0.01)")
    var threshold: Float?

    @Flag(name: .long, help: "Strip whitespace from sentences")
    var stripWhitespace: Bool = false

    @Option(name: .long, help: "Add delay between text generation")
    var delay: UInt64 = 100  // 100ms

    func run() async throws {
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            let splitter = try SentenceSplitter(bundle: Bundle.module)
            let runner = StreamingSentenceSplitter(
                splitter: splitter,
                threshold: threshold ?? 0.2,
                stripWhitespace: stripWhitespace,
                delay: delay
            )

            var currentIndex = text.startIndex
            while currentIndex < text.endIndex {
                let chunkSize = Int.random(in: 5 ... 20)
                let endIndex =
                    text.index(currentIndex, offsetBy: chunkSize, limitedBy: text.endIndex)
                    ?? text.endIndex
                let chunk = String(text[currentIndex ..< endIndex])
                print("chunk: \(chunk)")
                let s = runner.stream(text: chunk)
                currentIndex = endIndex
                if !s.isEmpty {
                    print("sentences: \(s)")
                }

                if delay > 0 {
                    try? await Task.sleep(nanoseconds: delay * 1_000_000)
                }
            }

            let s = runner.finishStream()
            if !s.isEmpty {
                print("sentences: \(s)")
            }
        } else {
            print("Error: This command requires macOS 15.0 or later")
            throw ExitCode.failure
        }
    }
}

struct VerifySplitter: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Verify SentenceSplitter implementation with comprehensive test cases",
        discussion:
            "This command runs various test cases through the sentence splitter to verify its functionality."
    )

    func run() async throws {
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            try await verifySentenceSplitter()
        } else {
            print("Error: This command requires macOS 15.0 or later")
            throw ExitCode.failure
        }
    }
}

struct Benchmark: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Benchmark the sentence splitter",
        discussion: "Measure runtime and memory characteristics for common text lengths."
    )

    @Option(name: .long, help: "Number of iterations for benchmarking")
    var iterations: Int = 100

    @Option(name: .long, help: "Path to CoreML model (.mlmodelc directory)")
    var modelPath: String?

    func run() async throws {
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            let modelURL = modelPath.map { URL(fileURLWithPath: $0) }
            try await runBenchmark(iterations: iterations, modelPath: modelURL)
        } else {
            print("Error: This command requires macOS 15.0 or later")
            throw ExitCode.failure
        }
    }
}

struct Download: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Download the SaT model from HuggingFace",
        discussion: "Downloads the CoreML model from HuggingFace Hub and caches it locally."
    )

    @Flag(name: .long, help: "Clear cached model before downloading")
    var clearCache: Bool = false

    @Flag(name: .long, help: "Test sentence splitting after download")
    var test: Bool = false

    func run() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) else {
            print("Error: This command requires macOS 15.0 or later")
            throw ExitCode.failure
        }

        print("=== SaT Model Downloader ===")
        print("Repository: smdesai/SaT")
        print("Cache: \(ModelDownloader.cacheDirectory.path)")
        print()

        if clearCache {
            print("Clearing cache...")
            try ModelDownloader.shared.clearCache()
            print("Cache cleared.")
            print()
        }

        // Check current state
        if let cached = ModelDownloader.shared.cachedModelURL() {
            print("Model already cached at: \(cached.path)")
            if !clearCache {
                print("Use --clear-cache to force re-download")
            }
        } else {
            print("Model not cached, downloading...")
        }

        print()
        print("Starting download...")

        var lastPercent = -1
        for await progress in await ModelDownloader.shared.download() {
            switch progress {
            case .notStarted:
                break
            case .checking:
                print("  Checking cache...")
            case .downloading(let fraction, let speed):
                let percent = Int(fraction * 100)
                if percent != lastPercent && percent % 5 == 0 {
                    let speedStr = speed.map { String(format: "%.1f KB/s", $0 / 1024) } ?? ""
                    print("  Downloading: \(percent)% \(speedStr)")
                    lastPercent = percent
                }
            case .completed(let url):
                print()
                print("✓ Download complete!")
                print("  Model path: \(url.path)")
            case .failed(let error):
                print()
                print("✗ Download failed: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }

        if test {
            print()
            print("Testing sentence splitting...")
            let splitter = try await SentenceSplitter()
            let testText = "Hello world. This is a test. The download worked!"
            let sentences = splitter.split(text: testText)
            print("  Input: \"\(testText)\"")
            print("  Sentences found: \(sentences.count)")
            for (i, s) in sentences.enumerated() {
                print("    [\(i + 1)]: \"\(s)\"")
            }
        }

        print()
        print("Done!")
    }
}

struct MainWrapper {
    static func main() async {
        await Main.main()
    }
}

await MainWrapper.main()
