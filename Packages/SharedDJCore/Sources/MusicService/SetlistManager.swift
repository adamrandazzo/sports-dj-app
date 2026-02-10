import Foundation
import SwiftData
import Core

/// Mode for loading a setlist into event pools
public enum SetlistLoadMode: String, CaseIterable {
    case addToExisting = "Add to Existing"
    case replaceAll = "Replace All"

    public var description: String {
        switch self {
        case .addToExisting:
            return "Add songs to existing event pools"
        case .replaceAll:
            return "Clear event pools before adding"
        }
    }
}

/// Result of loading a setlist
public struct SetlistLoadResult {
    public let setlistName: String
    public let totalSongs: Int
    public let assignedToEvents: Int
    public let addedToLibraryOnly: Int
    public let skippedMissingEvents: Int

    public init(
        setlistName: String,
        totalSongs: Int,
        assignedToEvents: Int,
        addedToLibraryOnly: Int,
        skippedMissingEvents: Int
    ) {
        self.setlistName = setlistName
        self.totalSongs = totalSongs
        self.assignedToEvents = assignedToEvents
        self.addedToLibraryOnly = addedToLibraryOnly
        self.skippedMissingEvents = skippedMissingEvents
    }
}

/// Result of saving current pools as a setlist
public struct SetlistSaveResult {
    public let setlist: Setlist
    public let totalSongs: Int
    public let eventsWithSongs: Int

    public init(setlist: Setlist, totalSongs: Int, eventsWithSongs: Int) {
        self.setlist = setlist
        self.totalSongs = totalSongs
        self.eventsWithSongs = eventsWithSongs
    }
}

/// Service for managing setlist operations
public final class SetlistManager {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Save Current Pools

    /// Save current event pools as a new setlist
    public func saveCurrentPools(name: String, description: String = "") throws -> SetlistSaveResult {
        // Fetch all events with their pools
        let descriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let events = try modelContext.fetch(descriptor)

        // Create new setlist
        let setlist = Setlist(name: name, description: description)
        modelContext.insert(setlist)

        var totalSongs = 0
        var eventsWithSongs = 0
        var sortOrder = 0

        // Iterate through events and add their songs
        for event in events {
            guard let pool = event.pool, let songs = pool.songs, !songs.isEmpty else {
                continue
            }

            eventsWithSongs += 1

            // Add each song as a setlist entry with event code
            for song in pool.orderedSongs {
                let entry = SetlistEntry(
                    setlist: setlist,
                    song: song,
                    eventCode: event.code,
                    sortOrder: sortOrder
                )
                modelContext.insert(entry)
                sortOrder += 1
                totalSongs += 1
            }
        }

        setlist.updatedAt = Date()
        try modelContext.save()

        return SetlistSaveResult(
            setlist: setlist,
            totalSongs: totalSongs,
            eventsWithSongs: eventsWithSongs
        )
    }

    // MARK: - Load Setlist

    /// Load a setlist into event pools
    public func loadSetlist(_ setlist: Setlist, mode: SetlistLoadMode) throws -> SetlistLoadResult {
        // Fetch all events for matching
        let eventDescriptor = FetchDescriptor<Event>()
        let events = try modelContext.fetch(eventDescriptor)
        let eventsByCode = Dictionary(uniqueKeysWithValues: events.compactMap { event in
            event.code.isEmpty ? nil : (event.code, event)
        })

        // Clear existing pools if replace mode
        if mode == .replaceAll {
            for event in events {
                if let pool = event.pool {
                    pool.songs = []
                    pool.sortOrder = []
                }
            }
        }

        var assignedToEvents = 0
        var addedToLibraryOnly = 0
        var skippedMissingEvents = 0

        // Process each entry
        for entry in setlist.orderedEntries {
            guard let song = entry.song else { continue }

            if let eventCode = entry.eventCode, !eventCode.isEmpty {
                // Has event assignment
                if let event = eventsByCode[eventCode], let pool = event.pool {
                    // Check if song already in pool (for add mode)
                    if mode == .addToExisting {
                        let alreadyInPool = pool.songs?.contains(where: { $0.id == song.id }) ?? false
                        if alreadyInPool {
                            continue
                        }
                    }
                    pool.addSong(song)
                    assignedToEvents += 1
                } else {
                    // Event code doesn't match any event
                    skippedMissingEvents += 1
                }
            } else {
                // No event assignment - song is just in library
                addedToLibraryOnly += 1
            }
        }

        try modelContext.save()

        return SetlistLoadResult(
            setlistName: setlist.name,
            totalSongs: setlist.songCount,
            assignedToEvents: assignedToEvents,
            addedToLibraryOnly: addedToLibraryOnly,
            skippedMissingEvents: skippedMissingEvents
        )
    }

    // MARK: - CRUD Operations

    /// Create a new empty setlist
    public func createSetlist(name: String, description: String = "") throws -> Setlist {
        let setlist = Setlist(name: name, description: description)
        modelContext.insert(setlist)
        try modelContext.save()
        return setlist
    }

    /// Add a song to a setlist
    public func addSong(_ song: SongClip, to setlist: Setlist, eventCode: String? = nil) throws {
        let sortOrder = setlist.songCount
        let entry = SetlistEntry(
            setlist: setlist,
            song: song,
            eventCode: eventCode,
            sortOrder: sortOrder
        )
        modelContext.insert(entry)
        setlist.updatedAt = Date()
        try modelContext.save()
    }

    /// Remove an entry from a setlist
    public func removeEntry(_ entry: SetlistEntry) throws {
        if let setlist = entry.setlist {
            setlist.updatedAt = Date()
        }
        modelContext.delete(entry)
        try modelContext.save()
    }

    /// Update entry's event assignment
    public func updateEventCode(for entry: SetlistEntry, eventCode: String?) throws {
        entry.eventCode = eventCode
        if let setlist = entry.setlist {
            setlist.updatedAt = Date()
        }
        try modelContext.save()
    }

    /// Reorder entries in a setlist
    public func reorderEntries(_ entries: [SetlistEntry]) throws {
        for (index, entry) in entries.enumerated() {
            entry.sortOrder = index
        }
        if let setlist = entries.first?.setlist {
            setlist.updatedAt = Date()
        }
        try modelContext.save()
    }

    /// Delete a setlist
    public func deleteSetlist(_ setlist: Setlist) throws {
        modelContext.delete(setlist)
        try modelContext.save()
    }

    /// Rename a setlist
    public func renameSetlist(_ setlist: Setlist, to name: String) throws {
        setlist.name = name
        setlist.updatedAt = Date()
        try modelContext.save()
    }
}
