import SwiftUI
import SwiftData
import Core
import MusicService
import StoreService
import AnalyticsService
import CommonUI

/// Detail view for editing a player
struct PlayerDetailView: View {
    @Bindable var player: Player
    @Environment(\.modelContext) var modelContext
    @Environment(AnnouncerService.self) var announcer
    @Environment(PlayerIntroCoordinator.self) var coordinator
    @Query(sort: \Team.sortOrder) private var teams: [Team]

    @State private var showingSongPicker = false
    @State private var showingPhoneticHelp = false
    @State private var isGeneratingVoice = false
    @State private var generateError: String?
    @State private var isPreviewingName = false
    @State private var isPreviewingFullWalkUp = false
    @State private var showingProUpgrade = false

    private var proStatus: ProStatusManager { .shared }
    private var ttsService: TTSService { .shared }
    private var audioPlayer: AudioPlayerService { .shared }

    /// The announcer's voice ID for the player's team
    private var teamVoiceId: String {
        (player.team?.announcer ?? .bigBill).voiceId
    }

    /// Whether regeneration is needed based on current settings
    private var needsRegeneration: Bool {
        player.needsAIAnnouncementRegeneration(forVoiceId: teamVoiceId)
    }

    /// Whether the generate button should be enabled
    private var canGenerate: Bool {
        !isGeneratingVoice &&
        !player.announcementName.isEmpty &&
        proStatus.isPro &&
        proStatus.hasAINameCredits()
    }

    /// Whether an AI announcement file exists
    private var hasExistingAnnouncement: Bool {
        ttsService.hasExistingAnnouncement(for: player)
    }

    var body: some View {
        Form {
            Section("Team") {
                Picker("Team", selection: Binding(
                    get: { player.team },
                    set: { newTeam in
                        changeTeam(to: newTeam)
                    }
                )) {
                    Text("None").tag(nil as Team?)
                    ForEach(teams) { team in
                        Text(team.name).tag(team as Team?)
                    }
                }
            }

            Section("Player Info") {
                TextField("Name", text: $player.name)

                TextField("Number", text: Binding(
                    get: { player.number },
                    set: { newValue in
                        let filtered = String(newValue.filter { $0.isNumber }.prefix(2))
                        player.number = filtered
                    }
                ))
                    .keyboardType(.numberPad)
            }

            walkUpSequenceSection

            // Preview Full Walk-Up
            previewFullWalkUpSection
        }
        .navigationTitle(player.name.isEmpty ? "New Player" : player.name)
        .sheet(isPresented: $showingSongPicker) {
            PlayerSongPickerSheet(player: player)
        }
        .sheet(isPresented: $showingPhoneticHelp) {
            PhoneticNameHelpView()
        }
        .sheet(isPresented: $showingProUpgrade) {
            ProTabView(
                seasonSubtitle: "1 year of Pro",
                termsURL: AppConfig.termsOfServiceURL,
                privacyURL: AppConfig.privacyPolicyURL
            )
        }
    }

    // MARK: - Walk-Up Sequence Section

    @ViewBuilder
    private var walkUpSequenceSection: some View {
        // Step 1: Batting Announcement
        Section {
            Toggle("Batting Announcement", isOn: $player.playNumberAnnouncement)

            if player.playNumberAnnouncement {
                Button {
                    Task {
                        let teamAnnouncer = player.team?.announcer ?? .bigBill
                        await announcer.announce(playerNumber: player.number, announcer: teamAnnouncer)
                    }
                } label: {
                    Label("Play", systemImage: "play.circle")
                }
                .disabled(announcer.isPlaying || player.number.isEmpty)
            }
        } header: {
            Text("Step 1: Batting Number")
        } footer: {
            Text("Plays \"Now batting, number \(player.number.isEmpty ? "X" : player.number)\"")
        }

        // Step 2: AI Name Announcement
        Section {
            if proStatus.isPro {
                Toggle("Name Announcement", isOn: $player.playNameAnnouncement)

                if player.playNameAnnouncement {
                    // Phonetic name field with help button
                    HStack {
                        TextField("Phonetic Spelling (optional)", text: Binding(
                            get: { player.phoneticName ?? "" },
                            set: { player.phoneticName = $0.isEmpty ? nil : $0 }
                        ))

                        Button {
                            showingPhoneticHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Preview text
                    if player.phoneticName != nil {
                        Text("Will announce: \(player.announcementName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Generate button
                    Button {
                        generateVoiceAnnouncement()
                    } label: {
                        HStack {
                            if isGeneratingVoice {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Generating...")
                            } else {
                                Label("Generate Name Announcement", systemImage: "waveform")
                            }
                        }
                    }
                    .disabled(!canGenerate)

                    // Preview existing announcement
                    if hasExistingAnnouncement {
                        Button {
                            previewNameAnnouncement()
                        } label: {
                            HStack {
                                Label(
                                    isPreviewingName ? "Playing..." : "Play",
                                    systemImage: isPreviewingName ? "speaker.wave.2.fill" : "play.circle"
                                )

                                Spacer()

                                if needsRegeneration {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                            }
                        }
                        .disabled(isPreviewingName)
                        
                        if needsRegeneration {
                            Text("Update phonetic spelling and regenerate for latest voice")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    // Error message
                    if let error = generateError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } else {
                // Pro upgrade prompt
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32))
                            .foregroundStyle(.yellow, .orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Name Announcements")
                                .font(.headline)
                            Text("A Pro Feature")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Text("Generate professional AI voice announcements of your players' names with customizable pronunciation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        showingProUpgrade = true
                    } label: {
                        Text("Upgrade to Pro")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        } header: {
            Text("Step 2: Player Name (AI)")
        } footer: {
            if proStatus.isPro {
                Text("\(proStatus.aiNameCredits) credits remaining")
            }
        }

        // Step 3: Walk-Up Song toggle (song selection is in separate section)
        Section {
            Toggle("Walk-Up Song", isOn: $player.playWalkUpSong)
            
            if player.playWalkUpSong {
                if let song = player.walkUpSong {
                    // Display selected song
                    HStack {
                        if let artwork = song.artworkImage {
                            Image(uiImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: "music.note")
                                .frame(width: 44, height: 44)
                                .background(Color.accentColor.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.subheadline.weight(.medium))
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Compact button row
                    HStack(spacing: 12) {
                        Button("Change Song") {
                            showingSongPicker = true
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button("Remove", role: .destructive) {
                            player.walkUpSong = nil
                            try? modelContext.save()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        showingSongPicker = true
                    } label: {
                        Label("Select Song", systemImage: "plus.circle")
                    }
                }
            }
        } header: {
            Text("Step 3: Music")
        } footer: {
            if !player.playWalkUpSong {
                Text("Enable to select a walk-up song")
            } else if player.walkUpSong == nil {
                Text("No song selected")
            }
        }
    }

    @ViewBuilder
    private var previewFullWalkUpSection: some View {
        Section {
            Button {
                previewFullWalkUp()
            } label: {
                HStack(spacing: 16) {
                    // Prominent icon
                    ZStack {
                        Circle()
                            .fill(isPreviewingFullWalkUp ? Color.green.gradient : Color.accentColor.gradient)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: isPreviewingFullWalkUp ? "speaker.wave.2.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .symbolEffect(.pulse, isActive: isPreviewingFullWalkUp)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview Full Walk-Up")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text(isPreviewingFullWalkUp ? "Playing walk-up sequence..." : "Test all enabled steps")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if coordinator.isPlaying && coordinator.currentPlayer?.id == player.id {
                        Button {
                            coordinator.stop()
                            isPreviewingFullWalkUp = false
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red.gradient)
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            .disabled(isPreviewingFullWalkUp && coordinator.currentPlayer?.id != player.id)
        } footer: {
            Text("Plays all enabled steps in sequence: batting announcement, name announcement, and walk-up song")
        }
    }

    // MARK: - Actions

    private func generateVoiceAnnouncement() {
        generateError = nil
        
        // Check if we already have a valid cached announcement
        if hasExistingAnnouncement && !needsRegeneration {
            generateError = "Announcement already exists. Update the name or phonetic spelling to regenerate."
            return
        }
        
        isGeneratingVoice = true

        Task {
            do {
                try await ttsService.generateNameAnnouncement(
                    text: player.announcementName,
                    voiceId: teamVoiceId,
                    for: player
                )
                try? modelContext.save()
            } catch {
                await MainActor.run {
                    generateError = error.localizedDescription
                }
            }

            await MainActor.run {
                isGeneratingVoice = false
            }
        }
    }

    private func previewNameAnnouncement() {
        let fileURL = ttsService.announcementFileURL(for: player)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        isPreviewingName = true
        Task {
            await announcer.playLocalFile(at: fileURL)
            await MainActor.run {
                isPreviewingName = false
            }
        }
    }

    private func previewFullWalkUp() {
        isPreviewingFullWalkUp = true

        Task {
            await coordinator.previewIntro(for: player)

            // Wait for playback to finish
            while coordinator.isPlaying {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            await MainActor.run {
                isPreviewingFullWalkUp = false
            }
        }
    }

    private func changeTeam(to newTeam: Team?) {
        // Update the player's team
        player.team = newTeam

        // Update sortOrder to be at the end of the new team's batting order
        if let newTeam = newTeam {
            let maxOrder = newTeam.playersArray.filter { $0.id != player.id }.map { $0.sortOrder }.max() ?? -1
            player.sortOrder = maxOrder + 1
        } else {
            player.sortOrder = 0
        }

        try? modelContext.save()
    }
}

// MARK: - Player Song Picker Sheet
struct PlayerSongPickerSheet: View {
    let player: Player
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \SongClip.title) var songs: [SongClip]

    var body: some View {
        NavigationStack {
            if songs.isEmpty {
                ContentUnavailableView(
                    "No Songs",
                    systemImage: "music.note",
                    description: Text("Import songs in Setup first")
                )
            } else {
                List(songs) { song in
                    Button {
                        player.walkUpSong = song
                        try? modelContext.save()
                        AnalyticsService.songAssignedToPlayer()
                        dismiss()
                    } label: {
                        HStack {
                            if let artwork = song.artworkImage {
                                Image(uiImage: artwork)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image(systemName: "music.note")
                                    .frame(width: 44, height: 44)
                                    .background(Color.accentColor.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }

                            VStack(alignment: .leading) {
                                Text(song.title)
                                    .foregroundStyle(.primary)
                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if player.walkUpSong?.id == song.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Select Song")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Phonetic Name Help View

struct PhoneticNameHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("When entering names for voice generation, phonetic spelling helps ensure correct pronunciation.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("General Principles")
                            .font(.headline)

                        Text("Write names the way they sound, not the way they're spelled. Break complex names into syllable chunks that use common English pronunciation patterns.")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Techniques That Work Well")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            phoneticExample(
                                technique: "Use familiar word sounds",
                                example: "\"Nguyen\" \u{2192} \"Win\" or \"Nwen\""
                            )

                            phoneticExample(
                                technique: "Add hyphens between syllables",
                                example: "\"Siobhan\" \u{2192} \"Shiv-awn\""
                            )

                            phoneticExample(
                                technique: "Double vowels for long sounds",
                                example: "\"Leah\" \u{2192} \"Lee-uh\""
                            )

                            phoneticExample(
                                technique: "Use \"uh\" for schwa sounds",
                                example: "\"Amanda\" \u{2192} \"Uh-man-duh\""
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Phonetic Name Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func phoneticExample(technique: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(technique)
                .font(.subheadline.weight(.medium))
            Text(example)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Team.self, Player.self, SongClip.self, configurations: config)

    let team = Team(name: "Test Team")
    container.mainContext.insert(team)

    let player = Player(name: "John Smith", number: "7", team: team)
    container.mainContext.insert(player)

    let announcerService = AnnouncerService()
    let audioPlayer = AudioPlayerService.shared
    let gameSession = GameSession()
    let coordinator = PlayerIntroCoordinator(
        announcer: announcerService,
        audioPlayer: audioPlayer,
        session: gameSession
    )

    return NavigationStack {
        PlayerDetailView(player: player)
    }
    .modelContainer(container)
    .environment(announcerService)
    .environment(coordinator)
}
