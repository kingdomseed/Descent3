import XCTest

/// The Training robot deaths as the translated level module runs them: a
/// robot dies through the generic KillObject and ObjDeleteDead path, its
/// custom script hears EVT_DESTROY (dying), and the scripts of
/// TrainingMission.cpp run in source order.
final class TrainingRobotScriptTests: XCTestCase {
    private let followBot1 = ObjectHandle(8_200)
    private let destroyBot2 = ObjectHandle(4_112)
    private let destroyBot1 = ObjectHandle(4_113)

    /// Script 037 (TrainingMission.cpp:1977-1984) sets level timer 11 two
    /// seconds after FollowBot1 dies; Script 027 (:1558-1571) then turns
    /// both destroy bots to the rebel team, unghosts DestroyBot1, and sends
    /// it along FollowLoop1.
    func testFollowBot1DeathRunsScript037ThenScript027() throws {
        let session = try movingTargetSession()
        session.world.trainingMission.script026Count = 1
        killNow(session, followBot1)
        var timestamp = 0.1
        _ = session.update(at: timestamp, input: .zero)
        XCTAssertNil(session.world.objects[followBot1])
        XCTAssertEqual(session.world.testTrainingMission?.script037Count, 1)
        let timer = try XCTUnwrap(levelTimer(session, 11))
        XCTAssertEqual(timer.end, session.world.gameTime + 2, accuracy: 0.11)
        XCTAssertEqual(session.world.testTrainingMission?.script027Count, 0)

        var log: [String] = []
        for _ in 0..<30
        where session.world.testTrainingMission?.script027Count == 0 {
            timestamp += 0.1
            log = presentationLog(session.update(at: timestamp, input: .zero))
        }
        XCTAssertEqual(session.world.testTrainingMission?.script027Count, 1)
        XCTAssertEqual(
            log.filter { $0.hasPrefix("hud:") },
            [
                "hud:\(TrainingMissionScript.message(0, level: session.level))",
                "hud:\(TrainingMissionScript.message(25, level: session.level))",
            ]
        )
        XCTAssertTrue(log.contains("voice:kill1.osf"))
        XCTAssertFalse(log.contains { $0.contains("Message Not Found") })
        for handle in [destroyBot1, destroyBot2] {
            let ai = try XCTUnwrap(session.world.objects[handle]?.ai)
            XCTAssertEqual(ai.flags & ObjectAIFrame.teamMask, 65_536)
        }
        let bot1 = try XCTUnwrap(session.world.objects[destroyBot1])
        XCTAssertNotEqual(bot1.type, .dummy)
        XCTAssertEqual(bot1.ai?.goals[3].type, AIGoal.followPathType)
        XCTAssertEqual(
            bot1.ai?.goals[3].pathID,
            session.level.findPathName("FollowLoop1")
        )
        // DestroyBot2 stays a ghost until DestroyBot1 dies.
        XCTAssertEqual(session.world.objects[destroyBot2]?.type, .dummy)
    }

    /// Script 037 needs Script 026 (the end of the follow lesson).
    func testFollowBot1DeathBeforeScript026SetsNoTimer() throws {
        let session = try movingTargetSession()
        killNow(session, followBot1)
        _ = session.update(at: 0.1, input: .zero)
        XCTAssertEqual(session.world.testTrainingMission?.script037Count, 0)
        XCTAssertNil(levelTimer(session, 11))
    }

    /// ObjDeleteDead (object.cpp:2004-2045) in slot order, through the
    /// real handlers: each dead object's scripts hear EVT_DESTROY (dying)
    /// after it is unattached (an attached polygon object's attach parent
    /// hears EVT_CHILD_DIED first, which no Training script handles), and
    /// each is then deleted. FollowBot1's death runs Script 037 and
    /// DestroyBot1's runs Script 028.
    func testObjDeleteDeadRunsEachDeadObjectsDestroyHandlerInSlotOrder()
        throws
    {
        let session = try movingTargetSession()
        session.world.trainingMission.script026Count = 1
        session.world.trainingMission.script027Count = 1
        session.world.unghostObject(destroyBot1)
        // DestroyBot1 rides on FollowBot1.
        session.world.objects[destroyBot1]?.flags |= GameObject.attachedFlag
        session.world.objects[destroyBot1]?.attachUltimateHandle = followBot1
        for handle in [followBot1, destroyBot1] {
            session.world.objects[handle]?.flags |= GameObject.deadFlag
        }
        session.world.objDeleteDead(level: session.level)
        XCTAssertNil(session.world.objects[followBot1])
        XCTAssertNil(session.world.objects[destroyBot1])
        XCTAssertEqual(session.world.testTrainingMission?.script037Count, 1)
        XCTAssertNotNil(levelTimer(session, 11))
        XCTAssertEqual(session.world.testTrainingMission?.script028Count, 1)
        XCTAssertNotEqual(session.world.objects[destroyBot2]?.type, .dummy)
    }

    /// Script 028 (TrainingMission.cpp:2016-2024): after Script 027,
    /// DestroyBot1's death unghosts DestroyBot2 and sends it along
    /// FollowLoop1.
    func testDestroyBot1DeathRunsScript028() throws {
        let session = try movingTargetSession()
        session.world.trainingMission.script027Count = 1
        killNow(session, destroyBot1)
        _ = session.update(at: 0.1, input: .zero)
        XCTAssertEqual(session.world.testTrainingMission?.script028Count, 1)
        let bot2 = try XCTUnwrap(session.world.objects[destroyBot2])
        XCTAssertNotEqual(bot2.type, .dummy)
        XCTAssertEqual(bot2.ai?.goals[3].type, AIGoal.followPathType)
        XCTAssertEqual(bot2.ai?.goals[3].flags, 8_392_960)
    }

    /// A destroy that is not a death (the level ending) runs no script
    /// (TrainingMission.cpp:2015).
    func testDestroyAtLevelEndRunsNoScript() throws {
        let session = try movingTargetSession()
        session.world.trainingMission.script027Count = 1
        session.world.osirisCallEvent(
            destroyBot1,
            .destroy(isDying: false),
            level: session.level
        )
        XCTAssertEqual(session.world.testTrainingMission?.script028Count, 0)
        XCTAssertEqual(session.world.objects[destroyBot2]?.type, .dummy)
    }

    /// Script 036 (TrainingMission.cpp:2039-2050) on DestroyBot2's death:
    /// level timer 12, FlashLight-2 lit to 50, PortalRoom4's portals
    /// opened, every control on; Script 029 (:1573-1582) then hides the
    /// enabled controls and plays proceed5.osf.
    func testDestroyBot2DeathRunsScript036ThenScript029() throws {
        // The gallery level, with its barrier room named PortalRoom4 as in
        // the retail level; FlashLight-2 is the gallery marker light.
        var gallery = makeTrainingRobotGuidebotLevel()
        let barrier = try XCTUnwrap(gallery.trainingGalleryBarrier)
        let barrierRoom = try XCTUnwrap(gallery.rooms.firstIndex {
            $0.sourceIndex == barrier.barrierRoomSourceIndex
        })
        gallery.rooms[barrierRoom].name = "PortalRoom4"
        let level = addingTrainingMissionScripting(
            gallery,
            messages: fixtureTrainingMessages + [
                .init(
                    name: "ExitManuveur",
                    text:
                        "Now go through the open doorway, and into the next room."
                ),
            ]
        )
        try level.validate()
        XCTAssertEqual(
            level.findObjectName("FlashLight-2").rawValue,
            barrier.markerLightObjectHandle
        )
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        XCTAssertEqual(session.level.findObjectName("DestroyBot2"), destroyBot2)
        session.world.hudShowControls = true
        killNow(session, destroyBot2)
        var timestamp = 0.1
        _ = session.update(at: timestamp, input: .zero)
        XCTAssertEqual(session.world.testTrainingMission?.script036Count, 1)
        XCTAssertNotNil(levelTimer(session, 12))
        XCTAssertEqual(session.galleryMarkerLightDistance, 50)
        // Room numbers are source indices (osipf_FindRoomName).
        XCTAssertEqual(
            session.level.findRoomName("PortalRoom4"),
            barrier.barrierRoomSourceIndex
        )
        assertTrainingGalleryBarrier(
            level: session.runtimeLevel,
            rendersFaces: false
        )
        XCTAssertEqual(session.world.playerControllerBitflags, .all)

        var log: [String] = []
        for _ in 0..<30
        where session.world.testTrainingMission?.script029Count == 0 {
            timestamp += 0.1
            log = presentationLog(session.update(at: timestamp, input: .zero))
        }
        XCTAssertEqual(session.world.testTrainingMission?.script029Count, 1)
        XCTAssertFalse(session.world.hudShowControls)
        XCTAssertEqual(
            log.filter { $0.hasPrefix("hud:") },
            [
                "hud:\(TrainingMissionScript.message(0, level: session.level))",
                "hud:\(TrainingMissionScript.message(26, level: session.level))",
            ]
        )
        XCTAssertTrue(log.contains("voice:proceed5.osf"))
        XCTAssertFalse(log.contains { $0.contains("Message Not Found") })
    }

    /// Scripts 047 and 048 (TrainingMission.cpp:2174-2200) count the
    /// first EVT_COLLIDE on InvulnPowerup2 and CloakPowerup2.
    func testPickupContactsRunScripts047And048Once() throws {
        let level = addingTrainingMissionScripting(
            makeTrainingCloakPickupLevel()
        )
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        for _ in 0..<2 {
            session.collidePlayer(with: "InvulnPowerup2")
        }
        XCTAssertEqual(session.world.testTrainingMission?.script047Count, 1)
        XCTAssertEqual(session.world.testTrainingMission?.script048Count, 0)
        session.collidePlayer(with: "CloakPowerup2")
        XCTAssertEqual(session.world.testTrainingMission?.script048Count, 1)
    }

    /// Scripts 043-046 (TrainingMission.cpp:2099-2170) and 051-055
    /// (:2213-2305) count the RAS bots and the last bots as they die.
    func testRASBotAndLastBotDeathsRunTheirCounters() throws {
        let level = addingTrainingMissionScripting(
            makeTrainingFinalBotsCompletionLevel()
        )
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        let counters: [(String, WritableKeyPath<TrainingMissionState, Int>)] = [
            ("RASBot1", \.script043Count), ("RASBot2", \.script044Count),
            ("RASBot3", \.script045Count), ("RASBot4", \.script046Count),
            ("LastBot1", \.script051Count), ("LastBot2", \.script052Count),
            ("LastBot3", \.script053Count), ("LastBot4", \.script054Count),
            ("LastBot5", \.script055Count),
        ]
        var timestamp = 0.0
        for (name, counter) in counters {
            let handle = level.findObjectName(name)
            XCTAssertNotEqual(handle, .none, name)
            XCTAssertEqual(session.world.trainingMission[keyPath: counter], 0)
            killNow(session, handle)
            timestamp += 0.1
            _ = session.update(at: timestamp, input: .zero)
            XCTAssertEqual(
                session.world.trainingMission[keyPath: counter],
                1,
                name
            )
        }
    }

    /// Real content, opt-in (REVIVAL_TRAINING_PACKAGE, engineering.md
    /// section 2): the player's imported blue laser shoots DestroyBot1 down
    /// through collide_generic_and_weapon and ApplyDamageToGeneric; its
    /// death scores the page's points, and Script 028 unghosts DestroyBot2.
    func testImportedTrainingPackageShootsDownDestroyBot1() throws {
        guard let path = ProcessInfo.processInfo.environment[
            "REVIVAL_TRAINING_PACKAGE"
        ] else {
            throw XCTSkip("set REVIVAL_TRAINING_PACKAGE to a training.revival")
        }
        let level = try loadCanonicalLevel(from: URL(fileURLWithPath: path))
        let bot1 = level.findObjectName("DestroyBot1")
        let bot2 = level.findObjectName("DestroyBot2")
        let info = try XCTUnwrap(level.objectInfo(for: bot1))
        let laser = try XCTUnwrap(level.weapon(named: "Laser Level 2 - Blue"))
        XCTAssertEqual(laser.genericDamage, 7.5)
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        session.world = settingTrainingCounters(session.world) {
            $0.script027Count = 1
        }
        // Script 027 unghosted DestroyBot1; DestroyBot2 waits as a ghost.
        session.world.unghostObject(bot1)
        session.world.ghostObject(bot2)
        XCTAssertEqual(
            session.world.objects[bot1]?.shields, Float(info.hitPoints)
        )
        let player = session.world.testPlayerObject.handle
        var shots = 0
        while session.world.objects[bot1].map({
            $0.flags & GameObject.deadFlag == 0
                && $0.flags & GameObject.dyingFlag == 0
        }) == true, shots < 100 {
            session.world.gameTime += 0.25
            session.world.fireWeaponFromPlayer(
                player,
                weaponType: PlayerWeaponState.primary,
                isDown: true,
                downTime: 0.25,
                level: level
            )
            let bolt = try XCTUnwrap(session.world.objects.filter {
                $0.type == .weapon && $0.flags & GameObject.deadFlag == 0
            }.last)
            session.world.collideTwoObjects(bolt.handle, bot1, level: level)
            shots += 1
        }
        // Rookie scales each 7.5 by 1.5 (Diff_robot_damage).
        XCTAssertEqual(
            shots, Int((Float(info.hitPoints) / 11.25).rounded(.down)) + 1
        )
        var timestamp = 0.0
        for _ in 0..<40 where session.world.objects[bot1] != nil {
            timestamp += 0.1
            _ = session.update(at: timestamp, input: .zero)
        }
        XCTAssertNil(session.world.objects[bot1])
        XCTAssertEqual(session.world.playerScore, Int32(info.score ?? 0))
        XCTAssertEqual(session.world.testTrainingMission?.script028Count, 1)
        XCTAssertNotEqual(session.world.objects[bot2]?.type, .dummy)
    }

    // MARK: - Helpers

    /// The moving-target lesson with the Training module: FollowBot1,
    /// DestroyBot1, and DestroyBot2 (ghosts until Scripts 027 and 028).
    private func movingTargetSession() throws -> GameSession {
        let level = addingTrainingMissionScripting(
            makeTrainingMovingTargetHandoffLevel()
        )
        try level.validate()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        XCTAssertNotNil(session.world.testTrainingMission)
        for handle in [destroyBot1, destroyBot2] {
            session.world.ghostObject(handle)
        }
        return session
    }

    /// KillObject with no delay (a death type of DF_FIREBALL and
    /// DF_BREAKS_APART): the object is dead now, and ObjDeleteDead sends
    /// EVT_DESTROY at the end of the next object frame.
    private func killNow(_ session: GameSession, _ handle: ObjectHandle) {
        session.world.killObject(
            handle,
            killer: session.world.testPlayerObject.handle,
            damage: 10,
            deathFlags: DeathFlags.fireball | DeathFlags.breaksApart,
            delayTime: 0,
            level: session.level
        )
        XCTAssertNotEqual(
            (session.world.objects[handle]?.flags ?? 0) & GameObject.deadFlag,
            0
        )
    }

    private func levelTimer(_ session: GameSession, _ id: Int32) -> OsirisTimer? {
        session.world.osirisTimers.entries.first {
            $0.isUsed && $0.owner == .level && $0.id == id
        }
    }
}
