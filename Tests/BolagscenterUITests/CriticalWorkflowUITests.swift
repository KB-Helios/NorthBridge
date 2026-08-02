import XCTest

@MainActor
final class CriticalWorkflowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFiveRootTabsAndSettingsHubAreReachable() {
        let app = launchSeeded()
        let destinations = [
            ("tab.overview", "Översikt"),
            ("tab.finance", "Ekonomi"),
            ("tab.company", "Bolag"),
            ("tab.documents", "Dokument"),
            ("tab.search", "Sök"),
        ]

        for (identifier, title) in destinations {
            let tab = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(
                tab.waitForExistence(timeout: 5),
                "Tabben \(identifier) saknas"
            )
            tab.tap()
            XCTAssertTrue(
                app.navigationBars[title].waitForExistence(timeout: 3),
                "Rotvyn \(title) öppnades inte"
            )
        }

        app.descendants(matching: .any)["tab.overview"].tap()
        let settingsButton = app.buttons["settings.open"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["settings.hub"]
                .waitForExistence(timeout: 5)
        )
    }

    func testAddsAndSelectsACompany() {
        let app = launchSeeded()
        let switcher = app.buttons["company.switcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))

        switcher.tap()
        app.buttons["Lägg till bolag"].tap()

        app.textFields["company.add.organisationNumber"]
            .tapAndType("5599991238")
        app.textFields["company.add.name"]
            .tapAndType("Östra UI Test AB")
        dismissKeyboardIfPresent(in: app)
        let confirmation = app.switches["company.add.confirm"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        tapTrailingControl(confirmation)
        let saveButton = app.buttons["company.add.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        XCTAssertTrue(waitUntilEnabled(saveButton))
        saveButton.tap()

        XCTAssertTrue(
            waitForValue(
                "Östra UI Test AB",
                on: app.buttons["company.switcher"]
            )
        )
    }

    func testSwitchesBetweenAuthorizedCompanies() {
        let app = launchSeeded()
        let switcher = app.buttons["company.switcher"]
        XCTAssertTrue(switcher.waitForExistence(timeout: 5))

        switcher.tap()
        app.buttons["Sydlig Test AB"].tap()

        XCTAssertTrue(waitForValue("Sydlig Test AB", on: switcher))
    }

    func testCreatesBoardMeeting() {
        let app = launchSeeded(route: "board")
        let createButton = app.buttons["board.createMeeting"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        app.textFields["board.meeting.title"]
            .replaceText(with: "Strategimöte UI")
        app.textFields["board.meeting.location"]
            .tapAndType("Stockholm")
        app.buttons["board.meeting.save"].tap()

        XCTAssertTrue(
            app.staticTexts["Strategimöte UI"]
                .waitForExistence(timeout: 5)
        )
    }

    func testRegistersBoardDecision() {
        let app = launchSeeded(route: "board")
        let meeting = app.staticTexts["UI-testmöte"]
        XCTAssertTrue(meeting.waitForExistence(timeout: 5))
        meeting.tap()

        let createDecision = app.buttons["board.resolution.create"]
        scrollUntilHittable(createDecision, in: app)
        createDecision.tap()

        app.textFields["board.resolution.title"]
            .tapAndType("Beslut om UI-test")
        app.descendants(matching: .any)["board.resolution.text"]
            .tapAndType("Styrelsen beslutade att godkänna UI-testet.")
        app.buttons["board.resolution.save"].tap()

        XCTAssertTrue(
            app.staticTexts["Beslut om UI-test"]
                .waitForExistence(timeout: 5)
        )
    }

    func testImportsDocumentAndPersistsMetadata() {
        let app = launchSeeded(
            route: "documents",
            extraArguments: ["-ui-testing-document-import"]
        )
        let approve = app.buttons["document.import.confirm"]
        XCTAssertTrue(approve.waitForExistence(timeout: 5))
        approve.tap()

        XCTAssertTrue(
            app.staticTexts["UI-testdokument"]
                .waitForExistence(timeout: 5)
        )
    }

    func testAddsShareholder() {
        let app = launchSeeded(route: "ownership")
        let addMenu = app.buttons["ownership.add"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5))
        addMenu.tap()
        app.buttons["Lägg till aktieägare"].tap()

        app.textFields["ownership.shareholder.name"]
            .tapAndType("Anna Testägare")
        app.buttons["ownership.shareholder.save"].tap()

        XCTAssertTrue(
            app.staticTexts["Anna Testägare"]
                .waitForExistence(timeout: 5)
        )
    }

    func testCreatesShareCertificateDraft() {
        let app = launchSeeded(route: "certificates")
        let addButton = app.buttons["ownership.certificate.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let saveButton = app.buttons["ownership.certificate.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        XCTAssertTrue(
            app.staticTexts["Utkast"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["Skapa PDF"].exists)
    }

    func testShowsExplicitOfflineState() {
        let app = launchSeeded(
            extraArguments: ["-ui-testing-offline"]
        )
        let offline = app.descendants(matching: .any)["connectivity.offline"]
        XCTAssertTrue(offline.waitForExistence(timeout: 5))
        XCTAssertTrue(offline.label.contains("Offline"))
    }

    func testShowsExpiredSessionAndRequiresSignIn() {
        let app = launchSeeded(
            extraArguments: ["-ui-testing-expired"]
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["authentication.sessionExpired"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["authentication.signIn"].exists)
    }

    func testExportsPortableCompanyData() {
        let app = launchSeeded(route: "account")
        let createExport = app.buttons["account.export.create"]
        XCTAssertTrue(createExport.waitForExistence(timeout: 5))
        createExport.tap()

        XCTAssertTrue(
            app.buttons["account.export.share"]
                .waitForExistence(timeout: 5)
        )
    }

    func testExportsCompanyOverviewPDF() {
        let app = launchSeeded(route: "search")
        let createExport = app.buttons["search.exportCompanyOverview"]
        XCTAssertTrue(createExport.waitForExistence(timeout: 5))
        createExport.tap()

        XCTAssertTrue(
            app.buttons["search.shareCompanyOverview"]
                .waitForExistence(timeout: 5)
        )
    }

    func testDashboardAccessibilityAudit() throws {
        let app = launchSeeded()
        XCTAssertTrue(
            app.navigationBars["Översikt"].waitForExistence(timeout: 5)
        )
        try app.performAccessibilityAudit(
            for: [
                .elementDetection,
                .hitRegion,
                .sufficientElementDescription,
                .trait
            ]
        )
    }

    func testDashboardAtLargestDynamicType() throws {
        let app = launchSeeded(
            extraArguments: [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
            ]
        )
        XCTAssertTrue(
            app.navigationBars["Översikt"].waitForExistence(timeout: 5)
        )
        try app.performAccessibilityAudit(
            for: [.dynamicType, .textClipped]
        )
        attachScreenshot(of: app, named: "dashboard-ax5")
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

    private func waitForValue(
        _ value: String,
        on element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        return XCTWaiter.wait(
            for: [expectation],
            timeout: timeout
        ) == .completed
    }

    private func waitUntilEnabled(
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: element
        )
        return XCTWaiter.wait(
            for: [expectation],
            timeout: timeout
        ) == .completed
    }

    private func tapTrailingControl(_ element: XCUIElement) {
        element.coordinate(
            withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)
        ).tap()
    }

    private func dismissKeyboardIfPresent(in app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }

        let submitKey = app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ OR identifier == %@",
                "Done",
                "Return"
            )
        ).firstMatch
        XCTAssertTrue(submitKey.waitForExistence(timeout: 3))
        submitKey.tap()
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: keyboard
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 3),
            .completed
        )
    }

    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        var attempts = 0
        while !element.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(element.isHittable)
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

@MainActor
private extension XCUIElement {
    func tapAndType(_ text: String) {
        tap()
        typeText(text)
    }

    func replaceText(with text: String) {
        tap()
        typeText(
            String(
                repeating: XCUIKeyboardKey.delete.rawValue,
                count: 64
            )
        )
        typeText(text)
    }
}
