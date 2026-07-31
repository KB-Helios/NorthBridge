import SwiftData
import SwiftUI

@MainActor
struct CompanyProfileDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query private var companies: [CompanyRecord]
    @Query private var profiles: [CompanyProfileRecord]
    @Query private var registrations: [CompanyRegistrationRecord]
    @Query private var beneficialOwners: [BeneficialOwnerRecord]
    @Query private var industryCodes: [CompanyIndustryCodeRecord]
    @Query(sort: \CompanyHistoryEventRecord.effectiveAt, order: .reverse)
    private var historyEvents: [CompanyHistoryEventRecord]
    @Query private var boardMembers: [BoardMemberRecord]
    @Query private var people: [PersonRecord]
    @Query private var shareClasses: [ShareClassRecord]
    @Query private var documents: [DocumentRecord]

    @State private var presentedEditor: CompanyProfileEditorDestination?

    var body: some View {
        Group {
            if let company {
                List {
                    Section("Grunduppgifter") {
                        LabeledContent("Registrerat namn", value: company.registeredName)
                        LabeledContent(
                            "Organisationsnummer",
                            value: (try? OrganisationNumber(
                                company.organisationNumber
                            ).formatted) ?? company.organisationNumber
                        )
                        LabeledContent("Status", value: company.status.localizedName)
                        LabeledContent(
                            "Bolagsform",
                            value: profile?.companyType.nilIfEmpty ?? "Uppgift saknas"
                        )
                        LabeledContent(
                            "Säte",
                            value: profile?.registeredOffice.nilIfEmpty ?? "Uppgift saknas"
                        )
                        if let incorporationDate = profile?.incorporationDate {
                            LabeledContent(
                                "Registreringsdatum",
                                value: incorporationDate.formatted(
                                    date: .long,
                                    time: .omitted
                                )
                            )
                        }
                    }

                    Section("Registreringar") {
                        if companyRegistrations.isEmpty {
                            missingValue("Inga registreringar har lagts till.")
                        } else {
                            ForEach(companyRegistrations) { registration in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(registration.registrationType)
                                        .font(.body.weight(.semibold))
                                    Text(registration.status)
                                        .font(.subheadline)
                                    SourceFooter(
                                        source: registration.sourceName,
                                        updatedAt: registration.sourceUpdatedAt
                                    )
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Section("Räkenskapsår") {
                        if let profile {
                            LabeledContent(
                                "Period",
                                value: fiscalYearText(profile)
                            )
                            SourceFooter(
                                source: profile.sourceName,
                                updatedAt: profile.sourceUpdatedAt
                            )
                        } else {
                            missingValue("Räkenskapsår saknas.")
                        }
                    }

                    Section("Revisor") {
                        if auditors.isEmpty {
                            missingValue("Ingen aktiv revisor är registrerad.")
                        } else {
                            ForEach(auditors) { member in
                                LabeledContent(
                                    "Revisor",
                                    value: personName(member.personID)
                                )
                            }
                        }
                    }

                    Section("Verklig huvudman") {
                        if companyBeneficialOwners.isEmpty {
                            missingValue("Ingen uppgift om verklig huvudman finns.")
                        } else {
                            ForEach(companyBeneficialOwners) { owner in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(owner.displayName)
                                        .font(.body.weight(.semibold))
                                    Text(owner.controlDescription)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if let range = ownershipRange(owner) {
                                        Text(range)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    SourceFooter(
                                        source: owner.sourceName,
                                        updatedAt: owner.sourceUpdatedAt
                                    )
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Section("Aktiekapital och aktieslag") {
                        if let capital = profile?.shareCapital {
                            LabeledContent(
                                "Aktiekapital",
                                value: capital.formatted(
                                    .currency(
                                        code: profile?.shareCapitalCurrencyCode
                                            ?? "SEK"
                                    )
                                )
                            )
                        } else {
                            missingValue("Aktiekapital saknas.")
                        }
                        if companyShareClasses.isEmpty {
                            missingValue("Inga aktieslag är registrerade.")
                        } else {
                            ForEach(companyShareClasses) { shareClass in
                                LabeledContent {
                                    Text(
                                        "\(shareClass.votesPerShare.formatted()) röster/aktie"
                                    )
                                } label: {
                                    Text(shareClass.name)
                                }
                            }
                        }
                        NavigationLink(value: AppRoute.ownership) {
                            Label("Öppna ägare och aktiebok", systemImage: "chart.pie")
                        }
                    }

                    Section("Bolagsordning") {
                        if articles.isEmpty {
                            missingValue("Ingen bolagsordning finns i dokumentvalvet.")
                        } else {
                            ForEach(articles) { document in
                                NavigationLink(
                                    value: AppRoute.document(document.id)
                                ) {
                                    Label(document.title, systemImage: "doc.text")
                                }
                            }
                        }
                    }

                    Section("SNI-koder") {
                        if companyIndustryCodes.isEmpty {
                            missingValue("Inga SNI-koder är registrerade.")
                        } else {
                            ForEach(companyIndustryCodes) { code in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(code.code)
                                            .font(.body.monospaced().weight(.semibold))
                                        if code.isPrimary {
                                            StatusBadge(
                                                text: "Huvudkod",
                                                kind: .neutral
                                            )
                                        }
                                    }
                                    Text(code.codeDescription)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    SourceFooter(
                                        source: code.sourceName,
                                        updatedAt: code.sourceUpdatedAt
                                    )
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Section("Verksamhetsbeskrivning") {
                        if let description = profile?
                            .businessDescription
                            .nilIfEmpty {
                            Text(description)
                            SourceFooter(
                                source: profile?.sourceName ?? "",
                                updatedAt: profile?.sourceUpdatedAt ?? .distantPast
                            )
                        } else {
                            missingValue("Verksamhetsbeskrivning saknas.")
                        }
                    }

                    Section("Historiska bolagshändelser") {
                        if companyHistory.isEmpty {
                            missingValue("Inga källmarkerade bolagshändelser är registrerade.")
                        } else {
                            ForEach(companyHistory) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(.body.weight(.semibold))
                                    Text(event.effectiveAt, format: .dateTime.day().month().year())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !event.details.isEmpty {
                                        Text(event.details)
                                            .font(.subheadline)
                                    }
                                    SourceFooter(
                                        source: event.sourceName,
                                        updatedAt: event.sourceUpdatedAt
                                    )
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Section("Datakvalitet") {
                        SourceFooter(
                            source: company.sourceName,
                            updatedAt: company.sourceUpdatedAt,
                            stale: company.isStale
                        )
                        Text("Manuella poster är inte verifierade mot Bolagsverket, Skatteverket eller SCB om inte en sådan källa uttryckligen anges.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                EmptyStateView(
                    systemImage: "building.2",
                    title: "Bolaget saknas",
                    message: "Bolaget kan ha tagits bort eller så saknas behörighet."
                )
            }
        }
        .navigationTitle("Bolagsprofil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Redigera profil", systemImage: "pencil") {
                        presentedEditor = .profile
                    }
                    Button("Registrering", systemImage: "checkmark.seal") {
                        presentedEditor = .registration
                    }
                    Button("Verklig huvudman", systemImage: "person.badge.shield.checkmark") {
                        presentedEditor = .beneficialOwner
                    }
                    Button("Aktiekapital", systemImage: "banknote") {
                        presentedEditor = .capital
                    }
                    Button("SNI-kod", systemImage: "number") {
                        presentedEditor = .industryCode
                    }
                    Button("Historisk händelse", systemImage: "clock.arrow.circlepath") {
                        presentedEditor = .history
                    }
                } label: {
                    Label("Uppdatera bolagsprofil", systemImage: "plus")
                }
                .disabled(company == nil)
            }
        }
        .sheet(item: $presentedEditor) { destination in
            switch destination {
            case .profile:
                CompanyProfileEditorView()
            case .registration:
                CompanyRegistrationEditorView()
            case .beneficialOwner:
                BeneficialOwnerEditorView()
            case .capital:
                CompanyCapitalEditorView()
            case .industryCode:
                CompanyIndustryCodeEditorView()
            case .history:
                CompanyHistoryEventEditorView()
            }
        }
    }

    private var company: CompanyRecord? {
        companies.first { $0.id == environment.selectedCompanyID }
    }

    private var profile: CompanyProfileRecord? {
        profiles.first { $0.companyID == environment.selectedCompanyID }
    }

    private var companyRegistrations: [CompanyRegistrationRecord] {
        registrations.filter { $0.companyID == environment.selectedCompanyID }
    }

    private var companyBeneficialOwners: [BeneficialOwnerRecord] {
        beneficialOwners.filter { $0.companyID == environment.selectedCompanyID }
    }

    private var companyIndustryCodes: [CompanyIndustryCodeRecord] {
        industryCodes
            .filter { $0.companyID == environment.selectedCompanyID }
            .sorted {
                if $0.isPrimary != $1.isPrimary {
                    return $0.isPrimary && !$1.isPrimary
                }
                return $0.code < $1.code
            }
    }

    private var companyHistory: [CompanyHistoryEventRecord] {
        historyEvents.filter { $0.companyID == environment.selectedCompanyID }
    }

    private var auditors: [BoardMemberRecord] {
        boardMembers.filter {
            $0.companyID == environment.selectedCompanyID
                && $0.role == .auditor
                && $0.mandateEndsAt.map { $0 >= .now } != false
        }
    }

    private var companyShareClasses: [ShareClassRecord] {
        shareClasses.filter { $0.companyID == environment.selectedCompanyID }
    }

    private var articles: [DocumentRecord] {
        documents.filter {
            $0.companyID == environment.selectedCompanyID
                && $0.category == .articlesOfAssociation
        }
    }

    private func personName(_ personID: UUID) -> String {
        people.first { $0.id == personID }?.fullName
            ?? String(localized: "Okänd person")
    }

    private func fiscalYearText(_ profile: CompanyProfileRecord) -> String {
        String(
            format: "%02d-%02d – %02d-%02d",
            profile.fiscalYearStartDay,
            profile.fiscalYearStartMonth,
            profile.fiscalYearEndDay,
            profile.fiscalYearEndMonth
        )
    }

    private func ownershipRange(_ owner: BeneficialOwnerRecord) -> String? {
        switch (
            owner.ownershipPercentLowerBound,
            owner.ownershipPercentUpperBound
        ) {
        case (let lower?, let upper?):
            "\(lower.formatted())–\(upper.formatted()) %"
        case (let lower?, nil):
            "Minst \(lower.formatted()) %"
        case (nil, let upper?):
            "Högst \(upper.formatted()) %"
        case (nil, nil):
            nil
        }
    }

    private func missingValue(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
    }
}

private enum CompanyProfileEditorDestination: String, Identifiable {
    case profile
    case registration
    case beneficialOwner
    case capital
    case industryCode
    case history

    var id: String { rawValue }
}

@MainActor
private struct CompanyProfileEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [CompanyProfileRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var companyType = "Aktiebolag"
    @State private var registeredOffice = ""
    @State private var hasIncorporationDate = false
    @State private var incorporationDate = Date.now
    @State private var fiscalYearStart = Self.referenceDate(month: 1, day: 1)
    @State private var fiscalYearEnd = Self.referenceDate(month: 12, day: 31)
    @State private var businessDescription = ""
    @State private var sourceName = "Manuellt angivet"
    @State private var sourceURL = ""
    @State private var didLoad = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Bolagsuppgifter") {
                    TextField("Bolagsform", text: $companyType)
                    TextField("Säte", text: $registeredOffice)
                    Toggle("Registreringsdatum känt", isOn: $hasIncorporationDate)
                    if hasIncorporationDate {
                        DatePicker(
                            "Registreringsdatum",
                            selection: $incorporationDate,
                            displayedComponents: .date
                        )
                    }
                }

                Section("Räkenskapsår") {
                    DatePicker(
                        "Startdag",
                        selection: $fiscalYearStart,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "Slutdag",
                        selection: $fiscalYearEnd,
                        displayedComponents: .date
                    )
                    Text("Årtalet ignoreras; endast månad och dag sparas.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Verksamhetsbeskrivning") {
                    TextField(
                        "Beskrivning",
                        text: $businessDescription,
                        axis: .vertical
                    )
                    .lineLimit(3...10)
                }

                sourceSection
                errorSection(errorMessage)
            }
            .navigationTitle("Redigera bolagsprofil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                editorToolbar(save: save, dismiss: dismiss)
            }
            .task { load() }
        }
    }

    private var sourceSection: some View {
        Section("Källa") {
            TextField("Källnamn", text: $sourceName)
            TextField("Käll-URL (valfri)", text: $sourceURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let profile else { return }
        companyType = profile.companyType
        registeredOffice = profile.registeredOffice
        if let date = profile.incorporationDate {
            hasIncorporationDate = true
            incorporationDate = date
        }
        fiscalYearStart = Self.referenceDate(
            month: profile.fiscalYearStartMonth,
            day: profile.fiscalYearStartDay
        )
        fiscalYearEnd = Self.referenceDate(
            month: profile.fiscalYearEndMonth,
            day: profile.fiscalYearEndDay
        )
        businessDescription = profile.businessDescription
        sourceName = profile.sourceName
        sourceURL = profile.sourceURL ?? ""
    }

    private var profile: CompanyProfileRecord? {
        profiles.first { $0.companyID == environment.selectedCompanyID }
    }

    private func save() {
        guard let access = editorAccess(
            environment: environment,
            memberships: memberships,
            permission: .editCompany
        ) else {
            errorMessage = String(localized: "Din roll saknar behörighet att redigera bolagsprofilen.")
            return
        }
        guard !companyType.trimmed.isEmpty,
              !registeredOffice.trimmed.isEmpty,
              !sourceName.trimmed.isEmpty else {
            errorMessage = String(localized: "Fyll i bolagsform, säte och källa.")
            return
        }
        guard sourceURL.isBlankOrValidHTTPSURL else {
            errorMessage = String(localized: "Käll-URL måste börja med https://.")
            return
        }
        let start = Calendar.current.dateComponents(
            [.month, .day],
            from: fiscalYearStart
        )
        let end = Calendar.current.dateComponents(
            [.month, .day],
            from: fiscalYearEnd
        )
        let target = profile ?? CompanyProfileRecord(
            companyID: access.companyID,
            sourceName: sourceName.trimmed
        )
        if profile == nil {
            modelContext.insert(target)
        }
        target.companyType = companyType.trimmed
        target.registeredOffice = registeredOffice.trimmed
        target.incorporationDate = hasIncorporationDate
            ? incorporationDate
            : nil
        target.fiscalYearStartMonth = start.month ?? 1
        target.fiscalYearStartDay = start.day ?? 1
        target.fiscalYearEndMonth = end.month ?? 12
        target.fiscalYearEndDay = end.day ?? 31
        target.businessDescription = businessDescription.trimmed
        target.sourceName = sourceName.trimmed
        target.sourceURL = sourceURL.validURLString
        target.sourceUpdatedAt = .now
        target.updatedAt = .now
        saveWithAudit(
            action: "companyProfile.updated",
            entityID: target.id,
            summary: String(localized: "Bolagsprofilen uppdaterades."),
            access: access,
            context: modelContext,
            dismiss: dismiss,
            errorMessage: $errorMessage
        )
    }

    private static func referenceDate(month: Int, day: Int) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2024, month: month, day: day)
        ) ?? .now
    }
}

@MainActor
private struct CompanyRegistrationEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var memberships: [CompanyMembershipRecord]
    @State private var registrationType = ""
    @State private var status = ""
    @State private var sourceName = ""
    @State private var sourceURL = ""
    @State private var errorMessage: String?

    var body: some View {
        editorForm(
            title: "Lägg till registrering",
            errorMessage: errorMessage,
            save: save,
            dismiss: dismiss
        ) {
            Section("Registrering") {
                TextField("Typ, till exempel F-skatt", text: $registrationType)
                TextField("Status", text: $status)
            }
            sourceFields(name: $sourceName, url: $sourceURL)
        }
    }

    private func save() {
        guard let access = editorAccess(
            environment: environment,
            memberships: memberships,
            permission: .editCompany
        ) else {
            errorMessage = String(localized: "Din roll saknar behörighet.")
            return
        }
        guard !registrationType.trimmed.isEmpty,
              !status.trimmed.isEmpty,
              !sourceName.trimmed.isEmpty else {
            errorMessage = String(localized: "Fyll i typ, status och källa.")
            return
        }
        guard sourceURL.isBlankOrValidHTTPSURL else {
            errorMessage = String(localized: "Käll-URL måste börja med https://.")
            return
        }
        let value = CompanyRegistrationRecord(
            companyID: access.companyID,
            registrationType: registrationType.trimmed,
            status: status.trimmed,
            sourceName: sourceName.trimmed,
            sourceURL: sourceURL.validURLString,
            sourceUpdatedAt: .now
        )
        modelContext.insert(value)
        saveWithAudit(
            action: "companyRegistration.created",
            entityID: value.id,
            summary: String(localized: "Registrering lades till: \(value.registrationType)"),
            access: access,
            context: modelContext,
            dismiss: dismiss,
            errorMessage: $errorMessage
        )
    }
}

@MainActor
private struct BeneficialOwnerEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var memberships: [CompanyMembershipRecord]
    @State private var displayName = ""
    @State private var identityReference = ""
    @State private var controlDescription = ""
    @State private var lowerPercent: Double?
    @State private var upperPercent: Double?
    @State private var sourceName = ""
    @State private var sourceURL = ""
    @State private var errorMessage: String?

    var body: some View {
        editorForm(
            title: "Verklig huvudman",
            errorMessage: errorMessage,
            save: save,
            dismiss: dismiss
        ) {
            Section("Person och kontroll") {
                TextField("Namn", text: $displayName)
                TextField("Identitetsreferens (valfri)", text: $identityReference)
                TextField(
                    "Beskriv kontrollen",
                    text: $controlDescription,
                    axis: .vertical
                )
                TextField(
                    "Ägarandel från procent",
                    value: $lowerPercent,
                    format: .number
                )
                .keyboardType(.decimalPad)
                TextField(
                    "Ägarandel till procent",
                    value: $upperPercent,
                    format: .number
                )
                .keyboardType(.decimalPad)
            }
            sourceFields(name: $sourceName, url: $sourceURL)
        }
    }

    private func save() {
        guard let access = editorAccess(
            environment: environment,
            memberships: memberships,
            permission: .manageOwnership
        ) else {
            errorMessage = String(localized: "Din roll saknar behörighet till ägaruppgifter.")
            return
        }
        guard !displayName.trimmed.isEmpty,
              !controlDescription.trimmed.isEmpty,
              !sourceName.trimmed.isEmpty else {
            errorMessage = String(localized: "Fyll i namn, kontrollbeskrivning och källa.")
            return
        }
        guard sourceURL.isBlankOrValidHTTPSURL else {
            errorMessage = String(localized: "Käll-URL måste börja med https://.")
            return
        }
        guard percentRangeIsValid(
            lowerBound: lowerPercent,
            upperBound: upperPercent
        ) else {
            errorMessage = String(localized: "Kontrollera procentintervallet.")
            return
        }
        let value = BeneficialOwnerRecord(
            companyID: access.companyID,
            displayName: displayName.trimmed,
            identityReference: identityReference.nilIfEmpty,
            controlDescription: controlDescription.trimmed,
            ownershipPercentLowerBound: lowerPercent,
            ownershipPercentUpperBound: upperPercent,
            sourceName: sourceName.trimmed,
            sourceURL: sourceURL.validURLString
        )
        modelContext.insert(value)
        saveWithAudit(
            action: "beneficialOwner.created",
            entityID: value.id,
            summary: String(localized: "Uppgift om verklig huvudman lades till."),
            access: access,
            context: modelContext,
            dismiss: dismiss,
            errorMessage: $errorMessage
        )
    }
}

@MainActor
private struct CompanyCapitalEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [CompanyProfileRecord]
    @Query private var memberships: [CompanyMembershipRecord]
    @State private var amount = 25_000.0
    @State private var currencyCode = "SEK"
    @State private var sourceName = ""
    @State private var sourceURL = ""
    @State private var didLoad = false
    @State private var errorMessage: String?

    var body: some View {
        editorForm(
            title: "Aktiekapital",
            errorMessage: errorMessage,
            save: save,
            dismiss: dismiss
        ) {
            Section("Kapital") {
                TextField("Belopp", value: $amount, format: .number)
                    .keyboardType(.decimalPad)
                Picker("Valuta", selection: $currencyCode) {
                    Text("SEK").tag("SEK")
                    Text("EUR").tag("EUR")
                }
            }
            sourceFields(name: $sourceName, url: $sourceURL)
        }
        .task { load() }
    }

    private var profile: CompanyProfileRecord? {
        profiles.first { $0.companyID == environment.selectedCompanyID }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let profile {
            amount = profile.shareCapital ?? amount
            currencyCode = profile.shareCapitalCurrencyCode
            sourceName = profile.sourceName
            sourceURL = profile.sourceURL ?? ""
        }
    }

    private func save() {
        guard let access = editorAccess(
            environment: environment,
            memberships: memberships,
            permission: .manageOwnership
        ) else {
            errorMessage = String(localized: "Din roll saknar behörighet till aktiekapital.")
            return
        }
        guard amount >= 0, amount.isFinite, !sourceName.trimmed.isEmpty else {
            errorMessage = String(localized: "Kontrollera belopp och källa.")
            return
        }
        guard sourceURL.isBlankOrValidHTTPSURL else {
            errorMessage = String(localized: "Käll-URL måste börja med https://.")
            return
        }
        let target = profile ?? CompanyProfileRecord(
            companyID: access.companyID,
            sourceName: sourceName.trimmed
        )
        if profile == nil {
            modelContext.insert(target)
        }
        target.shareCapital = amount
        target.shareCapitalCurrencyCode = currencyCode
        target.sourceName = sourceName.trimmed
        target.sourceURL = sourceURL.validURLString
        target.sourceUpdatedAt = .now
        target.updatedAt = .now
        modelContext.insert(
            CompanyHistoryEventRecord(
                companyID: access.companyID,
                title: String(localized: "Aktiekapital registrerades"),
                details: amount.formatted(.currency(code: currencyCode)),
                effectiveAt: .now,
                sourceName: sourceName.trimmed,
                sourceURL: sourceURL.validURLString
            )
        )
        saveWithAudit(
            action: "companyCapital.updated",
            entityID: target.id,
            summary: String(localized: "Aktiekapitalet uppdaterades."),
            access: access,
            context: modelContext,
            dismiss: dismiss,
            errorMessage: $errorMessage
        )
    }
}

@MainActor
private struct CompanyIndustryCodeEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var memberships: [CompanyMembershipRecord]
    @State private var code = ""
    @State private var codeDescription = ""
    @State private var isPrimary = false
    @State private var sourceName = ""
    @State private var sourceURL = ""
    @State private var errorMessage: String?

    var body: some View {
        editorForm(
            title: "Lägg till SNI-kod",
            errorMessage: errorMessage,
            save: save,
            dismiss: dismiss
        ) {
            Section("SNI") {
                TextField("Kod", text: $code)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Beskrivning", text: $codeDescription)
                Toggle("Huvudkod", isOn: $isPrimary)
            }
            sourceFields(name: $sourceName, url: $sourceURL)
        }
    }

    private func save() {
        guard let access = editorAccess(
            environment: environment,
            memberships: memberships,
            permission: .editCompany
        ) else {
            errorMessage = String(localized: "Din roll saknar behörighet.")
            return
        }
        guard !code.trimmed.isEmpty,
              !codeDescription.trimmed.isEmpty,
              !sourceName.trimmed.isEmpty else {
            errorMessage = String(localized: "Fyll i kod, beskrivning och källa.")
            return
        }
        guard sourceURL.isBlankOrValidHTTPSURL else {
            errorMessage = String(localized: "Käll-URL måste börja med https://.")
            return
        }
        let value = CompanyIndustryCodeRecord(
            companyID: access.companyID,
            code: code.trimmed,
            codeDescription: codeDescription.trimmed,
            isPrimary: isPrimary,
            sourceName: sourceName.trimmed,
            sourceURL: sourceURL.validURLString
        )
        modelContext.insert(value)
        saveWithAudit(
            action: "companyIndustryCode.created",
            entityID: value.id,
            summary: String(localized: "SNI-kod lades till: \(value.code)"),
            access: access,
            context: modelContext,
            dismiss: dismiss,
            errorMessage: $errorMessage
        )
    }
}

@MainActor
private struct CompanyHistoryEventEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var memberships: [CompanyMembershipRecord]
    @State private var title = ""
    @State private var details = ""
    @State private var effectiveAt = Date.now
    @State private var sourceName = ""
    @State private var sourceURL = ""
    @State private var errorMessage: String?

    var body: some View {
        editorForm(
            title: "Historisk bolagshändelse",
            errorMessage: errorMessage,
            save: save,
            dismiss: dismiss
        ) {
            Section("Händelse") {
                TextField("Rubrik", text: $title)
                TextField("Beskrivning", text: $details, axis: .vertical)
                    .lineLimit(2...8)
                DatePicker(
                    "Gäller från",
                    selection: $effectiveAt,
                    displayedComponents: .date
                )
            }
            sourceFields(name: $sourceName, url: $sourceURL)
        }
    }

    private func save() {
        guard let access = editorAccess(
            environment: environment,
            memberships: memberships,
            permission: .editCompany
        ) else {
            errorMessage = String(localized: "Din roll saknar behörighet.")
            return
        }
        guard !title.trimmed.isEmpty, !sourceName.trimmed.isEmpty else {
            errorMessage = String(localized: "Fyll i rubrik och källa.")
            return
        }
        guard sourceURL.isBlankOrValidHTTPSURL else {
            errorMessage = String(localized: "Käll-URL måste börja med https://.")
            return
        }
        let value = CompanyHistoryEventRecord(
            companyID: access.companyID,
            title: title.trimmed,
            details: details.trimmed,
            effectiveAt: effectiveAt,
            sourceName: sourceName.trimmed,
            sourceURL: sourceURL.validURLString
        )
        modelContext.insert(value)
        saveWithAudit(
            action: "companyHistoryEvent.created",
            entityID: value.id,
            summary: String(localized: "Historisk bolagshändelse lades till: \(value.title)"),
            access: access,
            context: modelContext,
            dismiss: dismiss,
            errorMessage: $errorMessage
        )
    }
}

private struct CompanyEditorAccess {
    let companyID: UUID
    let accountID: UUID
}

@MainActor
private func editorAccess(
    environment: AppEnvironment,
    memberships: [CompanyMembershipRecord],
    permission: CompanyPermission
) -> CompanyEditorAccess? {
    guard let companyID = environment.selectedCompanyID,
          let accountID = environment.sessionController.activeSession?.accountID,
          let role = ActiveCompanyAccess.role(
            companyID: companyID,
            accountID: accountID,
            memberships: memberships
          ),
          environment.permissionPolicy.allows(permission, for: role) else {
        return nil
    }
    return CompanyEditorAccess(
        companyID: companyID,
        accountID: accountID
    )
}

@MainActor
private func saveWithAudit(
    action: String,
    entityID: UUID,
    summary: String,
    access: CompanyEditorAccess,
    context: ModelContext,
    dismiss: DismissAction,
    errorMessage: Binding<String?>
) {
    context.insert(
        AuditEventRecord(
            companyID: access.companyID,
            accountID: access.accountID,
            action: action,
            entityType: "companyProfile",
            entityID: entityID,
            summary: summary
        )
    )
    do {
        try context.save()
        dismiss()
    } catch {
        context.rollback()
        errorMessage.wrappedValue = String(
            localized: "Bolagsuppgiften kunde inte sparas."
        )
    }
}

@MainActor
private func editorForm<Content: View>(
    title: LocalizedStringKey,
    errorMessage: String?,
    save: @escaping @MainActor () -> Void,
    dismiss: DismissAction,
    @ViewBuilder content: () -> Content
) -> some View {
    NavigationStack {
        Form {
            content()
            errorSection(errorMessage)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            editorToolbar(save: save, dismiss: dismiss)
        }
    }
}

@ToolbarContentBuilder
@MainActor
private func editorToolbar(
    save: @escaping @MainActor () -> Void,
    dismiss: DismissAction
) -> some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
        Button("Avbryt") { dismiss() }
    }
    ToolbarItem(placement: .confirmationAction) {
        Button("Spara") { save() }
    }
}

@ViewBuilder
private func sourceFields(
    name: Binding<String>,
    url: Binding<String>
) -> some View {
    Section("Källa") {
        TextField("Källnamn", text: name)
        TextField("Käll-URL (valfri)", text: url)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
    }
}

@ViewBuilder
private func errorSection(_ message: String?) -> some View {
    if let message {
        Section {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }

    var validURLString: String? {
        guard let value = nilIfEmpty,
              let url = URL(string: value),
              url.scheme == "https" else {
            return nil
        }
        return value
    }

    var isBlankOrValidHTTPSURL: Bool {
        nilIfEmpty == nil || validURLString != nil
    }
}

private func percentRangeIsValid(
    lowerBound: Double?,
    upperBound: Double?
) -> Bool {
    let validRange = 0.0...100.0
    guard lowerBound.map(validRange.contains) != false,
          upperBound.map(validRange.contains) != false else {
        return false
    }
    guard let lowerBound, let upperBound else {
        return true
    }
    return lowerBound <= upperBound
}
