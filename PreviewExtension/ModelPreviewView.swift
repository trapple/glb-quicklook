import SwiftUI
import RealityKit

struct ModelPreviewView: View {
    let modelEntity: Entity
    let pinchZoom: PinchZoomController
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
        }
        .realityViewCameraControls(.orbit)
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
