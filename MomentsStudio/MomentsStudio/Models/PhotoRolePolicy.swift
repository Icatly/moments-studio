import Foundation

/// The deterministic Stage 06 role policy.
///
/// Pure values in, pure values out: no Vision, no files, no SwiftUI, no
/// randomness and no clock. The same inputs always produce the same suggestion,
/// which is what makes the rule testable without a device and what keeps "the
/// system suggested this" separate from "the user chose this".
///
/// The policy only ever produces `primary`/`supporting`. It never excludes a photo
/// and never reserves collage material, because those are user decisions.
enum PhotoRolePolicy {
    /// Scene evidence at or above this value counts as a possible natural scene.
    /// This is an engineering threshold of this project, **not** an accuracy claim.
    static let naturalSceneThreshold = 0.5

    /// One photo's inputs, already reduced to usable values.
    ///
    /// * `sceneScore` is a plain `Double`: non-finite and out-of-range values are
    ///   **discarded** by the analyzer before they get here, never clamped into
    ///   strong evidence. `0` means "no natural-scene evidence".
    /// * `analysisSucceeded` and `adequateSample` are deliberately separate. A
    ///   Stage 05 measurement that succeeded with a small sample is still a real
    ///   success and remains a valid primary/supporting candidate; `adequateSample`
    ///   is only the ranking tie-break the specification asks for.
    struct Candidate: Equatable {
        let assetID: UUID
        let importIndex: Int
        let manualPrimary: Bool
        let manualSupporting: Bool
        /// `true` for manual collageMaterial/excluded: such a photo is never
        /// auto-promoted and is not part of the automatic pass at all.
        let manualNonParticipating: Bool
        let sceneScore: Double
        let analysisSucceeded: Bool
        let adequateSample: Bool
        let pixelArea: Int

        init(
            assetID: UUID,
            importIndex: Int,
            manualRole: PhotoRole?,
            sceneScore: Double,
            analysisSucceeded: Bool,
            adequateSample: Bool,
            pixelArea: Int
        ) {
            self.assetID = assetID
            self.importIndex = importIndex
            self.manualPrimary = manualRole == .primary
            self.manualSupporting = manualRole == .supporting
            self.manualNonParticipating = manualRole == .collageMaterial || manualRole == .excluded
            self.sceneScore = Self.validatedScore(sceneScore)
            self.analysisSucceeded = analysisSucceeded
            self.adequateSample = adequateSample
            self.pixelArea = pixelArea
        }

        /// The one place a score is accepted: finite and inside `0...1`, otherwise
        /// it becomes "no evidence". Out-of-range input is dropped, not clamped.
        static func validatedScore(_ score: Double) -> Double {
            guard score.isFinite, score >= 0, score <= 1 else { return 0 }
            return score
        }

        /// Evidence that lets this photo be part of the automatic arrangement: a
        /// real Stage 05 measurement (even a limited sample) or natural-scene
        /// evidence above the threshold.
        var hasEvidence: Bool {
            analysisSucceeded || sceneScore >= PhotoRolePolicy.naturalSceneThreshold
        }
    }

    /// The suggestion for one photo.
    enum Suggestion: Equatable {
        case role(PhotoRole)
        case none
        case failed

        var role: PhotoRole? {
            if case .role(let role) = self { return role }
            return nil
        }
    }

    struct Outcome: Equatable {
        let suggestions: [UUID: Suggestion]
    }

    /// The automatic suggestion for one ordered photo list.
    ///
    /// Rules, in order:
    /// 1. a manual primary freezes the primary slot — every other automatic photo
    ///    becomes supporting;
    /// 2. otherwise one primary is chosen from the automatic candidates (not manual
    ///    collage/excluded and **not** a manual supporting photo) that produced
    ///    evidence, ordered by scene score (below the threshold counts as zero),
    ///    then by adequate Stage 05 sampling, then by corrected pixel area
    ///    descending, then by import order;
    /// 3. every other automatic photo with evidence becomes supporting;
    /// 4. a photo where **both** the pixel measurement and the semantic pass failed
    ///    has no suggestion and is reported as failed — a limited-but-successful
    ///    measurement is never reported as a failure.
    static func suggest(_ candidates: [Candidate]) -> Outcome {
        let ordered = candidates.sorted { $0.importIndex < $1.importIndex }
        let manualPrimary = ordered.first { $0.manualPrimary }

        var primaryID: UUID?
        if let manualPrimary {
            primaryID = manualPrimary.assetID
        } else {
            let pool = ordered.filter {
                !$0.manualNonParticipating && !$0.manualPrimary && !$0.manualSupporting
            }
            primaryID = pool.filter(\.hasEvidence).max { lhs, rhs in
                isOrderedBefore(lhs, rhs)
            }?.assetID
        }

        var suggestions: [UUID: Suggestion] = [:]
        for candidate in ordered {
            if candidate.manualNonParticipating {
                // The user said this photo is not for layout: no automatic opinion.
                suggestions[candidate.assetID] = .none
                continue
            }
            if let manualPrimary, candidate.assetID == manualPrimary.assetID {
                suggestions[candidate.assetID] = .role(.primary)
                continue
            }
            if candidate.manualSupporting {
                suggestions[candidate.assetID] = .role(.supporting)
                continue
            }
            guard candidate.hasEvidence else {
                suggestions[candidate.assetID] = .failed
                continue
            }
            suggestions[candidate.assetID] = .role(candidate.assetID == primaryID ? .primary : .supporting)
        }
        return Outcome(suggestions: suggestions)
    }

    /// Ranks two automatic candidates. Scene evidence below the threshold counts
    /// as zero (so a weak "maybe a landscape" never outranks a real one), then a
    /// full Stage 05 sample wins, then the larger corrected photo, and finally the
    /// stable import order decides a tie.
    static func isOrderedBefore(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        let lhsScene = effectiveSceneScore(lhs.sceneScore)
        let rhsScene = effectiveSceneScore(rhs.sceneScore)
        if lhsScene != rhsScene { return lhsScene < rhsScene }
        if lhs.adequateSample != rhs.adequateSample { return !lhs.adequateSample }
        if lhs.pixelArea != rhs.pixelArea { return lhs.pixelArea < rhs.pixelArea }
        return lhs.importIndex > rhs.importIndex
    }

    static func effectiveSceneScore(_ score: Double) -> Double {
        guard score.isFinite, score >= naturalSceneThreshold else { return 0 }
        return min(1, score)
    }

    /// What one row currently shows: the user's own selection wins, otherwise the
    /// last automatic suggestion. `nil` means no role is shown.
    static func displayedRole(manual: PhotoRole?, suggestion: Suggestion) -> PhotoRole? {
        manual ?? suggestion.role
    }

    /// The choices one Save would materialise for the whole project, as a **total**
    /// map: a candidate with no usable choice is **absent** from the map, and absent
    /// means the save clears any previously stored value.
    ///
    /// It resolves the real draft states (`PhotoRoleDraft`):
    /// * an explicit role is stored as `manual`;
    /// * an explicit Automatic stores this pass's fresh `automatic` suggestion when
    ///   there is one, otherwise clears the choice — so recomputation refreshes an
    ///   automatic role and can never resurrect an old one;
    /// * an untouched photo keeps its captured saved value **only when it was the
    ///   user's own manual choice**; a captured `automatic` choice is recomputed and
    ///   refreshed, exactly like an explicit Automatic, because it is not a manual
    ///   decision;
    /// * a photo with no usable suggestion stays absent → cleared.
    static func choices(
        candidates: [Candidate],
        draft: [UUID: PhotoRoleDraft],
        capturedRoles: [UUID: PhotoRoleChoice?],
        outcome: Outcome
    ) -> [UUID: PhotoRoleChoice] {
        var result: [UUID: PhotoRoleChoice] = [:]
        for candidate in candidates {
            let freshAutomatic: PhotoRoleChoice? = {
                guard case .role(let role)? = outcome.suggestions[candidate.assetID],
                      PhotoRole.automaticCandidates.contains(role) else { return nil }
                return .automatic(role)
            }()
            switch PhotoRoleDraft.value(in: draft, for: candidate.assetID) {
            case .role(let role):
                result[candidate.assetID] = .manual(role)
            case .automatic:
                result[candidate.assetID] = freshAutomatic
            case .absent:
                if let captured = capturedRoles[candidate.assetID] ?? nil, captured.source == .manual {
                    result[candidate.assetID] = captured
                } else {
                    result[candidate.assetID] = freshAutomatic
                }
            }
        }
        return result
    }
}

/// The layout-facing view of saved roles.
///
/// `nil` (no saved choice) keeps the frozen Stage 04 behaviour exactly, so a
/// project that never opened Photo roles arranges precisely as before.
enum PhotoRoleLayoutPlan {
    /// Photos that take part in the automatic arrangement: no saved choice, or a
    /// saved primary/supporting. Collage material and excluded photos are kept in
    /// the library and on the canvas but never added, moved or hidden.
    static func participatingPhotoIDs(_ photos: [ImportedPhoto]) -> Set<UUID> {
        Set(photos.filter { $0.roleChoice?.role.participatesInLayout ?? true }.map(\.id))
    }

    /// The saved primary photo, when there is one.
    static func primaryPhotoID(_ photos: [ImportedPhoto]) -> UUID? {
        photos.first { $0.roleChoice?.role == .primary }?.id
    }

    /// True when the project has photos but the user has saved every one of them as
    /// collage material or "not for layout". The layout screen must say that instead
    /// of telling the user to import photos that are already there.
    static func hasNoLayoutParticipant(_ photos: [ImportedPhoto]) -> Bool {
        !photos.isEmpty && participatingPhotoIDs(photos).isEmpty
    }

    /// The arrangement order the layout engine should **compute** against.
    ///
    /// Only Focus gives the saved primary photo the hero position: Grid and Offset
    /// keep the frozen Stage 04 order exactly, so a saved role never changes their
    /// composition.
    ///
    /// When the same asset owns several movable layers, **only its first layer in the
    /// existing order** is moved to the computed hero position. Every other layer —
    /// including the primary asset's own later layers — keeps its original relative
    /// order, so no layer is reordered against its own asset. The stored layer order,
    /// z-order, identities, sizes, opacity and protected layers are never touched;
    /// only which cell each movable layer is computed into changes.
    static func arrangementOrder(
        _ movable: [Layer],
        preset: CollagePreset,
        primaryAssetID: UUID?
    ) -> [Layer] {
        guard preset == .focus, let primaryAssetID else { return movable }
        guard let heroIndex = movable.firstIndex(where: { $0.assetID == primaryAssetID }) else {
            return movable
        }
        let hero = movable[heroIndex]
        let rest = movable.enumerated()
            .filter { $0.offset != heroIndex }
            .map(\.element)
        return [hero] + rest
    }
}
