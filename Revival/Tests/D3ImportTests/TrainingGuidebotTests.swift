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
        XCTAssertEqual(triggered.trainingGalleryMarkerLightDistance, 0)
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
        XCTAssertEqual(afterRestore.trainingGalleryMarkerLightDistance, 0)
    }

    func testScript029ThenPortal2RunsScript032OnceAndRestoresLaterState() throws {
        let level = makeTrainingRobotGuidebotLevel()
        try level.validate()
        XCTAssertNil(level.trainingFollowBotDestruction)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        simulation.destroyTrainingRobot(handle: 4_112)
        assertTrainingGalleryBarrier(
            level: simulation.runtimeLevel,
            rendersFaces: false
        )
        var timestamp = 0.0
        var script029Frame: PlayerSimulationFrame?
        for frameIndex in 1...30 {
            timestamp = Double(frameIndex) * 0.1
            let frame = simulation.update(
                at: timestamp,
                input: .zero
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "proceed5.osf"
            }) {
                script029Frame = frame
                break
            }
        }
        let script029 = try XCTUnwrap(script029Frame)
        XCTAssertEqual(
            script029.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Excellent!",
                    "Now go through the open doorway, and into the next room.",
                ],
                voiceSourceName: "proceed5.osf",
                voicePrecedesHUDMessages: false
            )]
        )
        XCTAssertEqual(script029.enabledPlayerControls, .all)
        XCTAssertEqual(script029.trainingGalleryMarkerLightDistance, 50)

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
        XCTAssertEqual(script032.trainingGalleryMarkerLightDistance, 0)
        XCTAssertNil(script032.trainingGuidebot)
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
        XCTAssertNil(repeated.trainingGuidebot)

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
        XCTAssertEqual(afterRestore.trainingGalleryMarkerLightDistance, 0)
        XCTAssertNil(afterRestore.trainingGuidebot)

    }

    func testScript036AfterScript060RestoresItsLaterBarrierState() throws {
        let level = makeTrainingRobotGuidebotLevel()
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
        XCTAssertEqual(script060.trainingGalleryMarkerLightDistance, 0)
        assertTrainingGalleryBarrier(
            level: simulation.runtimeLevel,
            rendersFaces: true
        )

        simulation.destroyTrainingRobot(handle: 4_112)
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let galleryState = try XCTUnwrap(
            continuationObject["trainingGalleryBarrierState"]
                as? [String: Any]
        )
        XCTAssertEqual(galleryState["markerLightDistance"] as? Double, 50)
        let robotState = try XCTUnwrap(
            continuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(robotState["controlsWereRestored"] as? Bool, true)
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
        XCTAssertEqual(afterRestore.trainingGalleryMarkerLightDistance, 50)
    }

    func testTrainingRobotDestructionAndGuidebotDeploymentContinueGalleryOnce() throws {
        let level = makeTrainingRobotGuidebotLevel()
        try level.validate()
        var relocatedRobotLevel = level
        let relocatedRobotIndex = try XCTUnwrap(
            relocatedRobotLevel.objects.firstIndex {
                $0.handle == 4_112
            }
        )
        relocatedRobotLevel.objects[relocatedRobotIndex].location = .room(1)
        XCTAssertThrowsError(try relocatedRobotLevel.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training robot Guidebot chain")
            )
        }
        let chain = try XCTUnwrap(level.trainingRobotGuidebotChain)
        let wrongRobotFlagsLevel = replacing(
            level,
            trainingRobotGuidebotChain: .init(
                destroyRobotObjectHandle: chain.destroyRobotObjectHandle,
                guidebotObjectHandle: chain.guidebotObjectHandle,
                destroyRobotRoomSourceIndex:
                    chain.destroyRobotRoomSourceIndex,
                destroyRobotFlags: 0,
                destructionDelay: chain.destructionDelay,
                destructionMessage: chain.destructionMessage,
                exitInstruction: chain.exitInstruction,
                destructionVoiceSourceName:
                    chain.destructionVoiceSourceName,
                deployedGuidebotObjectType:
                    chain.deployedGuidebotObjectType,
                deployedGuidebotMessage:
                    chain.deployedGuidebotMessage,
                deployedGuidebotVoiceSourceName:
                    chain.deployedGuidebotVoiceSourceName,
                combat: chain.combat,
                guidebot: chain.guidebot
            )
        )
        XCTAssertThrowsError(try wrongRobotFlagsLevel.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training robot Guidebot chain")
            )
        }
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
        XCTAssertEqual(
            deployed.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
                ],
                voiceSourceName: "guidebotb.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        XCTAssertEqual(deployed.enabledPlayerControls, .all)
        XCTAssertTrue(deployed.showsEnabledPlayerControls)
        XCTAssertEqual(deployed.trainingGalleryMarkerLightDistance, 0)
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

        let destructionSimulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        for frameIndex in 1...20 {
            let frame = destructionSimulation.update(
                at: Double(frameIndex) * 0.1,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                break
            }
        }
        destructionSimulation.destroyTrainingRobot(handle: 4_112)
        XCTAssertFalse(destructionSimulation.runtimeLevel.objects.contains {
            $0.handle == 4_112
        })
        assertTrainingGalleryBarrier(
            level: destructionSimulation.runtimeLevel,
            rendersFaces: false
        )

        let continuation = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(destructionSimulation.world)
        )
        var consumedDestructionObject = try XCTUnwrap(
            testWorldObject(continuation)
        )
        var consumedDestructionState = try XCTUnwrap(
            consumedDestructionObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        consumedDestructionState.removeValue(
            forKey: "destructionTimerRemaining"
        )
        consumedDestructionState["destructionFeedbackWasPresented"] = true
        consumedDestructionState["enabledControlHUDIsVisible"] = false
        consumedDestructionObject["trainingRobotGuidebotState"] =
            consumedDestructionState
        let consumedDestruction = try decodeTestWorld(consumedDestructionObject)
        let consumedDestructionSimulation = try GameSession(
            level: level,
            world: consumedDestruction.rebased(onto: level),
            resumedAtTimestamp: 300
        )
        let afterDestructionReload = consumedDestructionSimulation.update(
            at: 300.1,
            input: .zero
        )
        XCTAssertTrue(afterDestructionReload.trainingOpeningFeedback.isEmpty)
        XCTAssertFalse(afterDestructionReload.showsEnabledPlayerControls)
        XCTAssertEqual(
            afterDestructionReload.trainingGalleryMarkerLightDistance,
            50
        )
        XCTAssertFalse(consumedDestructionSimulation.runtimeLevel.objects.contains {
            $0.handle == 4_112
        })
        let restored = try GameSession(
            level: level,
            world: continuation.rebased(onto: level),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == 4_112
        })
        let restoredForwardControls = try GameSession(
            level: level,
            world: continuation.rebased(onto: level),
            resumedAtTimestamp: 150
        )
        let restoredNeutralControls = try GameSession(
            level: level,
            world: continuation.rebased(onto: level),
            resumedAtTimestamp: 150
        )
        let restoredForwardFrame = restoredForwardControls.update(
            at: 150.1,
            input: .init(forward: 1)
        )
        let restoredNeutralFrame = restoredNeutralControls.update(
            at: 150.1,
            input: .zero
        )
        XCTAssertNotEqual(
            restoredForwardFrame.velocity,
            restoredNeutralFrame.velocity
        )
        let destruction = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(destruction.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(destruction.enabledPlayerControls, .all)
        XCTAssertTrue(destruction.showsEnabledPlayerControls)
        XCTAssertEqual(destruction.trainingGalleryMarkerLightDistance, 50)
        var delayedFrame: PlayerSimulationFrame?
        for frameIndex in 2...21 {
            let frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: .zero
            )
            if !frame.trainingOpeningFeedback.isEmpty {
                delayedFrame = frame
                break
            }
        }
        let delayed = try XCTUnwrap(delayedFrame)
        XCTAssertEqual(
            delayed.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Excellent!",
                    "Now go through the open doorway, and into the next room.",
                ],
                voiceSourceName: "proceed5.osf",
                voicePrecedesHUDMessages: false
            )]
        )
        XCTAssertFalse(delayed.showsEnabledPlayerControls)
        let afterRestore = restored.update(
            at: Double(delayed.gameTime) + 100,
            input: .zero
        )
        XCTAssertTrue(afterRestore.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(afterRestore.enabledPlayerControls, .all)
        XCTAssertFalse(afterRestore.showsEnabledPlayerControls)
        XCTAssertEqual(afterRestore.trainingGalleryMarkerLightDistance, 50)
        assertTrainingGalleryBarrier(
            level: consumedDestructionSimulation.runtimeLevel,
            rendersFaces: false
        )
    }

    func testTrainingGuidebotDeploymentReachesScript060InSameUpdate() throws {
        let simulation = GameSession(
            level: makeTrainingRobotGuidebotLevel(),
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

        XCTAssertEqual(
            deployed.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
                ],
                voiceSourceName: "guidebotb.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        XCTAssertEqual(deployed.enabledPlayerControls, .all)
    }

    func testScript060ActiveGoalCommandReachesCameraMonitorThenReturnsToLivePlayer()
        throws
    {
        var level = makeTrainingRASBot1DeathLevel()
        let playerIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        let pickupIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == 6_167
        })
        let player = level.objects[playerIndex]
        let pickupPosition = Vector3(
            x: player.position.x + player.orientation.forward.x * 120,
            y: player.position.y + player.orientation.forward.y * 120,
            z: player.position.z + player.orientation.forward.z * 120
        )
        let roomCenter = Vector3(
            x: player.position.x + player.orientation.forward.x * 60,
            y: player.position.y + player.orientation.forward.y * 60,
            z: player.position.z + player.orientation.forward.z * 60
        )
        level.rooms.append(
            makeSourceContainmentRoom(
                center: roomCenter,
                texture: level.surfacePhysics[0].texture,
                sourceIndex: 39,
                halfExtent: 200
            )
        )
        level.objects[playerIndex].location = .room(39)
        level.objects[pickupIndex].location = .room(39)
        level.objects[pickupIndex].position = pickupPosition

        let seed = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = seed.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        // AIGame.cpp:5893 keeps GBM_BIRTH until mode_time > 1.2 s, and
        // AIGame.cpp:4892 offers the goal commands only in GBM_AMBIENT.
        // DoInit sets last_sound_time to the level start (AIGame.cpp:5683),
        // so DoMessage plays its sound only after 2.5 s (AIGame.cpp:4542).
        XCTAssertFalse(seed.trainingGuidebotGoalCommandIsAvailable)
        for frameIndex in 2...26 {
            _ = seed.update(at: Double(frameIndex) * 0.1, input: .zero)
        }
        var continuationObject = try XCTUnwrap(
            testWorldObject(seed.world)
        )
        var galleryState = try XCTUnwrap(
            continuationObject["trainingGalleryBarrierState"]
                as? [String: Any]
        )
        galleryState["wasTriggered"] = true
        galleryState["markerLightDistance"] = 0
        continuationObject["trainingGalleryBarrierState"] = galleryState
        var robotState = try XCTUnwrap(
            continuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        robotState["guidebotContinuationWasPresented"] = true
        robotState["controlsWereRestored"] = true
        continuationObject["trainingRobotGuidebotState"] = robotState
        let reachedContinuation = try decodeTestWorld(continuationObject)
        var unknownGoalLevel = level
        let cameraGoalIndex = try XCTUnwrap(
            unknownGoalLevel.goals.firstIndex {
                $0.name == "Locate the Camera Monitor"
            }
        )
        let cameraGoal = unknownGoalLevel.goals[cameraGoalIndex]
        unknownGoalLevel.goals[cameraGoalIndex] = LevelGoal(
            status: cameraGoal.status | 0x0000_0020,
            priority: cameraGoal.priority,
            list: cameraGoal.list,
            name: cameraGoal.name,
            itemName: cameraGoal.itemName,
            description: cameraGoal.description,
            completionMessage: cameraGoal.completionMessage,
            items: cameraGoal.items
        )
        let unknownGoalSimulation = try GameSession(
            level: unknownGoalLevel,
            world: reachedContinuation.rebased(onto: unknownGoalLevel),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(
            unknownGoalSimulation.trainingGuidebotGoalCommandIsAvailable
        )
        XCTAssertTrue(
            unknownGoalSimulation.update(
                at: 100.1,
                input: .init(
                    requestsTrainingGuidebotActiveGoal: true
                )
            ).trainingOpeningFeedback.isEmpty
        )

        var earlierUnknownGoalLevel = level
        earlierUnknownGoalLevel.goals.insert(
            LevelGoal(
                status: 0x0000_0004 | 0x0000_0020,
                priority: cameraGoal.priority - 1,
                list: cameraGoal.list,
                name: "Earlier Unknown Goal",
                itemName: "Unknown",
                description: "",
                completionMessage: "",
                items: cameraGoal.items
            ),
            at: cameraGoalIndex
        )
        let earlierUnknownGoalSimulation = try GameSession(
            level: earlierUnknownGoalLevel,
            world: reachedContinuation.rebased(onto: earlierUnknownGoalLevel),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(
            earlierUnknownGoalSimulation
                .trainingGuidebotGoalCommandIsAvailable
        )
        XCTAssertTrue(
            earlierUnknownGoalSimulation.update(
                at: 100.1,
                input: .init(
                    requestsTrainingGuidebotActiveGoal: true
                )
            ).trainingOpeningFeedback.isEmpty
        )

        let reached = try GameSession(
            level: level,
            world: reachedContinuation.rebased(onto: level),
            resumedAtTimestamp: 100
        )

        XCTAssertTrue(reached.trainingGuidebotGoalCommandIsAvailable)
        let accepted = reached.update(
            at: 100.1,
            input: .init(requestsTrainingGuidebotActiveGoal: true)
        )
        XCTAssertEqual(accepted.trainingOpeningFeedback, [
            .init(
                hudMessages: ["GB: On my way!"],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: "GBotAcceptOrder.wav"
            ),
        ])
        XCTAssertEqual(
            accepted.trainingGuidebot?.destination,
            pickupPosition
        )

        var pickupContinuationObject = try XCTUnwrap(
            testWorldObject(reached.world)
        )
        pickupContinuationObject["playerPosition"] = [
            "x": Double(pickupPosition.x),
            "y": Double(pickupPosition.y),
            "z": Double(pickupPosition.z),
        ]
        let pickupBeforeArrival = try GameSession(
            level: level,
            world: (decodeTestWorld(pickupContinuationObject)).rebased(onto: level),
            resumedAtTimestamp: 150
        )
        let pickupFrame = pickupBeforeArrival.update(
            at: 150.1,
            input: .zero
        )
        XCTAssertTrue(
            pickupFrame.trainingOpeningFeedback.contains {
                $0.hudMessages == [
                    "Excellent.  You now have the Camera Monitor.  Press the Use Inventory key to activate it!",
                ]
            }
        )
        let heldContinuationObject = try XCTUnwrap(
            testWorldObject(pickupBeforeArrival.world)
        )
        let heldRobotState = try XCTUnwrap(
            heldContinuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        let heldGuidebot = try XCTUnwrap(
            heldRobotState["guidebot"] as? [String: Any]
        )
        XCTAssertEqual(heldGuidebot["task"] as? String, "activeGoal")
        XCTAssertNoThrow(
            try GameSession(
                level: level,
                world: pickupBeforeArrival.world.rebased(onto: level),
                resumedAtTimestamp: 160
            )
        )

        var arrival: PlayerSimulationFrame?
        var beforeArrival = accepted
        for frameIndex in 2...80 {
            let frame = reached.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: .zero
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.hudMessages
                    == ["GB: I am at the goal, coming back to get you."]
            }) {
                arrival = frame
                break
            }
            beforeArrival = frame
        }
        let returned = try XCTUnwrap(arrival)
        // The arrival DoMessage comes less than 2.5 s after the accepted
        // command's sound, so AIGame.cpp:4542 suppresses its sound.
        XCTAssertLessThan(returned.gameTime - accepted.gameTime, 2.5)
        XCTAssertEqual(returned.trainingOpeningFeedback, [
            .init(
                hudMessages: [
                    "GB: I am at the goal, coming back to get you.",
                ],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true
            ),
        ])
        let guidebotAtGoal = try XCTUnwrap(
            beforeArrival.trainingGuidebot?.position
        )
        let goalDelta = Vector3(
            x: guidebotAtGoal.x - pickupPosition.x,
            y: guidebotAtGoal.y - pickupPosition.y,
            z: guidebotAtGoal.z - pickupPosition.z
        )
        let centerDistance = sqrt(
            goalDelta.x * goalDelta.x
                + goalDelta.y * goalDelta.y
                + goalDelta.z * goalDelta.z
        )
        XCTAssertGreaterThan(centerDistance, 20)
        XCTAssertLessThanOrEqual(
            centerDistance,
            20 + 5.659_440_5 + 2 + 0.1
        )
        XCTAssertEqual(
            returned.trainingGuidebot?.destination,
            returned.playerView.camera.position
        )
        XCTAssertNotNil(returned.trainingGuidebot)

        let restored = try GameSession(
            level: level,
            world: reached.world.rebased(onto: level),
            resumedAtTimestamp: 200
        )
        let silentRestore = restored.update(at: 200.1, input: .zero)
        XCTAssertTrue(silentRestore.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            silentRestore.trainingGuidebot?.destination,
            silentRestore.playerView.camera.position
        )
        XCTAssertNotNil(silentRestore.trainingGuidebot)

        let followingLivePlayer = restored.update(
            at: 200.2,
            input: .init(forward: 1)
        )
        XCTAssertEqual(
            followingLivePlayer.trainingGuidebot?.destination,
            followingLivePlayer.playerView.camera.position
        )
        XCTAssertNoThrow(
            try GameSession(
                level: level,
                world: restored.world.rebased(onto: level),
                resumedAtTimestamp: 300
            )
        )

    }

    func testGuidebotReturnCompletionUsesPersistedAuthoritativeStreamAndCoupledGreetingFlareDraw()
        throws
    {
        let initialRandomState: UInt32 = 0x1357_9BDF
        func nextReleasedRandomState(_ state: UInt32) -> UInt32 {
            state &* 214_013 &+ 2_531_011
        }
        func releasedRandomValue(_ state: UInt32) -> UInt32 {
            (state >> 16) & 0x7fff
        }
        func randomState(
            in continuation: GameWorld
        ) throws -> UInt32? {
            let object = try XCTUnwrap(
                testWorldObject(continuation)
            )
            return (object["authoritativeRandomState"] as? NSNumber)?
                .uint32Value
        }
        func guidebotState(
            in continuation: GameWorld
        ) throws -> [String: Any] {
            let object = try XCTUnwrap(
                testWorldObject(continuation)
            )
            return try XCTUnwrap(
                object["trainingRobotGuidebotState"]
                    as? [String: Any]
            )
        }
        func restore(
            _ continuation: GameWorld,
            at timestamp: Double,
            checkpoint: String,
            level: Level
        ) throws -> GameSession {
            do {
                return try GameSession(
                    level: level,
                    world: continuation.rebased(onto: level),
                    resumedAtTimestamp: timestamp
                )
            } catch {
                XCTFail(
                    "\(checkpoint) continuation was rejected: \(error)"
                )
                throw error
            }
        }

        var unboundLevel = makeTrainingRASBot1DeathLevel()
        let playerIndex = try XCTUnwrap(unboundLevel.objects.firstIndex {
            $0.handle == unboundLevel.defaultPlayerBinding?.objectHandle
        })
        let pickupIndex = try XCTUnwrap(unboundLevel.objects.firstIndex {
            $0.handle == 6_167
        })
        let player = unboundLevel.objects[playerIndex]
        let pickupPosition = Vector3(
            x: player.position.x
                + player.orientation.forward.x * 300,
            y: player.position.y
                + player.orientation.forward.y * 300,
            z: player.position.z
                + player.orientation.forward.z * 300
        )
        unboundLevel.objects[pickupIndex].location = player.location
        unboundLevel.objects[pickupIndex].position = pickupPosition

        var levelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(unboundLevel)
            ) as? [String: Any]
        )
        var cameraChain = try XCTUnwrap(
            levelObject["trainingCameraMonitorChain"]
                as? [String: Any]
        )
        var returnChain = try XCTUnwrap(
            cameraChain["returnToShip"] as? [String: Any]
        )
        returnChain["greetingSoundSourceName"] = "GBotGreetB.wav"
        cameraChain["returnToShip"] = returnChain
        levelObject["trainingCameraMonitorChain"] = cameraChain
        let boundLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: levelObject)
        )
        let greetingResource = SourceResource(
            storedIndex: 1_268,
            sourceName: "GBotGreetB.wav"
        )
        let greetingPCM = Data(repeating: 0, count: 2)
        let greetingClip = CanonicalSoundClip(
            logicalName: "GBotGreetB1",
            sourceName: greetingResource.sourceName,
            sourceEntryIndex: greetingResource.storedIndex,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: greetingPCM,
            pcmSHA256: canonicalSHA256(greetingPCM),
            sourceArchive: "d3.hog",
            sourceSHA256: String(repeating: "6", count: 64),
            importVolume: 1
        )
        let profileFiles = boundLevel.source.profileFiles.contains {
            $0.relativePath == "d3.hog"
        } ? boundLevel.source.profileFiles : boundLevel.source.profileFiles + [
            .init(
                relativePath: "d3.hog",
                byteCount: 194_030_423,
                sha256:
                    "a0f1cb2c1a73da828a5fd4e80d6544b63da04e177dc2b894d9e6418296bc24c6"
            ),
        ]
        let admittedLevel = replacing(
            boundLevel,
            source: replacing(
                boundLevel.source,
                profileFiles: profileFiles
            ),
            soundClips: boundLevel.soundClips + [greetingClip],
            dependencyManifest: .init(
                current: boundLevel.dependencyManifest.current + [
                    .init(
                        category: "sound",
                        source: greetingResource,
                        state: "canonical-pcm-imported",
                        provenance: "synthetic canonical fixture"
                    ),
                ],
                historicalEagerBaseline:
                    boundLevel.dependencyManifest
                        .historicalEagerBaseline
            )
        )
        try admittedLevel.validate()
        var level = admittedLevel
        let routeRoomCenter = Vector3(
            x: player.position.x
                + player.orientation.forward.x * 150,
            y: player.position.y
                + player.orientation.forward.y * 150,
            z: player.position.z
                + player.orientation.forward.z * 150
        )
        level.rooms.append(
            makeSourceContainmentRoom(
                center: routeRoomCenter,
                texture: level.surfacePhysics[0].texture,
                sourceIndex: 39,
                halfExtent: 400
            )
        )
        level.objects[playerIndex].location = .room(39)
        level.objects[pickupIndex].location = .room(39)

        let newSession = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        var startObject = try XCTUnwrap(
            testWorldObject(newSession.world)
        )
        startObject["gameTime"] = 30.0
        startObject["authoritativeRandomState"] =
            NSNumber(value: initialRandomState)
        var galleryState = try XCTUnwrap(
            startObject["trainingGalleryBarrierState"]
                as? [String: Any]
        )
        galleryState["wasTriggered"] = true
        galleryState["markerLightDistance"] = 0
        startObject["trainingGalleryBarrierState"] = galleryState
        let start = try decodeTestWorld(startObject)
        let simulation = try restore(
            start,
            at: 100,
            checkpoint: "new-session seed",
            level: level
        )

        let deployed = simulation.update(
            at: 100.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertEqual(
            deployed.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
                ],
                voiceSourceName: "guidebotb.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        let afterBirthFlare = nextReleasedRandomState(initialRandomState)
        let afterBirthVisibility =
            nextReleasedRandomState(afterBirthFlare)
        XCTAssertEqual(
            try randomState(in: simulation.world),
            afterBirthVisibility,
            "F4 birth must consume SetMode's flare and visibility draws."
        )

        XCTAssertFalse(simulation.trainingGuidebotGoalCommandIsAvailable)
        let rejectedDuringBirth = simulation.update(
            at: 100.2,
            input: .init(requestsTrainingGuidebotActiveGoal: true)
        )
        XCTAssertTrue(rejectedDuringBirth.trainingOpeningFeedback.isEmpty)

        let afterAmbientFlare =
            nextReleasedRandomState(afterBirthVisibility)
        let afterAmbientVisibility =
            nextReleasedRandomState(afterAmbientFlare)
        let afterAmbientDirection =
            nextReleasedRandomState(afterAmbientVisibility)
        let afterFirstPowerupSchedule =
            nextReleasedRandomState(afterAmbientDirection)
        var sawAmbientTransition = false
        var checkedFirstAmbientFrame = false
        var timestamp = 100.2
        for _ in 0..<50 where !checkedFirstAmbientFrame {
            timestamp += 0.1
            _ = simulation.update(at: timestamp, input: .zero)
            let state = try guidebotState(
                in: simulation.world
            )
            if !sawAmbientTransition,
               state["guidebotMode"] as? String == "ambient" {
                sawAmbientTransition = true
                XCTAssertEqual(
                    try randomState(in: simulation.world),
                    afterAmbientDirection,
                    "Birth-to-ambient SetMode must consume flare, visibility, then direction."
                )
            } else if sawAmbientTransition {
                checkedFirstAmbientFrame = true
                XCTAssertEqual(
                    try randomState(in: simulation.world),
                    afterFirstPowerupSchedule,
                    "The first reached ambient frame must schedule the due powerup check before later timers."
                )
            }
        }
        XCTAssertTrue(sawAmbientTransition)
        XCTAssertTrue(checkedFirstAmbientFrame)
        XCTAssertTrue(simulation.trainingGuidebotGoalCommandIsAvailable)

        timestamp += 0.1
        let accepted = simulation.update(
            at: timestamp,
            input: .init(requestsTrainingGuidebotActiveGoal: true)
        )
        XCTAssertEqual(accepted.trainingOpeningFeedback, [
            .init(
                hudMessages: ["GB: On my way!"],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: "GBotAcceptOrder.wav"
            ),
        ])

        var sawActiveGoalArrival = false
        var resumedSimulation: GameSession?
        var greetingFrame: PlayerSimulationFrame?
        var resumedGreetingFrame: PlayerSimulationFrame?
        var greetingCount = 0

        for _ in 0..<300 {
            timestamp += 0.1
            let frame = simulation.update(at: timestamp, input: .zero)

            if frame.trainingOpeningFeedback.contains(where: {
                $0.hudMessages
                    == ["GB: I am at the goal, coming back to get you."]
            }) {
                sawActiveGoalArrival = true
                resumedSimulation = try restore(
                    simulation.world,
                    at: timestamp,
                    checkpoint: "physical active-goal arrival",
                    level: level
                )
            }

            var resumedFrame: PlayerSimulationFrame?
            if let resumedSimulation,
               sawActiveGoalArrival,
               !frame.trainingOpeningFeedback.contains(where: {
                   $0.hudMessages
                       == ["GB: I am at the goal, coming back to get you."]
               }) {
                resumedFrame = resumedSimulation.update(
                    at: timestamp,
                    input: .zero
                )
                XCTAssertEqual(
                    resumedFrame?.trainingGuidebot,
                    frame.trainingGuidebot
                )
                XCTAssertEqual(
                    resumedFrame?.trainingOpeningFeedback,
                    frame.trainingOpeningFeedback
                )
            }

            let greetings = frame.trainingOpeningFeedback.filter {
                $0.hudMessages == ["GB: Come on!"]
                    || $0.hudMessages == ["GB: Let's go!"]
            }
            greetingCount += greetings.count
            if let greeting = greetings.first {
                greetingFrame = frame
                resumedGreetingFrame = resumedFrame
                XCTAssertEqual(
                    greeting.soundSourceName,
                    "GBotGreetB.wav"
                )
                break
            }
        }

        XCTAssertTrue(sawActiveGoalArrival)
        XCTAssertEqual(greetingCount, 1)
        guard let greetingFrame else {
            XCTFail(
                "Physical circle-30 completion did not present the coupled Guidebot greeting."
            )
            return
        }
        XCTAssertEqual(
            resumedGreetingFrame?.trainingOpeningFeedback,
            greetingFrame.trainingOpeningFeedback
        )
        XCTAssertNotNil(greetingFrame.trainingGuidebot)
        XCTAssertFalse(
            simulation.trainingGuidebotReturnToShipCommandIsAvailable
        )

        let completedContinuation = simulation.world
        let completedRandomState = try XCTUnwrap(
            try randomState(in: completedContinuation)
        )
        let greetingRandomState =
            (completedRandomState &- 2_531_011) &* 0xB9B3_3155
        let expectedGreeting =
            releasedRandomValue(greetingRandomState) % 100 > 50
            ? "GB: Come on!"
            : "GB: Let's go!"
        XCTAssertEqual(
            greetingFrame.trainingOpeningFeedback.filter {
                $0.hudMessages == ["GB: Come on!"]
                    || $0.hudMessages == ["GB: Let's go!"]
            }.map(\.hudMessages),
            [[expectedGreeting]]
        )
        let completedState = try guidebotState(
            in: completedContinuation
        )
        let completedGuidebot = try XCTUnwrap(
            completedState["guidebot"] as? [String: Any]
        )
        XCTAssertEqual(
            completedGuidebot["task"] as? String,
            "escortPlayer"
        )
        XCTAssertEqual(
            completedState["returnGreetingWasPresented"] as? Bool,
            true
        )
        XCTAssertEqual(
            try XCTUnwrap(
                (completedState["returnTime"] as? NSNumber)?
                    .floatValue
            ),
            greetingFrame.systemsGameTime,
            accuracy: 0.000_1
        )
        let nextFlareDelay = try XCTUnwrap(
            (completedState["timeUntilNextFlare"] as? NSNumber)?
                .floatValue
        )
        XCTAssertEqual(
            nextFlareDelay,
            3
                + Float(releasedRandomValue(completedRandomState))
                    / 32_767,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try randomState(
                in: try XCTUnwrap(resumedSimulation).world
            ),
            completedRandomState,
            "Save/restore must preserve the same event-driven stream consumption."
        )

        let afterCompletion = simulation.update(
            at: timestamp + 0.1,
            input: .zero
        )
        XCTAssertTrue(afterCompletion.trainingOpeningFeedback.isEmpty)
        XCTAssertNotNil(afterCompletion.trainingGuidebot)
        XCTAssertEqual(
            try randomState(in: simulation.world),
            completedRandomState,
            "The packet stops before any later flare or ambient draw."
        )

        let restored = try restore(
            completedContinuation,
            at: 500,
            checkpoint: "completed return",
            level: level
        )
        let silent = restored.update(at: 500.1, input: .zero)
        XCTAssertTrue(silent.trainingOpeningFeedback.isEmpty)
        XCTAssertNotNil(silent.trainingGuidebot)
        XCTAssertEqual(
            try randomState(in: restored.world),
            completedRandomState
        )

        var returnCommandObject = try XCTUnwrap(
            testWorldObject(completedContinuation)
        )
        returnCommandObject["playerLocation"] = [
            "room": ["_0": 39],
        ]
        returnCommandObject["playerPosition"] = [
            "x": pickupPosition.x,
            "y": pickupPosition.y,
            "z": pickupPosition.z,
        ]
        var returnCommandRobotState = try XCTUnwrap(
            returnCommandObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var returnCommandGuidebot = try XCTUnwrap(
            returnCommandRobotState["guidebot"] as? [String: Any]
        )
        returnCommandGuidebot["destination"] = [
            "x": pickupPosition.x,
            "y": pickupPosition.y,
            "z": pickupPosition.z,
        ]
        returnCommandRobotState["guidebot"] = returnCommandGuidebot
        returnCommandObject["trainingRobotGuidebotState"] =
            returnCommandRobotState
        let returnCommandSimulation = try restore(
            decodeTestWorld(returnCommandObject),
            at: 550,
            checkpoint: "post-Script-059 return command",
            level: level
        )
        _ = returnCommandSimulation.update(at: 550.1, input: .zero)
        XCTAssertFalse(
            returnCommandSimulation
                .trainingGuidebotReturnToShipCommandIsAvailable
        )
        let usedCameraMonitor = returnCommandSimulation.update(
            at: 550.2,
            input: .init(usesInventory: true)
        )
        XCTAssertEqual(
            usedCameraMonitor.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Now recall the Guidebot by pressing F4 and selecting \"Return to Ship\".  Move to the next area when he returns.",
                ],
                voiceSourceName: "guidebotd.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        XCTAssertTrue(
            returnCommandSimulation
                .trainingGuidebotReturnToShipCommandIsAvailable
        )
        for frameIndex in 3...30 {
            _ = returnCommandSimulation.update(
                at: 550 + Double(frameIndex) * 0.1,
                input: .zero
            )
        }
        let requestedReturn = returnCommandSimulation.update(
            at: 553.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertEqual(
            requestedReturn.trainingOpeningFeedback,
            [.init(
                hudMessages: ["GB: Returning to ship."],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: "GBotAcceptOrder.wav"
            )]
        )
        XCTAssertFalse(
            returnCommandSimulation
                .trainingGuidebotReturnToShipCommandIsAvailable
        )
    }
}
