import Foundation

/// The persisted unit of a project that has imported photos.
///
/// Stage 01 produced no on-disk archive, so this is the first persisted format
/// and there is no older format to migrate from. The photo library lives in the
/// package next to the project, so the import stage does not decide canvas or
/// layer structure — that belongs to later stages.
struct ProjectPackage: Identifiable, Codable, Equatable, Hashable {
    /// Format version written by this build. Decoding rejects anything else
    /// instead of guessing.
    static let currentSchemaVersion = 1

    /// Engineering ceiling for photos per project. It lives here because
    /// decoding validates it, and `PhotoLibraryLimits` defaults to it so the
    /// policy has a single source.
    static let photoLimit = 20

    let schemaVersion: Int
    var project: Project
    /// Import order, oldest import first.
    var photos: [ImportedPhoto]

    /// Package identity is project identity.
    var id: UUID { project.id }

    /// Keys are listed explicitly because they are the persisted contract.
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case project
        case photos
    }

    init(
        schemaVersion: Int = ProjectPackage.currentSchemaVersion,
        project: Project,
        photos: [ImportedPhoto] = []
    ) {
        self.schemaVersion = schemaVersion
        self.project = project
        self.photos = photos
    }

    /// Decodes a package and **rejects** damaged or future data rather than
    /// repairing it: an unknown `schemaVersion`, non-positive dimensions, an
    /// out-of-range orientation, a duplicate photo id, more photos than the
    /// limit, or a reference that does not belong to its own project and asset.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw PhotoLibraryError.unsupportedSchemaVersion(schemaVersion)
        }

        let project = try container.decode(Project.self, forKey: .project)
        let photos = try container.decode([ImportedPhoto].self, forKey: .photos)
        try Self.validate(photos: photos, projectID: project.id)

        self.schemaVersion = schemaVersion
        self.project = project
        self.photos = photos
    }

    /// Validation shared by decoding and by the library before it writes, so a
    /// value that cannot be decoded is never committed in the first place.
    static func validate(photos: [ImportedPhoto], projectID: UUID) throws {
        guard photos.count <= photoLimit else {
            throw PhotoLibraryError.invalidPackage("project holds \(photos.count) photos, limit \(photoLimit)")
        }

        var seenAssetIDs = Set<UUID>()
        for photo in photos {
            let assetID = photo.asset.id

            guard seenAssetIDs.insert(assetID).inserted else {
                throw PhotoLibraryError.invalidPackage("duplicate photo id \(assetID.uuidString)")
            }
            guard photo.asset.kind == .photo else {
                throw PhotoLibraryError.invalidPackage("asset \(assetID.uuidString) is not a photo asset")
            }
            guard photo.pixelWidth > 0, photo.pixelHeight > 0 else {
                throw PhotoLibraryError.invalidPackage("photo \(assetID.uuidString) has non-positive dimensions")
            }
            guard ImportedPhoto.orientationRange.contains(photo.orientation) else {
                throw PhotoLibraryError.invalidPackage("photo \(assetID.uuidString) has orientation \(photo.orientation)")
            }
            guard !photo.contentType.isEmpty else {
                throw PhotoLibraryError.invalidPackage("photo \(assetID.uuidString) has no content type")
            }

            try PhotoLibraryPath.validate(
                photo.asset.localReference,
                projectID: projectID,
                assetID: assetID,
                expecting: .original
            )
            try PhotoLibraryPath.validate(
                photo.thumbnailReference,
                projectID: projectID,
                assetID: assetID,
                expecting: .thumbnail
            )
            try PhotoLibraryPath.validate(
                photo.previewReference,
                projectID: projectID,
                assetID: assetID,
                expecting: .preview
            )
        }
    }
}
