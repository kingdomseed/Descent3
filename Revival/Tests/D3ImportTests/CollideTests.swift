import XCTest

// Object collisions (Descent3/collide.cpp): collide_two_objects and its
// script events, the CollideInit pair table, a weapon hit's room, the
// force-field bounce, and the rotation of a hit.
final class CollideTests: XCTestCase {
    private let robot = ObjectHandle(4_112)

    /// collide_two_objects sends EVT_COLLIDE to A with it = B, then to B
    /// with it = A (collide.cpp:2488-2496).
    func testCollideSendsEventToBothObjectsInLegacyOrder() {
        let a = ObjectHandle(0x0800)
        let b = ObjectHandle(0x1003)
        let calls = collideScriptEvents(a, b)
        XCTAssertEqual(calls.map(\.me), [a, b])
        XCTAssertEqual(calls.map(\.event), [.collide(it: b), .collide(it: a)])
    }

    /// Each object's EVT_COLLIDE goes through its own script chain: the
    /// player (no Training script) first, then the powerup's custom
    /// script, which runs Script 001.
    func testCollideTwoObjectsRunsTheHitObjectsCustomScript() throws {
        let level = makeTrainingScript003Level()
        var world = GameWorld(level: level)
        let player = try XCTUnwrap(level.defaultPlayerBinding).objectHandle
        let forwardGoal = level.findObjectName("ForwardGoal")
        XCTAssertNil(world.objects[ObjectHandle(player)]?.scripts)
        XCTAssertEqual(
            world.objects[forwardGoal]?.scripts,
            ObjectScripts(custom: 0x001, level: nil)
        )
        world.collideTwoObjects(ObjectHandle(player), forwardGoal, level: level)
        XCTAssertEqual(world.testTrainingMission?.script001Count, 1)
        XCTAssertEqual(world.presentationRequests, [
            .hudMessage("Excellent!"),
            .streamedAudio(name: "return1.osf", volume: 1),
            .hudMessage(trainingText("GoBackwards")),
        ])
    }

    /// CollideInit (collide.cpp:2585-2624): the player and a powerup check
    /// sphere against sphere; the pairs whose response is not translated
    /// yet check nothing.
    func testCollisionResultPairsPlayerWithPowerup() {
        XCTAssertEqual(collisionResult(.player, .powerup), .sphereSphere)
        XCTAssertEqual(collisionResult(.powerup, .player), .sphereSphere)
        XCTAssertEqual(collisionResult(.powerup, .powerup), .nothing)
        XCTAssertEqual(collisionResult(.player, .dummy), .nothing)
    }

    /// do_physics_sim moves a weapon to fvi's hit point and hit room
    /// before the object collision runs (ObjSetPos, physics.cpp:1142): a
    /// bolt that crosses an open portal and hits a robot there is in the
    /// robot's room when collide_two_objects runs.
    func testWeaponHitAcrossAPortalTakesTheRoomOfTheHitPoint() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        let crossing = try XCTUnwrap(openPortalCrossing(level, world: world))
        fire(&world, .primary, level: level)
        let bolt = try XCTUnwrap(world.objects.first { $0.type == .weapon })
        for other in world.objects where other.type == .weapon
            && other.handle != bolt.handle {
            world.objects.delete(other.handle)
        }
        world.objects[bolt.handle]?.location = .room(crossing.room)
        world.objects[bolt.handle]?.position = crossing.center
            + crossing.normal * 3
        world.objects[bolt.handle]?.velocity = crossing.normal * -225
        world.objects[robot]?.location = .room(crossing.connectedRoom)
        world.objects[robot]?.position = crossing.center
            - crossing.normal * 15
        world.frameDuration = 0.1
        world.objDoFrameSlots(0..<ObjectTable.capacity, level: level)
        let hit = try XCTUnwrap(world.objects[bolt.handle])
        XCTAssertNotEqual(hit.flags & GameObject.deadFlag, 0)
        // fvi's hit room is the room past the last portal the straight
        // move crossed; the fixture's rooms share their portal plane, so
        // the move crosses them all.
        let path = traceIndoorMovement(
            in: level, startRoom: crossing.room,
            start: crossing.center + crossing.normal * 3, end: hit.position,
            radius: 0
        )
        let last = try XCTUnwrap(path.passedPortalFaces.last)
        let hitRoom = try XCTUnwrap(level.rooms.first {
            $0.sourceIndex == last.roomSourceIndex
        }?.portals.first { $0.faceIndex == last.faceIndex }).connectedRoom
        XCTAssertNotEqual(hitRoom, crossing.room)
        XCTAssertEqual(hit.location, .room(hitRoom))
        XCTAssertLessThan(try XCTUnwrap(world.objects[robot]).shields, 55)
    }

    /// An energy weapon that hits a force field (TF_FORCEFIELD) lives
    /// (collide.cpp:1117-1136), is mirrored off the wall, loses
    /// PF_NO_COLLIDE_PARENT, and flies on with the frame time left
    /// (physics.cpp:1280, :1317-1365). A matter weapon explodes there as on
    /// any wall.
    func testEnergyWeaponsBounceOffForceFieldsAndMatterWeaponsExplode() throws {
        let base = makeTrainingRobotGuidebotLevel()
        let level = replacing(
            base,
            surfacePhysics: base.surfacePhysics.map {
                SurfacePhysicsEntry(
                    texture: $0.texture,
                    behavior: $0.behavior == .passThrough
                        ? .passThrough : .forceField
                )
            }
        )
        for secondary in [false, true] {
            var world = GameWorld(level: level)
            world.playerWeapons[PlayerWeaponState.secondary].index =
                PlayerWeaponState.concussionIndex
            fire(&world, secondary ? .secondary : .primary, level: level)
            let shot = try XCTUnwrap(world.objects.first { $0.type == .weapon })
            for other in world.objects where other.type == .weapon
                && other.handle != shot.handle {
                world.objects.delete(other.handle)
            }
            // A room wall: the shot 5 units in front of its center,
            // flying at it.
            guard let roomData = level.rooms.first(where: { candidate in
                      candidate.faces.indices.contains { index in
                          !candidate.portals.contains { $0.faceIndex == index }
                      }
                  }),
                  let wall = roomData.faces.indices.first(where: { index in
                      !roomData.portals.contains { $0.faceIndex == index }
                          && canonicalFaceNormal(
                              room: roomData, face: roomData.faces[index]
                          ) != nil
                  }),
                  let normal = canonicalFaceNormal(
                      room: roomData, face: roomData.faces[wall]
                  )
            else {
                return XCTFail("indoor shot with a wall")
            }

            let corners = roomData.faces[wall].corners
            let center = corners.reduce(Vector3.zero) {
                $0 + roomData.vertices[$1.vertexIndex]
            } / Float(corners.count)
            let direction = normal * -1
            let speed: Float = 100
            let start = center + normal * (5 + shot.size)
            let contact = (normal: normal, point: center)
            world.objects[shot.handle]?.position = start
            world.objects[shot.handle]?.location = .room(roomData.sourceIndex)
            world.objects[shot.handle]?.velocity = direction * speed
            world.frameDuration = 0.1
            world.objDoFrameSlots(0..<ObjectTable.capacity, level: level)
            let moved = try XCTUnwrap(world.objects[shot.handle])
            if secondary {
                XCTAssertNotEqual(moved.flags & GameObject.deadFlag, 0)
                XCTAssertNotNil(world.objects.first { $0.type == .shockwave })
                continue
            }
            XCTAssertEqual(moved.flags & GameObject.deadFlag, 0)
            XCTAssertFalse(moved.noCollideParent)
            let incoming = direction * speed
            let reflected = incoming
                - contact.normal * (2 * dot(contact.normal, incoming))
            XCTAssertEqual(moved.velocity.x, reflected.x, accuracy: 0.5)
            XCTAssertEqual(moved.velocity.y, reflected.y, accuracy: 0.5)
            XCTAssertEqual(moved.velocity.z, reflected.z, accuracy: 0.5)
            // 5 units to the wall, then the other 5 back off it.
            XCTAssertGreaterThan(
                dot(moved.position - contact.point, contact.normal),
                shot.size + 3
            )
            XCTAssertGreaterThan(dot(moved.orientation.forward, reflected), 0)
            XCTAssertTrue(world.visEffects.isEmpty)
        }
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
}
