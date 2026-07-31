import Foundation

struct WidgetSnapshot: Codable, Sendable {
    let deadlineTitle: String?
    let deadlineDate: Date?
    let openDeadlineCount: Int
    let openActionCount: Int
    let pulseFactors: [String]
    let availableLiquidity: Double?
    let liquidityCurrencyCode: String?
    let liquiditySourceUpdatedAt: Date?
    let showsSensitiveData: Bool
    let updatedAt: Date

    static let empty = WidgetSnapshot(
        deadlineTitle: nil,
        deadlineDate: nil,
        openDeadlineCount: 0,
        openActionCount: 0,
        pulseFactors: [],
        availableLiquidity: nil,
        liquidityCurrencyCode: nil,
        liquiditySourceUpdatedAt: nil,
        showsSensitiveData: false,
        updatedAt: .distantPast
    )
}

enum WidgetSnapshotStore {
    private static let suiteName = "group.com.kbhelios.northbridge"
    private static let snapshotKey = "widget.snapshot"

    static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshot) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw WidgetSnapshotError.appGroupUnavailable
        }
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: snapshotKey)
    }

    static func clear() {
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: snapshotKey)
    }
}

enum WidgetSnapshotError: Error {
    case appGroupUnavailable
}

enum WidgetPrivacyPreference {
    private static let suiteName = "group.com.kbhelios.northbridge"
    private static let key = "widget.showsSensitiveData"

    static var showsSensitiveData: Bool {
        get {
            UserDefaults(suiteName: suiteName)?.bool(forKey: key) ?? false
        }
        set {
            UserDefaults(suiteName: suiteName)?.set(newValue, forKey: key)
        }
    }

    static func reset() {
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: key)
    }
}
