import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// ImageIO work for the photo pipeline: inspect a received file, build bounded
/// derivatives with the EXIF orientation applied, and write them.
///
/// Pure functions over URLs and `CGImageSource`s — no actor state, no SwiftUI,
/// no `UIImage`, and no full-resolution `Data` loading. Files are read through
/// `CGImageSource` so a decode stays bounded.
enum PhotoDerivativeRenderer {
    /// Still formats Stage 02 accepts. Anything else (RAW, animated GIF,
    /// video) is rejected instead of guessed at.
    static let supportedContentTypes: Set<String> = [
        UTType.jpeg.identifier,
        UTType.png.identifier,
        UTType.heic.identifier,
        UTType.heif.identifier,
    ]

    /// What the pipeline records about the stored original.
    struct SourceMetadata: Equatable {
        /// Pixel width before any orientation transform.
        var pixelWidth: Int
        /// Pixel height before any orientation transform.
        var pixelHeight: Int
        /// EXIF orientation, normalised into 1...8.
        var orientation: Int
        /// UTI ImageIO detected for the file.
        var contentType: String
        /// Whether the file carries an alpha channel.
        var hasAlpha: Bool
    }

    /// One bounded derivative plus whether its file keeps transparency.
    struct Derivative {
        var image: CGImage
        var hasAlpha: Bool
    }

    // MARK: - Inspection

    /// Opens a file as an image source without decoding it.
    static func openSource(at url: URL) throws -> CGImageSource {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
            throw PhotoLibraryError.unreadableImage(url.lastPathComponent)
        }
        guard CGImageSourceGetCount(source) > 0 else {
            throw PhotoLibraryError.unreadableImage(url.lastPathComponent)
        }
        return source
    }

    /// Reads the properties the pipeline needs, and rejects unsupported types.
    static func metadata(of source: CGImageSource, fileName: String) throws -> SourceMetadata {
        guard let type = CGImageSourceGetType(source) else {
            throw PhotoLibraryError.unsupportedImageType(fileName)
        }
        let contentType = type as String
        guard supportedContentTypes.contains(contentType) else {
            throw PhotoLibraryError.unsupportedImageType(contentType)
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let pixelWidth = (properties?[kCGImagePropertyPixelWidth] as? Int) ?? 0
        let pixelHeight = (properties?[kCGImagePropertyPixelHeight] as? Int) ?? 0
        guard pixelWidth > 0, pixelHeight > 0 else {
            throw PhotoLibraryError.unreadableImage(fileName)
        }

        let rawOrientation = (properties?[kCGImagePropertyOrientation] as? Int) ?? 1
        let hasAlpha = (properties?[kCGImagePropertyHasAlpha] as? Bool) ?? false

        return SourceMetadata(
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            orientation: ImportedPhoto.orientationRange.contains(rawOrientation) ? rawOrientation : 1,
            contentType: contentType,
            hasAlpha: hasAlpha
        )
    }

    /// File extension ImageIO prefers for a detected content type.
    static func preferredFileExtension(forContentType contentType: String) -> String {
        UTType(contentType)?.preferredFilenameExtension ?? "img"
    }

    /// Derivatives keep transparency as PNG; everything else is written as JPEG.
    static func derivativeFileExtension(hasAlpha: Bool) -> String {
        hasAlpha ? "png" : "jpg"
    }

    // MARK: - Derivatives

    /// Builds the bounded thumbnail and preview for one source.
    ///
    /// `kCGImageSourceCreateThumbnailFromImageAlways` plus
    /// `kCGImageSourceCreateThumbnailWithTransform` apply the EXIF orientation,
    /// so a rotated or mirrored source produces upright derivatives. The pixel
    /// limit is also capped by the source's own longest edge, so a small image
    /// is never upsampled, and each derivative is redrawn into 8-bit sRGB so the
    /// stored file is genuinely sRGB SDR whatever the source carried.
    static func makeDerivatives(
        from source: CGImageSource,
        metadata: SourceMetadata,
        thumbnailMaxPixelSize: Int,
        previewMaxPixelSize: Int,
        fileName: String
    ) throws -> (thumbnail: Derivative, preview: Derivative) {
        let sourceLongestEdge = max(metadata.pixelWidth, metadata.pixelHeight)
        let thumbnailLimit = max(1, min(thumbnailMaxPixelSize, sourceLongestEdge))
        let previewLimit = max(1, min(previewMaxPixelSize, sourceLongestEdge))

        guard let rawThumbnail = renderedThumbnail(from: source, maxPixelSize: thumbnailLimit) else {
            throw PhotoLibraryError.unreadableImage(fileName)
        }
        guard let rawPreview = renderedThumbnail(from: source, maxPixelSize: previewLimit) else {
            throw PhotoLibraryError.unreadableImage(fileName)
        }

        let thumbnail = Derivative(
            image: try convertToSRGB8(rawThumbnail, hasAlpha: metadata.hasAlpha, fileName: fileName),
            hasAlpha: metadata.hasAlpha
        )
        let preview = Derivative(
            image: try convertToSRGB8(rawPreview, hasAlpha: metadata.hasAlpha, fileName: fileName),
            hasAlpha: metadata.hasAlpha
        )
        return (thumbnail, preview)
    }

    /// One orientation-corrected, size-bounded render from a source.
    private static func renderedThumbnail(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Redraws an image into 8-bit sRGB (RGBA when the photo has alpha, RGB
    /// otherwise), preserving the orientation that was already applied.
    ///
    /// Only bounded derivatives go through this: the stored original is a byte
    /// copy and is never re-encoded or colour-converted.
    private static func convertToSRGB8(
        _ image: CGImage,
        hasAlpha: Bool,
        fileName: String
    ) throws -> CGImage {
        let alphaInfo: CGImageAlphaInfo = hasAlpha ? .premultipliedLast : .noneSkipLast
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: alphaInfo.rawValue
        ) else {
            throw PhotoLibraryError.unreadableImage(fileName)
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard let converted = context.makeImage() else {
            throw PhotoLibraryError.unreadableImage(fileName)
        }
        return converted
    }

    // MARK: - Writing

    /// Writes one derivative. PNG keeps the alpha channel; JPEG uses `quality`.
    static func write(
        _ derivative: Derivative,
        to url: URL,
        quality: Double = 0.85
    ) throws {
        let fileExtension = derivativeFileExtension(hasAlpha: derivative.hasAlpha)
        let typeIdentifier = fileExtension == "png" ? UTType.png.identifier : UTType.jpeg.identifier

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            typeIdentifier as CFString,
            1,
            nil
        ) else {
            throw PhotoLibraryError.fileOperationFailed("cannot create \(fileExtension) at \(url.lastPathComponent)")
        }

        var properties: [CFString: Any] = [:]
        if typeIdentifier == UTType.jpeg.identifier {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }
        CGImageDestinationAddImage(destination, derivative.image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw PhotoLibraryError.fileOperationFailed("cannot write \(url.lastPathComponent)")
        }
    }

    // MARK: - Bounded decoding for the UI

    /// Reads a generated derivative for display.
    ///
    /// The decode goes through ImageIO's thumbnail path with the role's own
    /// limit (320 for a thumbnail, 2048 for a preview), further capped by the
    /// file's real size, so it never decodes more pixels than the role allows
    /// and never upscales. An oversized or corrupt derivative therefore cannot
    /// turn this into an unbounded decode.
    static func decodeDerivative(at url: URL, maxPixelSize: Int) throws -> CGImage {
        let source = try openSource(at: url)
        let metadata = try self.metadata(of: source, fileName: url.lastPathComponent)
        let sourceLongestEdge = max(metadata.pixelWidth, metadata.pixelHeight)
        let limit = max(1, min(maxPixelSize, sourceLongestEdge))

        guard let image = renderedThumbnail(from: source, maxPixelSize: limit) else {
            throw PhotoLibraryError.unreadableImage(url.lastPathComponent)
        }
        return image
    }
}
