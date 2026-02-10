import SwiftUI
import Core
import MusicService

/// Bottom bar showing next batter or current playback status
struct NextBatterBar: View {
    let activePlayers: [Player]

    @Environment(AudioPlayerService.self) var audioPlayer
    @Environment(PlayerIntroCoordinator.self) var coordinator
    @Environment(GameSession.self) var session

    var nextBatter: Player? {
        session.getNextPlayer(from: activePlayers)
    }

    var isPlaying: Bool {
        coordinator.isPlaying || audioPlayer.isPlaying
    }

    var body: some View {
        Group {
            if isPlaying {
                playingView
            } else if let player = nextBatter {
                nextBatterView(player: player)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, y: -2)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Playing View

    private var playingView: some View {
        HStack(spacing: 16) {
            // Album artwork or icon
            if coordinator.announcing {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let artwork = audioPlayer.currentClip?.artworkImage {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "music.note")
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Player and song info
            VStack(alignment: .leading, spacing: 2) {
                if let player = coordinator.currentPlayer {
                    Text(player.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if coordinator.announcing {
                        Text("Announcing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let song = audioPlayer.currentClip {
                        Text("\(song.title) - \(song.artist)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // Phase indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(coordinator.announcing ? .orange : .green)
                        .frame(width: 6, height: 6)
                    Text(coordinator.announcing ? "Announcing" : "Playing")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Stop button
            Button {
                coordinator.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Next Batter View

    private func nextBatterView(player: Player) -> some View {
        HStack(spacing: 16) {
            // Player number badge
            Text(player.number)
                .font(.system(.headline, design: .rounded).monospacedDigit())
                .frame(width: 50, height: 50)
                .background(Color.green.opacity(0.2))
                .foregroundStyle(.green)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Player info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Next Batter")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }

                Text(player.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if let song = player.walkUpSong {
                    Text("\(song.title) - \(song.artist)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if coordinator.isAnnouncerEnabled {
                    Text("Announcement only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No song")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Play button
            Button {
                Task {
                    if let index = activePlayers.firstIndex(where: { $0.id == player.id }) {
                        await coordinator.playIntro(for: player, at: index, totalPlayers: activePlayers.count)
                    }
                }
            } label: {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.green)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!player.hasWalkUpSong && !coordinator.isAnnouncerEnabled)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        NextBatterBar(activePlayers: [])
    }
    .environment(AudioPlayerService.shared)
    .environment(GameSession())
    .environment(PlayerIntroCoordinator(
        announcer: AnnouncerService(),
        audioPlayer: AudioPlayerService.shared,
        session: GameSession()
    ))
}
