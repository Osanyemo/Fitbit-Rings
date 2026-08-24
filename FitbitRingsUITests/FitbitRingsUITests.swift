import XCTest

final class FitbitRingsUITests: XCTestCase {
    func testLaunchShowsOnboardingWhenSignedOut() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-signed-out"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Fitbit Rings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Connect Google Health"].exists)
    }

    func testPopulatedFixtureNavigatesAcrossDashboardTabs() {
        let app = populatedApp()

        for tab in ["Summary", "Activity", "Workouts", "Health"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 2))
        }
    }

    func testPopulatedFixtureOpensSettingsAndDisconnectConfirmation() {
        let app = populatedApp()

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        app.buttons["Disconnect Google Health"].tap()
        XCTAssertTrue(app.alerts["Disconnect Google Health?"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.alerts.buttons["Cancel"].exists)
        XCTAssertTrue(app.alerts.buttons["Disconnect"].exists)
    }

    func testPopulatedFixtureOpensWorkoutDetail() {
        let app = populatedApp()

        app.tabBars.buttons["Workouts"].tap()
        let workout = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Outdoor Walk")
        ).firstMatch
        XCTAssertTrue(workout.waitForExistence(timeout: 2))
        workout.tap()
        XCTAssertTrue(app.navigationBars["Outdoor Walk"].waitForExistence(timeout: 2))
    }

    func testLoadingEmptyAndRetryFixturesExposeHonestStates() {
        let loading = XCUIApplication()
        loading.launchArguments = ["-ui-test-loading"]
        loading.launch()
        XCTAssertTrue(loading.staticTexts["Loading activity"].waitForExistence(timeout: 5))

        loading.terminate()
        let empty = XCUIApplication()
        empty.launchArguments = ["-ui-test-empty"]
        empty.launch()
        XCTAssertTrue(empty.staticTexts["No summary data yet"].waitForExistence(timeout: 5))

        empty.terminate()
        let failed = XCUIApplication()
        failed.launchArguments = ["-ui-test-failed"]
        failed.launch()
        XCTAssertTrue(failed.staticTexts["Couldn’t refresh"].waitForExistence(timeout: 5))
        XCTAssertTrue(failed.buttons["Try Again"].exists)
    }

    @available(iOS 17.0, *)
    func testOnboardingAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-signed-out"]
        app.launch()

        try app.performAccessibilityAudit()
    }

    @available(iOS 17.0, *)
    func testPopulatedDashboardAccessibilityAudit() throws {
        let app = populatedApp()

        for tab in ["Summary", "Activity", "Workouts", "Health"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.navigationBars[tab].waitForExistence(timeout: 2))
            try app.performAccessibilityAudit()
        }
    }

    private func populatedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-populated"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Summary"].waitForExistence(timeout: 5))
        return app
    }
}
