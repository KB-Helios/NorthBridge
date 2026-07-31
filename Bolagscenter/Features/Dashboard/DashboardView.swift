import SwiftData
import SwiftUI

@MainActor
struct DashboardView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \CompanyRecord.registeredName) private var companies: [CompanyRecord]
    @Query(sort: \DeadlineRecord.dueAt) private var deadlines: [DeadlineRecord]
    @Query(sort: \DocumentRecord.importedAt, order: .reverse)
    private var documents: [DocumentRecord]
    @Query(sort: \CompanyMembershipRecord.createdAt)
    private var memberships: [CompanyMembershipRecord]
    @Query(sort: \ActionItemRecord.dueAt) private var actions: [ActionItemRecord]
    @Query(sort: \FinancialMetricRecord.sourceUpdatedAt, order: .reverse)
    private var metrics: [FinancialMetricRecord]
    @Query(sort: \AuditEventRecord.occurredAt, order: .reverse)
    private var auditEvents: [AuditEventRecord]
    @Query private var integrations: [IntegrationRecord]

    var body: some View {
        ScrollView {
            LiquidGlassEffectGroup(spacing: AppSpacing.section) {
                LazyVStack(alignment: .leading, spacing: AppSpacing.section) {
                    if let company {
                        companyHeader(company)
                        pulseSection(company)
                        nextActionSection
                        upcomingDeadlinesSection
                        administrativeAlertsSection(company)
                        boardActionsSection
                        recentDocumentsSection
                        financialSummarySection
                        activitySection
                        integrationHealthSection
                        dataFreshnessSection(company)
                    } else {
                        EmptyStateView(
                            systemImage: "building.2",
                            title: "Inget bolag valt",
                            message: "Välj eller lägg till ett bolag för att se översikten."
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Översikt")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.search) {
                    Label("Sök", systemImage: "magnifyingglass")
                }
            }
        }
    }

    private func companyHeader(_ company: CompanyRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(company.registeredName)
                        .font(.title2.bold())
                    Text(formattedOrganisationNumber(company.organisationNumber))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(
                    text: company.status.localizedName,
                    kind: company.status == .active ? .positive : .warning
                )
            }

            if let membership {
                Label(
                    membership.role.localizedName,
                    systemImage: "person.text.rectangle"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text(lastSynchronizationText(company))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .bolagscenterGlassSurface(
            cornerRadius: 18,
            tint: Color.bolagscenterBlue.opacity(0.08)
        )
        .accessibilityElement(children: .combine)
    }

    private func pulseSection(_ company: CompanyRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Bolagspuls")

            VStack(spacing: 0) {
                pulseRow(
                    title: "Deadlines",
                    detail: deadlinePulseText,
                    icon: "calendar.badge.clock",
                    kind: openDeadlines.contains(where: { $0.dueAt < .now })
                        ? .critical
                        : .neutral
                )
                Divider()
                pulseRow(
                    title: "Dokument",
                    detail: companyDocuments.isEmpty
                        ? String(localized: "Inga dokument har importerats")
                        : String(localized: "\(companyDocuments.count) dokument tillgängliga"),
                    icon: "doc.text",
                    kind: companyDocuments.isEmpty ? .warning : .positive
                )
                Divider()
                pulseRow(
                    title: "Registreringsuppgifter",
                    detail: company.status == .unknown
                        ? String(localized: "Väntar på verifiering från officiell källa")
                        : String(localized: "Status hämtad från \(company.sourceName)"),
                    icon: "checkmark.seal",
                    kind: company.status == .unknown ? .warning : .positive
                )
                Divider()
                pulseRow(
                    title: "Ekonomiska signaler",
                    detail: financialPulseText,
                    icon: "chart.line.uptrend.xyaxis",
                    kind: hasFinancialWarning ? .warning : .neutral
                )
                Divider()
                pulseRow(
                    title: "Styrelseåtgärder",
                    detail: openActions.isEmpty
                        ? String(localized: "Inga öppna åtgärder")
                        : String(localized: "\(openActions.count) väntar på uppföljning"),
                    icon: "checklist",
                    kind: openActions.contains(where: { $0.dueAt < .now })
                        ? .critical
                        : (openActions.isEmpty ? .positive : .warning)
                )
                Divider()
                pulseRow(
                    title: "Integrationer",
                    detail: integrationPulseText,
                    icon: "arrow.triangle.2.circlepath",
                    kind: unhealthyIntegrations.isEmpty ? .neutral : .warning
                )
            }
            .bolagscenterGlassSurface(cornerRadius: 16)

            Text("Bolagspuls förklarar registrerade riskfaktorer och är inte en juridisk kontroll eller certifiering.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var nextActionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Nästa åtgärd")

            if let nextDashboardAction {
                NavigationLink(value: nextDashboardAction.route) {
                    HStack(spacing: 12) {
                        Image(systemName: nextDashboardAction.systemImage)
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(nextDashboardAction.title)
                                .font(.body.weight(.semibold))
                            Text(nextDashboardAction.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(.background, in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } else {
                EmptyStateView(
                    systemImage: "checkmark.circle",
                    title: "Inga öppna åtgärder",
                    message: "Lägg till en deadline eller styrelseåtgärd när något behöver följas upp."
                )
                .frame(minHeight: 180)
            }
        }
    }

    private var upcomingDeadlinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeading(title: "Kommande deadlines")
                Spacer()
                NavigationLink("Visa alla", value: AppRoute.deadlines)
                    .font(.subheadline.weight(.semibold))
            }

            if openDeadlines.isEmpty {
                Text("Inga öppna deadlines.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(openDeadlines.prefix(3)) { deadline in
                    NavigationLink(value: AppRoute.deadline(deadline.id)) {
                        DeadlineRow(deadline: deadline)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func administrativeAlertsSection(
        _ company: CompanyRecord
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Administrativa signaler")
            if administrativeAlerts(company).isEmpty {
                Label("Inga registrerade administrativa varningar", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                ForEach(administrativeAlerts(company)) { alert in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.title)
                                .font(.subheadline.weight(.semibold))
                            Text(alert.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: alert.systemImage)
                            .foregroundStyle(.orange)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var boardActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeading(title: "Styrelseåtgärder")
                Spacer()
                NavigationLink("Öppna", value: AppRoute.actionTracker)
                    .font(.subheadline.weight(.semibold))
            }
            if openActions.isEmpty {
                Text("Inga öppna styrelseåtgärder.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(openActions.prefix(3)) { action in
                    NavigationLink(value: AppRoute.actionTracker) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(action.title)
                                    .foregroundStyle(.primary)
                                Text("\(action.assignedTo) · \(action.dueAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(
                                        action.dueAt < .now
                                            ? Color.red
                                            : Color.secondary
                                    )
                            }
                            Spacer()
                            StatusBadge(
                                text: action.status.localizedName,
                                kind: action.status == .blocked ? .critical : .warning
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Senaste dokument")
            if companyDocuments.isEmpty {
                Text("Inga dokument har importerats.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(companyDocuments.prefix(3)) { document in
                    NavigationLink(value: AppRoute.document(document.id)) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text(document.title)
                                    .foregroundStyle(.primary)
                                Text(document.category.localizedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(document.importedAt, format: .dateTime.day().month())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var financialSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeading(title: "Finansiell sammanfattning")
                Spacer()
                if canViewFinance {
                    Button("Öppna ekonomi") {
                        environment.selectedTab = .finance
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            if !canViewFinance {
                Label(
                    "Din roll saknar behörighet att visa finansiella värden.",
                    systemImage: "lock.fill"
                )
                .foregroundStyle(.secondary)
            } else if summaryMetrics.isEmpty {
                Text("Inga finansiella värden har registrerats.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(summaryMetrics) { metric in
                    NavigationLink(value: AppRoute.financialMetric(metric.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(metric.kind.localizedName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(
                                    metric.amount.formatted(
                                        .currency(code: metric.currencyCode)
                                    )
                                )
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(metric.valueState.localizedName)
                                Text(metric.sourceName)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .bolagscenterGlassSurface(
                            cornerRadius: 14,
                            tint: Color.bolagscenterBlue.opacity(0.04)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeading(title: "Senaste aktivitet")
                Spacer()
                NavigationLink("Visa historik", value: AppRoute.activity)
                    .font(.subheadline.weight(.semibold))
            }
            if companyAuditEvents.isEmpty {
                Text("Ingen aktivitet har registrerats.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(companyAuditEvents.prefix(4)) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.summary)
                                .font(.subheadline)
                            Text(event.occurredAt, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var integrationHealthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeading(title: "Integrationshälsa")
                Spacer()
                NavigationLink("Hantera", value: AppRoute.integrations)
                    .font(.subheadline.weight(.semibold))
            }
            if companyIntegrations.isEmpty {
                Text("Inga integrationer har konfigurerats.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(companyIntegrations) { integration in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(integration.displayName)
                            Text(integrationLastActivity(integration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(
                            text: integration.state.localizedName,
                            kind: integrationBadgeKind(integration.state)
                        )
                    }
                }
            }
        }
    }

    private func dataFreshnessSection(_ company: CompanyRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "Datakvalitet")
            SourceFooter(
                source: company.sourceName,
                updatedAt: company.sourceUpdatedAt,
                stale: company.isStale
            )
            if company.status == .unknown {
                Label(
                    "Manuella uppgifter är inte verifierade mot en myndighetskälla.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func pulseRow(
        title: String,
        detail: String,
        icon: String,
        kind: StatusBadge.Kind
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(kind.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    private var company: CompanyRecord? {
        companies.first { $0.id == environment.selectedCompanyID }
    }

    private var membership: CompanyMembershipRecord? {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID else {
            return nil
        }
        return memberships.first {
            $0.companyID == companyID
                && $0.accountID == accountID
                && $0.isActive
        }
    }

    private var canViewFinance: Bool {
        membership.map {
            environment.permissionPolicy.allows(.viewFinance, for: $0.role)
        } ?? false
    }

    private var openDeadlines: [DeadlineRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return deadlines.filter {
            $0.companyID == companyID
                && $0.status != .completed
                && $0.status != .dismissed
        }
    }

    private var openActions: [ActionItemRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return actions.filter {
            $0.companyID == companyID && $0.status != .completed
        }
    }

    private var companyDocuments: [DocumentRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return documents.filter { $0.companyID == companyID }
    }

    private var companyMetrics: [FinancialMetricRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return metrics.filter { $0.companyID == companyID }
    }

    private var companyAuditEvents: [AuditEventRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return auditEvents.filter { $0.companyID == companyID }
    }

    private var companyIntegrations: [IntegrationRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return integrations.filter { $0.companyID == companyID }
    }

    private var unhealthyIntegrations: [IntegrationRecord] {
        companyIntegrations.filter {
            [
                IntegrationState.unauthorized,
                .stale,
                .rateLimited,
                .unavailable,
                .failed,
            ].contains($0.state)
        }
    }

    private var summaryMetrics: [FinancialMetricRecord] {
        let preferredKinds: [FinancialMetricKind] = [
            .availableLiquidity,
            .revenue,
            .operatingResult,
        ]
        return preferredKinds.compactMap { kind in
            companyMetrics
                .filter { $0.kind == kind }
                .max { $0.periodEnd < $1.periodEnd }
        }
    }

    private var latestOperatingResult: FinancialMetricRecord? {
        companyMetrics
            .filter { $0.kind == .operatingResult }
            .max { $0.periodEnd < $1.periodEnd }
    }

    private var hasFinancialWarning: Bool {
        latestOperatingResult.map { $0.amount < 0 } ?? false
    }

    private var deadlinePulseText: String {
        let overdueCount = openDeadlines.filter { $0.dueAt < .now }.count
        if overdueCount > 0 {
            return String(localized: "\(overdueCount) försenade")
        }
        return openDeadlines.isEmpty
            ? String(localized: "Inga öppna deadlines")
            : String(localized: "\(openDeadlines.count) öppna")
    }

    private var financialPulseText: String {
        guard canViewFinance else {
            return String(localized: "Dold för aktuell roll")
        }
        guard let latestOperatingResult else {
            return String(localized: "Underlag saknas")
        }
        if latestOperatingResult.amount < 0 {
            return String(localized: "Senaste registrerade rörelseresultat är negativt")
        }
        return String(localized: "Ingen varningssignal i senaste rörelseresultatet")
    }

    private var integrationPulseText: String {
        if companyIntegrations.isEmpty {
            return String(localized: "Inga integrationer konfigurerade")
        }
        if !unhealthyIntegrations.isEmpty {
            return String(localized: "\(unhealthyIntegrations.count) kräver uppmärksamhet")
        }
        let connectedCount = companyIntegrations.filter { $0.state == .connected }.count
        return connectedCount > 0
            ? String(localized: "\(connectedCount) anslutna")
            : String(localized: "Ingen integration är ansluten")
    }

    private var nextDashboardAction: DashboardActionSummary? {
        let deadlineSummary = openDeadlines.first.map {
            DashboardActionSummary(
                title: $0.title,
                subtitle: String(
                    localized: "Deadline \($0.dueAt.formatted(date: .abbreviated, time: .omitted))"
                ),
                dueAt: $0.dueAt,
                systemImage: "calendar.badge.clock",
                route: .deadline($0.id)
            )
        }
        let actionSummary = openActions.first.map {
            DashboardActionSummary(
                title: $0.title,
                subtitle: String(
                    localized: "\($0.assignedTo) · \($0.dueAt.formatted(date: .abbreviated, time: .omitted))"
                ),
                dueAt: $0.dueAt,
                systemImage: "checklist",
                route: .actionTracker
            )
        }
        return [deadlineSummary, actionSummary]
            .compactMap { $0 }
            .min { $0.dueAt < $1.dueAt }
    }

    private func administrativeAlerts(
        _ company: CompanyRecord
    ) -> [DashboardAdministrativeAlert] {
        var values: [DashboardAdministrativeAlert] = []
        let overdueDeadlines = openDeadlines.filter { $0.dueAt < .now }.count
        if overdueDeadlines > 0 {
            values.append(
                DashboardAdministrativeAlert(
                    id: "overdue-deadlines",
                    title: "\(overdueDeadlines) försenade deadlines",
                    detail: "Öppna deadlinecentret och registrera nästa åtgärd.",
                    systemImage: "calendar.badge.exclamationmark"
                )
            )
        }
        if company.status == .unknown {
            values.append(
                DashboardAdministrativeAlert(
                    id: "unverified-company",
                    title: "Bolagsstatus är inte verifierad",
                    detail: "Anslut en behörig officiell datakälla när den finns tillgänglig.",
                    systemImage: "building.2.crop.circle"
                )
            )
        }
        if company.isStale {
            values.append(
                DashboardAdministrativeAlert(
                    id: "stale-company",
                    title: "Bolagsuppgifterna är inaktuella",
                    detail: lastSynchronizationText(company),
                    systemImage: "clock.badge.exclamationmark"
                )
            )
        }
        if !unhealthyIntegrations.isEmpty {
            values.append(
                DashboardAdministrativeAlert(
                    id: "integration-health",
                    title: "\(unhealthyIntegrations.count) integrationer kräver åtgärd",
                    detail: "Kontrollera behörighet, fel och senaste lyckade synkronisering.",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            )
        }
        return values
    }

    private func lastSynchronizationText(_ company: CompanyRecord) -> String {
        guard let date = company.lastSynchronizedAt else {
            return String(localized: "Aldrig synkroniserad")
        }
        return String(
            localized: "Senast synkroniserad \(date.formatted(date: .abbreviated, time: .shortened))"
        )
    }

    private func integrationLastActivity(
        _ integration: IntegrationRecord
    ) -> String {
        if let lastSuccessfulAt = integration.lastSuccessfulAt {
            return String(
                localized: "Senast lyckad \(lastSuccessfulAt.formatted(date: .abbreviated, time: .shortened))"
            )
        }
        if let lastAttemptedAt = integration.lastAttemptedAt {
            return String(
                localized: "Senast försökt \(lastAttemptedAt.formatted(date: .abbreviated, time: .shortened))"
            )
        }
        return String(localized: "Ingen synkronisering utförd")
    }

    private func integrationBadgeKind(
        _ state: IntegrationState
    ) -> StatusBadge.Kind {
        switch state {
        case .connected: .positive
        case .refreshing: .neutral
        case .disconnected, .unauthorized, .stale, .rateLimited: .warning
        case .unavailable, .failed: .critical
        }
    }

    private func formattedOrganisationNumber(_ digits: String) -> String {
        (try? OrganisationNumber(digits).formatted) ?? digits
    }
}

private struct DashboardActionSummary {
    let title: String
    let subtitle: String
    let dueAt: Date
    let systemImage: String
    let route: AppRoute
}

private struct DashboardAdministrativeAlert: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
}
