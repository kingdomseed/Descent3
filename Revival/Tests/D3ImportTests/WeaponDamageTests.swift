import XCTest

/// The generic weapon, damage, and death path of M1 step 7: player firing
/// (FireWeaponFromPlayer), weapon ageing and timeout, weapon hits
/// (collide_generic_and_weapon), ApplyDamageToGeneric, KillObject and
/// DoDyingFrame, ObjDeleteDead's event order, timer detonators, the
/// shockwave, and the visual effect list. The level is the synthetic
/// Training robot level: DestroyBot2 (4112) has a destroyable RAS1 page
/// with 55 hit points and a 200 point score (WeaponFixtures.swift).
final class WeaponDamageTests: XCTestCase {
    private let robot = ObjectHandle(4_112)

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

    /// collide_generic_and_weapon (collide.cpp:2155): a blue laser bolt
    /// does 7.5 generic damage, scaled by Rookie's Diff_robot_damage of
    /// 1.5; its custom explosion and 3 to 8 sparks are made, and it dies.
    func testLaserHitDamagesTheRobotWithTheRookieScale() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        XCTAssertEqual(world.objects[robot]?.shields, 55)
        fire(&world, .primary, level: level)
        let bolt = try XCTUnwrap(world.objects.first { $0.type == .weapon })
        world.collideTwoObjects(bolt.handle, robot, level: level)
        XCTAssertEqual(try XCTUnwrap(world.objects[robot]).shields, 43.75)
        XCTAssertNotEqual(
            (world.objects[bolt.handle]?.flags ?? 0) & GameObject.deadFlag, 0
        )
        XCTAssertEqual(
            world.visEffects.filter { $0.id == VisEffect.customExplosionID }
                .count,
            1
        )
        // 3 + ps_rand() % 6 sparks, doubled (Katmai).
        let sparks = world.visEffects.filter {
            $0.id == VisEffect.fadingLineID
        }
        XCTAssertTrue((6...16).contains(sparks.count), "\(sparks.count)")
        XCTAssertEqual(sparks.count % 2, 0)
    }

    /// ApplyDamageToGeneric (damage.cpp:1290) and KillObject (:1037): damage
    /// past the shields kills the robot with its page death (no delay), and
    /// the player who fired scores its 200 points once. ObjDeleteDead
    /// deletes it.
    func testKillingDamageDestroysTheRobotAndThePlayerScores() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        fire(&world, .primary, level: level)
        let bolt = try XCTUnwrap(world.objects.first { $0.type == .weapon })
        world.applyDamageToGeneric(
            robot,
            killer: bolt.handle,
            damageType: .energy,
            damage: 40,
            level: level
        )
        let dead = try XCTUnwrap(world.objects[robot])
        XCTAssertEqual(dead.shields, -5)
        XCTAssertNotEqual(dead.flags & GameObject.deadFlag, 0)
        XCTAssertEqual(world.playerScore, 200)
        XCTAssertEqual(world.playerKillsLevel, 1)
        // More damage to a dying object kills nothing again.
        world.applyDamageToGeneric(
            robot, killer: bolt.handle, damageType: .energy, damage: 40,
            level: level
        )
        XCTAssertEqual(world.playerScore, 200)
        world.objDeleteDead(level: level)
        XCTAssertNil(world.objects[robot])
    }

    /// KillObject (damage.cpp:1175) with a delay: the object is dying
    /// (CT_DYING) until DoDyingFrame (fireball.cpp:1428) runs the delay
    /// out, destroys it, and scores for the killer.
    func testDelayedDeathIsDyingUntilTheDelayRunsOut() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        world.killObject(
            robot,
            killer: world.testPlayerObject.handle,
            damage: 10,
            deathFlags: DeathFlags.fireball,
            delayTime: 0.25,
            level: level
        )
        var dying = try XCTUnwrap(world.objects[robot])
        XCTAssertNotEqual(dying.flags & GameObject.dyingFlag, 0)
        XCTAssertEqual(dying.flags & GameObject.deadFlag, 0)
        XCTAssertEqual(dying.dying?.delayTime, 0.25)
        XCTAssertEqual(world.playerScore, 0)
        world.frameDuration = 0.1
        for frame in 1...3 {
            world.objDoFrameSlots(0..<ObjectTable.capacity, level: level)
            dying = try XCTUnwrap(world.objects[robot])
            XCTAssertEqual(
                dying.flags & GameObject.deadFlag != 0, frame == 3,
                "frame \(frame)"
            )
        }
        XCTAssertEqual(world.playerScore, 200)
        XCTAssertEqual(world.playerKillsLevel, 1)
    }

    /// Osiris_ProcessTimers (OsirisLoadandBind.cpp:2285): a timer whose
    /// detonator died is cancelled with EVT_TIMERCANCEL (detonated).
    func testDetonatorTimerIsCancelledWhenItsObjectDies() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        let handle = world.osirisTimers.create(
            .init(target: .level, id: 5, interval: 10, detonator: robot),
            gameTime: world.gameTime
        )
        world.killObject(
            robot,
            killer: .none,
            damage: 1,
            deathFlags: DeathFlags.fireball,
            delayTime: 0,
            level: level
        )
        var events: [(OsirisTimerTarget, ScriptEvent)] = []
        world.osirisProcessTimers { _, target, event in
            events.append((target, event))
        }
        XCTAssertTrue(events.isEmpty, "a dead object is not yet deleted")
        world.objDeleteDead(level: level)
        world.osirisProcessTimers { _, target, event in
            events.append((target, event))
        }
        XCTAssertEqual(events.map(\.0), [.level])
        XCTAssertEqual(
            events.map(\.1),
            [.timerCancel(handle: handle, detonated: true)]
        )
        XCTAssertFalse(world.osirisTimers.exists(handle))
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

    /// VisEffectCreate (viseffect.cpp:569) refuses an effect when all
    /// MAX_VIS_EFFECTS are in use, and CreateRandomLineSparks then takes
    /// none of its random draws.
    func testFullVisualEffectListTakesNoRandomDraws() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        for _ in 0..<VisEffect.capacity {
            _ = world.visEffectCreate(
                id: VisEffect.smallExplosionID,
                roomSourceIndex: 2,
                position: .zero,
                level: level
            )
        }
        let state = world.authoritativeRandomState
        world.createRandomLineSparks(
            5, position: .zero, roomSourceIndex: 2, color: 0, level: level
        )
        XCTAssertEqual(world.visEffects.count, VisEffect.capacity)
        XCTAssertEqual(world.authoritativeRandomState, state)

        world.visEffects.removeLast()
        world.createRandomLineSparks(
            5, position: .zero, roomSourceIndex: 2, color: 0, level: level
        )
        XCTAssertEqual(world.visEffects.count, VisEffect.capacity)
        XCTAssertNotEqual(world.authoritativeRandomState, state)
    }

    /// The explosion frame index is the effect's age at the render's
    /// Gametime over its lifetime, kept below 1 (DrawVisEffect,
    /// viseffect.cpp:1868-1876); a tiny lifetime cannot overflow it.
    func testExplosionFrameIndexStaysInRangeForTinyLifetimes() throws {
        let level = try makePlayerConcussionLevel()
        let concussion = try XCTUnwrap(
            level.weapons?.firstIndex { $0.name == "Concussion" }
        )
        let frames = try XCTUnwrap(level.weapons?[concussion].explosion?.frames)
        for (gameTime, lifetime, expected) in [
            (Float(1), Float(1e-44), frames.count - 1),
            (Float(0), Float(1e-20), 0),
            (Float(0.25), Float(0.5), frames.count / 2),
        ] {
            let effect = VisEffect(
                id: VisEffect.customExplosionID,
                roomSourceIndex: 1,
                position: .zero,
                size: 10,
                lifeLeft: lifetime,
                lifetime: lifetime,
                creationTime: 0,
                flags: VisEffect.usesLifeLeftFlag,
                customWeapon: concussion
            )
            let drawn = visEffectBillboardFrames(
                level,
                effects: [effect],
                gameTime: gameTime
            )
            XCTAssertEqual(drawn.map(\.texture), [frames[expected]])
        }
    }

    /// KillPlayer (damage.cpp:760) and InitiatePlayerDeath
    /// (Player.cpp:2057): lethal damage makes the player PLAYER_FLAGS_DYING,
    /// clears its firing, counts the death, and picks its fate with
    /// PlayerChooseDeathFate's one ps_rand draw (Player.cpp:2089-2093).
    /// ApplyDamageToPlayer then refuses more damage (damage.cpp:827), and a
    /// timer whose detonator is the dying player is cancelled
    /// (OsirisLoadandBind.cpp:2298).
    func testLethalDamageStartsThePlayersDeathOnce() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        let player = world.testPlayerObject.handle
        let timer = world.osirisTimers.create(
            .init(target: .level, id: 9, interval: 10, detonator: player),
            gameTime: world.gameTime
        )
        world.playerWeapons[PlayerWeaponState.primary].firingTime = 0.5
        world.playerWeapons[PlayerWeaponState.secondary].firingTime = 0.5
        var expected = world
        // 50 damage past zero: DEATH_FALL, which becomes DEATH_D2STYLE
        // unless ps_rand() % 4 is 3.
        let draw = expected.psRand()
        XCTAssertTrue(world.applyDamageToPlayer(
            player, killer: ObjectHandle(4_112), damage: 150, level: level
        ))
        XCTAssertEqual(world.shields, -50)
        let death = try XCTUnwrap(world.playerDeath)
        XCTAssertFalse(death.isDead)
        XCTAssertEqual(death.fate, draw % 4 != 3 ? .d2Style : .fall)
        XCTAssertEqual(death.killer, ObjectHandle(4_112))
        XCTAssertEqual(death.initialDeathTime, world.gameTime)
        XCTAssertEqual(world.authoritativeRandomState,
                       expected.authoritativeRandomState)
        XCTAssertEqual(world.playerDeathsLevel, 1)
        XCTAssertEqual(world.playerWeapons.map(\.firingTime), [0, 0])

        XCTAssertFalse(world.applyDamageToPlayer(
            player, killer: ObjectHandle(4_112), damage: 10, level: level
        ))
        XCTAssertEqual(world.shields, -50)
        XCTAssertEqual(world.playerDeathsLevel, 1)

        var events: [ScriptEvent] = []
        world.osirisProcessTimers { _, _, event in events.append(event) }
        XCTAssertEqual(events, [.timerCancel(handle: timer, detonated: true)])
    }

    /// Past 100 damage the fate is DEATH_INSTANT with no draw
    /// (Player.cpp:2084-2086).
    func testOverwhelmingDamageIsAnInstantDeathWithNoDraw() throws {
        let level = makeTrainingRobotGuidebotLevel()
        var world = GameWorld(level: level)
        let state = world.authoritativeRandomState
        world.applyDamageToPlayer(
            world.testPlayerObject.handle, damage: 250, level: level
        )
        XCTAssertEqual(world.playerDeath?.fate, .instant)
        XCTAssertEqual(world.authoritativeRandomState, state)
    }

    /// A dying player has CT_NONE (StartPlayerDeath, Player.cpp:2191): its
    /// controls do nothing, so it fires no weapon.
    func testADyingPlayerIgnoresItsControls() throws {
        let level = makeTrainingRobotGuidebotLevel()
        let living = GameSession(level: level, presentationReadyTimestamp: 0)
        _ = living.update(at: 0.1, input: .init(firesPrimaryWeapon: true))
        XCTAssertFalse(living.world.objects.filter { $0.type == .weapon }.isEmpty)
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        session.world.applyDamageToPlayer(
            session.world.testPlayerObject.handle, damage: 250, level: level
        )
        _ = session.update(at: 0.1, input: .init(firesPrimaryWeapon: true))
        XCTAssertTrue(session.world.objects.filter { $0.type == .weapon }.isEmpty)
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
            in: level,
            startRoom: crossing.room,
            start: crossing.center + crossing.normal * 3,
            end: hit.position,
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
                              room: roomData,
                              face: roomData.faces[index]
                          ) != nil
                  }),
                  let normal = canonicalFaceNormal(
                      room: roomData,
                      face: roomData.faces[wall]
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

    // MARK: - Helpers

    private enum Trigger { case primary, secondary }

    /// An open portal of the level: its face center, the normal into its
    /// room, and the room it leads to.
    private func openPortalCrossing(
        _ level: Level,
        world: GameWorld
    ) -> (room: Int, connectedRoom: Int, center: Vector3, normal: Vector3)? {
        for (index, room) in level.rooms.enumerated() {
            for (portalIndex, portal) in room.portals.enumerated()
            where world.rooms[index].portalFlags[portalIndex]
                & LevelPortal.renderFacesFlag == 0 {
                let face = room.faces[portal.faceIndex]
                guard let normal = canonicalFaceNormal(room: room, face: face)
                else {
                    continue
                }
                let sum = face.corners.reduce(Vector3.zero) {
                    $0 + room.vertices[$1.vertexIndex]
                }
                return (room.sourceIndex, portal.connectedRoom,
                        sum / Float(face.corners.count), normal)
            }
        }
        return nil
    }

    private func fire(
        _ world: inout GameWorld,
        _ trigger: Trigger,
        level: Level
    ) {
        world.fireWeaponFromPlayer(
            world.testPlayerObject.handle,
            weaponType: trigger == .primary
                ? PlayerWeaponState.primary : PlayerWeaponState.secondary,
            isDown: true,
            downTime: 0.1,
            level: level
        )
    }
}
