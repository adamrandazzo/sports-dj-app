import SwiftUI
import Core
import AnalyticsService

public struct GameHistoryView: View {
    @Environment(GameSession.self) private var gameSession

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if gameSession.isActive {
                    activeGameView
                } else {
                    inactiveGameView
                }
            }
            .navigationTitle("Game")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Inactive State

    private var inactiveGameView: some View {
        ContentUnavailableView {
            Label("No Game in Progress", systemImage: "sportscourt")
        } description: {
            Text("Start a game to track played songs")
        } actions: {
            Button {
                gameSession.newGame()
                AnalyticsService.gameStarted()
            } label: {
                Label("Start Game", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Active State

    private var activeGameView: some View {
        VStack(spacing: 0) {
            // Game status header
            gameStatusHeader

            Divider()

            // Song history list
            if gameSession.songHistory.isEmpty {
                ContentUnavailableView {
                    Label("No Songs Played", systemImage: "music.note")
                } description: {
                    Text("Tap events in the DJ tab to play songs")
                }
            } else {
                songHistoryList
            }
        }
    }

    private var gameStatusHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Game in Progress")
                    .font(.headline)

                Text("\(gameSession.totalSongsPlayed) songs played")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                let duration: Int
                if let startedAt = gameSession.startedAt {
                    duration = Int(Date().timeIntervalSince(startedAt))
                } else {
                    duration = 0
                }
                let songsPlayed = gameSession.totalSongsPlayed
                gameSession.endGame()
                AnalyticsService.gameEnded(durationSeconds: duration, songsPlayed: songsPlayed)
            } label: {
                Label("End Game", systemImage: "flag.checkered")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var songHistoryList: some View {
        List {
            Section("Songs Played") {
                ForEach(gameSession.songHistory.reversed()) { entry in
                    SongHistoryRow(entry: entry)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Song History Row

public struct SongHistoryRow: View {
    let entry: PlayedSongEntry

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    public init(entry: PlayedSongEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Artwork
            CachedArtworkView(song: entry.clip)

            // Song info and event
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.clip.title)
                    .font(.body)
                    .lineLimit(1)

                Text(entry.clip.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Event indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.eventColor)
                        .frame(width: 8, height: 8)

                    Text(entry.eventName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Timestamp
            Text(timeFormatter.string(from: entry.playedAt))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
