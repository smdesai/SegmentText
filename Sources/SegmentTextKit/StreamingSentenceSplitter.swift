//
//  StreamingSentenceSplitter.swift
//

import Accelerate
import Foundation

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
final public class StreamingSentenceSplitter {
    private let splitter: SentenceSplitter
    private let threshold: Float
    private let stripWhitespace: Bool
    private let delay: UInt64

    private var buffer = ""
    private var bufferEndsWithSpace = false
    private var bufferLastSignificant: Character? = nil
    private var needsSentenceSpacer = false
    private var lastOutputTerminator: Character? = nil
    private var newlineBoundaryOffsets: [Int] = []
    private let bufferLock = DispatchSemaphore(value: 1)

    public init(splitter: SentenceSplitter, threshold: Float, stripWhitespace: Bool, delay: UInt64)
    {
        self.splitter = splitter
        self.threshold = min(max(threshold, 0.1), 1.0)
        self.stripWhitespace = stripWhitespace
        self.delay = delay
    }

    public func stream(text: String) -> [String] {
        return process(text)
    }

    public func finishStream() -> [String] {
        return flush()
    }

    private func process(_ newText: String) -> [String] {
        bufferLock.wait()
        appendNormalized(newText)
        let snapshot = buffer
        bufferLock.signal()

        guard !snapshot.isEmpty else { return [] }

        let sentences = splitter.split(
            text: snapshot,
            threshold: threshold,
            stripWhitespace: false
        )

        guard !sentences.isEmpty else { return [] }

        var emitted: [String] = []
        var searchStart = snapshot.startIndex
        var consumedEnd = snapshot.startIndex

        for sentence in sentences where !sentence.isEmpty {
            guard
                let sentenceEnd = snapshot.index(
                    searchStart,
                    offsetBy: sentence.count,
                    limitedBy: snapshot.endIndex
                )
            else {
                break
            }

            guard snapshot[searchStart ..< sentenceEnd] == sentence else { break }

            let nextChar = sentenceEnd < snapshot.endIndex ? snapshot[sentenceEnd] : nil

            guard
                let termination = terminationIndex(
                    for: sentence,
                    in: snapshot,
                    sentenceStart: searchStart,
                    sentenceEnd: sentenceEnd,
                    nextChar: nextChar
                )
            else {
                break
            }

            var sentenceSlice = snapshot[searchStart ..< termination]
            if let trimmedStart = sentenceSlice.firstIndex(where: { !$0.isWhitespace }) {
                sentenceSlice = snapshot[trimmedStart ..< termination]
            }

            if !sentenceSlice.isEmpty {
                emitted.append(String(sentenceSlice))
            }
            consumedEnd = termination
            searchStart = termination
        }

        guard !emitted.isEmpty else { return [] }

        var consumedCount = snapshot.distance(from: snapshot.startIndex, to: consumedEnd)

        var remainingSlice = snapshot[consumedEnd...]
        let trimmedPrefixCount = remainingSlice.prefix { $0.isWhitespace }.count
        if trimmedPrefixCount > 0 {
            consumedCount += trimmedPrefixCount
            remainingSlice = remainingSlice.dropFirst(trimmedPrefixCount)
        }

        let remaining = String(remainingSlice)

        bufferLock.wait()
        buffer = remaining
        bufferEndsWithSpace = remaining.last == " "
        bufferLastSignificant = lastSignificantCharacter(in: remaining)
        if let last = bufferLastSignificant {
            lastOutputTerminator = last
        }
        if consumedCount > 0 && !newlineBoundaryOffsets.isEmpty {
            var adjusted: [Int] = []
            adjusted.reserveCapacity(newlineBoundaryOffsets.count)
            for offset in newlineBoundaryOffsets {
                let shifted = offset - consumedCount
                if shifted > 0 {
                    adjusted.append(shifted)
                }
            }
            newlineBoundaryOffsets = adjusted
        }
        bufferLock.signal()

        var result: [String] = []
        for sentence in emitted {
            let output =
                stripWhitespace
                ? sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                : sentence
            if output.isEmpty { continue }
            if let terminator = lastSignificantCharacter(in: sentence) {
                lastOutputTerminator = terminator
            }
            //print(">: \(output)")
            result.append(output)
        }
        return result
    }

    public func reset() {
        buffer = ""
        bufferEndsWithSpace = false
        bufferLastSignificant = nil
        needsSentenceSpacer = false
        newlineBoundaryOffsets.removeAll(keepingCapacity: true)
    }

    private func flush() -> [String] {
        let _ = process("")

        bufferLock.wait()
        let tail = buffer
        reset()
        bufferLock.signal()

        guard !tail.isEmpty else { return [] }

        if let termination = terminationIndex(
            for: tail,
            in: tail,
            sentenceStart: tail.startIndex,
            sentenceEnd: tail.endIndex,
            nextChar: nil
        ) {
            let emittedTail = String(tail[..<termination])
            let output =
                stripWhitespace
                ? emittedTail.trimmingCharacters(in: .whitespacesAndNewlines)
                : emittedTail
            if !output.isEmpty {
                if let terminator = lastSignificantCharacter(in: emittedTail) {
                    lastOutputTerminator = terminator
                }
                //print(">: \(output)")
                return [output]
            }
        }
        return []
    }

    private func terminationIndex(
        for sentence: String,
        in snapshot: String,
        sentenceStart: String.Index,
        sentenceEnd: String.Index,
        nextChar: Character?
    ) -> String.Index? {
        let startOffset = snapshot.distance(from: snapshot.startIndex, to: sentenceStart)
        let endOffset = snapshot.distance(from: snapshot.startIndex, to: sentenceEnd)

        if let boundary = newlineBoundaryOffsets.first(where: {
            $0 > startOffset && $0 <= endOffset
        }) {
            return snapshot.index(snapshot.startIndex, offsetBy: boundary)
        }

        if let next = nextChar, next.isNewline || next == " " || next == "\t" {
            return advancePastSentenceDelimiters(from: sentenceEnd, in: snapshot)
        }

        let closers = ")]}»”’』」》】）"
        let terminators = ".!?…。！？"

        var cursor = sentence.endIndex

        while cursor > sentence.startIndex {
            cursor = sentence.index(before: cursor)
            let ch = sentence[cursor]

            if ch == " " || ch == "\t" { continue }
            if ch.isNewline {
                return advancePastSentenceDelimiters(from: sentenceEnd, in: snapshot)
            }
            if closers.contains(ch) { continue }

            if terminators.contains(ch) {
                return advancePastSentenceDelimiters(from: sentenceEnd, in: snapshot)
            }
            break
        }

        return nil
    }

    private func advancePastSentenceDelimiters(from index: String.Index, in text: String)
        -> String.Index
    {
        var idx = index
        while idx < text.endIndex {
            let ch = text[idx]
            if ch.isNewline || ch == " " || ch == "\t" {
                idx = text.index(after: idx)
            } else {
                break
            }
        }
        return idx
    }

    private func appendNormalized(_ text: String) {
        guard !text.isEmpty else { return }

        var normalized = String()
        normalized.reserveCapacity(text.count)
        var previousWasSpace = bufferEndsWithSpace
        var lastSignificant = bufferLastSignificant ?? lastOutputTerminator
        var pendingSentenceSpace = needsSentenceSpacer
        let baseCount = buffer.count
        var appendedCount = 0
        var newBoundaries: [Int] = []

        for character in text {
            if character.isNewline {
                if lastSignificant == "." {
                    newBoundaries.append(baseCount + appendedCount)
                    pendingSentenceSpace = true
                } else if lastSignificant != nil {
                    normalized.append(".")
                    appendedCount += 1
                    lastSignificant = "."
                    previousWasSpace = false
                    newBoundaries.append(baseCount + appendedCount)
                    pendingSentenceSpace = true
                }
                continue
            }

            if character == " " {
                if pendingSentenceSpace {
                    pendingSentenceSpace = false
                }
                if previousWasSpace { continue }
                normalized.append(" ")
                appendedCount += 1
                previousWasSpace = true
                continue
            }

            if pendingSentenceSpace {
                if !previousWasSpace {
                    normalized.append(" ")
                    appendedCount += 1
                    previousWasSpace = true
                }
                pendingSentenceSpace = false
            }

            normalized.append(character)
            appendedCount += 1
            previousWasSpace = false
            if !character.isWhitespace {
                lastSignificant = character
            }
        }

        needsSentenceSpacer = pendingSentenceSpace

        if !normalized.isEmpty {
            buffer.append(normalized)
        }

        if !newBoundaries.isEmpty {
            for boundary in newBoundaries {
                if newlineBoundaryOffsets.last != boundary {
                    newlineBoundaryOffsets.append(boundary)
                }
            }
        }

        bufferEndsWithSpace = previousWasSpace
        bufferLastSignificant = lastSignificant
        if let lastSignificant {
            lastOutputTerminator = lastSignificant
        }
    }

    private func lastSignificantCharacter(in text: String) -> Character? {
        for character in text.reversed() {
            if character.isWhitespace { continue }
            return character
        }
        return nil
    }
}
