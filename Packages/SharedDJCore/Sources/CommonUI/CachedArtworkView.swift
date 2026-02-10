import SwiftUI
import Core

/// In-memory cache for decoded artwork images
private actor ArtworkCache {
    static let shared = ArtworkCache()

    private var cache: [UUID: UIImage] = [:]

    func image(for id: UUID) -> UIImage? {
        cache[id]
    }

    func setImage(_ image: UIImage, for id: UUID) {
        cache[id] = image
    }
}

/// Displays song artwork with async loading and caching to avoid main thread blocking
public struct CachedArtworkView: View {
    let song: SongClip
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var image: UIImage?

    public init(song: SongClip, size: CGFloat = 44, cornerRadius: CGFloat = 6) {
        self.song = song
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .cornerRadius(cornerRadius)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(white: 0.5))
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.white)
                    }
            }
        }
        .task(id: song.id) {
            await loadImage()
        }
    }

    private func loadImage() async {
        // Check cache first
        if let cached = await ArtworkCache.shared.image(for: song.id) {
            self.image = cached
            return
        }

        // Decode on background thread
        guard let data = song.artworkData else { return }

        let decoded = await Task.detached(priority: .userInitiated) {
            UIImage(data: data)
        }.value

        if let decoded {
            await ArtworkCache.shared.setImage(decoded, for: song.id)
            self.image = decoded
        }
    }
}
