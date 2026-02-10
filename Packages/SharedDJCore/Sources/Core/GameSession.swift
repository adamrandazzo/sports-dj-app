import Foundation
import Observation
import SwiftUI

/// A record of a song that was played during the session
public struct PlayedSongEntry: Identifiable {
    public let id = UUID()
    public let clip: SongClip
    public let eventName: String
    public let eventIcon: String
    public let eventColor: Color
    public let playedAt: Date

    public init(clip: SongClip, eventName: String, eventIcon: String, eventColor: Color, playedAt: Date) {
        self.clip = clip
        self.eventName = eventName
        self.eventIcon = eventIcon
        self.eventColor = eventColor
        self.playedAt = playedAt
    }
}

/// Runtime state for an active game session (not persisted)
@MainActor
@Observable
public final class GameSession {
    /// Songs that have been played this session (per-event tracking)
    private var playedSongIDs: [UUID: Set<UUID>] = [:]

    /// Next song index for sequential playback (per-event tracking)
    private var nextSongIndex: [UUID: Int] = [:]

    /// History of all songs played this session (in order)
    public var songHistory: [PlayedSongEntry] = []

    /// Currently paused clip state
    public var pausedClip: SongClip?
    public var pausedPosition: TimeInterval = 0
    public var pausedEventID: UUID?
    public var pausedEventName: String?

    /// Whether a game is actively in progress
    public var isActive: Bool = false

    /// When the current game session started (for duration tracking)
    public var startedAt: Date?

    /// Currently playing clip (if any)
    public var currentlyPlayingClip: SongClip?
    public var currentlyPlayingEvent: Event?
    public var currentlyPlayingEventID: UUID?
    public var currentlyPlayingEventName: String?

    // MARK: - Player Intro Tracking

    /// The currently selected team for this session
    public var activeTeam: Team?

    /// Index of the next player in the lineup
    public var nextPlayerIndex: Int = 0

    /// The player currently being introduced (during playback)
    public var currentPlayer: Player?

    /// Whether an announcement is currently playing
    public var isAnnouncementPlaying: Bool = false

    /// Callback to check if user is pro (injected to avoid cross-module dependency)
    public var isProCheck: (() -> Bool)?

    public init() {}

    // MARK: - Session Management

    public func newGame() {
        playedSongIDs.removeAll()
        nextSongIndex.removeAll()
        songHistory.removeAll()
        pausedClip = nil
        pausedPosition = 0
        pausedEventID = nil
        pausedEventName = nil
        currentlyPlayingClip = nil
        currentlyPlayingEvent = nil
        currentlyPlayingEventID = nil
        currentlyPlayingEventName = nil
        nextPlayerIndex = 0
        currentPlayer = nil
        isAnnouncementPlaying = false
        isActive = true
        startedAt = Date()
    }

    public func endGame() {
        isActive = false
        startedAt = nil
        currentlyPlayingClip = nil
        currentlyPlayingEvent = nil
        currentlyPlayingEventID = nil
        currentlyPlayingEventName = nil
        currentPlayer = nil
    }

    // MARK: - Next Player Management

    public func getNextPlayer(from players: [Player]) -> Player? {
        guard !players.isEmpty else { return nil }
        let safeIndex = nextPlayerIndex % players.count
        return players[safeIndex]
    }

    public func advanceToNextPlayer(playerCount: Int) {
        guard playerCount > 0 else { return }
        nextPlayerIndex = (nextPlayerIndex + 1) % playerCount
    }

    public func setNextPlayer(at index: Int, playerCount: Int) {
        guard playerCount > 0, index >= 0, index < playerCount else { return }
        nextPlayerIndex = index
    }

    public func isNextPlayer(at index: Int, playerCount: Int) -> Bool {
        guard playerCount > 0 else { return false }
        return (nextPlayerIndex % playerCount) == index
    }

    // MARK: - Song Selection

    public func getNextSong(for event: Event, from pool: [SongClip]) -> SongClip? {
        guard !pool.isEmpty else { return nil }

        let isPro = isProCheck?() ?? false
        let effectiveMode = isPro ? event.playbackMode : .random

        switch effectiveMode {
        case .random:
            return getNextRandomSong(for: event, from: pool)
        case .sequential:
            return getNextSequentialSong(for: event, from: pool)
        case .manual:
            return nil
        }
    }

    private func getNextRandomSong(for event: Event, from pool: [SongClip]) -> SongClip? {
        let eventID = event.id
        let played = playedSongIDs[eventID] ?? []

        let available = pool.filter { !played.contains($0.id) }

        if available.isEmpty {
            playedSongIDs[eventID] = []
            return pool.randomElement()
        }

        return available.randomElement()
    }

    private func getNextSequentialSong(for event: Event, from pool: [SongClip]) -> SongClip? {
        let eventID = event.id
        let currentIndex = nextSongIndex[eventID] ?? 0

        let song = pool[currentIndex % pool.count]

        nextSongIndex[eventID] = (currentIndex + 1) % pool.count

        return song
    }

    public func hasBeenPlayed(_ clip: SongClip, for event: Event) -> Bool {
        playedSongIDs[event.id]?.contains(clip.id) ?? false
    }

    public func markPlayed(_ clip: SongClip, for event: Event) {
        var played = playedSongIDs[event.id] ?? []
        played.insert(clip.id)
        playedSongIDs[event.id] = played

        let entry = PlayedSongEntry(
            clip: clip,
            eventName: event.name,
            eventIcon: event.icon,
            eventColor: event.color,
            playedAt: Date()
        )
        songHistory.append(entry)
    }

    // MARK: - Pause/Resume

    public func pauseCurrentSong(at position: TimeInterval) {
        guard let clip = currentlyPlayingClip,
              let eventID = currentlyPlayingEventID else { return }

        pausedClip = clip
        pausedPosition = position
        pausedEventID = eventID
        pausedEventName = currentlyPlayingEventName
        currentlyPlayingClip = nil
        currentlyPlayingEvent = nil
        currentlyPlayingEventID = nil
        currentlyPlayingEventName = nil
    }

    public var hasPausedSong: Bool {
        pausedClip != nil
    }

    public func clearPausedState() {
        pausedClip = nil
        pausedPosition = 0
        pausedEventID = nil
        pausedEventName = nil
    }

    public func setPlaying(_ clip: SongClip, for event: Event) {
        currentlyPlayingClip = clip
        currentlyPlayingEvent = event
        currentlyPlayingEventID = event.id
        currentlyPlayingEventName = event.name
    }

    public func stopPlaying() {
        currentlyPlayingClip = nil
        currentlyPlayingEvent = nil
        currentlyPlayingEventID = nil
        currentlyPlayingEventName = nil
    }

    // MARK: - Stats

    public func playedCount(for event: Event) -> Int {
        playedSongIDs[event.id]?.count ?? 0
    }

    public var totalSongsPlayed: Int {
        playedSongIDs.values.reduce(0) { $0 + $1.count }
    }
}
