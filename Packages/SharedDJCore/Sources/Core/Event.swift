import Foundation
import SwiftData
import SwiftUI

// MARK: - Playback Mode
public enum PlaybackMode: String, Codable, CaseIterable {
    case random = "random"
    case sequential = "sequential"
    case manual = "manual"

    public var displayName: String {
        switch self {
        case .random: return "Shuffle"
        case .sequential: return "In Order"
        case .manual: return "Pick"
        }
    }

    public var icon: String {
        switch self {
        case .random: return "shuffle"
        case .sequential: return "list.number"
        case .manual: return "hand.tap"
        }
    }

    public var description: String {
        switch self {
        case .random: return "Play songs randomly until all are played"
        case .sequential: return "Play songs in order from top to bottom"
        case .manual: return "Choose which song to play each time"
        }
    }
}

@Model
public final class Event {
    public var id: UUID = UUID()
    public var name: String = ""
    public var code: String = ""
    public var icon: String = "star.fill"
    public var colorHex: String = "#007AFF"
    public var isStandard: Bool = false
    public var sortOrder: Int = 0
    public var playbackModeRaw: String = PlaybackMode.random.rawValue
    public var continuousPlayback: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \EventPool.event)
    public var pool: EventPool?

    public var playbackMode: PlaybackMode {
        get { PlaybackMode(rawValue: playbackModeRaw) ?? .random }
        set { playbackModeRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        code: String = "",
        icon: String,
        colorHex: String,
        isStandard: Bool = false,
        sortOrder: Int = 0,
        playbackMode: PlaybackMode = .random
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.icon = icon
        self.colorHex = colorHex
        self.isStandard = isStandard
        self.sortOrder = sortOrder
        self.playbackModeRaw = playbackMode.rawValue
    }

    public var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

// MARK: - Standard Events
extension Event {
    public static func createStandardEvents(from events: [(name: String, code: String, icon: String, colorHex: String)]) -> [Event] {
        events.enumerated().map { index, event in
            Event(
                name: event.name,
                code: event.code,
                icon: event.icon,
                colorHex: event.colorHex,
                isStandard: true,
                sortOrder: index
            )
        }
    }
}

// MARK: - Deduplication
extension Event {
    /// Merges duplicate standard events that share the same `code`.
    /// Keeps the event whose pool has the most songs (ties broken by earliest sortOrder),
    /// moves songs from duplicates into the keeper's pool, then deletes the duplicates.
    @MainActor
    public static func deduplicateStandardEvents(in context: ModelContext) {
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate { $0.isStandard == true }
        )

        guard let standardEvents = try? context.fetch(descriptor),
              standardEvents.count > 1 else { return }

        // Group by code, skipping events with no code
        var groupedByCode: [String: [Event]] = [:]
        for event in standardEvents {
            guard !event.code.isEmpty else { continue }
            groupedByCode[event.code, default: []].append(event)
        }

        var didDelete = false

        for (_, events) in groupedByCode {
            guard events.count > 1 else { continue }

            // Pick keeper: most songs in pool, then earliest sortOrder
            let sorted = events.sorted { a, b in
                let aSongs = a.pool?.songsArray.count ?? 0
                let bSongs = b.pool?.songsArray.count ?? 0
                if aSongs != bSongs { return aSongs > bSongs }
                return a.sortOrder < b.sortOrder
            }

            let keeper = sorted[0]
            let duplicates = sorted.dropFirst()

            for duplicate in duplicates {
                // Move songs from duplicate's pool into keeper's pool
                for song in duplicate.pool?.songsArray ?? [] {
                    keeper.pool?.addSong(song)
                }
                context.delete(duplicate)
                didDelete = true
            }
        }

        if didDelete {
            try? context.save()
            print("Deduplicated standard events")
        }
    }
}

// MARK: - Color Extension
extension Color {
    public init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    public func toHex() -> String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
