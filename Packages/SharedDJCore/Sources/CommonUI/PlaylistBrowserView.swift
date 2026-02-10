import SwiftUI
import SwiftData
import MusicKit
import Core
import MusicService

public struct PlaylistBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @State private var playlists: [UserPlaylist] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPlaylist: UserPlaylist?
    @State private var searchText = ""

    /// Optional: Pre-selected target event for import
    let targetEvent: Event?

    /// Current song count for Pro limit checking
    let currentSongCount: Int

    /// Callback when import completes
    let onImportComplete: (([SongClip]) -> Void)?

    public init(targetEvent: Event? = nil, currentSongCount: Int = 0, onImportComplete: (([SongClip]) -> Void)? = nil) {
        self.targetEvent = targetEvent
        self.currentSongCount = currentSongCount
        self.onImportComplete = onImportComplete
    }

    var filteredPlaylists: [UserPlaylist] {
        guard !searchText.isEmpty else { return playlists }
        return playlists.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch authorizationStatus {
                case .authorized:
                    authorizedContent
                case .denied, .restricted:
                    deniedView
                case .notDetermined:
                    requestAccessView
                @unknown default:
                    requestAccessView
                }
            }
            .navigationTitle("My Playlists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedPlaylist) { playlist in
                PlaylistDetailView(
                    playlist: playlist,
                    targetEvent: targetEvent,
                    currentSongCount: currentSongCount,
                    onImportComplete: { clips in
                        onImportComplete?(clips)
                        dismiss()
                    }
                )
            }
            .onAppear {
                checkMusicAuthorization()
            }
        }
    }

    private var authorizedContent: some View {
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
        .searchable(text: $searchText, prompt: "Search playlists")
        .task {
            await loadPlaylists()
        }
    }

    private var requestAccessView: some View {
        ContentUnavailableView {
            Label("Apple Music Access", systemImage: "music.note.list")
        } description: {
            Text("Grant access to import songs from your Apple Music playlists")
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
            Text("Apple Music access was denied. Please enable it in Settings to import from your playlists.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var playlistList: some View {
        List {
            // Recently Played section
            Section {
                NavigationLink {
                    RecentlyPlayedView(
                        targetEvent: targetEvent,
                        currentSongCount: currentSongCount,
                        onImportComplete: { clips in
                            onImportComplete?(clips)
                            dismiss()
                        }
                    )
                } label: {
                    Label("Recently Played", systemImage: "clock.arrow.circlepath")
                }
            }

            // User playlists
            Section("My Playlists") {
                ForEach(filteredPlaylists) { playlist in
                    Button {
                        selectedPlaylist = playlist
                    } label: {
                        PlaylistRowView(playlist: playlist)
                    }
                }
            }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Playlists", systemImage: "music.note.list")
        } description: {
            Text("You don't have any playlists in your Apple Music library.")
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
            playlists = try await UserLibraryService.shared.fetchPlaylists()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
            }
        }
    }
}
