import XCTest

/// Minimal Stage 01 smoke coverage: the shell launches, Create Project opens the
/// editor placeholder, and back navigation returns Home.
///
/// Requires a booted iOS Simulator. These tests intentionally avoid the
/// project name (it is generated at runtime) and match accessibility
/// identifiers instead of visible copy.
final class Stage01SmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCreateProjectOpensEditorPlaceholder() {
        let app = XCUIApplication()
        app.launch()

        let createProject = app.buttons["home.createProject"]
        XCTAssertTrue(
            createProject.waitForExistence(timeout: 15),
            "Home did not show the Create Project action."
        )

        createProject.tap()

        XCTAssertTrue(
            app.staticTexts["editor.placeholder"].waitForExistence(timeout: 15),
            "The editor placeholder did not appear after creating a project."
        )
    }

    func testBackNavigationReturnsToHome() {
        let app = XCUIApplication()
        app.launch()

        let createProject = app.buttons["home.createProject"]
        XCTAssertTrue(createProject.waitForExistence(timeout: 15), "Home did not load.")
        createProject.tap()

        let placeholder = app.staticTexts["editor.placeholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 15), "The editor placeholder did not appear.")

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.exists, "The editor placeholder has no navigation bar back button.")
        backButton.tap()

        XCTAssertTrue(
            createProject.waitForExistence(timeout: 15),
            "Back navigation did not return to Home."
        )
    }
}
