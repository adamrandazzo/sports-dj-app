import SwiftUI
import SwiftData
import Core
import MusicService
import StoreService
import AnalyticsService

/// Detail view for a team - shows players
struct TeamDetailView: View {
    @Bindable var team: Team
    @Environment(\.modelContext) var modelContext
    @Environment(AnnouncerService.self) var announcerService

    @State private var showingAddPlayer = false
    @State private var showingPlayerLimitAlert = false

    var sortedPlayers: [Player] {
        team.orderedPlayers
    }

    var canAddPlayer: Bool {
        ProStatusManager.shared.canAddPlayer(currentCount: team.playerCount)
    }
    
    var maxPlayers: Int {
        ProStatusManager.shared.maxPlayersPerTeam
    }

    var body: some View {
        List {
            Section("Team Name") {
                TextField("Name", text: $team.name)
            }

            Section {
                Picker("Voice", selection: $team.announcer) {
                    ForEach(Announcer.allCases) { announcer in
                        Text(announcer.name).tag(announcer)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    if announcerService.isPlaying {
                        announcerService.stop()
                    } else {
                        announcerService.playPreview(for: team.announcer)
                    }
                } label: {
                    HStack {
                        Image(systemName: announcerService.isPlaying ? "stop.fill" : "play.fill")
                        Text(announcerService.isPlaying ? "Stop Preview" : "Preview \(team.announcer.name)")
                    }
                }
            } header: {
                Text("Announcer")
            } footer: {
                Text("Choose the voice that announces players before their walk-up song.")
            }

            Section("Players (\(team.playerCount))") {
                ForEach(sortedPlayers) { player in
                    NavigationLink {
                        PlayerDetailView(player: player)
                    } label: {
                        HStack {
                            Text("#\(player.number)")
                                .font(.headline.monospacedDigit())
                                .frame(width: 44)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name)
                            }

                            Spacer()
                            
                            HStack(spacing: 8) {
                                // AI announcement indicator
                                if player.playNameAnnouncement && TTSService.shared.hasExistingAnnouncement(for: player) {
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                
                                // Song indicator
                                if player.hasWalkUpSong {
                                    Image(systemName: "music.note")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }

                            if !player.isActive {
                                Text("Inactive")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .onDelete(perform: deletePlayers)
                .onMove(perform: movePlayers)
            }
        }
        .navigationTitle(team.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Player", systemImage: "plus") {
                    if canAddPlayer {
                        showingAddPlayer = true
                    } else {
                        showingPlayerLimitAlert = true
                        AnalyticsService.freeTierLimitHit(feature: "players")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerSheet(team: team)
        }
        .alert("Player Limit Reached", isPresented: $showingPlayerLimitAlert) {
            Button("OK", role: .cancel) {}
            if !ProStatusManager.shared.isPro {
                Button("Upgrade to Pro") {
                    // Navigate to Pro tab or show upgrade
                }
            }
        } message: {
            if ProStatusManager.shared.isPro {
                Text("You've reached the maximum of \(maxPlayers) players per team for Pro.")
            } else {
                Text("You've reached the free tier limit of \(maxPlayers) players per team. Upgrade to Pro for up to 24 players per team.")
            }
        }
    }

    private func deletePlayers(at offsets: IndexSet) {
        for index in offsets {
            let player = sortedPlayers[index]
            modelContext.delete(player)
        }
        try? modelContext.save()
    }

    private func movePlayers(from source: IndexSet, to destination: Int) {
        var players = sortedPlayers
        players.move(fromOffsets: source, toOffset: destination)

        for (index, player) in players.enumerated() {
            player.sortOrder = index
        }
        try? modelContext.save()
    }
}

// MARK: - Add Player Sheet
struct AddPlayerSheet: View {
    let team: Team
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var number = ""

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !number.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Number", text: $number)
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
        }
    }

    private func addPlayer() {
        let player = Player(
            name: name.trimmingCharacters(in: .whitespaces),
            number: number.trimmingCharacters(in: .whitespaces),
            team: team,
            sortOrder: team.playerCount
        )
        modelContext.insert(player)
        try? modelContext.save()
        AnalyticsService.playerAdded()
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Player.self, configurations: config)

    let team = Team(name: "Test Team")
    container.mainContext.insert(team)

    return NavigationStack {
        TeamDetailView(team: team)
    }
    .modelContainer(container)
    .environment(AnnouncerService())
}
