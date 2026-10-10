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

    private func photo(_ assetID: UUID = UUID(), roleChoice: PhotoRoleChoice? = nil) -> ImportedPhoto {
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
        let base = try encoded(photo(assetID, roleChoice: .manual(.primary)))
        for broken in [
            base.replacingOccurrences(of: "\"primary\"", with: "\"lead\""),
            base.replacingOccurrences(of: "\"manual\"", with: "\"guessed\""),
            base.replacingOccurrences(of: "\"role\":\"primary\"", with: "\"role\":7"),
            // An automatic choice may never exclude a photo or reserve collage
            // material: the policy only ever produces primary/supporting.
            base.replacingOccurrences(of: "\"role\":\"primary\"", with: "\"role\":\"excluded\"")
        ] {
            XCTAssertThrowsError(try JSONDecoder().decode(ImportedPhoto.self, from: Data(broken.utf8)),
                                 "must reject: \(broken)")
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
        let package = ProjectPackage(project: Project(name: "Roles"), photos: [primary, supporting])

        let data = try JSONEncoder().encode(package)
        let decoded = try JSONDecoder().decode(ProjectPackage.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, ProjectPackage.currentSchemaVersion)
        XCTAssertEqual(decoded.photos.map(\.roleChoice), [.manual(.primary), .automatic(.supporting)])

        // A Stage 01/02 payload (schemaVersion 1) that predates the key still decodes
        // and keeps nil choices: the key is stripped from a real encoded package so
        // the legacy shape is not hand-guessed.
        let legacyID = UUID()
        let legacyPhoto = photo()
        let legacyPackage = ProjectPackage(
            schemaVersion: ProjectPackage.legacySchemaVersion,
            project: Project(id: legacyID, name: "Legacy"),
            photos: [legacyPhoto]
        )
        let legacyJSON = String(decoding: try JSONEncoder().encode(legacyPackage), as: UTF8.self)
        XCTAssertFalse(legacyJSON.contains("roleChoice"))
        let decodedLegacy = try JSONDecoder().decode(ProjectPackage.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(decodedLegacy.schemaVersion, ProjectPackage.currentSchemaVersion)
        XCTAssertEqual(decodedLegacy.photos.count, 1)
        XCTAssertNil(decodedLegacy.photos[0].roleChoice)
    }
}
