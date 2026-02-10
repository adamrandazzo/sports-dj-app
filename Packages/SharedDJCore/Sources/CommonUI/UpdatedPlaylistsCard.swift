import SwiftUI
import Core
import MusicService

public struct UpdatedPlaylistsCard: View {
    let playlist: RemotePlaylistSummary

    public init(playlist: RemotePlaylistSummary) {
        self.playlist = playlist
    }

    public var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Artwork
            CachedAsyncImage(url: URL(string: playlist.artworkURL ?? "")) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.orange.opacity(0.2))
                    .overlay {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.orange)
                    }
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

            // Name
            Text(playlist.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Description
            Text(playlist.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 24)

            // Song count
            if let songCount = playlist.songCount {
                Label("\(songCount) songs", systemImage: "music.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.top, 24)
    }
}
