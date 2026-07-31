import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class AppLockController {
    private static let preferenceKey = "security.deviceLockEnabled"

    private(set) var isLocked: Bool
    private(set) var isUnlocking = false
    private(set) var errorMessage: String?
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.preferenceKey)
            isLocked = isEnabled
        }
    }

    init() {
        let enabled = UserDefaults.standard.bool(forKey: Self.preferenceKey)
        isEnabled = enabled
        isLocked = enabled
    }

    func lock() {
        guard isEnabled else { return }
        isLocked = true
        errorMessage = nil
    }

    func unlock() async {
        guard isEnabled, isLocked, !isUnlocking else {
            if !isEnabled { isLocked = false }
            return
        }

        isUnlocking = true
        errorMessage = nil
        defer { isUnlocking = false }

        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Avbryt")

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "Lås upp NorthBridge")
            )
            if success {
                isLocked = false
            }
        } catch {
            errorMessage = String(localized: "Upplåsningen avbröts eller kunde inte genomföras.")
        }
    }

    func disable() {
        isEnabled = false
        isLocked = false
        errorMessage = nil
    }

    func enableAfterVerifiedSetup() {
        isEnabled = true
        isLocked = false
        errorMessage = nil
    }
}
