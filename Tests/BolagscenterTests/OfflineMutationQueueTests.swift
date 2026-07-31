import Foundation
import Testing
@testable import Bolagscenter

struct OfflineMutationQueueTests {
    @Test
    func mutationGetsStableIdempotencyKeyAndPersists() async throws {
        let fileURL = temporaryQueueURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let queue = OfflineMutationQueue(fileURL: fileURL)
        let request = APIRequest<MutationResponse>(
            method: .post,
            path: "/v1/actions",
            body: Data(#"{"title":"Test"}"#.utf8),
            queuesWhenOffline: true
        )

        let firstID = try await queue.enqueue(request)
        let duplicateID = try await queue.enqueue(request)
        let reloaded = OfflineMutationQueue(fileURL: fileURL)
        let stored = try await reloaded.all()

        #expect(firstID == duplicateID)
        #expect(stored.count == 1)
        #expect(stored.first?.idempotencyKey == request.idempotencyKey)
        #expect(stored.first?.state == .pending)
    }

    @Test
    func conflictIsPreservedForExplicitResolution() async throws {
        let fileURL = temporaryQueueURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let queue = OfflineMutationQueue(fileURL: fileURL)
        let request = APIRequest<MutationResponse>(
            method: .patch,
            path: "/v1/actions/1",
            body: Data(#"{"status":"completed"}"#.utf8),
            expectedETag: #""version-1""#,
            queuesWhenOffline: true
        )
        _ = try await queue.enqueue(request)

        try await queue.drain { _ in
            throw APIClientError.conflict(serverVersion: "version-2")
        }
        let stored = try await queue.all()

        #expect(stored.count == 1)
        #expect(stored.first?.state == .blockedByConflict)
        #expect(stored.first?.attemptCount == 1)
    }

    @Test
    func clearRemovesPersistedMutationPayloads() async throws {
        let fileURL = temporaryQueueURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let queue = OfflineMutationQueue(fileURL: fileURL)
        let request = APIRequest<MutationResponse>(
            method: .post,
            path: "/v1/actions",
            body: Data(#"{"title":"Sensitive"}"#.utf8),
            queuesWhenOffline: true
        )
        _ = try await queue.enqueue(request)

        try await queue.clear()
        let stored = try await queue.all()

        #expect(!FileManager.default.fileExists(atPath: fileURL.path()))
        #expect(stored.isEmpty)
    }

    private func temporaryQueueURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "offline-mutations.json")
    }
}

private struct MutationResponse: Decodable, Sendable {
    let id: UUID?
}
