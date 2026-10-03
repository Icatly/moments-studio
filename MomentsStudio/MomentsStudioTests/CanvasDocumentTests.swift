import XCTest
@testable import MomentsStudio

final class CanvasDocumentTests: XCTestCase {
    /// Decoding this fixture pins the serialized document format: field names,
    /// nesting and enum raw values. Changing it is a contract change.
    private let documentFixture = """
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "canvasSize": { "width": 1080, "height": 1350 },
      "layers": [
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "kind": "photo",
          "transform": { "translationX": 12.5, "translationY": -4, "scale": 1.5, "rotationRadians": 0.25 },
          "opacity": 0.8,
          "zIndex": 3,
          "isLocked": true,
          "isHidden": false
        }
      ]
    }
    """

    func testEmptyDocumentHasNoLayersAndPlaceholderCanvasSize() {
        let document = CanvasDocument.empty

        XCTAssertTrue(document.layers.isEmpty)
        XCTAssertEqual(document.canvasSize, CanvasSize(width: 1080, height: 1350))
    }

    func testDocumentDecodesFromDocumentedFixture() throws {
        let data = try XCTUnwrap(documentFixture.data(using: .utf8))

        let document = try JSONDecoder().decode(CanvasDocument.self, from: data)

        XCTAssertEqual(document.id, UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        XCTAssertEqual(document.canvasSize, CanvasSize(width: 1080, height: 1350))
        XCTAssertEqual(document.layers.count, 1)

        let layer = try XCTUnwrap(document.layers.first)
        XCTAssertEqual(layer.kind, .photo)
        XCTAssertEqual(layer.opacity, 0.8, accuracy: 0.0001)
        XCTAssertEqual(layer.zIndex, 3)
        XCTAssertTrue(layer.isLocked)
        XCTAssertFalse(layer.isHidden)
        XCTAssertEqual(layer.transform.translationX, 12.5, accuracy: 0.0001)
        XCTAssertEqual(layer.transform.translationY, -4, accuracy: 0.0001)
        XCTAssertEqual(layer.transform.scale, 1.5, accuracy: 0.0001)
        XCTAssertEqual(layer.transform.rotationRadians, 0.25, accuracy: 0.0001)
    }

    /// Verifies that a Codable round trip preserves **storage order**. It asserts
    /// nothing about rendering: the stacking rule (larger `zIndex` is nearer the
    /// viewer, ties broken by the later array position) is defined in
    /// `CanvasDocument`'s documentation, and Stage 01 has no renderer.
    func testDocumentRoundTripPreservesLayerOrder() throws {
        let bottom = Layer(id: UUID(), zIndex: 0)
        let top = Layer(id: UUID(), zIndex: 1)
        let document = CanvasDocument(canvasSize: .portrait4x5, layers: [bottom, top])

        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(CanvasDocument.self, from: data)

        XCTAssertEqual(decoded, document)
        XCTAssertEqual(decoded.layers.map(\.id), [bottom.id, top.id])
    }
}
