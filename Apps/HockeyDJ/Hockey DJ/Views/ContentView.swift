import SwiftUI
import Core
import StoreService
import CommonUI

struct ContentView: View {
    @State private var selectedTab: Tab = .dj
    @State private var setupNavigationPath = NavigationPath()

    private let proStatus = ProStatusManager.shared

    enum Tab: Int {
        case dj = 0
        case game = 1
        case setlists = 2
        case setup = 3
        case pro = 4
        case help = 5
    }

    enum SetupDestination: Hashable {
        case events
        case songLibrary
        case importSong
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DJView()
                .tabItem {
                    Label("DJ", systemImage: "music.note.list")
                }
                .tag(Tab.dj)
                .accessibilityIdentifier("DJTab")

            GameHistoryView()
                .tabItem {
                    Label("Game", systemImage: "list.clipboard")
                }
                .tag(Tab.game)
                .accessibilityIdentifier("GameTab")

            SetlistsTabView()
                .tabItem {
                    Label("Setlists", systemImage: "rectangle.stack.fill")
                }
                .tag(Tab.setlists)
                .accessibilityIdentifier("SetlistsTab")

            if !proStatus.isPro {
                ProTabView(
                    seasonSubtitle: "6 months of Pro",
                    termsURL: AppConfig.termsOfServiceURL,
                    privacyURL: AppConfig.privacyPolicyURL
                )
                    .tabItem {
                        Label("Pro", systemImage: "star.fill")
                    }
                    .tag(Tab.pro)
                    .accessibilityIdentifier("ProTab")
            }

            SetupTabView(navigationPath: $setupNavigationPath)
                .tabItem {
                    Label("Setup", systemImage: "gear")
                }
                .tag(Tab.setup)
                .accessibilityIdentifier("SetupTab")

            HelpView(selectedTab: $selectedTab, setupNavigationPath: $setupNavigationPath)
                .tabItem {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .tag(Tab.help)
                .accessibilityIdentifier("HelpTab")
        }
        .environment(\.selectedTab, Binding(
            get: { selectedTab.rawValue },
            set: { selectedTab = Tab(rawValue: $0) ?? .dj }
        ))
    }

    /// Navigate to the Pro tab programmatically
    func showProTab() {
        selectedTab = .pro
    }
}

#Preview {
    ContentView()
        .environment(GameSession())
}
