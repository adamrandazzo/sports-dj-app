import Foundation
import MusicKit
import SwiftData
import Core

/// Service for managing the user's Apple Music library
@Observable
public final class MusicLibraryService {
    public static let shared = MusicLibraryService()

    private init() {}

    // MARK: - Add to Library

    /// Add a single song to the user's Apple Music library
    public func addToLibrary(appleMusicID: String) async throws {
        // Library IDs start with "i." - these songs are already in the user's library
        guard !appleMusicID.hasPrefix("i.") else {
            return  // Already a library song, nothing to do
        }

        let musicItemID = MusicItemID(rawValue: appleMusicID)

        // Fetch the song from catalog
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: musicItemID)
        let response = try await request.response()

        guard let song = response.items.first else {
            throw MusicLibraryError.songNotFound
        }

        try await MusicLibrary.shared.add(song)
    }

    /// Add multiple songs to the user's Apple Music library
    public func addToLibrary(appleMusicIDs: [String]) async throws -> AddToLibraryResult {
        var addedCount = 0
        var failedCount = 0

        for id in appleMusicIDs {
            do {
                try await addToLibrary(appleMusicID: id)
                addedCount += 1
            } catch {
                print("Failed to add song \(id) to library: \(error)")
                failedCount += 1
            }
        }

        return AddToLibraryResult(addedCount: addedCount, failedCount: failedCount)
    }

    // MARK: - Create Playlist

    /// Create a playlist in the user's Apple Music library with the given songs
    public func createPlaylist(
        name: String,
        description: String?,
        appleMusicIDs: [String]
    ) async throws -> MusicItemID {
        // Fetch all songs - use appropriate request based on ID type
        var songs: [Song] = []

        for id in appleMusicIDs {
            let musicItemID = MusicItemID(rawValue: id)

            do {
                let song: Song?
                if id.hasPrefix("i.") {
                    // Library song ID - fetch from user's library
                    var request = MusicLibraryRequest<Song>()
                    request.filter(matching: \.id, equalTo: musicItemID)
                    let response = try await request.response()
                    song = response.items.first
                } else {
                    // Catalog song ID - fetch from Apple Music catalog
                    let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: musicItemID)
                    let response = try await request.response()
                    song = response.items.first
                }

                if let song {
                    songs.append(song)
                }
            } catch {
                print("Failed to fetch song \(id): \(error)")
            }
        }

        guard !songs.isEmpty else {
            throw MusicLibraryError.noSongsToAdd
        }

        // Create the playlist
        let playlist = try await MusicLibrary.shared.createPlaylist(
            name: name,
            description: description,
            items: songs
        )

        return playlist.id
    }

    // MARK: - Export App Library

    /// Export all Apple Music songs from the app to a new playlist
    public func exportAppLibrary(
        modelContext: ModelContext,
        playlistName: String? = nil
    ) async throws -> ExportResult {
        let resolvedName = playlistName ?? ((DJCoreConfiguration.shared.sportConfig?.appName ?? "DJ") + " Songs")

        // Fetch all Apple Music songs from the app
        let descriptor = FetchDescriptor<SongClip>(
            predicate: #Predicate { $0.sourceTypeRaw == "appleMusic" }
        )
        let clips = try modelContext.fetch(descriptor)

        guard !clips.isEmpty else {
            throw MusicLibraryError.noSongsToExport
        }

        let appleMusicIDs = clips.map { $0.sourceID }

        // Create playlist with timestamp to avoid duplicates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: Date())
        let fullName = "\(resolvedName) - \(dateString)"

        let playlistID = try await createPlaylist(
            name: fullName,
            description: "Exported from \(DJCoreConfiguration.shared.sportConfig?.appName ?? "DJ") app for offline playback",
            appleMusicIDs: appleMusicIDs
        )

        return ExportResult(
            playlistName: fullName,
            playlistID: playlistID,
            totalSongs: clips.count,
            exportedSongs: appleMusicIDs.count
        )
    }
}

// MARK: - Models

public struct AddToLibraryResult {
    public let addedCount: Int
    public let failedCount: Int

    public init(addedCount: Int, failedCount: Int) {
        self.addedCount = addedCount
        self.failedCount = failedCount
    }
}

public struct ExportResult {
    public let playlistName: String
    public let playlistID: MusicItemID
    public let totalSongs: Int
    public let exportedSongs: Int

    public init(playlistName: String, playlistID: MusicItemID, totalSongs: Int, exportedSongs: Int) {
        self.playlistName = playlistName
        self.playlistID = playlistID
        self.totalSongs = totalSongs
        self.exportedSongs = exportedSongs
    }
}

public enum MusicLibraryError: LocalizedError {
    case songNotFound
    case noSongsToAdd
    case noSongsToExport

    public var errorDescription: String? {
        switch self {
        case .songNotFound:
            return "Song not found in Apple Music catalog"
        case .noSongsToAdd:
            return "No songs available to add"
        case .noSongsToExport:
            return "No Apple Music songs in your library to export"
        }
    }
}
