import SwiftData
import SwiftUI

@MainActor
struct AppShellView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CompanyRecord.registeredName) private var companies: [CompanyRecord]
    @Query private var memberships: [CompanyMembershipRecord]
    @Query private var deadlines: [DeadlineRecord]
    @Query private var actions: [ActionItemRecord]
    @Query private var documents: [DocumentRecord]
    @Query private var integrations: [IntegrationRecord]
    @Query private var metrics: [FinancialMetricRecord]
    @Namespace private var documentTransitionNamespace

    var body: some View {
        @Bindable var environment = environment

        TabView(selection: $environment.selectedTab) {
            Tab("Översikt", systemImage: "rectangle.grid.2x2", value: .overview) {
                tabRoot(.overview)
            }
            .accessibilityIdentifier("tab.overview")

            Tab("Ekonomi", systemImage: "chart.xyaxis.line", value: .finance) {
                tabRoot(.finance)
            }
            .accessibilityIdentifier("tab.finance")

            Tab("Bolag", systemImage: "building.2", value: .company) {
                tabRoot(.company)
            }
            .accessibilityIdentifier("tab.company")

            Tab("Dokument", systemImage: "doc.text", value: .documents) {
                tabRoot(.documents)
            }
            .accessibilityIdentifier("tab.documents")

            Tab(value: .search, role: .search) {
                tabRoot(.search)
            } label: {
                Label("Sök", systemImage: "magnifyingglass")
            }
            .accessibilityIdentifier("tab.search")
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.northBridgeBlue)
        .sensoryFeedback(
            .selection,
            trigger: environment.selectedTab
        ) { oldValue, newValue in
            environment.presentationPreferences.hapticsEnabled
                && oldValue != newValue
        }
        .animation(
            environment.presentationPreferences.enhancedMotion && !reduceMotion
                ? .snappy(duration: 0.24)
                : nil,
            value: environment.selectedTab
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            if environment.connectivityMonitor.state == .offline {
                offlineBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $environment.presentedSheet) { presentation in
            switch presentation {
            case .settings:
                SettingsNavigationView(router: environment.settingsRouter)
                    .presentationCornerRadius(NorthBridgeRadius.sheet)
            }
        }
        .task(id: widgetRevision) {
            if let companyID = environment.selectedCompanyID {
                WidgetSnapshotCoordinator.refresh(
                    companyID: companyID,
                    modelContext: modelContext
                )
            }
        }
    }

    private func tabRoot(_ tab: AppTab) -> some View {
        TabRootView(
            tab: tab,
            router: environment.router(for: tab),
            companies: companyContexts,
            selectedCompanyID: environment.selectedCompanyID,
            canAddCompany: canAddAnotherCompany,
            documentTransitionNamespace: documentTransitionNamespace,
            onSelectCompany: { companyID in
                environment.selectedCompanyID = companyID
            },
            onAddCompany: openCompanyCreation,
            onOpenSettings: {
                environment.presentSettings()
            }
        )
    }

    private var offlineBanner: some View {
        Label(
            "Offline – visar sparade uppgifter",
            systemImage: "wifi.slash"
        )
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color.northBridgeTextPrimary)
        .padding(.horizontal, NorthBridgeSpacing.md)
        .frame(minHeight: NorthBridgeMetrics.minimumTarget)
        .background(
            Color.northBridgeRaisedSurface,
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(Color.northBridgeWarning.opacity(0.5), lineWidth: 1)
        }
        .shadow(
            color: NorthBridgeElevation.card.color,
            radius: NorthBridgeElevation.card.radius,
            x: NorthBridgeElevation.card.x,
            y: NorthBridgeElevation.card.y
        )
        .padding(.horizontal, NorthBridgeSpacing.lg)
        .padding(.vertical, NorthBridgeSpacing.xs)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("connectivity.offline")
        .accessibilityHint(
            "Ändringar sparas lokalt och skickas när anslutningen återkommer."
        )
    }

    private var canAddAnotherCompany: Bool {
        accessibleCompanies.isEmpty
            || SubscriptionAccessPolicy().allows(
                .multipleCompanies,
                entitlement: environment.subscriptionManager.entitlement
            )
    }

    private func openCompanyCreation() {
        if canAddAnotherCompany {
            environment.router(for: environment.selectedTab)
                .navigate(to: .addCompany)
        } else {
            environment.presentSettings(route: .subscription)
        }
    }

    private var companyContexts: [NorthBridgeCompanyContext] {
        accessibleCompanies.map {
            NorthBridgeCompanyContext(id: $0.id, name: $0.registeredName)
        }
    }

    private var accessibleCompanies: [CompanyRecord] {
        guard let accountID = environment.sessionController.activeSession?.accountID else {
            return []
        }
        let companyIDs = Set(
            memberships
                .filter { $0.accountID == accountID && $0.isActive }
                .map(\.companyID)
        )
        return companies.filter { companyIDs.contains($0.id) }
    }

    private var widgetRevision: String {
        let companyID = environment.selectedCompanyID
        var values = [companyID?.uuidString ?? "none"]
        let deadlineValues = deadlines
            .filter { $0.companyID == companyID }
            .map { "\($0.id):\($0.statusRawValue):\($0.dueAt.timeIntervalSince1970)" }
        values.append(contentsOf: deadlineValues)
        let actionValues = actions
            .filter { $0.companyID == companyID }
            .map { "\($0.id):\($0.statusRawValue):\($0.dueAt.timeIntervalSince1970)" }
        values.append(contentsOf: actionValues)
        let documentValues = documents
            .filter { $0.companyID == companyID }
            .map { "\($0.id):\($0.lastModifiedAt.timeIntervalSince1970)" }
        values.append(contentsOf: documentValues)
        let integrationValues = integrations
            .filter { $0.companyID == companyID }
            .map { "\($0.id):\($0.stateRawValue)" }
        values.append(contentsOf: integrationValues)
        let metricValues = metrics
            .filter { $0.companyID == companyID }
            .map { "\($0.id):\($0.amount):\($0.sourceUpdatedAt.timeIntervalSince1970)" }
        values.append(contentsOf: metricValues)
        return values.sorted().joined(separator: "|")
    }
}

@MainActor
private struct TabRootView: View {
    let tab: AppTab
    @Bindable var router: RouterPath
    let companies: [NorthBridgeCompanyContext]
    let selectedCompanyID: UUID?
    let canAddCompany: Bool
    let documentTransitionNamespace: Namespace.ID
    let onSelectCompany: (UUID) -> Void
    let onAddCompany: () -> Void
    let onOpenSettings: () -> Void

    init(
        tab: AppTab,
        router: RouterPath,
        companies: [NorthBridgeCompanyContext],
        selectedCompanyID: UUID?,
        canAddCompany: Bool,
        documentTransitionNamespace: Namespace.ID,
        onSelectCompany: @escaping (UUID) -> Void,
        onAddCompany: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.tab = tab
        _router = Bindable(router)
        self.companies = companies
        self.selectedCompanyID = selectedCompanyID
        self.canAddCompany = canAddCompany
        self.documentTransitionNamespace = documentTransitionNamespace
        self.onSelectCompany = onSelectCompany
        self.onAddCompany = onAddCompany
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            tabContent
                .navigationDestination(for: AppRoute.self) { route in
                    AppRouteDestinationView(
                        route: route,
                        documentTransitionNamespace: documentTransitionNamespace
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        CompanyContextMenu(
                            companies: companies,
                            selectedCompanyID: selectedCompanyID,
                            canAddCompany: canAddCompany,
                            prefersCompactLabel: tab == .search,
                            onSelect: onSelectCompany,
                            onAddCompany: onAddCompany
                        )
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        NorthBridgeGlassIconButton(
                            systemImage: "person.crop.circle",
                            accessibilityLabel: "Öppna inställningar",
                            accessibilityIdentifier: "settings.open",
                            action: onOpenSettings
                        )
                    }
                }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .overview:
            DashboardView()
        case .finance:
            FinanceOverviewView()
        case .company:
            CompanyWorkspaceView()
        case .documents:
            DocumentVaultView(
                transitionNamespace: documentTransitionNamespace
            )
        case .search:
            GlobalSearchView()
        }
    }
}

@MainActor
private struct SettingsNavigationView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var router: RouterPath

    init(router: RouterPath) {
        _router = Bindable(router)
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            SettingsHubView()
                .navigationDestination(for: AppRoute.self) { route in
                    AppRouteDestinationView(
                        route: route,
                        documentTransitionNamespace: nil
                    )
                }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Klar") {
                    environment.dismissSettings()
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier("settings.close")
            }
        }
        .tint(.northBridgeBlue)
    }
}

@MainActor
private struct AppRouteDestinationView: View {
    let route: AppRoute
    let documentTransitionNamespace: Namespace.ID?

    @ViewBuilder
    var body: some View {
        switch route {
        case .deadlines:
            DeadlineCenterView()
        case .deadline(let id):
            DeadlineDetailView(deadlineID: id)
        case .addDeadline:
            DeadlineEditorView()
        case .financialMetric(let id):
            FinancialMetricDetailView(metricID: id)
        case .financialPlanning:
            FinancialPlanningView()
        case .addCompany:
            CompanyCreationView()
        case .companyDetails:
            CompanyProfileDetailView()
        case .boardAndSignatories:
            BoardAndSignatoriesView()
        case .boardWorkspace:
            BoardWorkspaceView()
        case .boardMeeting(let id):
            BoardMeetingDetailView(meetingID: id)
        case .addBoardMeeting:
            BoardMeetingEditorView()
        case .resolution(let id):
            ResolutionDetailView(resolutionID: id)
        case .actionTracker:
            ActionTrackerView()
        case .ownership:
            OwnershipOverviewView()
        case .shareholderRegister:
            ShareholderRegisterView()
        case .shareCertificates:
            ShareCertificatesView()
        case .addShareTransaction:
            ShareTransactionEditorView()
        case .document(let id):
            DocumentViewerView(
                documentID: id,
                transitionNamespace: documentTransitionNamespace
            )
        case .search:
            GlobalSearchView()
        case .integrations:
            IntegrationCenterView()
        case .usersAndRoles:
            UserRoleManagementView()
        case .notificationSettings:
            NotificationSettingsView()
        case .subscription:
            SubscriptionSettingsView()
        case .accountSettings:
            AccountLifecycleView()
        case .assistant:
            BolagsassistentView()
        case .security:
            SecuritySettingsView()
        case .activity:
            ActivityHistoryView()
        }
    }
}
