import XCTest

// The retail-gated trace: the imported Training package
// (REVIVAL_TRAINING_PACKAGE, the path of a schema 13 `training.revival`,
// engineering.md section 2) played lesson by lesson through the Osiris
// runtime, the AIGame Guide-Bot, the generic weapons, and the stored BOA
// tables. Every synthetic test of the same scripts stays in
// TrainingMissionScriptTests and the system test files; this trace checks
// that the real level, pages, strings, and sounds reach them.
final class TrainingPlaythroughTests: XCTestCase {
    func testImportedTrainingPackagePlaysTheTrainingMission() throws {
        guard let path = ProcessInfo.processInfo.environment[
            "REVIVAL_TRAINING_PACKAGE"
        ] else {
            throw XCTSkip("set REVIVAL_TRAINING_PACKAGE to a training.revival")
        }

        let level = try loadCanonicalLevel(from: URL(fileURLWithPath: path))
        try levelStartThroughTheFirstLessons(level)
        try timedDodge(level)
        try destroyBot1ShotDown(level)
        try portal2AndBuddyMenuRelease(level)
        try translatedGuideBotRelease(level)
        try playerAndGuideBotFlares(level)
        try lateLessonsToTheLevelEnd(level)
        try makeBOARemakesTheStoredTables(level)
    }

    /// The imported level starts the Training module, the 1 s level timer shows the
    /// retail Welcome and GoForward messages around welcome.osf, flying
    /// forward into ForwardGoal runs Script 001, and reversing into
    /// StartGoal runs Script 003.
    private func levelStartThroughTheFirstLessons(_ level: Level) throws {
        let scripting = try XCTUnwrap(level.scripting)
        XCTAssertEqual(scripting.levelScript, "trainingmission")
        let welcome = try XCTUnwrap(scripting.message(named: "Welcome"))
        let goForward = try XCTUnwrap(scripting.message(named: "GoForward"))
        XCTAssertTrue(level.voiceClips.contains {
            $0.sourceName == "welcome.osf"
        })

        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        XCTAssertEqual(session.world.testTrainingMission?.script000Count, 1)
        XCTAssertEqual(session.world.playerControllerBitflags, [.forward])
        for name in ["FlashLight-1", "FlashLight-5"] {
            let handle = level.findObjectName(name)
            XCTAssertEqual(
                session.world.objects[handle]?.localLighting?.lightDistance, 0,
                name
            )
        }
        for name in ["DestroyBot1", "DestroyBot2"] {
            XCTAssertEqual(
                session.world.objects[level.findObjectName(name)]?.type, .dummy,
                name
            )
        }

        var feedback: [PresentationFeedback] = []
        for frameIndex in 1...10 {
            feedback += session.update(
                at: Double(frameIndex) * 0.1, input: .zero
            ).presentationFeedback
        }
        XCTAssertTrue(feedback.isEmpty)
        let eleventh = session.update(at: 1.1, input: .zero)
        XCTAssertEqual(
            eleventh.presentationFeedback.map(\.hudMessages),
            [[welcome], [], [goForward]]
        )
        XCTAssertEqual(
            eleventh.presentationFeedback.map(\.voiceSourceName),
            ["", "welcome.osf", ""]
        )

        // Script 001 on real content: thrust forward into ForwardGoal. The
        // player's physics move sends its EVT_COLLIDE.
        let goodJob = try XCTUnwrap(scripting.message(named: "GoodJob"))
        let goBackwards = try XCTUnwrap(scripting.message(named: "GoBackwards"))
        var log: [String] = []
        var timestamp = 1.1
        for _ in 0..<300
        where session.world.testTrainingMission?.script001Count == 0 {
            timestamp += 0.1
            log += presentationLog(
                session.update(at: timestamp, input: InputSnapshot(forward: 1))
            )
        }
        XCTAssertEqual(session.world.testTrainingMission?.script001Count, 1)
        XCTAssertEqual(
            log, ["hud:\(goodJob)", "voice:return1.osf", "hud:\(goBackwards)"]
        )
        XCTAssertEqual(session.world.playerControllerBitflags, [.reverse])

        // Script 003: reverse back into StartGoal.
        let goLeft = try XCTUnwrap(scripting.message(named: "GoLeft"))
        log = []
        for _ in 0..<300
        where session.world.testTrainingMission?.script003Count == 0 {
            timestamp += 0.1
            log += presentationLog(
                session.update(at: timestamp, input: InputSnapshot(forward: -1))
            )
        }
        XCTAssertEqual(session.world.testTrainingMission?.script003Count, 1)
        XCTAssertEqual(log, ["hud:\(goLeft)", "voice:left1.osf"])
        XCTAssertEqual(session.world.playerControllerBitflags, [.left])
    }

    /// the imported object tables give DodgeTurrett the
    /// Hangturret page and FollowBot1 the flyer page; Script 016 powers the
    /// turret; with the pilot in the dodge room the turret's red lasers hit
    /// the hull and Script 018 restarts the dodge; and timer 2 then runs
    /// Script 017.
    private func timedDodge(_ level: Level) throws {
        let turret = level.findObjectName("DodgeTurrett")
        let followBot = level.findObjectName("FollowBot1")
        XCTAssertEqual(level.objectInfo(for: turret)?.name, "Hangturret")
        XCTAssertEqual(
            level.objectInfo(for: followBot)?.name, "RAS1 Light Security Flyer"
        )
        let laser = try XCTUnwrap(level.weapon(named: "Laser Level 1 - Red"))
        XCTAssertEqual(laser.speed, 200)
        XCTAssertEqual(laser.playerDamage, 6.75)

        // Whether a spread shot meets the hull depends on the ps_rand
        // draws, which now include each wall hit's random small explosion
        // (DoWeaponExploded); with this seed a shot hits within 7 s.
        let session = GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        XCTAssertNotEqual(
            session.world.objects[turret]!.ai!.flags
                & ObjectAIFrame.disabledFlag,
            0
        )
        session.world = settingTrainingCounters(session.world) {
            $0.script002Count = 1
            $0.script033Count = 1
        }

        let startDodge = level.findObjectName("StartDodge")
        session.world.osirisCallEvent(
            startDodge, .timer(id: 8, gameTime: session.world.gameTime),
            level: level
        )
        XCTAssertEqual(session.world.testTrainingMission?.script016Count, 1)
        // The pilot waits at DoneDodgeingGoal, about 85 units from the
        // turret. The turret's shots spread (Rookie's minimum fire spread,
        // 0.15), and only a shot that meets the ship's hull hits
        // (collide.cpp:2623).
        var player = session.world.testPlayerObject
        let goal = try XCTUnwrap(
            session.world.objects[level.findObjectName("DoneDodgeingGoal")]
        )
        player.location = goal.location
        player.position = goal.position
        session.world.objects[player.handle] = player

        var timestamp = 0.0
        var sawWeapon = false
        for _ in 0..<1_200
        where session.world.testTrainingMission!.script018Count == 0 {
            timestamp += 0.05
            _ = session.update(at: timestamp, input: .zero)
            sawWeapon = sawWeapon
                || session.world.objects.contains { $0.type == .weapon }
        }
        XCTAssertTrue(sawWeapon)
        XCTAssertEqual(session.world.testTrainingMission?.script018Count, 1)
        XCTAssertEqual(session.world.shields, 100)

        session.world.osirisCallEvent(
            level.findObjectName("DoneDodgeingGoal"),
            .timer(id: 2, gameTime: session.world.gameTime), level: level
        )
        XCTAssertEqual(session.world.testTrainingMission?.script017Count, 1)
        XCTAssertNotEqual(
            session.world.objects[turret]!.ai!.flags
                & ObjectAIFrame.disabledFlag,
            0
        )
    }

    /// the player's imported blue laser shoots DestroyBot1 down
    /// through collide_generic_and_weapon and ApplyDamageToGeneric; its
    /// death scores the page's points, and Script 028 unghosts DestroyBot2.
    private func destroyBot1ShotDown(_ level: Level) throws {
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
                player, weaponType: PlayerWeaponState.primary, isDown: true,
                downTime: 0.25, level: level
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

    /// after Script 036 opens PortalRoom4, the player flies
    /// through the retail Portal2 trigger face (PortalRoom4's portal 1),
    /// Script 032 runs from its EVT_COLLIDE, and the buddy menu's "Exit
    /// ship" then releases the Guide-Bot, so Script 060 turns every
    /// control on.
    private func portal2AndBuddyMenuRelease(_ level: Level) throws {
        let simulation = GameSession(level: level, presentationReadyTimestamp: 0)
        simulation.world.trainingMission.script002Count = 1
        // DestroyBot2's death runs Script 036 (TrainingMission.cpp:2040),
        // which opens PortalRoom4, where Portal2 is.
        simulation.world.osirisCallEvent(
            level.findObjectName("DestroyBot2"), .destroy(isDying: true),
            level: level
        )
        XCTAssertEqual(simulation.world.testTrainingMission?.script036Count, 1)
        let portal2 = try XCTUnwrap(level.triggers.firstIndex {
            $0.name.caseInsensitiveCompare("Portal2") == .orderedSame
        })
        let trigger = level.triggers[portal2]
        let center = simulation.world.roomFaceCenter(
            trigger.roomIndex, face: trigger.faceIndex, level: level
        )
        let normal = simulation.world.roomFaceNormal(
            trigger.roomIndex, face: trigger.faceIndex, level: level
        )
        // The player waits inside the trigger's room, 10 units in front of
        // the face (face normals point into the room), and moves out
        // through it.
        let player = simulation.world.testPlayerObject.handle
        simulation.world.objects[player]?.location = .room(trigger.roomIndex)
        simulation.world.objects[player]?.position = center + normal * 10
        var timestamp = 0.0
        var log: [String] = []
        for _ in 1...10
        where simulation.world.testTrainingMission?.script032Count == 0 {
            simulation.world.velocity = normal * -100
            timestamp += 0.1
            log = presentationLog(simulation.update(at: timestamp, input: .zero))
        }
        XCTAssertEqual(simulation.world.testTrainingMission?.script032Count, 1)
        let voice = try XCTUnwrap(level.scripting?.streamedAudio.first {
            $0.name == "GuideBotA.osf"
        }?.key)
        XCTAssertEqual(log.first, "voice:\(voice)")
        XCTAssertEqual(log.filter { $0.hasPrefix("hud:") }, [
            "hud:\(TrainingMissionScript.message(0, level: level))",
            "hud:\(TrainingMissionScript.message(27, level: level))",
        ])
        XCTAssertEqual(simulation.world.playerControllerBitflags.rawValue, 0)

        let menu = try XCTUnwrap(simulation.openBuddyMenu(at: timestamp))
        XCTAssertEqual(menu.itemText(0), "1. Exit ship")
        simulation.selectBuddyMenuItem(0, at: timestamp)
        timestamp += 0.1
        _ = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(
            simulation.world.objectType(simulation.world.buddyHandle), .robot
        )
        XCTAssertEqual(simulation.world.testTrainingMission?.script060Count, 1)
        XCTAssertEqual(simulation.world.playerControllerBitflags, .all)
    }

    /// the imported aigame module data, AIInitAll's ObjCreate of
    /// the Guide-Bot, its retail menu, and the release through the
    /// exit command to GBM_AMBIENT.
    private func translatedGuideBotRelease(_ level: Level) throws {
        // The Guide-Bot binds AIGame; the two pickups bind the generic
        // module.
        XCTAssertEqual(
            level.gameModules?.map(\.module),
            [AIGame.moduleName, GenericModule.moduleName]
        )
        let module = try XCTUnwrap(level.gameModules?.first {
            $0.module == AIGame.moduleName
        })
        XCTAssertGreaterThanOrEqual(module.strings.count, 146)
        XCTAssertEqual(module.sounds.map(\.name), AIGame.references.soundNames)
        XCTAssertNotEqual(
            GameWorld(level: level).weaponFindID("Yellow flare", level: level),
            -1
        )
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0
        )
        // AIInitAll's ObjCreate takes slot 20, the lowest free slot, whose
        // stored handle 6164 the level file retired (CHUNK_OBJECT_HANDLES,
        // LoadLevel.cpp:3847): the next handle count is 8212
        // (object.cpp:1700).
        let buddy = simulation.world.buddyHandle
        XCTAssertEqual(level.retiredObjectHandles, [6_164])
        XCTAssertEqual(buddy, ObjectHandle(8_212))
        XCTAssertEqual(simulation.world.objectType(buddy), .dummy)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode, GuideBotScript.inShipMode
        )
        let menu = try XCTUnwrap(
            simulation.world.guideBotMenu(level: simulation.level)
        )
        XCTAssertEqual(menu.commands.first?.id, 0)
        XCTAssertEqual(menu.commands.first?.text, "Exit ship")

        var timestamp = 0.0
        simulation.releaseOrRecallTestGuideBot()
        let released = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(soundNames(released), ["GBExpulsionA"])
        XCTAssertEqual(simulation.world.objectType(buddy), .robot)
        simulation.runFrames(14, from: &timestamp)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode, GuideBotScript.ambientMode
        )
        XCTAssertEqual(simulation.world.soundSystem.objectLoops.count, 1)
    }

    /// the imported Training package fires the player's flare
    /// from the ship's flare battery, and the released Guide-Bot fires its
    /// Yellow flare in GBM_AMBIENT.
    private func playerAndGuideBotFlares(_ level: Level) throws {
        let flareIndex = try XCTUnwrap(level.weapons?.firstIndex {
            $0.name == "Yellow flare"
        })
        let flare = try XCTUnwrap(level.weapons?[flareIndex])
        XCTAssertEqual(flare.spawn?.weapon, "YellowFlareSparks")
        XCTAssertEqual(flare.spawn?.count, 9)
        XCTAssertEqual(flare.particles?.count, 25)
        XCTAssertNotNil(level.weapon(named: "YellowFlareSparks")?.fireImage)
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0
        )
        var timestamp = 0.1
        let fired = simulation.update(
            at: timestamp, input: .init(firesPlayerFlare: true)
        )
        let playerFlare = try XCTUnwrap(
            simulation.world.objects.filter { $0.weapon == flareIndex }.only
        )
        XCTAssertEqual(playerFlare.parent,
                       simulation.world.testPlayerObject.handle)
        XCTAssertTrue(soundNames([fired]).contains("Flare"))

        simulation.releaseOrRecallTestGuideBot()
        simulation.runFrames(15, from: &timestamp)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode, GuideBotScript.ambientMode
        )
        simulation.world.prepareTestGuideBotFlare(
            helperSlotsAreUsed: false, level: simulation.level
        )
        simulation.runFrames(1, from: &timestamp)
        XCTAssertTrue(simulation.world.objects.contains {
            $0.weapon == flareIndex
                && $0.parent == simulation.world.buddyHandle
        })
    }

    /// the second half of Training on the imported package,
    /// through the translated scripts and the generic runtime. The player
    /// takes the Camera Monitor (Script 040: the level goal completes) and
    /// uses it (Script 059: the popup view looks from the SecurityCamera's
    /// gun 0; Script 058 follows with the Guide-Bot in the ship), enters
    /// the KillBot room (Script 042), takes the two powerups (Scripts 047
    /// and 048 with the generic pickups), shoots the RAS bots (Scripts
    /// 043-046, then 034 and 049), enters the last room (Script 050),
    /// shoots the last bots (Scripts 051-055, then 035 and 056), and
    /// touches FinalGoal (Script 057), whose aEndLevel ends Training with
    /// the success result.
    private func lateLessonsToTheLevelEnd(_ level: Level) throws {
        for name in EngineSound.names {
            XCTAssertTrue(
                level.soundClips.contains { $0.logicalName == name },
                name
            )
        }

        let simulation = GameSession(level: level, presentationReadyTimestamp: 0)
        simulation.world.trainingMission.script002Count = 1
        var timestamp = 0.1
        _ = simulation.update(at: timestamp, input: .zero)
        func voice(_ name: String) throws -> String {
            "voice:" + (try XCTUnwrap(level.scripting?.streamedAudio.first {
                $0.name == name
            }?.key))
        }

        func message(_ index: Int) -> String {
            "hud:" + TrainingMissionScript.message(index, level: level)
        }

        func next(_ input: InputSnapshot = .zero) -> [String] {
            timestamp += 0.1
            return presentationLog(simulation.update(at: timestamp, input: input))
        }

        func touch(_ name: String) -> [String] {
            timestamp += 0.1
            return presentationLog(simulation.touch(name, at: timestamp))
        }

        func cross(_ trigger: String) throws -> [String] {
            let index = try XCTUnwrap(level.triggers.firstIndex {
                $0.name.caseInsensitiveCompare(trigger) == .orderedSame
            })
            simulation.world.objCheckTriggers(
                simulation.world.testPlayerObject.handle,
                recordedFaces: [.init(
                    roomSourceIndex: level.triggers[index].roomIndex,
                    faceIndex: level.triggers[index].faceIndex
                )],
                level: level
            )
            return next()
        }

        // Script 040.
        let pickup = touch("CameraMonitor")
        XCTAssertEqual(pickup, [
            try voice("GuideBotC.osf"), "sound:PupC1",
            "hud:Completed Locate the Camera Monitor", "sound:GoalComplete",
            message(28),
        ])
        XCTAssertEqual(level.goals.count, 1)
        XCTAssertNotEqual(
            simulation.world.goals[0].status & LevelGoalFlag.completed, 0
        )
        // Script 059, then Script 058 (the Guide-Bot is in the ship).
        let used = next(.init(usesInventory: true))
        XCTAssertEqual(Array(used.prefix(2)), [
            try voice("GuideBotD.osf"), message(34),
        ])
        XCTAssertTrue(used.contains(try voice("proceed6.osf")))
        let popup = try XCTUnwrap(simulation.update(
            at: timestamp + 0.1, input: .zero
        ).popupView)
        timestamp += 0.1
        let camera = level.findObjectName("SecurityCamera")
        XCTAssertEqual(popup.viewerObjectHandle, camera.rawValue)
        XCTAssertEqual(popup.remainingDuration, 9.9, accuracy: 0.000_1)
        let cameraObject = try XCTUnwrap(simulation.world.objects[camera])
        XCTAssertLessThan(
            vectorDistance(popup.camera.position, cameraObject.position), 10
        )
        XCTAssertNotEqual(popup.camera.position, cameraObject.position)

        // Script 042, the pickups (047 and 048), and the RAS bots.
        let killBot = try cross("Portal3")
        XCTAssertEqual(killBot, [message(29), try voice("intro6.osf")])
        let invulnerable = touch("InvulnPowerup2")
        XCTAssertEqual(invulnerable, [
            "sound:Invulnerability on", "hud:Invulnerability On",
            "sound:Powerup pickup",
        ])
        let cloaked = touch("CloakPowerup2")
        XCTAssertEqual(cloaked, [
            "sound:Cloak on", "hud:Cloak On", "sound:Powerup pickup",
        ])
        simulation.killRobotsAsPlayer([2_074, 2_075, 2_077, 2_078])
        // The robots die after their dying delays; then Script 034's
        // timer 9 runs Script 049, and Script 042's timer 14 Script 039.
        var log: [String] = []
        for _ in 1...300
        where simulation.world.testTrainingMission.map({
            $0.script049Count == 0 || $0.script039Count == 0
        }) == true {
            log += next()
        }

        let mission = try XCTUnwrap(simulation.world.testTrainingMission)
        XCTAssertEqual(
            [mission.script042Count, mission.script047Count,
             mission.script048Count, mission.script043Count,
             mission.script044Count, mission.script045Count,
             mission.script046Count, mission.script034Count,
             mission.script049Count, mission.script039Count,
             mission.script041Count],
            [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        )
        XCTAssertTrue(log.contains(message(31)))
        XCTAssertTrue(log.contains(message(30)))

        // Script 050, the last bots (051-055, 035, and 056), and 057.
        let lastRoom = try cross("Portal4")
        XCTAssertEqual(lastRoom, [
            message(0), try voice("intro7.osf"), message(32),
        ])
        simulation.killRobotsAsPlayer([4_127, 2_080, 2_081, 2_082, 2_083])
        log = []
        for _ in 1...300
        where simulation.world.testTrainingMission?.script056Count == 0 {
            log += next()
        }
        XCTAssertEqual(simulation.world.testTrainingMission?.script056Count, 1)
        XCTAssertTrue(log.contains(message(33)))
        timestamp += 0.1
        let final = simulation.touch("FinalGoal", at: timestamp)
        XCTAssertEqual(simulation.world.testTrainingMission?.script057Count, 1)
        let end = try XCTUnwrap(final.levelEnd)
        XCTAssertEqual(end.endLevelState, .succeeded)
        XCTAssertEqual(end.postLevelResult.title, "Mission Successful")
        XCTAssertEqual(end.postLevelResult.enemyKills, 9)
        XCTAssertEqual(simulation.levelOutcome, .awaitingResultAcknowledgement)
    }

    /// MakeBOA at load (BOA.cpp:2020), run on the imported Training level without its
    /// stored tables, remakes what the level file stores: the small-portal
    /// flags, the path points, the costs, and each indoor pair's next room,
    /// blockage, sound, and robot flags.
    private func makeBOARemakesTheStoredTables(_ level: Level) throws {
        let stored = level
        let storedTables = try XCTUnwrap(stored.boaTables)
        // Without the tables, the small-portal flags, and the path points
        // the file stores, so MakeBOA must remake them all.
        var bare = stored
        bare.boaTables = nil
        for room in bare.rooms.indices {
            bare.rooms[room].pathPoint = .zero
            for portal in bare.rooms[room].portals.indices {
                bare.rooms[room].portals[portal].flags &= ~4
                bare.rooms[room].portals[portal].pathPoint = .zero
            }
        }

        let made = bare.madeByMakeBOA()
        let tables = try XCTUnwrap(made.boaTables)
        var mismatches: [String] = []
        for (room, madeRoom) in zip(stored.rooms, made.rooms) {
            for (index, (portal, madePortal)) in zip(
                room.portals, madeRoom.portals
            ).enumerated() {
                if portal.flags & 4 != madePortal.flags & 4 {
                    mismatches.append("small \(room.sourceIndex):\(index)")
                }
                if vectorDistance(portal.pathPoint, madePortal.pathPoint)
                    > 0.01 {
                    mismatches.append("portal point \(room.sourceIndex):\(index)")
                }

                let a = storedTables.cost(room.sourceIndex, index)
                let b = tables.cost(room.sourceIndex, index)
                if abs(a - b) > 0.01 {
                    mismatches.append("cost \(room.sourceIndex):\(index) \(a) \(b)")
                }
            }
            if vectorDistance(room.pathPoint, madeRoom.pathPoint) > 0.01 {
                mismatches.append("room point \(room.sourceIndex)")
            }
        }

        let used = stored.rooms.map(\.sourceIndex)
        let mask: UInt16 = BOATables.roomMask | BOATables.blockageFlag
            | BOATables.tooSmallForRobotFlag | 0x0800
        for i in used {
            for j in used where storedTables.entry(i, j) & mask
                != tables.entry(i, j) & mask {
                mismatches.append(
                    "entry \(i),\(j) \(storedTables.entry(i, j)) \(tables.entry(i, j))"
                )
            }
        }
        XCTAssertEqual(mismatches.count, 0,
                       mismatches.prefix(40).joined(separator: "; "))
    }

    private func timer(
        _ session: GameSession, _ owner: OsirisTimer.Owner, _ id: Int32
    ) -> OsirisTimer? {
        session.world.osirisTimers.entries.first {
            $0.isUsed && $0.owner == owner && $0.id == id
        }
    }
}
