import Foundation

public protocol SportConfig {
    static var sportName: String { get }
    static var appName: String { get }
    static var apiBasePath: String { get }
    static var apiToken: String { get }
    static var standardEvents: [(name: String, code: String, icon: String, colorHex: String)] { get }
    static var productIdentifiers: [String] { get }
    static var freeTierLimits: TierLimits { get }
    static var proTierLimits: TierLimits { get }
    static var supportsPlayerIntros: Bool { get }
    static var supportsLifetimePurchase: Bool { get }
    static var announcementPrefix: String { get }
    static var playerOrderLabel: String { get }
}

// TODO: IAP Differentiation
// ─────────────────────────
// Hockey DJ:  6-month subscription + lifetime purchase.
//             Pro gates: unlimited songs, setlists, event editing/customization.
// Baseball DJ: 1-year subscription ONLY (no lifetime — AI credits are too expensive to offer one-time).
//             Pro gates: unlimited songs, players, teams, event customization, AI name credits.
// Basketball DJ: TBD
//
// Free tier across all apps should restrict:
//   - Number of songs (e.g. 10)
//   - Event customization (free = standard events only, no editing)
//   - Playback modes (free = shuffle only)
// Pro tier unlocks:
//   - Unlimited songs
//   - Custom events / event editing
//   - All playback modes
//   - Setlists
//   - Teams/players (where applicable)

public struct TierLimits: Sendable {
    public let maxTeams: Int
    public let maxPlayersPerTeam: Int
    public let maxSongs: Int
    public let aiNameCredits: Int
    public let canCustomizeEvents: Bool
    public let canUseAllPlaybackModes: Bool

    public init(
        maxTeams: Int,
        maxPlayersPerTeam: Int,
        maxSongs: Int,
        aiNameCredits: Int,
        canCustomizeEvents: Bool = true,
        canUseAllPlaybackModes: Bool = true
    ) {
        self.maxTeams = maxTeams
        self.maxPlayersPerTeam = maxPlayersPerTeam
        self.maxSongs = maxSongs
        self.aiNameCredits = aiNameCredits
        self.canCustomizeEvents = canCustomizeEvents
        self.canUseAllPlaybackModes = canUseAllPlaybackModes
    }
}
