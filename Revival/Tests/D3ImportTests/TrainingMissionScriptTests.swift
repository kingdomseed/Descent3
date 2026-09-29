import XCTest

// The Training level module (scripts/TrainingMission.cpp) driven through
// the Osiris runtime: EVT_LEVELSTART (Script 000, :1457) and the level
// EVT_TIMER (Script 002, :1501).
final class TrainingMissionScriptTests: XCTestCase {
    /// Script 000 sets a 1 s level timer at Gametime 0. With 0.1 s frames the
    /// timer is processed with the pre-update Gametime, so it fires on the
    /// 11th frame (Gametime 1.0). Script 002 then shows "Welcome", streams
    /// welcome.osf, and shows "GoForward", in that order
    /// (TrainingMission.cpp:1506-1508).
    func testLevelTimerFiresOnEleventhFrameWithWelcomeVoiceAndTwoMessages() {
        let session = GameSession(
            level: makeTrainingScript003Level(),
            presentationReadyTimestamp: 0
        )
        for frameIndex in 1...10 {
            let frame = session.update(
                at: Double(frameIndex) * 0.1,
                input: .zero
            )
            XCTAssertTrue(
                frame.trainingOpeningFeedback.isEmpty,
                "frame \(frameIndex)"
            )
            XCTAssertEqual(frame.enabledPlayerControls, [.forward])
            XCTAssertTrue(frame.showsEnabledPlayerControls)
        }
        XCTAssertEqual(session.world.testTrainingMission?.script002Count, 0)

        let eleventh = session.update(at: 1.1, input: .zero)
        XCTAssertEqual(eleventh.systemsGameTime, 1, accuracy: 1e-6)
        XCTAssertEqual(
            eleventh.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Welcome to the Descent 3 Training session."],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: [],
                    voiceSourceName: "welcome.osf",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: ["Move forward until you stop."],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
            ]
        )
        XCTAssertEqual(session.world.testTrainingMission?.script002Count, 1)
        XCTAssertFalse(
            session.world.osirisTimers.entries.contains(where: \.isUsed)
        )
        XCTAssertTrue(session.world.presentationRequests.isEmpty)
        for frameIndex in 12...20 {
            XCTAssertTrue(
                session.update(at: Double(frameIndex) * 0.1, input: .zero)
                    .trainingOpeningFeedback.isEmpty
            )
        }
    }

    /// Script 000 (TrainingMission.cpp:1461-1499), observed on the world at
    /// level start.
    func testLevelStartRunsScript000() throws {
        var level = makeSliceSixObjectRenderLevel()
        // Give the fixture's objects the names Script 000 looks up.
        let names: [UInt32: String] = [
            12_301: "ForwardGoal",   // Object_handles[21]: hidden
            12_300: "FlashLight-1",  // Object_handles[0]: lighting
            12_299: "DestroyBot2",   // Object_handles[15]: ghosted
        ]
        level.objects = level.objects.map { object in
            names[object.handle].map { renamed(object, $0) } ?? object
        }
        let unscripted = GameWorld(level: level)
        let world = GameWorld(level: addingTrainingMissionScripting(level))

        XCTAssertEqual(world.testTrainingMission?.script000Count, 1)
        XCTAssertEqual(world.testTrainingMission?.script002Count, 0)
        XCTAssertEqual(world.testTrainingMission?.dallas, .dfInit())
        XCTAssertEqual(world.playerControllerBitflags, [.forward])
        XCTAssertTrue(world.hudShowControls)
        // aObjMakeInvuln(player, 0): cleared by the first DoPlayerFrame.
        XCTAssertEqual(world.playerInvulnerableTime, 0)

        let light = try XCTUnwrap(world.objects[ObjectHandle(12_300)])
        XCTAssertEqual(
            light.localLighting,
            ObjectLocalLighting(
                lightDistance: 0,
                color: Vector3(x: 0.2, y: 1, z: 0.2)
            )
        )
        XCTAssertEqual(world.objects[ObjectHandle(12_301)]?.renderType, ObjectRenderType.none)
        let ghost = try XCTUnwrap(world.objects[ObjectHandle(12_299)])
        let original = try XCTUnwrap(unscripted.objects[ObjectHandle(12_299)])
        XCTAssertEqual(ghost.type, .dummy)
        XCTAssertEqual(ghost.dummyType, original.type)
        // A ghost keeps its custom script (DestroyBot2: 0x00d).
        XCTAssertEqual(ghost.scripts, ObjectScripts(custom: 0x00d, level: nil))

        // aSetLevelTimer(1.0, 0).
        let timer = try XCTUnwrap(
            world.osirisTimers.entries.first(where: \.isUsed)
        )
        XCTAssertEqual(timer.owner, .level)
        XCTAssertEqual(timer.id, 0)
        XCTAssertEqual(timer.end, 1)
        XCTAssertEqual(timer.nextSignal, 1)
        XCTAssertEqual(world.osirisTimers.entries.count(where: \.isUsed), 1)

        // Unghosting restores the page type.
        var unghosted = world
        unghosted.aObjGhostSet(0, ObjectHandle(12_299))
        XCTAssertEqual(unghosted.objects[ObjectHandle(12_299)]?.type, original.type)
        XCTAssertNil(unghosted.objects[ObjectHandle(12_299)]?.dummyType)
    }

    /// Real content, opt-in: REVIVAL_TRAINING_PACKAGE names an imported
    /// `training.revival` package (engineering.md section 2). The imported
    /// level starts the Training module, and the 1 s level timer shows the
    /// retail Welcome and GoForward messages around welcome.osf.
    func testImportedTrainingPackageRunsLevelStartThroughFirstTimer() throws {
        guard let path = ProcessInfo.processInfo.environment[
            "REVIVAL_TRAINING_PACKAGE"
        ] else {
            throw XCTSkip("set REVIVAL_TRAINING_PACKAGE to a training.revival")
        }
        let level = try loadCanonicalLevel(from: URL(fileURLWithPath: path))
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
                session.world.objects[handle]?.localLighting?.lightDistance,
                0,
                name
            )
        }
        for name in ["DestroyBot1", "DestroyBot2"] {
            XCTAssertEqual(
                session.world.objects[level.findObjectName(name)]?.type,
                .dummy,
                name
            )
        }
        var feedback: [TrainingOpeningFeedback] = []
        for frameIndex in 1...10 {
            feedback += session.update(
                at: Double(frameIndex) * 0.1,
                input: .zero
            ).trainingOpeningFeedback
        }
        XCTAssertTrue(feedback.isEmpty)
        let eleventh = session.update(at: 1.1, input: .zero)
        XCTAssertEqual(
            eleventh.trainingOpeningFeedback.map(\.hudMessages),
            [[welcome], [], [goForward]]
        )
        XCTAssertEqual(
            eleventh.trainingOpeningFeedback.map(\.voiceSourceName),
            ["", "welcome.osf", ""]
        )
    }

    /// A missing message name shows NO_MESSAGE_STRING
    /// (TrainingMission.cpp:822).
    func testMissingMessageShowsNoMessageString() {
        let session = GameSession(
            level: addingTrainingMissionScripting(
                makeSliceSixObjectRenderLevel(),
                messages: []
            ),
            presentationReadyTimestamp: 0
        )
        var feedback: [TrainingOpeningFeedback] = []
        for frameIndex in 1...11 {
            feedback += session.update(
                at: Double(frameIndex) * 0.1,
                input: .zero
            ).trainingOpeningFeedback
        }
        XCTAssertEqual(
            feedback.map(\.hudMessages),
            [["*Message Not Found*"], [], ["*Message Not Found*"]]
        )
    }
}
