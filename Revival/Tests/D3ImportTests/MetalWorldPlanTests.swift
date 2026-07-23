import XCTest

final class MetalWorldPlanTests: XCTestCase {
    func testUpdatesPlayerCameraAndActiveDrawsWithoutReplacingPreparedPresentation() throws {
        let level = makeSliceSixObjectRenderLevel()
        let initialView = defaultPlayerView(in: level)
        let initial = try makeMetalWorldPlan(level: level, playerView: initialView)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        let frame = simulation.update(
            at: 0.016,
            input: .init(forward: 1, sideways: 1)
        )

        let updated = try updateMetalWorldPlan(
            initial,
            level: simulation.level,
            playerView: frame.playerView
        )

        XCTAssertEqual(updated.preparedDraws, initial.preparedDraws)
        XCTAssertNotEqual(updated.camera, initial.camera)
        XCTAssertEqual(
            updated.activeDrawIndices.map { updated.preparedDraws[$0] },
            updated.draws
        )
        XCTAssertFalse(updated.draws.contains {
            $0.objectHandle == frame.playerView.objectHandle
        })
    }

    func testDynamicPlanMatchesFreshVisibilityAdmissionBackfaceAndLODSelection() throws {
        var level = makeSliceSixObjectRenderLevel()
        let initialView = defaultPlayerView(in: level)
        let initial = try makeMetalWorldPlan(level: level, playerView: initialView)
        let playerIndex = level.objects.firstIndex {
            $0.handle == initialView.objectHandle
        }!
        level.objects[playerIndex].location = .room(3)
        level.objects[playerIndex].position = RoomCamera.trainingRoom3.position
        level.objects[playerIndex].orientation = .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 0, z: 1),
            forward: .init(x: 0, y: 1, z: 0)
        )
        let movedView = defaultPlayerView(in: level)

        let updated = try updateMetalWorldPlan(
            initial,
            level: level,
            playerView: movedView
        )
        let fresh = try makeMetalWorldPlan(level: level, playerView: movedView)

        XCTAssertEqual(updated.preparedDraws, initial.preparedDraws)
        XCTAssertNotEqual(updated.visibleRoomSourceIndices, initial.visibleRoomSourceIndices)
        XCTAssertNotEqual(updated.activeDrawIndices, initial.activeDrawIndices)
        XCTAssertEqual(updated.visibleRoomSourceIndices, fresh.visibleRoomSourceIndices)
        XCTAssertEqual(updated.activeDrawIndices, fresh.activeDrawIndices)
        XCTAssertEqual(updated.draws, fresh.draws)
    }

    func testResizeRecomputesRetainedPlanFromCurrentDrawableAspect() throws {
        let level = makeSliceSixObjectRenderLevel()
        let initialView = defaultPlayerView(in: level)
        let initial = try makeMetalWorldPlan(level: level, playerView: initialView)
        let resizedCamera = RoomCamera(
            position: initial.camera.position,
            target: initial.camera.target,
            up: initial.camera.up,
            projection: initial.camera.projection.withAspectRatio(16.0 / 9.0)
        )

        let resized = try updateMetalWorldPlan(
            initial,
            camera: resizedCamera
        )

        XCTAssertEqual(resized.camera, resizedCamera)
        XCTAssertEqual(resized.preparedDraws, initial.preparedDraws)
        XCTAssertEqual(
            resized.activeDrawIndices.map { resized.preparedDraws[$0] },
            resized.draws
        )
        XCTAssertFalse(resized.draws.contains {
            $0.objectHandle == initialView.objectHandle
        })
    }

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
