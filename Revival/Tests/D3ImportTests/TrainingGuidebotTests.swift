import XCTest

extension WorldRenderingTests {
    func testTrainingGalleryTriggerClosesAnimatedBarrierOnceAndRestores() throws {
        let level = makeTrainingGalleryBarrierLevel()
        try level.validate()
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        var triggerFrame: PlayerSimulationFrame?
        for frameIndex in 1...20 {
            let frame = simulation.update(
                at: Double(frameIndex) * 0.1,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                triggerFrame = frame
                break
            }
        }

        let triggered = try XCTUnwrap(triggerFrame)
        XCTAssertEqual(
            triggered.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Excellent!",
                    "Your ship is equipped with a utility robot called a Guidebot.  Release him now with F4.",
                ],
                voiceSourceName: "guidebota.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        XCTAssertEqual(
            triggered.enabledPlayerControls,
            PlayerControlMask(rawValue: 0)
        )
        XCTAssertEqual(simulation.galleryMarkerLightDistance, 0)
        XCTAssertEqual(triggered.playerView.roomSourceIndex, 3)
        assertTrainingGalleryBarrier(level: simulation.runtimeLevel, rendersFaces: true)
        let playerStart = level.objects.first { $0.handle == 2_048 }!
        let blockedReturn = traceIndoorMovement(
            in: simulation.runtimeLevel,
            startRoom: triggered.playerView.roomSourceIndex,
            start: triggered.playerView.camera.position,
            end: playerStart.position,
            radius: triggered.playerView.collisionRadius
        )
        guard case .wallHit = blockedReturn.outcome else {
            return XCTFail("The closed force-field barrier must block the player")
        }

        let continuation = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(simulation.world)
        )
        let repeated = simulation.update(
            at: Double(triggered.gameTime) + 0.1,
            input: .init(forward: -1)
        )
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            repeated.enabledPlayerControls,
            PlayerControlMask(rawValue: 0)
        )

        let restored = try GameSession(
            level: level,
            world: continuation.rebased(onto: level),
            resumedAtTimestamp: 100
        )
        assertTrainingGalleryBarrier(level: restored.runtimeLevel, rendersFaces: true)
        let afterRestore = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(afterRestore.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            afterRestore.enabledPlayerControls,
            PlayerControlMask(rawValue: 0)
        )
        XCTAssertEqual(restored.galleryMarkerLightDistance, 0)
    }

    /// After Script 036 opened the gallery (TrainingRobotScriptTests covers
    /// Scripts 036 and 029), Portal2 runs the bespoke Script 032 once.
    func testPortal2AfterScript036RunsScript032OnceAndRestoresLaterState() throws {
        let level = makeTrainingRobotGuidebotLevel()
        try level.validate()
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        simulation.applyTrainingScript036Outcome()
        assertTrainingGalleryBarrier(
            level: simulation.runtimeLevel,
            rendersFaces: false
        )
        var timestamp = 0.1
        let opened = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(opened.enabledPlayerControls, .all)
        XCTAssertEqual(simulation.galleryMarkerLightDistance, 50)

        var script032Frame: PlayerSimulationFrame?
        for _ in 1...20 {
            timestamp += 0.1
            let frame = simulation.update(
                at: timestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                script032Frame = frame
                break
            }
        }
        let script032 = try XCTUnwrap(script032Frame)
        XCTAssertEqual(
            script032.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Excellent!",
                    "Your ship is equipped with a utility robot called a Guidebot.  Release him now with F4.",
                ],
                voiceSourceName: "guidebota.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        XCTAssertEqual(
            level.trainingGalleryBarrier?.orderedPortalIndices,
            [1, 0]
        )
        XCTAssertEqual(
            script032.enabledPlayerControls,
            PlayerControlMask(rawValue: 0)
        )
        XCTAssertEqual(simulation.galleryMarkerLightDistance, 0)
        XCTAssertNotEqual(
            simulation.world.objectType(simulation.world.buddyHandle),
            .robot
        )
        XCTAssertFalse(simulation.runtimeLevel.objectPresentations.contains {
            $0.objectHandle
                == level.trainingRobotGuidebotChain?.guidebotObjectHandle
                && $0.isVisible
        })
        assertTrainingGalleryBarrier(
            level: simulation.runtimeLevel,
            rendersFaces: true
        )

        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuation = try JSONDecoder().decode(
            GameWorld.self,
            from: continuationData
        )
        let repeated = simulation.update(
            at: timestamp + 0.1,
            input: .init(forward: 1)
        )
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            repeated.enabledPlayerControls,
            PlayerControlMask(rawValue: 0)
        )
        XCTAssertNotEqual(
            simulation.world.objectType(simulation.world.buddyHandle),
            .robot
        )

        let restored = try GameSession(
            level: level,
            world: continuation.rebased(onto: level),
            resumedAtTimestamp: 100
        )
        assertTrainingGalleryBarrier(
            level: restored.runtimeLevel,
            rendersFaces: true
        )
        let afterRestore = restored.update(
            at: 100.1,
            input: .init(forward: 1)
        )
        XCTAssertTrue(afterRestore.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            afterRestore.enabledPlayerControls,
            PlayerControlMask(rawValue: 0)
        )
        XCTAssertEqual(restored.galleryMarkerLightDistance, 0)
        XCTAssertNotEqual(
            restored.world.objectType(restored.world.buddyHandle),
            .robot
        )

    }

    func testScript036AfterScript060RestoresItsLaterBarrierState() throws {
        let level = withTrainingGuideBot(makeTrainingRobotGuidebotLevel())
        try level.validate()
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for frameIndex in 1...20 {
            timestamp = Double(frameIndex) * 0.1
            let frame = simulation.update(
                at: timestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                break
            }
        }
        let script060 = simulation.update(
            at: timestamp + 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertTrue(script060.trainingOpeningFeedback.contains {
            $0.voiceSourceName == "guidebotb.osf"
        })
        XCTAssertEqual(simulation.galleryMarkerLightDistance, 0)
        assertTrainingGalleryBarrier(
            level: simulation.runtimeLevel,
            rendersFaces: true
        )

        simulation.applyTrainingScript036Outcome()
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        XCTAssertEqual(simulation.galleryMarkerLightDistance, 50)
        XCTAssertEqual(simulation.world.playerControllerBitflags, .all)
        assertTrainingGalleryBarrier(
            level: simulation.runtimeLevel,
            rendersFaces: false
        )
        let continuation = try JSONDecoder().decode(
            GameWorld.self,
            from: continuationData
        )
        var restorationLevel = level
        let restoredRoomIndex = try XCTUnwrap(
            restorationLevel.rooms.firstIndex {
                $0.sourceIndex == script060.playerView.roomSourceIndex
            }
        )
        restorationLevel.rooms[restoredRoomIndex] =
            addingSourceContainmentShell(
                to: restorationLevel.rooms[restoredRoomIndex],
                center: script060.playerView.camera.position,
                texture: restorationLevel.surfacePhysics[0].texture,
                halfExtent: 500
            )
        let restored = try GameSession(
            level: restorationLevel,
            world: continuation.rebased(onto: restorationLevel),
            resumedAtTimestamp: 100
        )
        assertTrainingGalleryBarrier(
            level: restored.runtimeLevel,
            rendersFaces: false
        )
        let afterRestore = restored.update(
            at: 100.1,
            input: .zero
        )
        XCTAssertTrue(afterRestore.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(afterRestore.enabledPlayerControls, .all)
        XCTAssertEqual(restored.galleryMarkerLightDistance, 50)
    }

    func testTrainingGuidebotDeploymentContinuesGalleryOnce() throws {
        let level = withTrainingGuideBot(makeTrainingRobotGuidebotLevel())
        try level.validate()
        XCTAssertEqual(
            trainingPlayerControlMask(
                galleryWasTriggered: true,
                controlsWereRestored: true,
                controllerBitflags: [.reverse]
            ),
            .all
        )
        let guidebotSimulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        // Scripts 000 and 021 showed the enabled controls
        // (TrainingMission.cpp:1494, :1949); Script 029 hides them.
        guidebotSimulation.world.hudShowControls = true

        var triggerFrame: PlayerSimulationFrame?
        var triggerTimestamp = 0.0
        for frameIndex in 1...20 {
            triggerTimestamp = Double(frameIndex) * 0.1
            let frame = guidebotSimulation.update(
                at: triggerTimestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                triggerFrame = frame
                break
            }
        }
        let triggered = try XCTUnwrap(triggerFrame)
        XCTAssertEqual(triggered.enabledPlayerControls.rawValue, 0)
        XCTAssertTrue(triggered.showsEnabledPlayerControls)

        let deployed = guidebotSimulation.update(
            at: triggerTimestamp + 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        // The exit command's birth plays GBExpulsionA at the player
        // (AIGame.cpp:4722), and Script 060 sees the Guide-Bot out.
        XCTAssertEqual(
            deployed.trainingOpeningFeedback.filter {
                $0.soundSourceName == nil
            },
            [.init(
                hudMessages: [
                    "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
                ],
                voiceSourceName: "guidebotb.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        XCTAssertEqual(soundNames([deployed]), ["GBExpulsionA"])
        XCTAssertEqual(deployed.enabledPlayerControls, .all)
        XCTAssertTrue(deployed.showsEnabledPlayerControls)
        XCTAssertEqual(guidebotSimulation.galleryMarkerLightDistance, 0)
        assertTrainingGalleryBarrier(
            level: guidebotSimulation.runtimeLevel,
            rendersFaces: true
        )
        let deployedContinuation = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(guidebotSimulation.world)
        )
        var deployedRestorationLevel = level
        let deployedRoomIndex = try XCTUnwrap(
            deployedRestorationLevel.rooms.firstIndex {
                $0.sourceIndex == deployed.playerView.roomSourceIndex
            }
        )
        deployedRestorationLevel.rooms[deployedRoomIndex] =
            addingSourceContainmentShell(
                to: deployedRestorationLevel.rooms[deployedRoomIndex],
                center: deployed.playerView.camera.position,
                texture: deployedRestorationLevel.surfacePhysics[0].texture,
                halfExtent: 500
            )
        XCTAssertNoThrow(
            try GameSession(
                level: deployedRestorationLevel,
                world: deployedContinuation.rebased(onto: deployedRestorationLevel),
                resumedAtTimestamp: 100
            )
        )
        let repeatedGuidebot = guidebotSimulation.update(
            at: triggerTimestamp + 0.2,
            input: .zero
        )
        XCTAssertTrue(repeatedGuidebot.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(repeatedGuidebot.enabledPlayerControls, .all)

    }

    func testTrainingGuidebotDeploymentReachesScript060InSameUpdate() throws {
        let simulation = GameSession(
            level: withTrainingGuideBot(makeTrainingRobotGuidebotLevel()),
            presentationReadyTimestamp: 0
        )
        var timestamp = 0.0
        for frameIndex in 1...20 {
            timestamp = Double(frameIndex) * 0.1
            let frame = simulation.update(
                at: timestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                break
            }
        }

        let deployed = simulation.update(
            at: timestamp + 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )

        // The exit command's birth plays GBExpulsionA at the player
        // (AIGame.cpp:4722), and Script 060 sees the Guide-Bot out.
        XCTAssertEqual(
            deployed.trainingOpeningFeedback.filter {
                $0.soundSourceName == nil
            },
            [.init(
                hudMessages: [
                    "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
                ],
                voiceSourceName: "guidebotb.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        XCTAssertEqual(soundNames([deployed]), ["GBExpulsionA"])
        XCTAssertEqual(deployed.enabledPlayerControls, .all)
    }
}
