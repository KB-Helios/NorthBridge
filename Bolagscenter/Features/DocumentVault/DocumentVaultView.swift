import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

@MainActor
struct DocumentVaultView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DocumentRecord.importedAt, order: .reverse) private var allDocuments: [DocumentRecord]
    @Query private var versions: [DocumentVersionRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var isImporting = false
    @State private var scannerSession: DocumentScannerSession?
    @State private var pendingImport: PendingDocumentImport?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    #if DEBUG
    @State private var didPresentUITestImport = false
    #endif

    private let processingService = DocumentProcessingService()

    var body: some View {
        Group {
            if filteredDocuments.isEmpty {
                EmptyStateView(
                    systemImage: "doc.text.magnifyingglass",
                    title: searchText.isEmpty ? "Inga dokument" : "Inga sökträffar",
                    message: searchText.isEmpty
                        ? "Skanna eller importera PDF-filer och bilder till bolagets säkra dokumentvalv."
                        : "Prova ett annat sökord.",
                    actionTitle: searchText.isEmpty ? "Importera dokument" : nil,
                    action: searchText.isEmpty ? { isImporting = true } : nil
                )
            } else {
                List(filteredDocuments) { document in
                    NavigationLink(value: AppRoute.document(document.id)) {
                        HStack(spacing: 12) {
                            Image(systemName: document.isFavorite ? "star.fill" : "doc.text")
                                .foregroundStyle(document.isFavorite ? Color.orange : Color.bolagscenterBlue)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.title)
                                HStack(spacing: 5) {
                                    Text(document.category.localizedName)
                                    if let pageCount = document.pageCount {
                                        Text("· \(pageCount) sidor")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(document.importedAt, format: .dateTime.day().month())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            document.isFavorite.toggle()
                            document.lastModifiedAt = .now
                            saveContext()
                        } label: {
                            Label(
                                document.isFavorite ? "Ta bort favorit" : "Favorit",
                                systemImage: document.isFavorite ? "star.slash" : "star"
                            )
                        }
                        .tint(.orange)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Dokument")
        .searchable(text: $searchText, prompt: "Sök dokument")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Skanna dokument", systemImage: "doc.viewfinder") {
                        scannerSession = DocumentScannerSession()
                    }
                    .disabled(!VNDocumentCameraViewController.isSupported)
                    Button("Importera fil", systemImage: "square.and.arrow.down") {
                        isImporting = true
                    }
                } label: {
                    Label("Lägg till dokument", systemImage: "plus")
                }
            }
        }
        .overlay {
            if isAnalyzing {
                ZStack {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                    ProgressView("Analyserar dokument på enheten")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityElement(children: .combine)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .fullScreenCover(item: $scannerSession) { _ in
            DocumentScannerView(
                onComplete: { pages in
                    scannerSession = nil
                    handleScannedPages(pages)
                },
                onCancel: {
                    scannerSession = nil
                },
                onError: { error in
                    scannerSession = nil
                    errorMessage = error.localizedDescription
                }
            )
            .ignoresSafeArea()
        }
        .sheet(item: $pendingImport) { item in
            DocumentMetadataReviewView(item: item) { metadata in
                persist(item, metadata: metadata)
            }
        }
        .alert("Dokumentåtgärden misslyckades", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            consumePendingAction()
            #if DEBUG
            presentUITestDocumentIfNeeded()
            #endif
        }
        .onChange(of: environment.pendingDocumentAction) { _, _ in
            consumePendingAction()
        }
    }

    private var documents: [DocumentRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return allDocuments.filter { $0.companyID == companyID }
    }

    private var filteredDocuments: [DocumentRecord] {
        guard !searchText.isEmpty else { return documents }
        return documents.filter {
            $0.title.localizedStandardContains(searchText)
                || $0.category.localizedName.localizedStandardContains(searchText)
                || $0.tags.localizedStandardContains(searchText)
                || ($0.extractedText?.localizedStandardContains(searchText) == true)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                throw DocumentImportError.permissionDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else { throw DocumentImportError.emptyFile }
            let values = try url.resourceValues(forKeys: [.contentTypeKey])
            guard let contentType = values.contentType else {
                throw DocumentImportError.unsupportedType
            }
            analyze(
                data: data,
                originalFilename: url.lastPathComponent,
                typeIdentifier: contentType.identifier,
                fallbackTitle: url.deletingPathExtension().lastPathComponent
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleScannedPages(_ pages: [Data]) {
        guard !pages.isEmpty else {
            errorMessage = String(localized: "Skanningen innehöll inga sidor.")
            return
        }
        do {
            let data = try DocumentProcessingService.makePDF(from: pages)
            let timestamp = Date.now.ISO8601Format()
                .prefix(19)
                .replacingOccurrences(of: ":", with: "-")
            analyze(
                data: data,
                originalFilename: "Skanning-\(timestamp).pdf",
                typeIdentifier: UTType.pdf.identifier,
                fallbackTitle: String(localized: "Skannat dokument")
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func analyze(
        data: Data,
        originalFilename: String,
        typeIdentifier: String,
        fallbackTitle: String
    ) {
        isAnalyzing = true
        Task {
            defer { isAnalyzing = false }
            do {
                let analysis = try await processingService.analyze(
                    data: data,
                    typeIdentifier: typeIdentifier
                )
                let suggestedTitle = analysis.suggestedTitle == String(localized: "Skannat dokument")
                    ? fallbackTitle
                    : analysis.suggestedTitle
                pendingImport = PendingDocumentImport(
                    suggestedTitle: suggestedTitle,
                    originalFilename: originalFilename,
                    typeIdentifier: typeIdentifier,
                    data: data,
                    analysis: analysis
                )
            } catch {
                errorMessage = String(localized: "Dokumentet kunde inte analyseras: \(error.localizedDescription)")
            }
        }
    }

    private func persist(
        _ item: PendingDocumentImport,
        metadata: ApprovedDocumentMetadata
    ) {
        guard let companyID = environment.selectedCompanyID,
              let accountID = environment.sessionController.activeSession?.accountID,
              let role = ActiveCompanyAccess.role(
                companyID: companyID,
                accountID: accountID,
                memberships: memberships
              ),
              environment.permissionPolicy.allows(.manageDocuments, for: role) else {
            errorMessage = String(localized: "Din roll saknar behörighet att importera dokument.")
            return
        }

        do {
            let documentsDirectory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let companyDirectory = documentsDirectory
                .appending(path: "Documents", directoryHint: .isDirectory)
                .appending(path: companyID.uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(
                at: companyDirectory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            let storedURL = companyDirectory.appending(
                path: "\(UUID().uuidString)-\(item.originalFilename)"
            )
            try item.data.write(to: storedURL, options: [.atomic, .completeFileProtection])
            let bookmark = try storedURL.bookmarkData()

            let document = DocumentRecord(
                companyID: companyID,
                title: metadata.title,
                category: metadata.category,
                fileBookmark: bookmark,
                originalFilename: item.originalFilename,
                uniformTypeIdentifier: item.typeIdentifier,
                extractedText: item.analysis.extractedText.nilIfBlank,
                detectedOrganisationNumbers: item.analysis.detectedOrganisationNumbers
                    .joined(separator: ", ")
                    .nilIfBlank,
                detectedParties: item.analysis.detectedParties
                    .joined(separator: "\n")
                    .nilIfBlank,
                tags: metadata.tags,
                pageCount: item.analysis.pageCount,
                sourceName: String(localized: "Importerad fil"),
                expiresAt: metadata.expiresAt
            )
            let version = DocumentVersionRecord(
                companyID: companyID,
                documentID: document.id,
                versionNumber: 1,
                fileBookmark: bookmark,
                sourceName: document.sourceName
            )
            let audit = AuditEventRecord(
                companyID: companyID,
                accountID: accountID,
                action: "document.imported",
                entityType: "document",
                entityID: document.id,
                summary: String(localized: "Dokument importerades: \(document.title)")
            )
            modelContext.insert(document)
            modelContext.insert(version)
            modelContext.insert(audit)
            try modelContext.save()
            pendingImport = nil
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "Dokumentet kunde inte sparas säkert.")
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = String(localized: "Ändringen kunde inte sparas.")
        }
    }

    private func consumePendingAction() {
        guard let action = environment.consumePendingDocumentAction() else { return }
        switch action {
        case .importFile:
            isImporting = true
        case .scan:
            guard VNDocumentCameraViewController.isSupported else {
                errorMessage = String(localized: "Dokumentskanning stöds inte på den här enheten.")
                return
            }
            scannerSession = DocumentScannerSession()
        }
    }

    #if DEBUG
    private func presentUITestDocumentIfNeeded() {
        guard UITestLaunchConfiguration.importsFixtureDocument,
              !didPresentUITestImport else {
            return
        }
        didPresentUITestImport = true

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 595, height: 842)
        )
        let data = renderer.pdfData { context in
            context.beginPage()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .title1),
                .foregroundColor: UIColor.label
            ]
            NSString(string: "NorthBridge UI-testdokument").draw(
                at: CGPoint(x: 48, y: 64),
                withAttributes: attributes
            )
        }
        pendingImport = PendingDocumentImport(
            suggestedTitle: "UI-testdokument",
            originalFilename: "ui-testdokument.pdf",
            typeIdentifier: UTType.pdf.identifier,
            data: data,
            analysis: DocumentAnalysis(
                extractedText: "NorthBridge UI-testdokument",
                detectedOrganisationNumbers: ["5560160680"],
                detectedDates: [],
                detectedParties: ["Nordisk Test AB"],
                suggestedTitle: "UI-testdokument",
                suggestedCategory: .other,
                pageCount: 1
            )
        )
    }
    #endif
}

struct PendingDocumentImport: Identifiable {
    let id = UUID()
    let suggestedTitle: String
    let originalFilename: String
    let typeIdentifier: String
    let data: Data
    let analysis: DocumentAnalysis
}

struct ApprovedDocumentMetadata {
    let title: String
    let category: DocumentCategory
    let tags: String
    let expiresAt: Date?
}

private enum DocumentImportError: LocalizedError {
    case permissionDenied
    case emptyFile
    case unsupportedType

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "NorthBridge fick inte åtkomst till den valda filen."
        case .emptyFile:
            "Den valda filen är tom."
        case .unsupportedType:
            "Filtypen kunde inte identifieras."
        }
    }
}

private struct DocumentMetadataReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let item: PendingDocumentImport
    let onApprove: (ApprovedDocumentMetadata) -> Void

    @State private var title: String
    @State private var category: DocumentCategory
    @State private var tags = ""
    @State private var hasExpiration = false
    @State private var expiresAt = Date.now.addingTimeInterval(86_400 * 30)

    init(
        item: PendingDocumentImport,
        onApprove: @escaping (ApprovedDocumentMetadata) -> Void
    ) {
        self.item = item
        self.onApprove = onApprove
        _title = State(initialValue: item.suggestedTitle)
        _category = State(initialValue: item.analysis.suggestedCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Granska metadata") {
                    TextField("Titel", text: $title)
                        .accessibilityIdentifier("document.metadata.title")
                    Picker("Kategori", selection: $category) {
                        ForEach(DocumentCategory.allCases) { category in
                            Text(category.localizedName).tag(category)
                        }
                    }
                    TextField("Taggar, separerade med komma", text: $tags)
                    Toggle("Dokumentet har ett utgångsdatum", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("Giltigt till", selection: $expiresAt, displayedComponents: .date)
                    }
                }

                Section("Filinformation") {
                    LabeledContent("Fil", value: item.originalFilename)
                    LabeledContent(
                        "Storlek",
                        value: ByteCountFormatter.string(
                            fromByteCount: Int64(item.data.count),
                            countStyle: .file
                        )
                    )
                    LabeledContent("Sidor", value: item.analysis.pageCount.formatted())
                }

                if !item.analysis.detectedOrganisationNumbers.isEmpty {
                    Section("Identifierade organisationsnummer") {
                        ForEach(item.analysis.detectedOrganisationNumbers, id: \.self) {
                            Text($0)
                                .monospacedDigit()
                        }
                    }
                }

                if !item.analysis.detectedDates.isEmpty {
                    Section {
                        ForEach(item.analysis.detectedDates, id: \.self) {
                            Text($0)
                        }
                    } header: {
                        Text("Möjliga datum")
                    } footer: {
                        Text("Datumen blir inte deadlines förrän du uttryckligen skapar och bekräftar en deadline.")
                    }
                }

                if !item.analysis.detectedParties.isEmpty {
                    Section {
                        ForEach(item.analysis.detectedParties, id: \.self) {
                            Text($0)
                        }
                    } header: {
                        Text("Möjliga parter")
                    } footer: {
                        Text("Parterna är OCR-förslag. Kontrollera dem mot dokumentet innan metadata godkänns.")
                    }
                }

                if !item.analysis.extractedText.isEmpty {
                    Section("OCR-förhandsvisning") {
                        Text(item.analysis.extractedText)
                            .font(.footnote)
                            .lineLimit(12)
                            .textSelection(.enabled)
                    }
                } else {
                    Section {
                        Label("Ingen läsbar text identifierades", systemImage: "text.magnifyingglass")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Bekräfta dokument")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importera") {
                        onApprove(
                            ApprovedDocumentMetadata(
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                category: category,
                                tags: tags.trimmingCharacters(in: .whitespacesAndNewlines),
                                expiresAt: hasExpiration ? expiresAt : nil
                            )
                        )
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("document.import.confirm")
                }
            }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
