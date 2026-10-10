import Foundation

/// Functional layout presets, not final brand styles or AI recommendations.
enum CollagePreset: String, CaseIterable, Identifiable, Hashable {
    case grid
    case focus
    case offset

    var id: Self { self }

    var title: String {
        switch self {
        case .grid: return "Grid"
        case .focus: return "Focus"
        case .offset: return "Offset"
        }
    }

    var summary: String {
        switch self {
        case .grid: return "Even spacing, with every photo shown in full."
        case .focus: return "Give the first photo more room, with the others below."
        case .offset: return "Gentle rotation and staggered spacing."
        }
    }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let keywords: String
        switch self {
        case .grid: keywords = "整齐 网格 并列 留白"
        case .focus: keywords = "主图 突出 焦点 封面"
        case .offset: keywords = "错落 旋转 拼贴 随意"
        }
        return "\(title) \(summary) \(keywords)".localizedCaseInsensitiveContains(query)
    }
}

enum CollageLayoutError: Error, Equatable, LocalizedError {
    case invalidCanvas
    case invalidPhoto(UUID)
    case invalidLayers
    case noPhotos
    /// Photos exist, but every one of them is saved as collage material or "not for
    /// layout", so there is nothing a layout may arrange. This is about the saved
    /// roles — not about importing photos the user already has.
    case noEligiblePhotos
    case noEditableLayers
    case tooManyLayers
    case cannotFit

    var errorDescription: String? {
        switch self {
        case .invalidCanvas: return "This canvas has an unusable size."
        case .invalidPhoto: return "A photo needed for this layout is missing or has an unusable size."
        case .invalidLayers: return "This canvas has invalid or duplicate layers."
        case .noPhotos: return "Import photos before choosing a layout."
        case .noEligiblePhotos: return "Every photo is saved as collage material or not for layout. Set at least one photo to Primary or Supporting in Photo roles, then choose a layout."
        case .noEditableLayers: return "There are no visible, unlocked photo layers to arrange."
        case .tooManyLayers: return "A layout can use at most \(ProjectPackage.layerLimit) layers."
        case .cannotFit: return "These photos cannot fit this layout within the editing limits. Try another layout."
        }
    }
}

/// Metadata-only, deterministic layout. No image work, random IDs or persistence.
enum CollageLayout {
    static func arrange(
        _ preset: CollagePreset,
        document: CanvasDocument,
        photos: [ImportedPhoto]
    ) throws -> CanvasDocument {
        let size = document.canvasSize
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            throw CollageLayoutError.invalidCanvas
        }
        guard photos.count <= ProjectPackage.photoLimit, document.layers.count <= ProjectPackage.layerLimit else {
            throw CollageLayoutError.tooManyLayers
        }
        guard Set(document.layers.map(\.id)).count == document.layers.count else {
            throw CollageLayoutError.invalidLayers
        }
        for layer in document.layers {
            guard (layer.assetID == nil) == (layer.baseSize == nil),
                  layer.transform.translationX.isFinite, layer.transform.translationY.isFinite,
                  layer.transform.rotationRadians.isFinite,
                  layer.transform.scale.isFinite, layer.transform.scale > 0 else {
                throw CollageLayoutError.invalidLayers
            }
            if let base = layer.baseSize {
                guard base.width.isFinite, base.height.isFinite, base.width > 0, base.height > 0 else {
                    throw CollageLayoutError.invalidLayers
                }
            }
        }
        var photoIDs = Set<UUID>()
        for photo in photos {
            guard photoIDs.insert(photo.id).inserted, photo.asset.kind == .photo,
                  photo.pixelWidth > 0, photo.pixelHeight > 0,
                  ImportedPhoto.orientationRange.contains(photo.orientation) else {
                throw CollageLayoutError.invalidPhoto(photo.id)
            }
        }

        var result = document
        // Stage 06: only photos that take part in the layout are ever added. A
        // decision the user saved as collage material or "not for layout" is kept
        // in the library and on the canvas, and an untouched project (every
        // `roleChoice` nil) behaves exactly as before.
        let participating = PhotoRoleLayoutPlan.participatingPhotoIDs(photos)
        let layoutPhotos = photos.filter { participating.contains($0.id) }
        if result.layers.isEmpty {
            guard !layoutPhotos.isEmpty else {
                // Distinguish "no photos at all" from "photos exist but the user saved
                // every one of them as not for layout": the second case must tell the
                // user to change a role, not to import photos they already have.
                throw photos.isEmpty ? CollageLayoutError.noPhotos : CollageLayoutError.noEligiblePhotos
            }
            for photo in layoutPhotos {
                let display = photo.displayPixelSize
                guard let baseSize = CanvasGeometry.fittedBaseSize(
                    displayWidth: display.width, displayHeight: display.height, canvasSize: size
                ) else { throw CollageLayoutError.invalidPhoto(photo.id) }
                // An empty canvas has no layer IDs to collide with. Reuse asset
                // identity so preview, apply and retries create exactly the same IDs.
                result = try CanvasEditor.addingLayer(
                    assetID: photo.id, baseSize: baseSize, to: result, layerID: photo.id
                )
            }
        }

        for layer in result.layers where layer.isBoundToAsset {
            guard let assetID = layer.assetID, photoIDs.contains(assetID) else {
                throw CollageLayoutError.invalidPhoto(layer.assetID ?? layer.id)
            }
        }
        // Collage material and excluded photos keep their current transform, order,
        // lock and visibility: they are simply not part of the movable set. Only
        // Focus gives the saved primary photo the computed hero position; Grid and
        // Offset keep their frozen Stage 04 order (see `arrangementOrder`).
        let movable = PhotoRoleLayoutPlan.arrangementOrder(
            CanvasGeometry.orderedBackToFront(result.layers).filter {
                $0.isBoundToAsset && !$0.isHidden && !$0.isLocked
                    && (($0.assetID.map { participating.contains($0) }) ?? false)
            },
            preset: preset,
            primaryAssetID: PhotoRoleLayoutPlan.primaryPhotoID(photos)
        )
        guard !movable.isEmpty else {
            // A canvas whose only layers belong to photos the user saved as collage
            // material / not for layout is a role problem, not "nothing editable".
            throw (photos.isEmpty || !participating.isEmpty)
                ? CollageLayoutError.noEditableLayers
                : CollageLayoutError.noEligiblePhotos
        }
        guard movable.allSatisfy({ layer in
            guard let base = layer.baseSize else { return false }
            return base.width.isFinite && base.height.isFinite && base.width > 0 && base.height > 0
        }) else { throw CollageLayoutError.invalidLayers }

        let shortSide = min(size.width, size.height)
        let margin = shortSide * 0.05
        let gap = shortSide * 0.02
        let bounds = CanvasRect(x: margin, y: margin, width: size.width - margin * 2, height: size.height - margin * 2)
        let cells: [CanvasRect]
        if preset == .focus {
            if movable.count == 1 {
                cells = [CanvasRect(
                    x: bounds.x + bounds.width * 0.05, y: bounds.y + bounds.height * 0.05,
                    width: bounds.width * 0.9, height: bounds.height * 0.9
                )]
            } else {
                let fraction = movable.count <= 6 ? 0.6 : movable.count <= 12 ? 0.45 : 0.3
                let heroHeight = bounds.height * fraction
                let hero = CanvasRect(x: bounds.x, y: bounds.y, width: bounds.width, height: heroHeight)
                let remainder = CanvasRect(
                    x: bounds.x, y: bounds.y + heroHeight + gap,
                    width: bounds.width, height: bounds.height - heroHeight - gap
                )
                cells = [hero] + (try gridCells(for: Array(movable.dropFirst()), in: remainder, gap: gap, preset: preset))
            }
        } else {
            cells = try gridCells(for: movable, in: bounds, gap: gap, preset: preset)
        }

        var transforms: [UUID: LayerTransform] = [:]
        for (index, layer) in movable.enumerated() {
            guard let transform = fittedTransform(layer, cell: cells[index], index: index, preset: preset) else {
                throw CollageLayoutError.cannotFit
            }
            transforms[layer.id] = transform
        }
        // Preserve stored order, stacking, base sizes, opacity and every protected layer.
        for index in result.layers.indices {
            if let transform = transforms[result.layers[index].id] {
                result.layers[index].transform = transform
            }
        }
        return result
    }

    private static func gridCells(
        for layers: [Layer], in bounds: CanvasRect, gap: Double, preset: CollagePreset
    ) throws -> [CanvasRect] {
        guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else {
            throw CollageLayoutError.cannotFit
        }
        var bestCells: [CanvasRect]?
        var bestScore = -Double.infinity
        // ponytail: bounded to 20 layers. Revisit this exhaustive grid search only
        // if a future approved layer limit makes metadata planning expensive.
        for columns in 1...layers.count {
            let rows = (layers.count + columns - 1) / columns
            let width = (bounds.width - gap * Double(columns - 1)) / Double(columns)
            let height = (bounds.height - gap * Double(rows - 1)) / Double(rows)
            guard width.isFinite, height.isFinite, width > 0, height > 0 else { continue }
            var cells: [CanvasRect] = []
            var score = 0.0
            for (index, layer) in layers.enumerated() {
                let row = index / columns
                let column = index % columns
                let rowCount = min(columns, layers.count - row * columns)
                let startX = bounds.centerX - (Double(rowCount) * width + Double(rowCount - 1) * gap) / 2
                let cell = CanvasRect(
                    x: startX + Double(column) * (width + gap), y: bounds.y + Double(row) * (height + gap),
                    width: width, height: height
                )
                guard let transform = fittedTransform(layer, cell: cell, index: index, preset: preset),
                      let base = layer.baseSize else { break }
                score += (base.width * transform.scale / bounds.width) * (base.height * transform.scale / bounds.height)
                cells.append(cell)
            }
            if cells.count == layers.count, score > bestScore + 1e-12 {
                bestScore = score
                bestCells = cells
            }
        }
        guard let bestCells else { throw CollageLayoutError.cannotFit }
        return bestCells
    }

    private static func fittedTransform(
        _ layer: Layer, cell: CanvasRect, index: Int, preset: CollagePreset
    ) -> LayerTransform? {
        guard let base = layer.baseSize, cell.width > 0, cell.height > 0 else { return nil }
        let direction = index.isMultiple(of: 2) ? -1.0 : 1.0
        let rotation = preset == .offset ? direction * Double.pi / 36 : 0
        let rotatedWidth = base.width * abs(cos(rotation)) + base.height * abs(sin(rotation))
        let rotatedHeight = base.height * abs(cos(rotation)) + base.width * abs(sin(rotation))
        let fill = preset == .offset ? 0.9 : 1.0
        let fitScale = min(cell.width * fill / rotatedWidth, cell.height * fill / rotatedHeight)
        guard fitScale.isFinite, fitScale >= CanvasGeometry.minimumScale else { return nil }
        let scale = min(fitScale, CanvasGeometry.maximumScale)
        let x = cell.centerX + (preset == .offset ? direction * cell.width * 0.03 : 0)
        let y = cell.centerY + (preset == .offset ? -direction * cell.height * 0.025 : 0)
        guard x.isFinite, y.isFinite, scale.isFinite else { return nil }
        return LayerTransform(translationX: x, translationY: y, scale: scale, rotationRadians: rotation)
    }
}
