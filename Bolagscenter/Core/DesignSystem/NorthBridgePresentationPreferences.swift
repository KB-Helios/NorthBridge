import Foundation
import Observation
import SwiftUI

enum NorthBridgeAppearance: String, CaseIterable, Equatable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system:
            "System"
        case .light:
            "Ljust"
        case .dark:
            "Mörkt"
        }
    }

    var systemImage: String {
        switch self {
        case .system:
            "circle.lefthalf.filled"
        case .light:
            "sun.max.fill"
        case .dark:
            "moon.stars.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum NorthBridgeDashboardDensity: String, CaseIterable, Equatable, Identifiable, Sendable {
    case comfortable
    case compact

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .comfortable:
            "Luftig"
        case .compact:
            "Kompakt"
        }
    }
}

enum NorthBridgeDocumentPresentation: String, CaseIterable, Equatable, Identifiable, Sendable {
    case list
    case grid

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .list:
            "Lista"
        case .grid:
            "Rutnät"
        }
    }

    var systemImage: String {
        switch self {
        case .list:
            "list.bullet"
        case .grid:
            "square.grid.2x2"
        }
    }
}

@MainActor
@Observable
final class NorthBridgePresentationPreferences {
    enum Key {
        static let appearance = "northbridge.appearance"
        static let enhancedMotion = "northbridge.motion.enhanced"
        static let haptics = "northbridge.haptics.enabled"
        static let dashboardDensity = "northbridge.dashboard.density"
        static let financialPrivacyBlur = "northbridge.finance.privacyBlur"
        static let documentPresentation = "northbridge.documents.presentation"
    }

    var appearance: NorthBridgeAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    var enhancedMotion: Bool {
        didSet { defaults.set(enhancedMotion, forKey: Key.enhancedMotion) }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) }
    }

    var dashboardDensity: NorthBridgeDashboardDensity {
        didSet {
            defaults.set(dashboardDensity.rawValue, forKey: Key.dashboardDensity)
        }
    }

    var financialPrivacyBlur: Bool {
        didSet {
            defaults.set(financialPrivacyBlur, forKey: Key.financialPrivacyBlur)
        }
    }

    var documentPresentation: NorthBridgeDocumentPresentation {
        didSet {
            defaults.set(
                documentPresentation.rawValue,
                forKey: Key.documentPresentation
            )
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = NorthBridgeAppearance(
            rawValue: defaults.string(forKey: Key.appearance) ?? ""
        ) ?? .system
        enhancedMotion = defaults.object(forKey: Key.enhancedMotion) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        dashboardDensity = NorthBridgeDashboardDensity(
            rawValue: defaults.string(forKey: Key.dashboardDensity) ?? ""
        ) ?? .comfortable
        financialPrivacyBlur = defaults.object(
            forKey: Key.financialPrivacyBlur
        ) as? Bool ?? false
        documentPresentation = NorthBridgeDocumentPresentation(
            rawValue: defaults.string(forKey: Key.documentPresentation) ?? ""
        ) ?? .list
    }
}
