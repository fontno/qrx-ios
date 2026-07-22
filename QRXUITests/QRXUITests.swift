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

    /// Taps Save in the builder and confirms the name alert. The confirm tap
    /// can land while the alert is still animating in and get swallowed, so
    /// retry once if the alert is still on screen.
    private func saveViaAlert(_ app: XCUIApplication) {
        app.buttons["builder.save"].tap()
        let alert = app.alerts["Save Code"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Save"].tap()
        if alert.waitForExistence(timeout: 2) {
            alert.buttons["Save"].tap()
        }
    }

    func testEmptyLibraryShowsCreateCallToAction() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["No Codes Yet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["library.createFirst"].exists)
    }

    func testCreateSaveAndReopenCode() {
        let app = launchApp()

        app.buttons["library.createFirst"].tap()

        // Default URL content renders immediately; the live scan check must
        // pass. Generous timeout: CI runners cold-start CoreImage slowly.
        XCTAssertTrue(app.staticTexts["Scans"].waitForExistence(timeout: 30))

        saveViaAlert(app)

        // Back in the library: the saved row exists with the suggested name.
        let row = app.staticTexts["example.com"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // Reopening restores the editor for that code. The Duplicate button
        // only exists when editing a saved code, so it proves the reopen.
        // (Don't assert on the nav title: it truncates with three toolbar items.)
        row.tap()
        XCTAssertTrue(app.buttons["builder.duplicate"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["builder.save"].exists)
    }

    func testLibraryTogglesBetweenListAndGrid() {
        let app = launchApp()
        app.buttons["library.createFirst"].tap()
        XCTAssertTrue(app.buttons["builder.save"].waitForExistence(timeout: 5))
        saveViaAlert(app)
        XCTAssertTrue(app.staticTexts["example.com"].waitForExistence(timeout: 5))

        let toggle = app.buttons["library.viewMode"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        // Grid still shows the code's name.
        XCTAssertTrue(app.staticTexts["example.com"].waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(app.staticTexts["example.com"].waitForExistence(timeout: 5))
    }

    func testTappingPreviewShowsFullScreenCode() {
        let app = launchApp()
        app.buttons["library.createFirst"].tap()
        let preview = app.descendants(matching: .any).matching(identifier: "builder.preview").firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        preview.tap()
        XCTAssertTrue(app.buttons["present.share"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["present.download"].exists)
        let close = app.buttons["present.close"]
        XCTAssertTrue(close.exists)
        close.tap()
        XCTAssertTrue(app.buttons["builder.save"].waitForExistence(timeout: 5))
    }

    func testShareMenuOffersPNGAndSVG() {
        let app = launchApp()
        app.buttons["library.createFirst"].tap()
        let shareMenu = app.buttons["builder.shareMenu"]
        XCTAssertTrue(shareMenu.waitForExistence(timeout: 5))
        shareMenu.tap()
        XCTAssertTrue(app.buttons["Share PNG"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share SVG (vector)"].exists)
    }

    func testDuplicateCreatesEditableCopy() {
        let app = launchApp()

        // Create and save a code, reopen it, duplicate it.
        app.buttons["library.createFirst"].tap()
        XCTAssertTrue(app.buttons["builder.save"].waitForExistence(timeout: 5))
        saveViaAlert(app)

        let row = app.staticTexts["example.com"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let duplicate = app.buttons["builder.duplicate"]
        XCTAssertTrue(duplicate.waitForExistence(timeout: 5))
        duplicate.tap()

        XCTAssertTrue(app.staticTexts["example.com Copy"].waitForExistence(timeout: 5))
    }
}
