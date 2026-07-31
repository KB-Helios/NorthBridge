import Foundation

enum QueuedMutationState: String, Codable, Sendable {
    case pending
    case blockedByConflict
}

struct QueuedMutation: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let method: HTTPMethod
    let path: String
    let queryItems: [QueuedMutationQueryItem]
    let headers: [String: String]
    let body: Data?
    let requiresAuthentication: Bool
    let idempotencyKey: String
    let expectedETag: String?
    let createdAt: Date
    var attemptCount: Int
    var lastAttemptedAt: Date?
    var lastErrorDescription: String?
    var state: QueuedMutationState
}

struct QueuedMutationQueryItem: Codable, Equatable, Sendable {
    let name: String
    let value: String?
}

enum OfflineMutationQueueError: LocalizedError, Sendable {
    case notAMutation
    case missingIdempotencyKey
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .notAMutation:
            "Endast ändringar kan läggas i synkroniseringskön."
        case .missingIdempotencyKey:
            "Ändringen saknar idempotensnyckel och kan inte köas säkert."
        case .persistenceFailed:
            "Synkroniseringskön kunde inte lagras säkert."
        }
    }
}

actor OfflineMutationQueue {
    private let fileURL: URL
    private var mutations: [QueuedMutation] = []
    private var didLoad = false

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func applicationQueueURL(
        fileManager: FileManager = .default
    ) throws -> URL {
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return baseURL
            .appending(path: "NorthBridge", directoryHint: .isDirectory)
            .appending(path: "offline-mutations.json")
    }

    func enqueue<Response: Decodable & Sendable>(
        _ request: APIRequest<Response>
    ) throws -> UUID {
        guard request.method != .get else {
            throw OfflineMutationQueueError.notAMutation
        }
        guard let idempotencyKey = request.idempotencyKey else {
            throw OfflineMutationQueueError.missingIdempotencyKey
        }
        try loadIfNeeded()
        if let existing = mutations.first(where: {
            $0.idempotencyKey == idempotencyKey
        }) {
            return existing.id
        }
        let mutation = QueuedMutation(
            id: UUID(),
            method: request.method,
            path: request.path,
            queryItems: request.queryItems.map {
                QueuedMutationQueryItem(name: $0.name, value: $0.value)
            },
            headers: request.headers,
            body: request.body,
            requiresAuthentication: request.requiresAuthentication,
            idempotencyKey: idempotencyKey,
            expectedETag: request.expectedETag,
            createdAt: .now,
            attemptCount: 0,
            lastAttemptedAt: nil,
            lastErrorDescription: nil,
            state: .pending
        )
        mutations.append(mutation)
        try persist()
        return mutation.id
    }

    func all() throws -> [QueuedMutation] {
        try loadIfNeeded()
        return mutations.sorted { $0.createdAt < $1.createdAt }
    }

    func pendingCount() throws -> Int {
        try loadIfNeeded()
        return mutations.filter { $0.state == .pending }.count
    }

    func remove(id: UUID) throws {
        try loadIfNeeded()
        mutations.removeAll { $0.id == id }
        try persist()
    }

    func clear() throws {
        mutations = []
        didLoad = true
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw OfflineMutationQueueError.persistenceFailed
        }
    }

    func retryConflictedMutation(id: UUID) throws {
        try loadIfNeeded()
        guard let index = mutations.firstIndex(where: { $0.id == id }) else {
            return
        }
        mutations[index].state = .pending
        mutations[index].lastErrorDescription = nil
        try persist()
    }

    func drain(
        execute: @Sendable (QueuedMutation) async throws -> Void
    ) async throws {
        try loadIfNeeded()
        let pendingIDs = mutations
            .filter { $0.state == .pending }
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.id)

        for id in pendingIDs {
            try Task.checkCancellation()
            guard let index = mutations.firstIndex(where: { $0.id == id }) else {
                continue
            }
            mutations[index].attemptCount += 1
            mutations[index].lastAttemptedAt = .now
            let mutation = mutations[index]
            do {
                try await execute(mutation)
                mutations.removeAll { $0.id == id }
                try persist()
            } catch let error as APIClientError {
                guard let currentIndex = mutations.firstIndex(
                    where: { $0.id == id }
                ) else {
                    continue
                }
                mutations[currentIndex].lastErrorDescription =
                    error.localizedDescription
                switch error {
                case .conflict, .preconditionFailed:
                    mutations[currentIndex].state = .blockedByConflict
                    try persist()
                case .offline, .timedOut, .transport:
                    try persist()
                    return
                default:
                    try persist()
                }
            } catch {
                guard let currentIndex = mutations.firstIndex(
                    where: { $0.id == id }
                ) else {
                    continue
                }
                mutations[currentIndex].lastErrorDescription =
                    error.localizedDescription
                try persist()
            }
        }
    }

    private func loadIfNeeded() throws {
        guard !didLoad else { return }
        defer { didLoad = true }
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            mutations = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            mutations = try decoder.decode(
                [QueuedMutation].self,
                from: data
            )
        } catch {
            throw OfflineMutationQueueError.persistenceFailed
        }
    }

    private func persist() throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(mutations)
            try data.write(
                to: fileURL,
                options: [.atomic, .completeFileProtection]
            )
        } catch {
            throw OfflineMutationQueueError.persistenceFailed
        }
    }
}
