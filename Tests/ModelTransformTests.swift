import XCTest
import RealityKit

final class ModelTransformTests: XCTestCase {

    // MARK: ズーム

    @MainActor
    func testMagnificationAccumulates() {
        let controller = ModelTransformController()
        controller.applyMagnification(delta: 1.0) // 1.0 * 2.0
        XCTAssertEqual(controller.zoom, 2.0, accuracy: 1e-6)
        XCTAssertEqual(controller.root.scale.x, 2.0, accuracy: 1e-6)
    }

    @MainActor
    func testZoomClampsToLowerBound() {
        let controller = ModelTransformController()
        controller.applyMagnification(delta: -10.0) // 負スケールにならず 0.1 に張り付く
        XCTAssertEqual(controller.zoom, 0.1, accuracy: 1e-6)
    }

    @MainActor
    func testZoomClampsToUpperBound() {
        let controller = ModelTransformController()
        for _ in 0..<100 { controller.applyMagnification(delta: 1.0) }
        XCTAssertEqual(controller.zoom, 20.0, accuracy: 1e-6)
    }

    // MARK: 回転

    @MainActor
    func testYawAccumulatesAndRotatesRoot() {
        let controller = ModelTransformController()
        controller.applyOrbit(deltaX: 100, deltaY: 0) // 100pt * 0.01 = 1.0 rad
        XCTAssertEqual(controller.yaw, 1.0, accuracy: 1e-6)
        // 右ドラッグで前面 (+Z) が右 (+X) へ回る
        let front = controller.root.orientation.act(SIMD3<Float>(0, 0, 1))
        XCTAssertEqual(front.x, sin(1.0), accuracy: 1e-5)
        XCTAssertEqual(front.z, cos(1.0), accuracy: 1e-5)
    }

    @MainActor
    func testDragDownTipsTopTowardCamera() {
        let controller = ModelTransformController()
        controller.applyOrbit(deltaX: 0, deltaY: 50) // 下ドラッグ 0.5 rad
        // 上面 (+Y) がカメラ (+Z) 側へ倒れる
        let top = controller.root.orientation.act(SIMD3<Float>(0, 1, 0))
        XCTAssertGreaterThan(top.z, 0)
    }

    @MainActor
    func testPitchClampsToVertical() {
        let controller = ModelTransformController()
        controller.applyOrbit(deltaX: 0, deltaY: 10_000)
        XCTAssertEqual(controller.pitch, .pi / 2, accuracy: 1e-6)
        controller.applyOrbit(deltaX: 0, deltaY: -20_000)
        XCTAssertEqual(controller.pitch, -.pi / 2, accuracy: 1e-6)
    }

    // MARK: パン

    @MainActor
    func testPanMovesRootInDragDirection() {
        let controller = ModelTransformController()
        controller.applyPan(deltaX: 100, deltaY: 100) // 右下ドラッグ (deltaY は下向き正)
        XCTAssertEqual(controller.root.position.x, 0.3, accuracy: 1e-6)
        XCTAssertEqual(controller.root.position.y, -0.3, accuracy: 1e-6) // world は Y 上向き
        XCTAssertEqual(controller.root.position.z, 0, accuracy: 1e-6)
    }

    @MainActor
    func testPanAccumulates() {
        let controller = ModelTransformController()
        controller.applyPan(deltaX: 10, deltaY: 0)
        controller.applyPan(deltaX: -10, deltaY: 0) // 往復で元の位置へ
        XCTAssertEqual(controller.root.position.x, 0, accuracy: 1e-6)
    }

    // MARK: 変換の独立性

    @MainActor
    func testZoomOrbitPanAreIndependent() {
        let controller = ModelTransformController()
        controller.applyMagnification(delta: 1.0)
        controller.applyOrbit(deltaX: 50, deltaY: 0)
        controller.applyPan(deltaX: 100, deltaY: 0)
        XCTAssertEqual(controller.root.scale.x, 2.0, accuracy: 1e-6)
        XCTAssertEqual(controller.yaw, 0.5, accuracy: 1e-6)
        XCTAssertEqual(controller.root.position.x, 0.3, accuracy: 1e-6)
    }
}
