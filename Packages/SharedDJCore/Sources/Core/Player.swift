import Foundation
import SwiftData

@Model
public final class Player {
    public var id: UUID = UUID()
    public var name: String = ""
    public var phoneticName: String?
    public var number: String = ""

    public var aiAnnouncementGeneratedText: String?
    public var aiAnnouncementVoiceId: String?

    public var playNumberAnnouncement: Bool = true
    public var playNameAnnouncement: Bool = true
    public var playWalkUpSong: Bool = true

    public var sortOrder: Int = 0
    public var isActive: Bool = true
    public var dateCreated: Date = Date()

    public var team: Team?

    @Relationship(inverse: \SongClip.assignedPlayers)
    public var walkUpSong: SongClip?

    public init(
        id: UUID = UUID(),
        name: String,
        number: String,
        team: Team? = nil,
        phoneticName: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.team = team
        self.phoneticName = phoneticName
        self.sortOrder = sortOrder
        self.dateCreated = Date()
    }

    public var announcementName: String {
        phoneticName ?? name
    }

    /// Full announcement text using the sport's announcement prefix
    public var announcementText: String {
        let prefix = DJCoreConfiguration.shared.sportConfig?.announcementPrefix ?? "Now batting"
        var parts = [prefix]
        parts.append("number \(number)")
        parts.append("\(announcementName)!")
        return parts.joined(separator: ", ")
    }

    public var hasWalkUpSong: Bool {
        walkUpSong != nil
    }

    public var aiAnnouncementFilename: String {
        "player-\(id.uuidString)-name.mp3"
    }

    public func needsAIAnnouncementRegeneration(forVoiceId voiceId: String) -> Bool {
        guard let generatedText = aiAnnouncementGeneratedText,
              let generatedVoiceId = aiAnnouncementVoiceId else {
            return true
        }

        if generatedText != announcementName {
            return true
        }

        if generatedVoiceId != voiceId {
            return true
        }

        return false
    }
}
