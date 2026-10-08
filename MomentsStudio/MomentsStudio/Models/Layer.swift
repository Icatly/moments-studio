import Foundation

/// Position, scale and rotation of a layer relative to the canvas origin.
///
/// Plain `Double` fields (instead of a `CGAffineTransform`) keep the document
/// format explicit, readable and independent of any rendering framework.
struct LayerTransform: Codable, Equatable, Hashable {
    var translationX: Double
    var translationY: Double
    var scale: Double
    var rotationRadians: Double

    static let identity = LayerTransform()

    init(
        translationX: Double = 0,
        translationY: Double = 0,
        scale: Double = 1,
        rotationRadians: Double = 0
    ) {
        self.translationX = translationX
        self.translationY = translationY
        self.scale = scale
        self.rotationRadians = rotationRadians
    }
}

/// What a layer contains.
///
/// Stage 01 only needs `photo`: photo import, collage roles, cutouts and text
/// layers do not exist yet. New cases require architecture review, and decoding
/// a document that contains an unknown kind currently fails (recorded as a
/// known limitation in the Stage 01 report).
enum LayerKind: String, Codable, Equatable, Hashable {
    case photo
}

/// One element of the composition stack.
struct Layer: Identifiable, Codable, Equatable, Hashable {
    /// The only range an opacity may occupy.
    static let opacityRange: ClosedRange<Double> = 0...1

    /// Opacity substituted when programmatic input is not finite.
    static let defaultOpacity: Double = 1

    /// Decoded keys, listed explicitly because `init(from:)` is custom. The
    /// names are the serialization contract and must not change without
    /// architecture review.
    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case transform
        case opacity
        case zIndex
        case isLocked
        case isHidden
        // Stage 03 additions (approved schema change): a photo layer points at an
        // asset inside the same package and remembers its unscaled canvas size.
        case assetID
        case baseSize
    }

    let id: UUID
    var kind: LayerKind
    var transform: LayerTransform

    /// The asset this layer renders, when it is bound to an imported photo.
    ///
    /// Stage 03 photo layers always have both `assetID` and `baseSize`. A layer
    /// saved before Stage 03 has neither: it is kept as an honest unbound
    /// placeholder, is listed as unavailable and can be removed, but no image is
    /// invented for it.
    var assetID: UUID?

    /// Canvas-space size of the layer before `transform.scale` is applied.
    ///
    /// Fixed once the layer is added; it never follows the screen or the derived
    /// preview pixel size.
    var baseSize: CanvasSize?

    /// Opacity inside `opacityRange`.
    ///
    /// Writes are closed: the only entry points are `init(...)` and
    /// `setOpacity(_:)`, both of which sanitize their input, so the stored value
    /// is always finite and inside the range.
    private(set) var opacity: Double

    /// Stacking order: a larger value is nearer the viewer. Layers with equal
    /// `zIndex` fall back to their position in `CanvasDocument.layers`, where a
    /// later element is nearer the viewer. Stage 01 defines the semantics only;
    /// no renderer or sorting API exists yet.
    var zIndex: Int

    var isLocked: Bool
    var isHidden: Bool

    init(
        id: UUID = UUID(),
        kind: LayerKind = .photo,
        transform: LayerTransform = .identity,
        opacity: Double = Layer.defaultOpacity,
        zIndex: Int = 0,
        isLocked: Bool = false,
        isHidden: Bool = false,
        assetID: UUID? = nil,
        baseSize: CanvasSize? = nil
    ) {
        self.id = id
        self.kind = kind
        self.transform = transform
        self.opacity = Self.sanitizedOpacity(opacity)
        self.zIndex = zIndex
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.assetID = assetID
        self.baseSize = baseSize
    }

    /// True when both Stage 03 keys are present, i.e. this layer can be rendered.
    var isBoundToAsset: Bool { assetID != nil && baseSize != nil }

    /// Sets opacity, applying the same policy as `init(...)`.
    ///
    /// Programmatic input policy: a non-finite value (`NaN`, `±Infinity`) has no
    /// meaning as an opacity, so it becomes `defaultOpacity` (fully opaque);
    /// any other value outside `opacityRange` is clamped to the nearest bound.
    /// Decoded documents are handled more strictly — see `init(from:)`.
    mutating func setOpacity(_ value: Double) {
        opacity = Self.sanitizedOpacity(value)
    }

    /// Decodes a layer and **rejects** a damaged `opacity` rather than repairing
    /// it.
    ///
    /// A persisted opacity must already be finite and inside `opacityRange`. A
    /// value outside that contract means the archive is wrong, and silently
    /// clamping it would hide data loss, so decoding fails with
    /// `DecodingError.dataCorruptedError`. Every other field keeps the decoding
    /// requirements it had before, and `encode(to:)` remains synthesized over
    /// the same field names, so the encoded shape is unchanged.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedOpacity = try container.decode(Double.self, forKey: .opacity)

        guard decodedOpacity.isFinite, Self.opacityRange.contains(decodedOpacity) else {
            throw DecodingError.dataCorruptedError(
                forKey: .opacity,
                in: container,
                debugDescription: "Layer opacity must be finite and within \(Self.opacityRange); found \(decodedOpacity)."
            )
        }

        self.id = try container.decode(UUID.self, forKey: .id)
        self.kind = try container.decode(LayerKind.self, forKey: .kind)
        let decodedTransform = try container.decode(LayerTransform.self, forKey: .transform)
        // Stage 03: a persisted transform must already be usable. Finite position
        // and rotation with a positive, finite scale is the decode contract; bad
        // archives are rejected instead of silently repaired.
        guard decodedTransform.translationX.isFinite,
              decodedTransform.translationY.isFinite,
              decodedTransform.rotationRadians.isFinite,
              decodedTransform.scale.isFinite,
              decodedTransform.scale > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .transform,
                in: container,
                debugDescription: "Layer transform must have finite position/rotation and a positive finite scale: \(decodedTransform)."
            )
        }
        self.transform = decodedTransform
        self.opacity = decodedOpacity
        self.zIndex = try container.decode(Int.self, forKey: .zIndex)
        self.isLocked = try container.decode(Bool.self, forKey: .isLocked)
        self.isHidden = try container.decode(Bool.self, forKey: .isHidden)

        // Stage 03 keys. Both present is a bound photo layer; both absent is a
        // historical unbound placeholder. Anything in between, or a base size
        // that is not finite and positive, is damage and is rejected.
        let assetID = try container.decodeIfPresent(UUID.self, forKey: .assetID)
        let baseSize = try container.decodeIfPresent(CanvasSize.self, forKey: .baseSize)
        switch (assetID, baseSize) {
        case (nil, nil):
            break
        case let (.some(_), .some(size)):
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .baseSize,
                    in: container,
                    debugDescription: "Layer base size must be finite and positive: \(size)."
                )
            }
            break
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .assetID,
                in: container,
                debugDescription: "A layer must carry both assetID and baseSize, or neither."
            )
        }
        self.assetID = assetID
        self.baseSize = baseSize
    }

    private static func sanitizedOpacity(_ value: Double) -> Double {
        guard value.isFinite else { return defaultOpacity }
        return min(max(value, opacityRange.lowerBound), opacityRange.upperBound)
    }
}
