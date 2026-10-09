import XCTest
@testable import MomentsStudio

/// Real files, the real library actor and the read-only coordinator bridge.
///
/// Nothing here mocks the analyzer: each case imports synthetic fixtures through
/// the production pipeline and checks the value that comes back, the byte-level
/// guarantee that analysis writes nothing, typed failures, cancellation and
/// project isolation.
final class Stage05AnalysisStorageTests: XCTestCase {
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

    /// Imports two synthetic photos; the first half of the fixture is red, the
    /// second blue, and `orientation` is only written to the first photo's tag.
    private func makePackage(
        _ library: PhotoLibrary,
        name: String = "Analysis",
        orientation: Int? = nil
    ) async throws -> ProjectPackage {
        var package = ProjectPackage(project: Project(name: name), photos: [])
        for (index, size) in [(320, 240), (240, 320)].enumerated() {
            let fixture = try SyntheticImageFactory.writeFixture(
                in: baseURL.appendingPathComponent("fixtures", isDirectory: true),
                name: "\(UUID().uuidString)-\(index).jpg",
                width: size.0,
                height: size.1,
                orientation: index == 0 ? orientation : nil
            )
            let staged = try await PhotoFileTransfer.stageCopy(of: fixture, rootURL: rootURL)
            package = try await library.importPhoto(fileURL: staged, into: package, at: Date()).package
        }
        return package
    }

    private func bytes(_ urls: [URL]) throws -> [Data] {
        try urls.map { try Data(contentsOf: $0) }
    }

    @MainActor
    func testAnalyzeRealThumbnailReportsStatsAndWritesNothing() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let committed = try await makePackage(library)
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let photo = committed.photos[0]

        let manifestURL = manifest(committed.id)
        let originalURL = rootURL.appendingPathComponent(photo.asset.localReference)
        let thumbnailURL = rootURL.appendingPathComponent(photo.thumbnailReference)
        let before = try bytes([manifestURL, originalURL, thumbnailURL])

        let analysis = try await model.analyzePhoto(projectID: committed.id, assetID: photo.asset.id)

        XCTAssertEqual(analysis.assetID, photo.asset.id)
        XCTAssertEqual(analysis.displayWidth, 320)
        XCTAssertEqual(analysis.displayHeight, 240)
        XCTAssertEqual(max(analysis.sampleWidth, analysis.sampleHeight), PhotoAnalyzer.maximumSampleSide)
        XCTAssertGreaterThan(analysis.sampleWidth, analysis.sampleHeight)
        XCTAssertEqual(analysis.totalPixelCount, analysis.sampleWidth * analysis.sampleHeight)
        XCTAssertEqual(analysis.validPixelCount, analysis.totalPixelCount)
        XCTAssertEqual(analysis.coverage, 1, accuracy: 1e-9)
        XCTAssertEqual(analysis.confidence, .adequate)
        // Left half red, right half blue (JPEG keeps both channels well above zero).
        XCTAssertGreaterThan(analysis.meanRed, 0.25)
        XCTAssertGreaterThan(analysis.meanBlue, 0.25)
        XCTAssertGreaterThan(analysis.meanLuminance, 0)
        XCTAssertLessThan(analysis.meanLuminance, 1)

        XCTAssertEqual(try bytes([manifestURL, originalURL, thumbnailURL]), before,
                       "Analysis must not rewrite the manifest, the original or the derivative")
        XCTAssertNil(model.failedDraft(for: committed.id))
        XCTAssertEqual(store.openProject(id: committed.id), committed.project)
    }

    @MainActor
    func testAnalyzeUsesExifCorrectedDisplaySize() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let committed = try await makePackage(library, name: "Rotated", orientation: 6)
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let photo = try XCTUnwrap(committed.photos.first)
        XCTAssertEqual(photo.orientation, 6)
        XCTAssertEqual(photo.displayPixelSize.width, 240)
        XCTAssertEqual(photo.displayPixelSize.height, 320)

        let analysis = try await model.analyzePhoto(projectID: committed.id, assetID: photo.asset.id)
        XCTAssertEqual(analysis.displayWidth, 240)
        XCTAssertEqual(analysis.displayHeight, 320)
        // The derivative is built with the orientation applied, so the sample is portrait.
        XCTAssertGreaterThan(analysis.sampleHeight, analysis.sampleWidth)
    }

    @MainActor
    func testMissingThumbnailFailsTypedAndDoesNotBlockOtherPhotos() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let committed = try await makePackage(library, name: "Isolation")
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let first = committed.photos[0]
        let second = committed.photos[1]
        try FileManager.default.removeItem(at: rootURL.appendingPathComponent(first.thumbnailReference))

        do {
            _ = try await model.analyzePhoto(projectID: committed.id, assetID: first.asset.id)
            XCTFail("A missing thumbnail must be reported, not analyzed")
        } catch let failure as PhotoAnalysisFailure {
            XCTAssertEqual(failure, .unreadable)
        }

        let other = try await model.analyzePhoto(projectID: committed.id, assetID: second.asset.id)
        XCTAssertEqual(other.assetID, second.asset.id)
        XCTAssertEqual(other.confidence, .adequate)
        XCTAssertEqual(store.openProject(id: committed.id), committed.project)
    }

    @MainActor
    func testUnknownAssetIsMissingAndProjectsDoNotShareResults() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let first = try await makePackage(library, name: "A")
        let second = try await makePackage(library, name: "B")
        let store = ProjectStore()
        store.restore([first, second])
        let model = PhotoImportModel(library: library, store: store)
        let beforeA = try Data(contentsOf: manifest(first.id))
        let beforeB = try Data(contentsOf: manifest(second.id))

        for assetID in [UUID(), second.photos[0].asset.id] {
            do {
                _ = try await model.analyzePhoto(projectID: first.id, assetID: assetID)
                XCTFail("An asset outside project A must not be analyzed through project A")
            } catch let failure as PhotoAnalysisFailure {
                XCTAssertEqual(failure, .missing)
            }
        }

        let own = try await model.analyzePhoto(projectID: second.id, assetID: second.photos[0].asset.id)
        XCTAssertEqual(own.assetID, second.photos[0].asset.id)
        XCTAssertEqual(try Data(contentsOf: manifest(first.id)), beforeA)
        XCTAssertEqual(try Data(contentsOf: manifest(second.id)), beforeB)
    }

    @MainActor
    func testCancellationPropagatesInsteadOfReturningAFailure() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let committed = try await makePackage(library, name: "Cancelled")
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let assetID = committed.photos[0].asset.id

        let task = Task { @MainActor () -> Error? in
            try? await Task.sleep(nanoseconds: 50_000_000)
            do {
                _ = try await model.analyzePhoto(projectID: committed.id, assetID: assetID)
                return nil
            } catch {
                return error
            }
        }
        task.cancel()
        let error = await task.value
        XCTAssertTrue(error is CancellationError,
                      "Cancellation must propagate, got \(String(describing: error))")
        XCTAssertFalse(error is PhotoAnalysisFailure, "Cancellation is not an ordinary bad-photo result")
    }

    @MainActor
    func testThumbnailSymlinkIsRejectedAndNothingChanges() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let committed = try await makePackage(library, name: "Symlink")
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let first = committed.photos[0]
        let second = committed.photos[1]
        let manifestURL = manifest(committed.id)
        let thumbnailURL = rootURL.appendingPathComponent(first.thumbnailReference)
        let originalURL = rootURL.appendingPathComponent(first.asset.localReference)
        let outside = baseURL.appendingPathComponent("outside.jpg")
        try FileManager.default.copyItem(at: thumbnailURL, to: outside)
        let outsideBefore = try Data(contentsOf: outside)
        let manifestBefore = try Data(contentsOf: manifestURL)
        let originalBefore = try Data(contentsOf: originalURL)

        // Replace the generated thumbnail with a symlink that points outside the
        // library: the real path guard must refuse to follow it.
        try FileManager.default.removeItem(at: thumbnailURL)
        try FileManager.default.createSymbolicLink(at: thumbnailURL, withDestinationURL: outside)

        do {
            _ = try await model.analyzePhoto(projectID: committed.id, assetID: first.asset.id)
            XCTFail("A symlinked thumbnail must be rejected by the path guard")
        } catch let failure as PhotoAnalysisFailure {
            XCTAssertEqual(failure, .unreadable)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: thumbnailURL.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink,
                       "The rejected path must stay untouched")
        XCTAssertEqual(try Data(contentsOf: outside), outsideBefore, "Nothing may be read or written through the link")
        XCTAssertEqual(try Data(contentsOf: manifestURL), manifestBefore)
        XCTAssertEqual(try Data(contentsOf: originalURL), originalBefore)

        let other = try await model.analyzePhoto(projectID: committed.id, assetID: second.asset.id)
        XCTAssertEqual(other.assetID, second.asset.id)
    }

    func testPathGuardRejectsReferencesThatEscapeTheLibrary() throws {
        // Direct regression for the guard the analysis path goes through: a
        // generated reference may not escape the library by relative traversal,
        // absolute path or a backslash, while a normal reference still resolves.
        for reference in ["../outside.jpg", "/etc/hosts", "assets\\escape.jpg"] {
            do {
                _ = try PhotoLibraryPathGuard.resolve(reference, below: rootURL, label: reference,
                                                      fileManager: .default)
                XCTFail("\(reference) must be rejected")
            } catch let error as PhotoLibraryError {
                XCTAssertEqual(error, .invalidReference(reference))
            }
        }
        let resolved = try PhotoLibraryPathGuard.resolve(
            PhotoLibraryPath.manifestReference(UUID()), below: rootURL, label: "manifest",
            fileManager: .default
        )
        XCTAssertTrue(resolved.path.hasPrefix(rootURL.path))
    }

    @MainActor
    func testAnalysisDoesNotTakeTheMutationGateOrWriteDraftState() async throws {
        let library = PhotoLibrary(rootURL: rootURL)
        let committed = try await makePackage(library, name: "Gated")
        let store = ProjectStore()
        store.apply(committed)
        let model = PhotoImportModel(library: library, store: store)
        let manifestURL = manifest(committed.id)
        let before = try Data(contentsOf: manifestURL)

        let gesture = try XCTUnwrap(model.beginCanvasGesture(projectID: committed.id))
        XCTAssertTrue(model.isBusy)

        let analysis = try await model.analyzePhoto(projectID: committed.id, assetID: committed.photos[0].asset.id)
        XCTAssertEqual(analysis.assetID, committed.photos[0].asset.id)
        XCTAssertTrue(model.isBusy, "Analysis must not release or consume the canvas gesture gate")
        XCTAssertNil(model.failedDraft(for: committed.id))
        XCTAssertNil(model.editMessage(for: committed.id))
        XCTAssertEqual(try Data(contentsOf: manifestURL), before)

        model.cancelCanvasGesture(id: gesture)
        XCTAssertFalse(model.isBusy)
    }
}
