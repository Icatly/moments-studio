import Foundation

/// Errors thrown by the Stage 02 photo library.
///
/// The cases stay distinguishable so the UI can explain a specific reason
/// instead of a generic failure: cancellation, unsupported input, size and
/// pixel limits, path/reference damage and package damage are all separate.
/// Cancellation is not a failure of the user's data — nothing is committed
/// when it is thrown.
enum PhotoLibraryError: Error, Equatable {
    /// A stored or requested path is not one of the generated library paths.
    case invalidReference(String)
    /// A photo package is structurally invalid: duplicate ids, non-positive
    /// dimensions, an out-of-range orientation, too many photos, or a
    /// reference that does not belong to its own project/asset.
    case invalidPackage(String)
    /// `ProjectPackage.schemaVersion` is not supported by this build.
    case unsupportedSchemaVersion(Int)
    /// ImageIO did not recognise the file as one of the supported still formats.
    case unsupportedImageType(String)
    /// The source file could not be read, or no image source could be created.
    case unreadableImage(String)
    /// The source file is larger than the per-file byte limit.
    case fileTooLarge(limitBytes: Int, actualBytes: Int)
    /// The source image has more pixels than the per-photo pixel limit.
    case tooManyPixels(limit: Int, actualPixels: Int)
    /// The project already holds the maximum number of photos.
    case photoLimitReached(limit: Int)
    /// The requested photo is not part of the package that was passed in.
    case photoNotFound(UUID)
    /// The work was cancelled before it committed; no partial state is kept.
    case cancelled
    /// A file operation failed. The message keeps the underlying reason.
    case fileOperationFailed(String)
}

extension PhotoLibraryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidReference(let reference):
            return "Stored photo path is not valid: \(reference)"
        case .invalidPackage(let reason):
            return "Saved project data is not valid: \(reason)"
        case .unsupportedSchemaVersion(let version):
            return "Saved project uses unsupported format version \(version)"
        case .unsupportedImageType(let type):
            return "Unsupported image type: \(type)"
        case .unreadableImage(let name):
            return "Could not read image: \(name)"
        case .fileTooLarge(let limitBytes, let actualBytes):
            return "Photo is too large (\(actualBytes) bytes, limit \(limitBytes))"
        case .tooManyPixels(let limit, let actualPixels):
            return "Photo has too many pixels (\(actualPixels), limit \(limit))"
        case .photoLimitReached(let limit):
            return "This project already holds the maximum of \(limit) photos"
        case .photoNotFound(let assetID):
            return "Photo is no longer part of this project: \(assetID.uuidString)"
        case .cancelled:
            return "Import cancelled"
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        }
    }
}

/// Pure, library-relative path rules for photo packages.
///
/// Every stored reference is produced by this type and validated by it, so a
/// damaged or hand-edited manifest cannot point outside its own project, at
/// another project's assets, or up the directory tree. There is no filesystem
/// access here — identity and string validation only — which lets
/// `ProjectPackage` validate references while decoding.
enum PhotoLibraryPath {
    /// Which generated file a reference points at.
    enum FileKind: String, Equatable {
        case original
        case thumbnail
        case preview
    }

    static let projectsDirectoryName = "Projects"
    static let assetsDirectoryName = "assets"
    static let manifestFileName = "manifest.json"
    /// Extensions allowed for generated derivatives. Originals keep the
    /// extension ImageIO detected for the received file.
    static let derivativeExtensions: Set<String> = ["jpg", "jpeg", "png"]
    /// Extensions allowed for stored originals: exactly the still-image formats
    /// this stage accepts (JPEG/PNG/HEIC/HEIF). A reference such as
    /// `original.gif` is not something this pipeline can produce or read, so it
    /// is rejected instead of being accepted as a "generated" path.
    static let supportedOriginalExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif"]

    static func projectDirectoryName(_ projectID: UUID) -> String {
        projectID.uuidString
    }

    /// `Projects/<projectID>`
    static func projectReference(_ projectID: UUID) -> String {
        "\(projectsDirectoryName)/\(projectDirectoryName(projectID))"
    }

    /// `Projects/<projectID>/manifest.json`
    static func manifestReference(_ projectID: UUID) -> String {
        "\(projectReference(projectID))/\(manifestFileName)"
    }

    /// `Projects/<projectID>/assets/<assetID>`
    static func assetDirectoryReference(_ projectID: UUID, assetID: UUID) -> String {
        "\(projectReference(projectID))/\(assetsDirectoryName)/\(assetID.uuidString)"
    }

    /// `Projects/<projectID>/assets/<assetID>/original.<ext>`
    static func originalReference(_ projectID: UUID, assetID: UUID, fileExtension: String) -> String {
        "\(assetDirectoryReference(projectID, assetID: assetID))/\(FileKind.original.rawValue).\(fileExtension.lowercased())"
    }

    /// `Projects/<projectID>/assets/<assetID>/<kind>.<ext>`
    static func derivativeReference(
        _ kind: FileKind,
        projectID: UUID,
        assetID: UUID,
        fileExtension: String
    ) -> String {
        "\(assetDirectoryReference(projectID, assetID: assetID))/\(kind.rawValue).\(fileExtension.lowercased())"
    }

    /// Parses a reference into identity plus file kind, rejecting anything that
    /// is not a path this library generates.
    static func parse(
        _ reference: String
    ) throws -> (projectID: UUID, assetID: UUID, kind: FileKind, fileExtension: String) {
        guard !reference.isEmpty, !reference.hasPrefix("/"), !reference.contains("\\") else {
            throw PhotoLibraryError.invalidReference(reference)
        }

        let components = reference.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard components.count == 5,
              components[0] == projectsDirectoryName,
              let projectID = UUID(uuidString: components[1]),
              components[2] == assetsDirectoryName,
              let assetID = UUID(uuidString: components[3]) else {
            throw PhotoLibraryError.invalidReference(reference)
        }

        let nameParts = components[4].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard nameParts.count == 2, let kind = FileKind(rawValue: nameParts[0]) else {
            throw PhotoLibraryError.invalidReference(reference)
        }

        let fileExtension = nameParts[1].lowercased()
        switch kind {
        case .original:
            guard supportedOriginalExtensions.contains(fileExtension) else {
                throw PhotoLibraryError.invalidReference(reference)
            }
        case .thumbnail, .preview:
            guard derivativeExtensions.contains(fileExtension) else {
                throw PhotoLibraryError.invalidReference(reference)
            }
        }

        return (projectID, assetID, kind, fileExtension)
    }

    /// Validates that `reference` is exactly the generated file `kind` for this
    /// project and asset, and returns its file extension.
    @discardableResult
    static func validate(
        _ reference: String,
        projectID: UUID,
        assetID: UUID,
        expecting kind: FileKind
    ) throws -> String {
        let parsed = try parse(reference)
        guard parsed.projectID == projectID, parsed.assetID == assetID, parsed.kind == kind else {
            throw PhotoLibraryError.invalidReference(reference)
        }
        return parsed.fileExtension
    }

    /// Validates a *derivative* reference without knowing its identifiers, which
    /// is what `PhotoLibrary.loadDerivedImage` needs so it can never be used as
    /// a bypass to load an original.
    static func validateDerivative(
        _ reference: String
    ) throws -> (projectID: UUID, assetID: UUID, kind: FileKind, fileExtension: String) {
        let parsed = try parse(reference)
        guard parsed.kind != .original else {
            throw PhotoLibraryError.invalidReference(reference)
        }
        return parsed
    }
}
