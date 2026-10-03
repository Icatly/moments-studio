import Foundation

/// What an asset contains.
///
/// Stage 01 only needs `photo`. Generated images (cutouts, silhouettes,
/// stickers) become additional cases in a later stage under architecture
/// review.
enum AssetKind: String, Codable, Equatable, Hashable {
    case photo
}

/// A photo referenced by a project.
///
/// `localReference` is a path inside the app sandbox (relative to the asset
/// store root), never an absolute URL: absolute URLs break across app
/// reinstalls, device restores and container path changes.
///
/// Stage 01 does not import photos, so no `Asset` is created at runtime yet.
/// The type exists because the serialized project contract needs a stable,
/// reviewed shape before import is implemented in Stage 02.
struct Asset: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var kind: AssetKind
    var localReference: String

    init(id: UUID = UUID(), kind: AssetKind = .photo, localReference: String) {
        self.id = id
        self.kind = kind
        self.localReference = localReference
    }
}
