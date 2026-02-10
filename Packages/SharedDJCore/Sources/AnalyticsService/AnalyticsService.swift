import FirebaseAnalytics
import FirebaseCrashlytics
import Core

/// Centralized analytics event tracking via Firebase Analytics
/// Sport-specific events should be added via extensions in app targets
public enum AnalyticsService {

    // MARK: - Playback

    public static func playbackAction(_ action: String, songSource: String) {
        Analytics.logEvent("playback_action", parameters: [
            "action": action,
            "song_source": songSource,
        ])
    }

    public static func playbackError(message: String, songSource: String, sourceID: String? = nil, underlyingError: Error? = nil, subscriptionInfo: String? = nil) {
        Analytics.logEvent("playback_error", parameters: [
            "error_message": message,
            "song_source": songSource,
        ])

        let sportName = DJCoreConfiguration.shared.sportConfig?.sportName.lowercased() ?? "unknown"
        let userInfo: [String: Any] = [
            "message": message,
            "song_source": songSource,
            "source_id": sourceID ?? "unknown",
            "underlying_error": underlyingError?.localizedDescription ?? "none",
            "subscription": subscriptionInfo ?? "not_checked",
        ]
        let error = NSError(domain: "com.\(sportName)DJ.playback", code: 1, userInfo: userInfo)
        Crashlytics.crashlytics().record(error: error)
    }

    // MARK: - Library Management

    public static func songImported(source: String, count: Int = 1) {
        Analytics.logEvent("song_imported", parameters: [
            "source": source,
            "count": count,
        ])
    }

    public static func songDeleted(count: Int) {
        Analytics.logEvent("song_deleted", parameters: [
            "count": count,
        ])
    }

    public static func poolEdited(action: String, eventName: String, count: Int) {
        Analytics.logEvent("pool_edited", parameters: [
            "action": action,
            AnalyticsParameterItemName: eventName,
            "count": count,
        ])
    }

    public static func playbackModeChanged(eventName: String, newMode: String) {
        Analytics.logEvent("playback_mode_changed", parameters: [
            AnalyticsParameterItemName: eventName,
            "new_mode": newMode,
        ])
    }

    // MARK: - Upgrade Funnel

    public static func upgradePromptShown(feature: String) {
        Analytics.logEvent("upgrade_prompt_shown", parameters: [
            "feature": feature,
        ])
    }

    public static func upgradePromptTapped(feature: String) {
        Analytics.logEvent("upgrade_prompt_tapped", parameters: [
            "feature": feature,
        ])
    }

    public static func purchase(itemID: String) {
        Analytics.logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterItemID: itemID,
        ])
    }

    public static func freeTierLimitHit(feature: String) {
        Analytics.logEvent("free_tier_limit_hit", parameters: [
            "feature": feature,
        ])
    }

    // MARK: - Setlists

    public static func setlistSaved() {
        Analytics.logEvent("setlist_saved", parameters: nil)
    }

    public static func setlistLoaded(mode: String) {
        Analytics.logEvent("setlist_loaded", parameters: [
            "mode": mode,
        ])
    }

    public static func remoteSetlistImported() {
        Analytics.logEvent("remote_setlist_imported", parameters: nil)
    }

    // MARK: - AI Announcements

    public static func aiAnnouncementGenerated() {
        Analytics.logEvent("ai_announcement_generated", parameters: nil)
    }

    // MARK: - Player Intros

    public static func playerIntroPlayed(hasSong: Bool, hasAnnouncement: Bool) {
        Analytics.logEvent("player_intro_played", parameters: [
            "has_song": hasSong,
            "has_announcement": hasAnnouncement,
        ])
    }

    // MARK: - Game Session

    public static func gameStarted() {
        Analytics.logEvent("game_started", parameters: nil)
    }

    public static func gameEnded(durationSeconds: Int, songsPlayed: Int) {
        Analytics.logEvent("game_ended", parameters: [
            "duration_seconds": durationSeconds,
            "songs_played": songsPlayed,
        ])
    }

    public static func eventTriggered(
        eventName: String,
        eventCode: String,
        playbackMode: String,
        songSource: String,
        poolSize: Int
    ) {
        Analytics.logEvent("event_triggered", parameters: [
            AnalyticsParameterItemName: eventName,
            "event_code": eventCode,
            "playback_mode": playbackMode,
            "song_source": songSource,
            "pool_size": poolSize,
        ])
    }

    // MARK: - Settings

    public static func settingChanged(setting: String, value: String) {
        Analytics.logEvent("setting_changed", parameters: [
            "setting": setting,
            "value": value,
        ])
    }

    public static func appleMusicAuth(status: String) {
        Analytics.logEvent("apple_music_auth", parameters: [
            "status": status,
        ])
    }

    public static func exportToAppleMusic(result: String, songCount: Int) {
        Analytics.logEvent("export_to_apple_music", parameters: [
            "result": result,
            "song_count": songCount,
        ])
    }

    public static func dataReset(type: String) {
        Analytics.logEvent("data_reset", parameters: [
            "type": type,
        ])
    }

    public static func clipEdited() {
        Analytics.logEvent("clip_edited", parameters: nil)
    }

    // MARK: - App Lifecycle

    public static func appOpened() {
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)
    }

    // MARK: - User Properties

    public static func setIsPro(_ isPro: Bool) {
        Analytics.setUserProperty(isPro ? "true" : "false", forName: "is_pro")
    }

    public static func setSongCount(_ count: Int) {
        Analytics.setUserProperty("\(count)", forName: "song_count")
    }

    // MARK: - Custom Event (for sport-specific extensions in app targets)

    public static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
}
