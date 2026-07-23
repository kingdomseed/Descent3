import XCTest

final class MetalWorldPlanTests: XCTestCase {
    func testAddsObjectModelsToTheOneWorldPlanWithTypedMaterials() throws {
        let plan = try makeMetalWorldPlan(
            level: makeSliceSixObjectRenderLevel(),
            camera: .trainingRoom3,
            startRoomSourceIndex: 3
        )

        let objectDraws = plan.draws.filter { $0.objectHandle != nil }
        XCTAssertEqual(
            objectDraws.compactMap(\.objectHandle),
            [18_441, 2_048, 12_300, 6_147]
        )
        let player = try XCTUnwrap(objectDraws.first { $0.objectHandle == 2_048 })
        XCTAssertEqual(player.model?.sourceName, "PyroGLMed.OOF")
        XCTAssertEqual(player.texture?.sourceName, "model-surface")
        XCTAssertEqual(player.blend, .sourceAlpha(opacity: 255))
        XCTAssertTrue(player.writesDepth)
        XCTAssertEqual(player.vertices[0].position.x, 2_058.6497, accuracy: 0.0002)

        let startCourse = try XCTUnwrap(
            objectDraws.first { $0.objectHandle == 6_147 }
        )
        XCTAssertNil(startCourse.texture)
        XCTAssertEqual(
            startCourse.sourceColor,
            SIMD3<Float>(32.0 / 255, 64.0 / 255, 96.0 / 255)
        )
        XCTAssertEqual(startCourse.vertices[0].surfaceColor.w, 1)
    }

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
        XCTAssertGreaterThan(plan.preparedDraws.count, plan.draws.count)
        XCTAssertEqual(
            plan.activeDrawIndices.map { plan.preparedDraws[$0] },
            plan.draws
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
