//
//  SentenceSplitter.swift
//

import Accelerate
import CoreML
import Foundation

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public class SentenceSplitter {
    private let model: MLModel
    private let tokenizer: SentencePieceTokenizer
    private let predictionOptions = MLPredictionOptions()

    // Special token IDs (Python-compatible)
    private let clsTokenId: Int32 = 0
    private let sepTokenId: Int32 = 2
    private let padTokenId: Int32 = 1

    // Default parameters
    private let maxLength = 512
    private let stride = 256
    private let defaultThreshold: Float = 0.25

    // Cached arrays to avoid repeated allocations
    private let inputIdsArray: MLMultiArray
    private let attentionMaskArray: MLMultiArray

    // Cache for tokenization results
    private var tokenCache = [String: (tokens: [Int], offsets: [(Int, Int)])]()
    private var tokenCacheOrder: [String] = []
    private let cacheSize = 100

    /// Initialize with model and tokenizer paths
    public init(modelPath: URL? = nil, tokenizerPath: URL? = nil, bundle: Bundle) throws {
        // Load CoreML model
        let modelURL = bundle.url(
            forResource: "SaT",
            withExtension: "mlmodelc",
            subdirectory: "Resources"
        )!

        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndGPU
        config.allowLowPrecisionAccumulationOnGPU = true
        self.model = try MLModel(contentsOf: modelURL, configuration: config)

        // Load tokenizer
        let tokenizerURL =
            tokenizerPath ?? bundle.url(
                forResource: "sentencepiece.bpe",
                withExtension: "model",
                subdirectory: "Resources"
            )!
        self.tokenizer = try SentencePieceTokenizer(modelPath: tokenizerURL.path)

        // Pre-allocate arrays
        self.inputIdsArray = try MLMultiArray(
            shape: [1, NSNumber(value: maxLength)], dataType: .int32)
        self.attentionMaskArray = try MLMultiArray(
            shape: [1, NSNumber(value: maxLength)], dataType: .int32)
    }

    /// Initialize with just bundle
    public convenience init(bundle: Bundle) throws {
        try self.init(modelPath: nil, tokenizerPath: nil, bundle: bundle)
    }

    /// Initializer using module bundle
    public convenience init() throws {
        try self.init(modelPath: nil, tokenizerPath: nil, bundle: Bundle.module)
    }

    public func split(
        text: String,
        threshold: Float? = nil,
        stripWhitespace: Bool = false
    ) -> [String] {
        let sentenceThreshold = threshold ?? defaultThreshold

        // Get probabilities for each character position
        let probs = try! predictProba(text: text)

        // Find indices where probability exceeds threshold
        let indices = findThresholdIndices(probs: probs, threshold: sentenceThreshold)

        // Split text at these indices
        return indicesToSentences(
            text: text,
            indices: indices,
            stripWhitespace: stripWhitespace
        )
    }

    private func findThresholdIndices(probs: [Float], threshold: Float) -> [Int] {
        var indices: [Int] = []
        indices.reserveCapacity(probs.count / 10)  // Estimate ~10% will exceed threshold

        for (index, prob) in probs.enumerated() {
            if prob > threshold {
                indices.append(index)
            }
        }

        return indices
    }

    /// Predict sentence boundary probabilities with caching
    private func predictProba(text: String) throws -> [Float] {
        guard !text.isEmpty else { return [] }

        let textLength = text.count

        if textLength <= maxLength - 2 {
            return try processSingleBlock(text: text)
        } else {
            return try processWithStride(text: text)
        }
    }

    /// Process a single block
    private func processSingleBlock(text: String) throws -> [Float] {
        // Check cache first
        if let cached = tokenCache[text] {
            touchCacheEntry(for: text)
            return try processTokenizedText(
                text: text, tokens: cached.tokens, offsets: cached.offsets)
        }

        // Tokenize and cache
        let (tokens, offsets) = tokenizer.encodeWithOffset(text: text)

        cacheTokenization(tokens: tokens, offsets: offsets, for: text)

        return try processTokenizedText(text: text, tokens: tokens, offsets: offsets)
    }

    /// Process already tokenized text
    private func processTokenizedText(text: String, tokens: [Int], offsets: [(Int, Int)]) throws
        -> [Float]
    {
        // Prepare input efficiently
        let (inputIds, attentionMask, usedTokenCount) = tokenizer.encodeForModel(
            tokens: tokens,
            maxLength: maxLength,
            addSpecialTokens: true,
            clsTokenId: clsTokenId,
            sepTokenId: sepTokenId,
            padTokenId: padTokenId
        )

        let sequenceLength = usedTokenCount + 2  // +2 for CLS and SEP tokens

        // Use cached MLMultiArrays - use memcpy for better performance
        inputIds.withUnsafeBufferPointer { idsBuffer in
            attentionMask.withUnsafeBufferPointer { maskBuffer in
                // Get raw pointers for direct memory access
                let inputPtr = inputIdsArray.dataPointer.bindMemory(
                    to: Int32.self, capacity: maxLength)
                let maskPtr = attentionMaskArray.dataPointer.bindMemory(
                    to: Int32.self, capacity: maxLength)

                // Copy data directly
                memcpy(inputPtr, idsBuffer.baseAddress, maxLength * MemoryLayout<Int32>.size)
                memcpy(maskPtr, maskBuffer.baseAddress, maxLength * MemoryLayout<Int32>.size)
            }
        }

        // Run model prediction
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: inputIdsArray),
            "attention_mask": MLFeatureValue(multiArray: attentionMaskArray),
        ])

        let outputFeatures = try model.prediction(from: inputFeatures, options: predictionOptions)

        guard let logits = outputFeatures.featureValue(for: "output")?.multiArrayValue else {
            throw SegmentTextError.initializationFailed(
                "SaT model output missing 'output' feature.")
        }

        // Use pre-allocated buffer for probabilities
        var probabilities = [Float](repeating: 0, count: sequenceLength)

        // Apply sigmoid using Accelerate
        probabilities.withUnsafeMutableBufferPointer { buffer in
            for i in 0 ..< sequenceLength {
                buffer[i] = logits[i].floatValue
            }

            // Apply sigmoid using vForce
            var negOne: Float = -1.0
            vDSP_vsmul(
                buffer.baseAddress!, 1, &negOne, buffer.baseAddress!, 1, vDSP_Length(sequenceLength)
            )

            var count = Int32(sequenceLength)
            vvexpf(buffer.baseAddress!, buffer.baseAddress!, &count)

            var one: Float = 1.0
            vDSP_vsadd(
                buffer.baseAddress!, 1, &one, buffer.baseAddress!, 1, vDSP_Length(sequenceLength))
            vvrecf(buffer.baseAddress!, buffer.baseAddress!, &count)
        }

        // Map token probabilities to character positions
        let offsetsToUse: [(Int, Int)]
        if usedTokenCount < offsets.count {
            offsetsToUse = Array(offsets.prefix(usedTokenCount))
        } else {
            offsetsToUse = offsets
        }

        return mapTokenProbsToCharProbs(
            text: text,
            tokenProbs: probabilities,
            offsetMapping: offsetsToUse,
            excludeSpecialTokens: true
        )
    }

    private func mapTokenProbsToCharProbs(
        text: String,
        tokenProbs: [Float],
        offsetMapping: [(Int, Int)],
        excludeSpecialTokens: Bool
    ) -> [Float] {
        var charProbs = [Float](repeating: 0, count: text.count)

        let startIdx = excludeSpecialTokens ? 1 : 0
        let endIdx = min(tokenProbs.count - (excludeSpecialTokens ? 1 : 0), offsetMapping.count + 1)

        for i in startIdx ..< endIdx {
            let tokenIdx = i - (excludeSpecialTokens ? 1 : 0)
            if tokenIdx < offsetMapping.count {
                let end = offsetMapping[tokenIdx].1
                if end > 0 && end <= charProbs.count {
                    charProbs[end - 1] = tokenProbs[i]
                }
            }
        }

        return charProbs
    }

    /// Process with sliding window
    private func processWithStride(text: String) throws -> [Float] {
        var allProbs = [Float](repeating: 0, count: text.count)
        var counts = [Int](repeating: 0, count: text.count)

        let blockSize = maxLength - 2
        let textCount = text.count
        var offset = 0

        while offset < textCount {
            let endOffset = min(offset + blockSize, textCount)
            let startIdx = text.index(text.startIndex, offsetBy: offset)
            let endIdx = text.index(text.startIndex, offsetBy: endOffset)
            let block = String(text[startIdx ..< endIdx])

            let blockProbs = try processSingleBlock(text: block)
            let limit = min(blockProbs.count, textCount - offset)

            for i in 0 ..< limit {
                let globalIdx = offset + i
                allProbs[globalIdx] += blockProbs[i]
                counts[globalIdx] += 1
            }

            if endOffset == textCount {
                break
            }

            let nextOffset = offset + stride
            if nextOffset >= textCount {
                let tailOffset = max(textCount - blockSize, 0)
                if tailOffset <= offset {
                    break
                }
                offset = tailOffset
            } else {
                offset = nextOffset
            }
        }

        // Average overlapping predictions
        for i in 0 ..< allProbs.count {
            if counts[i] > 0 {
                allProbs[i] /= Float(counts[i])
            }
        }

        return allProbs
    }

    private func cacheTokenization(
        tokens: [Int],
        offsets: [(Int, Int)],
        for key: String
    ) {
        tokenCache[key] = (tokens, offsets)
        if let index = tokenCacheOrder.firstIndex(of: key) {
            tokenCacheOrder.remove(at: index)
        }
        tokenCacheOrder.append(key)
        trimTokenCacheIfNeeded()
    }

    private func touchCacheEntry(for key: String) {
        if let index = tokenCacheOrder.firstIndex(of: key) {
            tokenCacheOrder.remove(at: index)
            tokenCacheOrder.append(key)
        }
    }

    private func trimTokenCacheIfNeeded() {
        guard tokenCacheOrder.count > cacheSize else { return }
        let overflow = tokenCacheOrder.count - cacheSize
        let batchSize = max(cacheSize / 5, 1)
        let removalCount = max(overflow, batchSize)

        for _ in 0 ..< min(removalCount, tokenCacheOrder.count) {
            let key = tokenCacheOrder.removeFirst()
            tokenCache.removeValue(forKey: key)
        }
    }

    /// Sentence extraction
    private func indicesToSentences(
        text: String,
        indices: [Int],
        stripWhitespace: Bool
    ) -> [String] {
        var sentences: [String] = []
        sentences.reserveCapacity(indices.count + 1)

        var offset = 0
        let textArray = Array(text)

        for idx in indices {
            var endIdx = idx + 1

            // Skip trailing whitespace
            while endIdx < textArray.count && textArray[endIdx].isWhitespace {
                endIdx += 1
            }

            let sentence = String(textArray[offset ..< endIdx])
            if stripWhitespace {
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
            } else if !sentence.isEmpty {
                sentences.append(sentence)
            }

            offset = endIdx
        }

        // Add remaining text
        if offset < textArray.count {
            let sentence = String(textArray[offset...])

            if stripWhitespace {
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
            } else if !sentence.isEmpty {
                sentences.append(sentence)
            }
        }

        return sentences
    }
}
