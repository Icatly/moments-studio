import XCTest

/// Stage 02 UI smoke coverage.
///
/// These tests need a booted iOS simulator and were **not** executed on the
/// Windows host. The photo picker is system UI hosted over the app, so the
/// picker test asserts that the picker's own controls really appeared, presses
/// Cancel, and then checks the editor is usable again. A real multi-photo
/// import, the read-only preview and removal are manual checks with the
/// synthetic photos produced by `tools/generate_stage02_photo_fixtures.py`; see
/// the Stage 02 report.
final class Stage02ImportUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEditorShowsTheImportEntryForANewProject() {
        let app = XCUIApplication()
        app.launch()

        let createProject = app.buttons["home.createProject"]
        XCTAssertTrue(createProject.waitUntilEnabled(), "Home never became ready.")
        createProject.tap()

        XCTAssertTrue(
            app.staticTexts["editor.placeholder"].waitForExistence(timeout: 20),
            "The editor screen did not appear."
        )

        XCTAssertTrue(
            element("editor.importPhotos", in: app).waitUntilEnabled(),
            "The import entry is missing or not tappable."
        )
        XCTAssertTrue(app.staticTexts["editor.photoCount"].exists, "The photo counter is missing.")
        XCTAssertTrue(app.staticTexts["editor.galleryEmpty"].exists, "The empty gallery state is missing.")
    }

    func testImportPickerCanBeDismissedBackToTheEditor() {
        let app = XCUIApplication()
        app.launch()

        let createProject = app.buttons["home.createProject"]
        XCTAssertTrue(createProject.waitUntilEnabled(), "Home never became ready.")
        createProject.tap()

        let importEntry = element("editor.importPhotos", in: app)
        XCTAssertTrue(importEntry.waitUntilEnabled(), "The import entry never became tappable.")
        importEntry.tap()

        // The picker is system UI. Its own Cancel control is the concrete proof
        // that it opened, so this test cannot pass by doing nothing.
        let pickerCancel = app.buttons["Cancel"]
        let pickerNavigationBar = app.navigationBars["Photos"]

        let pickerAppeared = pickerCancel.waitForExistence(timeout: 20)
            || pickerNavigationBar.waitForExistence(timeout: 5)
        XCTAssertTrue(pickerAppeared, "The system photo picker did not appear.")
        XCTAssertTrue(pickerCancel.exists, "The picker is open but exposes no Cancel control.")

        pickerCancel.tap()

        // A real bounded absence wait: `waitForExistence` returns immediately
        // while the element still exists, so it cannot be used to assert that
        // the picker went away.
        XCTAssertTrue(
            pickerCancel.waitForDisappearance(),
            "Cancel must dismiss the picker instead of leaving it on screen."
        )

        let importEntryAfterDismissal = element("editor.importPhotos", in: app)
        XCTAssertTrue(
            importEntryAfterDismissal.waitUntilEnabled(),
            "The editor must be interactive again after the picker is dismissed."
        )
        XCTAssertTrue(
            importEntryAfterDismissal.isHittable,
            "The import entry must be hittable again after the picker is dismissed."
        )
    }

    /// The identifier is applied to a `PhotosPicker`, whose element type is not
    /// guaranteed, so match any element type.
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
