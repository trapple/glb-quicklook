import AppKit
import SwiftUI

/// マウス/スクロール/ピンチ入力を受ける透明な AppKit ビュー。
/// QL のリモートビュー転送 (ViewBridge) 下でも動く実測ベースの構成 (設計書
/// 「QL プレビューの入力制約」参照):
/// - 左ドラッグ: NSPanGestureRecognizer (生イベントはパネルで delta が 0 に潰され、
///   Finder 欄ではホストに食われる)。Shift 押下でパン、通常は回転
/// - 右ドラッグ: 生イベント + locationInWindow の位置差分 (buttonMask 指定の
///   レコグナイザはパネルで一切発火しない)
/// - スクロール/ピンチ: override (どの面でも潰されず届く)
/// Finder 欄では右イベント自体が届かないため、欄でのパンは Shift+ドラッグを使う。
final class InteractionView: NSView {
    var onOrbit: ((Float, Float) -> Void)?
    var onPan: ((Float, Float) -> Void)?
    var onZoom: ((CGFloat) -> Void)?

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
        let (dx, dy) = (Float(translation.x), Float(-translation.y))
        if NSEvent.modifierFlags.contains(.shift) {
            onPan?(dx, dy)
        } else {
            onOrbit?(dx, dy)
        }
    }

    // 右 (2本指クリック) ドラッグのパン。delta は 0 に潰されるため位置差分で計算する
    private var lastRightDragLocation: NSPoint?

    override func rightMouseDown(with event: NSEvent) {
        lastRightDragLocation = event.locationInWindow
    }

    override func rightMouseDragged(with event: NSEvent) {
        let location = event.locationInWindow
        if let last = lastRightDragLocation {
            onPan?(Float(location.x - last.x), Float(last.y - location.y))
        }
        lastRightDragLocation = location
    }

    override func rightMouseUp(with event: NSEvent) {
        lastRightDragLocation = nil
    }

    override func scrollWheel(with event: NSEvent) {
        onZoom?(event.scrollingDeltaY * 0.01)
    }

    override func magnify(with event: NSEvent) {
        onZoom?(event.magnification)
    }
}

/// InteractionView を SwiftUI のオーバーレイとして載せるためのラッパー
struct InteractionLayer: NSViewRepresentable {
    let transform: ModelTransformController

    func makeNSView(context: Context) -> InteractionView {
        let view = InteractionView()
        view.onOrbit = { [weak transform] dx, dy in transform?.applyOrbit(deltaX: dx, deltaY: dy) }
        view.onPan = { [weak transform] dx, dy in transform?.applyPan(deltaX: dx, deltaY: dy) }
        view.onZoom = { [weak transform] delta in transform?.applyMagnification(delta: delta) }
        return view
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {}
}
