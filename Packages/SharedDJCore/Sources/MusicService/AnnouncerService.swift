import Foundation
import AVFoundation
import Observation
import Core

/// Service for playing pre-recorded player announcements
@Observable
public final class AnnouncerService: NSObject {
    private var audioPlayer: AVAudioPlayer?

    /// Whether the announcer is currently playing
    public private(set) var isPlaying: Bool = false

    /// Whether announcements are enabled
    public var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "announcer_enabled")
        }
    }

    /// Volume (0.0 - 1.0, default 1.0)
    public var volume: Float = 1.0 {
        didSet {
            UserDefaults.standard.set(volume, forKey: "announcer_volume")
            audioPlayer?.volume = volume
        }
    }

    /// Continuation for async announce completion
    private var announceContinuation: CheckedContinuation<Void, Never>?

    public override init() {
        super.init()
        loadSettings()
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "announcer_enabled") != nil {
            isEnabled = defaults.bool(forKey: "announcer_enabled")
        }

        if defaults.object(forKey: "announcer_volume") != nil {
            volume = defaults.float(forKey: "announcer_volume")
        }
    }

    // MARK: - Announcement

    /// Announce a player using pre-recorded audio
    @MainActor
    public func announce(playerNumber: String, announcer: Announcer) async {
        guard isEnabled else { return }

        // Stop any current playback
        stop()

        // Parse and validate the player number
        guard let number = Int(playerNumber), number >= 1, number <= 99 else {
            print("AnnouncerService: Invalid player number '\(playerNumber)' - must be 1-99")
            return
        }

        // Format number with zero-padding
        let paddedNumber = String(format: "%02d", number)
        let filename = "batting-\(paddedNumber)-\(announcer.fileCode)"

        // Try to find the audio file in the bundle
        // First try with subdirectory (folder reference), then without (folder group)
        let url: URL
        if let subdirURL = Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Announcements") {
            url = subdirURL
        } else if let flatURL = Bundle.main.url(forResource: filename, withExtension: "mp3") {
            url = flatURL
        } else {
            print("AnnouncerService: File not found: \(filename).mp3")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()

            isPlaying = true

            // Wait for playback to complete
            await withCheckedContinuation { continuation in
                self.announceContinuation = continuation
                audioPlayer?.play()
            }

            isPlaying = false
        } catch {
            print("AnnouncerService: Failed to play audio: \(error.localizedDescription)")
            isPlaying = false
        }
    }

    /// Stop any current announcement
    public func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        let continuation = announceContinuation
        announceContinuation = nil
        continuation?.resume()
    }

    /// Play a local audio file and wait for completion (for AI name announcements)
    @MainActor
    public func playLocalFile(at url: URL) async {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("AnnouncerService: File not found at \(url.path)")
            return
        }

        // Stop any current playback
        stop()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()

            isPlaying = true

            // Wait for playback to complete
            await withCheckedContinuation { continuation in
                self.announceContinuation = continuation
                audioPlayer?.play()
            }

            isPlaying = false
        } catch {
            print("AnnouncerService: Failed to play local file: \(error.localizedDescription)")
            isPlaying = false
        }
    }

    /// Play the preview audio for an announcer
    @MainActor
    public func playPreview(for announcer: Announcer) {
        // Stop any current playback
        stop()

        let filename = "\(announcer.fileCode)-preview"

        // Try to find the audio file in the bundle
        let url: URL
        if let subdirURL = Bundle.main.url(forResource: filename, withExtension: "mp3", subdirectory: "Announcers") {
            url = subdirURL
        } else if let flatURL = Bundle.main.url(forResource: filename, withExtension: "mp3") {
            url = flatURL
        } else {
            print("AnnouncerService: Preview file not found: \(filename).mp3")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            isPlaying = true
            audioPlayer?.play()
        } catch {
            print("AnnouncerService: Failed to play preview: \(error.localizedDescription)")
            isPlaying = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AnnouncerService: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            let continuation = self.announceContinuation
            self.announceContinuation = nil
            continuation?.resume()
        }
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isPlaying = false
            let continuation = self.announceContinuation
            self.announceContinuation = nil
            continuation?.resume()
            if let error = error {
                print("AnnouncerService: Decode error: \(error.localizedDescription)")
            }
        }
    }
}
