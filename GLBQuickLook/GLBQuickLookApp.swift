import SwiftUI

@main
struct GLBQuickLookApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("GLB Quick Look")
                    .font(.title2)
                Text("Finder で .glb を選んでスペースキーを押すとプレビューされます。\nこのアプリは拡張を登録するためだけに存在します。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(minWidth: 420, minHeight: 240)
        }
    }
}
