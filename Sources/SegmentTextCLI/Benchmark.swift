//
//  Benchmark.swift
//  Performance benchmarking for sentence splitter
//

import Foundation
import SegmentTextKit

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
func runBenchmark(iterations: Int, modelPath: URL? = nil) async throws {
    guard iterations > 0 else {
        print("Iterations must be greater than zero.")
        return
    }

    // Determine model name for display
    let modelName: String
    if let path = modelPath {
        modelName = path.deletingPathExtension().lastPathComponent
    } else {
        modelName = "SaT (bundled)"
    }

    print("=== SentenceSplitter Performance Benchmark ===")
    print("Model: \(modelName)")
    print("Iterations: \(iterations)")
    print()

    // Test texts of various lengths
    let testTexts = [
        // Short text (< 512 chars)
        "This is a short test. It has multiple sentences. Each one ends with punctuation!",

        // Medium text (~500 chars)
        "The sun rose slowly, painting the sky in soft gold and blush pink; birds chirped—brief, bright symphonies—as if greeting the day with quiet joy, while a lone cyclist pedaled down the empty street, wheels humming against pavement. Somewhere, a cat stretched in a sunbeam, unaware of the world's rush; children laughed in the distance, their voices tumbling like wind chimes. The coffee shop opened its doors, releasing the rich aroma of roasted beans",

        // Long text (> 512 chars, requires sliding window)
        String(repeating: "This is a test sentence that will be repeated many times. ", count: 20)
            + "Final sentence at the end of this very long text. It should trigger the sliding window processing.",
    ]

    // Initialize splitter with optional external model path
    let splitter: SentenceSplitter
    if let path = modelPath {
        splitter = try SentenceSplitter(modelPath: path)
    } else {
        splitter = try SentenceSplitter(bundle: Bundle.module)
    }

    // Warm up (first run is slower due to model loading)
    print("Warming up model...")
    _ = splitter.split(text: testTexts[0])

    for (index, text) in testTexts.enumerated() {
        print("\nTest Case \(index + 1): \(text.count) characters")
        print(separator("-", count: 50))

        // Benchmark implementation
        let start = CFAbsoluteTimeGetCurrent()
        var firstResult: [String]?

        for _ in 0 ..< iterations {
            let result = splitter.split(text: text)
            if firstResult == nil {
                firstResult = result
            }
        }

        let end = CFAbsoluteTimeGetCurrent()
        let totalTime = (end - start) * 1000  // Convert to milliseconds
        let avgTime = totalTime / Double(iterations)

        print("Performance:")
        print("  Total time: \(String(format: "%.2f", totalTime)) ms")
        print("  Average per iteration: \(String(format: "%.3f", avgTime)) ms")
        if let sentences = firstResult {
            print("  Sentences found: \(sentences.count)")
        } else {
            print("  Sentences found: unavailable")
        }
    }

    // Memory usage test
    print("\n" + separator("=", count: 50))
    print("Memory Usage Test")
    print(separator("=", count: 50))

    // Test with batch processing
    let batchSize = 10
    let batchText = testTexts[1]  // Use medium text

    print("\nProcessing \(batchSize) texts sequentially...")

    let memStart = getMemoryUsage()
    for _ in 0 ..< batchSize {
        _ = splitter.split(text: batchText)
    }
    let memEnd = getMemoryUsage()
    let memDelta = memEnd - memStart

    print("Memory increase: \(formatBytes(memDelta))")

    print("\n" + separator("=", count: 50))
    print("Benchmark complete!")
}

// Helper function to get current memory usage
private func getMemoryUsage() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(
                mach_task_self_,
                task_flavor_t(MACH_TASK_BASIC_INFO),
                $0,
                &count)
        }
    }

    return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
}

// Helper function to format bytes
private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .binary
    return formatter.string(fromByteCount: bytes)
}

// Helper to create separator strings
private func separator(_ str: String, count: Int) -> String {
    return String(repeating: str, count: count)
}
