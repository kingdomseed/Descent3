import XCTest

final class MetalWorldPlanTests: XCTestCase {
    func testBuildsTheSourceOrderedRoomThreeMetalPlanFromTypedPresentationValues() throws {
        let plan = try makeMetalWorldPlan(
            level: makeSelectedRoomRenderLevel(),
            camera: .init(
                position: .zero,
                target: .init(x: 0, y: 1, z: 0),
                up: .init(x: 0, y: 0, z: 1)
            ),
            startRoomSourceIndex: 3
        )

        XCTAssertEqual(plan.visibleRoomSourceIndices, [3, 2, 1])
        XCTAssertEqual(
            plan.draws.map { "\($0.roomSourceIndex):\($0.faceIndex)" },
            ["1:1", "2:0", "3:0"]
        )
        XCTAssertEqual(plan.draws.map(\.blend), [
            .opaque,
            .additiveSourceAlpha(opacity: 178),
            .additiveSourceAlpha(opacity: 178),
        ])

        let forceField = try XCTUnwrap(plan.draws.last)
        XCTAssertEqual(forceField.vertices.count, 4)
        XCTAssertEqual(forceField.indices, [0, 1, 2, 0, 2, 3])
        XCTAssertEqual(
            forceField.vertices[0].textureAndLightmapUV,
            SIMD4<Float>(1, 1, 0, 0)
        )
        XCTAssertEqual(
            forceField.vertices[0].presentation.x,
            Float(178) / 255,
            accuracy: 0.000_001
        )
        XCTAssertEqual(forceField.vertices[0].presentation.y, 1, accuracy: 0.000_001)
        XCTAssertNil(forceField.lightmapPageIndex)
    }
}
