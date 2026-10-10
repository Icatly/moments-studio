import Foundation

/// One photo that belongs to a project package.
///
/// The asset keeps the Stage 01 `Asset` shape: `asset.id` is the photo's
/// identity, `asset.kind` is `.photo`, and `asset.localReference` is the
/// library-relative path of the received original file. Derivatives are
/// separate references, so nothing here is an absolute URL, a picker item, an
/// image object, a photo-library identifier or copied EXIF/GPS.
struct ImportedPhoto: Identifiable, Codable, Equatable, Hashable {
    /// EXIF orientations this model accepts; `1` means "already upright".
    static let orientationRange: ClosedRange<Int> = 1...8

    var asset: Asset
    /// Library-relative path of the 320px-bounded derivative.
    var thumbnailReference: String
    /// Library-relative path of the 2048px-bounded derivative.
    var previewReference: String
    /// Pixel width of the stored original, before any orientation transform.
    var pixelWidth: Int
    /// Pixel height of the stored original, before any orientation transform.
    var pixelHeight: Int
    /// EXIF orientation of the stored original (1...8).
    var orientation: Int
    /// UTI ImageIO detected for the received file, e.g. `public.jpeg`.
    var contentType: String
    /// The saved Stage 06 role choice, or `nil` when the user has saved nothing.
    ///
    /// Additive and optional by contract: a package without the key decodes to
    /// `nil`, and a `nil` value is **not** encoded at all, so a project that never
    /// used Photo roles keeps byte-compatible schema 2 output. The value is
    /// validated on decode and by `ProjectPackage.validate` before every write.
    var roleChoice: PhotoRoleChoice?

    /// Photo identity is its asset identity.
    var id: UUID { asset.id }

    /// Display size once the EXIF orientation is applied: orientations 5...8
    /// rotate the image by 90 degrees, so width and height swap.
    var displayPixelSize: (width: Int, height: Int) {
        (5...8).contains(orientation) ? (pixelHeight, pixelWidth) : (pixelWidth, pixelHeight)
    }

    /// Keys are listed explicitly because they are the persisted contract;
    /// renaming one requires architecture review.
    private enum CodingKeys: String, CodingKey {
        case asset
        case thumbnailReference
        case previewReference
        case pixelWidth
        case pixelHeight
        case orientation
        case contentType
        /// Stage 06 additive key. Absent, `null` and `nil` all mean "no choice".
        case roleChoice
    }

    init(
        asset: Asset,
        thumbnailReference: String,
        previewReference: String,
        pixelWidth: Int,
        pixelHeight: Int,
        orientation: Int,
        contentType: String,
        roleChoice: PhotoRoleChoice? = nil
    ) {
        self.asset = asset
        self.thumbnailReference = thumbnailReference
        self.previewReference = previewReference
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.orientation = orientation
        self.contentType = contentType
        self.roleChoice = roleChoice
    }

    /// Decodes the frozen Stage 01/02/03 shape and the additive Stage 06 key.
    ///
    /// An absent key, an explicit `null` and a corrupt/unknown `roleChoice` object
    /// behave differently on purpose: absent or `null` is "no saved choice", while
    /// an unknown role/source or an impossible automatic choice throws instead of
    /// being silently dropped or guessed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.asset = try container.decode(Asset.self, forKey: .asset)
        self.thumbnailReference = try container.decode(String.self, forKey: .thumbnailReference)
        self.previewReference = try container.decode(String.self, forKey: .previewReference)
        self.pixelWidth = try container.decode(Int.self, forKey: .pixelWidth)
        self.pixelHeight = try container.decode(Int.self, forKey: .pixelHeight)
        self.orientation = try container.decode(Int.self, forKey: .orientation)
        self.contentType = try container.decode(String.self, forKey: .contentType)
        self.roleChoice = try container.decodeIfPresent(PhotoRoleChoice.self, forKey: .roleChoice)
    }

    /// Writes the Stage 01/02/03 keys exactly as before. `roleChoice` is only
    /// emitted when a choice is actually saved, so an untouched project keeps its
    /// previous schema 2 bytes.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(asset, forKey: .asset)
        try container.encode(thumbnailReference, forKey: .thumbnailReference)
        try container.encode(previewReference, forKey: .previewReference)
        try container.encode(pixelWidth, forKey: .pixelWidth)
        try container.encode(pixelHeight, forKey: .pixelHeight)
        try container.encode(orientation, forKey: .orientation)
        try container.encode(contentType, forKey: .contentType)
        try container.encodeIfPresent(roleChoice, forKey: .roleChoice)
    }
}
