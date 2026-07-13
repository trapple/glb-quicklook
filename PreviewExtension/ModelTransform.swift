import Foundation
import RealityKit

/// ピンチ/スクロール/ドラッグをモデルの変換に反映する。
/// モデルは原点にフレーミング済み・カメラは固定なので、原点中心の親 Entity の
/// scale (ズーム)・orientation (ターンテーブル回転)・position (パン) を
/// 書き換えるだけでカメラ操作相当になる。
@MainActor
final class ModelTransformController {
    let root = Entity()
    private(set) var zoom: Float = 1.0
    private(set) var yaw: Float = 0
    private(set) var pitch: Float = 0

    /// 1pt あたりの回転量 (rad)
    static let radiansPerPoint: Float = 0.01
    /// 1pt あたりの平行移動量 (world)。カメラ距離 2.0 / FOV 60° でドラッグにほぼ追従する値
    static let panUnitsPerPoint: Float = 0.003

    func applyMagnification(delta: CGFloat) {
        zoom = min(max(zoom * Float(1.0 + delta), 0.1), 20.0)
        root.scale = SIMD3<Float>(repeating: zoom)
    }

    /// deltaY は下向き正 (AppKit 座標からの反転はビュー側で済ませる)
    func applyOrbit(deltaX: Float, deltaY: Float) {
        yaw += deltaX * Self.radiansPerPoint
        pitch = min(max(pitch + deltaY * Self.radiansPerPoint, -.pi / 2), .pi / 2)
        root.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0])
            * simd_quatf(angle: yaw, axis: [0, 1, 0])
    }

    /// deltaY は下向き正。ドラッグ方向へモデルを平行移動する
    func applyPan(deltaX: Float, deltaY: Float) {
        root.position += SIMD3<Float>(deltaX, -deltaY, 0) * Self.panUnitsPerPoint
    }
}
