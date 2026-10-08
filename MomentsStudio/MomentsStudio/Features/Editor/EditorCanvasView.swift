import CoreGraphics
import SwiftUI

/// The editable Stage 03 canvas.
///
/// Structure follows the approved architecture:
/// - the canvas is an independent gesture area (never inside a vertical scroll
///   view, so single-finger drags reach it);
/// - one continuous drag+magnify+rotate gesture composes **one** transform from a
///   single start snapshot and commits it **once** when the gesture ends, so the
///   three components can never overwrite each other;
/// - the gesture only builds a transient draft; the committed document is written
///   through the single mutation gate in `PhotoImportModel`;
/// - unselected layers load only their thumbnail, and at most the selected layer
///   loads the 2048px preview.
///
/// `@MainActor` is stated explicitly, consistent with the rest of the target.
@MainActor
struct EditorCanvasView: View {
    let projectID: UUID
    let document: CanvasDocument
    let photos: [ImportedPhoto]
    @Binding var selectedLayerID: UUID?
    let isEditingDisabled: Bool
    var reloadID: Int = 0

    @Environment(PhotoImportModel.self) private var photoImport
    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var gestureRecognized = false
    @State private var gestureFit: CanvasFit?

    /// Transient transform of the layer the finger is moving; never persisted
    /// directly and cleared when the gesture ends.
    @State private var draftTransform: LayerTransform?
    @State private var gestureStart: LayerTransform?
    @State private var gestureLayerID: UUID?
    /// The three gesture components are accumulated separately and recomposed from
    /// `gestureStart` on every change, so a drag, a pinch and a rotation that run
    /// at the same time cannot overwrite one another.
    @State private var gestureTranslation = CanvasPoint(x: 0, y: 0)
    @State private var gestureMagnification: Double = 1
    @State private var gestureRotation: Double = 0
    /// Identity of the gesture that holds the model's gate, so a late callback
    /// cannot commit or cancel a different gesture.
    @State private var gestureID: UUID?

    private var photosByAssetID: [UUID: ImportedPhoto] {
        Dictionary(uniqueKeysWithValues: photos.map { ($0.asset.id, $0) })
    }

    var body: some View {
        GeometryReader { proxy in
            let viewport = CanvasSize(
                width: max(1, proxy.size.width),
                height: max(1, proxy.size.height)
            )
            if let fit = CanvasFit(canvasSize: document.canvasSize, viewportSize: viewport) {
                canvas(fit: fit)
                    .onChange(of: fit) { _, _ in cancelGesture() }
            } else {
                Color.clear
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Canvas")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("editor.canvas")
        .onDisappear {
            // Leaving the screen (or an interruption) cancels the live gesture and
            // releases the model's gate immediately. Commits that already returned
            // are unaffected, so a finished save is never discarded.
            cancelGesture()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelGesture() }
        }
        .onChange(of: gestureRecognized) { _, recognized in
            // An interrupted recognizer may reset without delivering onEnded.
            // Let a normal end consume the local identity before cancelling it.
            guard !recognized, let id = gestureID else { return }
            Task { @MainActor in
                await Task.yield()
                if gestureID == id { cancelGesture() }
            }
        }
    }

    private var accessibilityValue: String {
        "\(document.layers.count) layers"
    }

    private func canvas(fit: CanvasFit) -> some View {
        ZStack {
            // The canvas surface is a real view so its bounds are obvious in both
            // light and dark mode, and so taps on empty space reach it.
            Rectangle()
                .fill(Color(.secondarySystemBackground))
                .overlay(Rectangle().stroke(Color.secondary.opacity(0.35), lineWidth: 1))
                .frame(
                    width: document.canvasSize.width * fit.scale,
                    height: document.canvasSize.height * fit.scale
                )
                .position(
                    x: fit.originX + document.canvasSize.width * fit.scale / 2,
                    y: fit.originY + document.canvasSize.height * fit.scale / 2
                )

            // Layer content is clipped to the **logical canvas**, so a photo dragged
            // past the canvas edge cannot be drawn into the letterbox area either.
            ZStack {
                ForEach(CanvasGeometry.orderedBackToFront(document.layers)) { layer in
                    if !layer.isHidden && layer.isBoundToAsset {
                        layerView(layer, fit: fit)
                    }
                }
            }
            .frame(
                width: document.canvasSize.width * fit.scale,
                height: document.canvasSize.height * fit.scale
            )
            .clipped()
            .position(
                x: fit.originX + document.canvasSize.width * fit.scale / 2,
                y: fit.originY + document.canvasSize.height * fit.scale / 2
            )

            if let selected = selectedLayer, !selected.isHidden, let rect = onScreenRect(of: selected, fit: fit) {
                selectionOutline(rect, rotation: draftTransform(for: selected).rotationRadians)
            }
        }
        .frame(width: fit.viewportSize.width, height: fit.viewportSize.height, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
        .gesture(canvasGesture(fit: fit))
        .simultaneousGesture(selectionTap(fit: fit))
        .accessibilityIdentifier("editor.canvasSurface")
    }

    private var selectedLayer: Layer? {
        guard let selectedLayerID else { return nil }
        return document.layers.first { $0.id == selectedLayerID }
    }

    @ViewBuilder
    private func layerView(_ layer: Layer, fit: CanvasFit) -> some View {
        let transform = draftTransform(for: layer)
        let isSelected = layer.id == selectedLayerID
        let reference = reference(for: layer, usePreview: isSelected)
        let width = max(1, (layer.baseSize?.width ?? 1) * transform.scale * fit.scale)
        let height = max(1, (layer.baseSize?.height ?? 1) * transform.scale * fit.scale)
        // This view sits inside the already-positioned logical canvas. Applying
        // the viewport origin here again would shift every letterboxed layer.
        let centre = CanvasPoint(x: transform.translationX * fit.scale, y: transform.translationY * fit.scale)
        // Valid archives can contain very large finite historical transforms;
        // their projection must not send an infinite frame to SwiftUI.
        if width.isFinite, height.isFinite, centre.x.isFinite, centre.y.isFinite {
          DerivedImageView(reference: reference, contentMode: .fit, reloadID: isSelected ? reloadID : 0) { reference in
            await photoImport.loadImage(reference: reference)
        } placeholder: {
            Color.secondary.opacity(0.15)
        }
        .frame(width: width, height: height)
        .opacity(layer.opacity)
        .rotationEffect(.radians(transform.rotationRadians))
        .position(x: centre.x, y: centre.y)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(layerAccessibilityLabel(layer))
        .accessibilityIdentifier("editor.layer.\(layer.id.uuidString)")
        .allowsHitTesting(false)
        }
    }

    private func layerAccessibilityLabel(_ layer: Layer) -> String {
        guard let index = CanvasGeometry.orderedBackToFront(document.layers).firstIndex(where: { $0.id == layer.id }) else {
            return "Layer"
        }
        var parts = ["Layer \(index + 1)"]
        if layer.id == selectedLayerID { parts.append("selected") }
        if layer.isLocked { parts.append("locked") }
        if layer.isHidden { parts.append("hidden") }
        if !layer.isBoundToAsset { parts.append("unavailable photo") }
        return parts.joined(separator: ", ")
    }

    private func reference(for layer: Layer, usePreview: Bool) -> String {
        guard let assetID = layer.assetID, let photo = photosByAssetID[assetID] else { return "" }
        return usePreview ? photo.previewReference : photo.thumbnailReference
    }

    private func draftTransform(for layer: Layer) -> LayerTransform {
        if let draftTransform, gestureLayerID == layer.id { return draftTransform }
        if let failed = photoImport.failedDraft(for: projectID), failed.layerID == layer.id,
           case .transform(let transform) = failed.intent,
           let clamped = CanvasGeometry.clampedForEditing(transform, canvasSize: document.canvasSize) {
            return clamped
        }
        return layer.transform
    }

    private func onScreenRect(of layer: Layer, fit: CanvasFit) -> CanvasRect? {
        guard let baseSize = layer.baseSize, layer.isBoundToAsset else { return nil }
        let transform = draftTransform(for: layer)
        let width = baseSize.width * transform.scale * fit.scale
        let height = baseSize.height * transform.scale * fit.scale
        let center = fit.screenPoint(CanvasPoint(x: transform.translationX, y: transform.translationY))
        guard width.isFinite, height.isFinite, width > 0, height > 0,
              center.x.isFinite, center.y.isFinite else { return nil }
        return CanvasRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    private func selectionOutline(_ rect: CanvasRect, rotation: Double) -> some View {
        Rectangle()
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(width: max(1, rect.width), height: max(1, rect.height))
            .rotationEffect(.radians(rotation))
            .position(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Gestures

    /// One combined gesture with a **single** end handler: the three components only
    /// record their own values while the gesture is live, so a component that
    /// finishes early can never clear the snapshot or drop another component's final
    /// value. The end handler composes the final transform once and commits once.
    private func canvasGesture(fit: CanvasFit) -> some Gesture {
        let drag = DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                if gestureStart == nil {
                    guard !isEditingDisabled else { return }
                    let point = fit.canvasPoint(CanvasPoint(x: value.startLocation.x, y: value.startLocation.y))
                    guard point.x >= 0, point.y >= 0,
                          point.x <= document.canvasSize.width, point.y <= document.canvasSize.height,
                          let touched = CanvasGeometry.hitTest(point, in: document.layers) else { return }
                    selectedLayerID = touched.id
                }
                gestureTranslation = CanvasPoint(x: value.translation.width, y: value.translation.height)
                recomposeDraft(fit: fit)
            }

        let magnify = MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                gestureMagnification = value.magnification
                recomposeDraft(fit: fit)
            }

        let rotate = RotateGesture(minimumAngleDelta: .degrees(1))
            .onChanged { value in
                gestureRotation = value.rotation.radians
                recomposeDraft(fit: fit)
            }

        return drag
            .simultaneously(with: magnify.simultaneously(with: rotate))
            .updating($gestureRecognized) { _, state, _ in state = true }
            .onEnded { value in
                if let finalDrag = value.first {
                    gestureTranslation = CanvasPoint(x: finalDrag.translation.width, y: finalDrag.translation.height)
                }
                if let finalMagnify = value.second?.first { gestureMagnification = finalMagnify.magnification }
                if let finalRotate = value.second?.second { gestureRotation = finalRotate.rotation.radians }
                commitDraft(fit: fit)
            }
    }

    /// Selection lives outside the transform gesture so a tap never moves a layer.
    private func selectionTap(fit: CanvasFit) -> some Gesture {
        SpatialTapGesture(coordinateSpace: .local)
            .onEnded { value in
                guard !photoImport.isBusy else { return }
                let point = fit.canvasPoint(CanvasPoint(x: value.location.x, y: value.location.y))
                guard point.x >= 0, point.y >= 0,
                      point.x <= document.canvasSize.width, point.y <= document.canvasSize.height else {
                    selectedLayerID = nil
                    return
                }
                selectedLayerID = CanvasGeometry.hitTest(point, in: document.layers)?.id
            }
    }

    /// Recomposes the draft from the start snapshot plus the three accumulated
    /// components. The gesture starts on the current selection when it is editable,
    /// otherwise on the topmost layer; a locked layer is never transformed.
    private func recomposeDraft(fit: CanvasFit) {
        if gestureStart == nil {
            guard !isEditingDisabled else { return }
            guard let startLayer = gestureStartLayer() else { return }
            // Hidden and unbound layers can be selected in the list, but a canvas
            // gesture must never transform them.
            guard !startLayer.isHidden, startLayer.isBoundToAsset, !startLayer.isLocked else { return }
            // The model owns the gate: it refuses while other work is in flight.
            guard let id = photoImport.beginCanvasGesture(projectID: projectID) else { return }
            gestureID = id
            gestureFit = fit
            gestureLayerID = startLayer.id
            gestureStart = startLayer.transform
            selectedLayerID = startLayer.id
        }
        guard let start = gestureStart, let layerID = gestureLayerID else { return }
        guard let layer = document.layers.first(where: { $0.id == layerID }), !layer.isLocked else { return }
        guard let composed = CanvasGeometry.composedTransform(
            from: start,
            canvasTranslation: (gestureFit ?? fit).canvasDelta(gestureTranslation),
            magnification: gestureMagnification,
            rotationDelta: gestureRotation,
            canvasSize: document.canvasSize
        ) else { return }
        draftTransform = CanvasGeometry.clampedForEditing(composed, canvasSize: document.canvasSize)
    }

    /// The layer a gesture starts on: the current selection. A locked selection is
    /// refused by `recomposeDraft`, so a locked layer stays selectable but immovable.
    private func gestureStartLayer() -> Layer? {
        selectedLayer
    }

    /// Exactly one commit, from the values this gesture actually ended with.
    private func commitDraft(fit: CanvasFit) {
        guard let id = gestureID,
              let layerID = gestureLayerID,
              let start = gestureStart else {
            cancelGesture()
            return
        }
        let finalTransform = CanvasGeometry.composedTransform(
            from: start,
            canvasTranslation: (gestureFit ?? fit).canvasDelta(gestureTranslation),
            magnification: gestureMagnification,
            rotationDelta: gestureRotation,
            canvasSize: document.canvasSize
        ) ?? draftTransform
        clearGestureState()
        guard let transform = finalTransform else {
            photoImport.cancelCanvasGesture(id: id)
            return
        }
        Task {
            await photoImport.commitCanvasGesture(id: id, projectID: projectID, layerID: layerID, transform: transform)
        }
    }

    /// Cancels without committing: used when the view disappears or is interrupted.
    private func cancelGesture() {
        guard let id = gestureID else { return }
        clearGestureState()
        photoImport.cancelCanvasGesture(id: id)
    }

    private func clearGestureState() {
        gestureStart = nil
        gestureLayerID = nil
        gestureID = nil
        gestureFit = nil
        draftTransform = nil
        gestureTranslation = CanvasPoint(x: 0, y: 0)
        gestureMagnification = 1
        gestureRotation = 0
    }
}
