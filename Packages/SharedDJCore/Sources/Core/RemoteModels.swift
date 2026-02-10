import Foundation

// MARK: - API Response Models

public struct RemotePlaylistListResponse: Codable {
    public let data: [RemotePlaylistSummary]

    public init(data: [RemotePlaylistSummary]) {
        self.data = data
    }
}

public struct RemotePlaylistSummary: Codable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let description: String
    public let songCount: Int?
    public let artworkURL: String?
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case songCount = "song_count"
        case artworkURL = "artwork_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(id: Int, name: String, description: String, songCount: Int?, artworkURL: String?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.description = description
        self.songCount = songCount
        self.artworkURL = artworkURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct RemotePlaylistDetailResponse: Codable {
    public let data: RemotePlaylistDetail

    public init(data: RemotePlaylistDetail) {
        self.data = data
    }
}

public struct RemotePlaylistDetail: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let description: String
    public let artworkURL: String?
    public let songs: [RemoteSong]

    enum CodingKeys: String, CodingKey {
        case id, name, description, songs
        case artworkURL = "artwork_url"
    }

    public init(id: Int, name: String, description: String, artworkURL: String?, songs: [RemoteSong]) {
        self.id = id
        self.name = name
        self.description = description
        self.artworkURL = artworkURL
        self.songs = songs
    }
}

public struct RemoteSong: Codable, Identifiable {
    public let appleTrackID: String
    public let name: String
    public let artist: String
    public let album: String?
    public let artworkURL: String?
    public let durationMs: Int
    public let event: RemoteEventInfo?

    public var id: String { appleTrackID }

    public var durationSeconds: Double {
        Double(durationMs) / 1000.0
    }

    enum CodingKeys: String, CodingKey {
        case appleTrackID = "apple_track_id"
        case name, artist, album
        case artworkURL = "artwork_url"
        case durationMs = "duration_ms"
        case event
    }

    public init(appleTrackID: String, name: String, artist: String, album: String?, artworkURL: String?, durationMs: Int, event: RemoteEventInfo?) {
        self.appleTrackID = appleTrackID
        self.name = name
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.durationMs = durationMs
        self.event = event
    }
}

public struct RemoteEventInfo: Codable {
    public let code: String
    public let name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

// MARK: - Error Types

public enum RemotePlaylistError: LocalizedError {
    case noNetwork
    case invalidURL
    case serverError(statusCode: Int)
    case decodingError(Error)
    case requestFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "No internet connection. Please check your network settings."
        case .invalidURL:
            return "Invalid server configuration."
        case .serverError(let code):
            return "Server error (code: \(code)). Please try again later."
        case .decodingError:
            return "Failed to process server response."
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        }
    }
}
