import PDFKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct DocumentViewerView: View {
    @Query private var documents: [DocumentRecord]
    @Query(sort: \DocumentVersionRecord.versionNumber, order: .reverse) private var versions: [DocumentVersionRecord]

    let documentID: UUID
    private let transitionNamespace: Namespace.ID?
    @State private var resolvedURL: URL?
    @State private var selectedVersionID: UUID?
    @State private var errorMessage: String?

    init(documentID: UUID, transitionNamespace: Namespace.ID? = nil) {
        self.documentID = documentID
        self.transitionNamespace = transitionNamespace
        _documents = Query(filter: #Predicate { $0.id == documentID })
    }

    var body: some View {
        Group {
            if let document = documents.first {
                List {
                    documentHeader(document)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    Section {
                        documentPreview(document: document)
                            .listRowInsets(EdgeInsets())
                            .clipShape(RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous))
                    }

                    Section("Dokumentuppgifter") {
                        LabeledContent("Kategori", value: document.category.localizedName)
                        LabeledContent("Källa", value: document.sourceName)
                        LabeledContent(
                            "Importerad",
                            value: document.importedAt.formatted(date: .long, time: .shortened)
                        )
                        if let pageCount = document.pageCount {
                            LabeledContent("Sidor", value: pageCount.formatted())
                        }
                        if !document.tags.isEmpty {
                            LabeledContent("Taggar", value: document.tags)
                        }
                        if let detectedParties = document.detectedParties,
                           !detectedParties.isEmpty {
                            LabeledContent(
                                "OCR-förslag på parter",
                                value: detectedParties
                                    .components(separatedBy: .newlines)
                                    .joined(separator: ", ")
                            )
                        }
                        if let expiresAt = document.expiresAt {
                            LabeledContent(
                                "Giltigt till",
                                value: expiresAt.formatted(date: .long, time: .omitted)
                            )
                        }
                        LabeledContent(
                            "Offline",
                            value: document.isAvailableOffline ? "Tillgänglig" : "Inte tillgänglig"
                        )
                    }

                    Section("Versionshistorik") {
                        let documentVersions = versions.filter { $0.documentID == document.id }
                        if documentVersions.isEmpty {
                            Text("Ingen version registrerad")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(documentVersions) { version in
                                Button {
                                    selectedVersionID = version.id
                                    resolve(version.fileBookmark)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Version \(version.versionNumber)")
                                                .foregroundStyle(.primary)
                                            Text(
                                                version.createdAt.formatted(
                                                    date: .abbreviated,
                                                    time: .shortened
                                                )
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if selectedVersionID == version.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    "Öppna version \(version.versionNumber)"
                                )
                                .accessibilityValue(
                                    selectedVersionID == version.id
                                        ? "Visas"
                                        : version.createdAt.formatted(
                                            date: .abbreviated,
                                            time: .shortened
                                        )
                                )
                            }
                        }
                    }

                    if let extractedText = document.extractedText, !extractedText.isEmpty {
                        Section("Identifierad text") {
                            Text(extractedText)
                                .textSelection(.enabled)
                        }
                    }

                    if document.detectedParties != nil {
                        Section {
                            Text("Identifierade parter är OCR-förslag och har inte verifierats mot en officiell källa.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.northBridgeBackground)
                .navigationTitle(document.title)
                .navigationBarTitleDisplayMode(.inline)
                .task(id: versionRevision(for: document)) {
                    let latestVersion = versions
                        .filter { $0.documentID == document.id }
                        .max(by: { $0.versionNumber < $1.versionNumber })
                    selectedVersionID = latestVersion?.id
                    resolve(latestVersion?.fileBookmark ?? document.fileBookmark)
                }
            } else {
                EmptyStateView(
                    systemImage: "doc.badge.exclamationmark",
                    title: "Dokumentet saknas",
                    message: "Posten kan ha tagits bort."
                )
            }
        }
        .documentMatchedNavigationTransition(
            id: documentID,
            namespace: transitionNamespace
        )
        .accessibilityIdentifier("documents.viewer.root")
        .alert("Dokumentet kunde inte öppnas", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .toolbar {
            if let resolvedURL {
                DocumentExportToolbarItem(url: resolvedURL)
            }
        }
    }

    private func documentHeader(_ document: DocumentRecord) -> some View {
        HStack(spacing: 14) {
            Image(systemName: document.category.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(document.category.tint)
                .frame(width: 52, height: 58)
                .background(
                    document.category.tint.opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(document.title)
                    .font(.title3.weight(.semibold))
                Text(document.category.localizedName)
                    .font(.subheadline)
                    .foregroundStyle(document.category.tint)
                Label(
                    document.isAvailableOffline ? "Tillgänglig offline" : "Kräver anslutning",
                    systemImage: document.isAvailableOffline ? "checkmark.circle" : "icloud.slash"
                )
                .font(.caption)
                .foregroundStyle(
                    document.isAvailableOffline
                        ? Color.northBridgeTextSecondary
                        : Color.northBridgeWarning
                )
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            Color.northBridgeRaisedSurface,
            in: RoundedRectangle(cornerRadius: NorthBridgeRadius.card, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func documentPreview(document: DocumentRecord) -> some View {
        if let resolvedURL {
            if document.uniformTypeIdentifier == UTType.pdf.identifier {
                PDFKitView(url: resolvedURL)
                    .frame(minHeight: 440)
                    .accessibilityLabel("PDF-förhandsvisning av \(document.title)")
            } else if let image = UIImage(contentsOfFile: resolvedURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Bildförhandsvisning av \(document.title)")
            } else {
                ContentUnavailableView(
                    "Ingen förhandsvisning",
                    systemImage: "doc",
                    description: Text("Filformatet kan inte förhandsvisas i appen.")
                )
                .frame(minHeight: 240)
            }
        } else {
            ProgressView("Öppnar dokument")
                .frame(maxWidth: .infinity, minHeight: 240)
        }
    }

    private func resolve(_ bookmark: Data?) {
        resolvedURL = nil
        guard let bookmark else {
            errorMessage = String(localized: "Dokumentfilen saknas.")
            return
        }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
            resolvedURL = url
        } catch {
            errorMessage = String(localized: "Den skyddade dokumentfilen kunde inte läsas.")
        }
    }

    private func versionRevision(for document: DocumentRecord) -> String {
        let revision = versions
            .filter { $0.documentID == document.id }
            .map { "\($0.id.uuidString):\($0.versionNumber)" }
            .sorted()
            .joined(separator: "|")
        return "\(document.id.uuidString)#\(revision)"
    }
}

private extension View {
    @ViewBuilder
    func documentMatchedNavigationTransition(
        id: UUID,
        namespace: Namespace.ID?
    ) -> some View {
        if let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

private struct DocumentExportToolbarItem: ToolbarContent {
    let url: URL

    var body: some ToolbarContent {
#if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            ToolbarItem(placement: .topBarPinnedTrailing) {
                shareLink
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                shareLink
            }
        }
#else
        ToolbarItem(placement: .topBarTrailing) {
            shareLink
        }
#endif
    }

    private var shareLink: some View {
        ShareLink(item: url) {
            Label(
                "Exportera dokument",
                systemImage: "square.and.arrow.up"
            )
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageShadowsEnabled = true
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
