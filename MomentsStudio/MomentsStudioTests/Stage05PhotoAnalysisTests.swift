import CoreGraphics
import XCTest
@testable import MomentsStudio

/// Pure-statistics tests for `PhotoAnalyzer`.
///
/// Every input is built programmatically with a *known* pixel layout, so the
/// expected numbers come from the frozen formulas rather than from a stored
/// snapshot: black/white/grey/RGB solids, a two-region image, semi-transparent and
/// fully transparent pixels, mixed alpha coverage, sample rounding, a non-RGBA
/// input bitmap and the three-way UI bands.
final class Stage05PhotoAnalysisTests: XCTestCase {
    private let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    /// RGBA, 8-bit, alpha premultiplied, byte order big endian (r, g, b, a in memory).
    private func rgbaImage(
        width: Int,
        height: Int,
        pixel: (Int, Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)
    ) throws -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let value = pixel(x, y)
                let alpha = Double(value.a) / 255
                let offset = (y * width + x) * 4
                bytes[offset] = UInt8(min(255, (Double(value.r) * alpha).rounded()))
                bytes[offset + 1] = UInt8(min(255, (Double(value.g) * alpha).rounded()))
                bytes[offset + 2] = UInt8(min(255, (Double(value.b) * alpha).rounded()))
                bytes[offset + 3] = value.a
            }
        }
        return try image(width: width, height: height, bytes: bytes,
                         bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                            | CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    /// Same pixels, but declared as a *different* in-memory layout (BGRA,
    /// premultiplied first, little endian) to prove the analyzer converts instead
    /// of assuming the input format.
    private func bgraImage(
        width: Int,
        height: Int,
        pixel: (Int, Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)
    ) throws -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let value = pixel(x, y)
                let offset = (y * width + x) * 4
                bytes[offset] = value.b
                bytes[offset + 1] = value.g
                bytes[offset + 2] = value.r
                bytes[offset + 3] = value.a
            }
        }
        return try image(width: width, height: height, bytes: bytes,
                         bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
                            | CGImageAlphaInfo.premultipliedFirst.rawValue)
    }

    private func image(width: Int, height: Int, bytes: [UInt8], bitmapInfo: UInt32) throws -> CGImage {
        let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
        return try XCTUnwrap(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: sRGB,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
    }

    private func solid(
        _ value: (r: UInt8, g: UInt8, b: UInt8, a: UInt8),
        width: Int = 64,
        height: Int = 64
    ) throws -> CGImage {
        try rgbaImage(width: width, height: height) { _, _ in value }
    }

    private func analysis(_ image: CGImage, display: (Int, Int) = (1200, 800)) throws -> PhotoAnalysis {
        try PhotoAnalyzer.analyze(
            assetID: UUID(),
            thumbnail: image,
            displayWidth: display.0,
            displayHeight: display.1
        )
    }

    func testBlackWhiteAndMidGraySolidsMeasureExactly() throws {
        let black = try analysis(try solid((0, 0, 0, 255)))
        XCTAssertEqual(black.meanLuminance, 0, accuracy: 0.001)
        XCTAssertEqual(black.darkPixelRatio, 1, accuracy: 0.001)
        XCTAssertEqual(black.brightPixelRatio, 0, accuracy: 0.001)
        XCTAssertEqual(black.meanSaturation, 0, accuracy: 0.001)
        XCTAssertEqual(black.luminanceContrast, 0, accuracy: 0.001)

        let white = try analysis(try solid((255, 255, 255, 255)))
        XCTAssertEqual(white.meanLuminance, 1, accuracy: 0.001)
        XCTAssertEqual(white.brightPixelRatio, 1, accuracy: 0.001)
        XCTAssertEqual(white.darkPixelRatio, 0, accuracy: 0.001)
        XCTAssertEqual(white.meanSaturation, 0, accuracy: 0.001)
        XCTAssertEqual(white.luminanceContrast, 0, accuracy: 0.001)

        let gray = try analysis(try solid((128, 128, 128, 255)))
        XCTAssertEqual(gray.meanLuminance, 128.0 / 255.0, accuracy: 0.005)
        XCTAssertEqual(gray.meanRed, 128.0 / 255.0, accuracy: 0.005)
        XCTAssertEqual(gray.darkPixelRatio, 0, accuracy: 0.001)
        XCTAssertEqual(gray.brightPixelRatio, 0, accuracy: 0.001)
        XCTAssertEqual(gray.coverage, 1, accuracy: 0.0001)
        XCTAssertEqual(gray.confidence, .adequate)
        XCTAssertEqual(gray.validPixelCount, 64 * 64)
    }

    func testPureRGBChannelsUseTheDeclaredWeights() throws {
        let red = try analysis(try solid((255, 0, 0, 255)))
        XCTAssertEqual(red.meanRed, 1, accuracy: 0.005)
        XCTAssertEqual(red.meanGreen, 0, accuracy: 0.005)
        XCTAssertEqual(red.meanBlue, 0, accuracy: 0.005)
        XCTAssertEqual(red.meanLuminance, 0.2126, accuracy: 0.005)
        XCTAssertEqual(red.meanSaturation, 1, accuracy: 0.005)

        let green = try analysis(try solid((0, 255, 0, 255)))
        XCTAssertEqual(green.meanLuminance, 0.7152, accuracy: 0.005)

        let blue = try analysis(try solid((0, 0, 255, 255)))
        XCTAssertEqual(blue.meanLuminance, 0.0722, accuracy: 0.005)
    }

    func testTwoRegionImageSplitsDarkAndBrightRatios() throws {
        let image = try rgbaImage(width: 320, height: 320) { x, _ in
            x < 160 ? (0, 0, 0, 255) : (255, 255, 255, 255)
        }
        let result = try analysis(image)
        XCTAssertEqual(result.meanLuminance, 0.5, accuracy: 0.05)
        XCTAssertEqual(result.darkPixelRatio, 0.5, accuracy: 0.05)
        XCTAssertEqual(result.brightPixelRatio, 0.5, accuracy: 0.05)
        XCTAssertEqual(result.luminanceContrast, 0.5, accuracy: 0.05)
        XCTAssertLessThanOrEqual(result.luminanceContrast, 0.5)
    }

    func testSemiTransparentPixelIsUnpremultipliedBeforeStatistics() throws {
        // `rgbaImage` stores premultiplied bytes, so "pure red at alpha 128" is
        // written as (128, 0, 0, 128); un-premultiplying must recover red 1.0
        // instead of reading the stored 0.5.
        let image = try rgbaImage(width: 64, height: 64) { _, _ in (255, 0, 0, 128) }
        let result = try analysis(image)
        XCTAssertEqual(result.meanRed, 1, accuracy: 0.01)
        XCTAssertEqual(result.meanLuminance, 0.2126, accuracy: 0.01)
        XCTAssertEqual(result.coverage, 1, accuracy: 0.0001)
        XCTAssertEqual(result.validPixelCount, 64 * 64)
        XCTAssertEqual(result.confidence, .adequate)
    }

    func testFullyTransparentImageIsNoVisiblePixels() throws {
        let image = try solid((0, 0, 0, 0))
        XCTAssertThrowsError(try analysis(image)) {
            XCTAssertEqual($0 as? PhotoAnalysisFailure, .noVisiblePixels)
        }
    }

    func testCoverageAndPixelCountBothDriveSamplingConfidence() throws {
        // Half transparent: coverage 0.5 but plenty of pixels -> limited.
        let half = try rgbaImage(width: 64, height: 64) { x, _ in
            x < 32 ? (10, 10, 10, 0) : (200, 200, 200, 255)
        }
        let halfResult = try analysis(half)
        XCTAssertEqual(halfResult.coverage, 0.5, accuracy: 0.01)
        XCTAssertEqual(halfResult.validPixelCount, 64 * 32)
        XCTAssertEqual(halfResult.confidence, .limited)

        // Almost opaque: coverage above 0.75 -> adequate.
        let almost = try rgbaImage(width: 64, height: 64) { x, y in
            (x < 6 && y < 6) ? (0, 0, 0, 0) : (180, 180, 180, 255)
        }
        let almostResult = try analysis(almost)
        XCTAssertGreaterThan(almostResult.coverage, 0.75)
        XCTAssertGreaterThan(almostResult.validPixelCount, 256)
        XCTAssertEqual(almostResult.confidence, .adequate)

        // Small but fully visible: 64 pixels is below the 256-pixel minimum -> limited.
        let tiny = try analysis(try solid((200, 80, 80, 255), width: 8, height: 8))
        XCTAssertEqual(tiny.validPixelCount, 64)
        XCTAssertEqual(tiny.coverage, 1, accuracy: 0.0001)
        XCTAssertEqual(tiny.confidence, .limited)
        XCTAssertTrue(tiny.confidenceExplanation.contains("64"))
    }

    func testSampleSizeNeverUpscalesAndKeepsTheAspectRatio() throws {
        XCTAssertEqual(PhotoAnalyzer.sampleSize(forWidth: 320, height: 240)?.width, 64)
        XCTAssertEqual(PhotoAnalyzer.sampleSize(forWidth: 320, height: 240)?.height, 48)
        XCTAssertEqual(PhotoAnalyzer.sampleSize(forWidth: 1000, height: 500)?.width, 64)
        XCTAssertEqual(PhotoAnalyzer.sampleSize(forWidth: 1000, height: 500)?.height, 32)
        XCTAssertEqual(PhotoAnalyzer.sampleSize(forWidth: 40, height: 30)?.width, 40)
        XCTAssertEqual(PhotoAnalyzer.sampleSize(forWidth: 40, height: 30)?.height, 30)
        XCTAssertNil(PhotoAnalyzer.sampleSize(forWidth: 0, height: 10))

        let wide = try analysis(try solid((20, 20, 20, 255), width: 320, height: 160))
        XCTAssertEqual(wide.sampleWidth, 64)
        XCTAssertEqual(wide.sampleHeight, 32)
        let small = try analysis(try solid((20, 20, 20, 255), width: 30, height: 20))
        XCTAssertEqual(small.sampleWidth, 30)
        XCTAssertEqual(small.sampleHeight, 20)
    }

    func testNonRGBAInputBitmapIsConvertedExplicitly() throws {
        let source = try bgraImage(width: 64, height: 64) { _, _ in (0, 255, 0, 255) }
        let result = try analysis(source)
        XCTAssertEqual(result.meanGreen, 1, accuracy: 0.01)
        XCTAssertEqual(result.meanRed, 0, accuracy: 0.01)
        XCTAssertEqual(result.meanBlue, 0, accuracy: 0.01)
        XCTAssertEqual(result.meanLuminance, 0.7152, accuracy: 0.01)
    }

    func testInvalidDisplayMetadataIsRejected() throws {
        let image = try solid((128, 128, 128, 255))
        XCTAssertThrowsError(try analysis(image, display: (0, 800))) {
            XCTAssertEqual($0 as? PhotoAnalysisFailure, .invalidMetadata)
        }
        XCTAssertThrowsError(try analysis(image, display: (1200, 0))) {
            XCTAssertEqual($0 as? PhotoAnalysisFailure, .invalidMetadata)
        }
    }

    func testAlphaThresholdExcludesTwelveAndIncludesThirteen() throws {
        // Stored alpha byte 12 is exactly the excluded boundary (alpha <= 0.05);
        // byte 13 is the first included value. `rgbaImage` writes correct
        // premultiplied bytes, so the recovered colour is exact and the assertion
        // cannot pass because of quantisation error.
        let excluded = try solid((255, 0, 0, 12))
        XCTAssertThrowsError(try analysis(excluded)) {
            XCTAssertEqual($0 as? PhotoAnalysisFailure, .noVisiblePixels)
        }

        let included = try analysis(try solid((255, 0, 0, 13)))
        XCTAssertEqual(included.validPixelCount, 64 * 64)
        XCTAssertEqual(included.coverage, 1, accuracy: 1e-9)
        XCTAssertEqual(included.meanRed, 1, accuracy: 0.001)
        XCTAssertEqual(included.meanLuminance, 0.2126, accuracy: 0.005)
    }

    func testEstimateBandsUseTheFrozenThresholds() throws {
        XCTAssertEqual(try analysis(try solid((40, 40, 40, 255))).lightEstimate, .darker)
        XCTAssertEqual(try analysis(try solid((128, 128, 128, 255))).lightEstimate, .balanced)
        XCTAssertEqual(try analysis(try solid((240, 240, 240, 255))).lightEstimate, .brighter)

        XCTAssertEqual(try analysis(try solid((128, 128, 128, 255))).colorEstimate, .muted)
        XCTAssertEqual(try analysis(try solid((200, 150, 150, 255))).colorEstimate, .moderate)
        XCTAssertEqual(try analysis(try solid((255, 0, 0, 255))).colorEstimate, .colorful)
    }
}
