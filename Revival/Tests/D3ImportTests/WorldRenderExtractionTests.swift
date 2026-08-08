import XCTest

extension WorldRenderingTests {
    func testDefaultPlayerViewDerivesCanonicalPoseRadiusAndExcludesViewer() throws {
        let level = makeSliceSixObjectRenderLevel()
        let view = defaultPlayerView(in: level)

        XCTAssertEqual(view.playerID, 0)
        XCTAssertEqual(view.objectHandle, 2_048)
        XCTAssertEqual(view.roomSourceIndex, 1)
        XCTAssertEqual(
            view.camera.position,
            .init(x: 2_060.6497, y: -131.22517, z: 2_204.4216)
        )
        XCTAssertEqual(
            view.camera.target,
            .init(x: 2_060.6497, y: -131.22517, z: 2_205.4216)
        )
        XCTAssertEqual(view.camera.up, .init(x: 0, y: 1, z: 0))
        XCTAssertEqual(
            view.collisionRadius,
            level.shipDefinitions[0].presentationSize * 0.8
        )

        let extraction = try extractWorldForRendering(level, playerView: view)
        XCTAssertEqual(extraction.admittedObjectHandles, [12_301, 12_300])
        XCTAssertFalse(extraction.admittedObjectHandles.contains(view.objectHandle))

        let plan = try makeMetalWorldPlan(level: level, playerView: view)
        XCTAssertEqual(plan.camera, view.camera)
        XCTAssertGreaterThan(plan.preparedDraws.count, plan.draws.count)
        XCTAssertEqual(
            plan.activeDrawIndices.map { plan.preparedDraws[$0] },
            plan.draws
        )
        XCTAssertFalse(plan.draws.contains { $0.objectHandle == view.objectHandle })
    }

    func testSourceProjectionPreservesVerticalFramingAcrossFullDrawableAspect() {
        let fourByThree = PerspectiveProjection.sourceDefault
        let wide = fourByThree.withAspectRatio(16.0 / 9.0)
        let fourByThreeVerticalScale =
            (1 / tan(fourByThree.horizontalFieldOfViewRadians / 2))
            * fourByThree.aspectRatio
        let wideVerticalScale =
            (1 / tan(wide.horizontalFieldOfViewRadians / 2))
            * wide.aspectRatio
        XCTAssertEqual(
            fourByThree.horizontalFieldOfViewRadians,
            3.14 * 72 / 180,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            wideVerticalScale,
            fourByThreeVerticalScale,
            accuracy: 0.000_001
        )
        XCTAssertLessThan(
            1 / tan(wide.horizontalFieldOfViewRadians / 2),
            1 / tan(fourByThree.horizontalFieldOfViewRadians / 2)
        )

        let portrait = fullDrawableMetalViewport(
            drawableWidth: 1_170,
            drawableHeight: 2_532
        )
        XCTAssertEqual(portrait.originX, 0)
        XCTAssertEqual(portrait.originY, 0)
        XCTAssertEqual(portrait.width, 1_170)
        XCTAssertEqual(portrait.height, 2_532)

        let landscape = fullDrawableMetalViewport(
            drawableWidth: 2_360,
            drawableHeight: 1_640
        )
        XCTAssertEqual(landscape.originX, 0)
        XCTAssertEqual(landscape.originY, 0)
        XCTAssertEqual(landscape.width, 2_360)
        XCTAssertEqual(landscape.height, 1_640)
    }

    func testRoomThreeConvexShellContainmentAcceptsItsBoundaryAndRejectsPastIt() {
        let center = RoomCamera.trainingRoom3.position
        let room = makeSourceContainmentRoom(
            center: center,
            texture: .init(storedIndex: 0, sourceName: "wall")
        )

        XCTAssertTrue(
            sourceRoomThreeContains(
                .init(x: center.x - 0.5, y: center.y, z: center.z),
                in: room
            )
        )
        XCTAssertTrue(
            sourceRoomThreeContains(
                .init(x: center.x, y: center.y + 1, z: center.z),
                in: room
            )
        )
        XCTAssertFalse(
            sourceRoomThreeContains(
                .init(x: center.x, y: center.y + 1.25, z: center.z),
                in: room
            )
        )
    }

    func testEvaluatesTypedCoronaNearCutoffAndRenderedPortalOcclusion() throws {
        let camera = RoomCamera(
            position: .zero,
            target: .init(x: 0, y: 1, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        let visible = try extractWorldForRendering(
            makeCoronaEvaluationLevel(blocked: false),
            camera: camera,
            startRoomSourceIndex: 3
        )
        let corona = try XCTUnwrap(visible.lightCoronas.only)
        XCTAssertEqual(corona.roomSourceIndex, 3)
        XCTAssertEqual(corona.faceIndex, 0)
        XCTAssertEqual(corona.assetIndex, 0)
        XCTAssertEqual(corona.size, 4, accuracy: 0.000_001)
        XCTAssertEqual(corona.center, .init(x: 0, y: 20.75, z: 0))
        XCTAssertEqual(corona.tint, .init(x: 0.25, y: 0.5, z: 0.75))
        XCTAssertEqual(corona.blend, .additiveSourceAlpha(opacity: 102))
        let plan = try makeMetalWorldPlan(
            level: makeCoronaEvaluationLevel(blocked: false),
            camera: camera,
            startRoomSourceIndex: 3
        )
        XCTAssertEqual(plan.preparedLightCoronaCandidates, [corona])
        XCTAssertEqual(
            plan.draws.count,
            visible.opaqueDrawItems.count
                + visible.modelDrawItems.count
                + visible.translucentDrawItems.count
        )

        let nearCamera = RoomCamera(
            position: .init(x: 0, y: 1, z: 0),
            target: .init(x: 0, y: 2, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        XCTAssertTrue(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(blocked: false),
                camera: nearCamera,
                startRoomSourceIndex: 3
            ).lightCoronas.isEmpty
        )
        XCTAssertTrue(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(blocked: true),
                camera: camera,
                startRoomSourceIndex: 3
            ).lightCoronas.isEmpty
        )
        XCTAssertTrue(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(objectBlocked: true),
                camera: camera,
                startRoomSourceIndex: 3
            ).lightCoronas.isEmpty
        )
        XCTAssertEqual(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(objectBlocked: true),
                camera: camera,
                startRoomSourceIndex: 3,
                excludedObjectHandle: 99
            ).lightCoronas.count,
            1
        )
    }

    func testHiddenObjectPresentationDoesNotOccludeTypedCorona() throws {
        let camera = RoomCamera(
            position: .zero,
            target: .init(x: 0, y: 1, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )

        XCTAssertEqual(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(
                    objectBlocked: true,
                    objectPresentationVisible: false
                ),
                camera: camera,
                startRoomSourceIndex: 3
            ).lightCoronas.count,
            1
        )
    }

    func testEvaluatesTypedWaterOnTheSimulationOwnedSixtyHertzVisualTick() throws {
        var base = Data()
        base.reserveCapacity(128 * 128 * 4)
        for y in 0..<128 {
            for x in 0..<128 {
                base.append(UInt8(x))
                base.append(UInt8(y))
                base.append(UInt8(x ^ y))
                base.append(UInt8((x + y) & 0xff))
            }
        }
        var evaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )

        let frame0 = evaluator.rgba8(visualTick: 0)
        XCTAssertEqual(
            evaluator.rgba8(visualTick: 0),
            frame0
        )
        let frame1 = evaluator.rgba8(visualTick: 1)
        var frame15 = frame1
        for frame in 2...15 {
            frame15 = evaluator.rgba8(visualTick: frame)
        }

        XCTAssertEqual(
            canonicalSHA256(frame0),
            "c93b482fca480de0b038229dc4713132eccaa80565d4de49290ad298fb3ff3d3"
        )
        XCTAssertEqual(
            canonicalSHA256(frame1),
            "d3807e29ea90fef543de25265f4340e6c97154bf0ed09885b4ba967b23d1d25d"
        )
        XCTAssertEqual(
            canonicalSHA256(frame15),
            "a6421e077e293fe63fb6d67f6977fdf575028ff946a0f229e3b21d366afbdeb0"
        )

        var boundedSequentialEvaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )
        var boundedSequentialFrame = boundedSequentialEvaluator.rgba8(visualTick: 0)
        for frame in 1...7 {
            boundedSequentialFrame = boundedSequentialEvaluator.rgba8(visualTick: frame)
        }
        var boundedSkippedEvaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )
        _ = boundedSkippedEvaluator.rgba8(visualTick: 0)
        XCTAssertEqual(
            boundedSkippedEvaluator.rgba8(visualTick: 7),
            boundedSequentialFrame
        )

        var skippedEvaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )
        _ = skippedEvaluator.rgba8(visualTick: 0)
        let directlyDemandedFrame15 = skippedEvaluator.rgba8(visualTick: 15)
        XCTAssertEqual(
            canonicalSHA256(directlyDemandedFrame15),
            "314d89786dd2c0ae2917f3fe44d420a469a9eede2a424d7256e6a87beccb2d49"
        )
    }

    func testPreservesSplitGreenShadeTableSemantics() throws {
        var base = Data()
        base.reserveCapacity(128 * 128 * 4)
        for _ in 0..<(128 * 128) {
            base.append(contentsOf: [0, 90, 0, 255])
        }
        var evaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: .init(
                evaluationIntervalSeconds: 0,
                lightingShift: 0,
                dampingShift: 6,
                elements: [
                    .init(
                        kind: .heightBlob,
                        frequency: 0,
                        speed: 29,
                        size: 1,
                        x1: 64,
                        y1: 64,
                        x2: 0,
                        y2: 0
                    ),
                ]
            )
        )

        let frame0 = evaluator.rgba8(visualTick: 0)

        let discriminatingPixelOffset = (64 * 128 + 65) * 4
        XCTAssertEqual(
            Array(frame0[discriminatingPixelOffset..<(discriminatingPixelOffset + 4)]),
            [0, 0, 0, 255]
        )
        XCTAssertEqual(
            canonicalSHA256(frame0),
            "e5495353fb1b915327813cc39a74d33aebf4484f023039fb485d77a38c9c678b"
        )
    }

    func testTraversesTheTwoAlignedRenderedPortalsAndStopsAtRoomOne() throws {
        let level = makeSelectedRoomRenderLevel()
        let camera = RoomCamera(
            position: .zero,
            target: .init(x: 0, y: 1, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )

        let extraction = try extractWorldForRendering(
            level,
            camera: camera,
            startRoomSourceIndex: 3
        )

        XCTAssertEqual(extraction.visibleRoomSourceIndices, [3, 2, 1])
        XCTAssertEqual(
            extraction.translucentDrawItems.map {
                "\($0.roomSourceIndex):\($0.faceIndex)"
            },
            ["2:0", "3:0"]
        )
        XCTAssertEqual(
            extraction.opaqueDrawItems.map {
                "\($0.roomSourceIndex):\($0.faceIndex)"
            },
            ["1:1"]
        )
        XCTAssertFalse(
            extraction.opaqueDrawItems.contains {
                $0.roomSourceIndex == 1 && $0.faceIndex == 2
            }
        )
        XCTAssertFalse(
            extraction.portalEdges.contains(where: { $0.roomSourceIndex == 4 })
        )
    }

    func testAdmitsTheFixedSliceSixObjectsAndSelectsTheSourceLOD() throws {
        let level = makeSliceSixObjectRenderLevel()
        try level.validate()

        let extraction = try extractWorldForRendering(
            level,
            camera: .trainingRoom3,
            startRoomSourceIndex: 3
        )

        XCTAssertEqual(
            extraction.admittedObjectHandles,
            [18_441, 2_048, 12_300, 6_147]
        )
        XCTAssertEqual(
            Set(extraction.modelDrawItems.map(\.objectHandle)),
            Set(extraction.admittedObjectHandles)
        )
        XCTAssertEqual(
            Set(
                extraction.modelDrawItems
                    .filter { $0.objectHandle == 2_048 }
                    .map(\.model)
            ),
            [.init(storedIndex: 1, sourceName: "PyroGLMed.OOF")]
        )
        XCTAssertFalse(extraction.admittedObjectHandles.contains(2_052))
        XCTAssertTrue(
            extraction.modelDrawItems.contains {
                $0.objectHandle == 6_147
                    && $0.material == .sourceColor(red: 32, green: 64, blue: 96)
            }
        )
        XCTAssertFalse(extraction.modelDrawItems.contains { $0.submodelIndex == 2 })
        let facing = try XCTUnwrap(
            extraction.modelDrawItems.first {
                $0.objectHandle == 6_147 && $0.submodelIndex == 3
            }
        )
        XCTAssertEqual(
            facing.material,
            .texture(.init(storedIndex: 50, sourceName: "model-surface"))
        )
        XCTAssertEqual(facing.blend, .sourceAlpha(opacity: 255))
        XCTAssertEqual(facing.triangleIndices, [0, 1, 2, 0, 2, 3])
        XCTAssertEqual(facing.vertices.map(\.u), [0, 1, 1, 0])
        XCTAssertEqual(facing.vertices.map(\.v), [0, 0, 1, 1])
        let expectedFacingPositions = [
            Vector3(x: 2_063.4604, y: -230.09009, z: 2_204.0276),
            Vector3(x: 2_065.4604, y: -230.09009, z: 2_204.0276),
            Vector3(x: 2_065.4604, y: -230.09009, z: 2_202.0276),
            Vector3(x: 2_063.4604, y: -230.09009, z: 2_202.0276),
        ]
        for (actual, expected) in zip(
            facing.vertices.map(\.position),
            expectedFacingPositions
        ) {
            XCTAssertEqual(actual.x, expected.x, accuracy: 0.000_1)
            XCTAssertEqual(actual.y, expected.y, accuracy: 0.000_1)
            XCTAssertEqual(actual.z, expected.z, accuracy: 0.000_1)
        }
        XCTAssertTrue(extraction.modelDrawItems.contains {
            $0.objectHandle == 6_147
                && $0.submodelIndex == 4
                && $0.vertices.count == 3
        })
        let rotating = try extractWorldForRendering(
            level,
            camera: .trainingRoom3,
            startRoomSourceIndex: 3,
            presentationGameTime: 0.25
        )
        let rotated = try XCTUnwrap(
            rotating.modelDrawItems.first {
                $0.objectHandle == 6_147 && $0.submodelIndex == 4
            }
        )
        XCTAssertEqual(
            rotated.vertices[0].position.x,
            2_064.0604,
            accuracy: 0.001
        )
        XCTAssertEqual(
            rotated.vertices[0].position.z,
            2_208.0276,
            accuracy: 0.001
        )
    }
}
