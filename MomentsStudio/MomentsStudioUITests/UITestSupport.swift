import XCTest

extension XCUIElement {
    /// Waits until the element exists **and** is enabled.
    ///
    /// Since Stage 02, Home keeps Create and Import disabled until the photo
    /// library has finished loading, so `waitForExistence` alone can hand back a
    /// control that is not tappable yet. Used by every smoke test that taps.
    func waitUntilEnabled(timeout: TimeInterval = 20) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits until the element exists, is enabled **and** can receive a tap.
    ///
    /// Selection state in system UI updates asynchronously: an Add control can
    /// exist and even be hittable while it is still disabled, so waiting for
    /// existence alone is not enough before pressing it.
    func waitUntilEnabledAndHittable(timeout: TimeInterval = 30) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isEnabled == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits until the element exists **and** can receive a tap.
    func waitUntilHittable(timeout: TimeInterval = 20) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits until the element no longer exists, within a bounded timeout.
    ///
    /// `waitForExistence(timeout:)` returns *immediately* when the element still
    /// exists, so it cannot assert that something disappeared while a dismissal
    /// is still underway. This waits for `exists == false` and only reports
    /// success once the element is really gone.
    func waitForDisappearance(timeout: TimeInterval = 20) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}


/// Stage 02 picker, gallery and confirmation helpers, moved verbatim from
/// `Stage02ImportUITests` into a shared `XCTestCase` extension so Stage 03 uses the
/// exact same locators, waits, Close and Popover rules instead of simplified copies.
/// Only the `private` keyword was removed.
extension XCTestCase {
    /// failure message so a real macOS run preserves native evidence.
    struct PickerInteraction {
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
    var usesModernPickerLayout: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
    }

    var pickerGridIdentifier: String {
        usesModernPickerLayout ? "photosView_content_scroll_view" : "content_scroll_view"
    }

    func pickerConfirmationControl(in app: XCUIApplication) -> XCUIElement {
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
    func selectFirstPhotoCell(in app: XCUIApplication, session: String) -> PickerInteraction {
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
    func pickerElementDiagnostics(scope: XCUIElement, photos: XCUIElementQuery) -> String {
        var parts = ["scope=\(scope.frame)", "count=\(photos.count)"]
        for index in 0..<min(3, photos.count) {
            let element = photos.element(boundBy: index)
            parts.append("#\(index) exists=\(element.exists) hittable=\(element.isHittable) "
                + "frame=\(element.frame) label=\(element.label)")
        }
        return parts.joined(separator: " | ")
    }

    /// Test-only diagnosis kept for the run report; no product hooks are involved.
    func attachFullAppScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Presses the picker's confirmation control once it is **enabled and
    /// hittable**: the selection state updates asynchronously, so existing is not
    /// enough. iOS 26 confirms with `Done` inside the `Photos` navigation bar;
    /// older versions keep the observed `Add` button.
    func tapPickerAddButton(in app: XCUIApplication) -> PickerInteraction {
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
    func previewLoadingIndicator(in app: XCUIApplication) -> XCUIElement {
        let inSheet = app.sheets.firstMatch.activityIndicators.firstMatch
        if inSheet.exists { return inSheet }
        return app.activityIndicators.firstMatch
    }

    /// Imported thumbnails carry `editor.photo.<uuid>`; the id is generated at
    /// runtime, so match by prefix instead of guessing one.
    func importedThumbnail(in app: XCUIApplication) -> XCUIElement {
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
    func editorBackButton(in app: XCUIApplication) -> XCUIElement {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
            return app.buttons["BackButton"]
        }
        return app.navigationBars.buttons["Moments Studio"]
    }

    /// Full identifiers of the Home project rows. Used to identify a project across
    /// a real terminate/launch by set difference, never by row order or name.
    func homeProjectIdentifiers(in app: XCUIApplication) -> Set<String> {
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
    func importedThumbnailIdentifiers(in app: XCUIApplication) -> [String] {
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

    func photoCount(in app: XCUIApplication) -> String {
        element("editor.photoCount", in: app).label
    }

    func staticText(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Confirmation dialogs are action sheets (occasionally alerts); the sheet is
    /// preferred so the toolbar's own "Remove" label cannot be matched instead.
    func confirmationButton(named label: String, in app: XCUIApplication) -> XCUIElement {
        let inSheet = app.sheets.buttons[label]
        if inSheet.waitForExistence(timeout: 15) { return inSheet }
        return app.alerts.buttons[label]
    }

    /// System-UI shape branch (iOS 26 changed several system containers).
    var usesModernSystemUI: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
    }

    /// Finite, non-empty and positive-size frame check shared by the confirmation
    /// checks: an empty frame must never be treated as visible.
    func isFinitePositive(_ frame: CGRect) -> Bool {
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
    func prepareEditorGallery(expectingThumbnail thumbnail: XCUIElement, in app: XCUIApplication,
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

        // Real evidence (run 37957684567, Stage02ImportUITests:155): the committed
        // count anchor sat at y=852.3 inside the 874-point window, yet the lazy
        // gallery grid *below* it had not been instantiated, so no thumbnail node
        // existed. The approved minimal repair keeps every guard above and
        // additionally scrolls the unique Editor container downwards from the count
        // with bounded, slow real drags until the gallery grid exists. It never
        // asserts the thumbnail itself and adds no waiting as a substitute: the
        // caller's original existence, identity, viewport-hittable and
        // preview/removal assertions still decide.
        var instantiationAttempts = 0
        while !thumbnail.exists, instantiationAttempts < 6 {
            guard app.scrollViews.count == 1, app.navigationBars.count == 1,
                  element("editor.placeholder", in: app).exists,
                  !app.navigationBars["Photos"].exists,
                  !element("preview.image", in: app).exists,
                  !element("preview.done", in: app).exists else { break }
            let scrollView = app.scrollViews.element
            let scrollFrame = scrollView.frame
            guard isFinitePositive(scrollFrame), isFinitePositive(app.frame) else { break }
            print("INTERACTION-VERIFY[gallery] session=\(session): bounded drag to instantiate the gallery "
                + "(attempt \(instantiationAttempts + 1), scroll=\(scrollFrame))")
            scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.1,
                       thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
            instantiationAttempts += 1
        }
        print("INTERACTION-VERIFY[gallery] session=\(session): gallery instantiation attempts="
            + "\(instantiationAttempts) thumbnailExists=\(thumbnail.exists)")
        print("INTERACTION-VERIFY[gallery] session=\(session): after preparation "
            + "thumbnailExists=\(thumbnail.exists)")
        attachFullAppScreenshot(app, named: "INTERACTION-VERIFY[gallery] after preparation (\(session))")
    }

    /// Minimal bounded user scroll for Editor targets outside the usable viewport,
    /// including partially visible targets reported as hittable by XCTest.
    /// Maximum text size also exposes this (Editor content 2256.3
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
    /// drags up, only one that reaches past the top edge drags down, and a target
    /// inside the usable viewport that still cannot be hit (or whose frame is not
    /// finite) fails instead of guessing a direction. At most three native drags;
    /// a fully visible, hittable target never sees a gesture.
    func scrollEditorToMakeHittable(_ target: XCUIElement, in app: XCUIApplication) -> Bool {
        guard target.exists else { return false }
        guard element("editor.placeholder", in: app).exists else { return false }
        guard !app.navigationBars["Photos"].exists,
              !element("preview.image", in: app).exists,
              !element("preview.done", in: app).exists else { return false }
        guard app.scrollViews.count == 1 else { return false }
        let scrollView = app.scrollViews.element
        guard isFinitePositive(app.frame), isFinitePositive(scrollView.frame) else { return false }

        for attempt in 0...3 {
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

            // iOS 26.5 reports a thumbnail with only its top 14 points visible as
            // hittable. Its center tap misses the clipped editor viewport, so
            // require the whole control inside the actual viewport before tapping.
            if viewport.contains(targetFrame) { return target.isHittable }
            guard attempt < 3 else { return false }

            // Full swipes oscillated past the lower layer in run 37881959932.
            // Move only the measured overflow plus a small inset, slowly, and
            // hold before lifting to avoid momentum. Both endpoints stay inside
            // the proven viewport and are relative to the actual scroll element.
            let overflow: CGFloat
            let direction: CGFloat
            if targetFrame.maxY > viewport.maxY {
                overflow = targetFrame.maxY - viewport.maxY
                direction = -1
            } else if targetFrame.minY < viewport.minY {
                overflow = viewport.minY - targetFrame.minY
                direction = 1
            } else {
                return false
            }
            let distance = min(max(24, overflow + 16), viewport.height * 0.45)
            let startY = (viewport.midY - scrollFrame.minY) / scrollFrame.height
            let endY = startY + direction * distance / scrollFrame.height
            print("INTERACTION-VERIFY[editor-scroll] attempt=\(attempt) target=\(target.identifier) "
                + "frame=\(targetFrame) viewport=\(viewport) distance=\(distance)")
            scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                .press(forDuration: 0.05,
                       thenDragTo: scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        return false
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
    func closeOverflowingPhotoAccessOnboarding(in app: XCUIApplication, scope: XCUIElement,
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
    func cancelRemovalConfirmation(in app: XCUIApplication) -> PickerInteraction {
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
    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}



/// Moved verbatim from `Stage02ImportUITests` (body unchanged, only `private`
/// removed) so Stage 03 opens the picker with the same readiness rule.
extension XCTestCase {
    /// The picker is system UI over the app. Readiness is the native `Photos`
    /// navigation bar, which was observed in **both** recorded layouts
}

/// Stage 03 additions on top of the shared Stage 02 helpers: dynamic-identifier
/// lookup for layer rows/buttons and label lookup for the reorder/reset buttons.
/// They fail loudly (an exact-match query for a name that cannot exist) instead of
/// returning an arbitrary element.
extension XCTestCase {
    func firstElement(withIdentifierPrefix prefix: String, in app: XCUIApplication) -> XCUIElement {
        for candidate in app.descendants(matching: .any).allElementsBoundByIndex
        where candidate.identifier.hasPrefix(prefix) {
            return candidate
        }
        return app.descendants(matching: .any)
            .matching(identifier: prefix + "-absent")
            .element(boundBy: 0)
    }

    func button(matchingLabel label: String, in query: XCUIElementQuery) -> XCUIElement {
        for candidate in query.allElementsBoundByIndex where candidate.label == label {
            return candidate
        }
        return query.element(boundBy: 0)
    }
}

/// Moved verbatim from `Stage02ImportUITests` (body unchanged, only `private`
/// removed) so Stage 03 opens the picker with the exact same readiness rule:
/// the native `Photos` navigation bar, never a lone Cancel control.
extension XCTestCase {
    func waitForPickerToOpen(in app: XCUIApplication, timeout: TimeInterval = 30) -> Bool {
        app.navigationBars["Photos"].waitForExistence(timeout: timeout)
    }
}
