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
        captureHealthyEmptyOverview(app)
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
        waitForVisualStability()
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
        waitForVisualStability()
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
        waitForVisualStability()
        attachScreenshot(of: app, named: "08-activity-light")
    }

    func testCapturesDarkDashboard() {
        let app = launchSeeded(
            extraArguments: ["-ui-testing-appearance-dark"]
        )
        XCTAssertTrue(
            app.navigationBars["Översikt"].waitForExistence(timeout: 5)
        )
        waitForVisualStability()
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
        waitForVisualStability()
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
        waitForVisualStability()
        attachScreenshot(of: app, named: "11-onboarding-account-chapter")
    }

    func testCapturesOnboardingLiquidSwipeChapterTransition() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-ui-testing-liquid-swipe-frame",
        ]
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["onboarding.liquidSwipe.frame"]
                .waitForExistence(timeout: 5)
        )
        waitForVisualStability()
        attachScreenshot(of: app, named: "12-onboarding-liquid-swipe-chapter")
    }

    private func captureRoot(
        _ app: XCUIApplication,
        tabIdentifier: String,
        navigationTitle: String,
        screenshotName: String
    ) {
        let identifiedTab = app.descendants(matching: .any)
            .matching(identifier: tabIdentifier)
            .firstMatch
        let tab = identifiedTab.waitForExistence(timeout: 1)
            ? identifiedTab
            : app.buttons[navigationTitle]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        XCTAssertTrue(
            app.navigationBars[navigationTitle].waitForExistence(timeout: 5)
        )
        waitForVisualStability()
        attachScreenshot(of: app, named: screenshotName)
    }

    private func captureHealthyEmptyOverview(_ app: XCUIApplication) {
        openCompanySwitcher(in: app)
        app.buttons["Sydlig Test AB"].tap()
        XCTAssertTrue(waitForCompanyHero("Sydlig Test AB", in: app))
        waitForVisualStability()
        attachScreenshot(of: app, named: "01b-overview-healthy-empty")

        openCompanySwitcher(in: app)
        app.buttons["Nordisk Test AB"].tap()
        XCTAssertTrue(waitForCompanyHero("Nordisk Test AB", in: app))
    }

    private func openCompanySwitcher(in app: XCUIApplication) {
        let switcher = app.descendants(matching: .any)
            .matching(identifier: "company.switcher")
            .firstMatch

        if !switcher.waitForExistence(timeout: 1) {
            let overflow = app.buttons["OverflowBarButtonItem"]
            XCTAssertTrue(overflow.waitForExistence(timeout: 3))

            let hero = app.descendants(matching: .any)
                .matching(identifier: "overview.companyHero")
                .firstMatch
            XCTAssertTrue(hero.waitForExistence(timeout: 3))
            let activeCompanyName = hero.label
                .split(separator: ",", maxSplits: 1)
                .first
                .map(String.init) ?? ""

            overflow.tap()
            let overflowCompanyButton = app.buttons[activeCompanyName]
            XCTAssertTrue(overflowCompanyButton.waitForExistence(timeout: 3))
            overflowCompanyButton.tap()
            return
        }

        switcher.tap()
    }

    private func waitForCompanyHero(
        _ companyName: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 5
    ) -> Bool {
        let hero = app.descendants(matching: .any)
            .matching(identifier: "overview.companyHero")
            .firstMatch
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", companyName),
            object: hero
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForVisualStability() {
        let settled = XCTestExpectation(description: "Visual state settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            settled.fulfill()
        }
        XCTAssertEqual(
            XCTWaiter.wait(for: [settled], timeout: 1.5),
            .completed
        )
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
