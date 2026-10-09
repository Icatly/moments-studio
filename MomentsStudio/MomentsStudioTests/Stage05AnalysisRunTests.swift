import XCTest
@testable import MomentsStudio

/// Regression tests for `PhotoAnalysisRun` — the identity/request guard that the
/// Photo summary sheet actually writes and reads through.
///
/// They cover the reported gaps directly: a superseded request, a different
/// current project, a deleted photo or changed metadata must neither write nor
/// display a value; a result measured for another asset or another display size is
/// refused; and a failure must never stand in for a previous success. The fixtures
/// always describe the metadata they claim, so no assertion can pass because the
/// helper silently invented the right numbers.
final class Stage05AnalysisRunTests: XCTestCase {
    private func photo(
        assetID: UUID = UUID(),
        thumbnail: String = "thumb.jpg",
        width: Int = 320,
        height: Int = 240,
        orientation: Int = 1
    ) -> ImportedPhoto {
        ImportedPhoto(
            asset: Asset(id: assetID, localReference: "original.jpg"),
            thumbnailReference: thumbnail,
            previewReference: "preview.jpg",
            pixelWidth: width,
            pixelHeight: height,
            orientation: orientation,
            contentType: "public.jpeg"
        )
    }

    /// Builds a result for the exact metadata it claims.
    private func analysis(
        assetID: UUID,
        displayWidth: Int,
        displayHeight: Int,
        luminance: Double = 0.5,
        confidence: PhotoAnalysisConfidence = .adequate
    ) -> PhotoAnalysis {
        PhotoAnalysis(
            assetID: assetID,
            displayWidth: displayWidth,
            displayHeight: displayHeight,
            sampleWidth: 64,
            sampleHeight: 48,
            validPixelCount: 3072,
            meanRed: 0.5,
            meanGreen: 0.5,
            meanBlue: 0.5,
            meanLuminance: luminance,
            luminanceContrast: 0.1,
            meanSaturation: 0.1,
            darkPixelRatio: 0,
            brightPixelRatio: 0,
            coverage: 1,
            confidence: confidence
        )
    }

    /// A result that matches one photo's own identity and display size.
    private func matching(_ subject: ImportedPhoto, luminance: Double = 0.5) -> PhotoAnalysis {
        analysis(assetID: subject.asset.id,
                 displayWidth: subject.displayPixelSize.width,
                 displayHeight: subject.displayPixelSize.height,
                 luminance: luminance)
    }

    func testValueIsShownOnlyForTheMetadataItWasMeasuredFrom() {
        let project = UUID()
        let subject = photo()
        var run = PhotoAnalysisRun(projectID: project)
        XCTAssertTrue(run.accept(matching(subject), measuredFor: subject, current: subject,
                                 token: run.token, currentProjectID: project, isProjectAvailable: true))
        XCTAssertNotNil(run.measurement(for: subject, currentProjectID: project))

        // Same asset identity, different metadata: the old value must not render.
        let resized = photo(assetID: subject.asset.id, width: 640, height: 480)
        XCTAssertNil(run.measurement(for: resized, currentProjectID: project))
        let reThumbnailed = photo(assetID: subject.asset.id, thumbnail: "thumb-v2.jpg")
        XCTAssertNil(run.measurement(for: reThumbnailed, currentProjectID: project))
        let rotated = photo(assetID: subject.asset.id, orientation: 6)
        XCTAssertNil(run.measurement(for: rotated, currentProjectID: project))

        // A result whose display size belongs to the *new* metadata is what can be shown.
        XCTAssertTrue(run.accept(matching(resized, luminance: 0.9), measuredFor: resized, current: resized,
                                 token: run.token, currentProjectID: project, isProjectAvailable: true))
        XCTAssertEqual(run.measurement(for: resized, currentProjectID: project)?.meanLuminance, 0.9)
        XCTAssertNil(run.measurement(for: subject, currentProjectID: project))
    }

    func testResultForAnotherAssetOrDisplaySizeIsRefused() {
        let project = UUID()
        let subject = photo()
        var run = PhotoAnalysisRun(projectID: project)
        let other = photo()

        // Same photo request, but the measured asset is a different one.
        XCTAssertFalse(run.accept(analysis(assetID: other.asset.id,
                                           displayWidth: subject.displayPixelSize.width,
                                           displayHeight: subject.displayPixelSize.height),
                                  measuredFor: subject, current: subject, token: run.token,
                                  currentProjectID: project, isProjectAvailable: true))
        XCTAssertNil(run.measurement(for: subject, currentProjectID: project))

        // Correct asset, but a display size that does not belong to this photo.
        XCTAssertFalse(run.accept(analysis(assetID: subject.asset.id, displayWidth: 999, displayHeight: 111),
                                  measuredFor: subject, current: subject, token: run.token,
                                  currentProjectID: project, isProjectAvailable: true))
        // A rotated photo's display size is swapped, so the unrotated numbers are wrong too.
        let rotated = photo(assetID: subject.asset.id, orientation: 6)
        XCTAssertFalse(run.accept(matching(subject), measuredFor: rotated, current: rotated, token: run.token,
                                  currentProjectID: project, isProjectAvailable: true))
        XCTAssertNil(run.measurement(for: rotated, currentProjectID: project))

        XCTAssertTrue(run.accept(matching(rotated), measuredFor: rotated, current: rotated, token: run.token,
                                 currentProjectID: project, isProjectAvailable: true))
        XCTAssertNotNil(run.measurement(for: rotated, currentProjectID: project))
    }

    func testAnotherCurrentProjectCannotWriteOrDisplay() {
        let project = UUID()
        let otherProject = UUID()
        let subject = photo()
        var run = PhotoAnalysisRun(projectID: project)

        // Same run, same token, same asset — but the sheet now presents another project.
        XCTAssertFalse(run.accept(matching(subject), measuredFor: subject, current: subject, token: run.token,
                                  currentProjectID: otherProject, isProjectAvailable: true))
        XCTAssertFalse(run.reject(.unreadable, measuredFor: subject, current: subject, token: run.token,
                                  currentProjectID: otherProject, isProjectAvailable: true))
        XCTAssertNil(run.measurement(for: subject, currentProjectID: otherProject))
        XCTAssertNil(run.failure(for: subject, currentProjectID: otherProject))

        // A dismissed sheet (no presented project) can neither write nor display either.
        XCTAssertFalse(run.accept(matching(subject), measuredFor: subject, current: subject, token: run.token,
                                  currentProjectID: nil, isProjectAvailable: true))
        XCTAssertNil(run.measurement(for: subject, currentProjectID: nil))

        XCTAssertTrue(run.accept(matching(subject), measuredFor: subject, current: subject, token: run.token,
                                 currentProjectID: project, isProjectAvailable: true))
        XCTAssertNotNil(run.measurement(for: subject, currentProjectID: project))
        XCTAssertNil(run.measurement(for: subject, currentProjectID: otherProject),
                     "A stored value is still only readable for its own project")
    }

    func testSupersededTokenCannotWriteAnything() {
        let project = UUID()
        let subject = photo()
        var run = PhotoAnalysisRun(projectID: project)
        let staleToken = run.token

        let freshToken = run.invalidate()
        XCTAssertNotEqual(staleToken, freshToken)
        XCTAssertFalse(run.accept(matching(subject), measuredFor: subject, current: subject,
                                  token: staleToken, currentProjectID: project, isProjectAvailable: true))
        XCTAssertFalse(run.reject(.unreadable, measuredFor: subject, current: subject,
                                  token: staleToken, currentProjectID: project, isProjectAvailable: true))
        XCTAssertNil(run.measurement(for: subject, currentProjectID: project))
        XCTAssertNil(run.failure(for: subject, currentProjectID: project))

        XCTAssertTrue(run.accept(matching(subject), measuredFor: subject, current: subject,
                                 token: freshToken, currentProjectID: project, isProjectAvailable: true))
        XCTAssertNotNil(run.measurement(for: subject, currentProjectID: project))
    }

    func testInvalidateDropsValuesImmediatelyForCloseAndRecompute() {
        let project = UUID()
        let subject = photo()
        var run = PhotoAnalysisRun(projectID: project)
        let firstToken = run.token
        XCTAssertTrue(run.accept(matching(subject), measuredFor: subject, current: subject,
                                 token: firstToken, currentProjectID: project, isProjectAvailable: true))
        XCTAssertNotNil(run.measurement(for: subject, currentProjectID: project))

        // Close or recompute invalidates in place; nothing from the old run survives
        // and its token stops matching even before a replacement task exists.
        let secondToken = run.invalidate()
        XCTAssertNil(run.measurement(for: subject, currentProjectID: project))
        XCTAssertNil(run.failure(for: subject, currentProjectID: project))
        XCTAssertFalse(run.accept(matching(subject), measuredFor: subject, current: subject,
                                  token: firstToken, currentProjectID: project, isProjectAvailable: true))
        XCTAssertNil(run.measurement(for: subject, currentProjectID: project))
        XCTAssertTrue(run.accept(matching(subject, luminance: 0.2), measuredFor: subject, current: subject,
                                 token: secondToken, currentProjectID: project, isProjectAvailable: true))
        XCTAssertEqual(run.measurement(for: subject, currentProjectID: project)?.meanLuminance, 0.2)
    }

    func testDeletedPhotoAndUnavailableProjectCannotWrite() {
        let project = UUID()
        let subject = photo()
        var run = PhotoAnalysisRun(projectID: project)

        XCTAssertFalse(run.accept(matching(subject), measuredFor: subject, current: nil,
                                  token: run.token, currentProjectID: project, isProjectAvailable: true),
                       "A deleted photo must not be written")
        XCTAssertFalse(run.accept(matching(subject), measuredFor: subject, current: subject,
                                  token: run.token, currentProjectID: project, isProjectAvailable: false),
                       "A project that no longer exists must not be written")
        XCTAssertFalse(run.reject(.missing, measuredFor: subject, current: subject,
                                  token: run.token, currentProjectID: project, isProjectAvailable: false))
        XCTAssertNil(run.measurement(for: subject, currentProjectID: project))
        XCTAssertNil(run.failure(for: subject, currentProjectID: project))
    }

    func testOldSizeResultIsNeverShownAsNewMetadataResult() {
        let project = UUID()
        let subject = photo(width: 320, height: 240)
        let resized = photo(assetID: subject.asset.id, width: 640, height: 480)
        var run = PhotoAnalysisRun(projectID: project)

        XCTAssertTrue(run.accept(matching(subject, luminance: 0.3), measuredFor: subject, current: subject,
                                 token: run.token, currentProjectID: project, isProjectAvailable: true))
        // The 320x240 measurement must not be readable as the 640x480 photo's result,
        // and the old-size payload cannot be accepted for the new metadata either.
        XCTAssertNil(run.measurement(for: resized, currentProjectID: project))
        XCTAssertFalse(run.accept(matching(subject), measuredFor: resized, current: resized, token: run.token,
                                  currentProjectID: project, isProjectAvailable: true))
        XCTAssertNil(run.measurement(for: resized, currentProjectID: project))
    }

    func testFailureReplacesSuccessAndNeverCoexistsForOneIdentity() {
        let project = UUID()
        let subject = photo()
        var run = PhotoAnalysisRun(projectID: project)

        XCTAssertTrue(run.accept(matching(subject), measuredFor: subject, current: subject,
                                 token: run.token, currentProjectID: project, isProjectAvailable: true))
        XCTAssertTrue(run.reject(.noVisiblePixels, measuredFor: subject, current: subject,
                                 token: run.token, currentProjectID: project, isProjectAvailable: true))
        XCTAssertNil(run.measurement(for: subject, currentProjectID: project),
                     "A failure must not leave the old estimate on screen")
        XCTAssertEqual(run.failure(for: subject, currentProjectID: project), .noVisiblePixels)

        XCTAssertTrue(run.accept(matching(subject), measuredFor: subject, current: subject,
                                 token: run.token, currentProjectID: project, isProjectAvailable: true))
        XCTAssertNil(run.failure(for: subject, currentProjectID: project))
        XCTAssertNotNil(run.measurement(for: subject, currentProjectID: project))

        // A failure measured from other metadata is not shown for this photo.
        let resized = photo(assetID: subject.asset.id, width: 640, height: 480)
        XCTAssertTrue(run.reject(.unreadable, measuredFor: resized, current: resized,
                                 token: run.token, currentProjectID: project, isProjectAvailable: true))
        XCTAssertNil(run.failure(for: subject, currentProjectID: project))
        XCTAssertEqual(run.failure(for: resized, currentProjectID: project), .unreadable)
    }

    func testBeginRequestOnlyStartsForTheCurrentKeyAndSheet() {
        let project = UUID()
        let subject = photo()
        var run = PhotoAnalysisRun(projectID: project)
        let key = "1|photoA"
        let initialToken = run.token
        XCTAssertTrue(run.accept(matching(subject, luminance: 0.4), measuredFor: subject, current: subject,
                                 token: initialToken, currentProjectID: project, isProjectAvailable: true))

        // A superseded task (its captured key is no longer current) must not rotate
        // the token and must not clear the live run's values.
        XCTAssertNil(run.beginRequest(taskKey: "0|photoA", currentTaskKey: key, isSheetCurrent: true))
        XCTAssertEqual(run.token, initialToken)
        XCTAssertEqual(run.measurement(for: subject, currentProjectID: project)?.meanLuminance, 0.4)

        // Nor may a task start while the sheet is no longer current.
        XCTAssertNil(run.beginRequest(taskKey: key, currentTaskKey: key, isSheetCurrent: false))
        XCTAssertEqual(run.token, initialToken)
        XCTAssertNotNil(run.measurement(for: subject, currentProjectID: project))

        // The task that owns the current key does start, with a fresh token and no
        // values carried over.
        let freshToken = run.beginRequest(taskKey: key, currentTaskKey: key, isSheetCurrent: true)
        XCTAssertNotNil(freshToken)
        XCTAssertNotEqual(freshToken, initialToken)
        XCTAssertNil(run.measurement(for: subject, currentProjectID: project))
        XCTAssertFalse(run.accept(matching(subject), measuredFor: subject, current: subject,
                                  token: initialToken, currentProjectID: project, isProjectAvailable: true))
    }

    func testNewMetadataRestartGetsANewTokenAndDropsOldValues() {
        let project = UUID()
        let before = photo(width: 320, height: 240)
        let after = photo(assetID: before.asset.id, width: 640, height: 480)
        var run = PhotoAnalysisRun(projectID: project)
        let oldToken = run.token
        XCTAssertTrue(run.accept(matching(before, luminance: 0.3), measuredFor: before, current: before,
                                 token: oldToken, currentProjectID: project, isProjectAvailable: true))
        XCTAssertNotNil(run.measurement(for: before, currentProjectID: project))

        // The metadata change restarts the `.task`, and that restart begins its own
        // request: a new token and none of the old values.
        let newToken = run.beginRequest(taskKey: "1|640x480", currentTaskKey: "1|640x480", isSheetCurrent: true)
        XCTAssertNotNil(newToken)
        XCTAssertNotEqual(newToken, oldToken)
        XCTAssertNil(run.measurement(for: before, currentProjectID: project))
        XCTAssertNil(run.measurement(for: after, currentProjectID: project))
        XCTAssertFalse(run.accept(matching(before), measuredFor: after, current: after,
                                  token: oldToken, currentProjectID: project, isProjectAvailable: true),
                       "The stale token must not write after the restart")
        XCTAssertTrue(run.accept(matching(after, luminance: 0.8), measuredFor: after, current: after,
                                 token: newToken!, currentProjectID: project, isProjectAvailable: true))
        XCTAssertEqual(run.measurement(for: after, currentProjectID: project)?.meanLuminance, 0.8)
    }

    func testSupersededTaskCannotClearNewState() {
        let project = UUID()
        let before = photo(width: 320, height: 240)
        let after = photo(assetID: before.asset.id, width: 640, height: 480)
        let oldKey = "1|320x240"
        let newKey = "1|640x480"
        var run = PhotoAnalysisRun(projectID: project)
        let oldToken = run.beginRequest(taskKey: oldKey, currentTaskKey: oldKey, isSheetCurrent: true)!
        XCTAssertTrue(run.accept(matching(before, luminance: 0.3), measuredFor: before, current: before,
                                 token: oldToken, currentProjectID: project, isProjectAvailable: true))

        let newToken = run.beginRequest(taskKey: newKey, currentTaskKey: newKey, isSheetCurrent: true)!
        XCTAssertTrue(run.accept(matching(after, luminance: 0.9), measuredFor: after, current: after,
                                 token: newToken, currentProjectID: project, isProjectAvailable: true))

        // The superseded task resumes late: it may not begin a request, may not clear
        // the newer value and may not write with its old token.
        XCTAssertNil(run.beginRequest(taskKey: oldKey, currentTaskKey: newKey, isSheetCurrent: true))
        XCTAssertEqual(run.token, newToken)
        XCTAssertEqual(run.measurement(for: after, currentProjectID: project)?.meanLuminance, 0.9)
        XCTAssertFalse(run.accept(matching(after, luminance: 0.1), measuredFor: after, current: after,
                                  token: oldToken, currentProjectID: project, isProjectAvailable: true))
        XCTAssertEqual(run.measurement(for: after, currentProjectID: project)?.meanLuminance, 0.9)
    }
}
