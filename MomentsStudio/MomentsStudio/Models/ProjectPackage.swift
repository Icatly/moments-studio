import Foundation

/// The persisted unit of a project that has imported photos.
///
/// Stage 02 introduced the archive. Stage 03 preserves its photos and adds
/// editable photo layers; version 1 is read without rewriting its manifest.
struct ProjectPackage: Identifiable, Codable, Equatable, Hashable {
    /// Format version written by this build. Decoding accepts this version and the
    /// frozen Stage 02 version 1, which is upgraded in memory without rewriting the
    /// file; anything else is rejected instead of guessed.
    static let currentSchemaVersion = 2

    /// The frozen Stage 02 format. Version 1 documents contain layers without
    /// `assetID`/`baseSize`; they decode as historical unbound placeholders and are
    /// only rewritten as version 2 after the next successful edit/import/removal.
    static let legacySchemaVersion = 1

    /// Version 1 fixtures must not be produced by the current encoder, so tests
    /// carry a frozen byte-for-byte document instead.
    static let readableSchemaVersions: ClosedRange<Int> = legacySchemaVersion...currentSchemaVersion

    /// Engineering ceiling for photos per project. It lives here because
    /// decoding validates it, and `PhotoLibraryLimits` defaults to it so the
    /// policy has a single source.
    static let photoLimit = 20

    /// Engineering ceiling for layers per project (Stage 03). The same asset may be
    /// added as several independent layers; the count is what is limited.
    static let layerLimit = 20

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
    /// limit, a reference that does not belong to its own project and asset, or a
    /// layer list that is duplicated, over the layer limit, bound to a missing
    /// asset or carrying an unusable size/transform.
    ///
    /// A real Stage 02 (`schemaVersion == 1`) document is accepted and upgraded to
    /// `currentSchemaVersion` **in memory**; the caller decides when to write, so
    /// reading an old package never rewrites it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard Self.readableSchemaVersions.contains(schemaVersion) else {
            throw PhotoLibraryError.unsupportedSchemaVersion(schemaVersion)
        }

        let project = try container.decode(Project.self, forKey: .project)
        let photos = try container.decode([ImportedPhoto].self, forKey: .photos)
        try Self.validate(
            photos: photos,
            projectID: project.id,
            canvasSize: project.document.canvasSize,
            layers: project.document.layers
        )

        // In-memory upgrade: the document the app works with is always the current
        // version, while the file on disk keeps its original bytes until a
        // successful mutation writes a new manifest.
        self.schemaVersion = Self.currentSchemaVersion
        self.project = project
        self.photos = photos
    }

    /// Validation shared by decoding and by the library before it writes, so a
    /// value that cannot be decoded is never committed in the first place.
    ///
    /// The canvas size and the layer list default to the empty document so
    /// existing callers that only validate photos keep their behaviour.
    static func validate(
        photos: [ImportedPhoto],
        projectID: UUID,
        canvasSize: CanvasSize = .portrait4x5,
        layers: [Layer] = []
    ) throws {
        guard canvasSize.width.isFinite, canvasSize.height.isFinite,
              canvasSize.width > 0, canvasSize.height > 0 else {
            throw PhotoLibraryError.invalidPackage(
                "canvas size must be finite and positive: \(canvasSize)"
            )
        }

        guard photos.count <= photoLimit else {
            throw PhotoLibraryError.invalidPackage("project holds \(photos.count) photos, limit \(photoLimit)")
        }

        var seenAssetIDs = Set<UUID>()
        var savedPrimaryCount = 0
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

            // Stage 06 additive contract. An impossible automatic choice would have
            // thrown while decoding, but the value is re-checked here because every
            // save path funnels through this validation before the manifest write,
            // and a package may hold at most one saved primary photo.
            if let choice = photo.roleChoice {
                guard choice.isValid else {
                    throw PhotoLibraryError.invalidPackage(
                        "photo \(assetID.uuidString) has an impossible automatic role \(choice.role.rawValue)"
                    )
                }
                if choice.role == .primary {
                    savedPrimaryCount += 1
                    guard savedPrimaryCount <= PhotoRoleChoice.primaryLimit else {
                        throw PhotoLibraryError.invalidPackage(
                            "more than one saved primary photo (photo \(assetID.uuidString))"
                        )
                    }
                }
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

        // Stage 03 layer contract. Historical unbound layers (both new keys absent)
        // are kept; anything else must be complete, unique, inside the layer limit
        // and point at a photo that is in this package.
        guard layers.count <= layerLimit else {
            throw PhotoLibraryError.invalidPackage(
                "project holds \(layers.count) layers, limit \(layerLimit)"
            )
        }

        let assetIDs = Set(photos.map(\.asset.id))
        var seenLayerIDs = Set<UUID>()
        for layer in layers {
            guard seenLayerIDs.insert(layer.id).inserted else {
                throw PhotoLibraryError.invalidPackage("duplicate layer id \(layer.id.uuidString)")
            }
            guard layer.transform.translationX.isFinite,
                  layer.transform.translationY.isFinite,
                  layer.transform.rotationRadians.isFinite,
                  layer.transform.scale.isFinite,
                  layer.transform.scale > 0 else {
                throw PhotoLibraryError.invalidPackage(
                    "layer \(layer.id.uuidString) has an unusable transform \(layer.transform)"
                )
            }
            switch (layer.assetID, layer.baseSize) {
            case (nil, nil):
                continue
            case let (.some(assetID), .some(size)):
                guard assetIDs.contains(assetID) else {
                    throw PhotoLibraryError.invalidPackage(
                        "layer \(layer.id.uuidString) references asset \(assetID.uuidString) which is not in this package"
                    )
                }
                guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
                    throw PhotoLibraryError.invalidPackage(
                        "layer \(layer.id.uuidString) has an unusable base size \(size)"
                    )
                }
            default:
                throw PhotoLibraryError.invalidPackage(
                    "layer \(layer.id.uuidString) must carry both assetID and baseSize, or neither"
                )
            }
        }
    }
}
