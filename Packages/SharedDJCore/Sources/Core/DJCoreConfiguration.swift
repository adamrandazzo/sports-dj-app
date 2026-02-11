import Foundation

public final class DJCoreConfiguration: @unchecked Sendable {
    public static let shared = DJCoreConfiguration()

    private var _sportConfig: (any SportConfig.Type)?
    private let lock = NSLock()

    public var sportConfig: (any SportConfig.Type)? {
        lock.lock()
        defer { lock.unlock() }
        return _sportConfig
    }

    private init() {}

    public func configure(with config: (any SportConfig.Type)) {
        lock.lock()
        defer { lock.unlock() }
        _sportConfig = config
    }
}
