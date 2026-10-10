import XCTest
import UniformTypeIdentifiers
@testable import MomentsStudio

/// Real files, the real library actor and the real save bridge for Stage 06.
///
/// Nothing here mocks storage: each case imports synthetic fixtures through the
/// production pipeline, saves roles through the production commit path, and then
/// checks the manifest, the asset bytes and the store. The stale-draft and
/// complete-batch rules are exercised against the real package on disk.
final class Stage06RoleStorageTests: XCTestCase {
    private var baseURL: URL!
    private var rootURL: URL!

    override func setUpWithError() throws {
        baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        rootURL = baseURL.appendingPathComponent("Library", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let baseURL { try? FileManager.default.removeItem(at: baseURL) }
    }

    private func manifest(_ id: UUID) -> URL {
        rootURL.appendingPathComponent(PhotoLibraryPath.manifestReference(id))
    }

    /// Imports two synthetic photos through the production pipeline.
    private func makePackage(_ library: PhotoLibrary, name: String = "Roles") async throws -> ProjectPackage {
        var package = ProjectPackage(project: Project(name: name), photos: [])
        for (index, size) in [(320, 240), (240, 320)].enumerated() {
            let fixture = try SyntheticImageFactory.writeFixture(
                in: baseURL.appendingPathComponent("fixtures", isDirectory: true),
                name: "\(UUID().uuidString)-\(index).jpg",
                width: size.0,
                height: size.1
            )
            let staged = try await PhotoFileTransfer.stageCopy(of: fixture, rootURL: rootURL)
            package = try await library.importPhoto(fileURL: staged, into: package, at: Date()).package
        }
        return package
    }

    private func roles(_ package: ProjectPackage) -> [UUID: PhotoRoleChoice?] {
        Dictionary(uniqueKeysWithValues: package.photos.map { ($0.id, $0.roleChoice) })
    }

    /// Imports one extra synthetic photo into an existing package through the same
    /// production path, so a stale snapshot can be tested against a grown package.
    private func addPhoto(_ library: PhotoLibrary, to package: ProjectPackage) async throws -> ProjectPackage {
        let fixture = try SyntheticImageFactory.writeFixture(
            in: baseURL.appendingPathComponent("fixtures", isDirectory: true),
            name: "\(UUID().uuidString)-extra.jpg", width: 300, height: 200
        )
        let staged = try await PhotoFileTransfer.stageCopy(of: fixture, rootURL: rootURL)
        return try await library.importPhoto(fileURL: staged, into: package, at: Date()).package
    }

    private func bytes(_ urls: [URL]) throws -> [Data] {
        try urls.map { try Data(contentsOf: $0) }
    }

    @MainActor
    private func makeModel(_ library: PhotoLibrary) async throws -> (PhotoImportModel, ProjectPackage) {
        let committed = try await makePackage(library)
        let store = ProjectStore()
        store.apply(committed)
        return (PhotoImportModel(library: library, store: store), committed)
    }

    // MARK: - Save and restore

    @MainActor
    func testSaveStoresEveryChoiceAndWritesNothingButTheManifest() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)
        let first = committed.photos[0]
        let second = committed.photos[1]

        let manifestURL = manifest(committed.id)
        let assetURLs = [first, second].flatMap { photo in
            [photo.asset.localReference, photo.thumbnailReference, photo.previewReference]
        }.map { rootURL.appendingPathComponent($0) }
        let before = try bytes([manifestURL] + assetURLs)

        let snapshot = model.roleSnapshot(for: committed.id)
        let choices: [UUID: PhotoRoleChoice] = [
            first.id: .manual(.primary),
            second.id: .automatic(.supporting)
        ]
        let outcome = await model.saveRoleChoices(projectID: committed.id, choices: choices, expecting: snapshot)
        XCTAssertEqual(outcome, .saved)

        let stored = try XCTUnwrap(model.roleSnapshot(for: committed.id))
        XCTAssertEqual(Set(stored.keys), Set([first.id, second.id]))
        // Only the manifest changed; the original and both derivatives are untouched.
        let after = try bytes(assetURLs)
        XCTAssertEqual(Array(before.dropFirst()), after, "role saving must not touch any asset byte")
        XCTAssertNotEqual(before[0], try Data(contentsOf: manifestURL), "the manifest must be rewritten")

        // A fresh library (as after an app restart) reads both choices back.
        let reopened = try await PhotoLibrary(rootURL: rootURL).restore()
        let reopenedPackage = try XCTUnwrap(reopened.packages.first { $0.id == committed.id })
        XCTAssertEqual(reopenedPackage.photos[0].roleChoice, .manual(.primary))
        XCTAssertEqual(reopenedPackage.photos[1].roleChoice, .automatic(.supporting))
        // The document and every other photo field stay exactly as imported.
        XCTAssertEqual(reopenedPackage.project.document, committed.project.document)
    }

    @MainActor
    func testCompleteBatchClearsAStoredChoiceAndKeepsPartialFailuresHonest() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)
        let first = committed.photos[0]
        let second = committed.photos[1]

        // Seed the first photo with a collage choice, as a user would have saved it.
        let seeding = model.roleSnapshot(for: committed.id)
        let seeded = await model.saveRoleChoices(
            projectID: committed.id,
            choices: [first.id: .manual(.collageMaterial), second.id: .manual(.primary)],
            expecting: seeding
        )
        XCTAssertEqual(seeded, .saved)

        // The new sheet shows Automatic for the first photo and its pass produced no
        // evidence for it, while the second photo got a real suggestion.
        let snapshot = model.roleSnapshot(for: committed.id)
        let choices: [UUID: PhotoRoleChoice] = [second.id: .automatic(.supporting)]
        let cleared = await model.saveRoleChoices(
            projectID: committed.id, choices: choices, expecting: snapshot
        )
        XCTAssertEqual(cleared, .saved)

        let current = model.roleSnapshot(for: committed.id)
        XCTAssertEqual(Set(current.keys), Set([first.id, second.id]))
        let reopened = try await PhotoLibrary(rootURL: rootURL).restore()
        let stored = try XCTUnwrap(reopened.packages.first { $0.id == committed.id })
        XCTAssertNil(stored.photos[0].roleChoice, "an absent entry clears the previously saved choice")
        XCTAssertEqual(stored.photos[1].roleChoice, .automatic(.supporting))
    }

    @MainActor
    func testPartialFailureLeavesThatPhotoWithoutAChoiceAndOthersSaved() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)
        let first = committed.photos[0]
        let second = committed.photos[1]

        let snapshot = model.roleSnapshot(for: committed.id)
        // The first photo had no usable evidence at all, so it is absent; the second
        // one keeps a real suggestion. Batch storage must not turn that into
        // "the first photo is not needed".
        let choices: [UUID: PhotoRoleChoice] = [second.id: .automatic(.primary)]
        let outcome = await model.saveRoleChoices(
            projectID: committed.id, choices: choices, expecting: snapshot
        )
        XCTAssertEqual(outcome, .saved)

        let reopened = try await PhotoLibrary(rootURL: rootURL).restore()
        let stored = try XCTUnwrap(reopened.packages.first { $0.id == committed.id })
        XCTAssertNil(stored.photos[0].roleChoice)
        XCTAssertEqual(stored.photos[1].roleChoice, .automatic(.primary))
        XCTAssertEqual(stored.photos.count, 2, "no photo is removed by a role choice")
    }

    // MARK: - Stale drafts

    @MainActor
    func testStaleSnapshotIsRejectedWhenASavedChoiceChanged() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)
        let first = committed.photos[0]
        let second = committed.photos[1]

        // An old sheet froze this snapshot.
        let staleSnapshot = model.roleSnapshot(for: committed.id)
        // Meanwhile another save changed the first photo's choice.
        let otherSave = await model.saveRoleChoices(
            projectID: committed.id,
            choices: [first.id: .manual(.excluded), second.id: .manual(.primary)],
            expecting: staleSnapshot
        )
        XCTAssertEqual(otherSave, .saved)

        // The old sheet now submits its own draft against the old snapshot: the
        // metadata is identical, but the saved choice is not, so it must be refused.
        let staleChoices: [UUID: PhotoRoleChoice] = [first.id: .manual(.primary), second.id: .manual(.supporting)]
        let outcome = await model.saveRoleChoices(
            projectID: committed.id, choices: staleChoices, expecting: staleSnapshot
        )
        guard case .rejected(let text) = outcome else {
            return XCTFail("a stale draft must be rejected, got \(outcome)")
        }
        XCTAssertTrue(text.contains("Reload"), "the user must be told to reload: \(text)")

        let reopened = try await PhotoLibrary(rootURL: rootURL).restore()
        let stored = try XCTUnwrap(reopened.packages.first { $0.id == committed.id })
        XCTAssertEqual(stored.photos[0].roleChoice, .manual(.excluded),
                       "the stale request must not overwrite the newer choice")
        XCTAssertEqual(stored.photos[1].roleChoice, .manual(.primary))
    }

    @MainActor
    func testStaleSnapshotIsRejectedWhenAPhotoIsAddedOrRemoved() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)
        let staleSnapshot = model.roleSnapshot(for: committed.id)

        // A third photo arrives after the sheet captured its snapshot, through the
        // same production import path.
        let grown = try await addPhoto(library, to: committed)

        let outcome = await model.saveRoleChoices(
            projectID: committed.id,
            choices: [committed.photos[0].id: .manual(.primary)],
            expecting: staleSnapshot
        )
        guard case .rejected = outcome else {
            return XCTFail("a snapshot missing a photo must be rejected, got \(outcome)")
        }
        let reopened = try await PhotoLibrary(rootURL: rootURL).restore()
        let stored = try XCTUnwrap(reopened.packages.first { $0.id == committed.id })
        XCTAssertEqual(stored.photos.count, grown.photos.count)
        XCTAssertNil(stored.photos[0].roleChoice, "nothing may be written from a stale snapshot")
    }

    @MainActor
    func testImpossibleDraftIsRejectedAndNotWritten() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)
        let first = committed.photos[0]
        let second = committed.photos[1]
        let manifestURL = manifest(committed.id)
        let before = try Data(contentsOf: manifestURL)

        // Two saved primaries can never be valid; the library must refuse the draft
        // as a typed rejection instead of writing it.
        let snapshot = model.roleSnapshot(for: committed.id)
        let outcome = await model.saveRoleChoices(
            projectID: committed.id,
            choices: [first.id: .manual(.primary), second.id: .automatic(.primary)],
            expecting: snapshot
        )
        guard case .rejected(let text) = outcome else {
            return XCTFail("an impossible draft must be rejected, got \(outcome)")
        }
        XCTAssertTrue(text.lowercased().contains("cannot be saved") || text.lowercased().contains("role"),
                      "the rejection must explain itself: \(text)")
        XCTAssertEqual(try Data(contentsOf: manifestURL), before, "an impossible draft must not reach disk")
    }

    @MainActor
    func testCrossProjectSnapshotIsRejected() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)
        let other = try await makePackage(library, name: "Other")
        let otherSnapshot = model.roleSnapshot(for: other.id)

        // A snapshot that carries another project's photos cannot match this package.
        let outcome = await model.saveRoleChoices(
            projectID: committed.id,
            choices: [committed.photos[0].id: .manual(.primary)],
            expecting: otherSnapshot
        )
        guard case .rejected = outcome else {
            return XCTFail("a cross-project snapshot must be rejected, got \(outcome)")
        }
        let reopened = try await PhotoLibrary(rootURL: rootURL).restore()
        let stored = try XCTUnwrap(reopened.packages.first { $0.id == committed.id })
        XCTAssertNil(stored.photos[0].roleChoice)
    }

    // MARK: - Role observation (real Vision smoke, bounded assertions)

    @MainActor
    func testObserveRoleRunsTheRealVisionPassOnASyntheticThumbnail() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)
        let photo = committed.photos[0]

        let observation = try await model.observeRole(projectID: committed.id, assetID: photo.id)

        // Bounded, honest assertions only: the system must not be required to name a
        // synthetic colour-block image as a landscape.
        XCTAssertEqual(observation.assetID, photo.id)
        XCTAssertEqual(observation.displayWidth, photo.displayPixelSize.width)
        XCTAssertEqual(observation.displayHeight, photo.displayPixelSize.height)
        XCTAssertGreaterThan(observation.classifyRevision, 0, "a real revision ran")
        XCTAssertGreaterThan(observation.faceRevision, 0)
        XCTAssertTrue(observation.sceneScore.isFinite)
        XCTAssertGreaterThanOrEqual(observation.sceneScore, 0)
        XCTAssertLessThanOrEqual(observation.sceneScore, 1)
        XCTAssertGreaterThanOrEqual(observation.faceCount, 0)
        XCTAssertFalse(observation.skippedPixelMeasurement)
        XCTAssertNotNil(observation.analysis, "the Stage 05 measurement ran on the same thumbnail")
        XCTAssertTrue(PhotoRoleAnalyzer.naturalSceneWhitelist.isSuperset(of: Set(observation.supportedNaturalSceneIdentifiers)),
                      "only supported whitelist identifiers may be offered")
        XCTAssertEqual(observation.supportedNaturalSceneIdentifiers,
                       observation.supportedNaturalSceneIdentifiers.sorted())
        XCTAssertEqual(observation.supportedNaturalSceneIdentifiers,
                       PhotoRoleAnalyzer.supportedNaturalSceneVocabulary())
    }

    @MainActor
    func testObserveRoleSkipsVisionForAFullyTransparentThumbnail() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        // A png whose pixels are all alpha 0: Stage 05 reports noVisiblePixels, and
        // Vision (which ignores alpha) must not be asked to name invisible pixels.
        let fixture = try writeFullyTransparentPNG(
            in: baseURL.appendingPathComponent("fixtures", isDirectory: true),
            name: "\(UUID().uuidString)-clear.png",
            width: 320, height: 240
        )
        let decoded = try SyntheticImageFactory.readImage(at: fixture)
        XCTAssertEqual(try SyntheticImageFactory.alphaStats(of: decoded).opaque, 0,
                       "the fixture must really have no opaque pixel")

        var package = ProjectPackage(project: Project(name: "Transparent"), photos: [])
        let staged = try await PhotoFileTransfer.stageCopy(of: fixture, rootURL: rootURL)
        package = try await library.importPhoto(fileURL: staged, into: package, at: Date()).package
        let store = ProjectStore()
        store.apply(package)
        let model = PhotoImportModel(library: library, store: store)
        let photo = package.photos[0]

        let analysis = try? await model.analyzePhoto(projectID: package.id, assetID: photo.id)
        XCTAssertNil(analysis)
        let observation = try await model.observeRole(projectID: package.id, assetID: photo.id)
        XCTAssertTrue(observation.skippedPixelMeasurement, "the transparent failure must skip Vision")
        XCTAssertFalse(observation.classificationRan)
        XCTAssertEqual(observation.sceneScore, 0)
        XCTAssertEqual(observation.faceCount, 0)
        XCTAssertNil(observation.analysis)
        XCTAssertEqual(observation.analysisFailure, .noVisiblePixels)
        XCTAssertEqual(observation.supportedNaturalSceneIdentifiers,
                       PhotoRoleAnalyzer.supportedNaturalSceneVocabulary())
    }

    /// The pure reduction the analyzer uses. It takes an **injected** supported set,
    /// so this check never depends on which labels the current SDK happens to ship.
    func testVocabularyReductionKeepsOnlyWhitelistedSupportedLabels() {
        let injected = [
            "landscape", "Nature", "OAK_TREE", "sunset", "person", "car",
            "CITYSCAPE", "mountain_range", "sky"
        ]
        let reduced = PhotoRoleAnalyzer.naturalSceneVocabulary(fromSupported: injected)
        // `mountain_range` normalises to "mountain range", which is **not** in the
        // approved exact whitelist (only `mountain` is), so it is dropped: the
        // reduction never substring-matches to stretch a label into evidence.
        XCTAssertEqual(reduced, ["cityscape", "landscape", "nature", "sky", "sunset"])
        XCTAssertFalse(reduced.contains("mountain range"))
        XCTAssertFalse(reduced.contains("mountain"), "the whitelist is exact, not a prefix match")
        XCTAssertFalse(reduced.contains("oak tree"), "an unsupported label is never evidence")
        XCTAssertFalse(reduced.contains("person"))

        // Scoring only ever reads the injected supported set: out-of-range and
        // non-finite confidences are discarded, never clamped into evidence.
        let observations: [(identifier: String, confidence: Double)] = [
            ("landscape", 0.9), ("person", 1.0), ("sunset", .nan), ("sky", 2.0), ("Nature", 0.6)
        ]
        XCTAssertEqual(
            PhotoRoleAnalyzer.sceneScore(from: observations, supportedIdentifiers: reduced),
            0.9,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            PhotoRoleAnalyzer.sceneScore(from: observations, supportedIdentifiers: []),
            0,
            "an empty vocabulary can never look like evidence"
        )
    }

    /// A Vision failure must not throw away a **successful** pixel measurement: the
    /// production fallback (the same function `PhotoLibrary.observeRole` calls from
    /// its real error path) keeps it for a limited suggestion and reports the
    /// recognition as unfinished. No label, score, face or revision is invented, and
    /// a non-Vision error is not swallowed into this shape.
    func testVisionFailureFallbackKeepsSuccessfulMeasurementAndClaimsNothingElse() throws {
        let assetID = UUID()
        let analysis = PhotoAnalysis(
            assetID: assetID, displayWidth: 320, displayHeight: 240,
            sampleWidth: 64, sampleHeight: 48, validPixelCount: 512,
            meanRed: 0.5, meanGreen: 0.5, meanBlue: 0.5,
            meanLuminance: 0.45, luminanceContrast: 0.1, meanSaturation: 0.3,
            darkPixelRatio: 0, brightPixelRatio: 0, coverage: 0.9, confidence: .adequate
        )

        let fallback = try XCTUnwrap(PhotoRoleAnalyzer.observationAfterVisionFailure(
            PhotoRoleObservationFailure.visionUnavailable,
            assetID: assetID, displayWidth: 320, displayHeight: 240,
            analysis: analysis, analysisFailure: nil
        ))
        XCTAssertEqual(fallback.assetID, assetID)
        XCTAssertEqual(fallback.analysis, analysis, "the measured light/size data survives the Vision failure")
        XCTAssertFalse(fallback.classificationRan)
        XCTAssertEqual(fallback.sceneScore, 0, "no scene score is fabricated")
        XCTAssertEqual(fallback.faceCount, 0, "no face is fabricated")
        XCTAssertEqual(fallback.classifyRevision, 0)
        XCTAssertEqual(fallback.faceRevision, 0)
        XCTAssertFalse(fallback.skippedPixelMeasurement)
        XCTAssertNil(fallback.analysisFailure)

        // The realistic reflection of the error path: Vision failed but the pixel
        // measurement also failed, so the fallback still tells the truth.
        let noMeasurement = try XCTUnwrap(PhotoRoleAnalyzer.observationAfterVisionFailure(
            PhotoRoleObservationFailure.visionUnavailable,
            assetID: assetID, displayWidth: 320, displayHeight: 240,
            analysis: nil, analysisFailure: .unreadable
        ))
        XCTAssertNil(noMeasurement.analysis)
        XCTAssertEqual(noMeasurement.analysisFailure, .unreadable)

        // A non-Vision error is not converted into a "recognition unfinished" result.
        XCTAssertNil(PhotoRoleAnalyzer.observationAfterVisionFailure(
            PhotoAnalysisFailure.missing,
            assetID: assetID, displayWidth: 320, displayHeight: 240,
            analysis: analysis, analysisFailure: nil
        ))
    }

    // MARK: - Clear, rollback and later edits

    @MainActor
    func testClearingEverySavedChoiceIsAcceptedAndPersisted() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)

        // Save both roles first, then clear everything in one complete batch.
        let first = model.roleSnapshot(for: committed.id)
        let seeded = await model.saveRoleChoices(
            projectID: committed.id,
            choices: [committed.photos[0].id: .manual(.excluded), committed.photos[1].id: .automatic(.supporting)],
            expecting: first
        )
        XCTAssertEqual(seeded, .saved)

        let second = model.roleSnapshot(for: committed.id)
        let cleared = await model.saveRoleChoices(
            projectID: committed.id, choices: [:], expecting: second
        )
        XCTAssertEqual(cleared, .saved, "clearing everything is a legal complete-batch save")

        let reopened = try await PhotoLibrary(rootURL: rootURL).restore()
        let stored = try XCTUnwrap(reopened.packages.first { $0.id == committed.id })
        XCTAssertTrue(stored.photos.allSatisfy { $0.roleChoice == nil })
        // The photos themselves stay: a role choice never removes one.
        XCTAssertEqual(stored.photos.count, committed.photos.count)
        XCTAssertEqual(stored.project.document, committed.project.document)
    }

    @MainActor
    func testClearingOneChoiceKeepsTheOtherAndSurvivesCanvasWork() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)
        let kept = committed.photos[0]
        let cleared = committed.photos[1]

        let seeded = await model.saveRoleChoices(
            projectID: committed.id,
            choices: [kept.id: .manual(.primary), cleared.id: .manual(.collageMaterial)],
            expecting: model.roleSnapshot(for: committed.id)
        )
        XCTAssertEqual(seeded, .saved)

        // A partial batch: only the kept photo is present, so the other is cleared.
        let partial = await model.saveRoleChoices(
            projectID: committed.id,
            choices: [kept.id: .manual(.primary)],
            expecting: model.roleSnapshot(for: committed.id)
        )
        XCTAssertEqual(partial, .saved)

        // A later canvas edit must not disturb the surviving role choice.
        let edit = await model.editCanvas(projectID: committed.id) { document in
            var updated = document
            let base = try XCTUnwrap(CanvasGeometry.fittedBaseSize(
                displayWidth: kept.displayPixelSize.width,
                displayHeight: kept.displayPixelSize.height,
                canvasSize: document.canvasSize
            ))
            updated = try CanvasEditor.addingLayer(assetID: kept.id, baseSize: base, to: updated)
            return updated
        }
        XCTAssertEqual(edit, .saved)

        let reopened = try await PhotoLibrary(rootURL: rootURL).restore()
        let stored = try XCTUnwrap(reopened.packages.first { $0.id == committed.id })
        XCTAssertEqual(stored.photos.first { $0.id == kept.id }?.roleChoice, .manual(.primary),
                       "a later canvas save keeps the other photo's role choice")
        XCTAssertNil(stored.photos.first { $0.id == cleared.id }?.roleChoice)
        XCTAssertFalse(stored.project.document.layers.isEmpty, "the canvas edit itself was committed")
    }

    @MainActor
    func testPhotoRemovalKeepsOtherRoleChoicesAndRemanifest() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)
        let kept = committed.photos[0]
        let removed = committed.photos[1]

        let seeded = await model.saveRoleChoices(
            projectID: committed.id,
            choices: [kept.id: .manual(.primary), removed.id: .manual(.supporting)],
            expecting: model.roleSnapshot(for: committed.id)
        )
        XCTAssertEqual(seeded, .saved)

        await model.removePhoto(projectID: committed.id, assetID: removed.id)

        let reopened = try await PhotoLibrary(rootURL: rootURL).restore()
        let stored = try XCTUnwrap(reopened.packages.first { $0.id == committed.id })
        XCTAssertEqual(stored.photos.count, 1)
        XCTAssertEqual(stored.photos[0].roleChoice, .manual(.primary),
                       "removing one photo keeps the other's saved role")
        let remaining = try XCTUnwrap(stored.photos.first)
        XCTAssertFalse(remaining.roleChoice == nil)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: rootURL.appendingPathComponent(remaining.asset.localReference).path
        ), "the kept photo's original is untouched")
    }

    // MARK: - Real IO write failure and rollback

    /// A real manifest write failure: the project directory is made unwritable, so the
    /// atomic write cannot create its sibling temporary file. The read path stays
    /// valid, and the committed manifest is untouched and still readable, which is
    /// what makes this an IO failure rather than a decode error.
    ///
    /// The failure is **required**, never optional: if the host cannot enforce the
    /// permission (non-POSIX build hosts) the test throws instead of silently skipping
    /// the rollback assertions. The native macOS run must always exercise the
    /// `saveFailed` + rollback + retry path.
    @MainActor
    func testRoleSaveWriteFailureKeepsStoreAndManifestAndRetrySucceeds() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let (model, committed) = try await makeModel(library)
        let first = committed.photos[0]
        let second = committed.photos[1]
        let manifestURL = manifest(committed.id)
        let before = try Data(contentsOf: manifestURL)
        let snapshot = model.roleSnapshot(for: committed.id)

        let projectDirectory = manifestURL.deletingLastPathComponent()
        let originalPermissions = try FileManager.default.attributesOfItem(atPath: projectDirectory.path)[.posixPermissions]
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: originalPermissions ?? 0o755], ofItemAtPath: projectDirectory.path
            )
        }

        try makeUnwritableAndProbe(projectDirectory)

        let outcome = await model.saveRoleChoices(
            projectID: committed.id,
            choices: [first.id: .manual(.primary), second.id: .manual(.supporting)],
            expecting: snapshot
        )
        guard case .saveFailed(let text) = outcome else {
            return XCTFail("a real write failure must be reported as saveFailed, got \(outcome)")
        }
        XCTAssertFalse(text.isEmpty)

        // Rollback: the committed manifest bytes and the store are unchanged, so
        // nothing was written and the app still shows the pre-save state.
        XCTAssertEqual(try Data(contentsOf: manifestURL), before)
        XCTAssertEqual(model.roleSnapshot(for: committed.id), snapshot)
        let reopenedAfterFailure = try await PhotoLibrary(rootURL: rootURL).restore()
        let storedAfterFailure = try XCTUnwrap(reopenedAfterFailure.packages.first { $0.id == committed.id })
        XCTAssertNil(storedAfterFailure.photos[0].roleChoice)
        XCTAssertNil(storedAfterFailure.photos[1].roleChoice)
        XCTAssertNil(model.failedDraft(for: committed.id), "a role save never creates a canvas draft")

        // The same draft retried after the storage recovers must commit.
        try FileManager.default.setAttributes(
            [.posixPermissions: originalPermissions ?? 0o755], ofItemAtPath: projectDirectory.path
        )
        let retried = await model.saveRoleChoices(
            projectID: committed.id,
            choices: [first.id: .manual(.primary), second.id: .manual(.supporting)],
            expecting: snapshot
        )
        XCTAssertEqual(retried, .saved)
        let reopened = try await PhotoLibrary(rootURL: rootURL).restore()
        let stored = try XCTUnwrap(reopened.packages.first { $0.id == committed.id })
        XCTAssertEqual(stored.photos[0].roleChoice, .manual(.primary))
        XCTAssertEqual(stored.photos[1].roleChoice, .manual(.supporting))
        XCTAssertEqual(stored.project.document, committed.project.document, "a role save never touches the document")
    }

    /// Makes one directory unwritable and **proves** the host enforced it by probing a
    /// real create attempt. A host that cannot enforce POSIX permissions **fails** the
    /// test: the rollback assertions must never be skipped.
    private func makeUnwritableAndProbe(_ directory: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        let probe = directory.appendingPathComponent("write-probe.tmp")
        var enforced = false
        do {
            try Data([0x01]).write(to: probe)
            try? FileManager.default.removeItem(at: probe)
        } catch {
            enforced = true
        }
        guard enforced else {
            throw PhotoRoleSaveError.impossible(
                "this host does not enforce POSIX directory permissions, so the real write-failure path "
                + "cannot be exercised; the native macOS run must enforce it"
            )
        }
    }

    /// Writes a genuinely fully transparent PNG by clearing an alpha-capable context
    /// without drawing anything, so every pixel really is RGBA (0,0,0,0).
    private func writeFullyTransparentPNG(in directory: URL, name: String, width: Int, height: Int) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw SyntheticImageFactory.FixtureError.contextUnavailable(width: width, height: height)
        }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            throw SyntheticImageFactory.FixtureError.renderFailed(width: width, height: height)
        }
        try SyntheticImageFactory.write(image, to: url, typeIdentifier: UTType.png.identifier)
        return url
    }
}
