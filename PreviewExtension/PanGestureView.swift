import AppKit
import SwiftUI

/// ドラッグを受けるための透明な AppKit ビュー。
/// QL のリモートビュー転送 (ViewBridge) は生の mouseDown/mouseDragged を表示面ごとに
/// 違う形で殺す (スペースキーパネルでは deltaX/deltaY が 0 に潰され、Finder プレビュー欄
/// ではホスト側のファイルドラッグ判定等に消費されてビューまで届かない)。
/// NSPanGestureRecognizer はホストとのイベント調停に乗るため両方の面で機能し、
/// translation(in:) はデルタ潰しの影響も受けない (Apple 純正 usdz プレビューと同方式)。
final class PanGestureView: NSView {
    var onDrag: ((Float, Float) -> Void)?

    /// Finder のプレビュー欄等、ホストウィンドウが key にならない文脈では
    /// 最初のクリックが click-through 防止で捨てられドラッグが成立しないため、
    /// 最初のクリックから受け付ける
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addGestureRecognizer(NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        // AppKit 座標は Y 上向きなので下向き正へ反転
        onDrag?(Float(translation.x), Float(-translation.y))
    }
}

/// PanGestureView を SwiftUI のオーバーレイとして載せるためのラッパー
struct PanGestureLayer: NSViewRepresentable {
    let onDrag: (Float, Float) -> Void

    func makeNSView(context: Context) -> PanGestureView {
        let view = PanGestureView()
        view.onDrag = onDrag
        return view
    }

    func updateNSView(_ nsView: PanGestureView, context: Context) {
        nsView.onDrag = onDrag
    }
}
