import SwiftData
import SwiftUI

@main
struct BolagscenterApp: App {
    @UIApplicationDelegateAdaptor(NorthBridgeAppDelegate.self)
    private var appDelegate

    @State private var environment: AppEnvironment
    private let persistence: PersistenceBootstrap

    init() {
        let environment = AppEnvironment()
        #if DEBUG
        let isUITesting = UITestLaunchConfiguration.usesInMemoryStore
        if isUITesting {
            environment.lockController.disable()
            environment.presentationPreferences.appearance =
                UITestLaunchConfiguration.requestedAppearance ?? .light
            environment.presentationPreferences.enhancedMotion = false
            environment.presentationPreferences.hapticsEnabled = false
            environment.presentationPreferences.dashboardDensity = .comfortable
            environment.presentationPreferences.financialPrivacyBlur = false
            environment.presentationPreferences.documentPresentation = .list
        }
        #else
        let isUITesting = false
        #endif
        _environment = State(initialValue: environment)

        BackgroundRefreshCoordinator.register()
        do {
            let schema = Schema(versionedSchema: BolagscenterSchemaV1.self)
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: isUITesting
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: BolagscenterMigrationPlan.self,
                configurations: [configuration]
            )
            persistence = .available(container)
        } catch {
            persistence = .failed
            SecureLogger.persistence.fault(
                "Persistent store failed to open: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
        BolagscenterShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            switch persistence {
            case .available(let container):
                RootView()
                    .environment(environment)
                    .modelContainer(container)
                    .tint(.bolagscenterBlue)
                    .preferredColorScheme(
                        environment.presentationPreferences.appearance.colorScheme
                    )
            case .failed:
                PersistenceUnavailableView()
                    .tint(.bolagscenterBlue)
            }
        }
    }
}

private enum PersistenceBootstrap {
    case available(ModelContainer)
    case failed
}

private struct PersistenceUnavailableView: View {
    var body: some View {
        ContentUnavailableView {
            Label("NorthBridge kunde inte öppnas", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Den lokala databasen kunde inte läsas. Starta om appen. Kontakta support om problemet kvarstår.")
        }
        .padding()
    }
}
