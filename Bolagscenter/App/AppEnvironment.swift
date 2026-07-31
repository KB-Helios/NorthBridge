import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    var selectedTab: AppTab = .overview
    var selectedCompanyID: UUID? {
        didSet {
            UserDefaults.standard.set(selectedCompanyID?.uuidString, forKey: "selection.companyID")
            if oldValue != selectedCompanyID {
                routers.values.forEach { $0.reset() }
            }
        }
    }
    var pendingDocumentAction: DocumentVaultAction?

    let lockController: AppLockController
    let permissionPolicy: PermissionPolicy
    let keychain: KeychainStore
    let sessionController: SessionController
    let notificationScheduler: NotificationScheduler
    let notificationRouter: NotificationResponseRouter
    let subscriptionManager: SubscriptionManager
    let connectivityMonitor: ConnectivityMonitor
    let offlineMutationQueue: OfflineMutationQueue?
    let backendClient: HTTPClient?
    let companyRegistryService: any CompanyRegistryService
    let remoteNotificationRegistration: RemoteNotificationRegistrationCoordinator

    private var routers: [AppTab: RouterPath] = [:]

    init() {
        let keychain = KeychainStore()
        self.keychain = keychain
        lockController = AppLockController()
        permissionPolicy = PermissionPolicy()
        sessionController = SessionController(keychain: keychain)
        subscriptionManager = SubscriptionManager(keychain: keychain)
        connectivityMonitor = ConnectivityMonitor()
        let mutationQueue: OfflineMutationQueue?
        do {
            mutationQueue = OfflineMutationQueue(
                fileURL: try OfflineMutationQueue.applicationQueueURL()
            )
        } catch {
            mutationQueue = nil
            SecureLogger.persistence.error(
                "Offline queue could not be initialized: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
        offlineMutationQueue = mutationQueue
        let remoteRegistrationService: any RemoteNotificationRegistrationService
        if let backend = AppConfiguration.backend() {
            let tokenProvider = KeychainAccessTokenProvider(
                keychain: keychain,
                baseURL: backend.baseURL
            )
            let client = HTTPClient(
                baseURL: backend.baseURL,
                tokenProvider: tokenProvider,
                mutationQueue: mutationQueue
            )
            backendClient = client
            companyRegistryService = BackendCompanyRegistryService(
                client: client
            )
            remoteRegistrationService = BackendRemoteNotificationRegistrationService(
                client: client
            )
        } else {
            backendClient = nil
            companyRegistryService = UnavailableCompanyRegistryService(
                providerName: "Bolagsregister"
            )
            remoteRegistrationService = UnavailableRemoteNotificationRegistrationService()
        }
        remoteNotificationRegistration = RemoteNotificationRegistrationCoordinator(
            service: remoteRegistrationService
        )
        notificationScheduler = NotificationScheduler()
        let notificationRouter = NotificationResponseRouter()
        self.notificationRouter = notificationRouter
        notificationRouter.onOpenURL = { [weak self] url in
            self?.handle(url: url)
        }
        notificationRouter.install()
        if let stored = UserDefaults.standard.string(forKey: "selection.companyID") {
            selectedCompanyID = UUID(uuidString: stored)
        }
    }

    func router(for tab: AppTab) -> RouterPath {
        if let existing = routers[tab] {
            return existing
        }
        let router = RouterPath()
        routers[tab] = router
        return router
    }

    func consumePendingIntent() {
        guard let destination = IntentHandoffStore.consume() else { return }
        switch destination {
        case .deadlines:
            navigate(to: .deadlines, in: .more)
        case .createDeadline:
            navigate(to: .addDeadline, in: .overview)
        case .openCompany:
            selectedTab = .company
            router(for: .company).reset()
        case .createBoardMeeting:
            navigate(to: .addBoardMeeting, in: .company)
        case .scanDocument:
            requestDocumentScan()
        case .addAction:
            navigate(to: .actionTracker, in: .company)
        case .assistant:
            navigate(to: .assistant, in: .more)
        }
    }

    func handle(url: URL) {
        guard
            let scheme = url.scheme,
            ["northbridge", "bolagscenter"].contains(scheme)
        else {
            return
        }
        switch url.host {
        case "deadlines":
            selectedTab = .more
            router(for: .more).navigate(to: .deadlines)
        case "create-deadline":
            selectedTab = .overview
            router(for: .overview).navigate(to: .addDeadline)
        case "deadline":
            if let idString = url.pathComponents.dropFirst().first,
               let id = UUID(uuidString: idString) {
                navigate(to: .deadline(id), in: .overview)
            } else {
                navigate(to: .deadlines, in: .more)
            }
        case "action":
            navigate(to: .actionTracker, in: .company)
        case "document":
            if let idString = url.pathComponents.dropFirst().first,
               let id = UUID(uuidString: idString) {
                navigate(to: .document(id), in: .documents)
            }
        case "resolution":
            if let idString = url.pathComponents.dropFirst().first,
               let id = UUID(uuidString: idString) {
                navigate(to: .resolution(id), in: .company)
            }
        case "integrations":
            navigate(to: .integrations, in: .more)
        case "assistant":
            navigate(to: .assistant, in: .more)
        case "company":
            selectedTab = .company
            router(for: .company).reset()
        case "finance":
            selectedTab = .finance
            router(for: .finance).reset()
        default:
            break
        }
    }

    func navigate(to route: AppRoute, in tab: AppTab) {
        selectedTab = tab
        let destinationRouter = router(for: tab)
        destinationRouter.reset()
        destinationRouter.navigate(to: route)
    }

    func requestDocumentImport() {
        pendingDocumentAction = .importFile
        selectedTab = .documents
    }

    func requestDocumentScan() {
        pendingDocumentAction = .scan
        selectedTab = .documents
    }

    func consumePendingDocumentAction() -> DocumentVaultAction? {
        defer { pendingDocumentAction = nil }
        return pendingDocumentAction
    }
}

enum DocumentVaultAction: Equatable, Sendable {
    case importFile
    case scan
}
