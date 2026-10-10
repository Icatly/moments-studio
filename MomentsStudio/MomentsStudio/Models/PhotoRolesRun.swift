import Foundation

/// The identity and request guard for one Photo roles run (Stage 06).
///
/// The sheet writes and reads **only** through this value type, so the guard that
/// is tested is the guard the UI actually uses:
/// * an observation is accepted only for the current token, **the project the sheet
///   is currently presenting**, a project that still exists, a photo that still
///   exists, and **the exact photo snapshot it was requested with**;
/// * the observed `assetID` and display size must match that photo, so an
///   observation for another asset or another size is refused instead of shown;
/// * a stored observation is displayed only for that same project and snapshot, so
///   changed metadata can never show a previous pass;
/// * `invalidate()` drops every previous value and rotates the token, and the sheet
///   calls it the moment the user closes or recomputes — so a late callback from a
///   superseded run, a recompute or a closed sheet cannot write or show anything
///   even before the replacement task starts.
struct PhotoRolesRun: Equatable {
    struct Entry: Equatable {
        let signature: String
        let observation: PhotoRoleObservation
    }

    struct Failure: Equatable {
        let signature: String
        let failure: PhotoRoleObservationFailure
    }

    let projectID: UUID
    private(set) var token: UUID
    private(set) var entries: [UUID: Entry] = [:]
    private(set) var failures: [UUID: Failure] = [:]

    init(projectID: UUID, token: UUID = UUID()) {
        self.projectID = projectID
        self.token = token
    }

    /// Invalidates the run in place: every previous value is dropped and the old
    /// token stops matching. Called on recompute and on close, before any new task
    /// exists, so an in-flight request can never write into newer state.
    mutating func invalidate() -> UUID {
        token = UUID()
        entries = [:]
        failures = [:]
        return token
    }

    /// Starts one new request for this run, for the task that still owns the current
    /// key and the presented sheet.
    ///
    /// It only rotates the token and drops the previous values when the caller's
    /// task key is still the current one: a superseded task that resumes late gets
    /// `nil` and can therefore never clear or overwrite newer state.
    mutating func beginRequest(taskKey: String, currentTaskKey: String, isSheetCurrent: Bool) -> UUID? {
        guard taskKey == currentTaskKey, isSheetCurrent else { return nil }
        return invalidate()
    }

    /// The exact identity an observation belongs to: the asset plus the stored
    /// metadata a role choice is saved against.
    /// The exact identity an observation belongs to: the stored metadata **and** the
    /// currently saved role choice.
    ///
    /// This is the single signature used by the run's accept/display guard, by the
    /// sheet's task key and by the save request's expected snapshot
    /// (`PhotoLibrary.roleSnapshot` delegates here), so "the photos and their roles
    /// are unchanged" means exactly the same thing on every path. Including the saved
    /// choice is what stops an old sheet from overwriting — or being shown for — a
    /// newer manual selection saved after it opened.
    static func signature(of photo: ImportedPhoto) -> String {
        let choice: String
        if let roleChoice = photo.roleChoice {
            choice = "\(roleChoice.role.rawValue)/\(roleChoice.source.rawValue)"
        } else {
            choice = "none"
        }
        return "\(photo.asset.id.uuidString):\(photo.asset.localReference):"
            + "\(photo.thumbnailReference):\(photo.previewReference):"
            + "\(photo.pixelWidth)x\(photo.pixelHeight):\(photo.orientation):\(photo.contentType):\(choice)"
    }

    /// Records one observation, or returns `false` when this callback belongs to a
    /// superseded run, another project, a deleted photo, changed metadata or a
    /// result measured for a different asset or display size.
    @discardableResult
    mutating func accept(
        _ observation: PhotoRoleObservation,
        observedFor photo: ImportedPhoto,
        current: ImportedPhoto?,
        token: UUID,
        currentProjectID: UUID?,
        isProjectAvailable: Bool
    ) -> Bool {
        let signature = Self.signature(of: photo)
        guard observation.assetID == photo.id,
              observation.displayWidth == photo.displayPixelSize.width,
              observation.displayHeight == photo.displayPixelSize.height,
              mayWrite(token: token, currentProjectID: currentProjectID,
                       isProjectAvailable: isProjectAvailable, signature: signature, current: current) else {
            return false
        }
        entries[photo.id] = Entry(signature: signature, observation: observation)
        failures[photo.id] = nil
        return true
    }

    /// Records one typed failure under the same identity guard. A failure replaces a
    /// previous observation for that identity and never stands in for a result.
    @discardableResult
    mutating func reject(
        _ failure: PhotoRoleObservationFailure,
        observedFor photo: ImportedPhoto,
        current: ImportedPhoto?,
        token: UUID,
        currentProjectID: UUID?,
        isProjectAvailable: Bool
    ) -> Bool {
        let signature = Self.signature(of: photo)
        guard mayWrite(token: token, currentProjectID: currentProjectID,
                       isProjectAvailable: isProjectAvailable, signature: signature, current: current) else {
            return false
        }
        failures[photo.id] = Failure(signature: signature, failure: failure)
        entries[photo.id] = nil
        return true
    }

    /// The observation to show for one photo — only when this run still belongs to
    /// the presented project and the value was observed from exactly this photo's
    /// current snapshot.
    func observation(for photo: ImportedPhoto, currentProjectID: UUID?) -> PhotoRoleObservation? {
        guard currentProjectID == projectID,
              let entry = entries[photo.id],
              entry.signature == Self.signature(of: photo) else { return nil }
        return entry.observation
    }

    func failure(for photo: ImportedPhoto, currentProjectID: UUID?) -> PhotoRoleObservationFailure? {
        guard currentProjectID == projectID,
              let failure = failures[photo.id],
              failure.signature == Self.signature(of: photo) else { return nil }
        return failure.failure
    }

    /// The policy inputs for one row, or `nil` when the stored metadata cannot
    /// produce an honest candidate.
    ///
    /// The corrected pixel area is computed with `multipliedReportingOverflow`: a
    /// legal `Int` width/height pair that would overflow is **rejected** instead of
    /// being clamped to some maximum, so damaged metadata can never masquerade as the
    /// largest photo and win the primary slot.
    ///
    /// A photo that only produced a **limited but successful** Stage 05
    /// measurement is a real success (`analysisSucceeded == true`) and stays a valid
    /// primary/supporting candidate; it simply loses the adequacy tie-break.
    func candidate(
        for photo: ImportedPhoto,
        importIndex: Int,
        manualRole: PhotoRole?,
        sceneScore: Double
    ) -> PhotoRolePolicy.Candidate? {
        guard let area = Self.pixelArea(of: photo) else { return nil }
        let observation = observation(for: photo, currentProjectID: projectID)
        return PhotoRolePolicy.Candidate(
            assetID: photo.id,
            importIndex: importIndex,
            manualRole: manualRole,
            sceneScore: sceneScore,
            analysisSucceeded: observation.flatMap(\.analysis) != nil,
            adequateSample: observation.flatMap(\.analysis)?.confidence == .adequate,
            pixelArea: area
        )
    }

    /// The EXIF-corrected pixel area, or `nil` when the stored dimensions are not
    /// positive or the product overflows `Int`.
    static func pixelArea(of photo: ImportedPhoto) -> Int? {
        let display = photo.displayPixelSize
        guard display.width > 0, display.height > 0 else { return nil }
        let (area, overflow) = display.width.multipliedReportingOverflow(by: display.height)
        guard !overflow, area > 0 else { return nil }
        return area
    }

    private func mayWrite(
        token: UUID,
        currentProjectID: UUID?,
        isProjectAvailable: Bool,
        signature: String,
        current: ImportedPhoto?
    ) -> Bool {
        guard token == self.token, currentProjectID == projectID, isProjectAvailable,
              let current else { return false }
        return Self.signature(of: current) == signature
    }
}
