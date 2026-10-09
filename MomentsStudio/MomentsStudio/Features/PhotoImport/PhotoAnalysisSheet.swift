import SwiftUI

/// Read-only per-photo light/colour summary.
///
/// Opening it starts a bounded analysis of the project's imported photos, one at a
/// time and in import order (at most the project's photo limit). It never writes a
/// project: no manifest, no layer, no photo, no failed draft. Closing cancels the
/// run, "Analyze again" recomputes from scratch, and a stored result only ever
/// belongs to the photo identity and metadata it was measured from.
///
/// The numbers are thumbnail estimates of encoded sRGB; they are not photographic
/// exposure, not a semantic judgement of the photo and not an AI probability.
@MainActor
struct PhotoAnalysisSheet: View {
    let projectID: UUID

    @Environment(ProjectStore.self) private var store
    @Environment(PhotoImportModel.self) private var photoImport
    @Environment(AppNavigationModel.self) private var navigation

    /// Results, failures, project identity and request token — the exact guard the
    /// UI writes and reads through (`PhotoAnalysisRun`).
    @State private var run: PhotoAnalysisRun
    @State private var isRunning = false
    @State private var reloadID = 0

    private var photos: [ImportedPhoto] { store.photos(for: projectID) }

    /// Measurements that can actually be shown for the presented project and the
    /// current photo metadata.
    private var displayedCount: Int {
        photos.filter { run.measurement(for: $0, currentProjectID: presentedProjectID) != nil }.count
    }

    /// The project the sheet is presenting right now (`nil` once it is dismissed).
    private var presentedProjectID: UUID? {
        guard case .photoAnalysis(let id)? = navigation.sheet else { return nil }
        return id
    }

    private var isSheetCurrent: Bool {
        presentedProjectID == projectID && store.openProject(id: projectID) != nil
    }

    init(projectID: UUID) {
        self.projectID = projectID
        _run = State(initialValue: PhotoAnalysisRun(projectID: projectID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    if store.openProject(id: projectID) == nil {
                        Text("This project is no longer available.")
                            .font(Typography.body)
                            .foregroundStyle(Color.secondary)
                            .accessibilityIdentifier("analysis.missingProject")
                    } else if photos.isEmpty {
                        Text("Import photos to see a light and colour estimate for each of them.")
                            .font(Typography.body)
                            .foregroundStyle(Color.secondary)
                            .accessibilityIdentifier("analysis.empty")
                    } else {
                        Text("Thumbnail estimates only. Nothing here is saved and your project is not changed.")
                            .font(Typography.body)
                            .foregroundStyle(Color.secondary)

                        Text("Analyzed \(displayedCount) of \(photos.count) photos")
                            .font(Typography.caption)
                            .foregroundStyle(Color.secondary)
                            .accessibilityIdentifier("analysis.status")

                        if isRunning {
                            ProgressView("Analyzing…")
                                .accessibilityIdentifier("analysis.running")
                        }

                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            row(photo, index: index)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.medium)
            }
            .accessibilityIdentifier("analysis.scroll")
            .navigationTitle("Photo summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismissIfCurrent() }
                        .frame(minHeight: Layout.minimumTapTarget)
                        .accessibilityIdentifier("analysis.close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Analyze again") {
                        // Invalidate first: an in-flight request must not write once
                        // the user asked for a recompute, even before the new task
                        // has started.
                        run.invalidate()
                        reloadID += 1
                    }
                    .frame(minHeight: Layout.minimumTapTarget)
                    .disabled(photos.isEmpty)
                    .accessibilityIdentifier("analysis.analyzeAgain")
                }
            }
        }
        // The key carries the project, the ordered photo identities and their
        // metadata, plus the manual reload counter: any change restarts the run,
        // and closing the sheet cancels the task.
        .task(id: taskKey) {
            await startRun()
        }
        .onDisappear {
            // Closing invalidates the run immediately, so a late callback cannot
            // write into a sheet that is gone.
            run.invalidate()
        }
    }

    /// Runs on the main actor so the run state is only ever mutated there.
    ///
    /// Every real new task starts its **own** request only after proving it is still
    /// current (not cancelled, still the presented sheet, the run still belongs to
    /// this project), and that request atomically rotates the token and drops the
    /// previous values. A superseded task can therefore never rotate or clear newer
    /// state, and its `defer` can never clear the new run's `isRunning`.
    @MainActor
    private func startRun() async {
        let key = taskKey
        guard !Task.isCancelled, isSheetCurrent, run.projectID == projectID else { return }
        guard let token = run.beginRequest(taskKey: key, currentTaskKey: taskKey,
                                           isSheetCurrent: isSheetCurrent) else { return }
        await analyze(photos: photos, token: token, taskKey: key)
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(_ photo: ImportedPhoto, index: Int) -> some View {
        let display = photo.displayPixelSize
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .top, spacing: Spacing.medium) {
                DerivedImageView(
                    reference: photo.thumbnailReference,
                    contentMode: .fill,
                    load: { reference in await photoImport.loadImage(reference: reference) },
                    placeholder: { Color.secondary.opacity(0.15) }
                )
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Radius.thumbnail, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                    Text("Photo \(index + 1)")
                        .font(Typography.body)
                    Text("Display \(display.width) × \(display.height) px")
                        .font(Typography.caption)
                        .foregroundStyle(Color.secondary)
                        .accessibilityIdentifier("analysis.size.\(photo.id.uuidString)")
                    estimate(photo)
                }

                Spacer(minLength: 0)
            }
            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analysis.row.\(photo.id.uuidString)")
    }

    @ViewBuilder
    private func estimate(_ photo: ImportedPhoto) -> some View {
        if let analysis = run.measurement(for: photo, currentProjectID: presentedProjectID) {
            Text("Estimated \(analysis.lightEstimate.rawValue) light, \(analysis.colorEstimate.rawValue) colour")
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("analysis.estimate.\(photo.id.uuidString)")
            if analysis.confidence == .limited {
                // User language only: the pixel counts, coverage and thresholds stay
                // in the analysis data, the report and the tests.
                Text("Not much visible detail to measure here — treat this as a rough estimate.")
                    .font(Typography.caption)
                    .foregroundStyle(Color.secondary)
                    .accessibilityIdentifier("analysis.lowConfidence.\(photo.id.uuidString)")
            }
        } else if let failure = run.failure(for: photo, currentProjectID: presentedProjectID) {
            Text(Self.message(for: failure))
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("analysis.failure.\(photo.id.uuidString)")
        } else {
            Text(isRunning ? "Analyzing…" : "Not analyzed yet.")
                .font(Typography.caption)
                .foregroundStyle(Color.secondary)
                .accessibilityIdentifier("analysis.pending.\(photo.id.uuidString)")
        }
    }

    // MARK: - Analysis run

    private var taskKey: String {
        let signature = photos.map(PhotoAnalysisRun.signature(of:)).joined(separator: "|")
        return "\(projectID.uuidString)|\(reloadID)|\(signature)"
    }

    /// The live copy of one photo, so a write-back compares the metadata the
    /// measurement was requested with against the metadata that is current now.
    private func currentPhoto(_ assetID: UUID) -> ImportedPhoto? {
        photos.first { $0.id == assetID }
    }

    private func analyze(photos: [ImportedPhoto], token: UUID, taskKey key: String) async {
        guard !photos.isEmpty else {
            isRunning = false
            return
        }
        isRunning = true
        defer {
            if run.token == token { isRunning = false }
        }

        for photo in photos {
            guard !Task.isCancelled, run.token == token, isSheetCurrent, taskKey == key else { return }
            do {
                let analysis = try await photoImport.analyzePhoto(projectID: projectID, assetID: photo.id)
                // After the await the task re-checks cancellation, the token, the
                // presented sheet and **its own captured task key** against the
                // current one, then the guard re-checks the project identity, the
                // photo's current metadata and the measured asset/display size.
                guard !Task.isCancelled, run.token == token, isSheetCurrent, taskKey == key else { return }
                guard run.accept(analysis, measuredFor: photo, current: currentPhoto(photo.id),
                                 token: token, currentProjectID: presentedProjectID,
                                 isProjectAvailable: store.openProject(id: projectID) != nil) else { return }
            } catch is CancellationError {
                // Closing, recomputing or changing the photo set cancels the run;
                // a cancelled photo is neither a result nor a failure.
                return
            } catch let failure as PhotoAnalysisFailure {
                guard !Task.isCancelled, run.token == token, isSheetCurrent, taskKey == key else { return }
                guard run.reject(failure, measuredFor: photo, current: currentPhoto(photo.id),
                                 token: token, currentProjectID: presentedProjectID,
                                 isProjectAvailable: store.openProject(id: projectID) != nil) else { return }
            } catch {
                guard !Task.isCancelled, run.token == token, isSheetCurrent, taskKey == key else { return }
                guard run.reject(.unreadable, measuredFor: photo, current: currentPhoto(photo.id),
                                 token: token, currentProjectID: presentedProjectID,
                                 isProjectAvailable: store.openProject(id: projectID) != nil) else { return }
            }
        }
    }

    private func dismissIfCurrent() {
        if navigation.sheet == .photoAnalysis(projectID: projectID) {
            // Close invalidates the run synchronously, in the same action that asks
            // the route to dismiss: an in-flight request is refused from this moment,
            // and `.onDisappear` stays as the backstop for any other dismissal path.
            run.invalidate()
            navigation.dismissSheet()
        }
    }

    private static func message(for failure: PhotoAnalysisFailure) -> String {
        switch failure {
        case .missing: return "This photo is no longer part of the project."
        case .unreadable: return "The saved thumbnail could not be read."
        case .invalidMetadata: return "This photo's saved size or orientation is unusable."
        case .noVisiblePixels: return "There are no visible pixels in this photo to measure."
        }
    }
}

/// The identity and request guard for one Photo summary run.
///
/// The sheet writes and reads **only** through this value type, so the guard that
/// is tested is the guard the UI actually uses:
/// * a value is accepted only for the current token, **the project the sheet is
///   currently presenting**, a project that still exists, a photo that still
///   exists, and **the exact metadata it was requested with**;
/// * the measured `assetID` and display size must match that photo, so a result
///   for another asset or another size is refused instead of shown;
/// * a value is displayed only for that same project and metadata, so changed
///   metadata can never show a previous measurement;
/// * `invalidate()` drops every previous value and rotates the token, and the sheet
///   calls it the moment the user closes or recomputes — so a late callback from a
///   superseded run, a recompute or a closed sheet cannot write or show anything
///   even before the replacement task starts.
struct PhotoAnalysisRun: Equatable {
    struct Measurement: Equatable {
        let signature: String
        let analysis: PhotoAnalysis
    }

    struct Failure: Equatable {
        let signature: String
        let failure: PhotoAnalysisFailure
    }

    let projectID: UUID
    private(set) var token: UUID
    private(set) var measurements: [UUID: Measurement] = [:]
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
        measurements = [:]
        failures = [:]
        return token
    }

    /// Starts one new request for this run, for the task that still owns the current
    /// key and the presented sheet.
    ///
    /// It only rotates the token and drops the previous values when the caller's
    /// task key is still the current one: a superseded task that resumes late gets
    /// `nil` and can therefore never clear or overwrite newer state. Returns the new
    /// token, or `nil` when this caller must not start a request.
    mutating func beginRequest(taskKey: String, currentTaskKey: String, isSheetCurrent: Bool) -> UUID? {
        guard taskKey == currentTaskKey, isSheetCurrent else { return nil }
        return invalidate()
    }

    /// The exact identity a measurement belongs to: the asset plus the metadata
    /// that would change what the estimate means.
    static func signature(of photo: ImportedPhoto) -> String {
        "\(photo.asset.id.uuidString):\(photo.thumbnailReference):"
            + "\(photo.pixelWidth)x\(photo.pixelHeight):\(photo.orientation)"
    }

    /// Records one measured value, or returns `false` when this callback belongs to
    /// a superseded run, another project, a deleted photo, changed metadata or a
    /// result measured for a different asset or display size.
    @discardableResult
    mutating func accept(
        _ analysis: PhotoAnalysis,
        measuredFor photo: ImportedPhoto,
        current: ImportedPhoto?,
        token: UUID,
        currentProjectID: UUID?,
        isProjectAvailable: Bool
    ) -> Bool {
        let signature = Self.signature(of: photo)
        guard analysis.assetID == photo.id,
              analysis.displayWidth == photo.displayPixelSize.width,
              analysis.displayHeight == photo.displayPixelSize.height,
              mayWrite(token: token, currentProjectID: currentProjectID,
                       isProjectAvailable: isProjectAvailable, signature: signature, current: current) else {
            return false
        }
        measurements[photo.id] = Measurement(signature: signature, analysis: analysis)
        failures[photo.id] = nil
        return true
    }

    /// Records one typed failure under the same identity guard. A failure replaces a
    /// previous success for that identity and never stands in for an estimate.
    @discardableResult
    mutating func reject(
        _ failure: PhotoAnalysisFailure,
        measuredFor photo: ImportedPhoto,
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
        measurements[photo.id] = nil
        return true
    }

    /// The estimate to show for one photo — only when this run still belongs to the
    /// presented project and the value was measured from exactly this photo's
    /// current metadata.
    func measurement(for photo: ImportedPhoto, currentProjectID: UUID?) -> PhotoAnalysis? {
        guard currentProjectID == projectID,
              let measurement = measurements[photo.id],
              measurement.signature == Self.signature(of: photo) else { return nil }
        return measurement.analysis
    }

    func failure(for photo: ImportedPhoto, currentProjectID: UUID?) -> PhotoAnalysisFailure? {
        guard currentProjectID == projectID,
              let failure = failures[photo.id],
              failure.signature == Self.signature(of: photo) else { return nil }
        return failure.failure
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
