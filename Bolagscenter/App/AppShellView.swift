import SwiftData
import SwiftUI

@MainActor
struct AppShellView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CompanyRecord.registeredName) private var companies: [CompanyRecord]
    @Query private var memberships: [CompanyMembershipRecord]
    @Query private var deadlines: [DeadlineRecord]
    @Query private var actions: [ActionItemRecord]
    @Query private var documents: [DocumentRecord]
    @Query private var integrations: [IntegrationRecord]
    @Query private var metrics: [FinancialMetricRecord]

    var body: some View {
        @Bindable var environment = environment

        TabView(selection: $environment.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                TabRootView(tab: tab, router: environment.router(for: tab))
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if environment.connectivityMonitor.state == .offline {
                    offlineBanner
                }
                if !accessibleCompanies.isEmpty {
                    companySwitcher
                }
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

    private var companySwitcher: some View {
        HStack {
            Menu {
                ForEach(accessibleCompanies) { company in
                    Button {
                        environment.selectedCompanyID = company.id
                    } label: {
                        if environment.selectedCompanyID == company.id {
                            Label(company.registeredName, systemImage: "checkmark")
                        } else {
                            Text(company.registeredName)
                        }
                    }
                }
                Divider()
                Button {
                    openCompanyCreation()
                } label: {
                    Label(
                        canAddAnotherCompany
                            ? "Lägg till bolag"
                            : "Uppgradera för fler bolag",
                        systemImage: canAddAnotherCompany
                            ? "plus.circle"
                            : "creditcard"
                    )
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "building.2")
                    Text(selectedCompany?.registeredName ?? String(localized: "Välj bolag"))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
            }
            }
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("company.switcher")
            .accessibilityLabel("Aktivt bolag")
            .accessibilityValue(selectedCompany?.registeredName ?? "")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .bolagscenterGlassSurface(
            cornerRadius: 16,
            tint: Color.bolagscenterBlue.opacity(0.06),
            interactive: true
        )
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }

    private var offlineBanner: some View {
        Label(
            "Offline – visar sparade uppgifter",
            systemImage: "wifi.slash"
        )
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.16))
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
            environment.navigate(to: .subscription, in: .more)
        }
    }

    private var selectedCompany: CompanyRecord? {
        accessibleCompanies.first { $0.id == environment.selectedCompanyID }
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

    init(tab: AppTab, router: RouterPath) {
        self.tab = tab
        _router = Bindable(router)
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            tabContent
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
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
            DocumentVaultView()
        case .more:
            MoreView()
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
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
            DocumentViewerView(documentID: id)
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
