import SwiftUI
import SwiftData
import Core
import MusicService
import StoreService
import AnalyticsService
import CommonUI

/// Music tab - Event grid for playing game sounds
struct MusicView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GameSession.self) private var gameSession

    @Query(sort: \Event.sortOrder) private var events: [Event]

    @CloudStorage("eventButtonSize") private var eventButtonSizeRaw = EventButtonSize.medium.rawValue

    /// State for manual song picker (use Event directly for .sheet(item:) pattern)
    @State private var pendingManualEvent: Event?
    @State private var eventToEdit: Event?
    @State private var showOfflineAlert = false
    @State private var showNoSongsAlert = false
    @State private var noSongsEvent: Event?

    private let networkMonitor = NetworkMonitor.shared

    private var buttonSize: EventButtonSize {
        EventButtonSize(rawValue: eventButtonSizeRaw) ?? .medium
    }

    /// Grid layout - adapts based on button size setting
    private var columns: [GridItem] {
        return [
            GridItem(.adaptive(minimum: buttonSize.minColumnWidth), spacing: 12)
        ]
    }

    private var showOverlay: Bool {
        gameSession.currentlyPlayingClip != nil || gameSession.hasPausedSong
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Offline indicator banner
                    if !networkMonitor.isConnected {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi.slash")
                            Text("Offline - Local files only")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                    }

                    // Event buttons grid
                    ScrollView(.vertical) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(events) { event in
                                EventButton(event: event, size: buttonSize) {
                                    handleEventTap(event)
                                } onLongPress: {
                                    eventToEdit = event
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 20)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(maxHeight: .infinity)
                }

                // Music player overlay
                if showOverlay {
                    MusicPlayerOverlay()
                }
            }
            .navigationTitle("DJ Mode")
            .sheet(item: $pendingManualEvent) { event in
                if let pool = event.pool {
                    SongPickerSheet(
                        event: event,
                        songs: pool.orderedSongs,
                        playedSongIDs: getPlayedSongIDs(for: event),
                        onSelect: { song in
                            playSelectedSong(song, for: event)
                        }
                    )
                }
            }
            .sheet(item: $eventToEdit) { event in
                NavigationStack {
                    EventPoolView(event: event)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    eventToEdit = nil
                                }
                            }
                        }
                }
            }
            .alert("Offline", isPresented: $showOfflineAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Apple Music songs require an internet connection. Only local files can be played while offline.")
            }
            .alert("No Songs", isPresented: $showNoSongsAlert) {
                Button("Add Songs") {
                    if let event = noSongsEvent {
                        eventToEdit = event
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("No songs have been assigned to this event.")
            }
            .musicAccessAlert()
        }
    }

    /// Get the set of played song IDs for an event
    private func getPlayedSongIDs(for event: Event) -> Set<UUID> {
        guard let pool = event.pool else { return [] }
        return Set(pool.orderedSongs.filter { gameSession.hasBeenPlayed($0, for: event) }.map(\.id))
    }

    private func handleEventTap(_ event: Event) {
        if !gameSession.isActive {
            // Auto-start game on first tap
            gameSession.newGame()
        }

        // If something is currently playing, stop it
        if gameSession.currentlyPlayingClip != nil {
            AudioPlayerService.shared.stop()
            gameSession.stopPlaying()
        }

        // Get the pool and songs for this event
        let songs = event.pool?.orderedSongs ?? []

        guard !songs.isEmpty else {
            noSongsEvent = event
            showNoSongsAlert = true
            return
        }

        // Check if manual mode - show picker instead
        if event.playbackMode == .manual {
            pendingManualEvent = event
            return
        }

        // Get next song (random or sequential)
        guard let nextSong = gameSession.getNextSong(for: event, from: songs) else {
            return
        }

        // Check if offline and trying to play Apple Music
        if !networkMonitor.isConnected && nextSong.sourceType == .appleMusic {
            showOfflineAlert = true
            return
        }

        // Play the song
        AudioPlayerService.shared.playForEvent(nextSong, event: event, session: gameSession)

        AnalyticsService.djEventTriggered(eventName: event.name, playbackMode: event.playbackMode.rawValue)

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    /// Play a manually selected song
    private func playSelectedSong(_ song: SongClip, for event: Event) {
        // Check if offline and trying to play Apple Music
        if !networkMonitor.isConnected && song.sourceType == .appleMusic {
            showOfflineAlert = true
            return
        }

        AudioPlayerService.shared.playForEvent(song, event: event, session: gameSession)

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - Music Player Overlay

struct MusicPlayerOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(GameSession.self) private var gameSession

    private let audioPlayer = AudioPlayerService.shared

    private var isPlaying: Bool {
        gameSession.currentlyPlayingClip != nil
    }

    private var isPaused: Bool {
        gameSession.hasPausedSong && gameSession.currentlyPlayingClip == nil
    }

    private var currentClip: SongClip? {
        gameSession.currentlyPlayingClip ?? gameSession.pausedClip
    }

    private var eventName: String? {
        gameSession.currentlyPlayingEventName ?? gameSession.pausedEventName
    }

    /// Format time as M:SS
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Progress through the clip (0 to 1)
    private var progress: Double {
        guard let clip = currentClip else { return 0 }
        let duration = clip.endTime - clip.startTime
        guard duration > 0 else { return 0 }
        let elapsed = audioPlayer.currentTime - clip.startTime
        return min(max(elapsed / duration, 0), 1)
    }

    /// Time remaining in the clip
    private var timeRemaining: TimeInterval {
        guard let clip = currentClip else { return 0 }
        return max(clip.endTime - audioPlayer.currentTime, 0)
    }

    var body: some View {
        ZStack {
            // Dimmed background - white in light mode, black in dark mode
            (colorScheme == .dark ? Color.black : Color.white)
                .opacity(0.95)
                .ignoresSafeArea()

            // Overlay content
            VStack(spacing: 24) {
                Spacer()

                // Event name
                if let eventName = eventName {
                    Text(eventName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary.opacity(0.9))
                }

                // Large artwork
                if let clip = currentClip {
                    CachedArtworkView(song: clip, size: 200, cornerRadius: 16)
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                        .opacity(isPaused ? 0.7 : 1.0)
                }

                // Song info
                if let clip = currentClip {
                    VStack(spacing: 4) {
                        Text(clip.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(clip.artist)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // Progress and timer
                VStack(spacing: 8) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.primary.opacity(0.3))
                                .frame(height: 4)

                            // Progress fill
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.primary)
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 40)

                    // Time remaining or error
                    if let error = audioPlayer.lastError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    } else if isPaused {
                        Text("Paused")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("-\(formatTime(timeRemaining))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                // Large playback controls
                HStack(spacing: 60) {
                    // Play/Pause button
                    Button {
                        if isPlaying {
                            AudioPlayerService.shared.pauseToSession(gameSession)
                        } else if isPaused {
                            AudioPlayerService.shared.resumeFromSession(gameSession)
                        }
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.primary)
                    }

                    // Stop button
                    Button {
                        if isPlaying {
                            AudioPlayerService.shared.stopAndUpdateSession(gameSession)
                        } else if isPaused {
                            gameSession.clearPausedState()
                        }
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.primary.opacity(0.8))
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Song Picker Sheet

struct SongPickerSheet: View {
    let event: Event
    let songs: [SongClip]
    let playedSongIDs: Set<UUID>
    let onSelect: (SongClip) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(songs) { song in
                    SongPickerRow(
                        song: song,
                        hasBeenPlayed: playedSongIDs.contains(song.id),
                        onTap: {
                            onSelect(song)
                            dismiss()
                        }
                    )
                }
            }
            .navigationTitle("Pick a Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Row for displaying a song in the picker
private struct SongPickerRow: View {
    let song: SongClip
    let hasBeenPlayed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Artwork (async loaded with caching)
                CachedArtworkView(song: song)

                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.body)
                        .foregroundStyle(hasBeenPlayed ? .secondary : .primary)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Played indicator
                if hasBeenPlayed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MusicView()
        .modelContainer(for: [Event.self, EventPool.self, SongClip.self], inMemory: true)
        .environment(AudioPlayerService.shared)
        .environment(GameSession())
}
