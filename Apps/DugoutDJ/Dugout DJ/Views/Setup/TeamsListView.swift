import SwiftUI
import SwiftData
import Core
import StoreService
import AnalyticsService

/// List of teams
struct TeamsListView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Team.sortOrder) var teams: [Team]

    @State private var showingAddTeam = false
    @State private var newTeamName = ""

    var canAddTeam: Bool {
        ProStatusManager.shared.canAddTeam(currentCount: teams.count)
    }

    var body: some View {
        List {
            ForEach(teams) { team in
                NavigationLink {
                    TeamDetailView(team: team)
                } label: {
                    HStack {
                        Text(team.name)
                        Spacer()
                        Text("\(team.playerCount) player\(team.playerCount == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteTeams)
            .onMove(perform: moveTeams)

            if !canAddTeam {
                UpgradePromptRow(message: "Upgrade to Pro for up to 3 teams")
                    .onAppear { AnalyticsService.freeTierLimitHit(feature: "teams") }
            }
        }
        .navigationTitle("Teams")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Team", systemImage: "plus") {
                    showingAddTeam = true
                }
                .disabled(!canAddTeam)
            }

            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .alert("New Team", isPresented: $showingAddTeam) {
            TextField("Team Name", text: $newTeamName)
            Button("Cancel", role: .cancel) {
                newTeamName = ""
            }
            Button("Add") {
                addTeam()
            }
            .disabled(newTeamName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addTeam() {
        let name = newTeamName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let team = Team(name: name, sortOrder: teams.count)
        modelContext.insert(team)
        try? modelContext.save()
        AnalyticsService.teamCreated()

        newTeamName = ""
    }

    private func deleteTeams(at offsets: IndexSet) {
        for index in offsets {
            let team = teams[index]
            modelContext.delete(team)
        }
        try? modelContext.save()
    }

    private func moveTeams(from source: IndexSet, to destination: Int) {
        var reorderedTeams = teams
        reorderedTeams.move(fromOffsets: source, toOffset: destination)

        for (index, team) in reorderedTeams.enumerated() {
            team.sortOrder = index
        }
        try? modelContext.save()
    }
}

// MARK: - Upgrade Prompt Row
struct UpgradePromptRow: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        TeamsListView()
    }
    .modelContainer(for: [Team.self, Player.self], inMemory: true)
}
