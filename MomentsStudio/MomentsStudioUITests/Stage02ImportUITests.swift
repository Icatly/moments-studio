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
    ///
    /// The two recorded layouts answer "can this element be hit right now?"
    /// differently:
    ///
    /// * iOS 18.5 (run 37147120379): the first `PXGGridLayout-Info` becomes
    ///   hittable, so this branch keeps the existing bounded hittable wait.
    /// * iOS 26.5 (run 37220074605): the correct scope and nine real photos were
    ///   found, yet the first photo reported `exists == true` / `hittable == false`
    ///   with frame `{{0.0, 346.0}, {132.9, 133.0}}`, so a hittable precondition
    ///   returned before any real tap. Apple documents `isHittable` as whether a
    ///   hit point can be computed for the element *now*, and `tap()` as
    ///   attempting to scroll the target into a tappable position, so this branch
    ///   requires existence plus a finite non-empty frame, records the native
    ///   diagnostics, and calls `tap()` exactly once on that element so XCTest
    ///   computes the hit point itself.
    ///
    /// A `tap()` call is **not** proof of selection: the caller still has to see
    /// the real confirmation control become enabled and hittable and then the real
    /// import/preview/removal path succeed, otherwise the test fails.
    private func selectFirstPhotoCell(in app: XCUIApplication, session: String) -> PickerInteraction {
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

        guard usesModernPickerLayout else {
            // iOS 18.5 layout: unchanged behaviour.
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

        // iOS 26 layout: existence plus a finite non-empty frame is the
        // precondition. `isHittable` is recorded for the report but does not block
        // the native tap. Maximum text size can push the grid below the fold behind
        // the system's photo-access onboarding, which is closed once - from its own
        // identified container only - before the original photo wait.
        let onboarding = closeOverflowingPhotoAccessOnboarding(in: app, scope: scope, photos: photos,
                                                              session: session)
        print("INTERACTION-VERIFY[onboarding] session=\(session): \(onboarding.diagnostic)")
        guard onboarding.succeeded else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "the overflowing photo-access onboarding could not be closed: \(onboarding.diagnostic)"
            )
        }

        guard photo.waitForExistence(timeout: 20) else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "no 'PXGGridLayout-Info' photo in '\(identifier)' on iOS 26 "
                    + "(exists=\(photo.exists) count=\(photos.count))"
            )
        }
        let frame = photo.frame
        let finiteFrame = frame.origin.x.isFinite && frame.origin.y.isFinite
            && frame.size.width.isFinite && frame.size.height.isFinite
        guard finiteFrame, !frame.isEmpty, frame.width > 0, frame.height > 0 else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "the first 'PXGGridLayout-Info' photo has no finite non-empty frame: \(frame) "
                    + "(exists=\(photo.exists) count=\(photos.count))"
            )
        }
        // The recorded layout must also place the target fully inside both its own
        // scroll scope and the app window before anything is tapped.
        guard scope.frame.contains(frame), app.frame.contains(frame) else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "the first 'PXGGridLayout-Info' photo frame \(frame) is not fully inside "
                    + "scope \(scope.frame) / app \(app.frame)"
            )
        }

        // Logging policy for this branch: one INTERACTION-VERIFY[picker] diagnostic
        // line per picker interaction (scope frame, count and the first three real
        // photos), plus one keepAlways screenshot immediately before and after the
        // single tap. The `session` label keeps the initial import and the reimport
        // distinguishable in the same run log.
        let diagnostics = pickerElementDiagnostics(scope: scope, photos: photos)
        print("INTERACTION-VERIFY[picker] session=\(session): \(diagnostics)")
        attachFullAppScreenshot(app, named: "Stage02 iOS 26 picker before first photo tap (\(session))")

        // Native `tap()` computed hit points of {-1, -1} for this layout in three
        // attempts (run 37222556297), so the Architect authorized exactly one
        // element-relative center tap for this recorded iOS 26 layout.
        // `coordinate(withNormalizedOffset:)` is a public XCTest API and the offset
        // is relative to the target element — never an absolute screen point. A tap
        // is still not proof of selection: the real confirmation control and the
        // whole import path must pass afterwards.
        let relativeCenterDescription = "element-relative center tap on '\(identifier)' normalized=(0.5, 0.5) "
            + "target=\(frame) scope=\(scope.frame) app=\(app.frame)"
        print("INTERACTION-VERIFY[picker] session=\(session): \(relativeCenterDescription)")
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        attachFullAppScreenshot(app, named: "Stage02 iOS 26 picker after first photo tap (\(session))")
        return PickerInteraction(succeeded: true, diagnostic: diagnostics)
    }

    /// Diagnostics only: the scope frame plus the first three real photo elements.
    /// This records native state for the run report; it never picks a candidate.
    private func pickerElementDiagnostics(scope: XCUIElement, photos: XCUIElementQuery) -> String {
        var parts = ["scope=\(scope.frame)", "count=\(photos.count)"]
        for index in 0..<min(3, photos.count) {
            let element = photos.element(boundBy: index)
            parts.append("#\(index) exists=\(element.exists) hittable=\(element.isHittable) "
                + "frame=\(element.frame) label=\(element.label)")
        }
        return parts.joined(separator: " | ")
    }

    /// Test-only diagnosis kept for the run report; no product hooks are involved.
    private func attachFullAppScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

    /// The editor's back control differs between the supported iOS versions, both
    /// recorded from real native dumps:
    ///
    /// * iOS 26.5 (run 37222556297): `Button` with `identifier: 'BackButton'`.
    /// * iOS 18.5 (run 37147120379): the same leading navigation button has **no**
    ///   identifier; it is exposed only with the observed label `'Moments Studio'`
    ///   (the previous screen's title). This branch matches that observed label
    ///   inside the navigation bar — no other label is guessed.
    private func editorBackButton(in app: XCUIApplication) -> XCUIElement {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
            return app.buttons["BackButton"]
        }
        return app.navigationBars.buttons["Moments Studio"]
    }

    /// Full identifiers of the Home project rows. Used to identify a project across
    /// a real terminate/launch by set difference, never by row order or name.
    private func homeProjectIdentifiers(in app: XCUIApplication) -> Set<String> {
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.project."))
        var identifiers = Set<String>()
        for index in 0..<rows.count {
            let identifier = rows.element(boundBy: index).identifier
            if identifier.hasPrefix("home.project.") {
                identifiers.insert(identifier)
            }
        }
        return identifiers
    }

    /// Unique full `editor.photo.<assetID>` identifiers of the imported thumbnails.
    ///
    /// The thumbnail is a SwiftUI `Button` (PhotoImportSection) and one button can be
    /// exposed as several accessibility nodes, so identifiers are deduplicated: the
    /// count must be the number of distinct assets, never the number of AX nodes.
    /// The `editor.photoCount` label shares the prefix without the dot, so it is
    /// deliberately excluded.
    private func importedThumbnailIdentifiers(in app: XCUIApplication) -> [String] {
        let thumbnails = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "editor.photo."))
        var identifiers = Set<String>()
        for index in 0..<thumbnails.count {
            let identifier = thumbnails.element(boundBy: index).identifier
            if identifier.hasPrefix("editor.photo.") {
                identifiers.insert(identifier)
            }
        }
        return identifiers.sorted()
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

    /// System-UI shape branch (iOS 26 changed several system containers).
    private var usesModernSystemUI: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
    }

    /// Finite, non-empty and positive-size frame check shared by the confirmation
    /// checks: an empty frame must never be treated as visible.
    private func isFinitePositive(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite && frame.origin.y.isFinite
            && frame.size.width.isFinite && frame.size.height.isFinite
            && !frame.isEmpty && frame.width > 0 && frame.height > 0
    }

    /// Prepares the Editor gallery before a thumbnail is queried.
    ///
    /// At maximum text size the committed count anchor **exists but sits below the
    /// screen** (run 37248700016: `editor.photoCount` at y=920 inside an 874-point
    /// window) while no `editor.photo.<assetID>` node has been created at all. The
    /// lazy grid not having exposed those nodes yet is an inference from the product
    /// source plus that dump, not a verified Apple internal mechanism, so the
    /// preparation only simulates a user scroll and the original assertions still
    /// decide.
    ///
    /// It first proves the Editor context (real `editor.placeholder`, no `Photos`
    /// picker navigation, no preview sheet, a unique Editor scroll view and a unique
    /// navigation bar), then finds the **unique** count anchor and waits on it with a
    /// predicate expectation for `exists == true AND label == "1 of 20 photos"` for up
    /// to 90 seconds: the real node commonly exists first as "0 of 20 photos", so
    /// existence alone would return before the asynchronous import commits. Only then
    /// does it scroll that anchor into the usable viewport with the reviewed bounded
    /// helper. It never treats a missing element's frame as valid and never guesses
    /// coordinates; if the anchor never commits or the thumbnail is still missing
    /// afterwards, the original existence/identifier assertions fail as before.
    private func prepareEditorGallery(expectingThumbnail thumbnail: XCUIElement, in app: XCUIApplication,
                                      session: String) {
        if thumbnail.exists { return }
        guard element("editor.placeholder", in: app).exists else {
            print("INTERACTION-VERIFY[gallery] session=\(session): no Editor placeholder; not an Editor context")
            return
        }
        guard !app.navigationBars["Photos"].exists,
              !element("preview.image", in: app).exists,
              !element("preview.done", in: app).exists else {
            print("INTERACTION-VERIFY[gallery] session=\(session): the picker or preview sheet is on screen")
            return
        }
        guard app.scrollViews.count == 1, app.navigationBars.count == 1 else {
            print("INTERACTION-VERIFY[gallery] session=\(session): the Editor scroll view or navigation is not "
                + "unique (scrollViews=\(app.scrollViews.count) navigationBars=\(app.navigationBars.count))")
            return
        }

        let anchors = app.staticTexts.matching(identifier: "editor.photoCount")
        guard anchors.count == 1 else {
            print("INTERACTION-VERIFY[gallery] session=\(session): expected exactly one count anchor, "
                + "found \(anchors.count)")
            return
        }
        let anchor = anchors.element
        let committed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label == %@", "1 of 20 photos"),
            object: anchor
        )
        guard XCTWaiter().wait(for: [committed], timeout: 90) == .completed else {
            print("INTERACTION-VERIFY[gallery] session=\(session): the count anchor never committed "
                + "(exists=\(anchor.exists) label=\(anchor.label))")
            return
        }

        print("INTERACTION-VERIFY[gallery] session=\(session): anchor frame=\(anchor.frame) app=\(app.frame) "
            + "thumbnailExists=\(thumbnail.exists)")
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[gallery] before preparation (\(session))")
        if scrollEditorToMakeHittable(anchor, in: app) {
            print("INTERACTION-VERIFY[gallery] session=\(session): count anchor reached the viewport at "
                + "\(anchor.frame)")
        } else {
            print("INTERACTION-VERIFY[gallery] session=\(session): count anchor could not be scrolled into "
                + "the viewport (frame=\(anchor.frame))")
        }
        print("INTERACTION-VERIFY[gallery] session=\(session): after preparation "
            + "thumbnailExists=\(thumbnail.exists)")
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[gallery] after preparation (\(session))")
    }

    /// Minimal bounded user scroll for Editor targets that exist but are not
    /// hittable, which is what maximum text size exposes (Editor content 2256.3
    /// points tall over four pages with the import entry from y=786.7 in run
    /// 37230253288).
    ///
    /// The Editor context is proven by the real `editor.placeholder`, the absence of
    /// the system `Photos` picker navigation and of the app's own preview sheet
    /// (detected through its declared `preview.*` identifiers, so no undeclared
    /// title string has to be queried), and a single Editor scroll view. The usable
    /// viewport is that scroll view intersected with the app window and reduced by
    /// the area the Editor navigation bar covers. The target frame and the viewport
    /// are re-read on every pass: only a target that reaches past the bottom edge
    /// swipes up, only one that reaches past the top edge swipes down, and a target
    /// inside the usable viewport that still cannot be hit (or whose frame is not
    /// finite) fails instead of guessing a direction. At most three native swipes;
    /// an already hittable target never sees a gesture.
    private func scrollEditorToMakeHittable(_ target: XCUIElement, in app: XCUIApplication) -> Bool {
        if target.isHittable { return true }
        guard target.exists else { return false }
        guard element("editor.placeholder", in: app).exists else { return false }
        guard !app.navigationBars["Photos"].exists,
              !element("preview.image", in: app).exists,
              !element("preview.done", in: app).exists else { return false }
        guard app.scrollViews.count == 1 else { return false }
        let scrollView = app.scrollViews.element
        guard isFinitePositive(app.frame), isFinitePositive(scrollView.frame) else { return false }

        for _ in 0..<3 {
            if target.isHittable { return true }
            // Every real geometry value is re-read on each pass: the app window, the
            // single Editor navigation bar and scroll view, and the target itself.
            let targetFrame = target.frame
            guard isFinitePositive(targetFrame) else { return false }
            let appFrame = app.frame
            guard isFinitePositive(appFrame) else { return false }
            guard app.navigationBars.count == 1 else { return false }
            let navigationFrame = app.navigationBars.element.frame
            guard isFinitePositive(navigationFrame) else { return false }
            let scrollFrame = scrollView.frame
            guard isFinitePositive(scrollFrame) else { return false }

            var viewport = scrollFrame.intersection(appFrame)
            if viewport.intersects(navigationFrame) {
                if navigationFrame.midY <= viewport.midY {
                    let newMinY = max(viewport.minY, navigationFrame.maxY)
                    viewport = CGRect(x: viewport.minX, y: newMinY,
                                      width: viewport.width, height: viewport.maxY - newMinY)
                } else {
                    let newMaxY = min(viewport.maxY, navigationFrame.minY)
                    viewport = CGRect(x: viewport.minX, y: viewport.minY,
                                      width: viewport.width, height: newMaxY - viewport.minY)
                }
            }
            guard isFinitePositive(viewport) else { return false }

            // Any part of the target reaching past an edge needs a gesture, so a
            // partially overflowing target (observed Import at y=786.7 with height
            // 125.3) is handled as well. A target fully inside the usable viewport
            // that still cannot be hit has no justified direction, so it fails
            // instead of guessing.
            if targetFrame.maxY > viewport.maxY {
                scrollView.swipeUp()
            } else if targetFrame.minY < viewport.minY {
                scrollView.swipeDown()
            } else {
                return false
            }
        }
        return target.isHittable
    }

    /// Closes the system's "Private Access to Photos" onboarding exactly once when
    /// it overflows the picker's grid.
    ///
    /// Observed at maximum text size (run 37230253288): the picker scope
    /// `photosView_content_scroll_view` is `{{0,72},{402,802}}` while the unique
    /// `PXGSingleViewContainerView_AX` banner is `{{0,184},{402,896.7}}` - taller
    /// than the scope - and pushes the grid to y=1080.7, below the 874-point window,
    /// so no photo ever existed. The same banner text also appears once in an
    /// unidentified wrapper with its own `Close`, so the button is queried **only**
    /// inside the identified container and must be unique there.
    ///
    /// Any state that is not an overflowing onboarding is left to the original path
    /// unchanged.
    private func closeOverflowingPhotoAccessOnboarding(in app: XCUIApplication, scope: XCUIElement,
                                                      photos: XCUIElementQuery,
                                                      session: String) -> PickerInteraction {
        let containers = app.otherElements.matching(identifier: "PXGSingleViewContainerView_AX")
        guard containers.count == 1 else {
            return PickerInteraction(succeeded: true,
                                     diagnostic: "no single photo-access onboarding container (count=\(containers.count))")
        }
        let container = containers.element
        guard container.exists else {
            return PickerInteraction(succeeded: true, diagnostic: "no photo-access onboarding present")
        }
        let containerFrame = container.frame
        guard isFinitePositive(containerFrame), isFinitePositive(scope.frame) else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "onboarding/scope frame is not finite and positive "
                    + "(container=\(containerFrame) scope=\(scope.frame))"
            )
        }
        // Only an onboarding that actually overflows the grid and hides every photo
        // is handled here.
        guard containerFrame.height > scope.frame.height, photos.count == 0 else {
            return PickerInteraction(
                succeeded: true,
                diagnostic: "no overflowing photo-access onboarding "
                    + "(container=\(containerFrame) scope=\(scope.frame) photos=\(photos.count))"
            )
        }

        let closes = container.buttons.matching(NSPredicate(format: "label == %@", "Close"))
        guard closes.count == 1 else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "expected exactly one Close inside the onboarding container, found \(closes.count)"
            )
        }
        let close = closes.element
        guard close.waitUntilEnabledAndHittable(), isFinitePositive(close.frame),
              scope.frame.contains(close.frame), app.frame.contains(close.frame) else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "the onboarding Close is not usable (exists=\(close.exists) enabled=\(close.isEnabled) "
                    + "hittable=\(close.isHittable) frame=\(close.frame))"
            )
        }

        print("INTERACTION-VERIFY[onboarding] session=\(session): overflowing container=\(containerFrame) "
            + "scope=\(scope.frame) photos=\(photos.count) close=\(close.frame)")
        print("INTERACTION-VERIFY[onboarding] hierarchy before close: \(app.debugDescription)")
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[onboarding] before close (\(session))")

        close.tap()

        print("INTERACTION-VERIFY[onboarding] photos after close: \(photos.count)")
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[onboarding] after close (\(session))")
        return PickerInteraction(
            succeeded: true,
            diagnostic: "closed overflowing onboarding (container=\(containerFrame) scope=\(scope.frame))"
        )
    }

    /// Cancels the removal confirmation.
    ///
    /// The recorded native hierarchies show two different shapes:
    ///
    /// * Older systems: a real sheet (or alert) with a `Cancel` button — the
    ///   original path is kept unchanged.
    /// * iOS 26.5 (run 37225749574, dump `9EC5723E-…`): the confirmation is a
    ///   `Popover` `{{81, 72}, {240, 247.3}}` whose `Sheet` titled "Remove this
    ///   photo from the project?" offers only `Remove`. There is no `Cancel`
    ///   control at all, so the only cancellation affordance is the unique
    ///   `Other` element `PopoverDismissRegion` (label "dismiss popup",
    ///   `{{0, 0}, {402, 874}}`) reported outside the popover.
    ///
    /// On iOS 26 this helper verifies — in this order — that there is exactly one
    /// `Popover`, that it contains exactly one `Sheet` whose label is exactly the
    /// removal question, that the question and the "original is not changed"
    /// explanation live inside that sheet (so an app-wide similar text can never
    /// stand in for ownership), that there is exactly one `Other`
    /// `PopoverDismissRegion` (whole-identifier match, not a first node of any
    /// type), that both frames are finite/positive and inside the app window,
    /// and that the region's relative centre is on screen and strictly outside the
    /// popover. Only then does it perform exactly one public element-relative
    /// centre tap. Any missing precondition is a hard failure: no substitute
    /// point, no candidate search, no retry.
    private func cancelRemovalConfirmation(in app: XCUIApplication) -> PickerInteraction {
        guard usesModernSystemUI else {
            let cancelButton = confirmationButton(named: "Cancel", in: app)
            guard cancelButton.waitUntilEnabledAndHittable() else {
                return PickerInteraction(
                    succeeded: false,
                    diagnostic: "the confirmation Cancel button exists=\(cancelButton.exists) "
                        + "enabled=\(cancelButton.isEnabled) hittable=\(cancelButton.isHittable)"
                )
            }
            cancelButton.tap()
            return PickerInteraction(succeeded: true, diagnostic: "")
        }

        // Exactly one confirmation popover, addressed as a whole (count == 1 and
        // `.element`), never a first match of any popover.
        let popovers = app.popovers
        guard popovers.count == 1 else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "expected exactly one confirmation popover, found \(popovers.count)"
            )
        }
        let popover = popovers.element
        guard popover.waitForExistence(timeout: 20) else {
            return PickerInteraction(succeeded: false, diagnostic: "the confirmation popover did not become ready")
        }
        let popoverFrame = popover.frame

        // Inside that unique popover, the sheet must carry the exact removal
        // question as its label and must itself be unique.
        let questionTitle = "Remove this photo from the project?"
        let sheets = popover.sheets.matching(NSPredicate(format: "label == %@", questionTitle))
        guard sheets.count == 1 else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "expected exactly one sheet labelled '\(questionTitle)' inside the popover, "
                    + "found \(sheets.count)"
            )
        }
        let sheet = sheets.element
        guard sheet.waitForExistence(timeout: 20) else {
            return PickerInteraction(succeeded: false, diagnostic: "the confirmation sheet did not become ready")
        }

        // The question and the "original is not changed" explanation must be inside
        // that exact sheet — an app-wide similar text proves no ownership.
        let question = sheet.staticTexts
            .matching(NSPredicate(format: "label == %@", questionTitle)).firstMatch
        let explanation = sheet.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "photo library is not changed")).firstMatch
        guard question.waitForExistence(timeout: 30), explanation.exists else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "the confirmation sheet is missing its question/explanation "
                    + "(question=\(question.exists) explanation=\(explanation.exists))"
            )
        }

        let dismissRegions = app.otherElements.matching(identifier: "PopoverDismissRegion")
        guard dismissRegions.count == 1 else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "expected exactly one 'PopoverDismissRegion', found \(dismissRegions.count)"
            )
        }
        let dismissRegion = dismissRegions.element
        guard dismissRegion.waitForExistence(timeout: 20) else {
            return PickerInteraction(succeeded: false, diagnostic: "'PopoverDismissRegion' did not become ready")
        }

        let regionFrame = dismissRegion.frame
        guard isFinitePositive(regionFrame), isFinitePositive(popoverFrame),
              app.frame.contains(regionFrame), app.frame.contains(popoverFrame) else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "non-usable confirmation frames: dismissRegion=\(regionFrame) "
                    + "popover=\(popoverFrame) app=\(app.frame)"
            )
        }

        // Computed only to validate the authorised point; the tap below stays
        // element-relative and never uses this absolute point.
        let centre = CGPoint(x: regionFrame.midX, y: regionFrame.midY)
        guard app.frame.contains(centre), !popoverFrame.contains(centre) else {
            return PickerInteraction(
                succeeded: false,
                diagnostic: "the dismiss-region centre \(centre) is not on screen or not strictly outside "
                    + "the popover \(popoverFrame)"
            )
        }

        print("INTERACTION-VERIFY[confirmation] popover=\(popoverFrame) dismissRegion=\(regionFrame) "
            + "centre=(\(centre.x), \(centre.y)) strategy=element-relative-centre-tap")
        print("INTERACTION-VERIFY[confirmation] hierarchy before cancel: \(app.debugDescription)")
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[confirmation] before cancel")

        dismissRegion.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[confirmation] after cancel")
        return PickerInteraction(
            succeeded: true,
            diagnostic: "popover=\(popoverFrame) dismissRegion=\(regionFrame) centre=(\(centre.x), \(centre.y))"
        )
    }

    /// The identifier is applied to a `PhotosPicker`, whose element type is not
    /// guaranteed, so match any element type.
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
