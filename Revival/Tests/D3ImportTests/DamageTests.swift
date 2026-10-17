import XCTest

// Damage and death (Descent3/damage.cpp): collide_generic_and_weapon's
// damage with the Rookie scale, ApplyDamageToGeneric, both KillObject
// forms with their scores and delays, and the player's death start
// (Player.cpp:2057). The level is the synthetic Training robot level:
// DestroyBot2 (4112) has a destroyable RAS1 page with 55 hit points and a
// 200 point score (WeaponFixtures.swift).
final class DamageTests: XCTestCase {
    private let robot = ObjectHandle(4_112)

    func testWeaponCollisionAppliesShipArmorBeforeShieldAndDeathChecks() throws {
        for (scalar, remainingShields, dies): (Float, Float, Bool) in [
            (0.5, 0, false), (1, -3.75, true), (2, -11.25, true),
        ] {
            var level = makeTrainingRobotGuidebotLevel()
            level.shipDefinitions[0].armorScalar = scalar
            var world = GameWorld(level: level)
            world.shields = 3.75
            let shot = try XCTUnwrap(world.fireWeaponFromObject(
                robot, weaponName: "Laser Level 2 - Blue", gunpoint: -1,
                forceForward: true, forceTarget: false, level: level
            ))
            world.collideTwoObjects(shot, world.testPlayerObject.handle, level: level)
            XCTAssertEqual(world.shields, remainingShields)
            XCTAssertEqual(world.playerDeath != nil, dies)
            XCTAssertEqual(world.playerDeathsLevel, dies ? 1 : 0)
            XCTAssertNotEqual(world.objects[shot]!.flags & GameObject.deadFlag, 0)
        }
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
            robot, killer: bolt.handle, damageType: .energy, damage: 40,
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
            robot, killer: world.testPlayerObject.handle, damage: 10,
            deathFlags: DeathFlags.fireball, delayTime: 0.25, level: level
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

        // Every value of the draw: only ps_rand() % 4 == 3 keeps DEATH_FALL.
        var fates: [Int32: PlayerDeathState.Fate] = [:]
        for seed in UInt32(1)...64 where fates.count < 4 {
            var seeded = GameWorld(level: level, authoritativeRandomSeed: seed)
            var drawn = seeded
            let residue = drawn.psRand() % 4
            _ = seeded.applyDamageToPlayer(
                player, killer: ObjectHandle(4_112), damage: 150, level: level
            )
            fates[residue] = seeded.playerDeath?.fate
        }
        XCTAssertEqual(fates, [0: .d2Style, 1: .d2Style, 2: .d2Style, 3: .fall])
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

    // MARK: - Helpers

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
}
