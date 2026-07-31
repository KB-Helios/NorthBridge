import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private struct IntegrationDescriptor: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
    let officialURLString: String
    let note: String

    var officialURL: URL? {
        URL(string: officialURLString)
    }

    static let officialServices: [IntegrationDescriptor] = [
        IntegrationDescriptor(
            id: "bolagsverket",
            name: "Bolagsverket",
            systemImage: "building.columns",
            officialURLString: "https://bolagsverket.se/",
            note: "Bolagsuppgifter kräver en behörig och avtalad datakälla."
        ),
        IntegrationDescriptor(
            id: "skatteverket",
            name: "Skatteverket",
            systemImage: "checkmark.seal",
            officialURLString: "https://www.skatteverket.se/",
            note: "Skatteärenden skickas inte automatiskt utan en stödd integration."
        ),
        IntegrationDescriptor(
            id: "verksamt",
            name: "Verksamt.se",
            systemImage: "briefcase",
            officialURLString: "https://verksamt.se/",
            note: "När API-stöd saknas öppnas den officiella tjänsten externt."
        ),
        IntegrationDescriptor(
            id: "scb",
            name: "SCB",
            systemImage: "chart.bar.xaxis",
            officialURLString: "https://www.scb.se/",
            note: "Dataset och användningsvillkor måste väljas innan anslutning."
        )
    ]
}

@MainActor
struct IntegrationCenterView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var integrations: [IntegrationRecord]
    @Query private var companies: [CompanyRecord]
    @Query private var profiles: [CompanyProfileRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var completionProvider: IntegrationDescriptor?
    @State private var isRefreshingCompany = false
    @State private var refreshMessage: String?
    @State private var refreshError: String?

    var body: some View {
        List {
            Section {
                LabeledContent {
                    StatusBadge(
                        text: AppConfiguration.backend() == nil ? "Inte konfigurerad" : "Konfigurerad",
                        kind: AppConfiguration.backend() == nil ? .warning : .positive
                    )
                } label: {
                    Label("NorthBridge API", systemImage: "network")
                }
                Button {
                    Task { await refreshCompanyFromRegistry() }
                } label: {
                    if isRefreshingCompany {
                        HStack {
                            ProgressView()
                            Text("Uppdaterar bolagsuppgifter")
                        }
                    } else {
                        Label(
                            "Uppdatera bolagsuppgifter",
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
                .disabled(
                    isRefreshingCompany
                        || selectedCompany == nil
                        || environment.connectivityMonitor.state == .offline
                )
                .accessibilityIdentifier("integrations.company.refresh")

                if let refreshMessage {
                    Label(refreshMessage, systemImage: "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
                if let refreshError {
                    Label(refreshError, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Backend")
            } footer: {
                Text("Backendadress och miljö läses från respektive byggkonfiguration. Inga adresser eller hemligheter är hårdkodade.")
            }

            Section("Svenska myndigheter och tjänster") {
                ForEach(IntegrationDescriptor.officialServices) { provider in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Label(provider.name, systemImage: provider.systemImage)
                                .font(.body.weight(.semibold))
                            Spacer()
                            StatusBadge(
                                text: integrationState(for: provider).localizedName,
                                kind: badgeKind(for: integrationState(for: provider))
                            )
                        }
                        Text(provider.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            if let officialURL = provider.officialURL {
                                Link(destination: officialURL) {
                                    Label("Öppna officiell tjänst", systemImage: "arrow.up.right.square")
                                }
                            }
                            Spacer()
                            Button("Registrera slutfört") {
                                completionProvider = provider
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 5)
                    .accessibilityElement(children: .contain)
                }
            }

            Section("Finansiella integrationer") {
                unavailableRow(
                    name: "Fortnox / Visma / Bokio",
                    detail: "Väntar på val av leverantör, kommersiellt avtal och OAuth-konfiguration."
                )
                unavailableRow(
                    name: "Open banking",
                    detail: "Kräver en godkänd open-banking-leverantör och uttryckligt användarsamtycke."
                )
            }

            Section {
                Text("NorthBridge skrapar inte autentiserade webbplatser och påstår aldrig att en myndighetsåtgärd skickats automatiskt när den utförts externt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Integrationer")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshCompanyFromRegistry()
        }
        .sheet(item: $completionProvider) { provider in
            ExternalWorkflowCompletionView(provider: provider)
        }
    }

    @ViewBuilder
    private func unavailableRow(name: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(name)
                Spacer()
                StatusBadge(text: "Inte konfigurerad", kind: .warning)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func integrationState(
        for provider: IntegrationDescriptor
    ) -> IntegrationState {
        guard let companyID = environment.selectedCompanyID else { return .disconnected }
        return integrations.first {
            $0.companyID == companyID && $0.providerIdentifier == provider.id
        }?.state ?? .disconnected
    }

    private func badgeKind(for state: IntegrationState) -> StatusBadge.Kind {
        switch state {
        case .connected: .positive
        case .refreshing: .neutral
        case .disconnected, .unauthorized, .stale, .rateLimited: .warning
        case .unavailable, .failed: .critical
        }
    }

    private var selectedCompany: CompanyRecord? {
        companies.first { $0.id == environment.selectedCompanyID }
    }

    private func refreshCompanyFromRegistry() async {
        guard !isRefreshingCompany else { return }
        refreshMessage = nil
        refreshError = nil

        guard environment.connectivityMonitor.state != .offline else {
            refreshError = String(
                localized: "Ingen nätverksanslutning. Sparade uppgifter och deras tidsstämplar har inte ändrats."
            )
            return
        }
        guard let company = selectedCompany,
              let accountID = environment.sessionController
                .activeSession?.accountID else {
            refreshError = String(localized: "Välj ett bolag och logga in igen.")
            return
        }

        isRefreshingCompany = true
        defer { isRefreshingCompany = false }

        do {
            let role = ActiveCompanyAccess.role(
                companyID: company.id,
                accountID: accountID,
                memberships: memberships
            )
            _ = try await CompanyRegistryRefreshService(
                registry: environment.companyRegistryService,
                permissionPolicy: environment.permissionPolicy
            ).refresh(
                company: company,
                accountID: accountID,
                role: role,
                profiles: profiles,
                integrations: integrations,
                in: modelContext
            )
            refreshMessage = String(
                localized: "Bolagsuppgifterna uppdaterades med källa och tidsstämpel."
            )
        } catch {
            refreshError = error.localizedDescription
        }
    }
}

private struct PendingSupportingDocument: Identifiable {
    let id = UUID()
    let filename: String
    let typeIdentifier: String
    let data: Data
}

@MainActor
private struct ExternalWorkflowCompletionView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]

    let provider: IntegrationDescriptor

    @State private var completionNote = ""
    @State private var isImportingEvidence = false
    @State private var evidence: PendingSupportingDocument?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let officialURL = provider.officialURL {
                    Section {
                        Link(destination: officialURL) {
                            Label("Öppna \(provider.name)", systemImage: "arrow.up.right.square")
                        }
                    } footer: {
                        Text("Åtgärden utförs i den officiella tjänsten utanför NorthBridge.")
                    }
                }

                Section("Bekräftelse") {
                    TextField(
                        "Vad slutfördes?",
                        text: $completionNote,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    Button("Bifoga underlag", systemImage: "paperclip") {
                        isImportingEvidence = true
                    }
                    if let evidence {
                        Label(evidence.filename, systemImage: "doc.badge.checkmark")
                    }
                }

                Section {
                    Text("NorthBridge registrerar endast din bekräftelse och det bifogade underlaget. Appen påstår inte att åtgärden skickades automatiskt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Registrera externt ärende")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Registrera") { save() }
                        .disabled(!isValid)
                }
            }
            .fileImporter(
                isPresented: $isImportingEvidence,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                importEvidence(result)
            }
        }
    }

    private var isValid: Bool {
        !completionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && evidence != nil
    }

    private func importEvidence(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                throw CocoaError(.fileReadNoPermission)
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            let type = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
            guard let type, !data.isEmpty else {
                throw CocoaError(.fileReadCorruptFile)
            }
            evidence = PendingSupportingDocument(
                filename: url.lastPathComponent,
                typeIdentifier: type.identifier,
                data: data
            )
        } catch {
            errorMessage = String(localized: "Underlaget kunde inte läsas.")
        }
    }

    private func save() {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.editCompany, for: role) else {
            errorMessage = String(localized: "Din roll saknar behörighet att registrera externa ärenden.")
            return
        }
        guard let evidence else {
            errorMessage = String(localized: "Bifoga ett underlag innan ärendet registreras.")
            return
        }

        do {
            let root = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = root
                .appending(path: "Documents", directoryHint: .isDirectory)
                .appending(path: companyID.uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            let fileURL = directory.appending(
                path: "\(UUID().uuidString)-\(evidence.filename)"
            )
            try evidence.data.write(
                to: fileURL,
                options: [.atomic, .completeFileProtection]
            )
            let bookmark = try fileURL.bookmarkData()
            let document = DocumentRecord(
                companyID: companyID,
                title: "\(provider.name) – externt underlag",
                category: .other,
                fileBookmark: bookmark,
                originalFilename: evidence.filename,
                uniformTypeIdentifier: evidence.typeIdentifier,
                sourceName: provider.name
            )
            modelContext.insert(document)
            modelContext.insert(
                DocumentVersionRecord(
                    companyID: companyID,
                    documentID: document.id,
                    versionNumber: 1,
                    fileBookmark: bookmark,
                    sourceName: provider.name
                )
            )
            modelContext.insert(
                AuditEventRecord(
                    companyID: companyID,
                    accountID: accountID,
                    action: "integration.external.completed",
                    entityType: "externalWorkflow",
                    entityID: document.id,
                    summary: String(localized: "\(provider.name): \(completionNote.trimmingCharacters(in: .whitespacesAndNewlines))")
                )
            )
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Bekräftelsen och underlaget kunde inte sparas.")
        }
    }
}
