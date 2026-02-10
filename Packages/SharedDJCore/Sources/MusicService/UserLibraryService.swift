import Foundation
import MusicKit
import Core

/// Service for accessing user's Apple Music library playlists
@Observable
public final class UserLibraryService {
    public static let shared = UserLibraryService()

    public private(set) var isLoading = false

    private init() {}

    // MARK: - Authorization

    /// Check if library access is available
    public var isAuthorized: Bool {
        MusicAuthorization.currentStatus == .authorized
    }

    // MARK: - Fetching Playlists

    /// Load all user playlists (owned + followed)
    public func fetchPlaylists() async throws -> [UserPlaylist] {
        let request = MusicLibraryRequest<MusicKit.Playlist>()

        let response = try await request.response()
        return response.items.map { playlist in
            UserPlaylist(
                id: playlist.id,
                name: playlist.name,
                description: playlist.standardDescription,
                artwork: playlist.artwork,
                trackCount: 0,  // Track count loaded when fetching details
                lastModified: playlist.lastModifiedDate,
                curatorName: playlist.curatorName
            )
        }
    }

    /// Load tracks for a specific playlist
    public func fetchPlaylistTracks(for playlistID: MusicItemID) async throws -> [PlaylistTrack] {
        var request = MusicLibraryRequest<MusicKit.Playlist>()
        request.filter(matching: \.id, equalTo: playlistID)

        let response = try await request.response()
        guard let playlist = response.items.first else {
            return []
        }

        // Fetch the playlist with tracks
        // Some playlists (e.g., followed Curator playlists) may fail to load entries
        // if they only have local device IDs without valid cloud identifiers
        let detailedPlaylist: MusicKit.Playlist
        do {
            detailedPlaylist = try await playlist.with(.entries)
        } catch {
            print("Failed to fetch entries for playlist '\(playlist.name)': \(error)")
            return []
        }

        guard let entries = detailedPlaylist.entries else {
            return []
        }

        return entries.compactMap { (entry: MusicKit.Playlist.Entry) -> PlaylistTrack? in
            guard let item = entry.item else { return nil }

            switch item {
            case .song(let song):
                // Prefer catalog ID for reliable playback; fall back to library ID
                let resolvedID = Self.catalogID(from: song.playParameters).map { MusicItemID($0) } ?? song.id
                return PlaylistTrack(
                    id: resolvedID,
                    title: song.title,
                    artist: song.artistName,
                    albumName: song.albumTitle,
                    artwork: song.artwork,
                    duration: song.duration ?? 180,
                    isExplicit: song.contentRating == .explicit,
                    isPlayable: song.playParameters != nil
                )
            default:
                return nil  // Skip non-song items (music videos, etc.)
            }
        }
    }

    // MARK: - Recently Played

    /// Fetch recently played songs from library
    public func fetchRecentlyPlayed(limit: Int = 25) async throws -> [PlaylistTrack] {
        var request = MusicRecentlyPlayedRequest<Song>()
        request.limit = limit

        let response = try await request.response()
        return response.items.map { song in
            let resolvedID = Self.catalogID(from: song.playParameters).map { MusicItemID($0) } ?? song.id
            return PlaylistTrack(
                id: resolvedID,
                title: song.title,
                artist: song.artistName,
                albumName: song.albumTitle,
                artwork: song.artwork,
                duration: song.duration ?? 180,
                isExplicit: song.contentRating == .explicit,
                isPlayable: song.playParameters != nil
            )
        }
    }

    // MARK: - Helpers

    /// Extract the catalog ID from play parameters so we store a playable catalog ID
    /// rather than a library-only ID that may fail during playback.
    private static func catalogID(from playParameters: PlayParameters?) -> String? {
        guard let playParameters,
              let data = try? JSONEncoder().encode(playParameters),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let catalogId = dict["catalogId"] as? String else {
            return nil
        }
        return catalogId
    }
}

// MARK: - Models

/// Represents a user's Apple Music playlist
public struct UserPlaylist: Identifiable, Hashable {
    public let id: MusicItemID
    public let name: String
    public let description: String?
    public let artwork: Artwork?
    public let trackCount: Int
    public let lastModified: Date?
    public let curatorName: String?

    // Populated when loading details
    public var tracks: [PlaylistTrack]?

    public init(
        id: MusicItemID,
        name: String,
        description: String?,
        artwork: Artwork?,
        trackCount: Int,
        lastModified: Date?,
        curatorName: String?,
        tracks: [PlaylistTrack]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.artwork = artwork
        self.trackCount = trackCount
        self.lastModified = lastModified
        self.curatorName = curatorName
        self.tracks = tracks
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: UserPlaylist, rhs: UserPlaylist) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents a track within a playlist
public struct PlaylistTrack: Identifiable, Hashable {
    public let id: MusicItemID
    public let title: String
    public let artist: String
    public let albumName: String?
    public let artwork: Artwork?
    public let duration: TimeInterval
    public let isExplicit: Bool
    public let isPlayable: Bool  // May be false if removed from catalog

    public init(
        id: MusicItemID,
        title: String,
        artist: String,
        albumName: String?,
        artwork: Artwork?,
        duration: TimeInterval,
        isExplicit: Bool,
        isPlayable: Bool
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumName = albumName
        self.artwork = artwork
        self.duration = duration
        self.isExplicit = isExplicit
        self.isPlayable = isPlayable
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: PlaylistTrack, rhs: PlaylistTrack) -> Bool {
        lhs.id == rhs.id
    }
}
