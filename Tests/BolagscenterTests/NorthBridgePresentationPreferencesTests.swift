import Foundation
import XCTest
@testable import Bolagscenter

@MainActor
final class NorthBridgePresentationPreferencesTests: XCTestCase {
    func testPresentationPreferencesPersistAcrossInstances() throws {
        let suiteName = "NorthBridgePresentationPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = NorthBridgePresentationPreferences(defaults: defaults)
        XCTAssertEqual(preferences.appearance, .system)
        XCTAssertTrue(preferences.enhancedMotion)
        XCTAssertTrue(preferences.hapticsEnabled)
        XCTAssertEqual(preferences.dashboardDensity, .comfortable)
        XCTAssertFalse(preferences.financialPrivacyBlur)
        XCTAssertEqual(preferences.documentPresentation, .list)

        preferences.appearance = .dark
        preferences.enhancedMotion = false
        preferences.hapticsEnabled = false
        preferences.dashboardDensity = .compact
        preferences.financialPrivacyBlur = true
        preferences.documentPresentation = .grid

        let reloaded = NorthBridgePresentationPreferences(defaults: defaults)
        XCTAssertEqual(reloaded.appearance, .dark)
        XCTAssertFalse(reloaded.enhancedMotion)
        XCTAssertFalse(reloaded.hapticsEnabled)
        XCTAssertEqual(reloaded.dashboardDensity, .compact)
        XCTAssertTrue(reloaded.financialPrivacyBlur)
        XCTAssertEqual(reloaded.documentPresentation, .grid)
    }
}
