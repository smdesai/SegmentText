import Accelerate
import ArgumentParser
import CoreML
import Foundation
import SegmentTextKit
import SentencePieceWrapper

struct Main: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "SaT - Tokenization and sentence segmentation tools",
        subcommands: [Tokenize.self, Split.self, VerifySplitter.self, Benchmark.self],
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
        // Get the path to the model file in Resources
        guard
            let modelURL = Bundle.module.url(
                forResource: "sentencepiece.bpe", withExtension: "model", subdirectory: "Resources")
        else {
            throw ValidationError("Could not find sentencepiece.bpe.model in Resources")
        }

        // Initialize the tokenizer
        let tokenizer = try SentencePieceTokenizer(modelPath: modelURL.path)

        // Use the extension method
        let (encodedTokens, offsetMapping) = tokenizer.encodeWithOffset(text: text)

        // Print the encoded tokens
        print("Encoded tokens: \(encodedTokens)")

        // Get token pieces for display
        let tokenPieces = tokenizer.tokenize(text: text)
        print("Token pieces: \(tokenPieces)")

        // Print offset mapping
        print("Offset mapping: \(offsetMapping)")

        /*
        // Print detailed mapping for clarity
        print("\nDetailed token mapping:")
        for (i, (piece, (start, end))) in zip(tokenPieces, offsetMapping).enumerated() {
            let substring = String(text[text.index(text.startIndex, offsetBy: start)..<text.index(text.startIndex, offsetBy: end)])
            print("  Token \(i): '\(piece)' -> '\(substring)' [position \(start):\(end)]")
        }
        */

        let clsToken = tokenizer.convertTokenToId("<s>")
        let sepToken = tokenizer.convertTokenToId("</s>")
        let padToken = tokenizer.convertTokenToId("<pad>")
        print("CLS token ID: \(String(describing: clsToken))")
        print("SEP token ID: \(String(describing: sepToken))")
        print("PAD token ID: \(String(describing: padToken))")

        let a = tokenizer.convertIdToToken(2)
        print("token 2: \(String(describing: a))")
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

            /*
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
            */

            let chunks = [
                "I went to see my ",
                "univer",
                "sity to ",
                "see Prof. Jame",
                "s and found he ",
                "was not the",
                "re and ins",
                "tead had g",
                "one to the hos",
                "pital ",
                "to see Dr. ",
                "James about an ",
                "ear infection.",
            ]
            for chunk in chunks {
                print("chunk: \(chunk)")
                let s = runner.stream(text: chunk)
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
        abstract: "Benchmark original vs optimized sentence splitter",
        discussion: "Compare performance between the original and optimized implementations."
    )

    @Option(name: .long, help: "Number of iterations for benchmarking")
    var iterations: Int = 100

    @Flag(name: .long, help: "Use optimized implementation only")
    var optimizedOnly: Bool = false

    func run() async throws {
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            try await runBenchmark(iterations: iterations, optimizedOnly: optimizedOnly)
        } else {
            print("Error: This command requires macOS 15.0 or later")
            throw ExitCode.failure
        }
    }
}

struct MainWrapper {
    static func main() async {
        await Main.main()
    }
}

await MainWrapper.main()
