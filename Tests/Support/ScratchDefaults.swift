import Foundation

/// Throwaway `UserDefaults` for tests, kept in memory only. A real suite
/// (`UserDefaults(suiteName:)`) is persisted by cfprefsd to
/// `~/Library/Preferences/<suite>.plist` — asynchronously, even after the test
/// process exits — so every run used to leave dozens of files behind.
///
/// The typed accessors (`string(forKey:)`, `integer(forKey:)`, `bool(forKey:)`,
/// `set(_:forKey:)` with Int/Bool…) all route through the three overrides below.
final class ScratchDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Any] = [:]

    static func make() -> ScratchDefaults { ScratchDefaults(suiteName: nil)! }

    override func object(forKey defaultName: String) -> Any? {
        lock.withLock { storage[defaultName] }
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        lock.withLock { storage[defaultName] = value }
    }

    override func removeObject(forKey defaultName: String) {
        lock.withLock { storage[defaultName] = nil }
    }
}
