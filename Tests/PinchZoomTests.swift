import XCTest
import RealityKit

final class PinchZoomTests: XCTestCase {

    @MainActor
    func testMagnificationAccumulates() {
        let controller = PinchZoomController()
        controller.applyMagnification(delta: 1.0) // 1.0 * 2.0
        XCTAssertEqual(controller.zoom, 2.0, accuracy: 1e-6)
        XCTAssertEqual(controller.root.scale.x, 2.0, accuracy: 1e-6)
    }

    @MainActor
    func testZoomClampsToLowerBound() {
        let controller = PinchZoomController()
        controller.applyMagnification(delta: -10.0) // 負スケールにならず 0.1 に張り付く
        XCTAssertEqual(controller.zoom, 0.1, accuracy: 1e-6)
    }

    @MainActor
    func testZoomClampsToUpperBound() {
        let controller = PinchZoomController()
        for _ in 0..<100 { controller.applyMagnification(delta: 1.0) }
        XCTAssertEqual(controller.zoom, 20.0, accuracy: 1e-6)
    }
}
