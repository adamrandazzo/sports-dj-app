import Foundation
import SwiftData

@Model
public final class EventPool {
    public var id: UUID = UUID()
    public var event: Event?

    @Relationship(inverse: \SongClip.pools)
    public var songs: [SongClip]?

    public var sortOrder: [UUID] = []

    public init(
        id: UUID = UUID(),
        event: Event? = nil,
        songs: [SongClip] = [],
        sortOrder: [UUID] = []
    ) {
        self.id = id
        self.event = event
        self.songs = songs
        self.sortOrder = sortOrder
    }

    public var songsArray: [SongClip] {
        get { songs ?? [] }
        set { songs = newValue }
    }

    public var orderedSongs: [SongClip] {
        var result: [SongClip] = []

        for songID in sortOrder {
            if let song = songsArray.first(where: { $0.id == songID }) {
                result.append(song)
            }
        }

        for song in songsArray {
            if !sortOrder.contains(song.id) {
                result.append(song)
            }
        }

        return result
    }

    public func addSong(_ song: SongClip) {
        guard !songsArray.contains(where: { $0.id == song.id }) else { return }
        songsArray.append(song)
        sortOrder.append(song.id)
    }

    public func removeSong(_ song: SongClip) {
        songsArray.removeAll { $0.id == song.id }
        sortOrder.removeAll { $0 == song.id }
    }

    public func moveSong(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0 && sourceIndex < sortOrder.count,
              destinationIndex >= 0 && destinationIndex <= sortOrder.count else {
            return
        }

        let songID = sortOrder.remove(at: sourceIndex)
        let adjustedDestination = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        sortOrder.insert(songID, at: adjustedDestination)
    }
}
