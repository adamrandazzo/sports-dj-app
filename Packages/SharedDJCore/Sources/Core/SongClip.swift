import Foundation
import SwiftData
import AVFoundation
import UIKit

public enum SourceType: String, Codable {
    case appleMusic
    case localFile
}

@Model
public final class SongClip {
    public var id: UUID = UUID()
    public var title: String = ""
    public var artist: String = ""
    public var sourceTypeRaw: String = SourceType.localFile.rawValue
    public var sourceID: String = ""
    public var startTime: Double = 0
    public var endTime: Double = 30
    public var artworkData: Data?
    public var storedDuration: Double?
    public var fadeInDuration: Double?
    public var fadeOutDuration: Double?
    public var dateAdded: Date = Date()

    // Inverse relationships for CloudKit
    @Relationship(deleteRule: .nullify) public var pools: [EventPool]?
    @Relationship(deleteRule: .cascade) public var setlistEntries: [SetlistEntry]?
    @Relationship(deleteRule: .nullify) public var assignedPlayers: [Player]?

    public var sourceType: SourceType {
        get { SourceType(rawValue: sourceTypeRaw) ?? .localFile }
        set { sourceTypeRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        sourceType: SourceType,
        sourceID: String,
        startTime: Double = 0,
        endTime: Double = 30,
        artworkData: Data? = nil,
        storedDuration: Double? = nil,
        fadeInDuration: Double? = nil,
        fadeOutDuration: Double? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.startTime = startTime
        self.endTime = endTime
        self.artworkData = artworkData
        self.storedDuration = storedDuration
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
        self.dateAdded = dateAdded
    }

    public var clipDuration: Double {
        endTime - startTime
    }

    /// Resolver for local file URLs. Set by MusicService at startup.
    public static var fileURLResolver: ((String) -> URL?)?

    public var localFileURL: URL? {
        guard sourceType == .localFile else { return nil }
        return Self.fileURLResolver?(sourceID)
    }
}

// MARK: - Artwork Helpers
extension SongClip {
    public func setArtwork(from image: UIImage?) {
        artworkData = image?.jpegData(compressionQuality: 0.8)
    }

    public var artworkImage: UIImage? {
        guard let data = artworkData else { return nil }
        return UIImage(data: data)
    }

    public static func extractArtwork(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)

        do {
            let metadata = try await asset.load(.commonMetadata)
            for item in metadata {
                if item.commonKey == .commonKeyArtwork {
                    if let data = try await item.load(.dataValue) {
                        return UIImage(data: data)
                    }
                }
            }
        } catch {
            print("Failed to extract artwork: \(error)")
        }

        return nil
    }

    public static func extractTitle(from url: URL) async -> String? {
        let asset = AVURLAsset(url: url)

        do {
            let metadata = try await asset.load(.commonMetadata)
            for item in metadata {
                if item.commonKey == .commonKeyTitle {
                    return try await item.load(.stringValue)
                }
            }
        } catch {
            print("Failed to extract title: \(error)")
        }

        return nil
    }

    public static func extractArtist(from url: URL) async -> String? {
        let asset = AVURLAsset(url: url)

        do {
            let metadata = try await asset.load(.commonMetadata)
            for item in metadata {
                if item.commonKey == .commonKeyArtist {
                    return try await item.load(.stringValue)
                }
            }
        } catch {
            print("Failed to extract artist: \(error)")
        }

        return nil
    }

    public static func getDuration(from url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)

        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            guard seconds.isFinite && seconds > 0 else {
                return nil
            }
            return seconds
        } catch {
            print("Failed to get duration: \(error)")
            return nil
        }
    }
}
