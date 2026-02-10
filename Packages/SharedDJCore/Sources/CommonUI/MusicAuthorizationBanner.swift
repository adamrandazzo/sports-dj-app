import SwiftUI
import MusicKit
import MusicService

/// View modifier that shows an alert when Apple Music playback fails
/// due to authorization or subscription issues.
struct MusicAccessAlertModifier: ViewModifier {
    @State private var issue: AudioPlayerService.MusicAccessIssue?

    private var audioPlayer: AudioPlayerService { .shared }

    func body(content: Content) -> some View {
        content
            .onChange(of: audioPlayer.musicAccessIssue) { _, newValue in
                if let newValue {
                    issue = newValue
                    audioPlayer.musicAccessIssue = nil
                }
            }
            .alert(alertTitle, isPresented: showingAlert, presenting: issue) { issue in
                switch issue {
                case .authorizationNeeded:
                    Button("Allow Access") {
                        Task {
                            _ = await MusicAuthorization.request()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                case .authorizationDenied:
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                case .subscriptionRequired:
                    Button("OK", role: .cancel) {}
                }
            } message: { issue in
                switch issue {
                case .authorizationNeeded:
                    Text("This song is from Apple Music. Allow access to play it.")
                case .authorizationDenied:
                    Text("Apple Music access was denied. You can enable it in Settings.")
                case .subscriptionRequired:
                    Text("An Apple Music subscription is required to play this song. You can still use local audio files.")
                }
            }
    }

    private var showingAlert: Binding<Bool> {
        Binding(
            get: { issue != nil },
            set: { if !$0 { issue = nil } }
        )
    }

    private var alertTitle: String {
        switch issue {
        case .authorizationNeeded: return "Apple Music Access"
        case .authorizationDenied: return "Apple Music Access Denied"
        case .subscriptionRequired: return "Apple Music Subscription Required"
        case nil: return ""
        }
    }
}

public extension View {
    /// Shows an alert when Apple Music playback fails due to auth or subscription issues.
    func musicAccessAlert() -> some View {
        modifier(MusicAccessAlertModifier())
    }
}
