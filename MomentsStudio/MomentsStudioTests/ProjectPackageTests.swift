import XCTest
@testable import MomentsStudio

/// Contract tests for the Stage 02 persisted format.
///
/// They pin the coding keys (including the unchanged Stage 01 `Asset` keys) and
/// prove that damaged or future data is rejected instead of repaired.
final class ProjectPackageTests: XCTestCase {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Fixtures

    private func makePhoto(projectID: UUID, assetID: UUID = UUID()) -> ImportedPhoto {
        ImportedPhoto(
            asset: Asset(
                id: assetID,
                kind: .photo,
                localReference: PhotoLibraryPath.originalReference(
                    projectID,
                    assetID: assetID,
                    fileExtension: "jpg"
                )
            ),
            thumbnailReference: PhotoLibraryPath.derivativeReference(
                .thumbnail,
                projectID: projectID,
                assetID: assetID,
                fileExtension: "jpg"
            ),
            previewReference: PhotoLibraryPath.derivativeReference(
                .preview,
                projectID: projectID,
                assetID: assetID,
                fileExtension: "jpg"
            ),
            pixelWidth: 1200,
            pixelHeight: 800,
            orientation: 1,
            contentType: "public.jpeg"
        )
    }

    private func makePackage(photoCount: Int = 1) -> (package: ProjectPackage, projectID: UUID) {
        let projectID = UUID()
        let photos = (0..<photoCount).map { _ in makePhoto(projectID: projectID) }
        let project = Project(id: projectID, name: "Package", createdAt: createdAt)
        return (ProjectPackage(project: project, photos: photos), projectID)
    }

    private func json(of package: ProjectPackage) throws -> [String: Any] {
        let data = try JSONEncoder().encode(package)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decode(_ json: [String: Any]) throws -> ProjectPackage {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(ProjectPackage.self, from: data)
    }

    private func assertInvalidPackage(
        _ body: () throws -> ProjectPackage,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            guard let libraryError = error as? PhotoLibraryError else {
                return XCTFail("expected PhotoLibraryError, got \(error)", file: file, line: line)
            }
            guard case .invalidPackage = libraryError else {
                return XCTFail("expected invalidPackage, got \(libraryError)", file: file, line: line)
            }
        }
    }

    private func assertInvalidReference(
        _ body: () throws -> ProjectPackage,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            guard let libraryError = error as? PhotoLibraryError else {
                return XCTFail("expected PhotoLibraryError, got \(error)", file: file, line: line)
            }
            guard case .invalidReference = libraryError else {
                return XCTFail("expected invalidReference, got \(libraryError)", file: file, line: line)
            }
        }
    }

    // MARK: - Coding contract

    func testPackageRoundTripsWithDocumentedCodingKeys() throws {
        let (package, _) = makePackage(photoCount: 2)

        let root = try json(of: package)
        XCTAssertEqual(Set(root.keys), ["schemaVersion", "project", "photos"])
        // Stage 03 raised the written format to 2 (approved contract: `Layer.assetID`
        // and `Layer.baseSize` were added and version 1 documents are upgraded in
        // memory on read). The previous value here was the literal `1`; the key set
        // and every other assertion in this file are unchanged. Version 1 remains
        // readable and is covered by Stage03ContractTests and
        // Stage03StorageCoordinatorTests (a real version 1 manifest is restored from
        // disk without being rewritten).
        XCTAssertEqual(root["schemaVersion"] as? Int, ProjectPackage.currentSchemaVersion)
        XCTAssertEqual(ProjectPackage.currentSchemaVersion, 2)

        let photos = try XCTUnwrap(root["photos"] as? [[String: Any]])
        XCTAssertEqual(photos.count, 2)
        XCTAssertEqual(
            Set(try XCTUnwrap(photos.first).keys),
            [
                "asset", "thumbnailReference", "previewReference",
                "pixelWidth", "pixelHeight", "orientation", "contentType",
            ]
        )

        // The Stage 01 Asset contract must not have changed.
        let asset = try XCTUnwrap(photos.first?["asset"] as? [String: Any])
        XCTAssertEqual(Set(asset.keys), ["id", "kind", "localReference"])

        let decoded = try JSONDecoder().decode(ProjectPackage.self, from: JSONEncoder().encode(package))
        XCTAssertEqual(decoded, package)
        XCTAssertEqual(decoded.photos.map(\.asset.id), package.photos.map(\.asset.id))
    }

    func testDisplayPixelSizeSwapsForRotatedOrientations() {
        let projectID = UUID()
        var photo = makePhoto(projectID: projectID, assetID: UUID())

        photo.orientation = 1
        XCTAssertEqual(photo.displayPixelSize.width, 1200)
        XCTAssertEqual(photo.displayPixelSize.height, 800)

        photo.orientation = 6
        XCTAssertEqual(photo.displayPixelSize.width, 800)
        XCTAssertEqual(photo.displayPixelSize.height, 1200)

        photo.orientation = 8
        XCTAssertEqual(photo.displayPixelSize.width, 800)
        XCTAssertEqual(photo.displayPixelSize.height, 1200)
    }

    // MARK: - Rejection

    func testDecodingRejectsUnknownSchemaVersion() throws {
        var root = try json(of: makePackage().package)
        root["schemaVersion"] = 99

        XCTAssertThrowsError(try decode(root)) { error in
            XCTAssertEqual(error as? PhotoLibraryError, .unsupportedSchemaVersion(99))
        }
    }

    func testDecodingRejectsMorePhotosThanTheLimit() throws {
        var root = try json(of: makePackage().package)
        let photo = try XCTUnwrap((root["photos"] as? [[String: Any]])?.first)

        // Same asset repeated, so only the ceiling can reject this.
        root["photos"] = Array(repeating: photo, count: ProjectPackage.photoLimit + 1)

        assertInvalidPackage { try self.decode(root) }
    }

    func testDecodingRejectsDuplicatePhotoIdentifiers() throws {
        let (package, _) = makePackage(photoCount: 1)
        var root = try json(of: package)
        let photos = try XCTUnwrap(root["photos"] as? [[String: Any]])
        root["photos"] = photos + photos

        assertInvalidPackage { try self.decode(root) }
    }

    func testDecodingRejectsInvalidDimensionsOrientationAndContentType() throws {
        let (package, _) = makePackage(photoCount: 1)

        // Explicit context for mixed Int/String values. Swift 6.1.2 crashed while
        // typechecking this test in run 37133937308; whether inference was the
        // trigger remains unverified until the next actual build.
        let cases: [(key: String, value: Any)] = [
            ("pixelWidth", 0),
            ("pixelHeight", -5),
            ("orientation", 9),
            ("contentType", ""),
        ]

        for (key, value) in cases {
            var root = try json(of: package)
            var photos = try XCTUnwrap(root["photos"] as? [[String: Any]])
            photos[0][key] = value
            root["photos"] = photos

            assertInvalidPackage { try self.decode(root) }
        }
    }

    func testDecodingRejectsReferencesThatEscapeTheirOwnProjectOrAsset() throws {
        let (package, projectID) = makePackage(photoCount: 1)
        let assetID = try XCTUnwrap(package.photos.first).asset.id
        let foreignProject = UUID()
        let foreignAsset = UUID()

        let cases: [(field: String, value: String)] = [
            // Absolute path.
            ("original", "/etc/passwd"),
            // Directory traversal.
            ("original", "Projects/../Projects/x/original.jpg"),
            // Another project's asset directory.
            (
                "thumbnail",
                PhotoLibraryPath.derivativeReference(
                    .thumbnail,
                    projectID: foreignProject,
                    assetID: assetID,
                    fileExtension: "jpg"
                )
            ),
            // Right project, foreign asset.
            (
                "preview",
                PhotoLibraryPath.derivativeReference(
                    .preview,
                    projectID: projectID,
                    assetID: foreignAsset,
                    fileExtension: "jpg"
                )
            ),
            // A different file kind than the field promises.
            (
                "thumbnail",
                PhotoLibraryPath.originalReference(projectID, assetID: assetID, fileExtension: "jpg")
            ),
            // Missing extension.
            ("preview", "Projects/\(projectID.uuidString)/assets/\(assetID.uuidString)/preview"),
        ]

        for entry in cases {
            var root = try json(of: package)
            var photos = try XCTUnwrap(root["photos"] as? [[String: Any]])

            if entry.field == "original" {
                var asset = try XCTUnwrap(photos[0]["asset"] as? [String: Any])
                asset["localReference"] = entry.value
                photos[0]["asset"] = asset
            } else {
                let key = entry.field == "thumbnail" ? "thumbnailReference" : "previewReference"
                photos[0][key] = entry.value
            }
            root["photos"] = photos

            assertInvalidReference { try self.decode(root) }
        }
    }

    func testPathRulesAcceptOnlyGeneratedReferences() throws {
        let projectID = UUID()
        let assetID = UUID()

        let original = PhotoLibraryPath.originalReference(projectID, assetID: assetID, fileExtension: "HEIC")
        let parsed = try PhotoLibraryPath.parse(original)
        XCTAssertEqual(parsed.projectID, projectID)
        XCTAssertEqual(parsed.assetID, assetID)
        XCTAssertEqual(parsed.kind, .original)
        XCTAssertEqual(parsed.fileExtension, "heic")

        XCTAssertThrowsError(try PhotoLibraryPath.validateDerivative(original)) { error in
            XCTAssertEqual(error as? PhotoLibraryError, .invalidReference(original))
        }
        XCTAssertThrowsError(try PhotoLibraryPath.parse("Projects/\(projectID.uuidString)/assets/\(assetID.uuidString)/original.gif"))
        XCTAssertThrowsError(try PhotoLibraryPath.parse("Temporary/\(assetID.uuidString).jpg"))
        XCTAssertThrowsError(try PhotoLibraryPath.parse("Projects/\(projectID.uuidString)/assets/\(assetID.uuidString)/thumbnail.jpg/extra"))
    }
}
