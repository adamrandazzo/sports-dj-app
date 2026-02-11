import Foundation
import Core

struct BaseballConfig: SportConfig {
    static let sportName = "Baseball"
    static let appName = "Dugout DJ"
    static let apiBasePath = "dugoutdj"
    static let apiToken = "1|CPCiy2zWlPokgH3keiPtZDjXNyOaNMSgGSgF7sP75701464d"
    static let standardEvents: [(name: String, code: String, icon: String, colorHex: String)] = [
        ("Warm Ups", "warmups", "flame.fill", "#FF6B35"),
        ("National Anthem", "anthem", "flag.fill", "#FF2D55"),
        ("Home Run", "home_run", "figure.baseball", "#FF3B30"),
        ("Strike Out", "strikeout", "k.circle.fill", "#FF9500"),
        ("Inning Start", "inning_start", "play.circle.fill", "#5856D6"),
        ("Between Innings", "between_innings", "clock.fill", "#34C759"),
        ("7th Inning Stretch", "seventh_inning", "figure.stand", "#AF52DE"),
        ("Victory", "victory", "trophy.fill", "#FFD700"),
    ]
    static let productIdentifiers = ["dugout.dj.pro.season.subscription"]
    static let freeTierLimits = TierLimits(maxTeams: 1, maxPlayersPerTeam: 8, maxSongs: 10, aiNameCredits: 0, canCustomizeEvents: false, canUseAllPlaybackModes: false)
    static let proTierLimits = TierLimits(maxTeams: 3, maxPlayersPerTeam: 24, maxSongs: .max, aiNameCredits: 100, canCustomizeEvents: true, canUseAllPlaybackModes: true)
    static let supportsPlayerIntros = true
    static let supportsLifetimePurchase = false  // 1-year subscription only (no lifetime — AI credits too expensive)
    static let announcementPrefix = "Now batting"
    static let playerOrderLabel = "Batting Order"
    static let termsURL = URL(string: "https://ultimatesportsdj.app/privacy")!
    static let privacyURL = URL(string: "https://ultimatesportsdj.app/privacy")!
}
