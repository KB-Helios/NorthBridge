import Foundation
import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case finance
    case company
    case documents
    case more

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .overview: "Översikt"
        case .finance: "Ekonomi"
        case .company: "Bolag"
        case .documents: "Dokument"
        case .more: "Mer"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .finance: "chart.xyaxis.line"
        case .company: "building.2"
        case .documents: "doc.text"
        case .more: "ellipsis.circle"
        }
    }
}

enum AppRoute: Hashable {
    case deadlines
    case deadline(UUID)
    case addDeadline
    case financialMetric(UUID)
    case financialPlanning
    case addCompany
    case companyDetails
    case boardAndSignatories
    case boardWorkspace
    case boardMeeting(UUID)
    case addBoardMeeting
    case resolution(UUID)
    case actionTracker
    case ownership
    case shareholderRegister
    case shareCertificates
    case addShareTransaction
    case document(UUID)
    case search
    case integrations
    case usersAndRoles
    case notificationSettings
    case subscription
    case accountSettings
    case assistant
    case security
    case activity
}

@MainActor
@Observable
final class RouterPath {
    var path: [AppRoute] = []

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func reset() {
        path.removeAll()
    }
}
