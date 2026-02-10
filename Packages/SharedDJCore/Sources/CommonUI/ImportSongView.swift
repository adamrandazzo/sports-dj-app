import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import MusicKit
import Core
import MusicService
import StoreService
import AnalyticsService

// MARK: - Apple Music Search Type
public enum AppleMusicSearchType: String, CaseIterable {
    case songs = "Songs"
    case artists = "Artists"
    case albums = "Albums"
}

public struct ImportSongView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allSongs: [SongClip]

    private let proStatus = ProStatusManager.shared

    @State private var showingFilePicker = false
    @State private var showingAppleMusicSearch = false
    @State private var showingPlaylistBrowser = false
    @State private var importedSong: SongClip?
    @State private var showingUpgradePrompt = false
    @State private var navigateToProTab = false

    private var songCount: Int { allSongs.count }
    private var canAddSong: Bool { proStatus.canAddSongs(currentCount: songCount) }

    public init() {}

    public var body: some View {
        List {
            if !proStatus.isPro {
                Section {
                    HStack {
                        Label("Songs", systemImage: "music.note")
                        Spacer()
                        Text("\(songCount)/\(proStatus.maxSongs)")
                            .foregroundStyle(canAddSong ? Color.secondary : Color.red)
                    }
                }
            }

            Section {
                Button {
                    if canAddSong {
                        showingFilePicker = true
                    } else {
                        showingUpgradePrompt = true
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Import Local File")
                            Text("MP3, M4A, WAV, and more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                    }
                }

                Button {
                    if canAddSong {
                        showingAppleMusicSearch = true
                    } else {
                        showingUpgradePrompt = true
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Search Apple Music")
                            Text("Requires Apple Music subscription")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "applelogo")
                            .foregroundStyle(.pink)
                    }
                }

                Button {
                    if canAddSong {
                        showingPlaylistBrowser = true
                    } else {
                        showingUpgradePrompt = true
                    }
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Import from Playlist")
                            Text("Import songs from your Apple Music playlists")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(.purple)
                    }
                }
            } header: {
                Text("Import Source")
            } footer: {
                Text("Local files are copied to the app. Apple Music songs require an active subscription to play.")
            }
        }
        .navigationTitle("Import Song")
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingAppleMusicSearch) {
            AppleMusicSearchView(currentSongCount: songCount) { song in
                importedSong = song
            }
        }
        .sheet(isPresented: $showingPlaylistBrowser) {
            PlaylistBrowserView(targetEvent: nil, currentSongCount: songCount) { clips in
                if clips.count == 1, let clip = clips.first {
                    // Single song: show clip editor
                    importedSong = clip
                } else if clips.count > 1 {
                    // Multiple songs: navigate back to song library
                    dismiss()
                }
            }
        }
        .fullScreenCover(item: $importedSong) { song in
            SongClipEditView(song: song, isNewSong: true)
        }
        .upgradePrompt(isPresented: $showingUpgradePrompt, feature: .unlimitedSongs) {
            navigateToProTab = true
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let sourceURL = urls.first else { return }

            Task {
                await importLocalFile(from: sourceURL)
            }

        case .failure(let error):
            print("File import failed: \(error)")
        }
    }

    @MainActor
    private func importLocalFile(from sourceURL: URL) async {
        do {
            // Copy file to storage (handles iCloud if available)
            let filename = try FileStorageManager.shared.copyAudioFile(from: sourceURL)
            let destinationURL = FileStorageManager.shared.audioFileURL(for: filename)

            // Extract metadata
            let title = await SongClip.extractTitle(from: destinationURL) ?? sourceURL.deletingPathExtension().lastPathComponent
            let artist = await SongClip.extractArtist(from: destinationURL) ?? "Unknown Artist"
            let duration = await SongClip.getDuration(from: destinationURL) ?? 30
            let artwork = await SongClip.extractArtwork(from: destinationURL)

            // Create song clip
            let song = SongClip(
                title: title,
                artist: artist,
                sourceType: .localFile,
                sourceID: filename,
                startTime: 0,
                endTime: duration
            )

            if let artwork = artwork {
                song.setArtwork(from: artwork)
            }

            modelContext.insert(song)
            try modelContext.save()

            importedSong = song
            AnalyticsService.songImported(source: "local_file")
            AnalyticsService.setSongCount(allSongs.count + 1)

        } catch {
            print("Failed to import file: \(error)")
        }
    }
}

// MARK: - Apple Music Search View
public struct AppleMusicSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let currentSongCount: Int
    let onSongSelected: (SongClip) -> Void

    private let proStatus = ProStatusManager.shared

    @State private var searchText = ""
    @State private var searchType: AppleMusicSearchType = .songs
    @State private var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @State private var searchResults: MusicItemCollection<Song> = []
    @State private var artistResults: MusicItemCollection<Artist> = []
    @State private var albumResults: MusicItemCollection<Album> = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedArtist: Artist?
    @State private var selectedAlbum: Album?
    @State private var showingUpgradePrompt = false

    @CloudStorage("hideExplicitContent") private var hideExplicitContent = false
    @CloudStorage("addToAppleMusicLibrary") private var addToAppleMusicLibrary = false

    private var canAddSong: Bool { proStatus.canAddSongs(currentCount: currentSongCount) }

    public init(currentSongCount: Int, onSongSelected: @escaping (SongClip) -> Void) {
        self.currentSongCount = currentSongCount
        self.onSongSelected = onSongSelected
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch authorizationStatus {
                case .authorized:
                    searchResultsView
                case .denied, .restricted:
                    deniedView
                case .notDetermined:
                    requestAccessView
                @unknown default:
                    requestAccessView
                }
            }
            .searchable(text: $searchText, prompt: "Search Apple Music")
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
            .onChange(of: searchType) { _, _ in
                performSearch(query: searchText)
            }
            .navigationTitle("Apple Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkMusicAuthorization()
            }
        }
    }

    // MARK: - Views

    private var requestAccessView: some View {
        ContentUnavailableView {
            Label("Apple Music Access", systemImage: "music.note")
        } description: {
            Text("Grant access to search and play songs from Apple Music")
        } actions: {
            Button("Request Access") {
                requestMusicAccess()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var deniedView: some View {
        ContentUnavailableView {
            Label("Access Denied", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Apple Music access was denied. Please enable it in Settings to search and play songs.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var filteredSongs: [Song] {
        guard hideExplicitContent else { return Array(searchResults) }
        return searchResults.filter { $0.contentRating != .explicit }
    }

    private var searchResultsView: some View {
        VStack(spacing: 0) {
            // Search type picker and filter toggle
            VStack(spacing: 12) {
                Picker("Search Type", selection: $searchType) {
                    ForEach(AppleMusicSearchType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Toggle("Hide Explicit Content", isOn: $hideExplicitContent)
                    .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))

            Divider()

            // Search results
            Group {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("Search Apple Music", systemImage: "magnifyingglass")
                    } description: {
                        Text("Enter a song title, artist, or album name")
                    }
                } else if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch searchType {
                    case .songs:
                        songResultsView
                    case .artists:
                        artistResultsView
                    case .albums:
                        albumResultsView
                    }
                }
            }
        }
        .navigationDestination(item: $selectedArtist) { artist in
            ArtistSongsView(artist: artist, hideExplicit: hideExplicitContent, addToLibrary: addToAppleMusicLibrary, currentSongCount: currentSongCount, onSongSelected: onSongSelected)
        }
        .navigationDestination(item: $selectedAlbum) { album in
            AlbumTracksView(album: album, hideExplicit: hideExplicitContent, addToLibrary: addToAppleMusicLibrary, currentSongCount: currentSongCount, onSongSelected: onSongSelected)
        }
        .upgradePrompt(isPresented: $showingUpgradePrompt, feature: .unlimitedSongs) {
            dismiss()
        }
    }

    private var songResultsView: some View {
        Group {
            if filteredSongs.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "music.note")
                } description: {
                    Text(hideExplicitContent ? "No non-explicit songs found for \"\(searchText)\"" : "No songs found for \"\(searchText)\"")
                }
            } else {
                List(filteredSongs, id: \.id) { song in
                    Button {
                        selectSong(song)
                    } label: {
                        AppleMusicSongRow(song: song)
                    }
                }
            }
        }
    }

    private var artistResultsView: some View {
        Group {
            if artistResults.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "person.fill")
                } description: {
                    Text("No artists found for \"\(searchText)\"")
                }
            } else {
                List(artistResults) { artist in
                    Button {
                        selectedArtist = artist
                    } label: {
                        AppleMusicArtistRow(artist: artist)
                    }
                }
            }
        }
    }

    private var albumResultsView: some View {
        Group {
            if albumResults.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "square.stack")
                } description: {
                    Text("No albums found for \"\(searchText)\"")
                }
            } else {
                List(albumResults) { album in
                    Button {
                        selectedAlbum = album
                    } label: {
                        AppleMusicAlbumRow(album: album)
                    }
                }
            }
        }
    }

    // MARK: - Authorization

    private func checkMusicAuthorization() {
        authorizationStatus = MusicAuthorization.currentStatus
    }

    private func requestMusicAccess() {
        Task {
            let status = await MusicAuthorization.request()
            await MainActor.run {
                authorizationStatus = status
                AnalyticsService.appleMusicAuth(status: "\(status)")
            }
        }
    }

    // MARK: - Search

    private func performSearch(query: String) {
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            artistResults = []
            albumResults = []
            return
        }

        searchTask = Task {
            isSearching = true
            defer { isSearching = false }

            // Debounce
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                switch searchType {
                case .songs:
                    var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
                    request.limit = 25
                    let response = try await request.response()
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        searchResults = response.songs
                    }

                case .artists:
                    var request = MusicCatalogSearchRequest(term: query, types: [Artist.self])
                    request.limit = 25
                    let response = try await request.response()
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        artistResults = response.artists
                    }

                case .albums:
                    var request = MusicCatalogSearchRequest(term: query, types: [Album.self])
                    request.limit = 25
                    let response = try await request.response()
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        albumResults = response.albums
                    }
                }
            } catch {
                print("Search failed: \(error)")
            }
        }
    }

    // MARK: - Selection

    private func selectSong(_ song: Song) {
        guard canAddSong else {
            showingUpgradePrompt = true
            return
        }

        Task {
            // Get the song duration
            let songDuration = song.duration ?? 180  // Default to 3 minutes if unknown

            // Create SongClip from Apple Music song
            let clip = SongClip(
                title: song.title,
                artist: song.artistName,
                sourceType: .appleMusic,
                sourceID: song.id.rawValue,
                startTime: 0,
                endTime: songDuration,
                storedDuration: songDuration
            )

            // Try to get artwork
            if let artwork = song.artwork {
                let size = CGSize(width: 300, height: 300)
                if let url = artwork.url(width: Int(size.width), height: Int(size.height)) {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            clip.setArtwork(from: image)
                        }
                    } catch {
                        print("Failed to download artwork: \(error)")
                    }
                }
            }

            // Add to Apple Music library if enabled
            if addToAppleMusicLibrary {
                try? await MusicLibraryService.shared.addToLibrary(appleMusicID: song.id.rawValue)
            }

            await MainActor.run {
                modelContext.insert(clip)
                try? modelContext.save()
                AnalyticsService.songImported(source: "apple_music")
                AnalyticsService.setSongCount(currentSongCount + 1)
                onSongSelected(clip)
                dismiss()
            }
        }
    }
}

// MARK: - Apple Music Song Row
public struct AppleMusicSongRow: View {
    let song: Song

    public init(song: Song) {
        self.song = song
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artwork = song.artwork {
                ArtworkImage(artwork, width: 50, height: 50)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(song.title)
                        .font(.body)
                        .lineLimit(1)

                    if song.contentRating == .explicit {
                        Text("E")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(2)
                    }
                }

                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let albumTitle = song.albumTitle {
                    Text(albumTitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Duration
            if let duration = song.duration {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Apple Music Artist Row
public struct AppleMusicArtistRow: View {
    let artist: Artist

    public init(artist: Artist) {
        self.artist = artist
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artwork = artist.artwork {
                ArtworkImage(artwork, width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(artist.name)
                    .font(.body)
                    .lineLimit(1)

                if let genres = artist.genres, let firstGenre = genres.first {
                    Text(firstGenre.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

// MARK: - Apple Music Album Row
public struct AppleMusicAlbumRow: View {
    let album: Album

    public init(album: Album) {
        self.album = album
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artwork = album.artwork {
                ArtworkImage(artwork, width: 50, height: 50)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "square.stack")
                            .foregroundStyle(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(album.title)
                        .font(.body)
                        .lineLimit(1)

                    if album.contentRating == .explicit {
                        Text("E")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(2)
                    }
                }

                Text(album.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if album.trackCount > 0 {
                    Text("\(album.trackCount) tracks")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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

// MARK: - Artist Songs View
public struct ArtistSongsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let artist: Artist
    let hideExplicit: Bool
    let addToLibrary: Bool
    let currentSongCount: Int
    let onSongSelected: (SongClip) -> Void

    private let proStatus = ProStatusManager.shared

    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var showingUpgradePrompt = false

    private var filteredSongs: [Song] {
        guard hideExplicit else { return songs }
        return songs.filter { $0.contentRating != .explicit }
    }

    private var canAddSong: Bool { proStatus.canAddSongs(currentCount: currentSongCount) }

    public init(artist: Artist, hideExplicit: Bool, addToLibrary: Bool, currentSongCount: Int, onSongSelected: @escaping (SongClip) -> Void) {
        self.artist = artist
        self.hideExplicit = hideExplicit
        self.addToLibrary = addToLibrary
        self.currentSongCount = currentSongCount
        self.onSongSelected = onSongSelected
    }

    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading songs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredSongs.isEmpty {
                ContentUnavailableView {
                    Label("No Songs", systemImage: "music.note")
                } description: {
                    Text(hideExplicit ? "No non-explicit songs available" : "No songs available")
                }
            } else {
                List(filteredSongs, id: \.id) { song in
                    Button {
                        selectSong(song)
                    } label: {
                        AppleMusicSongRow(song: song)
                    }
                }
            }
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadArtistSongs()
        }
        .upgradePrompt(isPresented: $showingUpgradePrompt, feature: .unlimitedSongs) {
            dismiss()
        }
    }

    private func loadArtistSongs() async {
        do {
            var request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: artist.id)
            request.properties = [.topSongs]
            let response = try await request.response()

            if let artistWithSongs = response.items.first,
               let topSongs = artistWithSongs.topSongs {
                await MainActor.run {
                    songs = Array(topSongs)
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        } catch {
            print("Failed to load artist songs: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func selectSong(_ song: Song) {
        guard canAddSong else {
            showingUpgradePrompt = true
            return
        }

        Task {
            let songDuration = song.duration ?? 180

            let clip = SongClip(
                title: song.title,
                artist: song.artistName,
                sourceType: .appleMusic,
                sourceID: song.id.rawValue,
                startTime: 0,
                endTime: songDuration,
                storedDuration: songDuration
            )

            if let artwork = song.artwork {
                let size = CGSize(width: 300, height: 300)
                if let url = artwork.url(width: Int(size.width), height: Int(size.height)) {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            clip.setArtwork(from: image)
                        }
                    } catch {
                        print("Failed to download artwork: \(error)")
                    }
                }
            }

            // Add to Apple Music library if enabled
            if addToLibrary {
                try? await MusicLibraryService.shared.addToLibrary(appleMusicID: song.id.rawValue)
            }

            await MainActor.run {
                modelContext.insert(clip)
                try? modelContext.save()
                AnalyticsService.songImported(source: "apple_music")
                AnalyticsService.setSongCount(currentSongCount + 1)
                onSongSelected(clip)
                dismiss()
            }
        }
    }
}

// MARK: - Album Tracks View
public struct AlbumTracksView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let album: Album
    let hideExplicit: Bool
    let addToLibrary: Bool
    let currentSongCount: Int
    let onSongSelected: (SongClip) -> Void

    private let proStatus = ProStatusManager.shared

    @State private var tracks: [Track] = []
    @State private var isLoading = true
    @State private var showingUpgradePrompt = false

    private var filteredTracks: [Track] {
        guard hideExplicit else { return tracks }
        return tracks.filter { $0.contentRating != .explicit }
    }

    private var canAddSong: Bool { proStatus.canAddSongs(currentCount: currentSongCount) }

    public init(album: Album, hideExplicit: Bool, addToLibrary: Bool, currentSongCount: Int, onSongSelected: @escaping (SongClip) -> Void) {
        self.album = album
        self.hideExplicit = hideExplicit
        self.addToLibrary = addToLibrary
        self.currentSongCount = currentSongCount
        self.onSongSelected = onSongSelected
    }

    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading tracks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTracks.isEmpty {
                ContentUnavailableView {
                    Label("No Tracks", systemImage: "music.note")
                } description: {
                    Text(hideExplicit ? "No non-explicit tracks available" : "No tracks available")
                }
            } else {
                List(filteredTracks, id: \.id) { track in
                    Button {
                        selectTrack(track)
                    } label: {
                        AlbumTrackRow(track: track, albumArtwork: album.artwork)
                    }
                }
            }
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAlbumTracks()
        }
        .upgradePrompt(isPresented: $showingUpgradePrompt, feature: .unlimitedSongs) {
            dismiss()
        }
    }

    private func loadAlbumTracks() async {
        do {
            var request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: album.id)
            request.properties = [.tracks]
            let response = try await request.response()

            if let albumWithTracks = response.items.first,
               let albumTracks = albumWithTracks.tracks {
                await MainActor.run {
                    tracks = Array(albumTracks)
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        } catch {
            print("Failed to load album tracks: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func selectTrack(_ track: Track) {
        guard canAddSong else {
            showingUpgradePrompt = true
            return
        }

        Task {
            let trackDuration = track.duration ?? 180

            let clip = SongClip(
                title: track.title,
                artist: track.artistName,
                sourceType: .appleMusic,
                sourceID: track.id.rawValue,
                startTime: 0,
                endTime: trackDuration,
                storedDuration: trackDuration
            )

            // Use album artwork for track
            if let artwork = album.artwork {
                let size = CGSize(width: 300, height: 300)
                if let url = artwork.url(width: Int(size.width), height: Int(size.height)) {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            clip.setArtwork(from: image)
                        }
                    } catch {
                        print("Failed to download artwork: \(error)")
                    }
                }
            }

            // Add to Apple Music library if enabled
            if addToLibrary {
                try? await MusicLibraryService.shared.addToLibrary(appleMusicID: track.id.rawValue)
            }

            await MainActor.run {
                modelContext.insert(clip)
                try? modelContext.save()
                AnalyticsService.songImported(source: "apple_music")
                AnalyticsService.setSongCount(currentSongCount + 1)
                onSongSelected(clip)
                dismiss()
            }
        }
    }
}

// MARK: - Album Track Row
public struct AlbumTrackRow: View {
    let track: Track
    let albumArtwork: Artwork?

    public init(track: Track, albumArtwork: Artwork?) {
        self.track = track
        self.albumArtwork = albumArtwork
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Track number or artwork
            if let trackNumber = track.trackNumber {
                Text("\(trackNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            } else if let artwork = albumArtwork {
                ArtworkImage(artwork, width: 40, height: 40)
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(track.title)
                        .font(.body)
                        .lineLimit(1)

                    if track.contentRating == .explicit {
                        Text("E")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(2)
                    }
                }

                Text(track.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let duration = track.duration {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
