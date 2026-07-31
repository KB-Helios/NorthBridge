import SwiftData
import SwiftUI

@MainActor
struct AccountLifecycleView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserAccountRecord.createdAt) private var accounts: [UserAccountRecord]

    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var showsLogoutConfirmation = false
    @State private var showsDeletion = false

    var body: some View {
        Form {
            if let account = activeAccount {
                Section("Profil") {
                    LabeledContent("Namn", value: account.displayName)
                    LabeledContent("E-post", value: account.email)
                    LabeledContent(
                        "Konto skapat",
                        value: account.createdAt.formatted(
                            date: .long,
                            time: .omitted
                        )
                    )
                }

                Section {
                    Button {
                        createExport(accountID: account.id)
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            Label(
                                "Skapa portabel dataexport",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                    }
                    .disabled(isExporting)
                    .accessibilityIdentifier("account.export.create")

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label(
                                "Dela dataexport",
                                systemImage: "square.and.arrow.up.on.square"
                            )
                        }
                        .accessibilityIdentifier("account.export.share")
                    }
                } header: {
                    Text("Dina data")
                } footer: {
                    Text("JSON-exporten innehåller kontots bolags-, styrelse-, ägar-, ekonomi- och dokumentmetadata. Skyddade dokumentfiler delas separat från respektive dokumentvy.")
                }

                Section {
                    Button("Logga ut", systemImage: "rectangle.portrait.and.arrow.right") {
                        showsLogoutConfirmation = true
                    }
                } footer: {
                    Text("Utloggning tar bort session och eventuella åtkomsttoken från nyckelringen men behåller dina lokala bolagsdata.")
                }

                Section {
                    Button(
                        "Radera konto och lokala data",
                        systemImage: "trash",
                        role: .destructive
                    ) {
                        showsDeletion = true
                    }
                } header: {
                    Text("Riskzon")
                } footer: {
                    Text("Bolag utan någon annan aktiv användare raderas från enheten. Delade bolagsdata behålls för kvarvarande användare.")
                }
            } else {
                ContentUnavailableView(
                    "Kontot saknas",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Logga in igen för att hantera kontot.")
                )
            }

            if let errorMessage {
                Section {
                    Label(
                        errorMessage,
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Konto och data")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Vill du logga ut?",
            isPresented: $showsLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Logga ut", role: .destructive) {
                Task {
                    await environment.remoteNotificationRegistration
                        .unregisterCurrentInstallation()
                    WidgetSnapshotCoordinator.clear()
                    await environment.sessionController.logout()
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Du behöver enhetens kod, Face ID eller Touch ID för att logga in igen.")
        }
        .sheet(isPresented: $showsDeletion) {
            if let account = activeAccount {
                AccountDeletionConfirmationView(
                    accountID: account.id,
                    email: account.email
                )
            }
        }
        .onDisappear {
            if let exportURL {
                try? FileManager.default.removeItem(at: exportURL)
            }
        }
    }

    private var activeAccount: UserAccountRecord? {
        guard let accountID = environment.sessionController.activeSession?.accountID else {
            return nil
        }
        return accounts.first { $0.id == accountID }
    }

    private func createExport(accountID: UUID) {
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }
        do {
            if let exportURL {
                try? FileManager.default.removeItem(at: exportURL)
            }
            exportURL = try AccountDataExportService().export(
                accountID: accountID,
                from: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private struct AccountDeletionConfirmationView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let accountID: UUID
    let email: String

    @State private var confirmation = ""
    @State private var understandsSubscription = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(
                        "Detta kan inte ångras.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.red)
                    Text("Kontot och bolag som saknar andra aktiva användare raderas från den här enheten, inklusive appägda dokumentfiler.")
                }

                Section {
                    Text(email)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                    TextField("Skriv e-postadressen", text: $confirmation)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                } header: {
                    Text("Bekräfta e-postadress")
                }

                Section {
                    Toggle(
                        "Jag förstår att en App Store-prenumeration måste sägas upp separat.",
                        isOn: $understandsSubscription
                    )
                }

                if let errorMessage {
                    Section {
                        Label(
                            errorMessage,
                            systemImage: "exclamationmark.circle.fill"
                        )
                        .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(
                        "Radera konto permanent",
                        role: .destructive
                    ) {
                        Task { await deleteAccount() }
                    }
                    .disabled(!canDelete || isDeleting)
                } footer: {
                    Text("Åtgärden kräver Face ID, Touch ID eller enhetens kod.")
                }
            }
            .navigationTitle("Radera konto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        dismiss()
                    }
                    .disabled(isDeleting)
                }
            }
            .interactiveDismissDisabled(isDeleting)
        }
    }

    private var canDelete: Bool {
        confirmation.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(email) == .orderedSame
            && understandsSubscription
    }

    private func deleteAccount() async {
        guard canDelete else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await environment.sessionController.confirmIdentity(
                reason: String(localized: "Bekräfta permanent kontoradering")
            )
            if let queue = environment.offlineMutationQueue {
                try await queue.clear()
            }
            _ = try AccountDeletionService().delete(
                accountID: accountID,
                from: modelContext
            )
            await environment.notificationScheduler.removeAllOwnedRequests()
            await environment.subscriptionManager.clearLocalState()
            await environment.remoteNotificationRegistration
                .unregisterCurrentInstallation()
            WidgetSnapshotCoordinator.clear(resetPrivacyPreference: true)
            environment.selectedCompanyID = nil
            environment.lockController.disable()
            await environment.sessionController.logout()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
