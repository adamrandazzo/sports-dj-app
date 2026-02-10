import SwiftUI
import SwiftData
import Core
import MusicService
import StoreService
import CommonUI

/// Main tab view container
struct ContentView: View {
    @State private var selectedTab: Tab = .walkUp
    @State private var setupNavigationPath = NavigationPath()

    enum Tab: Int, CaseIterable {
        case walkUp = 0
        case music = 1
        case setlists = 2
        case pro = 3
        case setup = 4
        case help = 5
    }

    enum SetupDestination: Hashable {
        case teams
        case events
        case songLibrary
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WalkUpView()
                .tabItem {
                    Label("Walk Up", systemImage: "figure.baseball")
                }
                .tag(Tab.walkUp)

            MusicView()
                .tabItem {
                    Label("DJ", systemImage: "music.note.list")
                }
                .tag(Tab.music)

            SetlistsTabView()
                .tabItem {
                    Label("Setlists", systemImage: "rectangle.stack.fill")
                }
                .tag(Tab.setlists)

            if !ProStatusManager.shared.isPro {
                ProTabView(
                    seasonSubtitle: "1 year of Pro",
                    termsURL: AppConfig.termsOfServiceURL,
                    privacyURL: AppConfig.privacyPolicyURL
                )
                    .tabItem {
                        Label("Pro", systemImage: "star.fill")
                    }
                    .tag(Tab.pro)
            }

            SetupView(navigationPath: $setupNavigationPath)
                .tabItem {
                    Label("Setup", systemImage: "gear")
                }
                .tag(Tab.setup)

            HelpView(selectedTab: $selectedTab, setupNavigationPath: $setupNavigationPath)
                .tabItem {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .tag(Tab.help)
        }
        .environment(\.selectedTab, Binding(
            get: { selectedTab.rawValue },
            set: { selectedTab = Tab(rawValue: $0) ?? .walkUp }
        ))
        .environment(ProStatusManager.shared)
        .environment(StoreKitManager.shared)
        .onChange(of: ProStatusManager.shared.isPro) { _, isPro in
            if isPro && selectedTab == .pro {
                selectedTab = .walkUp
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Team.self,
            Player.self,
            Event.self,
            SongClip.self,
            EventPool.self,
            Setlist.self,
            SetlistEntry.self
        ], inMemory: true)
        .environment(GameSession())
        .environment(AudioPlayerService.shared)
        .environment(AnnouncerService())
        .environment(PlayerIntroCoordinator(
            announcer: AnnouncerService(),
            audioPlayer: AudioPlayerService.shared,
            session: GameSession()
        ))
}
