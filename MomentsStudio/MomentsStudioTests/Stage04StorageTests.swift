import XCTest
@testable import MomentsStudio

/// Real files, atomic writes and the existing coordinator; no mocked saver.
final class Stage04StorageTests: XCTestCase {
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

    private func manifest(_ id: UUID) -> URL { rootURL.appendingPathComponent(PhotoLibraryPath.manifestReference(id)) }

    private func package(_ library: PhotoLibrary, name: String = "Layout") async throws -> ProjectPackage {
        var package = ProjectPackage(project: Project(name: name), photos: [])
        for (index, size) in [(320, 240), (240, 320)].enumerated() {
            let fixture = try SyntheticImageFactory.writeFixture(
                in: baseURL.appendingPathComponent("fixtures", isDirectory: true),
                name: "\(UUID().uuidString)-\(index).jpg", width: size.0, height: size.1
            )
            let staged = try await PhotoFileTransfer.stageCopy(of: fixture, rootURL: rootURL)
            package = try await library.importPhoto(fileURL: staged, into: package, at: Date()).package
        }
        return package
    }

    @MainActor
    func testApplyPersistsLayoutRestoresIdentityAndKeepsOriginalBytes() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let committed = try await package(library)
        let originalURLs = committed.photos.map { rootURL.appendingPathComponent($0.asset.localReference) }
        let originals = try originalURLs.map { try Data(contentsOf: $0) }
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let expected = try CollageLayout.arrange(.offset, document: committed.project.document, photos: committed.photos)
        let outcome = await model.applyCanvasIntent(projectID: committed.id, layerID: nil, intent: .layout(.offset))
        XCTAssertEqual(outcome, .saved)
        let saved = try JSONDecoder().decode(ProjectPackage.self, from: Data(contentsOf: manifest(committed.id)))
        XCTAssertEqual(saved.project.document, expected)
        XCTAssertEqual(saved.photos, committed.photos)
        XCTAssertEqual(saved.project.id, committed.project.id)
        XCTAssertEqual(try originalURLs.map { try Data(contentsOf: $0) }, originals)

        let restoredStore = ProjectStore()
        let restoredModel = PhotoImportModel(library: library, store: restoredStore)
        await restoredModel.restoreProjects()
        XCTAssertEqual(restoredStore.openProject(id: committed.id)?.document, expected)
        let repeated = await restoredModel.applyCanvasIntent(projectID: committed.id, layerID: nil, intent: .layout(.offset))
        XCTAssertEqual(repeated, .saved)
        XCTAssertEqual(restoredStore.openProject(id: committed.id)?.document, expected)
    }

    @MainActor
    func testFailedSaveKeepsCommittedBytesAndRetryPreservesNewerLockedLayer() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let empty = try await package(library)
        let initial = try CollageLayout.arrange(.grid, document: empty.project.document, photos: empty.photos)
        let committed = try await library.saveEdit(document: initial, into: empty, at: Date()).package
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let before = try Data(contentsOf: manifest(committed.id))
        let backup = baseURL.appendingPathComponent("retained.json")
        try FileManager.default.moveItem(at: manifest(committed.id), to: backup)
        try FileManager.default.createSymbolicLink(at: manifest(committed.id), withDestinationURL: backup)
        let failed = await model.applyCanvasIntent(projectID: committed.id, layerID: nil, intent: .layout(.focus))
        guard case .saveFailed = failed else { return XCTFail("Expected actual manifest write failure, got \(failed)") }
        XCTAssertEqual(store.openProject(id: committed.id), committed.project)
        XCTAssertEqual(try Data(contentsOf: backup), before)
        XCTAssertEqual(try Data(contentsOf: manifest(committed.id)), before)
        XCTAssertEqual(model.failedDraft(for: committed.id)?.intent, .layout(.focus))
        try FileManager.default.removeItem(at: manifest(committed.id))
        try FileManager.default.moveItem(at: backup, to: manifest(committed.id))

        var newer = initial
        newer.layers[0].isLocked = true
        newer.layers[0].transform = LayerTransform(translationX: 111, translationY: 222, scale: 0.5, rotationRadians: 0.3)
        let latest = try await library.saveEdit(document: newer, into: committed, at: Date()).package
        store.apply(latest)
        let retried = await model.retryFailedDraft(projectID: committed.id)
        XCTAssertEqual(retried, .saved)
        XCTAssertNil(model.failedDraft(for: committed.id))
        let saved = try JSONDecoder().decode(ProjectPackage.self, from: Data(contentsOf: manifest(committed.id)))
        XCTAssertEqual(saved.project.document.layers[0], newer.layers[0])
        XCTAssertEqual(saved.project.document, try CollageLayout.arrange(.focus, document: newer, photos: latest.photos))
        XCTAssertEqual(store.openProject(id: committed.id), saved.project)
    }

    @MainActor
    func testGestureAndCrossProjectDraftCannotApplyLayout() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let first = try await package(library, name: "A")
        let second = try await package(library, name: "B")
        let store = ProjectStore()
        store.restore([first, second])
        let model = PhotoImportModel(library: library, store: store)
        let beforeA = try Data(contentsOf: manifest(first.id))
        let beforeB = try Data(contentsOf: manifest(second.id))
        let gesture = try XCTUnwrap(model.beginCanvasGesture(projectID: first.id))
        let busy = await model.applyCanvasIntent(projectID: first.id, layerID: nil, intent: .layout(.grid))
        XCTAssertEqual(busy, .busy)
        model.cancelCanvasGesture(id: gesture)
        let wrong = PhotoImportModel.CanvasDraft(projectID: second.id, layerID: nil, intent: .layout(.grid))
        let rejected = await model.editCanvas(projectID: first.id, intent: wrong) { $0 }
        guard case .rejected = rejected else { return XCTFail("Cross-project draft was not rejected") }
        XCTAssertEqual(try Data(contentsOf: manifest(first.id)), beforeA)
        XCTAssertEqual(try Data(contentsOf: manifest(second.id)), beforeB)
        XCTAssertNil(model.failedDraft(for: first.id))
    }

    @MainActor
    func testInvalidLayoutIsRejectedWithoutWritingOrCreatingFailedSaveDraft() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let store = ProjectStore()
        let project = store.createProject(name: "No photos")
        let model = PhotoImportModel(library: library, store: store)
        let rejected = await model.applyCanvasIntent(projectID: project.id, layerID: nil, intent: .layout(.grid))
        guard case .rejected = rejected else { return XCTFail("No-photo layout should be validation rejection") }
        XCTAssertNil(model.failedDraft(for: project.id))
        XCTAssertEqual(store.openProject(id: project.id), project)
        XCTAssertFalse(FileManager.default.fileExists(atPath: manifest(project.id).path))
        XCTAssertNotNil(model.editMessage(for: project.id))
    }
}
