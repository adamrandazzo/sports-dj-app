import SwiftUI
import Core

public struct EventButton: View {
    let event: Event
    var size: EventButtonSize = .medium
    let action: () -> Void
    var onLongPress: (() -> Void)?

    public init(event: Event, size: EventButtonSize = .medium, action: @escaping () -> Void, onLongPress: (() -> Void)? = nil) {
        self.event = event
        self.size = size
        self.action = action
        self.onLongPress = onLongPress
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: size == .small ? 4 : 6) {
                // Icon
                Image(systemName: event.icon)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundStyle(.white)

                // Name
                Text(event.name)
                    .font(size == .large ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                // Song count indicator
                if let pool = event.pool, !pool.songsArray.isEmpty {
                    Text("\(pool.songsArray.count) songs")
                        .font(size == .large ? .caption : .caption2)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text("No songs")
                        .font(size == .large ? .caption : .caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(event.color.gradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                // Playback mode indicator badge
                Image(systemName: event.playbackMode.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                    )
                    .padding(6)
            }
        }
        .buttonStyle(EventButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress?()
                }
        )
        .accessibilityLabel("\(event.name) button")
        .accessibilityHint(accessibilityHintText)
    }

    private var accessibilityHintText: String {
        switch event.playbackMode {
        case .random:
            return "Plays a random song for this event"
        case .sequential:
            return "Plays the next song in order for this event"
        case .manual:
            return "Opens song picker for this event"
        }
    }
}

// MARK: - Button Style
public struct EventButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Compact variant for lists
public struct EventButtonCompact: View {
    let event: Event

    public init(event: Event) {
        self.event = event
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon circle
            Circle()
                .fill(event.color.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: event.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.headline)

                if let pool = event.pool {
                    Text("\(pool.songsArray.count) songs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Playback mode indicator
            HStack(spacing: 4) {
                Image(systemName: event.playbackMode.icon)
                    .font(.caption2)
                Text(event.playbackMode.displayName)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
        }
    }
}
