import Foundation
import Observation
import UIKit
import Core

/// Coordinates player intro announcements and song playback
@MainActor
@Observable
public final class PlayerIntroCoordinator {
    private let announcer: AnnouncerService
    private let audioPlayer: AudioPlayerService
    private let session: GameSession

    /// Whether an intro sequence is currently playing
    public private(set) var isPlaying: Bool = false

    /// Current phase of the intro sequence
    public private(set) var currentPhase: IntroPhase = .idle

    /// The player currently being announced/played
    public private(set) var currentPlayer: Player?

    /// Track player count for auto-advancing after playback
    private var currentPlayerCount: Int = 0

    /// Generation counter for atomic stop — incremented on stop() and new playIntro(),
    /// so any in-flight async sequence detects it's been superseded and bails out.
    private var introGeneration: Int = 0

    // MARK: - Analytics Callback

    /// Optional callback for reporting intro played events (replaces direct AnalyticsService dependency)
    public static var analyticsIntroPlayed: ((_ hasSong: Bool, _ hasAnnouncement: Bool) -> Void)?

    public enum IntroPhase: Equatable {
        case idle
        case numberAnnouncement    // "Now batting, number X" / sport-specific announcement
        case nameAnnouncement      // AI-generated player name
        case playingSong           // Walk-up / intro song
    }

    /// Backwards compatibility alias
    public var announcing: Bool {
        currentPhase == .numberAnnouncement || currentPhase == .nameAnnouncement
    }

    /// Whether the announcer is enabled
    public var isAnnouncerEnabled: Bool {
        announcer.isEnabled
    }

    public init(announcer: AnnouncerService, audioPlayer: AudioPlayerService, session: GameSession) {
        self.announcer = announcer
        self.audioPlayer = audioPlayer
        self.session = session
    }

    // MARK: - Intro Playback

    /// Play the intro sequence for a player (number announcement + AI name + song)
    public func playIntro(for player: Player, at index: Int? = nil, totalPlayers: Int? = nil) async {
        // Stop any current playback without advancing (we're starting a new intro)
        stop(advance: false)

        // Claim a new generation — any previously running sequence will see a mismatch and bail out
        introGeneration += 1
        let myGeneration = introGeneration

        isPlaying = true
        currentPlayer = player
        session.currentPlayer = player

        // Store player count for auto-advance
        if let count = totalPlayers {
            currentPlayerCount = count
        }

        // If an index is provided, set it as the current player position
        if let idx = index, let count = totalPlayers {
            session.setNextPlayer(at: idx, playerCount: count)
        }

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        Self.analyticsIntroPlayed?(player.playWalkUpSong && player.walkUpSong != nil, player.playNumberAnnouncement || player.playNameAnnouncement)

        // Phase 1: Number announcement ("Now batting, number X" or sport-specific)
        if player.playNumberAnnouncement, announcer.isEnabled, let team = player.team {
            currentPhase = .numberAnnouncement
            session.isAnnouncementPlaying = true
            await announcer.announce(playerNumber: player.number, announcer: team.announcer)
            guard myGeneration == introGeneration else {
                session.isAnnouncementPlaying = false
                return
            }
        }

        // Phase 2: AI Name announcement (if enabled and generated)
        if player.playNameAnnouncement {
            let nameFileURL = TTSService.shared.announcementFileURL(for: player)
            if FileManager.default.fileExists(atPath: nameFileURL.path) {
                currentPhase = .nameAnnouncement
                session.isAnnouncementPlaying = true
                await announcer.playLocalFile(at: nameFileURL)

                guard myGeneration == introGeneration else {
                    session.isAnnouncementPlaying = false
                    return
                }

                // Brief pause before song
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
                guard myGeneration == introGeneration else {
                    session.isAnnouncementPlaying = false
                    return
                }
            }
        }

        session.isAnnouncementPlaying = false

        // Phase 3: Intro song (if enabled and available)
        if player.playWalkUpSong, let song = player.walkUpSong {
            currentPhase = .playingSong
            audioPlayer.play(song)
        } else {
            // No song or disabled, we're done - advance to next player
            handlePlaybackCompleted()
        }
    }

    /// Preview the full intro sequence for a player (for use in setup/testing)
    public func previewIntro(for player: Player) async {
        // Stop any current playback without advancing (this is a preview)
        stop(advance: false)

        introGeneration += 1
        let myGeneration = introGeneration

        isPlaying = true
        currentPlayer = player

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        // Phase 1: Number announcement
        if player.playNumberAnnouncement, let team = player.team {
            currentPhase = .numberAnnouncement
            await announcer.announce(playerNumber: player.number, announcer: team.announcer)
            guard myGeneration == introGeneration else { return }
        }

        // Phase 2: AI Name announcement
        if player.playNameAnnouncement {
            let nameFileURL = TTSService.shared.announcementFileURL(for: player)
            if FileManager.default.fileExists(atPath: nameFileURL.path) {
                currentPhase = .nameAnnouncement
                await announcer.playLocalFile(at: nameFileURL)
                guard myGeneration == introGeneration else { return }
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard myGeneration == introGeneration else { return }
            }
        }

        // Phase 3: Intro song (play a short clip for preview)
        if player.playWalkUpSong, let song = player.walkUpSong {
            currentPhase = .playingSong
            audioPlayer.play(song)
            // For preview, let the song play - user can stop manually
        } else {
            currentPhase = .idle
            isPlaying = false
            currentPlayer = nil
        }
    }

    /// Play only the announcement for a player (no song)
    public func playNumberAnnouncementOnly(for player: Player) async {
        guard let team = player.team else { return }

        stop(advance: false)

        isPlaying = true
        currentPlayer = player
        currentPhase = .numberAnnouncement
        session.isAnnouncementPlaying = true

        await announcer.announce(playerNumber: player.number, announcer: team.announcer)

        session.isAnnouncementPlaying = false
        currentPhase = .idle
        isPlaying = false
        currentPlayer = nil
    }

    /// Play only the intro song for a player (no announcement)
    public func playSongOnly(for player: Player) {
        guard let song = player.walkUpSong else { return }

        stop(advance: false)

        isPlaying = true
        currentPlayer = player
        currentPhase = .playingSong
        session.currentPlayer = player

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        audioPlayer.play(song)
    }

    /// Stop any current playback and optionally advance to next player.
    /// Increments the generation counter so any in-flight async sequence bails out immediately.
    public func stop(advance: Bool = true) {
        introGeneration += 1
        announcer.stop()

        // Fade out music if a song is playing, otherwise stop immediately
        if currentPhase == .playingSong {
            audioPlayer.fadeOutAndStop()
        } else {
            audioPlayer.stop()
        }

        isPlaying = false
        currentPhase = .idle
        currentPlayer = nil
        session.currentPlayer = nil
        session.isAnnouncementPlaying = false

        // Advance to next player (only on user-initiated stops, not internal transitions)
        if advance && currentPlayerCount > 0 {
            session.advanceToNextPlayer(playerCount: currentPlayerCount)
        }
    }

    // MARK: - Playback Completion

    /// Handle playback completion - advance to next player
    private func handlePlaybackCompleted() {
        currentPhase = .idle
        isPlaying = false
        currentPlayer = nil
        session.currentPlayer = nil

        // Auto-advance to next player
        if currentPlayerCount > 0 {
            session.advanceToNextPlayer(playerCount: currentPlayerCount)
        }
    }
}

// MARK: - Playback State Observation
extension PlayerIntroCoordinator {
    /// Called when AudioPlayerService stops (song finished or stopped)
    public func handlePlaybackStopped() {
        if currentPhase == .playingSong {
            handlePlaybackCompleted()
        }
    }
}
