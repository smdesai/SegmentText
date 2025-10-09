//
//  SentencePieceTokenizer.swift
//  Swift wrapper for Google's SentencePiece
//

import Foundation
import Hub
import SentencePieceWrapper
import Tokenizers

/// Swift wrapper for Google's SentencePiece tokenizer
public class SentencePieceTokenizer: PreTrainedTokenizerModel {
    private let processor: SentencePieceProcessor
    private let modelPath: String

    public let unknownTokenId: Int? = 0
    public var unknownToken: String? { "<unk>" }

    public var bosToken: String? { nil }
    public var bosTokenId: Int? { nil }
    public var eosToken: String? { nil }
    public var eosTokenId: Int? { nil }
    public var fuseUnknownTokens: Bool { false }

    public init(modelPath: String) throws {
        self.modelPath = modelPath

        guard let proc = sentencepiece_create(modelPath) else {
            throw TokenizerError.missingVocab
        }

        self.processor = proc
    }

    deinit {
        sentencepiece_free_processor(processor)
    }

    public func tokenize(text: String) -> [String] {
        var piecesPtr: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
        let count = sentencepiece_encode_as_pieces(processor, text, &piecesPtr)

        guard count > 0, let pieces = piecesPtr else {
            return []
        }

        var result: [String] = []
        for i in 0 ..< Int(count) {
            if let piece = pieces[i] {
                result.append(String(cString: piece))
            }
        }

        sentencepiece_free_pieces(pieces, count)
        return result
    }

    public func encode(text: String) -> [Int] {
        var idsPtr: UnsafeMutablePointer<Int32>?
        let count = sentencepiece_encode_as_ids(processor, text, &idsPtr)

        guard count > 0, let ids = idsPtr else {
            return []
        }

        let result = Array(UnsafeBufferPointer(start: ids, count: Int(count)))
            .map { Int($0) + 1 }  // Add 1 to match Python tokenizer behavior

        sentencepiece_free_ids(ids)
        return result
    }

    public func convertTokenToId(_ token: String) -> Int? {
        let id = sentencepiece_piece_to_id(processor, token)
        return id >= 0 ? Int(id) + 1 : nil  // Add 1 to match Python tokenizer behavior
    }

    public func convertIdToToken(_ id: Int) -> String? {
        guard let piece = sentencepiece_id_to_piece(processor, Int32(id - 1)) else {  // Subtract 1 to match Python tokenizer behavior
            return nil
        }
        return String(cString: piece)
    }

    public func convertTokensToIds(_ tokens: [String]) -> [Int] {
        tokens.compactMap { convertTokenToId($0) }
    }

    public func convertIdsToTokens(_ ids: [Int]) -> [String?] {
        ids.map { convertIdToToken($0) }
    }

    public var vocabSize: Int {
        Int(sentencepiece_get_piece_size(processor))
    }

    public func getScore(id: Int) -> Float {
        sentencepiece_get_score(processor, Int32(id))
    }

    // Required initializer for PreTrainedTokenizerModel
    public required convenience init(
        tokenizerConfig: Config, tokenizerData: Config, addedTokens: [String: Int]
    ) throws {
        // Extract model path from config or use default
        let modelPath = "tokenizer/sentencepiece.bpe.model"
        try self.init(modelPath: modelPath)
    }
}
