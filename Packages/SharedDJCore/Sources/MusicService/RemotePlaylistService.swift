import Foundation
import SwiftData
import UIKit
import Core

// MARK: - Service

@Observable
public final class RemotePlaylistService {
    public static let shared = RemotePlaylistService()

    private var baseURL: String {
        guard let config = DJCoreConfiguration.shared.sportConfig else {
            return "https://api.ultimatesportsdj.app/api/v1/unknown"
        }
        return "https://api.ultimatesportsdj.app/api/v1/\(config.apiBasePath)"
    }

    private var apiToken: String {
        DJCoreConfiguration.shared.sportConfig?.apiToken ?? ""
    }

    private let session: URLSession

    public private(set) var isLoading = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Fetch list of available remote playlists
    public func fetchPlaylists() async throws -> [RemotePlaylistSummary] {
        guard NetworkMonitor.shared.isConnected else {
            throw RemotePlaylistError.noNetwork
        }

        let url = try buildURL(path: "/playlists")
        let data = try await performRequest(url: url)

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let response = try decoder.decode(RemotePlaylistListResponse.self, from: data)
            return response.data
        } catch {
            throw RemotePlaylistError.decodingError(error)
        }
    }

    /// Fetch detailed playlist with all songs
    public func fetchPlaylistDetail(id: Int) async throws -> RemotePlaylistDetail {
        guard NetworkMonitor.shared.isConnected else {
            throw RemotePlaylistError.noNetwork
        }

        let url = try buildURL(path: "/playlists/\(id)")
        let data = try await performRequest(url: url)

        do {
            let response = try JSONDecoder().decode(RemotePlaylistDetailResponse.self, from: data)
            return response.data
        } catch {
            throw RemotePlaylistError.decodingError(error)
        }
    }

    // MARK: - Import

    /// Import a remote playlist into local storage as a Setlist
    public func importPlaylist(
        _ remotePlaylist: RemotePlaylistDetail,
        modelContext: ModelContext,
        progressHandler: @escaping (Int, Int) -> Void
    ) async throws -> Setlist {
        // Check if we already have this setlist
        let remoteID = remotePlaylist.id
        let descriptor = FetchDescriptor<Setlist>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )

        let existingSetlist = try? modelContext.fetch(descriptor).first

        // Create or update setlist
        let setlist: Setlist
        if let existing = existingSetlist {
            setlist = existing
            setlist.name = remotePlaylist.name
            setlist.setlistDescription = remotePlaylist.description
            setlist.lastSyncedAt = Date()
            setlist.updatedAt = Date()

            // Remove existing entries for resync
            if let entries = setlist.entries {
                for entry in entries {
                    modelContext.delete(entry)
                }
            }
        } else {
            setlist = Setlist(
                name: remotePlaylist.name,
                description: remotePlaylist.description,
                remoteID: remotePlaylist.id
            )
            modelContext.insert(setlist)
        }

        // Download playlist artwork
        if let artworkURLString = remotePlaylist.artworkURL,
           let artworkURL = URL(string: artworkURLString) {
            do {
                let (data, _) = try await URLSession.shared.data(from: artworkURL)
                if let image = UIImage(data: data) {
                    setlist.setArtwork(from: image)
                }
            } catch {
                print("Failed to download playlist artwork: \(error)")
            }
        }

        // Import songs
        let total = remotePlaylist.songs.count
        for (index, remoteSong) in remotePlaylist.songs.enumerated() {
            await MainActor.run {
                progressHandler(index + 1, total)
            }

            // Find or create SongClip
            let songClip = try await findOrCreateSongClip(for: remoteSong, modelContext: modelContext)

            // Create setlist entry
            let entry = SetlistEntry(
                setlist: setlist,
                song: songClip,
                eventCode: remoteSong.event?.code,
                sortOrder: index
            )
            modelContext.insert(entry)
        }

        try modelContext.save()
        return setlist
    }

    // MARK: - Private Helpers

    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw RemotePlaylistError.invalidURL
        }
        return url
    }

    private func performRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RemotePlaylistError.requestFailed(URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw RemotePlaylistError.serverError(statusCode: httpResponse.statusCode)
            }

            return data
        } catch let error as RemotePlaylistError {
            throw error
        } catch {
            throw RemotePlaylistError.requestFailed(error)
        }
    }

    private func findOrCreateSongClip(for remoteSong: RemoteSong, modelContext: ModelContext) async throws -> SongClip {
        // Check if we already have this song
        let sourceID = remoteSong.appleTrackID
        let descriptor = FetchDescriptor<SongClip>(
            predicate: #Predicate { $0.sourceID == sourceID }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        // Create new SongClip
        let clip = SongClip(
            title: remoteSong.name,
            artist: remoteSong.artist,
            sourceType: .appleMusic,
            sourceID: remoteSong.appleTrackID,
            startTime: 0,
            endTime: remoteSong.durationSeconds,
            storedDuration: remoteSong.durationSeconds
        )

        // Download artwork
        if let artworkURLString = remoteSong.artworkURL,
           let artworkURL = URL(string: artworkURLString) {
            do {
                let (data, _) = try await URLSession.shared.data(from: artworkURL)
                if let image = UIImage(data: data) {
                    clip.setArtwork(from: image)
                }
            } catch {
                print("Failed to download artwork for \(remoteSong.name): \(error)")
            }
        }

        modelContext.insert(clip)
        return clip
    }
}
