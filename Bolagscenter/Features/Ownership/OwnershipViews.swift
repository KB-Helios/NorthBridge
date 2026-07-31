import SwiftData
import SwiftUI

private enum OwnershipSheet: Identifiable {
    case shareholder
    case shareClass

    var id: String {
        switch self {
        case .shareholder: "shareholder"
        case .shareClass: "shareClass"
        }
    }
}

@MainActor
struct OwnershipOverviewView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \ShareholderRecord.displayName) private var shareholders: [ShareholderRecord]
    @Query(sort: \ShareClassRecord.name) private var shareClasses: [ShareClassRecord]
    @Query(sort: \ShareTransactionRecord.transactionDate, order: .reverse) private var transactions: [ShareTransactionRecord]

    @State private var presentedSheet: OwnershipSheet?

    var body: some View {
        List {
            if environment.selectedCompanyID == nil {
                EmptyStateView(
                    systemImage: "building.2",
                    title: "Inget bolag valt",
                    message: "Välj ett bolag för att öppna ägararbetsytan."
                )
            } else {
                Section("Ägarbild") {
                    if activeShareholders.isEmpty {
                        Text("Inga aktieägare registrerade")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeShareholders) { shareholder in
                            let quantity = shares(for: shareholder.id)
                            LabeledContent {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(quantity) aktier")
                                    Text(ownershipPercentage(for: shareholder.id), format: .percent.precision(.fractionLength(1)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(shareholder.displayName)
                                    Text(shareholder.shareholderKind.localizedName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Aktieslag") {
                    if companyShareClasses.isEmpty {
                        Text("Inga aktieslag registrerade")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(companyShareClasses) { shareClass in
                            LabeledContent(shareClass.name) {
                                Text("\(shareClass.votesPerShare.formatted()) röst/aktie")
                            }
                        }
                    }
                }

                Section("Aktiebok") {
                    NavigationLink(value: AppRoute.shareholderRegister) {
                        Label("Öppna aktiebok", systemImage: "book.pages")
                    }
                    NavigationLink(value: AppRoute.shareCertificates) {
                        Label("Aktiebrev", systemImage: "doc.badge.gearshape")
                    }
                    NavigationLink(value: AppRoute.addShareTransaction) {
                        Label("Registrera aktiehändelse", systemImage: "arrow.left.arrow.right")
                    }
                }

                Section("Senaste historik") {
                    if companyTransactions.isEmpty {
                        Text("Inga aktiehändelser registrerade")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(companyTransactions.prefix(8)) { transaction in
                            ShareTransactionRow(
                                transaction: transaction,
                                shareClassName: shareClassName(for: transaction.shareClassID),
                                fromName: shareholderName(for: transaction.fromShareholderID),
                                toName: shareholderName(for: transaction.toShareholderID)
                            )
                        }
                    }
                }

                Section {
                    Text("Innehav beräknas från append-only historiska aktiehändelser. En rättelse skapar en ny post och skriver aldrig över tidigare ägarhistorik.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Ägare")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Lägg till aktieägare", systemImage: "person.badge.plus") {
                        presentedSheet = .shareholder
                    }
                    Button("Lägg till aktieslag", systemImage: "square.stack.3d.up") {
                        presentedSheet = .shareClass
                    }
                    Button("Registrera aktiehändelse", systemImage: "arrow.left.arrow.right") {
                        router.navigate(to: .addShareTransaction)
                    }
                } label: {
                    Label("Lägg till", systemImage: "plus")
                }
                .accessibilityIdentifier("ownership.add")
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .shareholder:
                ShareholderEditorView()
            case .shareClass:
                ShareClassEditorView()
            }
        }
    }

    private var activeShareholders: [ShareholderRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return shareholders.filter { $0.companyID == companyID && $0.archivedAt == nil }
    }

    private var companyShareClasses: [ShareClassRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return shareClasses.filter { $0.companyID == companyID }
    }

    private var companyTransactions: [ShareTransactionRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return transactions.filter { $0.companyID == companyID }
    }

    private var positions: [SharePosition] {
        OwnershipLedger().positions(from: companyTransactions.map(\.snapshot))
    }

    private var totalShares: Int {
        positions.reduce(0) { $0 + max(0, $1.quantity) }
    }

    private func shares(for shareholderID: UUID) -> Int {
        positions
            .filter { $0.shareholderID == shareholderID }
            .reduce(0) { $0 + $1.quantity }
    }

    private func ownershipPercentage(for shareholderID: UUID) -> Double {
        guard totalShares > 0 else { return 0 }
        return Double(shares(for: shareholderID)) / Double(totalShares)
    }

    private func shareholderName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return shareholders.first { $0.id == id }?.displayName
    }

    private func shareClassName(for id: UUID) -> String {
        shareClasses.first { $0.id == id }?.name ?? String(localized: "Okänt aktieslag")
    }

    private var router: RouterPath {
        environment.router(for: environment.selectedTab)
    }
}

private struct ShareTransactionRow: View {
    let transaction: ShareTransactionRecord
    let shareClassName: String
    let fromName: String?
    let toName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(transaction.kind.localizedName)
                    .font(.body.weight(.semibold))
                Spacer()
                Text(transaction.transactionDate, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(transaction.quantity) \(shareClassName)")
                .font(.subheadline)
            Text(partiesDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Underlag: \(transaction.reference)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var partiesDescription: String {
        switch (fromName, toName) {
        case (nil, let recipient?):
            "Till \(recipient)"
        case (let sender?, nil):
            "Från \(sender)"
        case (let sender?, let recipient?):
            "\(sender) → \(recipient)"
        case (nil, nil):
            "Parter saknas"
        }
    }
}

@MainActor
private struct ShareholderEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var displayName = ""
    @State private var kind: ShareholderKind = .person
    @State private var identityReference = ""
    @State private var email = ""
    @State private var postalAddress = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Aktieägare") {
                    TextField("Namn", text: $displayName)
                        .textContentType(.name)
                        .accessibilityIdentifier("ownership.shareholder.name")
                    Picker("Typ", selection: $kind) {
                        ForEach(ShareholderKind.allCases) { kind in
                            Text(kind.localizedName).tag(kind)
                        }
                    }
                    TextField(
                        kind == .person ? "Personnummer eller referens" : "Organisationsnummer eller referens",
                        text: $identityReference
                    )
                    .privacySensitive()
                    TextField("E-postadress", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    TextField("Postadress", text: $postalAddress, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Text("Person- och organisationsnummer lagras som användarregistrerat underlag tills en behörig verifieringskälla är ansluten.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Ny aktieägare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("ownership.shareholder.save")
                }
            }
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
              environment.permissionPolicy.allows(.manageOwnership, for: role) else {
            errorMessage = String(localized: "Din roll saknar behörighet att lägga till aktieägare.")
            return
        }
        let shareholder = ShareholderRecord(
            companyID: companyID,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            shareholderKind: kind,
            identityReference: identityReference.nilIfBlank,
            email: email.nilIfBlank,
            postalAddress: postalAddress.nilIfBlank
        )
        modelContext.insert(shareholder)
        modelContext.insert(
            AuditEventRecord(
                companyID: companyID,
                accountID: accountID,
                action: "ownership.shareholder.created",
                entityType: "shareholder",
                entityID: shareholder.id,
                summary: String(localized: "Aktieägare lades till: \(shareholder.displayName)")
            )
        )
        persistAndDismiss(error: "Aktieägaren kunde inte sparas.")
    }

    private func persistAndDismiss(error message: String) {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = message
        }
    }
}

@MainActor
private struct ShareClassEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var name = "A"
    @State private var votesPerShare = 1.0
    @State private var nominalValueText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Aktieslag") {
                    TextField("Benämning", text: $name)
                    TextField("Röster per aktie", value: $votesPerShare, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Kvotvärde, SEK (valfritt)", text: $nominalValueText)
                        .keyboardType(.decimalPad)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Nytt aktieslag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || votesPerShare <= 0)
                }
            }
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
              environment.permissionPolicy.allows(.manageOwnership, for: role) else {
            errorMessage = String(localized: "Din roll saknar behörighet att skapa aktieslag.")
            return
        }
        let shareClass = ShareClassRecord(
            companyID: companyID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            votesPerShare: votesPerShare,
            nominalValue: DecimalInputParser.double(from: nominalValueText)
        )
        modelContext.insert(shareClass)
        modelContext.insert(
            AuditEventRecord(
                companyID: companyID,
                accountID: accountID,
                action: "ownership.shareClass.created",
                entityType: "shareClass",
                entityID: shareClass.id,
                summary: String(localized: "Aktieslag skapades: \(shareClass.name)")
            )
        )
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Aktieslaget kunde inte sparas.")
        }
    }
}

@MainActor
struct ShareTransactionEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShareholderRecord.displayName) private var shareholders: [ShareholderRecord]
    @Query(sort: \ShareClassRecord.name) private var shareClasses: [ShareClassRecord]
    @Query(sort: \ShareTransactionRecord.transactionDate) private var transactions: [ShareTransactionRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var kind: ShareTransactionKind = .issuance
    @State private var shareClassID: UUID?
    @State private var fromShareholderID: UUID?
    @State private var toShareholderID: UUID?
    @State private var quantity = 1
    @State private var transactionDate = Date.now
    @State private var reference = ""
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if companyShareholders.isEmpty || companyShareClasses.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("Underlag saknas", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("Lägg först till minst en aktieägare och ett aktieslag.")
                    }
                }
            } else {
                Section("Aktiehändelse") {
                    Picker("Typ", selection: $kind) {
                        ForEach(ShareTransactionKind.allCases) { kind in
                            Text(kind.localizedName).tag(kind)
                        }
                    }
                    Picker("Aktieslag", selection: $shareClassID) {
                        Text("Välj aktieslag").tag(UUID?.none)
                        ForEach(companyShareClasses) { shareClass in
                            Text(shareClass.name).tag(UUID?.some(shareClass.id))
                        }
                    }

                    if kind != .issuance {
                        Picker("Från", selection: $fromShareholderID) {
                            Text("Välj överlåtare").tag(UUID?.none)
                            ForEach(companyShareholders) { shareholder in
                                Text(shareholder.displayName).tag(UUID?.some(shareholder.id))
                            }
                        }
                    }
                    if kind != .redemption {
                        Picker("Till", selection: $toShareholderID) {
                            Text("Välj mottagare").tag(UUID?.none)
                            ForEach(companyShareholders) { shareholder in
                                Text(shareholder.displayName).tag(UUID?.some(shareholder.id))
                            }
                        }
                    }
                    Stepper("Antal: \(quantity)", value: $quantity, in: 1...10_000_000)
                    DatePicker("Händelsedatum", selection: $transactionDate, displayedComponents: .date)
                }

                Section {
                    TextField("Underlag eller referens", text: $reference)
                    TextField("Anteckningar", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text("Spårbarhet")
                } footer: {
                    Text("Sparade aktiehändelser kan inte redigeras. Registrera en rättelsepost om historiken behöver korrigeras.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Registrera aktiehändelse") { save() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("ownership.transaction.save")
                }
            }
        }
        .navigationTitle("Ny aktiehändelse")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if shareClassID == nil {
                shareClassID = companyShareClasses.first?.id
            }
        }
        .onChange(of: kind) { _, newKind in
            if newKind == .issuance {
                fromShareholderID = nil
            }
            if newKind == .redemption {
                toShareholderID = nil
            }
        }
    }

    private var companyShareholders: [ShareholderRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return shareholders.filter { $0.companyID == companyID && $0.archivedAt == nil }
    }

    private var companyShareClasses: [ShareClassRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return shareClasses.filter { $0.companyID == companyID }
    }

    private var companyTransactions: [ShareTransactionRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return transactions.filter { $0.companyID == companyID }
    }

    private var isValid: Bool {
        shareClassID != nil
            && quantity > 0
            && !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageOwnership, for: role) else {
            errorMessage = String(localized: "Din roll saknar behörighet att registrera aktiehändelser.")
            return
        }
        guard let shareClassID else {
            errorMessage = String(localized: "Välj ett aktieslag.")
            return
        }

        let snapshot = ShareTransactionSnapshot(
            shareClassID: shareClassID,
            fromShareholderID: fromShareholderID,
            toShareholderID: toShareholderID,
            quantity: quantity,
            kind: kind
        )
        do {
            try OwnershipLedger().validate(
                snapshot,
                existing: companyTransactions.map(\.snapshot)
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let transaction = ShareTransactionRecord(
            companyID: companyID,
            shareClassID: shareClassID,
            fromShareholderID: fromShareholderID,
            toShareholderID: toShareholderID,
            quantity: quantity,
            kind: kind,
            transactionDate: transactionDate,
            reference: reference.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(transaction)
        modelContext.insert(
            AuditEventRecord(
                companyID: companyID,
                accountID: accountID,
                action: "ownership.transaction.created",
                entityType: "shareTransaction",
                entityID: transaction.id,
                summary: String(localized: "Aktiehändelse registrerades: \(transaction.kind.localizedName), \(transaction.quantity) aktier.")
            )
        )

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Aktiehändelsen kunde inte sparas.")
        }
    }
}

@MainActor
struct ShareholderRegisterView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query private var companies: [CompanyRecord]
    @Query(sort: \ShareholderRecord.displayName) private var shareholders: [ShareholderRecord]
    @Query(sort: \ShareClassRecord.name) private var shareClasses: [ShareClassRecord]
    @Query(sort: \ShareTransactionRecord.transactionDate) private var transactions: [ShareTransactionRecord]
    @Query private var documents: [DocumentRecord]
    @Query private var versions: [DocumentVersionRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var exportedFileURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Aktieinnehav") {
                if registerRows.isEmpty {
                    Text("Inga innehav kan visas innan aktiehändelser har registrerats.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(registerRows) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(row.shareholderName)
                                .font(.body.weight(.semibold))
                            HStack {
                                Text("\(row.quantity) \(row.shareClassName)")
                                Spacer()
                                Text(row.ownershipPercentage, format: .percent.precision(.fractionLength(1)))
                            }
                            .font(.subheadline)
                            Text("Röstandel \(row.votingPercentage.formatted(.percent.precision(.fractionLength(1))))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            Section("Sammanställning") {
                LabeledContent("Totalt antal aktier", value: totalShares.formatted())
                LabeledContent(
                    "Totalt antal röster",
                    value: totalVotes.formatted(.number.precision(.fractionLength(0...2)))
                )
            }

            Section("Export") {
                Button("Skapa PDF av aktieboken", systemImage: "doc.richtext") {
                    exportRegister()
                }
                if let exportedFileURL {
                    ShareLink(item: exportedFileURL) {
                        Label("Dela senaste exporten", systemImage: "square.and.arrow.up")
                    }
                }
                Text("PDF-exporten skapas från den historik som är registrerad i NorthBridge och måste kontrolleras mot bolagets underlag.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Historik") {
                ForEach(companyTransactions.reversed()) { transaction in
                    ShareTransactionRow(
                        transaction: transaction,
                        shareClassName: shareClassName(for: transaction.shareClassID),
                        fromName: shareholderName(for: transaction.fromShareholderID),
                        toName: shareholderName(for: transaction.toShareholderID)
                    )
                }
            }
        }
        .navigationTitle("Aktiebok")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Exporten kunde inte skapas", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private struct RegisterRow: Identifiable {
        let shareholderID: UUID
        let shareClassID: UUID
        let shareholderName: String
        let identityReference: String
        let shareClassName: String
        let quantity: Int
        let ownershipPercentage: Double
        let votingPercentage: Double

        var id: String {
            "\(shareholderID.uuidString):\(shareClassID.uuidString)"
        }
    }

    private var companyTransactions: [ShareTransactionRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return transactions.filter { $0.companyID == companyID }
    }

    private var positions: [SharePosition] {
        OwnershipLedger().positions(from: companyTransactions.map(\.snapshot))
            .filter { $0.quantity > 0 }
    }

    private var totalShares: Int {
        positions.reduce(0) { $0 + $1.quantity }
    }

    private var totalVotes: Double {
        positions.reduce(0) { result, position in
            let weight = shareClasses.first { $0.id == position.shareClassID }?.votesPerShare ?? 0
            return result + (Double(position.quantity) * weight)
        }
    }

    private var registerRows: [RegisterRow] {
        positions.compactMap { position in
            guard let shareholder = shareholders.first(where: { $0.id == position.shareholderID }),
                  let shareClass = shareClasses.first(where: { $0.id == position.shareClassID }) else {
                return nil
            }
            let votes = Double(position.quantity) * shareClass.votesPerShare
            return RegisterRow(
                shareholderID: shareholder.id,
                shareClassID: shareClass.id,
                shareholderName: shareholder.displayName,
                identityReference: shareholder.identityReference ?? "",
                shareClassName: shareClass.name,
                quantity: position.quantity,
                ownershipPercentage: totalShares > 0 ? Double(position.quantity) / Double(totalShares) : 0,
                votingPercentage: totalVotes > 0 ? votes / totalVotes : 0
            )
        }
        .sorted { lhs, rhs in
            if lhs.shareholderName == rhs.shareholderName {
                lhs.shareClassName < rhs.shareClassName
            } else {
                lhs.shareholderName.localizedStandardCompare(rhs.shareholderName) == .orderedAscending
            }
        }
    }

    private func exportRegister() {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.exportData, for: role),
              let company = companies.first(where: { $0.id == companyID }) else {
            errorMessage = String(localized: "Du saknar behörighet eller bolagsunderlag för exporten.")
            return
        }

        var generatedURL: URL?
        do {
            let input = ShareholderRegisterPDFInput(
                companyID: companyID,
                companyName: company.registeredName,
                organisationNumber: company.organisationNumber,
                generatedAt: .now,
                rows: registerRows.map {
                    ShareholderRegisterRow(
                        shareholderName: $0.shareholderName,
                        identityReference: $0.identityReference,
                        shareClassName: $0.shareClassName,
                        quantity: $0.quantity,
                        ownershipPercentage: $0.ownershipPercentage,
                        votingPercentage: $0.votingPercentage
                    )
                },
                totalShares: totalShares,
                totalVotes: totalVotes
            )
            let fileURL = try GovernancePDFExporter.exportShareholderRegister(input)
            generatedURL = fileURL
            let title = String(localized: "Aktiebok – \(company.registeredName)")
            let sourceName = String(localized: "Genererat i NorthBridge")
            let vaultResult = try GeneratedDocumentVaultService().recordPDF(
                companyID: companyID,
                title: title,
                category: .shareholderRegister,
                fileURL: fileURL,
                sourceName: sourceName,
                documents: documents,
                versions: versions,
                in: modelContext
            )
            modelContext.insert(
                AuditEventRecord(
                    companyID: companyID,
                    accountID: accountID,
                    action: "ownership.register.exported",
                    entityType: "shareholderRegister",
                    entityID: vaultResult.document.id,
                    summary: String(localized: "Aktieboken exporterades som PDF.")
                )
            )
            try modelContext.save()
            exportedFileURL = fileURL
        } catch {
            modelContext.rollback()
            if let generatedURL {
                try? FileManager.default.removeItem(at: generatedURL)
            }
            errorMessage = error.localizedDescription
        }
    }

    private func shareholderName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return shareholders.first { $0.id == id }?.displayName
    }

    private func shareClassName(for id: UUID) -> String {
        shareClasses.first { $0.id == id }?.name ?? String(localized: "Okänt aktieslag")
    }
}

private enum DecimalInputParser {
    static func double(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.number(from: trimmed)?.doubleValue
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
