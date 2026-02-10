import SwiftUI
import SwiftData
import Core
import MusicService
import StoreService
import AnalyticsService
import CommonUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.selectedTab) private var selectedTab

    private let proStatus = ProStatusManager.shared

    @CloudStorage("hapticFeedback") private var hapticFeedback = true
    @CloudStorage("autoStartGame") private var autoStartGame = true
    @CloudStorage("eventButtonSize") private var eventButtonSize = EventButtonSize.medium.rawValue
    @CloudStorage("addToAppleMusicLibrary") private var addToAppleMusicLibrary = false
    @CloudStorage("hasSeenQuickStart") private var hasSeenQuickStart = false

    @State private var showingResetConfirmation = false
    @State private var showingDeleteAllConfirmation = false
    @State private var isExporting = false
    @State private var exportResult: ExportResult?
    @State private var exportError: String?
    @State private var showingExportAlert = false

    /// Show debug controls in DEBUG builds or TestFlight
    private var showDebugControls: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    var body: some View {
        Form {
            // Pro Status Section
            Section {
                if proStatus.isPro {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Pro")
                            .fontWeight(.semibold)
                        Spacer()
                        if let type = proStatus.purchaseType {
                            Text(type.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let expiration = proStatus.subscriptionExpirationDate {
                        HStack {
                            Text("Renews")
                            Spacer()
                            Text(expiration, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("Upgrade to Pro")
                                .fontWeight(.semibold)
                        }

                        Text("Unlock unlimited songs, custom events, and all playback modes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        NavigationLink {
                            ProTabView(
                                seasonSubtitle: "6 months of Pro",
                                termsURL: AppConfig.termsOfServiceURL,
                                privacyURL: AppConfig.privacyPolicyURL
                            )
                        } label: {
                            Text("View Pro Features")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Pro Status")
            }

            Section {
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
                    .onChange(of: hapticFeedback) { _, newValue in
                        AnalyticsService.settingChanged(setting: "haptic_feedback", value: "\(newValue)")
                    }

                Toggle("Auto-start Game on First Tap", isOn: $autoStartGame)
                    .onChange(of: autoStartGame) { _, newValue in
                        AnalyticsService.settingChanged(setting: "auto_start_game", value: "\(newValue)")
                    }
            } header: {
                Text("Playback")
            }

            Section {
                Picker("Event Button Size", selection: $eventButtonSize) {
                    ForEach(EventButtonSize.allCases, id: \.rawValue) { size in
                        Text(size.displayName).tag(size.rawValue)
                    }
                }
                .onChange(of: eventButtonSize) { _, newValue in
                    let name = EventButtonSize(rawValue: newValue)?.displayName ?? "unknown"
                    AnalyticsService.settingChanged(setting: "event_button_size", value: name)
                }

                Button("Show Quick Start Guide") {
                    hasSeenQuickStart = false
                    selectedTab?.wrappedValue = ContentView.Tab.dj.rawValue
                }
            } header: {
                Text("Display")
            }

            Section {
                Toggle("Add Songs to Library by Default", isOn: $addToAppleMusicLibrary)
                    .onChange(of: addToAppleMusicLibrary) { _, newValue in
                        AnalyticsService.settingChanged(setting: "add_to_apple_music_library", value: "\(newValue)")
                    }

                Button {
                    exportToAppleMusic()
                } label: {
                    HStack {
                        Text("Export Songs to Apple Music Playlist")
                        Spacer()
                        if isExporting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isExporting)
            } header: {
                Text("Apple Music")
            } footer: {
                Text("Creates a playlist in Apple Music with all your imported songs. You can then download it for offline use.")
            }

            Section {
                Button("Reset Events to Default") {
                    showingResetConfirmation = true
                }

                Button("Delete All Songs", role: .destructive) {
                    showingDeleteAllConfirmation = true
                }
            } header: {
                Text("Data")
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)
            }

            if showDebugControls {
                Section {
                    Toggle("Pro Mode", isOn: Binding(
                        get: { proStatus.isPro },
                        set: { newValue in
                            if newValue {
                                proStatus.grantPro(type: .lifetime)
                            } else {
                                proStatus.revokePro()
                            }
                        }
                    ))

                    Button("Test Crash", role: .destructive) {
                        fatalError("Test crash for Crashlytics")
                    }
                } header: {
                    Text("Debug")
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Reset Events",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Default", role: .destructive) {
                resetEventsToDefault()
                AnalyticsService.dataReset(type: "events")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all custom events and reset standard events. Song pools will be cleared.")
        }
        .confirmationDialog(
            "Delete All Songs",
            isPresented: $showingDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                deleteAllSongs()
                AnalyticsService.dataReset(type: "songs")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all imported songs and their clips.")
        }
        .alert("Export Complete", isPresented: $showingExportAlert) {
            Button("OK") {
                exportResult = nil
                exportError = nil
            }
        } message: {
            if let result = exportResult {
                Text("Created playlist \"\(result.playlistName)\" with \(result.exportedSongs) songs.\n\nOpen Apple Music and download the playlist for offline use.")
            } else if let error = exportError {
                Text(error)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func exportToAppleMusic() {
        isExporting = true

        Task {
            do {
                let result = try await MusicLibraryService.shared.exportAppLibrary(
                    modelContext: modelContext
                )

                await MainActor.run {
                    exportResult = result
                    exportError = nil
                    showingExportAlert = true
                    isExporting = false
                    AnalyticsService.exportToAppleMusic(result: "success", songCount: result.exportedSongs)
                }
            } catch {
                await MainActor.run {
                    exportResult = nil
                    exportError = error.localizedDescription
                    showingExportAlert = true
                    isExporting = false
                    AnalyticsService.exportToAppleMusic(result: "error", songCount: 0)
                }
            }
        }
    }

    private func resetEventsToDefault() {
        // Delete all existing events
        let eventDescriptor = FetchDescriptor<Event>()
        if let events = try? modelContext.fetch(eventDescriptor) {
            for event in events {
                modelContext.delete(event)
            }
        }

        // Delete all pools
        let poolDescriptor = FetchDescriptor<EventPool>()
        if let pools = try? modelContext.fetch(poolDescriptor) {
            for pool in pools {
                modelContext.delete(pool)
            }
        }

        // Create fresh standard events
        let standardEvents = Event.createStandardEvents(from: HockeyConfig.standardEvents)
        for event in standardEvents {
            modelContext.insert(event)

            let pool = EventPool(event: event)
            modelContext.insert(pool)
            event.pool = pool
        }

        try? modelContext.save()
    }

    private func deleteAllSongs() {
        // Delete all songs
        let descriptor = FetchDescriptor<SongClip>()
        if let songs = try? modelContext.fetch(descriptor) {
            for song in songs {
                // Delete local file if exists
                if song.sourceType == .localFile, let url = song.localFileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                modelContext.delete(song)
            }
        }

        // Clear all pools
        let poolDescriptor = FetchDescriptor<EventPool>()
        if let pools = try? modelContext.fetch(poolDescriptor) {
            for pool in pools {
                pool.songsArray.removeAll()
                pool.sortOrder.removeAll()
            }
        }

        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [Event.self, SongClip.self, EventPool.self], inMemory: true)
}
