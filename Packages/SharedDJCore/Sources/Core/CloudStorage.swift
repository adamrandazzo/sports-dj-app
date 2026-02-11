import SwiftUI
import Combine

/// Property wrapper that syncs values to iCloud Key-Value Store
/// Falls back to UserDefaults if iCloud is unavailable
@propertyWrapper
public struct CloudStorage<Value>: DynamicProperty {
    @StateObject private var observer: CloudStorageObserver<Value>

    private let key: String
    private let defaultValue: Value
    private let store = NSUbiquitousKeyValueStore.default

    private var value: Value {
        get { observer.value }
        nonmutating set { observer.value = newValue }
    }

    public init(wrappedValue: Value, _ key: String) where Value == Bool {
        self.key = key
        self.defaultValue = wrappedValue
        _observer = StateObject(wrappedValue: CloudStorageObserver(key: key, defaultValue: wrappedValue, valueType: .bool))
    }

    public init(wrappedValue: Value, _ key: String) where Value == Int {
        self.key = key
        self.defaultValue = wrappedValue
        _observer = StateObject(wrappedValue: CloudStorageObserver(key: key, defaultValue: wrappedValue, valueType: .int))
    }

    public init(wrappedValue: Value, _ key: String) where Value == Double {
        self.key = key
        self.defaultValue = wrappedValue
        _observer = StateObject(wrappedValue: CloudStorageObserver(key: key, defaultValue: wrappedValue, valueType: .double))
    }

    public init(wrappedValue: Value, _ key: String) where Value == String {
        self.key = key
        self.defaultValue = wrappedValue
        _observer = StateObject(wrappedValue: CloudStorageObserver(key: key, defaultValue: wrappedValue, valueType: .string))
    }

    public var wrappedValue: Value {
        get { value }
        nonmutating set { value = newValue }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { observer.value },
            set: { observer.value = $0 }
        )
    }
}

// MARK: - Observer Class

private enum CloudStorageValueType {
    case bool, int, double, string
}

@MainActor
private class CloudStorageObserver<Value>: ObservableObject {
    @Published var value: Value {
        didSet {
            guard !isUpdatingFromNotification else { return }
            store.set(value, forKey: key)
            store.synchronize()
            NotificationCenter.default.post(
                name: Self.localChangeNotification,
                object: nil,
                userInfo: ["key": key]
            )
        }
    }

    private let key: String
    private let defaultValue: Value
    private let valueType: CloudStorageValueType
    private let store = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()
    private var isUpdatingFromNotification = false

    private static var localChangeNotification: Notification.Name {
        Notification.Name("CloudStorageLocalChange")
    }

    deinit {
        cancellables.removeAll()
    }

    init(key: String, defaultValue: Value, valueType: CloudStorageValueType) {
        self.key = key
        self.defaultValue = defaultValue
        self.valueType = valueType

        self.value = Self.loadValue(key: key, defaultValue: defaultValue, valueType: valueType, store: store)

        NotificationCenter.default
            .publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleStoreChange(notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: Self.localChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleLocalChange(notification)
            }
            .store(in: &cancellables)
    }

    private static func loadValue(key: String, defaultValue: Value, valueType: CloudStorageValueType, store: NSUbiquitousKeyValueStore) -> Value {
        if store.object(forKey: key) != nil {
            switch valueType {
            case .bool:
                return (store.bool(forKey: key) as? Value) ?? defaultValue
            case .int:
                let intValue = store.object(forKey: key) as? Int ?? (defaultValue as? Int ?? 0)
                return (intValue as? Value) ?? defaultValue
            case .double:
                return (store.double(forKey: key) as? Value) ?? defaultValue
            case .string:
                let stringValue = store.string(forKey: key) ?? (defaultValue as? String ?? "")
                return (stringValue as? Value) ?? defaultValue
            }
        } else if UserDefaults.standard.object(forKey: key) != nil {
            let existingValue: Value
            switch valueType {
            case .bool:
                existingValue = (UserDefaults.standard.bool(forKey: key) as? Value) ?? defaultValue
            case .int:
                existingValue = (UserDefaults.standard.integer(forKey: key) as? Value) ?? defaultValue
            case .double:
                existingValue = (UserDefaults.standard.double(forKey: key) as? Value) ?? defaultValue
            case .string:
                let stringValue = UserDefaults.standard.string(forKey: key) ?? (defaultValue as? String ?? "")
                existingValue = (stringValue as? Value) ?? defaultValue
            }
            store.set(existingValue, forKey: key)
            return existingValue
        }
        return defaultValue
    }

    private func handleStoreChange(_ notification: Notification) {
        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
              changedKeys.contains(key) else {
            return
        }

        reloadFromStore()
    }

    private func handleLocalChange(_ notification: Notification) {
        guard let changedKey = notification.userInfo?["key"] as? String,
              changedKey == key else {
            return
        }

        reloadFromStore()
    }

    private func reloadFromStore() {
        let newValue = Self.loadValue(key: key, defaultValue: defaultValue, valueType: valueType, store: store)
        if !isEqual(value, newValue) {
            isUpdatingFromNotification = true
            value = newValue
            isUpdatingFromNotification = false
        }
    }

    private func isEqual(_ lhs: Value, _ rhs: Value) -> Bool {
        switch valueType {
        case .bool:
            guard let l = lhs as? Bool, let r = rhs as? Bool else { return false }
            return l == r
        case .int:
            guard let l = lhs as? Int, let r = rhs as? Int else { return false }
            return l == r
        case .double:
            guard let l = lhs as? Double, let r = rhs as? Double else { return false }
            return l == r
        case .string:
            guard let l = lhs as? String, let r = rhs as? String else { return false }
            return l == r
        }
    }
}
