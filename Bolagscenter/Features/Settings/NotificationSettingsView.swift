import SwiftData
import SwiftUI
import UIKit

@MainActor
struct NotificationSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [NotificationPreferenceRecord]
    @Query private var deadlines: [DeadlineRecord]
    @Query private var deadlineReminders: [DeadlineReminderRecord]
    @Query private var actions: [ActionItemRecord]
    @Query private var documents: [DocumentRecord]
    @Query private var integrations: [IntegrationRecord]
    @Query private var resolutions: [BoardResolutionRecord]

    @State private var authorizationState: NotificationAuthorizationState = .unknown
    @State private var pendingCount = 0
    @State private var isRequesting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Systembehörighet", value: authorizationState.localizedName)
                LabeledContent("Schemalagda notiser", value: pendingCount.formatted())

                if authorizationState == .unknown {
                    Button {
                        Task { await requestAuthorization() }
                    } label: {
                        if isRequesting {
                            ProgressView()
                        } else {
                            Label("Aktivera notiser", systemImage: "bell.badge")
                        }
                    }
                    .disabled(isRequesting)
                } else if authorizationState == .denied,
                          let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    Link(destination: settingsURL) {
                        Label("Öppna systeminställningar", systemImage: "gear")
                    }
                }
            } header: {
                Text("Behörighet")
            } footer: {
                Text("NorthBridge begär bara notisbehörighet efter att du väljer att aktivera den.")
            }

            ForEach(NotificationCategory.allCases) { category in
                if let preference = preference(for: category) {
                    Section {
                        Toggle(
                            "Aktiverad",
                            isOn: binding(
                                get: { preference.isEnabled },
                                set: { preference.isEnabled = $0 }
                            )
                        )
                        if usesLeadTime(category) {
                            Stepper(
                                "Förvarning: \(preference.leadTimeDays) dagar",
                                value: binding(
                                    get: { preference.leadTimeDays },
                                    set: { preference.leadTimeDays = $0 }
                                ),
                                in: 0...60
                            )
                        }
                        Toggle(
                            "Visa känsliga detaljer",
                            isOn: binding(
                                get: { preference.showsSensitiveDetails },
                                set: { preference.showsSensitiveDetails = $0 }
                            )
                        )
                    } header: {
                        Text(category.localizedName)
                    } footer: {
                        Text(categoryDescription(category))
                    }
                }
            }

            Section {
                Button("Uppdatera schemalagda notiser", systemImage: "arrow.clockwise") {
                    Task { await synchronize() }
                }
                .disabled(!canSchedule)
            } footer: {
                Text("Standardläget döljer bolagsnamn och ärendedetaljer på låsskärmen. Fjärrnotiser kräver en konfigurerad backend och APNs-registrering.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Notiser")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            ensurePreferences()
            await refreshAuthorization()
            await synchronize()
        }
    }

    private var accountID: UUID? {
        environment.sessionController.activeSession?.accountID
    }

    private var companyID: UUID? {
        environment.selectedCompanyID
    }

    private var companyPreferences: [NotificationPreferenceRecord] {
        guard let accountID else { return [] }
        return preferences.filter {
            $0.accountID == accountID && $0.companyID == companyID
        }
    }

    private var canSchedule: Bool {
        authorizationState == .authorized
            || authorizationState == .provisional
            || authorizationState == .ephemeral
    }

    private func preference(
        for category: NotificationCategory
    ) -> NotificationPreferenceRecord? {
        companyPreferences.first { $0.category == category }
    }

    private func ensurePreferences() {
        guard let accountID else { return }
        let existing = Set(companyPreferences.map(\.category))
        for category in NotificationCategory.allCases where !existing.contains(category) {
            modelContext.insert(
                NotificationPreferenceRecord(
                    accountID: accountID,
                    companyID: companyID,
                    category: category,
                    isEnabled: false,
                    leadTimeDays: defaultLeadTime(for: category),
                    showsSensitiveDetails: false
                )
            )
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Notisinställningarna kunde inte förberedas.")
        }
    }

    private func binding<Value: Sendable>(
        get: @escaping @MainActor @Sendable () -> Value,
        set: @escaping @MainActor @Sendable (Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: get,
            set: { value in
                set(value)
                for preference in companyPreferences {
                    preference.updatedAt = .now
                }
                do {
                    try modelContext.save()
                    Task { await synchronize() }
                } catch {
                    modelContext.rollback()
                    errorMessage = String(localized: "Notisinställningen kunde inte sparas.")
                }
            }
        )
    }

    private func requestAuthorization() async {
        isRequesting = true
        defer { isRequesting = false }
        do {
            authorizationState = try await environment.notificationScheduler
                .requestAuthorization()
            if canSchedule {
                UIApplication.shared.registerForRemoteNotifications()
                await synchronize()
            }
        } catch {
            errorMessage = String(localized: "Notisbehörigheten kunde inte begäras.")
        }
    }

    private func refreshAuthorization() async {
        authorizationState = await environment.notificationScheduler
            .authorizationState()
        if authorizationState == .denied {
            await environment.notificationScheduler.removeAllOwnedRequests()
            await environment.remoteNotificationRegistration
                .unregisterCurrentInstallation()
            pendingCount = 0
        }
    }

    private func synchronize() async {
        guard canSchedule, let companyID else {
            pendingCount = await environment.notificationScheduler.pendingCount()
            return
        }
        let input = NotificationScheduleInput(
            preferences: companyPreferences.map {
                NotificationPreferenceSnapshot(
                    category: $0.category,
                    isEnabled: $0.isEnabled,
                    leadTimeDays: $0.leadTimeDays,
                    showsSensitiveDetails: $0.showsSensitiveDetails
                )
            },
            deadlines: deadlines
                .filter { $0.companyID == companyID }
                .map {
                    DeadlineNotificationSnapshot(
                        id: $0.id,
                        companyID: $0.companyID,
                        title: $0.title,
                        dueAt: $0.dueAt,
                        status: $0.status,
                        reminderIsEnabled: reminder(for: $0.id)?.isEnabled,
                        reminderLeadTimeDays: reminder(for: $0.id)?.leadTimeDays
                    )
                },
            actions: actions
                .filter { $0.companyID == companyID }
                .map {
                    ActionNotificationSnapshot(
                        id: $0.id,
                        companyID: $0.companyID,
                        title: $0.title,
                        assignedTo: $0.assignedTo,
                        dueAt: $0.dueAt,
                        status: $0.status
                    )
                },
            documents: documents
                .filter { $0.companyID == companyID && $0.expiresAt != nil }
                .compactMap {
                    guard let expiresAt = $0.expiresAt else { return nil }
                    return DocumentExpirationSnapshot(
                        id: $0.id,
                        companyID: $0.companyID,
                        title: $0.title,
                        expiresAt: expiresAt
                    )
                },
            integrations: integrations
                .filter { $0.companyID == companyID }
                .map {
                    IntegrationFailureSnapshot(
                        id: $0.id,
                        companyID: $0.companyID,
                        displayName: $0.displayName,
                        state: $0.state
                    )
                },
            approvals: resolutions
                .filter { $0.companyID == companyID }
                .map {
                    ApprovalNotificationSnapshot(
                        id: $0.id,
                        companyID: $0.companyID,
                        title: $0.title,
                        status: $0.status
                    )
                }
        )
        do {
            try await environment.notificationScheduler.synchronize(input)
            pendingCount = await environment.notificationScheduler.pendingCount()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = String(localized: "Notiserna kunde inte schemaläggas.")
        }
    }

    private func defaultLeadTime(
        for category: NotificationCategory
    ) -> Int {
        switch category {
        case .deadlines, .expiringContracts: 7
        case .assignedActions: 2
        case .approvals, .integrations, .officialDocuments,
             .companyStatus, .missingInformation: 0
        }
    }

    private func reminder(
        for deadlineID: UUID
    ) -> DeadlineReminderRecord? {
        deadlineReminders.first { $0.deadlineID == deadlineID }
    }

    private func usesLeadTime(_ category: NotificationCategory) -> Bool {
        category == .deadlines
            || category == .assignedActions
            || category == .expiringContracts
    }

    private func categoryDescription(
        _ category: NotificationCategory
    ) -> String {
        switch category {
        case .deadlines:
            "Kommande bolagsdeadlines."
        case .approvals:
            "Beslut och protokoll som väntar på behandling."
        case .assignedActions:
            "Åtgärder som har tilldelats en ansvarig."
        case .integrations:
            "Anslutningar som misslyckats eller tappat behörighet."
        case .officialDocuments:
            "Nya officiella dokument kräver en konfigurerad fjärrintegration."
        case .companyStatus:
            "Statusändringar kräver en källansluten fjärrintegration."
        case .expiringContracts:
            "Dokument och avtal med registrerat utgångsdatum."
        case .missingInformation:
            "Registrerade informationsluckor i bolagsarbetsytan."
        }
    }
}
