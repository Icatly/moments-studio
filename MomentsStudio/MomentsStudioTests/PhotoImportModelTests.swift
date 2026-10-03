import CoreGraphics
import Foundation
import PhotosUI
import UniformTypeIdentifiers
import XCTest
@testable import MomentsStudio

/// Coordinator-level tests for the Stage 02 import orchestration.
///
/// `PhotosPickerItem(itemIdentifier:)` is constructible in tests, and item 6 of
/// the authorised fix approves a narrow injected file-loader closure, so a batch
/// can be driven deterministically with synthetic files. The real photo library
/// is never asked about a synthetic identifier: production's loader is the only
/// code that calls `loadTransferable`, and these tests replace it. No service
/// protocol, mock repository, production test button or second scheduler is
/// involved.
final class PhotoImportModelTests: XCTestCase {
    private var baseURL: URL!
    private var rootURL: URL!
    private var fixturesURL: URL!

    override func setUpWithError() throws {
        baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MomentsStudioModelTests-\(UUID().uuidString)", isDirectory: true)
        rootURL = baseURL.appendingPathComponent("Library", isDirectory: true)
        fixturesURL = baseURL.appendingPathComponent("Fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fixturesURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let baseURL {
            try? FileManager.default.removeItem(at: baseURL)
        }
    }

    // MARK: - Helpers

    private func makeFixture(named name: String, width: Int = 120, height: Int = 90) throws -> URL {
        try SyntheticImageFactory.writeFixture(in: fixturesURL, name: name, width: width, height: height)
    }

    private func makeEmptyPackage(projectID: UUID, name: String) -> ProjectPackage {
        ProjectPackage(project: Project(id: projectID, name: name, createdAt: Date()), photos: [])
    }

    @MainActor
    func testRestoreMergesSavedPackagesIntoTheStore() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let store = ProjectStore()
        let model = PhotoImportModel(library: library, store: store)

        await model.restoreProjects()
        XCTAssertEqual(model.restoreState, .ready)
        XCTAssertTrue(store.projects.isEmpty, "an empty library must not invent projects")

        // Commit a package through the library, then restore a fresh store.
        let source = try makeFixture(named: "saved.jpg")
        let projectID = UUID()
        _ = try await library.importPhoto(
            fileURL: source,
            into: makeEmptyPackage(projectID: projectID, name: "Saved"),
            at: Date()
        )

        let restoredStore = ProjectStore()
        let restoredModel = PhotoImportModel(library: library, store: restoredStore)
        await restoredModel.restoreProjects()

        XCTAssertEqual(restoredStore.projects.map(\.id), [projectID])
        XCTAssertEqual(restoredStore.photos(for: projectID).count, 1)
        XCTAssertEqual(restoredStore.savedProjectIDs, [projectID])
        XCTAssertTrue(restoredModel.isReady)
    }

    // MARK: - Import batches (item 6)

    @MainActor
    func testImportBatchRunsThroughTheInjectedLoaderAndMatchesDisk() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let store = ProjectStore()
        let fixture = try makeFixture(named: "batch.jpg")
        let root: URL = rootURL

        let model = PhotoImportModel(library: library, store: store) { _ in
            try await PhotoFileTransfer.stageCopy(of: fixture, rootURL: root)
        }

        let projectID = UUID()
        store.apply(makeEmptyPackage(projectID: projectID, name: "Batch"))

        let items = [
            PhotosPickerItem(itemIdentifier: "synthetic-1"),
            PhotosPickerItem(itemIdentifier: "synthetic-2"),
        ]
        await model.importSelection(items, projectID: projectID)

        XCTAssertEqual(store.photos(for: projectID).count, 2)
        XCTAssertEqual(model.completedCount, 2)
        XCTAssertEqual(model.totalCount, 2)
        XCTAssertTrue(model.itemErrors.isEmpty, "unexpected errors: \(model.itemErrors)")
        XCTAssertFalse(model.isImporting)
        XCTAssertFalse(model.isBusy)

        // Store and disk agree, and the staging area was cleaned again.
        let restored = try await library.restore()
        XCTAssertEqual(restored.packages.count, 1)
        XCTAssertEqual(restored.packages.first?.photos.count, 2)
        XCTAssertTrue(restored.warnings.isEmpty, "unexpected warnings: \(restored.warnings)")

        let staging = rootURL.appendingPathComponent(PhotoLibraryLocation.stagingDirectoryName, isDirectory: true)
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: staging.path)) ?? []
        XCTAssertTrue(leftovers.isEmpty, "staging must be clean after a batch: \(leftovers)")
    }

    @MainActor
    func testRemovalIsRefusedWhileAnImportBatchIsRunning() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let store = ProjectStore()
        let fixture = try makeFixture(named: "during.jpg")
        let root: URL = rootURL
        let gate = TestGate()

        let model = PhotoImportModel(library: library, store: store) { _ in
            await gate.wait()
            return try await PhotoFileTransfer.stageCopy(of: fixture, rootURL: root)
        }

        // One already committed photo, so there is something to remove.
        let projectID = UUID()
        let committed = try await library.importPhoto(
            fileURL: fixture,
            into: makeEmptyPackage(projectID: projectID, name: "During"),
            at: Date()
        ).package
        store.apply(committed)
        let existingAssetID = try XCTUnwrap(committed.photos.first).asset.id

        let importTask = Task {
            await model.importSelection(
                [PhotosPickerItem(itemIdentifier: "synthetic-during")],
                projectID: projectID
            )
        }

        await gate.waitUntilEntered()
        XCTAssertEqual(model.importingProjectID, projectID, "the batch must be in flight")
        XCTAssertTrue(model.isBusy)

        // The single-operation guard must refuse the removal instead of applying
        // a value built from the same stale snapshot.
        await model.removePhoto(projectID: projectID, assetID: existingAssetID)
        XCTAssertEqual(store.photos(for: projectID).count, 1, "the removal must not have run")
        XCTAssertEqual(model.itemErrors.count, 1, "the refusal must be reported")

        await gate.open()
        await importTask.value

        XCTAssertEqual(store.photos(for: projectID).count, 2, "the batch must still commit its photo")
        XCTAssertTrue(
            store.photos(for: projectID).contains { $0.asset.id == existingAssetID },
            "the existing photo must survive"
        )

        let restored = try await library.restore()
        XCTAssertEqual(restored.packages.first?.photos.count, 2, "store and disk must agree")
    }

    @MainActor
    func testSecondImportBatchIsRefusedWhileTheFirstIsRunning() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let store = ProjectStore()
        let fixture = try makeFixture(named: "second.jpg")
        let root: URL = rootURL
        let gate = TestGate()

        let model = PhotoImportModel(library: library, store: store) { _ in
            await gate.wait()
            return try await PhotoFileTransfer.stageCopy(of: fixture, rootURL: root)
        }

        let projectID = UUID()
        store.apply(makeEmptyPackage(projectID: projectID, name: "Second"))

        let firstBatch = Task {
            await model.importSelection(
                [PhotosPickerItem(itemIdentifier: "synthetic-first")],
                projectID: projectID
            )
        }
        await gate.waitUntilEntered()

        // A second batch is refused while the first holds the mutation token.
        await model.importSelection(
            [PhotosPickerItem(itemIdentifier: "synthetic-second")],
            projectID: projectID
        )

        await gate.open()
        await firstBatch.value

        XCTAssertEqual(store.photos(for: projectID).count, 1, "only the first batch may commit")
        let restored = try await library.restore()
        XCTAssertEqual(restored.packages.first?.photos.count, 1)
    }

    @MainActor
    func testConcurrentRemovalsAreSerialised() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let store = ProjectStore()
        let model = PhotoImportModel(library: library, store: store)

        let source = try makeFixture(named: "two.jpg")
        let projectID = UUID()
        var package = makeEmptyPackage(projectID: projectID, name: "Two photos")
        package = try await library.importPhoto(fileURL: source, into: package, at: Date()).package
        package = try await library.importPhoto(fileURL: source, into: package, at: Date()).package
        store.apply(package)

        let first = try XCTUnwrap(package.photos.first).asset.id
        let second = try XCTUnwrap(package.photos.last).asset.id

        async let removalA: Void = model.removePhoto(projectID: projectID, assetID: first)
        async let removalB: Void = model.removePhoto(projectID: projectID, assetID: second)
        _ = await (removalA, removalB)

        XCTAssertEqual(store.photos(for: projectID).count, 1, "only one removal may be applied")
        XCTAssertEqual(model.itemErrors.count, 1, "the second removal is refused while the first runs")

        // The store must still agree with what is on disk.
        let restored = try await library.restore()
        XCTAssertEqual(restored.packages.count, 1)
        XCTAssertEqual(
            store.photos(for: projectID).count,
            restored.packages.first?.photos.count,
            "store and disk must not diverge"
        )
    }

    @MainActor
    func testRemovingAnUnknownPhotoReportsAnErrorAndLeavesDiskAlone() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let store = ProjectStore()
        let model = PhotoImportModel(library: library, store: store)

        let source = try makeFixture(named: "known.jpg", width: 100, height: 70)
        let projectID = UUID()
        let committed = try await library.importPhoto(
            fileURL: source,
            into: makeEmptyPackage(projectID: projectID, name: "Known"),
            at: Date()
        ).package
        store.apply(committed)

        await model.removePhoto(projectID: projectID, assetID: UUID())

        XCTAssertEqual(store.photos(for: projectID).count, 1)
        XCTAssertEqual(model.itemErrors.count, 1)

        let restored = try await library.restore()
        XCTAssertEqual(restored.packages.first?.photos.count, 1)
    }
}
