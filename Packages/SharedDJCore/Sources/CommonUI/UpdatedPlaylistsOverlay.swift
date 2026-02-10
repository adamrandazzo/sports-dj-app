import SwiftUI
import Core

public struct UpdatedPlaylistsOverlay: View {
    let playlists: [RemotePlaylistSummary]
    let isPro: Bool
    let onDismiss: () -> Void
    let onViewPlaylist: (RemotePlaylistSummary) -> Void
    let onGoPro: () -> Void

    @State private var currentPage = 0

    private var totalPages: Int {
        playlists.count
    }

    private var currentPlaylist: RemotePlaylistSummary? {
        guard currentPage < playlists.count else { return nil }
        return playlists[currentPage]
    }

    private var isLastPage: Bool {
        currentPage >= totalPages - 1
    }

    public init(playlists: [RemotePlaylistSummary], isPro: Bool, onDismiss: @escaping () -> Void, onViewPlaylist: @escaping (RemotePlaylistSummary) -> Void, onGoPro: @escaping () -> Void) {
        self.playlists = playlists
        self.isPro = isPro
        self.onDismiss = onDismiss
        self.onViewPlaylist = onViewPlaylist
        self.onGoPro = onGoPro
    }

    public var body: some View {
        ZStack {
            // Dimmed background
            Color.black
                .opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't dismiss on background tap
                }

            // Card
            VStack(spacing: 0) {
                // Header
                Text("Updated Setlists")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
                        UpdatedPlaylistsCard(playlist: playlist)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)

                // Custom page indicators (only show if multiple pages)
                if totalPages > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                } else {
                    Spacer()
                        .frame(height: 36)
                }

                // Buttons
                HStack(spacing: 16) {
                    // Skip All button (always shows)
                    Button {
                        onDismiss()
                    } label: {
                        Text("Skip All")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }

                    if isLastPage {
                        // Last page: show View/Go Pro button
                        if isPro {
                            Button {
                                if let playlist = currentPlaylist {
                                    onViewPlaylist(playlist)
                                }
                            } label: {
                                Text("View")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        } else {
                            Button {
                                onGoPro()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                    Text("Go Pro")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.yellow)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    } else {
                        // Not last page: show Next button
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            Text("Next")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.3), radius: 20)
            .padding(.horizontal, 32)
        }
    }
}
