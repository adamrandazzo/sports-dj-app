import SwiftUI
import SwiftData
import MusicKit
import Core
import MusicService

public struct PlaylistImportSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let playlistName: String
    let selectedTracks: [PlaylistTrack]
    let targetEvent: Event?
    let onComplete: (PlaylistImportResult) -> Void

    @State private var isImporting = false
    @State private var progress: (current: Int, total: Int) = (0, 0)
    @State private var result: PlaylistImportResult?
    @State private var skipExisting = true

    @CloudStorage("addToAppleMusicLibrary") private var addToAppleMusicLibrary = false

    public init(playlistName: String, selectedTracks: [PlaylistTrack], targetEvent: Event?, onComplete: @escaping (PlaylistImportResult) -> Void) {
        self.playlistName = playlistName
        self.selectedTracks = selectedTracks
        self.targetEvent = targetEvent
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            Group {
                if isImporting {
                    progressView
                } else if let result = result {
                    resultView(result)
                } else {
                    configView
                }
            }
            .navigationTitle("Import Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isImporting && result == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isImporting)
    }

    private var configView: some View {
        List {
            Section {
                HStack {
                    Text("Songs to import")
                    Spacer()
                    Text("\(selectedTracks.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("From")
                    Spacer()
                    Text(playlistName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Text("Destination")
                    Spacer()
                    if let event = targetEvent {
                        Text(event.name)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Song Library")
                            .foregroundStyle(.secondary)
                    }
                }

            }

            Section {
                Toggle("Skip Existing Songs", isOn: $skipExisting)
            } footer: {
                Text("Songs already in your library won't be duplicated.")
            }

            Section {
                Toggle("Add to Apple Music Library", isOn: $addToAppleMusicLibrary)
            } footer: {
                Text("Songs will be added to your Apple Music library for offline download.")
            }

            Section {
                Button {
                    startImport()
                } label: {
                    HStack {
                        Spacer()
                        Text("Import \(selectedTracks.count) Songs")
                            .bold()
                        Spacer()
                    }
                }
            }
        }
    }

    private var progressView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: Double(progress.current), total: Double(max(1, progress.total)))
                .progressViewStyle(.linear)
                .padding(.horizontal, 40)

            Text("Importing \(progress.current) of \(progress.total)...")
                .font(.headline)

            Text("Please wait")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private func resultView(_ result: PlaylistImportResult) -> some View {
        List {
            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title)

                    VStack(alignment: .leading) {
                        Text("Import Complete")
                            .font(.headline)
                        Text("\(result.importedCount) songs imported")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            if result.skippedExisting > 0 || result.skippedUnavailable > 0 || result.failedCount > 0 {
                Section("Details") {
                    if result.skippedExisting > 0 {
                        HStack {
                            Label("Already in library", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            Text("\(result.skippedExisting)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if result.skippedUnavailable > 0 {
                        HStack {
                            Label("Unavailable", systemImage: "exclamationmark.triangle")
                            Spacer()
                            Text("\(result.skippedUnavailable)")
                                .foregroundStyle(.orange)
                        }
                    }

                    if result.failedCount > 0 {
                        HStack {
                            Label("Failed", systemImage: "xmark.circle")
                            Spacer()
                            Text("\(result.failedCount)")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            Section {
                Button {
                    onComplete(result)
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text("Done")
                            .bold()
                        Spacer()
                    }
                }
            }
        }
    }

    private func startImport() {
        isImporting = true
        progress = (0, selectedTracks.count)

        Task {
            let config = PlaylistImportConfig(
                tracks: selectedTracks,
                targetEvent: targetEvent,
                skipExisting: skipExisting,
                addToAppleMusicLibrary: addToAppleMusicLibrary
            )

            let importer = PlaylistImporter(modelContext: modelContext)

            do {
                let importResult = try await importer.importTracks(
                    config: config,
                    progressHandler: { current, total in
                        Task { @MainActor in
                            progress = (current, total)
                        }
                    }
                )

                await MainActor.run {
                    result = importResult
                    isImporting = false
                }
            } catch {
                print("Import failed: \(error)")
                await MainActor.run {
                    // Create a failed result
                    result = PlaylistImportResult(
                        totalTracks: selectedTracks.count,
                        importedCount: 0,
                        skippedExisting: 0,
                        skippedUnavailable: 0,
                        failedCount: selectedTracks.count,
                        createdClips: []
                    )
                    isImporting = false
                }
            }
        }
    }
}
