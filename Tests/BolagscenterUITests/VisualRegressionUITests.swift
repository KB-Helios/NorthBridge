import XCTest

@MainActor
final class VisualRegressionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCapturesPrimaryWorkspacesAndSettings() {
        let app = launchSeeded()

        captureRoot(
            app,
            tabIdentifier: "tab.overview",
            navigationTitle: "Översikt",
            screenshotName: "01-overview-light"
        )
        captureRoot(
            app,
            tabIdentifier: "tab.finance",
            navigationTitle: "Ekonomi",
            screenshotName: "02-finance-light"
        )
        captureRoot(
            app,
            tabIdentifier: "tab.company",
            navigationTitle: "Bolag",
            screenshotName: "03-company-light"
        )
        captureRoot(
            app,
            tabIdentifier: "tab.documents",
            navigationTitle: "Dokument",
            screenshotName: "04-documents-list-light"
        )

        let gridButton = app.descendants(matching: .any)["documents.presentation.grid"]
        XCTAssertTrue(gridButton.waitForExistence(timeout: 5))
        gridButton.tap()
        attachScreenshot(of: app, named: "05-documents-grid-light")

        captureRoot(
            app,
            tabIdentifier: "tab.search",
            navigationTitle: "Sök",
            screenshotName: "06-search-light"
        )

        let settingsButton = app.buttons["settings.open"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.hub"]
                .waitForExistence(timeout: 5)
        )
        attachScreenshot(of: app, named: "07-settings-light")
    }

    func testCapturesActivityTimeline() {
        let app = launchSeeded(route: "activity")
        XCTAssertTrue(
            app.descendants(matching: .any)["activity.timeline.root"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["activity.timeline.filters"]
                .waitForExistence(timeout: 5)
        )
        attachScreenshot(of: app, named: "08-activity-light")
    }

    func testCapturesDarkDashboard() {
        let app = launchSeeded(
            extraArguments: ["-AppleInterfaceStyle", "Dark"]
        )
        XCTAssertTrue(
            app.navigationBars["Översikt"].waitForExistence(timeout: 5)
        )
        attachScreenshot(of: app, named: "09-overview-dark")
    }

    func testCapturesOnboardingMotionEntryPoints() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-UIAccessibilityReduceMotionEnabled",
            "YES",
        ]
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["onboarding.root"]
                .waitForExistence(timeout: 5)
        )
        attachScreenshot(of: app, named: "10-onboarding-welcome")

        let startButton = app.buttons["onboarding.start"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["onboarding.chapter"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["onboarding.progress"]
                .waitForExistence(timeout: 5)
        )
        attachScreenshot(of: app, named: "11-onboarding-account-chapter")
    }

    private func captureRoot(
        _ app: XCUIApplication,
        tabIdentifier: String,
        navigationTitle: String,
        screenshotName: String
    ) {
        let tab = app.descendants(matching: .any)[tabIdentifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        XCTAssertTrue(
            app.navigationBars[navigationTitle].waitForExistence(timeout: 5)
        )
        attachScreenshot(of: app, named: screenshotName)
    }

    private func launchSeeded(
        route: String? = nil,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-ui-testing-seeded"]
        if let route {
            arguments += ["-ui-testing-route", route]
        }
        arguments += extraArguments
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func attachScreenshot(
        of app: XCUIApplication,
        named name: String
    ) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
