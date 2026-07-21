import XCTest

/// Smoke tests for the primary user journey. Logic lives in QRCoreTests and
/// QRXTests; these only prove the screens are wired together.
final class QRXUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-inmemory"]
        app.launch()
        return app
    }

    func testEmptyLibraryShowsCreateCallToAction() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["No Codes Yet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["library.createFirst"].exists)
    }

    func testCreateSaveAndReopenCode() {
        let app = launchApp()

        app.buttons["library.createFirst"].tap()

        // Default URL content renders immediately; the live scan check must pass.
        XCTAssertTrue(app.staticTexts["Scans"].waitForExistence(timeout: 10))

        app.buttons["builder.save"].tap()
        let alert = app.alerts["Save Code"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Save"].tap()

        // Back in the library: the saved row exists with the suggested name.
        let row = app.staticTexts["example.com"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // Reopening restores the editor for that code.
        row.tap()
        XCTAssertTrue(app.navigationBars["example.com"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["builder.save"].exists)
    }

    func testShareActionsAvailableWhenCodeHasContent() {
        let app = launchApp()
        app.buttons["library.createFirst"].tap()
        XCTAssertTrue(app.buttons["builder.sharePNG"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["builder.shareSVG"].exists)
    }
}
