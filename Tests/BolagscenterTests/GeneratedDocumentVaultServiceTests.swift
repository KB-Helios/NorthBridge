import Foundation
import SwiftData
import Testing
@testable import Bolagscenter

@MainActor
struct GeneratedDocumentVaultServiceTests {
    @Test
    func repeatedExportCreatesOneDocumentWithImmutableVersions() throws {
        let context = try makeContext()
        let companyID = UUID()
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: directory) }

        let firstURL = directory.appending(path: "first.pdf")
        let secondURL = directory.appending(path: "second.pdf")
        try Data("first".utf8).write(to: firstURL)
        try Data("second".utf8).write(to: secondURL)

        let service = GeneratedDocumentVaultService()
        _ = try service.recordPDF(
            companyID: companyID,
            title: "Aktiebok – Test AB",
            category: .shareholderRegister,
            fileURL: firstURL,
            sourceName: "NorthBridge",
            documents: [],
            versions: [],
            in: context
        )
        try context.save()

        let firstDocuments = try context.fetch(FetchDescriptor<DocumentRecord>())
        let firstVersions = try context.fetch(
            FetchDescriptor<DocumentVersionRecord>()
        )
        _ = try service.recordPDF(
            companyID: companyID,
            title: "Aktiebok – Test AB",
            category: .shareholderRegister,
            fileURL: secondURL,
            sourceName: "NorthBridge",
            documents: firstDocuments,
            versions: firstVersions,
            in: context
        )
        try context.save()

        let documents = try context.fetch(FetchDescriptor<DocumentRecord>())
        let versions = try context.fetch(
            FetchDescriptor<DocumentVersionRecord>(
                sortBy: [SortDescriptor(\.versionNumber)]
            )
        )

        #expect(documents.count == 1)
        #expect(documents.first?.originalFilename == "second.pdf")
        #expect(versions.map(\.versionNumber) == [1, 2])
        #expect(Set(versions.map(\.documentID)) == Set(documents.map(\.id)))
        #expect(fileManager.fileExists(atPath: firstURL.path))
        #expect(fileManager.fileExists(atPath: secondURL.path))
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: BolagscenterSchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        return ModelContext(container)
    }
}
