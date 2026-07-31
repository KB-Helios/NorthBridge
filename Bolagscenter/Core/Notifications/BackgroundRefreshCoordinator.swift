import BackgroundTasks
import Foundation
import WidgetKit

enum BackgroundRefreshCoordinator {
    static let identifier = "com.kbhelios.northbridge.refresh"

    static func register() {
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            schedule()
            let handle = BackgroundRefreshTaskHandle(task: refreshTask)
            handle.installExpirationHandler()
            let operation = Task {
                let success = await performMaintenance(handle: handle)
                handle.complete(success: success && !Task.isCancelled)
            }
            handle.track(operation)
        }
        if !registered {
            SecureLogger.app.error("Background refresh handler registration failed")
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = .now.addingTimeInterval(6 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            SecureLogger.app.error(
                "Background refresh scheduling failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }

    private static func performMaintenance(
        handle: BackgroundRefreshTaskHandle
    ) async -> Bool {
        guard !Task.isCancelled, !handle.isExpired else { return false }
        _ = await NotificationScheduler().pendingCount()
        guard !Task.isCancelled, !handle.isExpired else { return false }
        await MainActor.run {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return !Task.isCancelled && !handle.isExpired
    }
}

private final class BackgroundRefreshTaskHandle: @unchecked Sendable {
    private let task: BGAppRefreshTask
    private let lock = NSLock()
    private var operation: Task<Void, Never>?
    private var expired = false
    private var completed = false

    init(task: BGAppRefreshTask) {
        self.task = task
    }

    var isExpired: Bool {
        lock.withLock { expired }
    }

    func installExpirationHandler() {
        task.expirationHandler = { [weak self] in
            self?.expire()
        }
    }

    func track(_ operation: Task<Void, Never>) {
        lock.withLock {
            self.operation = operation
        }
    }

    func complete(success: Bool) {
        let shouldComplete = lock.withLock {
            guard !completed else { return false }
            completed = true
            operation = nil
            return true
        }
        guard shouldComplete else { return }
        task.setTaskCompleted(success: success)
    }

    private func expire() {
        let operation = lock.withLock {
            expired = true
            return self.operation
        }
        operation?.cancel()
    }
}
