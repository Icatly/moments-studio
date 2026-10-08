import Foundation
import Observation

/// The single owner of project state for the running app.
///
/// A project is memory-only until Done or importing a photo commits it.
/// Once saved, `PhotoLibrary` has committed a
/// `ProjectPackage` on disk and `apply(_:)` / `restore(_:)` keep this store's
/// snapshot in step with that committed value. This type still never touches
/// the filesystem: `init` performs no I/O, which keeps it usable in unit tests,
/// and views never read or write files themselves.
///
/// Main actor: this type holds UI state, so it is `@MainActor`-isolated and the
/// compiler enforces main-thread access. Views reach it through the SwiftUI
/// environment; tests isolate themselves with `@MainActor` on the test method.
@MainActor
@Observable
final class ProjectStore {
    /// Creation order, oldest first. `recentProjects` reverses this for display.
    private(set) var projects: [Project] = []

    /// Newest first.
    ///
    /// Stage 01 defines "recent" as most recently created: opening a project is
    /// a read-only lookup and never reorders the list, because a view body must
    /// not mutate state. Reordering by last edit arrives with persistence.
    var recentProjects: [Project] {
        Array(projects.reversed())
    }

    /// Creates a project and returns it so the caller can navigate to it.
    ///
    /// - Parameter name: Explicit name, or `nil` to use a generated unique
    ///   placeholder name.
    @discardableResult
    func createProject(name: String? = nil, at date: Date = Date()) -> Project {
        let project = Project(name: resolvedName(for: name), createdAt: date)
        projects.append(project)
        return project
    }

    /// Looks up a project by identity. Returns `nil` once the project is gone,
    /// which lets screens show an explicit empty state instead of stale data.
    func openProject(id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    /// Renames a stored project. Returns `false` when the project is unknown or
    /// the requested name is blank; in both cases nothing changes.
    @discardableResult
    func renameProject(id: UUID, to newName: String, at date: Date = Date()) -> Bool {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return false }
        return projects[index].rename(to: newName, at: date)
    }

    /// Photos of every project that exists on disk, keyed by project id.
    ///
    /// A saved empty project has an empty collection here; `savedProjectIDs`
    /// distinguishes it from a project that has never been committed.
    private(set) var photoCollections: [UUID: [ImportedPhoto]] = [:]

    /// Projects that have been committed to the photo library on disk.
    private(set) var savedProjectIDs: Set<UUID> = []

    /// Photos of one project in import order. Empty for a memory-only project.
    func photos(for projectID: UUID) -> [ImportedPhoto] {
        photoCollections[projectID] ?? []
    }

    /// Applies one **committed** package snapshot: replaces the project when its
    /// id is already known, otherwise inserts it. It never duplicates an id and
    /// never creates layers or changes the document.
    func apply(_ package: ProjectPackage) {
        merge(package)
    }

    /// Merges packages loaded from disk at startup.
    ///
    /// Existing in-memory projects are kept, and restored packages are inserted
    /// in creation order so `recentProjects` stays meaningful across launches.
    func restore(_ packages: [ProjectPackage]) {
        let ordered = packages.sorted { lhs, rhs in
            if lhs.project.createdAt != rhs.project.createdAt {
                return lhs.project.createdAt < rhs.project.createdAt
            }
            return lhs.project.id.uuidString < rhs.project.id.uuidString
        }
        for package in ordered {
            merge(package)
        }
    }

    private func merge(_ package: ProjectPackage) {
        if let index = projects.firstIndex(where: { $0.id == package.project.id }) {
            projects[index] = package.project
        } else {
            projects.append(package.project)
        }
        photoCollections[package.project.id] = package.photos
        savedProjectIDs.insert(package.project.id)
    }

    private func resolvedName(for requested: String?) -> String {
        let trimmed = requested?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }

        let taken = Set(projects.map(\.name))
        guard taken.contains(Project.untitledName) else { return Project.untitledName }

        var index = 2
        while taken.contains("\(Project.untitledName) \(index)") {
            index += 1
        }
        return "\(Project.untitledName) \(index)"
    }
}
