import PhotosUI
import SwiftUI
import XCTest
@testable import MomentsStudio

/// Stage 03 storage and coordinator tests.
///
/// They use a real `PhotoLibrary` rooted in a temporary directory, real synthetic
/// image files (`SyntheticImageFactory`) and real manifest bytes on disk. Nothing
/// here is a stub of the writer: a failure is produced by making the manifest path
/// genuinely unwritable, and "reading does not rewrite" is proven by comparing the
/// file bytes before and after `restore()`.
final class Stage03StorageCoordinatorTests: XCTestCase {
    private var baseURL: URL!
    private var rootURL: URL!
    private var fixturesURL: URL!

    override func setUpWithError() throws {
        baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        rootURL = baseURL.appendingPathComponent("Library", isDirectory: true)
        fixturesURL = baseURL.appendingPathComponent("fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fixturesURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let baseURL { try? FileManager.default.removeItem(at: baseURL) }
    }

    private func makeLibrary() -> PhotoLibrary { PhotoLibrary(rootURL: rootURL) }

    private func manifestURL(_ projectID: UUID) -> URL {
        rootURL.appendingPathComponent(PhotoLibraryPath.manifestReference(projectID))
    }

    /// Imports one real fixture and returns the package the library wrote.
    private func importedPhotoPackage(
        library: PhotoLibrary,
        projectName: String = "Stage03"
    ) async throws -> (package: ProjectPackage, fixture: URL) {
        let fixture = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "\(projectName)-\(UUID().uuidString).jpg",
            width: 320,
            height: 240
        )
        let staged = try await PhotoFileTransfer.stageCopy(of: fixture, rootURL: rootURL)
        let project = Project(name: projectName)
        let result = try await library.importPhoto(
            fileURL: staged,
            into: ProjectPackage(project: project, photos: []),
            at: Date()
        )
        return (result.package, fixture)
    }

    // MARK: - Frozen version 1 with a real photo, verified on disk

    /// The first test also touches `PhotoImportModel`/`ProjectStore` synchronously,
    /// so it is MainActor-isolated at method level, matching
    /// `PhotoImportModelTests`' isolation rule (the XCTest lifecycle is untouched).
    @MainActor
    func testRealVersion1PackageOnDiskRestoresWithoutRewritingTheFile() async throws {
        // Frozen old shape: no current encoder participates in these bytes.
        let projectID = try XCTUnwrap(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let assetID = try XCTUnwrap(UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF"))
        let legacyBytes = Data("""
        {
          "schemaVersion": 1,
          "project": {
            "id": "11111111-2222-3333-4444-555555555555",
            "name": "Frozen photo project", "createdAt": 0, "updatedAt": 0,
            "document": {
              "id": "66666666-7777-8888-9999-AAAAAAAAAAAA",
              "canvasSize": {"width": 1080, "height": 1350},
              "layers": [{
                "id": "6F1B1B4E-3A2E-4C9B-8E7A-9F0C1D2E3F40", "kind": "photo",
                "transform": {"translationX": 10, "translationY": 20, "scale": 1.5, "rotationRadians": 0.25},
                "opacity": 0.8, "zIndex": 3, "isLocked": true, "isHidden": false
              }]
            }
          },
          "photos": [{
            "asset": {
              "id": "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF", "kind": "photo",
              "localReference": "Projects/11111111-2222-3333-4444-555555555555/assets/BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF/original.jpg"
            },
            "thumbnailReference": "Projects/11111111-2222-3333-4444-555555555555/assets/BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF/thumbnail.jpg",
            "previewReference": "Projects/11111111-2222-3333-4444-555555555555/assets/BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF/preview.jpg",
            "pixelWidth": 320, "pixelHeight": 240, "orientation": 1, "contentType": "public.jpeg"
          }]
        }
        """.utf8)
        let assetDirectory = rootURL.appendingPathComponent(PhotoLibraryPath.assetDirectoryReference(projectID, assetID: assetID))
        let original = try SyntheticImageFactory.writeFixture(in: assetDirectory, name: "original.jpg", width: 320, height: 240)
        for name in ["thumbnail.jpg", "preview.jpg"] {
            try FileManager.default.copyItem(at: original, to: assetDirectory.appendingPathComponent(name))
        }
        try legacyBytes.write(to: manifestURL(projectID))
        let originalBytes = try Data(contentsOf: original)
        let library = makeLibrary()
        let store = ProjectStore()
        let model = PhotoImportModel(library: library, store: store)
        await model.restoreProjects()
        XCTAssertEqual(model.restoreState, .ready)
        XCTAssertTrue(model.warnings.isEmpty)
        XCTAssertEqual(try Data(contentsOf: manifestURL(projectID)), legacyBytes)
        XCTAssertEqual(store.photos(for: projectID).map(\.asset.id), [assetID])
        let restored = try XCTUnwrap(store.openProject(id: projectID))
        XCTAssertEqual(restored.document.layers.count, 1)
        XCTAssertNil(restored.document.layers[0].assetID)
        XCTAssertEqual(restored.document.layers[0].transform.scale, 1.5)
        XCTAssertEqual(restored.document.layers[0].zIndex, 3)
        XCTAssertTrue(restored.document.layers[0].isLocked)
        XCTAssertEqual(try Data(contentsOf: original), originalBytes)

        // The first successful edit upgrades the actual disk manifest, preserving
        // the old placeholder, document identity and real asset.
        let outcome = await model.addPhotoLayer(projectID: projectID, assetID: assetID)
        XCTAssertEqual(outcome, .saved)
        let saved = try JSONDecoder().decode(ProjectPackage.self, from: Data(contentsOf: manifestURL(projectID)))
        XCTAssertEqual(saved.schemaVersion, 2)
        XCTAssertEqual(saved.project.document.id, restored.document.id)
        XCTAssertEqual(saved.project.document.layers.count, 2)
        XCTAssertEqual(saved.project.document.layers.last?.assetID, assetID)
        XCTAssertEqual(try Data(contentsOf: original), originalBytes)
    }

    // MARK: - saveEdit commits schema 2 and restores every layer field

    func testSaveEditWritesSchema2AndRoundTripsLayerFields() async throws {
        let library = makeLibrary()
        let imported = try await importedPhotoPackage(library: library)
        let assetID = try XCTUnwrap(imported.package.photos.first?.asset.id)
        let baseSize = CanvasSize(width: 240, height: 180)

        var document = try CanvasEditor.addingLayer(assetID: assetID, baseSize: baseSize, to: imported.package.project.document)
        let layerID = try XCTUnwrap(document.layers.first?.id)
        document = try CanvasEditor.settingTransform(
            LayerTransform(translationX: 123.5, translationY: 456.25, scale: 2.5, rotationRadians: 0.75),
            forLayerID: layerID,
            in: document
        )
        document = try CanvasEditor.settingHidden(true, forLayerID: layerID, in: document)
        document = try CanvasEditor.settingLocked(true, forLayerID: layerID, in: document)

        let result = try await library.saveEdit(document: document, into: imported.package, at: Date())
        XCTAssertEqual(result.package.schemaVersion, ProjectPackage.currentSchemaVersion)

        let written = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL(imported.package.project.id))) as? [String: Any]
        XCTAssertEqual(written?["schemaVersion"] as? Int, 2)

        let decoded = try JSONDecoder().decode(ProjectPackage.self, from: Data(contentsOf: manifestURL(imported.package.project.id)))
        let layer = try XCTUnwrap(decoded.project.document.layers.first)
        XCTAssertEqual(layer.id, layerID)
        XCTAssertEqual(layer.assetID, assetID)
        XCTAssertEqual(layer.baseSize, baseSize)
        XCTAssertEqual(layer.transform.translationX, 123.5)
        XCTAssertEqual(layer.transform.translationY, 456.25)
        XCTAssertEqual(layer.transform.scale, 2.5)
        XCTAssertEqual(layer.transform.rotationRadians, 0.75)
        XCTAssertTrue(layer.isHidden)
        XCTAssertTrue(layer.isLocked)
        XCTAssertEqual(decoded.photos.count, 1)
        XCTAssertEqual(layer, document.layers.first)
        XCTAssertEqual(decoded.project.document.id, imported.package.project.document.id)
        XCTAssertEqual(decoded.photos, imported.package.photos)
    }

    // MARK: - Layer removal keeps the asset; photo removal cascades in one transaction

    func testRemovingALayerKeepsTheOriginalBytes() async throws {
        let library = makeLibrary()
        let imported = try await importedPhotoPackage(library: library)
        let photo = try XCTUnwrap(imported.package.photos.first)
        let originalBytes = try Data(contentsOf: rootURL.appendingPathComponent(photo.asset.localReference))

        var document = try CanvasEditor.addingLayer(assetID: photo.asset.id, baseSize: CanvasSize(width: 100, height: 100), to: imported.package.project.document)
        let layerID = try XCTUnwrap(document.layers.first?.id)
        document = try CanvasEditor.removingLayer(layerID: layerID, from: document)

        _ = try await library.saveEdit(document: document, into: imported.package, at: Date())

        XCTAssertTrue(FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(photo.asset.localReference).path))
        XCTAssertEqual(try Data(contentsOf: rootURL.appendingPathComponent(photo.asset.localReference)), originalBytes)
        let decoded = try JSONDecoder().decode(ProjectPackage.self, from: Data(contentsOf: manifestURL(imported.package.project.id)))
        XCTAssertTrue(decoded.project.document.layers.isEmpty)
        XCTAssertEqual(decoded.photos.count, 1)
    }

    func testRemovingAPhotoAlsoRemovesItsLockedLayersInOneTransaction() async throws {
        let library = makeLibrary()
        let first = try await importedPhotoPackage(library: library, projectName: "A")
        let secondFixture = try SyntheticImageFactory.writeFixture(in: fixturesURL, name: "B.jpg", width: 200, height: 300)
        let stagedSecond = try await PhotoFileTransfer.stageCopy(of: secondFixture, rootURL: rootURL)
        let withSecond = try await library.importPhoto(
            fileURL: stagedSecond,
            into: first.package,
            at: Date()
        )
        let removedAssetID = try XCTUnwrap(first.package.photos.first?.asset.id)
        let keptAssetID = try XCTUnwrap(withSecond.package.photos.last?.asset.id)

        var document = withSecond.package.project.document
        document = try CanvasEditor.addingLayer(assetID: removedAssetID, baseSize: CanvasSize(width: 100, height: 100), to: document)
        document = try CanvasEditor.addingLayer(assetID: keptAssetID, baseSize: CanvasSize(width: 100, height: 100), to: document)
        document = try CanvasEditor.settingLocked(true, forLayerID: document.layers[0].id, in: document)
        let saved = try await library.saveEdit(document: document, into: withSecond.package, at: Date())
        XCTAssertEqual(saved.package.project.document.layers.count, 2)
        let keptPhoto = try XCTUnwrap(saved.package.photos.first(where: { $0.asset.id == keptAssetID }))
        let keptOriginalURL = rootURL.appendingPathComponent(keptPhoto.asset.localReference)
        let keptOriginalBytes = try Data(contentsOf: keptOriginalURL)
        var expectedKeptLayer = try XCTUnwrap(saved.package.project.document.layers.first(where: { $0.assetID == keptAssetID }))
        expectedKeptLayer.zIndex = 0

        let removal = try await library.removePhoto(assetID: removedAssetID, from: saved.package, at: Date())

        // The locked layer bound to the deleted photo is gone in the same manifest,
        // and the other photo's layer survives untouched.
        XCTAssertEqual(removal.package.photos.map(\.asset.id), [keptAssetID])
        XCTAssertEqual(removal.package.project.document.layers.count, 1)
        XCTAssertEqual(removal.package.project.document.layers.first?.assetID, keptAssetID)

        let decoded = try JSONDecoder().decode(ProjectPackage.self, from: Data(contentsOf: manifestURL(removal.package.project.id)))
        XCTAssertEqual(decoded.project.document.layers.count, 1)
        XCTAssertEqual(decoded.photos.map(\.asset.id), [keptAssetID])
        XCTAssertEqual(decoded.project.document.layers.first, expectedKeptLayer)
        XCTAssertEqual(decoded.photos, [keptPhoto])
        XCTAssertEqual(try Data(contentsOf: keptOriginalURL), keptOriginalBytes)
    }

    // MARK: - A genuinely failing write keeps the committed state, and retry recovers

    /// Keeps the old manifest readable but rejects writes via the existing path
    /// guard. No stub writer, chmod assumption or deleted old manifest.
    private func blockManifest(_ projectID: UUID) throws -> URL {
        let backup = baseURL.appendingPathComponent("retained-\(projectID.uuidString).json")
        try FileManager.default.moveItem(at: manifestURL(projectID), to: backup)
        try FileManager.default.createSymbolicLink(at: manifestURL(projectID), withDestinationURL: backup)
        return backup
    }

    private func unblockManifest(_ projectID: UUID, backup: URL) throws {
        try FileManager.default.removeItem(at: manifestURL(projectID))
        try FileManager.default.moveItem(at: backup, to: manifestURL(projectID))
    }

    @MainActor
    func testFailedWriteKeepsCommittedStateAndRetrySucceeds() async throws {
        let library = makeLibrary()
        let committed = try await importedPhotoPackage(library: library).package
        let projectID = committed.project.id
        let assetID = try XCTUnwrap(committed.photos.first?.asset.id)
        let bytes = try Data(contentsOf: manifestURL(projectID))
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let backup = try blockManifest(projectID)
        let outcome = await model.addPhotoLayer(projectID: projectID, assetID: assetID)
        guard case .saveFailed = outcome else { return XCTFail("Expected real write rejection, got \(outcome)") }
        XCTAssertEqual(store.openProject(id: projectID), committed.project)
        XCTAssertEqual(store.photos(for: projectID), committed.photos)
        XCTAssertEqual(try Data(contentsOf: manifestURL(projectID)), bytes)
        XCTAssertEqual(try Data(contentsOf: backup), bytes)
        XCTAssertEqual(model.failedDraft(for: projectID)?.intent, .add(assetID: assetID))
        XCTAssertNotNil(model.editMessage(for: projectID))
        try unblockManifest(projectID, backup: backup)
        let retried = await model.retryFailedDraft(projectID: projectID)
        XCTAssertEqual(retried, .saved)
        XCTAssertNil(model.failedDraft(for: projectID))
        XCTAssertNil(model.editMessage(for: projectID))
        let saved = try JSONDecoder().decode(ProjectPackage.self, from: Data(contentsOf: manifestURL(projectID)))
        XCTAssertEqual(store.openProject(id: projectID), saved.project)
        XCTAssertEqual(store.photos(for: projectID), saved.photos)
        XCTAssertEqual(saved.project.document.layers.count, 1)
    }

    // MARK: - Coordinator: gate, gesture identity, cross-project failure state

    @MainActor
    func testMismatchedDraftProjectCannotWriteEitherPackage() async throws {
        let library = makeLibrary()
        let first = try await importedPhotoPackage(library: library, projectName: "A").package
        let second = try await importedPhotoPackage(library: library, projectName: "B").package
        let store = ProjectStore()
        store.restore([first, second])
        let model = PhotoImportModel(library: library, store: store)
        let bytesA = try Data(contentsOf: manifestURL(first.id))
        let bytesB = try Data(contentsOf: manifestURL(second.id))
        let draft = PhotoImportModel.CanvasDraft(projectID: second.id, layerID: nil, intent: .add(assetID: try XCTUnwrap(second.photos.first?.id)))
        let result = await model.editCanvas(projectID: first.id, intent: draft) { $0 }
        guard case .rejected = result else { return XCTFail("Cross-project draft must be rejected") }
        XCTAssertEqual(try Data(contentsOf: manifestURL(first.id)), bytesA)
        XCTAssertEqual(try Data(contentsOf: manifestURL(second.id)), bytesB)
        XCTAssertEqual(store.openProject(id: first.id), first.project)
        XCTAssertEqual(store.openProject(id: second.id), second.project)
        XCTAssertNil(model.failedDraft(for: first.id))
        XCTAssertNil(model.failedDraft(for: second.id))
    }

    @MainActor
    func testActiveGestureHoldsTheGateAndLateCallbacksAreRefused() async throws {
        let library = makeLibrary()
        let imported = try await importedPhotoPackage(library: library)
        let projectID = imported.package.project.id
        let assetID = try XCTUnwrap(imported.package.photos.first?.asset.id)
        let store = ProjectStore()
        store.restore([imported.package])
        let model = PhotoImportModel(library: library, store: store)

        let gestureID = try XCTUnwrap(model.beginCanvasGesture(projectID: projectID))
        XCTAssertTrue(model.isBusy)
        XCTAssertTrue(model.isCanvasGestureActive)
        // Direct restore and import calls must respect the active gesture too.
        await model.restoreProjects()
        XCTAssertEqual(model.restoreState, .idle)
        await model.importSelection([PhotosPickerItem(itemIdentifier: "must-not-load")], projectID: projectID)
        XCTAssertEqual(model.totalCount, 0)
        XCTAssertEqual(store.photos(for: projectID), imported.package.photos)
        // A second gesture cannot start while one holds the gate.
        XCTAssertNil(model.beginCanvasGesture(projectID: projectID))

        // Button edits wait for the gesture instead of interleaving with it.
        let blocked = await model.editCanvas(projectID: projectID) { $0 }
        XCTAssertEqual(blocked, .busy)

        // A removal attempt while the gesture is live is refused and reported.
        await model.removePhoto(projectID: projectID, assetID: assetID)
        XCTAssertFalse(model.itemErrors.isEmpty)

        // A callback for a different gesture identity cannot commit.
        let lateOutcome = await model.commitCanvasGesture(
            id: UUID(),
            projectID: projectID,
            layerID: UUID(),
            transform: .identity
        )
        XCTAssertEqual(lateOutcome, .busy)
        XCTAssertTrue(model.isCanvasGestureActive, "a refused late commit must not release the real gesture")

        // Cancelling with the wrong identity is ignored; the right one releases it.
        model.cancelCanvasGesture(id: UUID())
        XCTAssertTrue(model.isCanvasGestureActive)
        model.cancelCanvasGesture(id: gestureID)
        XCTAssertFalse(model.isCanvasGestureActive)
        XCTAssertFalse(model.isBusy)
    }

    @MainActor
    func testFailedDraftIsProjectScopedAndMessagesAreAttributed() async throws {
        let library = makeLibrary()
        let first = try await importedPhotoPackage(library: library, projectName: "A").package
        let second = try await importedPhotoPackage(library: library, projectName: "B").package
        let store = ProjectStore()
        store.restore([first, second])
        let model = PhotoImportModel(library: library, store: store)
        let a = first.project.id
        let b = second.project.id
        let backupA = try blockManifest(a)
        let failedA = await model.addPhotoLayer(projectID: a, assetID: try XCTUnwrap(first.photos.first?.asset.id))
        guard case .saveFailed = failedA else { return XCTFail("A must fail") }
        let draftA = try XCTUnwrap(model.failedDraft(for: a))
        let messageA = try XCTUnwrap(model.editMessage(for: a))
        let successB = await model.addPhotoLayer(projectID: b, assetID: try XCTUnwrap(second.photos.first?.asset.id))
        XCTAssertEqual(successB, .saved)
        XCTAssertEqual(model.failedDraft(for: a), draftA)
        XCTAssertEqual(model.editMessage(for: a), messageA)
        XCTAssertNil(model.failedDraft(for: b))
        let bLayer = try XCTUnwrap(store.openProject(id: b)?.document.layers.first?.id)
        let backupB = try blockManifest(b)
        let failedB = await model.applyCanvasIntent(projectID: b, layerID: bLayer, intent: .move(x: 15, y: 0))
        guard case .saveFailed = failedB else { return XCTFail("B must fail independently") }
        XCTAssertEqual(model.failedDraft(for: a), draftA)
        XCTAssertEqual(model.editMessage(for: a), messageA)
        XCTAssertEqual(model.failedDraft(for: b)?.projectID, b)
        model.discardFailedDraft(projectID: b)
        XCTAssertNil(model.failedDraft(for: b))
        XCTAssertEqual(model.failedDraft(for: a), draftA)
        try unblockManifest(b, backup: backupB)
        try unblockManifest(a, backup: backupA)
        let retried = await model.retryFailedDraft(projectID: a)
        XCTAssertEqual(retried, .saved)
        XCTAssertNil(model.failedDraft(for: a))
    }

    @MainActor
    func testPendingDraftBlocksSameProjectMutationsAndDiscardLeavesDiskAlone() async throws {
        let library = makeLibrary()
        let committed = try await importedPhotoPackage(library: library).package
        let id = committed.project.id
        let assetID = try XCTUnwrap(committed.photos.first?.asset.id)
        let bytes = try Data(contentsOf: manifestURL(id))
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let backup = try blockManifest(id)
        let failed = await model.addPhotoLayer(projectID: id, assetID: assetID)
        guard case .saveFailed = failed else { return XCTFail("Expected retained failure") }
        let draft = model.failedDraft(for: id)
        XCTAssertNil(model.beginCanvasGesture(projectID: id))
        let blocked = await model.editCanvas(projectID: id) { $0 }
        guard case .rejected = blocked else { return XCTFail("Pending draft must block ordinary edits") }
        await model.importSelection([PhotosPickerItem(itemIdentifier: "must-not-load")], projectID: id)
        XCTAssertEqual(model.totalCount, 0)
        await model.removePhoto(projectID: id, assetID: assetID)
        XCTAssertEqual(store.openProject(id: id), committed.project)
        XCTAssertEqual(store.photos(for: id), committed.photos)
        XCTAssertEqual(model.failedDraft(for: id), draft)
        model.discardFailedDraft(projectID: id)
        XCTAssertNil(model.failedDraft(for: id))
        XCTAssertNil(model.editMessage(for: id))
        XCTAssertEqual(try Data(contentsOf: manifestURL(id)), bytes)
        try unblockManifest(id, backup: backup)
        let saved = await model.addPhotoLayer(projectID: id, assetID: assetID)
        XCTAssertEqual(saved, .saved)
    }

    @MainActor
    func testRetryReappliesIntentToLatestTargetAndPreservesUnrelatedFields() async throws {
        let library = makeLibrary()
        var committed = try await importedPhotoPackage(library: library).package
        let id = committed.project.id
        let assetID = try XCTUnwrap(committed.photos.first?.asset.id)
        var document = try CanvasEditor.addingLayer(assetID: assetID, baseSize: CanvasSize(width: 100, height: 100), to: committed.project.document)
        document = try CanvasEditor.addingLayer(assetID: assetID, baseSize: CanvasSize(width: 100, height: 100), to: document)
        committed = try await library.saveEdit(document: document, into: committed, at: Date()).package
        let targetID = document.layers[0].id
        let otherID = document.layers[1].id
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let backup = try blockManifest(id)
        let failed = await model.applyCanvasIntent(projectID: id, layerID: targetID, intent: .move(x: 10, y: 20))
        guard case .saveFailed = failed else { return XCTFail("Expected retryable move") }
        try unblockManifest(id, backup: backup)

        // A newer committed snapshot (e.g. refreshed from disk) must not be
        // overwritten wholesale by the old intent. The UI itself blocks conflicts.
        document = try CanvasEditor.settingTransform(LayerTransform(translationX: 100, translationY: 200, scale: 2, rotationRadians: 0.7), forLayerID: targetID, in: document)
        document = try CanvasEditor.settingHidden(true, forLayerID: otherID, in: document)
        var renamed = committed.project
        renamed.name = "Newer name"
        let latest = try await library.saveEdit(document: document, into: ProjectPackage(project: renamed, photos: committed.photos), at: Date()).package
        store.apply(latest)
        let untouched = try XCTUnwrap(latest.project.document.layers.first { $0.id == otherID })
        let retried = await model.retryFailedDraft(projectID: id)
        XCTAssertEqual(retried, .saved)
        let restored = try XCTUnwrap(store.openProject(id: id))
        let target = try XCTUnwrap(restored.document.layers.first { $0.id == targetID })
        XCTAssertEqual(target.transform.translationX, 110)
        XCTAssertEqual(target.transform.translationY, 220)
        XCTAssertEqual(target.transform.scale, 2)
        XCTAssertEqual(target.transform.rotationRadians, 0.7)
        XCTAssertEqual(restored.document.layers.first { $0.id == otherID }, untouched)
        XCTAssertEqual(restored.name, "Newer name")
        XCTAssertEqual(store.photos(for: id), latest.photos)
        let onDisk = try JSONDecoder().decode(ProjectPackage.self, from: Data(contentsOf: manifestURL(id)))
        XCTAssertEqual(onDisk.project, restored)
    }

    @MainActor
    func testWholeGestureCommitsOnceAndCancelledCallbackCannotOverwriteNewGesture() async throws {
        let library = makeLibrary()
        var committed = try await importedPhotoPackage(library: library).package
        let id = committed.project.id
        let assetID = try XCTUnwrap(committed.photos.first?.asset.id)
        let document = try CanvasEditor.addingLayer(assetID: assetID, baseSize: CanvasSize(width: 100, height: 100), to: committed.project.document)
        committed = try await library.saveEdit(document: document, into: committed, at: Date()).package
        let layerID = try XCTUnwrap(document.layers.first?.id)
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let cancelled = try XCTUnwrap(model.beginCanvasGesture(projectID: id))
        model.cancelCanvasGesture(id: cancelled)
        let active = try XCTUnwrap(model.beginCanvasGesture(projectID: id))
        let late = await model.commitCanvasGesture(id: cancelled, projectID: id, layerID: layerID, transform: .identity)
        XCTAssertEqual(late, .busy)
        XCTAssertEqual(model.canvasGestureID, active)
        let final = LayerTransform(translationX: 321, translationY: 432, scale: 1.75, rotationRadians: 0.5)
        let saved = await model.commitCanvasGesture(id: active, projectID: id, layerID: layerID, transform: final)
        XCTAssertEqual(saved, .saved)
        XCTAssertFalse(model.isBusy)
        XCTAssertEqual(store.openProject(id: id)?.document.layers.first?.transform, final)
        let bytes = try Data(contentsOf: manifestURL(id))
        let repeated = await model.commitCanvasGesture(id: active, projectID: id, layerID: layerID, transform: .identity)
        XCTAssertEqual(repeated, .busy)
        XCTAssertEqual(try Data(contentsOf: manifestURL(id)), bytes)
    }

    @MainActor
    func testImportGateRejectsRestoreRemovalEditsAndGestures() async throws {
        let library = makeLibrary()
        let committed = try await importedPhotoPackage(library: library).package
        let id = committed.project.id
        let store = ProjectStore()
        store.apply(committed)
        let gate = TestGate()
        let source = try SyntheticImageFactory.writeFixture(in: fixturesURL, name: "gated.jpg", width: 100, height: 100)
        let model = PhotoImportModel(library: library, store: store, loadPhotoFile: { _ in
            await gate.wait()
            return source
        })
        let batch = Task {
            await model.importSelection([PhotosPickerItem(itemIdentifier: "gated")], projectID: id)
        }
        await gate.waitUntilEntered()
        XCTAssertTrue(model.isBusy)
        await model.restoreProjects()
        XCTAssertEqual(model.restoreState, .idle)
        await model.removePhoto(projectID: id, assetID: try XCTUnwrap(committed.photos.first?.asset.id))
        let blocked = await model.editCanvas(projectID: id) { $0 }
        XCTAssertEqual(blocked, .busy)
        XCTAssertNil(model.beginCanvasGesture(projectID: id))
        XCTAssertEqual(store.photos(for: id), committed.photos)
        await gate.open()
        await batch.value
        XCTAssertFalse(model.isBusy)
        XCTAssertEqual(store.photos(for: id).count, 2)
        let disk = try JSONDecoder().decode(ProjectPackage.self, from: Data(contentsOf: manifestURL(id)))
        XCTAssertEqual(store.openProject(id: id), disk.project)
        XCTAssertEqual(store.photos(for: id), disk.photos)
    }

    @MainActor
    func testGestureSaveFailureReleasesGateAndRetainsExactRetryableTransform() async throws {
        let library = makeLibrary()
        var committed = try await importedPhotoPackage(library: library).package
        let id = committed.id
        let document = try CanvasEditor.addingLayer(assetID: try XCTUnwrap(committed.photos.first?.id), baseSize: CanvasSize(width: 100, height: 100), to: committed.project.document)
        committed = try await library.saveEdit(document: document, into: committed, at: Date()).package
        let layerID = try XCTUnwrap(document.layers.first?.id)
        let bytes = try Data(contentsOf: manifestURL(id))
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let backup = try blockManifest(id)
        let gesture = try XCTUnwrap(model.beginCanvasGesture(projectID: id))
        let transform = LayerTransform(translationX: 150, translationY: 250, scale: 2, rotationRadians: 0.5)
        let outcome = await model.commitCanvasGesture(id: gesture, projectID: id, layerID: layerID, transform: transform)
        guard case .saveFailed = outcome else { return XCTFail("Expected real gesture write failure") }
        XCTAssertFalse(model.isBusy)
        XCTAssertFalse(model.isCanvasGestureActive)
        XCTAssertEqual(model.failedDraft(for: id)?.intent, .transform(transform))
        XCTAssertEqual(store.openProject(id: id), committed.project)
        XCTAssertEqual(try Data(contentsOf: manifestURL(id)), bytes)
        try unblockManifest(id, backup: backup)
        let retried = await model.retryFailedDraft(projectID: id)
        XCTAssertEqual(retried, .saved)
        XCTAssertEqual(store.openProject(id: id)?.document.layers.first?.transform, transform)
        XCTAssertNil(model.failedDraft(for: id))
    }

    func testSaveEditCannotReplaceCanvasIdentity() async throws {
        let library = makeLibrary()
        let committed = try await importedPhotoPackage(library: library).package
        let bytes = try Data(contentsOf: manifestURL(committed.id))
        let replacement = CanvasDocument(canvasSize: committed.project.document.canvasSize, layers: committed.project.document.layers)
        do {
            _ = try await library.saveEdit(document: replacement, into: committed, at: Date())
            XCTFail("An edit cannot replace the existing canvas identity")
        } catch {
            guard case .invalidPackage = error as? PhotoLibraryError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: manifestURL(committed.id)), bytes)
    }

    @MainActor
    func testExplicitSavePersistsAnEmptyProjectAndRestoresItsIdentity() async throws {
        let library = makeLibrary()
        let store = ProjectStore()
        let project = store.createProject()
        let model = PhotoImportModel(library: library, store: store)
        XCTAssertFalse(store.savedProjectIDs.contains(project.id))
        let result = await model.applyCanvasIntent(projectID: project.id, layerID: nil, intent: .save)
        XCTAssertEqual(result, .saved)
        XCTAssertTrue(store.savedProjectIDs.contains(project.id))
        let disk = try JSONDecoder().decode(ProjectPackage.self, from: Data(contentsOf: manifestURL(project.id)))
        XCTAssertEqual(disk.project.id, project.id)
        XCTAssertEqual(disk.project.document, project.document)
        XCTAssertEqual(disk.project.name, project.name)
        XCTAssertTrue(disk.photos.isEmpty)
        let restoredStore = ProjectStore()
        let restored = PhotoImportModel(library: makeLibrary(), store: restoredStore)
        await restored.restoreProjects()
        XCTAssertEqual(restoredStore.openProject(id: project.id), disk.project)
        XCTAssertTrue(restoredStore.savedProjectIDs.contains(project.id))
    }

    @MainActor
    func testExplicitSaveFailureKeepsCommittedBytesAndRetryableIntent() async throws {
        let library = makeLibrary()
        let committed = try await importedPhotoPackage(library: library).package
        let id = committed.id
        let bytes = try Data(contentsOf: manifestURL(id))
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let backup = try blockManifest(id)
        let result = await model.applyCanvasIntent(projectID: id, layerID: nil, intent: .save)
        guard case .saveFailed = result else { return XCTFail("Expected a real manifest save failure") }
        XCTAssertEqual(store.openProject(id: id), committed.project)
        XCTAssertEqual(try Data(contentsOf: manifestURL(id)), bytes)
        XCTAssertEqual(model.failedDraft(for: id)?.intent, .save)
        XCTAssertFalse(model.isBusy)
        try unblockManifest(id, backup: backup)
        let retried = await model.retryFailedDraft(projectID: id)
        XCTAssertEqual(retried, .saved)
        XCTAssertNil(model.failedDraft(for: id))
        let disk = try JSONDecoder().decode(ProjectPackage.self, from: Data(contentsOf: manifestURL(id)))
        XCTAssertEqual(store.openProject(id: id), disk.project)
        XCTAssertEqual(disk.project.document, committed.project.document)
        XCTAssertEqual(disk.photos, committed.photos)
    }
}
