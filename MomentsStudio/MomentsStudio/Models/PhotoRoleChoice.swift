import Foundation

/// What one imported photo is meant to be in a layout (Stage 06).
///
/// The stored value is deliberately tiny and additive: it is the only new key in
/// the package, it never changes an original or a derivative, and it is validated
/// on decode and before every write, so an unknown or contradictory value is
/// rejected instead of guessed.
enum PhotoRole: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// One photo carries the layout (the Focus hero).
    case primary
    /// A regular photo that fills the remaining cells.
    case supporting
    /// Reserved for a future collage/cutout step. A layout never adds or moves it.
    case collageMaterial
    /// Kept in the library and on the canvas, but never arranged.
    case excluded

    /// Title shown in the Photo roles sheet.
    var title: String {
        switch self {
        case .primary: return "Primary photo"
        case .supporting: return "Supporting photo"
        case .collageMaterial: return "Collage material"
        case .excluded: return "Not for layout"
        }
    }

    var summary: String {
        switch self {
        case .primary: return "Gets the most room; Focus puts it first."
        case .supporting: return "Fills the remaining spots."
        case .collageMaterial: return "Kept for a later collage step; not arranged yet."
        case .excluded: return "Stays in your library and canvas; not arranged."
        }
    }

    /// Roles that take part in the automatic Stage 06 arrangement. Focus and the
    /// grid presets only ever place these.
    var participatesInLayout: Bool {
        switch self {
        case .primary, .supporting: return true
        case .collageMaterial, .excluded: return false
        }
    }

    /// The vocabulary the automatic suggestion may produce. The policy never
    /// excludes a photo or assigns collage material on its own.
    static let automaticCandidates: [PhotoRole] = [.primary, .supporting]
}

/// How a stored role came to be.
enum PhotoRoleSource: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// The user saved the suggestion this build produced.
    case automatic
    /// The user chose this role themselves.
    case manual
}

/// One saved role choice. `nil` (the whole value) means "no saved choice".
///
/// Semantics fixed by the Stage 06 specification:
/// * `automatic` is only legal for `primary`/`supporting`, because the automatic
///   policy never excludes a photo or reserves it as collage material;
/// * `manual` is legal for every role;
/// * a package holds at most one saved `primary`, checked on decode and before
///   every write.
struct PhotoRoleChoice: Codable, Equatable, Hashable, Sendable {
    static let primaryLimit = 1

    let role: PhotoRole
    let source: PhotoRoleSource

    init(role: PhotoRole, source: PhotoRoleSource) {
        self.role = role
        self.source = source
    }

    /// True when this value is a legal stored choice.
    var isValid: Bool {
        source == .manual || PhotoRole.automaticCandidates.contains(role)
    }

    /// A user's own choice.
    static func manual(_ role: PhotoRole) -> PhotoRoleChoice {
        PhotoRoleChoice(role: role, source: .manual)
    }

    /// A choice the user accepted from the system suggestion.
    static func automatic(_ role: PhotoRole) -> PhotoRoleChoice {
        PhotoRoleChoice(role: role, source: .automatic)
    }

    /// The choice a manual pick should become when a *different* photo is promoted
    /// to primary: the previous primary keeps its place as a supporting photo and is
    /// explicitly marked as the user's own decision, so the automatic policy will
    /// not silently promote another photo over it.
    static let demotedPrimary = PhotoRoleChoice(role: .supporting, source: .manual)

    var summary: String {
        "\(role.title) · \(source == .manual ? "your choice" : "suggested")"
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case role
        case source
    }

    /// Decodes strictly: an unknown role, an unknown source, a wrong type or an
    /// impossible automatic collage/excluded choice is an error, never a guess.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let role = try container.decode(PhotoRole.self, forKey: .role)
        let source = try container.decode(PhotoRoleSource.self, forKey: .source)
        guard source == .manual || PhotoRole.automaticCandidates.contains(role) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: container.codingPath,
                debugDescription: "an automatic choice cannot be \(role.rawValue)"
            ))
        }
        self.role = role
        self.source = source
    }
}
