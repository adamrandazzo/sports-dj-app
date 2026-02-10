import SwiftUI
import SwiftData
import Core
import MusicService

public struct RemotePlaylistBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var importedSetlists: [Setlist]

    let preselectedPlaylist: RemotePlaylistSummary?
    let onSetlistImported: ((Setlist) -> Void)?

    private let service = RemotePlaylistService.shared

    @State private var playlists: [RemotePlaylistSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedPlaylist: RemotePlaylistSummary?
    @State private var hasNavigatedToPreselected = false

    public init(preselectedPlaylist: RemotePlaylistSummary? = nil, onSetlistImported: ((Setlist) -> Void)? = nil) {
        self.preselectedPlaylist = preselectedPlaylist
        self.onSetlistImported = onSetlistImported
    }

    private var importedRemoteIDs: Set<Int> {
        Set(importedSetlists.compactMap { $0.remoteID })
    }

    private var filteredPlaylists: [RemotePlaylistSummary] {
        guard !searchText.isEmpty else { return playlists }
        return playlists.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading playlists...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    errorView(error)
                } else if playlists.isEmpty {
                    emptyView
                } else {
                    playlistList
                }
            }
            .navigationTitle("Curated Setlists")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search playlists")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $selectedPlaylist) { playlist in
                RemotePlaylistDetailView(
                    playlistSummary: playlist,
                    isAlreadyImported: importedRemoteIDs.contains(playlist.id),
                    onImportComplete: { importedSetlist in
                        if let setlist = importedSetlist {
                            onSetlistImported?(setlist)
                        }
                        dismiss()
                    }
                )
            }
            .task {
                await loadPlaylists()
            }
        }
    }

    private var playlistList: some View {
        List(filteredPlaylists) { playlist in
            Button {
                selectedPlaylist = playlist
            } label: {
                RemotePlaylistSummaryRow(
                    playlist: playlist,
                    isImported: importedRemoteIDs.contains(playlist.id)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Playlists", systemImage: "music.note.list")
        } description: {
            Text("No playlists are available at this time.")
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await loadPlaylists() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func loadPlaylists() async {
        isLoading = true
        errorMessage = nil

        do {
            playlists = try await service.fetchPlaylists()

            // Auto-navigate to preselected playlist if provided
            if let preselected = preselectedPlaylist, !hasNavigatedToPreselected {
                hasNavigatedToPreselected = true
                await MainActor.run {
                    selectedPlaylist = preselected
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Summary Row

public struct RemotePlaylistSummaryRow: View {
    let playlist: RemotePlaylistSummary
    let isImported: Bool

    public init(playlist: RemotePlaylistSummary, isImported: Bool) {
        self.playlist = playlist
        self.isImported = isImported
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Artwork or fallback icon
            CachedAsyncImage(url: URL(string: playlist.artworkURL ?? "")) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.2))
                    .overlay {
                        Image(systemName: "star.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(playlist.name)
                        .font(.headline)
                        .lineLimit(1)

                    if isImported {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                Text(playlist.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let songCount = playlist.songCount {
                    Label("\(songCount) songs", systemImage: "music.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Detail View

public struct RemotePlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let playlistSummary: RemotePlaylistSummary
    let isAlreadyImported: Bool
    let onImportComplete: (Setlist?) -> Void

    @Query private var events: [Event]

    private let service = RemotePlaylistService.shared

    @State private var playlistDetail: RemotePlaylistDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var importProgress: (current: Int, total: Int)?
    @State private var importedSetlist: Setlist?

    private var eventsByCode: [String: Event] {
        Dictionary(uniqueKeysWithValues: events.compactMap { event in
            event.code.isEmpty ? nil : (event.code, event)
        })
    }

    public init(playlistSummary: RemotePlaylistSummary, isAlreadyImported: Bool, onImportComplete: @escaping (Setlist?) -> Void) {
        self.playlistSummary = playlistSummary
        self.isAlreadyImported = isAlreadyImported
        self.onImportComplete = onImportComplete
    }

    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading playlist...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                errorView(error)
            } else if let detail = playlistDetail {
                if let imported = importedSetlist {
                    successView(imported)
                } else if isImporting {
                    importingView
                } else {
                    playlistContent(detail)
                }
            }
        }
        .navigationTitle(playlistSummary.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isLoading && !isImporting && importedSetlist == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button(isAlreadyImported ? "Re-sync" : "Import") {
                        Task { await importPlaylist() }
                    }
                    .disabled(playlistDetail == nil)
                }
            }
        }
        .task {
            await loadPlaylistDetail()
        }
    }

    private func playlistContent(_ detail: RemotePlaylistDetail) -> some View {
        List {
            // Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if isAlreadyImported {
                        Label("Already Imported", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if !detail.description.isEmpty {
                        Text(detail.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("\(detail.songs.count) songs", systemImage: "music.note")
                        Spacer()
                        let eventCount = detail.songs.filter { $0.event != nil }.count
                        if eventCount > 0 {
                            Label("\(eventCount) with events", systemImage: "star.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Songs grouped by event
            let songsWithEvents = detail.songs.filter { $0.event != nil }
            let songsWithoutEvents = detail.songs.filter { $0.event == nil }

            if !songsWithEvents.isEmpty {
                let grouped = Dictionary(grouping: songsWithEvents) { $0.event?.code ?? "" }

                ForEach(grouped.keys.sorted(), id: \.self) { code in
                    if let songs = grouped[code],
                       let eventName = songs.first?.event?.name {
                        Section {
                            ForEach(songs) { song in
                                RemoteSongRow(song: song)
                            }
                        } header: {
                            HStack {
                                if let event = eventsByCode[code] {
                                    Image(systemName: event.icon)
                                        .foregroundStyle(event.color)
                                }
                                Text(eventName)
                            }
                        }
                    }
                }
            }

            if !songsWithoutEvents.isEmpty {
                Section {
                    ForEach(songsWithoutEvents) { song in
                        RemoteSongRow(song: song)
                    }
                } header: {
                    Text("Library Only")
                } footer: {
                    Text("These songs will be added to your library but not assigned to any event.")
                }
            }
        }
    }

    private var importingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            if let progress = importProgress {
                VStack(spacing: 8) {
                    Text("Importing...")
                        .font(.headline)

                    Text("\(progress.current) of \(progress.total) songs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ProgressView(value: Double(progress.current), total: Double(progress.total))
                        .frame(width: 200)
                }
            } else {
                Text("Preparing import...")
                    .font(.headline)
            }

            Spacer()
        }
    }

    private func successView(_ setlist: Setlist) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Setlist Imported!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\"\(setlist.name)\"")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("\(setlist.songCount) songs added")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") {
                onImportComplete(setlist)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await loadPlaylistDetail() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func loadPlaylistDetail() async {
        isLoading = true
        errorMessage = nil

        do {
            playlistDetail = try await service.fetchPlaylistDetail(id: playlistSummary.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func importPlaylist() async {
        guard let detail = playlistDetail else { return }

        isImporting = true

        do {
            let setlist = try await service.importPlaylist(detail, modelContext: modelContext) { current, total in
                importProgress = (current, total)
            }
            withAnimation {
                importedSetlist = setlist
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isImporting = false
    }
}

// MARK: - Remote Song Row

public struct RemoteSongRow: View {
    let song: RemoteSong

    public init(song: RemoteSong) {
        self.song = song
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Artwork
            CachedAsyncImage(url: URL(string: song.artworkURL ?? "")) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.gray)
                    }
            }
            .frame(width: 44, height: 44)
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.body)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatDuration(song.durationSeconds))
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
