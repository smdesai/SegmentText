//
//  DownloadProgress.swift
//  SegmentTextKit
//
//  Progress tracking for model downloads from HuggingFace
//

import Foundation

/// Represents the current state of a model download operation.
public enum DownloadProgress: Sendable {
    /// Download has not yet started.
    case notStarted

    /// Checking if the model exists locally or needs to be downloaded.
    case checking

    /// Download is in progress.
    /// - Parameters:
    ///   - fraction: Completion percentage (0.0 to 1.0)
    ///   - bytesPerSecond: Current download speed, if available
    case downloading(fraction: Double, bytesPerSecond: Double?)

    /// Download completed successfully.
    /// - Parameter modelURL: Local URL where the model was saved
    case completed(URL)

    /// Download failed with an error.
    /// - Parameter error: The error that caused the failure
    case failed(Error)
}

/// Errors specific to model download operations.
public enum ModelDownloadError: Error, LocalizedError, Sendable {
    /// Network request failed.
    case networkError(String)

    /// Model file not found on HuggingFace.
    case modelNotFound(String)

    /// Download was cancelled by user.
    case cancelled

    /// Failed to write to cache directory.
    case cacheWriteError(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .cancelled:
            return "Download was cancelled"
        case .cacheWriteError(let message):
            return "Cache write error: \(message)"
        }
    }
}
