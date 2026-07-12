import Cocoa
import OSLog
import QuickLookUI
import RealityKit
import SwiftUI
import GLTFKit2

class PreviewViewController: NSViewController, QLPreviewingController {

    private static let logger = Logger(subsystem: "jp.trapple.GLBQuickLook", category: "preview")

    private let pinchZoom = PinchZoomController()
    private var eventMonitors: [Any] = []

    override func loadView() {
        view = NSView()
        // QLホスト内では SwiftUI ジェスチャにピンチ/スクロールが配送されないため、
        // AppKit のイベントモニタで直接拾ってズームする
        eventMonitors.append(NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            guard let self, event.window === self.view.window else { return event }
            self.pinchZoom.applyMagnification(delta: event.magnification)
            return event
        } as Any)
        eventMonitors.append(NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.view.window else { return event }
            self.pinchZoom.applyMagnification(delta: event.scrollingDeltaY * 0.01)
            return event
        } as Any)
    }

    deinit {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
    }

    func preparePreviewOfFile(at url: URL) async throws {
        // 失敗時はそのまま throw し、Quick Look 標準フォールバックに任せる (Fail Fast)
        let entity: Entity
        do {
            entity = try await GLTFRealityKitLoader.load(from: url)
        } catch {
            Self.logger.error("GLB load failed for \(url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
            throw error
        }
        // glTF 内蔵カメラはズームを打ち消すため除去 (カメラはビュー側で制御する)
        removeCameras(from: entity)
        let hostingView = NSHostingView(rootView: ModelPreviewView(modelEntity: entity, pinchZoom: pinchZoom))
        hostingView.frame = view.bounds
        hostingView.autoresizingMask = [.width, .height]
        view.addSubview(hostingView)
    }
}
