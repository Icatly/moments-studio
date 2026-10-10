import CoreGraphics
import Foundation
import Observation
import PhotosUI
// `PhotosPickerItem` is declared in the PhotosUI SwiftUI support layer, so the
// public SwiftUI module must be imported alongside PhotosUI for the type to be
// in scope (Apple's own PhotosPicker example imports both). No underscored or
// private overlay module is used.
import SwiftUI

/// Orchestrates photo import for the UI.
///
/// Main-actor by design: it owns display state (progress, errors, warnings) and
/// applies **only** values that `PhotoLibrary` already committed to disk. Every
/// file copy, decode and JSON write happens inside the library actor, never on
/// the main thread.
///
/// Restore, an import batch and a removal all rewrite the same package, so at
/// most one of them may be in flight: `mutationToken` serialises them without
/// introducing a lock or a scheduler.
@MainActor
@Observable
final class PhotoImportModel {
    /// Startup restoration state, so Home can show loading, retry or warnings
    /// instead of pretending the library is empty while it is still loading.
    enum RestoreState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    /// Loads the received file for one picked item into app-owned staging.
    ///
    /// Production uses the real `PhotosPickerItem` transferable, which copies
    /// the borrowed file before the importing closure returns. Tests inject a
    /// narrow loader so a batch can be driven deterministically with synthetic
    /// files instead of the photo library — no service protocol, no mock
    /// repository, no production test button and no second scheduler.
    typealias PhotoFileLoader = @Sendable (PhotosPickerItem) async throws -> URL

    private let library: PhotoLibrary
    private let store: ProjectStore
    private let loadPhotoFile: PhotoFileLoader

    private(set) var restoreState: RestoreState = .idle
    /// Non-fatal problems reported by the library (damaged package, missing
    /// derivative, cleanup that will be retried).
    private(set) var warnings: [String] = []

    /// Project whose batch is running, if any.
    private(set) var importingProjectID: UUID?
    private(set) var completedCount = 0
    private(set) var totalCount = 0
    /// Per-item failures of the last batch. A failed item never blocks the rest.
    private(set) var itemErrors: [String] = []
    /// True while a removal is in flight.
    private(set) var isRemoving = false

    private var mutationToken: UUID?
    private var batchID = UUID()
    private var batchTask: Task<Void, Never>?
    private var batchIsCancelled = false

    init(
        library: PhotoLibrary,
        store: ProjectStore,
        loadPhotoFile: @escaping PhotoFileLoader = { item in
            guard let transfer = try await item.loadTransferable(type: PhotoFileTransfer.self) else {
                throw PhotoLibraryError.unreadableImage("selected photo")
            }
            return transfer.stagedFileURL
        }
    ) {
        self.library = library
        self.store = store
        self.loadPhotoFile = loadPhotoFile
    }

    /// App construction: library in Application Support, default limits.
    static func makeDefault(store: ProjectStore) -> PhotoImportModel {
        PhotoImportModel(
            library: PhotoLibrary(rootURL: PhotoLibraryLocation.applicationSupportRootURL()),
            store: store
        )
    }

    /// The library has finished loading, so creating or importing is safe.
    /// Screens must not allow either while this is false.
    var isReady: Bool {
        restoreState == .ready
    }

    var isRestoring: Bool {
        restoreState == .loading
    }

    var isImporting: Bool {
        importingProjectID != nil
    }

    /// One busy rule for every mutation **and** for an active canvas gesture, so
    /// conflicting entries (restore, import, removal, save, gesture) are disabled
    /// together. A canvas gesture owns the gate for its whole duration.
    var isBusy: Bool {
        mutationToken != nil || importingProjectID != nil || isSavingEdits || canvasGestureProjectID != nil
    }

    func isImporting(projectID: UUID) -> Bool {
        importingProjectID == projectID
    }

    /// Photos this project can still accept, per the stage's photo ceiling.
    func remainingCapacity(for projectID: UUID) -> Int {
        max(0, ProjectPackage.photoLimit - store.photos(for: projectID).count)
    }

    // MARK: - Restoration

    /// Loads every saved package. Calling it again retries after a failure.
    ///
    /// It participates in the same single-mutation rule as import and removal,
    /// so a restore can never race a batch that is rewriting a package.
    func restoreProjects() async {
        if restoreState == .loading { return }
        // Restore must never start while a canvas gesture owns the gate.
        guard mutationToken == nil, canvasGestureProjectID == nil else { return }

        let token = UUID()
        mutationToken = token
        restoreState = .loading
        defer {
            if mutationToken == token { mutationToken = nil }
        }

        do {
            let result = try await library.restore()
            store.restore(result.packages)
            warnings = result.warnings
            restoreState = .ready
        } catch {
            warnings = []
            restoreState = .failed(Self.message(for: error))
        }
    }

    // MARK: - Import

    /// Imports one picker selection into one project, one photo at a time.
    ///
    /// Each item commits independently: a failed item is reported and the batch
    /// continues. Values are taken from the newest committed package each time,
    /// so a batch can never write over a photo another batch committed.
    func importSelection(_ items: [PhotosPickerItem], projectID: UUID) async {
        guard !isBusy, failedDraft(for: projectID) == nil, !items.isEmpty else { return }
        guard store.openProject(id: projectID) != nil else { return }

        let capacity = remainingCapacity(for: projectID)
        guard capacity > 0 else {
            itemErrors = ["This project already holds the maximum of \(ProjectPackage.photoLimit) photos."]
            return
        }

        let token = UUID()
        mutationToken = token

        let batch = UUID()
        batchID = batch
        batchIsCancelled = false
        importingProjectID = projectID
        completedCount = 0
        totalCount = min(items.count, capacity)
        itemErrors = []

        // Explicitly `Task<Void, Never>`: a weak-self optional call would infer
        // `Task<Void?, Never>`, which does not match `batchTask`. The guard keeps
        // the weak reference, the awaited call stays non-optional, and mutation
        // token lifetime, cancel forwarding and committed-result application are
        // unchanged.
        let task: Task<Void, Never> = Task { [weak self] in
            guard let self else { return }
            await self.runBatch(items, projectID: projectID, batchID: batch)
        }
        batchTask = task
        await task.value

        if batchID == batch {
            batchTask = nil
            importingProjectID = nil
        }
        if mutationToken == token { mutationToken = nil }
    }

    /// Stops the remaining work of the current batch. Committed photos stay
    /// committed and are still applied; cancellation is not a failure.
    func cancelImport(projectID: UUID) {
        guard importingProjectID == projectID else { return }
        batchIsCancelled = true
        batchTask?.cancel()
    }

    // MARK: - Removal

    /// Removes one photo from its project. The library commits the manifest
    /// first, so a later cleanup failure is reported instead of bringing the
    /// photo back.
    func removePhoto(projectID: UUID, assetID: UUID) async {
        guard !isBusy, failedDraft(for: projectID) == nil else {
            itemErrors = ["Another photo operation is still running. Try again in a moment."]
            return
        }
        guard let package = currentPackage(for: projectID) else { return }

        let token = UUID()
        mutationToken = token
        isRemoving = true
        defer {
            isRemoving = false
            if mutationToken == token { mutationToken = nil }
        }

        do {
            let result = try await library.removePhoto(assetID: assetID, from: package, at: Date())
            store.apply(result.package)
            appendWarnings(result.warnings)
        } catch {
            itemErrors.append(Self.message(for: error))
        }
    }

    // MARK: - Canvas editing (Stage 03)

    /// What happened to one canvas edit request.
    enum CanvasEditOutcome: Equatable {
        case saved
        case rejected(String)
        case saveFailed(String)
        case busy
    }

    /// True while an edit is being written. The UI uses it to disable conflicting
    /// controls and to show a real saving state instead of a fake "saved".
    private(set) var isSavingEdits = false

    /// The single entry point for canvas edits.
    ///
    /// It reuses the same `mutationToken` as import and removal, so at most one
    /// mutation (import, removal or edit) is ever in flight. The change closure
    /// receives the **latest committed** document and returns a new one; only the
    /// fields it touches change, and project identity, assets and other layers are
    /// preserved by the pure `CanvasEditor` operations. A write failure leaves the
    /// committed store and manifest untouched and reports `saveFailed`, so the
    /// caller can keep a draft and retry or discard it.
    @discardableResult
    func editCanvas(
        projectID: UUID,
        intent: CanvasDraft? = nil,
        _ change: (CanvasDocument) throws -> CanvasDocument
    ) async -> CanvasEditOutcome {
        // A canvas gesture owns the gate for its whole duration; button edits wait.
        guard !isCanvasGestureActive else { return .busy }
        guard intent == nil || intent?.projectID == projectID else {
            return .rejected("This edit belongs to another project.")
        }
        guard failedDraft(for: projectID) == nil else {
            return .rejected("Retry or discard this project's unsaved edit first.")
        }
        return await performEdit(projectID: projectID, draft: intent, change)
    }

    /// The shared edit body: one gate, one atomic write, real failure reporting.
    ///
    /// `draft` is retained only when a write actually fails, so the caller can retry
    /// or discard the exact transform it tried to save.
    private func performEdit(
        projectID: UUID,
        draft: CanvasDraft?,
        _ change: (CanvasDocument) throws -> CanvasDocument
    ) async -> CanvasEditOutcome {
        guard mutationToken == nil, importingProjectID == nil else { return .busy }
        guard let package = currentPackage(for: projectID) else {
            return .rejected("This project is not available in the current session.")
        }

        let token = UUID()
        mutationToken = token
        isSavingEdits = true
        defer {
            if mutationToken == token {
                mutationToken = nil
                isSavingEdits = false
            }
        }

        do {
            let document = try change(package.project.document)
            let result = try await library.saveEdit(document: document, into: package, at: Date())
            guard mutationToken == token else { return .busy }
            store.apply(result.package)
            appendWarnings(result.warnings)
            editMessages[projectID] = nil
            failedDrafts[projectID] = nil
            return .saved
        } catch let error as CanvasEditError {
            let message = Self.message(for: error)
            editMessages[projectID] = message
            return .rejected(message)
        } catch let error as CollageLayoutError {
            let message = error.localizedDescription
            editMessages[projectID] = message
            return .rejected(message)
        } catch {
            let message = Self.message(for: error)
            editMessages[projectID] = "Not saved: \(message)"
            if let draft { failedDrafts[projectID] = draft }
            return .saveFailed(message)
        }
    }

    /// Adds one imported asset to the canvas as a new photo layer.
    ///
    /// The photo is only an asset source; adding it does not consume or move it, so
    /// the same asset can be added again as an independent layer until the layer
    /// limit is reached. The base size comes from the EXIF-corrected display size,
    /// fitted proportionally inside the canvas.
    @discardableResult
    func addPhotoLayer(projectID: UUID, assetID: UUID) async -> CanvasEditOutcome {
        await applyCanvasIntent(projectID: projectID, layerID: nil, intent: .add(assetID: assetID))
    }

    // MARK: - Canvas gesture and failure state

    /// What a failed edit intended to do, so a retry re-applies the same intent to
    /// the **latest** committed document instead of replaying a stale document.
    enum CanvasDraftIntent: Equatable {
        case save
        case transform(LayerTransform)
        case visibility(isHidden: Bool)
        case lock(isLocked: Bool)
        case remove
        case order(forward: Bool)
        case add(assetID: UUID)
        case reset
        case move(x: Double, y: Double)
        case scaleBy(Double)
        case rotateBy(Double)
        case layout(CollagePreset)
    }

    /// A change that was edited but could not be written.
    ///
    /// It is kept by the model rather than by the canvas view, so leaving the screen
    /// does not discard it and it can be retried or explicitly discarded. It only
    /// ever applies to the project it was made in.
    struct CanvasDraft: Equatable {
        var projectID: UUID
        var layerID: UUID?
        var intent: CanvasDraftIntent
    }

    /// Applies one draft intent to the latest document.
    static func apply(_ intent: CanvasDraftIntent, to document: CanvasDocument, layerID: UUID) throws -> CanvasDocument {
        switch intent {
        case .save:
            return document
        case .transform(let transform):
            guard let clamped = CanvasGeometry.clampedForEditing(transform, canvasSize: document.canvasSize) else {
                throw CanvasEditError.unusableTransform(transform)
            }
            return try CanvasEditor.settingTransform(clamped, forLayerID: layerID, in: document)
        case .visibility(let isHidden):
            return try CanvasEditor.settingHidden(isHidden, forLayerID: layerID, in: document)
        case .lock(let isLocked):
            return try CanvasEditor.settingLocked(isLocked, forLayerID: layerID, in: document)
        case .remove:
            return try CanvasEditor.removingLayer(layerID: layerID, from: document)
        case .order(let forward):
            return forward
                ? try CanvasEditor.bringingForward(layerID: layerID, in: document)
                : try CanvasEditor.sendingBackward(layerID: layerID, in: document)
        case .reset:
            return try CanvasEditor.resettingTransform(forLayerID: layerID, in: document)
        case .move(let x, let y):
            guard let layer = document.layers.first(where: { $0.id == layerID }) else {
                throw CanvasEditError.layerNotFound(layerID)
            }
            var transform = layer.transform
            transform.translationX += x
            transform.translationY += y
            return try apply(.transform(transform), to: document, layerID: layerID)
        case .scaleBy(let factor):
            guard let layer = document.layers.first(where: { $0.id == layerID }) else {
                throw CanvasEditError.layerNotFound(layerID)
            }
            var transform = layer.transform
            transform.scale *= factor
            return try apply(.transform(transform), to: document, layerID: layerID)
        case .rotateBy(let delta):
            guard let layer = document.layers.first(where: { $0.id == layerID }) else {
                throw CanvasEditError.layerNotFound(layerID)
            }
            var transform = layer.transform
            transform.rotationRadians += delta
            return try apply(.transform(transform), to: document, layerID: layerID)
        case .add(let assetID):
            throw CanvasEditError.assetAlreadyMissing(assetID)
        case .layout:
            // Layouts, like adding assets, need project photo metadata. The
            // instance dispatcher below handles these document-wide intents.
            throw CollageLayoutError.noPhotos
        }
    }

    /// The project whose canvas gesture is currently in flight, if any, and the
    /// identity of that one gesture so a late callback cannot commit or cancel a
    /// different (or already finished) gesture.
    private(set) var canvasGestureProjectID: UUID?
    private(set) var canvasGestureID: UUID?

    /// The draft that failed to save, retained for retry or explicit discard.
    private var failedDrafts: [UUID: CanvasDraft] = [:]

    /// A message for the editor UI: save failures and rejections are visible.
    private var editMessages: [UUID: String] = [:]

    func failedDraft(for projectID: UUID) -> CanvasDraft? { failedDrafts[projectID] }
    func editMessage(for projectID: UUID) -> String? { editMessages[projectID] }

    @discardableResult
    func applyCanvasIntent(projectID: UUID, layerID: UUID?, intent: CanvasDraftIntent) async -> CanvasEditOutcome {
        let draft = CanvasDraft(projectID: projectID, layerID: layerID, intent: intent)
        return await editCanvas(projectID: projectID, intent: draft) { document in
            try self.apply(draft, to: document)
        }
    }

    private func apply(_ draft: CanvasDraft, to document: CanvasDocument) throws -> CanvasDocument {
        if case .save = draft.intent { return document }
        if case .layout(let preset) = draft.intent {
            return try CollageLayout.arrange(preset, document: document, photos: store.photos(for: draft.projectID))
        }
        if case .add(let assetID) = draft.intent {
            guard let photo = store.photos(for: draft.projectID).first(where: { $0.asset.id == assetID }) else {
                throw CanvasEditError.assetAlreadyMissing(assetID)
            }
            let size = photo.displayPixelSize
            guard let baseSize = CanvasGeometry.fittedBaseSize(
                displayWidth: size.width, displayHeight: size.height, canvasSize: document.canvasSize
            ) else { throw CanvasEditError.unusableBaseSize(document.canvasSize) }
            return try CanvasEditor.addingLayer(assetID: assetID, baseSize: baseSize, to: document)
        }
        guard let layerID = draft.layerID else {
            throw CanvasEditError.layerNotFound(draft.projectID)
        }
        return try Self.apply(draft.intent, to: document, layerID: layerID)
    }

    var isCanvasGestureActive: Bool { canvasGestureProjectID != nil }

    /// The canvas holds the gate for the whole gesture: while a finger is editing, no
    /// import/removal/restore/list edit may start, and the system back button stays
    /// usable. It refuses when any other work is in flight, and never blocks its own
    /// gesture.
    @discardableResult
    func beginCanvasGesture(projectID: UUID) -> UUID? {
        guard !isBusy, failedDraft(for: projectID) == nil,
              store.openProject(id: projectID) != nil else { return nil }
        let id = UUID()
        canvasGestureProjectID = projectID
        canvasGestureID = id
        return id
    }

    /// Ends a gesture without committing: used when the view disappears or the app
    /// goes to the background. It releases the gate immediately, and a late callback
    /// for a different or already finished gesture is ignored.
    func cancelCanvasGesture(id: UUID? = nil) {
        if let id, canvasGestureID != id { return }
        canvasGestureProjectID = nil
        canvasGestureID = nil
    }

    /// Commits exactly one complete transform at the end of a gesture.
    ///
    /// The gate stays held until the write returns, so a finished save is never
    /// interrupted by a new gesture; a late callback for another gesture is refused.
    /// A failed write keeps the draft and reports why.
    @discardableResult
    func commitCanvasGesture(
        id: UUID,
        projectID: UUID,
        layerID: UUID,
        transform: LayerTransform
    ) async -> CanvasEditOutcome {
        guard canvasGestureID == id, canvasGestureProjectID == projectID else { return .busy }
        let draft = CanvasDraft(projectID: projectID, layerID: layerID, intent: .transform(transform))
        let outcome = await performEdit(projectID: projectID, draft: draft) { document in
            try Self.apply(.transform(transform), to: document, layerID: layerID)
        }
        // Release only this gesture's gate, and only after the write returned.
        if canvasGestureID == id {
            canvasGestureProjectID = nil
            canvasGestureID = nil
        }
        return outcome
    }

    /// Retries the retained draft against the **latest** committed package. It never
    /// touches another project and never rewrites the asset package.
    @discardableResult
    func retryFailedDraft(projectID: UUID) async -> CanvasEditOutcome {
        guard !isCanvasGestureActive else { return .busy }
        guard let draft = failedDraft(for: projectID) else { return .rejected("There is nothing to save again.") }
        let outcome = await performEdit(projectID: draft.projectID, draft: draft) { document in
            try self.apply(draft, to: document)
        }
        return outcome
    }

    /// Explicitly gives up a failed draft.
    func discardFailedDraft(projectID: UUID) {
        guard !isBusy else { return }
        failedDrafts[projectID] = nil
        editMessages[projectID] = nil
    }

    private static func message(for error: CanvasEditError) -> String {
        switch error {
        case .layerLimitReached(let limit):
            return "This project already holds the maximum of \(limit) layers."
        case .layerNotFound:
            return "That layer is no longer part of this project."
        case .layerIsLocked:
            return "Unlock the layer before changing it."
        case .unusableTransform:
            return "That position, scale or rotation cannot be saved."
        case .unusableBaseSize:
            return "That photo has an unusable display size."
        case .assetAlreadyMissing:
            return "That photo is no longer part of this project."
        }
    }

    // MARK: - Photo analysis (Stage 05, read-only)

    /// Read-only bridge for the Photo summary sheet.
    ///
    /// It deliberately does **not** take part in the single mutation gate and does
    /// **not** write the store, the manifest or the failed-draft state: analysis
    /// changes no project. Cancellation propagates as `CancellationError`, and only
    /// the value result crosses back to the UI (never a `CGImage`).
    func analyzePhoto(projectID: UUID, assetID: UUID) async throws -> PhotoAnalysis {
        guard store.openProject(id: projectID) != nil else {
            throw PhotoAnalysisFailure.missing
        }
        return try await library.analyzePhoto(projectID: projectID, assetID: assetID)
    }

    // MARK: - Photo roles (Stage 06)

    /// What happened to one role-save request.
    enum RoleSaveOutcome: Equatable {
        case saved
        case rejected(String)
        case saveFailed(String)
        case busy
    }

    /// Read-only bridge for the Photo roles sheet.
    ///
    /// Like the Photo summary bridge it takes no part in the mutation gate and
    /// writes nothing: the Vision pass and the Stage 05 statistics happen inside
    /// the `PhotoLibrary` actor and only the value result crosses back to the UI.
    func observeRole(projectID: UUID, assetID: UUID) async throws -> PhotoRoleObservation {
        guard store.openProject(id: projectID) != nil else {
            throw PhotoRoleObservationFailure.missing
        }
        return try await library.observeRole(projectID: projectID, assetID: assetID)
    }

    /// The exact photo identity the sheet must describe before it may save.
    func roleSnapshot(for projectID: UUID) -> [UUID: String] {
        // The project's existence is what makes `store.photos` meaningful, so the check
        // is a guard without binding a value that is never used.
        guard store.openProject(id: projectID) != nil else { return [:] }
        return Dictionary(uniqueKeysWithValues: store.photos(for: projectID).map { photo in
            (photo.asset.id, PhotoLibrary.roleSnapshot(of: photo))
        })
    }

    /// The single entry point for saving Photo roles.
    ///
    /// It reuses the **same** `mutationToken`, `isSavingEdits` flag and atomic
    /// manifest writer as import, removal and canvas edits, so it can never run
    /// beside another mutation, and it refuses while a canvas gesture owns the gate
    /// or an unresolved canvas draft exists. `choices` is a **total** map for the
    /// snapshot the sheet was showing: an absent asset is cleared, a value is saved.
    /// The request also carries the photo snapshot (metadata **and** the currently
    /// saved choice); the library compares it with the committed package and refuses
    /// a stale request instead of writing the choices onto a changed project — which
    /// is what stops an old sheet from overwriting a newer manual selection. An
    /// impossible draft is a rejection; a real write failure leaves the store and
    /// manifest untouched and reports `saveFailed`, so the sheet can keep its draft
    /// and retry or cancel.
    @discardableResult
    func saveRoleChoices(
        projectID: UUID,
        choices: [UUID: PhotoRoleChoice],
        expecting snapshot: [UUID: String]
    ) async -> RoleSaveOutcome {
        guard !isCanvasGestureActive else { return .busy }
        guard failedDraft(for: projectID) == nil else {
            return .rejected("Retry or discard this project's unsaved edit first.")
        }
        guard store.openProject(id: projectID) != nil else {
            return .rejected("This project is not available in the current session.")
        }
        guard mutationToken == nil, importingProjectID == nil, !isSavingEdits else { return .busy }
        guard !snapshot.isEmpty else { return .rejected("Reload Photo roles and try again.") }

        let token = UUID()
        mutationToken = token
        isSavingEdits = true
        defer {
            if mutationToken == token {
                mutationToken = nil
                isSavingEdits = false
            }
        }

        do {
            let result = try await library.saveRoleChoices(
                projectID: projectID,
                choices: choices,
                expecting: snapshot,
                at: Date()
            )
            guard mutationToken == token else { return .busy }
            store.apply(result.package)
            appendWarnings(result.warnings)
            return .saved
        } catch let error as PhotoRoleSaveError {
            return .rejected(Self.message(for: error))
        } catch is CancellationError {
            return .rejected("Saving was interrupted. Your choices are still here — try again.")
        } catch {
            return .saveFailed("Not saved: \(Self.message(for: error))")
        }
    }

    /// User-facing wording for the role-save rejections. Stale data asks for a
    /// reload instead of silently writing a choice that no longer describes this
    /// package.
    private static func message(for error: PhotoRoleSaveError) -> String {
        switch error {
        case .projectMissing:
            return "This project is not available in the current session."
        case .photosChanged:
            return "These photos changed. Reload Photo roles and choose again."
        case .impossible:
            return "Those roles cannot be saved together."
        case .busy:
            return "Another photo operation is still running. Try again in a moment."
        }
    }

    // MARK: - Images

    /// Loads one generated derivative for display. Returns `nil` (and records a
    /// message) when the file cannot be read, so the UI shows a placeholder
    /// instead of failing.
    func loadImage(reference: String) async -> CGImage? {
        do {
            return try await library.loadDerivedImage(reference: reference)
        } catch {
            appendWarnings([Self.message(for: error)])
            return nil
        }
    }

    // MARK: - Messages

    func dismissWarnings() {
        warnings = []
    }

    func dismissItemErrors() {
        itemErrors = []
    }

    // MARK: - Batch internals

    private func runBatch(_ items: [PhotosPickerItem], projectID: UUID, batchID batch: UUID) async {
        var package = currentPackage(for: projectID)
        var index = 0

        for item in items {
            guard isBatchAcceptingWork(batch), remainingCapacity(for: projectID) > 0 else { break }
            index += 1

            do {
                guard let current = package else { break }

                let stagedFileURL = try await loadPhotoFile(item)
                do {
                    let result = try await library.importPhoto(
                        fileURL: stagedFileURL,
                        into: current,
                        at: Date()
                    )

                    // The photo is already committed on disk. Apply it whenever
                    // this batch is still the current one for this project — a
                    // cancellation that arrived during the commit must not leave
                    // the UI out of step with what was saved.
                    if batchID == batch, importingProjectID == projectID {
                        store.apply(result.package)
                        package = result.package
                        completedCount += 1
                        appendWarnings(result.warnings)
                    }

                    // Committed or not, the app-owned staging copy is done with.
                    // A cleanup failure is surfaced instead of being swallowed.
                    appendWarnings(await library.discardStagedFile(at: stagedFileURL))
                } catch {
                    // Failure or cancellation before the commit: the owned
                    // staging copy must not accumulate until the next launch.
                    appendWarnings(await library.discardStagedFile(at: stagedFileURL))
                    throw error
                }

                if batchIsCancelled { break }
            } catch let error as PhotoLibraryError {
                if error == .cancelled { break }
                recordFailure("Photo \(index): \(error.errorDescription ?? "\(error)")")
            } catch is CancellationError {
                break
            } catch {
                recordFailure("Photo \(index): \(error.localizedDescription)")
            }
        }
    }

    /// False once this batch is no longer current or has been cancelled, which
    /// stops further items without discarding an already committed one.
    private func isBatchAcceptingWork(_ batch: UUID) -> Bool {
        batchID == batch && !batchIsCancelled
    }

    /// Builds the package to import into from the store's committed snapshot.
    private func currentPackage(for projectID: UUID) -> ProjectPackage? {
        guard let project = store.openProject(id: projectID) else { return nil }
        return ProjectPackage(project: project, photos: store.photos(for: projectID))
    }

    private func recordFailure(_ message: String) {
        itemErrors.append(message)
    }

    private func appendWarnings(_ newWarnings: [String]) {
        guard !newWarnings.isEmpty else { return }
        warnings.append(contentsOf: newWarnings)
    }

    private static func message(for error: Error) -> String {
        if let libraryError = error as? PhotoLibraryError {
            return libraryError.errorDescription ?? "\(libraryError)"
        }
        return error.localizedDescription
    }
}
