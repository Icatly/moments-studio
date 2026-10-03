import XCTest
@testable import MomentsStudio

/// `ProjectStore` is `@MainActor`-isolated. Each test method states that
/// isolation itself (with an `async` signature) instead of annotating the whole
/// `XCTestCase` subclass, which would change the isolation of the inherited
/// class and of the other suites in this target.
final class ProjectStoreTests: XCTestCase {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    @MainActor
    func testCreateProjectAppendsAndReturnsTheStoredProject() async {
        let store = ProjectStore()

        let created = store.createProject(at: createdAt)

        XCTAssertEqual(store.projects.count, 1)
        XCTAssertEqual(store.openProject(id: created.id), created)
        XCTAssertEqual(created.name, Project.untitledName)
        XCTAssertEqual(created.createdAt, createdAt)
    }

    @MainActor
    func testCreateProjectGeneratesUniquePlaceholderNames() async {
        let store = ProjectStore()

        let names = (0..<3).map { _ in store.createProject(at: createdAt).name }

        XCTAssertEqual(names, ["Untitled Project", "Untitled Project 2", "Untitled Project 3"])
        XCTAssertEqual(Set(names).count, names.count)
    }

    @MainActor
    func testCreateProjectUsesTrimmedExplicitNameAndFallsBackWhenBlank() async {
        let store = ProjectStore()

        let named = store.createProject(name: "  Holiday  ", at: createdAt)
        let blank = store.createProject(name: "   ", at: createdAt)

        XCTAssertEqual(named.name, "Holiday")
        XCTAssertEqual(blank.name, Project.untitledName)
    }

    @MainActor
    func testOpenProjectReturnsNilForUnknownIdentifier() async {
        let store = ProjectStore()
        store.createProject(at: createdAt)

        XCTAssertNil(store.openProject(id: UUID()))
    }

    @MainActor
    func testRenameProjectUpdatesTheStoredProject() async {
        let store = ProjectStore()
        let project = store.createProject(at: createdAt)
        let editedAt = createdAt.addingTimeInterval(300)

        let didRename = store.renameProject(id: project.id, to: "Reworked", at: editedAt)

        XCTAssertTrue(didRename)
        XCTAssertEqual(store.openProject(id: project.id)?.name, "Reworked")
        XCTAssertEqual(store.openProject(id: project.id)?.updatedAt, editedAt)
    }

    @MainActor
    func testRenameProjectRejectsBlankNameAndUnknownIdentifier() async {
        let store = ProjectStore()
        let project = store.createProject(name: "Keep", at: createdAt)

        XCTAssertFalse(store.renameProject(id: project.id, to: "  "), "Blank names must be rejected.")
        XCTAssertEqual(store.openProject(id: project.id)?.name, "Keep")

        XCTAssertFalse(store.renameProject(id: UUID(), to: "Orphan"))
        XCTAssertEqual(store.projects.count, 1)
    }

    @MainActor
    func testRecentProjectsAreNewestFirst() async {
        let store = ProjectStore()

        let first = store.createProject(name: "First", at: createdAt)
        let second = store.createProject(name: "Second", at: createdAt.addingTimeInterval(60))

        XCTAssertEqual(store.recentProjects.map(\.id), [second.id, first.id])
        XCTAssertEqual(store.projects.map(\.id), [first.id, second.id])
    }

    // MARK: - Stage 02 photo snapshot seams

    @MainActor
    func testPhotosAreEmptyForAnUnknownProject() async {
        let store = ProjectStore()
        let project = store.createProject(at: createdAt)

        XCTAssertTrue(store.photos(for: project.id).isEmpty)
        XCTAssertTrue(store.savedProjectIDs.isEmpty)
    }

    @MainActor
    func testApplyInsertsOnceAndThenReplaces() async {
        let store = ProjectStore()
        let projectID = UUID()
        let photo = makePhoto(projectID: projectID)

        store.apply(ProjectPackage(project: makeProject(id: projectID), photos: []))
        XCTAssertEqual(store.projects.count, 1)
        XCTAssertTrue(store.photos(for: projectID).isEmpty)
        XCTAssertTrue(store.savedProjectIDs.contains(projectID))

        store.apply(ProjectPackage(project: makeProject(id: projectID, name: "Renamed"), photos: [photo]))
        XCTAssertEqual(store.projects.count, 1, "applying a known project must not duplicate it")
        XCTAssertEqual(store.openProject(id: projectID)?.name, "Renamed")
        XCTAssertEqual(store.photos(for: projectID).map(\.asset.id), [photo.asset.id])
    }

    @MainActor
    func testRestoreMergesSavedPackagesAndKeepsMemoryOnlyProjects() async {
        let store = ProjectStore()
        let memoryOnly = store.createProject(name: "Memory only", at: createdAt)

        let older = makeProject(id: UUID(), created: createdAt.addingTimeInterval(-600), name: "Older")
        let newer = makeProject(id: UUID(), created: createdAt.addingTimeInterval(600), name: "Newer")

        store.restore([
            ProjectPackage(project: newer, photos: [makePhoto(projectID: newer.id)]),
            ProjectPackage(project: older, photos: []),
        ])

        XCTAssertEqual(store.projects.count, 3)
        XCTAssertTrue(
            store.projects.contains { $0.id == memoryOnly.id },
            "a memory-only project must survive a restore"
        )
        XCTAssertEqual(
            store.projects.suffix(2).map(\.id),
            [older.id, newer.id],
            "restored packages keep creation order"
        )
        XCTAssertEqual(store.recentProjects.first?.id, newer.id)
        XCTAssertEqual(store.savedProjectIDs, [older.id, newer.id])
        XCTAssertEqual(store.photos(for: newer.id).count, 1)
        XCTAssertTrue(store.photos(for: memoryOnly.id).isEmpty)
    }

    @MainActor
    func testRestoreIsIdempotent() async {
        let store = ProjectStore()
        let projectID = UUID()
        let package = ProjectPackage(
            project: makeProject(id: projectID),
            photos: [makePhoto(projectID: projectID)]
        )

        store.restore([package])
        store.restore([package])

        XCTAssertEqual(store.projects.count, 1)
        XCTAssertEqual(store.photos(for: projectID).count, 1)
    }

    // MARK: - Fixtures

    private func makeProject(id: UUID, created: Date? = nil, name: String = "Saved") -> Project {
        Project(id: id, name: name, createdAt: created ?? createdAt)
    }

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
            pixelWidth: 100,
            pixelHeight: 100,
            orientation: 1,
            contentType: "public.jpeg"
        )
    }
}
