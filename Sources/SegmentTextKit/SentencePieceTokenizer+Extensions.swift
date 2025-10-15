//
//  SentencePieceTokenizer+Extensions.swift
//  Extensions for SentencePieceTokenizer
//

import Foundation

extension SentencePieceTokenizer {
    /// Encode text and return both encoded tokens and offset mapping
    /// - Parameter text: The text to encode
    /// - Returns: A tuple containing encoded tokens and offset mapping
    ///   where each offset is (start, end) position in the original text
    public func encodeWithOffset(text: String) -> (
        encodedTokens: [Int], offsetMapping: [(Int, Int)]
    ) {
        guard !text.isEmpty else { return ([], []) }

        let encodedTokens = self.encode(text: text)
        guard !encodedTokens.isEmpty else { return ([], []) }

        var offsetMapping: [(Int, Int)] = []
        offsetMapping.reserveCapacity(encodedTokens.count)

        var cursorIndex = text.startIndex

        for tokenId in encodedTokens {
            guard let piece = convertIdToToken(tokenId) else {
                let position = text.distance(from: text.startIndex, to: cursorIndex)
                offsetMapping.append((position, position))
                continue
            }

            var pieceText = piece
            var searchStart = cursorIndex

            if pieceText.hasPrefix("▁") {
                pieceText.removeFirst()
                while searchStart < text.endIndex, text[searchStart].isWhitespace {
                    searchStart = text.index(after: searchStart)
                }
                cursorIndex = searchStart
            }

            if pieceText.isEmpty {
                let position = text.distance(from: text.startIndex, to: cursorIndex)
                offsetMapping.append((position, position))
                continue
            }

            guard let matchRange = text[searchStart...].range(of: pieceText) else {
                let position = text.distance(from: text.startIndex, to: cursorIndex)
                offsetMapping.append((position, position))
                continue
            }

            let start = text.distance(from: text.startIndex, to: matchRange.lowerBound)
            let end = text.distance(from: text.startIndex, to: matchRange.upperBound)
            offsetMapping.append((start, end))
            cursorIndex = matchRange.upperBound
        }

        return (encodedTokens: encodedTokens, offsetMapping: offsetMapping)
    }

    /// Encode text with padding and special tokens for model input
    /// - Parameters:
    ///   - tokens: Pre-tokenized ids (Python-compatible, already +1 adjusted)
    ///   - maxLength: Maximum sequence length (default: 512)
    ///   - addSpecialTokens: Whether to add CLS and SEP tokens (default: true)
    ///   - clsTokenId: CLS token ID (default: 0 for Python compatibility)
    ///   - sepTokenId: SEP token ID (default: 2 for Python compatibility)
    ///   - padTokenId: PAD token ID (default: 1 for Python compatibility)
    /// - Returns: A tuple containing input IDs, attention mask, and the number of non-special tokens used
    public func encodeForModel(
        tokens: [Int],
        maxLength: Int = 512,
        addSpecialTokens: Bool = true,
        clsTokenId: Int32 = 0,
        sepTokenId: Int32 = 2,
        padTokenId: Int32 = 1
    ) -> (inputIds: [Int32], attentionMask: [Int32], usedTokenCount: Int) {
        guard maxLength > 0 else { return ([], [], 0) }

        let specialTokenCount = addSpecialTokens ? 2 : 0
        let capacityForTokens = max(0, maxLength - specialTokenCount)
        let usedTokenCount = min(tokens.count, capacityForTokens)

        var inputIds = [Int32](repeating: padTokenId, count: maxLength)
        var attentionMask = [Int32](repeating: 0, count: maxLength)

        var cursor = 0

        if addSpecialTokens {
            inputIds[cursor] = clsTokenId
            attentionMask[cursor] = 1
            cursor += 1
        }

        if usedTokenCount > 0 {
            for token in tokens.prefix(usedTokenCount) {
                guard cursor < maxLength else { break }
                inputIds[cursor] = Int32(token)
                attentionMask[cursor] = 1
                cursor += 1
            }
        }

        if addSpecialTokens && cursor < maxLength {
            inputIds[cursor] = sepTokenId
            attentionMask[cursor] = 1
            cursor += 1
        }

        return (inputIds, attentionMask, usedTokenCount)
    }

    /// Encode text with padding and special tokens for model input
    /// - Parameters:
    ///   - text: The text to encode
    ///   - maxLength: Maximum sequence length (default: 512)
    ///   - addSpecialTokens: Whether to add CLS and SEP tokens (default: true)
    ///   - clsTokenId: CLS token ID (default: 0 for Python compatibility)
    ///   - sepTokenId: SEP token ID (default: 2 for Python compatibility)
    ///   - padTokenId: PAD token ID (default: 1 for Python compatibility)
    /// - Returns: A tuple containing input IDs and attention mask
    public func encodeForModel(
        text: String,
        maxLength: Int = 512,
        addSpecialTokens: Bool = true,
        clsTokenId: Int32 = 0,
        sepTokenId: Int32 = 2,
        padTokenId: Int32 = 1
    ) -> (inputIds: [Int32], attentionMask: [Int32]) {
        let tokens = self.encode(text: text)
        let (inputIds, attentionMask, _) = encodeForModel(
            tokens: tokens,
            maxLength: maxLength,
            addSpecialTokens: addSpecialTokens,
            clsTokenId: clsTokenId,
            sepTokenId: sepTokenId,
            padTokenId: padTokenId
        )
        return (inputIds, attentionMask)
    }
}
