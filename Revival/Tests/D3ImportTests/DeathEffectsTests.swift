import XCTest

/// The effects of a death (Descent3/fireball.cpp DestroyObject :1344 and
/// DoDyingFrame :1428): their object allocations and every ps_rand draw,
/// with the presentation deferred. The robot is DestroyBot2 (4112) of the
/// synthetic Training robot level: its gyro fixture model has 5 submodels,
/// a body of 2 faces, and the RAS1 page's death (DF_FIREBALL,
/// DF_BREAKS_APART, DF_DEBRIS_SMOKES, no delay).
final class DeathEffectsTests: XCTestCase {
    private let robot = ObjectHandle(4_112)

    /// DestroyObject in order: explosion sound (a draw, as the page has
    /// none), the fireball (a medium one: a draw), CreateExtraFireballs
    /// (0 to 3 extras; 2 sparks each, 7 draws per spark; 5 draws and an
    /// event per extra), 4 debris pieces (8 draws each), and 2 splinters
    /// (3 draws each, one more in a slot that is a multiple of 14). The
    /// test replays exactly that many draws.
    func testDestroyObjectTakesEveryEffectDrawAndAllocation() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        let before = world
        let target = try XCTUnwrap(world.objects[robot])
        world.killObject(
            robot,
            killer: world.testPlayerObject.handle,
            damage: 10,
            level: level
        )
        XCTAssertNotEqual(
            (world.objects[robot]?.flags ?? 0) & GameObject.deadFlag, 0
        )
        let fireballs = world.visEffects.filter {
            [VisEffect.mediumExplosionID, VisEffect.mediumExplosion2ID,
             VisEffect.mediumExplosion3ID].contains($0.id)
        }
        XCTAssertEqual(fireballs.count, 1)
        XCTAssertEqual(fireballs[0].size, target.size * 0.5 * 2)
        let events = world.gameEvents.compactMap { $0 }
        XCTAssertTrue((0...3).contains(events.count))
        for event in events {
            XCTAssertTrue((0.3...0.8).contains(event.endTime))
        }
        let sparks = world.visEffects.filter {
            $0.id == VisEffect.hotSparkID || $0.id == VisEffect.coolSparkID
        }
        XCTAssertEqual(sparks.count, events.count * 2)
        let debris = world.objects.filter { $0.type == .debris }
        XCTAssertEqual(debris.count, 4)
        for piece in debris {
            XCTAssertEqual(piece.physics?.numberOfBounces, 2)
            XCTAssertEqual(piece.physics?.restitution, 0.2)
            XCTAssertTrue((2...4.45).contains(piece.lifeLeft ?? 0))
            XCTAssertNotNil(piece.debris)
        }
        let splinters = world.objects.filter { $0.type == .splinter }
        XCTAssertEqual(splinters.count, 2)
        let extraSplinterDraws = splinters.filter {
            $0.handle.slot % 14 == 0
        }.count
        let draws = 2                       // KillObject's death type
            + 1                             // PlayObjectExplosionSound
            + 1                             // GetRandomMediumExplosion
            + 1                             // extras
            + sparks.count * 7              // each spark's kind and motion
            + events.count * 5              // each extra's place and time
            + debris.count * 8              // each debris piece
            + splinters.count * 3 + extraSplinterDraws
        var replay = before
        for _ in 0..<draws { _ = replay.psRand() }
        XCTAssertEqual(
            world.authoritativeRandomState,
            replay.authoritativeRandomState
        )
    }

    /// The made objects live their own frames: DoExplosionEvent makes the
    /// delayed fireballs (with a sound draw each), and the debris and
    /// splinters fall, bounce, and die (DoDebrisFrame, DoSplinterFrame).
    func testDeathEffectsRunOutThroughTheFrame() throws {
        let level = makeTrainingRobotGuidebotLevel()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        session.world.killObject(
            robot,
            killer: session.world.testPlayerObject.handle,
            damage: 10,
            level: level
        )
        let events = session.world.gameEvents.compactMap { $0 }.count
        var timestamp = 0.0
        var sawDelayedFireballs = false
        for _ in 0..<80 {
            timestamp += 0.1
            _ = session.update(at: timestamp, input: .zero)
            if session.world.gameEvents.compactMap({ $0 }).isEmpty {
                sawDelayedFireballs = true
            }
        }
        XCTAssertTrue(sawDelayedFireballs || events == 0)
        XCTAssertTrue(session.world.gameEvents.allSatisfy { $0 == nil })
        XCTAssertTrue(session.world.objects.filter {
            [.debris, .splinter, .fireball].contains($0.type)
        }.isEmpty)
        XCTAssertNoThrow(try session.world.validate(against: level))
    }

    /// DF_BLAST_RING: KillObject queues 0 to 2 more rings 0.1 s apart
    /// (damage.cpp:1211-1215), and DestroyObject's CreateBlastRing makes a
    /// ring object (fireball.cpp:1972) of DAMAGE_RING_TIME, with a blue ring
    /// or a turn toward the viewer.
    func testBlastRingDeathMakesRingObjectsAndDelayedRings() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        world.killObject(
            robot,
            killer: .none,
            damage: 10,
            deathFlags: DeathFlags.blastRing,
            delayTime: 0,
            level: level
        )
        let rings = world.objects.filter { $0.type == .fireball }
        XCTAssertTrue((1...2).contains(rings.count))
        for ring in rings {
            XCTAssertEqual(ring.fireball?.id, VisEffect.blastRingID)
            XCTAssertTrue([1.5, 0.75, 1].contains(ring.lifeLeft ?? 0))
        }
        let queued = world.gameEvents.compactMap { $0 }
        XCTAssertTrue((0...2).contains(queued.count))
        for (index, event) in queued.enumerated() {
            XCTAssertEqual(event.endTime, Float(index) * 0.1 + 0.1,
                           accuracy: 0.000_01)
        }
        // ProcessNormalEvents stops once it has seen Num_events used slots,
        // and FreeEvent lowers Num_events as it goes (gameevent.cpp:147), so
        // a frame that runs the first event leaves the second for the next.
        world.gameTime = 0.25
        world.processNormalEvents(level: level)
        XCTAssertEqual(
            world.gameEvents.compactMap { $0 }.count,
            queued.count == 2 ? 1 : 0
        )
        world.processNormalEvents(level: level)
        XCTAssertTrue(world.gameEvents.allSatisfy { $0 == nil })
        XCTAssertGreaterThanOrEqual(
            world.objects.filter { $0.type == .fireball }.count,
            rings.count + queued.count
        )
    }

    /// VisEffectCreate refuses an effect in a room no frame rendered in the
    /// last 5 seconds (viseffect.cpp:588).
    func testVisualEffectsNeedARecentlyRenderedRoom() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        let room = try XCTUnwrap(level.rooms.first)
        world.gameTime = 5
        XCTAssertNotNil(world.visEffectCreate(
            id: VisEffect.blackSmokeID,
            roomSourceIndex: room.sourceIndex,
            position: .zero,
            level: level
        ))
        world.gameTime = 5.5
        XCTAssertNil(world.visEffectCreate(
            id: VisEffect.blackSmokeID,
            roomSourceIndex: room.sourceIndex,
            position: .zero,
            level: level
        ))
        world.rooms[0].lastRenderTime = 1
        XCTAssertNotNil(world.visEffectCreate(
            id: VisEffect.blackSmokeID,
            roomSourceIndex: room.sourceIndex,
            position: .zero,
            level: level
        ))
    }

    /// A frame marks the rooms it renders (render.cpp:2930).
    func testTheFrameMarksTheRoomsItRenders() throws {
        let level = makeTrainingRobotGuidebotLevel()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        _ = session.update(at: 0.1, input: .zero)
        _ = session.update(at: 0.2, input: .zero)
        let player = session.world.testPlayerObject
        guard case let .room(room) = player.location else {
            return XCTFail("indoor player")
        }
        let index = try XCTUnwrap(level.rooms.firstIndex {
            $0.sourceIndex == room
        })
        XCTAssertEqual(session.world.rooms[index].lastRenderTime, 0.1,
                       accuracy: 0.000_1)
    }

    /// DoDyingFrame's DF_DELAY_SPARKS (fireball.cpp:1446-1461): near the
    /// end of the delay every frame draws a bolt count of 3 to 8, and each
    /// bolt that picks a submodel with vertices spans two of them.
    func testSparkingDeathMakesAttachedLightningBolts() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        world.killObject(
            robot,
            killer: .none,
            damage: 10,
            deathFlags: DeathFlags.delaySparks,
            delayTime: 0.25,
            level: level
        )
        world.frameDuration = 0.02
        world.objDoFrameSlots(0..<ObjectTable.capacity, level: level)
        let bolts = world.visEffects.filter {
            $0.id == VisEffect.lightningBoltID
        }
        XCTAssertTrue((1...7).contains(bolts.count), "\(bolts.count)")
        for bolt in bolts {
            XCTAssertEqual(bolt.attachedObject, robot)
            XCTAssertNotEqual(bolt.attachedSubmodel, 1)
            XCTAssertNotEqual(bolt.flags & VisEffect.attachedFlag, 0)
        }
    }

    /// DoDeathSpew (fireball.cpp:1134): each possible object draws against
    /// the spew percent; a spewed object is made (ObjInitGeneric draws
    /// first), thrown with three draws, and falls with its page physics.
    func testDeathSpewThrowsPowerupsThatFall() throws {
        var robotPage = fixtureTargetRobotInfo
        robotPage.deathSpew = CanonicalDeathSpew(
            flags: 0,
            entries: [
                .init(pageName: "Energy", percent: 1, number: 2),
                .init(pageName: "", percent: 0, number: 0),
            ]
        )
        robotPage.explodeSound = ""
        let energy = CanonicalObjectInfo(
            name: "Energy",
            type: 7,
            flags: CanonicalObjectInfo.usesPhysicsFlag,
            size: 2,
            hitPoints: 0,
            lightDistance: 0,
            lighting: fixtureNoLight,
            ai: nil,
            weaponBatteries: [],
            physics: ObjectPhysics(
                flags: ObjectPhysics.gravityFlag | ObjectPhysics.bounceFlag,
                mass: 1,
                drag: 0.1
            )
        )
        let level = makeTrainingRobotGuidebotLevel()
            .addingObjectInfo(robotPage)
            .addingObjectInfo(energy)
        var world = GameWorld(level: level)
        let target = try XCTUnwrap(world.objects[robot])
        world.destroyObject(
            robot,
            explosionMagnitude: 30,
            deathFlags: 0,
            level: level
        )
        let spewed = world.objects.filter { $0.type == .powerup
            && $0.creationTime == world.gameTime && $0.physics != nil }
        XCTAssertEqual(spewed.count, 2)
        for powerup in spewed {
            XCTAssertEqual(powerup.position, target.position)
            XCTAssertLessThanOrEqual(abs(powerup.velocity.x), 17.5)
            XCTAssertLessThanOrEqual(abs(powerup.velocity.y), 17.5)
            XCTAssertLessThanOrEqual(abs(powerup.velocity.z), 17.5)
        }
        let start = spewed[0]
        world.frameDuration = 0.1
        world.objDoFrameSlots(0..<ObjectTable.capacity, level: level)
        let moved = try XCTUnwrap(world.objects[start.handle])
        XCTAssertNotEqual(moved.position, start.position)
    }

    /// ConvertEulerToAxisAmount (collide.cpp:1523-1567) by hand for a yaw of
    /// 1 angle unit per second: e_n is (0, 0.0001, 0) radians, so
    /// CollideAnglesToMatrix gives rvec.z = sin h and fvec.x = -sin h; the
    /// source's n.y = fvec.x - rvec.z = -2 sin h normalizes to -1, and as
    /// sin(acos(cos h)) >= 0 the axis flips to (0, 1, 0). The amount is
    /// 2 pi / 65535.
    func testEulerToAxisAmountFollowsTheSourceSigns() throws {
        let world = GameWorld(level: makeTrainingRobotGuidebotLevel())
        let (axis, amount) = world.convertEulerToAxisAmount(
            Vector3(x: 0, y: 1, z: 0)
        )
        XCTAssertEqual(axis.x, 0, accuracy: 0.000_1)
        XCTAssertEqual(axis.y, 1, accuracy: 0.000_1)
        XCTAssertEqual(axis.z, 0, accuracy: 0.000_1)
        XCTAssertEqual(amount, 2 * Float.pi / 65_535, accuracy: 0.000_001)
    }

    /// VisEffectMoveOne (viseffect.cpp:2037-2047): an attached effect dies
    /// with its object.
    func testAttachedBoltsDieWithTheirObject() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        world.killObject(
            robot, killer: .none, damage: 10,
            deathFlags: DeathFlags.delaySparks, delayTime: 0.25, level: level
        )
        world.frameDuration = 0.02
        world.objDoFrameSlots(0..<ObjectTable.capacity, level: level)
        XCTAssertFalse(world.visEffects.filter {
            $0.flags & VisEffect.attachedFlag != 0
        }.isEmpty)
        // A saved world with the attached bolts is valid.
        XCTAssertNoThrow(try world.validate(against: level))
        world.objects.delete(robot)
        world.visEffectMoveAll(level: level)
        world.visEffectDeleteDead()
        XCTAssertTrue(world.visEffects.filter {
            $0.flags & VisEffect.attachedFlag != 0
        }.isEmpty)
    }

    /// DoDyingFrame scores after DestroyObject (fireball.cpp:1436-1441):
    /// DF_REMAINS has made the object OBJ_DEBRIS, which is not generic, so
    /// a delayed death that leaves remains scores nothing.
    func testDelayedRemainsDeathScoresNothing() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        world.killObject(
            robot, killer: world.testPlayerObject.handle, damage: 10,
            deathFlags: DeathFlags.remains, delayTime: 0.05, level: level
        )
        world.frameDuration = 0.1
        world.objDoFrameSlots(0..<ObjectTable.capacity, level: level)
        XCTAssertEqual(world.objects[robot]?.type, .debris)
        XCTAssertEqual(world.playerScore, 0)
    }

    /// A dying object that falls into a wall with no bounces left is
    /// destroyed (physics.cpp:1329-1333); with DF_REMAINS it stays as
    /// motionless remains (MT_NONE) and does not die again.
    func testRemainsFromAWallImpactStopMoving() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        let shell = try XCTUnwrap(level.rooms.first { room in
            room.faces.indices.contains { index in
                !room.portals.contains { $0.faceIndex == index }
            }
        })
        let wall = try XCTUnwrap(shell.faces.indices.first { index in
            !shell.portals.contains { $0.faceIndex == index }
        })
        let normal = try XCTUnwrap(
            canonicalFaceNormal(room: shell, face: shell.faces[wall])
        )
        let corners = shell.faces[wall].corners
        let center = corners.reduce(Vector3.zero) {
            $0 + shell.vertices[$1.vertexIndex]
        } / Float(corners.count)
        world.objects[robot]?.location = .room(shell.sourceIndex)
        world.killObject(
            robot, killer: .none, damage: 10,
            deathFlags: DeathFlags.remains | DeathFlags.delayLosesAntigravity,
            delayTime: 5, level: level
        )
        let size = try XCTUnwrap(world.objects[robot]).size
        world.objects[robot]?.position = center + normal * (size + 2)
        world.objects[robot]?.velocity = normal * -100
        world.frameDuration = 0.1
        world.objDoFrameSlots(0..<ObjectTable.capacity, level: level)
        let remains = try XCTUnwrap(world.objects[robot])
        XCTAssertEqual(remains.type, .debris)
        XCTAssertNil(remains.physics)
        XCTAssertEqual(remains.flags & GameObject.deadFlag, 0)
        world.objDoFrameSlots(0..<ObjectTable.capacity, level: level)
        let later = try XCTUnwrap(world.objects[robot])
        XCTAssertEqual(later.position, remains.position)
        XCTAssertEqual(later.flags & GameObject.deadFlag, 0)
    }
}
