import XCTest

// The Training level module (scripts/TrainingMission.cpp) driven through
// the Osiris runtime: EVT_LEVELSTART (Script 000, :1457), the level
// EVT_TIMER (Script 002, :1501), the level EVT_INTERVAL (Script 030, :1385),
// and the goal powerups' EVT_COLLIDE (Scripts 001-015 and 033, :1633-1867),
// which the player's physics move sends (collide.cpp:2493-2496).
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
                frame.presentationFeedback.isEmpty,
                "frame \(frameIndex)"
            )
            XCTAssertEqual(frame.enabledPlayerControls, [.forward])
            XCTAssertTrue(frame.showsEnabledPlayerControls)
        }
        XCTAssertEqual(session.world.testTrainingMission?.script002Count, 0)

        let eleventh = session.update(at: 1.1, input: .zero)
        XCTAssertEqual(eleventh.systemsGameTime, 1, accuracy: 1e-6)
        XCTAssertEqual(
            eleventh.presentationFeedback,
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
                    .presentationFeedback.isEmpty
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
    /// level starts the Training module, the 1 s level timer shows the
    /// retail Welcome and GoForward messages around welcome.osf, flying
    /// forward into ForwardGoal runs Script 001, and reversing into
    /// StartGoal runs Script 003.
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
        var feedback: [PresentationFeedback] = []
        for frameIndex in 1...10 {
            feedback += session.update(
                at: Double(frameIndex) * 0.1,
                input: .zero
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
        let goBackwards = try XCTUnwrap(
            scripting.message(named: "GoBackwards")
        )
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
            log,
            ["hud:\(goodJob)", "voice:return1.osf", "hud:\(goBackwards)"]
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
        var feedback: [PresentationFeedback] = []
        for frameIndex in 1...11 {
            feedback += session.update(
                at: Double(frameIndex) * 0.1,
                input: .zero
            ).presentationFeedback
        }
        XCTAssertEqual(
            feedback.map(\.hudMessages),
            [["*Message Not Found*"], [], ["*Message Not Found*"]]
        )
    }

    /// A session past Script 002 (the 11th frame), with every goal parked.
    private func openingSession(
        _ level: Level = makeTrainingScript003Level()
    ) -> GameSession {
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        session.parkTrainingGoals()
        for frameIndex in 1...11 {
            _ = session.update(at: Double(frameIndex) * 0.1, input: .zero)
        }
        return session
    }

    /// Script 001 (TrainingMission.cpp:1636-1645): the first ForwardGoal
    /// contact shows GoodJob, streams return1.osf, shows GoBackwards, and
    /// swaps forward for reverse. A later contact does nothing, because
    /// ScriptActionCtr_001 is 1 and Script 008 needs Script 007.
    func testForwardGoalContactRunsScript001Once() {
        let session = openingSession()
        XCTAssertEqual(session.world.playerControllerBitflags, [.forward])

        let frame = session.touch("ForwardGoal", at: 1.2)
        XCTAssertEqual(presentationLog(frame), [
            "hud:Excellent!",
            "voice:return1.osf",
            "hud:\(trainingText("GoBackwards"))",
        ])
        XCTAssertEqual(frame.enabledPlayerControls, [.reverse])
        XCTAssertEqual(session.world.testTrainingMission?.script001Count, 1)

        XCTAssertEqual(presentationLog(session.touch("ForwardGoal", at: 1.3)), [])
        XCTAssertEqual(session.world.testTrainingMission?.script001Count, 1)
        XCTAssertEqual(session.world.testTrainingMission?.script008Count, 0)
    }

    /// Scripts 001 and 003-013 through the goal contacts, in the order the
    /// lessons ask for (TrainingMission.cpp:1633-1809). Each contact shows
    /// its messages and sounds in source order and swaps the enabled
    /// controls. Script 013 opens PortalRoom1's two portals, on both sides.
    func testOpeningAndReturnLessonsRunInSourceOrder() throws {
        let session = openingSession()
        let steps: [(String, [String], PlayerControlMask)] = [
            ("ForwardGoal", [
                "hud:Excellent!", "voice:return1.osf",
                "hud:\(trainingText("GoBackwards"))",
            ], [.reverse]),                                       // 001
            ("StartGoal", [
                "hud:\(trainingText("GoLeft"))", "voice:left1.osf",
            ], [.left]),                                          // 003
            ("LeftGoal", [
                "hud:Excellent!", "voice:return2.osf",
                "hud:\(trainingText("GoRight"))",
            ], [.right]),                                         // 004
            ("StartGoal", [
                "hud:Excellent!", "voice:up1.osf",
                "hud:\(trainingText("GoUp"))",
            ], [.up]),                                            // 005
            ("UpGoal", [
                "hud:Excellent!", "hud:\(trainingText("GoDown"))",
                "voice:return3.osf",
            ], [.down]),                                          // 006
            ("StartGoal", [
                "hud:Excellent!", "hud:\(trainingText("Repeat"))",
                "hud:\(trainingText("GoForward"))", "voice:repeat.osf",
            ], [.forward]),                                       // 007
            ("ForwardGoal", [
                "sound:MenuBeepEnter", "hud:\(trainingText("GoBackwards"))",
            ], [.reverse]),                                       // 008
            ("StartGoal", [
                "voice:lright.osf", "hud:\(trainingText("GoLeft"))",
            ], [.left]),                                          // 009
            ("LeftGoal", [
                "sound:MenuBeepEnter", "hud:\(trainingText("GoRight"))",
            ], [.right]),                                         // 010
            ("StartGoal", [
                "voice:udown.osf", "hud:\(trainingText("GoUp"))",
            ], [.up]),                                            // 011
            ("UpGoal", [
                "sound:MenuBeepEnter", "hud:\(trainingText("GoDown"))",
            ], [.down]),                                          // 012
            ("StartGoal", [
                "voice:proceed1.osf",
                "hud:\(trainingText("ContinueToCourse"))",
            ], [.down]),                                          // 013
        ]
        let portalRoom = try XCTUnwrap(
            session.level.rooms.firstIndex { $0.name == "PortalRoom1" }
        )
        // MakeBOA marks this synthetic level's portals PF_TOO_SMALL_FOR_ROBOT
        // (find_small_portals, BOA.cpp:1943); the check is on the others.
        let smallFlag: UInt32 = 4
        XCTAssertEqual(
            session.world.rooms[portalRoom].portalFlags.map { $0 & ~smallFlag },
            [1, 1]
        )
        var timestamp = 1.1
        for (index, step) in steps.enumerated() {
            timestamp += 0.1
            let frame = session.touch(step.0, at: timestamp)
            XCTAssertEqual(presentationLog(frame), step.1, "step \(index)")
            XCTAssertEqual(frame.enabledPlayerControls, step.2, "step \(index)")
        }
        let state = try XCTUnwrap(session.world.testTrainingMission)
        XCTAssertEqual(
            [
                state.script001Count, state.script003Count,
                state.script004Count, state.script005Count,
                state.script006Count, state.script007Count,
                state.script008Count, state.script009Count,
                state.script010Count, state.script011Count,
                state.script012Count, state.script013Count,
            ],
            Array(repeating: 1, count: 12)
        )
        // aPortalRenderSet(0, 0|1, Room_indexes[0], 1) clears
        // PF_RENDER_FACES on both sides (multisafe.cpp:1447).
        XCTAssertEqual(
            session.world.rooms[portalRoom].portalFlags.map { $0 & ~smallFlag },
            [0, 0]
        )
        for portal in session.level.rooms[portalRoom].portals {
            let connected = try XCTUnwrap(session.level.rooms.firstIndex {
                $0.sourceIndex == portal.connectedRoom
            })
            XCTAssertEqual(
                session.world.rooms[connected]
                    .portalFlags[portal.connectedPortal] & 1,
                0
            )
        }
        // Nothing repeats.
        for (index, name) in ["StartGoal", "ForwardGoal", "LeftGoal", "UpGoal"]
            .enumerated() {
            XCTAssertEqual(
                presentationLog(
                    session.touch(name, at: timestamp + Double(index + 1) * 0.1)
                ),
                [],
                name
            )
        }
    }

    /// Scripts 014 and 015 (TrainingMission.cpp:1811-1849): StartCourse
    /// closes PortalRoom1's portal 1 and adds the six slide controls;
    /// FinishCourse leaves only down and opens PortalRoom2.
    func testCourseStartAndFinishScripts014And015() throws {
        let session = openingSession(makeTrainingScript015Level())
        let roomOne = try XCTUnwrap(
            session.level.rooms.firstIndex { $0.name == "PortalRoom1" }
        )
        let roomTwo = try XCTUnwrap(
            session.level.rooms.firstIndex { $0.name == "PortalRoom2" }
        )
        session.world.rooms[roomOne].portalFlags = [0, 0]

        let start = session.touch("StartCourse", at: 1.2)
        XCTAssertEqual(presentationLog(start), [
            "hud:\(trainingText("CourseInstructions"))",
            "voice:intro1.osf",
        ])
        XCTAssertEqual(start.enabledPlayerControls.rawValue, 63)
        XCTAssertEqual(session.world.rooms[roomOne].portalFlags, [0, 1])
        XCTAssertEqual(session.world.testTrainingMission?.script014Count, 1)

        XCTAssertEqual(session.world.rooms[roomTwo].portalFlags, [1, 1])
        let finish = session.touch("FinishCourse", at: 1.3)
        XCTAssertEqual(presentationLog(finish), [
            "hud:Excellent!", "voice:proceed2.osf",
            "hud:\(trainingText("ContinueToCourse"))",
        ])
        XCTAssertEqual(finish.enabledPlayerControls, [.down])
        XCTAssertEqual(session.world.rooms[roomTwo].portalFlags, [0, 0])
        XCTAssertEqual(session.world.testTrainingMission?.script015Count, 1)
        XCTAssertEqual(presentationLog(session.touch("StartCourse", at: 1.4)), [])
        XCTAssertEqual(presentationLog(session.touch("FinishCourse", at: 1.5)), [])
    }

    /// Script 030 (TrainingMission.cpp:1385-1392) runs in the level
    /// EVT_INTERVAL (GameLoop.cpp:3013) once Script 014 has run: shields
    /// under 50 become 50 in the same frame, and each restore counts.
    func testScript030KeepsPlayerShieldsAtFiftyAfterScript014() {
        let session = openingSession()
        session.world.shields = 30
        XCTAssertEqual(session.update(at: 1.2, input: .zero).shields, 30)
        XCTAssertEqual(session.world.testTrainingMission?.script030Count, 0)

        XCTAssertEqual(session.touch("StartCourse", at: 1.3).shields, 50)
        XCTAssertEqual(session.world.testTrainingMission?.script030Count, 1)
        XCTAssertEqual(session.update(at: 1.4, input: .zero).shields, 50)
        XCTAssertEqual(session.world.testTrainingMission?.script030Count, 1)

        session.world.shields = 49.5
        XCTAssertEqual(session.update(at: 1.5, input: .zero).shields, 50)
        XCTAssertEqual(session.world.testTrainingMission?.script030Count, 2)
    }

    /// Script 033 (TrainingMission.cpp:1854-1862): StartDodge swaps forward
    /// and reverse for the four slides, closes PortalRoom2, streams
    /// intro2.osf, shows DodgeIntro, and sets a 10 s timer 8 on itself.
    func testStartDodgeContactRunsScript033AndSetsItsObjectTimer() throws {
        let session = openingSession(makeTrainingDodgeAttemptLevel())
        let roomTwo = try XCTUnwrap(
            session.level.rooms.firstIndex { $0.name == "PortalRoom2" }
        )
        session.world.rooms[roomTwo].portalFlags = [0, 0]
        let startDodge = session.level.findObjectName("StartDodge")
        let gameTime = session.world.gameTime

        let frame = session.touch("StartDodge", at: 1.2)
        XCTAssertEqual(presentationLog(frame), [
            "voice:intro2.osf", "hud:\(trainingText("DodgeIntro"))",
        ])
        XCTAssertEqual(frame.enabledPlayerControls, [.left, .right, .up, .down])
        XCTAssertEqual(session.world.rooms[roomTwo].portalFlags, [1, 1])
        XCTAssertEqual(session.world.testTrainingMission?.script033Count, 1)
        let timer = try XCTUnwrap(
            session.world.osirisTimers.entries.first {
                $0.isUsed && $0.owner == .object(startDodge)
            }
        )
        XCTAssertEqual(timer.id, 8)
        XCTAssertEqual(timer.end, gameTime + 10, accuracy: 1e-5)
        XCTAssertFalse(timer.repeats)
        XCTAssertNil(timer.detonator)
        XCTAssertEqual(presentationLog(session.touch("StartDodge", at: 1.3)), [])
    }

    /// A world saved mid-lesson (after Script 004), loaded, and advanced
    /// with the same contacts matches the uninterrupted world
    /// (architecture.md section 7).
    func testSaveMidLessonContinuesLikeTheUninterruptedWorld() throws {
        let original = openingSession()
        original.touch("ForwardGoal", at: 1.2)
        original.touch("StartGoal", at: 1.3)
        original.touch("LeftGoal", at: 1.4)
        let saved = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(original.world)
        )
        let restored = try GameSession(
            level: original.level,
            world: saved,
            resumedAtTimestamp: 1.4
        )
        XCTAssertEqual(restored.world, original.world)
        for (index, name) in ["StartGoal", "UpGoal", "StartGoal"].enumerated() {
            let timestamp = 1.5 + Double(index) * 0.1
            let expected = original.touch(name, at: timestamp)
            let actual = restored.touch(name, at: timestamp)
            XCTAssertEqual(actual, expected, name)
            XCTAssertEqual(restored.world, original.world, name)
        }
        XCTAssertEqual(restored.world.testTrainingMission?.script007Count, 1)
    }

    /// A goal whose room the move does not reach gets no EVT_COLLIDE: fvi
    /// checks the objects of the rooms it visits
    /// (findintersection.cpp:3325).
    func testGoalInAnUnreachedRoomIsNotHit() throws {
        var level = makeTrainingScript003Level()
        let playerRoom = try XCTUnwrap(level.rooms.first { $0.sourceIndex == 1 })
        level.rooms.append(LevelRoom(
            sourceIndex: 99,
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                LevelFace(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: $0.lightmapInfoIndex,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: []
        ))
        let session = openingSession(level)
        let forwardGoal = level.findObjectName("ForwardGoal")
        var goal = try XCTUnwrap(session.world.objects[forwardGoal])
        goal.location = .room(99)
        goal.position = session.world.playerPosition + Vector3(x: 0, y: 0, z: 3)
        session.world.objects[forwardGoal] = goal
        session.world.velocity = Vector3(x: 0, y: 0, z: 30)
        let frame = session.update(at: 1.2, input: .zero)
        XCTAssertEqual(presentationLog(frame), [])
        XCTAssertEqual(frame.enabledPlayerControls, [.forward])
    }

    /// Two goals on one move are hit nearest first, each once
    /// (physics.cpp:1535-1560). LeftGoal (Script 004) is nearer than
    /// ForwardGoal (Script 001), so its messages come first; swapped, they
    /// come second.
    func testGoalsOnOneMoveAreHitNearestFirst() {
        for leftIsNearer in [true, false] {
            let session = openingSession()
            let player = session.world.testPlayerObject
            for (name, distance) in [
                ("LeftGoal", leftIsNearer ? 2 : 4),
                ("ForwardGoal", leftIsNearer ? 4 : 2),
            ] as [(String, Float)] {
                let handle = session.level.findObjectName(name)
                var goal = session.world.objects[handle]!
                goal.location = player.location
                // Off the path to one side, so the start is outside both
                // spheres and the entry distances differ.
                goal.position = player.position
                    + Vector3(x: 0, y: 0, z: 20 + distance)
                session.world.objects[handle] = goal
            }
            session.world.velocity = Vector3(x: 0, y: 0, z: 150)
            let log = presentationLog(session.update(at: 1.2, input: .zero))
            let script004 = [
                "hud:Excellent!", "voice:return2.osf",
                "hud:\(trainingText("GoRight"))",
            ]
            let script001 = [
                "hud:Excellent!", "voice:return1.osf",
                "hud:\(trainingText("GoBackwards"))",
            ]
            XCTAssertEqual(
                log,
                leftIsNearer ? script004 + script001 : script001 + script004
            )
        }
    }

    // MARK: Independent conditions (each script block is its own `if`)

    /// Script 006 (TrainingMission.cpp:1781-1788) needs no earlier lesson:
    /// the first UpGoal contact runs it.
    func testScript006RunsWithoutEarlierLessons() {
        let session = openingSession()
        let frame = session.touch("UpGoal", at: 1.2)
        XCTAssertEqual(presentationLog(frame), [
            "hud:Excellent!", "hud:\(trainingText("GoDown"))",
            "voice:return3.osf",
        ])
        XCTAssertEqual(frame.enabledPlayerControls, [.forward, .down])
        XCTAssertEqual(session.world.testTrainingMission?.script006Count, 1)
        XCTAssertEqual(session.world.testTrainingMission?.script001Count, 0)
    }

    /// Script 015 (TrainingMission.cpp:1832-1840) does not need Script 014.
    func testScript015RunsWithoutScript014() {
        let session = openingSession(makeTrainingScript015Level())
        let frame = session.touch("FinishCourse", at: 1.2)
        XCTAssertEqual(presentationLog(frame), [
            "hud:Excellent!", "voice:proceed2.osf",
            "hud:\(trainingText("ContinueToCourse"))",
        ])
        XCTAssertEqual(frame.enabledPlayerControls, [.down])
        XCTAssertEqual(session.world.testTrainingMission?.script015Count, 1)
        XCTAssertEqual(session.world.testTrainingMission?.script014Count, 0)
    }

    /// CustomObjectScript_300C runs every eligible block in one EVT_COLLIDE
    /// (TrainingMission.cpp:1665-1690): with Scripts 001 and 004 done,
    /// one StartGoal contact runs Script 003 and then Script 005.
    func testOneStartGoalContactRunsEveryEligibleScriptInOrder() {
        let session = openingSession()
        session.world = settingTrainingCounters(session.world) {
            $0.script001Count = 1
            $0.script004Count = 1
        }
        let frame = session.touch("StartGoal", at: 1.2)
        XCTAssertEqual(presentationLog(frame), [
            "hud:\(trainingText("GoLeft"))", "voice:left1.osf",
            "hud:Excellent!", "voice:up1.osf",
            "hud:\(trainingText("GoUp"))",
        ])
        XCTAssertEqual(session.world.testTrainingMission?.script003Count, 1)
        XCTAssertEqual(session.world.testTrainingMission?.script005Count, 1)
    }

    /// A mover with OF_NO_OBJECT_COLLISIONS checks no objects: the physics
    /// loop clears FQ_CHECK_OBJS (physics.cpp:1012).
    func testPlayerWithNoObjectCollisionsHitsNoGoal() {
        let session = openingSession()
        let player = session.world.testPlayerObject.handle
        session.world.objects[player]!.flags |=
            GameObject.noObjectCollisionsFlag
        XCTAssertEqual(presentationLog(session.touch("ForwardGoal", at: 1.2)), [])
        XCTAssertEqual(session.world.testTrainingMission?.script001Count, 0)
    }

    // MARK: Object hits inside the physics loop (physics.cpp:1503-1560)

    /// The opening level with PortalRoom1 moved to a 40-unit box (room 60)
    /// around the player. Its portal 1, on the +z side, leads to room 61;
    /// its portal 0, on the -z side, to room 62. Old room 2 loses the name.
    private func makePortalCrossingLevel(portalOneIsOpen: Bool) -> Level {
        var level = makeTrainingScript003Level()
        let playerIndex = level.objects.firstIndex {
            $0.handle == level.defaultPlayerBinding!.objectHandle
        }!
        let center = level.objects[playerIndex].position
        let texture = level.surfacePhysics[0].texture
        let halfExtent: Float = 20
        let roomTwo = level.rooms.firstIndex { $0.sourceIndex == 2 }!
        level.rooms[roomTwo].name = nil
        func box(
            _ sourceIndex: Int,
            z offset: Float,
            name: String?,
            portals: [(face: Int, room: Int, portal: Int, flags: UInt32)]
        ) -> LevelRoom {
            let shell = makeSourceContainmentRoom(
                center: center + Vector3(x: 0, y: 0, z: offset),
                texture: texture,
                sourceIndex: sourceIndex,
                halfExtent: halfExtent
            )
            var faces = shell.faces
            for (index, portal) in portals.enumerated() {
                let face = faces[portal.face]
                faces[portal.face] = LevelFace(
                    corners: face.corners,
                    flags: face.flags,
                    portalIndex: index,
                    texture: face.texture
                )
            }
            return LevelRoom(
                sourceIndex: sourceIndex,
                name: name,
                pathPoint: shell.pathPoint,
                vertices: shell.vertices,
                faces: faces,
                portals: portals.map {
                    LevelPortal(
                        flags: $0.flags,
                        faceIndex: $0.face,
                        connectedRoom: $0.room,
                        connectedPortal: $0.portal
                    )
                }
            )
        }
        let portalOneFlags: UInt32 = portalOneIsOpen ? 0 : 1
        level.rooms += [
            box(60, z: 0, name: "PortalRoom1", portals: [
                (face: 4, room: 62, portal: 0, flags: 1),
                (face: 5, room: 61, portal: 0, flags: portalOneFlags),
            ]),
            box(61, z: 2 * halfExtent, name: nil, portals: [
                (face: 4, room: 60, portal: 1, flags: portalOneFlags),
            ]),
            box(62, z: -2 * halfExtent, name: nil, portals: [
                (face: 5, room: 60, portal: 0, flags: 1),
            ]),
        ]
        level.objects[playerIndex].location = .room(60)
        return level
    }

    /// One frame at 600 units per second along +z, with `goal` (if any)
    /// 3 units ahead in room 60.
    private func crossingFrame(
        _ level: Level,
        goal: String?,
        counters: (inout TrainingMissionState) -> Void = { _ in }
    ) -> GameSession {
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        session.parkTrainingGoals()
        session.world = settingTrainingCounters(session.world, counters)
        if let goal {
            let handle = level.findObjectName(goal)
            session.world.objects[handle]!.location = .room(60)
            session.world.objects[handle]!.position =
                session.world.playerPosition + Vector3(x: 0, y: 0, z: 3)
        }
        session.world.velocity = Vector3(x: 0, y: 0, z: 600)
        _ = session.update(at: 0.1, input: .zero)
        return session
    }

    /// Script 014 closes PortalRoom1's portal 1 (TrainingMission.cpp:1814)
    /// during the move's StartCourse hit. The rest of the move is traced
    /// again against the closed portal, so the player stops in room 60 in
    /// the same frame. With no hit the player crosses into room 61.
    func testPortalClosedByAnObjectHitStopsTheRestOfTheMove() {
        let level = makePortalCrossingLevel(portalOneIsOpen: true)
        let unhit = crossingFrame(level, goal: nil)
        XCTAssertEqual(unhit.world.playerLocation, .room(61))

        let session = crossingFrame(level, goal: "StartCourse")
        XCTAssertEqual(session.world.testTrainingMission?.script014Count, 1)
        XCTAssertEqual(session.world.playerLocation, .room(60))
        XCTAssertLessThan(
            session.world.playerPosition.z,
            unhit.level.objects.first {
                $0.handle == level.defaultPlayerBinding!.objectHandle
            }!.position.z + 20
        )
    }

    /// Script 013 opens PortalRoom1's portals (TrainingMission.cpp:1726-1727)
    /// during the move's StartGoal hit, so the rest of the move crosses the
    /// portal it would have hit. With no hit the player stays in room 60.
    func testPortalOpenedByAnObjectHitLetsTheRestOfTheMoveCross() {
        let level = makePortalCrossingLevel(portalOneIsOpen: false)
        let after012: (inout TrainingMissionState) -> Void = {
            $0.script012Count = 1
        }
        let unhit = crossingFrame(level, goal: nil, counters: after012)
        XCTAssertEqual(unhit.world.playerLocation, .room(60))

        let session = crossingFrame(level, goal: "StartGoal", counters: after012)
        XCTAssertEqual(session.world.testTrainingMission?.script013Count, 1)
        XCTAssertEqual(session.world.playerLocation, .room(61))
    }

    // MARK: Script 016 start through StartDodge's timer 8

    /// Script 033's timer 8 reaches StartDodge's EVT_TIMER at
    /// Osiris_ProcessTimers (GameLoop.cpp:3014), which runs Script 016
    /// (TrainingMission.cpp:1869): on the frame whose pre-update Gametime
    /// reaches the timer's end, and last in that frame's presentation.
    func testStartDodgeTimerStartsTheDodgeOnTheFrameItFires() throws {
        let session = openingSession(makeTrainingDodgeAttemptLevel())
        let instruction = trainingText("Dodge30")
        session.touch("StartDodge", at: 1.2)
        let end = try XCTUnwrap(startDodgeTimer(session)).end
        var timestamp = 1.2
        var startFrame: PlayerSimulationFrame?
        for _ in 0..<150 where startFrame == nil {
            timestamp += 0.1
            let frame = session.update(at: timestamp, input: .zero)
            let started =
                session.world.testTrainingMission?.script016Count == 1
            XCTAssertEqual(started, frame.systemsGameTime >= end)
            if started { startFrame = frame }
        }
        let frame = try XCTUnwrap(startFrame)
        XCTAssertEqual(presentationLog(frame).last, "hud:\(instruction)")
        XCTAssertNil(startDodgeTimer(session))
    }

    /// With timer 8 cancelled (Osiris_CancelTimerID,
    /// OsirisLoadandBind.cpp:2515) StartDodge gets no EVT_TIMER, so the
    /// dodge never starts.
    func testCancelledStartDodgeTimerNeverStartsTheDodge() throws {
        let session = openingSession(makeTrainingDodgeAttemptLevel())
        let instruction = trainingText("Dodge30")
        session.touch("StartDodge", at: 1.2)
        XCTAssertNotNil(startDodgeTimer(session))
        session.world.osirisCancelTimerID(8, level: session.level)
        XCTAssertNil(startDodgeTimer(session))
        var log: [String] = []
        for frameIndex in 1...150 {
            log += presentationLog(
                session.update(at: 1.2 + Double(frameIndex) * 0.1, input: .zero)
            )
        }
        XCTAssertFalse(log.contains("hud:\(instruction)"))
        XCTAssertEqual(session.world.testTrainingMission?.script016Count, 0)
    }
}
