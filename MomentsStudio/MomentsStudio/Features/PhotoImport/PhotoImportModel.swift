import CoreGraphics
import Foundation
import Observation
import PhotosUI

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

    /// True while any mutation (restore, import or removal) is running.
    var isBusy: Bool {
        mutationToken != nil
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
        guard mutationToken == nil else { return }

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
        guard mutationToken == nil, importingProjectID == nil, !items.isEmpty else { return }
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

        let task = Task { [weak self] in
            await self?.runBatch(items, projectID: projectID, batchID: batch)
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
        guard mutationToken == nil, importingProjectID == nil else {
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
