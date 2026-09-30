import XCTest

/// The retail text of the Training messages the Guide-Bot scripts show
/// (TrainingMission.msg).
let fixtureGuideBotScriptMessages = [
    LevelScriptMessage(
        name: "GBIntro",
        text: "Your ship is equipped with a utility robot called a Guidebot.  Release him now with F4."
    ),
    LevelScriptMessage(
        name: "GetCameraMonitor",
        text: "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to."
    ),
]

/// `level` with the Training module and the Guide-Bot script messages,
/// and the room with this source index named as the scripts look it up.
func addingGuideBotLessonScripting(
    _ level: Level,
    roomSourceIndex: Int,
    roomName: String
) -> Level {
    var level = level
    let room = level.rooms.firstIndex { $0.sourceIndex == roomSourceIndex }!
    level.rooms[room].name = roomName
    return addingTrainingMissionScripting(
        level,
        messages: fixtureTrainingMessages + fixtureGuideBotScriptMessages
    )
}

/// The gallery level with the Training module and the translated
/// Guide-Bot: the barrier room is PortalRoom4 (Room_indexes[3]) and
/// FlashLight-2 is Object_handles[1], as in the retail level.
func makeScriptedTrainingGalleryLevel() -> Level {
    let level = makeTrainingRobotGuidebotLevel()
    return withTrainingGuideBot(addingGuideBotLessonScripting(
        level,
        roomSourceIndex: level.trainingGalleryBarrier!.barrierRoomSourceIndex,
        roomName: "PortalRoom4"
    ))
}

/// `level` (a Camera Monitor level) with the Training module: the return
/// barrier room is PortalRoom5 (Room_indexes[4]) and FlashLight-3 is
/// Object_handles[2]. With `guideBot`, the Guide-Bot is the translated one.
func scriptingTrainingCameraMonitorLevel(
    _ level: Level,
    guideBot: Bool = true
) -> Level {
    let scripted = addingGuideBotLessonScripting(
        level,
        roomSourceIndex: level.trainingCameraMonitorChain!.returnToShip!
            .barrierRoomSourceIndex,
        roomName: "PortalRoom5"
    )
    return guideBot ? withTrainingGuideBot(scripted) : scripted
}

/// Scripts 032 and 060 of TrainingMission.cpp as the translated level
/// module runs them: Portal2's trigger EVT_COLLIDE, and the level
/// EVT_INTERVAL check of the Guide-Bot (qGetBuddyObj). Script 058 is in
/// TrainingCameraAndReturnTests.
final class TrainingGuideBotScriptTests: XCTestCase {
    private func session(_ level: Level) throws -> GameSession {
        try level.validate()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        // Script 002's first HUD message has run.
        session.world.trainingMission.script002Count = 1
        return session
    }

    /// Flies forward until Script 032 runs, and returns that frame.
    private func flyThroughPortal2(
        _ session: GameSession,
        timestamp: inout Double
    ) throws -> PlayerSimulationFrame {
        session.parkTrainingGoals()
        for _ in 1...40 {
            timestamp += 0.1
            let frame = session.update(at: timestamp, input: .init(forward: 1))
            if session.world.testTrainingMission?.script032Count == 1 {
                return frame
            }
        }
        XCTFail("The player did not cross Portal2")
        return session.update(at: timestamp + 0.1, input: .zero)
    }

    /// Script 032 (TrainingMission.cpp:2328-2341): Portal2's trigger hears
    /// EVT_COLLIDE when the player crosses it, and the script plays
    /// GuideBotA.osf, turns FlashLight-2 off, closes PortalRoom4's portals
    /// 1 and 0, shows GoodJob and GBIntro, and turns every control off,
    /// once. The one-shot trigger dies (trigger.cpp:250).
    func testPortal2TriggerRunsScript032Once() throws {
        let level = makeScriptedTrainingGalleryLevel()
        let simulation = try session(level)
        simulation.applyTrainingScript036Outcome()
        XCTAssertEqual(simulation.galleryMarkerLightDistance, 50)
        var timestamp = 0.0
        let crossed = try flyThroughPortal2(simulation, timestamp: &timestamp)
        XCTAssertEqual(presentationLog(crossed), [
            "voice:guidebota.osf",
            "hud:Excellent!",
            "hud:\(fixtureGuideBotScriptMessages[0].text)",
        ])
        XCTAssertEqual(simulation.galleryMarkerLightDistance, 0)
        assertTrainingGalleryBarrier(
            level: simulation.runtimeLevel,
            rendersFaces: true
        )
        XCTAssertEqual(simulation.world.playerControllerBitflags.rawValue, 0)
        let portal2 = try XCTUnwrap(level.triggers.firstIndex {
            $0.name == "Portal2"
        })
        XCTAssertNotEqual(
            simulation.world.triggerFlags[portal2] & TriggerFlag.dead,
            0
        )

        // The saved world keeps the dead trigger and the counter.
        let saved = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(simulation.world)
        )
        let restored = try GameSession(
            level: level,
            world: saved,
            resumedAtTimestamp: 100
        )
        XCTAssertEqual(restored.world.triggerFlags, simulation.world.triggerFlags)
        XCTAssertEqual(restored.world.testTrainingMission?.script032Count, 1)
        let later = simulation.update(at: timestamp + 0.1, input: .zero)
        XCTAssertTrue(presentationLog(later).isEmpty)
        XCTAssertEqual(later.enabledPlayerControls.rawValue, 0)
    }

    /// Script 060 (TrainingMission.cpp:1431-1441): in the level
    /// EVT_INTERVAL of the frame after the buddy menu's "Exit ship", the
    /// Guide-Bot is a robot after Script 032, so the script plays
    /// GuideBotB.osf, turns every control on, and shows GetCameraMonitor,
    /// once.
    func testScript060RunsOnceTheGuideBotIsOutAfterScript032() throws {
        let simulation = try session(makeScriptedTrainingGalleryLevel())
        simulation.applyTrainingScript036Outcome()
        var timestamp = 0.0
        _ = try flyThroughPortal2(simulation, timestamp: &timestamp)
        XCTAssertEqual(simulation.world.testTrainingMission?.script060Count, 0)

        // F4, then "Exit ship" (buddymenu.cpp:437).
        timestamp += 0.1
        _ = simulation.update(at: timestamp, input: .init(opensBuddyMenu: true))
        XCTAssertTrue(simulation.buddyMenuIsRequested)
        let menu = try XCTUnwrap(simulation.openBuddyMenu(at: timestamp))
        XCTAssertEqual(menu.commands.first?.id, GuideBotScript.exitShipCommand)
        simulation.selectBuddyMenuItem(0, at: timestamp)
        timestamp += 0.1
        let released = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(soundNames([released]), ["GBExpulsionA"])
        XCTAssertEqual(
            presentationLog(released).filter { !$0.hasPrefix("sound:") },
            [
                "voice:guidebotb.osf",
                "hud:\(fixtureGuideBotScriptMessages[1].text)",
            ]
        )
        XCTAssertEqual(released.enabledPlayerControls, .all)
        XCTAssertEqual(simulation.world.testTrainingMission?.script060Count, 1)
        timestamp += 0.1
        let later = simulation.update(at: timestamp, input: .zero)
        XCTAssertTrue(presentationLog(later).isEmpty)
    }

    /// Script 060 needs Script 032 (TrainingMission.cpp:1433): a Guide-Bot
    /// released before the gallery changes no control.
    func testScript060WaitsForScript032() throws {
        let simulation = try session(makeScriptedTrainingGalleryLevel())
        XCTAssertTrue(simulation.selectTestBuddyCommand(
            GuideBotScript.exitShipCommand
        ))
        var timestamp = 0.0
        let frames = simulation.runFrames(3, from: &timestamp)
        XCTAssertEqual(
            simulation.world.objectType(simulation.world.buddyHandle),
            .robot
        )
        XCTAssertFalse(presentationLog(frames[0]).contains("voice:guidebotb.osf"))
        XCTAssertEqual(simulation.world.testTrainingMission?.script060Count, 0)
    }

    /// Real content, opt-in (REVIVAL_TRAINING_PACKAGE, engineering.md
    /// section 2): after Script 036 opens PortalRoom4, the player flies
    /// through the retail Portal2 trigger face (PortalRoom4's portal 1),
    /// Script 032 runs from its EVT_COLLIDE, and the buddy menu's "Exit
    /// ship" then releases the Guide-Bot, so Script 060 turns every
    /// control on.
    func testImportedTrainingPackagePortal2AndBuddyMenuRelease() throws {
        guard let path = ProcessInfo.processInfo.environment[
            "REVIVAL_TRAINING_PACKAGE"
        ] else {
            throw XCTSkip("set REVIVAL_TRAINING_PACKAGE to a training.revival")
        }
        let level = try loadCanonicalLevel(from: URL(fileURLWithPath: path))
        let simulation = GameSession(level: level, presentationReadyTimestamp: 0)
        simulation.world.trainingMission.script002Count = 1
        // DestroyBot2's death runs Script 036 (TrainingMission.cpp:2040),
        // which opens PortalRoom4, where Portal2 is.
        simulation.world.osirisCallEvent(
            level.findObjectName("DestroyBot2"),
            .destroy(isDying: true),
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
            simulation.world.objectType(simulation.world.buddyHandle),
            .robot
        )
        XCTAssertEqual(simulation.world.testTrainingMission?.script060Count, 1)
        XCTAssertEqual(simulation.world.playerControllerBitflags, .all)
    }
}
