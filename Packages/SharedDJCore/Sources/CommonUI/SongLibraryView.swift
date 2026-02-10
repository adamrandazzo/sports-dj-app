import SwiftUI
import SwiftData
import Core
import StoreService
import AnalyticsService

// MARK: - Sort Options

public enum SongSortOption: String, CaseIterable {
    case dateAddedNewest = "Recently Added"
    case dateAddedOldest = "Oldest First"
    case titleAZ = "Title (A-Z)"
    case titleZA = "Title (Z-A)"
    case artistAZ = "Artist (A-Z)"
    case artistZA = "Artist (Z-A)"
    case durationShortest = "Duration (Shortest)"
    case durationLongest = "Duration (Longest)"

    public var icon: String {
        switch self {
        case .dateAddedNewest, .dateAddedOldest: return "calendar"
        case .titleAZ, .titleZA: return "textformat"
        case .artistAZ, .artistZA: return "person"
        case .durationShortest, .durationLongest: return "clock"
        }
    }
}

public enum SongSourceFilter: String, CaseIterable {
    case all = "All Sources"
    case appleMusic = "Apple Music"
    case localFiles = "Local Files"

    public var icon: String {
        switch self {
        case .all: return "music.note.list"
        case .appleMusic: return "applelogo"
        case .localFiles: return "folder.fill"
        }
    }
}

// MARK: - Selectable Song Row

public struct SelectableSongRow: View {
    let song: SongClip
    let isSelected: Bool
    let isSelectionMode: Bool
    let onToggle: () -> Void

    public init(song: SongClip, isSelected: Bool, isSelectionMode: Bool, onToggle: @escaping () -> Void) {
        self.song = song
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
        self.onToggle = onToggle
    }

    public var body: some View {
        if isSelectionMode {
            Button(action: onToggle) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            // Selection indicator (only in selection mode)
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
            }

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

// MARK: - Song Library View

public struct SongLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var songs: [SongClip]

    private let proStatus = ProStatusManager.shared

    @State private var searchText = ""
    @State private var songToEdit: SongClip?
    @State private var showingUpgradePrompt = false

    // Sorting and filtering
    @AppStorage("songLibrarySortOption") private var sortOptionRaw: String = SongSortOption.dateAddedNewest.rawValue
    @State private var sourceFilter: SongSourceFilter = .all

    // Selection mode
    @State private var isSelectionMode = false
    @State private var selectedSongIDs: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    private var sortOption: SongSortOption {
        get { SongSortOption(rawValue: sortOptionRaw) ?? .dateAddedNewest }
        set { sortOptionRaw = newValue.rawValue }
    }

    private var filteredAndSortedSongs: [SongClip] {
        var result = songs

        // Apply source filter
        switch sourceFilter {
        case .all:
            break
        case .appleMusic:
            result = result.filter { $0.sourceType == .appleMusic }
        case .localFiles:
            result = result.filter { $0.sourceType == .localFile }
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply sorting
        switch sortOption {
        case .dateAddedNewest:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .dateAddedOldest:
            result.sort { $0.dateAdded < $1.dateAdded }
        case .titleAZ:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleZA:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .artistAZ:
            result.sort { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        case .artistZA:
            result.sort { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedDescending }
        case .durationShortest:
            result.sort { $0.clipDuration < $1.clipDuration }
        case .durationLongest:
            result.sort { $0.clipDuration > $1.clipDuration }
        }

        return result
    }

    private var canAddSong: Bool {
        proStatus.canAddSongs(currentCount: songs.count)
    }

    private var selectedSongs: [SongClip] {
        songs.filter { selectedSongIDs.contains($0.id) }
    }

    public init() {}

    public var body: some View {
        List {
            // Song count section for free users
            if !proStatus.isPro && !songs.isEmpty {
                Section {
                    HStack {
                        Label("Songs", systemImage: "music.note")
                        Spacer()
                        Text("\(songs.count)/\(proStatus.maxSongs)")
                            .foregroundStyle(canAddSong ? Color.secondary : Color.orange)
                    }
                    if !canAddSong {
                        Button {
                            showingUpgradePrompt = true
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text("Upgrade to Pro for unlimited songs")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if songs.isEmpty {
                ContentUnavailableView {
                    Label("No Songs", systemImage: "music.note.list")
                } description: {
                    Text("Import songs from Apple Music or local files to get started")
                } actions: {
                    NavigationLink("Import Song") {
                        ImportSongView()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Selection controls (only in selection mode)
                if isSelectionMode {
                    Section {
                        HStack {
                            Button {
                                selectedSongIDs = Set(filteredAndSortedSongs.map(\.id))
                            } label: {
                                Text("Select All")
                            }

                            Spacer()

                            Button {
                                selectedSongIDs.removeAll()
                            } label: {
                                Text("Deselect All")
                            }
                            .disabled(selectedSongIDs.isEmpty)
                        }
                        .buttonStyle(.borderless)

                        if !selectedSongIDs.isEmpty {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete \(selectedSongIDs.count) Song\(selectedSongIDs.count == 1 ? "" : "s")")
                                }
                            }
                        }
                    }
                }

                // Filter and sort controls (not in selection mode)
                if !isSelectionMode {
                    Section {
                        // Source filter
                        Picker("Source", selection: $sourceFilter) {
                            ForEach(SongSourceFilter.allCases, id: \.self) { filter in
                                Label(filter.rawValue, systemImage: filter.icon)
                                    .tag(filter)
                            }
                        }

                        // Sort option
                        Picker("Sort By", selection: Binding(
                            get: { sortOption },
                            set: { sortOptionRaw = $0.rawValue }
                        )) {
                            ForEach(SongSortOption.allCases, id: \.self) { option in
                                Label(option.rawValue, systemImage: option.icon)
                                    .tag(option)
                            }
                        }
                    }
                }

                // Song list
                Section {
                    if filteredAndSortedSongs.isEmpty {
                        ContentUnavailableView {
                            Label("No Results", systemImage: "magnifyingglass")
                        } description: {
                            Text("No songs match your search or filter")
                        }
                    } else {
                        ForEach(filteredAndSortedSongs) { song in
                            if isSelectionMode {
                                SelectableSongRow(
                                    song: song,
                                    isSelected: selectedSongIDs.contains(song.id),
                                    isSelectionMode: true,
                                    onToggle: { toggleSelection(song) }
                                )
                            } else {
                                Button {
                                    songToEdit = song
                                } label: {
                                    SelectableSongRow(
                                        song: song,
                                        isSelected: false,
                                        isSelectionMode: false,
                                        onToggle: {}
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("SongRow_\(song.title)")
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteSong(song)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    if !filteredAndSortedSongs.isEmpty {
                        HStack {
                            Text("\(filteredAndSortedSongs.count) song\(filteredAndSortedSongs.count == 1 ? "" : "s")")
                            if isSelectionMode && !selectedSongIDs.isEmpty {
                                Text("\u{2022} \(selectedSongIDs.count) selected")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search songs")
        .navigationTitle("Song Library")
        .fullScreenCover(item: $songToEdit) { song in
            SongClipEditView(song: song)
        }
        .upgradePrompt(isPresented: $showingUpgradePrompt, feature: .unlimitedSongs) {
            // Navigate to Pro tab handled by parent
        }
        .confirmationDialog(
            "Delete \(selectedSongIDs.count) Song\(selectedSongIDs.count == 1 ? "" : "s")?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteSelectedSongs()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the selected songs from your library. Songs will also be removed from any events they're assigned to.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !songs.isEmpty {
                    Button {
                        withAnimation {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedSongIDs.removeAll()
                            }
                        }
                    } label: {
                        Text(isSelectionMode ? "Done" : "Select")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if !songs.isEmpty && !isSelectionMode {
                    if canAddSong {
                        NavigationLink {
                            ImportSongView()
                        } label: {
                            Image(systemName: "plus")
                        }
                    } else {
                        Button {
                            showingUpgradePrompt = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .onChange(of: isSelectionMode) { _, newValue in
            if !newValue {
                selectedSongIDs.removeAll()
            }
        }
    }

    private func toggleSelection(_ song: SongClip) {
        if selectedSongIDs.contains(song.id) {
            selectedSongIDs.remove(song.id)
        } else {
            selectedSongIDs.insert(song.id)
        }
    }

    private func deleteSong(_ song: SongClip) {
        // Remove from file system if local
        if song.sourceType == .localFile, let url = song.localFileURL {
            try? FileManager.default.removeItem(at: url)
        }

        modelContext.delete(song)
        try? modelContext.save()
        AnalyticsService.songDeleted(count: 1)
        AnalyticsService.setSongCount(songs.count - 1)
    }

    private func deleteSelectedSongs() {
        let count = selectedSongs.count
        for song in selectedSongs {
            // Remove from file system if local
            if song.sourceType == .localFile, let url = song.localFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(song)
        }

        try? modelContext.save()
        AnalyticsService.songDeleted(count: count)
        AnalyticsService.setSongCount(songs.count - count)
        selectedSongIDs.removeAll()
        isSelectionMode = false
    }
}
