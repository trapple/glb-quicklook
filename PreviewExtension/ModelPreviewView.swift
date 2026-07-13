import SwiftUI
import RealityKit

struct ModelPreviewView: View {
    let modelEntity: Entity
    let transform: ModelTransformController
    @State private var isDarkBackground = true

    // spec: ダーク #262626 ⇄ ライト #d9d9d9
    private var backgroundColor: Color {
        isDarkBackground
            ? Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x26 / 255.0)
            : Color(red: 0xd9 / 255.0, green: 0xd9 / 255.0, blue: 0xd9 / 255.0)
    }

    var body: some View {
        RealityView { content in
            let bounds = modelEntity.visualBounds(relativeTo: nil)
            let framing = framingTransform(center: bounds.center, extents: bounds.extents)
            modelEntity.scale = SIMD3<Float>(repeating: framing.scale)
            modelEntity.position = framing.translation
            transform.root.addChild(modelEntity)
            content.add(transform.root)
            // カメラ操作は自前 (InteractionView + ModelTransformController) なので
            // カメラ自体は固定配置 (モデルは原点中心・最大辺 1.0 にフレーミング済み)
            let camera = PerspectiveCamera()
            camera.position = [0, 0, 2]
            content.add(camera)
        }
        .overlay {
            // QL 内では生マウスイベントが当てにならないため、AppKit ビューを
            // かぶせてドラッグ/スクロール/ピンチを受ける (InteractionView 参照)
            InteractionLayer(transform: transform)
        }
        .background(backgroundColor)
        .overlay(alignment: .topTrailing) {
            Button {
                isDarkBackground.toggle()
            } label: {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 14))
                    .foregroundStyle(isDarkBackground ? .white : .black)
            }
            .buttonStyle(.plain)
            .padding(10)
            .help("背景色を切り替え")
        }
    }
}
