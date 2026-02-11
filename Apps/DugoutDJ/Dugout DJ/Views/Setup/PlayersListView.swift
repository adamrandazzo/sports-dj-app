import SwiftUI
import SwiftData
import Core
import MusicService

/// View showing all players grouped by team
struct PlayersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Team.sortOrder) private var teams: [Team]
    @Query private var allPlayers: [Player]

    @State private var showingAddPlayer = false
    @State private var showingPlayerLimitAlert = false

    var body: some View {
        List {
            if teams.isEmpty && allPlayers.isEmpty {
                ContentUnavailableView(
                    "No Players",
                    systemImage: "person.slash",
                    description: Text("Add teams and players to get started")
                )
            } else {
                // Show players grouped by team
                ForEach(teams) { team in
                    if !team.orderedPlayers.isEmpty {
                        Section {
                            ForEach(team.orderedPlayers) { player in
                                NavigationLink {
                                    PlayerDetailView(player: player)
                                } label: {
                                    PlayersListRow(player: player)
                                }
                            }
                            .onDelete { offsets in
                                deletePlayers(from: team.orderedPlayers, at: offsets)
                            }
                        } header: {
                            Text(team.name)
                        }
                    }
                }

                // Show unassigned players (players with no team)
                let unassignedPlayers = allPlayers.filter { $0.team == nil }.sorted { $0.name < $1.name }
                if !unassignedPlayers.isEmpty {
                    Section {
                        ForEach(unassignedPlayers) { player in
                            NavigationLink {
                                PlayerDetailView(player: player)
                            } label: {
                                PlayersListRow(player: player)
                            }
                        }
                        .onDelete { offsets in
                            deletePlayers(from: unassignedPlayers, at: offsets)
                        }
                    } header: {
                        Text("Unassigned")
                    }
                }
            }
        }
        .navigationTitle("Players")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Player", systemImage: "plus") {
                    if teams.isEmpty {
                        // No teams to add to
                        showingPlayerLimitAlert = true
                    } else {
                        showingAddPlayer = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerToTeamSheet(teams: teams)
        }
        .alert("No Teams", isPresented: $showingPlayerLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Create a team first before adding players.")
        }
    }

    private func deletePlayers(from players: [Player], at offsets: IndexSet) {
        for index in offsets {
            let player = players[index]
            modelContext.delete(player)
        }
        try? modelContext.save()
    }
}

// MARK: - Add Player to Team Sheet
private struct AddPlayerToTeamSheet: View {
    let teams: [Team]
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var number = ""
    @State private var selectedTeam: Team?

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !number.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedTeam != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Team", selection: $selectedTeam) {
                        Text("Select a team").tag(nil as Team?)
                        ForEach(teams) { team in
                            Text(team.name).tag(team as Team?)
                        }
                    }
                }

                Section {
                    TextField("Name", text: $name)
                    TextField("Number", text: Binding(
                        get: { number },
                        set: { number = String($0.filter { $0.isNumber }.prefix(2)) }
                    ))
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        addPlayer()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if teams.count == 1 {
                    selectedTeam = teams.first
                }
            }
        }
    }

    private func addPlayer() {
        guard let team = selectedTeam else { return }
        let player = Player(
            name: name.trimmingCharacters(in: .whitespaces),
            number: number.trimmingCharacters(in: .whitespaces),
            team: team,
            sortOrder: team.playerCount
        )
        modelContext.insert(player)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Player Row
private struct PlayersListRow: View {
    let player: Player

    var body: some View {
        HStack(spacing: 12) {
            // Number badge
            Text(player.number.isEmpty ? "-" : player.number)
                .font(.headline.monospacedDigit())
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.2))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.body)

                if !player.isActive {
                    Text("Inactive")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // AI announcement indicator
                if player.playNameAnnouncement && TTSService.shared.hasExistingAnnouncement(for: player) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                // Walk-up song indicator
                if player.hasWalkUpSong {
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Player.self, SongClip.self, configurations: config)

    let team1 = Team(name: "Tigers", sortOrder: 0)
    container.mainContext.insert(team1)

    let player1 = Player(name: "John Smith", number: "7", team: team1, sortOrder: 0)
    let player2 = Player(name: "Mike Johnson", number: "12", team: team1, sortOrder: 1)
    container.mainContext.insert(player1)
    container.mainContext.insert(player2)

    let team2 = Team(name: "Cubs", sortOrder: 1)
    container.mainContext.insert(team2)

    let player3 = Player(name: "Dave Williams", number: "3", team: team2, sortOrder: 0)
    container.mainContext.insert(player3)

    return NavigationStack {
        PlayersListView()
    }
    .modelContainer(container)
    .environment(AnnouncerService())
}
