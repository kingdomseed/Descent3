import XCTest

// Training Scripts 016-026 (scripts/TrainingMission.cpp) on the Osiris
// runtime, and the generic AI they drive: the object AI frames made before
// Script 000 (AIInitAll, gamesequence.cpp:1482), EVT_AI_INIT
// (ObjScript.cpp:206), the follow-path goal (AIGoalFollowPathSimple,
// aipath.cpp and AIGoal.cpp), and the turret's weapon objects (AIFire,
// AImain.cpp:1398; CreateAndFireWeapon, weapon.cpp).
extension TrainingMissionScriptTests {
    // MARK: AI frames and EVT_AI_INIT

    /// AIInitAll runs before the level script (gamesequence.cpp:1482,
    /// :1600), so Script 000's aAISetState(0, ...) (TrainingMission.cpp:1484
    /// -1485) finds AI frames and sets AIF_DISABLED on DodgeTurrett and
    /// FollowBot1. An object without an AI page gets no frame.
    func testLevelStartMakesAIFramesThatScript000Disables() throws {
        let session = GameSession(
            level: makeTrainingManeuverFollowLevel(),
            presentationReadyTimestamp: 0
        )
        for name in ["DodgeTurrett", "FollowBot1"] {
            let handle = session.level.findObjectName(name)
            let ai = try XCTUnwrap(session.world.objects[handle]?.ai, name)
            XCTAssertNotEqual(ai.flags & ObjectAIFrame.disabledFlag, 0, name)
        }

        let turret = try XCTUnwrap(
            session.world.objects[session.level.findObjectName("DodgeTurrett")]
        )
        XCTAssertEqual(turret.ai?.aiType, ObjectAIFrame.stationaryTurretType)
        XCTAssertEqual(turret.weaponBatteries.count, 1)
        XCTAssertNil(
            session.world.objects[session.level.findObjectName("StartDodge")]?
                .ai
        )
    }

    /// InitObjectScripts (ObjScript.cpp:199-212) binds each object's
    /// scripts, sends EVT_AI_INIT to a CT_AI object, and then sends
    /// EVT_CREATED, in slot order.
    func testLevelStartSendsAIInitBeforeCreatedOnlyToAIObjects() throws {
        let level = makeTrainingManeuverFollowLevel()
        var world = GameSession(level: level, presentationReadyTimestamp: 0)
            .world
        for object in world.objects {
            var unbound = object
            unbound.scripts = nil
            world.objects[object.handle] = unbound
        }

        var events: [(ObjectHandle, ScriptEvent)] = []
        world.startLevelScripts(level: level) { _, handle, event in
            events.append((handle, event))
        }

        let turret = level.findObjectName("DodgeTurrett")
        let followBot = level.findObjectName("FollowBot1")
        let startDodge = level.findObjectName("StartDodge")
        for handle in [turret, followBot] {
            XCTAssertEqual(
                events.filter { $0.0 == handle }.map(\.1),
                [.aiInit, .created]
            )
        }
        XCTAssertEqual(
            events.filter { $0.0 == startDodge }.map(\.1),
            [.created]
        )
    }

    // MARK: Scripts 016-020, the timed dodge

    /// Script 016 (TrainingMission.cpp:1868-1880): timer 8 on StartDodge
    /// sets the shields to 100, shows Dodge30, sets timer 2 (20 s) on
    /// DoneDodgeingGoal and timer 3 (14 s) on DodgeTurrett, and turns the
    /// turret's AI on.
    func testScript016StartsTheTimersAndTurnsTheTurretOn() throws {
        let session = try startedDodgeSession()
        let gameTime = session.world.gameTime
        XCTAssertEqual(session.world.shields, 100)
        let done = session.level.findObjectName("DoneDodgeingGoal")
        let turret = session.level.findObjectName("DodgeTurrett")
        XCTAssertEqual(
            try XCTUnwrap(timer(session, .object(done), 2)).end,
            gameTime + 20, accuracy: 0.11
        )
        XCTAssertEqual(
            try XCTUnwrap(timer(session, .object(turret), 3)).end,
            gameTime + 14, accuracy: 0.11
        )
        XCTAssertEqual(
            session.world.objects[turret]!.ai!.flags
                & ObjectAIFrame.disabledFlag,
            0
        )
    }

    /// The powered turret fires Laser Level 1 - Red weapon objects from its
    /// gun points (AIFire, AImain.cpp:1398; FireWeaponFromObject,
    /// weapon.cpp); the bolts fly at 200 units per second scaled by
    /// Diff_ai_weapon_speed (0.75 at Rookie); a bolt that hits the player
    /// takes 6.75 shields (collide_player_and_weapon, collide.cpp:1851);
    /// and Script 018 (TrainingMission.cpp:1348-1361) then restores the
    /// shields to 100, restarts timers 3 and 2, and shows DodgeHit.
    func testTurretBoltsHitThePlayerAndScript018RestartsTheDodge() throws {
        // The turret's fire spread and each wall hit's random small
        // explosion (DoWeaponExploded) draw ps_rand, so whether a bolt hits
        // the waiting pilot depends on the seed; with seed 10 one does.
        let session = try startedDodgeSession(seed: 10)
        let turret = session.level.findObjectName("DodgeTurrett")
        var timestamp = session.world.gameTime.double + 1.2
        var sawWeapon = false
        var hitLog: [String] = []
        for _ in 0..<400 where session.world.testTrainingMission!
            .script018Count == 0
        {
            timestamp += 0.05
            let frame = session.update(at: timestamp, input: .zero)
            for object in session.world.objects where object.type == .weapon {
                sawWeapon = true
                XCTAssertEqual(object.parent, turret)
                XCTAssertEqual(sqrt(dot(object.velocity, object.velocity)), 150, accuracy: 0.01)
            }
            if session.world.testTrainingMission!.script018Count == 1 {
                hitLog = presentationLog(frame)
            }
        }
        XCTAssertTrue(sawWeapon)
        XCTAssertEqual(session.world.testTrainingMission?.script018Count, 1)
        XCTAssertTrue(hitLog.contains("hud:\(trainingText("KeepDodging"))"))
        XCTAssertEqual(session.world.shields, 100)
        let gameTime = session.world.gameTime
        let done = session.level.findObjectName("DoneDodgeingGoal")
        XCTAssertEqual(
            try XCTUnwrap(timer(session, .object(done), 2)).end,
            gameTime + 20, accuracy: 0.06
        )
        XCTAssertEqual(
            try XCTUnwrap(timer(session, .object(turret), 3)).end,
            gameTime + 14, accuracy: 0.06
        )
    }

    /// Script 020 (TrainingMission.cpp:1930-1941) has no counter test: each
    /// timer 3 on DodgeTurrett streams almost.osf and shows DodgeAlmost.
    func testScript020RunsOnEveryTurretTimerThree() throws {
        let session = try startedDodgeSession()
        let turret = session.level.findObjectName("DodgeTurrett")
        for expected in 1...2 {
            session.world.osirisCallEvent(
                turret, .timer(id: 3, gameTime: session.world.gameTime),
                level: session.level
            )
            XCTAssertEqual(
                session.world.testTrainingMission?.script020Count, expected
            )
        }

        let log = presentationLog(
            session.update(
                at: session.world.gameTime.double + 1.25, input: .zero
            )
        )
        XCTAssertEqual(
            log.filter { $0 == "voice:almost.osf" }.count,
            2
        )
    }

    /// Script 017 (TrainingMission.cpp:1905-1920): timer 2 on
    /// DoneDodgeingGoal after Script 016 lights FlashLight-1, opens
    /// PortalRoom3, turns the turret off, gives back forward and reverse,
    /// streams proceed3.osf, and shows Excellent and DodgeDone.
    func testScript017EndsTheDodgeOnTimerTwo() throws {
        let session = try startedDodgeSession()
        let done = session.level.findObjectName("DoneDodgeingGoal")
        let turret = session.level.findObjectName("DodgeTurrett")
        let roomThree = try XCTUnwrap(
            session.level.rooms.firstIndex { $0.name == "PortalRoom3" }
        )
        session.world.osirisCallEvent(
            done, .timer(id: 2, gameTime: session.world.gameTime),
            level: session.level
        )
        XCTAssertEqual(session.world.testTrainingMission?.script017Count, 1)
        XCTAssertNotEqual(
            session.world.objects[turret]!.ai!.flags
                & ObjectAIFrame.disabledFlag,
            0
        )
        XCTAssertEqual(session.world.rooms[roomThree].portalFlags, [0, 0])
        let light = session.level.findObjectName("FlashLight-1")
        XCTAssertEqual(
            session.world.objects[light]?.localLighting?.lightDistance, 50
        )
        let frame = session.update(
            at: session.world.gameTime.double + 1.25, input: .zero
        )
        XCTAssertEqual(presentationLog(frame), [
            "voice:proceed3.osf", "hud:\(trainingText("GoodJob"))",
            "hud:\(trainingText("LeaveDodge"))",
        ])
        XCTAssertTrue(frame.enabledPlayerControls.contains(.forward))
        XCTAssertTrue(frame.enabledPlayerControls.contains(.reverse))
    }

    /// Script 019 (TrainingMission.cpp:1888-1901): the first contact with
    /// DoneDodgeingGoal lights FlashLight-1, opens PortalRoom3, takes
    /// controls 62 away, streams proceed4.osf, and shows DodgeLeave. It has
    /// no test on the dodge counters.
    func testScript019RunsOnceOnDoneDodgeingGoalContact() throws {
        let session = try startedDodgeSession()
        session.collidePlayer(with: "DoneDodgeingGoal")
        session.collidePlayer(with: "DoneDodgeingGoal")
        XCTAssertEqual(session.world.testTrainingMission?.script019Count, 1)
        let frame = session.update(
            at: session.world.gameTime.double + 1.25, input: .zero
        )
        // The turret's fire sounds (AIFire) are left out.
        XCTAssertEqual(presentationLog(frame).filter { !$0.hasPrefix("sound:") }, [
            "voice:proceed4.osf", "hud:\(trainingText("KeepMovingOutofDodging"))",
        ])
        XCTAssertEqual(frame.enabledPlayerControls.rawValue & 62, 0)
    }

    // MARK: Scripts 021-026, the maneuver room

    /// Script 021 (TrainingMission.cpp:1947-1963): the contact with
    /// ManuverRoomCenter after Script 020 shows the control HUD, darkens
    /// FlashLight-1, closes PortalRoom3, gives heading only, sets level
    /// timer 4 (20 s), and shows Maneuver1, intro3.osf, and Maneuver2.
    /// Before Script 020 the contact does nothing.
    func testScript021StartsTheManeuverLessonAfterScript020() throws {
        let early = try maneuverReadySession(script020Count: 0)
        early.collidePlayer(with: "ManuverRoomCenter")
        XCTAssertEqual(early.world.testTrainingMission?.script021Count, 0)

        let session = try maneuverReadySession()
        let gameTime = session.world.gameTime
        session.collidePlayer(with: "ManuverRoomCenter")
        session.collidePlayer(with: "ManuverRoomCenter")
        XCTAssertEqual(session.world.testTrainingMission?.script021Count, 1)
        XCTAssertEqual(
            try XCTUnwrap(timer(session, .level, 4)).end, gameTime + 20,
            accuracy: 1e-4
        )
        let roomThree = try XCTUnwrap(
            session.level.rooms.firstIndex { $0.name == "PortalRoom3" }
        )
        XCTAssertEqual(session.world.rooms[roomThree].portalFlags, [1, 1])
        let frame = session.update(at: 0.1, input: .zero)
        XCTAssertEqual(presentationLog(frame), [
            "hud:\(trainingText("ManuverIntro"))", "voice:intro3.osf",
            "hud:\(trainingText("HeadingIntro"))",
        ])
        XCTAssertEqual(frame.enabledPlayerControls.rawValue, 768)
        XCTAssertTrue(frame.showsEnabledPlayerControls)
    }

    /// Level timer 4 runs Scripts 022, 024, and 023 in that order
    /// (TrainingMission.cpp:1515-1556): 022 gives pitch and a 12 s timer,
    /// 024 gives bank and a 15 s timer, and 023 gives all rotation, powers
    /// FollowBot1 on the rebel team, sets its 20 s timer 7, streams
    /// follow.osf, and gives it the FollowLoop1 goal (flags 9437444,
    /// priority 3).
    func testLevelTimerFourRunsScripts022Then024Then023() throws {
        let session = try maneuverReadySession()
        let followBot = session.level.findObjectName("FollowBot1")
        session.collidePlayer(with: "ManuverRoomCenter")
        var frame = advance(session, to: 20.1)
        XCTAssertEqual(counters(session), [1, 1, 0, 0])
        XCTAssertEqual(frame.enabledPlayerControls.rawValue, 192)
        frame = advance(session, to: 32.2)
        XCTAssertEqual(counters(session), [1, 1, 1, 0])
        XCTAssertEqual(frame.enabledPlayerControls.rawValue, 3_072)
        frame = advance(session, to: 47.3)
        XCTAssertEqual(counters(session), [1, 1, 1, 1])
        XCTAssertEqual(frame.enabledPlayerControls.rawValue, 4_032)
        XCTAssertTrue(presentationLog(frame).contains("voice:follow.osf"))
        let ai = try XCTUnwrap(session.world.objects[followBot]?.ai)
        XCTAssertEqual(ai.flags & ObjectAIFrame.disabledFlag, 0)
        XCTAssertEqual(ai.flags & ObjectAIFrame.teamMask, ObjectAIFrame.teamRebel)
        XCTAssertEqual(ai.goals[3].type, AIGoal.followPathType)
        XCTAssertEqual(ai.goals[3].pathID, 0)
        XCTAssertEqual(ai.goals[3].flags, 9_437_444)
        XCTAssertNotNil(timer(session, .object(followBot), 7))
    }

    /// Script 025 (TrainingMission.cpp:1363-1374) runs on every interval
    /// after Script 023: while FollowBot1 cannot see the player within its
    /// 90 degree cone (qObjCanSeeObj), timer 7 starts again at 20 s.
    /// Script 026 (TrainingMission.cpp:1990-2001) then runs on timer 7: it
    /// gives the weapons, sends FollowBot1 down GoToDie (flags 4352), and
    /// shows Excellent, Maneuver6, intro4.osf, and Maneuver7.
    func testScripts025And026EndTheFollowLesson() throws {
        let session = try maneuverReadySession()
        let followBot = session.level.findObjectName("FollowBot1")
        runToScript023(session)
        // Put the player behind FollowBot1, out of its cone.
        var bot = try XCTUnwrap(session.world.objects[followBot])
        let player = session.world.testPlayerObject
        var moved = player
        moved.position = bot.position - bot.orientation.forward * 30
        moved.location = bot.location
        session.world.objects[player.handle] = moved
        _ = session.update(at: 47.4, input: .zero)
        let restarted = try XCTUnwrap(timer(session, .object(followBot), 7))
        XCTAssertEqual(restarted.end, session.world.gameTime + 20, accuracy: 0.11)
        XCTAssertGreaterThan(
            session.world.testTrainingMission!.script025Count, 0
        )

        bot = try XCTUnwrap(session.world.objects[followBot])
        session.world.osirisCallEvent(
            followBot, .timer(id: 7, gameTime: session.world.gameTime),
            level: session.level
        )
        XCTAssertEqual(session.world.testTrainingMission?.script026Count, 1)
        XCTAssertEqual(activeFollowPath(session.world, followBot.rawValue), 1)
        let frame = session.update(at: 47.5, input: .zero)
        XCTAssertEqual(
            Array(presentationLog(frame).suffix(4)),
            [
                "hud:\(trainingText("GoodJob"))",
                "hud:\(trainingText("WeaponsEnabled"))", "voice:intro4.osf",
                "hud:\(trainingText("DestroyFollowbot"))",
            ]
        )
        XCTAssertEqual(frame.enabledPlayerControls.rawValue, 4_032 | 12_288)
    }

    // MARK: Save continuation

    /// A world saved with turret bolts in flight continues like the
    /// uninterrupted world (architecture.md section 7).
    func testSaveMidDodgeContinuesLikeTheUninterruptedWorld() throws {
        let original = try startedDodgeSession()
        var timestamp = original.world.gameTime.double + 1.2
        for _ in 0..<200 {
            timestamp += 0.05
            _ = original.update(at: timestamp, input: .zero)
            if original.world.objects.contains(where: { $0.type == .weapon }) {
                break
            }
        }
        XCTAssertTrue(
            original.world.objects.contains { $0.type == .weapon }
        )
        try assertContinuation(original, from: timestamp, frames: 60)
    }

    /// A world saved while FollowBot1 follows FollowLoop1 continues like
    /// the uninterrupted world.
    func testSaveMidFollowContinuesLikeTheUninterruptedWorld() throws {
        let original = try maneuverReadySession()
        runToScript023(original)
        _ = advance(original, to: 50)
        let followBot = original.level.findObjectName("FollowBot1")
        XCTAssertEqual(activeFollowPath(original.world, followBot.rawValue), 0)
        try assertContinuation(original, from: 50, frames: 60)
    }

    // MARK: Helpers

    private func assertContinuation(
        _ original: GameSession, from timestamp: Double, frames: Int
    ) throws {
        let saved = try JSONDecoder().decode(
            GameWorld.self, from: JSONEncoder().encode(original.world)
        )
        let restored = try GameSession(
            level: original.level, world: saved, resumedAtTimestamp: timestamp
        )
        XCTAssertEqual(restored.world, original.world)
        for index in 1...frames {
            let at = timestamp + Double(index) * 0.05
            let live = original.update(at: at, input: .zero)
            let again = restored.update(at: at, input: .zero)
            XCTAssertEqual(presentationLog(again), presentationLog(live))
        }
        XCTAssertEqual(restored.world, original.world)
    }

    /// Script 021 by contact, then Scripts 022, 024, and 023 on level
    /// timer 4.
    private func runToScript023(_ session: GameSession) {
        session.collidePlayer(with: "ManuverRoomCenter")
        for timestamp in [20.1, 32.2, 47.3] {
            _ = advance(session, to: timestamp)
        }
        XCTAssertEqual(counters(session), [1, 1, 1, 1])
    }

    /// Scripts 021, 022, 024, and 023's counters.
    private func counters(_ session: GameSession) -> [Int] {
        let state = session.world.testTrainingMission!
        return [
            state.script021Count, state.script022Count,
            state.script024Count, state.script023Count,
        ]
    }

    private func advance(
        _ session: GameSession, to timestamp: Double
    ) -> PlayerSimulationFrame {
        var frame = session.update(at: timestamp - 0.1, input: .zero)
        frame = session.update(at: timestamp, input: .zero)
        return frame
    }

    private func timer(
        _ session: GameSession, _ owner: OsirisTimer.Owner, _ id: Int32
    ) -> OsirisTimer? {
        session.world.osirisTimers.entries.first {
            $0.isUsed && $0.owner == owner && $0.id == id
        }
    }

    /// The dodge fixture after Script 033 and Script 016.
    private func startedDodgeSession(
        seed: UInt32? = nil
    ) throws -> GameSession {
        let session = seed.map {
            GameSession(
                level: makeTrainingDodgeAttemptLevel(),
                presentationReadyTimestamp: 0, authoritativeRandomSeed: $0
            )
        } ?? GameSession(
            level: makeTrainingDodgeAttemptLevel(),
            presentationReadyTimestamp: 0
        )
        session.parkTrainingGoals()
        for frameIndex in 1...11 {
            _ = session.update(at: Double(frameIndex) * 0.1, input: .zero)
        }
        session.touch("StartDodge", at: 1.2)
        var timestamp = 1.2
        for _ in 0..<150
        where session.world.testTrainingMission?.script016Count == 0 {
            timestamp += 0.1
            _ = session.update(at: timestamp, input: .zero)
        }
        XCTAssertEqual(session.world.testTrainingMission?.script016Count, 1)
        // The pilot waits in the dodge room, between StartDodge and the
        // turret.
        var player = session.world.testPlayerObject
        player.location = .room(35)
        player.position = Vector3(x: 2_061.8, y: -740, z: 2_300)
        session.world.objects[player.handle] = player
        return session
    }
}

private extension Float {
    var double: Double { Double(self) }
}
