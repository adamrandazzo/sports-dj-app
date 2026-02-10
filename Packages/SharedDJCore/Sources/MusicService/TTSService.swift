import Foundation
import Core

// MARK: - Error Types

public enum TTSError: LocalizedError {
    case noNetwork
    case invalidURL
    case noCredits
    case unauthorized
    case notFound
    case validationError(String)
    case serviceUnavailable
    case serverError(statusCode: Int)
    case requestFailed(Error)
    case fileWriteError(Error)

    public var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "No internet connection. Please check your network settings."
        case .invalidURL:
            return "Invalid server configuration."
        case .noCredits:
            return "No AI name credits remaining. Upgrade to Pro for more credits."
        case .unauthorized:
            return "Authentication failed. Please try again."
        case .notFound:
            return "Service not available."
        case .validationError(let message):
            return message
        case .serviceUnavailable:
            return "Voice generation service is temporarily unavailable."
        case .serverError(let code):
            return "Server error (code: \(code)). Please try again later."
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .fileWriteError(let error):
            return "Failed to save audio file: \(error.localizedDescription)"
        }
    }
}

// MARK: - Service

/// Service for generating AI voice announcements via the TTS API
@Observable
public final class TTSService {
    public static let shared = TTSService()

    // MARK: - Dependency Callbacks

    /// Optional callback to check if the user has AI name credits (replaces ProStatusManager dependency)
    public static var hasAICreditsCheck: (() -> Bool)?

    /// Optional callback to use an AI name credit (replaces ProStatusManager dependency)
    public static var useAICredit: (() -> Bool)?

    /// Optional callback for analytics when an AI announcement is generated
    public static var analyticsAIGenerated: (() -> Void)?

    // MARK: - Configuration

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

    public private(set) var isGenerating = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Generate a name announcement for a player
    /// - Parameters:
    ///   - text: The text to convert to speech (player name)
    ///   - voiceId: The ElevenLabs voice ID
    ///   - player: The player to save the announcement for
    /// - Returns: URL to the saved audio file
    @discardableResult
    @MainActor
    public func generateNameAnnouncement(
        text: String,
        voiceId: String,
        for player: Player
    ) async throws -> URL {
        guard NetworkMonitor.shared.isConnected else {
            throw TTSError.noNetwork
        }

        guard Self.hasAICreditsCheck?() ?? false else {
            throw TTSError.noCredits
        }

        isGenerating = true
        defer { isGenerating = false }

        // Build request
        let url = try buildURL(path: "/tts")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "text": text,
            "voice_id": voiceId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Perform request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.requestFailed(URLError(.badServerResponse))
        }

        // Handle error responses
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            throw TTSError.unauthorized
        case 404:
            throw TTSError.notFound
        case 422:
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(TTSErrorResponse.self, from: data) {
                throw TTSError.validationError(errorResponse.error)
            }
            throw TTSError.validationError("Validation error")
        case 503:
            throw TTSError.serviceUnavailable
        default:
            throw TTSError.serverError(statusCode: httpResponse.statusCode)
        }

        // Save the audio file
        let fileURL = try saveAudioFile(data: data, filename: player.aiAnnouncementFilename)

        // Use a credit
        _ = Self.useAICredit?()

        // Update player's generation metadata
        player.aiAnnouncementGeneratedText = text
        player.aiAnnouncementVoiceId = voiceId

        Self.analyticsAIGenerated?()

        return fileURL
    }

    /// Check if an AI announcement file exists for a player
    public func hasExistingAnnouncement(for player: Player) -> Bool {
        let fileURL = FileStorageManager.shared.audioDirectory
            .appendingPathComponent("Announcements", isDirectory: true)
            .appendingPathComponent(player.aiAnnouncementFilename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Get the URL for a player's AI announcement file
    public func announcementFileURL(for player: Player) -> URL {
        FileStorageManager.shared.audioDirectory
            .appendingPathComponent("Announcements", isDirectory: true)
            .appendingPathComponent(player.aiAnnouncementFilename)
    }

    /// Delete a player's AI announcement file
    public func deleteAnnouncement(for player: Player) throws {
        let fileURL = announcementFileURL(for: player)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Private Helpers

    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw TTSError.invalidURL
        }
        return url
    }

    private func saveAudioFile(data: Data, filename: String) throws -> URL {
        let announcementsDir = FileStorageManager.shared.audioDirectory
            .appendingPathComponent("Announcements", isDirectory: true)

        // Ensure directory exists
        do {
            try FileManager.default.createDirectory(
                at: announcementsDir,
                withIntermediateDirectories: true
            )
        } catch {
            throw TTSError.fileWriteError(error)
        }

        let fileURL = announcementsDir.appendingPathComponent(filename)

        // Write file
        do {
            try data.write(to: fileURL)
        } catch {
            throw TTSError.fileWriteError(error)
        }

        return fileURL
    }
}

// MARK: - Response Models

private struct TTSErrorResponse: Codable {
    let error: String
}
