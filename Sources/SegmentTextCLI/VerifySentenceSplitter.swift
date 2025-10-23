//
//  VerifySentenceSplitter.swift
//  Verify SentenceSplitter implementation
//

import Foundation
import SegmentTextKit

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
func verifySentenceSplitter() async throws {
    print("=== SentenceSplitter Verification ===")
    print()

    // Initialize the splitter
    let splitter = try SentenceSplitter(bundle: Bundle.module)

    // Test cases
    let testCases = [
        // Simple cases
        "This is a test sentence.",
        "Hello world! How are you doing today?",
        "The quick brown fox jumps over the lazy dog.",

        // Multiple sentences with different punctuation
        "First sentence. Second sentence? Third sentence! Fourth sentence.",

        // Complex punctuation
        "Dr. Smith went to the U.S.A. yesterday. He met with Mr. Johnson.",

        // Numbers and abbreviations
        "The temperature is 23.5°C. That's about 74.3°F.",

        // Edge cases
        "Single sentence without punctuation",
        "Multiple...   spaces...   between...   sentences...",

        // Newlines
        "First line.\nSecond line.\nThird line.",

        // Empty and whitespace
        "   Leading and trailing spaces.   ",
    ]

    // Test with different thresholds
    let thresholds: [Float?] = [nil, 0.01, 0.1, 0.5]

    for (caseIndex, text) in testCases.enumerated() {
        print("Test Case \(caseIndex + 1):")
        print("Input: \"\(text)\"")
        print()

        for threshold in thresholds {
            let thresholdStr = threshold.map { String($0) } ?? "default"
            print("  Threshold: \(thresholdStr)")

            // Split without stripping whitespace
            let sentences = splitter.split(
                text: text,
                threshold: threshold,
                stripWhitespace: false
            )

            print("  Sentences (keep whitespace): \(sentences.count)")
            for (i, sentence) in sentences.enumerated() {
                print("    [\(i + 1)]: \"\(sentence)\"")
            }

            // Split with stripping whitespace
            let strippedSentences = splitter.split(
                text: text,
                threshold: threshold,
                stripWhitespace: true
            )

            if strippedSentences != sentences {
                print("  Sentences (strip whitespace): \(strippedSentences.count)")
                for (i, sentence) in strippedSentences.enumerated() {
                    print("    [\(i + 1)]: \"\(sentence)\"")
                }
            }

            print()
        }

        print(String(repeating: "-", count: 50))
        print()
    }
}
