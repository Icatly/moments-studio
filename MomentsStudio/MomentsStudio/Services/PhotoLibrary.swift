import CoreGraphics
import Foundation

/// Runtime result of scanning the library at startup. Not persisted.
struct PhotoLibraryLoadResult {
    var packages: [ProjectPackage]
    var warnings: [String]
}

/// Result of a committed mutation. `package` is the value that is now on disk.
struct PhotoLibraryMutationResult {
    var package: ProjectPackage
    var warnings: [String]
}

/// Engineering limits for the photo pipeline.
///
/// These are this stage's project policy, not Apple requirements: 20 photos per
/// project, 100 MiB per source file, 80 million source pixels, a 320px
/// thumbnail and a 2048px preview.
struct PhotoLibraryLimits: Equatable {
    var maxPhotosPerProject: Int
    var maxSourceBytes: Int
    var maxSourcePixels: Int
    var thumbnailMaxPixelSize: Int
    var previewMaxPixelSize: Int

    /// Defaults used by the app. The photo ceiling comes from
    /// `ProjectPackage.photoLimit` so decoding and importing share one number.
    static let standard = PhotoLibraryLimits(
        maxPhotosPerProject: ProjectPackage.photoLimit,
        maxSourceBytes: 100 * 1024 * 1024,
        maxSourcePixels: 80_000_000,
        thumbnailMaxPixelSize: 320,
        previewMaxPixelSize: 2048
    )
}

/// Where the library and its staging area live.
///
/// Application Support is local persistent data (not Caches), so imported
/// projects survive a restart and are not purged under storage pressure.
enum PhotoLibraryLocation {
    static let libraryDirectoryName = "MomentsStudio"
    /// App-owned staging area for received picker files. Never a system
    /// temporary URL: picker files are copied here before the importing closure
    /// returns.
    static let stagingDirectoryName = "Temporary"

    static func applicationSupportRootURL(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(libraryDirectoryName, isDirectory: true)
    }

    /// The trusted root and the staging directory below it, both canonicalised
    /// **only for the trusted root** — generated components are inspected, never
    /// normalized, by `PhotoLibraryPathGuard`.
    private static func canonicalRoots(rootURL: URL) throws -> (root: URL, staging: URL) {
        let root = rootURL.resolvingSymlinksInPath().standardizedFileURL
        let staging = try PhotoLibraryPathGuard.resolve(
            stagingDirectoryName,
            below: root,
            label: stagingDirectoryName,
            fileManager: .default
        )
        return (root, staging)
    }

    /// The staging directory, required to be exactly `<canonical root>/Temporary`.
    ///
    /// Used before any staging create, copy or delete. Ownership is enforced by
    /// inspecting the component itself (see `PhotoLibraryPathGuard`), so a
    /// symlinked staging directory — pointing outside the library, aliasing
    /// something inside it, or dangling — can never redirect those operations.
    static func canonicalStagingDirectory(rootURL: URL) throws -> URL {
        try canonicalRoots(rootURL: rootURL).staging
    }

    /// Confirms that `url` **is** an owned staged file: its parent must be the
    /// staging directory in one of the two trusted forms, and the file component
    /// itself must be a real file, never a link (a dangling link included).
    ///
    /// Matching on the file name alone is not ownership, and neither is resolving
    /// an arbitrary incoming parent: an outside directory holding a link named
    /// `Temporary` would resolve onto the owned staging folder and be accepted.
    /// The caller's path is therefore compared **lexically** against the trusted
    /// forms only — the root as supplied (which may carry the platform alias) and
    /// its canonical form — and the generated components are then inspected.
    static func canonicalStagedFile(_ url: URL, rootURL: URL) throws -> URL {
        let roots = try canonicalRoots(rootURL: rootURL)
        let name = url.lastPathComponent
        guard !name.isEmpty else {
            throw PhotoLibraryError.invalidReference(name)
        }

        let lexicalParent = url.deletingLastPathComponent().standardizedFileURL
        let callerForm = rootURL.standardizedFileURL
            .appendingPathComponent(stagingDirectoryName, isDirectory: true)
            .standardizedFileURL
        guard lexicalParent.path == callerForm.path || lexicalParent.path == roots.staging.path else {
            throw PhotoLibraryError.invalidReference(name)
        }

        return try PhotoLibraryPathGuard.resolve(
            "\(stagingDirectoryName)/\(name)",
            below: roots.root,
            label: name,
            fileManager: .default
        )
    }
}

/// Component-wise ownership check for every generated library path.
///
/// Each generated path is validated one component at a time **below the
/// canonical library root**: every component that already exists must be a real
/// directory or file, never a symbolic link. That rejects a link pointing outside
/// the library, an alias *inside* the library (`A/assets -> B/assets`) and a
/// dangling link, all of which would otherwise redirect a create, read, write or
/// delete into another project's files.
///
/// The failure this exists for is observed, not theoretical: in run 37135113445 a
/// whole-path comparison accepted an in-library alias (`A/assets -> B/assets`) and
/// an import wrote into project B's folder. The exact Foundation mechanics behind
/// that observation are **not** established here, and this type does not depend on
/// any theory about them. What it does instead is inspect each generated component
/// itself with `attributesOfItem(atPath:)`, which reports the item rather than
/// following it — unlike `fileExists`, which follows links and cannot see them.
///
/// A genuinely missing tail is allowed, because that is the normal state of the
/// folder that is about to be created; "no such file" is distinguished from every
/// other inspection error, which stays a real failure.
enum PhotoLibraryPathGuard {
    private enum ComponentState {
        case exists
        case symlink
        case missing
        case inspectionFailed(String)
    }

    /// Resolves a generated relative path below an already-canonical root.
    ///
    /// - Parameters:
    ///   - relativePath: generated path, `/`-separated. An empty string means the
    ///     canonical root itself (used when the library creates its own root).
    ///   - canonicalRootURL: trusted root, canonicalised by the caller.
    ///   - label: value used in errors.
    static func resolve(
        _ relativePath: String,
        below canonicalRootURL: URL,
        label: String,
        fileManager: FileManager
    ) throws -> URL {
        guard !relativePath.hasPrefix("/"), !relativePath.contains("\\") else {
            throw PhotoLibraryError.invalidReference(label)
        }

        var components: [String] = []
        if !relativePath.isEmpty {
            components = relativePath
                .split(separator: "/", omittingEmptySubsequences: false)
                .map(String.init)
            guard components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
                throw PhotoLibraryError.invalidReference(label)
            }
        }

        var current = canonicalRootURL
        for (index, component) in components.enumerated() {
            current.appendPathComponent(component, isDirectory: false)

            switch state(of: current, fileManager: fileManager) {
            case .symlink:
                throw PhotoLibraryError.invalidReference(label)
            case .exists:
                continue
            case .missing:
                // Nothing below a missing component can be an alias, so the rest
                // of this generated path is allowed to be created normally.
                for remaining in components[(index + 1)...] {
                    current.appendPathComponent(remaining, isDirectory: false)
                }
                return current
            case .inspectionFailed(let reason):
                throw PhotoLibraryError.fileOperationFailed(reason)
            }
        }

        return current
    }

    /// Inspects one component without following it.
    private static func state(of url: URL, fileManager: FileManager) -> ComponentState {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return attributes[.type] as? FileAttributeType == .typeSymbolicLink ? .symlink : .exists
        } catch let error as NSError {
            if isMissing(error) {
                return .missing
            }
            return .inspectionFailed("cannot inspect \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Distinguishes "no such file" from every other inspection error.
    ///
    /// A missing component can be reported through either documented Cocoa code
    /// (`NSFileNoSuchFileError` 4, `NSFileReadNoSuchFileError` 260) or as POSIX
    /// `ENOENT`; all three mean "this generated path does not exist yet", which is
    /// what a first launch and a brand-new asset folder look like. Anything else
    /// stays a real failure instead of being swallowed.
    private static func isMissing(_ error: NSError) -> Bool {
        if error.domain == NSCocoaErrorDomain,
           error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError {
            return true
        }
        return error.domain == NSPOSIXErrorDomain && error.code == Int(ENOENT)
    }
}

/// The file-owning photo library for Stage 02.
///
/// One actor owns the on-disk transactions, derivative generation and package
/// recovery. It is deliberately **not** `@MainActor`: file copies, ImageIO work
/// and manifest I/O must not run on the UI thread, so the coordinator awaits it
/// and only applies values that were committed here. There is no repository
/// protocol, cache or job queue — this stage does not need them.
actor PhotoLibrary {
    private let rootURL: URL
    /// Trusted root, canonicalised **once** here so platform aliases such as
    /// `/var -> /private/var` are supported. Generated components are never
    /// normalized before inspection — that is what `PhotoLibraryPathGuard` does.
    private let canonicalRootURL: URL
    private let limits: PhotoLibraryLimits
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// - Parameters:
    ///   - rootURL: library root. Tests pass their own temporary directory; the
    ///     app passes `PhotoLibraryLocation.applicationSupportRootURL()`.
    ///   - limits: engineering limits, injectable so tests can exercise the caps
    ///     without generating 100 MiB files. The app uses `.standard`.
    init(
        rootURL: URL,
        limits: PhotoLibraryLimits = .standard,
        fileManager: FileManager = .default
    ) {
        let standardizedRoot = rootURL.standardizedFileURL
        self.rootURL = standardizedRoot
        self.canonicalRootURL = standardizedRoot.resolvingSymlinksInPath().standardizedFileURL
        self.limits = limits
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    // MARK: - Restore

    /// Loads every readable package, reporting one warning per damaged project
    /// or missing file instead of failing the whole scan. Damaged or
    /// future-versioned packages are reported and left untouched on disk.
    func restore() throws -> PhotoLibraryLoadResult {
        try ensureLibraryDirectories()

        let projectsRoot = try resolvedLibraryPath(
            PhotoLibraryPath.projectsDirectoryName,
            label: PhotoLibraryPath.projectsDirectoryName
        )
        let projectDirectories = try directoryContents(of: projectsRoot)
        var packages: [ProjectPackage] = []
        var warnings: [String] = []

        for directory in projectDirectories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let projectID = UUID(uuidString: directory.lastPathComponent) else {
                warnings.append("Skipped unrecognised folder in Projects: \(directory.lastPathComponent)")
                continue
            }

            do {
                let package = try loadPackage(projectID: projectID)
                guard package.project.id == projectID else {
                    // A manifest whose project does not match its folder must not
                    // be used to clean or rewrite anything.
                    throw PhotoLibraryError.invalidPackage("manifest project id does not match its folder")
                }
                warnings.append(contentsOf: missingFileWarnings(for: package))
                packages.append(package)
                cleanupUnreferencedAssets(for: package, warnings: &warnings)
            } catch let error as PhotoLibraryError {
                warnings.append("Project \(projectID.uuidString.prefix(8)): \(error.errorDescription ?? "\(error)")")
            } catch {
                warnings.append("Project \(projectID.uuidString.prefix(8)): \(error.localizedDescription)")
            }
        }

        cleanupStagingResidue(warnings: &warnings)
        return PhotoLibraryLoadResult(packages: packages, warnings: warnings)
    }

    // MARK: - Import

    /// Copies one received file into the library and commits it as a photo.
    ///
    /// Order: validate the source, write the original bytes and both
    /// derivatives, validate the resulting package exactly as decoding would,
    /// then commit the manifest atomically. Nothing is reported to the caller
    /// until the manifest write succeeded; any earlier failure or cancellation
    /// removes that photo's new files and leaves the previous manifest and the
    /// already imported photos untouched.
    func importPhoto(
        fileURL: URL,
        into package: ProjectPackage,
        at date: Date
    ) throws -> PhotoLibraryMutationResult {
        try checkCancellation()
        try validatePackageEntry(package)
        guard package.photos.count < limits.maxPhotosPerProject else {
            throw PhotoLibraryError.photoLimitReached(limit: limits.maxPhotosPerProject)
        }
        try ensureLibraryDirectories()

        let sourceURL = fileURL.standardizedFileURL
        let byteCount = try sourceByteCount(of: sourceURL)
        guard byteCount <= limits.maxSourceBytes else {
            throw PhotoLibraryError.fileTooLarge(limitBytes: limits.maxSourceBytes, actualBytes: byteCount)
        }

        let projectID = package.project.id
        let assetID = UUID()
        let assetReference = PhotoLibraryPath.assetDirectoryReference(projectID, assetID: assetID)
        var warnings: [String] = []

        do {
            try checkCancellation()

            // Inspect and derive without ever loading the whole file into memory.
            let inspection = try autoreleasepool {
                () throws -> (metadata: PhotoDerivativeRenderer.SourceMetadata, fileExtension: String, thumbnail: PhotoDerivativeRenderer.Derivative, preview: PhotoDerivativeRenderer.Derivative) in
                let source = try PhotoDerivativeRenderer.openSource(at: sourceURL)
                let metadata = try PhotoDerivativeRenderer.metadata(of: source, fileName: sourceURL.lastPathComponent)

                let pixels = try PhotoLibrary.checkedPixelCount(
                    width: metadata.pixelWidth,
                    height: metadata.pixelHeight,
                    limit: limits.maxSourcePixels,
                    fileName: sourceURL.lastPathComponent
                )
                guard pixels <= limits.maxSourcePixels else {
                    throw PhotoLibraryError.tooManyPixels(limit: limits.maxSourcePixels, actualPixels: pixels)
                }

                let derivatives = try PhotoDerivativeRenderer.makeDerivatives(
                    from: source,
                    metadata: metadata,
                    thumbnailMaxPixelSize: limits.thumbnailMaxPixelSize,
                    previewMaxPixelSize: limits.previewMaxPixelSize,
                    fileName: sourceURL.lastPathComponent
                )
                return (
                    metadata,
                    PhotoDerivativeRenderer.preferredFileExtension(forContentType: metadata.contentType),
                    derivatives.thumbnail,
                    derivatives.preview
                )
            }

            try createDirectory(assetReference)
            try checkCancellation()

            let originalReference = PhotoLibraryPath.originalReference(
                projectID,
                assetID: assetID,
                fileExtension: inspection.fileExtension
            )
            try copyBytes(from: sourceURL, toReference: originalReference)

            let thumbnailExtension = PhotoDerivativeRenderer.derivativeFileExtension(hasAlpha: inspection.thumbnail.hasAlpha)
            let previewExtension = PhotoDerivativeRenderer.derivativeFileExtension(hasAlpha: inspection.preview.hasAlpha)
            let thumbnailReference = PhotoLibraryPath.derivativeReference(
                .thumbnail,
                projectID: projectID,
                assetID: assetID,
                fileExtension: thumbnailExtension
            )
            let previewReference = PhotoLibraryPath.derivativeReference(
                .preview,
                projectID: projectID,
                assetID: assetID,
                fileExtension: previewExtension
            )

            let thumbnailURL = try resolvedLibraryPath(thumbnailReference, label: thumbnailReference)
            let previewURL = try resolvedLibraryPath(previewReference, label: previewReference)

            try autoreleasepool {
                try PhotoDerivativeRenderer.write(inspection.thumbnail, to: thumbnailURL)
                try PhotoDerivativeRenderer.write(inspection.preview, to: previewURL)
            }

            let photo = ImportedPhoto(
                asset: Asset(id: assetID, kind: .photo, localReference: originalReference),
                thumbnailReference: thumbnailReference,
                previewReference: previewReference,
                pixelWidth: inspection.metadata.pixelWidth,
                pixelHeight: inspection.metadata.pixelHeight,
                orientation: inspection.metadata.orientation,
                contentType: inspection.metadata.contentType
            )

            var updatedPhotos = package.photos
            updatedPhotos.append(photo)
            try ProjectPackage.validate(photos: updatedPhotos, projectID: projectID, canvasSize: package.project.document.canvasSize, layers: package.project.document.layers)
            guard updatedPhotos.count <= limits.maxPhotosPerProject else {
                throw PhotoLibraryError.photoLimitReached(limit: limits.maxPhotosPerProject)
            }

            var updatedProject = package.project
            updatedProject.updatedAt = date
            let updatedPackage = ProjectPackage(project: updatedProject, photos: updatedPhotos)

            // Commit point: only after this succeeds is the photo committed.
            try checkCancellation()
            try writeManifest(updatedPackage)

            removeStagingCopyIfOwned(sourceURL, warnings: &warnings)
            return PhotoLibraryMutationResult(package: updatedPackage, warnings: warnings)
        } catch {
            rollbackAssetDirectory(assetReference, warnings: &warnings)
            throw error
        }
    }

    // MARK: - Removal

    /// Removes one photo from the package.
    ///
    /// The manifest is committed first; only then are the photo's files deleted.
    /// A cleanup failure is reported as a warning and retried on a later launch
    /// rather than resurrecting the removed photo.
    func removePhoto(
        assetID: UUID,
        from package: ProjectPackage,
        at date: Date
    ) throws -> PhotoLibraryMutationResult {
        try validatePackageEntry(package)
        guard let index = package.photos.firstIndex(where: { $0.asset.id == assetID }) else {
            throw PhotoLibraryError.photoNotFound(assetID)
        }
        try ensureLibraryDirectories()

        var updatedPhotos = package.photos
        updatedPhotos.remove(at: index)

        // Stage 03: deleting a photo also drops every layer that renders it, in the
        // same manifest transaction, so a package can never reference a missing
        // asset. Layer identity for other assets is untouched.
        var updatedProject = package.project
        updatedProject.document = CanvasEditor.removingLayers(boundTo: assetID, from: package.project.document)
        updatedProject.updatedAt = date
        let updatedPackage = ProjectPackage(project: updatedProject, photos: updatedPhotos)
        try ProjectPackage.validate(
            photos: updatedPhotos,
            projectID: updatedProject.id,
            canvasSize: updatedProject.document.canvasSize,
            layers: updatedProject.document.layers
        )

        try writeManifest(updatedPackage)

        var warnings: [String] = []
        let assetReference = PhotoLibraryPath.assetDirectoryReference(
            package.project.id,
            assetID: assetID
        )
        if let target = try? resolvedLibraryPath(assetReference, label: assetReference),
           fileManager.fileExists(atPath: target.path) {
            do {
                try fileManager.removeItem(at: target)
            } catch {
                warnings.append("Photo removed, but its files could not be deleted yet; a later launch retries.")
            }
        }

        return PhotoLibraryMutationResult(package: updatedPackage, warnings: warnings)
    }

    // MARK: - Derived images

    /// Decodes one generated derivative for display.
    ///
    /// Only derivative references are accepted, so this can never be used to
    /// load an original photo, and the decode is bounded by the role's own
    /// 320/2048 limit, further capped by the file's real size.
    func loadDerivedImage(reference: String) throws -> CGImage {
        let parsed = try PhotoLibraryPath.validateDerivative(reference)
        let url = try resolvedLibraryPath(reference, label: reference)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PhotoLibraryError.fileOperationFailed("missing image \(reference)")
        }

        let maxPixelSize = parsed.kind == .thumbnail
            ? limits.thumbnailMaxPixelSize
            : limits.previewMaxPixelSize

        return try autoreleasepool {
            try PhotoDerivativeRenderer.decodeDerivative(at: url, maxPixelSize: maxPixelSize)
        }
    }

    // MARK: - Photo analysis (Stage 05)

    /// Read-only light/colour analysis for one photo of one project.
    ///
    /// It reads the current package's metadata and the generated 320px thumbnail
    /// through the normal path guard, never an original, and it writes nothing: no
    /// manifest, no asset, no project state. Cancellation propagates as
    /// `CancellationError` and is never reported as an ordinary bad-photo result.
    func analyzePhoto(projectID: UUID, assetID: UUID) throws -> PhotoAnalysis {
        try checkAnalysisCancellation()

        let package: ProjectPackage
        do {
            package = try loadPackage(projectID: projectID)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // No readable package means the photo cannot be resolved at all.
            throw PhotoAnalysisFailure.missing
        }
        guard let photo = package.photos.first(where: { $0.asset.id == assetID }) else {
            throw PhotoAnalysisFailure.missing
        }
        let display = photo.displayPixelSize
        guard photo.pixelWidth > 0, photo.pixelHeight > 0,
              ImportedPhoto.orientationRange.contains(photo.orientation),
              display.width > 0, display.height > 0 else {
            throw PhotoAnalysisFailure.invalidMetadata
        }
        try checkAnalysisCancellation()

        let thumbnail: CGImage
        do {
            thumbnail = try loadDerivedImage(reference: photo.thumbnailReference)
        } catch PhotoLibraryError.cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PhotoAnalysisFailure.unreadable
        }
        try checkAnalysisCancellation()

        do {
            return try PhotoAnalyzer.analyze(
                assetID: assetID,
                thumbnail: thumbnail,
                displayWidth: display.width,
                displayHeight: display.height
            )
        } catch let failure as PhotoAnalysisFailure {
            throw failure
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PhotoAnalysisFailure.unreadable
        }
    }

    /// Cancellation for the read-only analysis path. It throws `CancellationError`
    /// (not `PhotoLibraryError.cancelled`) so the caller can tell "cancelled" from
    /// "this photo could not be analyzed".
    private func checkAnalysisCancellation() throws {
        if Task.isCancelled { throw CancellationError() }
    }

    // MARK: - Staging

    /// Deletes one app-owned staging copy that was **not** committed, because
    /// that item failed or the batch was cancelled.
    ///
    /// Ownership is verified against the exact staged path, so a file that merely
    /// shares a name — or any system picker URL — can never be deleted through
    /// this path.
    ///
    /// - Returns: warnings when the cleanup itself failed, so the coordinator can
    ///   surface them; a failed cleanup is retried on the next launch. This is a
    ///   runtime result only and changes no persisted contract.
    func discardStagedFile(at url: URL) -> [String] {
        var warnings: [String] = []
        removeStagingCopyIfOwned(url, warnings: &warnings)
        return warnings
    }

    /// Deletes the received staging copy only when it really is this library's
    /// own staging file. A missing file is not an error.
    private func removeStagingCopyIfOwned(_ url: URL, warnings: inout [String]) {
        guard let target = try? PhotoLibraryLocation.canonicalStagedFile(url, rootURL: rootURL),
              fileManager.fileExists(atPath: target.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: target)
        } catch {
            warnings.append("Could not remove a temporary import file; a later launch will retry.")
        }
    }

    // MARK: - Directories and paths

    /// Resolves a **generated** library-relative path below the canonical root,
    /// enforcing the ownership invariant on every existing component.
    ///
    /// Every create, read, write, copy, rollback, delete and cleanup target goes
    /// through here, so a symlink component — pointing outside the library,
    /// aliasing another project's folder *inside* it, or dangling — is rejected
    /// instead of redirecting the operation. A genuinely missing tail is allowed,
    /// because that is the normal state of a folder about to be created.
    ///
    /// An empty relative path means the root itself and is only used when the
    /// library creates its own directories.
    private func resolvedLibraryPath(_ relativePath: String, label: String) throws -> URL {
        try PhotoLibraryPathGuard.resolve(
            relativePath,
            below: canonicalRootURL,
            label: label,
            fileManager: fileManager
        )
    }

    private func ensureLibraryDirectories() throws {
        try createDirectory("")
        try createDirectory(PhotoLibraryPath.projectsDirectoryName)
        try createDirectory(PhotoLibraryLocation.stagingDirectoryName)
    }

    /// Creates a library directory. `relativePath` is empty for the root itself,
    /// which is the one place where the resolved path is allowed to equal the
    /// root rather than being a strict subpath.
    private func createDirectory(_ relativePath: String) throws {
        let label = relativePath.isEmpty ? PhotoLibraryLocation.libraryDirectoryName : relativePath
        let target = try resolvedLibraryPath(relativePath, label: label)
        do {
            try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        } catch {
            throw PhotoLibraryError.fileOperationFailed(
                "cannot create \(target.lastPathComponent): \(error.localizedDescription)"
            )
        }
    }

    private func directoryContents(of url: URL) throws -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw PhotoLibraryError.fileOperationFailed("cannot list \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    // MARK: - Manifest

    private func loadPackage(projectID: UUID) throws -> ProjectPackage {
        let reference = PhotoLibraryPath.manifestReference(projectID)
        let url = try resolvedLibraryPath(reference, label: reference)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PhotoLibraryError.fileOperationFailed("missing \(PhotoLibraryPath.manifestFileName)")
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PhotoLibraryError.fileOperationFailed("cannot read manifest: \(error.localizedDescription)")
        }

        do {
            return try decoder.decode(ProjectPackage.self, from: data)
        } catch let error as PhotoLibraryError {
            throw error
        } catch {
            throw PhotoLibraryError.invalidPackage(error.localizedDescription)
        }
    }

    private func writeManifest(_ package: ProjectPackage) throws {
        // Last line of defence: whatever built this value, it must be a package
        // this build can decode again before it reaches the disk.
        try validatePackageEntry(package)

        let projectReference = PhotoLibraryPath.projectReference(package.project.id)
        try createDirectory(projectReference)

        let manifestReference = PhotoLibraryPath.manifestReference(package.project.id)
        let url = try resolvedLibraryPath(manifestReference, label: manifestReference)
        do {
            let data = try encoder.encode(package)
            // `.atomic` writes a sibling temporary file and renames it, so an
            // interrupted write can never leave a half-written manifest.
            try data.write(to: url, options: .atomic)
        } catch {
            throw PhotoLibraryError.fileOperationFailed("cannot write manifest: \(error.localizedDescription)")
        }
    }

    /// Applies an already-computed canvas document edit to a package.
    ///
    /// This is Stage 03's edit commit point: the updated manifest is validated and
    /// written atomically by the same writer the import path uses, and **no asset
    /// file is touched**. The caller (the single mutation gate in
    /// `PhotoImportModel`) guarantees at most one edit is in flight, and a thrown
    /// error leaves the previously committed manifest untouched.
    func saveEdit(
        document: CanvasDocument,
        into package: ProjectPackage,
        at date: Date
    ) throws -> PhotoLibraryMutationResult {
        try checkCancellation()
        try validatePackageEntry(package)
        guard document.id == package.project.document.id else {
            throw PhotoLibraryError.invalidPackage("canvas identity cannot change during an edit")
        }
        try ensureLibraryDirectories()

        var updatedProject = package.project
        updatedProject.document = document
        updatedProject.updatedAt = date
        let updatedPackage = ProjectPackage(project: updatedProject, photos: package.photos)
        try ProjectPackage.validate(
            photos: updatedPackage.photos,
            projectID: updatedProject.id,
            canvasSize: document.canvasSize,
            layers: document.layers
        )

        // Commit point: only after this succeeds is the edit committed.
        try checkCancellation()
        try writeManifest(updatedPackage)
        return PhotoLibraryMutationResult(package: updatedPackage, warnings: [])
    }

    // MARK: - Files

    private func sourceByteCount(of url: URL) throws -> Int {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values?.isRegularFile == true else {
            throw PhotoLibraryError.unreadableImage(url.lastPathComponent)
        }
        return values?.fileSize ?? 0
    }

    private func copyBytes(from sourceURL: URL, toReference reference: String) throws {
        let destination = try resolvedLibraryPath(reference, label: reference)
        do {
            try fileManager.copyItem(at: sourceURL, to: destination)
        } catch {
            throw PhotoLibraryError.fileOperationFailed("cannot copy original: \(error.localizedDescription)")
        }
    }

    private func rollbackAssetDirectory(_ reference: String, warnings: inout [String]) {
        guard let target = try? resolvedLibraryPath(reference, label: reference),
              fileManager.fileExists(atPath: target.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: target)
        } catch {
            warnings.append("Could not remove an incomplete import folder; a later launch will retry.")
        }
    }

    // MARK: - Cleanup

    private func missingFileWarnings(for package: ProjectPackage) -> [String] {
        var warnings: [String] = []
        for photo in package.photos {
            let references = [photo.asset.localReference, photo.thumbnailReference, photo.previewReference]
            for reference in references {
                guard let url = try? resolvedLibraryPath(reference, label: reference) else {
                    warnings.append("Photo \(photo.asset.id.uuidString.prefix(8)) has an invalid path")
                    continue
                }
                if !fileManager.fileExists(atPath: url.path) {
                    warnings.append("Photo \(photo.asset.id.uuidString.prefix(8)) is missing \(reference)")
                }
            }
        }
        return warnings
    }

    /// Removes asset folders of a **validated** package that no photo
    /// references, which is what an interrupted import leaves behind.
    ///
    /// Only unreferenced entries that are both UUID-named **and** directories are
    /// removed, and each removal is re-resolved against its generated path, so a
    /// plain file, an unrecognised name or a symlink alias is reported and kept.
    private func cleanupUnreferencedAssets(for package: ProjectPackage, warnings: inout [String]) {
        let assetsReference = "\(PhotoLibraryPath.projectReference(package.project.id))/\(PhotoLibraryPath.assetsDirectoryName)"
        guard let assetsRoot = try? resolvedLibraryPath(assetsReference, label: assetsReference),
              let entries = try? fileManager.contentsOfDirectory(
                  at: assetsRoot,
                  includingPropertiesForKeys: [.isDirectoryKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return
        }

        let referenced = Set(package.photos.map { $0.asset.id.uuidString.lowercased() })
        for entry in entries {
            let name = entry.lastPathComponent
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

            guard UUID(uuidString: name) != nil, isDirectory else {
                warnings.append("Left an unrecognised item in a project's assets folder: \(name)")
                continue
            }
            guard !referenced.contains(name.lowercased()) else { continue }

            do {
                let target = try resolvedLibraryPath("\(assetsReference)/\(name)", label: name)
                try fileManager.removeItem(at: target)
            } catch {
                warnings.append("Could not remove an unreferenced photo folder; a later launch will retry.")
            }
        }
    }

    /// Clears staging residue left by an interrupted import.
    ///
    /// Only entries that are **both** UUID-named and regular files are treated as
    /// our own staged copies; anything else in the staging directory (an unknown
    /// file or a nested directory) is reported and kept.
    private func cleanupStagingResidue(warnings: inout [String]) {
        guard let stagingRoot = try? PhotoLibraryLocation.canonicalStagingDirectory(rootURL: rootURL),
              let entries = try? fileManager.contentsOfDirectory(
                  at: stagingRoot,
                  includingPropertiesForKeys: [.isRegularFileKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return
        }

        for entry in entries {
            let name = entry.lastPathComponent
            let stem = entry.deletingPathExtension().lastPathComponent
            let isRegularFile = (try? entry.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true

            guard UUID(uuidString: stem) != nil, isRegularFile,
                  let target = try? PhotoLibraryLocation.canonicalStagedFile(entry, rootURL: rootURL) else {
                warnings.append("Left an unrecognised item in the staging area: \(name)")
                continue
            }

            do {
                try fileManager.removeItem(at: target)
            } catch {
                warnings.append("Could not remove leftover temporary import files; a later launch will retry.")
            }
        }
    }

    // MARK: - Validation

    /// Rejects a package this build cannot round-trip **before** any work
    /// happens: an unknown schema version (never silently downgraded to the
    /// current one) or photos whose stored values would not decode again.
    private func validatePackageEntry(_ package: ProjectPackage) throws {
        guard package.schemaVersion == ProjectPackage.currentSchemaVersion else {
            throw PhotoLibraryError.unsupportedSchemaVersion(package.schemaVersion)
        }
        try ProjectPackage.validate(photos: package.photos, projectID: package.project.id, canvasSize: package.project.document.canvasSize, layers: package.project.document.layers)
    }

    /// Source pixel count for the limit check, computed without overflowing.
    ///
    /// Corrupt properties can carry absurd dimensions, so the product is checked
    /// for overflow instead of being multiplied blindly. A non-positive dimension
    /// is reported as unreadable; a product that cannot be represented is
    /// reported as one over the limit, because the exact count does not fit.
    private static func checkedPixelCount(
        width: Int,
        height: Int,
        limit: Int,
        fileName: String
    ) throws -> Int {
        guard width > 0, height > 0 else {
            throw PhotoLibraryError.unreadableImage(fileName)
        }
        let product = width.multipliedReportingOverflow(by: height)
        return product.overflow ? limit + 1 : product.partialValue
    }

    // MARK: - Cancellation

    /// Cancellation is observed from the surrounding task, which is what the UI
    /// cancels. It is checked before any work and again around every commit so a
    /// cancelled import can never commit a half-finished photo.
    private func checkCancellation() throws {
        if Task.isCancelled {
            throw PhotoLibraryError.cancelled
        }
    }
}
