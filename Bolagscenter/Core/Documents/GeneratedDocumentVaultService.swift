import Foundation
import SwiftData

struct GeneratedDocumentVaultResult {
    let document: DocumentRecord
    let version: DocumentVersionRecord
}

@MainActor
struct GeneratedDocumentVaultService {
    func recordPDF(
        companyID: UUID,
        title: String,
        category: DocumentCategory,
        fileURL: URL,
        sourceName: String,
        documents: [DocumentRecord],
        versions: [DocumentVersionRecord],
        in context: ModelContext
    ) throws -> GeneratedDocumentVaultResult {
        let bookmark = try fileURL.bookmarkData()
        let document: DocumentRecord

        if let existing = documents.first(where: {
            $0.companyID == companyID
                && $0.title == title
                && $0.category == category
        }) {
            document = existing
            document.fileBookmark = bookmark
            document.originalFilename = fileURL.lastPathComponent
            document.uniformTypeIdentifier = "com.adobe.pdf"
            document.sourceName = sourceName
            document.lastModifiedAt = .now
            document.isAvailableOffline = true
        } else {
            document = DocumentRecord(
                companyID: companyID,
                title: title,
                category: category,
                fileBookmark: bookmark,
                originalFilename: fileURL.lastPathComponent,
                uniformTypeIdentifier: "com.adobe.pdf",
                sourceName: sourceName
            )
            context.insert(document)
        }

        let nextVersion = versions
            .filter { $0.documentID == document.id }
            .map(\.versionNumber)
            .max()
            .map { $0 + 1 }
            ?? 1
        let version = DocumentVersionRecord(
            companyID: companyID,
            documentID: document.id,
            versionNumber: nextVersion,
            fileBookmark: bookmark,
            sourceName: sourceName
        )
        context.insert(version)

        return GeneratedDocumentVaultResult(
            document: document,
            version: version
        )
    }
}
