import XCTest

// The generic object frame on synthetic Training fixtures: the frame order
// of GameFrame (AIFrameAll, then one ObjDoFrameAll slot loop that includes
// the player, GameLoop.cpp:2964-2973), the player-weapon polygon/sphere
// check (collide.cpp:2623; PolyCollideObject, newstyle_fi.cpp:354), the
// per-AI memory, target, and vision steps of AIDoFrame (AImain.cpp:6089-
// 6100), and AITurnTowardsDir's turn (AImain.cpp:2110).
final class ObjectFrameTests: XCTestCase {
    // MARK: Frame order

    /// ObjDoFrameAll (object.cpp:2969) visits every object, the player too,
    /// in ascending slots. A weapon in a lower slot than the player moves
    /// first, so it meets the player where the player was at the start of
    /// the frame, even though the player then flies clear.
    func testWeaponInALowerSlotMovesBeforeThePlayer() throws {
        let level = try relocatingPlayer(
            try dodgeLevelWithRoomyPlayerRoom(),
            toSlot: 1_400
        )
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        let player = try XCTUnwrap(session.world.objects[ObjectHandle(
            level.defaultPlayerBinding!.objectHandle
        )])
        XCTAssertEqual(player.handle.slot, 1_400)
        let weapon = try XCTUnwrap(fireTestShot(
            &session.world,
            level: level,
            modelStart: .init(x: 3, y: -5, z: 0),
            modelVelocity: .init(x: 0, y: 100, z: 0)
        ))
        XCTAssertLessThan(weapon.slot, player.handle.slot)
        // The player flies sideways, clear of the shot's line, this frame.
        session.world.velocity = player.orientation.right * 150
        _ = session.update(at: 0.1, input: .zero)
        XCTAssertEqual(session.world.shields, 100 - 6.75)
        XCTAssertNil(session.world.objects[weapon])
    }

    /// AIFrameAll (AImain.cpp:6211) tells each CT_AI object the previous
    /// frame drew (AI_RenderedList, renderobject.cpp:1239) that the player
    /// sees it: AIN_PLAYER_SEES_YOU sets last_render_time (AImain.cpp:2943).
    func testAIFrameAllTellsRenderedAIObjectsThePlayerSeesThem() throws {
        let level = try dodgeLevelWithRoomyPlayerRoom()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        let turret = level.findObjectName("DodgeTurrett")
        session.world.aAISetState(1, turret)
        // Put the turret 30 units in front of the player's eye.
        let player = session.world.testPlayerObject
        var object = try XCTUnwrap(session.world.objects[turret])
        object.location = player.location
        object.position = player.position + player.orientation.forward * 30
        session.world.objects[turret] = object
        _ = session.update(at: 0.1, input: .zero)
        XCTAssertEqual(session.world.aiRenderedList, [turret])
        XCTAssertEqual(session.world.objects[turret]?.ai?.lastRenderTime, -1)
        let gameTime = session.world.gameTime
        _ = session.update(at: 0.2, input: .zero)
        XCTAssertEqual(
            session.world.objects[turret]?.ai?.lastRenderTime,
            gameTime
        )
    }

    /// The small views render after the main view (DrawSmallViews calls
    /// GameRenderWorld, SmallViews.cpp:332), so their AI objects join
    /// AI_RenderedList (renderobject.cpp:1239), and the next AIFrameAll tells them the player sees them
    /// (AImain.cpp:6225). A robot behind the player is seen only through a
    /// popup view that looks back.
    func testARobotSeenOnlyThroughThePopupViewHearsThePlayerSeesIt()
        throws
    {
        func session(popup: Bool) throws -> (GameSession, ObjectHandle) {
            let level = try dodgeLevelWithRoomyPlayerRoom()
            let session = GameSession(level: level, presentationReadyTimestamp: 0)
            let turret = level.findObjectName("DodgeTurrett")
            session.world.aAISetState(1, turret)
            let player = session.world.testPlayerObject
            var object = try XCTUnwrap(session.world.objects[turret])
            object.location = player.location
            object.position = player.position - player.orientation.forward * 30
            session.world.objects[turret] = object
            if popup {
                let viewer = try XCTUnwrap(session.world.objects.first {
                    $0.type == .powerup
                }).handle
                session.world.objects[viewer]?.location = player.location
                session.world.objects[viewer]?.position = player.position
                session.world.objects[viewer]?.orientation = .init(
                    right: player.orientation.right * -1,
                    up: player.orientation.up,
                    forward: player.orientation.forward * -1
                )
                session.world.aCreatePopupView(-1, viewer, 10, 1)
            }
            return (session, turret)
        }

        // A robot in both views joins the list for each view: each
        // GameRenderWorld marks its rooms' objects OF_SAFE_TO_RENDER again
        // (render.cpp:1126).
        let (both, bothTurret) = try session(popup: true)
        let bothPlayer = both.world.testPlayerObject
        both.world.objects[bothTurret]?.position =
            bothPlayer.position + bothPlayer.orientation.forward * 30
        let bothViewer = try XCTUnwrap(both.world.smallViews.first?.viewer)
        both.world.objects[bothViewer]?.orientation = bothPlayer.orientation
        _ = both.update(at: 0.1, input: .zero)
        XCTAssertEqual(both.world.aiRenderedList, [bothTurret, bothTurret])

        let (unseen, unseenTurret) = try session(popup: false)
        _ = unseen.update(at: 0.1, input: .zero)
        XCTAssertFalse(unseen.world.aiRenderedList.contains(unseenTurret))

        let (seen, turret) = try session(popup: true)
        _ = seen.update(at: 0.1, input: .zero)
        XCTAssertEqual(seen.world.aiRenderedList, [turret])
        XCTAssertEqual(seen.world.objects[turret]?.ai?.lastRenderTime, -1)
        let gameTime = seen.world.gameTime
        _ = seen.update(at: 0.2, input: .zero)
        XCTAssertEqual(seen.world.objects[turret]?.ai?.lastRenderTime, gameTime)
    }

    // MARK: Player and weapon collision

    /// The player's physics move checks runtime objects with their runtime
    /// size and shape (fvi_FindIntersection, physics.cpp:986): a player who
    /// flies into a resting laser takes its damage.
    func testPlayerMoveHitsARuntimeWeapon() throws {
        let level = try dodgeLevelWithRoomyPlayerRoom()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        let player = session.world.testPlayerObject
        let weapon = try XCTUnwrap(fireTestShot(
            &session.world,
            level: level,
            modelStart: .init(x: 3, y: -5, z: 0),
            modelVelocity: .zero
        ))
        session.world.velocity = player.orientation.up * -100
        _ = session.update(at: 0.1, input: .zero)
        XCTAssertEqual(session.world.shields, 100 - 6.75)
        XCTAssertNil(session.world.objects[weapon])
    }

    /// A weapon hits the player's polygon model, not its bounding sphere
    /// (ENABLE_COLLISION_POLY_SPHERE, collide.cpp:2623; PolyCollideObject,
    /// newstyle_fi.cpp:354). The fixture hull is a flat triangle below the
    /// ship's center: a shot through it hits, and a shot 3 units off its
    /// edge, still inside the bounding sphere, flies past.
    func testWeaponHitsTheShipHullAndMissesOutsideIt() throws {
        let level = try dodgeLevelWithRoomyPlayerRoom()
        for (offset, hits) in [(Float(0), true), (3, false)] {
            let session = GameSession(
                level: level,
                presentationReadyTimestamp: 0
            )
            let size = session.world.testPlayerObject.size
            XCTAssertLessThan(sqrt(9 + offset * offset), size + 0.5)
            let weapon = try XCTUnwrap(fireTestShot(
                &session.world,
                level: level,
                modelStart: .init(x: 3, y: -5, z: offset),
                modelVelocity: .init(x: 0, y: 100, z: 0)
            ))
            session.world.moveWeapon(weapon, level: level)
            XCTAssertEqual(
                session.world.shields,
                hits ? 100 - 6.75 : 100,
                "offset \(offset)"
            )
        }
    }

    // MARK: AI

    /// AIDoFrame runs AIDoMemFrame for every enabled AI object
    /// (AImain.cpp:6089), and each memory renewal draws the next 3 to 5 s
    /// with ps_rand (AImain.cpp:5963). FollowBot1 is a flyer, not a turret.
    func testEveryEnabledAIObjectRenewsItsMemory() throws {
        let level = makeTrainingManeuverFollowLevel()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        let followBot = level.findObjectName("FollowBot1")
        session.world.aAISetState(1, followBot)
        let start = try XCTUnwrap(
            session.world.objects[followBot]?.ai?.memoryTimeUntilNextUpdate
        )
        XCTAssertTrue((3...5).contains(start))
        var timestamp = 0.0
        for _ in 0..<60 {
            timestamp += 0.1
            _ = session.update(at: timestamp, input: .zero)
        }
        let renewed = try XCTUnwrap(
            session.world.objects[followBot]?.ai?.memoryTimeUntilNextUpdate
        )
        XCTAssertNotEqual(renewed, start)
        XCTAssertGreaterThan(renewed, 0)
        XCTAssertLessThanOrEqual(renewed, 5)
    }

    /// AITurnTowardsDir with the goal straight behind: forward x goal is
    /// zero, so vm_VectorToMatrix builds the turn frame from the forward
    /// vector alone (DoVectorToMatrix's bad_vector2 path,
    /// vecmat/vector.cpp:500-514), and the object turns max_angle toward
    /// that frame's right vector (AImain.cpp:2140-2153).
    func testOppositeGoalTurnsTowardTheFallbackRightVector() throws {
        var world = GameSession(
            level: makeTrainingManeuverFollowLevel(),
            presentationReadyTimestamp: 0
        ).world
        world.frameDuration = 0.1
        var object = world.testPlayerObject
        object.orientation = Matrix3(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )
        world.aiTurnTowardsDir(
            &object,
            direction: .init(x: 0, y: 0, z: -1),
            turnRate: 12_000
        )
        let angle = Float(1_200) * (2 * Float.pi / 65_536)
        XCTAssertEqual(object.orientation.forward.x, sin(angle), accuracy: 1e-4)
        XCTAssertEqual(object.orientation.forward.y, 0, accuracy: 1e-4)
        XCTAssertEqual(object.orientation.forward.z, cos(angle), accuracy: 1e-4)
    }

    /// ai_mem's counters are int16_t (aistruct.h:717-728): the hit count
    /// wraps as the C++ short does, and never traps.
    func testAIMemoryHitCountWrapsAsASourceShort() throws {
        let level = try dodgeLevelWithRoomyPlayerRoom()
        var world = GameSession(level: level, presentationReadyTimestamp: 0)
            .world
        let turret = level.findObjectName("DodgeTurrett")
        world.aAISetState(1, turret)
        world.objects[turret]?.ai?.memory[0].numberOfHitEnemy = 32_767
        world.aiNotifyWeaponHitObject(
            turret,
            target: world.testPlayerObject.handle,
            level: level
        )
        XCTAssertEqual(
            world.objects[turret]?.ai?.memory[0].numberOfHitEnemy,
            -32_768
        )
    }
}

/// A red laser of the dodge fixture, fired by DodgeTurrett, at a point and
/// with a velocity given in the player's model frame.
private func fireTestShot(
    _ world: inout GameWorld,
    level: Level,
    modelStart: Vector3,
    modelVelocity: Vector3
) -> ObjectHandle? {
    guard let player = world.objects[ObjectHandle(
        level.defaultPlayerBinding!.objectHandle
    )] else {
        return nil
    }
    let frame = player.orientation
    func toWorld(_ vector: Vector3) -> Vector3 {
        frame.right * vector.x + frame.up * vector.y + frame.forward * vector.z
    }
    // Script 000's aObjMakeInvuln(player, 0) (TrainingMission.cpp:1473)
    // lasts until the first DoPlayerFrame; these shots come later.
    world.playerInvulnerableTime = nil
    guard let handle = world.objects.create(
        type: .weapon,
        renderType: .polyobj,
        location: player.location,
        position: player.position + toWorld(modelStart),
        orientation: frame
    ) else {
        return nil
    }
    var weapon = world.objects[handle]!
    weapon.weapon = 0
    weapon.parent = level.findObjectName("DodgeTurrett")
    weapon.usesPhysics = true
    weapon.lifeLeft = 5
    weapon.size = 0.5
    weapon.velocity = toWorld(modelVelocity)
    world.objects[handle] = weapon
    return handle
}

/// The level with its player object moved to `slot`, keeping the handle's
/// count.
private func relocatingPlayer(_ level: Level, toSlot slot: UInt32) throws
    -> Level
{
    let old = try XCTUnwrap(level.defaultPlayerBinding?.objectHandle)
    let new = (old & ~ObjectHandle.slotMask) | slot
    var object = try XCTUnwrap(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(level))
            as? [String: Any]
    )
    func renamed(_ key: String, _ field: String) throws {
        var entries = try XCTUnwrap(object[key] as? [[String: Any]])
        for index in entries.indices
        where (entries[index][field] as? NSNumber)?.uint32Value == old {
            entries[index][field] = new
        }
        object[key] = entries
    }
    try renamed("objects", "handle")
    try renamed("objectPresentations", "objectHandle")
    var binding = try XCTUnwrap(object["defaultPlayerBinding"] as? [String: Any])
    binding["objectHandle"] = new
    object["defaultPlayerBinding"] = binding
    return try JSONDecoder().decode(
        Level.self,
        from: JSONSerialization.data(withJSONObject: object)
    )
}

/// The dodge fixture with the player's room replaced by a 1,000-unit box
/// around the player that keeps the room's portals, so test moves meet no
/// wall.
private func dodgeLevelWithRoomyPlayerRoom() throws -> Level {
    var level = makeTrainingDodgeAttemptLevel()
    let placed = try XCTUnwrap(level.objects.first {
        $0.handle == level.defaultPlayerBinding?.objectHandle
    })
    guard case let .room(roomSourceIndex) = placed.location else {
        throw XCTSkip("indoor player")
    }
    let roomIndex = try XCTUnwrap(level.rooms.firstIndex {
        $0.sourceIndex == roomSourceIndex
    })
    let original = level.rooms[roomIndex]
    let containment = makeSourceContainmentRoom(
        center: placed.position,
        texture: level.surfacePhysics[0].texture,
        sourceIndex: roomSourceIndex,
        halfExtent: 500
    )
    var faces = containment.faces
    let portals = original.portals.enumerated().map { index, portal in
        let face = faces[index]
        faces[index] = .init(
            corners: face.corners,
            flags: face.flags,
            portalIndex: index,
            texture: face.texture,
            lightmapInfoIndex: face.lightmapInfoIndex,
            allowsLightCorona: face.allowsLightCorona,
            lightMultiple: face.lightMultiple,
            special: face.special
        )
        return LevelPortal(
            flags: portal.flags,
            faceIndex: index,
            connectedRoom: portal.connectedRoom,
            connectedPortal: portal.connectedPortal,
            boundaryNodeIndex: portal.boundaryNodeIndex,
            pathPoint: portal.pathPoint,
            combineMaster: portal.combineMaster
        )
    }
    level.rooms[roomIndex] = replacing(
        original,
        vertices: containment.vertices,
        faces: faces,
        portals: portals
    )
    return level
}
