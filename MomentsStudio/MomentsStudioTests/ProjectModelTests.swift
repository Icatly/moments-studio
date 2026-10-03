import XCTest
@testable import MomentsStudio

final class ProjectModelTests: XCTestCase {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testNewProjectStartsEmptyWithMatchingTimestamps() {
        let project = Project(name: "Trip", createdAt: createdAt)

        XCTAssertEqual(project.createdAt, createdAt)
        XCTAssertEqual(project.updatedAt, createdAt, "A new project must not look edited later than it was created.")
        XCTAssertTrue(project.document.layers.isEmpty)
        XCTAssertEqual(project.document.canvasSize, .portrait4x5)
    }

    func testRenameTrimsWhitespaceAndRecordsEditTime() {
        var project = Project(name: "Trip", createdAt: createdAt)
        let editedAt = createdAt.addingTimeInterval(600)

        let didRename = project.rename(to: "  Summer 2026 ", at: editedAt)

        XCTAssertTrue(didRename)
        XCTAssertEqual(project.name, "Summer 2026")
        XCTAssertEqual(project.updatedAt, editedAt)
        XCTAssertEqual(project.createdAt, createdAt, "Renaming must not change the creation time.")
    }

    func testRenameRejectsBlankNameWithoutMutatingState() {
        var project = Project(name: "Trip", createdAt: createdAt)

        let didRename = project.rename(to: " \n\t ")

        XCTAssertFalse(didRename, "A whitespace-only name must be rejected.")
        XCTAssertEqual(project.name, "Trip")
        XCTAssertEqual(project.updatedAt, createdAt, "A rejected rename must not touch the edit time.")
    }

    func testProjectRoundTripsThroughJSON() throws {
        let layer = Layer(
            id: UUID(),
            opacity: 0.5,
            zIndex: 2,
            isLocked: true,
            isHidden: true
        )
        let original = Project(
            id: UUID(),
            name: "Round Trip",
            createdAt: createdAt,
            updatedAt: createdAt.addingTimeInterval(120),
            document: CanvasDocument(
                id: UUID(),
                canvasSize: CanvasSize(width: 1080, height: 1080),
                layers: [layer]
            )
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testEncodedProjectUsesDocumentedKeys() throws {
        let project = Project(name: "Keys", createdAt: createdAt)
        let data = try JSONEncoder().encode(project)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(
            Set(json.keys),
            ["id", "name", "createdAt", "updatedAt", "document"],
            "The persisted project shape is part of the serialization contract."
        )
    }
}
