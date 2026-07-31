import Foundation
import SwiftData

@Model
final class CompanyResponsibilityRecord {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var companyID: UUID
    var categoryRawValue: String
    var isPrimary: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        accountID: UUID,
        companyID: UUID,
        category: CompanyResponsibilityCategory,
        isPrimary: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.accountID = accountID
        self.companyID = companyID
        categoryRawValue = category.rawValue
        self.isPrimary = isPrimary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: CompanyResponsibilityCategory {
        get {
            CompanyResponsibilityCategory(rawValue: categoryRawValue)
                ?? .deadlines
        }
        set {
            categoryRawValue = newValue.rawValue
            updatedAt = .now
        }
    }
}

enum CompanyResponsibilityCategory:
    String,
    Codable,
    CaseIterable,
    Identifiable,
    Sendable
{
    case deadlines
    case board
    case finance
    case documents
    case ownership
    case integrations

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .deadlines: "Deadlines och myndighetsdatum"
        case .board: "Styrelse och beslut"
        case .finance: "Ekonomi och likviditet"
        case .documents: "Dokument och avtal"
        case .ownership: "Ägare och aktiebok"
        case .integrations: "Integrationer och synkronisering"
        }
    }

    var systemImage: String {
        switch self {
        case .deadlines: "calendar.badge.clock"
        case .board: "person.3.sequence"
        case .finance: "chart.line.uptrend.xyaxis"
        case .documents: "doc.text"
        case .ownership: "chart.pie"
        case .integrations: "arrow.triangle.2.circlepath"
        }
    }
}
