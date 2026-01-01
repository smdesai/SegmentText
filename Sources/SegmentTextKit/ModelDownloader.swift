//
//  ModelDownloader.swift
//  SegmentTextKit
//
//  Manages downloading CoreML models from HuggingFace Hub
//

import Foundation
import Hub

/// Thread-safe progress state container for download progress reporting.
private final class ProgressState: @unchecked Sendable {
    private let lock = NSLock()
    private var _fraction: Double = 0
    private var _speed: Double?

    var current: (Double, Double?)? {
        lock.lock()
        defer { lock.unlock() }
        return (_fraction, _speed)
    }

    func update(fraction: Double, speed: Double?) {
        lock.lock()
        defer { lock.unlock() }
        _fraction = fraction
        _speed = speed
    }
}

/// Manages downloading and caching of CoreML models from HuggingFace Hub.
///
/// This actor provides thread-safe model downloading with progress reporting,
/// automatic caching, and deduplication of concurrent download requests.
public actor ModelDownloader {
    /// Shared instance for the default SaT model.
    public static let shared = ModelDownloader()

    /// Default HuggingFace repository for the SaT model.
    public static let defaultRepoId = "smdesai/SaT"

    /// Glob pattern to match the compiled CoreML model directory.
    public static let defaultGlob = "SaT.mlmodelc/**"

    /// The model filename (directory name for compiled models).
    public static let modelFilename = "SaT.mlmodelc"

    private var activeDownloadTask: Task<URL, Error>?
    private var progressContinuations: [UUID: AsyncStream<DownloadProgress>.Continuation] = [:]

    /// Cache directory for downloaded models.
    ///
    /// Uses `~/Library/Caches/SegmentText/models` on all platforms.
    /// The system may purge this directory when storage is low.
    public static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("SegmentText/models", isDirectory: true)
    }

    /// Returns the local URL of the cached model if it exists.
    ///
    /// - Returns: URL to the cached `.mlmodelc` directory, or `nil` if not cached.
    public nonisolated func cachedModelURL() -> URL? {
        let hub = HubApi(downloadBase: Self.cacheDirectory)
        let repo = Hub.Repo(id: Self.defaultRepoId)
        let repoLocation = hub.localRepoLocation(repo)
        let modelPath = repoLocation.appendingPathComponent(Self.modelFilename)

        // Check if the model directory exists and contains expected files
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            // Verify it contains at least the metadata.json (basic integrity check)
            let metadataPath = modelPath.appendingPathComponent("metadata.json")
            if FileManager.default.fileExists(atPath: metadataPath.path) {
                return modelPath
            }
        }

        return nil
    }

    /// Downloads the model from HuggingFace, returning a stream of progress updates.
    ///
    /// If a download is already in progress, returns a stream connected to the same download.
    /// The stream will emit `.completed(URL)` when finished or `.failed(Error)` on error.
    ///
    /// - Returns: An async stream of download progress updates.
    public func download() -> AsyncStream<DownloadProgress> {
        AsyncStream { continuation in
            let id = UUID()
            self.progressContinuations[id] = continuation

            continuation.onTermination = { @Sendable _ in
                Task { await self.removeContinuation(id: id) }
            }

            // If already downloading, new subscribers just get progress updates
            if self.activeDownloadTask != nil {
                continuation.yield(.checking)
                return
            }

            // Start new download
            self.activeDownloadTask = Task {
                defer {
                    self.activeDownloadTask = nil
                    self.finishAllContinuations()
                }

                do {
                    self.broadcast(.checking)

                    // Check cache first
                    if let cached = self.cachedModelURL() {
                        self.broadcast(.completed(cached))
                        return cached
                    }

                    // Ensure cache directory exists
                    try FileManager.default.createDirectory(
                        at: Self.cacheDirectory,
                        withIntermediateDirectories: true
                    )

                    // Configure HubApi with our cache directory
                    let hub = HubApi(
                        downloadBase: Self.cacheDirectory,
                        useBackgroundSession: false
                    )

                    // Download using snapshot with glob pattern
                    // Use nonisolated progress handling to avoid Sendable issues
                    let progressState = ProgressState()
                    let repoLocation = try await hub.snapshot(
                        from: Self.defaultRepoId,
                        matching: Self.defaultGlob
                    ) { (progress: Progress) in
                        progressState.update(fraction: progress.fractionCompleted, speed: progress.userInfo[.throughputKey] as? Double)
                    }

                    // Broadcast final progress
                    if let (fraction, speed) = progressState.current {
                        self.broadcast(.downloading(fraction: fraction, bytesPerSecond: speed))
                    }

                    // The model should now be at repoLocation/SaT.mlmodelc
                    let modelPath = repoLocation.appendingPathComponent(Self.modelFilename)

                    guard FileManager.default.fileExists(atPath: modelPath.path) else {
                        throw ModelDownloadError.modelNotFound(Self.modelFilename)
                    }

                    self.broadcast(.completed(modelPath))
                    return modelPath

                } catch is CancellationError {
                    self.broadcast(.failed(ModelDownloadError.cancelled))
                    throw ModelDownloadError.cancelled
                } catch let error as Hub.HubClientError {
                    let downloadError: ModelDownloadError
                    switch error {
                    case .fileNotFound(let file):
                        downloadError = .modelNotFound(file)
                    case .authorizationRequired:
                        downloadError = .networkError("Authorization required for private repository")
                    default:
                        downloadError = .networkError(error.localizedDescription)
                    }
                    self.broadcast(.failed(downloadError))
                    throw downloadError
                } catch {
                    let downloadError = ModelDownloadError.networkError(error.localizedDescription)
                    self.broadcast(.failed(downloadError))
                    throw downloadError
                }
            }
        }
    }

    /// Cancels any active download.
    public func cancel() {
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
    }

    /// Clears the cached model, forcing a fresh download on next use.
    ///
    /// - Throws: File system errors if the cache cannot be removed.
    public nonisolated func clearCache() throws {
        let hub = HubApi(downloadBase: Self.cacheDirectory)
        let repo = Hub.Repo(id: Self.defaultRepoId)
        let repoLocation = hub.localRepoLocation(repo)

        if FileManager.default.fileExists(atPath: repoLocation.path) {
            try FileManager.default.removeItem(at: repoLocation)
        }
    }

    // MARK: - Private

    private func removeContinuation(id: UUID) {
        progressContinuations.removeValue(forKey: id)
    }

    private func broadcast(_ progress: DownloadProgress) {
        for continuation in progressContinuations.values {
            continuation.yield(progress)
        }
    }

    private func finishAllContinuations() {
        for continuation in progressContinuations.values {
            continuation.finish()
        }
        progressContinuations.removeAll()
    }
}
