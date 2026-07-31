import SwiftData
import SwiftUI
import UIKit

@MainActor
struct OnboardingFlowView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .welcome
    @State private var displayName = ""
    @State private var email = ""
    @State private var organisationNumber = ""
    @State private var registeredName = ""
    @State private var didConfirmCompanyDetails = false
    @State private var role: CompanyRole = .owner
    @State private var responsibilities: Set<CompanyResponsibilityCategory> = [
        .deadlines,
        .documents,
    ]
    @State private var enableDeviceLock = true
    @State private var didVerifyDeviceLock = false
    @State private var enableNotifications = false
    @State private var notificationAuthorization: NotificationAuthorizationState = .unknown
    @State private var selectedNotificationCategories: Set<NotificationCategory> = [
        .deadlines,
        .approvals,
        .assignedActions,
        .integrations,
    ]
    @State private var notificationLeadTimeDays = 7
    @State private var requestedIntegrationIDs: Set<String> = []
    @State private var inviteDisplayName = ""
    @State private var inviteEmail = ""
    @State private var inviteRole: CompanyRole = .readOnlyAdvisor
    @State private var inviteResponsibilities = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private enum Step: Int, CaseIterable {
        case welcome
        case account
        case company
        case verification
        case role
        case responsibilities
        case security
        case notifications
        case integrations
        case invitation

        var progress: Double {
            Double(rawValue + 1) / Double(Self.allCases.count)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: step.progress)
                    .tint(.bolagscenterBlue)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .accessibilityLabel("Steg \(step.rawValue + 1) av \(Step.allCases.count)")

                Group {
                    switch step {
                    case .welcome:
                        welcome
                    case .account:
                        accountForm
                    case .company:
                        companyForm
                    case .verification:
                        verificationForm
                    case .role:
                        roleForm
                    case .responsibilities:
                        responsibilitiesForm
                    case .security:
                        securityForm
                    case .notifications:
                        notificationsForm
                    case .integrations:
                        integrationsForm
                    case .invitation:
                        invitationForm
                    }
                }
                .frame(maxWidth: 620, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
            }
            .background(Color.appBackground)
            .navigationTitle("NorthBridge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .welcome {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Tillbaka", systemImage: "chevron.left") {
                            moveBack()
                        }
                        .disabled(isWorking)
                    }
                }
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer()
            NorthBridgeBrandLockup()

            VStack(spacing: 12) {
                Text("Ditt bolag, samlat och begripligt")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Skapa en säker arbetsyta. Du ser alltid källa, tidpunkt och synkroniseringsstatus för externa uppgifter.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Button("Kom igång") {
                advance(to: .account)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("onboarding.start")
        }
        .padding(28)
    }

    private var accountForm: some View {
        Form {
            Section {
                TextField("Namn", text: $displayName)
                    .textContentType(.name)
                    .accessibilityIdentifier("onboarding.name")
                TextField("E-postadress", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("onboarding.email")
            } header: {
                Text("Konto")
            } footer: {
                Text("Kontot lagras säkert på enheten. Befintliga lokala konton loggar du in på från välkomstskärmen.")
            }

            continueSection(
                title: "Fortsätt",
                enabled: accountIsValid,
                identifier: "onboarding.account.continue"
            ) {
                advance(to: .company)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var companyForm: some View {
        Form {
            Section {
                TextField("Organisationsnummer", text: $organisationNumber)
                    .keyboardType(.numberPad)
                    .textContentType(.none)
                    .accessibilityIdentifier("onboarding.organisationNumber")
                TextField("Registrerat namn", text: $registeredName)
                    .textContentType(.organizationName)
                    .accessibilityIdentifier("onboarding.companyName")
            } header: {
                Text("Lägg till bolag")
            } footer: {
                Text("Uppgifterna registreras manuellt och markeras som ej verifierade tills en behörig officiell datakälla har anslutits.")
            }

            if let organisationNumberError {
                errorSection(organisationNumberError, warning: true)
            }

            continueSection(
                title: "Kontrollera uppgifter",
                enabled: companyIsValid,
                identifier: "onboarding.company.continue"
            ) {
                didConfirmCompanyDetails = false
                advance(to: .verification)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var verificationForm: some View {
        Form {
            Section("Kontrollera bolaget") {
                LabeledContent("Registrerat namn", value: registeredName.trimmed)
                LabeledContent(
                    "Organisationsnummer",
                    value: parsedOrganisationNumber?.formatted ?? organisationNumber
                )
                LabeledContent {
                    StatusBadge(text: "Ej officiellt verifierat", kind: .warning)
                } label: {
                    Text("Datastatus")
                }
                LabeledContent("Källa", value: "Manuellt angivet")
                LabeledContent(
                    "Kontrollerad",
                    value: Date.now.formatted(date: .long, time: .shortened)
                )
            }

            Section {
                Toggle(
                    "Jag har kontrollerat att namn och organisationsnummer stämmer",
                    isOn: $didConfirmCompanyDetails
                )
                .accessibilityIdentifier("onboarding.company.confirm")
            } footer: {
                Text("Din bekräftelse ersätter inte data från Bolagsverket och innebär inte att bolaget är juridiskt kontrollerat.")
            }

            Section {
                Button("Redigera bolagsuppgifter", systemImage: "pencil") {
                    advance(to: .company)
                }
                Button("Fortsätt") {
                    advance(to: .role)
                }
                .disabled(!didConfirmCompanyDetails)
                .accessibilityIdentifier("onboarding.verification.continue")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var roleForm: some View {
        Form {
            Section {
                Picker("Din roll", selection: $role) {
                    ForEach(CompanyRole.allCases) { role in
                        Text(role.localizedName).tag(role)
                    }
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("onboarding.role")
            } header: {
                Text("Roll och behörighet")
            } footer: {
                Text(roleExplanation)
            }

            continueSection(
                title: "Fortsätt",
                identifier: "onboarding.role.continue"
            ) {
                if responsibilities.isEmpty {
                    responsibilities = recommendedResponsibilities(for: role)
                }
                advance(to: .responsibilities)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var responsibilitiesForm: some View {
        Form {
            Section {
                ForEach(CompanyResponsibilityCategory.allCases) { category in
                    Toggle(isOn: responsibilityBinding(category)) {
                        Label(category.localizedName, systemImage: category.systemImage)
                    }
                }
            } header: {
                Text("Dina ansvarsområden")
            } footer: {
                Text("Valen används för att prioritera översikt och notiser. De utökar aldrig behörigheten för din roll.")
            }

            continueSection(
                title: "Fortsätt",
                enabled: !responsibilities.isEmpty,
                identifier: "onboarding.responsibilities.continue"
            ) {
                advance(to: .security)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var securityForm: some View {
        Form {
            Section {
                Toggle(isOn: deviceLockBinding) {
                    Label("Skydda med Face ID eller enhetskod", systemImage: "faceid")
                }
                .accessibilityIdentifier("onboarding.deviceLock")
            } header: {
                Text("Säkerhet")
            } footer: {
                Text("Om skyddet aktiveras verifierar NorthBridge enhetens ägare nu och låser automatiskt när appen lämnar förgrunden.")
            }

            if didVerifyDeviceLock {
                Section {
                    Label("Enhetsskydd verifierat", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                }
            }
            onboardingErrorSection

            continueSection(
                title: enableDeviceLock ? "Verifiera och fortsätt" : "Fortsätt utan applås",
                enabled: !isWorking,
                identifier: "onboarding.security.continue"
            ) {
                Task { await continueFromSecurity() }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var notificationsForm: some View {
        Form {
            Section {
                Toggle("Aktivera notiser", isOn: $enableNotifications)
                    .accessibilityIdentifier("onboarding.notifications.enabled")
                if enableNotifications {
                    Stepper(
                        "Standardförvarning: \(notificationLeadTimeDays) dagar",
                        value: $notificationLeadTimeDays,
                        in: 0...60
                    )
                }
            } header: {
                Text("Notiser")
            } footer: {
                Text("Känsliga detaljer döljs alltid från början. Systembehörighet begärs först när du fortsätter.")
            }

            if enableNotifications {
                Section("Kategorier") {
                    ForEach(NotificationCategory.allCases) { category in
                        Toggle(
                            category.localizedName,
                            isOn: notificationCategoryBinding(category)
                        )
                    }
                }
            }

            if notificationAuthorization == .denied,
               let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Section {
                    Label(
                        "Notiser nekades. Du kan fortsätta utan notiser eller ändra i Inställningar.",
                        systemImage: "bell.slash.fill"
                    )
                    .foregroundStyle(.orange)
                    Link("Öppna systeminställningar", destination: settingsURL)
                }
            }
            onboardingErrorSection

            continueSection(
                title: notificationContinueTitle,
                enabled: !isWorking,
                identifier: "onboarding.notifications.continue"
            ) {
                Task { await continueFromNotifications() }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var integrationsForm: some View {
        Form {
            Section {
                ForEach(OnboardingIntegrationOption.options) { option in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: integrationBinding(option.id)) {
                            Label(option.name, systemImage: option.systemImage)
                        }
                        Text(option.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let informationURL = option.informationURL {
                            Link(
                                "Öppna officiell information",
                                destination: informationURL
                            )
                            .font(.caption.weight(.semibold))
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Förbered integrationer")
            } footer: {
                Text("Valen skapar en lokal installationspost med statusen Inte ansluten. Ingen inloggning, överföring eller myndighetsåtgärd utförs i det här steget.")
            }

            Section {
                LabeledContent(
                    "NorthBridge API",
                    value: AppConfiguration.backend() == nil
                        ? "Inte konfigurerat"
                        : "Konfigurerat"
                )
            }

            continueSection(
                title: "Fortsätt",
                identifier: "onboarding.integrations.continue"
            ) {
                advance(to: .invitation)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var invitationForm: some View {
        Form {
            if canInviteUsers {
                Section {
                    TextField("Namn (valfritt)", text: $inviteDisplayName)
                        .textContentType(.name)
                    TextField("E-postadress (valfritt)", text: $inviteEmail)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("onboarding.invitation.email")
                    Picker("Roll", selection: $inviteRole) {
                        ForEach(CompanyRole.allCases) { role in
                            Text(role.localizedName).tag(role)
                        }
                    }
                    TextField(
                        "Ansvarsområden",
                        text: $inviteResponsibilities,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                } header: {
                    Text("Bjud in en behörig användare")
                } footer: {
                    Text("Inbjudan sparas som ett lokalt utkast. Den ger inte åtkomst och skickas inte förrän en säker backend är konfigurerad.")
                }
            } else {
                Section {
                    Label(
                        "Rollen \(role.localizedName) får inte hantera användare. En ägare eller administratör kan skapa inbjudningar senare.",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                }
            }

            onboardingErrorSection

            Section {
                Button {
                    Task { await completeOnboarding() }
                } label: {
                    if isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(inviteEmail.trimmed.isEmpty ? "Skapa arbetsyta" : "Spara utkast och skapa arbetsyta")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isWorking)
                .accessibilityIdentifier("onboarding.complete")
            } footer: {
                Text("Du kan ändra alla val i Mer efter att arbetsytan har skapats.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func continueSection(
        title: LocalizedStringKey,
        enabled: Bool = true,
        identifier: String,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Section {
            Button(title) {
                action()
            }
            .disabled(!enabled)
            .accessibilityIdentifier(identifier)
        }
    }

    @ViewBuilder
    private func errorSection(
        _ message: String,
        warning: Bool = false
    ) -> some View {
        Section {
            Label(
                message,
                systemImage: warning
                    ? "exclamationmark.triangle.fill"
                    : "exclamationmark.circle.fill"
            )
            .foregroundStyle(warning ? Color.orange : Color.red)
        }
    }

    @ViewBuilder
    private var onboardingErrorSection: some View {
        if let errorMessage {
            errorSection(errorMessage)
        }
    }

    private var accountIsValid: Bool {
        !displayName.trimmed.isEmpty
            && email.normalizedEmail.isPlausibleEmail
    }

    private var parsedOrganisationNumber: OrganisationNumber? {
        try? OrganisationNumber(organisationNumber)
    }

    private var organisationNumberError: String? {
        guard !organisationNumber.isEmpty else { return nil }
        do {
            _ = try OrganisationNumber(organisationNumber)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private var companyIsValid: Bool {
        parsedOrganisationNumber != nil && !registeredName.trimmed.isEmpty
    }

    private var canInviteUsers: Bool {
        environment.permissionPolicy.allows(.manageUsers, for: role)
    }

    private var notificationContinueTitle: LocalizedStringKey {
        if notificationAuthorization == .denied {
            "Fortsätt utan notiser"
        } else if enableNotifications {
            "Aktivera och fortsätt"
        } else {
            "Fortsätt utan notiser"
        }
    }

    private var roleExplanation: String {
        switch role {
        case .owner, .administrator:
            String(localized: "Kan administrera bolag, användare, styrelse, ägande, dokument, deadlines och ekonomi.")
        case .boardMember:
            String(localized: "Kan arbeta med styrelse, dokument och deadlines men inte ändra ägande eller användare.")
        case .chiefExecutive:
            String(localized: "Kan hantera bolagsuppgifter, styrelse, dokument, deadlines och ekonomi.")
        case .accountingConsultant:
            String(localized: "Kan arbeta med ekonomi, dokument och deadlines.")
        case .auditor:
            String(localized: "Har läs- och exportåtkomst till bolag, dokument och ekonomi.")
        case .readOnlyAdvisor:
            String(localized: "Har läs- och exportåtkomst utan rätt att ändra bolagsdata.")
        }
    }

    private var deviceLockBinding: Binding<Bool> {
        Binding(
            get: { enableDeviceLock },
            set: { value in
                enableDeviceLock = value
                didVerifyDeviceLock = false
                errorMessage = nil
            }
        )
    }

    private func responsibilityBinding(
        _ category: CompanyResponsibilityCategory
    ) -> Binding<Bool> {
        Binding(
            get: { responsibilities.contains(category) },
            set: { selected in
                if selected {
                    responsibilities.insert(category)
                } else {
                    responsibilities.remove(category)
                }
            }
        )
    }

    private func notificationCategoryBinding(
        _ category: NotificationCategory
    ) -> Binding<Bool> {
        Binding(
            get: { selectedNotificationCategories.contains(category) },
            set: { selected in
                if selected {
                    selectedNotificationCategories.insert(category)
                } else {
                    selectedNotificationCategories.remove(category)
                }
            }
        )
    }

    private func integrationBinding(_ identifier: String) -> Binding<Bool> {
        Binding(
            get: { requestedIntegrationIDs.contains(identifier) },
            set: { selected in
                if selected {
                    requestedIntegrationIDs.insert(identifier)
                } else {
                    requestedIntegrationIDs.remove(identifier)
                }
            }
        )
    }

    private func recommendedResponsibilities(
        for role: CompanyRole
    ) -> Set<CompanyResponsibilityCategory> {
        switch role {
        case .owner, .administrator:
            Set(CompanyResponsibilityCategory.allCases)
        case .boardMember:
            [.board, .deadlines, .documents]
        case .chiefExecutive:
            [.deadlines, .board, .finance, .documents, .integrations]
        case .accountingConsultant:
            [.finance, .deadlines, .documents]
        case .auditor:
            [.finance, .documents]
        case .readOnlyAdvisor:
            [.documents]
        }
    }

    private func advance(to nextStep: Step) {
        errorMessage = nil
        withAnimation(reduceMotion ? nil : .snappy) {
            step = nextStep
        }
    }

    private func moveBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        advance(to: previous)
    }

    private func continueFromSecurity() async {
        guard !isWorking else { return }
        errorMessage = nil
        if enableDeviceLock && !didVerifyDeviceLock {
            isWorking = true
            defer { isWorking = false }
            do {
                try await environment.sessionController.confirmIdentity(
                    reason: String(localized: "Aktivera säkert applås för NorthBridge")
                )
                didVerifyDeviceLock = true
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        advance(to: .notifications)
    }

    private func continueFromNotifications() async {
        guard !isWorking else { return }
        errorMessage = nil
        guard enableNotifications else {
            advance(to: .integrations)
            return
        }
        if notificationAuthorization == .denied {
            enableNotifications = false
            advance(to: .integrations)
            return
        }

        isWorking = true
        defer { isWorking = false }
        do {
            notificationAuthorization = try await environment
                .notificationScheduler
                .requestAuthorization()
            if notificationAuthorization == .denied {
                errorMessage = String(localized: "Notiser är inte tillåtna. Du kan fortsätta utan notiser.")
            } else {
                UIApplication.shared.registerForRemoteNotifications()
                advance(to: .integrations)
            }
        } catch {
            errorMessage = String(localized: "Notisbehörigheten kunde inte begäras. Försök igen eller fortsätt utan notiser.")
        }
    }

    private func completeOnboarding() async {
        guard accountIsValid,
              companyIsValid,
              didConfirmCompanyDetails,
              let number = parsedOrganisationNumber,
              !responsibilities.isEmpty else {
            errorMessage = String(localized: "Kontrollera uppgifterna och försök igen.")
            return
        }
        guard !enableDeviceLock || didVerifyDeviceLock else {
            errorMessage = String(localized: "Enhetsskyddet måste verifieras innan det aktiveras.")
            advance(to: .security)
            return
        }

        let normalizedInviteEmail = inviteEmail.normalizedEmail
        if canInviteUsers && !normalizedInviteEmail.isEmpty {
            guard normalizedInviteEmail.isPlausibleEmail else {
                errorMessage = String(localized: "Kontrollera e-postadressen för inbjudan.")
                return
            }
            do {
                try MembershipPolicy().validateInvitation(
                    email: normalizedInviteEmail,
                    pendingEmails: []
                )
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let account = UserAccountRecord(
            email: email.normalizedEmail,
            displayName: displayName.trimmed
        )
        let company = CompanyRecord(
            organisationNumber: number.digits,
            registeredName: registeredName.trimmed,
            status: .unknown,
            sourceName: String(localized: "Manuellt angivet"),
            sourceUpdatedAt: .now
        )
        let membership = CompanyMembershipRecord(
            accountID: account.id,
            companyID: company.id,
            role: role
        )

        modelContext.insert(account)
        modelContext.insert(company)
        modelContext.insert(membership)
        insertOnboardingRecords(account: account, company: company)

        do {
            try modelContext.save()
            try await environment.sessionController.createLocalSession(
                accountID: account.id
            )
            environment.selectedCompanyID = company.id
            if enableDeviceLock {
                environment.lockController.enableAfterVerifiedSetup()
            } else {
                environment.lockController.disable()
            }
        } catch {
            modelContext.rollback()
            SecureLogger.security.error(
                "Onboarding failed: \(error.localizedDescription, privacy: .private(mask: .hash))"
            )
            errorMessage = String(localized: "Arbetsytan kunde inte sparas säkert. Försök igen.")
        }
    }

    private func insertOnboardingRecords(
        account: UserAccountRecord,
        company: CompanyRecord
    ) {
        for category in responsibilities {
            modelContext.insert(
                CompanyResponsibilityRecord(
                    accountID: account.id,
                    companyID: company.id,
                    category: category
                )
            )
        }

        let notificationsAreAuthorized = notificationAuthorization == .authorized
            || notificationAuthorization == .provisional
            || notificationAuthorization == .ephemeral
        for category in NotificationCategory.allCases {
            modelContext.insert(
                NotificationPreferenceRecord(
                    accountID: account.id,
                    companyID: company.id,
                    category: category,
                    isEnabled: enableNotifications
                        && notificationsAreAuthorized
                        && selectedNotificationCategories.contains(category),
                    leadTimeDays: notificationLeadTimeDays,
                    showsSensitiveDetails: false
                )
            )
        }

        for option in OnboardingIntegrationOption.options
        where requestedIntegrationIDs.contains(option.id) {
            let integration = IntegrationRecord(
                companyID: company.id,
                providerIdentifier: option.id,
                displayName: option.name,
                state: .disconnected
            )
            modelContext.insert(integration)
            modelContext.insert(
                AuditEventRecord(
                    companyID: company.id,
                    accountID: account.id,
                    action: "integration.setup.requested",
                    entityType: "integration",
                    entityID: integration.id,
                    summary: String(localized: "Installation för \(option.name) förbereddes lokalt. Ingen anslutning upprättades.")
                )
            )
        }

        if canInviteUsers, !inviteEmail.normalizedEmail.isEmpty {
            let invitation = CompanyInvitationRecord(
                companyID: company.id,
                email: inviteEmail.normalizedEmail,
                displayName: inviteDisplayName.trimmed,
                role: inviteRole,
                responsibilities: inviteResponsibilities.trimmed,
                invitedByAccountID: account.id
            )
            modelContext.insert(invitation)
            modelContext.insert(
                AuditEventRecord(
                    companyID: company.id,
                    accountID: account.id,
                    action: "membership.invitation.drafted",
                    entityType: "companyInvitation",
                    entityID: invitation.id,
                    summary: String(localized: "Ett lokalt inbjudningsutkast skapades för \(invitation.email).")
                )
            )
        }

        modelContext.insert(
            AuditEventRecord(
                companyID: company.id,
                accountID: account.id,
                action: "company.created",
                entityType: "company",
                entityID: company.id,
                summary: String(localized: "Bolaget lades till manuellt och väntar på verifiering från en officiell källa.")
            )
        )
    }
}

private struct OnboardingIntegrationOption: Identifiable, Sendable {
    let id: String
    let name: String
    let systemImage: String
    let note: String
    let informationURLString: String

    var informationURL: URL? {
        URL(string: informationURLString)
    }

    static let options: [OnboardingIntegrationOption] = [
        OnboardingIntegrationOption(
            id: "bolagsverket",
            name: "Bolagsverket",
            systemImage: "building.columns",
            note: "Bolagsuppgifter kräver en behörig och avtalad datakälla.",
            informationURLString: "https://bolagsverket.se/"
        ),
        OnboardingIntegrationOption(
            id: "skatteverket",
            name: "Skatteverket",
            systemImage: "checkmark.seal",
            note: "Skatteärenden kräver ett stödd och behörigt integrationsflöde.",
            informationURLString: "https://www.skatteverket.se/"
        ),
        OnboardingIntegrationOption(
            id: "fortnox",
            name: "Fortnox",
            systemImage: "books.vertical",
            note: "Anslutning kräver ett kommersiellt avtal och OAuth-konfiguration.",
            informationURLString: "https://www.fortnox.se/"
        ),
    ]
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedEmail: String {
        trimmed.lowercased()
    }

    var isPlausibleEmail: Bool {
        let parts = split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              let domain = parts.last,
              domain.contains("."),
              !domain.hasPrefix("."),
              !domain.hasSuffix(".") else {
            return false
        }
        return true
    }
}
