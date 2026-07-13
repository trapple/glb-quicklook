import XCTest
import RealityKit

final class DragRotationTests: XCTestCase {

    @MainActor
    func testYawAccumulatesAndRotatesRoot() {
        let controller = DragRotationController(root: Entity())
        controller.applyDrag(deltaX: 100, deltaY: 0) // 100pt * 0.01 = 1.0 rad
        XCTAssertEqual(controller.yaw, 1.0, accuracy: 1e-6)
        // 右ドラッグで前面 (+Z) が右 (+X) へ回る
        let front = controller.root.orientation.act(SIMD3<Float>(0, 0, 1))
        XCTAssertEqual(front.x, sin(1.0), accuracy: 1e-5)
        XCTAssertEqual(front.z, cos(1.0), accuracy: 1e-5)
    }

    @MainActor
    func testDragDownTipsTopTowardCamera() {
        let controller = DragRotationController(root: Entity())
        controller.applyDrag(deltaX: 0, deltaY: 50) // 下ドラッグ 0.5 rad
        // 上面 (+Y) がカメラ (+Z) 側へ倒れる
        let top = controller.root.orientation.act(SIMD3<Float>(0, 1, 0))
        XCTAssertGreaterThan(top.z, 0)
    }

    @MainActor
    func testPitchClampsToVertical() {
        let controller = DragRotationController(root: Entity())
        controller.applyDrag(deltaX: 0, deltaY: 10_000)
        XCTAssertEqual(controller.pitch, .pi / 2, accuracy: 1e-6)
        controller.applyDrag(deltaX: 0, deltaY: -20_000)
        XCTAssertEqual(controller.pitch, -.pi / 2, accuracy: 1e-6)
    }
}
