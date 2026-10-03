import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import MomentsStudio

/// Behavioural tests for the Stage 02 photo library: real files in a temporary
/// root, generated fixtures, no network and no private photos.
final class PhotoLibraryTests: XCTestCase {
    private var baseURL: URL!
    private var rootURL: URL!
    private var fixturesURL: URL!

    override func setUpWithError() throws {
        baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MomentsStudioPhotoTests-\(UUID().uuidString)", isDirectory: true)
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

    private func makeLibrary(limits: PhotoLibraryLimits = .standard) -> PhotoLibrary {
        PhotoLibrary(rootURL: rootURL, limits: limits)
    }

    private func makePackage(projectID: UUID = UUID(), photos: [ImportedPhoto] = []) -> ProjectPackage {
        ProjectPackage(
            project: Project(
                id: projectID,
                name: "Library test",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            photos: photos
        )
    }

    private func projectDirectory(_ projectID: UUID) -> URL {
        rootURL.appendingPathComponent(PhotoLibraryPath.projectReference(projectID), isDirectory: true)
    }

    private func assetDirectory(_ projectID: UUID, _ assetID: UUID) -> URL {
        rootURL.appendingPathComponent(
            PhotoLibraryPath.assetDirectoryReference(projectID, assetID: assetID),
            isDirectory: true
        )
    }

    private func assetDirectoryNames(_ projectID: UUID) throws -> [String] {
        let url = projectDirectory(projectID).appendingPathComponent(PhotoLibraryPath.assetsDirectoryName)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
    }

    private func assertImportFails(
        _ library: PhotoLibrary,
        fileURL: URL,
        into package: ProjectPackage? = nil,
        check: (PhotoLibraryError) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await library.importPhoto(fileURL: fileURL, into: package ?? makePackage(), at: Date())
            XCTFail("expected the import to fail", file: file, line: line)
        } catch let error as PhotoLibraryError {
            check(error)
        } catch {
            XCTFail("expected PhotoLibraryError, got \(error)", file: file, line: line)
        }
    }

    // MARK: - Import

    func testImportWritesOriginalThumbnailAndPreviewAndKeepsOriginalBytes() async throws {
        let library = makeLibrary()
        let package = makePackage()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "wide.jpg",
            width: 1600,
            height: 1200
        )
        // Captured before the import so the test can prove the received file was
        // not re-encoded, truncated or written back.
        let sourceBytes = try Data(contentsOf: source)

        let result = try await library.importPhoto(fileURL: source, into: package, at: Date())

        XCTAssertEqual(result.package.photos.count, 1)
        let photo = try XCTUnwrap(result.package.photos.first)
        XCTAssertEqual(photo.contentType, UTType.jpeg.identifier)
        XCTAssertEqual(photo.pixelWidth, 1600)
        XCTAssertEqual(photo.pixelHeight, 1200)
        XCTAssertEqual(photo.orientation, 1)
        XCTAssertEqual(
            photo.thumbnailReference,
            PhotoLibraryPath.derivativeReference(
                .thumbnail,
                projectID: package.id,
                assetID: photo.asset.id,
                fileExtension: "jpg"
            )
        )
        XCTAssertEqual(
            photo.previewReference,
            PhotoLibraryPath.derivativeReference(
                .preview,
                projectID: package.id,
                assetID: photo.asset.id,
                fileExtension: "jpg"
            )
        )

        for reference in [photo.asset.localReference, photo.thumbnailReference, photo.previewReference] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(reference).path),
                "missing \(reference)"
            )
        }

        XCTAssertEqual(
            try Data(contentsOf: rootURL.appendingPathComponent(photo.asset.localReference)),
            sourceBytes,
            "the stored original must be a byte-for-byte copy of the received file"
        )
        XCTAssertEqual(
            try Data(contentsOf: source),
            sourceBytes,
            "the received source file must not be modified by the import"
        )

        let thumbnail = try await library.loadDerivedImage(reference: photo.thumbnailReference)
        XCTAssertEqual(max(thumbnail.width, thumbnail.height), 320)
        let preview = try await library.loadDerivedImage(reference: photo.previewReference)
        XCTAssertEqual(max(preview.width, preview.height), 1600)
        XCTAssertGreaterThan(preview.width, thumbnail.width)
    }

    func testImportDoesNotUpscaleSmallImages() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "small.png",
            width: 100,
            height: 80,
            typeIdentifier: UTType.png.identifier
        )

        let result = try await library.importPhoto(fileURL: source, into: makePackage(), at: Date())
        let photo = try XCTUnwrap(result.package.photos.first)

        let thumbnail = try await library.loadDerivedImage(reference: photo.thumbnailReference)
        XCTAssertEqual(thumbnail.width, 100)
        XCTAssertEqual(thumbnail.height, 80)

        let preview = try await library.loadDerivedImage(reference: photo.previewReference)
        XCTAssertEqual(preview.width, 100)
        XCTAssertEqual(preview.height, 80)
    }

    func testImportAppliesOrientationTransformIncludingMirroring() async throws {
        let library = makeLibrary()

        // Orientation 6 rotates by 90 degrees, so the display size swaps.
        let rotated = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "rotated.jpg",
            width: 200,
            height: 100,
            orientation: 6
        )
        let rotatedResult = try await library.importPhoto(fileURL: rotated, into: makePackage(), at: Date())
        let rotatedPhoto = try XCTUnwrap(rotatedResult.package.photos.first)
        XCTAssertEqual(rotatedPhoto.orientation, 6)
        XCTAssertEqual(rotatedPhoto.displayPixelSize.width, 100)
        XCTAssertEqual(rotatedPhoto.displayPixelSize.height, 200)

        let rotatedThumbnail = try await library.loadDerivedImage(reference: rotatedPhoto.thumbnailReference)
        XCTAssertEqual(rotatedThumbnail.width, 100)
        XCTAssertEqual(rotatedThumbnail.height, 200)

        // Orientation 2 mirrors horizontally: the pixels themselves must move,
        // not just the metadata.
        let mirrored = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "mirrored.jpg",
            width: 200,
            height: 100,
            orientation: 2
        )
        let mirroredResult = try await library.importPhoto(fileURL: mirrored, into: makePackage(), at: Date())
        let mirroredPhoto = try XCTUnwrap(mirroredResult.package.photos.first)

        let mirroredThumbnail = try await library.loadDerivedImage(reference: mirroredPhoto.thumbnailReference)
        let left = try SyntheticImageFactory.averageColor(of: mirroredThumbnail, leftHalf: true)
        let right = try SyntheticImageFactory.averageColor(of: mirroredThumbnail, leftHalf: false)

        XCTAssertGreaterThan(left.blue, left.red, "a mirrored image shows the source's right half on the left")
        XCTAssertGreaterThan(right.red, right.blue, "a mirrored image shows the source's left half on the right")
    }

    func testImportKeepsTransparencyAsPNGAndUsesJPEGOtherwise() async throws {
        let library = makeLibrary()

        let alphaSource = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "alpha.png",
            width: 120,
            height: 90,
            typeIdentifier: UTType.png.identifier,
            hasAlpha: true
        )

        // The fixture itself must really carry transparency, otherwise the
        // derivative assertions below would be vacuous.
        let fixtureStats = try SyntheticImageFactory.alphaStats(
            of: try SyntheticImageFactory.readImage(at: alphaSource)
        )
        XCTAssertTrue(fixtureStats.hasTransparency, "the PNG fixture must contain fully transparent pixels")
        XCTAssertGreaterThan(fixtureStats.semitransparent, 0, "the PNG fixture must contain semi-transparent pixels")

        let alphaResult = try await library.importPhoto(fileURL: alphaSource, into: makePackage(), at: Date())
        let alphaPhoto = try XCTUnwrap(alphaResult.package.photos.first)
        XCTAssertTrue(alphaPhoto.asset.localReference.hasSuffix(".png"))
        XCTAssertTrue(alphaPhoto.thumbnailReference.hasSuffix(".png"))
        XCTAssertTrue(alphaPhoto.previewReference.hasSuffix(".png"))

        // Pixel alpha must survive, not just the file extension.
        let thumbnailStats = try SyntheticImageFactory.alphaStats(
            of: try await library.loadDerivedImage(reference: alphaPhoto.thumbnailReference)
        )
        XCTAssertTrue(thumbnailStats.hasTransparency, "the thumbnail must keep fully transparent pixels")
        XCTAssertGreaterThan(thumbnailStats.semitransparent, 0, "the thumbnail must keep semi-transparent pixels")

        let previewStats = try SyntheticImageFactory.alphaStats(
            of: try await library.loadDerivedImage(reference: alphaPhoto.previewReference)
        )
        XCTAssertTrue(previewStats.hasTransparency, "the preview must keep fully transparent pixels")

        let opaqueSource = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "opaque.jpg",
            width: 120,
            height: 90
        )
        let opaqueResult = try await library.importPhoto(fileURL: opaqueSource, into: makePackage(), at: Date())
        let opaquePhoto = try XCTUnwrap(opaqueResult.package.photos.first)
        XCTAssertTrue(opaquePhoto.thumbnailReference.hasSuffix(".jpg"))
        XCTAssertTrue(opaquePhoto.previewReference.hasSuffix(".jpg"))

        // The JPEG path carries no transparency at all.
        let opaqueStats = try SyntheticImageFactory.alphaStats(
            of: try await library.loadDerivedImage(reference: opaquePhoto.thumbnailReference)
        )
        XCTAssertEqual(opaqueStats.transparent, 0)
        XCTAssertEqual(opaqueStats.semitransparent, 0)
    }

    func testImportRejectsFilesThatAreNotImages() async throws {
        let library = makeLibrary()
        let textURL = fixturesURL.appendingPathComponent("notes.txt")
        try Data("this is not an image".utf8).write(to: textURL)

        await assertImportFails(library, fileURL: textURL) { error in
            guard case .unreadableImage = error else {
                return XCTFail("expected unreadableImage, got \(error)")
            }
        }
    }

    func testImportRejectsUnsupportedImageTypes() async throws {
        let library = makeLibrary()
        // A GIF is a real image container that this stage does not accept.
        let gifURL = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "animated.gif",
            width: 60,
            height: 60,
            typeIdentifier: UTType.gif.identifier
        )

        await assertImportFails(library, fileURL: gifURL) { error in
            guard case .unsupportedImageType = error else {
                return XCTFail("expected unsupportedImageType, got \(error)")
            }
        }
    }

    func testImportRejectsFilesAboveTheByteLimitWithoutCreatingAssets() async throws {
        var limits = PhotoLibraryLimits.standard
        limits.maxSourceBytes = 512
        let library = makeLibrary(limits: limits)
        let package = makePackage()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "over-limit.jpg",
            width: 800,
            height: 600
        )

        await assertImportFails(library, fileURL: source, into: package) { error in
            guard case .fileTooLarge(let limitBytes, let actualBytes) = error else {
                return XCTFail("expected fileTooLarge, got \(error)")
            }
            XCTAssertEqual(limitBytes, 512)
            XCTAssertGreaterThan(actualBytes, 512)
        }
        XCTAssertTrue(try assetDirectoryNames(package.id).isEmpty)
    }

    func testImportRejectsImagesAboveThePixelLimit() async throws {
        var limits = PhotoLibraryLimits.standard
        limits.maxSourcePixels = 1_000
        let library = makeLibrary(limits: limits)
        let package = makePackage()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "many-pixels.jpg",
            width: 200,
            height: 200
        )

        await assertImportFails(library, fileURL: source, into: package) { error in
            guard case .tooManyPixels(let limit, let actualPixels) = error else {
                return XCTFail("expected tooManyPixels, got \(error)")
            }
            XCTAssertEqual(limit, 1_000)
            XCTAssertEqual(actualPixels, 40_000)
        }
        XCTAssertTrue(try assetDirectoryNames(package.id).isEmpty)
    }

    func testImportEnforcesTheProjectPhotoLimit() async throws {
        var limits = PhotoLibraryLimits.standard
        limits.maxPhotosPerProject = 2
        let library = makeLibrary(limits: limits)
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "one.jpg",
            width: 120,
            height: 90
        )

        var package = makePackage()
        package = try await library.importPhoto(fileURL: source, into: package, at: Date()).package
        package = try await library.importPhoto(fileURL: source, into: package, at: Date()).package
        XCTAssertEqual(package.photos.count, 2)

        await assertImportFails(library, fileURL: source, into: package) { error in
            XCTAssertEqual(error, .photoLimitReached(limit: 2))
        }
        XCTAssertEqual(try assetDirectoryNames(package.id).count, 2)
    }

    // MARK: - Failure and cancellation

    func testFailedManifestCommitRollsBackTheNewPhotoFiles() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "rollback.jpg",
            width: 300,
            height: 200
        )

        var package = makePackage()
        package = try await library.importPhoto(fileURL: source, into: package, at: Date()).package
        let committedAssetID = try XCTUnwrap(package.photos.first).asset.id

        let manifestURL = projectDirectory(package.id)
            .appendingPathComponent(PhotoLibraryPath.manifestFileName)
        let manifestBefore = try Data(contentsOf: manifestURL)

        // Make the manifest path unwritable so the failure happens *after* the
        // original and derivatives were written.
        try FileManager.default.removeItem(at: manifestURL)
        try FileManager.default.createDirectory(at: manifestURL, withIntermediateDirectories: true)

        do {
            _ = try await library.importPhoto(fileURL: source, into: package, at: Date())
            XCTFail("the import must fail when the manifest cannot be written")
        } catch let error as PhotoLibraryError {
            guard case .fileOperationFailed = error else {
                return XCTFail("expected fileOperationFailed, got \(error)")
            }
        }

        XCTAssertEqual(
            try assetDirectoryNames(package.id),
            [committedAssetID.uuidString],
            "the failed photo's files must be rolled back and the committed photo kept"
        )

        // Put the previous manifest back: it must still decode unchanged.
        try FileManager.default.removeItem(at: manifestURL)
        try manifestBefore.write(to: manifestURL)

        let restored = try await library.restore()
        XCTAssertEqual(restored.packages.count, 1)
        XCTAssertEqual(restored.packages.first?.photos.count, 1)
    }

    func testCancelledImportCommitsNothingAndKeepsThePreviousPackage() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "cancelled.jpg",
            width: 400,
            height: 300
        )

        var package = makePackage()
        package = try await library.importPhoto(fileURL: source, into: package, at: Date()).package
        let manifestURL = projectDirectory(package.id)
            .appendingPathComponent(PhotoLibraryPath.manifestFileName)
        let manifestBefore = try Data(contentsOf: manifestURL)

        let gate = TestGate()
        let task = Task { () throws -> PhotoLibraryMutationResult in
            await gate.wait()
            return try await library.importPhoto(fileURL: source, into: package, at: Date())
        }
        task.cancel()
        await gate.open()

        let outcome = await task.result
        switch outcome {
        case .success:
            XCTFail("a cancelled import must not commit a photo")
        case .failure(let error):
            XCTAssertEqual(error as? PhotoLibraryError, .cancelled)
        }

        XCTAssertEqual(
            try Data(contentsOf: manifestURL),
            manifestBefore,
            "cancellation must not touch the previous manifest"
        )
        XCTAssertEqual(
            try assetDirectoryNames(package.id).count,
            1,
            "cancellation must not leave a partial asset folder"
        )
    }

    // MARK: - Removal

    func testRemovalDeletesOnlyThatProjectsFiles() async throws {
        let library = makeLibrary()
        let sourceA = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "a.jpg",
            width: 200,
            height: 150
        )
        let sourceB = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "b.png",
            width: 200,
            height: 150,
            typeIdentifier: UTType.png.identifier
        )

        var packageA = makePackage()
        packageA = try await library.importPhoto(fileURL: sourceA, into: packageA, at: Date()).package
        let photoA = try XCTUnwrap(packageA.photos.first)

        let packageB = makePackage()
        let resultB = try await library.importPhoto(fileURL: sourceB, into: packageB, at: Date())
        let photoB = try XCTUnwrap(resultB.package.photos.first)

        let removedDirectory = assetDirectory(packageA.id, photoA.asset.id)
        let untouchedDirectory = assetDirectory(packageB.id, photoB.asset.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: removedDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: untouchedDirectory.path))

        let removal = try await library.removePhoto(assetID: photoA.asset.id, from: packageA, at: Date())

        XCTAssertTrue(removal.package.photos.isEmpty)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: removedDirectory.path),
            "the removed photo's files must be deleted"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: untouchedDirectory.path),
            "another project's files must be untouched"
        )

        let restored = try await library.restore()
        XCTAssertEqual(restored.packages.count, 2)
        XCTAssertEqual(restored.packages.first { $0.id == packageA.id }?.photos.count, 0)
        XCTAssertEqual(restored.packages.first { $0.id == packageB.id }?.photos.count, 1)
    }

    func testRemovalRejectsAnUnknownPhoto() async throws {
        let library = makeLibrary()
        let package = makePackage()

        do {
            _ = try await library.removePhoto(assetID: UUID(), from: package, at: Date())
            XCTFail("removing an unknown photo must fail")
        } catch let error as PhotoLibraryError {
            guard case .photoNotFound = error else {
                return XCTFail("expected photoNotFound, got \(error)")
            }
        }
    }

    // MARK: - Restore

    func testRestoreLoadsPackagesInImportOrderAndIsRepeatable() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "order.jpg",
            width: 200,
            height: 150
        )

        var package = makePackage()
        package = try await library.importPhoto(fileURL: source, into: package, at: Date()).package
        package = try await library.importPhoto(fileURL: source, into: package, at: Date()).package

        let restored = try await library.restore()
        XCTAssertEqual(restored.packages.count, 1)
        XCTAssertEqual(restored.packages.first?.photos.map(\.asset.id), package.photos.map(\.asset.id))
        XCTAssertTrue(restored.warnings.isEmpty, "unexpected warnings: \(restored.warnings)")

        let again = try await library.restore()
        XCTAssertEqual(again.packages.count, 1)
        XCTAssertEqual(again.packages.first?.photos.count, 2)
    }

    func testRestoreReportsMissingDerivativeWithoutRewritingTheManifest() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "missing.jpg",
            width: 200,
            height: 150
        )
        let result = try await library.importPhoto(fileURL: source, into: makePackage(), at: Date())
        let photo = try XCTUnwrap(result.package.photos.first)

        let manifestURL = projectDirectory(result.package.id)
            .appendingPathComponent(PhotoLibraryPath.manifestFileName)
        let manifestBefore = try Data(contentsOf: manifestURL)

        try FileManager.default.removeItem(at: rootURL.appendingPathComponent(photo.thumbnailReference))

        let restored = try await library.restore()
        XCTAssertEqual(restored.packages.count, 1, "a photo with a missing derivative is still listed")
        XCTAssertTrue(restored.warnings.contains { $0.contains("is missing") })
        XCTAssertEqual(
            try Data(contentsOf: manifestURL),
            manifestBefore,
            "restore must not rewrite a damaged project"
        )
    }

    func testRestoreSkipsUnknownSchemaVersionAndLeavesTheFileUntouched() async throws {
        let library = makeLibrary()
        let projectID = UUID()
        let directory = projectDirectory(projectID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let project = Project(id: projectID, name: "Future format", createdAt: Date())
        let manifestJSON: [String: Any] = [
            "schemaVersion": 99,
            "project": try JSONSerialization.jsonObject(with: JSONEncoder().encode(project)),
            "photos": [],
        ]
        let manifestURL = directory.appendingPathComponent(PhotoLibraryPath.manifestFileName)
        let data = try JSONSerialization.data(withJSONObject: manifestJSON, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: manifestURL)

        let restored = try await library.restore()
        XCTAssertTrue(restored.packages.isEmpty)
        XCTAssertTrue(restored.warnings.contains { $0.contains("unsupported format version") })
        XCTAssertEqual(
            try Data(contentsOf: manifestURL),
            data,
            "a future-version package must be preserved, not rewritten or deleted"
        )
    }

    func testRestoreCleansUnreferencedAssetFoldersAndStagingResidue() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "clean.jpg",
            width: 200,
            height: 150
        )
        let result = try await library.importPhoto(fileURL: source, into: makePackage(), at: Date())
        let projectID = result.package.id

        // What an import interrupted before its manifest commit leaves behind.
        let strayDirectory = assetDirectory(projectID, UUID())
        try FileManager.default.createDirectory(at: strayDirectory, withIntermediateDirectories: true)
        try Data("partial".utf8).write(to: strayDirectory.appendingPathComponent("original.jpg"))

        // And a staged copy that was never imported.
        let staged = try await PhotoFileTransfer.stageCopy(of: source, rootURL: rootURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.path))

        _ = try await library.restore()

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: strayDirectory.path),
            "unreferenced asset folders are removed"
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: staged.path),
            "staging residue is removed"
        )
        XCTAssertEqual(try assetDirectoryNames(projectID).count, 1)
    }

    // MARK: - Derived images

    func testLoadDerivedImageRejectsAnOriginalReference() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "bypass.jpg",
            width: 200,
            height: 150
        )
        let result = try await library.importPhoto(fileURL: source, into: makePackage(), at: Date())
        let photo = try XCTUnwrap(result.package.photos.first)

        do {
            _ = try await library.loadDerivedImage(reference: photo.asset.localReference)
            XCTFail("the derivative API must not load originals")
        } catch let error as PhotoLibraryError {
            guard case .invalidReference = error else {
                return XCTFail("expected invalidReference, got \(error)")
            }
        }
    }

    // MARK: - HEIC

    func testImportAcceptsSyntheticHEICAndKeepsItsDerivativesBounded() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "synthetic.heic",
            width: 240,
            height: 160,
            typeIdentifier: UTType.heic.identifier
        )

        let result = try await library.importPhoto(fileURL: source, into: makePackage(), at: Date())
        let photo = try XCTUnwrap(result.package.photos.first)

        XCTAssertEqual(photo.contentType, UTType.heic.identifier)
        XCTAssertEqual(photo.pixelWidth, 240)
        XCTAssertEqual(photo.pixelHeight, 160)
        XCTAssertTrue(photo.asset.localReference.hasSuffix(".heic"))
        XCTAssertEqual(
            try Data(contentsOf: rootURL.appendingPathComponent(photo.asset.localReference)),
            try Data(contentsOf: source)
        )

        let thumbnail = try await library.loadDerivedImage(reference: photo.thumbnailReference)
        XCTAssertEqual(max(thumbnail.width, thumbnail.height), 240, "no upsampling beyond the source")
        let preview = try await library.loadDerivedImage(reference: photo.previewReference)
        XCTAssertEqual(max(preview.width, preview.height), 240)
    }

    // MARK: - Store safety

    func testRestoreSkipsManifestWhoseProjectDoesNotMatchItsFolder() async throws {
        let library = makeLibrary()
        let folderID = UUID()
        let otherProjectID = UUID()

        let directory = projectDirectory(folderID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Structurally valid, but for a different project than the folder name.
        let package = ProjectPackage(
            project: Project(id: otherProjectID, name: "Mismatch", createdAt: Date()),
            photos: []
        )
        let manifestURL = directory.appendingPathComponent(PhotoLibraryPath.manifestFileName)
        let data = try JSONEncoder().encode(package)
        try data.write(to: manifestURL)

        let restored = try await library.restore()

        XCTAssertTrue(restored.packages.isEmpty)
        XCTAssertTrue(restored.warnings.contains { $0.contains("does not match its folder") })
        XCTAssertEqual(
            try Data(contentsOf: manifestURL),
            data,
            "a mismatched manifest must be preserved for inspection, not rewritten"
        )
    }

    func testRestoreKeepsUnrecognisedItemsInAnAssetsFolder() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "kept.jpg",
            width: 100,
            height: 80
        )
        let result = try await library.importPhoto(fileURL: source, into: makePackage(), at: Date())

        let assetsRoot = projectDirectory(result.package.id)
            .appendingPathComponent(PhotoLibraryPath.assetsDirectoryName, isDirectory: true)
        let strayFile = assetsRoot.appendingPathComponent("notes.txt")
        let strayFolder = assetsRoot.appendingPathComponent("not-a-uuid", isDirectory: true)
        try Data("leave me alone".utf8).write(to: strayFile)
        try FileManager.default.createDirectory(at: strayFolder, withIntermediateDirectories: true)

        let restored = try await library.restore()

        XCTAssertEqual(restored.packages.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: strayFile.path), "unknown files must be kept")
        XCTAssertTrue(FileManager.default.fileExists(atPath: strayFolder.path), "unknown folders must be kept")
        XCTAssertTrue(restored.warnings.contains { $0.contains("unrecognised item") })
    }

    func testDerivativeLoadRejectsAnAssetDirectoryThatEscapesThroughASymlink() async throws {
        let library = makeLibrary()
        let projectID = UUID()
        let assetID = UUID()

        // A real derivative outside the library root.
        let outsideDirectory = baseURL.appendingPathComponent("OutsideAsset", isDirectory: true)
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        let outsideImage = try SyntheticImageFactory.makeImage(width: 40, height: 40)
        try SyntheticImageFactory.write(
            outsideImage,
            to: outsideDirectory.appendingPathComponent("thumbnail.jpg"),
            typeIdentifier: UTType.jpeg.identifier
        )

        // The library's asset folder is a symlink that points at it.
        let projectAssets = projectDirectory(projectID)
            .appendingPathComponent(PhotoLibraryPath.assetsDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: projectAssets, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: projectAssets.appendingPathComponent(assetID.uuidString, isDirectory: true),
            withDestinationURL: outsideDirectory
        )

        let reference = PhotoLibraryPath.derivativeReference(
            .thumbnail,
            projectID: projectID,
            assetID: assetID,
            fileExtension: "jpg"
        )

        do {
            _ = try await library.loadDerivedImage(reference: reference)
            XCTFail("an asset folder that escapes the library through a symlink must be refused")
        } catch let error as PhotoLibraryError {
            guard case .invalidReference = error else {
                return XCTFail("expected invalidReference, got \(error)")
            }
        }
    }

    // MARK: - Staging ownership

    func testDiscardStagedFileOnlyRemovesOwnedStagingCopies() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "staged.jpg",
            width: 60,
            height: 60
        )
        let sourceBytes = try Data(contentsOf: source)

        let staged = try await PhotoFileTransfer.stageCopy(of: source, rootURL: rootURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: staged.path))
        XCTAssertEqual(try Data(contentsOf: staged), sourceBytes, "staging must not alter the received bytes")

        // A file outside staging that merely shares the staged file's name must
        // not cause the library to delete the owned copy.
        let lookalikeDirectory = baseURL.appendingPathComponent("Lookalike", isDirectory: true)
        try FileManager.default.createDirectory(at: lookalikeDirectory, withIntermediateDirectories: true)
        let lookalike = lookalikeDirectory.appendingPathComponent(staged.lastPathComponent)
        try Data("not ours".utf8).write(to: lookalike)

        let lookalikeWarnings = await library.discardStagedFile(at: lookalike)
        XCTAssertTrue(lookalikeWarnings.isEmpty)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: staged.path),
            "a same-named file outside staging must not delete the owned staged copy"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: lookalike.path))

        // The owned copy is removed.
        let warnings = await library.discardStagedFile(at: staged)
        XCTAssertTrue(warnings.isEmpty)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: staged.path),
            "an owned staging copy is removed once its item is finished"
        )

        // A file that is not in the staging directory must never be deleted.
        let outsideWarnings = await library.discardStagedFile(at: source)
        XCTAssertTrue(outsideWarnings.isEmpty)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: source.path),
            "a file outside the staging directory must be left alone"
        )
        XCTAssertEqual(try Data(contentsOf: source), sourceBytes, "the source is never modified")
    }

    // MARK: - First launch and within-library aliases

    func testRestoreCreatesTheLibraryOnFirstLaunchWithAMissingRoot() async throws {
        let missingRoot = baseURL.appendingPathComponent("BrandNewLibrary", isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingRoot.path))

        let library = PhotoLibrary(rootURL: missingRoot)
        let result = try await library.restore()

        XCTAssertTrue(result.packages.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty, "a first launch must not warn: \(result.warnings)")
        for directory in [
            missingRoot,
            missingRoot.appendingPathComponent(PhotoLibraryPath.projectsDirectoryName, isDirectory: true),
            missingRoot.appendingPathComponent(PhotoLibraryLocation.stagingDirectoryName, isDirectory: true),
        ] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: directory.path),
                "\(directory.lastPathComponent) was not created on first launch"
            )
        }
    }

    func testSymlinkAliasInsideTheLibraryCannotRedirectAnotherProjectsAssets() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "alias.jpg",
            width: 120,
            height: 90
        )

        // Project B holds one committed photo.
        let packageB = makePackage()
        let committedB = try await library.importPhoto(fileURL: source, into: packageB, at: Date()).package
        let photoB = try XCTUnwrap(committedB.photos.first)
        let assetsB = projectDirectory(packageB.id)
            .appendingPathComponent(PhotoLibraryPath.assetsDirectoryName, isDirectory: true)
        let listingBefore = try FileManager.default.contentsOfDirectory(atPath: assetsB.path).sorted()
        let fileB = rootURL.appendingPathComponent(photoB.asset.localReference)

        // Project A's assets folder is a symlink to project B's assets folder:
        // both resolve *inside* the library, so a plain containment check alone
        // would let A write into, or clean up, B.
        let packageA = makePackage()
        let projectDirectoryA = projectDirectory(packageA.id)
        try FileManager.default.createDirectory(at: projectDirectoryA, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: projectDirectoryA.appendingPathComponent(PhotoLibraryPath.assetsDirectoryName, isDirectory: true),
            withDestinationURL: assetsB
        )

        do {
            _ = try await library.importPhoto(fileURL: source, into: packageA, at: Date())
            XCTFail("writing through a within-library symlink alias must be refused")
        } catch let error as PhotoLibraryError {
            guard case .invalidReference = error else {
                return XCTFail("expected invalidReference, got \(error)")
            }
        }

        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: assetsB.path).sorted(),
            listingBefore,
            "the other project's assets must not gain or lose anything"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileB.path), "project B's photo must still exist")
    }

    func testCleanupKeepsAUUIDNamedRegularFileInAnAssetsFolder() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "kept-file.jpg",
            width: 100,
            height: 80
        )
        let result = try await library.importPhoto(fileURL: source, into: makePackage(), at: Date())

        let assetsRoot = projectDirectory(result.package.id)
            .appendingPathComponent(PhotoLibraryPath.assetsDirectoryName, isDirectory: true)
        let uuidNamedFile = assetsRoot.appendingPathComponent("\(UUID().uuidString).txt")
        try Data("not a folder".utf8).write(to: uuidNamedFile)

        let restored = try await library.restore()

        XCTAssertEqual(restored.packages.count, 1)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: uuidNamedFile.path),
            "a UUID-named plain file is not an asset folder and must not be cleaned up"
        )
        XCTAssertTrue(restored.warnings.contains { $0.contains("unrecognised item") })
    }

    // MARK: - Staging boundary (FIX-01)

    func testStagingDirectoryAliasIsRejectedAndSourceIsUnchanged() async throws {
        // Temporary is replaced by a symlink that points outside the library.
        let outside = baseURL.appendingPathComponent("OutsideStaging", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: rootURL.appendingPathComponent(PhotoLibraryLocation.stagingDirectoryName, isDirectory: true),
            withDestinationURL: outside
        )

        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "alias-source.jpg",
            width: 80,
            height: 60
        )
        let sourceBytes = try Data(contentsOf: source)

        do {
            _ = try await PhotoFileTransfer.stageCopy(of: source, rootURL: rootURL)
            XCTFail("staging through an aliased Temporary directory must be refused")
        } catch {
            guard let libraryError = error as? PhotoLibraryError else {
                return XCTFail("expected PhotoLibraryError, got \(error)")
            }
            guard case .invalidReference = libraryError else {
                return XCTFail("expected invalidReference, got \(libraryError)")
            }
        }

        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: outside.path),
            [],
            "nothing may be written through the alias"
        )
        XCTAssertEqual(try Data(contentsOf: source), sourceBytes, "the source is never modified")
    }

    func testDanglingSymlinkAtAGeneratedPathIsRejected() async throws {
        let library = makeLibrary()
        let projectID = UUID()
        let assetID = UUID()

        // `assets/<assetID>` is a link whose destination does not exist, so
        // `fileExists` (which follows links) reports "missing" while the link
        // itself is still standing where a generated folder would be created.
        let assetsDirectory = projectDirectory(projectID)
            .appendingPathComponent(PhotoLibraryPath.assetsDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)

        let danglingDestination = baseURL.appendingPathComponent("Missing", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: assetsDirectory.appendingPathComponent(assetID.uuidString, isDirectory: true),
            withDestinationURL: danglingDestination
        )

        let reference = PhotoLibraryPath.derivativeReference(
            .thumbnail,
            projectID: projectID,
            assetID: assetID,
            fileExtension: "jpg"
        )

        do {
            _ = try await library.loadDerivedImage(reference: reference)
            XCTFail("a dangling generated symlink must be refused")
        } catch {
            XCTAssertEqual(error as? PhotoLibraryError, .invalidReference(reference))
        }

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: danglingDestination.path),
            "a rejected path must never create the link's destination"
        )
    }

    func testExternalAliasToTheOwnedStagingFolderIsNotAcceptedAsOwnership() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "alias-owned.jpg",
            width: 60,
            height: 60
        )

        // An owned staged copy inside the library's own staging folder.
        let owned = try await PhotoFileTransfer.stageCopy(of: source, rootURL: rootURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: owned.path))

        // An outside directory holding a link named like the staging folder, so
        // resolving the incoming parent would land on the owned Temporary.
        let outside = baseURL.appendingPathComponent("OutsideStagingAlias", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let alias = outside.appendingPathComponent(PhotoLibraryLocation.stagingDirectoryName, isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: alias,
            withDestinationURL: rootURL.appendingPathComponent(
                PhotoLibraryLocation.stagingDirectoryName,
                isDirectory: true
            )
        )
        let aliasedURL = alias.appendingPathComponent(owned.lastPathComponent)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: aliasedURL.path),
            "the outside alias does reach the owned file"
        )

        let warnings = await library.discardStagedFile(at: aliasedURL)

        XCTAssertTrue(warnings.isEmpty)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: owned.path),
            "an external alias must not be accepted as ownership of the owned staged file"
        )
    }

    func testStagingCancellationLeavesNoCopy() async throws {
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "cancel-staging.jpg",
            width: 80,
            height: 60
        )

        let gate = TestGate()
        let task = Task { () throws -> URL in
            await gate.wait()
            return try await PhotoFileTransfer.stageCopy(of: source, rootURL: rootURL)
        }
        task.cancel()
        await gate.open()

        let outcome = await task.result
        switch outcome {
        case .success:
            XCTFail("a cancelled staging copy must not be returned")
        case .failure(let error):
            XCTAssertTrue(error is CancellationError, "expected CancellationError, got \(error)")
        }

        let staging = rootURL.appendingPathComponent(PhotoLibraryLocation.stagingDirectoryName, isDirectory: true)
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: staging.path)) ?? []
        XCTAssertTrue(entries.isEmpty, "cancellation must not leave a staged copy behind: \(entries)")
    }

    func testImportAndRemoveRejectFutureOrInvalidPackagesWithoutWriting() async throws {
        let library = makeLibrary()
        let source = try SyntheticImageFactory.writeFixture(
            in: fixturesURL,
            name: "rejected.jpg",
            width: 80,
            height: 60
        )

        // A package from a future format version must never be downgraded.
        let future = ProjectPackage(
            schemaVersion: 99,
            project: Project(id: UUID(), name: "Future", createdAt: Date()),
            photos: []
        )
        do {
            _ = try await library.importPhoto(fileURL: source, into: future, at: Date())
            XCTFail("import must reject a future schema version")
        } catch {
            XCTAssertEqual(error as? PhotoLibraryError, .unsupportedSchemaVersion(99))
        }
        do {
            _ = try await library.removePhoto(assetID: UUID(), from: future, at: Date())
            XCTFail("removal must reject a future schema version")
        } catch {
            XCTAssertEqual(error as? PhotoLibraryError, .unsupportedSchemaVersion(99))
        }

        // A package whose stored references escape their own project must be refused.
        let badAssetID = UUID()
        let badPhoto = ImportedPhoto(
            asset: Asset(id: badAssetID, kind: .photo, localReference: "/etc/passwd"),
            thumbnailReference: "Projects/../escape/thumbnail.jpg",
            previewReference: "Temporary/preview.jpg",
            pixelWidth: 10,
            pixelHeight: 10,
            orientation: 1,
            contentType: "public.jpeg"
        )
        let badPackage = ProjectPackage(
            project: Project(id: UUID(), name: "Bad", createdAt: Date()),
            photos: [badPhoto]
        )
        do {
            _ = try await library.importPhoto(fileURL: source, into: badPackage, at: Date())
            XCTFail("import must reject an invalid stored reference")
        } catch {
            guard let libraryError = error as? PhotoLibraryError else {
                return XCTFail("expected PhotoLibraryError, got \(error)")
            }
            guard case .invalidReference = libraryError else {
                return XCTFail("expected invalidReference, got \(libraryError)")
            }
        }
        do {
            _ = try await library.removePhoto(assetID: badAssetID, from: badPackage, at: Date())
            XCTFail("removal must reject an invalid stored reference")
        } catch {
            guard let libraryError = error as? PhotoLibraryError else {
                return XCTFail("expected PhotoLibraryError, got \(error)")
            }
            guard case .invalidReference = libraryError else {
                return XCTFail("expected invalidReference, got \(libraryError)")
            }
        }

        // Nothing was written for either rejected package.
        for projectID in [future.project.id, badPackage.project.id] {
            let manifest = rootURL.appendingPathComponent(PhotoLibraryPath.manifestReference(projectID))
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: manifest.path),
                "a rejected mutation must not write a manifest"
            )
        }
    }
}
