import Foundation
import StoreKit
import Observation
import Core

/// Manages in-app purchases using StoreKit 2
@Observable
public final class StoreKitManager {
    public static let shared = StoreKitManager()

    // MARK: - State

    public private(set) var products: [Product] = []
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?
    public private(set) var isPurchasing: Bool = false

    // MARK: - Private

    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Init

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Computed Properties

    /// First subscription product (typically season pass)
    public var seasonProduct: Product? {
        products.first { $0.type == .autoRenewable }
    }

    /// First non-consumable product (typically lifetime)
    public var lifetimeProduct: Product? {
        products.first { $0.type == .nonConsumable }
    }

    // MARK: - Product Loading

    @MainActor
    public func loadProducts() async {
        guard products.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            let productIDs = DJCoreConfiguration.shared.sportConfig?.productIdentifiers ?? []
            products = try await Product.products(for: productIDs)
            products.sort { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Purchase

    @MainActor
    public func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handlePurchase(transaction)
                await transaction.finish()
                Self.analyticsPurchase?(product.id)
                isPurchasing = false
                return true

            case .userCancelled:
                isPurchasing = false
                return false

            case .pending:
                errorMessage = "Purchase is pending approval"
                isPurchasing = false
                return false

            @unknown default:
                errorMessage = "Unknown purchase result"
                isPurchasing = false
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            isPurchasing = false
            return false
        }
    }

    // MARK: - Restore Purchases

    @MainActor
    public func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Transaction Handling

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.handlePurchase(transaction)
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }

    @MainActor
    private func handlePurchase(_ transaction: Transaction) async {
        let productID = transaction.productID

        if let expirationDate = transaction.expirationDate {
            if expirationDate > Date() {
                ProStatusManager.shared.grantPro(
                    type: .subscription,
                    expirationDate: expirationDate
                )
            } else {
                ProStatusManager.shared.revokePro()
            }
        } else {
            // Lifetime purchase (no expiration)
            ProStatusManager.shared.grantPro(type: .lifetime)
        }
    }

    @MainActor
    public func updatePurchasedProducts() async {
        var hasValidPurchase = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if let expirationDate = transaction.expirationDate {
                    if expirationDate > Date() {
                        ProStatusManager.shared.grantPro(
                            type: .subscription,
                            expirationDate: expirationDate
                        )
                        hasValidPurchase = true
                    }
                } else {
                    // Lifetime - always valid
                    ProStatusManager.shared.grantPro(type: .lifetime)
                    hasValidPurchase = true
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        // If no valid purchases found and no debug override, revoke Pro
        if !hasValidPurchase && !ProStatusManager.shared.isDebugOverride {
            ProStatusManager.shared.revokePro()
        }
    }

    // MARK: - Analytics Callback

    public static var analyticsPurchase: ((_ productID: String) -> Void)?
}
