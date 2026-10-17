import XCTest

// The weapons as generic objects (Descent3/WeaponFire.cpp): the player's
// laser, Concussion, and flare batteries (FireWeaponFromPlayer :2830,
// FireFlareFromPlayer :3023) with their energy, ammo, waits, and gun
// points; weapon ageing, particles (WeaponDoFrame :1706), sticking
// (physics.cpp:1290, collide.cpp:2146), timeout spawns (:3162), the
// shockwave (DoWeaponExploded :3058), ObjectsAreRelated (:962), the flicker
// light (object_lighting.cpp:379), and the generic weapon drawing.
final class WeaponFireTests: XCTestCase {
    private let robot = ObjectHandle(4_112)
    private let seed: UInt32 = 0x1357_9bdf

    // MARK: Fixtures

    private struct FlareWorld {
        let level: Level
        var world: GameWorld
        let player: GameObject
        let flare: Int
        let spark: Int
    }

    private func makeFlareWorld() throws -> FlareWorld {
        let level = makeTrainingGuidebotYellowFlareLevel()
        try level.validate()
        let world = GameWorld(level: level, authoritativeRandomSeed: seed)
        return FlareWorld(
            level: level,
            world: world,
            player: world.testPlayerObject,
            flare: try XCTUnwrap(level.weapons?.firstIndex {
                $0.name == "Yellow flare"
            }),
            spark: try XCTUnwrap(level.weapons?.firstIndex {
                $0.name == "YellowFlareSparks"
            })
        )
    }

    /// A flare the player fired from `distance` ahead of it.
    private func makeFlare(_ fixture: inout FlareWorld,
                           ahead distance: Float) throws -> ObjectHandle {
        let player = fixture.player
        return try XCTUnwrap(fixture.world.createAndFireWeapon(
            position: player.position
                + player.orientation.forward * distance,
            direction: player.orientation.forward,
            parent: player.handle,
            weaponIndex: fixture.flare,
            level: fixture.level
        ))
    }

    /// ps_rand (misc/psrand.cpp) from `state`: the next `count` values.
    private func psRandValues(after state: UInt32, _ count: Int) -> [Int32] {
        var state = state
        return (0..<count).map { _ in
            state = state &* 214_013 &+ 2_531_011
            return Int32((state >> 16) & 0x7fff)
        }
    }

    private func psRandState(after state: UInt32, _ count: Int) -> UInt32 {
        var state = state
        for _ in 0..<count { state = state &* 214_013 &+ 2_531_011 }
        return state
    }

    func testEvaderFiresItsUnturretedBurstThroughFramesAndDamagesThePlayer() throws {
        let level = makeNonAnimatedRobotFireLevel()
        try level.validate()
        let session = GameSession(level: level, presentationReadyTimestamp: 0,
                                  authoritativeRandomSeed: seed)
        prepareNonAnimatedRobotFire(session)
        let enemy = ObjectHandle(4_112)
        var shots: [(time: Float, mask: Int)] = []
        var previousFireTime: Float = -1
        var sawProjectile = false
        for frame in 1...60 {
            _ = session.update(at: Double(frame) * 0.1, input: .zero)
            let battery = try XCTUnwrap(session.world.objects[enemy]?.weaponBatteries.first)
            if battery.lastFireTime != previousFireTime {
                shots.append((battery.lastFireTime, battery.currentFiringMask))
                previousFireTime = battery.lastFireTime
            }
            sawProjectile = sawProjectile || session.world.objects.contains {
                $0.type == .weapon && $0.parent == enemy
            }
        }
        XCTAssertTrue(sawProjectile)
        XCTAssertGreaterThan(shots.count, 4)
        XCTAssertEqual(Array(shots.prefix(5).map(\.mask)), [1, 2, 3, 0, 1])
        for (index, pair) in zip(shots, shots.dropFirst()).prefix(4).enumerated() {
            XCTAssertEqual(pair.1.time - pair.0.time,
                           index == 3 ? 2.4 : 0.2, accuracy: 0.11)
        }
        XCTAssertLessThan(session.world.shields, 100)
        XCTAssertNil(session.world.playerDeath)
    }

    // MARK: Firing

    /// FireFlareFromPlayer: the flare key fires the ship's FLARE_INDEX
    /// battery from gun point 0 along its normal, with the battery's Flare
    /// sound, at most once a second (WBIsBatteryReady). The flare is a
    /// Yellow flare weapon object: RT_WEAPON, the custom size, the page's
    /// life and speed, the player as parent, and a particle clock at 0. Its
    /// slot follows the player's, so its first ObjDoFrame is this frame: it
    /// moves 10. At Gametime 0 no particle is due yet, and the first frame
    /// has no rendered view, so it makes no draw. Later frames drop its
    /// particles and, in the rendered view, flicker its light.
    func testPlayerFlareFiresTheFlareBatteryOncePerSecond() throws {
        let level = try makePlayerYellowFlareLevel()
        let flareIndex = try XCTUnwrap(level.weapons?.firstIndex {
            $0.name == "Yellow flare"
        })
        let session = GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
        let control = GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
        let player = session.world.testPlayerObject
        let shipModel = try XCTUnwrap(level.polygonModel(of: player))
        let gun = session.world.weaponCalcGun(
            player, gunpoint: 0, model: shipModel
        )
        let frame = session.update(
            at: 0.1, input: .init(firesPlayerFlare: true)
        )
        _ = control.update(at: 0.1, input: .zero)
        let flare = try XCTUnwrap(
            session.world.objects.filter { $0.weapon == flareIndex }.only
        )
        XCTAssertGreaterThan(flare.handle.slot, player.handle.slot)
        XCTAssertEqual(flare.parent, player.handle)
        XCTAssertEqual(flare.renderType, .weapon)
        XCTAssertEqual(flare.size, 0.1)
        XCTAssertEqual(try XCTUnwrap(flare.lifeLeft), 14.9, accuracy: 1e-5)
        XCTAssertEqual(flare.orientation.forward.x, gun.normal.x,
                       accuracy: 1e-5)
        XCTAssertEqual(flare.orientation.forward.z, gun.normal.z,
                       accuracy: 1e-5)
        let expected = gun.point + gun.normal * 10
        XCTAssertEqual(flare.position.x, expected.x, accuracy: 1e-3)
        XCTAssertEqual(flare.position.y, expected.y, accuracy: 1e-3)
        XCTAssertEqual(flare.position.z, expected.z, accuracy: 1e-3)
        XCTAssertEqual(flare.lastDropTime, 0)
        XCTAssertEqual(
            frame.presentationFeedback.filter {
                $0.soundSourceName == "Flare"
            }.count,
            1
        )
        XCTAssertTrue(session.world.visEffects.filter {
            $0.id == VisEffect.particleID
        }.isEmpty)
        XCTAssertEqual(
            session.world.authoritativeRandomState,
            control.world.authoritativeRandomState
        )
        XCTAssertTrue(frame.objectLights.isEmpty)
        let battery = try XCTUnwrap(
            session.world.testPlayerObject
                .weaponBatteries[PlayerWeaponState.flareIndex]
        )
        XCTAssertEqual(battery.lastFireTime, 0)

        // The battery waits one second: presses before then fire nothing.
        var timestamp = 0.1
        for _ in 0..<9 {
            timestamp += 0.1
            _ = session.update(
                at: timestamp, input: .init(firesPlayerFlare: true)
            )
        }
        XCTAssertEqual(
            session.world.objects.filter { $0.weapon == flareIndex }.count,
            1
        )
        // The rendered view now sees the flare: its light flickers.
        timestamp += 0.1
        let lit = session.update(at: timestamp, input: .zero)
        XCTAssertEqual(lit.objectLights.count, 1)
        XCTAssertFalse(session.world.visEffects.filter {
            $0.id == VisEffect.particleID
        }.isEmpty)
        timestamp += 0.1
        _ = session.update(at: timestamp, input: .init(firesPlayerFlare: true))
        XCTAssertEqual(
            session.world.objects.filter { $0.weapon == flareIndex }.count,
            2
        )
    }

    /// Capacity drops keep the gameplay effects: with the object table full
    /// the flare is not made, but the battery's fire time and mask advance
    /// as WBFireBattery does; no sound plays and no draw is made.
    func testAFullObjectTableMakesNoFlareButUsesTheBattery() throws {
        var fixture = try makeFlareWorld()
        let player = fixture.player
        while fixture.world.objects.create(
            type: .debris, renderType: .none, location: player.location,
            position: player.position, orientation: player.orientation
        ) != nil {}
        fixture.world.gameTime = 2
        let state = fixture.world.authoritativeRandomState
        fixture.world.fireFlareFromPlayer(player.handle, level: fixture.level)
        XCTAssertTrue(fixture.world.objects.filter {
            $0.type == .weapon
        }.isEmpty)
        XCTAssertEqual(
            fixture.world.objects[player.handle]?
                .weaponBatteries[PlayerWeaponState.flareIndex].lastFireTime,
            2
        )
        XCTAssertTrue(fixture.world.presentationRequests.isEmpty)
        XCTAssertEqual(fixture.world.authoritativeRandomState, state)
    }

    // MARK: Particles

    /// WeaponDoFrame's particle drop (WeaponFire.cpp:1706-1716): a drop is
    /// due when more than 1 / particle_count seconds passed since the last
    /// one. CreateRandomParticles (viseffect.cpp:900) makes a PARTICLE_INDEX
    /// effect behind the weapon by its size, and draws, in order, the
    /// direction's x, y, and z, the speed, the size, and the life. The
    /// drop time moves on even when no effect could be made: the room was
    /// not rendered in 5 s, or the list is full; then no draw is made.
    func testParticlesDropOnTheirIntervalWithTheirSixDraws() throws {
        var fixture = try makeFlareWorld()
        let handle = try makeFlare(&fixture, ahead: 5)
        fixture.world.gameTime = 1
        for index in fixture.world.rooms.indices {
            fixture.world.rooms[index].lastRenderTime = 1
        }

        // Not yet due: 0.03 s since the last drop.
        fixture.world.objects[handle]?.lastDropTime = 0.97
        var state = fixture.world.authoritativeRandomState
        fixture.world.weaponDoFrame(handle, level: fixture.level)
        XCTAssertTrue(fixture.world.visEffects.isEmpty)
        XCTAssertEqual(fixture.world.objects[handle]?.lastDropTime, 0.97)
        XCTAssertEqual(fixture.world.authoritativeRandomState, state)

        // Due: 0.05 s since the last drop.
        fixture.world.objects[handle]?.lastDropTime = 0.95
        let flare = try XCTUnwrap(fixture.world.objects[handle])
        let draws = psRandValues(after: state, 6)
        fixture.world.weaponDoFrame(handle, level: fixture.level)
        let particle = try XCTUnwrap(fixture.world.visEffects.only)
        XCTAssertEqual(particle.id, VisEffect.particleID)
        XCTAssertEqual(particle.customWeapon, fixture.flare)
        XCTAssertEqual(
            particle.position,
            flare.position - flare.orientation.forward * flare.size
        )
        let direction = osirisNormalizedFast(Vector3(
            x: Float(draws[0] % 100 - 50), y: Float(draws[1] % 100),
            z: Float(draws[2] % 100 - 50)
        ))
        XCTAssertEqual(particle.velocity, direction * Float(10 + draws[3] % 10))
        XCTAssertEqual(
            particle.size, 0.2 + Float(draws[4] % 11 - 5) * (0.2 / 10)
        )
        XCTAssertEqual(
            particle.lifetime, 0.3 + Float(draws[5] % 11 - 5) * (0.3 / 10)
        )
        XCTAssertEqual(particle.lifeLeft, particle.lifetime)
        XCTAssertEqual(particle.mass, 100)
        XCTAssertEqual(particle.drag, 0.1)
        XCTAssertEqual(
            particle.physicsFlags,
            WeaponPhysics.gravityFlag | WeaponPhysics.noCollideFlag
        )
        XCTAssertEqual(fixture.world.objects[handle]?.lastDropTime, 1)
        XCTAssertEqual(
            fixture.world.authoritativeRandomState, psRandState(after: state, 6)
        )

        // A room no frame rendered in 5 s makes no particle and no draw.
        fixture.world.gameTime = 7
        state = fixture.world.authoritativeRandomState
        fixture.world.weaponDoFrame(handle, level: fixture.level)
        XCTAssertEqual(fixture.world.visEffects.count, 1)
        XCTAssertEqual(fixture.world.objects[handle]?.lastDropTime, 7)
        XCTAssertEqual(fixture.world.authoritativeRandomState, state)

        // A full list makes none either.
        fixture.world.gameTime = 8
        for index in fixture.world.rooms.indices {
            fixture.world.rooms[index].lastRenderTime = 8
        }
        fixture.world.visEffects = Array(
            repeating: particle, count: VisEffect.capacity
        )
        fixture.world.weaponDoFrame(handle, level: fixture.level)
        XCTAssertEqual(fixture.world.visEffects.count, VisEffect.capacity)
        XCTAssertEqual(fixture.world.objects[handle]?.lastDropTime, 8)
        XCTAssertEqual(fixture.world.authoritativeRandomState, state)
    }

    // MARK: Sticking

    /// PF_STICK on a wall (physics.cpp:1290-1315): the flare stops where
    /// it hit (MT_NONE, velocity 0) and lives on; a wall that is not a
    /// portal face notes no portal. A stopped flare does not move again.
    func testFlareSticksToAWall() throws {
        var fixture = try makeFlareWorld()
        let player = fixture.player
        guard case let .room(room) = player.location else {
            return XCTFail("indoor player")
        }

        let toWall = traceIndoorMovement(
            in: fixture.level, roomStates: fixture.world.rooms, startRoom: room,
            start: player.position,
            end: player.position + player.orientation.forward * 5_000,
            radius: 0.1
        )
        guard case let .wallHit(contact) = toWall.outcome else {
            return XCTFail("the shell stops the flare")
        }

        let handle = try makeFlare(&fixture, ahead: contact.distance - 15)
        fixture.world.frameDuration = 0.1
        fixture.world.moveWeapon(handle, level: fixture.level)
        XCTAssertEqual(fixture.world.objects[handle]?.usesPhysics, true)
        fixture.world.moveWeapon(handle, level: fixture.level)
        let stuck = try XCTUnwrap(fixture.world.objects[handle])
        XCTAssertFalse(stuck.usesPhysics)
        XCTAssertEqual(stuck.velocity, .zero)
        XCTAssertEqual(stuck.flags & GameObject.deadFlag, 0)
        XCTAssertNil(stuck.stuckPortal)
        XCTAssertEqual(stuck.position.x, toWall.finalPosition.x, accuracy: 1e-2)
        XCTAssertEqual(stuck.position.y, toWall.finalPosition.y, accuracy: 1e-2)
        XCTAssertEqual(stuck.position.z, toWall.finalPosition.z, accuracy: 1e-2)
        // No explosion: a sticking weapon does not explode on the wall.
        XCTAssertTrue(fixture.world.visEffects.isEmpty)
    }

    /// OF_STUCK_ON_PORTAL (object.cpp:2783-2791): an MT_NONE weapon stuck
    /// on a portal face dies when the portal stops rendering its faces.
    func testAFlareStuckOnAPortalDiesWhenThePortalOpens() throws {
        var fixture = try makeFlareWorld()
        let handle = try makeFlare(&fixture, ahead: 5)
        let roomIndex = try XCTUnwrap(fixture.level.rooms.firstIndex {
            !$0.portals.isEmpty
        })
        let room = fixture.level.rooms[roomIndex]
        fixture.world.objects[handle]?.usesPhysics = false
        fixture.world.objects[handle]?.velocity = .zero
        fixture.world.objects[handle]?.flags |= GameObject.stuckOnPortalFlag
        fixture.world.objects[handle]?.stuckPortal = .init(
            roomSourceIndex: room.sourceIndex, portal: 0
        )
        fixture.world.rooms[roomIndex].portalFlags[0] |=
            LevelPortal.renderFacesFlag
        fixture.world.objDoFrameSlots(
            handle.slot..<(handle.slot + 1), level: fixture.level
        )
        XCTAssertEqual(
            (fixture.world.objects[handle]?.flags ?? 0)
                & GameObject.deadFlag,
            0
        )
        fixture.world.rooms[roomIndex].portalFlags[0] &=
            ~LevelPortal.renderFacesFlag
        fixture.world.objDoFrameSlots(
            handle.slot..<(handle.slot + 1), level: fixture.level
        )
        XCTAssertNotEqual(
            (fixture.world.objects[handle]?.flags ?? 0)
                & GameObject.deadFlag,
            0
        )
    }

    /// A flare that hits a robot runs collide_generic_and_weapon: it
    /// explodes (its FlarePuff), does its damage, and sticks
    /// (MakeWeaponStick, collide.cpp:2146): MT_OBJ_LINKED to the robot's
    /// submodel. The ObjDoFrameAll loop lists it and its tail moves it with
    /// the robot (DoPhysLinkedFrame, physics.cpp:87); linked objects are
    /// related (WeaponFire.cpp:973). When the robot is gone the flare dies.
    func testFlareSticksToARobotAndFollowsIt() throws {
        var fixture = try makeFlareWorld()
        let player = fixture.player
        let robot = try XCTUnwrap(fixture.world.objects.first {
            $0.type == .robot
                && fixture.level.polygonModel(of: $0) != nil
        })
        fixture.world.objects[robot.handle]?.location = player.location
        fixture.world.objects[robot.handle]?.position =
            player.position + player.orientation.forward * 40
        let shields = try XCTUnwrap(fixture.world.objects[robot.handle])
            .shields
        // Aim at the middle of the model's first textured face, from 20
        // units out along its normal.
        let placed = try XCTUnwrap(fixture.world.objects[robot.handle])
        let model = try XCTUnwrap(fixture.level.polygonModel(of: placed))
        let offsets = accumulatedModelOffsets(model)
        let target = try XCTUnwrap(model.submodels.indices.lazy.compactMap {
            index -> (Int, Vector3, Vector3)? in
            guard let face = model.submodels[index].faces.first(where: {
                if case .texture = $0.material { return $0.corners.count >= 3 }
                return false
            }) else {
                return nil
            }

            let points = face.corners.map {
                model.submodels[index].vertices[$0.vertexIndex].position
            }

            let sum = points.reduce(Vector3.zero, +)
            return (index, sum / Float(points.count) + offsets[index],
                    face.normal)
        }.first)
        let aim = placed.position + transform(target.1, by: placed.orientation)
        let normal = sourceVectorNormalized(
            transform(target.2, by: placed.orientation)
        )
        let handle = try XCTUnwrap(fixture.world.createAndFireWeapon(
            position: aim + normal * 20, direction: normal * -1,
            parent: player.handle, weaponIndex: fixture.flare,
            level: fixture.level
        ))
        fixture.world.frameDuration = 0.1
        for _ in 0..<5
        where fixture.world.objects[handle]?.objectLink == nil {
            fixture.world.moveWeapon(handle, level: fixture.level)
        }

        let stuck = try XCTUnwrap(fixture.world.objects[handle])
        let link = try XCTUnwrap(stuck.objectLink)
        XCTAssertEqual(link.parentHandle, robot.handle)
        XCTAssertEqual(link.submodel, target.0)
        XCTAssertFalse(stuck.usesPhysics)
        XCTAssertEqual(stuck.flags & GameObject.deadFlag, 0)
        XCTAssertLessThan(
            try XCTUnwrap(fixture.world.objects[robot.handle]).shields, shields
        )
        XCTAssertEqual(
            fixture.world.visEffects.filter {
                $0.id == VisEffect.customExplosionID
                    && $0.customWeapon == fixture.flare
            }.count,
            1
        )
        let hitRobot = try XCTUnwrap(fixture.world.objects[robot.handle])
        XCTAssertTrue(fixture.world.objectsAreRelated(
            stuck, hitRobot, level: fixture.level
        ))

        // The robot moves and turns; the flare keeps its place on it.
        let local = inverseTransform(
            stuck.position - hitRobot.position, by: hitRobot.orientation
        )
        let localForward = inverseTransform(
            stuck.orientation.forward, by: hitRobot.orientation
        )
        let turned = sourceMatrixMultiply(
            hitRobot.orientation,
            sourceRotationMatrix(pitch: 0, yaw: 16_384, roll: 0)
        )
        fixture.world.objects[robot.handle]?.position =
            hitRobot.position + .init(x: 0, y: 5, z: 0)
        fixture.world.objects[robot.handle]?.orientation = turned
        fixture.world.objDoFrameSlots(
            handle.slot..<(handle.slot + 1), level: fixture.level
        )
        XCTAssertEqual(fixture.world.physicsLinkList, [handle])
        fixture.world.objDoFrameAllTail(level: fixture.level)
        XCTAssertTrue(fixture.world.physicsLinkList.isEmpty)
        let moved = try XCTUnwrap(fixture.world.objects[handle])
        let expected = hitRobot.position + .init(x: 0, y: 5, z: 0)
            + transform(local, by: turned)
        XCTAssertEqual(moved.position.x, expected.x, accuracy: 1e-3)
        XCTAssertEqual(moved.position.y, expected.y, accuracy: 1e-3)
        XCTAssertEqual(moved.position.z, expected.z, accuracy: 1e-3)
        let expectedForward = transform(localForward, by: turned)
        XCTAssertEqual(moved.orientation.forward.x, expectedForward.x,
                       accuracy: 1e-3)
        XCTAssertEqual(moved.orientation.forward.z, expectedForward.z,
                       accuracy: 1e-3)

        fixture.world.objects.delete(robot.handle)
        fixture.world.doPhysLinkedFrame(handle, level: fixture.level)
        XCTAssertNotEqual(
            (fixture.world.objects[handle]?.flags ?? 0)
                & GameObject.deadFlag,
            0
        )
    }

    // MARK: Relations

    /// ObjectsAreRelated (WeaponFire.cpp:962): a weapon and its parent are
    /// related while it has PF_NO_COLLIDE_PARENT (3 s, cleared by
    /// WeaponDoFrame); two weapons always are, unless siblings that hit
    /// each other; a PF_NO_COLLIDE spark is related to everything; two
    /// non-weapons only within 3 s of one making the other. The flare and
    /// an object that shares its parent (the Guide-Bot the player's ship
    /// released) are not related, so the flare can hit it.
    func testObjectsAreRelatedFollowsTheWeaponRules() throws {
        var fixture = try makeFlareWorld()
        let flare = try makeFlare(&fixture, ahead: 5)
        let other = try makeFlare(&fixture, ahead: 6)
        func related(_ a: ObjectHandle, _ b: ObjectHandle) -> Bool {
            fixture.world.objectsAreRelated(
                fixture.world.objects[a]!, fixture.world.objects[b]!,
                level: fixture.level
            )
        }

        let player = fixture.player.handle
        XCTAssertTrue(related(flare, player))
        XCTAssertTrue(related(player, flare))
        XCTAssertTrue(related(flare, other))
        // A robot made by the player, as the Guide-Bot is.
        let robot = try XCTUnwrap(fixture.world.objects.first {
            $0.type == .robot
        })
        fixture.world.objects[robot.handle]?.parent = player
        fixture.world.objects[robot.handle]?.creationTime = 0
        XCTAssertFalse(related(flare, robot.handle))
        XCTAssertTrue(related(robot.handle, player))
        fixture.world.gameTime = 3.5
        XCTAssertFalse(related(robot.handle, player))
        // An attached object and its ultimate attach parent are related.
        fixture.world.objects[robot.handle]?.flags |= GameObject.attachedFlag
        fixture.world.objects[robot.handle]?.attachUltimateHandle = player
        XCTAssertTrue(related(robot.handle, player))
        XCTAssertTrue(related(player, robot.handle))
        fixture.world.objects[robot.handle]?.flags &= ~GameObject.attachedFlag
        fixture.world.weaponDoFrame(flare, level: fixture.level)
        XCTAssertFalse(fixture.world.objects[flare]!.noCollideParent)
        XCTAssertFalse(related(flare, player))
        // The timeout's sparks have PF_NO_COLLIDE.
        fixture.world.timeoutWeapon(flare, level: fixture.level)
        let spark = try XCTUnwrap(fixture.world.objects.first {
            $0.weapon == fixture.spark
        })
        XCTAssertTrue(related(spark.handle, robot.handle))
        XCTAssertTrue(related(robot.handle, spark.handle))
    }

    // MARK: Timeout

    /// TimeoutWeapon (WeaponFire.cpp:3348) of a WF_SPAWNS_TIMEOUT flare:
    /// DoWeaponExploded along its heading (its FlarePuff custom explosion,
    /// no draw), then CreateTimeoutSpawnFromWeapon (:3162): no alternate,
    /// so no draw; the first spark fires along the heading and the other
    /// eight on a ring a sixteenth of a turn off it (4096-unit twists), all
    /// from half the flare's size ahead, with the flare's parent as theirs.
    func testTimeoutMakesAFlarePuffAndNineSparks() throws {
        var fixture = try makeFlareWorld()
        let handle = try makeFlare(&fixture, ahead: 5)
        let flare = try XCTUnwrap(fixture.world.objects[handle])
        let state = fixture.world.authoritativeRandomState
        fixture.world.timeoutWeapon(handle, level: fixture.level)
        XCTAssertEqual(fixture.world.authoritativeRandomState, state)
        let puff = try XCTUnwrap(fixture.world.visEffects.only)
        XCTAssertEqual(puff.id, VisEffect.customExplosionID)
        XCTAssertEqual(puff.customWeapon, fixture.flare)
        XCTAssertEqual(puff.size, 2)
        XCTAssertEqual(puff.lifetime, 0.2)
        XCTAssertEqual(puff.position, flare.position)

        let sparks = fixture.world.objects.filter {
            $0.weapon == fixture.spark
        }
        XCTAssertEqual(sparks.count, 9)
        let origin = flare.position + flare.orientation.forward * 0.05
        let ring = cos(Float.pi / 8)
        var directions: [Vector3] = []
        for spark in sparks {
            XCTAssertEqual(spark.parent, fixture.player.handle)
            XCTAssertEqual(spark.position, origin)
            XCTAssertEqual(spark.size, 0.2)
            XCTAssertEqual(spark.lifeLeft, 0.2)
            XCTAssertEqual(spark.renderType, .weapon)
            let speed = sqrt(dot(spark.velocity, spark.velocity))
            // The ring's table-trig twist is not quite orthonormal, and
            // CreateAndFireWeapon scales the heading as it is.
            XCTAssertEqual(speed, 17, accuracy: 0.01)
            directions.append(spark.velocity / speed)
        }

        let along = directions.filter {
            dot($0, flare.orientation.forward) > 0.999_9
        }
        XCTAssertEqual(along.count, 1)
        for direction in directions where dot(
            direction, flare.orientation.forward
        ) <= 0.999_9 {
            XCTAssertEqual(dot(direction, flare.orientation.forward), ring,
                           accuracy: 2e-3)
        }
        for (index, direction) in directions.enumerated() {
            for other in directions[(index + 1)...] {
                XCTAssertLessThan(dot(direction, other), 0.999)
            }
        }
    }

    /// The lifeleft timeout in ObjDoFrame (object.cpp:2742): the flare's
    /// particle drop comes first (its control), then the timeout makes the
    /// sparks, then the flare is dead and does not move. A spark in a later
    /// slot than the flare gets its own ObjDoFrame in the same pass (its
    /// life drops by the frame and it drops its first particle: six draws);
    /// one in an earlier slot waits for the next frame.
    func testTimeoutSparksInLaterSlotsRunInTheSameFrame() throws {
        var fixture = try makeFlareWorld()
        let handle = try makeFlare(&fixture, ahead: 5)
        // Free a slot below the flare's, so a spark takes it.
        let filler = try XCTUnwrap(fixture.world.objects.create(
            type: .debris, renderType: .none, location: fixture.player.location,
            position: fixture.player.position,
            orientation: fixture.player.orientation
        ))
        let low = try XCTUnwrap(fixture.world.objects.first {
            $0.type != .player && $0.handle.slot < handle.slot
                && $0.handle != filler
        })
        fixture.world.objects.delete(low.handle)
        fixture.world.objects[handle]?.lifeLeft = 0.05
        fixture.world.frameDuration = 0.1
        fixture.world.gameTime = 1
        for index in fixture.world.rooms.indices {
            fixture.world.rooms[index].lastRenderTime = 1
        }

        var control = fixture.world
        control.objects[handle]?.lifeLeft = 10
        fixture.world.objDoFrameSlots(
            handle.slot..<ObjectTable.capacity, level: fixture.level
        )
        control.objDoFrameSlots(
            handle.slot..<ObjectTable.capacity, level: fixture.level
        )
        let sparks = fixture.world.objects.filter {
            $0.weapon == fixture.spark
        }
        XCTAssertEqual(sparks.count, 9)
        let later = sparks.filter { $0.handle.slot > handle.slot }
        let earlier = sparks.filter { $0.handle.slot < handle.slot }
        XCTAssertFalse(earlier.isEmpty)
        XCTAssertFalse(later.isEmpty)
        for spark in later {
            XCTAssertEqual(try XCTUnwrap(spark.lifeLeft), 0.1, accuracy: 1e-6)
            XCTAssertEqual(spark.lastDropTime, fixture.world.gameTime)
        }
        for spark in earlier {
            XCTAssertEqual(spark.lifeLeft, 0.2)
            XCTAssertEqual(spark.lastDropTime, 0)
        }
        XCTAssertNotEqual(
            (fixture.world.objects[handle]?.flags ?? 0)
                & GameObject.deadFlag,
            0
        )
        XCTAssertEqual(
            fixture.world.authoritativeRandomState,
            psRandState(
                after: control.authoritativeRandomState, 6 * later.count
            )
        )
    }

    /// A PF_NO_COLLIDE spark falls with gravity and drag and keeps its room,
    /// even through a wall (physics.cpp:957-968).
    func testSparksFallWithoutCollisions() throws {
        var fixture = try makeFlareWorld()
        let handle = try makeFlare(&fixture, ahead: 5)
        fixture.world.timeoutWeapon(handle, level: fixture.level)
        let spark = try XCTUnwrap(fixture.world.objects.first {
            $0.weapon == fixture.spark
        })
        fixture.world.objects[spark.handle]?.velocity =
            .init(x: 0, y: -100_000, z: 0)
        fixture.world.frameDuration = 0.1
        let start = try XCTUnwrap(fixture.world.objects[spark.handle])
        fixture.world.moveWeapon(spark.handle, level: fixture.level)
        let moved = try XCTUnwrap(fixture.world.objects[spark.handle])
        let motion = analyticLinearMotion(
            position: start.position, velocity: start.velocity,
            force: .init(x: 0, y: fixture.level.metadata.gravity * 0.1, z: 0),
            mass: 0.1, drag: 0.1, duration: 0.1
        )
        XCTAssertEqual(moved.position, motion.position)
        XCTAssertEqual(moved.velocity, motion.velocity)
        XCTAssertEqual(moved.location, start.location)
        XCTAssertEqual(moved.lastPosition, start.position)
    }

    // MARK: Light

    /// DoObjectLight for a weapon (object_lighting.cpp:340-456): in the
    /// last rendered view, the flare's OLF_FLICKER_SLIGHTLY light of 35
    /// (Katmai: 52.5) moves by ps_rand() % 5 - 2, one draw; out of the view
    /// it casts nothing and draws nothing.
    func testFlareLightFlickersWithOneDrawInTheRenderedView() throws {
        var fixture = try makeFlareWorld()
        let handle = try makeFlare(&fixture, ahead: 5)
        let flare = try XCTUnwrap(fixture.world.objects[handle])
        let forward = flare.orientation.forward
        fixture.world.lastRenderCamera = RoomCamera(
            position: flare.position - forward * 20, target: flare.position,
            up: flare.orientation.up
        )
        let state = fixture.world.authoritativeRandomState
        fixture.world.doObjectLight(handle, level: fixture.level)
        let light = try XCTUnwrap(fixture.world.objectLights.only)
        let draw = try XCTUnwrap(psRandValues(after: state, 1).first)
        XCTAssertEqual(light.distance, 52.5 + Float(draw % 5 - 2))
        XCTAssertEqual(light.position, flare.position)
        XCTAssertEqual(light.color, .init(x: 1, y: 1, z: 0.8))
        XCTAssertEqual(
            fixture.world.authoritativeRandomState, psRandState(after: state, 1)
        )

        fixture.world.objectLights = []
        fixture.world.lastRenderCamera = RoomCamera(
            position: flare.position + forward * 1_000,
            target: flare.position + forward * 2_000, up: flare.orientation.up
        )
        let away = fixture.world.authoritativeRandomState
        fixture.world.doObjectLight(handle, level: fixture.level)
        XCTAssertTrue(fixture.world.objectLights.isEmpty)
        XCTAssertEqual(fixture.world.authoritativeRandomState, away)
    }

    // MARK: Drawing

    /// The flare, its sparks, particles, explosion, and lights reach the
    /// renderer through the generic paths: the flare's model at its
    /// orientation (RT_WEAPON), the spark's vclip frame `Gametime /
    /// frame_time` (GetWeaponFireImage), a particle's frame by its age with
    /// its fade (DrawVisEffect), and the cast lights.
    func testFlareDrawsThroughTheGenericWeaponAndEffectPaths() throws {
        var fixture = try makeFlareWorld()
        let handle = try makeFlare(&fixture, ahead: 30)
        let flare = try XCTUnwrap(fixture.world.objects[handle])
        let other = try makeFlare(&fixture, ahead: 25)
        fixture.world.timeoutWeapon(other, level: fixture.level)
        fixture.world.objects[other]?.flags |= GameObject.deadFlag
        fixture.world.objDeleteDead(level: fixture.level)
        fixture.world.createRandomParticles(
            1, position: flare.position, roomSourceIndex: 1,
            weapon: fixture.flare, size: 0.2, life: 0.3, level: fixture.level
        )
        let playerView = defaultPlayerView(in: fixture.level)
        let models = extractWeaponObjectDrawItems(
            fixture.level, objects: fixture.world.objects,
            camera: playerView.camera
        )
        let flareModel = try XCTUnwrap(
            fixture.level.weapons?[fixture.flare].model
        )
        XCTAssertTrue(models.contains { $0.model == flareModel })

        let sparkFrames = fixtureYellowSparkFrames
        let billboards = weaponBillboardFrames(
            fixture.level, objects: fixture.world.objects, gameTime: 0.15
        )
        XCTAssertEqual(billboards.count, 9)
        XCTAssertTrue(billboards.allSatisfy {
            $0.texture == sparkFrames[2] && $0.size == 0.2
        })

        let effects = visEffectBillboardFrames(
            fixture.level, effects: fixture.world.visEffects, gameTime: 0.2
        )
        let particle = try XCTUnwrap(fixture.world.visEffects.first {
            $0.id == VisEffect.particleID
        })
        let age = 0.2 / particle.lifetime
        let particleFrame = try XCTUnwrap(effects.first {
            sparkFrames.contains($0.texture)
        })
        XCTAssertEqual(particleFrame.texture, sparkFrames[min(5, Int(6 * age))])
        XCTAssertEqual(
            particleFrame.opacity, age > 0.5 ? 1 - (age - 0.5) / 0.5 : 1,
            accuracy: 1e-5
        )
        XCTAssertTrue(effects.contains {
            $0.texture.sourceName == "FlarePuff"
        })

        let light = ObjectLightRequest(
            roomSourceIndex: 1, position: flare.position, distance: 52.5,
            color: .init(x: 1, y: 1, z: 0.8), direction: nil, directionalDot: 0
        )
        let initial = try makeMetalWorldPlan(
            level: fixture.level, playerView: playerView
        )
        let plan = try updateMetalWorldPlan(
            initial, level: fixture.level, objects: fixture.world.objects,
            roomStates: fixture.world.rooms, playerView: playerView,
            visEffectBillboards: effects, weaponBillboards: billboards,
            objectLights: [light]
        )
        XCTAssertTrue(plan.draws.contains {
            $0.objectHandle == UInt32.max - 9_000
                && $0.texture == sparkFrames[2]
        })
        XCTAssertTrue(plan.draws.contains {
            $0.objectHandle.map { (UInt32.max - 7_000 - 400)...(UInt32.max - 7_000) ~= $0 } == true
                && $0.texture == particleFrame.texture
        })
        XCTAssertTrue(plan.draws.contains { draw in
            draw.objectHandle == nil
                && draw.vertices.contains { $0.dynamicLight.x > 0 }
        })
        XCTAssertEqual(
            plan.activeDrawIndices.map { plan.preparedDraws[$0] },
            plan.draws
        )
    }

    // MARK: Review follow-ups

    /// A fire image with no imported frames is not drawn (its type's
    /// contract), and a tiny frame_time cannot overflow the frame number
    /// (GetWeaponFireImage, weapon.cpp:608).
    func testBillboardsSkipEmptyImagesAndBoundTheFrameNumber() throws {
        var fixture = try makeFlareWorld()
        let handle = try makeFlare(&fixture, ahead: 5)
        fixture.world.timeoutWeapon(handle, level: fixture.level)
        var level = fixture.level
        level.weapons?[fixture.spark].fireImage = .init(
            frames: [], frameTime: 0
        )
        XCTAssertTrue(weaponBillboardFrames(
            level, objects: fixture.world.objects, gameTime: 3
        ).isEmpty)
        level.weapons?[fixture.spark].fireImage = .init(
            frames: fixtureYellowSparkFrames, frameTime: 1e-30
        )
        let frames = weaponBillboardFrames(
            level, objects: fixture.world.objects, gameTime: 100_000
        )
        XCTAssertEqual(frames.count, 9)
        XCTAssertTrue(frames.allSatisfy {
            fixtureYellowSparkFrames.contains($0.texture)
        })
    }

    /// A stationary flare the player flies into after the parent grace
    /// sticks to the player, as one that flies into the player does
    /// (collide_player_and_weapon passes the hit to MakeWeaponStick,
    /// collide.cpp:2335). The player's move reports the submodel of its own
    /// model that the flare's sphere touched.
    func testFlareSticksToThePlayerFromEitherSide() throws {
        // The flare flies into the player.
        var fixture = try makeFlareWorld()
        let player = fixture.player
        let robot = try XCTUnwrap(fixture.world.objects.first {
            $0.type == .robot
        })
        fixture.world.objects[robot.handle]?.location = player.location
        fixture.world.objects[robot.handle]?.position =
            player.position + .init(x: 0, y: 0, z: 0.5)
        let model = try XCTUnwrap(fixture.level.polygonModel(of: player))
        let offsets = accumulatedModelOffsets(model)
        var faces: [(Int, Vector3, Vector3)] = []
        for (index, submodel) in model.submodels.enumerated() {
            for face in submodel.faces {
                guard case .texture = face.material,
                      face.corners.count >= 3
                else {
                    continue
                }

                let points = face.corners.map {
                    submodel.vertices[$0.vertexIndex].position
                }
                faces.append((
                    index,
                    points.reduce(Vector3.zero, +) / Float(points.count)
                        + offsets[index],
                    face.normal
                ))
            }
        }

        let face = try XCTUnwrap(faces.first)
        let aim = player.position + transform(face.1, by: player.orientation)
        let normal = sourceVectorNormalized(
            transform(face.2, by: player.orientation)
        )
        let incoming = try XCTUnwrap(fixture.world.createAndFireWeapon(
            position: aim + normal * 20, direction: normal * -1,
            parent: robot.handle, weaponIndex: fixture.flare,
            level: fixture.level
        ))
        fixture.world.frameDuration = 0.1
        for _ in 0..<5
        where fixture.world.objects[incoming]?.objectLink == nil {
            fixture.world.moveWeapon(incoming, level: fixture.level)
        }

        let flown = try XCTUnwrap(fixture.world.objects[incoming])
        XCTAssertEqual(flown.objectLink?.parentHandle, player.handle)
        XCTAssertEqual(flown.flags & GameObject.deadFlag, 0)

        // The player flies into a stationary flare.
        let level = fixture.level
        let session = GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
        let ship = session.world.testPlayerObject
        // Park the flare 2 units off a face of the ship, and fly the ship
        // at it along that face's normal.
        let forward = sourceVectorNormalized(
            transform(face.2, by: ship.orientation)
        )
        let point = ship.position + transform(face.1, by: ship.orientation)
            + forward * 2
        session.world.objects[robot.handle]?.location = ship.location
        session.world.objects[robot.handle]?.position =
            ship.position + .init(x: 0, y: 0, z: 0.5)
        let parked = try XCTUnwrap(session.world.createAndFireWeapon(
            position: point, direction: forward, parent: robot.handle,
            weaponIndex: fixture.flare, level: level
        ))
        session.world.objects[parked]?.usesPhysics = false
        session.world.objects[parked]?.velocity = .zero
        session.world.velocity = forward * 60
        _ = session.update(at: 0.1, input: .zero)
        let hit = try XCTUnwrap(session.world.objects[parked])
        let link = try XCTUnwrap(hit.objectLink)
        XCTAssertEqual(link.parentHandle, ship.handle)
        XCTAssertTrue(model.submodels.indices.contains(link.submodel))
        XCTAssertEqual(hit.flags & GameObject.deadFlag, 0)
    }

    /// The flag-dependent numbers of a weapon's light are checked at the
    /// package boundary (object_lighting.cpp:379-446): OLF_TIMEBITS needs a
    /// time interval, and OLF_FLICKER_SLIGHTLY a flicker factor an int
    /// holds. A tiny pulse or timebits interval still lights safely.
    func testWeaponLightDomainsAreCheckedAndConversionsAreSafe() throws {
        let base = try makeFlareWorld()
        func lighting(flags: UInt32, interval: Float,
                      flicker: Float) -> ObjectLightPresentation {
            .init(
                primaryColor: .init(x: 1, y: 1, z: 1), secondaryColor: .zero,
                timeInterval: interval, flickerDistance: flicker,
                directionalDot: 0, flags: flags, timebits: UInt32.max, angle: 0,
                lightingRenderType: 0
            )
        }

        func level(_ light: ObjectLightPresentation) -> Level {
            var level = base.level
            level.weapons?[base.flare].lighting = light
            return level
        }
        XCTAssertThrowsError(try level(lighting(
            flags: ObjectLightFlag.timebits, interval: 0, flicker: 0
        )).validate())
        XCTAssertThrowsError(try level(lighting(
            flags: ObjectLightFlag.flickerSlightly, interval: 0, flicker: 1e20
        )).validate())
        XCTAssertThrowsError(try level(lighting(
            flags: 0, interval: .nan, flicker: 0
        )).validate())
        for flags in [ObjectLightFlag.pulse, ObjectLightFlag.pulseToSecond,
                      ObjectLightFlag.timebits] {
            let tiny = level(lighting(flags: flags, interval: 1e-30,
                                      flicker: 0))
            XCTAssertNoThrow(try tiny.validate())
            var world = GameWorld(level: tiny)
            let player = world.testPlayerObject
            let handle = try XCTUnwrap(world.createAndFireWeapon(
                position: player.position + player.orientation.forward * 5,
                direction: player.orientation.forward, parent: player.handle,
                weaponIndex: base.flare, level: tiny
            ))
            world.gameTime = 100_000
            world.lastRenderCamera = RoomCamera(
                position: player.position,
                target: player.position + player.orientation.forward,
                up: player.orientation.up
            )
            world.doObjectLight(handle, level: tiny)
            XCTAssertLessThanOrEqual(world.objectLights.count, 1)
        }
    }

    /// The lifeleft boundary (object.cpp:2743, viseffect.cpp:2170) through
    /// the generic frame, with a newly sampled frame time that differs from
    /// the one the frame uses (architecture.md section 5): a flare, a spark,
    /// and a particle left at exactly 0 live on; below 0 the flare times
    /// out into its spawn and the spark and particle die.
    func testLifeleftExactlyZeroSurvivesTheFrame() throws {
        let level = makeTrainingGuidebotYellowFlareLevel()
        let flare = try XCTUnwrap(level.weapons?.firstIndex {
            $0.name == "Yellow flare"
        })
        let spark = try XCTUnwrap(level.weapons?.firstIndex {
            $0.name == "YellowFlareSparks"
        })
        let session = GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
        _ = session.update(at: 0.25, input: .zero)
        let used = session.world.frameDuration
        XCTAssertEqual(used, 0.25)
        let player = session.world.testPlayerObject
        func fire(_ weapon: Int, ahead: Float) throws -> ObjectHandle {
            try XCTUnwrap(session.world.createAndFireWeapon(
                position: player.position
                    + player.orientation.forward * ahead,
                direction: player.orientation.forward,
                parent: player.handle,
                weaponIndex: weapon,
                level: level
            ))
        }

        let flareHandle = try fire(flare, ahead: 5)
        let sparkHandle = try fire(spark, ahead: 6)
        session.world.objects[flareHandle]?.lifeLeft = used
        session.world.objects[sparkHandle]?.lifeLeft = used
        guard case let .room(room) = player.location else {
            return XCTFail("indoor player")
        }
        session.world.createRandomParticles(
            1, position: player.position, roomSourceIndex: room,
            weapon: flare, size: 0.2, life: 0.3, level: level
        )
        let particle = try XCTUnwrap(session.world.visEffects.indices.last)
        session.world.visEffects[particle].lifeLeft = used
        session.world.visEffects[particle].lifetime = used

        _ = session.update(at: 0.30, input: .zero)
        XCTAssertEqual(session.world.frameDuration, 0.05, accuracy: 1e-6)
        XCTAssertEqual(session.world.objects[flareHandle]?.lifeLeft, 0)
        XCTAssertEqual(session.world.objects[sparkHandle]?.lifeLeft, 0)
        XCTAssertEqual(
            session.world.objects.filter { $0.weapon == spark }.count,
            1
        )
        XCTAssertTrue(session.world.visEffects.contains {
            $0.id == VisEffect.particleID && $0.lifeLeft == 0
        })

        _ = session.update(at: 0.40, input: .zero)
        XCTAssertNil(session.world.objects[flareHandle])
        XCTAssertNil(session.world.objects[sparkHandle])
        XCTAssertEqual(
            session.world.objects.filter { $0.weapon == spark }.count,
            9
        )
        XCTAssertFalse(session.world.visEffects.contains {
            $0.id == VisEffect.particleID && $0.lifetime == used
        })
    }

    /// FireWeaponFromPlayer (WeaponFire.cpp:2830): battery 0 fires the blue
    /// laser from both wing guns for 0.15 energy, and is ready again only
    /// after its 0.25 s fire wait.
    func testPlayerLaserFiresBothWingGunsForItsEnergyAndWait() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        let player = world.testPlayerObject
        fire(&world, .primary, level: level)
        let bolts = world.objects.filter { $0.type == .weapon }
        XCTAssertEqual(bolts.count, 2)
        XCTAssertEqual(world.energy, 99.85, accuracy: 0.000_01)
        for bolt in bolts {
            XCTAssertEqual(bolt.parent, player.handle)
            XCTAssertEqual(bolt.lifeLeft, 5)
            XCTAssertEqual(
                sqrt(dot(bolt.velocity, bolt.velocity)), 225, accuracy: 0.01
            )
            XCTAssertGreaterThan(
                dot(bolt.velocity, player.orientation.forward), 224
            )
        }
        XCTAssertGreaterThan(
            vectorDistance(bolts[0].position, bolts[1].position), 5
        )

        world.gameTime += 0.1
        fire(&world, .primary, level: level)
        XCTAssertEqual(world.objects.filter { $0.type == .weapon }.count, 2)
        world.gameTime += 0.15
        fire(&world, .primary, level: level)
        XCTAssertEqual(world.objects.filter { $0.type == .weapon }.count, 4)
        XCTAssertEqual(world.energy, 99.7, accuracy: 0.000_01)
    }

    /// The Concussion takes one missile per shot and, with none left,
    /// shows "Not enough projectiles available!" and fires nothing.
    func testConcussionUsesAmmoAndStopsWhenEmpty() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        world.playerWeapons[PlayerWeaponState.secondary].index =
            PlayerWeaponState.concussionIndex
        // 2 + MAX_DIFFICULTY_LEVELS - Rookie (InitPlayerNewShip).
        XCTAssertEqual(world.playerWeaponAmmo[PlayerWeaponState.concussionIndex], 6)
        fire(&world, .secondary, level: level)
        XCTAssertEqual(world.objects.filter { $0.type == .weapon }.count, 1)
        XCTAssertEqual(world.playerWeaponAmmo[PlayerWeaponState.concussionIndex], 5)

        world.playerWeaponAmmo[PlayerWeaponState.concussionIndex] = 0
        world.presentationRequests = []
        world.gameTime += 1
        fire(&world, .secondary, level: level)
        XCTAssertEqual(world.objects.filter { $0.type == .weapon }.count, 1)
        XCTAssertEqual(
            world.presentationRequests,
            [.hudMessage("Not enough projectiles available!")]
        )
    }

    /// ObjDoFrame ages a weapon, and TimeoutObject and ObjDeleteDead remove
    /// it when its life runs out. An energy bolt leaves no explosion.
    func testWeaponLifetimeRunsOutThroughTheObjectFrame() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        fire(&world, .primary, level: level)
        let bolts = world.objects.filter { $0.type == .weapon }.map(\.handle)
        for bolt in bolts { world.objects[bolt]?.lifeLeft = 0.05 }
        world.frameDuration = 0.1
        world.objDoFrameSlots(0..<ObjectTable.capacity, level: level)
        for bolt in bolts {
            XCTAssertNotEqual(
                (world.objects[bolt]?.flags ?? 0) & GameObject.deadFlag, 0
            )
        }
        world.objDoFrameAllTail(level: level)
        XCTAssertTrue(world.objects.filter { $0.type == .weapon }.isEmpty)
        XCTAssertTrue(world.visEffects.isEmpty)
    }

    /// DoWeaponExploded (WeaponFire.cpp:3058) makes the Concussion's 0.1 s
    /// shockwave; DoConcussiveForce (fireball.cpp:1788) reaches the robot
    /// once as the wave grows, for damage that falls off with distance
    /// (scaled by Rookie's 1.5).
    func testConcussionShockwaveDamagesTheRobotOnce() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        world.playerWeapons[PlayerWeaponState.secondary].index =
            PlayerWeaponState.concussionIndex
        fire(&world, .secondary, level: level)
        let missile = try XCTUnwrap(world.objects.first { $0.type == .weapon })
        let target = try XCTUnwrap(world.objects[robot])
        let player = world.testPlayerObject
        XCTAssertEqual(target.location, player.location)
        // The missile 12 units from the robot, toward the player.
        world.objects[missile.handle]?.position = target.position
            + sourceVectorNormalized(player.position - target.position) * 12
        world.objects[missile.handle]?.location = target.location

        world.doWeaponExploded(missile.handle, level: level)
        let shockwave = try XCTUnwrap(
            world.objects.first { $0.type == .shockwave }
        )
        XCTAssertEqual(shockwave.parent, player.handle)
        XCTAssertEqual(shockwave.lifeLeft, 0.1)
        XCTAssertEqual(
            world.visEffects.filter { $0.id == VisEffect.customExplosionID }
                .count,
            1
        )

        // At its birth the wave reaches nothing; at 0.05 s it reaches 16.
        world.shockwaveConcussiveForce(shockwave.handle, level: level)
        XCTAssertEqual(world.objects[robot]?.shields, 55)
        world.gameTime += 0.05
        world.shockwaveConcussiveForce(shockwave.handle, level: level)
        let distance = 12 - target.size
        let expected = 55 - (19 - distance / 32 * 19) * 1.5
        XCTAssertEqual(
            try XCTUnwrap(world.objects[robot]).shields, expected,
            accuracy: 0.001
        )
        world.gameTime += 0.05
        world.shockwaveConcussiveForce(shockwave.handle, level: level)
        XCTAssertEqual(
            try XCTUnwrap(world.objects[robot]).shields, expected,
            accuracy: 0.001
        )
    }

    /// FireWeaponFromPlayer through GameSession.update (WeaponFire.cpp:2830
    /// with 3MASTERED dbd611e4, bd896ac, c47df2d; sources.md section 2).
    /// Frames of 0.01, 0.247, and 0.01 s: the first shot fires at Gametime
    /// 0; the held button's next shot is due at 0.25 and fires in the frame
    /// whose Gametime is 0.257, keeping the 0.007 s overshoot
    /// (last_fire_time 0.25). A release and a new press start a new burst
    /// anchored at that frame's Gametime.
    func testHeldPrimaryFireKeepsItsScheduledCadenceAcrossFrames() throws {
        let level = makeTrainingRobotGuidebotLevel()
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        func battery() -> DynamicWeaponBattery {
            simulation.world.testPlayerObject.weaponBatteries[0]
        }

        func bolts() -> Int {
            simulation.world.objects.filter { $0.type == .weapon }.count
        }
        _ = simulation.update(at: 0.01, input: .init(firesPrimaryWeapon: true))
        XCTAssertEqual(simulation.energy, 99.85, accuracy: 0.000_01)
        XCTAssertEqual(bolts(), 2)
        XCTAssertEqual(battery().lastFireTime, 0, accuracy: 0.000_01)

        _ = simulation.update(at: 0.257, input: .init(firesPrimaryWeapon: true))
        XCTAssertEqual(simulation.energy, 99.85, accuracy: 0.000_01)
        XCTAssertEqual(bolts(), 2)
        _ = simulation.update(at: 0.267, input: .init(firesPrimaryWeapon: true))
        XCTAssertEqual(simulation.energy, 99.7, accuracy: 0.000_01)
        XCTAssertEqual(bolts(), 4)
        XCTAssertEqual(battery().lastFireTime, 0.25, accuracy: 0.000_01)
        // Firing draws no random numbers.
        XCTAssertEqual(simulation.world.authoritativeRandomState, 0x1234_5678)

        _ = simulation.update(at: 9, input: .zero)
        XCTAssertEqual(
            simulation.world.playerWeapons[PlayerWeaponState.primary]
                .firingTime,
            0
        )
        _ = simulation.update(at: 9.016, input: .zero)
        _ = simulation.update(at: 9.032, input: .init(firesPrimaryWeapon: true))
        XCTAssertEqual(simulation.energy, 99.55, accuracy: 0.000_01)
        XCTAssertEqual(battery().lastFireTime, 9.016, accuracy: 0.000_01)
    }

    /// The Concussion battery alternates gun points 1 and 2 (fire masks 2
    /// and 4), each shot taking one missile and waiting 0.5 s.
    func testConcussionAlternatesItsGunpointsThroughTheFrame() throws {
        let level = try makePlayerConcussionLevel()
        let simulation = GameSession(level: level, presentationReadyTimestamp: 0)
        simulation.world.playerWeapons[PlayerWeaponState.secondary].index =
            PlayerWeaponState.concussionIndex
        let player = simulation.world.testPlayerObject
        func rightOffsets() -> [Float] {
            simulation.world.objects.filter { $0.type == .weapon }
                .sorted { $0.creationTime < $1.creationTime }
                .map { dot($0.position - player.position,
                           player.orientation.right) }
        }
        _ = simulation.update(at: 0.1, input: .init(firesSecondaryWeapon: true))
        XCTAssertEqual(
            simulation.world.playerWeaponAmmo[PlayerWeaponState.concussionIndex],
            5
        )
        XCTAssertEqual(rightOffsets().count, 1)
        let first = rightOffsets()[0]
        _ = simulation.update(at: 0.4, input: .init(firesSecondaryWeapon: true))
        XCTAssertEqual(rightOffsets().count, 1)
        _ = simulation.update(at: 0.6, input: .init(firesSecondaryWeapon: true))
        XCTAssertEqual(rightOffsets().count, 1)
        _ = simulation.update(at: 0.7, input: .init(firesSecondaryWeapon: true))
        XCTAssertEqual(
            simulation.world.playerWeaponAmmo[PlayerWeaponState.concussionIndex],
            4
        )
        let offsets = rightOffsets()
        XCTAssertEqual(offsets.count, 2)
        // Gun point 1 is 2.792 right of the model's center, gun point 2
        // 2.804 left of it.
        XCTAssertEqual(first - (offsets.last ?? 0), 5.596_459, accuracy: 0.05)
    }
}
