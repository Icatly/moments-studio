import CoreGraphics
import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import XCTest
@testable import MomentsStudio

#if canImport(Darwin)
import Darwin
#endif

/// Stage 02 performance/behaviour verification path required by acceptance:
/// a serial batch of three generated 4000×3000 (12 MP) JPEG stills plus a
/// deterministic mid-batch cancellation.
///
/// What this file does **not** claim:
/// - no pass/fail threshold on time or memory (there is no hard-coded budget);
/// - the memory numbers are **snapshots** of this process at two call sites, not
///   peak RSS, and a simulator/CI run says nothing about real-device performance;
/// - fixture bytes are small (flat two-colour JPEGs); the 12 MP size exercises
///   the decode/derivative path, not network or storage throughput.
///
/// Fixture generation happens before timing starts, and decoded derivatives are
/// scoped to one loop iteration so the test never holds three originals'
/// worth of pixels at once.
final class LargePhotoBatchTests: XCTestCase {
    private static let largeWidth = 4000
    private static let largeHeight = 3000

    private var baseURL: URL!
    private var rootURL: URL!
    private var fixturesURL: URL!

    override func setUpWithError() throws {
        baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MomentsStudioLargeBatchTests-\(UUID().uuidString)", isDirectory: true)
        rootURL = baseURL.appendingPathComponent("Library", isDirectory: true)
        fixturesURL = baseURL.appendingPathComponent("Fixtures", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fixturesURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let baseURL {
            try? FileManager.default.removeItem(at: baseURL)
        }
    }

    // MARK: - Serial large-photo batch

    func testSerialThreeLargePhotoBatchCommitsOrderedBoundedAndRecordsMetrics() async throws {
        // Generation is deliberately outside the measured section.
        let fixtureURLs = try makeLargeFixtures(count: 3)
        let library = PhotoLibrary(rootURL: rootURL)
        let projectID = UUID()
        var package = ProjectPackage(
            project: Project(id: projectID, name: "Large batch", createdAt: Date()),
            photos: []
        )

        let memoryBefore = Self.memorySnapshot()
        let started = Date()

        // Serial: one photo at a time through the real library.
        var committedIDs: [UUID] = []
        for fixtureURL in fixtureURLs {
            let result = try await library.importPhoto(fileURL: fixtureURL, into: package, at: Date())
            package = result.package
            committedIDs.append(try XCTUnwrap(result.package.photos.last).asset.id)
        }

        let elapsedSeconds = Date().timeIntervalSince(started)
        let memoryAfter = Self.memorySnapshot()

        // MARK: behaviour contract (the only asserted facts)

        XCTAssertEqual(package.photos.count, 3)
        XCTAssertEqual(
            package.photos.map(\.asset.id),
            committedIDs,
            "the committed order must be the import order"
        )
        XCTAssertEqual(Set(package.photos.map(\.asset.id)).count, 3, "each still is its own photo")

        for (index, photo) in package.photos.enumerated() {
            XCTAssertEqual(photo.pixelWidth, Self.largeWidth)
            XCTAssertEqual(photo.pixelHeight, Self.largeHeight)
            XCTAssertEqual(photo.contentType, UTType.jpeg.identifier)

            // Original: byte-for-byte copy of the received file.
            let sourceBytes = try Data(contentsOf: fixtureURLs[index])
            let originalURL = rootURL.appendingPathComponent(photo.asset.localReference)
            XCTAssertEqual(
                try Data(contentsOf: originalURL),
                sourceBytes,
                "original \(index + 1) must be preserved byte for byte"
            )

            // Derivatives are bounded by role and never upscaled. Each image is
            // released before the next iteration, so only one pair is alive.
            let thumbnail = try await library.loadDerivedImage(reference: photo.thumbnailReference)
            XCTAssertLessThanOrEqual(max(thumbnail.width, thumbnail.height), 320)
            let preview = try await library.loadDerivedImage(reference: photo.previewReference)
            XCTAssertLessThanOrEqual(max(preview.width, preview.height), 2048)
            XCTAssertGreaterThan(
                max(preview.width, preview.height),
                max(thumbnail.width, thumbnail.height),
                "the preview must be larger than the thumbnail"
            )
        }

        // Restore sees the same three photos in the same order.
        let restored = try await library.restore()
        XCTAssertEqual(restored.packages.count, 1)
        XCTAssertEqual(restored.packages.first?.photos.map(\.asset.id), committedIDs)
        XCTAssertTrue(restored.warnings.isEmpty, "unexpected warnings: \(restored.warnings)")

        recordMetrics(elapsedSeconds: elapsedSeconds, memoryBefore: memoryBefore, memoryAfter: memoryAfter)
    }

    // MARK: - Deterministic mid-batch cancellation

    @MainActor
    func testBatchCancellationKeepsCommittedPhotoAndCleansStaging() async throws {
        let fixtureURLs = try makeLargeFixtures(count: 1, prefix: "cancel")
        let fixture = try XCTUnwrap(fixtureURLs.first)
        let root: URL = rootURL
        let library = PhotoLibrary(rootURL: rootURL)
        let store = ProjectStore()

        // Items after the first stay blocked in the loader until the test has
        // cancelled, which makes the interleaving deterministic: the first photo
        // is committed before cancellation, the rest are not.
        let blockGate = TestGate()
        let calls = LoadCallCounter()
        let model = PhotoImportModel(library: library, store: store) { _ in
            if await calls.next() > 1 {
                await blockGate.wait()
            }
            return try await PhotoFileTransfer.stageCopy(of: fixture, rootURL: root)
        }

        let projectID = UUID()
        store.apply(
            ProjectPackage(project: Project(id: projectID, name: "Cancelled batch", createdAt: Date()), photos: [])
        )

        let items = (1...3).map { PhotosPickerItem(itemIdentifier: "synthetic-large-\($0)") }
        let batch = Task { await model.importSelection(items, projectID: projectID) }

        // Reaching the gate means item 2 is blocked, so item 1 already committed.
        await blockGate.waitUntilEntered()
        XCTAssertEqual(store.photos(for: projectID).count, 1, "the first photo must be committed before cancelling")

        // `cancelImport` is a synchronous MainActor method, so this test (also
        // MainActor) calls it directly — no `await`, which would only warn.
        model.cancelImport(projectID: projectID)
        await blockGate.open()
        await batch.value

        // Committed photos remain; remaining items do not commit; cancellation is
        // not reported as a failure.
        XCTAssertEqual(store.photos(for: projectID).count, 1)
        XCTAssertEqual(model.completedCount, 1)
        XCTAssertFalse(model.isImporting)
        XCTAssertTrue(model.itemErrors.isEmpty, "cancellation must not be a failure: \(model.itemErrors)")

        let restored = try await library.restore()
        XCTAssertEqual(restored.packages.first?.photos.count, 1, "store and disk must agree")
        XCTAssertEqual(restored.warnings, [])

        // Staging is cleaned for both the committed item and the cancelled one.
        let staging = rootURL.appendingPathComponent(PhotoLibraryLocation.stagingDirectoryName, isDirectory: true)
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: staging.path)) ?? []
        XCTAssertTrue(leftovers.isEmpty, "cancelled items must not leave staged copies: \(leftovers)")
    }

    // MARK: - Fixtures

    /// Writes `count` 4000×3000 JPEG stills. Sampling helper reuses the shared
    /// synthetic factory, so no real photograph is involved.
    private func makeLargeFixtures(count: Int, prefix: String = "large") throws -> [URL] {
        try (1...count).map { index in
            try SyntheticImageFactory.writeFixture(
                in: fixturesURL,
                name: "\(prefix)-\(index).jpg",
                width: Self.largeWidth,
                height: Self.largeHeight
            )
        }
    }

    // MARK: - Observable metrics (recorded, never asserted)

    private func recordMetrics(
        elapsedSeconds: TimeInterval,
        memoryBefore: (footprintBytes: UInt64, residentBytes: UInt64)?,
        memoryAfter: (footprintBytes: UInt64, residentBytes: UInt64)?
    ) {
        var lines = [
            "stage02 large-batch metrics — observable facts, NOT pass/fail thresholds",
            "stills=3 x \(Self.largeWidth)x\(Self.largeHeight) JPEG, serial import through PhotoLibrary",
            String(format: "elapsed_import_seconds=%.3f", elapsedSeconds),
        ]
        if let memoryBefore, let memoryAfter {
            lines.append("memory_snapshot_units=bytes")
            lines.append("memory_before_phys_footprint_bytes=\(memoryBefore.footprintBytes)")
            lines.append("memory_before_resident_bytes=\(memoryBefore.residentBytes)")
            lines.append("memory_after_phys_footprint_bytes=\(memoryAfter.footprintBytes)")
            lines.append("memory_after_resident_bytes=\(memoryAfter.residentBytes)")
            let footprintDelta = Int64(memoryAfter.footprintBytes) - Int64(memoryBefore.footprintBytes)
            lines.append("phys_footprint_delta_bytes=\(footprintDelta)")
        } else {
            lines.append("memory_snapshot=unavailable on this platform (Darwin task_info not compiled in)")
        }
        lines.append("note=snapshots at two call sites, not peak RSS; simulator/CI values are not real-device performance")

        let summary = lines.joined(separator: "\n")
        print(summary)

        let attachment = XCTAttachment(string: summary)
        attachment.name = "stage02-large-batch-metrics"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Observable process memory snapshot in **bytes**.
    ///
    /// `phys_footprint` is the value XCTest's own memory metric reports and
    /// `resident_size` is the resident size. Both describe this process **at the
    /// call site**: they are not peak RSS and are not a real-device measurement.
    /// Returns `nil` when the platform API is unavailable instead of failing.
    private static func memorySnapshot() -> (footprintBytes: UInt64, residentBytes: UInt64)? {
        #if canImport(Darwin)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let status = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        return (UInt64(info.phys_footprint), UInt64(info.resident_size))
        #else
        return nil
        #endif
    }
}

/// Counts loader invocations so the cancellation test can block only the items
/// after the first. Test-only; no production type depends on it.
private actor LoadCallCounter {
    private var calls = 0

    func next() -> Int {
        calls += 1
        return calls
    }
}
