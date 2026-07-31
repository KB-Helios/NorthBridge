import Foundation
import SwiftData
import SwiftUI

@MainActor
struct ShareCertificatesView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var companies: [CompanyRecord]
    @Query(sort: \ShareholderRecord.displayName) private var shareholders: [ShareholderRecord]
    @Query(sort: \ShareClassRecord.name) private var shareClasses: [ShareClassRecord]
    @Query(sort: \ShareTransactionRecord.transactionDate)
    private var transactions: [ShareTransactionRecord]
    @Query(sort: \ShareCertificateRecord.issuedAt, order: .reverse)
    private var certificates: [ShareCertificateRecord]
    @Query private var documents: [DocumentRecord]
    @Query private var versions: [DocumentVersionRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var isPresentingEditor = false
    @State private var exportedFileURL: URL?
    @State private var certificateToRevoke: ShareCertificateRecord?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Registrerade aktiebrev") {
                if companyCertificates.isEmpty {
                    ContentUnavailableView(
                        "Inga aktiebrev",
                        systemImage: "doc.badge.gearshape",
                        description: Text(
                            "Skapa ett administrativt utkast först när innehavet har kontrollerats mot aktieboken."
                        )
                    )
                } else {
                    ForEach(companyCertificates) { certificate in
                        certificateRow(certificate)
                    }
                }
            }

            if let exportedFileURL {
                Section("Senaste PDF") {
                    ShareLink(item: exportedFileURL) {
                        Label("Dela aktiebrevet", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("ownership.certificate.share")
                }
            }

            if !validationIssues.isEmpty {
                Section("Kontroll krävs") {
                    ForEach(validationIssues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    Text(
                        "NorthBridge ändrar aldrig ägarhistoriken automatiskt. Kontrollera aktieboken och återkalla eller ersätt felaktiga aktiebrev uttryckligen."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Text(
                    "NorthBridge skapar administrativt underlag och registrerar historik. Appen avgör inte om ett aktiebrev ska utfärdas och markeringen i appen ersätter inte kontroll, beslut, underskrift eller överlämnande av ett original."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Aktiebrev")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nytt aktiebrev", systemImage: "plus") {
                    isPresentingEditor = true
                }
                .disabled(!canManageCertificates)
                .accessibilityIdentifier("ownership.certificate.add")
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            NavigationStack {
                ShareCertificateEditorView()
            }
        }
        .confirmationDialog(
            "Återkalla registreringen?",
            isPresented: Binding(
                get: { certificateToRevoke != nil },
                set: { if !$0 { certificateToRevoke = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Återkalla aktiebrevet", role: .destructive) {
                if let certificateToRevoke {
                    revoke(certificateToRevoke)
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text(
                "Posten och tidigare PDF-filer behålls i historiken. Ägarinnehavet ändras inte."
            )
        }
        .alert(
            "Åtgärden kunde inte slutföras",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func certificateRow(_ certificate: ShareCertificateRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(certificate.certificateNumber)
                    .font(.body.weight(.semibold))
                Spacer()
                StatusBadge(
                    text: certificate.status.localizedName,
                    kind: statusKind(certificate.status)
                )
            }
            Text(shareholderName(certificate.shareholderID))
            Text(
                "\(certificate.quantity.formatted()) \(shareClassName(certificate.shareClassID)) · \(certificate.issuedAt.formatted(date: .abbreviated, time: .omitted))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Button("Skapa PDF", systemImage: "doc.richtext") {
                    export(certificate)
                }
                .buttonStyle(.borderless)
                .disabled(!canExport)

                Spacer()

                if certificate.status == .draft || certificate.status == .issued {
                    Button(role: .destructive) {
                        certificateToRevoke = certificate
                    } label: {
                        Label("Återkalla", systemImage: "xmark.seal")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canManageCertificates)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private var companyCertificates: [ShareCertificateRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return certificates.filter { $0.companyID == companyID }
    }

    private var validationIssues: [String] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        let positions = OwnershipLedger().positions(
            from: transactions
                .filter { $0.companyID == companyID }
                .map(\.snapshot)
        )
        let activeCertificates = companyCertificates.filter {
            $0.status == .draft || $0.status == .issued
        }
        let grouped = Dictionary(
            grouping: activeCertificates,
            by: {
                "\($0.shareholderID.uuidString):\($0.shareClassID.uuidString)"
            }
        )

        return grouped.values.compactMap { group in
            guard let first = group.first else { return nil }
            let certified = group.reduce(0) { $0 + $1.quantity }
            let holding = positions.first {
                $0.shareholderID == first.shareholderID
                    && $0.shareClassID == first.shareClassID
            }?.quantity ?? 0
            guard certified > holding else { return nil }
            return String(
                localized: "\(shareholderName(first.shareholderID)): aktiva aktiebrev omfattar \(certified) aktier men aktieboken visar \(holding)."
            )
        }
        .sorted()
    }

    private var activeRole: CompanyRole? {
        ActiveCompanyAccess.role(
            companyID: environment.selectedCompanyID,
            accountID: environment.sessionController.activeSession?.accountID,
            memberships: memberships
        )
    }

    private var canManageCertificates: Bool {
        guard let activeRole else { return false }
        return environment.permissionPolicy.allows(.manageOwnership, for: activeRole)
    }

    private var canExport: Bool {
        guard let activeRole else { return false }
        return environment.permissionPolicy.allows(.exportData, for: activeRole)
    }

    private func statusKind(_ status: ShareCertificateStatus) -> StatusBadge.Kind {
        switch status {
        case .draft: .warning
        case .issued: .positive
        case .revoked, .replaced: .neutral
        }
    }

    private func shareholderName(_ id: UUID) -> String {
        shareholders.first(where: { $0.id == id })?.displayName
            ?? String(localized: "Okänd aktieägare")
    }

    private func shareClassName(_ id: UUID) -> String {
        shareClasses.first(where: { $0.id == id })?.name
            ?? String(localized: "Okänt aktieslag")
    }

    private func export(_ certificate: ShareCertificateRecord) {
        guard canExport,
              let company = companies.first(where: {
                  $0.id == certificate.companyID
              }),
              let shareholder = shareholders.first(where: {
                  $0.id == certificate.shareholderID
              }),
              let shareClass = shareClasses.first(where: {
                  $0.id == certificate.shareClassID
              }),
              let accountID = environment.sessionController.activeSession?.accountID else {
            errorMessage = String(
                localized: "Du saknar behörighet eller underlag för exporten."
            )
            return
        }

        var generatedURL: URL?
        do {
            let input = ShareCertificatePDFInput(
                certificateID: certificate.id,
                companyID: company.id,
                companyName: company.registeredName,
                organisationNumber: company.organisationNumber,
                certificateNumber: certificate.certificateNumber,
                shareholderName: shareholder.displayName,
                shareholderIdentityReference: shareholder.identityReference ?? "",
                shareholderPostalAddress: shareholder.postalAddress ?? "",
                shareClassName: shareClass.name,
                quantity: certificate.quantity,
                shareNumberFrom: certificate.shareNumberFrom,
                shareNumberTo: certificate.shareNumberTo,
                issuedAt: certificate.issuedAt,
                status: certificate.status,
                notes: certificate.notes
            )
            let fileURL = try GovernancePDFExporter.exportShareCertificate(input)
            generatedURL = fileURL
            let title = String(
                localized: "Aktiebrev \(certificate.certificateNumber) – \(shareholder.displayName)"
            )
            let sourceName = String(localized: "Genererat i NorthBridge")
            _ = try GeneratedDocumentVaultService().recordPDF(
                companyID: company.id,
                title: title,
                category: .shareCertificate,
                fileURL: fileURL,
                sourceName: sourceName,
                documents: documents,
                versions: versions,
                in: modelContext
            )
            modelContext.insert(
                AuditEventRecord(
                    companyID: company.id,
                    accountID: accountID,
                    action: "ownership.shareCertificate.exported",
                    entityType: "shareCertificate",
                    entityID: certificate.id,
                    summary: String(
                        localized: "Aktiebrev \(certificate.certificateNumber) exporterades som PDF."
                    )
                )
            )
            try modelContext.save()
            exportedFileURL = fileURL
            errorMessage = nil
        } catch {
            modelContext.rollback()
            if let generatedURL {
                try? FileManager.default.removeItem(at: generatedURL)
            }
            errorMessage = error.localizedDescription
        }
    }

    private func revoke(_ certificate: ShareCertificateRecord) {
        guard canManageCertificates,
              let accountID = environment.sessionController.activeSession?.accountID else {
            errorMessage = String(localized: "Du saknar behörighet att återkalla aktiebrev.")
            return
        }
        guard certificate.status == .draft || certificate.status == .issued else {
            return
        }

        certificate.status = .revoked
        modelContext.insert(
            AuditEventRecord(
                companyID: certificate.companyID,
                accountID: accountID,
                action: "ownership.shareCertificate.revoked",
                entityType: "shareCertificate",
                entityID: certificate.id,
                summary: String(
                    localized: "Aktiebrev \(certificate.certificateNumber) återkallades utan att ägarhistoriken ändrades."
                )
            )
        )
        do {
            try modelContext.save()
            certificateToRevoke = nil
            errorMessage = nil
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Återkallandet kunde inte sparas.")
        }
    }
}

@MainActor
private struct ShareCertificateEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShareholderRecord.displayName) private var shareholders: [ShareholderRecord]
    @Query(sort: \ShareClassRecord.name) private var shareClasses: [ShareClassRecord]
    @Query(sort: \ShareTransactionRecord.transactionDate) private var transactions: [ShareTransactionRecord]
    @Query private var certificates: [ShareCertificateRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var shareholderID: UUID?
    @State private var shareClassID: UUID?
    @State private var certificateNumber = ""
    @State private var quantity = 1
    @State private var shareNumberFrom = ""
    @State private var shareNumberTo = ""
    @State private var issuedAt = Date.now
    @State private var isMarkedIssued = false
    @State private var notes = ""
    @State private var isConfirmingIssuance = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Aktiebrev") {
                TextField("Aktiebrevsnummer", text: $certificateNumber)
                    .textInputAutocapitalization(.characters)
                    .accessibilityIdentifier("ownership.certificate.number")
                Picker("Aktieägare", selection: $shareholderID) {
                    Text("Välj aktieägare").tag(UUID?.none)
                    ForEach(companyShareholders) { shareholder in
                        Text(shareholder.displayName).tag(UUID?.some(shareholder.id))
                    }
                }
                Picker("Aktieslag", selection: $shareClassID) {
                    Text("Välj aktieslag").tag(UUID?.none)
                    ForEach(companyShareClasses) { shareClass in
                        Text(shareClass.name).tag(UUID?.some(shareClass.id))
                    }
                }
                TextField("Antal aktier", value: $quantity, format: .number)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("ownership.certificate.quantity")
                DatePicker(
                    "Registrerat datum",
                    selection: $issuedAt,
                    displayedComponents: .date
                )
            }

            Section {
                TextField("Första aktienummer", text: $shareNumberFrom)
                    .keyboardType(.numberPad)
                TextField("Sista aktienummer", text: $shareNumberTo)
                    .keyboardType(.numberPad)
            } header: {
                Text("Aktienummer, valfritt")
            } footer: {
                Text(
                    "Om aktienummer anges måste intervallet motsvara antalet aktier och får inte överlappa ett aktivt aktiebrev för samma aktieslag."
                )
            }

            Section {
                LabeledContent(
                    "Aktuellt innehav",
                    value: currentHolding.formatted()
                )
                LabeledContent(
                    "Redan i aktiva aktiebrev",
                    value: alreadyCertifiedQuantity.formatted()
                )
                LabeledContent(
                    "Tillgängligt",
                    value: availableQuantity.formatted()
                )
                Toggle("Markera som utfärdat i registret", isOn: $isMarkedIssued)
            } header: {
                Text("Kontroll")
            } footer: {
                Text(
                    "Markeringen bevisar inte att ett giltigt original har beslutats, undertecknats eller överlämnats."
                )
            }

            Section("Anteckningar") {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle("Nytt aktiebrev")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Avbryt") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Spara") {
                    if isMarkedIssued {
                        isConfirmingIssuance = true
                    } else {
                        save()
                    }
                }
                .accessibilityIdentifier("ownership.certificate.save")
            }
        }
        .task {
            prepareDefaults()
        }
        .confirmationDialog(
            "Markera som utfärdat?",
            isPresented: $isConfirmingIssuance,
            titleVisibility: .visible
        ) {
            Button("Spara och markera som utfärdat") {
                save()
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text(
                "Bekräfta först efter att behörig företrädare har kontrollerat bolagets underlag. NorthBridge skapar ingen juridisk giltighet."
            )
        }
        .alert(
            "Aktiebrevet kunde inte sparas",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var companyShareholders: [ShareholderRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return shareholders.filter {
            $0.companyID == companyID && $0.archivedAt == nil
        }
    }

    private var companyShareClasses: [ShareClassRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return shareClasses.filter { $0.companyID == companyID }
    }

    private var companyTransactions: [ShareTransactionRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return transactions.filter { $0.companyID == companyID }
    }

    private var currentHolding: Int {
        guard let shareholderID, let shareClassID else { return 0 }
        return OwnershipLedger()
            .positions(from: companyTransactions.map(\.snapshot))
            .first {
                $0.shareholderID == shareholderID
                    && $0.shareClassID == shareClassID
            }?
            .quantity ?? 0
    }

    private var alreadyCertifiedQuantity: Int {
        guard let companyID = environment.selectedCompanyID,
              let shareholderID,
              let shareClassID else {
            return 0
        }
        return certificates
            .filter {
                $0.companyID == companyID
                    && $0.shareholderID == shareholderID
                    && $0.shareClassID == shareClassID
                    && ($0.status == .draft || $0.status == .issued)
            }
            .reduce(0) { $0 + $1.quantity }
    }

    private var availableQuantity: Int {
        max(0, currentHolding - alreadyCertifiedQuantity)
    }

    private var activeShareNumberRanges: [ClosedRange<Int>] {
        guard let companyID = environment.selectedCompanyID,
              let shareClassID else {
            return []
        }
        return certificates.compactMap { certificate in
            guard certificate.companyID == companyID,
                  certificate.shareClassID == shareClassID,
                  certificate.status == .draft || certificate.status == .issued,
                  let first = certificate.shareNumberFrom,
                  let last = certificate.shareNumberTo,
                  first <= last else {
                return nil
            }
            return first...last
        }
    }

    private func prepareDefaults() {
        shareholderID = shareholderID ?? companyShareholders.first?.id
        shareClassID = shareClassID ?? companyShareClasses.first?.id
        guard certificateNumber.isEmpty else { return }
        let sequence = certificates
            .filter { $0.companyID == environment.selectedCompanyID }
            .count + 1
        certificateNumber = String(
            format: "AKTIEBREV-%d-%03d",
            Calendar.current.component(.year, from: .now),
            sequence
        )
    }

    private func save() {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                  companyID: companyID,
                  accountID: accountID,
                  memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageOwnership, for: role),
              let shareholderID,
              let shareClassID else {
            errorMessage = String(localized: "Välj bolag, aktieägare och aktieslag.")
            return
        }

        do {
            let first = try parseOptionalShareNumber(shareNumberFrom)
            let last = try parseOptionalShareNumber(shareNumberTo)
            let draft = ShareCertificateDraft(
                certificateNumber: certificateNumber,
                quantity: quantity,
                shareNumberFrom: first,
                shareNumberTo: last
            )
            try ShareCertificatePolicy().validate(
                draft,
                currentHolding: currentHolding,
                alreadyCertifiedQuantity: alreadyCertifiedQuantity,
                existingCertificateNumbers: Set(
                    certificates
                        .filter { $0.companyID == companyID }
                        .map(\.certificateNumber)
                ),
                existingShareNumberRanges: activeShareNumberRanges
            )

            let status: ShareCertificateStatus = isMarkedIssued ? .issued : .draft
            let certificate = ShareCertificateRecord(
                companyID: companyID,
                shareholderID: shareholderID,
                shareClassID: shareClassID,
                certificateNumber: certificateNumber
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: quantity,
                shareNumberFrom: first,
                shareNumberTo: last,
                issuedAt: issuedAt,
                status: status,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(certificate)
            modelContext.insert(
                AuditEventRecord(
                    companyID: companyID,
                    accountID: accountID,
                    action: isMarkedIssued
                        ? "ownership.shareCertificate.issued"
                        : "ownership.shareCertificate.drafted",
                    entityType: "shareCertificate",
                    entityID: certificate.id,
                    summary: isMarkedIssued
                        ? String(
                            localized: "Aktiebrev \(certificate.certificateNumber) markerades som utfärdat i registret."
                        )
                        : String(
                            localized: "Ett utkast till aktiebrev \(certificate.certificateNumber) skapades."
                        )
                )
            )
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func parseOptionalShareNumber(_ value: String) throws -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let number = Int(trimmed) else {
            throw ShareCertificateValidationError.invalidShareNumberRange
        }
        return number
    }
}
