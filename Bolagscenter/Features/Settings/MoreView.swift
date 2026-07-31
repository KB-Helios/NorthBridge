import SwiftData
import SwiftUI

@MainActor
struct MoreView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \UserAccountRecord.createdAt) private var accounts: [UserAccountRecord]

    var body: some View {
        List {
            if let account = activeAccount {
                Section {
                    LabeledContent("Namn", value: account.displayName)
                    LabeledContent("E-post", value: account.email)
                    NavigationLink(value: AppRoute.accountSettings) {
                        Label("Konto och data", systemImage: "person.crop.circle")
                    }
                } header: {
                    Text("Profil")
                } footer: {
                    Text("Lokal profil. Serverbaserad kontosynkronisering är inte konfigurerad.")
                }
            }

            Section("NorthBridge") {
                NavigationLink(value: AppRoute.assistant) {
                    Label("Bolagsassistenten", systemImage: "sparkles")
                }
                NavigationLink(value: AppRoute.search) {
                    Label("Global sökning", systemImage: "magnifyingglass")
                }
                NavigationLink(value: AppRoute.deadlines) {
                    Label("Deadlinecenter", systemImage: "calendar.badge.clock")
                }
                NavigationLink(value: AppRoute.activity) {
                    Label("Aktivitetshistorik", systemImage: "clock.arrow.circlepath")
                }
            }

            Section("Inställningar") {
                NavigationLink(value: AppRoute.integrations) {
                    Label("Integrationer", systemImage: "point.3.connected.trianglepath.dotted")
                }
                NavigationLink(value: AppRoute.usersAndRoles) {
                    Label("Användare och roller", systemImage: "person.2.badge.gearshape")
                }
                NavigationLink(value: AppRoute.notificationSettings) {
                    Label("Notiser", systemImage: "bell.badge")
                }
                NavigationLink(value: AppRoute.subscription) {
                    Label("Prenumeration", systemImage: "creditcard")
                }
                NavigationLink(value: AppRoute.security) {
                    Label("Integritet och säkerhet", systemImage: "lock.shield")
                }
            }

            Section {
                Text("Officiella myndighets-, bank-, bokförings-, prenumerations- och AI-integrationer är inte aktiverade utan respektive avtal och autentiseringsuppgifter.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Integrationsstatus")
            }
        }
        .navigationTitle("Mer")
    }

    private var activeAccount: UserAccountRecord? {
        guard let accountID = environment.sessionController.activeSession?.accountID else {
            return nil
        }
        return accounts.first { $0.id == accountID }
    }
}

@MainActor
struct SecuritySettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @State private var showsSensitiveWidgetData = false

    var body: some View {
        @Bindable var lockController = environment.lockController

        Form {
            Section {
                Toggle(isOn: $lockController.isEnabled) {
                    Label("Face ID eller enhetskod", systemImage: "faceid")
                }
            } header: {
                Text("Appskydd")
            } footer: {
                Text("När appskydd är aktiverat låses NorthBridge automatiskt i bakgrunden.")
            }

            Section("Loggning") {
                Label("Känsliga identifierare maskeras i tekniska loggar.", systemImage: "eye.slash")
                    .font(.footnote)
            }

            Section {
                Toggle(
                    "Visa bolagsdetaljer i widgetar",
                    isOn: Binding(
                        get: { showsSensitiveWidgetData },
                        set: { updateWidgetPrivacy($0) }
                    )
                )
            } header: {
                Text("Widgetintegritet")
            } footer: {
                Text("Av som standard. När detta aktiveras får deadline, datum och likviditetsbelopp skrivas till den skyddade appgruppen. Widgetinnehållet markeras fortfarande som integritetskänsligt.")
            }
        }
        .navigationTitle("Integritet och säkerhet")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            showsSensitiveWidgetData = WidgetPrivacyPreference.showsSensitiveData
        }
    }

    private func updateWidgetPrivacy(_ newValue: Bool) {
        showsSensitiveWidgetData = newValue
        WidgetPrivacyPreference.showsSensitiveData = newValue
        if let companyID = environment.selectedCompanyID {
            WidgetSnapshotCoordinator.refresh(
                companyID: companyID,
                modelContext: modelContext
            )
        }
    }
}
