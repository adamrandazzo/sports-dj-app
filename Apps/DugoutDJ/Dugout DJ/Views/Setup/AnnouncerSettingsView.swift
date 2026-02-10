import SwiftUI
import Core
import MusicService

/// Announcer settings
struct AnnouncerSettingsView: View {
    @Environment(AnnouncerService.self) var announcer

    var body: some View {
        Form {
            Section {
                Toggle("Enable Announcements", isOn: Binding(
                    get: { announcer.isEnabled },
                    set: { announcer.isEnabled = $0 }
                ))
            } footer: {
                Text("When enabled, the app will announce each player before their walk-up song plays.")
            }

            Section("Volume") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Announcement Volume")
                        Spacer()
                        Text("\(Int(announcer.volume * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(announcer.volume) },
                        set: { announcer.volume = Float($0) }
                    ), in: 0.5...1.0)
                }
            }

            Section {
                Button {
                    Task {
                        // Test with a sample announcement (player #7, Big Bill)
                        await announcer.announce(playerNumber: "7", announcer: .bigBill)
                    }
                } label: {
                    Label("Test Announcement", systemImage: "play.circle")
                }
                .disabled(announcer.isPlaying)

                if announcer.isPlaying {
                    Button {
                        announcer.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                }
            } footer: {
                Text("Each team can have a different announcer voice. Change the announcer in team settings.")
            }
        }
        .navigationTitle("Announcer")
    }
}

#Preview {
    NavigationStack {
        AnnouncerSettingsView()
    }
    .environment(AnnouncerService())
}
