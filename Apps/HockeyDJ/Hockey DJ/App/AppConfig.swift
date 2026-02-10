import Foundation

/// App-wide configuration constants (hockey-specific URLs and settings)
enum AppConfig {
    // MARK: - URLs

    /// Base URL for legal pages
    private static let legalBaseURL = "https://ultimatesportsdj.app/privacy"

    /// Terms of Service URL (falls back to Apple if URL is invalid)
    static var termsOfServiceURL: URL {
        URL(string: legalBaseURL) ?? URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    }

    /// Privacy Policy URL (falls back to Apple if URL is invalid)
    static var privacyPolicyURL: URL {
        URL(string: legalBaseURL) ?? URL(string: "https://www.apple.com/legal/privacy/")!
    }
}
