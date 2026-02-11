import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import MusicKit
import Core
import MusicService
import StoreService
import AnalyticsService
import CommonUI

/// Setup tab - Configuration screens
struct SetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var songs: [SongClip]

    @Binding var navigationPath: NavigationPath

    private let proStatus = ProStatusManager.shared

    @State private var showingFilePicker = false
    @State private var showingAppleMusicSearch = false
    @State private var showingPlaylistBrowser = false
    @State private var showingUpgradePrompt = false
    @State private var isImporting = false
    @State private var importedSong: SongClip?

    private var songCount: Int { songs.count }
    private var canAddSong: Bool { proStatus.canAddSongs(currentCount: songCount) }
    private var remainingSlots: Int { proStatus.remainingSongSlots(currentCount: songCount) }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // Teams & Players
                Section {
                    NavigationLink(value: ContentView.SetupDestination.teams) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Teams")
                                Text("Manage teams and their players")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "person.3.fill")
                        }
                    }

                    NavigationLink {
                        PlayersListView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Players")
                                Text("View all players across teams")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "figure.baseball")
                        }
                    }
                } header: {
                    Text("Teams & Players")
                }

                // Events
                Section {
                    NavigationLink(value: ContentView.SetupDestination.events) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Events")
                                Text("Manage event types and their song pools")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "music.note.list")
                        }
                    }
                } header: {
                    Text("Events")
                }

                // Song Library
                Section {
                    NavigationLink(value: ContentView.SetupDestination.songLibrary) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Song Library")
                                Text("All imported songs and clips")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "music.note")
                        }
                    }
                } header: {
                    Text("Library")
                }

                // Import Section
                Section {
                    Button {
                        if canAddSong {
                            showingFilePicker = true
                        } else {
                            showingUpgradePrompt = true
                            AnalyticsService.freeTierLimitHit(feature: "songs")
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Import Local File")
                                    .foregroundStyle(.primary)
                                Text("MP3, M4A, WAV, and more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        if canAddSong {
                            requestMusicAccess()
                        } else {
                            showingUpgradePrompt = true
                            AnalyticsService.freeTierLimitHit(feature: "songs")
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Search Apple Music")
                                    .foregroundStyle(.primary)
                                Text("Requires Apple Music subscription")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "applelogo")
                                .foregroundStyle(.pink)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        if canAddSong {
                            requestMusicAccessForPlaylist()
                        } else {
                            showingUpgradePrompt = true
                            AnalyticsService.freeTierLimitHit(feature: "songs")
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Import From Playlist")
                                    .foregroundStyle(.primary)
                                Text("Import from your Apple Music Playlists")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "music.note.list")
                                .foregroundStyle(.purple)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Import")
                } footer: {
                    if !proStatus.isPro {
                        Text("Free users can import up to \(ProStatusManager.shared.freeSongLimit) songs. You have \(remainingSlots) slot\(remainingSlots == 1 ? "" : "s") remaining.")
                    } else {
                        Text("Local files are copied to the app. Apple Music songs require an active subscription to play.")
                    }
                }

                // Settings
                Section("Settings") {
                    NavigationLink(value: ContentView.SetupDestination.settings) {
                        Label("App Settings", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("Setup")
            .navigationDestination(for: ContentView.SetupDestination.self) { destination in
                switch destination {
                case .teams:
                    TeamsListView()
                case .events:
                    EventsListView()
                case .songLibrary:
                    SongLibraryView()
                case .settings:
                    AppSettingsView()
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showingAppleMusicSearch) {
                AppleMusicSearchView(currentSongCount: songCount) { song in
                    importedSong = song
                }
            }
            .fullScreenCover(item: $importedSong) { song in
                SongClipEditView(song: song, isNewSong: true)
            }
            .sheet(isPresented: $showingPlaylistBrowser) {
                PlaylistBrowserView(
                    targetEvent: nil,
                    currentSongCount: songCount,
                    onImportComplete: { _ in }
                )
            }
            .upgradePrompt(isPresented: $showingUpgradePrompt, feature: .unlimitedSongs) {
                // Navigation to Pro tab handled by environment
            }
            .overlay {
                if isImporting {
                    ProgressView("Importing...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func requestMusicAccess() {
        Task {
            let status = await MusicAuthorization.request()
            if status == .authorized {
                await MainActor.run {
                    showingAppleMusicSearch = true
                }
            }
        }
    }

    private func requestMusicAccessForPlaylist() {
        Task {
            let status = await MusicAuthorization.request()
            if status == .authorized {
                await MainActor.run {
                    showingPlaylistBrowser = true
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await importLocalFiles(urls)
            }
        case .failure(let error):
            print("File import error: \(error)")
        }
    }

    @MainActor
    private func importLocalFiles(_ urls: [URL]) async {
        isImporting = true

        for url in urls {
            // Check if we can still add songs
            guard ProStatusManager.shared.canAddSongs(currentCount: songs.count) else {
                break
            }

            do {
                // Copy file to app storage
                let filename = try FileStorageManager.shared.copyAudioFile(from: url)

                // Extract metadata
                let title = await SongClip.extractTitle(from: url) ?? url.deletingPathExtension().lastPathComponent
                let artist = await SongClip.extractArtist(from: url) ?? "Unknown Artist"
                let duration = await SongClip.getDuration(from: url)
                let artwork = await SongClip.extractArtwork(from: url)

                let song = SongClip(
                    title: title,
                    artist: artist,
                    sourceType: .localFile,
                    sourceID: filename,
                    startTime: 0,
                    endTime: min(duration ?? 30, 30),
                    storedDuration: duration
                )

                if let artwork {
                    song.setArtwork(from: artwork)
                }

                modelContext.insert(song)
            } catch {
                print("Failed to import \(url.lastPathComponent): \(error)")
            }
        }

        try? modelContext.save()
        AnalyticsService.songImported(source: "local", count: urls.count)
        isImporting = false
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    SetupView(navigationPath: $path)
        .modelContainer(for: [SongClip.self], inMemory: true)
}
