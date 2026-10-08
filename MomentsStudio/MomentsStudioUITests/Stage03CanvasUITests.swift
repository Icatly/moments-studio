import XCTest

/// Stage 03 UI smoke: the complete editing chain on a real imported photo.
///
/// It calls the **shared original** Stage 02 helpers that live in
/// `UITestSupport` (`selectFirstPhotoCell(in:session:)`, `tapPickerAddButton(in:)`,
/// `element(_:in:)`, `photoCount(in:)`, `homeProjectIdentifiers(in:)`,
/// `scrollEditorToMakeHittable(_:in:)`, `waitForPickerToOpen(in:)`,
/// `editorBackButton(in:)`), so the exact scope, Close and Popover rules are reused
/// rather than re-implemented. The Stage 02 test file itself is not touched.
///
/// Identity rules this test follows (Round 02 review):
///
/// * Layer identity comes **only** from the app's own dynamic
///   `editor.selectLayer.<layerUUID>` buttons. The first add yields the first
///   identity set; the second add's **set difference** is the newly added top
///   layer. No query in this file falls back to an arbitrary element when its
///   exact target is missing: every dynamic lookup is by the app's full
///   identifier, and a miss returns a non-existent proxy that fails loudly.
/// * The ordinal number and the hidden/locked flags are read from the
///   `editor.selectLayer.<layerUUID>` button's own accessibility label, which the
///   app declares as `Select layer N, Photo[, hidden][, locked]`. The container
///   `editor.layerRow.<UUID>` label is never used.
/// * The non-default state (hidden + locked) is applied to the **other** layer and
///   kept until the process is terminated, so the restart really has to restore
///   it; the target layer keeps a changed transform and a changed stacking order.
///
/// The two-finger gesture is **not** claimed here: the button steps are the
/// accessibility alternative, and real pinch/rotate needs a device run.
final class Stage03CanvasUITests: XCTestCase {

    /// Prefixes of the app's own dynamic layer identifiers.
    private let selectLayerPrefix = "editor.selectLayer."
    private let addLayerPrefix = "editor.addLayer."

    override func setUp() {
        super.setUp()
        // One failing step stops the chain: continuing would run later assertions
        // against a screen an earlier failure already left in the wrong state.
        continueAfterFailure = false
    }

    /// Waits until a label actually reaches the expected value (not merely exists).
    private func waitForLabel(_ element: XCUIElement, toEqual expected: String, timeout: TimeInterval = 60) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForLabel(_ element: XCUIElement, containing fragment: String, timeout: TimeInterval = 60) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", fragment)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Taps a tool only after confirming it is enabled and hittable, scrolling the
    /// editor's single scroll container when needed. No off-screen coordinate taps.
    private func activate(_ tool: XCUIElement, in app: XCUIApplication, named name: String,
                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(tool.waitForExistence(timeout: 45), "\(name) never appeared.", file: file, line: line)
        if !tool.isHittable {
            XCTAssertTrue(scrollEditorToMakeHittable(tool, in: app), "\(name) never became hittable.", file: file, line: line)
        }
        // Waits for the save to release the control instead of asserting immediately.
        XCTAssertTrue(tool.waitUntilEnabledAndHittable(), "\(name) never became enabled and hittable.", file: file, line: line)
        tool.tap()
    }

    // MARK: - Layer identity, read only from the app's own identifiers

    /// The raw layer-UUID suffixes of every `app.buttons` element whose identifier
    /// starts with `editor.selectLayer.`. The list is returned as read; callers
    /// deduplicate exactly like the shared Stage 02 thumbnail helper does, because
    /// one SwiftUI button can be exposed as several accessibility nodes.
    private func selectLayerIdentifiers(in app: XCUIApplication) -> [String] {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", selectLayerPrefix))
        var identifiers: [String] = []
        for index in 0..<query.count {
            let identifier = query.element(boundBy: index).identifier
            guard identifier.hasPrefix(selectLayerPrefix) else { continue }
            identifiers.append(String(identifier.dropFirst(selectLayerPrefix.count)))
        }
        return identifiers
    }

    /// The distinct layer UUIDs currently exposed by the app.
    private func distinctSelectLayerUUIDs(in app: XCUIApplication) -> Set<String> {
        Set(selectLayerIdentifiers(in: app))
    }

    /// The exact button of one recorded layer UUID, queried through the app's own
    /// `editor.selectLayer.<UUID>` identifier. A missing layer yields a
    /// non-existent proxy, so the caller's `waitForExistence` fails; this never
    /// falls back to an arbitrary element.
    private func selectLayerButton(_ layerID: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: selectLayerPrefix + layerID).firstMatch
    }

    /// The imported asset buttons (`editor.addLayer.<assetUUID>`).
    private func addLayerButtons(in app: XCUIApplication) -> [XCUIElement] {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", addLayerPrefix))
        return (0..<query.count).map { query.element(boundBy: $0) }
    }

    /// Bounded poll for the number of **distinct** `editor.selectLayer.<UUID>`
    /// buttons. A set of dynamic identifiers cannot be expressed as one element
    /// predicate, so this waits explicitly with a fixed sleep between reads; the
    /// caller still asserts the exact identities afterwards.
    private func waitForSelectLayerCount(_ expected: Int, in app: XCUIApplication,
                                         timeout: TimeInterval = 30) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if distinctSelectLayerUUIDs(in: app).count == expected { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return distinctSelectLayerUUIDs(in: app).count == expected
    }

    /// The ordinal the app itself puts into its accessibility label
    /// (`Select layer 2, Photo, hidden, locked` → `2`), or `nil` when the label is
    /// not the app's declared `Select layer N, …` form.
    private func layerOrdinal(fromLabel label: String) -> Int? {
        let prefix = "Select layer "
        guard label.hasPrefix(prefix) else { return nil }
        let digits = label.dropFirst(prefix.count).prefix(while: { $0.isNumber })
        guard !digits.isEmpty else { return nil }
        return Int(digits)
    }

    /// Real, bounded scroll back to the top of the Editor's single scroll
    /// container.
    ///
    /// The Layer list and its "Add to canvas" grid sit above the import controls in
    /// lazy content, so an earlier scroll can leave the grid outside the rendered
    /// viewport. This performs at most four ordinary user swipes on the one scroll
    /// view and taps nothing; the caller's existence, enabled and hittable checks
    /// still decide whether the target is really usable.
    private func scrollEditorToTop(in app: XCUIApplication, swipes: Int = 4) {
        guard element("editor.placeholder", in: app).exists, app.scrollViews.count == 1 else { return }
        let scrollView = app.scrollViews.element
        for _ in 0..<swipes {
            guard scrollView.exists else { return }
            scrollView.swipeDown()
        }
    }

    func testImportEditPersistAndRemoveLayerKeepingTheAsset() {
        let app = XCUIApplication()
        app.launch()

        // 1. Home must be ready before the baseline is read, and the baseline is only
        // meaningful while Home is actually on screen.
        let createProject = element("home.createProject", in: app)
        XCTAssertTrue(createProject.waitUntilEnabledAndHittable(), "Home was not ready.")
        let projectsBefore = homeProjectIdentifiers(in: app)
        createProject.tap()

        XCTAssertTrue(app.otherElements["editor.canvas"].waitForExistence(timeout: 60), "The canvas never appeared.")

        // Return to Home with the original back helper, wait for Home to be ready
        // again, and only then read the unique new project identity.
        let back = editorBackButton(in: app)
        XCTAssertTrue(back.waitUntilEnabledAndHittable(), "The editor back control was not usable.")
        back.tap()
        XCTAssertTrue(createProject.waitUntilEnabledAndHittable(), "Home did not become ready again.")
        let addedProjects = homeProjectIdentifiers(in: app).subtracting(projectsBefore)
        XCTAssertEqual(addedProjects.count, 1, "Exactly one new project row was expected, got \(addedProjects).")
        guard let projectIdentifier = addedProjects.first else {
            return XCTFail("The new project identity could not be read.")
        }

        // Open exactly that project and do the import inside it.
        let projectRow = element(projectIdentifier, in: app)
        XCTAssertTrue(projectRow.waitForExistence(timeout: 60), "The created project is missing from Home.")
        XCTAssertTrue(projectRow.waitUntilEnabledAndHittable(), "The created project row was not usable.")
        projectRow.tap()
        XCTAssertTrue(app.otherElements["editor.canvas"].waitForExistence(timeout: 60), "The new project did not open.")

        // 2. Real import through the shared original picker helpers.
        let importEntry = element("editor.importPhotos", in: app)
        XCTAssertTrue(importEntry.waitForExistence(timeout: 45), "The import entry never appeared.")
        XCTAssertTrue(scrollEditorToMakeHittable(importEntry, in: app), "The import entry never became hittable.")
        XCTAssertTrue(importEntry.waitUntilEnabledAndHittable(), "The import entry was not usable.")
        importEntry.tap()
        XCTAssertTrue(waitForPickerToOpen(in: app), "The Photos navigation never appeared.\n\(app.debugDescription)")

        let selection = selectFirstPhotoCell(in: app, session: "stage03 import")
        XCTAssertTrue(selection.succeeded, "No real photo could be selected: \(selection.diagnostic)")
        let confirmation = tapPickerAddButton(in: app)
        XCTAssertTrue(confirmation.succeeded, "The picker confirmation failed: \(confirmation.diagnostic)")

        let photoCountLabel = element("editor.photoCount", in: app)
        XCTAssertTrue(waitForLabel(photoCountLabel, toEqual: "1 of 20 photos"),
                      "The imported count never committed; got '\(photoCountLabel.label)'.")

        // The layer list above the import controls is lazy content: one bounded
        // user scroll returns to the top of the Editor's single scroll container
        // before the "Add to canvas" grid is queried.
        scrollEditorToTop(in: app)

        let assetButtons = addLayerButtons(in: app)
        XCTAssertEqual(assetButtons.count, 1,
                       "Exactly one imported asset button was expected, got \(assetButtons.map(\.identifier)).")
        guard let assetButton = assetButtons.first, assetButton.identifier.hasPrefix(addLayerPrefix) else {
            return XCTFail("The imported asset button could not be read: \(assetButtons.map(\.identifier)).")
        }
        let assetIdentifier = String(assetButton.identifier.dropFirst(addLayerPrefix.count))
        XCTAssertNotNil(UUID(uuidString: assetIdentifier),
                        "The asset identifier '\(assetIdentifier)' is not a valid UUID.")

        // 3. Two layers from the same asset. Layer identity is read only from the
        //    real `editor.selectLayer.<UUID>` buttons: the first add gives the first
        //    identity set, and the second add's set difference is the new top layer.
        let layerCountLabel = element("editor.layerCount", in: app)
        activate(assetButton, in: app, named: "add to canvas (first layer)")
        XCTAssertTrue(waitForLabel(layerCountLabel, toEqual: "1 of 20 layers"), "The first layer was not committed.")
        XCTAssertTrue(waitForSelectLayerCount(1, in: app), "The first layer's select button did not appear.")
        let layersAfterFirstAdd = distinctSelectLayerUUIDs(in: app)
        XCTAssertEqual(layersAfterFirstAdd.count, 1,
                       "The first add must expose exactly one layer identity, got \(layersAfterFirstAdd).")
        for identifier in layersAfterFirstAdd {
            XCTAssertNotNil(UUID(uuidString: identifier), "Layer identifier '\(identifier)' is not a valid UUID.")
        }

        activate(assetButton, in: app, named: "add to canvas (second layer)")
        XCTAssertTrue(waitForLabel(layerCountLabel, toEqual: "2 of 20 layers"), "The second layer was not committed.")
        XCTAssertTrue(waitForSelectLayerCount(2, in: app), "The second layer's select button did not appear.")
        let layersAfterSecondAdd = distinctSelectLayerUUIDs(in: app)
        XCTAssertEqual(layersAfterSecondAdd.count, 2,
                       "Two distinct layer identities were expected, got \(layersAfterSecondAdd).")
        for identifier in layersAfterSecondAdd {
            XCTAssertNotNil(UUID(uuidString: identifier), "Layer identifier '\(identifier)' is not a valid UUID.")
        }

        let newLayerIdentities = layersAfterSecondAdd.subtracting(layersAfterFirstAdd)
        XCTAssertEqual(newLayerIdentities.count, 1,
                       "The second add must introduce exactly one new layer identity, got \(newLayerIdentities).")
        XCTAssertTrue(layersAfterFirstAdd.isSubset(of: layersAfterSecondAdd),
                      "The first layer identity changed when the second layer was added.")
        guard let targetID = newLayerIdentities.first, let otherID = layersAfterFirstAdd.first else {
            return XCTFail("The two fixed layer identities could not be determined.")
        }
        XCTAssertNotEqual(targetID, otherID, "The two layers must keep distinct UUIDs.")

        let targetButton = selectLayerButton(targetID, in: app)
        let otherButton = selectLayerButton(otherID, in: app)
        XCTAssertTrue(targetButton.waitForExistence(timeout: 45), "The target layer button is missing.")
        XCTAssertTrue(otherButton.waitForExistence(timeout: 45), "The other layer button is missing.")
        // The new layer is added on top: number 2 in the app's back-to-front
        // numbering, while the first layer stays number 1.
        XCTAssertEqual(targetButton.label, "Select layer 2, Photo",
                       "The newly added layer is not the app's number 2 default layer; got '\(targetButton.label)'.")
        XCTAssertEqual(otherButton.label, "Select layer 1, Photo",
                       "The first layer is not the app's number 1 default layer; got '\(otherButton.label)'.")
        XCTAssertEqual(layerOrdinal(fromLabel: targetButton.label), 2, "The new top layer's ordinal is not 2.")
        XCTAssertEqual(layerOrdinal(fromLabel: otherButton.label), 1, "The first layer's ordinal is not 1.")

        // 4. Fix the target (number 2, top) and drag it on the real canvas
        //    (element-relative drag; never a screen coordinate).
        activate(targetButton, in: app, named: "select the top layer (number 2)")
        let transformReadout = element("editor.layerTransform", in: app)
        XCTAssertTrue(transformReadout.waitForExistence(timeout: 45), "The transform readout is missing.")
        let transformAfterSelect = transformReadout.label

        let surface = element("editor.canvasSurface", in: app)
        XCTAssertTrue(surface.waitForExistence(timeout: 45), "The canvas surface is missing.")
        XCTAssertTrue(surface.waitUntilHittable(), "The canvas surface was not hittable for the drag.")
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.15, thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.58)))
        let dragExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", transformAfterSelect),
            object: element("editor.layerTransform", in: app)
        )
        XCTAssertEqual(XCTWaiter().wait(for: [dragExpectation], timeout: 30), .completed,
                       "Dragging the top layer did not change its transform.")

        // 5. Button transforms, each step waiting for its own real result:
        //    `Larger` must reach 110% before `Rotate right` is tapped, and the
        //    rotation must then reach 5 degrees. No merged single-change wait.
        activate(element("editor.step.Larger", in: app), in: app, named: "Larger")
        let largerExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "110%"),
            object: element("editor.layerTransform", in: app)
        )
        XCTAssertEqual(XCTWaiter().wait(for: [largerExpectation], timeout: 30), .completed,
                       "Larger did not reach 110%; got '\(element("editor.layerTransform", in: app).label)'.")
        activate(element("editor.step.Rotateright", in: app), in: app, named: "Rotate right")
        let rotateExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "5°"),
            object: element("editor.layerTransform", in: app)
        )
        XCTAssertEqual(XCTWaiter().wait(for: [rotateExpectation], timeout: 30), .completed,
                       "Rotate right did not reach 5 degrees; got '\(element("editor.layerTransform", in: app).label)'.")
        let transformAfterButtons = element("editor.layerTransform", in: app).label

        // 6. Non-default state on the **other** layer, kept until the restart: its
        //    own select button's real label must report hidden and then locked. The
        //    container `editor.layerRow` label is never read.
        activate(element("editor.hideLayer.\(otherID)", in: app), in: app, named: "hide the other layer")
        XCTAssertTrue(waitForLabel(otherButton, containing: "hidden"),
                      "The other layer's select button never reported hidden; got '\(otherButton.label)'.")
        activate(element("editor.lockLayer.\(otherID)", in: app), in: app, named: "lock the other layer")
        XCTAssertTrue(waitForLabel(otherButton, containing: "locked"),
                      "The other layer's select button never reported locked; got '\(otherButton.label)'.")
        XCTAssertEqual(otherButton.label, "Select layer 1, Photo, hidden, locked",
                       "The other layer's real label is not the app's hidden+locked form; got '\(otherButton.label)'.")

        // 7. Re-select the fixed target and send it backwards: its own number must
        //    go 2 -> 1 and the other layer's 1 -> 2.
        activate(targetButton, in: app, named: "re-select the top layer for reordering")
        XCTAssertEqual(targetButton.label, "Select layer 2, Photo",
                       "The target layer must still be number 2 before the reorder; got '\(targetButton.label)'.")
        activate(element("editor.sendBackward", in: app), in: app, named: "Send backward")
        XCTAssertTrue(waitForLabel(targetButton, toEqual: "Select layer 1, Photo"),
                      "The target layer did not move from number 2 to 1; got '\(targetButton.label)'.")
        XCTAssertTrue(waitForLabel(otherButton, toEqual: "Select layer 2, Photo, hidden, locked"),
                      "The other layer did not move from number 1 to 2; got '\(otherButton.label)'.")

        // The two complete labels and the target transform are exactly what the
        // restart has to reproduce. The app commits the store only after the
        // manifest write returned, so a label reaching its expected value is a real
        // save signal; the explicit disappearance wait below adds the write gate.
        let targetLabelBeforeRestart = targetButton.label
        let otherLabelBeforeRestart = otherButton.label
        let transformBeforeRestart = element("editor.layerTransform", in: app).label
        XCTAssertEqual(transformBeforeRestart, transformAfterButtons,
                       "The reorder changed the target layer's transform.")
        XCTAssertTrue(element("editor.saving", in: app).waitForDisappearance(timeout: 60),
                      "The last edit never finished writing to disk.")

        // 8. Terminate and relaunch, then open **that** project only.
        app.terminate()
        app.launch()

        let restoredCreateProject = element("home.createProject", in: app)
        XCTAssertTrue(restoredCreateProject.waitUntilEnabledAndHittable(), "Home was not ready after the relaunch.")
        let restoredProjectRow = element(projectIdentifier, in: app)
        XCTAssertTrue(restoredProjectRow.waitForExistence(timeout: 60),
                      "The recorded project is missing after the relaunch.")
        XCTAssertTrue(restoredProjectRow.waitUntilEnabledAndHittable(), "The recorded project row was not usable.")
        restoredProjectRow.tap()

        XCTAssertTrue(app.otherElements["editor.canvas"].waitForExistence(timeout: 60),
                      "The recorded project did not reopen.")
        XCTAssertTrue(waitForLabel(element("editor.photoCount", in: app), toEqual: "1 of 20 photos"),
                      "The photo did not survive the relaunch.")
        XCTAssertTrue(waitForLabel(element("editor.layerCount", in: app), toEqual: "2 of 20 layers"),
                      "Both layers did not survive the relaunch.")

        // 9. Exact identity, full label and transform after the restart.
        let restoredTarget = selectLayerButton(targetID, in: app)
        let restoredOther = selectLayerButton(otherID, in: app)
        XCTAssertTrue(restoredTarget.waitForExistence(timeout: 60), "The target layer identity was not restored exactly.")
        XCTAssertTrue(restoredOther.waitForExistence(timeout: 60), "The other layer identity was not restored exactly.")
        XCTAssertEqual(restoredTarget.label, targetLabelBeforeRestart,
                       "The target layer's full label changed across the restart.")
        XCTAssertEqual(restoredOther.label, otherLabelBeforeRestart,
                       "The other layer's full label (number/order plus hidden/locked) changed across the restart.")
        activate(restoredTarget, in: app, named: "restored target layer")
        let restoredTransformReadout = element("editor.layerTransform", in: app)
        XCTAssertTrue(restoredTransformReadout.waitForExistence(timeout: 45),
                      "The transform readout is missing after the relaunch.")
        XCTAssertTrue(waitForLabel(restoredTransformReadout, toEqual: transformBeforeRestart),
                      "The target layer's transform changed across the restart; got '\(restoredTransformReadout.label)'.")

        // 10. Remove the fixed target: its own button must disappear, the layer
        //     count drop to 1, the other layer keep its hidden/locked state, and the
        //     same photo asset must still be available.
        activate(element("editor.removeLayer.\(targetID)", in: app), in: app, named: "remove the target layer")
        XCTAssertTrue(restoredTarget.waitForDisappearance(timeout: 60),
                      "The removed layer's select button never disappeared.")
        XCTAssertTrue(waitForLabel(element("editor.layerCount", in: app), toEqual: "1 of 20 layers"),
                      "Removing a layer did not reduce the layer count to 1.")
        XCTAssertTrue(restoredOther.exists, "The remaining layer disappeared with the removed one.")
        XCTAssertTrue(waitForLabel(restoredOther, toEqual: "Select layer 1, Photo, hidden, locked"),
                      "The remaining layer lost its number, hidden or locked state; got '\(restoredOther.label)'.")
        XCTAssertTrue(waitForLabel(element("editor.photoCount", in: app), toEqual: "1 of 20 photos"),
                      "The photo disappeared with the removed layer.")
        // The asset grid is lazy content above the layer rows: one bounded user
        // scroll brings it back into the rendered viewport before it is queried.
        scrollEditorToTop(in: app)
        XCTAssertTrue(element("editor.addLayer.\(assetIdentifier)", in: app).waitForExistence(timeout: 45),
                      "The same photo asset is no longer available after removing one of its layers.")
    }

    /// The canvas screen keeps the Stage 02 import entry and identifiers reachable.
    func testCanvasScreenKeepsTheStage02ImportEntryReachable() {
        let app = XCUIApplication()
        app.launch()
        let createProject = element("home.createProject", in: app)
        XCTAssertTrue(createProject.waitUntilEnabledAndHittable(), "Home Create Project was not usable.")
        createProject.tap()

        XCTAssertTrue(app.otherElements["editor.canvas"].waitForExistence(timeout: 60), "The canvas never appeared.")
        XCTAssertTrue(element("editor.importPhotos", in: app).waitForExistence(timeout: 30), "The import entry is gone.")
        XCTAssertTrue(element("editor.placeholder", in: app).exists, "The editor heading identifier is gone.")
        XCTAssertTrue(element("editor.layerCount", in: app).exists, "The layer count is missing.")
    }
}
