import Foundation
import SwiftData
import SwiftUI

@MainActor
struct GlobalSearchView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var memberships: [CompanyMembershipRecord]
    @Query(sort: \CompanyRecord.registeredName) private var companies: [CompanyRecord]
    @Query private var companyProfiles: [CompanyProfileRecord]
    @Query(sort: \PersonRecord.fullName) private var people: [PersonRecord]
    @Query(sort: \ShareholderRecord.displayName) private var shareholders: [ShareholderRecord]
    @Query(sort: \DocumentRecord.title) private var documents: [DocumentRecord]
    @Query(sort: \BoardMeetingRecord.scheduledAt, order: .reverse) private var meetings: [BoardMeetingRecord]
    @Query(sort: \BoardResolutionRecord.createdAt, order: .reverse) private var resolutions: [BoardResolutionRecord]
    @Query(sort: \DeadlineRecord.dueAt) private var deadlines: [DeadlineRecord]
    @Query(sort: \FinancialMetricRecord.sourceUpdatedAt, order: .reverse) private var metrics: [FinancialMetricRecord]
    @Query(sort: \AuditEventRecord.occurredAt, order: .reverse) private var events: [AuditEventRecord]

    @State private var searchText = ""
    @State private var exportedOverviewURL: URL?
    @State private var exportErrorMessage: String?
    @State private var isExportingOverview = false
    @State private var selectedScope: GlobalSearchCategory = .all

    var body: some View {
        let currentResults = results
        let currentFilteredResults = filteredResults(from: currentResults)

        NorthBridgeScreen {
            searchHero

            if searchText.trimmed.isEmpty {
                quickActions
                Label(
                    "Sökningen omfattar endast bolag och poster som din lokala profil har aktiv behörighet till.",
                    systemImage: "lock.shield"
                )
                .font(.footnote)
                .foregroundStyle(Color.northBridgeTextSecondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.northBridgeRecessedSurface,
                    in: RoundedRectangle(cornerRadius: NorthBridgeRadius.control, style: .continuous)
                )
            } else if currentResults.isEmpty {
                NorthBridgeEmptyState(
                    systemImage: "magnifyingglass",
                    title: "Inga träffar",
                    message: "Kontrollera stavningen eller prova ett bredare sökord.",
                    compact: true
                )
            } else {
                resultFilterBar(currentResults)

                if currentFilteredResults.isEmpty {
                    NorthBridgeEmptyState(
                        systemImage: selectedScope.systemImage,
                        title: "Inga träffar i filtret",
                        message: "Sökningen gav träffar i andra delar av arbetsytan.",
                        compact: true,
                        actionTitle: "Visa alla",
                        action: { selectedScope = .all }
                    )
                } else {
                    ForEach(resultGroups(from: currentFilteredResults)) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            NorthBridgeSectionHeader(group.category.title)

                            VStack(spacing: 0) {
                                ForEach(group.results) { result in
                                    Button {
                                        open(result)
                                    } label: {
                                        GlobalSearchResultRow(result: result)
                                    }
                                    .buttonStyle(.plain)
                                    if result.id != group.results.last?.id {
                                        Divider()
                                            .padding(.leading, 62)
                                    }
                                }
                            }
                            .background(
                                Color.northBridgeRaisedSurface,
                                in: RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous)
                                    .stroke(Color.northBridgeHairline, lineWidth: 0.5)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Sök")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .accessibilityIdentifier("search.root")
        .onChange(of: environment.selectedCompanyID) { _, _ in
            exportedOverviewURL = nil
        }
        .alert(
            "Exporten misslyckades",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            NorthBridgeSectionHeader(
                "Snabbåtgärder",
                subtitle: "Vanliga flöden, alltid nära"
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                spacing: 12
            ) {
                quickAction("Importera dokument", systemImage: "square.and.arrow.down") {
                    environment.requestDocumentImport()
                }
                quickAction("Skapa styrelsemöte", systemImage: "person.3.sequence") {
                    environment.navigate(to: .addBoardMeeting, in: .company)
                }
                quickAction("Lägg till deadline", systemImage: "calendar.badge.plus") {
                    environment.navigate(to: .addDeadline, in: .overview)
                }
                quickAction("Registrera beslut", systemImage: "checkmark.seal") {
                    environment.navigate(to: .boardWorkspace, in: .company)
                }
                quickAction("Lägg till aktieägare", systemImage: "person.badge.plus") {
                    environment.navigate(to: .ownership, in: .company)
                }

                Button {
                    exportCompanyOverview()
                } label: {
                    SearchQuickActionLabel(
                        title: isExportingOverview ? "Skapar översikt" : "Exportera översikt",
                        systemImage: "square.and.arrow.up",
                        isWorking: isExportingOverview
                    )
                }
                .buttonStyle(.plain)
                .disabled(activeCompany == nil || isExportingOverview)
                .accessibilityIdentifier("search.exportCompanyOverview")

                if let exportedOverviewURL {
                    ShareLink(item: exportedOverviewURL) {
                        SearchQuickActionLabel(
                            title: "Dela bolagsöversikt",
                            systemImage: "doc.richtext"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("search.shareCompanyOverview")
                }

                quickAction("Fråga Bolagsassistenten", systemImage: "sparkles") {
                    environment.navigate(to: .assistant, in: .overview)
                }
            }
        }
    }

    private var searchHero: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(
                    .white.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("Hitta i hela arbetsytan")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(searchContextDescription)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [.northBridgeNavy, .northBridgeBlue.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: NorthBridgeRadius.hero, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private func resultFilterBar(_ currentResults: [GlobalSearchResult]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(GlobalSearchCategory.allCases) { category in
                    NorthBridgeFilterChip(
                        category.title,
                        systemImage: category == .all ? nil : category.systemImage,
                        isSelected: selectedScope == category,
                        count: category == .all
                            ? currentResults.count
                            : currentResults.lazy.filter { $0.category == category }.count
                    ) {
                        withAnimation(selectionAnimation) {
                            selectedScope = category
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("search.filters")
    }

    private func quickAction(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            SearchQuickActionLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private var searchContextDescription: String {
        if let activeCompany {
            return String(localized: "Bolag, dokument och händelser i \(activeCompany.registeredName)")
        }
        return String(localized: "Sök bland bolag och poster du har behörighet till")
    }

    private func filteredResults(
        from currentResults: [GlobalSearchResult]
    ) -> [GlobalSearchResult] {
        guard selectedScope != .all else { return currentResults }
        return currentResults.filter { $0.category == selectedScope }
    }

    private var selectionAnimation: Animation? {
        reduceMotion || !environment.presentationPreferences.enhancedMotion
            ? nil
            : NorthBridgeMotion.selection
    }

    private func resultGroups(
        from currentResults: [GlobalSearchResult]
    ) -> [GlobalSearchResultGroup] {
        GlobalSearchCategory.allCases.compactMap { category in
            guard category != .all else { return nil }
            let categoryResults = currentResults.filter { $0.category == category }
            guard !categoryResults.isEmpty else { return nil }
            return GlobalSearchResultGroup(category: category, results: categoryResults)
        }
    }

    private var activeCompany: CompanyRecord? {
        if let selectedCompanyID = environment.selectedCompanyID,
           accessibleCompanyIDs.contains(selectedCompanyID),
           let selectedCompany = companies.first(where: { $0.id == selectedCompanyID }) {
            return selectedCompany
        }

        return companies.first(where: { accessibleCompanyIDs.contains($0.id) })
    }

    private func exportCompanyOverview() {
        guard let company = activeCompany,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                  companyID: company.id,
                  accountID: accountID,
                  memberships: memberships
              ),
              environment.permissionPolicy.allows(.exportData, for: role) else {
            exportErrorMessage = "Välj ett behörigt bolag innan du exporterar."
            return
        }

        isExportingOverview = true
        defer { isExportingOverview = false }

        let profile = companyProfiles.first(where: { $0.companyID == company.id })
        let companyDeadlines = deadlines
            .filter {
                $0.companyID == company.id
                    && ($0.status == .open || $0.status == .inProgress)
            }
            .sorted(by: { $0.dueAt < $1.dueAt })
            .prefix(8)
            .map {
                CompanyOverviewDeadlineRow(
                    title: $0.title,
                    dueAt: $0.dueAt,
                    priority: $0.priority,
                    responsibleName: $0.responsibleName
                )
            }
        let latestMetrics = Dictionary(
            grouping: metrics.filter { $0.companyID == company.id },
            by: { $0.kind.rawValue }
        )
        .values
        .compactMap { group in
            group.max(by: { $0.sourceUpdatedAt < $1.sourceUpdatedAt })
        }
        .sorted(by: { $0.kind.localizedName < $1.kind.localizedName })
        .map {
            CompanyOverviewFinancialMetricRow(
                title: $0.kind.localizedName,
                amount: $0.amount,
                currencyCode: $0.currencyCode,
                valueState: $0.valueState,
                sourceName: $0.sourceName,
                sourceUpdatedAt: $0.sourceUpdatedAt
            )
        }
        let input = CompanyOverviewPDFInput(
            companyID: company.id,
            companyName: company.registeredName,
            organisationNumber: company.organisationNumber,
            status: company.status,
            companyType: profile?.companyType ?? "",
            registeredOffice: profile?.registeredOffice ?? "",
            incorporationDate: profile?.incorporationDate,
            fiscalYear: profile.map(fiscalYearDescription) ?? "",
            businessDescription: profile?.businessDescription ?? "",
            shareCapital: profile?.shareCapital,
            shareCapitalCurrencyCode: profile?.shareCapitalCurrencyCode ?? "SEK",
            generatedAt: .now,
            sourceName: company.sourceName,
            sourceUpdatedAt: company.sourceUpdatedAt,
            lastSynchronizedAt: company.lastSynchronizedAt,
            peopleCount: people.filter { $0.companyID == company.id }.count,
            shareholderCount: shareholders.filter { $0.companyID == company.id }.count,
            documentCount: documents.filter { $0.companyID == company.id }.count,
            meetingCount: meetings.filter { $0.companyID == company.id }.count,
            adoptedResolutionCount: resolutions.filter {
                $0.companyID == company.id && $0.status == .adopted
            }.count,
            openDeadlines: Array(companyDeadlines),
            financialMetrics: latestMetrics
        )

        var generatedURL: URL?
        do {
            let fileURL = try GovernancePDFExporter.exportCompanyOverview(input)
            generatedURL = fileURL
            modelContext.insert(
                AuditEventRecord(
                    companyID: company.id,
                    accountID: accountID,
                    action: "company.overview.exported",
                    entityType: "companyOverview",
                    entityID: company.id,
                    summary: String(
                        localized: "Bolagsöversikten exporterades som PDF."
                    )
                )
            )
            try modelContext.save()
            exportedOverviewURL = fileURL
            exportErrorMessage = nil
        } catch {
            modelContext.rollback()
            if let generatedURL {
                try? FileManager.default.removeItem(at: generatedURL)
            }
            exportedOverviewURL = nil
            exportErrorMessage = error.localizedDescription
        }
    }

    private func fiscalYearDescription(_ profile: CompanyProfileRecord) -> String {
        String(
            format: "%02d-%02d–%02d-%02d",
            profile.fiscalYearStartMonth,
            profile.fiscalYearStartDay,
            profile.fiscalYearEndMonth,
            profile.fiscalYearEndDay
        )
    }

    private var accessibleCompanyIDs: Set<UUID> {
        guard let accountID = environment.sessionController.activeSession?.accountID else {
            return []
        }
        return Set(
            memberships
                .filter { $0.accountID == accountID && $0.isActive }
                .map(\.companyID)
        )
    }

    private var results: [GlobalSearchResult] {
        let query = searchText.trimmed
        guard !query.isEmpty else { return [] }
        var output: [GlobalSearchResult] = []

        output += companies
            .filter {
                accessibleCompanyIDs.contains($0.id)
                    && ($0.registeredName.localizedStandardContains(query)
                        || $0.organisationNumber.localizedStandardContains(query))
            }
            .map {
                GlobalSearchResult(
                    id: "company:\($0.id)",
                    companyID: $0.id,
                    title: $0.registeredName,
                    subtitle: "Bolag · \($0.organisationNumber)",
                    systemImage: "building.2",
                    category: .company,
                    destination: .route(.companyDetails, tab: .company)
                )
            }

        output += people
            .filter {
                accessibleCompanyIDs.contains($0.companyID)
                    && ($0.fullName.localizedStandardContains(query)
                        || $0.email?.localizedStandardContains(query) == true)
            }
            .map {
                GlobalSearchResult(
                    id: "person:\($0.id)",
                    companyID: $0.companyID,
                    title: $0.fullName,
                    subtitle: "Person",
                    systemImage: "person",
                    category: .governance,
                    destination: .route(.boardAndSignatories, tab: .company)
                )
            }

        output += shareholders
            .filter {
                accessibleCompanyIDs.contains($0.companyID)
                    && ($0.displayName.localizedStandardContains(query)
                        || $0.identityReference?.localizedStandardContains(query) == true)
            }
            .map {
                GlobalSearchResult(
                    id: "shareholder:\($0.id)",
                    companyID: $0.companyID,
                    title: $0.displayName,
                    subtitle: "Aktieägare",
                    systemImage: "chart.pie",
                    category: .governance,
                    destination: .route(.shareholderRegister, tab: .company)
                )
            }

        output += documents
            .filter {
                accessibleCompanyIDs.contains($0.companyID)
                    && ($0.title.localizedStandardContains(query)
                        || $0.tags.localizedStandardContains(query)
                        || $0.extractedText?.localizedStandardContains(query) == true
                        || $0.detectedParties?.localizedStandardContains(query) == true)
            }
            .map {
                GlobalSearchResult(
                    id: "document:\($0.id)",
                    companyID: $0.companyID,
                    title: $0.title,
                    subtitle: "Dokument · \($0.category.localizedName)",
                    systemImage: "doc.text",
                    category: .documents,
                    destination: .route(.document($0.id), tab: .documents)
                )
            }

        output += meetings
            .filter {
                accessibleCompanyIDs.contains($0.companyID)
                    && ($0.title.localizedStandardContains(query)
                        || $0.location.localizedStandardContains(query)
                        || $0.notes.localizedStandardContains(query))
            }
            .map {
                GlobalSearchResult(
                    id: "meeting:\($0.id)",
                    companyID: $0.companyID,
                    title: $0.title,
                    subtitle: "Styrelsemöte · \($0.scheduledAt.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "person.3.sequence",
                    category: .governance,
                    destination: .route(.boardMeeting($0.id), tab: .company)
                )
            }

        output += resolutions
            .filter {
                accessibleCompanyIDs.contains($0.companyID)
                    && ($0.title.localizedStandardContains(query)
                        || $0.decisionText.localizedStandardContains(query))
            }
            .map {
                GlobalSearchResult(
                    id: "resolution:\($0.id)",
                    companyID: $0.companyID,
                    title: $0.title,
                    subtitle: "Beslut · \($0.status.localizedName)",
                    systemImage: "checkmark.seal",
                    category: .governance,
                    destination: .route(.resolution($0.id), tab: .company)
                )
            }

        output += deadlines
            .filter {
                accessibleCompanyIDs.contains($0.companyID)
                    && ($0.title.localizedStandardContains(query)
                        || $0.details.localizedStandardContains(query)
                        || $0.responsibleName?.localizedStandardContains(query) == true)
            }
            .map {
                GlobalSearchResult(
                    id: "deadline:\($0.id)",
                    companyID: $0.companyID,
                    title: $0.title,
                    subtitle: "Deadline · \($0.dueAt.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "calendar.badge.clock",
                    category: .company,
                    destination: .route(.deadline($0.id), tab: .overview)
                )
            }

        output += metrics
            .filter {
                accessibleCompanyIDs.contains($0.companyID)
                    && ($0.kind.localizedName.localizedStandardContains(query)
                        || $0.sourceName.localizedStandardContains(query))
            }
            .map {
                GlobalSearchResult(
                    id: "metric:\($0.id)",
                    companyID: $0.companyID,
                    title: $0.kind.localizedName,
                    subtitle: "Finansiellt mått · \($0.sourceName)",
                    systemImage: "chart.xyaxis.line",
                    category: .finance,
                    destination: .route(.financialMetric($0.id), tab: .finance)
                )
            }

        output += events
            .filter {
                guard let companyID = $0.companyID else { return false }
                return accessibleCompanyIDs.contains(companyID)
                    && $0.summary.localizedStandardContains(query)
            }
            .map {
                GlobalSearchResult(
                    id: "event:\($0.id)",
                    companyID: $0.companyID,
                    title: $0.summary,
                    subtitle: "Aktivitet · \($0.occurredAt.formatted(date: .abbreviated, time: .shortened))",
                    systemImage: "clock.arrow.circlepath",
                    category: .activity,
                    destination: .route(.activity, tab: .company)
                )
            }

        return Array(output.prefix(60))
    }

    private func open(_ result: GlobalSearchResult) {
        if let companyID = result.companyID {
            environment.selectedCompanyID = companyID
        }
        switch result.destination {
        case .route(let route, let tab):
            environment.navigate(to: route, in: tab)
        case .tab(let tab):
            environment.selectedTab = tab
        }
    }
}

private enum GlobalSearchCategory: String, CaseIterable, Identifiable {
    case all
    case company
    case documents
    case governance
    case finance
    case activity

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .all: "Alla"
        case .company: "Bolag"
        case .documents: "Dokument"
        case .governance: "Styrning"
        case .finance: "Ekonomi"
        case .activity: "Aktivitet"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .company: "building.2"
        case .documents: "doc.text"
        case .governance: "person.3.sequence"
        case .finance: "chart.xyaxis.line"
        case .activity: "clock.arrow.circlepath"
        }
    }

    var tint: Color {
        switch self {
        case .all, .company: .northBridgeInformational
        case .documents: .cyan
        case .governance: .indigo
        case .finance: .northBridgePositive
        case .activity: .northBridgeWarning
        }
    }
}

private struct GlobalSearchResultGroup: Identifiable {
    let category: GlobalSearchCategory
    let results: [GlobalSearchResult]

    var id: GlobalSearchCategory { category }
}

private struct SearchQuickActionLabel: View {
    let title: String
    let systemImage: String
    var isWorking = false

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if isWorking {
                    ProgressView()
                        .tint(.northBridgeBlue)
                } else {
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(Color.northBridgeInformational)
                }
            }
            .frame(width: 38, height: 38)
            .background(
                Color.northBridgeInformational.opacity(0.11),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.northBridgeTextPrimary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(12)
        .background(
            Color.northBridgeRaisedSurface,
            in: RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous)
                .stroke(Color.northBridgeHairline, lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous))
    }
}

private struct GlobalSearchResultRow: View {
    let result: GlobalSearchResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.systemImage)
                .font(.headline)
                .foregroundStyle(result.category.tint)
                .frame(width: 40, height: 40)
                .background(
                    result.category.tint.opacity(0.11),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.northBridgeTextPrimary)
                Text(result.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.northBridgeTextSecondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.northBridgeTextTertiary)
        }
        .padding(12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct GlobalSearchResult: Identifiable {
    enum Destination {
        case route(AppRoute, tab: AppTab)
        case tab(AppTab)
    }

    let id: String
    let companyID: UUID?
    let title: String
    let subtitle: String
    let systemImage: String
    let category: GlobalSearchCategory
    let destination: Destination
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
