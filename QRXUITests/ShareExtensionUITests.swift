import XCTest

/// Drives Safari's share sheet into the QRX share extension — the only way to
/// exercise extension activation, content extraction, and the shared-store
/// write end to end.
final class ShareExtensionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testShareURLFromSafariSavesToLibrary() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()

        // Load a page. Tap the address bar and wait for keyboard focus —
        // relaunches with a page already loaded need a second tap.
        let addressBar = safari.textFields["Address"].firstMatch
        XCTAssertTrue(addressBar.waitForExistence(timeout: 10), "Safari address bar not found")
        addressBar.tap()
        if !safari.keyboards.firstMatch.waitForExistence(timeout: 3) {
            addressBar.tap()
            XCTAssertTrue(safari.keyboards.firstMatch.waitForExistence(timeout: 5), "keyboard never appeared")
        }
        safari.typeText("https://example.com\n")

        // Open the share sheet: direct toolbar button on older layouts, or
        // Safari 26's "…" menu → Share.
        let directShare = safari.buttons["ShareButton"].firstMatch
        if directShare.waitForExistence(timeout: 5) {
            directShare.tap()
        } else {
            let more = safari.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'menu' OR label CONTAINS[c] 'more'")
            ).firstMatch
            if !more.waitForExistence(timeout: 5) {
                print("SAFARI-TREE-BEGIN\n\(safari.debugDescription)\nSAFARI-TREE-END")
                XCTFail("no share entry point found in Safari")
                return
            }
            more.tap()
            let shareEntry = safari.buttons.matching(
                NSPredicate(format: "label BEGINSWITH[c] 'share'")
            ).firstMatch
            if !shareEntry.waitForExistence(timeout: 5) {
                print("SAFARI-TREE-BEGIN\n\(safari.debugDescription)\nSAFARI-TREE-END")
                XCTFail("no Share item in Safari menu")
                return
            }
            shareEntry.tap()
        }

        // Our extension appears as an activity named after the app. It may be
        // a button or a cell, and may sit past the fold of the activity row.
        let byLabel = NSPredicate(format: "label CONTAINS[c] 'QRX'")
        func findActivity() -> XCUIElement? {
            for query in [safari.buttons.matching(byLabel), safari.cells.matching(byLabel), safari.otherElements.matching(byLabel)] {
                let element = query.firstMatch
                if element.waitForExistence(timeout: 3) { return element }
            }
            return nil
        }
        var activity = findActivity()
        if activity == nil {
            safari.swipeUp()
            activity = findActivity()
        }
        guard let activity else {
            print("SAFARI-TREE-BEGIN\n\(safari.debugDescription)\nSAFARI-TREE-END")
            throw XCTSkip("QRX activity not visible in share sheet (may need enabling once on this device)")
        }
        activity.tap()

        // Extension UI: rendered code + Save.
        let saveButton = safari.buttons["Save"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 10), "share extension UI did not appear")
        saveButton.tap()

        // The app should now show the saved code. Note: the extension writes
        // to the real App Group store, so launch WITHOUT the in-memory flag.
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["example.com"].firstMatch.waitForExistence(timeout: 10))
    }
}
