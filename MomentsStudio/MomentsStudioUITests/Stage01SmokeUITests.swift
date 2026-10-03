import XCTest

/// Minimal Stage 01 smoke coverage: the shell launches, Create Project opens the
/// editor placeholder, and back navigation returns Home.
///
/// Requires a booted iOS Simulator. These tests intentionally avoid the
/// project name (it is generated at runtime) and match accessibility
/// identifiers instead of visible copy.
///
/// Since Stage 02, Home keeps Create Project disabled until the photo library
/// has finished loading, so these tests wait for the control to be *enabled*
/// rather than merely present.
final class Stage01SmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCreateProjectOpensEditorPlaceholder() {
        let app = XCUIApplication()
        app.launch()

        let createProject = app.buttons["home.createProject"]
        XCTAssertTrue(
            createProject.waitUntilEnabled(),
            "Home never showed an enabled Create Project action."
        )

        createProject.tap()

        XCTAssertTrue(
            app.staticTexts["editor.placeholder"].waitForExistence(timeout: 20),
            "The editor placeholder did not appear after creating a project."
        )
    }

    func testBackNavigationReturnsToHome() {
        let app = XCUIApplication()
        app.launch()

        let createProject = app.buttons["home.createProject"]
        XCTAssertTrue(createProject.waitUntilEnabled(), "Home never became ready.")
        createProject.tap()

        let placeholder = app.staticTexts["editor.placeholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 20), "The editor placeholder did not appear.")

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.exists, "The editor placeholder has no navigation bar back button.")
        backButton.tap()

        XCTAssertTrue(
            createProject.waitUntilEnabled(),
            "Back navigation did not return to a usable Home."
        )
    }
}
