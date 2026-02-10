import Foundation
import Core
import StoreService

/// Features gated behind Pro subscription
public enum ProFeature: String, CaseIterable, Identifiable {
    case unlimitedSongs
    case customEvents
    case playbackModes
    case setlists
    case moreTeams
    case morePlayers
    case aiNames

    public var id: String { rawValue }

    /// Features visible for the current sport configuration
    public static var visibleFeatures: [ProFeature] {
        let supportsIntros = DJCoreConfiguration.shared.sportConfig?.supportsPlayerIntros ?? false
        return allCases.filter { feature in
            switch feature {
            case .aiNames, .moreTeams, .morePlayers: return supportsIntros
            default: return true
            }
        }
    }

    private static var proLimits: TierLimits {
        DJCoreConfiguration.shared.sportConfig?.proTierLimits ?? TierLimits(maxTeams: 3, maxPlayersPerTeam: 24, maxSongs: .max, aiNameCredits: 100)
    }

    private static var freeLimits: TierLimits {
        DJCoreConfiguration.shared.sportConfig?.freeTierLimits ?? TierLimits(maxTeams: 1, maxPlayersPerTeam: 8, maxSongs: 10, aiNameCredits: 0)
    }

    public var title: String {
        switch self {
        case .unlimitedSongs: return "Unlimited Songs"
        case .customEvents: return "Custom Events"
        case .playbackModes: return "All Playback Modes"
        case .setlists: return "Setlists"
        case .moreTeams: return "Up to \(Self.proLimits.maxTeams) Teams"
        case .morePlayers: return "Up to \(Self.proLimits.maxPlayersPerTeam) Players"
        case .aiNames: return "AI Name Announcements"
        }
    }

    public var description: String {
        switch self {
        case .unlimitedSongs:
            return "Import as many songs as you want. Free users are limited to \(ProStatusManager.shared.freeSongLimit) songs."
        case .customEvents:
            return "Create your own custom events beyond the standard set."
        case .playbackModes:
            return "Use Sequential and Manual playback modes. Free users can only use Shuffle."
        case .setlists:
            return "Save and load custom setlists for different games with access to curated playlists."
        case .moreTeams:
            return "Create up to \(Self.proLimits.maxTeams) teams. Free users are limited to \(Self.freeLimits.maxTeams) team."
        case .morePlayers:
            return "Add up to \(Self.proLimits.maxPlayersPerTeam) players per team. Free users are limited to \(Self.freeLimits.maxPlayersPerTeam)."
        case .aiNames:
            return "Generate AI voice announcements for player names. Includes \(Self.proLimits.aiNameCredits) credits to get you started!"
        }
    }

    public var icon: String {
        switch self {
        case .unlimitedSongs: return "music.note.list"
        case .customEvents: return "plus.circle"
        case .playbackModes: return "list.number"
        case .setlists: return "list.bullet"
        case .moreTeams: return "person.3"
        case .morePlayers: return "person.badge.plus"
        case .aiNames: return "waveform"
        }
    }
}
