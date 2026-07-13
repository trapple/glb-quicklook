import Foundation
import RealityKit
import GLTFKit2

/// .glb を読み込み、ビューア表示用に整えた Entity を返す (appex とアプリで共用)。
/// 失敗時はそのまま throw する (Fail Fast)。
@MainActor
func loadViewerEntity(from url: URL) async throws -> Entity {
    let entity = try await GLTFRealityKitLoader.load(from: url)
    // glTF 内蔵カメラはズームを打ち消すため除去 (カメラはビュー側で制御する)
    removeCameras(from: entity)
    return entity
}
