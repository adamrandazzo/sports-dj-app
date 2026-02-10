import SwiftUI
import SwiftData
import MusicKit
import Core
import MusicService
import StoreService

public struct RecentlyPlayedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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

    private var maxImportCount: Int {
        proStatus.remainingSongSlots(currentCount: currentSongCount)
    }

    private var canImport: Bool {
        proStatus.canAddSongs(currentCount: currentSongCount)
    }

    public init(targetEvent: Event?, currentSongCount: Int, onImportComplete: (([SongClip]) -> Void)?) {
        self.targetEvent = targetEvent
        self.currentSongCount = currentSongCount
        self.onImportComplete = onImportComplete
    }

    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading recently played...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTracks.isEmpty {
                emptyView
            } else {
                trackList
            }
        }
        .navigationTitle("Recently Played")
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

            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    if proStatus.isPro {
                        Button("Select All") {
                            selectedTrackIDs = Set(selectableTracks.map(\.id))
                        }
                    } else {
                        Button("Select All (up to \(maxImportCount))") {
                            let tracksToSelect = Array(selectableTracks.prefix(maxImportCount))
                            selectedTrackIDs = Set(tracksToSelect.map(\.id))
                        }
                        .disabled(maxImportCount == 0)
                    }
                    Button("Deselect All") {
                        selectedTrackIDs.removeAll()
                    }
                    Divider()
                    Toggle("Hide Explicit", isOn: $hideExplicitContent)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .upgradePrompt(isPresented: $showingUpgradePrompt, feature: .unlimitedSongs) {
            dismiss()
        }
        .sheet(isPresented: $showingImportSheet) {
            PlaylistImportSheet(
                playlistName: "Recently Played",
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

            Section {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recently Played")
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

            Section("Songs") {
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

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Recent Songs", systemImage: "clock.arrow.circlepath")
        } description: {
            Text("Songs you've recently played in Apple Music will appear here.")
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
            tracks = try await UserLibraryService.shared.fetchRecentlyPlayed(limit: 50)
            // Don't auto-select for recently played - let user choose
        } catch {
            print("Failed to load recently played: \(error)")
        }
        isLoading = false
    }
}
