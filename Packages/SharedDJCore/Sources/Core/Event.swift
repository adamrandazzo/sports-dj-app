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
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
