import XCTest
@testable import MomentsStudio

final class Stage04LayoutTests: XCTestCase {
    private func photos(_ count: Int) -> [ImportedPhoto] {
        (0..<count).map { index in
            let size = [(1200, 800), (800, 1200), (1000, 1000), (1600, 900)][index % 4]
            return ImportedPhoto(
                asset: Asset(localReference: "original-\(index).jpg"),
                thumbnailReference: "thumb-\(index).jpg", previewReference: "preview-\(index).jpg",
                pixelWidth: size.0, pixelHeight: size.1, orientation: index % 4 == 3 ? 6 : 1,
                contentType: "public.jpeg"
            )
        }
    }

    private func existingDocument(_ photos: [ImportedPhoto]) throws -> CanvasDocument {
        var document = CanvasDocument.empty
        for photo in photos {
            let display = photo.displayPixelSize
            let base = try XCTUnwrap(CanvasGeometry.fittedBaseSize(
                displayWidth: display.width, displayHeight: display.height, canvasSize: document.canvasSize
            ))
            document = try CanvasEditor.addingLayer(assetID: photo.id, baseSize: base, to: document)
        }
        return document
    }

    func testThreePresetsAreDeterministicDistinctAndLeaveInputUntouched() throws {
        let photos = photos(4)
        let source = CanvasDocument.empty
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let sourceBytes = try encoder.encode(source)
        var results: [CanvasDocument] = []
        for preset in CollagePreset.allCases {
            let result = try CollageLayout.arrange(preset, document: source, photos: photos)
            XCTAssertEqual(result, try CollageLayout.arrange(preset, document: source, photos: photos))
            XCTAssertEqual(result.id, source.id)
            XCTAssertEqual(result.canvasSize, source.canvasSize)
            XCTAssertEqual(result.layers.map(\.assetID), photos.map { Optional($0.id) })
            results.append(result)
        }
        XCTAssertNotEqual(results[0].layers.map(\.transform), results[1].layers.map(\.transform))
        XCTAssertNotEqual(results[0].layers.map(\.transform), results[2].layers.map(\.transform))
        XCTAssertNotEqual(results[1].layers.map(\.transform), results[2].layers.map(\.transform))
        XCTAssertEqual(try encoder.encode(source), sourceBytes)
        XCTAssertTrue(source.layers.isEmpty)
    }

    func testOneThroughTwentyMixedPhotosFitWithoutCroppingOrOverlap() throws {
        for count in 1...ProjectPackage.layerLimit {
            let photos = photos(count)
            for preset in CollagePreset.allCases {
                let document = try CollageLayout.arrange(preset, document: .empty, photos: photos)
                XCTAssertEqual(document.layers.count, count)
                var rects: [CanvasRect] = []
                for (index, layer) in document.layers.enumerated() {
                    let rect = try XCTUnwrap(CanvasGeometry.boundingRect(of: layer))
                    XCTAssertGreaterThanOrEqual(rect.x, -1e-8)
                    XCTAssertGreaterThanOrEqual(rect.y, -1e-8)
                    XCTAssertLessThanOrEqual(rect.x + rect.width, document.canvasSize.width + 1e-8)
                    XCTAssertLessThanOrEqual(rect.y + rect.height, document.canvasSize.height + 1e-8)
                    XCTAssertTrue(CanvasGeometry.isWithinEditRange(layer.transform, canvasSize: document.canvasSize))
                    let base = try XCTUnwrap(layer.baseSize)
                    let display = photos[index].displayPixelSize
                    XCTAssertEqual(base.width / base.height, Double(display.width) / Double(display.height), accuracy: 1e-10)
                    for previous in rects {
                        let separate = rect.x >= previous.x + previous.width - 1e-8
                            || previous.x >= rect.x + rect.width - 1e-8
                            || rect.y >= previous.y + previous.height - 1e-8
                            || previous.y >= rect.y + rect.height - 1e-8
                        XCTAssertTrue(separate, "\(preset) count=\(count) has overlapping generated photos")
                    }
                    rects.append(rect)
                }
            }
        }
    }

    func testExistingLayersKeepIdentityBaseSizeStackingAndProtectedValues() throws {
        let photos = photos(5)
        var source = try existingDocument(Array(photos.prefix(4)))
        source.layers[0].isLocked = true
        source.layers[0].transform = LayerTransform(translationX: 17, translationY: 23, scale: 2.2, rotationRadians: 0.6)
        source.layers[1].isHidden = true
        source.layers[1].setOpacity(0.4)
        source.layers[2].zIndex = Int.max
        source.layers[3].zIndex = Int.min
        source.layers[3].setOpacity(0.6)
        source.layers.append(Layer(transform: LayerTransform(translationX: 99, translationY: 88)))
        for preset in CollagePreset.allCases {
            let result = try CollageLayout.arrange(preset, document: source, photos: photos)
            XCTAssertEqual(result.layers.count, source.layers.count, "Unused library photos must not be added")
            XCTAssertEqual(result.layers[0], source.layers[0])
            XCTAssertEqual(result.layers[1], source.layers[1])
            XCTAssertEqual(result.layers[4], source.layers[4])
            XCTAssertEqual(result.layers.map(\.id), source.layers.map(\.id))
            XCTAssertEqual(result.layers.map(\.baseSize), source.layers.map(\.baseSize))
            XCTAssertEqual(result.layers.map(\.zIndex), source.layers.map(\.zIndex))
            XCTAssertEqual(result.layers.map(\.opacity), source.layers.map(\.opacity))
            XCTAssertEqual(result.layers.map(\.assetID), source.layers.map(\.assetID))
        }
    }

    func testApplyingAgainDoesNotDuplicateLayersAndIsIdempotent() throws {
        let photos = photos(6)
        for preset in CollagePreset.allCases {
            let first = try CollageLayout.arrange(preset, document: .empty, photos: photos)
            let second = try CollageLayout.arrange(preset, document: first, photos: photos)
            XCTAssertEqual(first, second)
            XCTAssertEqual(Set(second.layers.map(\.id)).count, photos.count)
        }
    }

    func testEXIFOrientationsPreserveDisplayedAspectRatio() throws {
        for orientation in ImportedPhoto.orientationRange {
            var photo = try XCTUnwrap(photos(1).first)
            photo.orientation = orientation
            for preset in CollagePreset.allCases {
                let result = try CollageLayout.arrange(preset, document: .empty, photos: [photo])
                let base = try XCTUnwrap(result.layers.first?.baseSize)
                let expected = (5...8).contains(orientation) ? 2.0 / 3.0 : 3.0 / 2.0
                XCTAssertEqual(base.width / base.height, expected, accuracy: 1e-10)
            }
        }
    }

    func testEmptyAndProtectedOnlyCanvasesAreRejected() throws {
        XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: .empty, photos: [])) {
            XCTAssertEqual($0 as? CollageLayoutError, .noPhotos)
        }
        let photos = photos(2)
        var source = try existingDocument(photos)
        source.layers[0].isLocked = true
        source.layers[1].isHidden = true
        XCTAssertThrowsError(try CollageLayout.arrange(.focus, document: source, photos: photos)) {
            XCTAssertEqual($0 as? CollageLayoutError, .noEditableLayers)
        }
        XCTAssertTrue(source.layers[0].isLocked)
        XCTAssertTrue(source.layers[1].isHidden)
    }

    func testInvalidCanvasAndUnfitHistoricalGeometryDoNotGetClamped() throws {
        let photos = photos(1)
        for size in [CanvasSize(width: 0, height: 1), CanvasSize(width: .nan, height: 1350), CanvasSize(width: 1, height: .infinity)] {
            XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: CanvasDocument(canvasSize: size), photos: photos)) {
                XCTAssertEqual($0 as? CollageLayoutError, .invalidCanvas)
            }
        }
        var source = try existingDocument(photos)
        source.layers[0].baseSize = CanvasSize(width: 1e12, height: 1e12)
        for preset in CollagePreset.allCases {
            XCTAssertThrowsError(try CollageLayout.arrange(preset, document: source, photos: photos)) {
                XCTAssertEqual($0 as? CollageLayoutError, .cannotFit)
            }
        }
        XCTAssertEqual(source.layers[0].baseSize?.width, 1e12)
    }

    func testDuplicateAndMissingPhotoIdentitiesAreRejected() throws {
        let photos = photos(2)
        XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: .empty, photos: [photos[0], photos[0]])) {
            XCTAssertEqual($0 as? CollageLayoutError, .invalidPhoto(photos[0].id))
        }
        let source = try existingDocument(photos)
        XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: source, photos: [photos[0]])) {
            XCTAssertEqual($0 as? CollageLayoutError, .invalidPhoto(photos[1].id))
        }
        var duplicate = source
        duplicate.layers.append(source.layers[0])
        XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: duplicate, photos: photos)) {
            XCTAssertEqual($0 as? CollageLayoutError, .invalidLayers)
        }
        var partial = source
        partial.layers[0].baseSize = nil
        XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: partial, photos: photos)) {
            XCTAssertEqual($0 as? CollageLayoutError, .invalidLayers)
        }
    }

    func testInvalidPhotoMetadataAndOverLimitAreRejected() throws {
        var photo = try XCTUnwrap(photos(1).first)
        photo.orientation = 9
        XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: .empty, photos: [photo])) {
            XCTAssertEqual($0 as? CollageLayoutError, .invalidPhoto(photo.id))
        }
        photo.orientation = 1
        photo.pixelWidth = 0
        XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: .empty, photos: [photo])) {
            XCTAssertEqual($0 as? CollageLayoutError, .invalidPhoto(photo.id))
        }
        XCTAssertThrowsError(try CollageLayout.arrange(.grid, document: .empty, photos: photos(21))) {
            XCTAssertEqual($0 as? CollageLayoutError, .tooManyLayers)
        }
    }

    func testLayoutRoundTripsUsingExistingLayerDocumentContract() throws {
        let photos = photos(3)
        let source = try existingDocument(photos)
        let result = try CollageLayout.arrange(.offset, document: source, photos: photos)
        let bytes = try JSONEncoder().encode(result)
        XCTAssertEqual(try JSONDecoder().decode(CanvasDocument.self, from: bytes), result)
        let sourceJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
        let resultJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(Set(sourceJSON.keys), Set(resultJSON.keys))
        let sourceLayers = try XCTUnwrap(sourceJSON["layers"] as? [[String: Any]])
        let resultLayers = try XCTUnwrap(resultJSON["layers"] as? [[String: Any]])
        XCTAssertEqual(Set(sourceLayers[0].keys), Set(resultLayers[0].keys))
    }

    func testSearchHandlesCaseWhitespaceChineseAndNoMatch() {
        XCTAssertEqual(CollagePreset.allCases.filter { $0.matches("  ") }, CollagePreset.allCases)
        XCTAssertEqual(CollagePreset.allCases.filter { $0.matches(" FOCUS ") }, [.focus])
        XCTAssertEqual(CollagePreset.allCases.filter { $0.matches("错落") }, [.offset])
        XCTAssertTrue(CollagePreset.allCases.filter { $0.matches("unavailable style") }.isEmpty)
    }
}
