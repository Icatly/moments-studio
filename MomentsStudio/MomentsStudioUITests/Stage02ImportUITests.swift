import XCTest

/// Stage 02 UI smoke coverage.
///
/// These tests need a booted iOS simulator and were **not** executed on the
/// Windows host. The photo picker is system UI hosted over the app, so the
/// picker test asserts that the picker's own controls really appeared, presses
/// Cancel, and then checks the editor is usable again. The import → preview
/// regression below drives the real picker and a real imported photo against the
/// images the cloud workflow seeds into the simulator; its system-UI locators are
/// assumptions that only a real macOS run can confirm (see the FIX-06 report).
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

    /// End-to-end regression for the modal wiring defect that exited the app:
    /// real picker → real imported photo → preview → Done → Remove confirmation.
    ///
    /// The cloud workflow seeds synthetic images into the simulator's photo
    /// library, so this drives the native picker rather than injecting anything:
    /// no production test buttons, no launch arguments, no mocked photo ids.
    /// Locators for the picker grid and its Add control are reported assumptions
    /// about system UI; only a real macOS run can confirm them.
    func testImportPreviewShowsTheImageAndRemovalConfirmationKeepsOrRemovesTheCopy() {
        let app = XCUIApplication()
        app.launch()

        let createProject = app.buttons["home.createProject"]
        XCTAssertTrue(createProject.waitUntilEnabled(), "Home never became ready.")
        createProject.tap()

        let importEntry = element("editor.importPhotos", in: app)
        XCTAssertTrue(importEntry.waitUntilEnabled(), "The import entry never became tappable.")
        XCTAssertTrue(
            app.staticTexts["editor.galleryEmpty"].exists,
            "A new project must start with an empty gallery."
        )

        // 1. Real system picker: open, select a seeded photo, confirm.
        importEntry.tap()
        XCTAssertTrue(
            waitForPickerToOpen(in: app),
            "The system photo picker did not appear.\n\(app.debugDescription)"
        )
        let selection = selectFirstPhotoCell(in: app)
        XCTAssertTrue(
            selection.succeeded,
            "No native photo-grid cell could be selected: \(selection.diagnostic)\n\(app.debugDescription)"
        )
        let confirmation = tapPickerAddButton(in: app)
        XCTAssertTrue(
            confirmation.succeeded,
            "The picker's Add control never became usable: \(confirmation.diagnostic)\n\(app.debugDescription)"
        )

        // 2. The import committed: a real thumbnail and a truthful count.
        let thumbnail = importedThumbnail(in: app)
        XCTAssertTrue(
            thumbnail.waitForExistence(timeout: 90),
            "The imported photo never appeared in the grid.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            thumbnail.waitUntilHittable(),
            "The imported thumbnail is not tappable.\n\(app.debugDescription)"
        )
        XCTAssertEqual(photoCount(in: app), "1 of 20 photos")

        // 3. Preview — this is the path that terminated the app before the fix.
        thumbnail.tap()
        XCTAssertTrue(
            element("preview.info", in: app).waitForExistence(timeout: 45),
            "The preview sheet did not appear, or it shows no photo.\n\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("preview.missingPhoto", in: app).exists,
            "The preview lost the imported photo.\n\(app.debugDescription)"
        )

        // The `preview.image` wrapper exists while its derivative is still
        // loading, so the wrapper's presence proves nothing. Wait — bounded — for
        // the loading indicator to disappear, then assert the failure placeholder
        // is absent and the image area/info are visible. Production UI is
        // unchanged; no extra loading-state API was added for this test.
        let loadingIndicator = previewLoadingIndicator(in: app)
        XCTAssertTrue(
            loadingIndicator.waitForDisappearance(timeout: 60),
            "The preview never finished loading its derivative.\n\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("photo.unavailable", in: app).exists,
            "The preview image failed to load instead of showing the derivative.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            element("preview.image", in: app).isHittable,
            "The preview image area is not visible after loading.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            element("preview.info", in: app).exists,
            "The preview info is missing after loading."
        )

        // 4. Done returns to a usable editor, with the photo still there.
        element("preview.done", in: app).tap()
        XCTAssertTrue(importEntry.waitUntilEnabled(), "The editor was not usable after Done.")
        XCTAssertEqual(photoCount(in: app), "1 of 20 photos")

        // 5. Remove asks first; Cancel keeps this project's copy.
        importedThumbnail(in: app).tap()
        let removeButton = element("preview.remove", in: app)
        XCTAssertTrue(
            removeButton.waitForExistence(timeout: 45),
            "The preview has no Remove control.\n\(app.debugDescription)"
        )
        removeButton.tap()
        XCTAssertTrue(
            staticText(containing: "photo library is not changed", in: app).waitForExistence(timeout: 30),
            "The confirmation must say the photo library original is not changed.\n\(app.debugDescription)"
        )
        confirmationButton(named: "Cancel", in: app).tap()
        XCTAssertTrue(
            removeButton.waitForExistence(timeout: 30),
            "Cancel must return to the preview.\n\(app.debugDescription)"
        )
        element("preview.done", in: app).tap()
        XCTAssertTrue(importEntry.waitUntilEnabled(), "The editor was not usable after cancelling removal.")
        XCTAssertEqual(photoCount(in: app), "1 of 20 photos", "Cancel must keep the imported copy.")

        // 6. Confirming removal updates the project.
        importedThumbnail(in: app).tap()
        let removeAgain = element("preview.remove", in: app)
        XCTAssertTrue(
            removeAgain.waitForExistence(timeout: 45),
            "The preview has no Remove control.\n\(app.debugDescription)"
        )
        removeAgain.tap()
        confirmationButton(named: "Remove", in: app).tap()

        XCTAssertTrue(
            app.staticTexts["editor.galleryEmpty"].waitForExistence(timeout: 60),
            "Removing the only photo must restore the empty gallery state.\n\(app.debugDescription)"
        )
        XCTAssertEqual(photoCount(in: app), "0 of 20 photos")

        // 7. Removing the project's copy left the source alone, so it can be
        //    selected and imported again.
        let importAfterRemoval = element("editor.importPhotos", in: app)
        XCTAssertTrue(importAfterRemoval.waitUntilEnabled(), "The import entry was not usable after removal.")
        importAfterRemoval.tap()
        XCTAssertTrue(
            waitForPickerToOpen(in: app),
            "The system photo picker did not appear again.\n\(app.debugDescription)"
        )
        let secondSelection = selectFirstPhotoCell(in: app)
        XCTAssertTrue(
            secondSelection.succeeded,
            "The seeded photo was no longer selectable: \(secondSelection.diagnostic)\n\(app.debugDescription)"
        )
        let secondConfirmation = tapPickerAddButton(in: app)
        XCTAssertTrue(
            secondConfirmation.succeeded,
            "The picker's Add control never became usable: \(secondConfirmation.diagnostic)\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            importedThumbnail(in: app).waitForExistence(timeout: 90),
            "The same photo could not be imported again after removing the project copy.\n\(app.debugDescription)"
        )
        XCTAssertEqual(photoCount(in: app), "1 of 20 photos")
    }

    // MARK: - Pickers, gallery and confirmation helpers

    /// The picker is system UI over the app; its own Cancel control is the
    /// concrete proof that it opened (already observed to match in a real run).
    private func waitForPickerToOpen(in app: XCUIApplication, timeout: TimeInterval = 30) -> Bool {
        app.buttons["Cancel"].waitForExistence(timeout: timeout)
            || app.navigationBars["Photos"].waitForExistence(timeout: 5)
    }

    /// Outcome of one system-picker interaction, carrying a diagnostic for the
    /// failure message so a real macOS run preserves native evidence.
    private struct PickerInteraction {
        let succeeded: Bool
        let diagnostic: String
    }

    /// Taps the first native photo cell **in the picker's own grid**.
    ///
    /// Reported assumption: the picker exposes its grid as collection-view cells
    /// and/or images. The queries stay scoped to collection views on purpose — the
    /// previous unscoped `app.images` fallback could match unrelated app icons, so
    /// it was removed rather than kept as a blind fallback.
    private func selectFirstPhotoCell(in app: XCUIApplication) -> PickerInteraction {
        var tried: [String] = []
        for (name, query) in [("collectionViews.cells", app.collectionViews.cells),
                             ("collectionViews.images", app.collectionViews.images)] {
            let cell = query.element(boundBy: 0)
            let exists = cell.waitForExistence(timeout: 10)
            tried.append("\(name): exists=\(exists) hittable=\(exists ? String(describing: cell.isHittable) : "n/a")")
            guard exists, cell.isHittable else { continue }
            cell.tap()
            return PickerInteraction(succeeded: true, diagnostic: "")
        }
        return PickerInteraction(succeeded: false, diagnostic: tried.joined(separator: "; "))
    }

    /// Presses the picker's Add control once it is **enabled and hittable**: the
    /// selection state updates asynchronously, so existing is not enough.
    private func tapPickerAddButton(in app: XCUIApplication) -> PickerInteraction {
        let add = app.buttons["Add"]
        guard add.waitUntilEnabledAndHittable() else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "Add button exists=\(add.exists) enabled=\(add.isEnabled) hittable=\(add.isHittable)"
            )
        }
        add.tap()
        return PickerInteraction(succeeded: true, diagnostic: "")
    }

    /// The preview's loading placeholder is an indeterminate `ProgressView`, which
    /// XCTest exposes as an activity indicator. Queried inside the presented sheet
    /// first, then app-wide; a missing indicator (already loaded) simply means the
    /// bounded disappearance wait is satisfied immediately.
    private func previewLoadingIndicator(in app: XCUIApplication) -> XCUIElement {
        let inSheet = app.sheets.firstMatch.activityIndicators.firstMatch
        if inSheet.exists { return inSheet }
        return app.activityIndicators.firstMatch
    }

    /// Imported thumbnails carry `editor.photo.<uuid>`; the id is generated at
    /// runtime, so match by prefix instead of guessing one.
    private func importedThumbnail(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.photo."))
            .firstMatch
    }

    private func photoCount(in app: XCUIApplication) -> String {
        element("editor.photoCount", in: app).label
    }

    private func staticText(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Confirmation dialogs are action sheets (occasionally alerts); the sheet is
    /// preferred so the toolbar's own "Remove" label cannot be matched instead.
    private func confirmationButton(named label: String, in app: XCUIApplication) -> XCUIElement {
        let inSheet = app.sheets.buttons[label]
        if inSheet.waitForExistence(timeout: 15) { return inSheet }
        return app.alerts.buttons[label]
    }

    /// The identifier is applied to a `PhotosPicker`, whose element type is not
    /// guaranteed, so match any element type.
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
