import SwiftUI
import RealityKit

struct ModelPreviewView: View {
    let modelEntity: Entity
    let pinchZoom: PinchZoomController
    let dragRotation: DragRotationController
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
            pinchZoom.root.addChild(modelEntity)
            content.add(pinchZoom.root)
            // カメラ操作は自前 (PanGestureView + DragRotationController) なので
            // カメラ自体は固定配置 (モデルは原点中心・最大辺 1.0 にフレーミング済み)
            let camera = PerspectiveCamera()
            camera.position = [0, 0, 2]
            content.add(camera)
        }
        .overlay {
            // QL 内では生マウスイベントが当てにならないため、レコグナイザを載せた
            // AppKit ビューをかぶせてドラッグ回転を受ける (PanGestureView 参照)
            PanGestureLayer { dx, dy in
                dragRotation.applyDrag(deltaX: dx, deltaY: dy)
            }
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
