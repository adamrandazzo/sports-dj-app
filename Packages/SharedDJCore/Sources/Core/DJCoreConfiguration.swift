import Foundation

public final class DJCoreConfiguration {
    public static let shared = DJCoreConfiguration()

    public private(set) var sportConfig: (any SportConfig.Type)?

    private init() {}

    public func configure(with config: (any SportConfig.Type)) {
        self.sportConfig = config
    }
}
