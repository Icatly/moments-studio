import XCTest
@testable import MomentsStudio

/// Stage 03 contract, geometry and document-operation tests.
///
/// These only touch models and pure functions: no SwiftUI, no file system. The
/// frozen version 1 layer below is a hand-written literal in the real Stage 02 key
/// shape (no `assetID`/`baseSize` keys at all), which is exactly what a document
/// written by the previous build contains.
final class Stage03ContractTests: XCTestCase {

    /// A real Stage 02 layer: the two Stage 03 keys do not exist yet.
    private let frozenVersion1LayerJSON = """
    {
      "id": "6F1B1B4E-3A2E-4C9B-8E7A-9F0C1D2E3F40",
      "kind": "photo",
      "transform": { "translationX": 10, "translationY": 20, "scale": 1.5, "rotationRadians": 0.25 },
      "opacity": 0.8,
      "zIndex": 3,
      "isLocked": true,
      "isHidden": false
    }
    """

    // MARK: - Frozen version 1 compatibility

    func testFrozenVersion1LayerDecodesAsUnboundPlaceholder() throws {
        let layer = try JSONDecoder().decode(Layer.self, from: Data(frozenVersion1LayerJSON.utf8))

        XCTAssertEqual(layer.transform.translationX, 10)
        XCTAssertEqual(layer.transform.translationY, 20)
        XCTAssertEqual(layer.transform.scale, 1.5)
        XCTAssertEqual(layer.transform.rotationRadians, 0.25)
        XCTAssertEqual(layer.opacity, 0.8)
        XCTAssertEqual(layer.zIndex, 3)
        XCTAssertTrue(layer.isLocked)
        XCTAssertFalse(layer.isHidden)
        // Historical layers are kept as honest unbound placeholders.
        XCTAssertNil(layer.assetID)
        XCTAssertNil(layer.baseSize)
        XCTAssertFalse(layer.isBoundToAsset)
    }

    func testVersion1ShapedPackageUpgradesInMemoryAndWritesVersion2() throws {
        // Build a real package, then rewrite it into the Stage 02 shape: version 1
        // and layers without the Stage 03 keys.
        let layer = Layer(zIndex: 2)
        let document = CanvasDocument(layers: [layer, Layer(zIndex: -5)])
        let package = ProjectPackage(project: Project(name: "Legacy"), photos: [])
            .withDocument(document)
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(package)) as? [String: Any]
        )
        json["schemaVersion"] = 1
        var project = try XCTUnwrap(json["project"] as? [String: Any])
        var documentJSON = try XCTUnwrap(project["document"] as? [String: Any])
        var layers = try XCTUnwrap(documentJSON["layers"] as? [[String: Any]])
        for index in layers.indices {
            layers[index].removeValue(forKey: "assetID")
            layers[index].removeValue(forKey: "baseSize")
        }
        documentJSON["layers"] = layers
        project["document"] = documentJSON
        json["project"] = project
        let version1Data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(ProjectPackage.self, from: version1Data)

        // Upgraded in memory only; the file is not rewritten by the act of reading.
        XCTAssertEqual(decoded.schemaVersion, ProjectPackage.currentSchemaVersion)
        XCTAssertEqual(decoded.project.document.layers.count, 2)
        XCTAssertFalse(decoded.project.document.layers[0].isBoundToAsset)
        XCTAssertEqual(decoded.project.document.layers[0].zIndex, 2)

        // The next successful write uses version 2.
        let reEncoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any]
        XCTAssertEqual(reEncoded?["schemaVersion"] as? Int, 2)
    }

    func testUnknownSchemaVersionIsRejected() throws {
        let data = Data(#"{"schemaVersion": 99, "project": {}, "photos": []}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectPackage.self, from: data)) { error in
            XCTAssertEqual(error as? PhotoLibraryError, .unsupportedSchemaVersion(99))
        }
    }

    /// A frozen Stage 02 package: `schemaVersion` 1, no photos, and one layer with
    /// no `assetID`/`baseSize`. Written by hand in the real key shape rather than
    /// produced by the current encoder.
    private let frozenVersion1PackageJSON = """
    {
      "schemaVersion": 1,
      "project": {
        "id": "11111111-2222-3333-4444-555555555555",
        "name": "Legacy Project",
        "createdAt": 0,
        "updatedAt": 0,
        "document": {
          "id": "66666666-7777-8888-9999-AAAAAAAAAAAA",
          "canvasSize": { "width": 1080, "height": 1350 },
          "layers": [
            {
              "id": "6F1B1B4E-3A2E-4C9B-8E7A-9F0C1D2E3F40",
              "kind": "photo",
              "transform": { "translationX": 540, "translationY": 675, "scale": 1, "rotationRadians": 0 },
              "opacity": 1,
              "zIndex": 0,
              "isLocked": false,
              "isHidden": false
            }
          ]
        }
      },
      "photos": []
    }
    """

    func testFrozenVersion1PackageDecodesUpgradesInMemoryAndKeepsTheFileShape() throws {
        let frozen = Data(frozenVersion1PackageJSON.utf8)
        let decoded = try JSONDecoder().decode(ProjectPackage.self, from: frozen)

        // Read as version 2 in memory, historical layer preserved as unbound.
        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.project.name, "Legacy Project")
        XCTAssertEqual(decoded.project.document.canvasSize, CanvasSize(width: 1080, height: 1350))
        XCTAssertEqual(decoded.project.document.layers.count, 1)
        XCTAssertNil(decoded.project.document.layers[0].assetID)
        XCTAssertNil(decoded.project.document.layers[0].baseSize)
        XCTAssertEqual(decoded.project.document.layers[0].transform.translationX, 540)

        // Reading alone does not rewrite: the input bytes are untouched.
        XCTAssertEqual(Data(frozenVersion1PackageJSON.utf8), frozen)

        // The next successful write uses the current version.
        let written = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any]
        XCTAssertEqual(written?["schemaVersion"] as? Int, 2)
    }

    // MARK: - Damaged Stage 03 values

    private func layerJSON(
        assetID: String?,
        baseSize: String?,
        transform: String = "{\"translationX\":1,\"translationY\":2,\"scale\":1,\"rotationRadians\":0}"
    ) -> Data {
        var parts: [String] = [
            "\"id\": \"6F1B1B4E-3A2E-4C9B-8E7A-9F0C1D2E3F40\"",
            "\"kind\": \"photo\"",
            "\"transform\": \(transform)",
            "\"opacity\": 1",
            "\"zIndex\": 0",
            "\"isLocked\": false",
            "\"isHidden\": false",
        ]
        if let assetID { parts.append("\"assetID\": \"\(assetID)\"") }
        if let baseSize { parts.append("\"baseSize\": \(baseSize)") }
        let json = "{" + parts.joined(separator: ",") + "}"
        return Data(json.utf8)
    }

    func testLayerWithOnlyOneStage03KeyIsRejected() throws {
        XCTAssertThrowsError(try JSONDecoder().decode(Layer.self, from: layerJSON(assetID: UUID().uuidString, baseSize: nil)))
        XCTAssertThrowsError(try JSONDecoder().decode(Layer.self, from: layerJSON(assetID: nil, baseSize: "{\"width\":10,\"height\":10}")))
    }

    func testLayerWithUnusableBaseSizeIsRejected() throws {
        XCTAssertThrowsError(try JSONDecoder().decode(Layer.self, from: layerJSON(assetID: UUID().uuidString, baseSize: "{\"width\":0,\"height\":10}")))
        XCTAssertThrowsError(try JSONDecoder().decode(Layer.self, from: layerJSON(assetID: UUID().uuidString, baseSize: "{\"width\":10,\"height\":-1}")))
    }

    func testLayerWithUnusableTransformIsRejected() throws {
        let zeroScale = "{\"translationX\":1,\"translationY\":2,\"scale\":0,\"rotationRadians\":0}"
        XCTAssertThrowsError(try JSONDecoder().decode(Layer.self, from: layerJSON(assetID: nil, baseSize: nil, transform: zeroScale)))
    }

    // MARK: - Package level validation

    func testLayerLimitIsEnforced() {
        let layers = (0..<ProjectPackage.layerLimit).map { _ in Layer() }
        XCTAssertNoThrow(try ProjectPackage.validate(photos: [], projectID: UUID(), layers: layers))
        XCTAssertThrowsError(
            try ProjectPackage.validate(photos: [], projectID: UUID(), layers: layers + [Layer()])
        ) { error in
            guard case .invalidPackage = error as? PhotoLibraryError else {
                return XCTFail("expected invalidPackage, got \(error)")
            }
        }
    }

    func testDuplicateLayerIdentityIsRejected() {
        let repeated = Layer()
        XCTAssertThrowsError(
            try ProjectPackage.validate(photos: [], projectID: UUID(), layers: [repeated, repeated])
        ) { error in
            guard case .invalidPackage = error as? PhotoLibraryError else {
                return XCTFail("expected invalidPackage, got \(error)")
            }
        }
    }

    func testLayerBoundToMissingAssetIsRejected() {
        let layer = Layer(assetID: UUID(), baseSize: CanvasSize(width: 100, height: 200))
        XCTAssertThrowsError(
            try ProjectPackage.validate(photos: [], projectID: UUID(), layers: [layer])
        ) { error in
            guard case .invalidPackage = error as? PhotoLibraryError else {
                return XCTFail("expected invalidPackage, got \(error)")
            }
        }
    }

    func testUnusableCanvasSizeIsRejected() {
        XCTAssertThrowsError(
            try ProjectPackage.validate(
                photos: [],
                projectID: UUID(),
                canvasSize: CanvasSize(width: 0, height: 1350),
                layers: []
            )
        ) { error in
            guard case .invalidPackage = error as? PhotoLibraryError else {
                return XCTFail("expected invalidPackage, got \(error)")
            }
        }
    }

    // MARK: - Geometry

    func testNewLayerFitsInsideThreeQuarterBoxWithoutDistortion() throws {
        let canvas = CanvasSize.portrait4x5
        let portrait = try XCTUnwrap(CanvasGeometry.fittedBaseSize(displayWidth: 3000, displayHeight: 4000, canvasSize: canvas))
        XCTAssertLessThanOrEqual(portrait.width, canvas.width * 0.75 + 0.001)
        XCTAssertLessThanOrEqual(portrait.height, canvas.height * 0.75 + 0.001)
        XCTAssertEqual(portrait.width / portrait.height, 3000.0 / 4000.0, accuracy: 0.0001)

        let landscape = try XCTUnwrap(CanvasGeometry.fittedBaseSize(displayWidth: 4000, displayHeight: 3000, canvasSize: canvas))
        XCTAssertLessThanOrEqual(landscape.width, canvas.width * 0.75 + 0.001)
        XCTAssertLessThanOrEqual(landscape.height, canvas.height * 0.75 + 0.001)
        XCTAssertEqual(landscape.width / landscape.height, 4000.0 / 3000.0, accuracy: 0.0001)
    }

    func testCanvasFitMapsBothWaysAndIgnoresViewportChangesInTheDocument() throws {
        let canvas = CanvasSize(width: 1080, height: 1350)
        let fit = try XCTUnwrap(CanvasFit(canvasSize: canvas, viewportSize: CanvasSize(width: 375, height: 600)))
        let point = CanvasPoint(x: 540, y: 675)
        let roundTripped = fit.canvasPoint(fit.screenPoint(point))
        XCTAssertEqual(roundTripped.x, point.x, accuracy: 0.0001)
        XCTAssertEqual(roundTripped.y, point.y, accuracy: 0.0001)

        // Rotating the device only produces a different mapping.
        let rotated = try XCTUnwrap(CanvasFit(canvasSize: canvas, viewportSize: CanvasSize(width: 600, height: 375)))
        XCTAssertNotEqual(fit.scale, rotated.scale)
        XCTAssertEqual(rotated.canvasPoint(rotated.screenPoint(point)).x, point.x, accuracy: 0.0001)
    }

    func testCombinedGestureComposesAllThreeComponentsFromOneSnapshot() throws {
        let start = LayerTransform(translationX: 100, translationY: 200, scale: 1, rotationRadians: 0)
        let composed = try XCTUnwrap(
            CanvasGeometry.composedTransform(
                from: start,
                canvasTranslation: CanvasPoint(x: 30, y: -40),
                magnification: 2,
                rotationDelta: .pi / 2,
                canvasSize: CanvasSize.portrait4x5
            )
        )
        XCTAssertEqual(composed.translationX, 130, accuracy: 0.0001)
        XCTAssertEqual(composed.translationY, 160, accuracy: 0.0001)
        XCTAssertEqual(composed.scale, 2, accuracy: 0.0001)
        XCTAssertEqual(composed.rotationRadians, .pi / 2, accuracy: 0.0001)

        // Bad input never produces a value to commit.
        XCTAssertNil(CanvasGeometry.composedTransform(from: start, canvasTranslation: CanvasPoint(x: .nan, y: 0), magnification: 1, rotationDelta: 0, canvasSize: .portrait4x5))
        XCTAssertNil(CanvasGeometry.composedTransform(from: start, canvasTranslation: CanvasPoint(x: 0, y: 0), magnification: 0, rotationDelta: 0, canvasSize: .portrait4x5))
    }

    func testEditingRangeClampsAndNormalises() throws {
        let clamped = try XCTUnwrap(
            CanvasGeometry.clampedForEditing(
                LayerTransform(translationX: -50, translationY: 5000, scale: 99, rotationRadians: 7 * .pi),
                canvasSize: CanvasSize(width: 1080, height: 1350)
            )
        )
        XCTAssertEqual(clamped.translationX, 0)
        XCTAssertEqual(clamped.translationY, 1350)
        XCTAssertEqual(clamped.scale, CanvasGeometry.maximumScale)
        XCTAssertGreaterThanOrEqual(clamped.rotationRadians, -.pi)
        XCTAssertLessThan(clamped.rotationRadians, .pi)
    }

    func testOrderingIsStableWithExtremeZIndex() {
        let low = Layer(zIndex: Int.min)
        let middleA = Layer(zIndex: 0)
        let middleB = Layer(zIndex: 0)
        let high = Layer(zIndex: Int.max)
        let ordered = CanvasGeometry.orderedBackToFront([middleA, high, low, middleB])
        XCTAssertEqual(ordered.map(\.id), [low.id, middleA.id, middleB.id, high.id])
    }

    func testHitTestSelectsTopmostVisibleLayerAndKeepsLockedSelectable() throws {
        let hidden = Layer(transform: LayerTransform(translationX: 500, translationY: 500), zIndex: 3, isHidden: true, assetID: UUID(), baseSize: CanvasSize(width: 200, height: 200))
        let locked = Layer(transform: LayerTransform(translationX: 500, translationY: 500), zIndex: 2, isLocked: true, assetID: UUID(), baseSize: CanvasSize(width: 200, height: 200))
        let top = Layer(transform: LayerTransform(translationX: 500, translationY: 500), zIndex: 1, assetID: UUID(), baseSize: CanvasSize(width: 200, height: 200))
        let layers = [locked, top, hidden]
        let hit = CanvasGeometry.hitTest(CanvasPoint(x: 500, y: 500), in: layers)
        XCTAssertEqual(hit?.id, locked.id)
        XCTAssertNil(CanvasGeometry.hitTest(CanvasPoint(x: 5000, y: 5000), in: layers))
    }

    func testRotatedHitTestFollowsTheLayerRotation() {
        let layer = Layer(
            transform: LayerTransform(translationX: 100, translationY: 100, rotationRadians: .pi / 2),
            assetID: UUID(),
            baseSize: CanvasSize(width: 200, height: 40)
        )
        // After a quarter turn the long axis is vertical.
        XCTAssertTrue(CanvasGeometry.contains(CanvasPoint(x: 100, y: 180), layer: layer))
        XCTAssertFalse(CanvasGeometry.contains(CanvasPoint(x: 180, y: 100), layer: layer))
    }

    func testDragKeepsListSelectedLayerUnderLockedOrUnlockedOverlap() {
        let lower = Layer(transform: LayerTransform(translationX: 500, translationY: 500), zIndex: 0,
                          assetID: UUID(), baseSize: CanvasSize(width: 200, height: 200))
        var upper = Layer(transform: lower.transform, zIndex: 1, isLocked: true,
                          assetID: UUID(), baseSize: CanvasSize(width: 200, height: 200))
        let point = CanvasPoint(x: 500, y: 500)
        XCTAssertEqual(CanvasGeometry.hitTest(point, in: [lower, upper])?.id, upper.id)
        XCTAssertEqual(CanvasGeometry.dragTarget(point, selectedLayerID: lower.id, in: [lower, upper])?.id, lower.id)
        XCTAssertNil(CanvasGeometry.dragTarget(point, selectedLayerID: nil, in: [lower, upper]))
        upper.isLocked = false
        XCTAssertEqual(CanvasGeometry.dragTarget(point, selectedLayerID: lower.id, in: [lower, upper])?.id, lower.id)
        XCTAssertEqual(CanvasGeometry.dragTarget(point, selectedLayerID: nil, in: [lower, upper])?.id, upper.id)
    }

    func testDragNeverMovesLockedOrHiddenSelectionAndUsesRotatedBounds() {
        let lower = Layer(transform: LayerTransform(translationX: 100, translationY: 100), zIndex: 0,
                          assetID: UUID(), baseSize: CanvasSize(width: 200, height: 200))
        var selected = Layer(transform: LayerTransform(translationX: 100, translationY: 100, rotationRadians: .pi / 2),
                             zIndex: 1, isLocked: true, assetID: UUID(), baseSize: CanvasSize(width: 200, height: 40))
        let inside = CanvasPoint(x: 100, y: 180)
        XCTAssertNil(CanvasGeometry.dragTarget(inside, selectedLayerID: selected.id, in: [lower, selected]))
        selected.isLocked = false
        XCTAssertEqual(CanvasGeometry.dragTarget(inside, selectedLayerID: selected.id, in: [lower, selected])?.id, selected.id)
        let outside = CanvasPoint(x: 180, y: 100)
        XCTAssertEqual(CanvasGeometry.dragTarget(outside, selectedLayerID: selected.id, in: [lower, selected])?.id, lower.id)
        selected.isHidden = true
        XCTAssertEqual(CanvasGeometry.dragTarget(inside, selectedLayerID: selected.id, in: [lower, selected])?.id, lower.id)
        XCTAssertNil(CanvasGeometry.dragTarget(CanvasPoint(x: 5000, y: 5000), selectedLayerID: lower.id, in: [lower, selected]))
    }

    // MARK: - Document operations

    func testBoundLayerRoundTripsAllKeysWithoutChangingIdentityOrFlags() throws {
        let layer = Layer(
            transform: LayerTransform(translationX: 123.5, translationY: 456.25, scale: 2.5, rotationRadians: 0.75),
            opacity: 0.4, zIndex: -900, isLocked: true, isHidden: true,
            assetID: UUID(), baseSize: CanvasSize(width: 100, height: 160)
        )
        let data = try JSONEncoder().encode(layer)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["id", "kind", "transform", "opacity", "zIndex", "isLocked", "isHidden", "assetID", "baseSize"])
        XCTAssertEqual(try JSONDecoder().decode(Layer.self, from: data), layer)
    }

    func testEXIFQuarterTurnsUseDisplaySizeForInsertion() throws {
        let canvas = CanvasSize.portrait4x5
        for orientation in 1...8 {
            let photo = ImportedPhoto(
                asset: Asset(localReference: "unused"), thumbnailReference: "unused", previewReference: "unused",
                pixelWidth: 320, pixelHeight: 240, orientation: orientation, contentType: "public.jpeg"
            )
            let display = photo.displayPixelSize
            let fitted = try XCTUnwrap(CanvasGeometry.fittedBaseSize(displayWidth: display.width, displayHeight: display.height, canvasSize: canvas))
            if orientation >= 5 {
                XCTAssertEqual(display.width, 240)
                XCTAssertEqual(display.height, 320)
                XCTAssertEqual(fitted.width, 759.375, accuracy: 0.0001)
                XCTAssertEqual(fitted.height, 1012.5, accuracy: 0.0001)
            } else {
                XCTAssertEqual(fitted.width, 810, accuracy: 0.0001)
                XCTAssertEqual(fitted.height, 607.5, accuracy: 0.0001)
            }
        }
    }

    func testAddingAboveExtremeAndTiedZIndexesNormalizesWithoutOverflow() throws {
        let firstTop = Layer(zIndex: Int.max)
        let bottom = Layer(zIndex: Int.min)
        let laterTop = Layer(zIndex: Int.max)
        let document = CanvasDocument(layers: [firstTop, bottom, laterTop])
        let newID = UUID()
        let added = try CanvasEditor.addingLayer(assetID: UUID(), baseSize: CanvasSize(width: 100, height: 100), to: document, layerID: newID)
        XCTAssertEqual(CanvasGeometry.orderedBackToFront(added.layers).map(\.id), [bottom.id, firstTop.id, laterTop.id, newID])
        XCTAssertEqual(added.layers.map(\.zIndex).sorted(), [0, 1, 2, 3])
        XCTAssertEqual(document.layers.map(\.zIndex), [Int.max, Int.min, Int.max])
    }

    func testInvalidAndOverflowingGestureValuesNeverBecomeSavableTransforms() {
        let canvas = CanvasSize.portrait4x5
        for scale in [0.0, -1, .nan, .infinity] {
            XCTAssertNil(CanvasGeometry.clampedForEditing(LayerTransform(scale: scale), canvasSize: canvas))
        }
        let huge = Double.greatestFiniteMagnitude
        XCTAssertNil(CanvasGeometry.composedTransform(from: LayerTransform(translationX: huge), canvasTranslation: CanvasPoint(x: huge, y: 0), magnification: 1, rotationDelta: 0, canvasSize: canvas))
        XCTAssertNil(CanvasGeometry.composedTransform(from: LayerTransform(rotationRadians: huge), canvasTranslation: CanvasPoint(x: 0, y: 0), magnification: 1, rotationDelta: huge, canvasSize: canvas))
        XCTAssertNil(CanvasGeometry.composedTransform(from: LayerTransform(scale: huge), canvasTranslation: CanvasPoint(x: 0, y: 0), magnification: 2, rotationDelta: 0, canvasSize: canvas))
        let invalidCanvas = CanvasSize(width: -1, height: 0)
        XCTAssertFalse(CanvasGeometry.isWithinEditRange(.identity, canvasSize: invalidCanvas))
        XCTAssertNil(CanvasGeometry.clampedForEditing(.identity, canvasSize: invalidCanvas))
    }

    func testHistoricalFiniteTransformsAreNotReclampedDuringDecode() throws {
        let layer = Layer(transform: LayerTransform(translationX: -50, translationY: 5000, scale: 99, rotationRadians: 7 * .pi))
        let restored = try JSONDecoder().decode(Layer.self, from: JSONEncoder().encode(layer))
        XCTAssertEqual(restored.transform, layer.transform)
        XCTAssertFalse(CanvasGeometry.isWithinEditRange(restored.transform, canvasSize: .portrait4x5))
    }

    func testLockedAssetCascadeKeepsUnrelatedLayerFields() throws {
        let removedAsset = UUID()
        let removed = Layer(zIndex: Int.max, isLocked: true, assetID: removedAsset, baseSize: CanvasSize(width: 10, height: 10))
        let kept = Layer(transform: LayerTransform(translationX: 111, translationY: 222, scale: 3, rotationRadians: 0.4), opacity: 0.6, zIndex: -10, isLocked: true, isHidden: true, assetID: UUID(), baseSize: CanvasSize(width: 30, height: 40))
        let updated = CanvasEditor.removingLayers(boundTo: removedAsset, from: CanvasDocument(layers: [removed, kept]))
        XCTAssertEqual(updated.layers.count, 1)
        var expected = kept
        expected.zIndex = 0
        XCTAssertEqual(updated.layers.first, expected)
    }

    func testAddingLayerCentresItAndPutsItOnTop() throws {
        let assetID = UUID()
        var document = CanvasDocument()
        document = try CanvasEditor.addingLayer(assetID: assetID, baseSize: CanvasSize(width: 100, height: 200), to: document)
        document = try CanvasEditor.addingLayer(assetID: assetID, baseSize: CanvasSize(width: 100, height: 200), to: document)

        XCTAssertEqual(document.layers.count, 2)
        XCTAssertEqual(document.layers[0].zIndex, 0)
        XCTAssertEqual(document.layers[1].zIndex, 1)
        for layer in document.layers {
            XCTAssertEqual(layer.transform.translationX, document.canvasSize.width / 2)
            XCTAssertEqual(layer.transform.translationY, document.canvasSize.height / 2)
            XCTAssertEqual(layer.transform.scale, 1)
            XCTAssertEqual(layer.transform.rotationRadians, 0)
            XCTAssertEqual(layer.assetID, assetID)
        }
        // The same asset can be added twice as independent layers.
        XCTAssertNotEqual(document.layers[0].id, document.layers[1].id)
    }

    func testAddingLayerHonoursTheLayerLimit() throws {
        var document = CanvasDocument()
        for _ in 0..<ProjectPackage.layerLimit {
            document = try CanvasEditor.addingLayer(assetID: UUID(), baseSize: CanvasSize(width: 10, height: 10), to: document)
        }
        XCTAssertThrowsError(
            try CanvasEditor.addingLayer(assetID: UUID(), baseSize: CanvasSize(width: 10, height: 10), to: document)
        ) { error in
            XCTAssertEqual(error as? CanvasEditError, .layerLimitReached(limit: ProjectPackage.layerLimit))
        }
    }

    func testTransformUpdateOnlyChangesTheTargetLayer() throws {
        var document = CanvasDocument(layers: [Layer(zIndex: 0), Layer(zIndex: 1)])
        let untouchedID = document.layers[1].id
        let identity = document.layers[1].transform
        let newTransform = LayerTransform(translationX: 5, translationY: 6, scale: 2, rotationRadians: 0.1)
        document = try CanvasEditor.settingTransform(newTransform, forLayerID: document.layers[0].id, in: document)

        XCTAssertEqual(document.layers[0].transform, newTransform)
        XCTAssertEqual(document.layers[1].transform, identity)
        XCTAssertEqual(document.layers[1].id, untouchedID)
        XCTAssertEqual(document.layers[1].zIndex, 1)
    }

    func testResetRestoresInsertionTransform() throws {
        var document = try CanvasEditor.addingLayer(assetID: UUID(), baseSize: CanvasSize(width: 10, height: 10), to: CanvasDocument())
        let layerID = document.layers[0].id
        document = try CanvasEditor.settingTransform(
            LayerTransform(translationX: 1, translationY: 1, scale: 4, rotationRadians: 1),
            forLayerID: layerID,
            in: document
        )
        document = try CanvasEditor.resettingTransform(forLayerID: layerID, in: document)
        XCTAssertEqual(document.layers[0].transform.translationX, document.canvasSize.width / 2)
        XCTAssertEqual(document.layers[0].transform.translationY, document.canvasSize.height / 2)
        XCTAssertEqual(document.layers[0].transform.scale, 1)
        XCTAssertEqual(document.layers[0].transform.rotationRadians, 0)
    }

    func testRemovingLayerKeepsOtherLayersAndNormalisesZIndex() throws {
        let assetID = UUID()
        var document = try CanvasEditor.addingLayer(assetID: assetID, baseSize: CanvasSize(width: 10, height: 10), to: CanvasDocument())
        document = try CanvasEditor.addingLayer(assetID: assetID, baseSize: CanvasSize(width: 10, height: 10), to: document)
        document = try CanvasEditor.addingLayer(assetID: assetID, baseSize: CanvasSize(width: 10, height: 10), to: document)
        let keep1 = document.layers[0].id
        let remove = document.layers[1].id
        let keep2 = document.layers[2].id

        document = try CanvasEditor.removingLayer(layerID: remove, from: document)

        XCTAssertEqual(document.layers.map(\.id), [keep1, keep2])
        XCTAssertEqual(document.layers.map(\.zIndex), [0, 1])
        XCTAssertEqual(document.layers[0].assetID, assetID)
    }

    func testRemovingAssetRemovesOnlyItsLayers() throws {
        let removedAsset = UUID()
        let keptAsset = UUID()
        var document = try CanvasEditor.addingLayer(assetID: removedAsset, baseSize: CanvasSize(width: 10, height: 10), to: CanvasDocument())
        document = try CanvasEditor.addingLayer(assetID: keptAsset, baseSize: CanvasSize(width: 10, height: 10), to: document)
        let keptID = document.layers[1].id

        let updated = CanvasEditor.removingLayers(boundTo: removedAsset, from: document)

        XCTAssertEqual(updated.layers.map(\.id), [keptID])
        XCTAssertEqual(updated.layers[0].assetID, keptAsset)
    }

    func testReorderSwapsVisualNeighboursAndKeepsIdentity() throws {
        var document = try CanvasEditor.addingLayer(assetID: UUID(), baseSize: CanvasSize(width: 10, height: 10), to: CanvasDocument())
        document = try CanvasEditor.addingLayer(assetID: UUID(), baseSize: CanvasSize(width: 10, height: 10), to: document)
        let bottom = document.layers[0].id
        let top = document.layers[1].id

        document = try CanvasEditor.bringingForward(layerID: bottom, in: document)
        XCTAssertEqual(CanvasGeometry.orderedBackToFront(document.layers).map(\.id), [top, bottom])
        XCTAssertEqual(document.layers.map(\.zIndex).sorted(), [0, 1])

        document = try CanvasEditor.sendingBackward(layerID: bottom, in: document)
        XCTAssertEqual(CanvasGeometry.orderedBackToFront(document.layers).map(\.id), [bottom, top])

        // The top layer cannot move further forward.
        let unchanged = try CanvasEditor.bringingForward(layerID: top, in: document)
        XCTAssertEqual(unchanged.layers.map(\.id), document.layers.map(\.id))
    }

    func testLockedLayerRejectsTransformReorderAndRemovalButAllowsUnlockAndHide() throws {
        var document = try CanvasEditor.addingLayer(assetID: UUID(), baseSize: CanvasSize(width: 10, height: 10), to: CanvasDocument())
        document = try CanvasEditor.addingLayer(assetID: UUID(), baseSize: CanvasSize(width: 10, height: 10), to: document)
        let layerID = document.layers[0].id
        document = try CanvasEditor.settingLocked(true, forLayerID: layerID, in: document)

        XCTAssertThrowsError(try CanvasEditor.settingTransform(.identity, forLayerID: layerID, in: document))
        XCTAssertThrowsError(try CanvasEditor.resettingTransform(forLayerID: layerID, in: document))
        XCTAssertThrowsError(try CanvasEditor.removingLayer(layerID: layerID, from: document))
        XCTAssertThrowsError(try CanvasEditor.bringingForward(layerID: layerID, in: document))

        document = try CanvasEditor.settingHidden(true, forLayerID: layerID, in: document)
        XCTAssertTrue(document.layers[0].isHidden)
        document = try CanvasEditor.settingLocked(false, forLayerID: layerID, in: document)
        XCTAssertFalse(document.layers[0].isLocked)
    }
}

private extension ProjectPackage {
    /// Test helper: replaces the document while keeping the package shape valid.
    func withDocument(_ document: CanvasDocument) -> ProjectPackage {
        var project = self.project
        project.document = document
        return ProjectPackage(project: project, photos: photos)
    }
}
