import XCTest

/// Stage 05 UI smoke: the optional Photo summary on a real imported photo.
///
/// It walks the real chain — create a project, import one system photo, open the
/// summary, wait for a real estimate, re-run, close, verify nothing in the editor
/// changed, and re-open to prove the sheet recomputes from scratch. It asserts no
/// visual quality and does not replace the owner's own device check.
final class Stage05PhotoSummaryUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func waitForLabel(_ item: XCUIElement, _ label: String, timeout: TimeInterval = 60) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label), object: item
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// The editor's non-navigation controls must enter the usable editor viewport
    /// through the *shared* bounded scroll helper before they are tapped: its
    /// navigation-bar-aware viewport and finite-frame limits are the real gate
    /// (`isHittable` alone is not enough — Stage03 native runs showed a partially
    /// visible button reporting hittable while the tap did nothing). No extra blind
    /// swipes and no mirrored viewport math here.
    private func tapEditorControl(_ item: XCUIElement, in app: XCUIApplication,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(item.waitForExistence(timeout: 30), "\(item.identifier) never appeared", file: file, line: line)
        XCTAssertTrue(scrollEditorToMakeHittable(item, in: app),
                      "\(item.identifier) never entered the usable editor viewport", file: file, line: line)
        XCTAssertTrue(item.waitUntilEnabledAndHittable(), "\(item.identifier) was not usable", file: file, line: line)
        item.tap()
    }

    /// The analysis rows are `.accessibilityElement(children: .contain)`
    /// containers, so they must be located as real elements — never as Text.
    private func rows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "analysis.row."))
    }

    private func estimates(in app: XCUIApplication) -> XCUIElementQuery {
        app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "analysis.estimate."))
    }

    func testPhotoSummaryAnalyzesRealPhotoAndLeavesTheProjectUnchanged() throws {
        let app = XCUIApplication()
        app.launch()

        let create = element("home.createProject", in: app)
        XCTAssertTrue(create.waitUntilEnabledAndHittable())
        let beforeProjects = homeProjectIdentifiers(in: app)
        create.tap()
        XCTAssertTrue(app.otherElements["editor.canvas"].waitForExistence(timeout: 45))
        let back = editorBackButton(in: app)
        XCTAssertTrue(back.waitUntilEnabledAndHittable())
        back.tap()
        XCTAssertTrue(create.waitUntilEnabledAndHittable())
        let newProjects = homeProjectIdentifiers(in: app).subtracting(beforeProjects)
        XCTAssertEqual(newProjects.count, 1)
        let projectID = try XCTUnwrap(newProjects.first)
        let projectRow = element(projectID, in: app)
        XCTAssertTrue(projectRow.waitUntilEnabledAndHittable())
        projectRow.tap()

        // Real import through the shared original picker helpers.
        tapEditorControl(element("editor.importPhotos", in: app), in: app)
        XCTAssertTrue(waitForPickerToOpen(in: app))
        let selection = selectFirstPhotoCell(in: app, session: "stage05 photo summary")
        XCTAssertTrue(selection.succeeded, selection.diagnostic)
        let confirmation = tapPickerAddButton(in: app)
        XCTAssertTrue(confirmation.succeeded, confirmation.diagnostic)
        XCTAssertTrue(waitForLabel(element("editor.photoCount", in: app), "1 of 20 photos"))
        XCTAssertTrue(waitForLabel(element("editor.layerCount", in: app), "0 of 20 layers"))

        // The entry is optional and must never change the project by itself.
        tapEditorControl(element("editor.photoSummary", in: app), in: app)
        XCTAssertTrue(element("analysis.status", in: app).waitForExistence(timeout: 45))
        XCTAssertTrue(waitForLabel(element("analysis.status", in: app), "Analyzed 1 of 1 photos"),
                      "The summary never reported one analyzed photo")
        XCTAssertEqual(estimates(in: app).count, 1, "Expected exactly one estimate row")

        // The row is a `.contain` container, not a Text: locate the real container
        // element and pin the single row's asset identity to the estimate's.
        let analysisRow = rows(in: app).firstMatch
        XCTAssertTrue(analysisRow.waitForExistence(timeout: 30), "The analysis row container was not exposed")
        XCTAssertEqual(rows(in: app).count, 1, "Expected exactly one analysis row container")
        XCTAssertEqual(app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "analysis.row.")).count, 0,
            "analysis.row. must be the container element, not a static text")
        let rowIdentity = String(analysisRow.identifier.dropFirst("analysis.row.".count))
        XCTAssertNotNil(UUID(uuidString: rowIdentity), "The row identity is not an asset UUID")
        let estimateIdentity = String(
            estimates(in: app).firstMatch.identifier.dropFirst("analysis.estimate.".count))
        XCTAssertEqual(rowIdentity, estimateIdentity, "The estimate must belong to the single row's asset")
        attachFullAppScreenshot(app, named: "Stage05 photo summary with one estimate")

        // Recompute on demand; the sheet must stay usable and still show a result.
        app.buttons["analysis.analyzeAgain"].tap()
        XCTAssertTrue(waitForLabel(element("analysis.status", in: app), "Analyzed 1 of 1 photos"),
                      "Analyze again did not finish")
        XCTAssertEqual(estimates(in: app).count, 1)

        // Closing cannot have written anything: still one photo, still zero layers.
        app.buttons["analysis.close"].tap()
        XCTAssertTrue(app.buttons["analysis.close"].waitForDisappearance(timeout: 30))
        XCTAssertTrue(waitForLabel(element("editor.photoCount", in: app), "1 of 20 photos"))
        XCTAssertTrue(waitForLabel(element("editor.layerCount", in: app), "0 of 20 layers"))

        // Re-opening starts from an empty state and analyzes again.
        tapEditorControl(element("editor.photoSummary", in: app), in: app)
        XCTAssertTrue(waitForLabel(element("analysis.status", in: app), "Analyzed 1 of 1 photos"),
                      "Re-opening the summary did not analyze again")
        XCTAssertEqual(estimates(in: app).count, 1)
        app.buttons["analysis.close"].tap()
        XCTAssertTrue(app.buttons["analysis.close"].waitForDisappearance(timeout: 30))
    }
}
