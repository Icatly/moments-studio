import Foundation
import Observation

/// The single owner of project state for the running app.
///
/// Stage 01 keeps projects in memory. The Home screen labels the list as
/// session-only, so the app never implies that a draft survived a restart.
/// Persistence (copying originals into the sandbox and storing the document)
/// is a later stage; this type is the intended seam, so views never touch
/// storage directly.
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
