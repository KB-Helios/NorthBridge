import Foundation
import OSLog

enum SecureLogger {
    static let app = Logger(subsystem: "com.kbhelios.northbridge", category: "app")
    static let persistence = Logger(subsystem: "com.kbhelios.northbridge", category: "persistence")
    static let security = Logger(subsystem: "com.kbhelios.northbridge", category: "security")
    static let network = Logger(subsystem: "com.kbhelios.northbridge", category: "network")

    static func redactedIdentifier(_ identifier: String) -> String {
        guard identifier.count > 4 else { return "••••" }
        return "••••\(identifier.suffix(4))"
    }
}
