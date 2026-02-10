import SwiftUI
import Core

public struct SavedSetlistRowView: View {
    let setlist: Setlist

    public init(setlist: Setlist) {
        self.setlist = setlist
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Artwork or fallback icon
            if let artworkData = setlist.artworkData,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(setlist.isRemote ? Color.orange.opacity(0.2) : Color.purple.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: setlist.isRemote ? "star.circle.fill" : "music.note.list")
                            .font(.title2)
                            .foregroundStyle(setlist.isRemote ? .orange : .purple)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(setlist.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(setlist.songCount)", systemImage: "music.note")

                    if setlist.assignedSongCount > 0 {
                        Label("\(setlist.assignedSongCount) assigned", systemImage: "star.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let lastSynced = setlist.lastSyncedAt, setlist.isRemote {
                    Text("Synced \(lastSynced.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Updated \(setlist.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
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
