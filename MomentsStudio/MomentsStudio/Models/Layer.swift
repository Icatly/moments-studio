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
    }

    let id: UUID
    var kind: LayerKind
    var transform: LayerTransform

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
        isHidden: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.transform = transform
        self.opacity = Self.sanitizedOpacity(opacity)
        self.zIndex = zIndex
        self.isLocked = isLocked
        self.isHidden = isHidden
    }

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
        self.transform = try container.decode(LayerTransform.self, forKey: .transform)
        self.opacity = decodedOpacity
        self.zIndex = try container.decode(Int.self, forKey: .zIndex)
        self.isLocked = try container.decode(Bool.self, forKey: .isLocked)
        self.isHidden = try container.decode(Bool.self, forKey: .isHidden)
    }

    private static func sanitizedOpacity(_ value: Double) -> Double {
        guard value.isFinite else { return defaultOpacity }
        return min(max(value, opacityRange.lowerBound), opacityRange.upperBound)
    }
}
