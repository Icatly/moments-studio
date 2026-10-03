import Foundation

/// Logical size of a composition canvas, in canvas units (1 unit = 1 pixel at
/// export scale).
///
/// Doubles rather than `CGFloat` keep the serialized document independent of
/// the platform and easy to compare in tests.
struct CanvasSize: Codable, Equatable, Hashable {
    var width: Double
    var height: Double

    /// Temporary default (4:5 portrait). The approved output formats are a
    /// product decision that has not been made yet.
    static let portrait4x5 = CanvasSize(width: 1080, height: 1350)
}

/// The serializable description of one composition.
///
/// Stage 01 stores a canvas size and a layer list. The stacking rule is defined
/// here, once, so later stages do not each invent one:
///
/// - a larger `Layer.zIndex` is nearer the viewer;
/// - layers with equal `zIndex` fall back to their position in `layers`, where
///   a later element is nearer the viewer.
///
/// This is a semantic definition only: Stage 01 has no renderer and no sorting
/// API, and `layers` is stored exactly as written.
struct CanvasDocument: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var canvasSize: CanvasSize

    /// Ordered storage for layers; see the type documentation for how this
    /// order combines with `Layer.zIndex`.
    var layers: [Layer]

    init(
        id: UUID = UUID(),
        canvasSize: CanvasSize = .portrait4x5,
        layers: [Layer] = []
    ) {
        self.id = id
        self.canvasSize = canvasSize
        self.layers = layers
    }

    /// An empty document, used when a project is created.
    static var empty: CanvasDocument { CanvasDocument() }
}
