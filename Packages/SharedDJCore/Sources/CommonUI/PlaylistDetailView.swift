import SwiftUI
import SwiftData
import MusicKit
import Core
import MusicService
import StoreService

public struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let playlist: UserPlaylist
    let targetEvent: Event?
    let currentSongCount: Int
    let onImportComplete: (([SongClip]) -> Void)?

    private let proStatus = ProStatusManager.shared

    @State private var tracks: [PlaylistTrack] = []
    @State private var selectedTrackIDs: Set<MusicItemID> = []
    @State private var isLoading = true
    @State private var showingImportSheet = false
    @State private var showingUpgradePrompt = false

    @CloudStorage("hideExplicitContent") private var hideExplicitContent = false

    private var filteredTracks: [PlaylistTrack] {
        guard hideExplicitContent else { return tracks }
        return tracks.filter { !$0.isExplicit }
    }

    private var selectableTracks: [PlaylistTrack] {
        filteredTracks.filter { $0.isPlayable }
    }

    private var selectedTracks: [PlaylistTrack] {
        filteredTracks.filter { selectedTrackIDs.contains($0.id) }
    }

    /// Maximum number of songs that can be imported based on Pro status
    private var maxImportCount: Int {
        proStatus.remainingSongSlots(currentCount: currentSongCount)
    }

    /// Whether user can import more songs
    private var canImport: Bool {
        proStatus.canAddSongs(currentCount: currentSongCount)
    }

    public init(playlist: UserPlaylist, targetEvent: Event?, currentSongCount: Int, onImportComplete: (([SongClip]) -> Void)?) {
        self.playlist = playlist
        self.targetEvent = targetEvent
        self.currentSongCount = currentSongCount
        self.onImportComplete = onImportComplete
    }

    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading tracks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                trackList
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Import") {
                    if canImport {
                        showingImportSheet = true
                    } else {
                        showingUpgradePrompt = true
                    }
                }
                .disabled(selectedTrackIDs.isEmpty)
            }
        }
        .upgradePrompt(isPresented: $showingUpgradePrompt, feature: .unlimitedSongs) {
            dismiss()
        }
        .sheet(isPresented: $showingImportSheet) {
            PlaylistImportSheet(
                playlistName: playlist.name,
                selectedTracks: selectedTracks,
                targetEvent: targetEvent,
                onComplete: { result in
                    onImportComplete?(result.createdClips)
                }
            )
        }
        .task {
            await loadTracks()
        }
        .onChange(of: hideExplicitContent) { _, _ in
            // Update selection when filter changes
            selectedTrackIDs = selectedTrackIDs.filter { id in
                filteredTracks.contains { $0.id == id }
            }
        }
    }

    private var trackList: some View {
        List {
            // Free user limit banner
            if !proStatus.isPro {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        if maxImportCount > 0 {
                            Text("You can import up to \(maxImportCount) more song\(maxImportCount == 1 ? "" : "s")")
                        } else {
                            Text("Song limit reached. Upgrade to Pro for unlimited songs.")
                        }
                        Spacer()
                    }
                    .font(.subheadline)
                }
            }

            // Header with playlist info
            Section {
                HStack(spacing: 16) {
                    // Artwork
                    if let artwork = playlist.artwork {
                        ArtworkImage(artwork, width: 80, height: 80)
                            .cornerRadius(8)
                    } else {
                        playlistPlaceholder
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name)
                            .font(.headline)

                        Text("\(filteredTracks.count) songs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !selectedTrackIDs.isEmpty {
                            Text("\(selectedTrackIDs.count) selected")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // Selection controls
            Section {
                HStack {
                    Button {
                        if proStatus.isPro {
                            selectedTrackIDs = Set(selectableTracks.map(\.id))
                        } else {
                            let tracksToSelect = Array(selectableTracks.prefix(maxImportCount))
                            selectedTrackIDs = Set(tracksToSelect.map(\.id))
                        }
                    } label: {
                        Text("Select All")
                    }
                    .disabled(!proStatus.isPro && maxImportCount == 0)

                    Spacer()

                    Button {
                        selectedTrackIDs.removeAll()
                    } label: {
                        Text("Deselect All")
                    }
                    .disabled(selectedTrackIDs.isEmpty)
                }
                .buttonStyle(.borderless)

                Toggle("Hide Explicit", isOn: $hideExplicitContent)
            }

            // Track list
            if filteredTracks.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Tracks", systemImage: "music.note")
                    } description: {
                        Text(hideExplicitContent ? "No non-explicit tracks in this playlist." : "This playlist is empty.")
                    }
                }
            } else {
                Section("Tracks") {
                    ForEach(filteredTracks) { track in
                        PlaylistTrackRow(
                            track: track,
                            isSelected: selectedTrackIDs.contains(track.id),
                            onToggle: { toggleSelection(track) }
                        )
                    }
                }
            }
        }
    }

    private var playlistPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 80, height: 80)
            .overlay {
                Image(systemName: "music.note.list")
                    .font(.title)
                    .foregroundStyle(.gray)
            }
    }

    private func toggleSelection(_ track: PlaylistTrack) {
        guard track.isPlayable else { return }

        if selectedTrackIDs.contains(track.id) {
            selectedTrackIDs.remove(track.id)
        } else {
            // Check if we can add more tracks (for free users)
            if !proStatus.isPro && selectedTrackIDs.count >= maxImportCount {
                showingUpgradePrompt = true
                return
            }
            selectedTrackIDs.insert(track.id)
        }
    }

    private func loadTracks() async {
        do {
            tracks = try await UserLibraryService.shared.fetchPlaylistTracks(
                for: playlist.id
            )
            // All tracks start deselected
        } catch {
            print("Failed to load tracks: \(error)")
        }
        isLoading = false
    }
}
