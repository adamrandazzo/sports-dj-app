import SwiftUI
import SwiftData
import Core
import StoreService
import AnalyticsService

public struct EventPoolView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var event: Event

    @Query private var allSongs: [SongClip]

    private let proStatus = ProStatusManager.shared

    @State private var showingAddSongs = false
    @State private var showingUpgradePrompt = false
    @State private var editingSong: SongClip?

    public init(event: Event) {
        self.event = event
    }

    public var body: some View {
        List {
            // Playback mode selector
            Section {
                if proStatus.isPro {
                    // Pro users get full picker
                    Picker("Playback Mode", selection: $event.playbackMode) {
                        ForEach(PlaybackMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: event.playbackMode) { _, newValue in
                        AnalyticsService.playbackModeChanged(eventName: event.name, newMode: newValue.rawValue)
                    }
                } else {
                    // Free users only get Random
                    HStack {
                        Text("Playback Mode")
                        Spacer()
                        Text(PlaybackMode.random.displayName)
                            .foregroundStyle(.secondary)
                    }

                    // Show locked modes with upgrade prompt
                    ForEach([PlaybackMode.sequential, PlaybackMode.manual], id: \.self) { mode in
                        Button {
                            showingUpgradePrompt = true
                        } label: {
                            HStack {
                                Label(mode.displayName, systemImage: mode.icon)
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text("Pro")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Playback Mode")
            } footer: {
                if proStatus.isPro {
                    Text(event.playbackMode.description)
                } else {
                    Text("Songs are played randomly until all have been played. Upgrade to Pro for more playback modes.")
                }
            }

            // Continuous playback toggle
            Section {
                Toggle("Continuous Playback", isOn: $event.continuousPlayback)
            } footer: {
                Text(event.continuousPlayback
                    ? "When a song ends, the next song will automatically play."
                    : "When a song ends, playback will stop.")
            }

            // Pool songs
            Section {
                if let pool = event.pool {
                    if pool.orderedSongs.isEmpty {
                        ContentUnavailableView {
                            Label("No Songs", systemImage: "music.note")
                        } description: {
                            Text("Add songs to this event's pool")
                        } actions: {
                            Button("Add Songs") {
                                showingAddSongs = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ForEach(pool.orderedSongs) { song in
                            Button {
                                editingSong = song
                            } label: {
                                SongRow(song: song)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pool.removeSong(song)
                                    try? modelContext.save()
                                    AnalyticsService.poolEdited(action: "remove_song", eventName: event.name, count: pool.orderedSongs.count)
                                } label: {
                                    Label("Remove", systemImage: "minus.circle")
                                }
                            }
                        }
                        .onMove { source, destination in
                            moveSongs(in: pool, from: source, to: destination)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Songs")
                    Spacer()
                    if let pool = event.pool, !pool.songsArray.isEmpty {
                        Text("\(pool.songsArray.count) total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text(songsSectionFooter)
            }
        }
        .navigationTitle(event.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingAddSongs = true
                } label: {
                    Image(systemName: "plus")
                }
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddSongs) {
            AddSongsToPoolView(event: event)
        }
        .sheet(item: $editingSong) { song in
            SongClipEditView(song: song)
        }
        .upgradePrompt(isPresented: $showingUpgradePrompt, feature: .playbackModes) {
            // Navigate to Pro tab handled by parent
        }
    }

    private func moveSongs(in pool: EventPool, from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        pool.moveSong(from: sourceIndex, to: destination)
        try? modelContext.save()
    }

    private var songsSectionFooter: String {
        switch event.playbackMode {
        case .random:
            return "Songs are played randomly until all have been played, then the cycle repeats."
        case .sequential:
            return "Drag to reorder. Songs are played in order from top to bottom, then repeat."
        case .manual:
            return "You'll choose which song to play each time. Drag to reorder. "
        }
    }
}

// MARK: - Add Songs to Pool
public struct AddSongsToPoolView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let event: Event

    @Query private var allSongs: [SongClip]
    @State private var selectedSongs: Set<UUID> = []

    private var availableSongs: [SongClip] {
        let poolSongIDs = Set(event.pool?.songsArray.map(\.id) ?? [])
        return allSongs.filter { !poolSongIDs.contains($0.id) }
    }

    public init(event: Event) {
        self.event = event
    }

    public var body: some View {
        NavigationStack {
            List {
                if availableSongs.isEmpty {
                    ContentUnavailableView {
                        Label("No Songs Available", systemImage: "music.note")
                    } description: {
                        Text("Import songs first, or all songs are already in this pool")
                    }
                } else {
                    ForEach(availableSongs) { song in
                        Button {
                            toggleSelection(song)
                        } label: {
                            HStack {
                                SongRow(song: song)

                                Spacer()

                                if selectedSongs.contains(song.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedSongs.count)") {
                        addSelectedSongs()
                        dismiss()
                    }
                    .disabled(selectedSongs.isEmpty)
                }
            }
        }
    }

    private func toggleSelection(_ song: SongClip) {
        if selectedSongs.contains(song.id) {
            selectedSongs.remove(song.id)
        } else {
            selectedSongs.insert(song.id)
        }
    }

    private func addSelectedSongs() {
        guard let pool = event.pool else { return }

        let count = selectedSongs.count
        for song in availableSongs where selectedSongs.contains(song.id) {
            pool.addSong(song)
        }

        try? modelContext.save()
        AnalyticsService.poolEdited(action: "add_songs", eventName: event.name, count: count)
    }
}

// MARK: - Song Row
public struct SongRow: View {
    let song: SongClip

    public init(song: SongClip) {
        self.song = song
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Artwork
            CachedArtworkView(song: song)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\u{2022}")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formatDuration(song.clipDuration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Source indicator
            Image(systemName: song.sourceType == .appleMusic ? "applelogo" : "folder.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
