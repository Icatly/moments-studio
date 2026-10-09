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

    private func isFinitePositive(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.size.width.isFinite && rect.size.height.isFinite
            && !rect.isEmpty && rect.width > 0 && rect.height > 0
    }

    /// The viewport actually available to the layout sheet: the **unique**
    /// `layout.scroll` and its own sheet navigation bar, clipped by the app window,
    /// the identified navigation bar and the real keyboard.
    ///
    /// Real evidence (run 37957684567): with the search keyboard up,
    /// `layout.choose.offset` at y=541.3 inside the 0...874 window sat inside
    /// `layout.scroll` yet was covered by the keyboard. Every value that takes part
    /// is validated as finite and positive; a non-unique scope or non-finite
    /// geometry fails instead of being guessed.
    ///
    /// The navigation bar is **not** counted app-wide: the Editor behind the sheet
    /// owns its own bar, so `app.navigationBars.count == 1` would describe the whole
    /// app rather than this sheet. The sheet's own bar is the one this sheet already
    /// carries through its real `navigationTitle("Layouts")` — no new identifier is
    /// invented for the test. The exact `Layouts` bar must be unique and must be the
    /// bar that owns the sheet's Cancel/Apply toolbar items.
    private func usableViewport(in app: XCUIApplication) -> CGRect? {
        let scrolls = app.scrollViews.matching(identifier: "layout.scroll")
        let sheetNavigationBars = app.navigationBars.matching(identifier: "Layouts")
        guard scrolls.count == 1, sheetNavigationBars.count == 1 else {
            XCTFail("Expected exactly one layout.scroll and one Layouts sheet navigation bar, "
                + "found scrolls=\(scrolls.count) sheetNavigationBars=\(sheetNavigationBars.count)")
            return nil
        }
        let scrollFrame = scrolls.element.frame
        let appFrame = app.frame
        guard isFinitePositive(scrollFrame), isFinitePositive(appFrame) else {
            XCTFail("Non-finite layout geometry: scroll=\(scrollFrame) app=\(appFrame)")
            return nil
        }
        var viewport = scrollFrame.intersection(appFrame)
        let sheetNavigationBar = sheetNavigationBars.element
        let navigationFrame = sheetNavigationBar.frame
        guard isFinitePositive(navigationFrame) else {
            XCTFail("Non-finite sheet navigation frame \(navigationFrame)")
            return nil
        }
        // The identified bar must really be the layout sheet's own bar: its label is
        // the real navigation title "Layouts" and it owns the sheet's Cancel/Apply
        // toolbar items. This keeps the scope from silently pointing at some other bar.
        XCTAssertEqual(sheetNavigationBar.label, "Layouts",
                       "The identified bar is not the Layouts sheet navigation bar")
        for identifier in ["layout.cancel", "layout.apply"] {
            guard sheetNavigationBar.buttons.matching(identifier: identifier).firstMatch.exists else {
                XCTFail("The identified sheet navigation bar does not own \(identifier)")
                return nil
            }
        }
        if viewport.intersects(navigationFrame) {
            viewport = CGRect(x: viewport.minX, y: max(viewport.minY, navigationFrame.maxY),
                              width: viewport.width, height: viewport.maxY - max(viewport.minY, navigationFrame.maxY))
        }
        if app.keyboards.count > 0 {
            let keyboardFrame = app.keyboards.element.frame
            guard isFinitePositive(keyboardFrame) else {
                XCTFail("Non-finite keyboard frame \(keyboardFrame)")
                return nil
            }
            if viewport.intersects(keyboardFrame) {
                viewport = CGRect(x: viewport.minX, y: viewport.minY,
                                  width: viewport.width, height: min(viewport.maxY, keyboardFrame.minY) - viewport.minY)
            }
        }
        guard isFinitePositive(viewport) else {
            XCTFail("No usable layout viewport after clipping: \(viewport)")
            return nil
        }
        return viewport
    }

    /// Ends the search interaction with a real submit (the keyboard's Search key),
    /// which is the user path that uncovers the filtered results.
    private func submitSearch(_ search: XCUIElement, in app: XCUIApplication) {
        search.typeText("\n")
        XCTAssertTrue(app.keyboards.element.waitForDisappearance(timeout: 15),
                      "The search keyboard stayed up after submitting the search")
    }

    /// Moves the identified layout scroll view with bounded native drags whose
    /// endpoints are **real viewport points converted into scroll-relative
    /// normalized coordinates**, and taps the choice only when it is fully inside
    /// the usable viewport. A choice that is already inside the viewport but still
    /// not hittable fails loudly instead of guessing a direction.
    private func tapChoice(_ id: String, in app: XCUIApplication) {
        let item = app.buttons.matching(identifier: id).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 30))
        let scroll = app.scrollViews.matching(identifier: "layout.scroll").firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 30))

        for _ in 0..<5 {
            guard let viewport = usableViewport(in: app) else { return }
            let target = item.frame
            guard isFinitePositive(target) else {
                XCTFail("Non-finite choice frame \(target) for \(id)")
                return
            }
            if viewport.contains(target) {
                XCTAssertTrue(item.isHittable,
                              "Choice \(id) is inside the usable viewport \(viewport) but not hittable: \(target)")
                XCTAssertTrue(item.waitUntilEnabledAndHittable())
                item.tap()
                return
            }
            // The drag must happen in `layout.scroll`'s own coordinate space: the app
            // window origin is not guaranteed to be the scroll origin, so an app-based
            // absolute point could land outside the real scroll view. Both endpoints
            // are the actual viewport points re-expressed as normalized offsets inside
            // the identified scroll element.
            let scrollFrame = scroll.frame
            guard isFinitePositive(scrollFrame) else {
                XCTFail("Non-finite layout scroll frame \(scrollFrame)")
                return
            }
            let downward = target.maxY > viewport.maxY
            let overflow = downward ? target.maxY - viewport.maxY : viewport.minY - target.minY
            let travel = min(viewport.height * 0.3, max(viewport.height * 0.08, overflow + viewport.height * 0.05))
            let startY = downward ? viewport.maxY - viewport.height * 0.2 : viewport.minY + viewport.height * 0.2
            let endY = downward ? max(viewport.minY + 4, startY - travel) : min(viewport.maxY - 4, startY + travel)
            let normalizedX = (viewport.midX - scrollFrame.minX) / scrollFrame.width
            let normalizedStartY = (startY - scrollFrame.minY) / scrollFrame.height
            let normalizedEndY = (endY - scrollFrame.minY) / scrollFrame.height
            // Both endpoints are real points inside the viewport, and the viewport is
            // inside the scroll view, so they must stay normalized inside it: a value
            // outside 0...1 would mean the geometry no longer agrees and is not guessed.
            guard (0...1).contains(normalizedX),
                  (0...1).contains(normalizedStartY),
                  (0...1).contains(normalizedEndY) else {
                XCTFail("Layout drag endpoints are not inside layout.scroll: "
                    + "x=\(normalizedX) startY=\(normalizedStartY) endY=\(normalizedEndY) "
                    + "viewport=\(viewport) scroll=\(scrollFrame)")
                return
            }
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: normalizedX, dy: normalizedStartY))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: normalizedX, dy: normalizedEndY))
            start.press(forDuration: 0.12, thenDragTo: end,
                        withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        guard let viewport = usableViewport(in: app) else { return }
        XCTFail("Choice \(id) never entered the usable viewport: \(item.frame) in \(viewport)")
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
        // A real submit ends the search interaction, so the keyboard no longer
        // covers the filtered choice (run 37957684567) — and it must not clear the
        // query: the OFFSET filter is still in force afterwards.
        submitSearch(search, in: app)
        XCTAssertTrue(app.buttons.matching(identifier: "layout.choose.offset").firstMatch.exists,
                      "Submitting the search dropped the OFFSET filter result")
        XCTAssertFalse(app.buttons.matching(identifier: "layout.choose.grid").firstMatch.exists,
                       "Submitting the search cleared the OFFSET query")
        tapChoice("layout.choose.offset", in: app)
        XCTAssertEqual(app.buttons.matching(identifier: "layout.choose.offset").firstMatch.value as? String, "Selected")
        search.tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "OFFSET".count) + "unavailable")
        submitSearch(search, in: app)
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
