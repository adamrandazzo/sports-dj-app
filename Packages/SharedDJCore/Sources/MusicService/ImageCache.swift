import SwiftUI
import Core

public actor ImageCache {
    public static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImageCache", isDirectory: true)
        self.cacheDirectory = cacheDir
        memoryCache.countLimit = 100
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    public func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)

        // Check memory
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // Check disk
        let filePath = cacheDirectory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: filePath),
           let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: key as NSString)
            return image
        }

        // Download
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            return nil
        }

        // Save to memory and disk
        memoryCache.setObject(image, forKey: key as NSString)
        try? data.write(to: filePath)

        return image
    }

    private func cacheKey(for url: URL) -> String {
        url.absoluteString.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
    }
}

public struct CachedAsyncImage<Placeholder: View>: View {
    public let url: URL?
    public let placeholder: () -> Placeholder

    @State private var image: UIImage?

    public init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
    }

    public var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            image = await ImageCache.shared.image(for: url)
        }
    }
}
