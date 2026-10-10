import XCTest

/// One real end-to-end path through the optional Photo roles sheet.
///
/// It imports two synthetic photos through the production picker flow, opens the
/// sheet from the real editor entry and waits for the real local evidence pass, then
/// proves actual behaviour with real values and real transforms:
/// * a saved manual choice and its **source** are shown when the sheet reopens;
/// * a draft change followed by Cancel leaves the stored choice alone;
/// * promoting another photo while an earlier manual primary exists demotes it;
/// * the saved choice survives an app restart;
/// * the real Focus preview/Apply puts the saved primary's layer in the hero cell
///   even when that photo is **not** the first one, and applying twice does not add,
///   drop or reshape a layer.
///
/// It imports only `XCTest`: the UI target never links the app module, and the shared
/// `XCTestCase` helpers in `UITestSupport.swift` provide every locator rule.
@MainActor
final class Stage06PhotoRolesUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Local helpers (this class only)

    /// Waits until an element's label reaches an exact value.
    private func waitForLabel(_ item: XCUIElement, _ label: String, timeout: TimeInterval = 45) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label), object: item
        )
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Taps one editor control.
    ///
    /// The element decides: an already-usable control is tapped directly, and only a
    /// control that cannot be tapped goes through the shared editor-scroll gate. That
    /// helper is **never** used for the layout sheet's own controls, and no whole-app
    /// navigation assumption is made.
    private func tapEditor(_ item: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(item.waitForExistence(timeout: 30))
        if !item.isHittable {
            XCTAssertTrue(scrollEditorToMakeHittable(item, in: app),
                          "\(item.identifier) never became reachable in the editor")
        }
        XCTAssertTrue(item.waitUntilEnabledAndHittable())
        item.tap()
    }

    /// True when a rect is finite, non-empty and has a positive size.
    private func layoutGeometryIsFiniteAndPositive(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.size.width.isFinite && rect.size.height.isFinite
            && !rect.isEmpty && rect.width > 0 && rect.height > 0
    }

    /// The viewport actually usable inside the layout sheet: the **unique**
    /// `layout.scroll`, clipped by the app window, that sheet's own `Layouts`
    /// navigation bar and the real keyboard.
    ///
    /// This is the minimum of the already-verified Stage 04 rule, re-implemented here
    /// on purpose: modifying the frozen Stage 04 file or extracting a shared helper
    /// would change its bytes. Every value is validated as finite and positive, and a
    /// non-unique scope fails instead of being guessed.
    private func layoutUsableViewport(in app: XCUIApplication) -> CGRect? {
        let scrolls = app.scrollViews.matching(identifier: "layout.scroll")
        let sheetNavigationBars = app.navigationBars.matching(identifier: "Layouts")
        guard scrolls.count == 1, sheetNavigationBars.count == 1 else {
            XCTFail("Expected exactly one layout.scroll and one Layouts sheet navigation bar, "
                + "found scrolls=\(scrolls.count) sheetNavigationBars=\(sheetNavigationBars.count)")
            return nil
        }
        let scrollFrame = scrolls.element.frame
        let appFrame = app.frame
        guard layoutGeometryIsFiniteAndPositive(scrollFrame), layoutGeometryIsFiniteAndPositive(appFrame) else {
            XCTFail("Non-finite layout geometry: scroll=\(scrollFrame) app=\(appFrame)")
            return nil
        }
        var viewport = scrollFrame.intersection(appFrame)
        let navigationFrame = sheetNavigationBars.element.frame
        guard layoutGeometryIsFiniteAndPositive(navigationFrame) else {
            XCTFail("Non-finite sheet navigation frame \(navigationFrame)")
            return nil
        }
        if viewport.intersects(navigationFrame) {
            let minY = max(viewport.minY, navigationFrame.maxY)
            viewport = CGRect(x: viewport.minX, y: minY,
                              width: viewport.width, height: viewport.maxY - minY)
        }
        if app.keyboards.count > 0 {
            let keyboardFrame = app.keyboards.element.frame
            guard layoutGeometryIsFiniteAndPositive(keyboardFrame) else {
                XCTFail("Non-finite keyboard frame \(keyboardFrame)")
                return nil
            }
            if viewport.intersects(keyboardFrame) {
                viewport = CGRect(x: viewport.minX, y: viewport.minY,
                                  width: viewport.width,
                                  height: min(viewport.maxY, keyboardFrame.minY) - viewport.minY)
            }
        }
        guard layoutGeometryIsFiniteAndPositive(viewport) else {
            XCTFail("No usable layout viewport after clipping: \(viewport)")
            return nil
        }
        return viewport
    }

    /// Taps one control inside the layout sheet's **scroll content** (the three
    /// previews and their choices), scrolling it into the usable viewport first.
    ///
    /// The layout page stacks three previews vertically, so `layout.choose.focus` is a
    /// normal scroll-away target: this performs bounded slow native drags in
    /// `layout.scroll`'s own coordinate space, and only taps when the whole control is
    /// inside the usable viewport and enabled/hittable. A target already inside the
    /// viewport that still cannot be tapped fails with diagnostics instead of being
    /// blind-tapped, and nothing is force-tapped by coordinates.
    private func tapLayoutSheetContent(_ item: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(item.waitForExistence(timeout: 30))
        let scroll = app.scrollViews.matching(identifier: "layout.scroll").firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 30))

        for _ in 0..<6 {
            guard let viewport = layoutUsableViewport(in: app) else { return }
            let target = item.frame
            guard layoutGeometryIsFiniteAndPositive(target) else {
                XCTFail("Non-finite target frame \(target) for \(item.identifier)")
                return
            }
            if viewport.contains(target) {
                guard item.isHittable else {
                    attachFullAppScreenshot(app, named: "Stage06 layout target inside viewport but not hittable")
                    XCTFail("\(item.identifier) is inside the usable viewport \(viewport) but not hittable: \(target)")
                    return
                }
                XCTAssertTrue(item.waitUntilEnabledAndHittable(),
                              "\(item.identifier) never became enabled and hittable")
                item.tap()
                return
            }

            let scrollFrame = scroll.frame
            guard layoutGeometryIsFiniteAndPositive(scrollFrame) else {
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
        let viewport = layoutUsableViewport(in: app) ?? .zero
        attachFullAppScreenshot(app, named: "Stage06 layout target never entered the viewport")
        XCTFail("\(item.identifier) never entered the usable layout viewport: "
            + "frame=\(item.frame) viewport=\(viewport) "
            + "scroll=\(app.scrollViews.matching(identifier: "layout.scroll").firstMatch.frame)")
    }

    /// Taps one control that belongs to the layout sheet's own **navigation bar**
    /// (Cancel/Apply). Those are toolbar actions, not scroll content: they must never be
    /// required to enter the content viewport or be dragged into it.
    ///
    /// The control is resolved **inside the sheet's own bar** (`navigationBars["Layouts"]
    /// .descendants(matching: .any)[identifier]`), so a same-identifier element elsewhere
    /// in the app can never satisfy it. The exact `Layouts` identifier is the native
    /// mapping of this sheet's real title — the same anchor Stage 04 verified — and the
    /// element is matched by identifier only, not by accessibility type.
    private func tapLayoutSheetToolbar(_ identifier: String, in app: XCUIApplication) {
        let sheetNavigationBars = app.navigationBars.matching(identifier: "Layouts")
        XCTAssertEqual(sheetNavigationBars.count, 1,
                       "Expected exactly one Layouts sheet navigation bar, found \(sheetNavigationBars.count)")
        let item = sheetNavigationBars.firstMatch
            .descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 30),
                      "\(identifier) is not owned by the layout sheet's own navigation bar")
        XCTAssertTrue(item.waitUntilEnabledAndHittable(),
                      "\(identifier) must be usable in the layout sheet navigation bar")
        item.tap()
    }

    /// The Focus choice inside the layout sheet's scroll content: one real query by
    /// identifier (any accessibility type). Waiting happens only where the control is
    /// actually used, so a disappearance check cannot first wait for a re-appearance.
    private func focusChoice(in app: XCUIApplication) -> XCUIElement {
        element("layout.choose.focus", in: app)
    }

    /// The sheet's Apply toolbar action: one real query by identifier (any accessibility
    /// type), without a pre-wait, so `.waitForDisappearance` observes the real
    /// disappearance instead of timing out on an appearance that will not happen again.
    private func layoutApply(in app: XCUIApplication) -> XCUIElement {
        element("layout.apply", in: app)
    }

    /// Distinct imported thumbnails in the **editor's own order** (the AX tree order of
    /// `editor.photo.*` buttons), which is the import order shown to the user.
    ///
    /// The shared `importedThumbnailIdentifiers` returns a UUID-sorted set, so it is
    /// used only to prove the count; the ordered list comes from the real query.
    private func orderedThumbnailIdentifiers(in app: XCUIApplication) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        for identifier in importedThumbnailIdentifiers(in: app) {
            if seen.insert(identifier).inserted { ordered.append(identifier) }
        }
        // The shared helper sorts by UUID; re-read the live query for the real order.
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.photo."))
        var live: [String] = []
        var liveSeen = Set<String>()
        for index in 0..<query.count {
            let identifier = query.element(boundBy: index).identifier
            guard identifier.hasPrefix("editor.photo."), liveSeen.insert(identifier).inserted else { continue }
            live.append(identifier)
        }
        return live.isEmpty ? ordered : live
    }

    /// Waits until the real lazy editor gallery has exposed `count` distinct photo
    /// thumbnails, scrolling the unique editor container with bounded slow drags.
    ///
    /// The shared `prepareEditorGallery` freezes its expectation to exactly one photo
    /// (the already-verified Stage02 boundary), so this case cannot reuse it as-is: it
    /// first scrolls the committed count into the viewport (which is what makes the
    /// grid instantiate) and then waits for both identifiers.
    private func instantiateGallery(expecting count: Int, in app: XCUIApplication) -> [String] {
        let anchor = element("editor.photoCount", in: app)
        XCTAssertTrue(anchor.waitForExistence(timeout: 30))
        _ = scrollEditorToMakeHittable(anchor, in: app)
        let expected = "\(count) of 20 photos"
        XCTAssertTrue(waitForLabel(anchor, expected),
                      "the editor count never reached \(expected): \(anchor.label)")

        var identifiers = orderedThumbnailIdentifiers(in: app)
        var attempts = 0
        while identifiers.count < count, attempts < 6 {
            let scrollView = app.scrollViews.element
            guard layoutGeometryIsFiniteAndPositive(scrollView.frame) else { break }
            scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.1,
                       thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
            identifiers = orderedThumbnailIdentifiers(in: app)
            attempts += 1
        }
        XCTAssertEqual(identifiers.count, count,
                       "the lazy gallery never exposed \(count) thumbnails: \(identifiers)")
        return identifiers
    }

    private func assetID(_ identifier: String) -> UUID? {
        UUID(uuidString: String(identifier.dropFirst("editor.photo.".count)))
    }

    private func roleOption(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    private func choose(_ role: String, for assetID: UUID, in app: XCUIApplication) {
        let picker = element("roles.picker.\(assetID.uuidString)", in: app)
        XCTAssertTrue(picker.waitForExistence(timeout: 30))
        picker.tap()
        let option = roleOption(role, in: app)
        XCTAssertTrue(option.waitUntilEnabledAndHittable(), "role option \(role) never became usable")
        option.tap()
    }

    /// The currently shown role of one row's picker, or `nil` for Automatic.
    ///
    /// SwiftUI's native `Picker` reports a fixed `Role, ` prefix before the selected
    /// option's own label (run 38026510813: actual `Role, Primary photo`). Only that
    /// exact prefix is removed — the remaining text is still compared as a whole role
    /// title, so an unknown or different label still fails instead of being accepted by
    /// a `contains` check or replaced by a constant.
    private func shownRole(_ assetID: UUID, in app: XCUIApplication) -> String? {
        let picker = element("roles.picker.\(assetID.uuidString)", in: app)
        let candidates = [(picker.value as? String) ?? "", picker.label]
        for candidate in candidates where !candidate.isEmpty {
            let normalized = candidate.hasPrefix("Role, ")
                ? String(candidate.dropFirst("Role, ".count))
                : candidate
            guard normalized != "Role", !normalized.isEmpty else { continue }
            return normalized
        }
        return picker.buttons["Automatic"].exists ? "Automatic" : nil
    }

    /// The real source text a row currently shows.
    private func sourceText(_ assetID: UUID, in app: XCUIApplication) -> String {
        let label = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@", "roles.source.\(assetID.uuidString)")
        ).firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 30), "row \(assetID) shows no source line")
        return label.label
    }

    private func waitForChecked(_ app: XCUIApplication, count: Int) {
        let status = element("roles.status", in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 30))
        let ready = NSPredicate(format: "label BEGINSWITH %@", "Checked \(count) of \(count)")
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: ready, object: status)], timeout: 90),
            .completed,
            "the role pass did not finish: \(status.label)"
        )
    }

    private func openRoles(_ app: XCUIApplication) {
        tapEditor(element("editor.photoRoles", in: app), in: app)
        XCTAssertTrue(element("roles.scroll", in: app).waitForExistence(timeout: 30))
    }

    private func closeRolesWithCancel(_ app: XCUIApplication) {
        app.buttons["roles.cancel"].tap()
        XCTAssertTrue(element("roles.scroll", in: app).waitForDisappearance(timeout: 30))
    }

    /// Returns the sheet's save control when it is really reachable.
    ///
    /// It is looked up with the existing generic `element(_:in:)` helper (any element
    /// type), because the fourth-round debug attachment showed the `Button` query chain
    /// matching nothing — a wrapped item does not have to be a `Button` in the
    /// accessibility hierarchy. Reachability is still required (exists + enabled +
    /// hittable) before anything is tapped, so the save is never bypassed.
    ///
    /// Diagnostics run **before** the failing assertion: this test class sets
    /// `continueAfterFailure = false`, so nothing after an `XCTFail` would execute.
    /// `exists` is read first and every other property only when the element really
    /// exists, so collecting a diagnostic cannot itself trigger a second failed query.
    private func reachableSave(_ app: XCUIApplication, timeout: TimeInterval = 30) -> XCUIElement {
        let save = element("roles.save", in: app)
        if save.waitUntilEnabledAndHittable(timeout: timeout) {
            return save
        }
        let identifiers = app.descendants(matching: .any).allElementsBoundByIndex
            .map(\.identifier)
            .filter { !$0.isEmpty }
        var diagnostic = "exists=\(save.exists)"
        if save.exists {
            diagnostic += " enabled=\(save.isEnabled) hittable=\(save.isHittable) frame=\(save.frame)"
            if !save.isHittable {
                attachFullAppScreenshot(app, named: "Stage06 roles save not hittable")
            }
        }
        attachFullAppScreenshot(app, named: "Stage06 roles save missing")
        XCTFail("roles.save was not enabled and hittable after \(timeout)s. \(diagnostic). "
            + "Identifiers on screen: \(Array(Set(identifiers)).sorted().prefix(40))")
        return save
    }

    private func saveChoices(_ app: XCUIApplication) {
        let save = reachableSave(app)
        save.tap()
        XCTAssertTrue(element("roles.save", in: app).waitForDisappearance(timeout: 60),
                      "a successful save closes the sheet")
    }

    private func layerSnapshot(in app: XCUIApplication) -> [String] {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.selectLayer."))
        return (0..<query.count).map { query.element(boundBy: $0).identifier }.sorted()
    }

    /// Selects one layer by its real layer identity and reads the editor's own
    /// transform text (`x 12, y 34, 56%, 7°`).
    ///
    /// An empty-canvas layout reuses the photo identity as the layer identity, so the
    /// saved primary photo's layer is addressable by that identity — no name
    /// inference and no dependence on the UUID-sorted shared helper.
    private func transform(ofLayer layerID: UUID, in app: XCUIApplication) -> (x: Double, y: Double, scale: Double) {
        let row = element("editor.selectLayer.\(layerID.uuidString)", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30), "the layer row for \(layerID) is missing")
        tapEditor(row, in: app)
        let text = element("editor.layerTransform", in: app)
        XCTAssertTrue(text.waitForExistence(timeout: 30))
        return parseTransform(text.label)
    }

    /// Parses `x %.0f, y %.0f, %.0f%%, %.0f°`.
    private func parseTransform(_ label: String) -> (x: Double, y: Double, scale: Double) {
        let pattern = #"x\s*(-?\d+(?:\.\d+)?),\s*y\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)),
              match.numberOfRanges == 4,
              let xRange = Range(match.range(at: 1), in: label),
              let yRange = Range(match.range(at: 2), in: label),
              let scaleRange = Range(match.range(at: 3), in: label),
              let x = Double(label[xRange]),
              let y = Double(label[yRange]),
              let scale = Double(label[scaleRange]) else {
            XCTFail("the editor transform text is not the expected shape: '\(label)'")
            return (0, 0, 0)
        }
        return (x, y, scale)
    }

    // MARK: - The path

    func testRolesSheetSavesManualChoiceSurvivesRestartAndFocusUsesIt() throws {
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

        // Two photos, so a role choice can actually change the composition. Each newly
        // imported asset identity is captured as it appears, which is the real import
        // order (the shared helper's set is UUID-sorted).
        var importOrder: [UUID] = []
        for (index, expected) in ["1 of 20 photos", "2 of 20 photos"].enumerated() {
            tapEditor(element("editor.importPhotos", in: app), in: app)
            XCTAssertTrue(waitForPickerToOpen(in: app))
            let selection = selectFirstPhotoCell(in: app, session: "stage06 roles import \(index)")
            XCTAssertTrue(selection.succeeded, selection.diagnostic)
            let confirmation = tapPickerAddButton(in: app)
            XCTAssertTrue(confirmation.succeeded, confirmation.diagnostic)
            XCTAssertTrue(waitForLabel(element("editor.photoCount", in: app), expected))
            let identifiers = instantiateGallery(expecting: index + 1, in: app)
            let assets = identifiers.compactMap(assetID)
            importOrder = assets
        }
        XCTAssertEqual(importOrder.count, 2, "both imported photos must be listed in import order")
        let firstImported = importOrder[0]
        let secondImported = importOrder[1]
        XCTAssertNotEqual(firstImported, secondImported)

        // 1. Save the SECOND-imported photo as the manual primary first, so promoting
        //    the first-imported one later has to collide with a saved manual primary.
        openRoles(app)
        waitForChecked(app, count: 2)
        choose("Primary photo", for: secondImported, in: app)
        XCTAssertEqual(shownRole(secondImported, in: app), "Primary photo")
        XCTAssertTrue(sourceText(secondImported, in: app).hasPrefix("Your choice:"),
                      "an explicit pick must display its manual source")
        // Real full-page evidence of the Photo roles sheet itself: the first manual pick
        // and its source are already asserted above, so this frame shows the actual
        // picker values, source lines and the save control before the first save. (The
        // screenshot at the end of this test is the Layouts preview, not this page.)
        attachFullAppScreenshot(app, named: "Stage06 roles first manual pick before first save")
        saveChoices(app)

        // 2. Reopening shows the stored choice and the real stored source.
        openRoles(app)
        waitForChecked(app, count: 2)
        XCTAssertEqual(shownRole(secondImported, in: app), "Primary photo")
        XCTAssertTrue(sourceText(secondImported, in: app).contains("Saved earlier as your choice"),
                      "a stored manual choice must display its manual source: \(sourceText(secondImported, in: app))")

        // 3. Modify a draft and Cancel: the stored choice must be unchanged.
        choose("Supporting photo", for: secondImported, in: app)
        closeRolesWithCancel(app)
        openRoles(app)
        waitForChecked(app, count: 2)
        XCTAssertEqual(shownRole(secondImported, in: app), "Primary photo",
                       "Cancel must not change the saved choice")
        XCTAssertTrue(sourceText(secondImported, in: app).contains("Saved earlier as your choice"))

        // 4. Promote the FIRST-imported photo directly while the second still has a
        //    saved manual primary: that primary must be demoted, so one primary is kept.
        choose("Primary photo", for: firstImported, in: app)
        saveChoices(app)
        openRoles(app)
        waitForChecked(app, count: 2)
        XCTAssertEqual(shownRole(firstImported, in: app), "Primary photo")
        XCTAssertEqual(shownRole(secondImported, in: app), "Supporting photo",
                       "the previously saved manual primary must be demoted, not kept as a second primary")
        XCTAssertTrue(sourceText(secondImported, in: app).contains("Saved earlier as your choice"),
                      "the demotion is stored as the user's own manual supporting choice")

        // 5. Explicit Automatic must really clear the stored role and its manual source.
        choose("Automatic", for: firstImported, in: app)
        saveChoices(app)
        openRoles(app)
        waitForChecked(app, count: 2)
        XCTAssertFalse(sourceText(firstImported, in: app).contains("Saved earlier as your choice"),
                       "Automatic must clear the saved manual role, not keep its manual source")

        // 6. Save the SECOND-imported photo as the primary again and keep it across a
        //    restart, so the Focus check below is about a photo that is NOT first.
        choose("Primary photo", for: secondImported, in: app)
        saveChoices(app)

        app.terminate()
        app.launch()
        XCTAssertTrue(create.waitUntilEnabledAndHittable())
        let restored = element(projectID, in: app)
        XCTAssertTrue(restored.waitUntilEnabledAndHittable())
        restored.tap()
        XCTAssertTrue(waitForLabel(element("editor.photoCount", in: app), "2 of 20 photos"))
        let restoredOrder = instantiateGallery(expecting: 2, in: app).compactMap(assetID)
        XCTAssertEqual(restoredOrder.count, 2, "no photo is lost by saving a role")
        XCTAssertEqual(restoredOrder, importOrder, "the import order is preserved across a restart")

        openRoles(app)
        waitForChecked(app, count: 2)
        XCTAssertEqual(shownRole(secondImported, in: app), "Primary photo",
                       "the saved primary must survive an app restart (including its source)")
        XCTAssertTrue(sourceText(secondImported, in: app).contains("Saved earlier as your choice"))
        closeRolesWithCancel(app)

        // 7. The real Focus preview/Apply must give the SAVED primary the hero position,
        //    even though it is the second-imported photo, and applying twice must be
        //    stable: the same layer set, never a duplicate.
        tapEditor(element("editor.layouts", in: app), in: app)
        XCTAssertTrue(focusChoice(in: app).waitForExistence(timeout: 30))
        XCTAssertTrue(element("layout.preview.focus", in: app).waitForExistence(timeout: 30))
        attachFullAppScreenshot(app, named: "Stage06 roles saved choice after restart")
        tapLayoutSheetContent(focusChoice(in: app), in: app)
        tapLayoutSheetToolbar("layout.apply", in: app)
        XCTAssertTrue(layoutApply(in: app).waitForDisappearance(timeout: 60),
                      "Apply must dismiss the layout sheet after a real apply")

        let afterFirstApply = layerSnapshot(in: app)
        XCTAssertEqual(afterFirstApply.count, 2, "Focus must not invent or duplicate layers")
        XCTAssertTrue(waitForLabel(element("editor.layerCount", in: app), "2 of 20 layers"),
                      "the editor itself must report exactly the two photo layers")

        // Real transform values. An empty-canvas layout reuses the photo identity as the
        // layer identity, so the saved primary's layer is read directly: Focus must give
        // it the hero cell (smaller y, i.e. higher on the canvas) even though it is the
        // second-imported photo, while the other layer keeps the rest of the layout.
        XCTAssertTrue(element("editor.selectLayer.\(secondImported.uuidString)", in: app)
                        .waitForExistence(timeout: 30))
        XCTAssertTrue(element("editor.selectLayer.\(firstImported.uuidString)", in: app)
                        .waitForExistence(timeout: 30))
        let primaryTransform = transform(ofLayer: secondImported, in: app)
        let otherTransform = transform(ofLayer: firstImported, in: app)
        XCTAssertLessThan(primaryTransform.y, otherTransform.y,
                          "the saved second-imported primary must take the Focus hero cell "
                          + "(primary \(primaryTransform), other \(otherTransform))")
        XCTAssertNotEqual(primaryTransform.scale, otherTransform.scale,
                          "the hero cell and the remaining cells use different scales")

        tapEditor(element("editor.layouts", in: app), in: app)
        tapLayoutSheetContent(focusChoice(in: app), in: app)
        tapLayoutSheetToolbar("layout.apply", in: app)
        XCTAssertTrue(layoutApply(in: app).waitForDisappearance(timeout: 60),
                      "Apply must dismiss the layout sheet after a real apply")
        XCTAssertEqual(layerSnapshot(in: app), afterFirstApply,
                       "the same preset applied twice must not add, drop or rename a layer")
        XCTAssertEqual(transform(ofLayer: secondImported, in: app).y, primaryTransform.y, accuracy: 0.5,
                       "repeating Apply must not move the hero layer")
        XCTAssertEqual(transform(ofLayer: firstImported, in: app).y, otherTransform.y, accuracy: 0.5,
                       "repeating Apply must not move the other layer")

        // The roles choice is still stored after the layout was applied twice.
        openRoles(app)
        waitForChecked(app, count: 2)
        XCTAssertEqual(shownRole(secondImported, in: app), "Primary photo",
                       "applying a layout must not change the saved role choice")
        closeRolesWithCancel(app)
    }
}
