import XCTest

final class EntityFramingTests: XCTestCase {

    func testUnitCubeAtOriginIsIdentity() {
        let t = framingTransform(center: .zero, extents: SIMD3<Float>(1, 1, 1))
        XCTAssertEqual(t.scale, 1.0, accuracy: 1e-6)
        XCTAssertEqual(t.translation, SIMD3<Float>(0, 0, 0))
    }

    func testOffsetLargeModelIsCenteredAndScaled() {
        // 中心 (10,20,30)・最大辺 4 → scale 0.25、中心が原点に移動
        let t = framingTransform(center: SIMD3<Float>(10, 20, 30), extents: SIMD3<Float>(4, 2, 1))
        XCTAssertEqual(t.scale, 0.25, accuracy: 1e-6)
        XCTAssertEqual(t.translation.x, -2.5, accuracy: 1e-6)
        XCTAssertEqual(t.translation.y, -5.0, accuracy: 1e-6)
        XCTAssertEqual(t.translation.z, -7.5, accuracy: 1e-6)
    }

    func testZeroExtentDoesNotDivideByZero() {
        // 空シーン/点のみ: scale 1 で中心移動のみ
        let t = framingTransform(center: SIMD3<Float>(1, 1, 1), extents: .zero)
        XCTAssertEqual(t.scale, 1.0)
        XCTAssertEqual(t.translation, SIMD3<Float>(-1, -1, -1))
    }
}
