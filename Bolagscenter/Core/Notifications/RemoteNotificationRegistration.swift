import Foundation
import UIKit
import UserNotifications

enum APNsTokenEnvironment: String, Codable, Sendable {
    case sandbox
    case production

    static var current: Self {
        configured(
            buildSetting: Bundle.main.object(
                forInfoDictionaryKey: "APNSEnvironment"
            ) as? String
        )
    }

    static func configured(buildSetting: String?) -> Self {
        switch buildSetting?.lowercased() {
        case "development":
            .sandbox
        case "production":
            .production
        default:
        #if DEBUG
            .sandbox
        #else
            .production
        #endif
        }
    }
}

enum APNsAuthorizationState: String, Codable, Equatable, Sendable {
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        case .notDetermined:
            self = .unknown
        @unknown default:
            self = .unknown
        }
    }
}

struct APNsTokenSnapshot: Codable, Equatable, Sendable {
    let installationID: String
    let token: String
    let environment: APNsTokenEnvironment
    let authorization: APNsAuthorizationState
    let receivedAt: Date
    let appVersion: String
    let locale: String
}

enum APNsDeviceTokenFormatter {
    static func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

struct RemoteNotificationRegistrationReceipt: Decodable, Equatable, Sendable {
    let installationID: String
    let registeredAt: Date
    let status: String

    enum CodingKeys: String, CodingKey {
        case installationID = "installation_id"
        case registeredAt = "registered_at"
        case status
    }
}

private struct RemoteNotificationRegistrationRequest: Encodable, Sendable {
    let platform: String
    let apnsToken: String
    let apnsEnvironment: String
    let authorization: String
    let showsSensitiveDetails: Bool
    let appVersion: String
    let locale: String
    let receivedAt: Date

    enum CodingKeys: String, CodingKey {
        case platform
        case apnsToken = "apns_token"
        case apnsEnvironment = "apns_environment"
        case authorization
        case showsSensitiveDetails = "shows_sensitive_details"
        case appVersion = "app_version"
        case locale
        case receivedAt = "received_at"
    }
}

protocol RemoteNotificationRegistrationService: Sendable {
    func register(
        _ snapshot: APNsTokenSnapshot
    ) async throws -> RemoteNotificationRegistrationReceipt

    func unregister(installationID: String) async throws
}

enum RemoteNotificationRegistrationError: LocalizedError, Equatable, Sendable {
    case backendUnavailable

    var errorDescription: String? {
        "Fjärrnotiser väntar på en konfigurerad backend."
    }
}

struct UnavailableRemoteNotificationRegistrationService:
    RemoteNotificationRegistrationService {
    func register(
        _ snapshot: APNsTokenSnapshot
    ) async throws -> RemoteNotificationRegistrationReceipt {
        throw RemoteNotificationRegistrationError.backendUnavailable
    }

    func unregister(installationID: String) async throws {
        throw RemoteNotificationRegistrationError.backendUnavailable
    }
}

struct BackendRemoteNotificationRegistrationService:
    RemoteNotificationRegistrationService {
    let client: HTTPClient

    func register(
        _ snapshot: APNsTokenSnapshot
    ) async throws -> RemoteNotificationRegistrationReceipt {
        let payload = RemoteNotificationRegistrationRequest(
            platform: "ios",
            apnsToken: snapshot.token,
            apnsEnvironment: snapshot.environment.rawValue,
            authorization: snapshot.authorization.rawValue,
            showsSensitiveDetails: false,
            appVersion: snapshot.appVersion,
            locale: snapshot.locale,
            receivedAt: snapshot.receivedAt
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(payload)
        let request = APIRequest<RemoteNotificationRegistrationReceipt>(
            method: .put,
            path: "/v1/notification-installations/\(snapshot.installationID)",
            body: body,
            cachePolicy: .reloadIgnoringCache,
            requiresAuthentication: true,
            queuesWhenOffline: false
        )
        return try await client.send(request)
    }

    func unregister(installationID: String) async throws {
        let request = APIRequest<RemoteNotificationRegistrationReceipt>(
            method: .delete,
            path: "/v1/notification-installations/\(installationID)",
            cachePolicy: .reloadIgnoringCache,
            requiresAuthentication: true,
            queuesWhenOffline: false
        )
        let _: RemoteNotificationRegistrationReceipt = try await client.send(
            request
        )
    }
}

extension Notification.Name {
    static let northBridgeAPNsTokenDidChange = Notification.Name(
        "NorthBridgeAPNsTokenDidChange"
    )
}

@MainActor
final class RemoteNotificationRegistrationCoordinator: NSObject {
    enum State: Equatable {
        case idle
        case registering
        case registered(Date)
        case awaitingBackend
        case failed
    }

    private(set) var state: State = .idle
    private let service: any RemoteNotificationRegistrationService

    init(service: any RemoteNotificationRegistrationService) {
        self.service = service
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceTokenDidChange(_:)),
            name: .northBridgeAPNsTokenDidChange,
            object: nil
        )
    }

    func unregisterCurrentInstallation() async {
        guard let installationID = UIDevice.current.identifierForVendor?
            .uuidString else {
            return
        }
        do {
            try await service.unregister(installationID: installationID)
            state = .idle
        } catch RemoteNotificationRegistrationError.backendUnavailable {
            state = .awaitingBackend
        } catch {
            state = .failed
            SecureLogger.network.error(
                "Backend APNs unregistration failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }

    @objc
    private func deviceTokenDidChange(_ notification: Notification) {
        guard let snapshot = notification.object as? APNsTokenSnapshot else {
            return
        }
        state = .registering
        Task {
            do {
                let receipt = try await service.register(snapshot)
                state = .registered(receipt.registeredAt)
            } catch RemoteNotificationRegistrationError.backendUnavailable {
                state = .awaitingBackend
            } catch {
                state = .failed
                SecureLogger.network.error(
                    "Backend APNs registration failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
                )
            }
        }
    }
}

@MainActor
final class NorthBridgeAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [
            UIApplication.LaunchOptionsKey: Any
        ]? = nil
    ) -> Bool {
        Task {
            let status = await UNUserNotificationCenter.current()
                .notificationSettings()
                .authorizationStatus
            guard status == .authorized
                    || status == .provisional
                    || status == .ephemeral else {
                return
            }
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = APNsDeviceTokenFormatter.hexString(from: deviceToken)
        Task {
            let settings = await UNUserNotificationCenter.current()
                .notificationSettings()
            let snapshot = APNsTokenSnapshot(
                installationID: UIDevice.current.identifierForVendor?.uuidString
                    ?? UUID().uuidString,
                token: token,
                environment: .current,
                authorization: APNsAuthorizationState(
                    settings.authorizationStatus
                ),
                receivedAt: .now,
                appVersion: Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "unknown",
                locale: Locale.current.identifier
            )

            NotificationCenter.default.post(
                name: .northBridgeAPNsTokenDidChange,
                object: snapshot
            )
            SecureLogger.network.info(
                "Current APNs device token forwarded to the registration boundary."
            )
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        SecureLogger.network.error(
            "APNs registration failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
        )
    }
}
