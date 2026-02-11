import SwiftUI
import SwiftData
import Core
import MusicService
import CommonUI

/// Main Walk Up tab - shows player list with next batter tracking
struct WalkUpView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(GameSession.self) var session
    @Environment(PlayerIntroCoordinator.self) var coordinator
    @Environment(AudioPlayerService.self) var audioPlayer

    @Query(sort: \Team.sortOrder) var teams: [Team]
    @State private var selectedTeam: Team?
    @State private var editMode: EditMode = .inactive
    @AppStorage("selectedTeamID") private var selectedTeamID: String = ""
    @CloudStorage("hasSeenQuickStart") private var hasSeenQuickStart = false

    var currentTeam: Team? {
        selectedTeam ?? teams.first
    }

    var activePlayers: [Player] {
        currentTeam?.activePlayers ?? []
    }

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    if let team = currentTeam {
                        // Player list with drag-to-reorder
                        PlayerListView(team: team)
                    } else {
                        // Empty state: No teams configured
                        ContentUnavailableView(
                            "No Teams",
                            systemImage: "tshirt.fill",
                            description: Text("Add a team in Setup to get started")
                        )
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .environment(\.editMode, $editMode)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if let team = currentTeam {
                            if teams.count > 1 {
                                Menu {
                                    ForEach(teams) { t in
                                        Button {
                                            selectedTeam = t
                                        } label: {
                                            HStack {
                                                Text(t.name)
                                                if t.id == currentTeam?.id {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    teamBadge(for: team)
                                }
                            } else {
                                teamBadge(for: team)
                            }
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("ULTIMATE DUGOUT DJ")
                            .font(.custom("BebasNeue-Regular", size: 20))
                            .tracking(1)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if currentTeam != nil && !activePlayers.isEmpty {
                            Button {
                                withAnimation {
                                    editMode = editMode == .active ? .inactive : .active
                                }
                            } label: {
                                Image(systemName: editMode == .active ? "checkmark.circle.fill" : "arrow.up.arrow.down")
                                    .foregroundStyle(editMode == .active ? .green : .blue)
                            }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if !activePlayers.isEmpty {
                        NextBatterBar(activePlayers: activePlayers)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: coordinator.isPlaying)
                .animation(.easeInOut(duration: 0.2), value: audioPlayer.isPlaying)
                .onAppear {
                    // Restore previously selected team, or fall back to first
                    if selectedTeam == nil && !teams.isEmpty {
                        if let savedID = UUID(uuidString: selectedTeamID),
                           let saved = teams.first(where: { $0.id == savedID }) {
                            selectedTeam = saved
                        } else {
                            selectedTeam = teams.first
                        }
                        session.activeTeam = selectedTeam
                    }
                }
                .onChange(of: selectedTeam) { _, newTeam in
                    session.activeTeam = newTeam
                    selectedTeamID = newTeam?.id.uuidString ?? ""
                    // Reset next batter index when switching teams
                    session.nextPlayerIndex = 0
                }
            }

            if !hasSeenQuickStart {
                QuickStartOverlay(hasSeenQuickStart: $hasSeenQuickStart, pages: Self.quickStartPages)
            }
        }
    }

    // MARK: - Quick Start Pages (Baseball-specific)

    private static let quickStartPages: [QuickStartPageData] = [
        QuickStartPageData(icon: "figure.baseball", iconColor: .blue, title: "Welcome to Dugout DJ", description: "Your personal DJ for game day. Play walk-up songs, trigger event music, and keep the crowd going."),
        QuickStartPageData(icon: "tshirt.fill", iconColor: .teal, title: "Set Up Your Team", description: "Add your team and players with jersey numbers. Drag to set your batting order."),
        QuickStartPageData(icon: "music.note.list", iconColor: .pink, title: "Add Your Music", description: "Import songs from your Files app or search Apple Music. Trim clips to the perfect moment."),
        QuickStartPageData(icon: "mic.fill", iconColor: .purple, title: "Walk-Up Songs", description: "Assign a song to each player. They'll get an announcement before their walk-up music plays."),
        QuickStartPageData(icon: "square.grid.2x2", iconColor: .orange, title: "DJ Mode", description: "Tap event buttons for Home Runs, Strike Outs, and more. Long-press any event to add songs."),
        QuickStartPageData(icon: "star.fill", iconColor: .yellow, title: "Unlock Pro", description: "Get more teams, unlimited songs, AI name pronunciation, and all playback modes with a Season Pass."),
    ]

    private func teamBadge(for team: Team) -> some View {
        Text(String(team.name.prefix(1)).uppercased())
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .frame(width: 30, height: 30)
            .background(Color.blue.opacity(0.15))
            .foregroundStyle(.blue)
            .clipShape(Circle())
    }
}

#Preview {
    WalkUpView()
        .modelContainer(for: [Team.self, Player.self, SongClip.self], inMemory: true)
        .environment(GameSession())
        .environment(AudioPlayerService.shared)
        .environment(AnnouncerService())
        .environment(PlayerIntroCoordinator(
            announcer: AnnouncerService(),
            audioPlayer: AudioPlayerService.shared,
            session: GameSession()
        ))
}
