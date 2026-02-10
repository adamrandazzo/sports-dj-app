import Core

struct HockeyConfig: SportConfig {
    static let sportName = "Hockey"
    static let appName = "Hockey DJ"
    static let apiBasePath = "hockeydj"
    static let apiToken = "1|CPCiy2zWlPokgH3keiPtZDjXNyOaNMSgGSgF7sP75701464d"
    static let standardEvents: [(name: String, code: String, icon: String, colorHex: String)] = [
        ("Warm Up", "warmups", "music.note.list", "#AF52DE"),
        ("Game Start", "game_start", "play.circle.fill", "#00C7BE"),
        ("Goal Home", "goal_home", "flame.fill", "#FF3B30"),
        ("Goal Away", "goal_away", "xmark.circle.fill", "#8E8E93"),
        ("Power Play", "power_play", "bolt.fill", "#34C759"),
        ("Penalty Kill", "penalty_kill", "exclamationmark.triangle.fill", "#FF9500"),
        ("Stoppage", "stoppage", "pause.circle.fill", "#007AFF"),
        ("Intermission", "intermission", "clock.fill", "#5856D6"),
        ("Sound Effects", "sound_effects", "hifispeaker.fill", "#FF2D55"),
        ("Victory", "victory", "trophy.fill", "#FFD700"),
    ]
    static let productIdentifiers = ["pro.season.subscription", "pro.lifetime"]
    static let freeTierLimits = TierLimits(maxTeams: 1, maxPlayersPerTeam: 8, maxSongs: 10, aiNameCredits: 0, canCustomizeEvents: false, canUseAllPlaybackModes: false)
    static let proTierLimits = TierLimits(maxTeams: 3, maxPlayersPerTeam: 24, maxSongs: .max, aiNameCredits: 100, canCustomizeEvents: true, canUseAllPlaybackModes: true)
    static let supportsPlayerIntros = false
    static let supportsLifetimePurchase = true  // 6-month subscription + lifetime
    static let announcementPrefix = "Now on the ice"
    static let playerOrderLabel = "Starting Lineup"
}
