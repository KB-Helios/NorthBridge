import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

@MainActor
struct DocumentVaultView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \DocumentRecord.importedAt, order: .reverse) private var allDocuments: [DocumentRecord]
    @Query private var versions: [DocumentVersionRecord]
    @Query private var memberships: [CompanyMembershipRecord]

    @State private var isImporting = false
    @State private var scannerSession: DocumentScannerSession?
    @State private var pendingImport: PendingDocumentImport?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @AppStorage("northbridge.documents.filter") private var filterRawValue = DocumentWorkspaceFilter.all.rawValue
    @AppStorage("northbridge.documents.sort") private var sortRawValue = DocumentWorkspaceSort.newest.rawValue
    #if DEBUG
    @State private var didPresentUITestImport = false
    #endif

    private let processingService = DocumentProcessingService()
    private let transitionNamespace: Namespace.ID?

    init(transitionNamespace: Namespace.ID? = nil) {
        self.transitionNamespace = transitionNamespace
    }

    var body: some View {
        let displayedDocuments = visibleDocuments

        List {
            documentWorkspaceHero
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if !documents.isEmpty {
                workspaceControls
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if displayedDocuments.isEmpty {
                NorthBridgeEmptyState(
                    systemImage: documents.isEmpty ? "doc.badge.plus" : "doc.text.magnifyingglass",
                    title: documents.isEmpty ? "Dokumentvalvet är redo" : "Inga dokument matchar",
                    message: documents.isEmpty
                        ? "Skanna eller importera PDF-filer och bilder. Analysen sker på enheten."
                        : "Justera sökningen eller välj ett annat filter.",
                    compact: true,
                    actionTitle: documents.isEmpty ? "Importera dokument" : "Rensa filter",
                    action: documents.isEmpty ? { isImporting = true } : resetFilters
                )
                .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else if presentation == .list {
                ForEach(displayedDocuments) { document in
                    documentListLink(document)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading) {
                            favoriteButton(for: document)
                        }
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220, maximum: 340), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(displayedDocuments) { document in
                        documentGridLink(document)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 20, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.northBridgeBackground)
        .navigationTitle("Dokument")
        .searchable(text: $searchText, prompt: "Sök dokument")
        .accessibilityIdentifier("documents.workspace.root")
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
                    Color.black.opacity(0.16)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.northBridgeBlue)
                        Text("Analyserar dokument på enheten")
                            .font(.subheadline.weight(.semibold))
                        Text("Innehållet lämnar inte enheten.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(22)
                    .bolagscenterGlassSurface(
                        cornerRadius: NorthBridgeRadius.card,
                        tint: Color.northBridgeGlassTint
                    )
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

    private var documentWorkspaceHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Säkert dokumentvalv", systemImage: "lock.shield.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    Text("Samla, hitta och granska")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(documentCountSummary)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                }
                Spacer(minLength: 0)
                Image(systemName: "doc.text.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            HStack(spacing: 10) {
                Button {
                    scannerSession = DocumentScannerSession()
                } label: {
                    Label("Skanna", systemImage: "doc.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(Color.northBridgeNavy)
                .disabled(!VNDocumentCameraViewController.isSupported)
                .accessibilityIdentifier("documents.scan")

                Button {
                    isImporting = true
                } label: {
                    Label("Importera", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .foregroundStyle(.white)
                .accessibilityIdentifier("documents.import")
            }
            .controlSize(.large)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [.northBridgeNavy, .northBridgeBlue.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: NorthBridgeRadius.hero, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }

    private var workspaceControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                NorthBridgeSectionHeader("Ordna dokument")
                Spacer(minLength: 8)
                sortMenu
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    NorthBridgeFilterChip(
                        "Alla",
                        isSelected: filterRawValue == DocumentWorkspaceFilter.all.rawValue,
                        count: documents.count
                    ) {
                        filterRawValue = DocumentWorkspaceFilter.all.rawValue
                    }
                    NorthBridgeFilterChip(
                        "Favoriter",
                        systemImage: "star.fill",
                        isSelected: filterRawValue == DocumentWorkspaceFilter.favorites.rawValue,
                        count: documents.lazy.filter(\.isFavorite).count
                    ) {
                        filterRawValue = DocumentWorkspaceFilter.favorites.rawValue
                    }
                    ForEach(availableCategories) { category in
                        NorthBridgeFilterChip(
                            LocalizedStringKey(category.localizedName),
                            systemImage: category.systemImage,
                            isSelected: filterRawValue == DocumentWorkspaceFilter.category(category),
                            count: documents.lazy.filter { $0.category == category }.count
                        ) {
                            filterRawValue = DocumentWorkspaceFilter.category(category)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 8) {
                Text("Visning")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.northBridgeTextSecondary)
                Spacer()
                presentationButton(.list)
                presentationButton(.grid)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sortera dokument", selection: sortBinding) {
                ForEach(DocumentWorkspaceSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.systemImage)
                        .tag(sort)
                }
            }
        } label: {
            Label(sort.title, systemImage: "arrow.up.arrow.down")
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityIdentifier("documents.sort")
    }

    private func presentationButton(_ option: NorthBridgeDocumentPresentation) -> some View {
        Button {
            withAnimation(selectionAnimation) {
                environment.presentationPreferences.documentPresentation = option
            }
        } label: {
            Label(option.title, systemImage: option.systemImage)
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 38)
                .foregroundStyle(presentation == option ? Color.white : Color.northBridgeTextSecondary)
                .background(
                    presentation == option ? Color.northBridgeBlue : Color.northBridgeRecessedSurface,
                    in: RoundedRectangle(cornerRadius: NorthBridgeRadius.control, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(presentation == option ? .isSelected : [])
        .accessibilityIdentifier("documents.presentation.\(option.rawValue)")
    }

    private func documentListLink(_ document: DocumentRecord) -> some View {
        NavigationLink(value: AppRoute.document(document.id)) {
            DocumentWorkspaceRow(document: document)
                .documentMatchedTransitionSource(
                    id: document.id,
                    namespace: transitionNamespace
                )
        }
        .buttonStyle(.plain)
        .contextMenu { favoriteButton(for: document) }
    }

    private func documentGridLink(_ document: DocumentRecord) -> some View {
        NavigationLink(value: AppRoute.document(document.id)) {
            DocumentWorkspaceCard(document: document)
                .documentMatchedTransitionSource(
                    id: document.id,
                    namespace: transitionNamespace
                )
        }
        .buttonStyle(.plain)
        .contextMenu { favoriteButton(for: document) }
    }

    private func favoriteButton(for document: DocumentRecord) -> some View {
        Button {
            document.isFavorite.toggle()
            document.lastModifiedAt = .now
            saveContext()
        } label: {
            Label(
                document.isFavorite ? "Ta bort favorit" : "Markera som favorit",
                systemImage: document.isFavorite ? "star.slash" : "star"
            )
        }
        .tint(.orange)
    }

    private var documents: [DocumentRecord] {
        guard let companyID = environment.selectedCompanyID else { return [] }
        return allDocuments.filter { $0.companyID == companyID }
    }

    private var visibleDocuments: [DocumentRecord] {
        var output = documents
        if !searchText.isEmpty {
            output = output.filter {
                $0.title.localizedStandardContains(searchText)
                    || $0.category.localizedName.localizedStandardContains(searchText)
                    || $0.tags.localizedStandardContains(searchText)
                    || ($0.extractedText?.localizedStandardContains(searchText) == true)
            }
        }

        if filterRawValue == DocumentWorkspaceFilter.favorites.rawValue {
            output = output.filter(\.isFavorite)
        } else if let category = DocumentWorkspaceFilter.category(from: filterRawValue) {
            output = output.filter { $0.category == category }
        }

        return output.sorted(by: sort.areInIncreasingOrder)
    }

    private var availableCategories: [DocumentCategory] {
        let categories = Set(documents.map(\.category))
        return categories.sorted { $0.localizedName < $1.localizedName }
    }

    private var presentation: NorthBridgeDocumentPresentation {
        environment.presentationPreferences.documentPresentation
    }

    private var selectionAnimation: Animation? {
        reduceMotion || !environment.presentationPreferences.enhancedMotion
            ? nil
            : NorthBridgeMotion.selection
    }

    private var sort: DocumentWorkspaceSort {
        DocumentWorkspaceSort(rawValue: sortRawValue) ?? .newest
    }

    private var sortBinding: Binding<DocumentWorkspaceSort> {
        Binding(
            get: { sort },
            set: { sortRawValue = $0.rawValue }
        )
    }

    private var documentCountSummary: String {
        if documents.isEmpty {
            return String(localized: "Inga dokument ännu")
        }
        let favorites = documents.lazy.filter(\.isFavorite).count
        return String(localized: "\(documents.count) dokument · \(favorites) favoriter")
    }

    private func resetFilters() {
        searchText = ""
        filterRawValue = DocumentWorkspaceFilter.all.rawValue
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

private enum DocumentWorkspaceSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case title
    case modified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: String(localized: "Nyast först")
        case .oldest: String(localized: "Äldst först")
        case .title: String(localized: "Titel")
        case .modified: String(localized: "Senast ändrad")
        }
    }

    var systemImage: String {
        switch self {
        case .newest: "calendar.badge.clock"
        case .oldest: "calendar"
        case .title: "textformat.abc"
        case .modified: "clock.arrow.circlepath"
        }
    }

    func areInIncreasingOrder(_ lhs: DocumentRecord, _ rhs: DocumentRecord) -> Bool {
        switch self {
        case .newest:
            lhs.importedAt > rhs.importedAt
        case .oldest:
            lhs.importedAt < rhs.importedAt
        case .title:
            lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        case .modified:
            lhs.lastModifiedAt > rhs.lastModifiedAt
        }
    }
}

private enum DocumentWorkspaceFilter {
    static let all = FilterValue(rawValue: "all")
    static let favorites = FilterValue(rawValue: "favorites")

    struct FilterValue {
        let rawValue: String
    }

    static func category(_ category: DocumentCategory) -> String {
        "category:\(category.rawValue)"
    }

    static func category(from rawValue: String) -> DocumentCategory? {
        let prefix = "category:"
        guard rawValue.hasPrefix(prefix) else { return nil }
        return DocumentCategory(rawValue: String(rawValue.dropFirst(prefix.count)))
    }
}

@MainActor
private struct DocumentWorkspaceRow: View {
    let document: DocumentRecord

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(document.category.tint.opacity(0.13))
                Image(systemName: document.category.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(document.category.tint)
            }
            .frame(width: 50, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(document.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.northBridgeTextPrimary)
                    if document.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.northBridgeWarning)
                            .accessibilityLabel("Favorit")
                    }
                }

                HStack(spacing: 6) {
                    Text(document.category.localizedName)
                    if let pageCount = document.pageCount {
                        Text("·")
                        Text(pageDescription(pageCount))
                    }
                    Text("·")
                    Text(document.importedAt, format: .dateTime.day().month().year())
                }
                .font(.caption)
                .foregroundStyle(Color.northBridgeTextSecondary)

                Label(
                    document.isAvailableOffline ? document.sourceName : "Kräver anslutning",
                    systemImage: document.isAvailableOffline ? "checkmark.circle" : "icloud.slash"
                )
                .font(.caption2)
                .foregroundStyle(
                    document.isAvailableOffline
                        ? Color.northBridgeTextTertiary
                        : Color.northBridgeWarning
                )
            }

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.northBridgeTextTertiary)
        }
        .padding(14)
        .background(
            Color.northBridgeRaisedSurface,
            in: RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous)
                .stroke(Color.northBridgeHairline, lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func pageDescription(_ count: Int) -> String {
        String(localized: "\(count) sidor")
    }
}

@MainActor
private struct DocumentWorkspaceCard: View {
    let document: DocumentRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: document.category.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(document.category.tint)
                    .frame(width: 48, height: 54)
                    .background(
                        document.category.tint.opacity(0.13),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                Spacer()
                if document.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.northBridgeWarning)
                        .accessibilityLabel("Favorit")
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(document.title)
                    .font(.headline)
                    .foregroundStyle(Color.northBridgeTextPrimary)
                Text(document.category.localizedName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(document.category.tint)
            }

            HStack(spacing: 6) {
                if let pageCount = document.pageCount {
                    Label("\(pageCount) sidor", systemImage: "doc.on.doc")
                }
                Label {
                    Text(document.importedAt, format: .dateTime.day().month().year())
                } icon: {
                    Image(systemName: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(Color.northBridgeTextSecondary)

            Divider()

            Label(
                document.isAvailableOffline ? document.sourceName : "Kräver anslutning",
                systemImage: document.isAvailableOffline ? "checkmark.circle" : "icloud.slash"
            )
            .font(.caption)
            .foregroundStyle(
                document.isAvailableOffline
                    ? Color.northBridgeTextTertiary
                    : Color.northBridgeWarning
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Color.northBridgeRaisedSurface,
            in: RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous)
                .stroke(Color.northBridgeHairline, lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

extension DocumentCategory {
    var systemImage: String {
        switch self {
        case .registrationCertificate: "building.columns"
        case .articlesOfAssociation: "text.book.closed"
        case .annualReports: "chart.bar.doc.horizontal"
        case .boardMinutes: "person.3.sequence"
        case .generalMeetingMinutes: "person.2.wave.2"
        case .shareholderAgreement: "person.2.badge.key"
        case .shareholderRegister: "chart.pie"
        case .shareCertificate: "seal"
        case .taxDocuments: "banknote"
        case .agreements: "signature"
        case .insurance: "umbrella"
        case .powersOfAttorney: "checkmark.seal"
        case .other: "doc.text"
        }
    }

    var tint: Color {
        switch self {
        case .taxDocuments, .annualReports: .northBridgePositive
        case .boardMinutes, .generalMeetingMinutes: .indigo
        case .insurance, .powersOfAttorney: .northBridgeWarning
        default: .northBridgeInformational
        }
    }
}

private extension View {
    @ViewBuilder
    func documentMatchedTransitionSource(
        id: UUID,
        namespace: Namespace.ID?
    ) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
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
            .scrollContentBackground(.hidden)
            .background(Color.northBridgeBackground)
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
        .tint(.northBridgeBlue)
        .presentationDetents([.large])
        .presentationCornerRadius(NorthBridgeRadius.sheet)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
