import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

/// Deterministic, in-memory images for tests.
///
/// Nothing here uses a real photograph: every fixture is drawn programmatically,
/// so tests stay reproducible and no private image enters the repository, the
/// app or the simulator photo library. Fixtures are written to a temporary
/// directory supplied by each test.
///
/// Fixture, context and PNG/JPEG write problems are **real failures**, not
/// skips. Only an environment that cannot encode HEIC/HEIF may skip, and that
/// skip proves nothing about HEIC support.
enum SyntheticImageFactory {
    struct RGB: Equatable {
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat
    }

    /// Pixel alpha statistics used to prove that transparency survives a
    /// derivative, not merely that the file carries a `.png` extension.
    struct AlphaStats: Equatable {
        var opaque = 0
        var transparent = 0
        var semitransparent = 0

        var hasTransparency: Bool { transparent > 0 }
        var hasAnyNonOpaquePixel: Bool { transparent > 0 || semitransparent > 0 }
    }

    enum FixtureError: Error, CustomStringConvertible {
        case contextUnavailable(width: Int, height: Int)
        case renderFailed(width: Int, height: Int)
        case destinationUnavailable(String)
        case writeFailed(String)

        var description: String {
            switch self {
            case .contextUnavailable(let width, let height):
                return "could not create a \(width)x\(height) drawing context"
            case .renderFailed(let width, let height):
                return "could not render a \(width)x\(height) image"
            case .destinationUnavailable(let type):
                return "ImageIO cannot write \(type)"
            case .writeFailed(let type):
                return "ImageIO could not finish writing \(type)"
            }
        }
    }

    static let leftColor = RGB(red: 1, green: 0, blue: 0)
    static let rightColor = RGB(red: 0, green: 0, blue: 1)

    /// Draws an image whose left half is `left` and right half is `right`, which
    /// makes horizontal mirroring detectable.
    ///
    /// When `hasAlpha` is true the fixture also contains a genuinely transparent
    /// centred square (alpha 0) and a semi-transparent band (alpha 128), so an
    /// alpha assertion cannot pass on an opaque image.
    static func makeImage(
        width: Int,
        height: Int,
        left: RGB = leftColor,
        right: RGB = rightColor,
        hasAlpha: Bool = false
    ) throws -> CGImage {
        let alphaInfo: CGImageAlphaInfo = hasAlpha ? .premultipliedLast : .noneSkipLast
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: alphaInfo.rawValue
        ) else {
            throw FixtureError.contextUnavailable(width: width, height: height)
        }

        context.setFillColor(red: right.red, green: right.green, blue: right.blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(red: left.red, green: left.green, blue: left.blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: max(1, width / 2), height: height))

        if hasAlpha {
            // Fully transparent centred square.
            let side = max(2, min(width, height) / 2)
            context.clear(
                CGRect(
                    x: (width - side) / 2,
                    y: (height - side) / 2,
                    width: side,
                    height: side
                )
            )

            // Semi-transparent band along the bottom. The rectangle is cleared
            // first: filling alpha 0.5 with source-over on top of the opaque
            // background leaves the resulting alpha at 1, which is exactly what
            // the earlier fixture did and why the pixel-alpha assertion failed.
            let bandHeight = max(1, height / 4)
            let band = CGRect(x: 0, y: 0, width: width, height: bandHeight)
            context.clear(band)
            context.setFillColor(red: 0, green: 1, blue: 0, alpha: 0.5)
            context.fill(band)
        }

        guard let image = context.makeImage() else {
            throw FixtureError.renderFailed(width: width, height: height)
        }
        return image
    }

    /// Writes an image, optionally with an EXIF orientation tag. The pixels are
    /// not rotated here: the tag is what the pipeline has to act on.
    static func write(
        _ image: CGImage,
        to url: URL,
        typeIdentifier: String,
        orientation: Int? = nil
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            typeIdentifier as CFString,
            1,
            nil
        ) else {
            throw encodingUnavailable(typeIdentifier)
        }

        var properties: [CFString: Any] = [:]
        if let orientation {
            properties[kCGImagePropertyOrientation] = orientation
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw encodingUnavailable(typeIdentifier, finalize: true)
        }
    }

    /// HEIC/HEIF encoding is the only environment capability allowed to skip;
    /// anything else is a real failure.
    private static func encodingUnavailable(_ typeIdentifier: String, finalize: Bool = false) -> Error {
        if typeIdentifier == UTType.heic.identifier || typeIdentifier == UTType.heif.identifier {
            return XCTSkip(
                "ImageIO cannot encode \(typeIdentifier) in this environment; HEIC import support is therefore NOT proven by this run."
            )
        }
        return finalize
            ? FixtureError.writeFailed(typeIdentifier)
            : FixtureError.destinationUnavailable(typeIdentifier)
    }

    /// Reads an image back from disk, for fixture sanity checks.
    static func readImage(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw FixtureError.destinationUnavailable(url.lastPathComponent)
        }
        return image
    }

    /// Per-pixel alpha classification for an image.
    static func alphaStats(of image: CGImage) throws -> AlphaStats {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            throw FixtureError.renderFailed(width: width, height: height)
        }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw FixtureError.contextUnavailable(width: width, height: height)
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else {
            throw FixtureError.contextUnavailable(width: width, height: height)
        }

        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var stats = AlphaStats()
        for index in stride(from: 0, to: width * height * 4, by: 4) {
            let alpha = buffer[index + 3]
            switch alpha {
            case 0:
                stats.transparent += 1
            case 255:
                stats.opaque += 1
            default:
                stats.semitransparent += 1
            }
        }
        return stats
    }

    /// Average colour of one half of an image.
    ///
    /// Used to prove that an orientation transform really moved pixels, rather
    /// than only reporting a different metadata orientation.
    static func averageColor(of image: CGImage, leftHalf: Bool) throws -> RGB {
        let width = image.width
        let height = image.height
        guard width > 1, height > 0 else {
            throw FixtureError.renderFailed(width: width, height: height)
        }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw FixtureError.contextUnavailable(width: width, height: height)
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else {
            throw FixtureError.contextUnavailable(width: width, height: height)
        }

        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let startX = leftHalf ? 0 : width / 2
        let endX = leftHalf ? width / 2 : width
        guard startX < endX else {
            throw FixtureError.renderFailed(width: width, height: height)
        }

        var totalRed = 0.0
        var totalGreen = 0.0
        var totalBlue = 0.0
        var samples = 0.0

        for y in 0..<height {
            for x in startX..<endX {
                let offset = (y * width + x) * 4
                totalRed += Double(buffer[offset]) / 255
                totalGreen += Double(buffer[offset + 1]) / 255
                totalBlue += Double(buffer[offset + 2]) / 255
                samples += 1
            }
        }

        guard samples > 0 else {
            throw FixtureError.renderFailed(width: width, height: height)
        }
        return RGB(red: totalRed / samples, green: totalGreen / samples, blue: totalBlue / samples)
    }

    /// Writes a fixture of the requested size and returns its URL.
    static func writeFixture(
        in directory: URL,
        name: String,
        width: Int,
        height: Int,
        typeIdentifier: String = UTType.jpeg.identifier,
        orientation: Int? = nil,
        hasAlpha: Bool = false
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        let image = try makeImage(width: width, height: height, hasAlpha: hasAlpha)
        try write(image, to: url, typeIdentifier: typeIdentifier, orientation: orientation)
        return url
    }
}
