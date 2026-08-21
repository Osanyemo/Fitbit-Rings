import XCTest

final class FitbitRingsUITests: XCTestCase {
    func testLaunchShowsOnboardingWhenSignedOut() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Fitbit Rings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Connect Google Health"].exists)
    }
}
