//
//  SegmentTextKit.swift
//

import Foundation
import CoreML

/// Main class for sentence segmentation and tokenization
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public class SegmentTextKit {
    private let sentenceSplitter: SentenceSplitter
    private let tokenizer: SentencePieceTokenizer

    /// Initialize with default models from bundle resources
    public init() throws {
        let bundle = Bundle.module

        guard let tokenizerURL = bundle.url(forResource: "sentencepiece.bpe", withExtension: "model", subdirectory: "Resources") else {
            throw SegmentTextError.modelNotFound("sentencepiece.bpe.model")
        }

        self.tokenizer = try SentencePieceTokenizer(modelPath: tokenizerURL.path)
        self.sentenceSplitter = try SentenceSplitter()
    }

    /// Initialize with custom model paths
    public init(sentenceModelPath: URL? = nil, tokenizerPath: URL? = nil) throws {
        let bundle = Bundle.module
        self.sentenceSplitter = try SentenceSplitter(modelPath: sentenceModelPath, tokenizerPath: tokenizerPath, bundle: bundle)

        if let tokenizerPath = tokenizerPath {
            self.tokenizer = try SentencePieceTokenizer(modelPath: tokenizerPath.path)
        } else {
            guard let defaultTokenizerURL = bundle.url(forResource: "sentencepiece.bpe", withExtension: "model", subdirectory: "Resources") else {
                throw SegmentTextError.modelNotFound("sentencepiece.bpe.model")
            }
            self.tokenizer = try SentencePieceTokenizer(modelPath: defaultTokenizerURL.path)
        }
    }

    // MARK: - Sentence Splitting

    /// Split text into sentences
    public func splitSentences(_ text: String, threshold: Float? = nil) -> [String] {
        return sentenceSplitter.split(text: text, threshold: threshold)
    }

    // MARK: - Tokenization

    /// Tokenize text and return token pieces
    public func tokenize(_ text: String) -> [String] {
        return tokenizer.tokenize(text: text)
    }

    /// Encode text and return token IDs
    public func encode(_ text: String) -> [Int] {
        return tokenizer.encode(text: text)
    }

    /// Encode text with offset mapping
    public func encodeWithOffsets(_ text: String) -> (tokens: [Int], offsets: [(Int, Int)]) {
        let result = tokenizer.encodeWithOffset(text: text)
        return (tokens: result.encodedTokens, offsets: result.offsetMapping)
    }

    /// Convert token ID to token string
    public func convertIdToToken(_ id: Int) -> String? {
        return tokenizer.convertIdToToken(id)
    }

    /// Convert token string to token ID
    public func convertTokenToId(_ token: String) -> Int? {
        return tokenizer.convertTokenToId(token)
    }

    /// Get vocabulary size
    public var vocabularySize: Int {
        return tokenizer.vocabSize
    }
}

/// Errors that can occur in SegmentTextKit
public enum SegmentTextError: Error, LocalizedError {
    case modelNotFound(String)
    case initializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .initializationFailed(let reason):
            return "Initialization failed: \(reason)"
        }
    }
}
