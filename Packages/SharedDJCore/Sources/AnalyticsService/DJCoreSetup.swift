import Core

public struct DJCoreSetup {
    public static func configure(with config: (any SportConfig.Type)) {
        DJCoreConfiguration.shared.configure(with: config)
        // Firebase configured by app target (needs GoogleService-Info.plist in app bundle)
    }
}
