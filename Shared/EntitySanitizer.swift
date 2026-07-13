import RealityKit

/// glTF が内包するカメラを除去する。カメラがモデル階層 (ズーム用親 Entity の中) に
/// 残っていると RealityView がそれをアクティブカメラにし、ズームがモデルと一緒に
/// スケールされて打ち消されるため、プレビューのカメラは常にビュー側で制御する。
@MainActor
func removeCameras(from entity: Entity) {
    entity.components.remove(PerspectiveCameraComponent.self)
    entity.components.remove(OrthographicCameraComponent.self)
    for child in entity.children {
        removeCameras(from: child)
    }
}
