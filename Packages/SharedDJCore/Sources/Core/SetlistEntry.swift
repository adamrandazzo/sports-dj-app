import Foundation
import SwiftData

@Model
public final class SetlistEntry {
    public var id: UUID = UUID()
    public var eventCode: String?
    public var sortOrder: Int = 0

    public var setlist: Setlist?

    @Relationship(inverse: \SongClip.setlistEntries)
    public var song: SongClip?

    public init(
        id: UUID = UUID(),
        setlist: Setlist? = nil,
        song: SongClip? = nil,
        eventCode: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.setlist = setlist
        self.song = song
        self.eventCode = eventCode
        self.sortOrder = sortOrder
    }

    public var hasEventAssignment: Bool {
        eventCode != nil && !(eventCode?.isEmpty ?? true)
    }
}
