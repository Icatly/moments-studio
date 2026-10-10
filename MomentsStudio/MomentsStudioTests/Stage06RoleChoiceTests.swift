import XCTest
@testable import MomentsStudio

/// The Stage 06 additive contract: `ImportedPhoto.roleChoice`.
///
/// These tests pin the persisted shape, not an interpretation of it: a project
/// that never used Photo roles must keep exactly its previous schema 2 bytes, an
/// unknown or impossible value must be rejected instead of guessed, and a package
/// may hold at most one saved primary photo.
final class Stage06RoleChoiceTests: XCTestCase {
    private let projectID = UUID()

    /// One photo whose asset/derivative references belong to `projectID`.
    ///
    /// The project id is a parameter so a package and every photo inside it can be
    /// built from **one** identity: the library validates each reference against its
    /// own project, so mixing ids here would produce a synthetic "invalid reference"
    /// failure that has nothing to do with the contract under test.
    private func photo(
        _ assetID: UUID = UUID(),
        roleChoice: PhotoRoleChoice? = nil,
        projectID: UUID? = nil
    ) -> ImportedPhoto {
        let project = projectID ?? self.projectID
        return ImportedPhoto(
            asset: Asset(
                id: assetID,
                kind: .photo,
                localReference: PhotoLibraryPath.originalReference(project, assetID: assetID, fileExtension: "jpg")
            ),
            thumbnailReference: PhotoLibraryPath.derivativeReference(
                .thumbnail, projectID: project, assetID: assetID, fileExtension: "jpg"
            ),
            previewReference: PhotoLibraryPath.derivativeReference(
                .preview, projectID: project, assetID: assetID, fileExtension: "jpg"
            ),
            pixelWidth: 320,
            pixelHeight: 240,
            orientation: 1,
            contentType: "public.jpeg",
            roleChoice: roleChoice
        )
    }

    private func encoded(_ value: ImportedPhoto) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    // MARK: - Default and compatible encoding

    func testNilRoleChoiceAddsNoKeyAndDecodesFromLegacyPayloads() throws {
        let assetID = UUID()
        let json = try encoded(photo(assetID))
        XCTAssertFalse(json.contains("roleChoice"), "a nil choice must not add a key: \(json)")

        // A payload written before Stage 06 (no key) and one with an explicit null
        // both mean "no saved choice".
        let withoutKey = """
        {"asset":{"id":"\(assetID.uuidString)","kind":"photo","localReference":"Projects/\(projectID.uuidString)/assets/\(assetID.uuidString)/original.jpg"},"contentType":"public.jpeg","orientation":1,"pixelHeight":240,"pixelWidth":320,"previewReference":"Projects/\(projectID.uuidString)/assets/\(assetID.uuidString)/preview.jpg","thumbnailReference":"Projects/\(projectID.uuidString)/assets/\(assetID.uuidString)/thumbnail.jpg"}
        """
        let withNull = withoutKey.replacingOccurrences(
            of: "\"contentType\"", with: "\"roleChoice\":null,\"contentType\""
        )
        for payload in [withoutKey, withNull] {
            let decoded = try JSONDecoder().decode(ImportedPhoto.self, from: Data(payload.utf8))
            XCTAssertNil(decoded.roleChoice)
            XCTAssertEqual(decoded.asset.id, assetID)
        }
    }

    func testEveryRoleAndSourceRoundTripsAndKeepsItsSource() throws {
        for role in PhotoRole.allCases {
            let choice = PhotoRoleChoice.manual(role)
            let decoded = try JSONDecoder().decode(ImportedPhoto.self, from: Data(encoded(photo(roleChoice: choice)).utf8))
            XCTAssertEqual(decoded.roleChoice, choice)
            XCTAssertEqual(decoded.roleChoice?.source, .manual)
        }
        for role in PhotoRole.automaticCandidates {
            let choice = PhotoRoleChoice.automatic(role)
            let decoded = try JSONDecoder().decode(ImportedPhoto.self, from: Data(encoded(photo(roleChoice: choice)).utf8))
            XCTAssertEqual(decoded.roleChoice, choice)
            XCTAssertEqual(decoded.roleChoice?.source, .automatic)
        }
    }

    func testUnknownRoleSourceAndTypeAreRejectedNotGuessed() throws {
        let assetID = UUID()
        let manualPrimary = try encoded(photo(assetID, roleChoice: .manual(.primary)))
        let manualExcluded = try encoded(photo(assetID, roleChoice: .manual(.excluded)))

        // Text-level corruption: unknown role, unknown source and a wrong type. Each
        // replacement is asserted to have actually changed the payload, so a string
        // that silently did not match cannot turn this into a false pass.
        let corruptions: [(name: String, payload: String)] = [
            ("unknown role", manualPrimary.replacingOccurrences(of: "\"primary\"", with: "\"lead\"")),
            ("unknown source", manualPrimary.replacingOccurrences(of: "\"manual\"", with: "\"guessed\"")),
            ("wrong type", manualPrimary.replacingOccurrences(of: "\"role\":\"primary\"", with: "\"role\":7"))
        ]
        for corruption in corruptions {
            XCTAssertNotEqual(corruption.payload, manualPrimary,
                              "\(corruption.name): the variant must really differ from the base payload")
            XCTAssertThrowsError(try JSONDecoder().decode(ImportedPhoto.self, from: Data(corruption.payload.utf8)),
                                 "must reject \(corruption.name): \(corruption.payload)")
        }
        // A manual non-participating choice is legal and must keep decoding.
        XCTAssertNoThrow(try JSONDecoder().decode(ImportedPhoto.self, from: Data(manualExcluded.utf8)),
                         "manual excluded stays legal")

        // The impossible combinations are the ones the decoder rejects structurally:
        // an automatic choice may never exclude a photo or reserve collage material,
        // because the automatic policy only ever produces primary/supporting.
        let impossible = [
            PhotoRoleChoice(role: .excluded, source: .automatic),
            PhotoRoleChoice(role: .collageMaterial, source: .automatic)
        ]
        for illegal in impossible {
            XCTAssertFalse(illegal.isValid)
            let payload = try encoded(photo(assetID, roleChoice: illegal))
            XCTAssertTrue(payload.contains("\"source\":\"automatic\""),
                          "the illegal variant must really carry the automatic source: \(payload)")
            XCTAssertThrowsError(try JSONDecoder().decode(ImportedPhoto.self, from: Data(payload.utf8)),
                                 "must reject \(illegal.role.rawValue) from an automatic source")
            XCTAssertThrowsError(try ProjectPackage.validate(
                photos: [photo(assetID, roleChoice: illegal)], projectID: projectID
            ), "package validation must reject \(illegal.role.rawValue) from an automatic source")
        }
    }

    // MARK: - Package validation

    func testPackageRejectsTwoSavedPrimaries() {
        let first = photo(roleChoice: .manual(.primary))
        let second = photo(roleChoice: .automatic(.primary))
        XCTAssertThrowsError(try ProjectPackage.validate(
            photos: [first, second], projectID: projectID
        ))
    }

    func testPackageAcceptsOnePrimaryPlusSupportingAndNonParticipating() throws {
        let first = photo(roleChoice: .manual(.primary))
        let second = photo(roleChoice: .automatic(.supporting))
        let third = photo(roleChoice: .manual(.collageMaterial))
        let fourth = photo(roleChoice: .manual(.excluded))
        XCTAssertNoThrow(try ProjectPackage.validate(
            photos: [first, second, third, fourth], projectID: projectID
        ))
    }

    func testPackageRejectsAnImpossibleAutomaticNonParticipatingChoice() {
        var broken = photo()
        // Built directly rather than through the validating initializer, so this
        // pins the validation path as well as the decoder.
        broken.roleChoice = PhotoRoleChoice(role: .excluded, source: .automatic)
        XCTAssertThrowsError(try ProjectPackage.validate(photos: [broken], projectID: projectID))
        XCTAssertFalse(broken.roleChoice?.isValid ?? true)
    }

    func testDecodedPackageKeepsSavedChoicesAndLegacyOneStillReads() throws {
        let primary = photo(roleChoice: .manual(.primary))
        let supporting = photo(roleChoice: .automatic(.supporting))
        // The package project id must be the one every photo path was generated from.
        let package = ProjectPackage(
            project: Project(id: projectID, name: "Roles"), photos: [primary, supporting]
        )

        let data = try JSONEncoder().encode(package)
        let decoded = try JSONDecoder().decode(ProjectPackage.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, ProjectPackage.currentSchemaVersion)
        XCTAssertEqual(decoded.photos.map(\.roleChoice), [.manual(.primary), .automatic(.supporting)])

        // A Stage 01/02 package (schemaVersion 1) that predates the key still decodes and
        // keeps nil choices. The payload is a real encoded package of that version (not
        // hand-guessed), and its photos use the same legacy project id as its project.
        let legacyID = UUID()
        let legacyPhoto = photo(projectID: legacyID)
        let legacyPackage = ProjectPackage(
            schemaVersion: ProjectPackage.legacySchemaVersion,
            project: Project(id: legacyID, name: "Legacy"),
            photos: [legacyPhoto]
        )
        let legacyJSON = String(decoding: try JSONEncoder().encode(legacyPackage), as: UTF8.self)
        XCTAssertFalse(legacyJSON.contains("roleChoice"))
        // The payload really is a version-1 document: the in-memory package carries
        // `legacySchemaVersion` and the encoded JSON keeps it, so the decode below
        // genuinely exercises the legacy upgrade path instead of re-reading version 2.
        XCTAssertEqual(legacyPackage.schemaVersion, ProjectPackage.legacySchemaVersion)
        XCTAssertEqual(ProjectPackage.legacySchemaVersion, 1)
        XCTAssertTrue(legacyJSON.contains("\"schemaVersion\":1"),
                      "the encoded legacy payload must keep schemaVersion 1: \(legacyJSON)")
        let decodedLegacy = try JSONDecoder().decode(ProjectPackage.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(decodedLegacy.schemaVersion, ProjectPackage.currentSchemaVersion,
                       "decoding upgrades version 1 to the current in-memory version")
        XCTAssertEqual(ProjectPackage.currentSchemaVersion, 2)
        XCTAssertEqual(decodedLegacy.photos.count, 1)
        XCTAssertNil(decodedLegacy.photos[0].roleChoice)
    }
}
