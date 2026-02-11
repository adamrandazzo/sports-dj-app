import SwiftUI
import SwiftData
import Core
import MusicService
import AnalyticsService

/// List of players for walk-up playback
struct PlayerListView: View {
    let team: Team
    @Environment(\.modelContext) var modelContext
    @Environment(GameSession.self) var session
    @Environment(PlayerIntroCoordinator.self) var coordinator

    var activePlayers: [Player] {
        team.activePlayers
    }

    var inactivePlayers: [Player] {
        team.inactivePlayers
    }

    var body: some View {
        if activePlayers.isEmpty && inactivePlayers.isEmpty {
            ContentUnavailableView(
                "No Players",
                systemImage: "figure.baseball",
                description: Text("Add players in Setup")
            )
        } else {
            List {
                // Active players section
                if !activePlayers.isEmpty {
                    Section {
                        ForEach(Array(activePlayers.enumerated()), id: \.element.id) { index, player in
                            PlayerRow(player: player, index: index, totalPlayers: activePlayers.count)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        togglePlayerActive(player)
                                    } label: {
                                        Label("Bench", systemImage: "arrow.down.to.line")
                                    }
                                    .tint(.orange)

                                    Button {
                                        session.setNextPlayer(at: index, playerCount: activePlayers.count)
                                    } label: {
                                        Label("On Deck", systemImage: "figure.baseball")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        Task {
                                            await coordinator.playIntro(for: player, at: index, totalPlayers: activePlayers.count)
                                        }
                                    } label: {
                                        Label("Play", systemImage: "play.fill")
                                    }
                                    .tint(.green)
                                }
                        }
                        .onMove(perform: moveActivePlayers)
                    }
                }

                // Inactive players section
                if !inactivePlayers.isEmpty {
                    Section {
                        ForEach(inactivePlayers) { player in
                            InactivePlayerRow(player: player)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        togglePlayerActive(player)
                                    } label: {
                                        Label("Activate", systemImage: "arrow.up.to.line")
                                    }
                                    .tint(.green)
                                }
                        }
                    } header: {
                        Text("Inactive")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func togglePlayerActive(_ player: Player) {
        player.isActive.toggle()
        try? modelContext.save()
    }

    private func moveActivePlayers(from source: IndexSet, to destination: Int) {
        var players = activePlayers
        players.move(fromOffsets: source, toOffset: destination)

        // Update sortOrder for all players
        for (index, player) in players.enumerated() {
            player.sortOrder = index
        }

        try? modelContext.save()
        AnalyticsService.battingOrderChanged()
    }
}

// MARK: - Inactive Player Row
struct InactivePlayerRow: View {
    let player: Player

    var body: some View {
        HStack(spacing: 12) {
            // Number badge (muted)
            Text(player.number)
                .font(.system(.subheadline, design: .rounded).monospacedDigit())
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.15))
                .foregroundStyle(.secondary)
                .clipShape(Circle())

            // Player info
            Text(player.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Swipe hint
            Image(systemName: "arrow.up.to.line")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Player Row
struct PlayerRow: View {
    let player: Player
    let index: Int
    let totalPlayers: Int

    @Environment(\.editMode) var editMode
    @Environment(PlayerIntroCoordinator.self) var coordinator
    @Environment(GameSession.self) var session

    var isCurrentBatter: Bool {
        session.currentPlayer?.id == player.id
    }

    var isNextBatter: Bool {
        session.isNextPlayer(at: index, playerCount: totalPlayers)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Next batter indicator (green dot)
            Circle()
                .fill(isNextBatter ? Color.green : Color.clear)
                .frame(width: 8, height: 8)

            // Number badge
            Text(player.number)
                .font(.system(.headline, design: .rounded).monospacedDigit())
                .frame(width: 40, height: 40)
                .background(isCurrentBatter ? Color.accentColor : Color.accentColor.opacity(0.15))
                .foregroundStyle(isCurrentBatter ? .white : .primary)
                .clipShape(Circle())

            // Player info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    if let song = player.walkUpSong {
                        Text("\(song.artist) - \(song.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No walk-up song")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
            
            if editMode?.wrappedValue != .active {
                // Indicators for announcements and song
                HStack(spacing: 8) {
                    // AI announcement indicator
                    if player.playNameAnnouncement && TTSService.shared.hasExistingAnnouncement(for: player) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    // Song indicator
                    if player.walkUpSong != nil {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                // Play/Stop button
                Button {
                    if coordinator.isPlaying && isCurrentBatter {
                        coordinator.stop()
                    } else {
                        Task {
                            await coordinator.playIntro(for: player, at: index, totalPlayers: totalPlayers)
                        }
                    }
                } label: {
                    Image(systemName: coordinator.isPlaying && isCurrentBatter ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .disabled(!player.hasWalkUpSong && !coordinator.isAnnouncerEnabled)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Player.self, configurations: config)

    let team = Team(name: "Test Team")
    container.mainContext.insert(team)

    let player = Player(name: "John Smith", number: "7", team: team)
    container.mainContext.insert(player)

    let session = GameSession()
    return PlayerListView(team: team)
        .modelContainer(container)
        .environment(session)
        .environment(PlayerIntroCoordinator(
            announcer: AnnouncerService(),
            audioPlayer: AudioPlayerService.shared,
            session: session
        ))
}
