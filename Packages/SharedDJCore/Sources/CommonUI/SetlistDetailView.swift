import SwiftUI
import SwiftData
import Core

public struct SetlistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var setlist: Setlist
    @Query private var events: [Event]

    @State private var showingLoadSheet = false
    @State private var showingAddSongs = false
    @State private var showingRenameAlert = false
    @State private var showingDeleteConfirm = false
    @State private var newName = ""
    @State private var editMode: EditMode = .inactive

    private var eventsByCode: [String: Event] {
        Dictionary(uniqueKeysWithValues: events.compactMap { event in
            event.code.isEmpty ? nil : (event.code, event)
        })
    }

    // Group entries by event code
    private var entriesByEvent: [(eventCode: String?, eventName: String, entries: [SetlistEntry])] {
        let grouped = Dictionary(grouping: setlist.orderedEntries) { $0.eventCode }

        var result: [(eventCode: String?, eventName: String, entries: [SetlistEntry])] = []

        // Add entries with event codes first, sorted by event name
        let codesWithEntries = grouped.keys.compactMap { $0 }.sorted { code1, code2 in
            let name1 = eventsByCode[code1]?.name ?? code1
            let name2 = eventsByCode[code2]?.name ?? code2
            return name1 < name2
        }

        for code in codesWithEntries {
            if let entries = grouped[code] {
                let eventName = eventsByCode[code]?.name ?? code
                result.append((eventCode: code, eventName: eventName, entries: entries))
            }
        }

        // Add entries without event codes last
        if let unassignedEntries = grouped[nil], !unassignedEntries.isEmpty {
            result.append((eventCode: nil, eventName: "Library Only", entries: unassignedEntries))
        }

        return result
    }

    public init(setlist: Setlist) {
        self.setlist = setlist
    }

    public var body: some View {
        List {
            // Header Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if setlist.isRemote {
                            Label("Curated Setlist", systemImage: "star.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                    }

                    if !setlist.setlistDescription.isEmpty {
                        Text(setlist.setlistDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("\(setlist.songCount) songs", systemImage: "music.note")
                        Spacer()
                        if setlist.assignedSongCount > 0 {
                            Label("\(setlist.assignedSongCount) assigned to events", systemImage: "star.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Load Button Section
            Section {
                Button {
                    showingLoadSheet = true
                } label: {
                    Label("Load this Setlist", systemImage: "square.and.arrow.up")
                }
                .disabled(setlist.songCount == 0)
            }

            // Songs by Event
            ForEach(entriesByEvent, id: \.eventCode) { group in
                Section {
                    ForEach(group.entries) { entry in
                        if let song = entry.song {
                            SetlistEntryRowView(entry: entry, song: song)
                        }
                    }
                    .onDelete { indexSet in
                        deleteEntries(at: indexSet, from: group.entries)
                    }
                    .onMove { source, destination in
                        // Only allow reordering within same event group
                    }
                } header: {
                    HStack {
                        if let code = group.eventCode, let event = eventsByCode[code] {
                            Image(systemName: event.icon)
                                .foregroundStyle(event.color)
                        } else if group.eventCode == nil {
                            Image(systemName: "music.note.list")
                                .foregroundStyle(.secondary)
                        }
                        Text(group.eventName)
                    }
                }
            }

            // Add Songs Section (only for local setlists)
            if !setlist.isRemote {
                Section {
                    Button {
                        showingAddSongs = true
                    } label: {
                        Label("Add Songs", systemImage: "plus")
                    }
                }
            }
        }
        .navigationTitle(setlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingLoadSheet = true
                    } label: {
                        Label("Load this Setlist", systemImage: "square.and.arrow.up")
                    }
                    .disabled(setlist.songCount == 0)

                    if !setlist.isRemote {
                        Button {
                            showingAddSongs = true
                        } label: {
                            Label("Add Songs", systemImage: "plus")
                        }
                    }

                    Divider()

                    Button {
                        newName = setlist.name
                        showingRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Setlist", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingLoadSheet) {
            LoadSetlistSheet(setlist: setlist)
        }
        .sheet(isPresented: $showingAddSongs) {
            AddSongsToSetlistView(setlist: setlist)
        }
        .alert("Rename Setlist", isPresented: $showingRenameAlert) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if !newName.isEmpty {
                    setlist.name = newName
                    setlist.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        }
        .alert("Delete Setlist?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                modelContext.delete(setlist)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("This will delete the setlist. Songs will remain in your library.")
        }
    }

    private func deleteEntries(at offsets: IndexSet, from entries: [SetlistEntry]) {
        for index in offsets {
            let entry = entries[index]
            modelContext.delete(entry)
        }
        setlist.updatedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Entry Row View

public struct SetlistEntryRowView: View {
    let entry: SetlistEntry
    let song: SongClip

    public init(entry: SetlistEntry, song: SongClip) {
        self.entry = entry
        self.song = song
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artworkData = song.artworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: song.sourceType == .appleMusic ? "applelogo" : "music.note")
                            .foregroundStyle(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            Text(formatDuration(song.clipDuration))
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
