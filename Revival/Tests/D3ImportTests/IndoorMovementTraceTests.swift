import XCTest

extension CanonicalLevelTests {
    func testRadiusAwareIndoorTraceStopsAtRenderedPortalAndCrossesOpenPortal() throws {
        let rendered = makeIndoorTraceLevel(portalFlags: 0x0000_0001)
        let start = Vector3(x: 0, y: 0, z: 0)
        let end = Vector3(x: 1.75, y: 0, z: 0)

        let blocked = traceIndoorMovement(
            in: rendered,
            startRoom: 10,
            start: start,
            end: end,
            radius: 0.25
        )
        XCTAssertEqual(
            blocked.outcome,
            .wallHit(
                .init(
                    roomSourceIndex: 10,
                    faceIndex: 0,
                    contactPoint: .init(x: 1, y: 0, z: 0),
                    normal: .init(x: -1, y: 0, z: 0),
                    distance: 0.75
                )
            )
        )
        XCTAssertEqual(blocked.finalPosition, .init(x: 0.75, y: 0, z: 0))
        XCTAssertEqual(blocked.containingRoomSourceIndex, 10)
        XCTAssertEqual(blocked.visitedRoomSourceIndices, [10])

        let open = traceIndoorMovement(
            in: makeIndoorTraceLevel(portalFlags: 0),
            startRoom: 10,
            start: start,
            end: end,
            radius: 0.25
        )
        XCTAssertEqual(open.outcome, .noHit)
        XCTAssertEqual(open.finalPosition, end)
        XCTAssertEqual(open.containingRoomSourceIndex, 20)
        XCTAssertEqual(open.visitedRoomSourceIndices, [10, 20])

        for portalFlags: UInt32 in [0x0000_0003, 0x0000_0004] {
            let passable = traceIndoorMovement(
                in: makeIndoorTraceLevel(portalFlags: portalFlags),
                startRoom: 10,
                start: start,
                end: end,
                radius: 0.25
            )
            XCTAssertEqual(passable.outcome, .noHit)
            XCTAssertEqual(passable.containingRoomSourceIndex, 20)
        }
    }

    func testRenderedPortalUsesTypedFlythroughSurfacePhysics() {
        let rendered = makeIndoorTraceLevel(portalFlags: 0x0000_0001)
        let texture = rendered.rooms[0].faces[0].texture
        let flythrough = rendered.addingSurfacePhysics([
            .init(texture: texture, behavior: .passThrough),
        ])

        let trace = traceIndoorMovement(
            in: flythrough,
            startRoom: 10,
            start: .init(x: 0, y: 0, z: 0),
            end: .init(x: 1.75, y: 0, z: 0),
            radius: 0.25
        )

        XCTAssertEqual(trace.outcome, .noHit)
        XCTAssertEqual(trace.containingRoomSourceIndex, 20)
        XCTAssertEqual(trace.visitedRoomSourceIndices, [10, 20])
    }

    func testTypedFlythroughSurfaceMakesANonPortalFacePassable() throws {
        let level = makeNonPortalTraceLevel(behavior: .passThrough)
        try level.validate()
        let end = Vector3(x: 1.5, y: 0, z: 0)

        let trace = traceIndoorMovement(
            in: level,
            startRoom: 10,
            start: .init(x: 0, y: 0, z: 0),
            end: end,
            radius: 0.25
        )

        XCTAssertEqual(trace.outcome, .noHit)
        XCTAssertEqual(trace.finalPosition, end)
        XCTAssertEqual(trace.visitedRoomSourceIndices, [10])
    }

    func testRadiusContactOwnershipUsesTheStoppedCenterAcrossVisitedRooms() {
        let level = makeIndoorTraceLevelWithNearWall()

        let trace = traceIndoorMovement(
            in: level,
            startRoom: 10,
            start: .init(x: 0, y: 0, z: 0),
            end: .init(x: 2, y: 0, z: 0),
            radius: 0.25
        )

        guard case .wallHit(let contact) = trace.outcome else {
            return XCTFail("Expected the near wall in source room 20")
        }
        XCTAssertEqual(contact.roomSourceIndex, 20)
        XCTAssertEqual(trace.finalPosition.x, 0.85, accuracy: 0.000_1)
        XCTAssertEqual(trace.visitedRoomSourceIndices, [10, 20])
        XCTAssertEqual(trace.containingRoomSourceIndex, 10)
    }
}

private func makeIndoorTraceLevel(portalFlags: UInt32) -> Level {
    let base = makeMinimalCanonicalLevel()
    let texture = base.rooms[0].faces[0].texture
    let portalFace: ([Vector3], Int) -> (vertices: [Vector3], face: LevelFace) = {
        points, portalIndex in
        (
            points,
            LevelFace(
                corners: points.indices.map {
                    .init(vertexIndex: $0, u: 0, v: 0, alpha: 255)
                },
                flags: 0,
                portalIndex: portalIndex,
                texture: texture
            )
        )
    }
    let room10Portal = portalFace(
        [
            .init(x: 1, y: -1, z: -1),
            .init(x: 1, y: -1, z: 1),
            .init(x: 1, y: 1, z: 1),
            .init(x: 1, y: 1, z: -1),
        ],
        0
    )
    let room20Portal = portalFace(Array(room10Portal.vertices.reversed()), 0)
    let room10 = LevelRoom(
        sourceIndex: 10,
        vertices: room10Portal.vertices,
        faces: [room10Portal.face],
        portals: [
            .init(
                flags: portalFlags,
                faceIndex: 0,
                connectedRoom: 20,
                connectedPortal: 0
            ),
        ]
    )
    let room20 = LevelRoom(
        sourceIndex: 20,
        vertices: room20Portal.vertices,
        faces: [room20Portal.face],
        portals: [
            .init(
                flags: portalFlags,
                faceIndex: 0,
                connectedRoom: 10,
                connectedPortal: 0
            ),
        ]
    )
    return replacing(base, rooms: [room10, room20])
}

private func makeIndoorTraceLevelWithNearWall() -> Level {
    let base = makeIndoorTraceLevel(portalFlags: 0)
    let originalRoom20 = base.rooms[1]
    let firstVertex = originalRoom20.vertices.count
    let vertices = originalRoom20.vertices + [
        .init(x: 1.1, y: -1, z: -1),
        .init(x: 1.1, y: -1, z: 1),
        .init(x: 1.1, y: 1, z: 1),
        .init(x: 1.1, y: 1, z: -1),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: originalRoom20.faces[0].texture
    )
    let room20 = LevelRoom(
        sourceIndex: originalRoom20.sourceIndex,
        name: originalRoom20.name,
        pathPoint: originalRoom20.pathPoint,
        vertices: vertices,
        faces: originalRoom20.faces + [wall],
        portals: originalRoom20.portals,
        flags: originalRoom20.flags,
        pulseTime: originalRoom20.pulseTime,
        pulseOffset: originalRoom20.pulseOffset,
        mirrorFaceIndex: originalRoom20.mirrorFaceIndex,
        door: originalRoom20.door,
        volumeLights: originalRoom20.volumeLights,
        fog: originalRoom20.fog,
        ambientSoundPattern: originalRoom20.ambientSoundPattern,
        reverb: originalRoom20.reverb,
        damage: originalRoom20.damage,
        damageType: originalRoom20.damageType
    )
    return replacing(base, rooms: [base.rooms[0], room20])
}

private func makeNonPortalTraceLevel(
    behavior: SurfacePhysicsBehavior
) -> Level {
    let base = makeIndoorTraceLevel(portalFlags: 0x0000_0001)
    let originalRoom = base.rooms[0]
    let originalFace = originalRoom.faces[0]
    let face = LevelFace(
        corners: originalFace.corners,
        flags: originalFace.flags,
        portalIndex: nil,
        texture: originalFace.texture,
        lightmapInfoIndex: originalFace.lightmapInfoIndex,
        allowsLightCorona: originalFace.allowsLightCorona,
        lightMultiple: originalFace.lightMultiple,
        special: originalFace.special
    )
    let room = LevelRoom(
        sourceIndex: originalRoom.sourceIndex,
        name: originalRoom.name,
        pathPoint: originalRoom.pathPoint,
        vertices: originalRoom.vertices,
        faces: [face],
        portals: [],
        flags: originalRoom.flags,
        pulseTime: originalRoom.pulseTime,
        pulseOffset: originalRoom.pulseOffset,
        mirrorFaceIndex: originalRoom.mirrorFaceIndex,
        door: originalRoom.door,
        volumeLights: originalRoom.volumeLights,
        fog: originalRoom.fog,
        ambientSoundPattern: originalRoom.ambientSoundPattern,
        reverb: originalRoom.reverb,
        damage: originalRoom.damage,
        damageType: originalRoom.damageType
    )
    return replacing(
        base,
        rooms: [room],
        surfacePhysics: [
            .init(texture: face.texture, behavior: behavior),
        ]
    )
}
