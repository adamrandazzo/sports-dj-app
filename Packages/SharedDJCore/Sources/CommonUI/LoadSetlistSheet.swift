import SwiftUI
import SwiftData
import Core
import MusicService

public struct LoadSetlistSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let setlist: Setlist

    @Query(sort: \Event.sortOrder) private var events: [Event]

    @State private var loadMode: SetlistLoadMode = .addToExisting
    @State private var isLoading = false
    @State private var loadResult: SetlistLoadResult?
    @State private var errorMessage: String?
    @State private var showingSaveFirst = false

    private var eventsByCode: [String: Event] {
        Dictionary(uniqueKeysWithValues: events.compactMap { event in
            event.code.isEmpty ? nil : (event.code, event)
        })
    }

    private var hasExistingSongs: Bool {
        events.contains { event in
            guard let pool = event.pool, let songs = pool.songs else { return false }
            return !songs.isEmpty
        }
    }

    public init(setlist: Setlist) {
        self.setlist = setlist
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let result = loadResult {
                    successView(result)
                } else {
                    configView
                }
            }
            .navigationTitle("Load Setlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if loadResult == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Load") {
                            loadSetlist()
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .sheet(isPresented: $showingSaveFirst) {
                SaveSetlistSheet()
            }
        }
    }

    private var configView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(setlist.name)
                        .font(.headline)

                    HStack {
                        Label("\(setlist.songCount) songs", systemImage: "music.note")
                        Spacer()
                        if setlist.assignedSongCount > 0 {
                            Label("\(setlist.assignedSongCount) with events", systemImage: "star.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Load Mode") {
                Picker("Mode", selection: $loadMode) {
                    ForEach(SetlistLoadMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(loadMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if loadMode == .replaceAll && hasExistingSongs {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("This will clear your current setlist")
                                .font(.subheadline)
                        }

                        Button {
                            showingSaveFirst = true
                        } label: {
                            Label("Save My Setlist First", systemImage: "square.and.arrow.down")
                        }
                    }
                }
            }

            // Preview event assignments
            Section("Event Assignments") {
                let grouped = Dictionary(grouping: setlist.orderedEntries.filter { $0.eventCode != nil }) { $0.eventCode! }

                if grouped.isEmpty {
                    Text("No songs have event assignments")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(grouped.keys.sorted(), id: \.self) { code in
                        if let entries = grouped[code] {
                            HStack {
                                if let event = eventsByCode[code] {
                                    Image(systemName: event.icon)
                                        .foregroundStyle(event.color)
                                    Text(event.name)
                                } else {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundStyle(.orange)
                                    Text(code)
                                        .foregroundStyle(.secondary)
                                    Text("(unknown)")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                                Spacer()
                                Text("\(entries.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                let unassignedCount = setlist.orderedEntries.filter { $0.eventCode == nil }.count
                if unassignedCount > 0 {
                    HStack {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(.secondary)
                        Text("Library only")
                        Spacer()
                        Text("\(unassignedCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func successView(_ result: SetlistLoadResult) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Setlist Loaded!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\"\(result.setlistName)\"")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                if result.assignedToEvents > 0 {
                    Label("\(result.assignedToEvents) songs assigned to events", systemImage: "star.fill")
                        .foregroundStyle(.orange)
                }

                if result.addedToLibraryOnly > 0 {
                    Label("\(result.addedToLibraryOnly) songs in library only", systemImage: "music.note")
                        .foregroundStyle(.secondary)
                }

                if result.skippedMissingEvents > 0 {
                    Label("\(result.skippedMissingEvents) skipped (unknown events)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.subheadline)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }

    private func loadSetlist() {
        isLoading = true
        errorMessage = nil

        let manager = SetlistManager(modelContext: modelContext)

        do {
            let result = try manager.loadSetlist(setlist, mode: loadMode)
            withAnimation {
                loadResult = result
            }
        } catch {
            errorMessage = "Failed to load setlist: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
