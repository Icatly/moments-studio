import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// File-based ingestion of one picked photo.
///
/// `PhotosPicker` hands the app a file whose URL is valid only for the duration
/// of the `importing` closure. This type copies the received bytes into the
/// app's own staging directory *before* that closure returns, so the app never
/// retains a system temporary URL and never treats one as the original. The
/// received bytes are copied unchanged — no re-encoding, no downscaling, and
/// nothing is written back to the photo library.
struct PhotoFileTransfer: Transferable {
    /// App-owned staging file: a byte-for-byte copy of the received
    /// representation.
    let stagedFileURL: URL

    /// The transferable representation must produce **this** type, so the
    /// importing closure wraps the staged URL rather than returning it directly.
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            PhotoFileTransfer(stagedFileURL: try await stageCopy(of: received.file))
        }
    }

    /// Copies the received file into a UUID-named file inside the app-owned
    /// staging directory and returns the copy's URL.
    ///
    /// `nonisolated async`, so the copy runs off the main actor inside the
    /// caller's task: an explicit non-MainActor file boundary rather than an
    /// assumption about which thread the framework calls back on, and without
    /// adding another actor, queue or protocol.
    ///
    /// The per-file byte ceiling and a cancellation check both happen **before**
    /// any copy, the staging directory itself is verified to be exactly
    /// `<canonical root>/Temporary`, and cancellation is checked again after the
    /// copy. If the copy fails or is cancelled, only the app's own file is
    /// removed and the received source is never touched.
    ///
    /// - Parameter rootURL: library root; defaults to the app's Application
    ///   Support library. Tests pass their own temporary root.
    nonisolated static func stageCopy(
        of source: URL,
        rootURL: URL = PhotoLibraryLocation.applicationSupportRootURL(),
        limits: PhotoLibraryLimits = .standard
    ) async throws -> URL {
        try Task.checkCancellation()

        let values = try? source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values?.isRegularFile == true else {
            throw PhotoLibraryError.unreadableImage(source.lastPathComponent)
        }
        let byteCount = values?.fileSize ?? 0
        guard byteCount <= limits.maxSourceBytes else {
            throw PhotoLibraryError.fileTooLarge(limitBytes: limits.maxSourceBytes, actualBytes: byteCount)
        }

        let stagingDirectory = try PhotoLibraryLocation.canonicalStagingDirectory(rootURL: rootURL)
        let fileExtension = source.pathExtension.isEmpty ? "img" : source.pathExtension
        let destination = stagingDirectory.appendingPathComponent(
            "\(UUID().uuidString).\(fileExtension)",
            isDirectory: false
        )

        do {
            try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            try Task.checkCancellation()
            try FileManager.default.copyItem(at: source, to: destination)
            // A cancelled task must not return an uncleaned staged copy.
            try Task.checkCancellation()
        } catch {
            // Never leave our own copy behind, and never touch the source.
            try? FileManager.default.removeItem(at: destination)
            if error is CancellationError {
                throw error
            }
            throw PhotoLibraryError.fileOperationFailed(
                "cannot stage the selected photo: \(error.localizedDescription)"
            )
        }

        return destination
    }
}
