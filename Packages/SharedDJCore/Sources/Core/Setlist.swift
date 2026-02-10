import Foundation
import SwiftData
import UIKit

@Model
public final class Setlist {
    public var id: UUID = UUID()
    public var name: String = ""
    public var setlistDescription: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var remoteID: Int?
    public var lastSyncedAt: Date?

    @Attribute(.externalStorage) public var artworkData: Data?

    @Relationship(deleteRule: .cascade, inverse: \SetlistEntry.setlist)
    public var entries: [SetlistEntry]?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        remoteID: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.setlistDescription = description
        self.createdAt = Date()
        self.updatedAt = Date()
        self.remoteID = remoteID
        if remoteID != nil {
            self.lastSyncedAt = Date()
        }
    }

    public var isRemote: Bool {
        remoteID != nil
    }

    public var orderedEntries: [SetlistEntry] {
        (entries ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    public var songCount: Int {
        entries?.count ?? 0
    }

    public var assignedSongCount: Int {
        entries?.filter { $0.eventCode != nil }.count ?? 0
    }

    public func setArtwork(from image: UIImage) {
        artworkData = image.jpegData(compressionQuality: 0.8)
    }
}
