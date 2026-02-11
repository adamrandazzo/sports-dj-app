import Foundation
import AVFoundation
import Observation
import UIKit
import MusicKit
import Core

/// Unified audio player service for both local files and Apple Music
@Observable
public final class AudioPlayerService {
    public static let shared = AudioPlayerService()

    // MARK: - Analytics Callbacks

    /// Optional callback for reporting playback errors (replaces direct AnalyticsService dependency)
    public static var analyticsPlaybackError: ((_ message: String, _ songSource: String, _ sourceID: String?, _ underlyingError: Error?, _ subscriptionInfo: String?) -> Void)?

    /// Optional callback for reporting playback actions (replaces direct AnalyticsService dependency)
    public static var analyticsPlaybackAction: ((_ action: String, _ songSource: String) -> Void)?

    // MARK: - Music Access

    public enum MusicAccessIssue: Equatable {
        case authorizationNeeded
        case authorizationDenied
        case subscriptionRequired
    }

    /// Set when playback fails due to Apple Music auth or subscription issues
    public var musicAccessIssue: MusicAccessIssue?

    // MARK: - State
    public var isPlaying = false
    public var currentTime: TimeInterval = 0
    public var currentClip: SongClip?
    public var lastError: String?

    // MARK: - Private
    private var audioPlayer: AVAudioPlayer?
    private var musicPlayer = ApplicationMusicPlayer.shared
    private var playbackTimer: Timer?
    private var clipEndTime: TimeInterval = 0
    private var clipStartTime: TimeInterval = 0
    private var isPlayingAppleMusic = false
    private var fadeInDuration: TimeInterval = 0
    private var fadeOutDuration: TimeInterval = 0
    private weak var activeSession: GameSession?

    private init() {
        configureAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use playback category with default mode for full takeover
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Playback Control

    /// Play a song clip from the beginning
    public func play(_ clip: SongClip) {
        stop(clearSession: false)
        lastError = nil

        currentClip = clip
        clipStartTime = clip.startTime
        clipEndTime = clip.endTime
        fadeInDuration = clip.fadeInDuration ?? 0
        fadeOutDuration = clip.fadeOutDuration ?? 0

        switch clip.sourceType {
        case .localFile:
            playLocalFile(clip)
        case .appleMusic:
            playAppleMusic(clip)
        }
    }

    private func playLocalFile(_ clip: SongClip) {
        guard let url = clip.localFileURL else {
            lastError = "Could not find audio file"
            Self.analyticsPlaybackError?("Could not find audio file", "localFile", nil, nil, nil)
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.currentTime = clip.startTime
            // Start at volume 0 if fade in is enabled
            audioPlayer?.volume = fadeInDuration > 0 ? 0 : 1
            audioPlayer?.play()
            isPlaying = true
            isPlayingAppleMusic = false

            startPlaybackTimer()
        } catch {
            lastError = "Failed to play audio file"
            Self.analyticsPlaybackError?("Failed to play audio file", "localFile", nil, nil, nil)
        }
    }

    private func playAppleMusic(_ clip: SongClip) {
        guard !clip.sourceID.isEmpty else {
            lastError = "Invalid Apple Music track"
            return
        }

        // Check authorization status first
        let authStatus = MusicAuthorization.currentStatus
        guard authStatus == .authorized else {
            switch authStatus {
            case .denied, .restricted:
                lastError = "Apple Music access denied"
                musicAccessIssue = .authorizationDenied
            case .notDetermined:
                lastError = "Apple Music access required"
                musicAccessIssue = .authorizationNeeded
            default:
                lastError = "Apple Music access required"
                musicAccessIssue = .authorizationNeeded
            }
            return
        }

        let sourceID = clip.sourceID
        let startTime = clip.startTime

        Task {
            // Check subscription status before attempting playback
            do {
                let subscription = try await MusicSubscription.current
                if !subscription.canPlayCatalogContent {
                    await MainActor.run {
                        lastError = "Apple Music subscription required"
                        musicAccessIssue = .subscriptionRequired
                    }
                    return
                }
            } catch {
                // If we can't check subscription, continue and let playback fail with a specific error
                print("AudioPlayerService: Could not check subscription status: \(error)")
            }

            do {
                // Step 1: Fetch the song metadata
                // Catalog IDs are purely numeric; anything else is a library ID
                let isCatalogID = sourceID.allSatisfy { $0.isWholeNumber }
                let song: Song?

                if isCatalogID {
                    // Catalog song ID - fetch from Apple Music catalog
                    let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(sourceID))
                    let response = try await request.response()
                    song = response.items.first
                } else {
                    // Library song ID (i.xxx, l.xxx, etc.) - fetch from user's library
                    var request = MusicLibraryRequest<Song>()
                    request.filter(matching: \.id, equalTo: MusicItemID(sourceID))
                    let response = try await request.response()
                    song = response.items.first
                }

                guard let song else {
                    await MainActor.run {
                        lastError = "Song not found in Apple Music. It may have been removed from the catalog."
                    }
                    return
                }

                // Step 2: Try to play the song
                musicPlayer.queue = [song]
                try await musicPlayer.prepareToPlay()
                try await musicPlayer.play()

                // Seek to start time if needed
                if startTime > 0 {
                    musicPlayer.playbackTime = startTime
                }

                await MainActor.run {
                    isPlaying = true
                    isPlayingAppleMusic = true
                    startPlaybackTimer()
                }
            } catch {
                // Capture subscription details for diagnostics
                let subInfo: String
                if let sub = try? await MusicSubscription.current {
                    subInfo = "canPlay=\(sub.canPlayCatalogContent), canBecome=\(sub.canBecomeSubscriber), cloudLibrary=\(sub.hasCloudLibraryEnabled)"
                } else {
                    subInfo = "unknown"
                }

                // Check network status only after failure
                await MainActor.run {
                    let message = Self.describePlaybackError(error)
                    lastError = message
                    Self.analyticsPlaybackError?(message, "appleMusic", sourceID, error, subInfo)
                }
            }
        }
    }

    /// Convert playback errors to user-friendly messages
    @MainActor
    private static func describePlaybackError(_ error: Error) -> String {
        let nsError = error as NSError
        print("AudioPlayerService: Playback error - domain: \(nsError.domain), code: \(nsError.code), description: \(error.localizedDescription), userInfo: \(nsError.userInfo)")

        // Check network status at error time
        let isOffline = !NetworkMonitor.shared.isConnected

        // If offline, that's likely the cause
        if isOffline {
            return "No internet connection. Only local files and downloaded Apple Music can be played offline."
        }

        // Check for specific MusicKit error codes (only when online)
        if nsError.domain == "MPMusicPlayerControllerErrorDomain" || nsError.domain == "MusicKit.MusicDataRequest.Error" {
            switch nsError.code {
            case 1:
                return "This song couldn't be played. It may not be available in your region or may have been removed from Apple Music. Try removing and re-adding the song."
            case 6:
                return "Apple Music subscription required to play this song."
            default:
                break
            }
        }

        // Check error description for common issues
        let description = error.localizedDescription.lowercased()
        if description.contains("subscription") || description.contains("not subscribed") {
            return "Apple Music subscription required to play this song."
        }
        if description.contains("network") || description.contains("connection") || description.contains("offline") {
            return "Network error. Check your internet connection."
        }
        if description.contains("not found") || description.contains("unavailable") {
            return "Song not available. It may have been removed from Apple Music."
        }
        if description.contains("authorization") || description.contains("permission") {
            return "Apple Music access denied. Please enable access in Settings."
        }

        // Fallback with the actual error for debugging
        return "Failed to play: \(error.localizedDescription)"
    }

    /// Resume a paused clip from a specific position
    public func resume(_ clip: SongClip, from position: TimeInterval) {
        stop(clearSession: false)
        lastError = nil

        currentClip = clip
        clipStartTime = clip.startTime
        clipEndTime = clip.endTime
        fadeInDuration = clip.fadeInDuration ?? 0
        fadeOutDuration = clip.fadeOutDuration ?? 0

        switch clip.sourceType {
        case .localFile:
            guard let url = clip.localFileURL else {
                lastError = "Could not find audio file"
                return
            }

            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.currentTime = position
                // Set volume based on current position in fade regions
                audioPlayer?.volume = calculateVolume(at: position)
                audioPlayer?.play()
                isPlaying = true
                isPlayingAppleMusic = false

                startPlaybackTimer()
            } catch {
                lastError = "Failed to resume audio file"
            }

        case .appleMusic:
            guard !clip.sourceID.isEmpty else {
                lastError = "Invalid Apple Music track"
                return
            }

            // Check authorization status first
            let authStatus = MusicAuthorization.currentStatus
            guard authStatus == .authorized else {
                switch authStatus {
                case .denied, .restricted:
                    lastError = "Apple Music access denied. Please enable access in Settings."
                case .notDetermined:
                    lastError = "Apple Music access required. Please grant access in the app settings."
                default:
                    lastError = "Apple Music access required"
                }
                return
            }

            let sourceID = clip.sourceID

            Task {
                do {
                    // Step 1: Fetch the song metadata
                    // Catalog IDs are purely numeric; anything else is a library ID
                    let isCatalogID = sourceID.allSatisfy { $0.isWholeNumber }
                    let song: Song?
                    if isCatalogID {
                        // Catalog song ID - fetch from Apple Music catalog
                        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(sourceID))
                        let response = try await request.response()
                        song = response.items.first
                    } else {
                        // Library song ID (i.xxx, l.xxx, etc.) - fetch from user's library
                        var request = MusicLibraryRequest<Song>()
                        request.filter(matching: \.id, equalTo: MusicItemID(sourceID))
                        let response = try await request.response()
                        song = response.items.first
                    }

                    guard let song else {
                        await MainActor.run {
                            lastError = "Song not found in Apple Music. It may have been removed from the catalog."
                        }
                        return
                    }

                    // Step 2: Try to play the song
                    musicPlayer.queue = [song]
                    try await musicPlayer.prepareToPlay()
                    musicPlayer.playbackTime = position
                    try await musicPlayer.play()

                    await MainActor.run {
                        isPlaying = true
                        isPlayingAppleMusic = true
                        startPlaybackTimer()
                    }
                } catch {
                    // Check network status only after failure
                    await MainActor.run {
                        let message = Self.describePlaybackError(error)
                        lastError = message
                        Self.analyticsPlaybackError?(message, "appleMusic", sourceID, error, nil)
                    }
                }
            }
        }
    }

    /// Pause playback
    public func pause() {
        if isPlayingAppleMusic {
            musicPlayer.pause()
        } else {
            audioPlayer?.pause()
        }
        isPlaying = false
        stopPlaybackTimer()
    }

    /// Stop playback completely
    /// - Parameter clearSession: Whether to clear the active session reference (default true)
    public func stop(clearSession: Bool = true) {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        if isPlayingAppleMusic {
            musicPlayer.stop()
        } else {
            audioPlayer?.stop()
            audioPlayer = nil
        }
        isPlaying = false
        isPlayingAppleMusic = false
        currentTime = 0
        currentClip = nil
        stopPlaybackTimer()

        // Clear session state when clip ends (unless we're about to start a new clip)
        if clearSession {
            Task { @MainActor in
                activeSession?.stopPlaying()
            }
            activeSession = nil
        }
    }

    /// Fade out over a short duration then stop
    private var fadeOutTimer: Timer?
    private static let fadeOutStopDuration: TimeInterval = 0.4

    public func fadeOutAndStop(clearSession: Bool = true) {
        guard isPlaying else { return }

        if !isPlayingAppleMusic, let player = audioPlayer {
            // AVAudioPlayer has built-in fade support
            player.setVolume(0, fadeDuration: Self.fadeOutStopDuration)
            stopPlaybackTimer()
            isPlaying = false

            // Stop fully after the fade completes
            fadeOutTimer?.invalidate()
            fadeOutTimer = Timer.scheduledTimer(withTimeInterval: Self.fadeOutStopDuration, repeats: false) { [weak self] _ in
                self?.stop(clearSession: clearSession)
            }
        } else {
            // Apple Music doesn't expose volume control — stop immediately
            stop(clearSession: clearSession)
        }
    }

    /// Get current playback position
    public func getCurrentPosition() -> TimeInterval {
        if isPlayingAppleMusic {
            return musicPlayer.playbackTime
        }
        return audioPlayer?.currentTime ?? 0
    }

    // MARK: - Private Helpers

    private func startPlaybackTimer() {
        stopPlaybackTimer()

        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let currentPlaybackTime: TimeInterval
            if self.isPlayingAppleMusic {
                currentPlaybackTime = self.musicPlayer.playbackTime
            } else if let player = self.audioPlayer {
                currentPlaybackTime = player.currentTime
            } else {
                return
            }

            self.currentTime = currentPlaybackTime

            // Apply fade in/out for local files
            if !self.isPlayingAppleMusic, let player = self.audioPlayer {
                let volume = self.calculateVolume(at: currentPlaybackTime)
                player.volume = volume
            }

            // Check if we've reached the clip end time
            if currentPlaybackTime >= self.clipEndTime {
                self.handleClipEnd()
            }
        }
    }

    private func calculateVolume(at currentTime: TimeInterval) -> Float {
        let timeIntoClip = currentTime - clipStartTime
        let timeUntilEnd = clipEndTime - currentTime

        var volume: Float = 1.0

        // Fade in
        if fadeInDuration > 0 && timeIntoClip < fadeInDuration {
            volume = Float(timeIntoClip / fadeInDuration)
        }

        // Fade out
        if fadeOutDuration > 0 && timeUntilEnd < fadeOutDuration {
            let fadeOutVolume = Float(timeUntilEnd / fadeOutDuration)
            volume = min(volume, fadeOutVolume)
        }

        return max(0, min(1, volume))
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    /// Handle clip end - either auto-advance or stop based on event settings
    private func handleClipEnd() {
        // Capture session reference before async work
        guard let session = activeSession else {
            stop()
            return
        }

        // Access @MainActor GameSession properties on main thread
        Task { @MainActor in
            guard let event = session.currentlyPlayingEvent,
                  event.continuousPlayback,
                  event.playbackMode != .manual,
                  let pool = event.pool?.orderedSongs,
                  !pool.isEmpty else {
                // No continuous playback or manual mode - just stop
                self.stop()
                return
            }

            // Get the next song based on playback mode
            guard let nextSong = session.getNextSong(for: event, from: pool) else {
                self.stop()
                return
            }

            // Auto-advance to next song
            self.playForEvent(nextSong, event: event, session: session)
        }
    }
}

// MARK: - Session Integration Extension
extension AudioPlayerService {
    /// Play a song for an event, integrating with game session
    @MainActor
    public func playForEvent(_ clip: SongClip, event: Event, session: GameSession) {
        // Store session reference BEFORE play() for continuous playback support
        activeSession = session

        // Mark as played in session
        session.markPlayed(clip, for: event)
        session.setPlaying(clip, for: event)

        // Play the clip
        play(clip)

        Self.analyticsPlaybackAction?("play", clip.sourceType.rawValue)

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    /// Pause and save state to session
    @MainActor
    public func pauseToSession(_ session: GameSession) {
        guard let clip = currentClip else { return }

        Self.analyticsPlaybackAction?("pause", clip.sourceType.rawValue)

        let position = getCurrentPosition()
        session.pauseCurrentSong(at: position)
        pause()
    }

    /// Resume from session's paused state
    @MainActor
    public func resumeFromSession(_ session: GameSession) {
        guard let clip = session.pausedClip else { return }

        Self.analyticsPlaybackAction?("resume", clip.sourceType.rawValue)

        let eventID = session.pausedEventID
        let eventName = session.pausedEventName

        // Store session reference BEFORE resume() for continuous playback support
        activeSession = session

        // Resume playback
        resume(clip, from: session.pausedPosition)

        // Restore session playing state before clearing paused state
        session.currentlyPlayingClip = clip
        session.currentlyPlayingEventID = eventID
        session.currentlyPlayingEventName = eventName
        session.clearPausedState()
    }

    /// Stop and update session (with fade out)
    @MainActor
    public func stopAndUpdateSession(_ session: GameSession) {
        if let clip = currentClip {
            Self.analyticsPlaybackAction?("stop", clip.sourceType.rawValue)
        }
        fadeOutAndStop()
        session.stopPlaying()
    }
}
