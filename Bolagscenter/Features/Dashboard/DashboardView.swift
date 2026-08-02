import SwiftData
import SwiftUI

@MainActor
struct DashboardView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        NorthBridgeScreen(contentSpacing: dashboardContentSpacing) {
            if let company {
                companyHero(company)
                executiveMetrics
                nextAction
                commandCenter

                if !companyDocuments.isEmpty || !companyAuditEvents.isEmpty {
                    recentPreviews
                }
            } else {
                NorthBridgeEmptyState(
                    systemImage: "building.2",
                    title: "Inget bolag valt",
                    message: "Välj eller lägg till ett bolag för att se översikten.",
                    actionTitle: "Lägg till bolag",
                    action: {
                        environment.router(for: .overview)
                            .navigate(to: .addCompany)
                    }
                )
                .accessibilityIdentifier("overview.empty")
            }
        }
        .navigationTitle("Översikt")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.assistant) {
                    Label("NorthBridge-assistent", systemImage: "sparkles")
                }
                .accessibilityIdentifier("overview.assistant")
            }
        }
        .animation(
            reduceMotion || !environment.presentationPreferences.enhancedMotion
                ? nil
                : .snappy(duration: 0.28),
            value: nextDashboardAction?.id
        )
    }

    private func companyHero(_ company: CompanyRecord) -> some View {
        NorthBridgeCompanyHero(
            companyName: company.registeredName,
            organisationNumber: formattedOrganisationNumber(
                company.organisationNumber
            ),
            role: membership?.role.localizedName,
            status: companyStatusKind(company.status),
            statusText: company.status.localizedName,
            freshness: freshnessText(company)
        ) {
            Image(
                systemName: company.isStale
                    ? "clock.badge.exclamationmark"
                    : "checkmark.seal.fill"
            )
            .font(.title3)
            .foregroundStyle(
                company.isStale
                    ? Color.northBridgeWarning
                    : Color.northBridgePositive
            )
            .frame(
                width: NorthBridgeMetrics.minimumTarget,
                height: NorthBridgeMetrics.minimumTarget
            )
            .background(.white.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
        }
        .accessibilityIdentifier("overview.companyHero")
    }

    private var executiveMetrics: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            NorthBridgeSectionHeader(
                "I korthet",
                subtitle: "Det viktigaste just nu"
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: NorthBridgeSpacing.md) {
                    deadlineMetric
                    liquidityMetric
                    actionMetric
                }

                VStack(spacing: NorthBridgeSpacing.md) {
                    deadlineMetric
                    liquidityMetric
                    actionMetric
                }
            }
        }
        .accessibilityIdentifier("overview.metrics")
    }

    private var deadlineMetric: some View {
        NavigationLink(value: AppRoute.deadlines) {
            NorthBridgeMetricTile(
                title: "Nästa deadline",
                value: nextDeadlineValue,
                systemImage: "calendar.badge.clock",
                tint: deadlineTint,
                footnote: nextDeadlineFootnote
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("overview.metric.deadline")
    }

    private var liquidityMetric: some View {
        Button {
            environment.selectedTab = .finance
        } label: {
            NorthBridgeMetricTile(
                title: liquidityMetricTitle,
                value: liquidityMetricValue,
                systemImage: hidesFinancialValues ? "eye.slash" : "banknote",
                tint: .northBridgeInformational,
                footnote: liquidityMetricFootnote
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(liquidityAccessibilityLabel)
        .accessibilityIdentifier("overview.metric.liquidity")
    }

    private var actionMetric: some View {
        NavigationLink(value: AppRoute.actionTracker) {
            NorthBridgeMetricTile(
                title: "Öppna åtgärder",
                value: openActions.count.formatted(),
                systemImage: "checklist",
                tint: openActions.contains(where: { $0.dueAt < .now })
                    ? .northBridgeCritical
                    : .northBridgeBlue,
                footnote: openActionFootnote
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("overview.metric.actions")
    }

    @ViewBuilder
    private var nextAction: some View {
        if let action = nextDashboardAction {
            VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
                NorthBridgeSectionHeader("Nästa åtgärd")

                NavigationLink(value: action.route) {
                    HStack(alignment: .center, spacing: NorthBridgeSpacing.lg) {
                        Image(systemName: action.systemImage)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(action.tint)
                            .frame(width: 48, height: 48)
                            .background(
                                action.tint.opacity(0.12),
                                in: RoundedRectangle(
                                    cornerRadius: NorthBridgeRadius.control,
                                    style: .continuous
                                )
                            )
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                            Text(action.eyebrow)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(action.tint)
                                .textCase(.uppercase)
                            Text(action.title)
                                .font(.headline)
                                .foregroundStyle(Color.northBridgeTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(action.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(Color.northBridgeTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: NorthBridgeSpacing.sm)

                        Image(systemName: "arrow.right")
                            .font(.headline)
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                    .padding(NorthBridgeSpacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.northBridgeRaisedSurface,
                        in: RoundedRectangle(
                            cornerRadius: NorthBridgeRadius.card,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: NorthBridgeRadius.card,
                            style: .continuous
                        )
                        .stroke(action.tint.opacity(0.22), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Öppnar åtgärden")
                .accessibilityIdentifier("overview.nextAction")
            }
        } else {
            healthyState
        }
    }

    private var healthyState: some View {
        HStack(alignment: .top, spacing: NorthBridgeSpacing.md) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(Color.northBridgePositive)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                Text("Allt ser bra ut")
                    .font(.headline)
                Text("Inga registrerade deadlines eller åtgärder behöver din uppmärksamhet just nu.")
                    .font(.subheadline)
                    .foregroundStyle(Color.northBridgeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(NorthBridgeSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.northBridgePositive.opacity(0.09),
            in: RoundedRectangle(
                cornerRadius: NorthBridgeRadius.card,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isSummaryElement)
        .accessibilityIdentifier("overview.healthy")
    }

    private var commandCenter: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            NorthBridgeSectionHeader(
                "Kommandocenter",
                subtitle: "Gå direkt till bolagets viktigaste arbetsytor"
            )

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: NorthBridgeSpacing.md) {
                    deadlineCommand
                    documentCommand
                    governanceCommand
                    integrationCommand
                }
            } else {
                Grid(
                    horizontalSpacing: NorthBridgeSpacing.md,
                    verticalSpacing: NorthBridgeSpacing.md
                ) {
                    GridRow {
                        deadlineCommand
                        documentCommand
                    }
                    GridRow {
                        governanceCommand
                        integrationCommand
                    }
                }
            }
        }
        .accessibilityIdentifier("overview.commands")
    }

    private var deadlineCommand: some View {
        NavigationLink(value: AppRoute.deadlines) {
            NorthBridgeCommandCard(
                title: "Deadlines",
                detail: deadlineCommandDetail,
                systemImage: "calendar.badge.clock",
                tint: deadlineTint,
                badge: openDeadlines.isEmpty ? nil : openDeadlines.count.formatted()
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var documentCommand: some View {
        Button {
            environment.selectedTab = .documents
        } label: {
            NorthBridgeCommandCard(
                title: "Dokument",
                detail: documentCommandDetail,
                systemImage: "doc.text",
                tint: .northBridgeInformational,
                badge: companyDocuments.isEmpty
                    ? nil
                    : companyDocuments.count.formatted()
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var governanceCommand: some View {
        NavigationLink(value: AppRoute.boardWorkspace) {
            NorthBridgeCommandCard(
                title: "Styrning",
                detail: governanceCommandDetail,
                systemImage: "person.3.sequence",
                tint: .northBridgeBlue,
                badge: openActions.isEmpty ? nil : openActions.count.formatted()
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var integrationCommand: some View {
        NavigationLink(value: AppRoute.integrations) {
            NorthBridgeCommandCard(
                title: "Integrationer",
                detail: integrationCommandDetail,
                systemImage: "arrow.triangle.2.circlepath",
                tint: unhealthyIntegrations.isEmpty
                    ? .northBridgePositive
                    : .northBridgeWarning,
                badge: unhealthyIntegrations.isEmpty
                    ? nil
                    : unhealthyIntegrations.count.formatted()
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentPreviews: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            NorthBridgeSectionHeader("Senaste nytt")

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: NorthBridgeSpacing.md) {
                    if !companyAuditEvents.isEmpty {
                        recentActivityCard
                    }
                    if !companyDocuments.isEmpty {
                        recentDocumentsCard
                    }
                }

                VStack(spacing: NorthBridgeSpacing.md) {
                    if !companyAuditEvents.isEmpty {
                        recentActivityCard
                    }
                    if !companyDocuments.isEmpty {
                        recentDocumentsCard
                    }
                }
            }
        }
    }

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            HStack {
                Label("Aktivitet", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
                NavigationLink("Visa alla", value: AppRoute.activity)
                    .font(.subheadline.weight(.semibold))
            }

            ForEach(companyAuditEvents.prefix(dashboardPreviewLimit)) { event in
                HStack(alignment: .top, spacing: NorthBridgeSpacing.sm) {
                    Circle()
                        .fill(Color.northBridgeInformational)
                        .frame(width: 7, height: 7)
                        .padding(.top, 6)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                        Text(event.summary)
                            .font(.subheadline)
                            .lineLimit(2)
                        Text(
                            event.occurredAt,
                            format: .relative(presentation: .named)
                        )
                        .font(.caption)
                        .foregroundStyle(Color.northBridgeTextSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(NorthBridgeSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.northBridgeSurface,
            in: RoundedRectangle(
                cornerRadius: NorthBridgeRadius.card,
                style: .continuous
            )
        )
    }

    private var recentDocumentsCard: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            HStack {
                Label("Dokument", systemImage: "doc.text")
                    .font(.headline)
                Spacer()
                Button("Visa alla") {
                    environment.selectedTab = .documents
                }
                .font(.subheadline.weight(.semibold))
            }

            ForEach(companyDocuments.prefix(dashboardPreviewLimit)) { document in
                NavigationLink(value: AppRoute.document(document.id)) {
                    HStack(spacing: NorthBridgeSpacing.sm) {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(Color.northBridgeInformational)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                            Text(document.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.northBridgeTextPrimary)
                                .lineLimit(2)
                            Text(
                                "\(document.category.localizedName) · \(document.importedAt.formatted(date: .abbreviated, time: .omitted))"
                            )
                            .font(.caption)
                            .foregroundStyle(Color.northBridgeTextSecondary)
                        }
                        Spacer(minLength: NorthBridgeSpacing.xs)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(NorthBridgeSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.northBridgeSurface,
            in: RoundedRectangle(
                cornerRadius: NorthBridgeRadius.card,
                style: .continuous
            )
        )
    }

    private var company: CompanyRecord? {
        companies.first { $0.id == environment.selectedCompanyID }
    }

    private var hidesFinancialValues: Bool {
        environment.presentationPreferences.financialPrivacyBlur
    }

    private var dashboardContentSpacing: CGFloat {
        environment.presentationPreferences.dashboardDensity == .compact
            ? NorthBridgeSpacing.xl
            : NorthBridgeSpacing.xxl
    }

    private var dashboardPreviewLimit: Int {
        environment.presentationPreferences.dashboardDensity == .compact ? 2 : 3
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

    private var latestLiquidity: FinancialMetricRecord? {
        let preferredKinds: [FinancialMetricKind] = [
            .availableLiquidity,
            .bankBalance,
            .operatingResult,
        ]
        return preferredKinds.lazy.compactMap { kind in
            companyMetrics
                .filter { $0.kind == kind }
                .max { $0.periodEnd < $1.periodEnd }
        }.first
    }

    private var nextDeadlineValue: String {
        guard let deadline = openDeadlines.first else {
            return String(localized: "Ingen")
        }
        if deadline.dueAt < .now {
            return String(localized: "Försenad")
        }
        return deadline.dueAt.formatted(.dateTime.day().month(.abbreviated))
    }

    private var nextDeadlineFootnote: String? {
        guard let deadline = openDeadlines.first else {
            return String(localized: "Inget planerat")
        }
        return deadline.title
    }

    private var deadlineTint: Color {
        openDeadlines.contains(where: { $0.dueAt < .now })
            ? .northBridgeCritical
            : .northBridgeWarning
    }

    private var openActionFootnote: String? {
        if openActions.isEmpty {
            return String(localized: "Inget att följa upp")
        }
        let overdue = openActions.filter { $0.dueAt < .now }.count
        return overdue > 0
            ? String(localized: "\(overdue) försenade")
            : String(localized: "Under uppföljning")
    }

    private var liquidityMetricTitle: LocalizedStringKey {
        latestLiquidity?.kind == .operatingResult
            ? "Rörelseresultat"
            : "Likviditet"
    }

    private var liquidityMetricValue: String {
        guard canViewFinance else {
            return String(localized: "Skyddat")
        }
        guard !hidesFinancialValues else {
            return "••••••"
        }
        guard let latestLiquidity else {
            return String(localized: "Saknas")
        }
        return latestLiquidity.amount.formatted(
            .currency(code: latestLiquidity.currencyCode)
                .precision(.fractionLength(0))
        )
    }

    private var liquidityMetricFootnote: String? {
        guard canViewFinance else {
            return String(localized: "Behörighet krävs")
        }
        guard !hidesFinancialValues else {
            return String(localized: "Dolt i ekonomiinställningar")
        }
        return latestLiquidity.map {
            $0.periodEnd.formatted(.dateTime.month(.abbreviated).year())
        } ?? String(localized: "Inget underlag")
    }

    private var liquidityAccessibilityLabel: String {
        if !canViewFinance {
            return String(localized: "Finansiellt värde, behörighet krävs")
        }
        if hidesFinancialValues {
            return String(localized: "Finansiellt värde dolt")
        }
        return String(
            localized: "\(liquidityMetricAccessibilityTitle), \(liquidityMetricValue)"
        )
    }

    private var liquidityMetricAccessibilityTitle: String {
        latestLiquidity?.kind == .operatingResult
            ? String(localized: "Rörelseresultat")
            : String(localized: "Likviditet")
    }

    private var deadlineCommandDetail: String {
        let overdue = openDeadlines.filter { $0.dueAt < .now }.count
        if overdue > 0 {
            return String(localized: "\(overdue) behöver hanteras nu")
        }
        return openDeadlines.isEmpty
            ? String(localized: "Inget öppet")
            : String(localized: "Nästa är \(nextDeadlineValue.lowercased())")
    }

    private var documentCommandDetail: String {
        companyDocuments.isEmpty
            ? String(localized: "Importera första dokumentet")
            : String(localized: "\(companyDocuments.count) i valvet")
    }

    private var governanceCommandDetail: String {
        openActions.isEmpty
            ? String(localized: "Styrelsearbetet är i fas")
            : String(localized: "\(openActions.count) öppna åtgärder")
    }

    private var integrationCommandDetail: String {
        if !unhealthyIntegrations.isEmpty {
            return String(localized: "\(unhealthyIntegrations.count) kräver tillsyn")
        }
        let connected = companyIntegrations.filter { $0.state == .connected }.count
        return connected > 0
            ? String(localized: "\(connected) anslutna")
            : String(localized: "Anslut datakällor")
    }

    private var nextDashboardAction: DashboardActionSummary? {
        let deadline = openDeadlines.first.map {
            DashboardActionSummary(
                id: "deadline-\($0.id.uuidString)",
                eyebrow: $0.dueAt < .now ? "Försenad deadline" : "Kommande deadline",
                title: $0.title,
                subtitle: $0.dueAt.formatted(date: .long, time: .omitted),
                dueAt: $0.dueAt,
                systemImage: "calendar.badge.clock",
                tint: $0.dueAt < .now
                    ? .northBridgeCritical
                    : .northBridgeWarning,
                route: .deadline($0.id)
            )
        }
        let action = openActions.first.map {
            DashboardActionSummary(
                id: "action-\($0.id.uuidString)",
                eyebrow: "Styrelseåtgärd",
                title: $0.title,
                subtitle: String(
                    localized: "\($0.assignedTo) · \($0.dueAt.formatted(date: .abbreviated, time: .omitted))"
                ),
                dueAt: $0.dueAt,
                systemImage: "checklist",
                tint: $0.dueAt < .now
                    ? .northBridgeCritical
                    : .northBridgeBlue,
                route: .actionTracker
            )
        }

        if let dated = [deadline, action]
            .compactMap({ $0 })
            .min(by: { $0.dueAt < $1.dueAt }) {
            return dated
        }

        guard let company else { return nil }
        if company.status == .unknown || company.isStale {
            return DashboardActionSummary(
                id: "company-quality",
                eyebrow: "Bolagsuppgifter",
                title: company.status == .unknown
                    ? String(localized: "Komplettera bolagsprofilen")
                    : String(localized: "Granska inaktuella uppgifter"),
                subtitle: freshnessText(company),
                dueAt: .distantFuture,
                systemImage: "building.2.crop.circle",
                tint: .northBridgeWarning,
                route: .companyDetails
            )
        }

        if !unhealthyIntegrations.isEmpty {
            return DashboardActionSummary(
                id: "integration-health",
                eyebrow: "Integrationer",
                title: String(localized: "Återställ dataflödet"),
                subtitle: String(
                    localized: "\(unhealthyIntegrations.count) integrationer kräver tillsyn"
                ),
                dueAt: .distantFuture,
                systemImage: "arrow.triangle.2.circlepath",
                tint: .northBridgeWarning,
                route: .integrations
            )
        }

        return nil
    }

    private func freshnessText(_ company: CompanyRecord) -> String {
        if company.isStale {
            return String(localized: "Uppgifterna behöver uppdateras")
        }
        guard let date = company.lastSynchronizedAt else {
            return String(
                localized: "Källa: \(company.sourceName) · aldrig synkroniserad"
            )
        }
        return String(
            localized: "Källa: \(company.sourceName) · \(date.formatted(date: .abbreviated, time: .shortened))"
        )
    }

    private func companyStatusKind(
        _ status: CompanyStatus
    ) -> NorthBridgeStatusKind {
        switch status {
        case .active:
            .positive
        case .unknown:
            .warning
        case .inactive:
            .neutral
        case .liquidation, .bankruptcy:
            .critical
        }
    }

    private func formattedOrganisationNumber(_ digits: String) -> String {
        (try? OrganisationNumber(digits).formatted) ?? digits
    }
}

private struct DashboardActionSummary {
    let id: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let dueAt: Date
    let systemImage: String
    let tint: Color
    let route: AppRoute
}
