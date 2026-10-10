import XCTest
import UniformTypeIdentifiers
@testable import MomentsStudio

/// The real guard the Photo roles sheet writes and reads through.
///
/// Every acceptance case below is expressed with the same `ImportedPhoto` values the
/// sheet uses, so a stale observation, a changed saved choice or unusable dimensions
/// are refused by the code that actually runs in the app — not by a test-only path.
final class Stage06RolesRunTests: XCTestCase {
    private let projectID = UUID()

    private func photo(
        assetID: UUID = UUID(),
        width: Int = 320,
        height: Int = 240,
        orientation: Int = 1,
        roleChoice: PhotoRoleChoice? = nil
    ) -> ImportedPhoto {
        ImportedPhoto(
            asset: Asset(
                id: assetID,
                kind: .photo,
                localReference: PhotoLibraryPath.originalReference(projectID, assetID: assetID, fileExtension: "jpg")
            ),
            thumbnailReference: PhotoLibraryPath.derivativeReference(
                .thumbnail, projectID: projectID, assetID: assetID, fileExtension: "jpg"
            ),
            previewReference: PhotoLibraryPath.derivativeReference(
                .preview, projectID: projectID, assetID: assetID, fileExtension: "jpg"
            ),
            pixelWidth: width,
            pixelHeight: height,
            orientation: orientation,
            contentType: "public.jpeg",
            roleChoice: roleChoice
        )
    }

    private func observation(
        of photo: ImportedPhoto,
        analysis: PhotoAnalysis? = nil,
        sceneScore: Double = 0
    ) -> PhotoRoleObservation {
        let display = photo.displayPixelSize
        return PhotoRoleObservation(
            assetID: photo.id,
            displayWidth: display.width,
            displayHeight: display.height,
            classifyRevision: 1,
            faceRevision: 3,
            classificationRan: true,
            skippedPixelMeasurement: false,
            supportedNaturalSceneIdentifiers: [],
            sceneScore: sceneScore,
            faceCount: 0,
            analysis: analysis,
            analysisFailure: nil
        )
    }

    private func analysis(
        assetID: UUID,
        width: Int,
        height: Int,
        confidence: PhotoAnalysisConfidence
    ) -> PhotoAnalysis {
        PhotoAnalysis(
            assetID: assetID,
            displayWidth: width,
            displayHeight: height,
            sampleWidth: 64,
            sampleHeight: 48,
            validPixelCount: confidence == .adequate ? 512 : 32,
            meanRed: 0.5, meanGreen: 0.5, meanBlue: 0.5,
            meanLuminance: 0.5, luminanceContrast: 0.1, meanSaturation: 0.2,
            darkPixelRatio: 0, brightPixelRatio: 0,
            coverage: confidence == .adequate ? 0.9 : 0.4,
            confidence: confidence
        )
    }

    // MARK: - Signatures include the saved choice

    func testSignatureChangesWhenTheSavedChoiceChanges() {
        let assetID = UUID()
        let none = photo(assetID: assetID, roleChoice: nil)
        let manualPrimary = photo(assetID: assetID, roleChoice: .manual(.primary))
        let automaticPrimary = photo(assetID: assetID, roleChoice: .automatic(.primary))

        let signatures = Set([
            PhotoRolesRun.signature(of: none),
            PhotoRolesRun.signature(of: manualPrimary),
            PhotoRolesRun.signature(of: automaticPrimary)
        ])
        XCTAssertEqual(signatures.count, 3, "role, source and no-choice must all be distinguishable")
        XCTAssertEqual(PhotoRolesRun.signature(of: none), PhotoRolesRun.signature(of: photo(assetID: assetID)))
        // The run guard and the save request use the **same** signature, so a display
        // decision and a staleness decision can never disagree.
        XCTAssertEqual(PhotoRolesRun.signature(of: manualPrimary), PhotoLibrary.roleSnapshot(of: manualPrimary))
    }

    func testObservationIsRefusedWhenOnlyTheSavedRoleChoiceChanged() {
        let assetID = UUID()
        let captured = photo(assetID: assetID, roleChoice: .manual(.primary))
        var run = PhotoRolesRun(projectID: projectID)
        let token = run.token

        // Same metadata and same asset: only the saved role changed (e.g. the user
        // saved Automatic in another sheet). The observation must not be shown.
        let changed = photo(assetID: assetID, roleChoice: .automatic(.supporting))
        XCTAssertFalse(run.accept(
            observation(of: captured), observedFor: captured, current: changed,
            token: token, currentProjectID: projectID, isProjectAvailable: true
        ))
        XCTAssertNil(run.observation(for: changed, currentProjectID: projectID))
        XCTAssertNotEqual(PhotoRolesRun.signature(of: captured), PhotoRolesRun.signature(of: changed))
    }

    func testObservationIsRefusedWhenTheSavedChoiceChangedUnderIt() {
        let assetID = UUID()
        let captured = photo(assetID: assetID, roleChoice: .manual(.primary))
        var run = PhotoRolesRun(projectID: projectID)
        let token = run.token

        // Another save changed this photo's stored choice while the pass ran.
        let changed = photo(assetID: assetID, roleChoice: .manual(.excluded))
        XCTAssertFalse(run.accept(
            observation(of: captured), observedFor: captured, current: changed,
            token: token, currentProjectID: projectID, isProjectAvailable: true
        ))
        XCTAssertNil(run.observation(for: changed, currentProjectID: projectID))
    }

    func testObservationIsRefusedForAnotherProjectOrPhotoAndAcceptedWhenCurrent() {
        let assetID = UUID()
        let current = photo(assetID: assetID)
        var run = PhotoRolesRun(projectID: projectID)
        let token = run.token
        let value = observation(of: current)

        XCTAssertFalse(run.accept(value, observedFor: current, current: nil,
                                  token: token, currentProjectID: projectID, isProjectAvailable: true))
        XCTAssertFalse(run.accept(value, observedFor: current, current: current,
                                  token: token, currentProjectID: UUID(), isProjectAvailable: true))
        XCTAssertFalse(run.accept(value, observedFor: current, current: current,
                                  token: token, currentProjectID: projectID, isProjectAvailable: false))
        XCTAssertFalse(run.accept(value, observedFor: current, current: current,
                                  token: UUID(), currentProjectID: projectID, isProjectAvailable: true))
        XCTAssertTrue(run.accept(value, observedFor: current, current: current,
                                 token: token, currentProjectID: projectID, isProjectAvailable: true))
        XCTAssertEqual(run.observation(for: current, currentProjectID: projectID), value)
    }

    func testObservationForAnotherAssetOrDisplaySizeIsRefused() {
        let assetID = UUID()
        let current = photo(assetID: assetID, width: 320, height: 240)
        var run = PhotoRolesRun(projectID: projectID)
        let token = run.token

        let wrongSize = PhotoRoleObservation(
            assetID: assetID, displayWidth: 240, displayHeight: 320,
            classifyRevision: 1, faceRevision: 1, classificationRan: true,
            skippedPixelMeasurement: false, supportedNaturalSceneIdentifiers: [],
            sceneScore: 0, faceCount: 0, analysis: nil, analysisFailure: nil
        )
        XCTAssertFalse(run.accept(wrongSize, observedFor: current, current: current,
                                  token: token, currentProjectID: projectID, isProjectAvailable: true))

        let wrongAsset = observation(of: photo())
        XCTAssertFalse(run.accept(wrongAsset, observedFor: current, current: current,
                                  token: token, currentProjectID: projectID, isProjectAvailable: true))
    }

    func testInvalidateDropsValuesAndRefusesTheOldToken() {
        let assetID = UUID()
        let current = photo(assetID: assetID)
        var run = PhotoRolesRun(projectID: projectID)
        let token = run.token
        XCTAssertTrue(run.accept(observation(of: current), observedFor: current, current: current,
                                 token: token, currentProjectID: projectID, isProjectAvailable: true))

        let rotated = run.invalidate()
        XCTAssertNotEqual(rotated, token)
        XCTAssertNil(run.observation(for: current, currentProjectID: projectID))
        XCTAssertFalse(run.accept(observation(of: current), observedFor: current, current: current,
                                  token: token, currentProjectID: projectID, isProjectAvailable: true))
    }

    func testRolesBeginRequestOnlyStartsForTheCurrentKeyAndSheet() {
        var run = PhotoRolesRun(projectID: projectID)
        XCTAssertNil(run.beginRequest(taskKey: "old", currentTaskKey: "new", isSheetCurrent: true))
        XCTAssertNil(run.beginRequest(taskKey: "new", currentTaskKey: "new", isSheetCurrent: false))
        XCTAssertNotNil(run.beginRequest(taskKey: "new", currentTaskKey: "new", isSheetCurrent: true))
    }

    // MARK: - Candidates

    func testCandidateUsesAreaAndSeparatesSuccessFromAdequacy() throws {
        let assetID = UUID()
        let current = photo(assetID: assetID, width: 400, height: 300)
        var run = PhotoRolesRun(projectID: projectID)
        let token = run.token
        let limited = analysis(assetID: assetID, width: 400, height: 300, confidence: .limited)
        XCTAssertTrue(run.accept(
            observation(of: current, analysis: limited, sceneScore: 0.9),
            observedFor: current, current: current,
            token: token, currentProjectID: projectID, isProjectAvailable: true
        ))

        let candidate = try XCTUnwrap(run.candidate(
            for: current, importIndex: 0, manualRole: nil, sceneScore: 0.9
        ))
        XCTAssertEqual(candidate.pixelArea, 120_000)
        XCTAssertTrue(candidate.analysisSucceeded, "a limited sample is still a real success")
        XCTAssertFalse(candidate.adequateSample)
        XCTAssertEqual(candidate.sceneScore, 0.9)
    }

    func testCandidateIsNilForUnusableOrOverflowingDimensions() {
        let tiny = photo(width: 0, height: 240)
        let negative = photo(width: 320, height: -1)
        let overflow = photo(width: Int.max, height: 2)
        var run = PhotoRolesRun(projectID: projectID)

        for broken in [tiny, negative, overflow] {
            XCTAssertNil(run.candidate(for: broken, importIndex: 0, manualRole: nil, sceneScore: 0.9),
                         "\(broken.displayPixelSize) must not become a candidate")
            XCTAssertNil(PhotoRolesRun.pixelArea(of: broken))
        }
        XCTAssertEqual(PhotoRolesRun.pixelArea(of: photo(width: 320, height: 240)), 76_800)
    }

    /// A photo whose metadata cannot produce an area is not even a policy candidate,
    /// so a damaged record can never win the primary slot.
    func testDamagedMetadataYieldsNoCandidateAndThePolicyKeepsWorking() {
        let good = photo(width: 320, height: 240)
        let damaged = photo(width: Int.max, height: Int.max)
        var run = PhotoRolesRun(projectID: projectID)
        let candidates = [good, damaged].enumerated().compactMap { index, photo in
            run.candidate(for: photo, importIndex: index, manualRole: nil, sceneScore: 0.6)
        }
        XCTAssertEqual(candidates.count, 1)
        let outcome = PhotoRolePolicy.suggest(candidates)
        XCTAssertEqual(outcome.suggestions[good.id], .role(.primary))
        XCTAssertNil(outcome.suggestions[damaged.id])
        _ = run.invalidate()
    }
}
