import SwiftUI
import MusicKit
import MusicService

public struct PlaylistRowView: View {
    let playlist: UserPlaylist

    public init(playlist: UserPlaylist) {
        self.playlist = playlist
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Artwork
            if let artwork = playlist.artwork {
                ArtworkImage(artwork, width: 50, height: 50)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if playlist.trackCount > 0 {
                        Text("\(playlist.trackCount) songs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let curatorName = playlist.curatorName {
                        if playlist.trackCount > 0 {
                            Text("\u{2022}")
                                .foregroundStyle(.secondary)
                        }
                        Text(curatorName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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
