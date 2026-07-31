import Foundation
import Observation
import UserNotifications

enum NotificationAuthorizationState: Equatable, Sendable {
    case unknown
    case denied
    case authorized
    case provisional
    case ephemeral

    var localizedName: String {
        switch self {
        case .unknown: "Inte tillfrågad"
        case .denied: "Nekad"
        case .authorized: "Tillåten"
        case .provisional: "Provisorisk"
        case .ephemeral: "Tillfällig"
        }
    }
}

struct NotificationPreferenceSnapshot: Sendable {
    let category: NotificationCategory
    let isEnabled: Bool
    let leadTimeDays: Int
    let showsSensitiveDetails: Bool
}

struct DeadlineNotificationSnapshot: Sendable {
    let id: UUID
    let companyID: UUID
    let title: String
    let dueAt: Date
    let status: DeadlineStatus
    let reminderIsEnabled: Bool?
    let reminderLeadTimeDays: Int?
}

struct ActionNotificationSnapshot: Sendable {
    let id: UUID
    let companyID: UUID
    let title: String
    let assignedTo: String
    let dueAt: Date
    let status: ActionItemStatus
}

struct DocumentExpirationSnapshot: Sendable {
    let id: UUID
    let companyID: UUID
    let title: String
    let expiresAt: Date
}

struct IntegrationFailureSnapshot: Sendable {
    let id: UUID
    let companyID: UUID
    let displayName: String
    let state: IntegrationState
}

struct ApprovalNotificationSnapshot: Sendable {
    let id: UUID
    let companyID: UUID
    let title: String
    let status: ResolutionStatus
}

struct NotificationScheduleInput: Sendable {
    let preferences: [NotificationPreferenceSnapshot]
    let deadlines: [DeadlineNotificationSnapshot]
    let actions: [ActionNotificationSnapshot]
    let documents: [DocumentExpirationSnapshot]
    let integrations: [IntegrationFailureSnapshot]
    let approvals: [ApprovalNotificationSnapshot]
}

struct NotificationDatePolicy: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func reminderDate(
        targetDate: Date,
        leadTimeDays: Int,
        now: Date = .now
    ) -> Date? {
        guard targetDate > now else {
            return nil
        }
        guard let reminderDate = calendar.date(
            byAdding: .day,
            value: -max(0, leadTimeDays),
            to: targetDate
        ) else {
            return nil
        }
        let morning = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: reminderDate
        ) ?? reminderDate
        return morning > now ? morning : nil
    }
}

actor NotificationScheduler {
    private static let identifierPrefix = "com.kbhelios.northbridge.local."
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.center = center
        self.calendar = calendar
    }

    func authorizationState() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        return switch settings.authorizationStatus {
        case .notDetermined: .unknown
        case .denied: .denied
        case .authorized: .authorized
        case .provisional: .provisional
        case .ephemeral: .ephemeral
        @unknown default: .unknown
        }
    }

    func requestAuthorization() async throws -> NotificationAuthorizationState {
        _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        return await authorizationState()
    }

    func synchronize(_ input: NotificationScheduleInput) async throws {
        let pending = await center.pendingNotificationRequests()
        let ownedIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ownedIdentifiers)

        let preferences = Dictionary(
            uniqueKeysWithValues: input.preferences.map { ($0.category, $0) }
        )
        var requests: [UNNotificationRequest] = []

        if let preference = preferences[.deadlines], preference.isEnabled {
            requests += input.deadlines.compactMap {
                deadlineRequest(for: $0, preference: preference)
            }
        }
        if let preference = preferences[.assignedActions], preference.isEnabled {
            requests += input.actions.compactMap {
                actionRequest(for: $0, preference: preference)
            }
        }
        if let preference = preferences[.expiringContracts], preference.isEnabled {
            requests += input.documents.compactMap {
                documentRequest(for: $0, preference: preference)
            }
        }
        if let preference = preferences[.integrations], preference.isEnabled {
            requests += input.integrations.compactMap {
                integrationRequest(for: $0, preference: preference)
            }
        }
        if let preference = preferences[.approvals], preference.isEnabled {
            requests += input.approvals.compactMap {
                approvalRequest(for: $0, preference: preference)
            }
        }

        for request in requests {
            try Task.checkCancellation()
            try await center.add(request)
        }
    }

    func pendingCount() async -> Int {
        await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
            .count
    }

    func updateDeadline(
        _ deadline: DeadlineNotificationSnapshot,
        preference: NotificationPreferenceSnapshot
    ) async throws {
        let identifier = deadlineIdentifier(deadline.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard preference.isEnabled,
              let request = deadlineRequest(
                for: deadline,
                preference: preference
              ) else {
            return
        }
        try await center.add(request)
    }

    func removeAllOwnedRequests() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeAllDeliveredNotifications()
    }

    private func deadlineRequest(
        for deadline: DeadlineNotificationSnapshot,
        preference: NotificationPreferenceSnapshot
    ) -> UNNotificationRequest? {
        guard deadline.reminderIsEnabled != false,
              deadline.status != .completed,
              deadline.status != .dismissed,
              let trigger = calendarTrigger(
                targetDate: deadline.dueAt,
                leadTimeDays: deadline.reminderLeadTimeDays
                    ?? preference.leadTimeDays
              ) else {
            return nil
        }
        let content = UNMutableNotificationContent()
        content.title = preference.showsSensitiveDetails
            ? deadline.title
            : String(localized: "NorthBridge")
        content.body = preference.showsSensitiveDetails
            ? String(localized: "Deadline \(deadline.dueAt.formatted(date: .abbreviated, time: .omitted))")
            : String(localized: "En bolagsdeadline närmar sig.")
        content.sound = .default
        content.threadIdentifier = deadline.companyID.uuidString
        content.userInfo = [
            "url": "northbridge://deadline/\(deadline.id.uuidString)"
        ]
        return UNNotificationRequest(
            identifier: deadlineIdentifier(deadline.id),
            content: content,
            trigger: trigger
        )
    }

    private func deadlineIdentifier(_ id: UUID) -> String {
        "\(Self.identifierPrefix)deadline.\(id.uuidString)"
    }

    private func actionRequest(
        for action: ActionNotificationSnapshot,
        preference: NotificationPreferenceSnapshot
    ) -> UNNotificationRequest? {
        guard action.status != .completed,
              let trigger = calendarTrigger(
                targetDate: action.dueAt,
                leadTimeDays: preference.leadTimeDays
              ) else {
            return nil
        }
        let content = UNMutableNotificationContent()
        content.title = preference.showsSensitiveDetails
            ? action.title
            : String(localized: "NorthBridge")
        content.body = preference.showsSensitiveDetails
            ? String(localized: "Tilldelad till \(action.assignedTo)")
            : String(localized: "En tilldelad åtgärd behöver följas upp.")
        content.sound = .default
        content.threadIdentifier = action.companyID.uuidString
        content.userInfo = [
            "url": "northbridge://action/\(action.id.uuidString)"
        ]
        return UNNotificationRequest(
            identifier: "\(Self.identifierPrefix)action.\(action.id.uuidString)",
            content: content,
            trigger: trigger
        )
    }

    private func documentRequest(
        for document: DocumentExpirationSnapshot,
        preference: NotificationPreferenceSnapshot
    ) -> UNNotificationRequest? {
        guard let trigger = calendarTrigger(
            targetDate: document.expiresAt,
            leadTimeDays: preference.leadTimeDays
        ) else {
            return nil
        }
        let content = UNMutableNotificationContent()
        content.title = preference.showsSensitiveDetails
            ? document.title
            : String(localized: "NorthBridge")
        content.body = preference.showsSensitiveDetails
            ? String(localized: "Dokumentet löper snart ut.")
            : String(localized: "Ett bolagsdokument löper snart ut.")
        content.sound = .default
        content.threadIdentifier = document.companyID.uuidString
        content.userInfo = [
            "url": "northbridge://document/\(document.id.uuidString)"
        ]
        return UNNotificationRequest(
            identifier: "\(Self.identifierPrefix)document.\(document.id.uuidString)",
            content: content,
            trigger: trigger
        )
    }

    private func integrationRequest(
        for integration: IntegrationFailureSnapshot,
        preference: NotificationPreferenceSnapshot
    ) -> UNNotificationRequest? {
        guard integration.state == .failed || integration.state == .unauthorized else {
            return nil
        }
        let content = UNMutableNotificationContent()
        content.title = preference.showsSensitiveDetails
            ? integration.displayName
            : String(localized: "NorthBridge")
        content.body = preference.showsSensitiveDetails
            ? String(localized: "Integrationen behöver åtgärdas.")
            : String(localized: "En bolagsintegration behöver åtgärdas.")
        content.sound = .default
        content.threadIdentifier = integration.companyID.uuidString
        content.userInfo = ["url": "northbridge://integrations"]
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 60,
            repeats: false
        )
        return UNNotificationRequest(
            identifier: "\(Self.identifierPrefix)integration.\(integration.id.uuidString)",
            content: content,
            trigger: trigger
        )
    }

    private func approvalRequest(
        for approval: ApprovalNotificationSnapshot,
        preference: NotificationPreferenceSnapshot
    ) -> UNNotificationRequest? {
        guard approval.status == .draft else { return nil }
        let content = UNMutableNotificationContent()
        content.title = preference.showsSensitiveDetails
            ? approval.title
            : String(localized: "NorthBridge")
        content.body = preference.showsSensitiveDetails
            ? String(localized: "Ett beslutsutkast väntar på behandling.")
            : String(localized: "Ett bolagsärende väntar på behandling.")
        content.sound = .default
        content.threadIdentifier = approval.companyID.uuidString
        content.userInfo = [
            "url": "northbridge://resolution/\(approval.id.uuidString)"
        ]
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 60,
            repeats: false
        )
        return UNNotificationRequest(
            identifier: "\(Self.identifierPrefix)approval.\(approval.id.uuidString)",
            content: content,
            trigger: trigger
        )
    }

    private func calendarTrigger(
        targetDate: Date,
        leadTimeDays: Int
    ) -> UNCalendarNotificationTrigger? {
        guard let morning = NotificationDatePolicy(calendar: calendar)
            .reminderDate(
                targetDate: targetDate,
                leadTimeDays: leadTimeDays
            ) else { return nil }
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: morning
        )
        return UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
    }
}

@MainActor
final class NotificationResponseRouter: NSObject,
    @preconcurrency UNUserNotificationCenterDelegate {
    var onOpenURL: ((URL) -> Void)?

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let value = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: value) else {
            return
        }
        onOpenURL?(url)
    }
}
