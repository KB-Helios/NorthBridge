import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    var selectedTab: AppTab = .overview
    var presentedSheet: AppPresentation?
    var selectedCompanyID: UUID? {
        didSet {
            UserDefaults.standard.set(selectedCompanyID?.uuidString, forKey: "selection.companyID")
            if oldValue != selectedCompanyID {
                routers.values.forEach { $0.reset() }
                settingsRouter.reset()
            }
        }
    }
    var pendingDocumentAction: DocumentVaultAction?

    let presentationPreferences: NorthBridgePresentationPreferences
    let settingsRouter: RouterPath
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
        presentationPreferences = NorthBridgePresentationPreferences()
        settingsRouter = RouterPath()
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
            navigate(to: .deadlines, in: .overview)
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
            navigate(to: .assistant, in: .overview)
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
            navigate(to: .deadlines, in: .overview)
        case "create-deadline":
            selectedTab = .overview
            router(for: .overview).navigate(to: .addDeadline)
        case "deadline":
            if let idString = url.pathComponents.dropFirst().first,
               let id = UUID(uuidString: idString) {
                navigate(to: .deadline(id), in: .overview)
            } else {
                navigate(to: .deadlines, in: .overview)
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
            presentSettings(route: .integrations)
        case "assistant":
            navigate(to: .assistant, in: .overview)
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
        if route == .search {
            selectedTab = .search
            router(for: .search).reset()
            return
        }
        selectedTab = tab
        let destinationRouter = router(for: tab)
        destinationRouter.reset()
        destinationRouter.navigate(to: route)
    }

    func presentSettings(route: AppRoute? = nil) {
        settingsRouter.reset()
        if let route {
            settingsRouter.navigate(to: route)
        }
        presentedSheet = .settings
    }

    func dismissSettings() {
        presentedSheet = nil
        settingsRouter.reset()
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
