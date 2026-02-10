import SwiftUI

public struct QuickStartOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var hasSeenQuickStart: Bool

    @State private var currentPage = 0

    private let pages: [QuickStartPageData]

    public init(hasSeenQuickStart: Binding<Bool>, pages: [QuickStartPageData]) {
        self._hasSeenQuickStart = hasSeenQuickStart
        self.pages = pages
    }

    private var totalPages: Int {
        pages.count
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
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        QuickStartPage(
                            icon: page.icon,
                            iconColor: page.iconColor,
                            title: page.title,
                            description: page.description
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)

                // Custom page indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 20)

                // Buttons
                HStack(spacing: 16) {
                    if currentPage < totalPages - 1 {
                        Button {
                            dismissOverlay()
                        } label: {
                            Text("Skip")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }

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
                    } else {
                        Button {
                            dismissOverlay()
                        } label: {
                            Text("Got it!")
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

    private func dismissOverlay() {
        hasSeenQuickStart = true
    }
}

// MARK: - Quick Start Page Data

public struct QuickStartPageData {
    public let icon: String
    public let iconColor: Color
    public let title: String
    public let description: String

    public init(icon: String, iconColor: Color, title: String, description: String) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
    }
}

// MARK: - Quick Start Page

public struct QuickStartPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    public init(icon: String, iconColor: Color, title: String, description: String) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
    }

    public var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 24)
    }
}
