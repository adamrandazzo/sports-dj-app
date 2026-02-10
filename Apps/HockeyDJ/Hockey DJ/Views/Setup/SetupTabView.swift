import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import MusicKit
import Core
import MusicService
import StoreService
import CommonUI

struct SetupTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath

    @Query private var allSongs: [SongClip]

    private let proStatus = ProStatusManager.shared

    @State private var showingFilePicker = false
    @State private var showingAppleMusicSearch = false
    @State private var showingPlaylistBrowser = false
    @State private var importedSong: SongClip?
    @State private var showingUpgradePrompt = false

    private var songCount: Int { allSongs.count }
    private var canAddSong: Bool { proStatus.canAddSongs(currentCount: songCount) }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // Events Section
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
                            Image(systemName: "list.bullet.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .accessibilityIdentifier("EventsNavLink")
                } header: {
                    Text("Events")
                }

                // Song Library Section
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
                            Image(systemName: "music.note.list")
                                .foregroundStyle(.purple)
                        }
                    }
                    .accessibilityIdentifier("SongLibraryNavLink")
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
                            showingAppleMusicSearch = true
                        } else {
                            showingUpgradePrompt = true
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
                            showingPlaylistBrowser = true
                        } else {
                            showingUpgradePrompt = true
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Import from Playlist")
                                    .foregroundStyle(.primary)
                                Text("Import from your Apple Music playlists")
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
                    Text("Local files are copied to the app. Apple Music songs require an active subscription to play.")
                }

                // Settings Section
                Section {
                    NavigationLink(value: ContentView.SetupDestination.settings) {
                        Label("Settings", systemImage: "gear")
                    }
                } header: {
                    Text("App")
                }
            }
            .navigationTitle("Setup")
            .navigationDestination(for: ContentView.SetupDestination.self) { destination in
                switch destination {
                case .events:
                    EventsListView()
                case .songLibrary:
                    SongLibraryView()
                case .importSong:
                    ImportSongView()
                case .settings:
                    SettingsView()
                }
            }
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
                PlaylistBrowserView(targetEvent: nil, currentSongCount: songCount, onImportComplete: { clips in
                    if clips.count == 1, let clip = clips.first {
                        importedSong = clip
                    }
                })
            }
            .fullScreenCover(item: $importedSong) { song in
                SongClipEditView(song: song, isNewSong: true)
            }
            .upgradePrompt(isPresented: $showingUpgradePrompt, feature: .unlimitedSongs) {
                // Navigation to Pro tab handled by environment
            }
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
            let filename = try FileStorageManager.shared.copyAudioFile(from: sourceURL)
            let destinationURL = FileStorageManager.shared.audioFileURL(for: filename)

            let title = await SongClip.extractTitle(from: destinationURL) ?? sourceURL.deletingPathExtension().lastPathComponent
            let artist = await SongClip.extractArtist(from: destinationURL) ?? "Unknown Artist"
            let duration = await SongClip.getDuration(from: destinationURL) ?? 30
            let artwork = await SongClip.extractArtwork(from: destinationURL)

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

        } catch {
            print("Failed to import file: \(error)")
        }
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    SetupTabView(navigationPath: $path)
        .modelContainer(for: [Event.self, SongClip.self, EventPool.self], inMemory: true)
}
