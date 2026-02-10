import AnalyticsService

/// Baseball-specific analytics events
extension AnalyticsService {
    static func teamCreated() {
        logEvent("team_created")
    }

    static func playerAdded() {
        logEvent("player_added")
    }

    static func songAssignedToPlayer() {
        logEvent("song_assigned_to_player")
    }

    static func battingOrderChanged() {
        logEvent("batting_order_changed")
    }

    static func djEventTriggered(eventName: String, playbackMode: String) {
        logEvent("dj_event_triggered", parameters: [
            "event_name": eventName,
            "playback_mode": playbackMode,
        ])
    }
}
