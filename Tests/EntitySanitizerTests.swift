import XCTest
import RealityKit

final class EntitySanitizerTests: XCTestCase {

    @MainActor
    func testRemovesNestedCameraComponents() {
        let root = Entity()
        let child = Entity()
        let grandchild = Entity()
        grandchild.components.set(PerspectiveCameraComponent())
        child.addChild(grandchild)
        child.components.set(OrthographicCameraComponent())
        root.addChild(child)

        removeCameras(from: root)

        XCTAssertFalse(child.components.has(OrthographicCameraComponent.self))
        XCTAssertFalse(grandchild.components.has(PerspectiveCameraComponent.self))
    }

    @MainActor
    func testEntityWithoutCamerasIsUntouched() {
        let root = Entity()
        let child = Entity()
        root.addChild(child)

        removeCameras(from: root)

        XCTAssertEqual(root.children.count, 1)
    }
}
