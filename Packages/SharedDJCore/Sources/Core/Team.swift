import Foundation
import SwiftData

@Model
public final class Team {
    public var id: UUID = UUID()
    public var name: String = ""
    public var sortOrder: Int = 0
    public var dateCreated: Date = Date()
    public var announcerCode: String = Announcer.bigBill.rawValue

    @Relationship(deleteRule: .cascade, inverse: \Player.team)
    public var players: [Player]?

    public init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        announcer: Announcer = .bigBill
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.dateCreated = Date()
        self.announcerCode = announcer.rawValue
    }

    public var playersArray: [Player] {
        get { players ?? [] }
        set { players = newValue }
    }

    /// Get players sorted by sortOrder (player order)
    public var orderedPlayers: [Player] {
        playersArray.sorted { $0.sortOrder < $1.sortOrder }
    }

    public var activePlayers: [Player] {
        playersArray
            .filter { $0.isActive }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    public var inactivePlayers: [Player] {
        playersArray
            .filter { !$0.isActive }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    public var playerCount: Int {
        playersArray.count
    }

    public var activePlayerCount: Int {
        playersArray.filter { $0.isActive }.count
    }

    public var announcer: Announcer {
        get { Announcer(code: announcerCode) }
        set { announcerCode = newValue.rawValue }
    }
}
