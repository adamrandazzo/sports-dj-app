import Foundation
import Core

/// Manages file storage with iCloud Documents support
/// Falls back to local Documents directory if iCloud is unavailable
public final class FileStorageManager {
    public static let shared = FileStorageManager()

    private init() {
        // Ensure directories exist
        Task {
            await ensureDirectoriesExist()
        }

        // Set up the SongClip file URL resolver
        SongClip.fileURLResolver = { filename in
            FileStorageManager.shared.audioFileURL(for: filename)
        }
    }

    /// Returns the iCloud Documents URL if available, otherwise local Documents
    public var audioDirectory: URL {
        if let iCloudURL = iCloudDocumentsURL {
            return iCloudURL.appendingPathComponent("Audio", isDirectory: true)
        }
        return localDocumentsURL.appendingPathComponent("Audio", isDirectory: true)
    }

    /// Check if iCloud is available
    public var isICloudAvailable: Bool {
        iCloudDocumentsURL != nil
    }

    /// Local Documents directory
    private var localDocumentsURL: URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // This should never happen on iOS, but handle gracefully
            print("FileStorageManager: Could not access Documents directory")
            return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        }
        return url
    }

    /// iCloud Documents directory (nil if unavailable)
    private var iCloudDocumentsURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    /// Ensure storage directories exist
    private func ensureDirectoriesExist() async {
        let fm = FileManager.default

        // Create local Audio directory
        let localAudio = localDocumentsURL.appendingPathComponent("Audio", isDirectory: true)
        do {
            try fm.createDirectory(at: localAudio, withIntermediateDirectories: true)
        } catch {
            print("FileStorageManager: Failed to create local Audio directory: \(error)")
        }

        // Create iCloud Audio directory if available
        if let iCloudDocs = iCloudDocumentsURL {
            do {
                try fm.createDirectory(at: iCloudDocs, withIntermediateDirectories: true)
                let iCloudAudio = iCloudDocs.appendingPathComponent("Audio", isDirectory: true)
                try fm.createDirectory(at: iCloudAudio, withIntermediateDirectories: true)
            } catch {
                print("FileStorageManager: Failed to create iCloud directories: \(error)")
            }
        }
    }

    /// Copy a file to the storage directory
    /// Returns the filename (UUID.ext) to store in SongClip.sourceID
    public func copyAudioFile(from sourceURL: URL) throws -> String {
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let destinationURL = audioDirectory.appendingPathComponent(filename)

        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: audioDirectory,
            withIntermediateDirectories: true
        )

        // Access security-scoped resource if needed
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        return filename
    }

    /// Get the URL for an audio file by its filename
    public func audioFileURL(for filename: String) -> URL {
        audioDirectory.appendingPathComponent(filename)
    }

    /// Delete an audio file
    public func deleteAudioFile(_ filename: String) throws {
        let url = audioFileURL(for: filename)
        try FileManager.default.removeItem(at: url)
    }

    /// Migrate existing files from local Documents to iCloud
    /// Call this on app launch if iCloud becomes available
    public func migrateToICloud() async {
        guard isICloudAvailable,
              let iCloudDocs = iCloudDocumentsURL else { return }

        let fm = FileManager.default
        let localAudio = localDocumentsURL.appendingPathComponent("Audio", isDirectory: true)
        let iCloudAudio = iCloudDocs.appendingPathComponent("Audio", isDirectory: true)

        // Create iCloud Audio directory
        do {
            try fm.createDirectory(at: iCloudAudio, withIntermediateDirectories: true)
        } catch {
            print("FileStorageManager: Failed to create iCloud Audio directory during migration: \(error)")
            return
        }

        // Also check old location (directly in Documents)
        let oldLocalDocs = localDocumentsURL

        // Get files from both old and new local locations
        var filesToMigrate: [(URL, String)] = []

        // Check new Audio subdirectory
        if let files = try? fm.contentsOfDirectory(at: localAudio, includingPropertiesForKeys: nil) {
            for file in files where isAudioFile(file) {
                filesToMigrate.append((file, file.lastPathComponent))
            }
        }

        // Check old location (files directly in Documents)
        if let files = try? fm.contentsOfDirectory(at: oldLocalDocs, includingPropertiesForKeys: nil) {
            for file in files where isAudioFile(file) {
                filesToMigrate.append((file, file.lastPathComponent))
            }
        }

        // Move files to iCloud
        for (sourceURL, filename) in filesToMigrate {
            let destURL = iCloudAudio.appendingPathComponent(filename)

            // Skip if already exists in iCloud
            guard !fm.fileExists(atPath: destURL.path) else {
                // Delete local copy
                try? fm.removeItem(at: sourceURL)
                continue
            }

            do {
                try fm.setUbiquitous(true, itemAt: sourceURL, destinationURL: destURL)
                print("Migrated \(filename) to iCloud")
            } catch {
                print("Failed to migrate \(filename): \(error)")
            }
        }
    }

    private func isAudioFile(_ url: URL) -> Bool {
        let audioExtensions = ["mp3", "m4a", "aac", "wav", "aiff", "flac", "caf"]
        return audioExtensions.contains(url.pathExtension.lowercased())
    }
}
