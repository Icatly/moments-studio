import Foundation

/// Pure canvas geometry and document operations for Stage 03.
///
/// Everything here is a value function on the serializable models: no SwiftUI, no
/// UIKit, no file or image access. The canvas view and the edit coordinator both
/// call into it, and it can be unit tested in isolation.
///
/// Coordinate contract (approved in `docs/architecture/STAGE-03-EDITABLE-CANVAS-LAYERS.md`):
/// `LayerTransform.translationX/Y` is the **layer centre in canvas units, relative
/// to the canvas top-left corner** — not a screen point and not an accumulated
/// gesture offset. `scale` multiplies `Layer.baseSize`, and `rotationRadians`
/// rotates around that centre.

/// A rectangle in canvas units (Doubles keep the geometry platform independent).
struct CanvasRect: Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var centerX: Double { x + width / 2 }
    var centerY: Double { y + height / 2 }
}

/// A point in canvas units.
struct CanvasPoint: Equatable {
    var x: Double
    var y: Double
}

/// Errors the pure document operations can report. They never mutate the input.
enum CanvasEditError: Error, Equatable {
    case layerLimitReached(limit: Int)
    case layerNotFound(UUID)
    case layerIsLocked(UUID)
    case unusableTransform(LayerTransform)
    case unusableBaseSize(CanvasSize)
    case assetAlreadyMissing(UUID)
}

/// The canvas-to-viewport mapping. Changing the viewport or rotating the device
/// only produces a different value here; it never touches the document.
struct CanvasFit: Equatable {
    let canvasSize: CanvasSize
    let viewportSize: CanvasSize
    let scale: Double
    let originX: Double
    let originY: Double

    /// Equal-aspect fit of the canvas inside the viewport, centred.
    init?(canvasSize: CanvasSize, viewportSize: CanvasSize) {
        guard canvasSize.width.isFinite, canvasSize.height.isFinite,
              canvasSize.width > 0, canvasSize.height > 0,
              viewportSize.width.isFinite, viewportSize.height.isFinite,
              viewportSize.width > 0, viewportSize.height > 0 else { return nil }
        let scale = min(viewportSize.width / canvasSize.width, viewportSize.height / canvasSize.height)
        guard scale.isFinite, scale > 0 else { return nil }
        self.canvasSize = canvasSize
        self.viewportSize = viewportSize
        self.scale = scale
        self.originX = (viewportSize.width - canvasSize.width * scale) / 2
        self.originY = (viewportSize.height - canvasSize.height * scale) / 2
    }

    /// Canvas units → viewport points (`viewportOrigin + canvasPoint × fitScale`).
    func screenPoint(_ point: CanvasPoint) -> CanvasPoint {
        CanvasPoint(x: originX + point.x * scale, y: originY + point.y * scale)
    }

    /// Viewport points → canvas units (inverse of `screenPoint`).
    func canvasPoint(_ point: CanvasPoint) -> CanvasPoint {
        CanvasPoint(x: (point.x - originX) / scale, y: (point.y - originY) / scale)
    }

    /// A screen delta expressed in canvas units, used so dragging feels identical
    /// at every fit scale.
    func canvasDelta(_ delta: CanvasPoint) -> CanvasPoint {
        CanvasPoint(x: delta.x / scale, y: delta.y / scale)
    }
}

enum CanvasGeometry {
    /// Fraction of the canvas each new layer fills, per axis.
    static let insertionFillFraction: Double = 0.75

    /// Editing range for a committed transform's centre and scale.
    static let minimumScale: Double = 0.1
    static let maximumScale: Double = 8

    /// Base size for a newly added layer.
    ///
    /// The photo is fitted proportionally inside a box that is 75% of the canvas
    /// width and height (so the original is never cropped or stretched), using the
    /// EXIF-corrected display size.
    static func fittedBaseSize(
        displayWidth: Int,
        displayHeight: Int,
        canvasSize: CanvasSize
    ) -> CanvasSize? {
        guard displayWidth > 0, displayHeight > 0,
              canvasSize.width.isFinite, canvasSize.height.isFinite,
              canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let boxWidth = canvasSize.width * insertionFillFraction
        let boxHeight = canvasSize.height * insertionFillFraction
        let ratio = min(boxWidth / Double(displayWidth), boxHeight / Double(displayHeight))
        guard ratio.isFinite, ratio > 0 else { return nil }
        return CanvasSize(width: Double(displayWidth) * ratio, height: Double(displayHeight) * ratio)
    }

    /// The four rotated corners of a bound layer, in canvas units.
    static func corners(of layer: Layer) -> [CanvasPoint]? {
        guard let baseSize = layer.baseSize, layer.isBoundToAsset,
              baseSize.width > 0, baseSize.height > 0 else { return nil }
        let halfWidth = baseSize.width * layer.transform.scale / 2
        let halfHeight = baseSize.height * layer.transform.scale / 2
        let cosine = cos(layer.transform.rotationRadians)
        let sine = sin(layer.transform.rotationRadians)
        let centre = CanvasPoint(x: layer.transform.translationX, y: layer.transform.translationY)
        return [(-halfWidth, -halfHeight), (halfWidth, -halfHeight), (halfWidth, halfHeight), (-halfWidth, halfHeight)]
            .map { corner in
                CanvasPoint(
                    x: centre.x + corner.0 * cosine - corner.1 * sine,
                    y: centre.y + corner.0 * sine + corner.1 * cosine
                )
            }
    }

    /// Axis-aligned bounding box of a layer's rotated rect.
    static func boundingRect(of layer: Layer) -> CanvasRect? {
        guard let corners = corners(of: layer) else { return nil }
        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
        return CanvasRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Rotation-aware hit test against the layer's own (un-rotated) rectangle.
    static func contains(_ point: CanvasPoint, layer: Layer) -> Bool {
        guard let baseSize = layer.baseSize, layer.isBoundToAsset,
              baseSize.width > 0, baseSize.height > 0, layer.transform.scale > 0 else { return false }
        let dx = point.x - layer.transform.translationX
        let dy = point.y - layer.transform.translationY
        let cosine = cos(-layer.transform.rotationRadians)
        let sine = sin(-layer.transform.rotationRadians)
        let localX = dx * cosine - dy * sine
        let localY = dx * sine + dy * cosine
        return abs(localX) <= baseSize.width * layer.transform.scale / 2
            && abs(localY) <= baseSize.height * layer.transform.scale / 2
    }

    /// Back-to-front order: larger `zIndex` first, ties keep array order (a later
    /// element is nearer the viewer).
    static func orderedBackToFront(_ layers: [Layer]) -> [Layer] {
        layers.enumerated()
            .sorted { left, right in
                if left.element.zIndex != right.element.zIndex { return left.element.zIndex < right.element.zIndex }
                return left.offset < right.offset
            }
            .map(\.element)
    }

    /// The layer a tap selects: the topmost visible layer whose rotated rectangle
    /// contains the point. Locked layers are still selectable (they simply cannot
    /// be transformed).
    static func hitTest(_ point: CanvasPoint, in layers: [Layer]) -> Layer? {
        orderedBackToFront(layers).last { !$0.isHidden && contains(point, layer: $0) }
    }

    /// A list-selected layer keeps the drag when the start lies within it, even
    /// under another photo. Taps still use `hitTest`; a locked target never moves.
    static func dragTarget(_ point: CanvasPoint, selectedLayerID: UUID?, in layers: [Layer]) -> Layer? {
        let target = layers.first {
            $0.id == selectedLayerID && !$0.isHidden && contains(point, layer: $0)
        } ?? hitTest(point, in: layers)
        guard let target, !target.isLocked else { return nil }
        return target
    }

    /// True when a transform is inside the Stage 03 editing range.
    static func isWithinEditRange(_ transform: LayerTransform, canvasSize: CanvasSize) -> Bool {
        guard canvasSize.width.isFinite, canvasSize.height.isFinite,
              canvasSize.width > 0, canvasSize.height > 0 else { return false }
        return transform.translationX.isFinite && transform.translationY.isFinite
            && transform.rotationRadians.isFinite
            && transform.scale.isFinite
            && (minimumScale...maximumScale).contains(transform.scale)
            && (0...canvasSize.width).contains(transform.translationX)
            && (0...canvasSize.height).contains(transform.translationY)
    }

    /// Normalises an angle into `[-π, π)`.
    static func normalizedRotation(_ radians: Double) -> Double {
        guard radians.isFinite else { return 0 }
        let twoPi = 2 * Double.pi
        var value = radians.truncatingRemainder(dividingBy: twoPi)
        if value < -Double.pi { value += twoPi }
        if value >= Double.pi { value -= twoPi }
        return value
    }

    /// Composes one continuous gesture from a single start snapshot.
    ///
    /// All three components are derived from `start` on every call, so a drag, a
    /// magnification and a rotation can never overwrite each other. Returns `nil`
    /// for input the document must not store (non-finite, or a non-positive
    /// magnification result).
    static func composedTransform(
        from start: LayerTransform,
        canvasTranslation: CanvasPoint,
        magnification: Double,
        rotationDelta: Double,
        canvasSize: CanvasSize
    ) -> LayerTransform? {
        guard start.translationX.isFinite, start.translationY.isFinite, start.rotationRadians.isFinite,
              start.scale.isFinite, start.scale > 0,
              canvasTranslation.x.isFinite, canvasTranslation.y.isFinite,
              magnification.isFinite, magnification > 0, rotationDelta.isFinite else { return nil }
        let scale = start.scale * magnification
        let x = start.translationX + canvasTranslation.x
        let y = start.translationY + canvasTranslation.y
        let rotation = start.rotationRadians + rotationDelta
        guard scale.isFinite, scale > 0, x.isFinite, y.isFinite, rotation.isFinite else { return nil }
        return LayerTransform(
            translationX: x,
            translationY: y,
            scale: scale,
            rotationRadians: normalizedRotation(rotation)
        )
    }

    /// Applies the Stage 03 interaction range to a committed change: centre is
    /// clamped to the canvas, scale to `[0.1, 8]`, rotation normalised.
    ///
    /// Historical documents are never re-clamped by decoding; this is only used
    /// when an interaction commits a change.
    static func clampedForEditing(_ transform: LayerTransform, canvasSize: CanvasSize) -> LayerTransform? {
        guard transform.translationX.isFinite, transform.translationY.isFinite,
              transform.rotationRadians.isFinite, transform.scale.isFinite, transform.scale > 0,
              canvasSize.width.isFinite, canvasSize.height.isFinite,
              canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        return LayerTransform(
            translationX: min(max(transform.translationX, 0), canvasSize.width),
            translationY: min(max(transform.translationY, 0), canvasSize.height),
            scale: min(max(transform.scale, minimumScale), maximumScale),
            rotationRadians: normalizedRotation(transform.rotationRadians)
        )
    }
}

/// Pure document operations: each returns a new document and never mutates the
/// committed one. Only the addressed field changes; project identity, assets and
/// all other layers are preserved.
enum CanvasEditor {
    /// Adds a new photo layer on top, respecting the layer limit.
    static func addingLayer(
        assetID: UUID,
        baseSize: CanvasSize,
        to document: CanvasDocument,
        layerID: UUID = UUID()
    ) throws -> CanvasDocument {
        guard document.layers.count < ProjectPackage.layerLimit else {
            throw CanvasEditError.layerLimitReached(limit: ProjectPackage.layerLimit)
        }
        guard baseSize.width.isFinite, baseSize.height.isFinite, baseSize.width > 0, baseSize.height > 0 else {
            throw CanvasEditError.unusableBaseSize(baseSize)
        }
        // Normalize first, so even an archived Int.max never needs arithmetic.
        // The layer count is bounded, and every existing visual order is kept.
        var updated = normalizedZIndex(document)
        let nextZIndex = updated.layers.count
        updated.layers.append(
            Layer(
                id: layerID,
                transform: LayerTransform(
                    translationX: document.canvasSize.width / 2,
                    translationY: document.canvasSize.height / 2
                ),
                zIndex: nextZIndex,
                assetID: assetID,
                baseSize: baseSize
            )
        )
        return updated
    }

    /// Replaces exactly one layer's transform.
    static func settingTransform(
        _ transform: LayerTransform,
        forLayerID layerID: UUID,
        in document: CanvasDocument
    ) throws -> CanvasDocument {
        guard transform.translationX.isFinite, transform.translationY.isFinite,
              transform.rotationRadians.isFinite,
              transform.scale.isFinite, transform.scale > 0 else {
            throw CanvasEditError.unusableTransform(transform)
        }
        return try updating(document, layerID: layerID) { layer in
            layer.transform = transform
        }
    }

    static func settingHidden(_ isHidden: Bool, forLayerID layerID: UUID, in document: CanvasDocument) throws -> CanvasDocument {
        // Hiding and showing stay available on a locked layer by design.
        try updating(document, layerID: layerID, allowingLocked: true) { layer in
            layer.isHidden = isHidden
        }
    }

    static func settingLocked(_ isLocked: Bool, forLayerID layerID: UUID, in document: CanvasDocument) throws -> CanvasDocument {
        try updating(document, layerID: layerID, allowingLocked: true) { layer in
            layer.isLocked = isLocked
        }
    }

    /// Resets a layer to the insertion transform (canvas centre, scale 1, no rotation).
    static func resettingTransform(forLayerID layerID: UUID, in document: CanvasDocument) throws -> CanvasDocument {
        try updating(document, layerID: layerID) { layer in
            layer.transform = LayerTransform(
                translationX: document.canvasSize.width / 2,
                translationY: document.canvasSize.height / 2
            )
        }
    }

    /// Removes a layer. The asset file is never touched here, and a locked layer is
    /// only removable through the asset cascade (deleting the photo it belongs to),
    /// which never leaves a package referencing a missing asset.
    static func removingLayer(layerID: UUID, from document: CanvasDocument) throws -> CanvasDocument {
        guard let layer = document.layers.first(where: { $0.id == layerID }) else {
            throw CanvasEditError.layerNotFound(layerID)
        }
        guard !layer.isLocked else { throw CanvasEditError.layerIsLocked(layerID) }
        var updated = document
        updated.layers.removeAll { $0.id == layerID }
        return normalizedZIndex(updated)
    }

    /// Removes every layer bound to an asset. Used when a photo is deleted, in the
    /// same manifest transaction.
    static func removingLayers(boundTo assetID: UUID, from document: CanvasDocument) -> CanvasDocument {
        var updated = document
        updated.layers.removeAll { $0.assetID == assetID }
        return normalizedZIndex(updated)
    }

    /// Moves a layer one step towards the viewer (visual neighbour swap).
    static func bringingForward(layerID: UUID, in document: CanvasDocument) throws -> CanvasDocument {
        try reordering(document, layerID: layerID, towardsFront: true)
    }

    /// Moves a layer one step away from the viewer.
    static func sendingBackward(layerID: UUID, in document: CanvasDocument) throws -> CanvasDocument {
        try reordering(document, layerID: layerID, towardsFront: false)
    }

    /// Rewrites `zIndex` as `0...n-1` in visual order, keeping layer identity and
    /// the on-screen order. Done after a reorder so the stored values stay small.
    static func normalizedZIndex(_ document: CanvasDocument) -> CanvasDocument {
        var updated = document
        let ordered = CanvasGeometry.orderedBackToFront(document.layers)
        var indexByID: [UUID: Int] = [:]
        for (index, layer) in ordered.enumerated() { indexByID[layer.id] = index }
        for index in updated.layers.indices {
            if let newIndex = indexByID[updated.layers[index].id] { updated.layers[index].zIndex = newIndex }
        }
        return updated
    }

    private static func reordering(_ document: CanvasDocument, layerID: UUID, towardsFront: Bool) throws -> CanvasDocument {
        let ordered = CanvasGeometry.orderedBackToFront(document.layers)
        guard let position = ordered.firstIndex(where: { $0.id == layerID }) else {
            throw CanvasEditError.layerNotFound(layerID)
        }
        guard !ordered[position].isLocked else { throw CanvasEditError.layerIsLocked(layerID) }
        let neighbour = towardsFront ? position + 1 : position - 1
        guard ordered.indices.contains(neighbour) else { return document }
        var swapped = ordered
        swapped.swapAt(position, neighbour)
        var updated = document
        for (index, layer) in swapped.enumerated() {
            if let storedIndex = updated.layers.firstIndex(where: { $0.id == layer.id }) {
                updated.layers[storedIndex].zIndex = index
            }
        }
        return normalizedZIndex(updated)
    }

    private static func updating(
        _ document: CanvasDocument,
        layerID: UUID,
        allowingLocked: Bool = false,
        _ change: (inout Layer) -> Void
    ) throws -> CanvasDocument {
        guard let index = document.layers.firstIndex(where: { $0.id == layerID }) else {
            throw CanvasEditError.layerNotFound(layerID)
        }
        guard allowingLocked || !document.layers[index].isLocked else {
            throw CanvasEditError.layerIsLocked(layerID)
        }
        var updated = document
        change(&updated.layers[index])
        return updated
    }
}
