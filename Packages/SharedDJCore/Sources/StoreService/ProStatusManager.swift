import Foundation
import Observation
import Core

/// Manages Pro subscription status across the app
@MainActor
@Observable
public final class ProStatusManager {
    public static let shared = ProStatusManager()

    // MARK: - State

    public private(set) var isPro: Bool = false
    public private(set) var purchaseType: PurchaseType?
    public private(set) var subscriptionExpirationDate: Date?
    public private(set) var isLoaded: Bool = false
    public private(set) var aiNameCredits: Int = 0
    public private(set) var isDebugOverride: Bool = false

    // MARK: - Types

    public enum PurchaseType: String, Codable {
        case subscription
        case lifetime

        public var displayName: String {
            switch self {
            case .subscription: return "Season Pass"
            case .lifetime: return "Lifetime"
            }
        }
    }

    // MARK: - Persistence Keys

    private let isProKey = "pro_status_is_pro"
    private let purchaseTypeKey = "pro_status_purchase_type"
    private let expirationDateKey = "pro_status_expiration_date"
    private let aiNameCreditsKey = "pro_status_ai_name_credits"
    private let debugOverrideKey = "pro_status_debug_override"

    // MARK: - Init

    private init() {
        loadStatus()
    }

    // MARK: - Limits (from SportConfig)

    private var freeLimits: TierLimits {
        DJCoreConfiguration.shared.sportConfig?.freeTierLimits ?? TierLimits(maxTeams: 1, maxPlayersPerTeam: 8, maxSongs: 10, aiNameCredits: 0)
    }

    private var proLimits: TierLimits {
        DJCoreConfiguration.shared.sportConfig?.proTierLimits ?? TierLimits(maxTeams: 3, maxPlayersPerTeam: 24, maxSongs: .max, aiNameCredits: 100)
    }

    // MARK: - Event Customization & Playback Limits

    public var canCustomizeEvents: Bool {
        isPro ? proLimits.canCustomizeEvents : freeLimits.canCustomizeEvents
    }

    public var canUseAllPlaybackModes: Bool {
        isPro ? proLimits.canUseAllPlaybackModes : freeLimits.canUseAllPlaybackModes
    }

    // MARK: - Team Limits

    public var maxTeams: Int {
        isPro ? proLimits.maxTeams : freeLimits.maxTeams
    }

    public func canAddTeam(currentCount: Int) -> Bool {
        currentCount < maxTeams
    }

    public func remainingTeamSlots(currentCount: Int) -> Int {
        max(0, maxTeams - currentCount)
    }

    // MARK: - Player Limits

    public var maxPlayersPerTeam: Int {
        isPro ? proLimits.maxPlayersPerTeam : freeLimits.maxPlayersPerTeam
    }

    public func canAddPlayer(currentCount: Int) -> Bool {
        currentCount < maxPlayersPerTeam
    }

    public func remainingPlayerSlots(currentCount: Int) -> Int {
        max(0, maxPlayersPerTeam - currentCount)
    }

    // MARK: - Song Limits

    public var freeSongLimit: Int {
        freeLimits.maxSongs
    }

    public var maxSongs: Int {
        isPro ? proLimits.maxSongs : freeLimits.maxSongs
    }

    public func canAddSongs(currentCount: Int, adding: Int = 1) -> Bool {
        if isPro { return true }
        return (currentCount + adding) <= freeLimits.maxSongs
    }

    public func remainingSongSlots(currentCount: Int) -> Int {
        if isPro { return Int.max }
        return max(0, freeLimits.maxSongs - currentCount)
    }

    // MARK: - AI Name Credits

    public var initialAINameCredits: Int {
        isPro ? proLimits.aiNameCredits : 0
    }

    public func hasAINameCredits() -> Bool {
        aiNameCredits > 0
    }

    @discardableResult
    public func useAINameCredit() -> Bool {
        guard aiNameCredits > 0 else { return false }
        aiNameCredits -= 1
        saveStatus()
        return true
    }

    public func resetAINameCredits() {
        aiNameCredits = initialAINameCredits
        saveStatus()
    }

    // MARK: - Debug Override

    public func setDebugOverride(_ enabled: Bool) {
        isDebugOverride = enabled
        UserDefaults.standard.set(enabled, forKey: debugOverrideKey)
        if enabled {
            grantPro(type: .subscription)
        } else {
            revokePro()
        }
    }

    // MARK: - Pro Status Management

    public func grantPro(type: PurchaseType, expirationDate: Date? = nil) {
        let previousType = purchaseType
        isPro = true
        purchaseType = type
        subscriptionExpirationDate = expirationDate

        // Reset AI credits on new subscription or upgrade
        if previousType != type {
            aiNameCredits = initialAINameCredits
        }

        saveStatus()
        Self.analyticsSetIsPro?(true)
    }

    public func revokePro() {
        isPro = false
        purchaseType = nil
        subscriptionExpirationDate = nil
        aiNameCredits = 0
        saveStatus()
        Self.analyticsSetIsPro?(false)
    }

    public func refreshStatus() async {
        await StoreKitManager.shared.updatePurchasedProducts()
    }

    // MARK: - Persistence

    private func loadStatus() {
        let defaults = UserDefaults.standard
        isPro = defaults.bool(forKey: isProKey)

        if let typeRaw = defaults.string(forKey: purchaseTypeKey) {
            purchaseType = PurchaseType(rawValue: typeRaw)
        }

        if let expiration = defaults.object(forKey: expirationDateKey) as? Date {
            subscriptionExpirationDate = expiration
        }

        aiNameCredits = defaults.integer(forKey: aiNameCreditsKey)
        isDebugOverride = defaults.bool(forKey: debugOverrideKey)

        isLoaded = true
    }

    private func saveStatus() {
        let defaults = UserDefaults.standard
        defaults.set(isPro, forKey: isProKey)
        defaults.set(purchaseType?.rawValue, forKey: purchaseTypeKey)
        defaults.set(subscriptionExpirationDate, forKey: expirationDateKey)
        defaults.set(aiNameCredits, forKey: aiNameCreditsKey)
        defaults.set(isDebugOverride, forKey: debugOverrideKey)
    }

    // MARK: - Analytics Callback

    public static var analyticsSetIsPro: ((_ isPro: Bool) -> Void)?
}
