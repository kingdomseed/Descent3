import XCTest

// The KillBot room, the pickups, and the last room of TrainingMission.cpp:
// TriggerScript_0001 (Script 042, :2347-2366) with level timer 14 (Script
// 039, :1593-1600), the InvulnPowerup2 and CloakPowerup2 custom scripts
// (Scripts 047 and 048, :2174-2200) with the generic module's
// GenericScript (generic.cpp:310) and msafe_DoPowerup (multisafe.cpp:2467),
// Script 034 (:1403-1415) and its timer 9 (Script 049, :1602-1611), and
// TriggerScript_0002 (Script 050, :2368-2387).
final class TrainingLateLessonTests: XCTestCase {
    /// `level` with the Training module, PortalRoom5 named, and no
    /// Guide-Bot.
    private func session(_ level: Level) throws -> GameSession {
        let scripted = scriptingTrainingCameraMonitorLevel(
            level,
            guideBot: false
        )
        try scripted.validate()
        let session = GameSession(
            level: scripted,
            presentationReadyTimestamp: 0
        )
        // Script 002's first HUD message has run.
        session.world.trainingMission.script002Count = 1
        return session
    }

    private func restored(_ session: GameSession, at timestamp: Double)
        throws -> GameSession
    {
        try GameSession(
            level: session.level,
            world: JSONDecoder().decode(
                GameWorld.self,
                from: JSONEncoder().encode(session.world)
            ),
            resumedAtTimestamp: timestamp
        )
    }

    /// The presentation of the frames from `start`, 0.1 s apart, through
    /// `end`.
    private func run(
        _ session: GameSession,
        from start: Double,
        through end: Double
    ) -> [String] {
        var log: [String] = []
        var timestamp = start
        while timestamp <= end + 0.000_1 {
            log += presentationLog(session.update(at: timestamp, input: .zero))
            timestamp += 0.1
        }
        return log
    }

    /// Script 042: crossing Portal3 (the trigger's EVT_COLLIDE from
    /// ObjCheckTriggers) sets level timer 14 for 13 s, turns FlashLight-3
    /// off, shows KillBotIntro, plays intro6, and closes PortalRoom5's two
    /// portals, once. Script 039 then plays GuidebotF and shows KillBot2 on
    /// the timer.
    func testPortal3RunsScript042AndItsTimerRunsScript039AcrossReload() throws {
        let simulation = try session(makeTrainingKillbotEntryLevel())
        let player = simulation.world.testPlayerObject.handle
        simulation.world.setObjectLightDistance(
            simulation.level.findObjectName("FlashLight-3"),
            50
        )

        simulation.world.objCheckTriggers(
            player,
            recordedFaces: [.init(roomSourceIndex: 2, faceIndex: 1)],
            level: simulation.level
        )
        let entered = simulation.update(at: 0.1, input: .zero)

        XCTAssertEqual(presentationLog(entered), [
            "hud:\(trainingText("KillBotIntro"))",
            "voice:intro6.osf",
        ])
        XCTAssertEqual(simulation.world.testTrainingMission?.script042Count, 1)
        XCTAssertEqual(simulation.returnMarkerLightDistance, 0)
        let room = try XCTUnwrap(simulation.level.rooms.firstIndex {
            $0.sourceIndex == 2
        })
        XCTAssertTrue(simulation.world.rooms[room].portalFlags.allSatisfy {
            $0 & LevelPortal.renderFacesFlag != 0
        })
        let timer = try XCTUnwrap(simulation.world.osirisTimers.entries.first {
            $0.isUsed && $0.owner == .level && $0.id == 14
        })
        XCTAssertEqual(timer.end, 13, accuracy: 0.000_1)
        // Portal3 is a one-shot trigger (TF_ONESHOT): it does not fire again.
        simulation.world.objCheckTriggers(
            player,
            recordedFaces: [.init(roomSourceIndex: 2, faceIndex: 1)],
            level: simulation.level
        )
        XCTAssertEqual(simulation.world.testTrainingMission?.script042Count, 1)

        let resumed = try restored(simulation, at: 100)
        let log = run(resumed, from: 100.1, through: 113.1)
        XCTAssertEqual(log, [
            "voice:guidebotf.osf",
            "hud:\(trainingText("KillBot2"))",
        ])
        XCTAssertEqual(resumed.world.testTrainingMission?.script039Count, 1)
    }

    /// Script 047 counts the InvulnPowerup2 pickup; the powerup's generic
    /// default script then runs msafe_DoPowerup's Invulnerability branch:
    /// MakePlayerInvulnerable for 30 s with its sound and message
    /// (Player.cpp:1576), the powerup dies, and SOUND_POWERUP_PICKUP plays.
    /// DoPlayerFrame counts the time down; at the end MakePlayerVulnerable
    /// plays "Invulnerability off" and shows TXT_INVULNOFF (:1597, :1816).
    func testInvulnPowerup2RunsScript047AndExpiresAcrossReload() throws {
        let simulation = try session(makeTrainingInvulnerabilityPickupLevel())
        let pickup = simulation.level.findObjectName("InvulnPowerup2")
        XCTAssertEqual(
            simulation.world.objects[pickup]?.scripts?.defaultScript,
            .genericPowerup
        )

        // Script 000's aObjMakeInvuln(player, 0) (TrainingMission.cpp:1468)
        // leaves the player invulnerable until the first DoPlayerFrame, and
        // the pickup refuses an invulnerable player (multisafe.cpp:2777).
        _ = simulation.update(at: 0.1, input: .zero)
        XCTAssertNil(simulation.world.playerInvulnerableTime)
        let frame = simulation.touch("InvulnPowerup2", at: 0.2)

        XCTAssertEqual(presentationLog(frame), [
            "sound:Invulnerability on",
            "hud:Invulnerability On",
            "sound:Powerup pickup",
        ])
        XCTAssertEqual(
            frame.presentationFeedback.first?.soundEventVolume,
            0.5
        )
        XCTAssertEqual(simulation.world.testTrainingMission?.script047Count, 1)
        XCTAssertNil(simulation.world.objects[pickup])
        XCTAssertEqual(
            try XCTUnwrap(frame.playerInvulnerabilityRemaining),
            29.9,
            accuracy: 0.000_1
        )
        let shields = simulation.shields
        XCTAssertFalse(simulation.world.applyDamageToPlayer(
            simulation.world.testPlayerObject.handle,
            killer: .none,
            damage: 10,
            level: simulation.level
        ))
        XCTAssertEqual(simulation.shields, shields)

        // A save in the middle of the invulnerability continues it.
        _ = run(simulation, from: 0.3, through: 15.2)
        let resumed = try restored(simulation, at: 100)
        XCTAssertEqual(
            try XCTUnwrap(resumed.world.playerInvulnerableTime),
            14.9,
            accuracy: 0.001
        )
        XCTAssertTrue(resumed.world.playerInvulnerabilityAnnounces)
        let log = run(resumed, from: 100.1, through: 116)
        XCTAssertEqual(log, [
            "sound:Invulnerability off",
            "hud:Invulnerability Off",
        ])
        XCTAssertNil(resumed.world.playerInvulnerableTime)
    }

    /// Script 048 counts the CloakPowerup2 pickup; msafe_DoPowerup's Cloak
    /// branch runs MakeObjectInvisible for 30 s (object_lighting.cpp:572):
    /// "Cloak on" and TXT_CLOAKON, a 1-second fade out, then the cloak, in
    /// which the robots do not see the player (AIDetermineObjVisLevel,
    /// AImain.cpp:1645), then MakeObjectVisible's "Cloak off" and
    /// TXT_MSG_CLOAKOFF and a 1-second fade in (ObjDoEffects,
    /// object.cpp:2447). With the four RAS bots and the invulnerability
    /// already counted, this sixth producer runs Script 034 in the same
    /// frame, and its timer 9 runs Script 049.
    func testCloakPowerup2RunsScript048ThenScript034AndCloaksAcrossReload()
        throws
    {
        let simulation = try session(makeTrainingCloakPickupLevel())
        for counter in [\TrainingMissionState.script043Count,
                        \.script044Count, \.script045Count,
                        \.script046Count, \.script047Count] {
            simulation.world.trainingMission[keyPath: counter] = 1
        }
        let player = simulation.world.testPlayerObject.handle

        let frame = simulation.touch("CloakPowerup2", at: 0.1)

        XCTAssertEqual(presentationLog(frame), [
            "sound:Cloak on",
            "hud:Cloak On",
            "sound:Powerup pickup",
        ])
        let mission = try XCTUnwrap(simulation.world.testTrainingMission)
        XCTAssertEqual(mission.script048Count, 1)
        XCTAssertEqual(mission.script034Count, 1)
        XCTAssertEqual(
            simulation.world.objects[
                simulation.level.findObjectName("FlashLight-4")
            ]?.localLighting?.lightDistance,
            50
        )
        let cloak = try XCTUnwrap(frame.playerCloak)
        XCTAssertEqual(cloak.phase, .fadingOut)
        XCTAssertEqual(cloak.phaseRemaining, 0.9, accuracy: 0.000_1)
        XCTAssertEqual(cloak.phaseDuration, 1)

        let fadeLog = run(simulation, from: 0.2, through: 1.1)
        XCTAssertEqual(fadeLog, [])
        let cloaked = try XCTUnwrap(
            ObjectCloakFrame(simulation.world.objects[player]?.effect)
        )
        XCTAssertEqual(cloaked.phase, .cloaked)
        let robot = try XCTUnwrap(simulation.world.objects[ObjectHandle(2_074)])
        XCTAssertEqual(
            simulation.world.aiDetermineObjVisLevel(
                robot,
                simulation.world.testPlayerObject
            ),
            0
        )

        // Script 034's level timer 9 (2 s) runs Script 049.
        let timerLog = run(simulation, from: 1.2, through: 2.2)
        XCTAssertEqual(timerLog, [
            "hud:\(trainingText("GoodJob"))",
            "hud:\(trainingText("ProceedtoLastRoom"))",
            "voice:proceed5.osf",
        ])

        let resumed = try restored(simulation, at: 100)
        XCTAssertEqual(
            ObjectCloakFrame(resumed.world.objects[player]?.effect)?.phase,
            .cloaked
        )
        // The cloak ends 30 s after the fade (about 28.9 s after the
        // save), and the fade in takes 1 s.
        var endLog: [String] = []
        var timestamp = 100.1
        while endLog.isEmpty, timestamp < 131 {
            endLog = presentationLog(resumed.update(at: timestamp, input: .zero))
            timestamp += 0.1
        }
        XCTAssertEqual(endLog, [
            "sound:Cloak off",
            "hud:Cloak Off",
        ])
        XCTAssertEqual(timestamp, 128.9, accuracy: 0.15)
        XCTAssertEqual(
            ObjectCloakFrame(resumed.world.objects[player]?.effect)?.phase,
            .fadingIn
        )
        XCTAssertTrue(run(resumed, from: timestamp, through: timestamp + 1.1)
            .isEmpty)
        XCTAssertNil(ObjectCloakFrame(resumed.world.objects[player]?.effect))
    }

    /// Script 050: crossing Portal4 turns FlashLight-4 off, shows GoodJob,
    /// closes PortalRoom6's two portals, plays intro7, and shows
    /// FinalSessionIntro, in source order, once.
    func testPortal4RunsScript050AndClosesTheLastRoomAcrossReload() throws {
        let level = scriptingTrainingCameraMonitorLevel(
            makeTrainingFinalRoomEntryLevel(),
            guideBot: false
        )
        try level.validate()
        let simulation = try GameSession(
            level: level,
            world: script050ReadyContinuation(in: level),
            resumedAtTimestamp: 0
        )
        let room = try XCTUnwrap(level.rooms.firstIndex {
            $0.sourceIndex == 44
        })
        XCTAssertTrue(simulation.world.rooms[room].portalFlags.allSatisfy {
            $0 & LevelPortal.renderFacesFlag == 0
        })

        let entered = simulation.update(at: 0.1, input: .zero)

        XCTAssertEqual(presentationLog(entered), [
            "hud:\(trainingText("GoodJob"))",
            "voice:intro7.osf",
            "hud:\(trainingText("FinalSessionIntro"))",
        ])
        XCTAssertEqual(simulation.world.testTrainingMission?.script050Count, 1)
        XCTAssertEqual(
            simulation.world.objects[level.findObjectName("FlashLight-4")]?
                .localLighting?.lightDistance,
            0
        )
        XCTAssertTrue(simulation.world.rooms[room].portalFlags.allSatisfy {
            $0 & LevelPortal.renderFacesFlag != 0
        })

        let resumed = try restored(simulation, at: 100)
        XCTAssertTrue(resumed.world.rooms[room].portalFlags.allSatisfy {
            $0 & LevelPortal.renderFacesFlag != 0
        })
        XCTAssertEqual(resumed.world.testTrainingMission?.script050Count, 1)
    }

    /// Real content, opt-in (REVIVAL_TRAINING_PACKAGE, engineering.md
    /// section 2): the second half of Training on the imported package,
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
    func testImportedTrainingPackageRunsTheLateLessonsToTheLevelEnd()
        throws
    {
        guard let path = ProcessInfo.processInfo.environment[
            "REVIVAL_TRAINING_PACKAGE"
        ] else {
            throw XCTSkip("set REVIVAL_TRAINING_PACKAGE to a training.revival")
        }
        let level = try loadCanonicalLevel(from: URL(fileURLWithPath: path))
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
            try voice("GuideBotC.osf"),
            "sound:PupC1",
            "hud:Completed Locate the Camera Monitor",
            "sound:GoalComplete",
            message(28),
        ])
        XCTAssertEqual(level.goals.count, 1)
        XCTAssertNotEqual(
            simulation.world.goals[0].status & LevelGoalFlag.completed,
            0
        )
        // Script 059, then Script 058 (the Guide-Bot is in the ship).
        let used = next(.init(usesInventory: true))
        XCTAssertEqual(Array(used.prefix(2)), [
            try voice("GuideBotD.osf"),
            message(34),
        ])
        XCTAssertTrue(used.contains(try voice("proceed6.osf")))
        let popup = try XCTUnwrap(simulation.update(
            at: timestamp + 0.1,
            input: .zero
        ).popupView)
        timestamp += 0.1
        let camera = level.findObjectName("SecurityCamera")
        XCTAssertEqual(popup.viewerObjectHandle, camera.rawValue)
        XCTAssertEqual(popup.remainingDuration, 9.9, accuracy: 0.000_1)
        let cameraObject = try XCTUnwrap(simulation.world.objects[camera])
        XCTAssertLessThan(
            vectorDistance(popup.camera.position, cameraObject.position),
            10
        )
        XCTAssertNotEqual(popup.camera.position, cameraObject.position)

        // Script 042, the pickups (047 and 048), and the RAS bots.
        let killBot = try cross("Portal3")
        XCTAssertEqual(killBot, [message(29), try voice("intro6.osf")])
        let invulnerable = touch("InvulnPowerup2")
        XCTAssertEqual(invulnerable, [
            "sound:Invulnerability on",
            "hud:Invulnerability On",
            "sound:Powerup pickup",
        ])
        let cloaked = touch("CloakPowerup2")
        XCTAssertEqual(cloaked, [
            "sound:Cloak on",
            "hud:Cloak On",
            "sound:Powerup pickup",
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
            message(0),
            try voice("intro7.osf"),
            message(32),
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
}
