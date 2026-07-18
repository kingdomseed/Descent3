import XCTest

final class WorldRenderingTests: XCTestCase {
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
        XCTAssertThrowsError(
            try makeMetalWorldPlan(
                level: makeCoronaEvaluationLevel(blocked: false),
                camera: camera,
                startRoomSourceIndex: 3
            )
        ) {
            XCTAssertEqual(
                $0 as? MetalWorldPlanError,
                .nonzeroLightCorona(roomSourceIndex: 3, faceIndex: 0)
            )
        }

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
    }

    func testEvaluatesTypedWaterDeterministicallyAndOnlyOncePerFrame() throws {
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

        let frame0 = evaluator.rgba8(frameCount: 0, timeSeconds: 0)
        XCTAssertEqual(
            evaluator.rgba8(frameCount: 0, timeSeconds: 10),
            frame0
        )
        let frame1 = evaluator.rgba8(frameCount: 1, timeSeconds: 1 / 60)
        var frame15 = frame1
        for frame in 2...15 {
            frame15 = evaluator.rgba8(
                frameCount: frame,
                timeSeconds: Float(frame) / 60
            )
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

        var skippedEvaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )
        _ = skippedEvaluator.rgba8(frameCount: 0, timeSeconds: 0)
        let directlyDemandedFrame15 = skippedEvaluator.rgba8(
            frameCount: 15,
            timeSeconds: 15 / 60
        )
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

        let frame0 = evaluator.rgba8(frameCount: 0, timeSeconds: 0)

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
}

private extension Array {
    var only: Element? { count == 1 ? self[0] : nil }
}

private func makeCoronaEvaluationLevel(blocked: Bool) -> Level {
    let base = makeMinimalCanonicalLevel()
    let light = SourceResource(storedIndex: 1, sourceName: "light")
    let blocker = SourceResource(storedIndex: 2, sourceName: "blocker")
    let candidateVertices = [
        Vector3(x: -1, y: 21, z: -1),
        Vector3(x: 1, y: 21, z: -1),
        Vector3(x: 1, y: 21, z: 1),
        Vector3(x: -1, y: 21, z: 1),
    ]
    let blockerVertices = [
        Vector3(x: -5, y: 10, z: -5),
        Vector3(x: 5, y: 10, z: -5),
        Vector3(x: 5, y: 10, z: 5),
        Vector3(x: -5, y: 10, z: 5),
    ]
    let corners = [
        FaceCorner(vertexIndex: 0, u: 0, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 1, u: 1, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 2, u: 1, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 3, u: 0, v: 1, alpha: 255),
    ]
    var faces = [
        LevelFace(
            corners: corners,
            flags: 0,
            portalIndex: nil,
            texture: light,
            allowsLightCorona: true
        ),
    ]
    var portals: [LevelPortal] = []
    if blocked {
        faces.append(
            LevelFace(
                corners: corners.map {
                    FaceCorner(
                        vertexIndex: $0.vertexIndex + 4,
                        u: $0.u,
                        v: $0.v,
                        alpha: $0.alpha
                    )
                },
                flags: 0,
                portalIndex: 0,
                texture: blocker
            )
        )
        portals.append(
            .init(flags: 1, faceIndex: 1, connectedRoom: 4, connectedPortal: 0)
        )
    }
    let room3 = LevelRoom(
        sourceIndex: 3,
        vertices: candidateVertices + blockerVertices,
        faces: faces,
        portals: portals
    )
    let room4 = LevelRoom(
        sourceIndex: 4,
        vertices: blockerVertices,
        faces: blocked ? [
            .init(
                corners: Array(corners.reversed()),
                flags: 0,
                portalIndex: 0,
                texture: blocker
            ),
        ] : [],
        portals: blocked ? [
            .init(flags: 1, faceIndex: 0, connectedRoom: 3, connectedPortal: 0),
        ] : []
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: blocked ? [room3, room4] : [room3],
        terrain: base.terrain,
        objects: [],
        paths: [],
        goals: [],
        triggers: [],
        playerStartFlags: [],
        lightmaps: .init(pages: [], infos: []),
        presentationMaterials: [
            .init(
                texture: light,
                bitmapSourceName: "light.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                blend: .opaque,
                lightmapBlend: .none,
                waterProcedural: nil,
                lightCorona: .init(
                    assetIndex: 0,
                    tint: .init(x: 0.25, y: 0.5, z: 0.75),
                    blend: .additiveSourceAlpha(opacity: 102)
                ),
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "a", count: 64)
            ),
            .init(
                texture: blocker,
                bitmapSourceName: "blocker.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                blend: .opaque,
                lightmapBlend: .none,
                waterProcedural: nil,
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "b", count: 64)
            ),
        ],
        presentationCoronaAssets: [
            .init(
                source: .init(storedIndex: 0, sourceName: "flare"),
                bitmapSourceName: "flare.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "c", count: 64)
            ),
        ],
        dependencyManifest: .init(current: [], historicalEagerBaseline: nil),
        sourceChunks: base.sourceChunks
    )
}

func makeSourceContainmentRoom(
    center: Vector3,
    texture: SourceResource
) -> LevelRoom {
    let vertices = [
        Vector3(x: center.x - 1, y: center.y - 1, z: center.z - 1),
        Vector3(x: center.x + 1, y: center.y - 1, z: center.z - 1),
        Vector3(x: center.x + 1, y: center.y + 1, z: center.z - 1),
        Vector3(x: center.x - 1, y: center.y + 1, z: center.z - 1),
        Vector3(x: center.x - 1, y: center.y - 1, z: center.z + 1),
        Vector3(x: center.x + 1, y: center.y - 1, z: center.z + 1),
        Vector3(x: center.x + 1, y: center.y + 1, z: center.z + 1),
        Vector3(x: center.x - 1, y: center.y + 1, z: center.z + 1),
    ]
    func face(_ indices: [Int]) -> LevelFace {
        LevelFace(
            corners: indices.enumerated().map { index, vertexIndex in
                FaceCorner(
                    vertexIndex: vertexIndex,
                    u: index == 1 || index == 2 ? 1 : 0,
                    v: index >= 2 ? 1 : 0,
                    alpha: 255
                )
            },
            flags: 0,
            portalIndex: nil,
            texture: texture
        )
    }
    return LevelRoom(
        sourceIndex: 3,
        vertices: vertices,
        faces: [
            face([0, 3, 7, 4]),
            face([1, 5, 6, 2]),
            face([0, 4, 5, 1]),
            face([3, 2, 6, 7]),
            face([0, 1, 2, 3]),
            face([4, 7, 6, 5]),
        ],
        portals: []
    )
}

private func alienForceFieldWaterDefinition() -> WaterProceduralDefinition {
    let raw: [(WaterProceduralElementKind, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)] = [
        (.heightBlob, 20, 40, 100, 127, 58, 186, 13),
        (.heightBlob, 20, 40, 100, 0, 59, 13, 240),
        (.heightBlob, 20, 40, 100, 0, 58, 240, 173),
        (.heightBlob, 20, 40, 100, 62, 1, 173, 186),
        (.heightBlob, 20, 40, 100, 62, 126, 186, 13),
        (.heightBlob, 20, 40, 100, 62, 3, 13, 240),
        (.noOp, 0, 1, 1, 91, 38, 240, 173),
    ]
    return WaterProceduralDefinition(
        evaluationIntervalSeconds: 0,
        lightingShift: 7,
        dampingShift: 6,
        elements: raw.map {
            WaterProceduralElement(
                kind: $0.0,
                frequency: $0.1,
                speed: $0.2,
                size: $0.3,
                x1: $0.4,
                y1: $0.5,
                x2: $0.6,
                y2: $0.7
            )
        }
    )
}

func makeSelectedRoomRenderLevel() -> Level {
    let base = makeMinimalCanonicalLevel()
    let forceField = SourceResource(storedIndex: 3, sourceName: "force-field")
    let wall = SourceResource(storedIndex: 0, sourceName: "wall")
    let quad = [
        FaceCorner(vertexIndex: 0, u: 1, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 1, u: 0, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 2, u: 0, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 3, u: 1, v: 0, alpha: 255),
    ]
    let reversedQuad = [quad[3], quad[2], quad[1], quad[0]]
    let forwardVertices = [
        Vector3(x: 1, y: 2, z: 1),
        Vector3(x: -1, y: 2, z: 1),
        Vector3(x: -1, y: 2, z: -1),
        Vector3(x: 1, y: 2, z: -1),
        Vector3(x: 0.5, y: 4, z: 0.5),
        Vector3(x: -0.5, y: 4, z: 0.5),
        Vector3(x: -0.5, y: 4, z: -0.5),
        Vector3(x: 0.5, y: 4, z: -0.5),
        Vector3(x: 0.5, y: 6, z: 0.5),
        Vector3(x: -0.5, y: 6, z: 0.5),
        Vector3(x: -0.5, y: 6, z: -0.5),
        Vector3(x: 0.5, y: 6, z: -0.5),
        Vector3(x: 1, y: -2, z: 1),
        Vector3(x: -1, y: -2, z: 1),
        Vector3(x: -1, y: -2, z: -1),
        Vector3(x: 1, y: -2, z: -1),
    ]
    func corners(_ offset: Int, reversed: Bool = false) -> [FaceCorner] {
        let source = reversed ? reversedQuad : quad
        return source.map {
            FaceCorner(
                vertexIndex: $0.vertexIndex + offset,
                u: $0.u,
                v: $0.v,
                alpha: $0.alpha
            )
        }
    }
    let room2 = LevelRoom(
        sourceIndex: 2,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(4), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(0, reversed: true), flags: 0, portalIndex: 1, texture: forceField),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 1, connectedPortal: 0),
            .init(flags: 1, faceIndex: 1, connectedRoom: 3, connectedPortal: 0),
        ]
    )
    let room3 = LevelRoom(
        sourceIndex: 3,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(0), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(12, reversed: true), flags: 0, portalIndex: 1, texture: forceField),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 2, connectedPortal: 1),
            .init(faceIndex: 1, connectedRoom: 4, connectedPortal: 0),
        ]
    )
    let room1 = LevelRoom(
        sourceIndex: 1,
        vertices: forwardVertices + [
            Vector3(x: 12, y: 6, z: 0.5),
            Vector3(x: 10, y: 6, z: 0.5),
            Vector3(x: 10, y: 6, z: -0.5),
            Vector3(x: 12, y: 6, z: -0.5),
        ],
        faces: [
            .init(corners: corners(4, reversed: true), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(8), flags: 0, portalIndex: nil, texture: wall),
            .init(corners: corners(16), flags: 0, portalIndex: nil, texture: wall),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 2, connectedPortal: 0),
        ]
    )
    let room4 = LevelRoom(
        sourceIndex: 4,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(12), flags: 0, portalIndex: 0, texture: forceField),
        ],
        portals: [.init(faceIndex: 0, connectedRoom: 3, connectedPortal: 1)]
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: [room1, room2, room3, room4],
        terrain: base.terrain,
        objects: [],
        paths: [],
        goals: [],
        triggers: [],
        playerStartFlags: [],
        lightmaps: .init(pages: [], infos: []),
        presentationMaterials: [
            .init(
                texture: forceField,
                bitmapSourceName: "force-field.ogf",
                image: .init(
                    width: 2,
                    height: 2,
                    rgba8: Data(repeating: 255, count: 16)
                ),
                blend: .additiveSourceAlpha(opacity: 178),
                lightmapBlend: .none,
                waterProcedural: nil,
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "a", count: 64)
            ),
            .init(
                texture: wall,
                bitmapSourceName: "wall.ogf",
                image: .init(
                    width: 2,
                    height: 2,
                    rgba8: Data(repeating: 255, count: 16)
                ),
                blend: .opaque,
                lightmapBlend: .multiply,
                waterProcedural: nil,
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "b", count: 64)
            ),
        ],
        dependencyManifest: .init(
            current: [
                .init(
                    category: "texture",
                    source: wall,
                    state: "presentation-payload-imported",
                    provenance: "test"
                ),
                .init(category: "texture", source: forceField, state: "presentation-payload-imported", provenance: "test"),
            ],
            historicalEagerBaseline: nil
        ),
        sourceChunks: base.sourceChunks
    )
}
