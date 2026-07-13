import RealityKit

/// ドラッグをターンテーブル回転に変換する。
/// モデルは原点にフレーミング済みなので、原点中心の親 Entity の
/// orientation を書き換えるだけで回転になる (ズームのスケールと同型)。
@MainActor
final class DragRotationController {
    let root: Entity
    private(set) var yaw: Float = 0
    private(set) var pitch: Float = 0

    /// 1pt あたりの回転量 (rad)
    static let radiansPerPoint: Float = 0.01

    init(root: Entity) {
        self.root = root
    }

    /// deltaY は下向き正 (AppKit 座標からの反転はビュー側で済ませる)
    func applyDrag(deltaX: Float, deltaY: Float) {
        yaw += deltaX * Self.radiansPerPoint
        pitch = min(max(pitch + deltaY * Self.radiansPerPoint, -.pi / 2), .pi / 2)
        root.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0])
            * simd_quatf(angle: yaw, axis: [0, 1, 0])
    }
}
