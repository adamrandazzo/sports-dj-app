import SwiftUI
import AnalyticsService
import StoreService

// MARK: - Environment Key for Tab Navigation

private struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: Binding<Int>? = nil
}

extension EnvironmentValues {
    public var selectedTab: Binding<Int>? {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

/// A blocking modal that prompts users to upgrade to Pro
public struct UpgradePromptView: View {
    let feature: ProFeature
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    public init(feature: ProFeature, onUpgrade: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.feature = feature
        self.onUpgrade = onUpgrade
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "star.fill")
                .font(.system(size: 50))
                .foregroundStyle(.yellow)

            // Title
            VStack(spacing: 8) {
                Text("Pro Feature")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(feature.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text(feature.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Buttons
            VStack(spacing: 12) {
                Button {
                    AnalyticsService.upgradePromptTapped(feature: feature.rawValue)
                    onUpgrade()
                } label: {
                    Text("Upgrade to Pro")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Not Now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
        .padding(32)
        .onAppear {
            AnalyticsService.upgradePromptShown(feature: feature.rawValue)
        }
    }
}

/// View modifier for showing upgrade prompt as a sheet
public struct UpgradePromptModifier: ViewModifier {
    @Environment(\.selectedTab) private var selectedTab
    @Binding var isPresented: Bool
    let feature: ProFeature
    let proTabIndex: Int
    let onUpgrade: () -> Void

    public init(isPresented: Binding<Bool>, feature: ProFeature, proTabIndex: Int = 2, onUpgrade: @escaping () -> Void) {
        self._isPresented = isPresented
        self.feature = feature
        self.proTabIndex = proTabIndex
        self.onUpgrade = onUpgrade
    }

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                UpgradePromptView(
                    feature: feature,
                    onUpgrade: {
                        isPresented = false
                        // Navigate to Pro tab
                        selectedTab?.wrappedValue = proTabIndex
                        onUpgrade()
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    /// Shows an upgrade prompt sheet for a Pro feature
    public func upgradePrompt(
        isPresented: Binding<Bool>,
        feature: ProFeature,
        onUpgrade: @escaping () -> Void
    ) -> some View {
        modifier(UpgradePromptModifier(
            isPresented: isPresented,
            feature: feature,
            onUpgrade: onUpgrade
        ))
    }
}
