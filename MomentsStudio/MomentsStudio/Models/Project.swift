import Foundation

/// A user-authored photo composition project.
///
/// Stage 01 scope: identity, display name, timestamps and the canvas document.
/// The type is `Codable` so that a later stage **can** persist it. Persistence
/// and document migration are not implemented, and their policy is not decided.
///
/// The current field set is a Stage 01 contract under architecture review — not
/// a promise that these names or their encoding never change. Adding, renaming
/// or removing a field, or changing the encoding strategy, requires review
/// (see `ARCHITECTURE.md`).
///
/// Only fields that Stage 01 can actually explain are declared. Asset, AI and
/// rendering fields are decided in Stage 02+ and described in `ARCHITECTURE.md`
/// instead of being added here as unused properties.
struct Project: Identifiable, Codable, Equatable, Hashable {
    /// Placeholder name used when the user does not supply one.
    static let untitledName = "Untitled Project"

    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var document: CanvasDocument

    /// Creates a project. `updatedAt` defaults to `createdAt` so a brand new
    /// project never looks edited later than it was created.
    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        document: CanvasDocument = .empty
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.document = document
    }

    /// Renames the project and records the edit time.
    ///
    /// Whitespace-only names are rejected so the recent-projects list can never
    /// show an unnamed row. Returns `false` without mutating state when the
    /// requested name is blank.
    @discardableResult
    mutating func rename(to newName: String, at date: Date = Date()) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        name = trimmed
        updatedAt = date
        return true
    }
}
