import XCTest
@testable import MomentsStudio

/// The deterministic Stage 06 policy: manual priority, one primary, exact label
/// handling, finite data, failure fallback, stable ties and the Automatic reset.
///
/// These are the real value-model inputs the sheet feeds the policy, including the
/// distinction between "the pixel measurement really succeeded (maybe a limited
/// sample)" and "the sample was adequate".
final class Stage06RolePolicyTests: XCTestCase {
    private func candidate(
        _ id: UUID,
        index: Int,
        manual: PhotoRole? = nil,
        sceneScore: Double = 0,
        analysisSucceeded: Bool = true,
        adequateSample: Bool = true,
        pixelArea: Int = 1_000
    ) -> PhotoRolePolicy.Candidate {
        PhotoRolePolicy.Candidate(
            assetID: id,
            importIndex: index,
            manualRole: manual,
            sceneScore: sceneScore,
            analysisSucceeded: analysisSucceeded,
            adequateSample: adequateSample,
            pixelArea: pixelArea
        )
    }

    /// Convenience reader for tests that only care about the *value*.
    ///
    /// The fallback is **not** an existence check: `outcome.suggestions[id] ?? X`
    /// returns the same value for "the dictionary holds `X`" and "the key is absent",
    /// so this helper proves nothing about whether the policy actually stored a
    /// `Suggestion.none` entry. Tests that need that distinction assert on the raw
    /// subscript (see `testManualNonParticipatingPhotosAreNeverAutoAssigned`).
    private func role(_ outcome: PhotoRolePolicy.Outcome, _ id: UUID) -> PhotoRolePolicy.Suggestion {
        outcome.suggestions[id] ?? PhotoRolePolicy.Suggestion.none
    }

    // MARK: - One primary

    func testChoosesExactlyOnePrimaryAndSupportsTheRest() {
        let ids = (0..<4).map { _ in UUID() }
        let outcome = PhotoRolePolicy.suggest([
            candidate(ids[0], index: 0, sceneScore: 0.2),
            candidate(ids[1], index: 1, sceneScore: 0.9),
            candidate(ids[2], index: 2, sceneScore: 0.6),
            candidate(ids[3], index: 3, sceneScore: 0.0)
        ])
        let roles = ids.compactMap { role(outcome, $0).role }
        XCTAssertEqual(roles.filter { $0 == .primary }.count, 1)
        XCTAssertEqual(role(outcome, ids[1]), .role(.primary), "the strongest scene evidence leads")
        XCTAssertEqual(role(outcome, ids[2]), .role(.supporting))
        XCTAssertEqual(role(outcome, ids[0]), .role(.supporting))
    }

    func testManualPrimaryFreezesThePrimarySlotForEveryOtherPhoto() {
        let ids = (0..<3).map { _ in UUID() }
        let outcome = PhotoRolePolicy.suggest([
            candidate(ids[0], index: 0, sceneScore: 0.95),
            candidate(ids[1], index: 1, manual: .primary, sceneScore: 0.1),
            candidate(ids[2], index: 2, sceneScore: 0.7)
        ])
        XCTAssertEqual(role(outcome, ids[1]), .role(.primary))
        XCTAssertEqual(role(outcome, ids[0]), .role(.supporting))
        XCTAssertEqual(role(outcome, ids[2]), .role(.supporting))
    }

    func testManualNonParticipatingPhotosAreNeverAutoAssigned() {
        let excluded = UUID()
        let collage = UUID()
        let plain = UUID()
        let outcome = PhotoRolePolicy.suggest([
            candidate(excluded, index: 0, manual: .excluded, sceneScore: 0.99),
            candidate(collage, index: 1, manual: .collageMaterial, sceneScore: 0.99),
            candidate(plain, index: 2, sceneScore: 0.6)
        ])
        XCTAssertEqual(role(outcome, excluded), PhotoRolePolicy.Suggestion.none)
        XCTAssertEqual(role(outcome, collage), PhotoRolePolicy.Suggestion.none)
        XCTAssertEqual(role(outcome, plain), .role(.primary))

        // The two assertions above read through a helper that falls back to the same
        // value, so they cannot tell "stored Suggestion.none" from "key missing".
        // The raw subscripts pin the real dictionary semantics: the policy stores the
        // `Suggestion.none` **value** for a manually excluded/collage photo (rather
        // than dropping the key, which the ambiguous `.none` spelling would have done).
        XCTAssertEqual(outcome.suggestions[excluded], .some(PhotoRolePolicy.Suggestion.none),
                       "a non-participating photo must carry an explicit Suggestion.none entry")
        XCTAssertEqual(outcome.suggestions[collage], .some(PhotoRolePolicy.Suggestion.none),
                       "a collage-material photo must carry an explicit Suggestion.none entry")
    }

    // MARK: - Limited but successful sampling

    func testLimitedSuccessfulSampleIsARealCandidateAndNeverReportedAsFailure() {
        let ids = (0..<2).map { _ in UUID() }
        let outcome = PhotoRolePolicy.suggest([
            candidate(ids[0], index: 0, sceneScore: 0, analysisSucceeded: true, adequateSample: false),
            candidate(ids[1], index: 1, sceneScore: 0, analysisSucceeded: true, adequateSample: true)
        ])
        // Both are real successes; the adequate sample only wins the tie-break.
        XCTAssertEqual(role(outcome, ids[1]), .role(.primary))
        XCTAssertEqual(role(outcome, ids[0]), .role(.supporting))
        XCTAssertNotEqual(role(outcome, ids[0]), .failed)
    }

    func testOnlyWhenBothMeasurementAndSemanticsFailIsThereNoSuggestion() {
        let bothFailed = UUID()
        let semanticsOnly = UUID()
        let measurementOnly = UUID()
        let outcome = PhotoRolePolicy.suggest([
            candidate(bothFailed, index: 0, sceneScore: 0, analysisSucceeded: false, adequateSample: false),
            candidate(semanticsOnly, index: 1, sceneScore: 0.8, analysisSucceeded: false, adequateSample: false),
            candidate(measurementOnly, index: 2, sceneScore: 0, analysisSucceeded: true, adequateSample: false)
        ])
        XCTAssertEqual(role(outcome, bothFailed), .failed)
        XCTAssertTrue(role(outcome, semanticsOnly).role != nil)
        XCTAssertTrue(role(outcome, measurementOnly).role != nil)
    }

    func testTransparentPhotoWithoutAnalysisGetsNoSuggestionAndKeepsAManualChoice() {
        let transparent = UUID()
        let manual = UUID()
        let outcome = PhotoRolePolicy.suggest([
            candidate(transparent, index: 0, sceneScore: 0, analysisSucceeded: false, adequateSample: false),
            candidate(manual, index: 1, manual: .primary, sceneScore: 0, analysisSucceeded: false)
        ])
        XCTAssertEqual(role(outcome, transparent), .failed)
        XCTAssertEqual(role(outcome, manual), .role(.primary), "a manual choice survives a failed observation")
    }

    // MARK: - Score hygiene

    func testNonFiniteAndOutOfRangeScoresAreDiscardedNotClamped() {
        let ids = (0..<3).map { _ in UUID() }
        let outcome = PhotoRolePolicy.suggest([
            candidate(ids[0], index: 0, sceneScore: .nan),
            candidate(ids[1], index: 1, sceneScore: .infinity),
            candidate(ids[2], index: 2, sceneScore: 4.2)
        ])
        // None of these may act as strong evidence: the ranking sees 0 for all of
        // them, so the stable fallback decides.
        XCTAssertEqual(role(outcome, ids[0]), .role(.primary))
        XCTAssertEqual(role(outcome, ids[1]), .role(.supporting))
        XCTAssertEqual(role(outcome, ids[2]), .role(.supporting))
    }

    // MARK: - Stable order

    func testTiesFallBackToAreaThenImportOrder() {
        let small = UUID()
        let large = UUID()
        let outcome = PhotoRolePolicy.suggest([
            candidate(small, index: 0, sceneScore: 0.6, pixelArea: 100),
            candidate(large, index: 1, sceneScore: 0.6, pixelArea: 900)
        ])
        XCTAssertEqual(role(outcome, large), .role(.primary), "the larger corrected photo wins an equal score")

        let first = UUID()
        let second = UUID()
        let equalTie = PhotoRolePolicy.suggest([
            candidate(first, index: 0, sceneScore: 0.6, pixelArea: 500),
            candidate(second, index: 1, sceneScore: 0.6, pixelArea: 500)
        ])
        XCTAssertEqual(role(equalTie, first), .role(.primary), "the earlier import stays first")
    }

    // MARK: - Materialised choices

    func testSaveWritesManualAutomaticAndClearsWhatHasNoChoice() {
        let manualPrimary = UUID()
        let autoPhoto = UUID()
        let failure = UUID()
        let candidates = [
            candidate(manualPrimary, index: 0, manual: .primary),
            candidate(autoPhoto, index: 1, sceneScore: 0.6),
            candidate(failure, index: 2, sceneScore: 0, analysisSucceeded: false, adequateSample: false)
        ]
        let outcome = PhotoRolePolicy.suggest(candidates)
        let choices = PhotoRolePolicy.choices(
            candidates: candidates,
            draft: [manualPrimary: .role(.primary)],
            capturedRoles: [:],
            outcome: outcome
        )
        XCTAssertEqual(choices[manualPrimary], .manual(.primary))
        XCTAssertEqual(choices[autoPhoto], .automatic(.supporting))
        XCTAssertNil(choices[failure], "no usable choice is absent, which clears any stored value")
    }

    func testAutomaticDraftClearsAStoredChoiceWhenTheNewPassHasNoEvidence() {
        let photo = UUID()
        let candidates = [
            candidate(photo, index: 0, sceneScore: 0, analysisSucceeded: false, adequateSample: false)
        ]
        let choices = PhotoRolePolicy.choices(
            candidates: candidates,
            draft: [photo: .automatic],
            capturedRoles: [photo: .manual(.collageMaterial)],
            outcome: PhotoRolePolicy.suggest(candidates)
        )
        XCTAssertTrue(choices.isEmpty, "explicit Automatic clears, never 'leave the old choice alone'")
    }

    /// An untouched captured value is kept only when it is the user's own manual
    /// choice; a captured `automatic` role is recomputed and refreshed by this pass.
    func testUntouchedCapturedChoiceIsKeptOnlyWhenItWasManual() {
        let manual = UUID()
        let automatic = UUID()
        // `manual` is a saved manual supporting photo (no primary anywhere), and
        // `automatic` is a saved automatic supporting photo whose stored choice does
        // **not** constrain this pass: it has real scene evidence, so the automatic
        // suggestion legitimately promotes it to primary. The captured dictionary
        // therefore describes an already-valid package (no primary, no duplicates),
        // and the outcome comes from `suggest(...)` — not from a hand-made outcome.
        let candidates = [
            candidate(manual, index: 0, manual: .supporting, sceneScore: 0.2),
            candidate(automatic, index: 1, sceneScore: 0.9)
        ]
        let outcome = PhotoRolePolicy.suggest(candidates)
        XCTAssertEqual(role(outcome, automatic), .role(.primary),
                       "the photo with the strongest evidence is the automatic primary")
        XCTAssertEqual(role(outcome, manual), .role(.supporting))

        let captured: [UUID: PhotoRoleChoice?] = [
            manual: .manual(.supporting),
            automatic: .automatic(.supporting)
        ]
        // The captured package is legal: at most one primary (none here).
        XCTAssertEqual(captured.values.filter { $0?.role == .primary }.count, 0,
                       "the fixture must not pretend to hold two primaries")

        let choices = PhotoRolePolicy.choices(
            candidates: candidates,
            draft: [:],
            capturedRoles: captured,
            outcome: outcome
        )
        XCTAssertEqual(choices[manual], .manual(.supporting),
                       "a captured manual choice keeps its role and its manual source")
        XCTAssertEqual(choices[automatic], .automatic(.primary),
                       "a captured automatic role is refreshed by this pass, not frozen")
    }

    // MARK: - Layout integration

    func testOnlyFocusMovesThePrimaryPhotoAndOnlyItsFirstLayer() {
        let primaryAsset = UUID()
        let other = UUID()
        let third = UUID()
        func layer(_ id: UUID, _ asset: UUID) -> Layer {
            Layer(
                id: id,
                kind: .photo,
                transform: .identity,
                assetID: asset,
                baseSize: CanvasSize(width: 100, height: 80)
            )
        }
        let first = layer(UUID(), other)
        let primaryOne = layer(UUID(), primaryAsset)
        let middle = layer(UUID(), third)
        let primaryTwo = layer(UUID(), primaryAsset)

        let original = [first, primaryOne, middle, primaryTwo]
        let focus = PhotoRoleLayoutPlan.arrangementOrder(
            original, preset: .focus, primaryAssetID: primaryAsset
        )
        XCTAssertEqual(focus.map(\.id), [primaryOne.id, first.id, middle.id, primaryTwo.id],
                       "only the primary asset's FIRST layer takes the hero slot; every other layer keeps"
                       + " its original relative order, including the primary asset's later layers")
        XCTAssertEqual(Set(focus.map(\.id)), Set(original.map(\.id)), "no layer is dropped or duplicated")

        for preset in [CollagePreset.grid, .offset] {
            let unchanged = PhotoRoleLayoutPlan.arrangementOrder(
                original, preset: preset, primaryAssetID: primaryAsset
            )
            XCTAssertEqual(unchanged.map(\.id), original.map(\.id),
                           "\(preset.rawValue) keeps the frozen Stage 04 order")
        }
    }

    /// The same rule through the real layout engine: a saved primary changes which
    /// cell its first layer is computed into, and nothing else about the document —
    /// stored order, z-order, identities, base sizes, protected layers — moves.
    func testArrangeFocusKeepsStoredOrderAndDocumentIdentityWithMultipleLayersPerAsset() throws {
        let primaryAsset = UUID()
        let otherAsset = UUID()
        func photo(_ assetID: UUID, width: Int = 1200, height: Int = 800) -> ImportedPhoto {
            ImportedPhoto(
                asset: Asset(id: assetID, kind: .photo, localReference: "original-\(assetID).jpg"),
                thumbnailReference: "thumb-\(assetID).jpg",
                previewReference: "preview-\(assetID).jpg",
                pixelWidth: width, pixelHeight: height, orientation: 1, contentType: "public.jpeg",
                roleChoice: assetID == primaryAsset ? .manual(.primary) : nil
            )
        }
        let photos = [photo(otherAsset), photo(primaryAsset)]

        // Three layers: other, primary (first layer), primary (second layer, hidden).
        let baseSize = CanvasSize(width: 200, height: 150)
        var document = try CanvasEditor.addingLayer(assetID: otherAsset, baseSize: baseSize, to: .empty)
        let otherLayerID = try XCTUnwrap(document.layers.last?.id)
        document = try CanvasEditor.addingLayer(assetID: primaryAsset, baseSize: baseSize, to: document)
        let firstPrimaryLayerID = try XCTUnwrap(document.layers.last?.id)
        document = try CanvasEditor.addingLayer(assetID: primaryAsset, baseSize: baseSize, to: document)
        let secondPrimaryLayerID = try XCTUnwrap(document.layers.last?.id)
        document = try CanvasEditor.settingHidden(true, forLayerID: secondPrimaryLayerID, in: document)
        let storedOrderBefore = document.layers.map(\.id)
        let zOrderBefore = document.layers.map(\.zIndex)

        let result = try CollageLayout.arrange(.focus, document: document, photos: photos)

        XCTAssertEqual(result.id, document.id)
        XCTAssertEqual(result.layers.map(\.id), storedOrderBefore, "stored layer order never changes")
        XCTAssertEqual(result.layers.map(\.zIndex), zOrderBefore, "z-order never changes")
        XCTAssertEqual(result.layers.map(\.assetID), document.layers.map(\.assetID))
        XCTAssertTrue(result.layers.first { $0.id == secondPrimaryLayerID }?.isHidden ?? false,
                      "a hidden layer stays hidden and keeps its stored position")

        // The primary asset's first movable layer is computed into the hero cell: it
        // is the topmost cell, so its centre sits above the other photo's.
        let heroTransform = try XCTUnwrap(result.layers.first { $0.id == firstPrimaryLayerID }?.transform)
        let otherTransform = try XCTUnwrap(result.layers.first { $0.id == otherLayerID }?.transform)
        XCTAssertLessThan(heroTransform.translationY, otherTransform.translationY,
                          "Focus puts the saved primary's first layer in the hero cell")
        // Applying the same preset again is stable: preview and Apply share the plan,
        // so a repeat never adds, drops or reshapes a layer.
        XCTAssertEqual(try CollageLayout.arrange(.focus, document: result, photos: photos), result)
    }

    func testParticipatingPhotosExcludeOnlySavedNonParticipatingRoles() {
        let plain = ImportedPhoto.fixture(roleChoice: nil)
        let primary = ImportedPhoto.fixture(roleChoice: .manual(.primary))
        let supporting = ImportedPhoto.fixture(roleChoice: .automatic(.supporting))
        let collage = ImportedPhoto.fixture(roleChoice: .manual(.collageMaterial))
        let excluded = ImportedPhoto.fixture(roleChoice: .manual(.excluded))

        let participating = PhotoRoleLayoutPlan.participatingPhotoIDs([plain, primary, supporting, collage, excluded])
        XCTAssertEqual(participating, Set([plain.id, primary.id, supporting.id]))
        XCTAssertEqual(PhotoRoleLayoutPlan.primaryPhotoID([plain, primary, supporting]), primary.id)
        XCTAssertNil(PhotoRoleLayoutPlan.primaryPhotoID([plain, supporting]))
        XCTAssertTrue(PhotoRoleLayoutPlan.hasNoLayoutParticipant([collage, excluded]))
        XCTAssertFalse(PhotoRoleLayoutPlan.hasNoLayoutParticipant([plain]))
    }

    // MARK: - Real arrange coverage

    /// A project whose photos are all complete (no saved roles) arranges exactly as it
    /// did before Stage 06, and adding a saved role must not change Grid or Offset:
    /// only Focus reads the primary.
    func testNilRolesKeepTheFrozenStage04Arrangement() throws {
        let first = UUID()
        let second = UUID()
        let plain = [
            ImportedPhoto.fixture(roleChoice: nil, assetID: first, width: 1200, height: 800),
            ImportedPhoto.fixture(roleChoice: nil, assetID: second, width: 800, height: 1200)
        ]
        let decided = [
            ImportedPhoto.fixture(roleChoice: .manual(.supporting), assetID: first, width: 1200, height: 800),
            ImportedPhoto.fixture(roleChoice: .manual(.primary), assetID: second, width: 800, height: 1200)
        ]
        let empty = CanvasDocument.empty

        for preset in [CollagePreset.grid, .offset] {
            XCTAssertEqual(
                try CollageLayout.arrange(preset, document: empty, photos: decided),
                try CollageLayout.arrange(preset, document: empty, photos: plain),
                "\(preset.rawValue) must compute the same layout with or without saved roles"
            )
        }

        let focus = try CollageLayout.arrange(.focus, document: empty, photos: decided)
        XCTAssertEqual(focus.layers.map(\.id), [first, second],
                       "an empty canvas creates one layer per participating photo, in the array order")
        // Layer storage order is the photo array order, so the hero has to be proven by
        // the computed transform, not by the stored order.
        let primaryTransform = try XCTUnwrap(focus.layers.first { $0.id == second }?.transform)
        let otherTransform = try XCTUnwrap(focus.layers.first { $0.id == first }?.transform)
        XCTAssertLessThan(primaryTransform.translationY, otherTransform.translationY,
                          "the saved primary takes the hero cell")
        XCTAssertNotEqual(primaryTransform.scale, otherTransform.scale)
    }

    /// An empty canvas only ever creates layers for participating photos: collage
    /// material and "not for layout" photos stay in the library.
    func testEmptyCanvasOnlyAddsParticipatingPhotos() throws {
        let plain = ImportedPhoto.fixture(roleChoice: nil)
        let primary = ImportedPhoto.fixture(roleChoice: .manual(.primary))
        let collage = ImportedPhoto.fixture(roleChoice: .manual(.collageMaterial))
        let excluded = ImportedPhoto.fixture(roleChoice: .manual(.excluded))

        let result = try CollageLayout.arrange(.grid, document: .empty, photos: [plain, primary, collage, excluded])
        XCTAssertEqual(Set(result.layers.compactMap(\.assetID)), Set([plain.id, primary.id]),
                       "collage material and not-for-layout photos must not be added to an empty canvas")
        XCTAssertEqual(result.layers.count, 2)
        XCTAssertFalse(result.layers.contains { $0.assetID == collage.id })
        XCTAssertFalse(result.layers.contains { $0.assetID == excluded.id })
    }

    /// Every photo saved as collage material / not for layout is a **role** problem:
    /// the error must say so instead of telling the user to import photos.
    func testAllNonParticipatingPhotosReportARoleProblem() throws {
        let collage = ImportedPhoto.fixture(roleChoice: .manual(.collageMaterial))
        let excluded = ImportedPhoto.fixture(roleChoice: .manual(.excluded))
        let photos = [collage, excluded]

        XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: .empty, photos: photos)) { error in
            XCTAssertEqual(error as? CollageLayoutError, .noEligiblePhotos)
            let text = (error as? CollageLayoutError)?.errorDescription ?? ""
            XCTAssertTrue(text.contains("Photo roles"), "the message must point at roles: \(text)")
            XCTAssertFalse(text.contains("Import photos"), "the user already has photos: \(text)")
        }
        // With no photos at all the original "import photos" guidance still applies.
        XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: .empty, photos: [])) { error in
            XCTAssertEqual(error as? CollageLayoutError, .noPhotos)
        }
        // A canvas that already holds only non-participating layers is the same role
        // problem, not "nothing editable".
        let existing = try CanvasEditor.addingLayer(
            assetID: collage.id, baseSize: CanvasSize(width: 200, height: 150), to: .empty
        )
        XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: existing, photos: photos)) { error in
            XCTAssertEqual(error as? CollageLayoutError, .noEligiblePhotos)
        }
    }

    /// Existing protected or non-participating layers keep their complete transform,
    /// identity, stored order, z-order, base size and opacity, while participating
    /// layers are arranged around them.
    func testExistingProtectedAndNonParticipatingLayersAreUntouched() throws {
        let plain = ImportedPhoto.fixture(roleChoice: nil)
        let collage = ImportedPhoto.fixture(roleChoice: .manual(.collageMaterial))
        let photos = [plain, collage]

        // A canvas with: a non-participating collage layer, a locked complete layer and
        // one editable participating layer. Layer identities come from the real
        // production editor (`CanvasEditor.addingLayer` generates them).
        var document = try CanvasEditor.addingLayer(
            assetID: collage.id, baseSize: CanvasSize(width: 210, height: 160), to: .empty
        )
        document.layers[0].transform = LayerTransform(translationX: 11, translationY: 22, scale: 0.4, rotationRadians: 0.2)
        document.layers[0].setOpacity(0.6)
        let collageLayerBefore = document.layers[0]

        document = try CanvasEditor.addingLayer(
            assetID: plain.id, baseSize: CanvasSize(width: 200, height: 150), to: document
        )
        document = try CanvasEditor.settingLocked(true, forLayerID: document.layers[1].id, in: document)
        let lockedLayerBefore = document.layers[1]

        // A second, editable layer bound to the same participating photo.
        document = try CanvasEditor.addingLayer(
            assetID: plain.id, baseSize: CanvasSize(width: 180, height: 120), to: document
        )
        let storedOrderBefore = document.layers.map(\.id)
        let zOrderBefore = document.layers.map(\.zIndex)

        let result = try CollageLayout.arrange(.focus, document: document, photos: photos)

        XCTAssertEqual(result.layers.map(\.id), storedOrderBefore)
        XCTAssertEqual(result.layers.map(\.zIndex), zOrderBefore)
        XCTAssertEqual(result.layers[0], collageLayerBefore, "a non-participating layer keeps its whole value")
        XCTAssertEqual(result.layers[1], lockedLayerBefore, "a locked layer keeps its whole value")
        XCTAssertNotEqual(result.layers[2].transform, document.layers[2].transform,
                          "the editable participating layer was arranged")
    }

    /// Repeated Apply of the same preset is stable, and a second preset only changes
    /// transforms: the layer set, order and identities never move.
    func testRepeatedApplyOfTheSamePresetIsStable() throws {
        let primary = ImportedPhoto.fixture(roleChoice: .manual(.primary))
        let supporting = ImportedPhoto.fixture(roleChoice: .automatic(.supporting))
        let photos = [supporting, primary]

        let once = try CollageLayout.arrange(.focus, document: .empty, photos: photos)
        let twice = try CollageLayout.arrange(.focus, document: once, photos: photos)
        XCTAssertEqual(twice, once, "applying Focus twice must be byte-identical")
        let grid = try CollageLayout.arrange(.grid, document: twice, photos: photos)
        XCTAssertEqual(grid.layers.map(\.id), once.layers.map(\.id))
        XCTAssertEqual(grid.layers.map(\.zIndex), once.layers.map(\.zIndex))
        XCTAssertEqual(grid.layers.map(\.baseSize), once.layers.map(\.baseSize))
        XCTAssertEqual(grid.layers.map(\.opacity), once.layers.map(\.opacity))
    }
}

extension ImportedPhoto {
    /// A metadata-only photo used by the value-model tests.
    static func fixture(
        roleChoice: PhotoRoleChoice?,
        assetID: UUID = UUID(),
        width: Int = 320,
        height: Int = 240
    ) -> ImportedPhoto {
        let projectID = UUID()
        return ImportedPhoto(
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
            orientation: 1,
            contentType: "public.jpeg",
            roleChoice: roleChoice
        )
    }
}
