import CoreGraphics
import Foundation

/// Why one photo could not be analyzed.
///
/// Typed instead of a fake zero row: a failure never reports statistics and
/// never stands in for a previous success. `CancellationError` is deliberately
/// **not** part of this type — cancellation propagates and is never converted
/// into an ordinary bad-photo result.
enum PhotoAnalysisFailure: Error, Equatable, Sendable {
    /// The photo is not in the current, readable package (deleted, or the project
    /// is unavailable in this session).
    case missing
    /// The generated thumbnail is gone or cannot be decoded.
    case unreadable
    /// The stored metadata (pixel size and/or EXIF orientation) is unusable.
    case invalidMetadata
    /// Every sampled pixel was transparent (alpha at or below the threshold).
    case noVisiblePixels
}

/// How much of the sample the statistics actually rest on.
///
/// This is **sampling sufficiency only** — an engineering policy of this project,
/// not a trained AI probability, not a judgement of the photo and not an
/// exposure, aesthetic or semantic confidence.
enum PhotoAnalysisConfidence: String, Equatable, Sendable {
    case adequate
    case limited
}

/// Three-way light estimate shown in the UI, from the mean sRGB luminance proxy.
enum PhotoLightEstimate: String, Equatable, Sendable {
    case darker
    case balanced
    case brighter
}

/// Three-way colour estimate shown in the UI, from the mean HSV saturation.
enum PhotoColorEstimate: String, Equatable, Sendable {
    case muted
    case moderate
    case colorful
}

/// One photo's read-only light/colour estimate.
///
/// A value type that is `Equatable`/`Sendable` and deliberately **not** `Codable`:
/// the current architecture keeps no analysis cache on disk, so nothing here is a
/// serialization contract and every value is recomputed on demand.
struct PhotoAnalysis: Equatable, Sendable {
    let assetID: UUID
    /// EXIF-corrected display size of the stored original.
    let displayWidth: Int
    let displayHeight: Int
    /// Size of the sampled bitmap (longest side at most `PhotoAnalyzer.maximumSampleSide`).
    let sampleWidth: Int
    let sampleHeight: Int
    /// Pixels counted, i.e. those above the alpha threshold.
    let validPixelCount: Int
    let meanRed: Double
    let meanGreen: Double
    let meanBlue: Double
    let meanLuminance: Double
    /// Population standard deviation of the luminance proxy, in `0...0.5`.
    let luminanceContrast: Double
    let meanSaturation: Double
    let darkPixelRatio: Double
    let brightPixelRatio: Double
    /// Valid pixels / sampled pixels.
    let coverage: Double
    let confidence: PhotoAnalysisConfidence

    var totalPixelCount: Int { sampleWidth * sampleHeight }

    var lightEstimate: PhotoLightEstimate {
        if meanLuminance < 0.25 { return .darker }
        if meanLuminance <= 0.75 { return .balanced }
        return .brighter
    }

    var colorEstimate: PhotoColorEstimate {
        if meanSaturation < 0.2 { return .muted }
        if meanSaturation <= 0.5 { return .moderate }
        return .colorful
    }

    /// The stated basis for `confidence`, with the actual numbers, so the UI can
    /// explain a weak sample instead of implying an accuracy it does not have.
    var confidenceExplanation: String {
        "Sampled \(validPixelCount) of \(totalPixelCount) pixels (coverage "
            + String(format: "%.2f", coverage) + "); "
            + (confidence == .adequate
               ? "enough for a thumbnail estimate."
               : "too little for a full estimate — treat it as a rough thumbnail guess.")
    }
}

/// Bounded, deterministic pixel statistics over one already-decoded thumbnail.
///
/// Pure CoreGraphics/Foundation: it never touches a file, never loads an
/// original, never uses SwiftUI and never schedules work. The caller (the
/// `PhotoLibrary` actor) owns decoding and file access; the UI only ever receives
/// the value result.
///
/// Frozen sampling decisions (verified by tests and recorded in the Stage 05
/// report):
/// * the longest side is scaled down to at most `maximumSampleSide` pixels;
///   smaller inputs are never upscaled, and the aspect ratio is preserved within
///   one pixel of integer rounding;
/// * the pixels are drawn into an explicit 8-bit sRGB RGBA context
///   (`premultipliedLast | byteOrder32Big`, one byte each for r, g, b, a in that
///   memory order) with `.high` interpolation, so no input pixel format or colour
///   space is assumed;
/// * a pixel whose alpha is at or below 0.05 is excluded; the remaining pixels are
///   un-premultiplied before the equal-weight statistics, so a transparent edge is
///   never counted as black.
enum PhotoAnalyzer {
    /// Longest side of the analysis sample, in pixels.
    static let maximumSampleSide = 64

    /// Alpha encoded at `Int((0.05 * 255).rounded(.down))`. A pixel is excluded when
    /// its stored alpha byte is at or below this value, i.e. alpha <= 0.05.
    static let minimumIncludedAlphaByte = 12

    /// A sample is only `adequate` when it has both enough pixels and enough
    /// coverage; either alone is `limited`.
    static let adequateMinimumPixelCount = 256
    static let adequateMinimumCoverage = 0.75

    /// Luminance proxy thresholds for the dark/bright ratios.
    static let darkLuminanceThreshold = 0.1
    static let brightLuminanceThreshold = 0.9

    /// The sample size for one decoded thumbnail, or `nil` when the input has no
    /// usable size.
    static func sampleSize(forWidth width: Int, height: Int) -> (width: Int, height: Int)? {
        guard width > 0, height > 0 else { return nil }
        let longest = max(width, height)
        let scale = longest > maximumSampleSide ? Double(maximumSampleSide) / Double(longest) : 1
        return (
            max(1, Int((Double(width) * scale).rounded(.down))),
            max(1, Int((Double(height) * scale).rounded(.down)))
        )
    }

    /// Measures one decoded thumbnail.
    ///
    /// - Throws: `PhotoAnalysisFailure.invalidMetadata` for unusable display or
    ///   bitmap sizes, `.unreadable` when the bitmap cannot be drawn, and
    ///   `.noVisiblePixels` when every sampled pixel is transparent.
    ///   `CancellationError` is thrown before decoding-adjacent work and after the
    ///   draw when the surrounding task was cancelled.
    static func analyze(
        assetID: UUID,
        thumbnail: CGImage,
        displayWidth: Int,
        displayHeight: Int
    ) throws -> PhotoAnalysis {
        guard displayWidth > 0, displayHeight > 0 else {
            throw PhotoAnalysisFailure.invalidMetadata
        }
        try checkCancellation()
        guard let sample = sampleSize(forWidth: thumbnail.width, height: thumbnail.height) else {
            throw PhotoAnalysisFailure.invalidMetadata
        }

        // One explicit layout for every input: 8-bit sRGB, RGBA in memory, alpha
        // premultiplied. `premultipliedLast | byteOrder32Big` is the documented
        // combination in which byte 0 is red, 1 green, 2 blue and 3 alpha.
        //
        // The colour space must be the real sRGB space: falling back to a device
        // space while still calling the numbers "sRGB" would silently change what
        // the statistics mean, so a missing sRGB space is a typed failure.
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw PhotoAnalysisFailure.unreadable
        }
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: sample.width,
            height: sample.height,
            bitsPerComponent: 8,
            bytesPerRow: sample.width * 4,
            space: sRGB,
            bitmapInfo: bitmapInfo
        ) else {
            throw PhotoAnalysisFailure.unreadable
        }
        context.interpolationQuality = .high
        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: sample.width, height: sample.height))
        try checkCancellation()
        guard let data = context.data else { throw PhotoAnalysisFailure.unreadable }

        let buffer = data.bindMemory(to: UInt8.self, capacity: sample.width * sample.height * 4)
        let total = sample.width * sample.height
        let minimumAlpha = UInt8(minimumIncludedAlphaByte)

        var valid = 0
        var sumRed = 0.0
        var sumGreen = 0.0
        var sumBlue = 0.0
        var sumLuminance = 0.0
        var sumLuminanceSquared = 0.0
        var sumSaturation = 0.0
        var dark = 0
        var bright = 0

        for index in stride(from: 0, to: total * 4, by: 4) {
            let alphaByte = buffer[index + 3]
            guard alphaByte > minimumAlpha else { continue }
            let alpha = Double(alphaByte) / 255
            // Stored values are premultiplied; divide them back out before the
            // statistic so a semi-transparent pixel keeps its real colour. The
            // clamp only absorbs rounding (premultiplied data can round slightly up).
            let red = min(1, Double(buffer[index]) / 255 / alpha)
            let green = min(1, Double(buffer[index + 1]) / 255 / alpha)
            let blue = min(1, Double(buffer[index + 2]) / 255 / alpha)

            // Relative luminance proxy on encoded sRGB — not physical illuminance,
            // photographic EV or linear-light luminance.
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            let maximum = max(red, green, blue)
            let minimum = min(red, green, blue)
            let saturation = maximum > 0 ? (maximum - minimum) / maximum : 0

            valid += 1
            sumRed += red
            sumGreen += green
            sumBlue += blue
            sumLuminance += luminance
            sumLuminanceSquared += luminance * luminance
            sumSaturation += saturation
            if luminance <= darkLuminanceThreshold { dark += 1 }
            if luminance >= brightLuminanceThreshold { bright += 1 }
        }

        guard valid > 0 else { throw PhotoAnalysisFailure.noVisiblePixels }

        let count = Double(valid)
        let meanLuminance = clamp01(sumLuminance / count)
        // A tiny negative variance is floating-point error and becomes zero. The
        // upper clamp only absorbs error too: for values in [0,1] the true standard
        // deviation can never exceed 0.5.
        let variance = max(0, sumLuminanceSquared / count - meanLuminance * meanLuminance)
        let coverage = Double(valid) / Double(total)
        let confidence: PhotoAnalysisConfidence =
            valid >= adequateMinimumPixelCount && coverage >= adequateMinimumCoverage ? .adequate : .limited

        return PhotoAnalysis(
            assetID: assetID,
            displayWidth: displayWidth,
            displayHeight: displayHeight,
            sampleWidth: sample.width,
            sampleHeight: sample.height,
            validPixelCount: valid,
            meanRed: clamp01(sumRed / count),
            meanGreen: clamp01(sumGreen / count),
            meanBlue: clamp01(sumBlue / count),
            meanLuminance: meanLuminance,
            luminanceContrast: min(0.5, variance.squareRoot()),
            meanSaturation: clamp01(sumSaturation / count),
            darkPixelRatio: clamp01(Double(dark) / count),
            brightPixelRatio: clamp01(Double(bright) / count),
            coverage: clamp01(coverage),
            confidence: confidence
        )
    }

    private static func clamp01(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    private static func checkCancellation() throws {
        if Task.isCancelled { throw CancellationError() }
    }
}
