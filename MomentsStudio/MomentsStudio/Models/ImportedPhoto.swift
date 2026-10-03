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
    }

    init(
        asset: Asset,
        thumbnailReference: String,
        previewReference: String,
        pixelWidth: Int,
        pixelHeight: Int,
        orientation: Int,
        contentType: String
    ) {
        self.asset = asset
        self.thumbnailReference = thumbnailReference
        self.previewReference = previewReference
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.orientation = orientation
        self.contentType = contentType
    }
}
