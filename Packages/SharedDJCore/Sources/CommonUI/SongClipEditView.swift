import SwiftUI
import SwiftData
import AVFoundation
import MusicKit
import Core

public struct SongClipEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var song: SongClip
    var isNewSong: Bool = false

    // Song metadata
    @State private var title: String = ""
    @State private var artist: String = ""

    // Clip timing
    @State private var startTime: Double = 0
    @State private var endTime: Double = 30
    @State private var duration: Double = 0

    // Fade settings (local files only)
    @State private var fadeInDuration: Double = 0
    @State private var fadeOutDuration: Double = 0

    // Waveform data
    @State private var waveformData: [Float] = []
    @State private var isLoadingWaveform = true

    // Playback state
    @State private var isPlaying = false
    @State private var currentPlaybackTime: Double = 0
    @State private var playbackTimer: Timer?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var musicPlayer = ApplicationMusicPlayer.shared
    @State private var previewStopTask: Task<Void, Never>?

    // Zoom state
    @State private var zoomLevel: CGFloat = 1.0
    @State private var scrollOffset: CGFloat = 0.0

    // UI state
    @State private var showingFadeControls = false

    public init(song: SongClip, isNewSong: Bool = false) {
        self.song = song
        self.isNewSong = isNewSong
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                    VStack(spacing: 20) {
                        // Song info header
                        songInfoHeader
                            .padding(.top, 16)

                        // Current position display (prominent)
                        currentPositionDisplay

                        // Mini-map (shows when zoomed)
                        if zoomLevel > 1.0 {
                            TimelineMiniMapView(
                                samples: waveformData,
                                startTime: startTime,
                                endTime: endTime,
                                duration: duration,
                                zoomLevel: zoomLevel,
                                scrollOffset: $scrollOffset
                            )
                            .frame(height: 44)
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Time labels above timeline
                        timeLabelsView
                            .padding(.horizontal, 20)

                        // Main zoomable timeline
                        ZoomableTimelineView(
                            samples: waveformData,
                            startTime: $startTime,
                            endTime: $endTime,
                            duration: duration,
                            isLoading: isLoadingWaveform,
                            currentPlaybackTime: $currentPlaybackTime,
                            isPlaying: isPlaying,
                            onSeek: { time in
                                seekToTime(time)
                            },
                            onScrubStart: {
                                pausePlayback()
                            },
                            onScrubEnd: { time in
                                resumePlaybackFrom(time)
                            },
                            zoomLevel: $zoomLevel,
                            scrollOffset: $scrollOffset
                        )
                        .frame(height: 180)
                        .padding(.horizontal, 20)

                        // Zoom controls (directly below timeline)
                        ZoomControlsView(
                            zoomLevel: $zoomLevel,
                            scrollOffset: $scrollOffset,
                            startTime: startTime,
                            endTime: endTime,
                            duration: duration
                        )
                        .padding(.horizontal, 20)

                        // Time input buttons
                        timeInputRow
                            .padding(.horizontal, 20)

                        // Playback buttons
                        playbackButtons
                            .padding(.horizontal, 20)

                        // Fade controls (local files only)
                        if song.sourceType == .localFile {
                            fadeControlsSection
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 40)
                    }
                }
            .background(Color(.systemBackground))
            .navigationTitle(isNewSong ? "Set Up Clip" : "Edit Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNewSong {
                            modelContext.delete(song)
                            try? modelContext.save()
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .animation(.spring(response: 0.3), value: zoomLevel > 1.0)
        .onAppear {
            loadInitialValues()
            loadWaveform()
        }
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Song Info Header

    private var songInfoHeader: some View {
        HStack(spacing: 16) {
            CachedArtworkView(song: song, size: 72, cornerRadius: 10)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Title", text: $title)
                    .font(.title3)
                    .fontWeight(.semibold)

                TextField("Artist", text: $artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: song.sourceType == .appleMusic ? "apple.logo" : "doc.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(formatDuration(duration) + " total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Current Position Display

    private var currentPositionDisplay: some View {
        VStack(spacing: 2) {
            Text("Position")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(formatDuration(currentPlaybackTime))
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .foregroundColor(isPlaying ? .red : .primary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Time Labels

    private var timeLabelsView: some View {
        HStack {
            // Current viewport time range
            if zoomLevel > 1.0 {
                let visibleDuration = duration / Double(zoomLevel)
                let visibleStart = Double(scrollOffset) * (duration - visibleDuration)
                let visibleEnd = visibleStart + visibleDuration

                Text(formatDuration(visibleStart))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(formatDuration((visibleStart + visibleEnd) / 2))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(formatDuration(visibleEnd))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            } else {
                Text("0:00.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(formatDuration(duration / 2))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Time Input Row

    private var timeInputRow: some View {
        HStack(spacing: 0) {
            TimeInputButton(
                label: "In",
                time: $startTime,
                minTime: 0,
                maxTime: endTime - 0.5,
                duration: duration,
                currentPlaybackTime: currentPlaybackTime
            )

            Spacer()

            // Clip duration display
            VStack(spacing: 2) {
                Text("Clip")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(formatDuration(endTime - startTime))
                    .font(.system(.footnote, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }

            Spacer()

            TimeInputButton(
                label: "Out",
                time: $endTime,
                minTime: startTime + 0.5,
                maxTime: duration,
                duration: duration,
                currentPlaybackTime: currentPlaybackTime
            )
        }
    }

    // MARK: - Playback Buttons

    private var playbackButtons: some View {
        VStack(spacing: 12) {
            // Primary Play button - plays from playhead position
            Button {
                togglePlay()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.title2)

                    Text(isPlaying ? "Stop" : "Play")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isPlaying ? Color.red : Color.blue)
                )
            }

            // Secondary Preview Clip button
            Button {
                previewClip()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "repeat")
                        .font(.subheadline)

                    Text("Preview Clip")
                        .font(.subheadline)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 1.5)
                )
            }
            .disabled(isPlaying)
            .opacity(isPlaying ? 0.5 : 1)
        }
    }

    // MARK: - Fade Controls

    private var fadeControlsSection: some View {
        VStack(spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showingFadeControls.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "waveform.path")
                        .foregroundColor(.secondary)

                    Text("Fade Effects")
                        .foregroundColor(.primary)

                    Spacer()

                    if fadeInDuration > 0 || fadeOutDuration > 0 {
                        Text(fadeEffectsSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: showingFadeControls ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }

            if showingFadeControls {
                VStack(spacing: 12) {
                    // Fade In
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "speaker.wave.1")
                                .foregroundColor(.secondary)
                            Text("Fade In")
                            Spacer()
                            Text(fadeInDuration == 0 ? "Off" : String(format: "%.1fs", fadeInDuration))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        .font(.subheadline)

                        Slider(value: $fadeInDuration, in: 0...15, step: 0.5)
                            .tint(.blue)
                    }

                    // Fade Out
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "speaker.wave.3")
                                .foregroundColor(.secondary)
                            Text("Fade Out")
                            Spacer()
                            Text(fadeOutDuration == 0 ? "Off" : String(format: "%.1fs", fadeOutDuration))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        .font(.subheadline)

                        Slider(value: $fadeOutDuration, in: 0...15, step: 0.5)
                            .tint(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var fadeEffectsSummary: String {
        var parts: [String] = []
        if fadeInDuration > 0 {
            parts.append("In: \(String(format: "%.1fs", fadeInDuration))")
        }
        if fadeOutDuration > 0 {
            parts.append("Out: \(String(format: "%.1fs", fadeOutDuration))")
        }
        return parts.joined(separator: " \u{2022} ")
    }

    // MARK: - Data Loading

    private func loadInitialValues() {
        title = song.title
        artist = song.artist
        startTime = song.startTime
        endTime = song.endTime
        fadeInDuration = song.fadeInDuration ?? 0
        fadeOutDuration = song.fadeOutDuration ?? 0
        duration = max(endTime + 1, 30)

        Task {
            if song.sourceType == .localFile {
                if let url = getAudioURL() {
                    if let dur = await SongClip.getDuration(from: url) {
                        await MainActor.run {
                            duration = dur
                            if endTime > dur {
                                endTime = dur
                            }
                        }
                    }
                }
            } else if song.sourceType == .appleMusic {
                if let storedDur = song.storedDuration, storedDur > 0 {
                    await MainActor.run {
                        duration = storedDur
                        if endTime > storedDur {
                            endTime = storedDur
                        }
                    }
                } else {
                    await fetchAppleMusicDuration()
                }
            }
        }
    }

    private func fetchAppleMusicDuration() async {
        guard !song.sourceID.isEmpty else { return }

        do {
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(song.sourceID))
            let response = try await request.response()

            if let appleMusicSong = response.items.first, let dur = appleMusicSong.duration {
                await MainActor.run {
                    duration = dur
                    song.storedDuration = dur
                    if endTime > dur {
                        endTime = dur
                    }
                }
            }
        } catch {
            print("Failed to fetch Apple Music song duration: \(error)")
        }
    }

    private func getAudioURL() -> URL? {
        guard song.sourceType == .localFile else { return nil }
        return song.localFileURL
    }

    private func loadWaveform() {
        guard let url = getAudioURL() else {
            isLoadingWaveform = false
            return
        }

        Task {
            do {
                let samples = try await generateWaveformSamples(from: url, targetSamples: 200)
                await MainActor.run {
                    waveformData = samples
                    isLoadingWaveform = false
                }
            } catch {
                print("Failed to generate waveform: \(error)")
                await MainActor.run {
                    isLoadingWaveform = false
                }
            }
        }
    }

    // MARK: - Playback

    private func togglePlay() {
        if isPlaying {
            stopPlayback()
        } else {
            playFromPlayhead()
        }
    }

    private func previewClip() {
        // Play from clip start to end
        currentPlaybackTime = startTime
        playFromPosition(startTime, stopAt: endTime)
    }

    private func playFromPlayhead() {
        // Play from current playhead position to end of song
        playFromPosition(currentPlaybackTime, stopAt: duration)
    }

    private func playFromPosition(_ position: Double, stopAt stopTime: Double) {
        if song.sourceType == .localFile {
            playLocalFile(from: position, stopAt: stopTime)
        } else {
            playAppleMusic(from: position, stopAt: stopTime)
        }
    }

    private func playLocalFile(from position: Double, stopAt stopTime: Double) {
        guard let url = getAudioURL() else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.currentTime = position
            audioPlayer?.play()
            isPlaying = true
            currentPlaybackTime = position
            startPlaybackTimer(stopAt: stopTime)
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    private func playAppleMusic(from position: Double, stopAt stopTime: Double) {
        previewStopTask?.cancel()

        guard !song.sourceID.isEmpty else { return }

        Task {
            do {
                // Use library request for library IDs, catalog for catalog IDs
                let appleMusicSong: Song?
                if song.sourceID.hasPrefix("i.") {
                    var request = MusicLibraryRequest<Song>()
                    request.filter(matching: \.id, equalTo: MusicItemID(song.sourceID))
                    let response = try await request.response()
                    appleMusicSong = response.items.first
                } else {
                    let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(song.sourceID))
                    let response = try await request.response()
                    appleMusicSong = response.items.first
                }

                guard let song = appleMusicSong else { return }

                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)

                musicPlayer.queue = [song]
                try await musicPlayer.prepareToPlay()
                try await musicPlayer.play()

                if position > 0 {
                    musicPlayer.playbackTime = position
                }

                await MainActor.run {
                    isPlaying = true
                    currentPlaybackTime = position
                    startPlaybackTimer(stopAt: stopTime)
                }
            } catch {
                print("Failed to play Apple Music: \(error)")
            }
        }
    }

    private func stopPlayback() {
        previewStopTask?.cancel()
        previewStopTask = nil
        stopPlaybackTimer()

        if song.sourceType == .appleMusic {
            musicPlayer.stop()
        } else {
            audioPlayer?.stop()
            audioPlayer = nil
        }
        isPlaying = false
    }

    private func pausePlayback() {
        stopPlaybackTimer()

        if song.sourceType == .appleMusic {
            musicPlayer.pause()
        } else {
            audioPlayer?.pause()
        }
        isPlaying = false
    }

    private func resumePlaybackFrom(_ time: Double) {
        currentPlaybackTime = time

        if song.sourceType == .localFile {
            audioPlayer?.currentTime = time
            audioPlayer?.play()
            isPlaying = true
            startPlaybackTimer(stopAt: duration)
        } else {
            Task {
                musicPlayer.playbackTime = time
                try? await musicPlayer.play()
                await MainActor.run {
                    isPlaying = true
                    startPlaybackTimer(stopAt: duration)
                }
            }
        }
    }

    func scrubToTime(_ time: Double) {
        // Scrub to position while playing
        let clampedTime = max(0, min(time, duration))

        if song.sourceType == .localFile {
            audioPlayer?.currentTime = clampedTime
        } else {
            musicPlayer.playbackTime = clampedTime
        }
        currentPlaybackTime = clampedTime
    }

    private func startPlaybackTimer(stopAt stopTime: Double) {
        previewStopTask?.cancel()

        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if song.sourceType == .localFile {
                if let player = audioPlayer {
                    currentPlaybackTime = player.currentTime
                }
            } else {
                currentPlaybackTime = musicPlayer.playbackTime
            }

            // Stop when we reach the stop time
            if currentPlaybackTime >= stopTime {
                stopPlayback()
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func seekToTime(_ time: Double) {
        if isPlaying {
            // Scrub while playing
            scrubToTime(time)
        } else {
            // Just update playhead position when not playing
            if song.sourceType == .localFile {
                // For local files, we can prepare the player at the seek position
                if let url = getAudioURL() {
                    do {
                        if audioPlayer == nil {
                            audioPlayer = try AVAudioPlayer(contentsOf: url)
                            audioPlayer?.prepareToPlay()
                        }
                        audioPlayer?.currentTime = time
                    } catch {
                        print("Failed to seek: \(error)")
                    }
                }
            }
            currentPlaybackTime = time
        }
    }

    // MARK: - Save

    private func saveChanges() {
        song.title = title
        song.artist = artist
        song.startTime = startTime
        song.endTime = endTime
        song.fadeInDuration = fadeInDuration
        song.fadeOutDuration = fadeOutDuration
        try? modelContext.save()
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let tenths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, tenths)
    }
}

// MARK: - Waveform Generation

public func generateWaveformSamples(from url: URL, targetSamples: Int) async throws -> [Float] {
    let asset = AVURLAsset(url: url)
    let tracks = try await asset.loadTracks(withMediaType: .audio)

    guard let track = tracks.first else {
        throw WaveformError.noAudioTrack
    }

    let reader = try AVAssetReader(asset: asset)

    let outputSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
    ]

    let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
    reader.add(output)
    reader.startReading()

    var allSamples: [Int16] = []

    while let sampleBuffer = output.copyNextSampleBuffer() {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard let data = dataPointer else { continue }

        let sampleCount = length / 2
        data.withMemoryRebound(to: Int16.self, capacity: sampleCount) { samples in
            for i in 0..<sampleCount {
                allSamples.append(samples[i])
            }
        }
    }

    guard !allSamples.isEmpty else { return [] }

    let samplesPerBucket = max(1, allSamples.count / targetSamples)
    let actualSampleCount = min(targetSamples, allSamples.count)
    var result: [Float] = []

    for i in 0..<actualSampleCount {
        let startIndex = i * samplesPerBucket
        let endIndex = min(startIndex + samplesPerBucket, allSamples.count)
        guard startIndex < allSamples.count else { break }

        var maxValue: Int32 = 0
        for j in startIndex..<endIndex {
            let absValue = abs(Int32(allSamples[j]))
            if absValue > maxValue {
                maxValue = absValue
            }
        }

        result.append(Float(maxValue) / Float(Int16.max))
    }

    return result
}

public enum WaveformError: Error {
    case noAudioTrack
}
