import Foundation
import RealityKit

/// トラックパッドのピンチ (NSEvent.magnification) をズームに変換する。
/// モデルは原点にフレーミング済みなので、原点中心の親 Entity を
/// 等倍スケールするだけでズームになる。
@MainActor
final class PinchZoomController {
    let root = Entity()
    private(set) var zoom: Float = 1.0

    func applyMagnification(delta: CGFloat) {
        zoom = min(max(zoom * Float(1.0 + delta), 0.1), 20.0)
        root.scale = SIMD3<Float>(repeating: zoom)
    }
}
