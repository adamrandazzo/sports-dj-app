import SwiftUI
import SwiftData
import Core
import MusicService

public struct SaveSetlistSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Event.sortOrder) private var events: [Event]

    @State private var name = ""
    @State private var description = ""
    @State private var isSaving = false
    @State private var saveResult: SetlistSaveResult?
    @State private var errorMessage: String?

    private var eventsWithSongs: [(event: Event, songCount: Int)] {
        events.compactMap { event in
            guard let pool = event.pool, let songs = pool.songs, !songs.isEmpty else {
                return nil
            }
            return (event: event, songCount: songs.count)
        }
    }

    private var totalSongCount: Int {
        eventsWithSongs.reduce(0) { $0 + $1.songCount }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if let result = saveResult {
                    successView(result)
                } else {
                    formView
                }
            }
            .navigationTitle("Save My Setlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if saveResult == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveSetlist()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || totalSongCount == 0 || isSaving)
                    }
                }
            }
        }
    }

    private var formView: some View {
        Form {
            Section {
                TextField("Setlist Name", text: $name)

                TextField("Description (optional)", text: $description, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Songs to Save") {
                if eventsWithSongs.isEmpty {
                    Text("No songs in any event pools")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(eventsWithSongs, id: \.event.id) { item in
                        HStack {
                            Image(systemName: item.event.icon)
                                .foregroundStyle(item.event.color)
                            Text(item.event.name)
                            Spacer()
                            Text("\(item.songCount) song\(item.songCount == 1 ? "" : "s")")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if totalSongCount > 0 {
                Section {
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(totalSongCount) songs from \(eventsWithSongs.count) events")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func successView(_ result: SetlistSaveResult) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Setlist Saved!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\"\(result.setlist.name)\"")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text("\(result.totalSongs) songs from \(result.eventsWithSongs) events")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }

    private func saveSetlist() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true
        errorMessage = nil

        let manager = SetlistManager(modelContext: modelContext)

        do {
            let result = try manager.saveCurrentPools(name: trimmedName, description: trimmedDescription)
            withAnimation {
                saveResult = result
            }
        } catch {
            errorMessage = "Failed to save setlist: \(error.localizedDescription)"
        }

        isSaving = false
    }
}
