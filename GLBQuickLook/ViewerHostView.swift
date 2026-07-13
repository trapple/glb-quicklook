import SwiftUI
import RealityKit

/// アプリ単体ビューア: ロード中/エラー表示を挟んで ModelPreviewView を出す
struct ViewerHostView: View {
    let url: URL
    let transform: ModelTransformController
    @State private var entity: Entity?
    @State private var loadError: Error?

    var body: some View {
        ZStack {
            if let entity {
                ModelPreviewView(modelEntity: entity, transform: transform)
            } else if let loadError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("読み込みに失敗しました")
                    Text(loadError.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(40)
            } else {
                ProgressView()
            }
        }
        // ideal/max の明示は初期ウィンドウサイズを 900x660 にするために必要 (実測)。
        // これが無いと AppDelegate 側の setContentSize が表示時に打ち消され、
        // 最小サイズ (480x360) のウィンドウになる
        .frame(
            minWidth: 480, idealWidth: 900, maxWidth: .infinity,
            minHeight: 360, idealHeight: 660, maxHeight: .infinity)
        .task {
            do {
                entity = try await loadViewerEntity(from: url)
            } catch {
                loadError = error
            }
        }
    }
}
