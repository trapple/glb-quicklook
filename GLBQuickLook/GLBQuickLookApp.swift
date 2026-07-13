import SwiftUI
import UniformTypeIdentifiers

@main
struct GLBQuickLookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("GLB Quick Look")
                    .font(.title2)
                Text("Finder で .glb を選んでスペースキーを押すとプレビューされます。\n.glb をこのアプリで開く (または ⌘O) と単体ビューアで表示されます。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(minWidth: 420, minHeight: 240)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("開く…") { appDelegate.openDocument() }
                    .keyboardShortcut("o")
            }
        }
    }
}

/// Finder の「このアプリケーションで開く」(odoc) は SwiftUI の Scene では受けられない
/// ため、AppKit デリゲートで受けて単体ビューアウィンドウを開く
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 閉じるまでウィンドウを保持する (NSWindow は参照が切れると消える)
    private var viewerWindows: [NSWindow] = []

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(openViewer)
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(importedAs: "org.khronos.glb")]
        if panel.runModal() == .OK, let url = panel.url {
            openViewer(url)
        }
    }

    private func openViewer(_ url: URL) {
        let viewer = ViewerHostView(url: url, transform: ModelTransformController())
        let hosting = NSHostingController(rootView: viewer)
        // sizingOptions 既定値だと表示時にウィンドウが SwiftUI の最小サイズへ
        // 合わせ直され setContentSize が打ち消されるため、自動サイズ連動を切る
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.title = url.lastPathComponent
        window.setContentSize(NSSize(width: 900, height: 660))
        // ARC 管理下で AppKit 側の解放と二重にならないようにする
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        viewerWindows.append(window)
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] notification in
            guard let closing = notification.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                self?.viewerWindows.removeAll { $0 === closing }
            }
        }
    }
}
