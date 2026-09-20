//
//  TranscriptionClient.swift
//  Hex
//
//  Created by Kit Langton on 1/24/25.
//

import Dependencies
import DependenciesMacros
import Foundation
import HexCore

private let transcriptionLogger = HexLog.transcription
private let modelsLogger = HexLog.models
private let parakeetLogger = HexLog.parakeet

/// Transcription options passed through from the recording flow.
///
/// Parakeet ignores language/chunking today, but the shape is kept so the
/// recording flow doesn't need to know which engine is underneath.
struct DecodingOptions: Sendable {
  var language: String?
  var detectLanguage: Bool
  var chunkingStrategy: ChunkingStrategy
}

enum ChunkingStrategy: Sendable {
  case vad
}

/// Recommended-model response (Parakeet-only).
struct ModelSupport: Sendable {
  var `default`: String
}

/// A client that downloads and loads Parakeet models, then transcribes audio files using the loaded model.
/// Exposes progress callbacks to report overall download-and-load percentage and transcription progress.
@DependencyClient
struct TranscriptionClient {
  /// Transcribes an audio file at the specified `URL` using the named `model`.
  /// Reports transcription progress via `progressCallback`.
  var transcribe: @Sendable (URL, String, DecodingOptions, @escaping (Progress) -> Void) async throws -> String

  /// Ensures a model is downloaded (if missing) and loaded into memory, reporting progress via `progressCallback`.
  var downloadModel: @Sendable (String, @escaping (Progress) -> Void) async throws -> Void

  /// Deletes a model from disk if it exists
  var deleteModel: @Sendable (String) async throws -> Void

  /// Checks if a named model is already downloaded on this system.
  var isModelDownloaded: @Sendable (String) async -> Bool = { _ in false }

  /// Fetches the recommended model for the user's hardware.
  var getRecommendedModels: @Sendable () async throws -> ModelSupport

  /// Lists all supported model variants (Parakeet-only).
  var getAvailableModels: @Sendable () async throws -> [String]
}

extension TranscriptionClient: DependencyKey {
  static var liveValue: Self {
    let live = TranscriptionClientLive()
    return Self(
      transcribe: { try await live.transcribe(url: $0, model: $1, options: $2, progressCallback: $3) },
      downloadModel: { try await live.downloadAndLoadModel(variant: $0, progressCallback: $1) },
      deleteModel: { try await live.deleteModel(variant: $0) },
      isModelDownloaded: { await live.isModelDownloaded($0) },
      getRecommendedModels: { await live.getRecommendedModels() },
      getAvailableModels: { try await live.getAvailableModels() }
    )
  }
}

extension DependencyValues {
  var transcription: TranscriptionClient {
    get { self[TranscriptionClient.self] }
    set { self[TranscriptionClient.self] = newValue }
  }
}

/// An `actor` that manages Parakeet models by downloading,
/// loading them into memory, and then performing transcriptions.
actor TranscriptionClientLive {
  private var parakeet: ParakeetClient = ParakeetClient()

  // MARK: - Public Methods

  /// Ensures the given `variant` model is downloaded and loaded, reporting progress.
  func downloadAndLoadModel(variant: String, progressCallback: @escaping (Progress) -> Void) async throws {
    modelsLogger.info("Preparing Parakeet model download and load for \(variant)")
    try await parakeet.ensureLoaded(modelName: variant, progress: progressCallback)
  }

  /// Deletes a model from disk if it exists
  func deleteModel(variant: String) async throws {
    try await parakeet.deleteCaches(modelName: variant)
    modelsLogger.info("Deleted model \(variant)")
  }

  /// Returns `true` if the model is already downloaded to the local caches.
  func isModelDownloaded(_ modelName: String) async -> Bool {
    let available = await parakeet.isModelAvailable(modelName)
    parakeetLogger.debug("Parakeet available? \(available)")
    return available
  }

  /// Returns the recommended model for the user's hardware.
  func getRecommendedModels() async -> ModelSupport {
    ModelSupport(default: ParakeetModel.multilingualV3.identifier)
  }

  /// Lists all supported model variants (Parakeet-only).
  func getAvailableModels() async throws -> [String] {
    ParakeetModel.allCases.map(\.identifier)
  }

  /// Transcribes the audio file at `url` using a `model` name.
  /// The model is downloaded and loaded first if needed.
  /// Transcription progress can be monitored via `progressCallback`.
  func transcribe(
    url: URL,
    model: String,
    options: DecodingOptions,
    progressCallback: @escaping (Progress) -> Void
  ) async throws -> String {
    let startAll = Date()
    transcriptionLogger.notice("Transcribing with Parakeet model=\(model) file=\(url.lastPathComponent)")
    let startLoad = Date()
    try await downloadAndLoadModel(variant: model) { p in
      progressCallback(p)
    }
    transcriptionLogger.info("Parakeet ensureLoaded took \(String(format: "%.2f", Date().timeIntervalSince(startLoad)))s")
    let preparedClip = try ParakeetClipPreparer.ensureMinimumDuration(url: url, logger: parakeetLogger)
    defer { preparedClip.cleanup() }
    let startTx = Date()
    let text = try await parakeet.transcribe(preparedClip.url)
    transcriptionLogger.info("Parakeet transcription took \(String(format: "%.2f", Date().timeIntervalSince(startTx)))s")
    transcriptionLogger.info("Parakeet request total elapsed \(String(format: "%.2f", Date().timeIntervalSince(startAll)))s")
    return text
  }
}
