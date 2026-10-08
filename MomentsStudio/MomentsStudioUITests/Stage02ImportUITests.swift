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

        // Baseline for INTERACTION-VERIFY[restart]: the full identifiers of the Home
        // rows that already exist, so the project created by this test can later be
        // identified by set difference — never by row order or a display name.
        let projectIdentifiersBeforeCreation = homeProjectIdentifiers(in: app)
        print("INTERACTION-VERIFY[restart] Home project identifiers before creation: "
            + "\(projectIdentifiersBeforeCreation)")

        // Initial Home evidence for the maximum-text-size review: the review of the
        // 6s frame of run 37230253288 showed the main action label truncated, so the
        // next real run must be able to check the full string again.
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[home] initial Home before creating")

        createProject.tap()

        let importEntry = element("editor.importPhotos", in: app)
        XCTAssertTrue(importEntry.waitUntilEnabled(), "The import entry never became tappable.")
        XCTAssertTrue(
            scrollEditorToMakeHittable(importEntry, in: app),
            "INTERACTION-VERIFY[editor-scroll] the import entry never became hittable.\n\(app.debugDescription)"
        )
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
        let selection = selectFirstPhotoCell(in: app, session: "initial import")
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
        prepareEditorGallery(expectingThumbnail: thumbnail, in: app, session: "initial import")
        XCTAssertTrue(
            thumbnail.waitForExistence(timeout: 90),
            "The imported photo never appeared in the grid.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            scrollEditorToMakeHittable(thumbnail, in: app),
            "INTERACTION-VERIFY[editor-scroll] the imported thumbnail never became hittable.\n\(app.debugDescription)"
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
        let removalThumbnail = importedThumbnail(in: app)
        prepareEditorGallery(expectingThumbnail: removalThumbnail, in: app, session: "removal")
        XCTAssertTrue(
            scrollEditorToMakeHittable(removalThumbnail, in: app),
            "INTERACTION-VERIFY[editor-scroll] the removal thumbnail never became hittable.\n\(app.debugDescription)"
        )
        removalThumbnail.tap()
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
        let cancellation = cancelRemovalConfirmation(in: app)
        XCTAssertTrue(
            cancellation.succeeded,
            "INTERACTION-VERIFY[confirmation] the removal confirmation could not be cancelled: "
                + "\(cancellation.diagnostic)\n\(app.debugDescription)"
        )
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
        let confirmRemovalThumbnail = importedThumbnail(in: app)
        prepareEditorGallery(expectingThumbnail: confirmRemovalThumbnail, in: app, session: "confirm removal")
        XCTAssertTrue(
            scrollEditorToMakeHittable(confirmRemovalThumbnail, in: app),
            "INTERACTION-VERIFY[editor-scroll] the confirm-removal thumbnail never became hittable.\n"
                + "\(app.debugDescription)"
        )
        confirmRemovalThumbnail.tap()
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
        XCTAssertTrue(
            scrollEditorToMakeHittable(importAfterRemoval, in: app),
            "INTERACTION-VERIFY[editor-scroll] the re-import entry never became hittable.\n\(app.debugDescription)"
        )
        importAfterRemoval.tap()
        XCTAssertTrue(
            waitForPickerToOpen(in: app),
            "The system photo picker did not appear again.\n\(app.debugDescription)"
        )
        let secondSelection = selectFirstPhotoCell(in: app, session: "reimport")
        XCTAssertTrue(
            secondSelection.succeeded,
            "The seeded photo was no longer selectable: \(secondSelection.diagnostic)\n\(app.debugDescription)"
        )
        let secondConfirmation = tapPickerAddButton(in: app)
        XCTAssertTrue(
            secondConfirmation.succeeded,
            "The picker's confirmation control never became usable: \(secondConfirmation.diagnostic)\n\(app.debugDescription)"
        )
        prepareEditorGallery(expectingThumbnail: importedThumbnail(in: app), in: app, session: "reimport")
        XCTAssertTrue(
            importedThumbnail(in: app).waitForExistence(timeout: 90),
            "The same photo could not be imported again after removing the project copy.\n\(app.debugDescription)"
        )
        XCTAssertEqual(photoCount(in: app), "1 of 20 photos")

        // 8. INTERACTION-VERIFY[restart]: the same project and the same imported
        //    asset must survive a real terminate/launch. Everything below runs only
        //    after the whole original import path above has passed, so its failures
        //    can never mask an old-path regression.
        let thumbnailsBeforeRestart = importedThumbnailIdentifiers(in: app)
        XCTAssertEqual(
            thumbnailsBeforeRestart.count, 1,
            "INTERACTION-VERIFY[restart] expected exactly one imported thumbnail before restarting, "
                + "got \(thumbnailsBeforeRestart).\n\(app.debugDescription)"
        )
        let importedAssetIdentifier = thumbnailsBeforeRestart.first ?? ""
        print("INTERACTION-VERIFY[restart] imported asset identifier before restart: \(importedAssetIdentifier)")

        let editorBack = editorBackButton(in: app)
        XCTAssertTrue(
            editorBack.waitUntilEnabledAndHittable(),
            "INTERACTION-VERIFY[restart] the editor back button is not usable.\n\(app.debugDescription)"
        )
        editorBack.tap()

        let homeAfterEditor = app.buttons["home.createProject"]
        XCTAssertTrue(
            homeAfterEditor.waitUntilEnabled(),
            "INTERACTION-VERIFY[restart] Home was not ready after leaving the editor.\n\(app.debugDescription)"
        )
        XCTAssertFalse(
            app.staticTexts["home.libraryError"].exists,
            "INTERACTION-VERIFY[restart] Home reported a library error before the restart.\n\(app.debugDescription)"
        )

        let projectIdentifiersAfterImport = homeProjectIdentifiers(in: app)
        let createdProjects = projectIdentifiersAfterImport.subtracting(projectIdentifiersBeforeCreation)
        guard createdProjects.count == 1, let createdProjectIdentifier = createdProjects.first else {
            XCTFail(
                "INTERACTION-VERIFY[restart] expected exactly one new Home project, before="
                    + "\(projectIdentifiersBeforeCreation) after=\(projectIdentifiersAfterImport)"
            )
            return
        }
        print("INTERACTION-VERIFY[restart] created project identifier: \(createdProjectIdentifier)")
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[restart] Home before relaunch")

        // Real cold start: terminate the process and launch again. No reset, no data
        // injection and no product hook — the saved package itself must restore.
        app.terminate()
        app.launch()

        let homeAfterRelaunch = app.buttons["home.createProject"]
        XCTAssertTrue(
            homeAfterRelaunch.waitUntilEnabled(),
            "INTERACTION-VERIFY[restart] Home was not ready after the relaunch.\n\(app.debugDescription)"
        )
        XCTAssertFalse(
            app.staticTexts["home.libraryError"].exists,
            "INTERACTION-VERIFY[restart] Home reported a library error after the relaunch.\n\(app.debugDescription)"
        )

        let restoredProjectRow = app.buttons[createdProjectIdentifier]
        XCTAssertTrue(
            restoredProjectRow.waitUntilEnabledAndHittable(),
            "INTERACTION-VERIFY[restart] the same project was not restored: \(createdProjectIdentifier)\n"
                + "\(app.debugDescription)"
        )
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[restart] Home after relaunch")
        restoredProjectRow.tap()

        let editorAfterRestore = element("editor.importPhotos", in: app)
        XCTAssertTrue(
            scrollEditorToMakeHittable(editorAfterRestore, in: app),
            "INTERACTION-VERIFY[editor-scroll] the restored editor entry never became hittable.\n"
                + "\(app.debugDescription)"
        )
        XCTAssertTrue(
            editorAfterRestore.waitUntilEnabledAndHittable(),
            "INTERACTION-VERIFY[restart] the restored editor is not usable.\n\(app.debugDescription)"
        )
        XCTAssertEqual(
            photoCount(in: app), "1 of 20 photos",
            "INTERACTION-VERIFY[restart] the restored project lost its photo count.\n\(app.debugDescription)"
        )
        prepareEditorGallery(expectingThumbnail: app.buttons[importedAssetIdentifier].firstMatch, in: app,
                             session: "restore")
        let restoredThumbnails = importedThumbnailIdentifiers(in: app)
        XCTAssertEqual(
            restoredThumbnails.count, 1,
            "INTERACTION-VERIFY[restart] the restored editor must show exactly one asset, got "
                + "\(restoredThumbnails).\n\(app.debugDescription)"
        )
        XCTAssertEqual(
            restoredThumbnails.first, importedAssetIdentifier,
            "INTERACTION-VERIFY[restart] the restored asset identifier changed: expected "
                + "\(importedAssetIdentifier), got \(restoredThumbnails).\n\(app.debugDescription)"
        )

        let restoredThumbnail = app.buttons[importedAssetIdentifier].firstMatch
        XCTAssertTrue(
            scrollEditorToMakeHittable(restoredThumbnail, in: app),
            "INTERACTION-VERIFY[editor-scroll] the restored thumbnail never became hittable.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            restoredThumbnail.waitUntilHittable(),
            "INTERACTION-VERIFY[restart] the restored thumbnail is not hittable.\n\(app.debugDescription)"
        )
        restoredThumbnail.tap()

        XCTAssertTrue(
            element("preview.info", in: app).waitForExistence(timeout: 60),
            "INTERACTION-VERIFY[restart] the restored preview did not appear.\n\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("preview.missingPhoto", in: app).exists,
            "INTERACTION-VERIFY[restart] the restored preview lost its photo.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            previewLoadingIndicator(in: app).waitForDisappearance(timeout: 60),
            "INTERACTION-VERIFY[restart] the restored preview never finished loading.\n\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("photo.unavailable", in: app).exists,
            "INTERACTION-VERIFY[restart] the restored preview failed to load.\n\(app.debugDescription)"
        )
        let restoredPreviewImage = app.images["preview.image"]
        XCTAssertTrue(
            restoredPreviewImage.waitForExistence(timeout: 30),
            "INTERACTION-VERIFY[restart] the restored preview Image never appeared.\n\(app.debugDescription)"
        )
        let restoredPreviewFrame = restoredPreviewImage.frame
        let restoredPreviewFinite = restoredPreviewFrame.origin.x.isFinite
            && restoredPreviewFrame.origin.y.isFinite
            && restoredPreviewFrame.size.width.isFinite
            && restoredPreviewFrame.size.height.isFinite
        XCTAssertTrue(
            restoredPreviewFinite && !restoredPreviewFrame.isEmpty,
            "INTERACTION-VERIFY[restart] the restored preview Image frame is not finite/non-empty: "
                + "\(restoredPreviewFrame)"
        )
        XCTAssertTrue(
            app.frame.contains(restoredPreviewFrame),
            "INTERACTION-VERIFY[restart] the restored preview Image is not wholly on screen: image "
                + "\(restoredPreviewFrame) vs app \(app.frame)"
        )
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[restart] restored preview")

        let restoredDone = app.buttons["preview.done"]
        XCTAssertTrue(
            restoredDone.waitUntilEnabledAndHittable(),
            "INTERACTION-VERIFY[restart] the restored preview Done is not usable.\n\(app.debugDescription)"
        )
        restoredDone.tap()
        let editorAfterRestoredDone = element("editor.importPhotos", in: app)
        XCTAssertTrue(
            scrollEditorToMakeHittable(editorAfterRestoredDone, in: app),
            "INTERACTION-VERIFY[editor-scroll] the editor after the restored preview never became hittable.\n"
                + "\(app.debugDescription)"
        )
        XCTAssertTrue(
            element("editor.importPhotos", in: app).waitUntilEnabledAndHittable(),
            "INTERACTION-VERIFY[restart] the editor is not operable after the restored preview.\n"
                + "\(app.debugDescription)"
        )

        // 9. INTERACTION-VERIFY[dark]: the same restored project stays operable in
        //    dark appearance. The original appearance is always restored on exit and
        //    only this test simulator is affected.
        let originalAppearance = XCUIDevice.shared.appearance
        defer { XCUIDevice.shared.appearance = originalAppearance }
        XCUIDevice.shared.appearance = .dark
        print("INTERACTION-VERIFY[dark] appearance set to .dark for the restored project")

        let darkEditorImport = element("editor.importPhotos", in: app)
        XCTAssertTrue(
            scrollEditorToMakeHittable(darkEditorImport, in: app),
            "INTERACTION-VERIFY[editor-scroll] the dark-mode import entry never became hittable.\n"
                + "\(app.debugDescription)"
        )
        XCTAssertTrue(
            darkEditorImport.waitUntilEnabledAndHittable(),
            "INTERACTION-VERIFY[dark] the editor import entry is not usable in dark appearance.\n"
                + "\(app.debugDescription)"
        )
        XCTAssertEqual(
            photoCount(in: app), "1 of 20 photos",
            "INTERACTION-VERIFY[dark] the photo count is wrong in dark appearance.\n\(app.debugDescription)"
        )
        prepareEditorGallery(expectingThumbnail: app.buttons[importedAssetIdentifier].firstMatch, in: app,
                             session: "dark")
        let darkThumbnails = importedThumbnailIdentifiers(in: app)
        XCTAssertEqual(
            darkThumbnails.first, importedAssetIdentifier,
            "INTERACTION-VERIFY[dark] the restored asset changed in dark appearance: \(darkThumbnails).\n"
                + "\(app.debugDescription)"
        )
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[dark] Editor")

        let darkThumbnail = app.buttons[importedAssetIdentifier].firstMatch
        XCTAssertTrue(
            scrollEditorToMakeHittable(darkThumbnail, in: app),
            "INTERACTION-VERIFY[editor-scroll] the dark-mode thumbnail never became hittable.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            darkThumbnail.waitUntilHittable(),
            "INTERACTION-VERIFY[dark] the thumbnail is not hittable in dark appearance.\n\(app.debugDescription)"
        )
        darkThumbnail.tap()
        XCTAssertTrue(
            element("preview.info", in: app).waitForExistence(timeout: 60),
            "INTERACTION-VERIFY[dark] the preview did not appear in dark appearance.\n\(app.debugDescription)"
        )
        XCTAssertTrue(
            previewLoadingIndicator(in: app).waitForDisappearance(timeout: 60),
            "INTERACTION-VERIFY[dark] the preview never finished loading in dark appearance.\n"
                + "\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("photo.unavailable", in: app).exists,
            "INTERACTION-VERIFY[dark] the preview image is unavailable in dark appearance.\n"
                + "\(app.debugDescription)"
        )
        XCTAssertFalse(
            element("preview.missingPhoto", in: app).exists,
            "INTERACTION-VERIFY[dark] the preview lost its photo in dark appearance.\n\(app.debugDescription)"
        )
        let darkPreviewImage = app.images["preview.image"]
        XCTAssertTrue(
            darkPreviewImage.waitForExistence(timeout: 30),
            "INTERACTION-VERIFY[dark] the preview Image never appeared in dark appearance.\n"
                + "\(app.debugDescription)"
        )
        let darkPreviewFrame = darkPreviewImage.frame
        let darkPreviewFinite = darkPreviewFrame.origin.x.isFinite && darkPreviewFrame.origin.y.isFinite
            && darkPreviewFrame.size.width.isFinite && darkPreviewFrame.size.height.isFinite
        XCTAssertTrue(
            darkPreviewFinite && !darkPreviewFrame.isEmpty
                && darkPreviewFrame.width > 0 && darkPreviewFrame.height > 0,
            "INTERACTION-VERIFY[dark] the preview Image has no finite, non-empty, positive frame: "
                + "\(darkPreviewFrame)"
        )
        XCTAssertTrue(
            app.frame.contains(darkPreviewFrame),
            "INTERACTION-VERIFY[dark] the preview Image is not wholly on screen: \(darkPreviewFrame) "
                + "vs app \(app.frame)"
        )
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[dark] loaded preview")

        let darkDone = app.buttons["preview.done"]
        XCTAssertTrue(
            darkDone.waitUntilEnabledAndHittable(),
            "INTERACTION-VERIFY[dark] Done is not usable in dark appearance.\n\(app.debugDescription)"
        )
        darkDone.tap()
        let editorAfterDarkDone = element("editor.importPhotos", in: app)
        XCTAssertTrue(
            scrollEditorToMakeHittable(editorAfterDarkDone, in: app),
            "INTERACTION-VERIFY[editor-scroll] the editor after dark Done never became hittable.\n"
                + "\(app.debugDescription)"
        )
        XCTAssertTrue(
            element("editor.importPhotos", in: app).waitUntilEnabledAndHittable(),
            "INTERACTION-VERIFY[dark] the editor is not operable after Done in dark appearance.\n"
                + "\(app.debugDescription)"
        )

        let darkBack = editorBackButton(in: app)
        XCTAssertTrue(
            darkBack.waitUntilEnabledAndHittable(),
            "INTERACTION-VERIFY[dark] the editor back button is not usable in dark appearance.\n"
                + "\(app.debugDescription)"
        )
        darkBack.tap()
        XCTAssertTrue(
            app.buttons["home.createProject"].waitUntilEnabled(),
            "INTERACTION-VERIFY[dark] Home was not ready after leaving the editor in dark appearance.\n"
                + "\(app.debugDescription)"
        )
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[dark] Home")

        let darkProjectRow = app.buttons[createdProjectIdentifier]
        XCTAssertTrue(
            darkProjectRow.waitUntilEnabledAndHittable(),
            "INTERACTION-VERIFY[dark] the project row is not usable in dark appearance.\n\(app.debugDescription)"
        )
        darkProjectRow.tap()
        let editorAfterDarkReopen = element("editor.importPhotos", in: app)
        XCTAssertTrue(
            scrollEditorToMakeHittable(editorAfterDarkReopen, in: app),
            "INTERACTION-VERIFY[editor-scroll] the reopened dark project editor never became hittable.\n"
                + "\(app.debugDescription)"
        )
        XCTAssertTrue(
            element("editor.importPhotos", in: app).waitUntilEnabledAndHittable(),
            "INTERACTION-VERIFY[dark] the project did not reopen in dark appearance.\n\(app.debugDescription)"
        )
    }

    // MARK: - Pickers, gallery and confirmation helpers

    /// (iOS 18.5: run 37147120379, iOS 26.5: run 37216674264). The picker's early
    /// initialization screen can show a Cancel control before that navigation and
    /// its grid exist (see FIX-09), so Cancel alone is not treated as ready.
    // waitForPickerToOpen moved to the shared Stage 03/02 helper extension.

    /// Outcome of one system-picker interaction, carrying a diagnostic for the
}
