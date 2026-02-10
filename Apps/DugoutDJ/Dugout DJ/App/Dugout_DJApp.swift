import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import Core
import MusicService
import StoreService
import AnalyticsService

@main
struct Dugout_DJApp: App {
    /// Check if running for UI tests
    private static let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")

    /// Result of model container initialization
    private let containerResult: Result<ModelContainer, Error>

    init() {
        // Configure shared DJ core
        DJCoreSetup.configure(with: BaseballConfig.self)

        FirebaseApp.configure()
        Analytics.setAnalyticsCollectionEnabled(true)

        // Wire up analytics callbacks
        StoreKitManager.analyticsPurchase = { productID in
            AnalyticsService.purchase(itemID: productID)
        }
        ProStatusManager.analyticsSetIsPro = { isPro in
            AnalyticsService.setIsPro(isPro)
        }
        PlayerIntroCoordinator.analyticsIntroPlayed = { hasSong, hasAnnouncement in
            AnalyticsService.playerIntroPlayed(hasSong: hasSong, hasAnnouncement: hasAnnouncement)
        }
        TTSService.hasAICreditsCheck = {
            ProStatusManager.shared.hasAINameCredits()
        }
        TTSService.useAICredit = {
            ProStatusManager.shared.useAINameCredit()
        }
        TTSService.analyticsAIGenerated = {
            AnalyticsService.aiAnnouncementGenerated()
        }

        let schema = Schema([
            Event.self,
            SongClip.self,
            EventPool.self,
            Setlist.self,
            SetlistEntry.self,
            Team.self,
            Player.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: Self.isUITesting,
            cloudKitDatabase: Self.isUITesting ? .none : .automatic
        )

        do {
            containerResult = .success(try ModelContainer(for: schema, configurations: [modelConfiguration]))
        } catch {
            containerResult = .failure(error)
        }
    }

    /// Safe accessor for model container
    private var sharedModelContainer: ModelContainer? {
        try? containerResult.get()
    }

    /// Shared game session state
    @State private var gameSession = GameSession()

    /// Audio player service
    @State private var audioPlayer = AudioPlayerService.shared

    /// Announcer service for player announcements
    @State private var announcerService = AnnouncerService()

    /// Player intro coordinator (renamed from WalkUpCoordinator)
    @State private var playerIntroCoordinator: PlayerIntroCoordinator?

    var body: some Scene {
        WindowGroup {
            if let container = sharedModelContainer {
                ContentView()
                    .environment(gameSession)
                    .environment(audioPlayer)
                    .environment(announcerService)
                    .environment(playerIntroCoordinator ?? PlayerIntroCoordinator(
                        announcer: announcerService,
                        audioPlayer: audioPlayer,
                        session: gameSession
                    ))
                    .modelContainer(container)
                    .onAppear {
                        // Wire up game session's pro check
                        gameSession.isProCheck = { ProStatusManager.shared.isPro }

                        // Initialize player intro coordinator
                        if playerIntroCoordinator == nil {
                            playerIntroCoordinator = PlayerIntroCoordinator(
                                announcer: announcerService,
                                audioPlayer: audioPlayer,
                                session: gameSession
                            )
                        }

                        seedStandardEventsIfNeeded()
                        migrateEventCodes()

                        if !Self.isUITesting {
                            migrateFilesToICloud()
                        }

                        AnalyticsService.appOpened()
                    }
                    .task {
                        await ProStatusManager.shared.refreshStatus()
                    }
            } else {
                DatabaseErrorView(error: containerError)
            }
        }
    }

    private var containerError: String {
        if case .failure(let error) = containerResult {
            return error.localizedDescription
        }
        return "Unknown error"
    }

    private func migrateFilesToICloud() {
        Task {
            await FileStorageManager.shared.migrateToICloud()
        }
    }

    private func migrateEventCodes() {
        guard let context = sharedModelContainer?.mainContext else { return }

        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate { $0.isStandard && $0.code == "" }
        )

        guard let eventsToMigrate = try? context.fetch(descriptor),
              !eventsToMigrate.isEmpty else { return }

        let standardEvents = BaseballConfig.standardEvents
        for event in eventsToMigrate {
            if event.sortOrder >= 0 && event.sortOrder < standardEvents.count {
                event.code = standardEvents[event.sortOrder].code
            }
        }

        try? context.save()
        print("Migrated codes for \(eventsToMigrate.count) events")
    }

    private func seedStandardEventsIfNeeded() {
        guard let context = sharedModelContainer?.mainContext else { return }

        let descriptor = FetchDescriptor<Event>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        guard existingCount == 0 else { return }

        let standardEvents = Event.createStandardEvents(from: BaseballConfig.standardEvents)
        for event in standardEvents {
            context.insert(event)

            let pool = EventPool(event: event)
            context.insert(pool)
            event.pool = pool
        }

        try? context.save()
        print("Seeded \(standardEvents.count) standard events")
    }

}

// MARK: - Database Error View

struct DatabaseErrorView: View {
    let error: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text("Unable to Load Data")
                .font(.title2.bold())

            Text("The app couldn't initialize its database. This may be due to a storage issue or corrupted data.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Text("Try these steps:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Restart the app", systemImage: "arrow.clockwise")
                    Label("Free up device storage", systemImage: "internaldrive")
                    Label("Reinstall if the issue persists", systemImage: "arrow.down.app")
                }
                .font(.subheadline)
            }
            .padding()
        }
        .padding()
    }
}
