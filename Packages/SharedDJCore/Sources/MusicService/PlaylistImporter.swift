import Foundation
import SwiftData
import MusicKit
import UIKit
import Core

/// Configuration for bulk playlist import
public struct PlaylistImportConfig {
    public let tracks: [PlaylistTrack]
    public let targetEvent: Event?
    public let skipExisting: Bool
    public let addToAppleMusicLibrary: Bool

    public init(
        tracks: [PlaylistTrack],
        targetEvent: Event?,
        skipExisting: Bool,
        addToAppleMusicLibrary: Bool
    ) {
        self.tracks = tracks
        self.targetEvent = targetEvent
        self.skipExisting = skipExisting
        self.addToAppleMusicLibrary = addToAppleMusicLibrary
    }
}

/// Result of a playlist import operation
public struct PlaylistImportResult {
    public let totalTracks: Int
    public let importedCount: Int
    public let skippedExisting: Int
    public let skippedUnavailable: Int
    public let failedCount: Int
    public let createdClips: [SongClip]

    public init(
        totalTracks: Int,
        importedCount: Int,
        skippedExisting: Int,
        skippedUnavailable: Int,
        failedCount: Int,
        createdClips: [SongClip]
    ) {
        self.totalTracks = totalTracks
        self.importedCount = importedCount
        self.skippedExisting = skippedExisting
        self.skippedUnavailable = skippedUnavailable
        self.failedCount = failedCount
        self.createdClips = createdClips
    }
}

/// Service for importing tracks from Apple Music playlists
public final class PlaylistImporter {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Import selected tracks from a playlist
    public func importTracks(
        config: PlaylistImportConfig,
        progressHandler: @escaping (Int, Int) -> Void
    ) async throws -> PlaylistImportResult {
        var importedCount = 0
        var skippedExisting = 0
        var skippedUnavailable = 0
        var failedCount = 0
        var createdClips: [SongClip] = []

        let total = config.tracks.count

        for (index, track) in config.tracks.enumerated() {
            await MainActor.run {
                progressHandler(index + 1, total)
            }

            // Check if track is playable
            guard track.isPlayable else {
                skippedUnavailable += 1
                continue
            }

            // Check for existing clip with same Apple Music ID
            if config.skipExisting {
                let existingClip = try fetchExistingClip(appleMusicID: track.id.rawValue)
                if existingClip != nil {
                    skippedExisting += 1
                    continue
                }
            }

            // Create SongClip
            do {
                let clip = try await createClip(from: track, config: config)
                createdClips.append(clip)
                importedCount += 1

                // Add to event pool if specified
                if let event = config.targetEvent,
                   let pool = event.pool {
                    pool.addSong(clip)
                }
            } catch {
                print("Failed to create clip for \(track.title): \(error)")
                failedCount += 1
            }
        }

        try modelContext.save()

        return PlaylistImportResult(
            totalTracks: total,
            importedCount: importedCount,
            skippedExisting: skippedExisting,
            skippedUnavailable: skippedUnavailable,
            failedCount: failedCount,
            createdClips: createdClips
        )
    }

    private func fetchExistingClip(appleMusicID: String) throws -> SongClip? {
        let descriptor = FetchDescriptor<SongClip>(
            predicate: #Predicate { $0.sourceID == appleMusicID }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func createClip(
        from track: PlaylistTrack,
        config: PlaylistImportConfig
    ) async throws -> SongClip {
        let clip = SongClip(
            title: track.title,
            artist: track.artist,
            sourceType: .appleMusic,
            sourceID: track.id.rawValue,
            startTime: 0,
            endTime: track.duration,
            storedDuration: track.duration
        )

        // Download artwork
        if let artwork = track.artwork,
           let url = artwork.url(width: 300, height: 300) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    clip.setArtwork(from: image)
                }
            } catch {
                print("Failed to download artwork for \(track.title): \(error)")
                // Continue without artwork - not a fatal error
            }
        }

        // Add to Apple Music library if enabled
        if config.addToAppleMusicLibrary {
            try? await MusicLibraryService.shared.addToLibrary(appleMusicID: track.id.rawValue)
        }

        modelContext.insert(clip)
        return clip
    }
}
