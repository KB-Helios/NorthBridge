import SwiftData
import SwiftUI

@MainActor
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \UserAccountRecord.createdAt) private var accounts: [UserAccountRecord]
    @Query(sort: \CompanyRecord.createdAt) private var companies: [CompanyRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    var body: some View {
        Group {
            if accounts.isEmpty || companies.isEmpty {
                OnboardingFlowView()
            } else {
                switch environment.sessionController.state {
                case .checking:
                    ProgressView("Kontrollerar säker session")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .signedOut, .expired:
                    SignInView(accounts: accounts)
                case .active:
                    if environment.lockController.isEnabled
                        && environment.lockController.isLocked {
                        SecureLockView()
                    } else {
                        AppShellView()
                    }
                }
            }
        }
        .task {
            #if DEBUG
            if UITestLaunchConfiguration.isSeeded {
                do {
                    try UITestFixtureSeeder.seedIfNeeded(in: modelContext)
                    if UITestLaunchConfiguration.isExpired {
                        environment.sessionController
                            .installUITestExpiredState()
                    } else {
                        try await environment.sessionController
                            .createLocalSession(
                                accountID: UITestLaunchConfiguration.accountID
                            )
                        environment.selectedCompanyID =
                            UITestLaunchConfiguration.primaryCompanyID
                        environment.lockController.disable()
                        environment.subscriptionManager
                            .installUITestEntitlement(.team)
                        openRequestedUITestRoute()
                    }
                } catch {
                    SecureLogger.persistence.error(
                        "UI test fixture failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
                    )
                }
            } else {
                if !UITestLaunchConfiguration.usesInMemoryStore {
                    await environment.subscriptionManager.prepare()
                }
                await environment.sessionController.restore()
            }
            #else
            await environment.subscriptionManager.prepare()
            await environment.sessionController.restore()
            #endif
        }
        .task(id: selectionRevision) {
            reconcileCompanySelection()
            environment.consumePendingIntent()
        }
        .task(id: environment.connectivityMonitor.state) {
            guard environment.connectivityMonitor.state == .online,
                  let client = environment.backendClient else {
                return
            }
            do {
                try await client.replayQueuedMutations()
            } catch {
                SecureLogger.network.error(
                    "Offline mutation replay failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
                )
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                environment.lockController.lock()
                BackgroundRefreshCoordinator.schedule()
            } else if newPhase == .active {
                Task {
                    await environment.sessionController.validateExpiration()
                }
                environment.consumePendingIntent()
            }
        }
        .onChange(of: environment.sessionController.state) { _, newState in
            switch newState {
            case .active, .checking:
                break
            case .signedOut, .expired:
                WidgetSnapshotCoordinator.clear()
            }
        }
        .onOpenURL { url in
            environment.handle(url: url)
        }
    }

    #if DEBUG
    private func openRequestedUITestRoute() {
        switch UITestLaunchConfiguration.requestedRoute {
        case "board":
            environment.navigate(to: .boardWorkspace, in: .company)
        case "ownership":
            environment.navigate(to: .ownership, in: .company)
        case "certificates":
            environment.navigate(to: .shareCertificates, in: .company)
        case "documents":
            environment.selectedTab = .documents
        case "integrations":
            environment.presentSettings(route: .integrations)
        case "account":
            environment.presentSettings(route: .accountSettings)
        case "deadlines":
            environment.navigate(to: .deadlines, in: .overview)
        case "search":
            environment.selectedTab = .search
            environment.router(for: .search).reset()
        case "settings":
            environment.presentSettings()
        case "activity":
            environment.navigate(to: .activity, in: .company)
        default:
            break
        }
    }
    #endif

    private func reconcileCompanySelection() {
        guard let accountID = environment.sessionController.activeSession?.accountID else {
            environment.selectedCompanyID = nil
            return
        }

        do {
            // Fetch both sides of the saved transaction together. Independent
            // @Query updates can arrive in separate render passes and must not
            // invalidate a newly selected company between those passes.
            let currentCompanies = try modelContext.fetch(
                FetchDescriptor<CompanyRecord>()
            )
            let currentMemberships = try modelContext.fetch(
                FetchDescriptor<CompanyMembershipRecord>()
            )
            let companyIDs = Set(
                currentMemberships
                    .filter { $0.accountID == accountID && $0.isActive }
                    .map(\.companyID)
            )
            let accessibleCompanies = currentCompanies
                .filter { companyIDs.contains($0.id) }
                .sorted { $0.createdAt < $1.createdAt }

            guard !accessibleCompanies.isEmpty else {
                environment.selectedCompanyID = nil
                return
            }
            if let selected = environment.selectedCompanyID,
               accessibleCompanies.contains(where: { $0.id == selected }) {
                return
            }
            environment.selectedCompanyID = accessibleCompanies.first?.id
        } catch {
            SecureLogger.persistence.error(
                "Company selection reconciliation failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
        }
    }

    private var selectionRevision: String {
        let account = environment.sessionController.activeSession?
            .accountID
            .uuidString ?? "signed-out"
        let access = memberships
            .map {
                "\($0.id.uuidString):\($0.accountID.uuidString):\($0.companyID.uuidString):\($0.isActive)"
            }
            .sorted()
            .joined(separator: "|")
        let companyIDs = companies
            .map(\.id.uuidString)
            .sorted()
            .joined(separator: "|")
        return "\(account)#\(access)#\(companyIDs)"
    }
}

@MainActor
private struct SignInView: View {
    @Environment(AppEnvironment.self) private var environment
    let accounts: [UserAccountRecord]

    @State private var selectedAccountID: UUID?
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            NorthBridgeBrandLockup(maxWidth: 320)

            VStack(spacing: 10) {
                Text("Logga in i NorthBridge")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Den lokala arbetsytan låses upp med enhetens kod, Face ID eller Touch ID. BankID och serverinloggning används först när en godkänd leverantör har konfigurerats.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if accounts.count > 1 {
                Picker("Konto", selection: $selectedAccountID) {
                    ForEach(accounts) { account in
                        Text(account.email).tag(UUID?.some(account.id))
                    }
                }
                .pickerStyle(.menu)
            } else if let account = accounts.first {
                LabeledContent("Konto", value: account.email)
                    .frame(maxWidth: 420)
            }

            if let errorMessage = environment.sessionController.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            if environment.sessionController.state == .expired {
                Label(
                    "Sessionen har gått ut. Logga in igen.",
                    systemImage: "clock.badge.exclamationmark"
                )
                .font(.callout)
                .foregroundStyle(.orange)
                .accessibilityIdentifier("authentication.sessionExpired")
            }

            Button {
                Task { await signIn() }
            } label: {
                if isSigningIn {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Logga in säkert", systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 420)
            .disabled(isSigningIn || resolvedAccountID == nil)
            .accessibilityIdentifier("authentication.signIn")

            Spacer()
        }
        .padding(28)
        .background(Color.appBackground)
        .onAppear {
            selectedAccountID = accounts.first?.id
        }
    }

    private var resolvedAccountID: UUID? {
        selectedAccountID ?? accounts.first?.id
    }

    private func signIn() async {
        guard let accountID = resolvedAccountID else { return }
        isSigningIn = true
        defer { isSigningIn = false }
        await environment.sessionController.signInLocally(accountID: accountID)
    }
}

@MainActor
private struct SecureLockView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("NorthBridge är låst")
                    .font(.title2.bold())
                Text("Lås upp med Face ID eller enhetens kod.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let message = environment.lockController.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await environment.lockController.unlock() }
            } label: {
                if environment.lockController.isUnlocking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Lås upp", systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(environment.lockController.isUnlocking)
        }
        .padding(32)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .task {
            await environment.lockController.unlock()
        }
    }
}
