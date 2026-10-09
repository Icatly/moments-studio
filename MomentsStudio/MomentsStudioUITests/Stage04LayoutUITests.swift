import XCTest

final class Stage04LayoutUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func waitForLabel(_ item: XCUIElement, _ label: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: item)
        return XCTWaiter().wait(for: [expectation], timeout: 45) == .completed
    }

    private func tapEditor(_ item: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(item.waitForExistence(timeout: 30))
        if !app.navigationBars.element.frame.contains(item.frame) {
            XCTAssertTrue(scrollEditorToMakeHittable(item, in: app))
        }
        XCTAssertTrue(item.waitUntilEnabledAndHittable())
        item.tap()
    }

    /// Only the identified layout scroll view is moved, with bounded native drags.
    private func tapChoice(_ id: String, in app: XCUIApplication) {
        let item = app.buttons.matching(identifier: id).firstMatch
        let scroll = app.scrollViews.matching(identifier: "layout.scroll").firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 30))
        XCTAssertTrue(item.waitForExistence(timeout: 30))
        for _ in 0..<5 {
            if scroll.frame.contains(item.frame), item.isHittable { break }
            let frame = scroll.frame
            XCTAssertGreaterThan(frame.height, 0)
            let downward = item.frame.maxY > frame.maxY
            let overflow = downward ? item.frame.maxY - frame.maxY : frame.minY - item.frame.minY
            let distance = min(0.3, max(0.08, overflow / max(1, frame.height) + 0.05))
            let startY = downward ? 0.7 : 0.3
            let endY = downward ? startY - distance : startY + distance
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                .press(forDuration: 0.12,
                       thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(scroll.frame.contains(item.frame), "Choice is not fully inside the layout viewport")
        XCTAssertTrue(item.waitUntilEnabledAndHittable())
        item.tap()
    }

    func testThreePreviewsSearchCancelApplyAndRestartKeepExactLayer() throws {
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
        let row = element(projectID, in: app)
        XCTAssertTrue(row.waitUntilEnabledAndHittable())
        row.tap()

        tapEditor(element("editor.importPhotos", in: app), in: app)
        XCTAssertTrue(waitForPickerToOpen(in: app))
        let selection = selectFirstPhotoCell(in: app, session: "stage04 layout import")
        XCTAssertTrue(selection.succeeded, selection.diagnostic)
        let confirmation = tapPickerAddButton(in: app)
        XCTAssertTrue(confirmation.succeeded, confirmation.diagnostic)
        XCTAssertTrue(waitForLabel(element("editor.photoCount", in: app), "1 of 20 photos"))
        XCTAssertTrue(waitForLabel(element("editor.layerCount", in: app), "0 of 20 layers"))

        tapEditor(element("editor.layouts", in: app), in: app)
        for name in ["grid", "focus", "offset"] {
            XCTAssertTrue(app.buttons.matching(identifier: "layout.choose." + name).firstMatch.waitForExistence(timeout: 30))
            XCTAssertTrue(element("layout.preview." + name, in: app).waitForExistence(timeout: 30))
        }
        XCTAssertFalse(app.buttons["layout.apply"].isEnabled)
        attachFullAppScreenshot(app, named: "Stage04 layout previews before apply")
        tapChoice("layout.choose.grid", in: app)
        XCTAssertTrue(app.buttons["layout.apply"].waitUntilEnabledAndHittable())
        app.buttons["layout.cancel"].tap()
        XCTAssertTrue(app.buttons["layout.cancel"].waitForDisappearance())
        XCTAssertTrue(waitForLabel(element("editor.layerCount", in: app), "0 of 20 layers"))

        tapEditor(element("editor.layouts", in: app), in: app)
        let searches = app.searchFields.matching(NSPredicate(format: "placeholderValue == %@", "Find a layout"))
        let search = searches.firstMatch
        XCTAssertTrue(search.waitUntilEnabledAndHittable())
        XCTAssertEqual(searches.count, 1)
        search.tap()
        search.typeText("OFFSET")
        XCTAssertTrue(app.buttons.matching(identifier: "layout.choose.grid").firstMatch.waitForDisappearance())
        tapChoice("layout.choose.offset", in: app)
        XCTAssertEqual(app.buttons.matching(identifier: "layout.choose.offset").firstMatch.value as? String, "Selected")
        search.tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "OFFSET".count) + "unavailable")
        XCTAssertTrue(element("layout.noResults", in: app).waitForExistence(timeout: 30))
        XCTAssertTrue(waitForLabel(element("layout.selection", in: app), "Selected layout: Offset"))
        let clear = app.buttons["layout.clearSearch"]
        XCTAssertTrue(clear.waitUntilEnabledAndHittable())
        clear.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "layout.choose.grid").firstMatch.waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["layout.apply"].waitUntilEnabledAndHittable())
        app.buttons["layout.apply"].tap()
        XCTAssertTrue(app.buttons["layout.apply"].waitForDisappearance(timeout: 60))
        XCTAssertTrue(waitForLabel(element("editor.layerCount", in: app), "1 of 20 layers"))

        let layerQuery = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.selectLayer."))
        let layerIDs = Set(layerQuery.allElementsBoundByIndex.map(\.identifier))
        XCTAssertEqual(layerIDs.count, 1)
        let layerID = try XCTUnwrap(layerIDs.first)
        tapEditor(element(layerID, in: app), in: app)
        let transform = element("editor.layerTransform", in: app).label
        XCTAssertFalse(transform.isEmpty)
        tapEditor(element("editor.layouts", in: app), in: app)
        tapChoice("layout.choose.offset", in: app)
        XCTAssertTrue(app.buttons["layout.apply"].waitUntilEnabledAndHittable())
        app.buttons["layout.apply"].tap()
        XCTAssertTrue(app.buttons["layout.apply"].waitForDisappearance(timeout: 60))
        XCTAssertTrue(waitForLabel(element("editor.layerCount", in: app), "1 of 20 layers"))
        XCTAssertEqual(Set(layerQuery.allElementsBoundByIndex.map(\.identifier)), layerIDs)
        XCTAssertTrue(waitForLabel(element("editor.layerTransform", in: app), transform))
        tapEditor(element("editor.done", in: app), in: app)
        XCTAssertTrue(create.waitUntilEnabledAndHittable())
        app.terminate()
        app.launch()
        XCTAssertTrue(create.waitUntilEnabledAndHittable())
        let restored = element(projectID, in: app)
        XCTAssertTrue(restored.waitUntilEnabledAndHittable())
        restored.tap()
        XCTAssertTrue(waitForLabel(element("editor.layerCount", in: app), "1 of 20 layers"))
        XCTAssertTrue(waitForLabel(element("editor.photoCount", in: app), "1 of 20 photos"))
        tapEditor(element(layerID, in: app), in: app)
        XCTAssertTrue(waitForLabel(element("editor.layerTransform", in: app), transform))
        attachFullAppScreenshot(app, named: "Stage04 applied layout after restart")
    }
}
