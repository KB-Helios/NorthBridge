import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingValidatesAndCreatesWorkspace() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        app.buttons["onboarding.start"].tap()

        let nameField = app.textFields["onboarding.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Testanvändare")

        let emailField = app.textFields["onboarding.email"]
        emailField.tap()
        emailField.typeText("test@example.se")
        app.buttons["onboarding.account.continue"].tap()

        let numberField = app.textFields["onboarding.organisationNumber"]
        numberField.tap()
        numberField.typeText("5560160680")

        let companyField = app.textFields["onboarding.companyName"]
        companyField.tap()
        companyField.typeText("Testbolag AB")
        dismissKeyboardIfPresent(in: app)
        app.buttons["onboarding.company.continue"].tap()

        let confirmation = app.switches["onboarding.company.confirm"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        tapTrailingControl(confirmation)

        let verificationContinue = app.buttons["onboarding.verification.continue"]
        XCTAssertTrue(verificationContinue.waitForExistence(timeout: 3))
        XCTAssertTrue(waitUntilEnabled(verificationContinue))
        verificationContinue.tap()

        XCTAssertTrue(
            app.buttons["onboarding.role.continue"]
                .waitForExistence(timeout: 3)
        )
        app.buttons["onboarding.role.continue"].tap()
        app.buttons["onboarding.responsibilities.continue"].tap()

        let deviceLock = app.switches["onboarding.deviceLock"]
        XCTAssertTrue(deviceLock.waitForExistence(timeout: 3))
        tapTrailingControl(deviceLock)

        let securityContinue = app.buttons["onboarding.security.continue"]
        XCTAssertTrue(
            waitForLabel("Fortsätt utan applås", on: securityContinue)
        )
        securityContinue.tap()

        let notificationsContinue = app.buttons["onboarding.notifications.continue"]
        XCTAssertTrue(notificationsContinue.waitForExistence(timeout: 3))
        notificationsContinue.tap()

        let integrationsContinue = app.buttons["onboarding.integrations.continue"]
        XCTAssertTrue(integrationsContinue.waitForExistence(timeout: 3))
        integrationsContinue.tap()

        let complete = app.buttons["onboarding.complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 3))
        complete.tap()
        XCTAssertTrue(app.tabBars.buttons["Översikt"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func waitUntilEnabled(
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func waitForLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func tapTrailingControl(_ element: XCUIElement) {
        element.coordinate(
            withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)
        ).tap()
    }

    @MainActor
    private func dismissKeyboardIfPresent(in app: XCUIApplication) {
        let returnKey = app.buttons["Return"]
        if returnKey.exists {
            returnKey.tap()
        }
    }
}
