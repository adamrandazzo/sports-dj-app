import SwiftUI
import StoreKit
import Core
import StoreService

public struct ProTabView: View {
    private let proStatus = ProStatusManager.shared
    private let storeKit = StoreKitManager.shared

    @State private var showingError = false
    @State private var purchaseSuccessful = false

    let heroSubtitle: String
    let seasonSubtitle: String
    let termsURL: URL
    let privacyURL: URL

    public init(
        heroSubtitle: String = "Unlock the full experience",
        seasonSubtitle: String = "Subscription",
        termsURL: URL,
        privacyURL: URL
    ) {
        self.heroSubtitle = heroSubtitle
        self.seasonSubtitle = seasonSubtitle
        self.termsURL = termsURL
        self.privacyURL = privacyURL
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if proStatus.isPro {
                    proActiveView
                } else {
                    heroSection
                    featuresSection
                    pricingSection
                    restoreSection
                    legalSection
                }
            }
            .padding()
        }
        .navigationTitle("Pro")
        .alert("Purchase Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(storeKit.errorMessage ?? "An unknown error occurred")
        }
        .alert("Welcome to Pro!", isPresented: $purchaseSuccessful) {
            Button("Let's Go!", role: .cancel) {}
        } message: {
            Text("You now have access to all Pro features. Enjoy unlimited songs, custom events, and more!")
        }
    }

    // MARK: - Pro Active View

    private var proActiveView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
                .padding(.top, 40)

            Text("You're Pro!")
                .font(.largeTitle)
                .fontWeight(.bold)

            if let type = proStatus.purchaseType {
                Text(type.displayName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if let expiration = proStatus.subscriptionExpirationDate {
                GroupBox {
                    HStack {
                        Text("Renews")
                        Spacer()
                        Text(expiration, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("Your Pro Benefits")
                    .font(.headline)

                ForEach(ProFeature.visibleFeatures) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(feature.title)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 50))
                .foregroundStyle(.yellow)

            Text("Upgrade to Pro")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(heroSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pro Features")
                .font(.headline)

            ForEach(ProFeature.visibleFeatures) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title)
                            .fontWeight(.semibold)
                        Text(feature.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Pricing Section

    private var pricingSection: some View {
        VStack(spacing: 16) {
            if storeKit.isLoading {
                ProgressView("Loading prices...")
                    .padding()
            } else if storeKit.products.isEmpty {
                VStack(spacing: 8) {
                    Text("Unable to load products")
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task {
                            await storeKit.loadProducts()
                        }
                    }
                }
                .padding()
            } else {
                let supportsLifetime = DJCoreConfiguration.shared.sportConfig?.supportsLifetimePurchase ?? false

                if let season = storeKit.seasonProduct {
                    PurchaseButton(
                        product: season,
                        title: "Season Pass",
                        subtitle: seasonSubtitle,
                        highlight: !supportsLifetime
                    ) {
                        await purchase(season)
                    }
                }

                if supportsLifetime, let lifetime = storeKit.lifetimeProduct {
                    PurchaseButton(
                        product: lifetime,
                        title: "Lifetime",
                        subtitle: "One-time purchase, forever",
                        highlight: true
                    ) {
                        await purchase(lifetime)
                    }
                }
            }
        }
    }

    // MARK: - Restore Section

    private var restoreSection: some View {
        Button {
            Task {
                await storeKit.restorePurchases()
                if proStatus.isPro {
                    purchaseSuccessful = true
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
        }
        .disabled(storeKit.isLoading)
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Service", destination: termsURL)
                Link("Privacy Policy", destination: privacyURL)
            }
            .font(.caption2)
        }
        .padding(.top)
    }

    // MARK: - Actions

    private func purchase(_ product: Product) async {
        let success = await storeKit.purchase(product)
        if success {
            purchaseSuccessful = true
        } else if storeKit.errorMessage != nil {
            showingError = true
        }
    }
}

// MARK: - Purchase Button

public struct PurchaseButton: View {
    let product: Product
    let title: String
    let subtitle: String
    let highlight: Bool
    let action: () async -> Void

    @State private var isPurchasing = false

    public init(product: Product, title: String, subtitle: String, highlight: Bool, action: @escaping () async -> Void) {
        self.product = product
        self.title = title
        self.subtitle = subtitle
        self.highlight = highlight
        self.action = action
    }

    public var body: some View {
        Button {
            isPurchasing = true
            Task {
                await action()
                isPurchasing = false
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(highlight ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if isPurchasing {
                    ProgressView()
                        .tint(highlight ? .white : .blue)
                } else {
                    Text(product.displayPrice)
                        .font(.headline)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(highlight ? Color.blue : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(highlight ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }
}
