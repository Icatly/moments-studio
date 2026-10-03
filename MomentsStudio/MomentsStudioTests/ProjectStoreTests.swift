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
}
