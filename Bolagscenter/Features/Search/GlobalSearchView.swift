import Foundation
import SwiftData
import SwiftUI

@MainActor
struct GlobalSearchView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
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

    var body: some View {
        List {
            if searchText.trimmed.isEmpty {
                quickActions
                Section {
                    Text("Sökningen omfattar endast bolag och poster som den lokala profilen har aktiv behörighet till.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if results.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            } else {
                Section("Träffar") {
                    ForEach(results) { result in
                        Button {
                            open(result)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: result.systemImage)
                                    .foregroundStyle(Color.bolagscenterBlue)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.title)
                                        .foregroundStyle(.primary)
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .navigationTitle("Sök")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always)
        )
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

    @ViewBuilder
    private var quickActions: some View {
        Section("Snabbåtgärder") {
            Button {
                environment.requestDocumentImport()
            } label: {
                Label("Importera dokument", systemImage: "square.and.arrow.down")
            }
            Button {
                environment.navigate(to: .addBoardMeeting, in: .company)
            } label: {
                Label("Skapa styrelsemöte", systemImage: "person.3.sequence")
            }
            Button {
                environment.navigate(to: .addDeadline, in: .overview)
            } label: {
                Label("Lägg till deadline", systemImage: "calendar.badge.plus")
            }
            Button {
                environment.navigate(to: .boardWorkspace, in: .company)
            } label: {
                Label("Registrera beslut", systemImage: "checkmark.seal")
            }
            Button {
                environment.navigate(to: .ownership, in: .company)
            } label: {
                Label("Lägg till aktieägare", systemImage: "person.badge.plus")
            }
            Button {
                exportCompanyOverview()
            } label: {
                if isExportingOverview {
                    Label {
                        Text("Skapar bolagsöversikt")
                    } icon: {
                        ProgressView()
                    }
                } else {
                    Label("Exportera bolagsöversikt", systemImage: "square.and.arrow.up")
                }
            }
            .disabled(activeCompany == nil || isExportingOverview)
            .accessibilityIdentifier("search.exportCompanyOverview")

            if let exportedOverviewURL {
                ShareLink(item: exportedOverviewURL) {
                    Label("Dela bolagsöversikt", systemImage: "doc.richtext")
                }
                .accessibilityIdentifier("search.shareCompanyOverview")
            }
            Button {
                environment.navigate(to: .assistant, in: .more)
            } label: {
                Label("Fråga Bolagsassistenten", systemImage: "sparkles")
            }
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
    let destination: Destination
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
