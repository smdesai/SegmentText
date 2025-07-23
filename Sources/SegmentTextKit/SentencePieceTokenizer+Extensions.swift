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
    public func encodeWithOffset(text: String) -> (encodedTokens: [Int], offsetMapping: [(Int, Int)]) {
        // Get encoded tokens
        let encodedTokens = self.encode(text: text)
        
        // Get token pieces
        let tokenPieces = self.tokenize(text: text)
        
        // Calculate offset mapping using a more efficient approach
        var offsetMapping: [(Int, Int)] = []
        offsetMapping.reserveCapacity(tokenPieces.count)
        
        // Convert text to array for O(1) access
        let textArray = Array(text)
        var currentPosition = 0
        
        for piece in tokenPieces {
            // Handle the special underscore character that represents spaces
            let isSpacePrefix = piece.hasPrefix("▁")
            let cleanPiece = isSpacePrefix ? String(piece.dropFirst()) : piece
            
            if isSpacePrefix && currentPosition > 0 && currentPosition < textArray.count {
                // Skip the space between words if not at the beginning
                if textArray[currentPosition] == " " {
                    currentPosition += 1
                }
            }
            
            // Calculate end position based on clean piece length
            let start = currentPosition
            let pieceLength = cleanPiece.count
            let end = min(start + pieceLength, textArray.count)
            
            offsetMapping.append((start, end))
            currentPosition = end
        }
        
        return (encodedTokens: encodedTokens, offsetMapping: offsetMapping)
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
        // Tokenize the text
        let tokens = self.encode(text: text)
        
        // Create input sequence
        var inputSequence: [Int32] = []
        
        if addSpecialTokens {
            inputSequence.append(clsTokenId)
        }
        
        inputSequence.append(contentsOf: tokens.map { Int32($0) })
        
        if addSpecialTokens {
            inputSequence.append(sepTokenId)
        }
        
        // Calculate current length and padding needed
        let currentLength = inputSequence.count
        let paddingLength = maxLength - currentLength
        
        if paddingLength > 0 {
            // Pad if shorter than maxLength
            inputSequence.append(contentsOf: Array(repeating: padTokenId, count: paddingLength))
        } else if paddingLength < 0 {
            // Truncate if longer than maxLength
            if addSpecialTokens {
                inputSequence = Array(inputSequence.prefix(maxLength - 1)) + [sepTokenId]
            } else {
                inputSequence = Array(inputSequence.prefix(maxLength))
            }
        }
        
        // Create attention mask (1 for real tokens, 0 for padding)
        let realTokenCount = min(currentLength, maxLength)
        var attentionMask: [Int32] = Array(repeating: 1, count: realTokenCount)
        
        if paddingLength > 0 {
            attentionMask.append(contentsOf: Array(repeating: 0, count: paddingLength))
        }
        
        return (inputIds: inputSequence, attentionMask: attentionMask)
    }
}
