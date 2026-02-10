import SwiftUI
import SwiftData
import Core
import MusicService
import StoreService
import AnalyticsService
import CommonUI

struct DJView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GameSession.self) private var gameSession
    @Environment(\.selectedTab) private var selectedTab

    @Query(sort: \Event.sortOrder) private var events: [Event]

    @CloudStorage("eventButtonSize") private var eventButtonSizeRaw = EventButtonSize.medium.rawValue
    @CloudStorage("hasSeenQuickStart") private var hasSeenQuickStart = false
    @CloudStorage("lastPlaylistCheckTimestamp") private var lastPlaylistCheckTimestamp: Double = 0

    private let proStatus = ProStatusManager.shared

    /// State for manual song picker (use Event directly for .sheet(item:) pattern)
    @State private var pendingManualEvent: Event?
    @State private var eventToEdit: Event?
    @State private var showNoSongsAlert = false
    @State private var noSongsEvent: Event?

    /// State for updated playlists overlay
    @State private var updatedPlaylists: [RemotePlaylistSummary] = []
    @State private var showUpdatedPlaylistsOverlay = false
    @State private var selectedUpdatedPlaylist: RemotePlaylistSummary?
    @State private var showPlaylistBrowser = false

    private var networkMonitor = NetworkMonitor.shared

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
                            Text("Offline - Local files and downloaded Apple Music only")
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

                // Quick start overlay for first launch
                if !hasSeenQuickStart {
                    QuickStartOverlay(hasSeenQuickStart: $hasSeenQuickStart, pages: Self.quickStartPages)
                }

                // Updated playlists overlay (show after quick start has been seen)
                if showUpdatedPlaylistsOverlay && hasSeenQuickStart {
                    UpdatedPlaylistsOverlay(
                        playlists: updatedPlaylists,
                        isPro: proStatus.isPro,
                        onDismiss: {
                            lastPlaylistCheckTimestamp = Date().timeIntervalSince1970
                            showUpdatedPlaylistsOverlay = false
                        },
                        onViewPlaylist: { playlist in
                            selectedUpdatedPlaylist = playlist
                            lastPlaylistCheckTimestamp = Date().timeIntervalSince1970
                            showUpdatedPlaylistsOverlay = false
                            showPlaylistBrowser = true
                        },
                        onGoPro: {
                            lastPlaylistCheckTimestamp = Date().timeIntervalSince1970
                            showUpdatedPlaylistsOverlay = false
                            selectedTab?.wrappedValue = ContentView.Tab.pro.rawValue
                        }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ULTIMATE HOCKEY DJ")
                        .font(.custom("BebasNeue-Regular", size: 20))
                        .tracking(1)
                }
            }
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
            .sheet(isPresented: $showPlaylistBrowser) {
                RemotePlaylistBrowserView(
                    preselectedPlaylist: selectedUpdatedPlaylist,
                    onSetlistImported: nil
                )
            }
            .task {
                await checkForUpdatedPlaylists()
            }
            .musicAccessAlert()
        }
    }

    /// Check for playlists updated since last check
    private func checkForUpdatedPlaylists() async {
        guard hasSeenQuickStart else { return }

        do {
            let playlists = try await RemotePlaylistService.shared.fetchPlaylists()
            let lastCheck = Date(timeIntervalSince1970: lastPlaylistCheckTimestamp)

            // Filter to playlists updated after last check
            let updated = playlists.filter { $0.updatedAt > lastCheck }

            if !updated.isEmpty {
                await MainActor.run {
                    updatedPlaylists = updated
                    showUpdatedPlaylistsOverlay = true
                }
            }
        } catch {
            // Silently fail - this is an optional enhancement feature
            print("Failed to check for updated playlists: \(error)")
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
            AnalyticsService.gameStarted()
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

        // Play the song (Apple Music will error if not downloaded when offline)
        AudioPlayerService.shared.playForEvent(nextSong, event: event, session: gameSession)

        AnalyticsService.eventTriggered(
            eventName: event.name,
            eventCode: event.code,
            playbackMode: event.playbackMode.rawValue,
            songSource: nextSong.sourceType.rawValue,
            poolSize: songs.count
        )

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    // MARK: - Quick Start Pages (Hockey-specific)

    private static let quickStartPages: [QuickStartPageData] = [
        QuickStartPageData(icon: "music.mic", iconColor: .blue, title: "Welcome to Hockey DJ", description: "Your personal DJ for game day. Trigger songs for goals, penalties, and more with a single tap."),
        QuickStartPageData(icon: "music.note.list", iconColor: .pink, title: "Add Your Music", description: "Import songs from your Files app or search Apple Music. Trim clips to the perfect moment."),
        QuickStartPageData(icon: "square.grid.2x2", iconColor: .orange, title: "Assign to Events", description: "Long-press any event button to add songs. Build a pool of songs for each game moment."),
        QuickStartPageData(icon: "shuffle", iconColor: .green, title: "Playback Modes", description: "Shuffle plays random songs, Sequential plays in order, and Manual lets you pick each time."),
        QuickStartPageData(icon: "sportscourt", iconColor: .cyan, title: "Game Sessions", description: "Games auto-start on your first tap. View history to see what played and when."),
        QuickStartPageData(icon: "star.fill", iconColor: .yellow, title: "Unlock Pro", description: "Get unlimited songs, custom events, and all playback modes with Pro."),
    ]

    /// Play a manually selected song
    private func playSelectedSong(_ song: SongClip, for event: Event) {
        // Play the song (Apple Music will error if not downloaded when offline)
        AudioPlayerService.shared.playForEvent(song, event: event, session: gameSession)

        AnalyticsService.eventTriggered(
            eventName: event.name,
            eventCode: event.code,
            playbackMode: event.playbackMode.rawValue,
            songSource: song.sourceType.rawValue,
            poolSize: event.pool?.orderedSongs.count ?? 0
        )

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
                        if error.contains("Settings") {
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text(error)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(10)
                            }
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(10)
                        }
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

#Preview {
    DJView()
        .modelContainer(for: [Event.self, SongClip.self, EventPool.self], inMemory: true)
        .environment(GameSession())
}
