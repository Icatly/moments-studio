import CoreGraphics
import Foundation
import Vision

/// What one photo's role observation could not produce.
///
/// Typed, like the Stage 05 analysis failures: a failed observation is never
/// reported as a zero measurement and never invents a confidence. The reasons are
/// deliberately coarse because the Vision work is best-effort evidence, not a
/// saved contract — nothing here is persisted.
enum PhotoRoleObservationFailure: Error, Equatable, Sendable {
    /// The photo is gone from this session's readable package.
    case missing
    /// The saved thumbnail is missing or cannot be decoded.
    case unreadable
    /// The stored metadata (size/orientation) is unusable.
    case invalidMetadata
    /// Vision could not run for this image at all (typed instead of a fake zero).
    case visionUnavailable
}

/// Read-only role evidence for one photo: the semantic inputs the deterministic
/// policy may use.
///
/// A pure value type, `Equatable`/`Sendable`, deliberately **not** `Codable`: the
/// architecture keeps no role/analysis cache on disk, so nothing here is a
/// serialization contract and every value is recomputed on demand. Model labels,
/// probabilities and face boxes never leave this value except as the booleans the
/// UI is allowed to state.
struct PhotoRoleObservation: Equatable, Sendable {
    let assetID: UUID
    let displayWidth: Int
    let displayHeight: Int
    /// Actual `VNClassifyImageRequest` revision used for this image. Vision's own
    /// `revision`/`supportedRevisions` are `Int`/`IndexSet`, so this stays `Int`
    /// instead of being reshaped into another type.
    let classifyRevision: Int
    /// Actual `VNDetectFaceRectanglesRequest` revision used for this image.
    let faceRevision: Int
    /// True when classification actually ran and returned a candidate list. It is
    /// `false` when the pass was skipped on purpose (see `skippedPixelMeasurement`).
    let classificationRan: Bool
    /// True when the Stage 05 pixel measurement failed with `noVisiblePixels`, so
    /// Vision was **skipped on purpose**: Vision ignores alpha, so running it on a
    /// fully transparent bitmap could only invent scene evidence for pixels the
    /// project counts as invisible. The typed measurement failure is kept instead.
    let skippedPixelMeasurement: Bool
    /// The identifiers this image was actually allowed to contribute, i.e. the
    /// whitelist **intersected with** `VNClassifyImageRequest.supportedIdentifiers`
    /// for the running system. Model labels outside it are never evidence.
    let supportedNaturalSceneIdentifiers: [String]
    /// Highest whitelisted, in-range natural-scene value. `0` means "no evidence":
    /// non-finite and out-of-range values are discarded, never clamped.
    let sceneScore: Double
    /// Number of usable face boxes. `0` means "none detected", never "there is no
    /// face".
    let faceCount: Int
    /// Stage 05 sampling statistics for the same thumbnail, when measurement
    /// succeeded — including a successful but `limited` sample, which is a real
    /// success and stays a valid candidate.
    let analysis: PhotoAnalysis?
    /// The Stage 05 failure, when the pixel measurement itself failed.
    let analysisFailure: PhotoAnalysisFailure?

    /// Whether the scene evidence reaches the project's natural-scene threshold.
    /// The threshold is an engineering policy of this project, not an accuracy
    /// claim.
    var looksLikeNaturalScene: Bool {
        sceneScore >= PhotoRolePolicy.naturalSceneThreshold
    }

    /// True when a face was detected, so the UI may say the original photo is
    /// kept. It never claims identity, gender or that a beauty filter is needed.
    var hasDetectedFace: Bool { faceCount > 0 }
}

/// The local, on-device role evidence pass for one already-decoded thumbnail.
///
/// Pure and synchronous: it never touches a file, never loads an original and
/// never uses SwiftUI. `PhotoLibrary` owns decoding, the path guard and
/// cancellation; the UI only ever receives the value result.
///
/// Classification evidence is filtered in two real steps, never by guessing:
/// 1. the request's own `supportedIdentifiers` (the running system's model
///    vocabulary) is read, so a label the system does not support can never be
///    treated as evidence;
/// 2. that set is intersected with this project's exact whitelist after
///    normalisation (lower-cased, `_`/`-` to spaces, whitespace collapsed). It
///    never substring-matches, so an unknown label contributes nothing instead of
///    being stretched into evidence. Anything outside is "no evidence", not a
///    negative judgement.
enum PhotoRoleAnalyzer {
    /// Model identifiers treated as natural-scene evidence in this project.
    static let naturalSceneWhitelist: Set<String> = [
        "landscape", "nature", "scenery", "outdoor", "mountain",
        "beach", "forest", "sky", "sunset", "ocean", "lake", "cityscape"
    ]

    /// The whitelist entries the running system's classifier actually supports,
    /// compared after the same normalisation as the results.
    ///
    /// `supportedIdentifiers()` is an **instance** method that throws, so it is
    /// called on a request configured exactly like the analysis pass. A request that
    /// cannot report its vocabulary yields **no** supported labels instead of
    /// falling back to the project whitelist: the app never pretends a label is
    /// supported when the system did not say so.
    static func supportedNaturalSceneVocabulary() -> [String] {
        let request = VNClassifyImageRequest()
        _ = applyNewestSupportedRevision(to: request)
        let identifiers = (try? request.supportedIdentifiers()) ?? []
        return naturalSceneVocabulary(fromSupported: identifiers)
    }

    /// The exact intersection used everywhere, so this reduction is testable without
    /// depending on which labels the current SDK happens to ship.
    static func naturalSceneVocabulary(fromSupported supported: [String]) -> [String] {
        supported
            .map(normalizedIdentifier)
            .filter { naturalSceneWhitelist.contains($0) }
            .sorted()
    }

    /// Normalises one Vision identifier for exact whitelist comparison.
    static func normalizedIdentifier(_ identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// The highest supported, in-range classification confidence, or `0` when there
    /// is no usable evidence.
    ///
    /// The caller passes the **actual** supported set (from
    /// `supportedNaturalSceneVocabulary()` or an injected one in tests), so this
    /// reduction never depends on which labels a particular OS build ships.
    /// Non-finite and out-of-range confidences are **discarded**, so a broken model
    /// response can never look like confident scene evidence.
    static func sceneScore(
        from observations: [(identifier: String, confidence: Double)],
        supportedIdentifiers: [String]
    ) -> Double {
        let supported = Set(supportedIdentifiers)
        var best = 0.0
        for observation in observations {
            guard observation.confidence.isFinite,
                  observation.confidence >= 0,
                  observation.confidence <= 1,
                  supported.contains(normalizedIdentifier(observation.identifier)) else {
                continue
            }
            best = max(best, observation.confidence)
        }
        return best
    }

    /// Counts only rectangles that are real, in-range, positive-area unit boxes.
    /// A box outside `0...1` or with a non-finite component is discarded, so a
    /// broken detection can never be reported as "a face was detected".
    static func usableFaceCount(from boxes: [CGRect]) -> Int {
        boxes.filter { box in
            let values = [box.origin.x, box.origin.y, box.size.width, box.size.height]
            guard values.allSatisfy({ $0.isFinite }) else { return false }
            return box.origin.x >= 0 && box.origin.y >= 0
                && box.size.width > 0 && box.size.height > 0
                && box.maxX <= 1 && box.maxY <= 1
        }.count
    }

    /// Applies the newest revision the request type reports as supported.
    ///
    /// `supportedRevisions` is a **class** property of the concrete `VNRequest`
    /// subclass (not a property of a request instance), while `revision` is the
    /// instance property. Both are used exactly as Vision declares them — `Int` and
    /// `IndexSet` — so the value that ran is known instead of assumed.
    static func applyNewestSupportedRevision(to request: VNRequest) -> Int {
        let supported = type(of: request).supportedRevisions
        for revision in supported.reversed() where supported.contains(revision) {
            request.revision = revision
            break
        }
        return request.revision
    }

    /// Runs classification and face detection over one thumbnail.
    ///
    /// Throws `PhotoRoleObservationFailure.visionUnavailable` when the Vision pass
    /// itself cannot run. The caller turns that into `unavailableObservation(...)`
    /// so a successful Stage 05 measurement is still usable as a limited fallback.
    ///
    /// A full-transparency measurement failure (`noVisiblePixels`) skips Vision first
    /// and reports the typed Stage 05 failure instead: Vision ignores alpha, so
    /// running it there could only produce scene evidence for pixels this project
    /// counts as invisible. No label is ever fabricated and no confidence invented.
    static func observe(
        assetID: UUID,
        thumbnail: CGImage,
        displayWidth: Int,
        displayHeight: Int,
        analysis: PhotoAnalysis?,
        analysisFailure: PhotoAnalysisFailure?
    ) throws -> PhotoRoleObservation {
        guard displayWidth > 0, displayHeight > 0 else {
            throw PhotoRoleObservationFailure.invalidMetadata
        }
        try checkCancellation()

        let supportedIdentifiers = supportedNaturalSceneVocabulary()
        if analysisFailure == .noVisiblePixels {
            return PhotoRoleObservation(
                assetID: assetID,
                displayWidth: displayWidth,
                displayHeight: displayHeight,
                classifyRevision: 0,
                faceRevision: 0,
                classificationRan: false,
                skippedPixelMeasurement: true,
                supportedNaturalSceneIdentifiers: supportedIdentifiers,
                sceneScore: 0,
                faceCount: 0,
                analysis: nil,
                analysisFailure: .noVisiblePixels
            )
        }

        let classifyRequest = VNClassifyImageRequest()
        let classifyRevision = applyNewestSupportedRevision(to: classifyRequest)
        let faceRequest = VNDetectFaceRectanglesRequest()
        let faceRevision = applyNewestSupportedRevision(to: faceRequest)

        // A synchronous best-effort pass; the caller already checked cancellation.
        // Vision failures are typed and reported, never converted into "no scene"
        // with a fabricated confidence.
        try perform([classifyRequest, faceRequest], on: thumbnail)
        try checkCancellation()

        // The request results are already typed (`[VNClassificationObservation]` /
        // `[VNFaceObservation]`), so no conditional cast is needed — and none is written,
        // because a cast that always succeeds is noise rather than a check.
        let classifications = (classifyRequest.results ?? []).map { classification in
            (classification.identifier, Double(classification.confidence))
        }
        let faces = faceRequest.results ?? []

        return PhotoRoleObservation(
            assetID: assetID,
            displayWidth: displayWidth,
            displayHeight: displayHeight,
            classifyRevision: classifyRevision,
            faceRevision: faceRevision,
            classificationRan: classifyRequest.results != nil,
            skippedPixelMeasurement: false,
            supportedNaturalSceneIdentifiers: supportedIdentifiers,
            sceneScore: sceneScore(from: classifications, supportedIdentifiers: supportedIdentifiers),
            faceCount: usableFaceCount(from: faces.map(\.boundingBox)),
            analysis: analysis,
            analysisFailure: analysisFailure
        )
    }

    /// Turns a failed Vision pass into the honest fallback for one photo.
    ///
    /// `PhotoLibrary.observeRole` calls this from its real error path, so this is the
    /// production fallback and not a parallel test helper: the successful Stage 05
    /// measurement is preserved for a limited suggestion, while the recognition is
    /// reported as unfinished (no classification run, no score, no face, no
    /// revision). Cancellation is never converted here — the caller rethrows it.
    static func observationAfterVisionFailure(
        _ failure: Error,
        assetID: UUID,
        displayWidth: Int,
        displayHeight: Int,
        analysis: PhotoAnalysis?,
        analysisFailure: PhotoAnalysisFailure?
    ) -> PhotoRoleObservation? {
        guard failure is PhotoRoleObservationFailure else { return nil }
        return unavailableObservation(
            assetID: assetID,
            displayWidth: displayWidth,
            displayHeight: displayHeight,
            analysis: analysis,
            analysisFailure: analysisFailure
        )
    }

    /// The honest fallback when the Vision pass could not run.
    ///
    /// It keeps the **successful** Stage 05 measurement so the policy can still make
    /// a limited suggestion from light/size, and it states the recognition as
    /// unfinished instead of pretending: no classification ran, no scene score, no
    /// face count and no revision are claimed.
    static func unavailableObservation(
        assetID: UUID,
        displayWidth: Int,
        displayHeight: Int,
        analysis: PhotoAnalysis?,
        analysisFailure: PhotoAnalysisFailure?
    ) -> PhotoRoleObservation {
        PhotoRoleObservation(
            assetID: assetID,
            displayWidth: displayWidth,
            displayHeight: displayHeight,
            classifyRevision: 0,
            faceRevision: 0,
            classificationRan: false,
            skippedPixelMeasurement: false,
            supportedNaturalSceneIdentifiers: supportedNaturalSceneVocabulary(),
            sceneScore: 0,
            faceCount: 0,
            analysis: analysis,
            analysisFailure: analysisFailure
        )
    }

    private static func perform(_ requests: [VNRequest], on image: CGImage) throws {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform(requests)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PhotoRoleObservationFailure.visionUnavailable
        }
    }

    private static func checkCancellation() throws {
        if Task.isCancelled { throw CancellationError() }
    }
}
