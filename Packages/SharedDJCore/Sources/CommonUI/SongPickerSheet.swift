import SwiftUI
import Core

/// Sheet for manually selecting a song from an event's pool
public struct SongPickerSheet: View {
    let event: Event
    let songs: [SongClip]
    let playedSongIDs: Set<UUID>
    let onSelect: (SongClip) -> Void

    @Environment(\.dismiss) private var dismiss

    public init(event: Event, songs: [SongClip], playedSongIDs: Set<UUID>, onSelect: @escaping (SongClip) -> Void) {
        self.event = event
        self.songs = songs
        self.playedSongIDs = playedSongIDs
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(songs) { song in
                    SongPickerRow(
                        song: song,
                        hasBeenPlayed: playedSongIDs.contains(song.id),
                        onTap: {
                            onSelect(song)
                            dismiss()
                        }
                    )
                }
            }
            .navigationTitle("Pick a Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Row for displaying a song in the picker
private struct SongPickerRow: View {
    let song: SongClip
    let hasBeenPlayed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Artwork (async loaded with caching)
                CachedArtworkView(song: song)

                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.body)
                        .foregroundStyle(hasBeenPlayed ? .secondary : .primary)
                        .lineLimit(1)

                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Played indicator
                if hasBeenPlayed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
