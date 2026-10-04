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

        // Readiness is the native `Photos` navigation bar — not the mere existence
        // of any Cancel control. Run 37149876593's screen recording shows the
        // picker's initialization screen first: a Cancel is on screen for several
        // seconds before the Photos navigation, segmented control and grid appear,
        // and tapping that early Cancel does not dismiss the picker. The observed
        // native hierarchy (run 37147120379, iOS 18.5) places the real Cancel
        // inside `NavigationBar identifier: 'Photos'`.
        let photosNavigationBar = app.navigationBars["Photos"]
        XCTAssertTrue(
            photosNavigationBar.waitForExistence(timeout: 20),
            "The native Photos navigation never appeared.\n\(app.debugDescription)"
        )

        // Query Cancel inside that observed native scope and press it once it can
        // actually receive the tap.
        let pickerCancel = photosNavigationBar.buttons["Cancel"]
        XCTAssertTrue(
            pickerCancel.waitUntilEnabledAndHittable(),
            "The picker's Cancel control never became usable.\n\(app.debugDescription)"
        )
        pickerCancel.tap()

        // Dismissal is proven by the control *and* the native navigation going
        // away — this is a synchronization correction, not a longer timeout.
        XCTAssertTrue(
            pickerCancel.waitForDisappearance(),
            "The picker's Cancel control did not go away.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            photosNavigationBar.waitForDisappearance(),
            "The native Photos navigation did not go away.\n\(app.debugDescription)"
        )

        let importEntryAfterDismissal = element("editor.importPhotos", in: app)
        XCTAssertTrue(
            importEntryAfterDismissal.waitUntilEnabled(),
            "The editor must be interactive again after the picker is dismissed.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            importEntryAfterDismissal.isHittable,
            "The import entry must be hittable again after the picker is dismissed.\n\(app.debugDescription)"
        )
    }

    /// End-to-end regression for the modal wiring defect that exited the app:
    /// real picker → real imported photo → preview → Done → Remove confirmation.
    ///
    /// The cloud workflow seeds synthetic images into the simulator's photo
    /// library, so this drives the native picker rather than injecting anything:
    /// no production test buttons, no launch arguments, no mocked photo ids.
    /// Locators for the picker grid and its confirmation control are recorded from
    /// real native hierarchy dumps of two different iOS versions (see the
    /// version-branched helpers below); only a real macOS run can reconfirm them.
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
            "The picker's confirmation control never became usable: \(confirmation.diagnostic)\n\(app.debugDescription)"
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
        // is absent. Production UI is unchanged; no extra loading-state API was
        // added for this test.
        let loadingIndicator = previewLoadingIndicator(in: app)
        XCTAssertTrue(
            loadingIndicator.waitForDisappearance(timeout: 60),
            "The preview never finished loading its derivative.\n\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("photo.unavailable", in: app).exists,
            "The preview image failed to load instead of showing the derivative.\n\(app.debugDescription)"
        )

        // Positive proof of the loaded state: `DerivedImageView` only builds
        // `Image(decorative:)` in its `loaded(CGImage)` branch (loading shows a
        // `ProgressView`, failure shows the unavailable control), so a **typed**
        // `Image` query is loaded-state evidence that the generic wrapper is not.
        // `isHittable` is deliberately not used: it reports whether a computed
        // hit point is available for interaction, which a read-only decorative
        // image is not.
        let previewImage = app.images["preview.image"]
        XCTAssertTrue(
            previewImage.waitForExistence(timeout: 30),
            "The loaded preview Image never appeared.\n\(app.debugDescription)"
        )
        let imageFrame = previewImage.frame
        let hasFiniteFrame = imageFrame.origin.x.isFinite
            && imageFrame.origin.y.isFinite
            && imageFrame.size.width.isFinite
            && imageFrame.size.height.isFinite
        XCTAssertTrue(
            hasFiniteFrame && !imageFrame.isEmpty && imageFrame.width > 0 && imageFrame.height > 0,
            "The preview Image has no finite, non-empty frame: \(imageFrame)"
        )
        XCTAssertTrue(
            app.frame.contains(imageFrame),
            "The preview Image is not wholly on screen: image \(imageFrame) vs app \(app.frame)"
        )
        XCTAssertTrue(
            element("preview.info", in: app).exists,
            "The preview info is missing after loading."
        )

        // One retained full-app screenshot so the actual pixels can be inspected
        // by hand. There is no golden comparison and no snapshot framework.
        let previewScreenshot = XCTAttachment(screenshot: app.screenshot())
        previewScreenshot.name = "Stage02 imported photo preview"
        previewScreenshot.lifetime = .keepAlways
        add(previewScreenshot)

        // 4. Done returns to a usable editor, with the photo still there.
        // The dump showed duplicate Other/Button elements carrying the same
        // identifier, so the real action controls are queried by their observed
        // element type and pressed only once they are enabled and hittable.
        let doneButton = app.buttons["preview.done"]
        XCTAssertTrue(
            doneButton.waitUntilEnabledAndHittable(),
            "The preview's Done control never became usable.\n\(app.debugDescription)"
        )
        doneButton.tap()
        XCTAssertTrue(importEntry.waitUntilEnabled(), "The editor was not usable after Done.")
        XCTAssertEqual(photoCount(in: app), "1 of 20 photos")

        // 5. Remove asks first; Cancel keeps this project's copy.
        importedThumbnail(in: app).tap()
        let removeButton = app.buttons["preview.remove"]
        XCTAssertTrue(
            removeButton.waitUntilEnabledAndHittable(),
            "The preview's Remove control never became usable.\n\(app.debugDescription)"
        )
        removeButton.tap()
        XCTAssertTrue(
            staticText(containing: "photo library is not changed", in: app).waitForExistence(timeout: 30),
            "The confirmation must say the photo library original is not changed.\n\(app.debugDescription)"
        )
        confirmationButton(named: "Cancel", in: app).tap()
        XCTAssertTrue(
            removeButton.waitUntilEnabledAndHittable(),
            "Cancel must return to a usable preview.\n\(app.debugDescription)"
        )
        let doneAfterCancel = app.buttons["preview.done"]
        XCTAssertTrue(
            doneAfterCancel.waitUntilEnabledAndHittable(),
            "Done was not usable after cancelling removal.\n\(app.debugDescription)"
        )
        doneAfterCancel.tap()
        XCTAssertTrue(importEntry.waitUntilEnabled(), "The editor was not usable after cancelling removal.")
        XCTAssertEqual(photoCount(in: app), "1 of 20 photos", "Cancel must keep the imported copy.")

        // 6. Confirming removal updates the project.
        importedThumbnail(in: app).tap()
        let removeAgain = app.buttons["preview.remove"]
        XCTAssertTrue(
            removeAgain.waitUntilEnabledAndHittable(),
            "The preview's Remove control never became usable.\n\(app.debugDescription)"
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
            "The picker's confirmation control never became usable: \(secondConfirmation.diagnostic)\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            importedThumbnail(in: app).waitForExistence(timeout: 90),
            "The same photo could not be imported again after removing the project copy.\n\(app.debugDescription)"
        )
        XCTAssertEqual(photoCount(in: app), "1 of 20 photos")
    }

    // MARK: - Pickers, gallery and confirmation helpers

    /// The picker is system UI over the app. Readiness is the native `Photos`
    /// navigation bar, which was observed in **both** recorded layouts
    /// (iOS 18.5: run 37147120379, iOS 26.5: run 37216674264). The picker's early
    /// initialization screen can show a Cancel control before that navigation and
    /// its grid exist (see FIX-09), so Cancel alone is not treated as ready.
    private func waitForPickerToOpen(in app: XCUIApplication, timeout: TimeInterval = 30) -> Bool {
        app.navigationBars["Photos"].waitForExistence(timeout: timeout)
    }

    /// Outcome of one system-picker interaction, carrying a diagnostic for the
    /// failure message so a real macOS run preserves native evidence.
    private struct PickerInteraction {
        let succeeded: Bool
        let diagnostic: String
    }

    /// The system picker's accessibility layout changed between the iOS versions
    /// this project supports. Both layouts below come from real native hierarchy
    /// dumps, not from guesswork:
    ///
    /// * iOS 18.5 (run 37147120379): the grid container is `ScrollView`
    ///   `content_scroll_view`, photo cells are `Image` `PXGGridLayout-Info`
    ///   (label like "Photo, October 03, 7:14 PM"), and the confirmation control
    ///   is the `Add` button, Disabled until something is selected.
    /// * iOS 26.5 (run 37216674264): the same `Image` `PXGGridLayout-Info` photo
    ///   cells now live in `ScrollView` `photosView_content_scroll_view`, and the
    ///   confirmation control is `Done` **inside the `Photos` navigation bar**,
    ///   Disabled until something is selected.
    ///
    /// The branch is taken from the running system version, so each version keeps
    /// exactly one explicit scope: a missing scope fails loudly with its own
    /// diagnostic instead of falling back to an unscoped query, screen
    /// coordinates or a second guess.
    private var usesModernPickerLayout: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
    }

    private var pickerGridIdentifier: String {
        usesModernPickerLayout ? "photosView_content_scroll_view" : "content_scroll_view"
    }

    private func pickerConfirmationControl(in app: XCUIApplication) -> XCUIElement {
        if usesModernPickerLayout {
            return app.navigationBars["Photos"].buttons["Done"]
        }
        return app.buttons["Add"]
    }

    /// Taps the first real photo in the picker's grid inside the version-specific
    /// scope. These are native accessibility queries over system UI (not private
    /// APIs) and deliberately narrow: no unscoped `app.images`, no coordinates and
    /// no blind fallback.
    private func selectFirstPhotoCell(in app: XCUIApplication) -> PickerInteraction {
        let identifier = pickerGridIdentifier
        let scope = app.scrollViews[identifier]
        guard scope.waitForExistence(timeout: 20) else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "picker scroll view '\(identifier)' not found on iOS "
                    + "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)"
            )
        }

        let photos = scope.images.matching(identifier: "PXGGridLayout-Info")
        let photo = photos.element(boundBy: 0)
        guard photo.waitUntilHittable(timeout: 20) else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "no hittable 'PXGGridLayout-Info' photo in '\(identifier)' "
                    + "(exists=\(photo.exists) hittable=\(photo.isHittable) count=\(photos.count))"
            )
        }

        photo.tap()
        return PickerInteraction(succeeded: true, diagnostic: "")
    }

    /// Presses the picker's confirmation control once it is **enabled and
    /// hittable**: the selection state updates asynchronously, so existing is not
    /// enough. iOS 26 confirms with `Done` inside the `Photos` navigation bar;
    /// older versions keep the observed `Add` button.
    private func tapPickerAddButton(in app: XCUIApplication) -> PickerInteraction {
        let control = pickerConfirmationControl(in: app)
        guard control.waitUntilEnabledAndHittable() else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "picker confirmation control exists=\(control.exists) "
                    + "enabled=\(control.isEnabled) hittable=\(control.isHittable)"
            )
        }
        control.tap()
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
