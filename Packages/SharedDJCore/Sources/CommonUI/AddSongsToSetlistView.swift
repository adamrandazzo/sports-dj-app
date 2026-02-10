import SwiftUI
import SwiftData
import Core
import MusicService

public struct AddSongsToSetlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var setlist: Setlist
    @Query(sort: \SongClip.dateAdded, order: .reverse) private var allSongs: [SongClip]
    @Query(sort: \Event.sortOrder) private var events: [Event]

    @State private var selectedSongs: Set<UUID> = []
    @State private var selectedEventCode: String?
    @State private var searchText = ""

    // Songs not already in the setlist
    private var availableSongs: [SongClip] {
        let existingIDs = Set((setlist.entries ?? []).compactMap { $0.song?.id })
        return allSongs.filter { !existingIDs.contains($0.id) }
    }

    private var filteredSongs: [SongClip] {
        guard !searchText.isEmpty else { return availableSongs }
        return availableSongs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }

    public init(setlist: Setlist) {
        self.setlist = setlist
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Event assignment picker
                if !selectedSongs.isEmpty {
                    eventPicker
                        .padding()
                        .background(Color(.secondarySystemBackground))
                }

                if availableSongs.isEmpty {
                    ContentUnavailableView {
                        Label("No Songs Available", systemImage: "music.note")
                    } description: {
                        Text("All songs are already in this setlist, or your library is empty.")
                    }
                } else {
                    List(filteredSongs, selection: $selectedSongs) { song in
                        SongSelectionRow(song: song, isSelected: selectedSongs.contains(song.id))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(song.id)
                            }
                    }
                    .listStyle(.plain)
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search songs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedSongs.count)") {
                        addSelectedSongs()
                    }
                    .disabled(selectedSongs.isEmpty)
                }
            }
        }
    }

    private var eventPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assign to Event (optional)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // None option
                    Button {
                        selectedEventCode = nil
                    } label: {
                        Text("None")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedEventCode == nil ? Color.accentColor : Color(.tertiarySystemFill))
                            .foregroundStyle(selectedEventCode == nil ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    ForEach(events.filter { !$0.code.isEmpty }) { event in
                        Button {
                            selectedEventCode = event.code
                        } label: {
                            Label(event.name, systemImage: event.icon)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedEventCode == event.code ? event.color : Color(.tertiarySystemFill))
                                .foregroundStyle(selectedEventCode == event.code ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedSongs.contains(id) {
            selectedSongs.remove(id)
        } else {
            selectedSongs.insert(id)
        }
    }

    private func addSelectedSongs() {
        let manager = SetlistManager(modelContext: modelContext)

        for songID in selectedSongs {
            if let song = allSongs.first(where: { $0.id == songID }) {
                try? manager.addSong(song, to: setlist, eventCode: selectedEventCode)
            }
        }

        dismiss()
    }
}

// MARK: - Song Selection Row

public struct SongSelectionRow: View {
    let song: SongClip
    let isSelected: Bool

    public init(song: SongClip, isSelected: Bool) {
        self.song = song
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

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
        }
    }
}
