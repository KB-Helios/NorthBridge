import Foundation
import SwiftData

@Model
final class PersonRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var fullName: String
    var email: String?
    var phone: String?
    var personalIdentifier: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        fullName: String,
        email: String? = nil,
        phone: String? = nil,
        personalIdentifier: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.personalIdentifier = personalIdentifier
        self.createdAt = createdAt
    }
}

@Model
final class BoardMemberRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var personID: UUID
    var roleRawValue: String
    var isSignatory: Bool
    var mandateStartsAt: Date
    var mandateEndsAt: Date?
    var sourceName: String
    var sourceUpdatedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        personID: UUID,
        role: BoardMemberRole,
        isSignatory: Bool = false,
        mandateStartsAt: Date,
        mandateEndsAt: Date? = nil,
        sourceName: String,
        sourceUpdatedAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.personID = personID
        roleRawValue = role.rawValue
        self.isSignatory = isSignatory
        self.mandateStartsAt = mandateStartsAt
        self.mandateEndsAt = mandateEndsAt
        self.sourceName = sourceName
        self.sourceUpdatedAt = sourceUpdatedAt
        self.createdAt = createdAt
    }

    var role: BoardMemberRole {
        get { BoardMemberRole(rawValue: roleRawValue) ?? .member }
        set { roleRawValue = newValue.rawValue }
    }
}

enum BoardMemberRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case chair
    case member
    case deputy
    case chiefExecutive
    case auditor

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .chair: "Ordförande"
        case .member: "Styrelseledamot"
        case .deputy: "Suppleant"
        case .chiefExecutive: "VD"
        case .auditor: "Revisor"
        }
    }
}

@Model
final class BoardMeetingRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var title: String
    var meetingNumber: String
    var scheduledAt: Date
    var location: String
    var statusRawValue: String
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var approvedAt: Date?

    init(
        id: UUID = UUID(),
        companyID: UUID,
        title: String,
        meetingNumber: String,
        scheduledAt: Date,
        location: String,
        status: BoardMeetingStatus = .draft,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        approvedAt: Date? = nil
    ) {
        self.id = id
        self.companyID = companyID
        self.title = title
        self.meetingNumber = meetingNumber
        self.scheduledAt = scheduledAt
        self.location = location
        statusRawValue = status.rawValue
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.approvedAt = approvedAt
    }

    var status: BoardMeetingStatus {
        get { BoardMeetingStatus(rawValue: statusRawValue) ?? .draft }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = .now
            approvedAt = newValue == .approved ? .now : approvedAt
        }
    }
}

enum BoardMeetingStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft
    case scheduled
    case held
    case approved
    case cancelled

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .draft: "Utkast"
        case .scheduled: "Planerat"
        case .held: "Genomfört"
        case .approved: "Justerat"
        case .cancelled: "Inställt"
        }
    }
}

@Model
final class MeetingAttendanceRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var meetingID: UUID
    var personID: UUID
    var attendanceRawValue: String
    var recordedAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        meetingID: UUID,
        personID: UUID,
        attendance: AttendanceStatus = .invited,
        recordedAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.meetingID = meetingID
        self.personID = personID
        attendanceRawValue = attendance.rawValue
        self.recordedAt = recordedAt
    }

    var attendance: AttendanceStatus {
        get { AttendanceStatus(rawValue: attendanceRawValue) ?? .invited }
        set {
            attendanceRawValue = newValue.rawValue
            recordedAt = .now
        }
    }
}

enum AttendanceStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case invited
    case present
    case absent
    case excused

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .invited: "Inbjuden"
        case .present: "Närvarande"
        case .absent: "Frånvarande"
        case .excused: "Anmält förhinder"
        }
    }
}

@Model
final class AgendaItemRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var meetingID: UUID
    var position: Int
    var title: String
    var details: String
    var presenterName: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        meetingID: UUID,
        position: Int,
        title: String,
        details: String,
        presenterName: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.meetingID = meetingID
        self.position = position
        self.title = title
        self.details = details
        self.presenterName = presenterName
        self.createdAt = createdAt
    }
}

@Model
final class BoardResolutionRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var meetingID: UUID
    var agendaItemID: UUID?
    var title: String
    var decisionText: String
    var statusRawValue: String
    var decidedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        meetingID: UUID,
        agendaItemID: UUID? = nil,
        title: String,
        decisionText: String,
        status: ResolutionStatus = .draft,
        decidedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.meetingID = meetingID
        self.agendaItemID = agendaItemID
        self.title = title
        self.decisionText = decisionText
        statusRawValue = status.rawValue
        self.decidedAt = decidedAt
        self.createdAt = createdAt
    }

    var status: ResolutionStatus {
        get { ResolutionStatus(rawValue: statusRawValue) ?? .draft }
        set {
            statusRawValue = newValue.rawValue
            decidedAt = newValue == .adopted ? .now : decidedAt
        }
    }
}

enum ResolutionStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft
    case adopted
    case rejected
    case tabled

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .draft: "Utkast"
        case .adopted: "Beslutad"
        case .rejected: "Avslagen"
        case .tabled: "Bordlagd"
        }
    }
}

@Model
final class ActionItemRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var meetingID: UUID?
    var resolutionID: UUID?
    var title: String
    var details: String
    var assignedTo: String
    var dueAt: Date
    var statusRawValue: String
    var priorityRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        companyID: UUID,
        meetingID: UUID? = nil,
        resolutionID: UUID? = nil,
        title: String,
        details: String,
        assignedTo: String,
        dueAt: Date,
        status: ActionItemStatus = .open,
        priority: DeadlinePriority = .normal,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.companyID = companyID
        self.meetingID = meetingID
        self.resolutionID = resolutionID
        self.title = title
        self.details = details
        self.assignedTo = assignedTo
        self.dueAt = dueAt
        statusRawValue = status.rawValue
        priorityRawValue = priority.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    var status: ActionItemStatus {
        get { ActionItemStatus(rawValue: statusRawValue) ?? .open }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = .now
            completedAt = newValue == .completed ? .now : nil
        }
    }

    var priority: DeadlinePriority {
        get { DeadlinePriority(rawValue: priorityRawValue) ?? .normal }
        set {
            priorityRawValue = newValue.rawValue
            updatedAt = .now
        }
    }
}

enum ActionItemStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case open
    case inProgress
    case blocked
    case completed

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .open: "Öppen"
        case .inProgress: "Pågår"
        case .blocked: "Blockerad"
        case .completed: "Klar"
        }
    }
}

@Model
final class ShareholderRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var displayName: String
    var shareholderKindRawValue: String
    var identityReference: String?
    var email: String?
    var postalAddress: String?
    var createdAt: Date
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        companyID: UUID,
        displayName: String,
        shareholderKind: ShareholderKind,
        identityReference: String? = nil,
        email: String? = nil,
        postalAddress: String? = nil,
        createdAt: Date = .now,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.companyID = companyID
        self.displayName = displayName
        shareholderKindRawValue = shareholderKind.rawValue
        self.identityReference = identityReference
        self.email = email
        self.postalAddress = postalAddress
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }

    var shareholderKind: ShareholderKind {
        get { ShareholderKind(rawValue: shareholderKindRawValue) ?? .person }
        set { shareholderKindRawValue = newValue.rawValue }
    }
}

enum ShareholderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case person
    case legalEntity

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .person: "Fysisk person"
        case .legalEntity: "Juridisk person"
        }
    }
}

@Model
final class ShareClassRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var name: String
    var votesPerShare: Double
    var nominalValue: Double?
    var currencyCode: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        name: String,
        votesPerShare: Double = 1,
        nominalValue: Double? = nil,
        currencyCode: String = "SEK",
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.name = name
        self.votesPerShare = votesPerShare
        self.nominalValue = nominalValue
        self.currencyCode = currencyCode
        self.createdAt = createdAt
    }
}

@Model
final class ShareTransactionRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var shareClassID: UUID
    var fromShareholderID: UUID?
    var toShareholderID: UUID?
    var quantity: Int
    var kindRawValue: String
    var transactionDate: Date
    var reference: String
    var notes: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        shareClassID: UUID,
        fromShareholderID: UUID? = nil,
        toShareholderID: UUID? = nil,
        quantity: Int,
        kind: ShareTransactionKind,
        transactionDate: Date,
        reference: String,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.shareClassID = shareClassID
        self.fromShareholderID = fromShareholderID
        self.toShareholderID = toShareholderID
        self.quantity = quantity
        kindRawValue = kind.rawValue
        self.transactionDate = transactionDate
        self.reference = reference
        self.notes = notes
        self.createdAt = createdAt
    }

    var kind: ShareTransactionKind {
        get { ShareTransactionKind(rawValue: kindRawValue) ?? .transfer }
        set { kindRawValue = newValue.rawValue }
    }
}

enum ShareTransactionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case issuance
    case transfer
    case redemption
    case correction

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .issuance: "Nyemission/ingående innehav"
        case .transfer: "Överlåtelse"
        case .redemption: "Inlösen"
        case .correction: "Rättelsepost"
        }
    }
}

@Model
final class ShareCertificateRecord {
    @Attribute(.unique) var id: UUID
    var companyID: UUID
    var shareholderID: UUID
    var shareClassID: UUID
    var certificateNumber: String
    var quantity: Int
    var shareNumberFrom: Int?
    var shareNumberTo: Int?
    var issuedAt: Date
    var statusRawValue: String
    var revokedAt: Date?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        companyID: UUID,
        shareholderID: UUID,
        shareClassID: UUID,
        certificateNumber: String,
        quantity: Int,
        shareNumberFrom: Int? = nil,
        shareNumberTo: Int? = nil,
        issuedAt: Date,
        status: ShareCertificateStatus = .draft,
        revokedAt: Date? = nil,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.companyID = companyID
        self.shareholderID = shareholderID
        self.shareClassID = shareClassID
        self.certificateNumber = certificateNumber
        self.quantity = quantity
        self.shareNumberFrom = shareNumberFrom
        self.shareNumberTo = shareNumberTo
        self.issuedAt = issuedAt
        statusRawValue = status.rawValue
        self.revokedAt = revokedAt
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var status: ShareCertificateStatus {
        get { ShareCertificateStatus(rawValue: statusRawValue) ?? .draft }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = .now
            if newValue == .revoked {
                revokedAt = .now
            }
        }
    }
}

enum ShareCertificateStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft
    case issued
    case revoked
    case replaced

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .draft: "Utkast"
        case .issued: "Markerat som utfärdat"
        case .revoked: "Återkallat"
        case .replaced: "Ersatt"
        }
    }
}
