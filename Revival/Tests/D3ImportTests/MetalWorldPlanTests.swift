import XCTest

final class MetalWorldPlanTests: XCTestCase {
    func testScript058MarkerDistanceLightsReachedMetalWorld() throws {
        var level = makeTrainingCameraMonitorLevel()
        let playerView = defaultPlayerView(in: level)
        let markerHandle = try XCTUnwrap(
            level.trainingCameraMonitorChain?.returnToShip?
                .markerLightObjectHandle
        )
        let markerIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == markerHandle
        })
        let initial = try makeMetalWorldPlan(
            level: level,
            playerView: playerView
        )
        let target = try XCTUnwrap(
            initial.draws.first?.vertices.first?.position
        )
        level.objects[markerIndex].location =
            .room(playerView.roomSourceIndex)
        level.objects[markerIndex].position = .init(
            x: target.x + 20,
            y: target.y,
            z: target.z
        )
        let fullyLit = try updateMetalWorldPlan(
            initial,
            level: level,
            playerView: playerView,
            presentationFrame: .init(
                systemsFrameDuration: 0.1,
                systemsGameTime: 0.5
            ),
            trainingGuidebotReturnMarkerLightDistance: 50
        )
        let pulseFloor = try updateMetalWorldPlan(
            fullyLit,
            level: level,
            playerView: playerView,
            presentationFrame: .init(
                systemsFrameDuration: 0.1,
                systemsGameTime: 1
            ),
            trainingGuidebotReturnMarkerLightDistance: 50
        )

        XCTAssertGreaterThan(
            fullyLit.draws[0].vertices[0].dynamicLight.x,
            0
        )
        XCTAssertEqual(
            pulseFloor.draws[0].vertices[0].dynamicLight,
            .zero
        )
    }

    func testScript058MarkerPulseRefreshesAuxiliaryOnlyRoomDraws()
        throws
    {
        var level = makeTrainingCameraMonitorLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(at: 0.1, input: .zero)
        let used = simulation.update(
            at: 0.2,
            input: .init(usesInventory: true)
        )
        let playerView = used.playerView
        let monitor = try XCTUnwrap(used.trainingCameraMonitor)
        let initial = try makeMetalWorldPlan(
            level: level,
            playerView: playerView
        )
        let auxiliaryBaseline = try updateMetalWorldPlan(
            initial,
            level: level,
            playerView: playerView,
            trainingCameraMonitor: monitor
        )
        let auxiliaryOnlyIndex = try XCTUnwrap(
            auxiliaryBaseline.auxiliaryActiveDrawIndices.first {
                !auxiliaryBaseline.activeDrawIndices.contains($0)
                    && auxiliaryBaseline.preparedDraws[$0]
                        .objectHandle == nil
            }
        )
        let target = try XCTUnwrap(
            auxiliaryBaseline.preparedDraws[auxiliaryOnlyIndex]
                .vertices.first?.position
        )
        let markerHandle = try XCTUnwrap(
            level.trainingCameraMonitorChain?.returnToShip?
                .markerLightObjectHandle
        )
        let markerIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == markerHandle
        })
        level.objects[markerIndex].position = .init(
            x: target.x + 20,
            y: target.y,
            z: target.z
        )
        let fullyLit = try updateMetalWorldPlan(
            auxiliaryBaseline,
            level: level,
            playerView: playerView,
            presentationFrame: .init(
                systemsFrameDuration: 0.1,
                systemsGameTime: 0.5
            ),
            trainingCameraMonitor: monitor,
            trainingGuidebotReturnMarkerLightDistance: 50
        )
        let pulseFloor = try updateMetalWorldPlan(
            fullyLit,
            level: level,
            playerView: playerView,
            presentationFrame: .init(
                systemsFrameDuration: 0.1,
                systemsGameTime: 1
            ),
            trainingCameraMonitor: monitor,
            trainingGuidebotReturnMarkerLightDistance: 50
        )

        XCTAssertGreaterThan(
            fullyLit.preparedDraws[auxiliaryOnlyIndex]
                .vertices[0].dynamicLight.x,
            0
        )
        XCTAssertEqual(
            pulseFloor.preparedDraws[auxiliaryOnlyIndex]
                .vertices[0].dynamicLight,
            .zero
        )
    }

    func testCameraMonitorUsesSourceLeftBiggerPopupViewport() {
        let viewport = cameraMonitorMetalViewport(
            drawableWidth: 1_200,
            drawableHeight: 900
        )

        XCTAssertEqual(viewport.originX, 59.375)
        XCTAssertEqual(viewport.originY, 609.375)
        XCTAssertEqual(viewport.width, 281.25)
        XCTAssertEqual(viewport.height, 281.25)
    }

    func testCameraMonitorUsesRetainedWorldPlanForItsSecurityCamera() throws {
        let level = makeTrainingCameraMonitorLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(at: 0.1, input: .zero)
        let used = simulation.update(
            at: 0.2,
            input: .init(usesInventory: true)
        )
        let initial = try makeMetalWorldPlan(
            level: level,
            playerView: defaultPlayerView(in: level)
        )

        let updated = try updateMetalWorldPlan(
            initial,
            level: simulation.level,
            playerView: used.playerView,
            trainingCameraMonitor: used.trainingCameraMonitor
        )

        XCTAssertEqual(
            updated.auxiliaryCamera,
            used.trainingCameraMonitor?.camera
        )
        XCTAssertEqual(
            updated.auxiliaryStartRoomSourceIndex,
            used.trainingCameraMonitor?.roomSourceIndex
        )
        XCTAssertFalse(updated.auxiliaryDraws.isEmpty)
        XCTAssertEqual(
            updated.auxiliaryActiveDrawIndices.map {
                updated.preparedDraws[$0]
            },
            updated.auxiliaryDraws
        )
    }

    func testCameraMonitorIncludesPlayerShipOutsidePrimaryFirstPersonView() throws {
        let level = makeTrainingCameraMonitorLevel()
        let playerView = defaultPlayerView(in: level)
        let player = try XCTUnwrap(level.objects.first {
            $0.handle == playerView.objectHandle
        })
        let initial = try makeMetalWorldPlan(
            level: level,
            playerView: playerView
        )
        let monitor = TrainingCameraMonitorFrame(
            camera: RoomCamera(
                position: .init(
                    x:
                        player.position.x
                        - player.orientation.forward.x * 20,
                    y:
                        player.position.y
                        - player.orientation.forward.y * 20,
                    z:
                        player.position.z
                        - player.orientation.forward.z * 20
                ),
                target: player.position,
                up: player.orientation.up
            ),
            roomSourceIndex: playerView.roomSourceIndex,
            remainingDuration: 10
        )

        let updated = try updateMetalWorldPlan(
            initial,
            level: level,
            playerView: playerView,
            trainingCameraMonitor: monitor
        )

        XCTAssertFalse(updated.draws.contains {
            $0.objectHandle == playerView.objectHandle
        })
        XCTAssertTrue(updated.auxiliaryDraws.contains {
            $0.objectHandle == playerView.objectHandle
        })
    }

    func testCameraMonitorRefreshesPlayerVisibleOnlyToAuxiliaryCamera() throws {
        var level = makeTrainingCameraMonitorLevel()
        let initialPlayerView = defaultPlayerView(in: level)
        let initial = try makeMetalWorldPlan(
            level: level,
            playerView: initialPlayerView
        )
        let initialPlayerDraw = try XCTUnwrap(
            initial.preparedDraws.first {
                $0.objectHandle == initialPlayerView.objectHandle
            }
        )
        let playerIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == initialPlayerView.objectHandle
        })
        let oldPosition = level.objects[playerIndex].position
        level.objects[playerIndex].position = .init(
            x: oldPosition.x + 5,
            y: oldPosition.y,
            z: oldPosition.z
        )
        let movedPlayerView = defaultPlayerView(in: level)
        let movedPlayer = level.objects[playerIndex]
        let monitor = TrainingCameraMonitorFrame(
            camera: RoomCamera(
                position: .init(
                    x:
                        movedPlayer.position.x
                        - movedPlayer.orientation.forward.x * 20,
                    y:
                        movedPlayer.position.y
                        - movedPlayer.orientation.forward.y * 20,
                    z:
                        movedPlayer.position.z
                        - movedPlayer.orientation.forward.z * 20
                ),
                target: movedPlayer.position,
                up: movedPlayer.orientation.up
            ),
            roomSourceIndex: movedPlayerView.roomSourceIndex,
            remainingDuration: 10
        )

        let updated = try updateMetalWorldPlan(
            initial,
            level: level,
            playerView: movedPlayerView,
            trainingCameraMonitor: monitor
        )
        let auxiliaryPlayerDraw = try XCTUnwrap(
            updated.auxiliaryDraws.first {
                $0.objectHandle == movedPlayerView.objectHandle
            }
        )
        let freshAuxiliary = try makeMetalWorldPlan(
            level: level,
            camera: monitor.camera,
            startRoomSourceIndex: monitor.roomSourceIndex
        )
        let freshPlayerDraw = try XCTUnwrap(freshAuxiliary.draws.first {
            $0.objectHandle == movedPlayerView.objectHandle
        })

        XCTAssertNotEqual(auxiliaryPlayerDraw.vertices, initialPlayerDraw.vertices)
        XCTAssertEqual(auxiliaryPlayerDraw, freshPlayerDraw)
    }

    func testCameraMonitorKeepsFacingGeometryDistinctForBothViews() throws {
        let level = makeTrainingCameraMonitorLevel()
        let playerView = defaultPlayerView(in: level)
        let player = try XCTUnwrap(level.objects.first {
            $0.handle == playerView.objectHandle
        })
        let monitor = TrainingCameraMonitorFrame(
            camera: RoomCamera(
                position: .init(
                    x: player.position.x + player.orientation.right.x * 20,
                    y: player.position.y + player.orientation.right.y * 20,
                    z: player.position.z + player.orientation.right.z * 20
                ),
                target: player.position,
                up: player.orientation.up
            ),
            roomSourceIndex: playerView.roomSourceIndex,
            remainingDuration: 10
        )
        let initial = try makeMetalWorldPlan(
            level: level,
            playerView: playerView
        )

        let updated = try updateMetalWorldPlan(
            initial,
            level: level,
            playerView: playerView,
            trainingCameraMonitor: monitor
        )
        let auxiliaryFacingHandles = Set(
            updated.auxiliaryDraws
                .filter { $0.submodelIndex == 3 }
                .compactMap(\.objectHandle)
        )
        let primaryFacing = try XCTUnwrap(updated.draws.first {
            $0.submodelIndex == 3
                && $0.objectHandle.map(auxiliaryFacingHandles.contains) == true
        })
        let objectHandle = primaryFacing.objectHandle
        let model = primaryFacing.model
        let submodelIndex = primaryFacing.submodelIndex
        let faceIndex = primaryFacing.faceIndex
        let auxiliaryFacing = try XCTUnwrap(
            updated.auxiliaryDraws.first {
                $0.objectHandle == objectHandle
                    && $0.model == model
                    && $0.submodelIndex == submodelIndex
                    && $0.faceIndex == faceIndex
            }
        )
        XCTAssertNotEqual(
            primaryFacing.vertices,
            auxiliaryFacing.vertices
        )
    }

    func testUsesPerDrawLocalCoronaIndicesWithOffsetVertexBindings() {
        XCTAssertEqual(
            makeMetalLightCoronaIndices(drawCapacity: 3),
            [
                0, 1, 2, 0, 2, 3,
                0, 1, 2, 0, 2, 3,
                0, 1, 2, 0, 2, 3,
            ]
        )
    }

    func testSchedulesCoronaWithOldDeltaDrawThenPostUpdateAndFadeLifetime() throws {
        let level = makeCoronaEvaluationLevel()
        let camera = RoomCamera(
            position: .init(x: 0, y: -100, z: 0),
            target: .init(x: 0, y: -99, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        let initial = try makeMetalWorldPlan(
            level: level,
            camera: camera,
            startRoomSourceIndex: 3
        )
        XCTAssertEqual(initial.lightCoronaStates.map(\.scalar), [0])
        XCTAssertEqual(initial.lightCoronaDraws.map(\.opacity), [0])

        let fullScalar = try updateMetalWorldPlan(
            initial,
            camera: camera,
            presentationFrame: .init(
                systemsFrameDuration: 0.25,
                systemsGameTime: 0
            )
        )
        let clamped = try updateMetalWorldPlan(
            fullScalar,
            camera: camera,
            presentationFrame: .init(
                systemsFrameDuration: 0,
                systemsGameTime: 0
            )
        )
        XCTAssertEqual(
            try XCTUnwrap(clamped.lightCoronaDraws.first).opacity,
            102.0 / 255.0,
            accuracy: 0.000_001
        )

        let interiorCamera = RoomCamera(
            position: .init(x: 0, y: -19, z: 0),
            target: .init(x: 0, y: -18, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        let interior = try updateMetalWorldPlan(
            fullScalar,
            camera: interiorCamera,
            presentationFrame: .init(
                systemsFrameDuration: 0,
                systemsGameTime: 0
            )
        )
        let interiorCorona = try XCTUnwrap(
            fullScalar.lightCoronaStates.first
        ).corona
        let toEye = Vector3(
            x: interiorCamera.position.x - interiorCorona.firstVertex.x,
            y: interiorCamera.position.y - interiorCorona.firstVertex.y,
            z: interiorCamera.position.z - interiorCorona.firstVertex.z
        )
        let toEyeSquared = toEye.x * toEye.x
            + toEye.y * toEye.y
            + toEye.z * toEye.z
        let toEyeLength = sqrt(toEyeSquared)
        let facingDot = toEye.x * interiorCorona.normal.x
            + toEye.y * interiorCorona.normal.y
            + toEye.z * interiorCorona.normal.z
        let expectedInteriorFacing = 2 * facingDot / toEyeLength
        let offset = Vector3(
            x: interiorCorona.center.x - interiorCamera.position.x,
            y: interiorCorona.center.y - interiorCamera.position.y,
            z: interiorCorona.center.z - interiorCamera.position.z
        )
        let distanceSquared = offset.x * offset.x
            + offset.y * offset.y
            + offset.z * offset.z
        let interiorDistance = sqrt(distanceSquared)
        let expectedInteriorFade = (
            interiorDistance - interiorCorona.size * 5
        ) / (interiorCorona.size * 15)
        XCTAssertEqual(
            try XCTUnwrap(interior.lightCoronaDraws.first).opacity,
            expectedInteriorFacing * expectedInteriorFade * (102.0 / 255.0),
            accuracy: 0.000_001
        )

        let first = try updateMetalWorldPlan(
            initial,
            camera: camera,
            presentationFrame: .init(
                systemsFrameDuration: 0.1,
                systemsGameTime: 0
            )
        )
        XCTAssertEqual(first.lightCoronaDraws.map(\.opacity), [0])
        XCTAssertEqual(first.lightCoronaStates.map(\.scalar), [0.4])
        XCTAssertEqual(first.presentationVisualTick, 0)

        let second = try updateMetalWorldPlan(
            first,
            camera: camera,
            presentationFrame: .init(
                systemsFrameDuration: 0.016,
                systemsGameTime: 0.016
            )
        )
        XCTAssertGreaterThan(try XCTUnwrap(second.lightCoronaDraws.first).opacity, 0)
        XCTAssertEqual(
            try XCTUnwrap(second.lightCoronaStates.first).scalar,
            0.464,
            accuracy: 0.000_001
        )
        let expectedFacing = 2 * 121 / sqrt(Float(121 * 121 + 2))
        XCTAssertEqual(
            try XCTUnwrap(second.lightCoronaDraws.first).opacity,
            min(expectedFacing * 0.4, 1) * (102.0 / 255.0),
            accuracy: 0.000_001
        )
        XCTAssertEqual(second.presentationVisualTick, 0)

        let nearCamera = RoomCamera(
            position: .init(x: 0, y: 1, z: 0),
            target: .init(x: 0, y: 2, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        let fading = try updateMetalWorldPlan(
            second,
            camera: nearCamera,
            presentationFrame: .init(
                systemsFrameDuration: 0.1,
                systemsGameTime: 1.0 / 60
            )
        )
        XCTAssertEqual(fading.lightCoronaDraws.count, 1)
        XCTAssertEqual(try XCTUnwrap(fading.lightCoronaDraws.first).opacity, 0)
        XCTAssertEqual(
            try XCTUnwrap(fading.lightCoronaStates.first).scalar,
            0.064,
            accuracy: 0.000_001
        )
        XCTAssertEqual(fading.presentationVisualTick, 1)

        let retainedAtZero = try updateMetalWorldPlan(
            fading,
            camera: nearCamera,
            presentationFrame: .init(
                systemsFrameDuration: 0.016,
                systemsGameTime: 2.0 / 60
            )
        )
        XCTAssertEqual(retainedAtZero.lightCoronaDraws.count, 1)
        XCTAssertEqual(try XCTUnwrap(retainedAtZero.lightCoronaDraws.first).opacity, 0)
        XCTAssertEqual(
            try XCTUnwrap(retainedAtZero.lightCoronaStates.first).scalar,
            0,
            accuracy: 0.000_001
        )

        let removedAfterZeroDraw = try updateMetalWorldPlan(
            retainedAtZero,
            camera: nearCamera,
            presentationFrame: .init(
                systemsFrameDuration: 0.001,
                systemsGameTime: 3.0 / 60
            )
        )
        XCTAssertEqual(removedAfterZeroDraw.lightCoronaDraws.count, 1)
        XCTAssertTrue(removedAfterZeroDraw.lightCoronaStates.isEmpty)

        let absent = try updateMetalWorldPlan(
            removedAfterZeroDraw,
            camera: nearCamera,
            presentationFrame: .init(
                systemsFrameDuration: 0.001,
                systemsGameTime: 4.0 / 60
            )
        )
        XCTAssertTrue(absent.lightCoronaDraws.isEmpty)
        XCTAssertTrue(absent.lightCoronaStates.isEmpty)
    }

    func testBuildsCameraFacingTintedCoronaVerticesForTheSharedWorldPass() throws {
        let level = makeCoronaEvaluationLevel()
        let camera = RoomCamera(
            position: .zero,
            target: .init(x: 0, y: 1, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        let corona = try XCTUnwrap(
            try makeMetalWorldPlan(
                level: level,
                camera: camera,
                startRoomSourceIndex: 3
            ).preparedLightCoronaCandidates.first
        )

        let vertices = makeMetalLightCoronaVertices(
            corona,
            camera: camera,
            imageWidth: 2,
            imageHeight: 1,
            opacity: 0.25
        )

        XCTAssertEqual(vertices.count, 4)
        XCTAssertEqual(vertices.map(\.textureAndLightmapUV), [
            .init(0, 0, 0, 0),
            .init(1, 0, 0, 0),
            .init(1, 1, 0, 0),
            .init(0, 1, 0, 0),
        ])
        XCTAssertTrue(vertices.allSatisfy {
            $0.presentation == .init(0.25, 0, 1, 0)
                && $0.surfaceColor == .init(0.25, 0.5, 0.75, 0)
        })
        XCTAssertEqual(vertices[0].position.x, -4, accuracy: 0.000_001)
        XCTAssertEqual(vertices[0].position.z, 2, accuracy: 0.000_001)
        XCTAssertEqual(vertices[2].position.x, 4, accuracy: 0.000_001)
        XCTAssertEqual(vertices[2].position.z, -2, accuracy: 0.000_001)
    }

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

        XCTAssertEqual(
            updated.preparedDraws.map(\.indices),
            initial.preparedDraws.map(\.indices)
        )
        XCTAssertNotEqual(updated.camera, initial.camera)
        XCTAssertEqual(
            updated.activeDrawIndices.map { updated.preparedDraws[$0] },
            updated.draws
        )
        XCTAssertFalse(updated.draws.contains {
            $0.objectHandle == frame.playerView.objectHandle
        })
    }

    func testUpdatesReachedRotatingSubmodelFromPreUpdateGameTime() throws {
        let level = makeSliceSixObjectRenderLevel()
        let initial = try makeMetalWorldPlan(
            level: level,
            camera: .trainingRoom3,
            startRoomSourceIndex: 3
        )
        let before = try XCTUnwrap(initial.preparedDraws.first {
            $0.objectHandle == 6_147 && $0.submodelIndex == 4
        })

        let updated = try updateMetalWorldPlan(
            initial,
            camera: .trainingRoom3,
            presentationFrame: .init(
                systemsFrameDuration: 0.016,
                systemsGameTime: 0.25
            )
        )
        let after = try XCTUnwrap(updated.preparedDraws.first {
            $0.objectHandle == 6_147 && $0.submodelIndex == 4
        })

        XCTAssertNotEqual(after.vertices, before.vertices)
        XCTAssertEqual(
            after.vertices[0].position.x,
            2_064.0604,
            accuracy: 0.001
        )
        XCTAssertEqual(
            after.vertices[0].position.z,
            2_208.0276,
            accuracy: 0.001
        )
        XCTAssertEqual(
            updated.activeDrawIndices.map { updated.preparedDraws[$0] },
            updated.draws
        )
    }

    func testF4ActivatesReservedGuidebotDrawInTheRetainedPlan() throws {
        let level = makeTrainingRobotGuidebotLevel()
        let playerView = defaultPlayerView(in: level)
        let initial = try makeMetalWorldPlan(
            level: level,
            playerView: playerView
        )
        let guidebotHandle: UInt32 = 6_164
        XCTAssertTrue(initial.preparedDraws.contains {
            $0.objectHandle == guidebotHandle
        })
        XCTAssertFalse(initial.draws.contains {
            $0.objectHandle == guidebotHandle
        })

        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        let frame = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        let updated = try updateMetalWorldPlan(
            initial,
            level: simulation.level,
            playerView: frame.playerView
        )

        XCTAssertTrue(updated.draws.contains {
            $0.objectHandle == guidebotHandle
        })
        XCTAssertEqual(
            updated.activeDrawIndices.map { updated.preparedDraws[$0] },
            updated.draws
        )
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

        XCTAssertEqual(
            updated.preparedDraws.map(\.indices),
            initial.preparedDraws.map(\.indices)
        )
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
        XCTAssertEqual(
            resized.preparedDraws.map(\.indices),
            initial.preparedDraws.map(\.indices)
        )
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
        var seenObjectHandles: Set<UInt32> = []
        XCTAssertEqual(
            objectDraws.compactMap(\.objectHandle).filter {
                seenObjectHandles.insert($0).inserted
            },
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
