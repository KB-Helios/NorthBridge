import Foundation
import SwiftData

@Model
final class DeadlineSupportingDocumentRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var deadlineID: UUID
    var documentID: UUID
    var attachedByAccountID: UUID?
    var attachedAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        deadlineID: UUID,
        documentID: UUID,
        attachedByAccountID: UUID?,
        attachedAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.deadlineID = deadlineID
        self.documentID = documentID
        self.attachedByAccountID = attachedByAccountID
        self.attachedAt = attachedAt
    }
}

@Model
final class DeadlineReminderRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var deadlineID: UUID
    var isEnabled: Bool
    var leadTimeDays: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        deadlineID: UUID,
        isEnabled: Bool = true,
        leadTimeDays: Int = 7,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.deadlineID = deadlineID
        self.isEnabled = isEnabled
        self.leadTimeDays = leadTimeDays
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class DeadlineActionEventRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var deadlineID: UUID
    var accountID: UUID?
    var kindRawValue: String
    var details: String
    var occurredAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        deadlineID: UUID,
        accountID: UUID?,
        kind: DeadlineActionEventKind,
        details: String,
        occurredAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.deadlineID = deadlineID
        self.accountID = accountID
        kindRawValue = kind.rawValue
        self.details = details
        self.occurredAt = occurredAt
    }

    var kind: DeadlineActionEventKind {
        get {
            DeadlineActionEventKind(rawValue: kindRawValue) ?? .note
        }
        set {
            kindRawValue = newValue.rawValue
        }
    }
}

enum DeadlineActionEventKind:
    String,
    Codable,
    CaseIterable,
    Identifiable,
    Sendable
{
    case created
    case statusChanged
    case note
    case documentAttached
    case documentRemoved
    case reminderUpdated

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .created: "Skapad"
        case .statusChanged: "Status ändrad"
        case .note: "Anteckning"
        case .documentAttached: "Dokument bifogat"
        case .documentRemoved: "Dokument borttaget"
        case .reminderUpdated: "Påminnelse ändrad"
        }
    }

    var systemImage: String {
        switch self {
        case .created: "plus.circle"
        case .statusChanged: "arrow.triangle.2.circlepath"
        case .note: "note.text"
        case .documentAttached: "paperclip"
        case .documentRemoved: "paperclip.badge.ellipsis"
        case .reminderUpdated: "bell"
        }
    }
}
