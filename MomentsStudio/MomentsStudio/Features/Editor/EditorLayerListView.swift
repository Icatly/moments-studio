import SwiftUI

/// Gesture-free editing alternatives; all writes use retryable coordinator intents.
@MainActor
struct EditorLayerListView: View {
    let projectID: UUID
    let document: CanvasDocument
    let photos: [ImportedPhoto]
    @Binding var selectedLayerID: UUID?
    let isEditingDisabled: Bool
    let reloadSelectedPhoto: () -> Void

    @Environment(PhotoImportModel.self) private var photoImport
    @Environment(ProjectStore.self) private var projectStore

    private var selectedLayer: Layer? { document.layers.first { $0.id == selectedLayerID } }
    private var blocked: Bool {
        isEditingDisabled || photoImport.isBusy || photoImport.failedDraft(for: projectID) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Layers").font(Typography.sectionTitle)
            Text("\(document.layers.count) of \(ProjectPackage.layerLimit) layers")
                .font(Typography.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("editor.layerCount")
            addToCanvas
            if document.layers.isEmpty {
                Text("The canvas is empty. Add a photo to start.")
                    .font(Typography.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(CanvasGeometry.orderedBackToFront(document.layers).reversed())) { layer in
                layerRow(layer)
                Divider()
            }
            if let layer = selectedLayer { controls(for: layer) }
            if photoImport.isSavingEdits {
                Text("Saving…").accessibilityIdentifier("editor.saving")
            }
            if let message = photoImport.editMessage(for: projectID) {
                Text(message).font(Typography.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("editor.layerMessage")
            }
            if photoImport.failedDraft(for: projectID) != nil {
                VStack(spacing: Spacing.small) {
                    Button("Retry saving") {
                        Task { await photoImport.retryFailedDraft(projectID: projectID) }
                    }
                    .frame(minHeight: Layout.minimumTapTarget)
                    .accessibilityIdentifier("editor.retryEdit")
                    Button("Discard unsaved edit", role: .destructive) {
                        photoImport.discardFailedDraft(projectID: projectID)
                    }
                    .frame(minHeight: Layout.minimumTapTarget)
                    .accessibilityIdentifier("editor.discardEdit")
                }
                .buttonStyle(.bordered)
                .disabled(photoImport.isBusy)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var addToCanvas: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Add to canvas").font(Typography.body)
            if photos.isEmpty {
                Text("Import a photo first, then add it to the canvas.")
                    .font(Typography.caption).foregroundStyle(.secondary)
            } else {
                // Keep one editor scroll container: the original picker/gallery
                // checks depend on an unambiguous vertical tool viewport.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: Spacing.small)], spacing: Spacing.small) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            Button { submit(.add(assetID: photo.asset.id), layerID: nil) } label: {
                                DerivedImageView(reference: photo.thumbnailReference, contentMode: .fill) { reference in
                                    await photoImport.loadImage(reference: reference)
                                } placeholder: { Color.secondary.opacity(0.15) }
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .contentShape(.interaction, Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(minWidth: Layout.minimumTapTarget, minHeight: Layout.minimumTapTarget)
                            .contentShape(.interaction, Rectangle())
                            .disabled(blocked || document.layers.count >= ProjectPackage.layerLimit)
                            .accessibilityLabel("Add photo \(index + 1) to canvas")
                            .accessibilityIdentifier("editor.addLayer.\(photo.asset.id.uuidString)")
                        }
                }
            }
        }
    }

    private func layerRow(_ layer: Layer) -> some View {
        let number = (CanvasGeometry.orderedBackToFront(document.layers).firstIndex { $0.id == layer.id } ?? 0) + 1
        return VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Button { selectedLayerID = layer.id } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Layer \(number)").font(Typography.body)
                    Text(description(of: layer)).font(Typography.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: Layout.minimumTapTarget, alignment: .leading)
            }
            .disabled(photoImport.isBusy)
            .accessibilityLabel("Select layer \(number), \(description(of: layer))")
            .accessibilityIdentifier("editor.selectLayer.\(layer.id.uuidString)")
            HStack(spacing: Spacing.small) {
                Button { submit(.visibility(isHidden: !layer.isHidden), layerID: layer.id) } label: {
                    Image(systemName: layer.isHidden ? "eye.slash" : "eye")
                        .frame(minWidth: Layout.minimumTapTarget, minHeight: Layout.minimumTapTarget)
                }
                .accessibilityLabel("\(layer.isHidden ? "Show" : "Hide") layer \(number)")
                .accessibilityIdentifier("editor.hideLayer.\(layer.id.uuidString)")
                Button { submit(.lock(isLocked: !layer.isLocked), layerID: layer.id) } label: {
                    Image(systemName: layer.isLocked ? "lock" : "lock.open")
                        .frame(minWidth: Layout.minimumTapTarget, minHeight: Layout.minimumTapTarget)
                }
                .accessibilityLabel("\(layer.isLocked ? "Unlock" : "Lock") layer \(number)")
                .accessibilityIdentifier("editor.lockLayer.\(layer.id.uuidString)")
                Button(role: .destructive) { submit(.remove, layerID: layer.id) } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: Layout.minimumTapTarget, minHeight: Layout.minimumTapTarget)
                }
                .disabled(layer.isLocked)
                .accessibilityLabel("Remove layer \(number)")
                .accessibilityIdentifier("editor.removeLayer.\(layer.id.uuidString)")
            }
            .disabled(blocked)
        }
        .background(layer.id == selectedLayerID ? Color.accentColor.opacity(0.12) : .clear)
        .accessibilityIdentifier("editor.layerRow.\(layer.id.uuidString)")
    }

    private func description(of layer: Layer) -> String {
        ([layer.isBoundToAsset ? "Photo" : "Unavailable photo"]
         + (layer.isHidden ? ["hidden"] : []) + (layer.isLocked ? ["locked"] : [])).joined(separator: ", ")
    }

    private func controls(for layer: Layer) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Adjust the selected layer").font(Typography.body)
            Text(String(format: "x %.0f, y %.0f, %.0f%%, %.0f°", layer.transform.translationX,
                        layer.transform.translationY, layer.transform.scale * 100, layer.transform.rotationRadians * 180 / .pi))
                .font(Typography.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("editor.layerTransform")
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack(spacing: Spacing.small) {
                    step("arrow.left", "Move left", .move(x: -document.canvasSize.width * 0.02, y: 0))
                    step("arrow.right", "Move right", .move(x: document.canvasSize.width * 0.02, y: 0))
                    step("arrow.up", "Move up", .move(x: 0, y: -document.canvasSize.height * 0.02))
                    step("arrow.down", "Move down", .move(x: 0, y: document.canvasSize.height * 0.02))
                }
                HStack(spacing: Spacing.small) {
                    step("minus.magnifyingglass", "Smaller", .scaleBy(1 / 1.1))
                    step("plus.magnifyingglass", "Larger", .scaleBy(1.1))
                    step("rotate.left", "Rotate left", .rotateBy(-.pi / 36))
                    step("rotate.right", "Rotate right", .rotateBy(.pi / 36))
                }
                action("Bring forward", "editor.bringForward", .order(forward: true))
                action("Send backward", "editor.sendBackward", .order(forward: false))
                action("Reset", "editor.resetLayer", .reset)
            }
            .disabled(blocked || layer.isLocked || !layer.isBoundToAsset)
            if layer.isBoundToAsset {
                Button("Reload selected photo", action: reloadSelectedPhoto)
                    .frame(minHeight: Layout.minimumTapTarget)
                    .accessibilityIdentifier("editor.reloadPhoto")
            }
        }
    }

    private func step(_ symbol: String, _ label: String, _ intent: PhotoImportModel.CanvasDraftIntent) -> some View {
        Button { submit(intent, layerID: selectedLayerID) } label: {
            Image(systemName: symbol).frame(minWidth: Layout.minimumTapTarget, minHeight: Layout.minimumTapTarget)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier("editor.step.\(label.replacingOccurrences(of: " ", with: ""))")
    }

    private func action(_ label: String, _ identifier: String, _ intent: PhotoImportModel.CanvasDraftIntent) -> some View {
        Button { submit(intent, layerID: selectedLayerID) } label: {
            Text(label).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: Layout.minimumTapTarget)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier(identifier)
    }

    private func submit(_ intent: PhotoImportModel.CanvasDraftIntent, layerID: UUID?) {
        guard !blocked else { return }
        Task {
            let previousIDs = Set(projectStore.openProject(id: projectID)?.document.layers.map(\.id) ?? [])
            let outcome = await photoImport.applyCanvasIntent(projectID: projectID, layerID: layerID, intent: intent)
            if case .saved = outcome, case .add = intent {
                selectedLayerID = projectStore.openProject(id: projectID)?.document.layers.first { !previousIDs.contains($0.id) }?.id
            }
        }
    }
}

