import SwiftData
import SwiftUI

@MainActor
struct CompanyWorkspaceView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \CompanyRecord.registeredName) private var companies: [CompanyRecord]
    @Query private var memberships: [CompanyMembershipRecord]
    @Query private var profiles: [CompanyProfileRecord]
    @Query private var registrations: [CompanyRegistrationRecord]
    @Query private var boardMembers: [BoardMemberRecord]
    @Query private var shareholders: [ShareholderRecord]
    @Query private var shareClasses: [ShareClassRecord]
    @Query private var beneficialOwners: [BeneficialOwnerRecord]
    @Query(sort: \DeadlineRecord.dueAt) private var deadlines: [DeadlineRecord]
    @Query(sort: \AuditEventRecord.occurredAt, order: .reverse)
    private var auditEvents: [AuditEventRecord]

    @AppStorage("northbridge.company.workspace.presentation")
    private var presentationRawValue = CompanyWorkspacePresentation.comfortable.rawValue
    @AppStorage("northbridge.company.workspace.showsSource")
    private var showsSourceSummary = true

    var body: some View {
        NorthBridgeScreen(contentSpacing: sectionSpacing) {
            if let company {
                companyHero(company)
                profileCompletenessCard
                identityGroup
                governanceGroup
                ownershipGroup
                complianceGroup

                if showsSourceSummary {
                    sourceSummary(company)
                }
            } else {
                NorthBridgeEmptyState(
                    systemImage: "building.2",
                    title: "Inget bolag valt",
                    message: "Välj ett bolag för att öppna bolagsarbetsytan.",
                    actionTitle: "Lägg till bolag",
                    action: { addCompany() }
                )
                .accessibilityIdentifier("company.workspace.empty")
            }
        }
        .navigationTitle("Bolag")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                workspaceMenu
            }
        }
    }

    private var workspaceMenu: some View {
        Menu {
            Button("Lägg till bolag", systemImage: "plus") {
                addCompany()
            }

            Divider()

            Picker("Presentation", selection: $presentationRawValue) {
                ForEach(CompanyWorkspacePresentation.allCases) { presentation in
                    Label(
                        presentation.title,
                        systemImage: presentation.systemImage
                    )
                    .tag(presentation.rawValue)
                }
            }

            Toggle(
                "Visa källsammanfattning",
                systemImage: "checkmark.seal",
                isOn: $showsSourceSummary
            )
        } label: {
            Label("Bolagsåtgärder", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("company.workspace.menu")
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
            Image(systemName: "building.2.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))
                .frame(
                    width: NorthBridgeMetrics.minimumTarget,
                    height: NorthBridgeMetrics.minimumTarget
                )
                .background(.white.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
        }
        .accessibilityIdentifier("company.workspace.hero")
    }

    private var profileCompletenessCard: some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    completenessTitle
                    Spacer()
                    completenessValue
                }

                VStack(alignment: .leading, spacing: NorthBridgeSpacing.sm) {
                    completenessTitle
                    completenessValue
                }
            }

            ProgressView(value: profileCompleteness)
                .tint(completenessTint)
                .accessibilityLabel("Registrerad profil")
                .accessibilityValue(profileCompletenessText)

            Text(completenessDetail)
                .font(.subheadline)
                .foregroundStyle(Color.northBridgeTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Mätaren visar endast vilka uppgifter som finns i NorthBridge och är inte en juridisk fullständighetskontroll.")
                .font(.caption)
                .foregroundStyle(Color.northBridgeTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(cardPadding)
        .northBridgeCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("company.workspace.completeness")
    }

    private var completenessTitle: some View {
        Label("Registrerad profil", systemImage: "chart.bar.fill")
            .font(.headline)
            .foregroundStyle(Color.northBridgeTextPrimary)
    }

    private var completenessValue: some View {
        NorthBridgeStatusPill(
            profileCompletenessText,
            kind: profileCompleteness >= 0.75
                ? .positive
                : (profileCompleteness >= 0.45 ? .warning : .informational)
        )
    }

    private var identityGroup: some View {
        workspaceGroup(
            title: "Identitet och registrering",
            subtitle: "Grunddata, registreringar och verifierade källor"
        ) {
            NavigationLink(value: AppRoute.companyDetails) {
                CompanyDestinationCard(
                    title: "Bolagsprofil",
                    detail: identityDetail,
                    systemImage: "building.2",
                    tint: .northBridgeBlue,
                    badge: profile == nil ? "Komplettera" : nil,
                    presentation: presentation
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("company.workspace.identity")
        }
    }

    private var governanceGroup: some View {
        workspaceGroup(
            title: "Styrning och firmateckning",
            subtitle: "Ansvar, mandat och styrelsearbete"
        ) {
            NavigationLink(value: AppRoute.boardAndSignatories) {
                CompanyDestinationCard(
                    title: "Styrelse och firmateckning",
                    detail: governanceDetail,
                    systemImage: "person.3",
                    tint: .northBridgeInformational,
                    badge: activeBoardMembers.isEmpty
                        ? nil
                        : activeBoardMembers.count.formatted(),
                    presentation: presentation
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("company.workspace.board")

            NavigationLink(value: AppRoute.boardWorkspace) {
                CompanyDestinationCard(
                    title: "Styrelsearbete",
                    detail: "Möten, beslut och öppna styrelseåtgärder",
                    systemImage: "person.3.sequence",
                    tint: .northBridgeBlue,
                    presentation: presentation
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("company.workspace.governance")
        }
    }

    private var ownershipGroup: some View {
        workspaceGroup(
            title: "Ägande och aktiebok",
            subtitle: "Ägare, aktieslag, transaktioner och aktiebrev"
        ) {
            NavigationLink(value: AppRoute.ownership) {
                CompanyDestinationCard(
                    title: "Ägaröversikt",
                    detail: ownershipDetail,
                    systemImage: "chart.pie",
                    tint: .northBridgePositive,
                    badge: companyShareholders.isEmpty
                        ? nil
                        : companyShareholders.count.formatted(),
                    presentation: presentation
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("company.workspace.ownership")

            destinationPair(
                leading: CompanyWorkspaceDestination(
                    route: .shareholderRegister,
                    title: "Aktiebok",
                    detail: "Register och transaktioner",
                    systemImage: "list.bullet.rectangle",
                    tint: .northBridgePositive
                ),
                trailing: CompanyWorkspaceDestination(
                    route: .shareCertificates,
                    title: "Aktiebrev",
                    detail: "Utfärdade underlag",
                    systemImage: "doc.text.image",
                    tint: .northBridgeInformational
                )
            )
        }
    }

    private var complianceGroup: some View {
        workspaceGroup(
            title: "Efterlevnad och historik",
            subtitle: "Deadlines, uppföljning och bolagets händelser"
        ) {
            NavigationLink(value: AppRoute.deadlines) {
                CompanyDestinationCard(
                    title: "Deadlines",
                    detail: deadlineDetail,
                    systemImage: "calendar.badge.clock",
                    tint: overdueDeadlines.isEmpty
                        ? .northBridgeWarning
                        : .northBridgeCritical,
                    badge: openDeadlines.isEmpty
                        ? nil
                        : openDeadlines.count.formatted(),
                    presentation: presentation
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("company.workspace.deadlines")

            NavigationLink(value: AppRoute.activity) {
                CompanyDestinationCard(
                    title: "Aktivitetshistorik",
                    detail: historyDetail,
                    systemImage: "clock.arrow.circlepath",
                    tint: .northBridgeInformational,
                    presentation: presentation
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("company.workspace.activity")
        }
    }

    private func destinationPair(
        leading: CompanyWorkspaceDestination,
        trailing: CompanyWorkspaceDestination
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: NorthBridgeSpacing.md) {
                destinationLink(leading)
                destinationLink(trailing)
            }

            VStack(spacing: NorthBridgeSpacing.md) {
                destinationLink(leading)
                destinationLink(trailing)
            }
        }
    }

    private func destinationLink(
        _ destination: CompanyWorkspaceDestination
    ) -> some View {
        NavigationLink(value: destination.route) {
            CompanyDestinationCard(
                title: destination.title,
                detail: destination.detail,
                systemImage: destination.systemImage,
                tint: destination.tint,
                presentation: presentation
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func workspaceGroup<Content: View>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            NorthBridgeSectionHeader(title, subtitle: subtitle)
            VStack(spacing: NorthBridgeSpacing.md) {
                content()
            }
        }
    }

    private func sourceSummary(_ company: CompanyRecord) -> some View {
        VStack(alignment: .leading, spacing: NorthBridgeSpacing.md) {
            NorthBridgeSectionHeader(
                "Källsammanfattning",
                subtitle: "Detaljerad verifiering finns i bolagsprofilen"
            )

            NavigationLink(value: AppRoute.companyDetails) {
                HStack(alignment: .center, spacing: NorthBridgeSpacing.md) {
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
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                        Text(company.sourceName)
                            .font(.headline)
                            .foregroundStyle(Color.northBridgeTextPrimary)
                        Text(
                            company.sourceUpdatedAt,
                            format: .dateTime.day().month().year().hour().minute()
                        )
                        .font(.caption)
                        .foregroundStyle(Color.northBridgeTextSecondary)
                    }

                    Spacer(minLength: NorthBridgeSpacing.sm)

                    NorthBridgeStatusPill(
                        company.isStale ? "Inaktuell" : "Källmarkerad",
                        kind: company.isStale ? .warning : .positive
                    )
                }
                .padding(cardPadding)
                .northBridgeCardSurface()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öppnar käll- och verifieringsuppgifter")
        }
        .accessibilityIdentifier("company.workspace.source")
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

    private var profile: CompanyProfileRecord? {
        profiles.first { $0.companyID == environment.selectedCompanyID }
    }

    private var companyRegistrations: [CompanyRegistrationRecord] {
        registrations.filter { $0.companyID == environment.selectedCompanyID }
    }

    private var activeBoardMembers: [BoardMemberRecord] {
        boardMembers.filter {
            $0.companyID == environment.selectedCompanyID
                && $0.mandateEndsAt.map { $0 >= .now } != false
        }
    }

    private var activeSignatories: [BoardMemberRecord] {
        activeBoardMembers.filter(\.isSignatory)
    }

    private var companyShareholders: [ShareholderRecord] {
        shareholders.filter {
            $0.companyID == environment.selectedCompanyID
                && $0.archivedAt == nil
        }
    }

    private var companyShareClasses: [ShareClassRecord] {
        shareClasses.filter { $0.companyID == environment.selectedCompanyID }
    }

    private var companyBeneficialOwners: [BeneficialOwnerRecord] {
        beneficialOwners.filter { $0.companyID == environment.selectedCompanyID }
    }

    private var companyActivity: [AuditEventRecord] {
        auditEvents.filter { $0.companyID == environment.selectedCompanyID }
    }

    private var openDeadlines: [DeadlineRecord] {
        deadlines.filter {
            $0.companyID == environment.selectedCompanyID
                && $0.status != .completed
                && $0.status != .dismissed
        }
    }

    private var overdueDeadlines: [DeadlineRecord] {
        openDeadlines.filter { $0.dueAt < .now }
    }

    private var presentation: CompanyWorkspacePresentation {
        CompanyWorkspacePresentation(rawValue: presentationRawValue)
            ?? .comfortable
    }

    private var sectionSpacing: CGFloat {
        presentation == .compact
            ? NorthBridgeSpacing.xl
            : NorthBridgeSpacing.xxl
    }

    private var cardPadding: CGFloat {
        presentation == .compact
            ? NorthBridgeSpacing.md
            : NorthBridgeSpacing.lg
    }

    private var profileChecks: [Bool] {
        guard let company else { return [] }
        return [
            !company.registeredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !company.organisationNumber.isEmpty,
            company.status != .unknown,
            profile.map {
                !$0.companyType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.registeredOffice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } ?? false,
            !companyRegistrations.isEmpty,
            !activeBoardMembers.isEmpty,
            !activeSignatories.isEmpty,
            !companyShareholders.isEmpty && !companyShareClasses.isEmpty,
            !companyBeneficialOwners.isEmpty,
        ]
    }

    private var profileCompleteness: Double {
        guard !profileChecks.isEmpty else { return 0 }
        return Double(profileChecks.filter { $0 }.count)
            / Double(profileChecks.count)
    }

    private var profileCompletenessText: String {
        profileCompleteness.formatted(.percent.precision(.fractionLength(0)))
    }

    private var completenessTint: Color {
        if profileCompleteness >= 0.75 {
            return .northBridgePositive
        }
        if profileCompleteness >= 0.45 {
            return .northBridgeWarning
        }
        return .northBridgeInformational
    }

    private var completenessDetail: String {
        guard let missingIndex = profileChecks.firstIndex(of: false) else {
            return String(localized: "Alla bevakade uppgiftsgrupper har registrerat underlag.")
        }
        let nextSteps = [
            String(localized: "Lägg till bolagets identitetsuppgifter."),
            String(localized: "Granska bolagsstatus och verifieringskälla."),
            String(localized: "Komplettera bolagsform och säte."),
            String(localized: "Lägg till registreringar, till exempel F-skatt."),
            String(localized: "Registrera aktiva styrelsemedlemmar."),
            String(localized: "Registrera vem som tecknar firman."),
            String(localized: "Komplettera ägare och aktieslag."),
            String(localized: "Registrera uppgift om verklig huvudman."),
        ]
        return String(localized: "Nästa uppgift: \(nextSteps[missingIndex])")
    }

    private var identityDetail: String {
        if profile == nil {
            return String(localized: "Bolagsform, säte och registreringsdata behöver kompletteras")
        }
        return companyRegistrations.isEmpty
            ? String(localized: "Profil registrerad · registreringar saknas")
            : String(localized: "\(companyRegistrations.count) registreringar · källmarkerade uppgifter")
    }

    private var governanceDetail: String {
        if activeBoardMembers.isEmpty {
            return String(localized: "Ingen aktiv styrelse är registrerad")
        }
        return activeSignatories.isEmpty
            ? String(localized: "\(activeBoardMembers.count) ledamöter · firmatecknare saknas")
            : String(localized: "\(activeBoardMembers.count) ledamöter · \(activeSignatories.count) firmatecknare")
    }

    private var ownershipDetail: String {
        if companyShareholders.isEmpty {
            return String(localized: "Inga aktiva ägare är registrerade")
        }
        return String(
            localized: "\(companyShareholders.count) ägare · \(companyShareClasses.count) aktieslag"
        )
    }

    private var deadlineDetail: String {
        if !overdueDeadlines.isEmpty {
            return String(localized: "\(overdueDeadlines.count) försenade · kräver åtgärd")
        }
        if let next = openDeadlines.first {
            return String(
                localized: "Nästa: \(next.dueAt.formatted(date: .abbreviated, time: .omitted))"
            )
        }
        return String(localized: "Inga öppna deadlines")
    }

    private var historyDetail: String {
        guard let latest = companyActivity.first else {
            return String(localized: "Öppna bolagets registrerade aktivitet")
        }
        return String(
            localized: "Senast: \(latest.summary) · \(latest.occurredAt.formatted(date: .abbreviated, time: .omitted))"
        )
    }

    private var canAddAnotherCompany: Bool {
        accessibleCompanyCount == 0
            || SubscriptionAccessPolicy().allows(
                .multipleCompanies,
                entitlement: environment.subscriptionManager.entitlement
            )
    }

    private var accessibleCompanyCount: Int {
        guard let accountID = environment.sessionController.activeSession?.accountID else {
            return 0
        }
        let companyIDs = Set(
            memberships
                .filter { $0.accountID == accountID && $0.isActive }
                .map(\.companyID)
        )
        return companies.filter { companyIDs.contains($0.id) }.count
    }

    private func addCompany() {
        if canAddAnotherCompany {
            environment.router(for: .company)
                .navigate(to: .addCompany)
        } else {
            environment.presentSettings(route: .subscription)
        }
    }

    private func freshnessText(_ company: CompanyRecord) -> String {
        if company.isStale {
            return String(localized: "Källan behöver uppdateras")
        }
        return String(
            localized: "\(company.sourceName) · \(company.sourceUpdatedAt.formatted(date: .abbreviated, time: .omitted))"
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

private enum CompanyWorkspacePresentation: String, CaseIterable, Identifiable {
    case comfortable
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comfortable: String(localized: "Luftig")
        case .compact: String(localized: "Kompakt")
        }
    }

    var systemImage: String {
        switch self {
        case .comfortable: "rectangle.grid.1x2"
        case .compact: "list.bullet"
        }
    }
}

private struct CompanyWorkspaceDestination {
    let route: AppRoute
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
}

private struct CompanyDestinationCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    var badge: String? = nil
    let presentation: CompanyWorkspacePresentation

    var body: some View {
        HStack(alignment: .center, spacing: NorthBridgeSpacing.md) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(
                    width: NorthBridgeMetrics.minimumTarget,
                    height: NorthBridgeMetrics.minimumTarget
                )
                .background(tint.opacity(0.1), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: NorthBridgeSpacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.northBridgeTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.northBridgeTextSecondary)
                    .lineLimit(
                        dynamicTypeSize.isAccessibilitySize
                            ? nil
                            : (presentation == .compact ? 1 : 3)
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let badge {
                Text(badge)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, NorthBridgeSpacing.sm)
                    .padding(.vertical, NorthBridgeSpacing.xs)
                    .background(tint.opacity(0.1), in: Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.northBridgeTextTertiary)
                .accessibilityHidden(true)
        }
        .padding(
            presentation == .compact
                ? NorthBridgeSpacing.md
                : NorthBridgeSpacing.lg
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .northBridgeCardSurface()
        .contentShape(
            RoundedRectangle(
                cornerRadius: NorthBridgeRadius.card,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
    }
}

@MainActor
struct CompanyDetailsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query private var companies: [CompanyRecord]

    var body: some View {
        Group {
            if let company {
                List {
                    Section("Grunduppgifter") {
                        LabeledContent("Registrerat namn", value: company.registeredName)
                        LabeledContent(
                            "Organisationsnummer",
                            value: (try? OrganisationNumber(company.organisationNumber).formatted) ?? company.organisationNumber
                        )
                        LabeledContent("Status", value: company.status.localizedName)
                    }

                    Section("Datakvalitet") {
                        LabeledContent("Källa", value: company.sourceName)
                        LabeledContent(
                            "Uppdaterad",
                            value: company.sourceUpdatedAt.formatted(date: .long, time: .shortened)
                        )
                        LabeledContent("Verifiering", value: company.status == .unknown ? "Ej verifierad" : "Källmarkerad")
                    }
                }
            } else {
                EmptyStateView(
                    systemImage: "building.2",
                    title: "Bolaget saknas",
                    message: "Bolaget kan ha tagits bort."
                )
            }
        }
        .navigationTitle("Grunduppgifter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var company: CompanyRecord? {
        companies.first { $0.id == environment.selectedCompanyID }
    }
}
