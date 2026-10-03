import XCTest
@testable import MomentsStudio

final class LayerModelTests: XCTestCase {
    func testLayerRoundTripsThroughJSON() throws {
        let layer = Layer(
            id: UUID(),
            kind: .photo,
            transform: LayerTransform(translationX: 8, translationY: -3, scale: 0.75, rotationRadians: 0.5),
            opacity: 0.35,
            zIndex: -1,
            isLocked: false,
            isHidden: true
        )

        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(Layer.self, from: data)

        XCTAssertEqual(decoded, layer)
    }

    func testDefaultLayerIsVisibleUnlockedAndFullyOpaque() {
        let layer = Layer()

        XCTAssertEqual(layer.kind, .photo)
        XCTAssertEqual(layer.opacity, 1)
        XCTAssertEqual(layer.zIndex, 0)
        XCTAssertFalse(layer.isLocked)
        XCTAssertFalse(layer.isHidden)
        XCTAssertEqual(layer.transform, .identity)
    }

    func testOpacityIsClampedOnInitAndWhenSet() {
        XCTAssertEqual(Layer(opacity: -0.5).opacity, 0)
        XCTAssertEqual(Layer(opacity: 1.5).opacity, 1)
        XCTAssertEqual(Layer(opacity: 0.25).opacity, 0.25)

        var layer = Layer()
        layer.setOpacity(4)
        XCTAssertEqual(layer.opacity, 1)

        layer.setOpacity(-4)
        XCTAssertEqual(layer.opacity, 0)
    }

    func testOpacityBoundaryValuesAreAccepted() {
        for boundary in [0.0, 1.0] {
            XCTAssertEqual(Layer(opacity: boundary).opacity, boundary)

            var layer = Layer()
            layer.setOpacity(boundary)
            XCTAssertEqual(layer.opacity, boundary)
        }
    }

    /// Programmatic input policy: a non-finite value has no meaning as an
    /// opacity, so it becomes the fully-opaque default instead of being stored.
    func testNonFiniteOpacityFallsBackToDefaultOnInitAndWhenSet() {
        for nonFinite in [Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertEqual(
                Layer(opacity: nonFinite).opacity,
                Layer.defaultOpacity,
                "init must replace non-finite opacity input"
            )

            var layer = Layer()
            layer.setOpacity(nonFinite)
            XCTAssertEqual(layer.opacity, Layer.defaultOpacity, "setOpacity must replace non-finite input")
        }
    }

    func testDecodingRejectsOpacityBelowZero() {
        assertOpacityDecodingIsRejected(layerJSON(opacity: "-0.1"))
    }

    func testDecodingRejectsOpacityAboveOne() {
        assertOpacityDecodingIsRejected(layerJSON(opacity: "1.0001"))
    }

    /// JSON has no literal for infinity or NaN, so this test configures the
    /// decoder to read the strings `"Infinity"` / `"-Infinity"` / `"NaN"` as
    /// non-finite `Double`s. That strategy exists only in this test — the app
    /// never sets it — and the assertion is that `Layer` rejects such a value
    /// instead of storing or repairing it.
    func testDecodingRejectsNonFiniteOpacity() {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )

        for literal in ["\"Infinity\"", "\"-Infinity\"", "\"NaN\""] {
            assertOpacityDecodingIsRejected(layerJSON(opacity: literal), using: decoder)
        }
    }

    func testDecodingAcceptsBoundaryOpacityValues() throws {
        let zero = try JSONDecoder().decode(Layer.self, from: layerJSON(opacity: "0"))
        let one = try JSONDecoder().decode(Layer.self, from: layerJSON(opacity: "1"))

        XCTAssertEqual(zero.opacity, 0)
        XCTAssertEqual(one.opacity, 1)
    }

    // MARK: - Helpers

    /// A complete layer document, so only `opacity` varies between cases.
    private func layerJSON(opacity: String) -> Data {
        Data(
            """
            {
              "id": "33333333-3333-3333-3333-333333333333",
              "kind": "photo",
              "transform": { "translationX": 0, "translationY": 0, "scale": 1, "rotationRadians": 0 },
              "opacity": \(opacity),
              "zIndex": 0,
              "isLocked": false,
              "isHidden": false
            }
            """.utf8
        )
    }

    /// Asserts that decoding fails with `DecodingError.dataCorrupted` on the
    /// `opacity` key, i.e. that a damaged archive is rejected instead of being
    /// silently clamped or defaulted.
    private func assertOpacityDecodingIsRejected(
        _ json: Data,
        using decoder: JSONDecoder = JSONDecoder(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try decoder.decode(Layer.self, from: json), file: file, line: line) { error in
            guard let decodingError = error as? DecodingError else {
                return XCTFail("Expected DecodingError, got \(error).", file: file, line: line)
            }
            guard case .dataCorrupted(let context) = decodingError else {
                return XCTFail("Expected DecodingError.dataCorrupted, got \(decodingError).", file: file, line: line)
            }
            XCTAssertEqual(context.codingPath.last?.stringValue, "opacity", file: file, line: line)
        }
    }
}
