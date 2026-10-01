import XCTest

// The Guide-Bot lessons of TrainingMission.cpp on the Osiris runtime:
// Portal2's trigger EVT_COLLIDE (Script 032, :2325-2341), the level
// EVT_INTERVAL check of the released Guide-Bot (Script 060, :1431-1441),
// and its return to the ship (Script 058, :1443-1455) through the AIGame
// Guide-Bot's return command and the dynamic room route.
extension TrainingMissionScriptTests {
    private func session(_ level: Level) throws -> GameSession {
        try level.validate()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        // Script 002's first HUD message has run.
        session.world.trainingMission.script002Count = 1
        return session
    }

    /// Flies forward until Script 032 runs, and returns that frame.
    private func flyThroughPortal2(
        _ session: GameSession, timestamp: inout Double
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
            "voice:guidebota.osf", "hud:Excellent!",
            "hud:\(fixtureGuideBotScriptMessages[0].text)",
        ])
        XCTAssertEqual(simulation.galleryMarkerLightDistance, 0)
        assertTrainingGalleryBarrier(
            level: simulation.runtimeLevel, rendersFaces: true
        )
        XCTAssertEqual(simulation.world.playerControllerBitflags.rawValue, 0)
        let portal2 = try XCTUnwrap(level.triggers.firstIndex {
            $0.name == "Portal2"
        })
        XCTAssertNotEqual(
            simulation.world.triggerFlags[portal2] & TriggerFlag.dead, 0
        )

        // The saved world keeps the dead trigger and the counter.
        let saved = try JSONDecoder().decode(
            GameWorld.self, from: JSONEncoder().encode(simulation.world)
        )
        let restored = try GameSession(
            level: level, world: saved, resumedAtTimestamp: 100
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
            simulation.world.objectType(simulation.world.buddyHandle), .robot
        )
        XCTAssertFalse(presentationLog(frames[0]).contains("voice:guidebotb.osf"))
        XCTAssertEqual(simulation.world.testTrainingMission?.script060Count, 0)
    }

    /// PortalRoom5's two portals (Room_indexes[4], source room 2 in the
    /// fixture) and their reciprocals.
    private func assertReturnBarrier(
        _ level: Level,
        rendersFaces: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let room = level.rooms.first { $0.sourceIndex == 2 }!
        for portalIndex in [0, 1] {
            let portal = room.portals[portalIndex]
            XCTAssertEqual(
                portal.flags & 1 != 0, rendersFaces, file: file, line: line
            )
            let connectedRoom = level.rooms.first {
                $0.sourceIndex == portal.connectedRoom
            }!
            XCTAssertEqual(
                connectedRoom.portals[portal.connectedPortal].flags & 1 != 0,
                rendersFaces, file: file, line: line
            )
        }
    }

    /// The return command (GBC_RETURN_TO_SHIP, AIGame.cpp:5143) sends the
    /// Guide-Bot into the player; the collision enters the ship
    /// (DoCollide :5510, SetMode(GBM_ENTER_SHIP) :4628). Script 058
    /// (TrainingMission.cpp:1443-1455) waits while the Guide-Bot is a robot
    /// and then, in the level EVT_INTERVAL, lights FlashLight-3, opens
    /// PortalRoom5, plays proceed6.osf, and shows GoodJob, once.
    func testGuidebotReturnCollisionRunsScript058OnceAcrossReload() throws {
        let level = scriptingTrainingCameraMonitorLevel(
            makeTrainingCameraMonitorLevel()
        )
        try level.validate()
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0
        )
        var timestamp = 0.1
        simulation.releaseOrRecallTestGuideBot()
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp += 0.1
        _ = simulation.touch("CameraMonitor", at: timestamp)
        timestamp += 0.1
        _ = simulation.update(at: timestamp, input: .init(usesInventory: true))
        // GBM_BIRTH lasts until mode_time > 1.2 s (AIGame.cpp:5893), and the
        // menu offers the return command only in GBM_AMBIENT (:4892).
        simulation.runFrames(13, from: &timestamp)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode, GuideBotScript.ambientMode
        )
        // The Guide-Bot is a robot, so Script 058 waits after the use.
        XCTAssertEqual(simulation.world.testTrainingMission?.script059Count, 1)
        XCTAssertEqual(simulation.world.testTrainingMission?.script058Count, 0)
        XCTAssertEqual(simulation.returnMarkerLightDistance, 0)
        timestamp += 0.1
        simulation.releaseOrRecallTestGuideBot()
        let requested = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(hudMessages([requested]), ["GB: Returning to ship."])
        // DoInit set last_sound_time at level start (AIGame.cpp:5683), so
        // DoMessage plays no sound before 2.5 s (:4542).
        XCTAssertFalse(soundNames([requested]).contains("GBotAcceptOrder1"))
        XCTAssertEqual(simulation.world.testGuideBot?.isMarkedForPickup, true)

        // The fixture's Buddybot model is flat, so its move never touches
        // the ship's sphere (RESULT_CHECK_POLY_SPHERE); once the parent link
        // is gone (AIGame.cpp:6045) and it is at the player, the test gives
        // the pair's contact (collide_two_objects).
        for _ in 1...100 {
            timestamp += 0.1
            _ = simulation.update(at: timestamp, input: .zero)
            if let guideBot = simulation.world.testGuideBotObject,
               guideBot.parent == .none,
               simulation.world.objectDistance(
                   guideBot.handle, simulation.world.testPlayerObject.handle,
                   subtractingSizes: true
               ) < 0 {
                break
            }
        }
        XCTAssertEqual(simulation.world.testGuideBotObject?.parent, ObjectHandle.none)
        simulation.world.collideTwoObjects(
            simulation.world.buddyHandle,
            simulation.world.testPlayerObject.handle, level: simulation.level
        )
        var completed: PlayerSimulationFrame?
        for _ in 1...300 {
            timestamp += 0.1
            let frame = simulation.update(at: timestamp, input: .zero)
            if frame.presentationFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                completed = frame
                break
            }
        }

        let script058 = try XCTUnwrap(completed)
        XCTAssertEqual(
            Set(hudMessages([script058])), ["GB: Entering ship!", "Excellent!"]
        )
        XCTAssertEqual(
            simulation.world.objectType(simulation.world.buddyHandle), .dummy
        )
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode, GuideBotScript.inShipMode
        )
        XCTAssertTrue(script058.objectSoundLoops.isEmpty)
        XCTAssertEqual(simulation.returnMarkerLightDistance, 50)
        assertReturnBarrier(simulation.runtimeLevel, rendersFaces: false)
        let postReturnFrame = simulation.update(
            at: timestamp + 0.1, input: .zero
        )
        XCTAssertTrue(postReturnFrame.presentationFeedback.isEmpty)

        let restored = try restored(simulation, at: 100)
        let afterReload = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(afterReload.presentationFeedback.isEmpty)
        XCTAssertTrue(afterReload.objectSoundLoops.isEmpty)
        XCTAssertEqual(restored.returnMarkerLightDistance, 50)
        assertReturnBarrier(restored.runtimeLevel, rendersFaces: false)
    }

    func testGuidebotCrossRoomReturnReachesScript058() throws {
        var level = makeTrainingCameraMonitorLevel()
        let start = RoomCamera.trainingRoom3.position
        let turn = Vector3(x: start.x, y: start.y + 200, z: start.z)
        let destination = Vector3(
            x: start.x + 400, y: start.y + 200, z: start.z
        )
        let blockingTexture = try XCTUnwrap(
            level.surfacePhysics.first {
                $0.behavior == .blocking
            }?.texture
        )
        let returnTexture = SourceResource(
            storedIndex: 908, sourceName: "Alien Force Field_1"
        )
        func portalFace(_ face: LevelFace, portalIndex: Int) -> LevelFace {
            .init(
                corners: face.corners, flags: face.flags,
                portalIndex: portalIndex, texture: returnTexture
            )
        }

        var room3 = makeSourceContainmentRoom(
            center: start, texture: blockingTexture, sourceIndex: 3,
            halfExtent: 100
        )
        room3 = LevelRoom(
            sourceIndex: 3,
            pathPoint: start,
            vertices: room3.vertices,
            faces: room3.faces.enumerated().map {
                $0.offset == 3
                    ? portalFace($0.element, portalIndex: 0)
                    : $0.element
            },
            portals: [
                .init(
                    faceIndex: 3, connectedRoom: 2, connectedPortal: 0,
                    pathPoint: .init(x: start.x, y: start.y + 100, z: start.z)
                ),
            ]
        )
        var room2 = makeSourceContainmentRoom(
            center: turn, texture: blockingTexture, sourceIndex: 2,
            halfExtent: 100
        )
        room2 = LevelRoom(
            sourceIndex: 2,
            pathPoint: turn,
            vertices: room2.vertices,
            faces: room2.faces.enumerated().map {
                if $0.offset == 2 {
                    return portalFace($0.element, portalIndex: 0)
                }
                if $0.offset == 1 {
                    return portalFace($0.element, portalIndex: 1)
                }
                return $0.element
            },
            portals: [
                .init(
                    faceIndex: 2, connectedRoom: 3, connectedPortal: 0,
                    pathPoint: .init(x: start.x, y: start.y + 100, z: start.z)
                ),
                .init(
                    faceIndex: 1,
                    connectedRoom: 1,
                    connectedPortal: 0,
                    pathPoint: .init(
                        x: start.x + 100, y: start.y + 200, z: start.z
                    )
                ),
            ]
        )
        var room1 = makeSourceContainmentRoom(
            center: destination, texture: blockingTexture, sourceIndex: 1,
            halfExtent: 300
        )
        room1 = LevelRoom(
            sourceIndex: 1,
            pathPoint: destination,
            vertices: room1.vertices,
            faces: room1.faces.enumerated().map {
                $0.offset == 0
                    ? portalFace($0.element, portalIndex: 0)
                    : $0.element
            },
            portals: [
                .init(
                    faceIndex: 0,
                    connectedRoom: 2,
                    connectedPortal: 1,
                    pathPoint: .init(
                        x: start.x + 100, y: start.y + 200, z: start.z
                    )
                )
            ]
        )
        var objects = level.objects
        for handle in [UInt32(2_048), 6_167, 6_183, 10_245] {
            let objectIndex = try XCTUnwrap(objects.firstIndex {
                $0.handle == handle
            })
            objects[objectIndex].location = .room(3)
            objects[objectIndex].position = start
        }
        level = replacing(
            level,
            rooms: [room1, room2, room3],
            objects: objects,
            indoorNavigation: .init(
                sourceHighestRoomPlusTerrainRegions: 11,
                sourceWasVerified: true, rooms: []
            )
        )
        level = scriptingTrainingCameraMonitorLevel(level)
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0
        )
        simulation.releaseOrRecallTestGuideBot()
        _ = simulation.update(at: 0.1, input: .zero)
        _ = simulation.touch("CameraMonitor", at: 0.2)
        _ = simulation.update(at: 0.3, input: .init(usesInventory: true))
        XCTAssertEqual(simulation.world.testTrainingMission?.script059Count, 1)
        // The birth ends after 1.2 s (AIGame.cpp:5893), and the parent link
        // that keeps the Guide-Bot from hitting the player ends 3 s after
        // the birth (:6246).
        var seedTime = 0.3
        simulation.runFrames(31, from: &seedTime)
        XCTAssertEqual(
            simulation.world.boaRoomRoute(from: 3, to: 1, level: level),
            [3, 2, 1]
        )

        var continuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        continuationObject["playerLocation"] = ["room": ["_0": 1]]
        continuationObject["playerPosition"] = [
            "x": destination.x, "y": destination.y, "z": destination.z,
        ]
        let movedPlayerContinuation = try decodeTestWorld(continuationObject)
        let restored = try GameSession(
            level: level, world: movedPlayerContinuation.rebased(onto: level),
            resumedAtTimestamp: 100
        )

        var completed: PlayerSimulationFrame?
        for frameIndex in 1...400 {
            if frameIndex == 1 {
                restored.releaseOrRecallTestGuideBot()
            }

            let frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1, input: .zero
            )
            if frameIndex == 1 {
                XCTAssertEqual(hudMessages([frame]), ["GB: Returning to ship."])
            }
            if frameIndex == 2 {
                // The return goal paths through the portal rooms
                // (AIPathAllocPath, aipath.cpp:977).
                let path = try XCTUnwrap(
                    restored.world.testGuideBotObject?.ai?.path
                )
                XCTAssertEqual(path.dynamicNodes.last?.roomSourceIndex, 1)
                XCTAssertGreaterThan(path.dynamicNodes.count, 1)
            }
            if frame.presentationFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                completed = frame
                break
            }
        }

        XCTAssertNotNil(completed)
        XCTAssertEqual(
            restored.world.objectType(restored.world.buddyHandle), .dummy
        )
        XCTAssertEqual(restored.returnMarkerLightDistance, 50)
        assertReturnBarrier(restored.runtimeLevel, rendersFaces: false)
    }

    func testDeployedGuidebotContinuationRestoresPresentationWithoutRepeatingScript060() throws {
        let level = makeScriptedTrainingGalleryLevel()
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0
        )
        var galleryTimestamp = 0.0
        for frameIndex in 1...20 {
            galleryTimestamp = Double(frameIndex) * 0.1
            let frame = simulation.update(
                at: galleryTimestamp, input: .init(forward: 1)
            )
            if frame.presentationFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                break
            }
        }
        simulation.releaseOrRecallTestGuideBot()
        let deployed = simulation.update(
            at: galleryTimestamp + 0.1, input: .zero
        )
        // Script 060 runs once the Guide-Bot is out (TrainingMission.cpp:1431).
        XCTAssertTrue(deployed.presentationFeedback.contains {
            $0.voiceSourceName == "guidebotb.osf"
        })
        XCTAssertEqual(
            simulation.world.objectType(simulation.world.buddyHandle), .robot
        )
        var continuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        let restoredRoomPoint = try XCTUnwrap(
            level.rooms.first { $0.sourceIndex == 3 }
        ).pathPoint
        var restorationLevel = level
        let restoredRoomIndex = try XCTUnwrap(
            restorationLevel.rooms.firstIndex { $0.sourceIndex == 3 }
        )
        restorationLevel.rooms[restoredRoomIndex] =
            addingSourceContainmentShell(
                to: restorationLevel.rooms[restoredRoomIndex],
                center: restoredRoomPoint,
                texture: restorationLevel.surfacePhysics[0].texture,
                halfExtent: 500
            )
        continuationObject["playerPosition"] = [
            "x": restoredRoomPoint.x, "y": restoredRoomPoint.y,
            "z": restoredRoomPoint.z,
        ]
        let continuation = try decodeTestWorld(continuationObject)
        let restored = try GameSession(
            level: restorationLevel,
            world: continuation.rebased(onto: restorationLevel),
            resumedAtTimestamp: 100
        )
        XCTAssertEqual(restored.world, continuation)
        // The Guide-Bot AIInitAll made shows its page's model.
        let guidebot = try XCTUnwrap(
            restored.world.objects[restored.world.buddyHandle]
        )
        XCTAssertEqual(
            restored.runtimeLevel.objectPresentation(of: guidebot)?
                .primaryModel.sourceName,
            "Buddybot.oof"
        )
        let resumed = restored.update(at: 100.1, input: .zero)
        XCTAssertEqual(
            restored.world.objectType(restored.world.buddyHandle), .robot
        )
        XCTAssertTrue(resumed.presentationFeedback.isEmpty)
        XCTAssertEqual(resumed.enabledPlayerControls, .all)
    }
}
