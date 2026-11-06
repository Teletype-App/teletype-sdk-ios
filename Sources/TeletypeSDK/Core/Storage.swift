import Foundation

public protocol KeyValueStore: AnyObject {
    func getItem(_ key: String) async -> String?
    func setItem(_ key: String, _ value: String) async
    func removeItem(_ key: String) async
}

public final class MemoryStore: KeyValueStore {
    private var map: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func getItem(_ key: String) async -> String? {
        lock.lock(); defer { lock.unlock() }
        return map[key]
    }

    public func setItem(_ key: String, _ value: String) async {
        lock.lock(); defer { lock.unlock() }
        map[key] = value
    }

    public func removeItem(_ key: String) async {
        lock.lock(); defer { lock.unlock() }
        map.removeValue(forKey: key)
    }
}

/// Default persistence: `UserDefaults`, namespaced like the web widget.
public final class UserDefaultsStore: KeyValueStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func getItem(_ key: String) async -> String? {
        defaults.string(forKey: key)
    }

    public func setItem(_ key: String, _ value: String) async {
        defaults.set(value, forKey: key)
    }

    public func removeItem(_ key: String) async {
        defaults.removeObject(forKey: key)
    }

    public func removeKeys(matching predicate: (String) -> Bool) {
        for key in defaults.dictionaryRepresentation().keys where predicate(key) {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Persistence abstraction. Mirrors `teletype-{apiId}-{key}` localStorage.
public final class TeletypeStorage {
    private let backend: KeyValueStore
    private let apiId: String
    private var cache: [String: Any] = [:]
    private let lock = NSLock()

    public init(apiId: String, backend: KeyValueStore? = nil) {
        self.apiId = apiId
        self.backend = backend ?? UserDefaultsStore()
    }

    private func fullKey(_ key: String) -> String {
        "teletype-\(apiId)-\(key)"
    }

    public func hydrate(_ keys: [String]) async {
        for key in keys {
            let raw = await backend.getItem(fullKey(key))
            lock.lock()
            cache[key] = parse(raw)
            lock.unlock()
        }
    }

    private func parse(_ raw: String?) -> Any? {
        guard let raw else { return nil }
        if let data = raw.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        {
            return obj
        }
        return raw
    }

    public func get<T>(_ key: String, default defaultValue: T) -> T {
        lock.lock(); defer { lock.unlock() }
        guard let value = cache[key] else { return defaultValue }
        if let typed = value as? T { return typed }
        if let n = value as? NSNumber {
            if T.self == Double.self, let v = n.doubleValue as? T { return v }
            if T.self == Int.self, let v = n.intValue as? T { return v }
            if T.self == Bool.self, let v = n.boolValue as? T { return v }
            if T.self == String.self, let v = n.stringValue as? T { return v }
        }
        if let s = value as? String, T.self == String.self, let v = s as? T { return v }
        return defaultValue
    }

    public func getAny(_ key: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        return cache[key]
    }

    public func set(_ key: String, _ value: Any?) {
        lock.lock()
        if let value {
            cache[key] = value
        } else {
            cache.removeValue(forKey: key)
        }
        lock.unlock()
        Task {
            if let value {
                let data: Data?
                if JSONSerialization.isValidJSONObject(value) {
                    data = try? JSONSerialization.data(withJSONObject: value)
                } else {
                    data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
                }
                let payload: String
                if let data, let s = String(data: data, encoding: .utf8) {
                    payload = s
                } else if let s = value as? String {
                    payload = (try? String(data: JSONSerialization.data(withJSONObject: s, options: [.fragmentsAllowed]), encoding: .utf8)) ?? "\"\(s)\""
                } else {
                    payload = "\(value)"
                }
                await backend.setItem(fullKey(key), payload)
            } else {
                await backend.removeItem(fullKey(key))
            }
        }
    }

    public func remove(_ key: String) {
        lock.lock()
        cache.removeValue(forKey: key)
        lock.unlock()
        Task { await backend.removeItem(fullKey(key)) }
    }
}
