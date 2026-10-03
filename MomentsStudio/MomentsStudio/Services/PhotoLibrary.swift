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

    static func stagingDirectoryURL(rootURL: URL) -> URL {
        rootURL.appendingPathComponent(stagingDirectoryName, isDirectory: true)
    }

    /// The staging directory, required to resolve to exactly
    /// `<canonical root>/Temporary`.
    ///
    /// Used before any staging create, copy or delete, so a symlinked staging
    /// directory — pointing outside the library or aliasing something inside it —
    /// can never redirect those operations.
    static func canonicalStagingDirectory(rootURL: URL) throws -> URL {
        let root = rootURL.resolvingSymlinksInPath().standardizedFileURL
        let expected = root
            .appendingPathComponent(stagingDirectoryName, isDirectory: true)
            .standardizedFileURL
        let candidate = rootURL.appendingPathComponent(stagingDirectoryName, isDirectory: true)
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path == expected.path else {
            throw PhotoLibraryError.invalidReference(stagingDirectoryName)
        }
        return resolved
    }

    /// Confirms that `url` **is** an owned staged file: its resolved location must
    /// be exactly `<canonical root>/Temporary/<its own file name>`.
    ///
    /// Matching on the file name alone is not ownership: a file outside the
    /// staging directory that happens to share a name must be refused.
    static func canonicalStagedFile(_ url: URL, rootURL: URL) throws -> URL {
        let staging = try canonicalStagingDirectory(rootURL: rootURL)
        let inspected = url.resolvingSymlinksInPath().standardizedFileURL
        let expected = staging
            .appendingPathComponent(url.lastPathComponent, isDirectory: false)
            .standardizedFileURL

        guard inspected.path == expected.path,
              inspected.deletingLastPathComponent().standardizedFileURL.path == staging.path else {
            throw PhotoLibraryError.invalidReference(url.lastPathComponent)
        }
        return inspected
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
        self.rootURL = rootURL.standardizedFileURL
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
        let assetReference = PhotoLibraryPath.assetDirectoryReference(projectID: projectID, assetID: assetID)
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
                projectID: projectID,
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
            try ProjectPackage.validate(photos: updatedPhotos, projectID: projectID)
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

        var updatedProject = package.project
        updatedProject.updatedAt = date
        let updatedPackage = ProjectPackage(project: updatedProject, photos: updatedPhotos)

        try writeManifest(updatedPackage)

        var warnings: [String] = []
        let assetReference = PhotoLibraryPath.assetDirectoryReference(
            projectID: package.project.id,
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

    /// The library root with symlinks resolved once.
    private var canonicalRootURL: URL {
        rootURL.resolvingSymlinksInPath().standardizedFileURL
    }

    /// Resolves a **generated** library-relative path and requires the result to
    /// be exactly `<canonical root>/<relative path>`.
    ///
    /// Comparing against the expected canonical location — rather than merely
    /// checking that the result sits somewhere inside the root — is what rejects
    /// a symlink alias *within* the library, for example `A/assets` pointing at
    /// `B/assets`, which would otherwise let one project write into, or clean up,
    /// another project's files.
    ///
    /// An empty relative path means the root itself and is only used when the
    /// library creates its own directories; every file, asset and cleanup target
    /// must be a strict subpath.
    private func resolvedLibraryPath(_ relativePath: String, label: String) throws -> URL {
        let root = canonicalRootURL
        let expected: URL
        let candidate: URL

        if relativePath.isEmpty {
            expected = root
            candidate = rootURL
        } else {
            expected = root.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL
            candidate = rootURL.appendingPathComponent(relativePath, isDirectory: false)
        }

        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path == expected.path else {
            throw PhotoLibraryError.invalidReference(label)
        }
        return resolved
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
        try ProjectPackage.validate(photos: package.photos, projectID: package.project.id)
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
