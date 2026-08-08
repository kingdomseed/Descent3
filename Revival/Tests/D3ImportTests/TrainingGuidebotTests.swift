import XCTest

extension WorldRenderingTests {
    func testTrainingGalleryTriggerClosesAnimatedBarrierOnceAndRestores() throws {
        let level = makeTrainingGalleryBarrierLevel()
        try level.validate()
        let simulation = PlayerSimulation(
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
        assertTrainingGalleryBarrier(level: simulation.level, rendersFaces: true)
        let playerStart = level.objects.first { $0.handle == 2_048 }!
        let blockedReturn = traceIndoorMovement(
            in: simulation.level,
            startRoom: triggered.playerView.roomSourceIndex,
            start: triggered.playerView.camera.position,
            end: playerStart.position,
            radius: triggered.playerView.collisionRadius
        )
        guard case .wallHit = blockedReturn.outcome else {
            return XCTFail("The closed force-field barrier must block the player")
        }

        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
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

        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        assertTrainingGalleryBarrier(level: restored.level, rendersFaces: true)
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
        XCTAssertNil(level.trainingDodgeAttempt)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        simulation.destroyTrainingRobot(handle: 4_112)
        assertTrainingGalleryBarrier(
            level: simulation.level,
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
        XCTAssertFalse(simulation.level.objectPresentations.contains {
            $0.objectHandle
                == level.trainingRobotGuidebotChain?.guidebotObjectHandle
                && $0.isVisible
        })
        assertTrainingGalleryBarrier(
            level: simulation.level,
            rendersFaces: true
        )

        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
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

        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        assertTrainingGalleryBarrier(
            level: restored.level,
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

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        var hostileRobotState = try XCTUnwrap(
            hostileObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        hostileRobotState["controlsWereRestored"] = true
        hostileObject["trainingRobotGuidebotState"] = hostileRobotState
        let staleRestoredControls = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: staleRestoredControls,
                resumedAtTimestamp: 200
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        hostileRobotState["controlsWereRestored"] = false
        hostileObject["trainingRobotGuidebotState"] = hostileRobotState
        var hostileGalleryState = try XCTUnwrap(
            hostileObject["trainingGalleryBarrierState"]
                as? [String: Any]
        )
        hostileGalleryState["markerLightDistance"] = 50
        hostileObject["trainingGalleryBarrierState"] = hostileGalleryState
        let staleOpenMarker = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: staleOpenMarker,
                resumedAtTimestamp: 300
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    func testScript036AfterScript060RestoresItsLaterBarrierState() throws {
        let level = makeTrainingRobotGuidebotLevel()
        try level.validate()
        let simulation = PlayerSimulation(
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
            level: simulation.level,
            rendersFaces: true
        )

        simulation.destroyTrainingRobot(handle: 4_112)
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
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
            level: simulation.level,
            rendersFaces: false
        )
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
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
        let restored = try PlayerSimulation(
            level: restorationLevel,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        assertTrainingGalleryBarrier(
            level: restored.level,
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
                openingControls: [.reverse]
            ),
            .all
        )
        let guidebotSimulation = PlayerSimulation(
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

        let triggeredContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(guidebotSimulation.continuation)
        )
        var hostileContinuation = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(triggeredContinuation)
            ) as? [String: Any]
        )
        var hostileRobotState = try XCTUnwrap(
            hostileContinuation["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        hostileRobotState["controlsWereRestored"] = true
        hostileContinuation["trainingRobotGuidebotState"] =
            hostileRobotState
        let decodedHostile = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileContinuation)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: decodedHostile,
                resumedAtTimestamp: 100
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
        hostileRobotState["guidebotContinuationWasPresented"] = true
        hostileContinuation["trainingRobotGuidebotState"] =
            hostileRobotState
        let consumedGuidebot = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileContinuation)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: consumedGuidebot,
                resumedAtTimestamp: 200
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
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
            level: guidebotSimulation.level,
            rendersFaces: true
        )
        let deployedContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(guidebotSimulation.continuation)
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
            try PlayerSimulation(
                level: deployedRestorationLevel,
                continuation: deployedContinuation,
                resumedAtTimestamp: 100
            )
        )
        let repeatedGuidebot = guidebotSimulation.update(
            at: triggerTimestamp + 0.2,
            input: .zero
        )
        XCTAssertTrue(repeatedGuidebot.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(repeatedGuidebot.enabledPlayerControls, .all)

        let destructionSimulation = PlayerSimulation(
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
        XCTAssertFalse(destructionSimulation.level.objects.contains {
            $0.handle == 4_112
        })
        assertTrainingGalleryBarrier(
            level: destructionSimulation.level,
            rendersFaces: false
        )

        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(destructionSimulation.continuation)
        )
        var consumedDestructionObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(continuation)
            ) as? [String: Any]
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
        let consumedDestruction = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: consumedDestructionObject
            )
        )
        let consumedDestructionSimulation = try PlayerSimulation(
            level: level,
            continuation: consumedDestruction,
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
        XCTAssertFalse(consumedDestructionSimulation.level.objects.contains {
            $0.handle == 4_112
        })
        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == 4_112
        })
        let restoredForwardControls = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 150
        )
        let restoredNeutralControls = try PlayerSimulation(
            level: level,
            continuation: continuation,
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
            level: consumedDestructionSimulation.level,
            rendersFaces: false
        )
    }

    func testTrainingGuidebotDeploymentReachesScript060InSameUpdate() throws {
        let simulation = PlayerSimulation(
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

        let seed = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = seed.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(seed.continuation)
            ) as? [String: Any]
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
        let reachedContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: continuationObject
            )
        )
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
        let unknownGoalSimulation = try PlayerSimulation(
            level: unknownGoalLevel,
            continuation: reachedContinuation,
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
        let earlierUnknownGoalSimulation = try PlayerSimulation(
            level: earlierUnknownGoalLevel,
            continuation: reachedContinuation,
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

        let reached = try PlayerSimulation(
            level: level,
            continuation: reachedContinuation,
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
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(reached.continuation)
            ) as? [String: Any]
        )
        pickupContinuationObject["playerPosition"] = [
            "x": Double(pickupPosition.x),
            "y": Double(pickupPosition.y),
            "z": Double(pickupPosition.z),
        ]
        let pickupBeforeArrival = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: pickupContinuationObject
                )
            ),
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
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    pickupBeforeArrival.continuation
                )
            ) as? [String: Any]
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
            try PlayerSimulation(
                level: level,
                continuation: pickupBeforeArrival.continuation,
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
        XCTAssertEqual(returned.trainingOpeningFeedback, [
            .init(
                hudMessages: [
                    "GB: I am at the goal, coming back to get you.",
                ],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: "GBotAcceptOrder.wav"
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

        let restored = try PlayerSimulation(
            level: level,
            continuation: reached.continuation,
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
        XCTAssertEqual(restored.continuation.schemaVersion, 7)
        XCTAssertNoThrow(
            try PlayerSimulation(
                level: level,
                continuation: restored.continuation,
                resumedAtTimestamp: 300
            )
        )

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(restored.continuation)
            ) as? [String: Any]
        )
        var hostileRobotState = try XCTUnwrap(
            hostileObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var hostileGuidebot = try XCTUnwrap(
            hostileRobotState["guidebot"] as? [String: Any]
        )
        var hostileDestination = try XCTUnwrap(
            hostileGuidebot["destination"] as? [String: Any]
        )
        hostileDestination["x"] =
            (hostileDestination["x"] as? Double ?? 0) + 1
        hostileGuidebot["destination"] = hostileDestination
        hostileRobotState["guidebot"] = hostileGuidebot
        hostileObject["trainingRobotGuidebotState"] = hostileRobotState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: hostileObject
                    )
                ),
                resumedAtTimestamp: 400
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var missingArrivalObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(restored.continuation)
            ) as? [String: Any]
        )
        var missingArrivalRobotState = try XCTUnwrap(
            missingArrivalObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        missingArrivalRobotState.removeValue(
            forKey: "activeGoalWasReached"
        )
        missingArrivalObject["trainingRobotGuidebotState"] =
            missingArrivalRobotState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: missingArrivalObject
                    )
                ),
                resumedAtTimestamp: 500
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
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
            in continuation: PlayerSimulationContinuation
        ) throws -> UInt32? {
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(continuation)
                ) as? [String: Any]
            )
            return (object["authoritativeRandomState"] as? NSNumber)?
                .uint32Value
        }
        func guidebotState(
            in continuation: PlayerSimulationContinuation
        ) throws -> [String: Any] {
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(continuation)
                ) as? [String: Any]
            )
            return try XCTUnwrap(
                object["trainingRobotGuidebotState"]
                    as? [String: Any]
            )
        }
        func restore(
            _ continuation: PlayerSimulationContinuation,
            at timestamp: Double,
            checkpoint: String,
            level: Level
        ) throws -> PlayerSimulation {
            do {
                return try PlayerSimulation(
                    level: level,
                    continuation: continuation,
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

        let newSession = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var startObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(newSession.continuation)
            ) as? [String: Any]
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
        let start = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: startObject)
        )
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
            try randomState(in: simulation.continuation),
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
                in: simulation.continuation
            )
            if !sawAmbientTransition,
               state["guidebotMode"] as? String == "ambient" {
                sawAmbientTransition = true
                XCTAssertEqual(
                    try randomState(in: simulation.continuation),
                    afterAmbientDirection,
                    "Birth-to-ambient SetMode must consume flare, visibility, then direction."
                )
            } else if sawAmbientTransition {
                checkedFirstAmbientFrame = true
                XCTAssertEqual(
                    try randomState(in: simulation.continuation),
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
        var resumedSimulation: PlayerSimulation?
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
                    simulation.continuation,
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

        let completedContinuation = simulation.continuation
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
                in: try XCTUnwrap(resumedSimulation).continuation
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
            try randomState(in: simulation.continuation),
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
            try randomState(in: restored.continuation),
            completedRandomState
        )

        var returnCommandObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(completedContinuation)
            ) as? [String: Any]
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
            JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: returnCommandObject
                )
            ),
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

        var legacyObject = startObject
        legacyObject.removeValue(forKey: "authoritativeRandomState")
        var legacyRobotState = try XCTUnwrap(
            legacyObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        for key in [
            "guidebotMode",
            "guidebotModeTime",
            "nextAmbientTime",
            "timeUntilNextPlayerVisibilityCheck",
            "timeUntilNextFlare",
            "nextPowerupCheckTime",
            "lastMessageSoundTime",
            "returnTime",
            "returnGreetingWasPresented",
        ] {
            legacyRobotState.removeValue(forKey: key)
        }
        legacyObject["trainingRobotGuidebotState"] =
            legacyRobotState
        XCTAssertNoThrow(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: legacyObject
                    )
                ),
                resumedAtTimestamp: 600
            )
        )

        var missingStreamObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(completedContinuation)
            ) as? [String: Any]
        )
        missingStreamObject.removeValue(
            forKey: "authoritativeRandomState"
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: missingStreamObject
                    )
                ),
                resumedAtTimestamp: 700
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var orphanedCooldownObject = legacyObject
        var orphanedCooldownState = try XCTUnwrap(
            orphanedCooldownObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        orphanedCooldownState["lastMessageSoundTime"] = 29.0
        orphanedCooldownObject["trainingRobotGuidebotState"] =
            orphanedCooldownState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: orphanedCooldownObject
                    )
                ),
                resumedAtTimestamp: 800
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var futureCooldownObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(completedContinuation)
            ) as? [String: Any]
        )
        var futureCooldownState = try XCTUnwrap(
            futureCooldownObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        futureCooldownState["lastMessageSoundTime"] =
            completedContinuation.gameTime + 1
        futureCooldownObject["trainingRobotGuidebotState"] =
            futureCooldownState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: futureCooldownObject
                    )
                ),
                resumedAtTimestamp: 900
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    func testGuidebotYellowFlareResetsBeforeEligibilityThenRetainsCarrierAndFirstParticle()
        throws
    {
        let level = makeTrainingGuidebotYellowFlareLevel()
        let initialRandomState: UInt32 = 0x1357_9BDF
        func nextState(_ state: UInt32) -> UInt32 {
            state &* 214_013 &+ 2_531_011
        }
        func expectedMotion(
            position: Vector3,
            velocity: Vector3,
            duration: Float
        ) -> (position: Vector3, velocity: Vector3) {
            let mass: Float = 0.1
            let drag: Float = 0.1
            let force = Vector3(
                x: 0,
                y: level.metadata.gravity * mass,
                z: 0
            )
            func component(
                _ position: Float,
                _ velocity: Float,
                _ force: Float
            ) -> (Float, Float) {
                let position = Double(position)
                let velocity = Double(velocity)
                let force = Double(force)
                let mass = Double(mass)
                let drag = Double(drag)
                let duration = Double(duration)
                let terminalVelocity = force / drag
                let massOverDrag = mass / drag
                let decay = exp(-(drag / mass) * duration)
                return (
                    Float(
                        position + terminalVelocity * duration
                            + massOverDrag
                                * (velocity - terminalVelocity)
                                * (1 - decay)
                    ),
                    Float(
                        (velocity - terminalVelocity) * decay
                            + terminalVelocity
                    )
                )
            }
            let x = component(position.x, velocity.x, force.x)
            let y = component(position.y, velocity.y, force.y)
            let z = component(position.z, velocity.z, force.z)
            return (
                .init(x: x.0, y: y.0, z: z.0),
                .init(x: x.1, y: y.1, z: z.1)
            )
        }
        func expectedParticleMotion(
            position: Vector3,
            velocity: Vector3,
            duration: Float
        ) -> (position: Vector3, velocity: Vector3) {
            func component(
                _ position: Float,
                _ velocity: Float,
                _ force: Float
            ) -> (Float, Float) {
                let terminalVelocity = Double(force) / 0.1
                let massOverDrag = 100.0 / 0.1
                let decay = exp(-(0.1 / 100.0) * Double(duration))
                return (
                    Float(
                        Double(position)
                            + terminalVelocity * Double(duration)
                            + massOverDrag
                                * (Double(velocity) - terminalVelocity)
                                * (1 - decay)
                    ),
                    Float(
                        (Double(velocity) - terminalVelocity) * decay
                            + terminalVelocity
                    )
                )
            }
            let x = component(position.x, velocity.x, 0)
            let y = component(position.y, velocity.y, -3_220)
            let z = component(position.z, velocity.z, 0)
            return (
                .init(x: x.0, y: y.0, z: z.0),
                .init(x: x.1, y: y.1, z: z.1)
            )
        }
        func continuationObject(
            _ continuation: PlayerSimulationContinuation
        ) throws -> [String: Any] {
            try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(continuation)
                ) as? [String: Any]
            )
        }
        func preparedContinuation(
            from continuation: PlayerSimulationContinuation,
            helperSlotsAreUsed: Bool,
            randomState: UInt32
        ) throws -> PlayerSimulationContinuation {
            var object = try continuationObject(continuation)
            object["authoritativeRandomState"] = NSNumber(value: randomState)
            var state = try XCTUnwrap(
                object["trainingRobotGuidebotState"] as? [String: Any]
            )
            state["guidebotMode"] = "ambient"
            state["guidebotModeTime"] = 0.1
            state["nextAmbientTime"] = 100.0
            state["timeUntilNextFlare"] = 0.05
            state["nextPowerupCheckTime"] = 100.0
            state["yellowFlareGoalSlots"] = [
                "slot1IsUsed": true,
                "slot2IsUsed": helperSlotsAreUsed,
                "slot3IsUsed": helperSlotsAreUsed,
            ]
            state["yellowFlares"] = []
            object["trainingRobotGuidebotState"] = state
            return try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        }
        func randomState(
            in continuation: PlayerSimulationContinuation
        ) throws -> UInt32 {
            let object = try continuationObject(continuation)
            return try XCTUnwrap(
                (object["authoritativeRandomState"] as? NSNumber)?
                    .uint32Value
            )
        }

        let seedSimulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = seedSimulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = try PlayerSimulation(
            level: level,
            continuation: seedSimulation.continuation,
            resumedAtTimestamp: 9
        )
        let blockedStart = try preparedContinuation(
            from: seedSimulation.continuation,
            helperSlotsAreUsed: true,
            randomState: initialRandomState
        )
        let blocked = try PlayerSimulation(
            level: level,
            continuation: blockedStart,
            resumedAtTimestamp: 10
        )
        let blockedFrame = blocked.update(at: 10.1, input: .zero)
        let stateAfterBlockedReset = nextState(initialRandomState)
        XCTAssertEqual(
            try randomState(in: blocked.continuation),
            stateAfterBlockedReset
        )
        XCTAssertTrue(blockedFrame.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertTrue(blockedFrame.trainingGuidebotYellowFlareParticles.isEmpty)
        XCTAssertFalse(blockedFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })

        let eligibleStart = try preparedContinuation(
            from: blocked.continuation,
            helperSlotsAreUsed: false,
            randomState: stateAfterBlockedReset
        )
        let eligible = try PlayerSimulation(
            level: level,
            continuation: eligibleStart,
            resumedAtTimestamp: 20
        )
        let fired = eligible.update(at: 20.1, input: .zero)
        let stateAfterEligibleReset = nextState(stateAfterBlockedReset)
        XCTAssertEqual(
            try randomState(in: eligible.continuation),
            stateAfterEligibleReset
        )
        XCTAssertEqual(
            fired.trainingOpeningFeedback.filter {
                $0.soundSourceName == "Flare.wav"
            }.count,
            1
        )
        let carrierAtCreation = try XCTUnwrap(
            fired.trainingGuidebotYellowFlares.only
        )
        XCTAssertTrue(fired.trainingGuidebotYellowFlareParticles.isEmpty)
        XCTAssertEqual(carrierAtCreation.lightDistance, 35)

        let emitted = eligible.update(at: 20.2, input: .zero)
        var expectedDrawState = stateAfterEligibleReset
        let particleAndLightDraws = (0..<7).map { _ -> UInt32 in
            expectedDrawState = nextState(expectedDrawState)
            return (expectedDrawState >> 16) & 0x7fff
        }
        XCTAssertEqual(
            try randomState(in: eligible.continuation),
            expectedDrawState
        )
        XCTAssertFalse(emitted.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
        let carrier = try XCTUnwrap(
            emitted.trainingGuidebotYellowFlares.only
        )
        XCTAssertEqual(carrier.model.sourceName, "FlareYellowBright.OOF")
        XCTAssertEqual(carrier.collisionRadius, 0.1)
        XCTAssertEqual(
            carrier.velocity,
            .init(
                x: carrier.orientation.forward.x * 100,
                y: carrier.orientation.forward.y * 100,
                z: carrier.orientation.forward.z * 100
            )
        )
        XCTAssertEqual(carrier.sourceLightDistance, 35)
        XCTAssertTrue((33...37).contains(carrier.lightDistance))
        let particle = try XCTUnwrap(
            emitted.trainingGuidebotYellowFlareParticles.only
        )
        XCTAssertEqual(particle.texture.sourceName, "yellowspark")
        let rawVelocity = Vector3(
            x: Float(Int(particleAndLightDraws[0] % 100) - 50),
            y: Float(particleAndLightDraws[1] % 100),
            z: Float(Int(particleAndLightDraws[2] % 100) - 50)
        )
        let rawMagnitude = sqrt(
            rawVelocity.x * rawVelocity.x
                + rawVelocity.y * rawVelocity.y
                + rawVelocity.z * rawVelocity.z
        )
        let expectedSpeed = Float(10 + particleAndLightDraws[3] % 10)
        let initialParticleVelocity = Vector3(
            x: rawVelocity.x / rawMagnitude * expectedSpeed,
            y: rawVelocity.y / rawMagnitude * expectedSpeed,
            z: rawVelocity.z / rawMagnitude * expectedSpeed
        )
        let initialParticlePosition = Vector3(
            x: carrierAtCreation.position.x
                - carrierAtCreation.orientation.forward.x * 0.1,
            y: carrierAtCreation.position.y
                - carrierAtCreation.orientation.forward.y * 0.1,
            z: carrierAtCreation.position.z
                - carrierAtCreation.orientation.forward.z * 0.1
        )
        let expectedParticle = expectedParticleMotion(
            position: initialParticlePosition,
            velocity: initialParticleVelocity,
            duration: 0.1
        )
        let emittedContinuationState = try XCTUnwrap(
            try continuationObject(eligible.continuation)[
                "trainingRobotGuidebotState"
            ] as? [String: Any]
        )
        let persistedParticle = try XCTUnwrap(
            (emittedContinuationState["yellowFlareParticles"]
                as? [[String: Any]])?.only
        )
        let persistedVelocity = try XCTUnwrap(
            persistedParticle["velocity"] as? [String: NSNumber]
        )
        XCTAssertEqual(
            try XCTUnwrap(persistedVelocity["x"]?.floatValue),
            expectedParticle.velocity.x,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(persistedVelocity["y"]?.floatValue),
            expectedParticle.velocity.y,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(persistedVelocity["z"]?.floatValue),
            expectedParticle.velocity.z,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            particle.size,
            0.2
                + Float(Int(particleAndLightDraws[4] % 11) - 5)
                    * 0.02,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            particle.lifetime,
            0.3
                + Float(Int(particleAndLightDraws[5] % 11) - 5)
                    * 0.03,
            accuracy: 0.000_001
        )
        XCTAssertEqual(particle.sourceSize, 0.2)
        XCTAssertEqual(particle.sourceLifetime, 0.3)
        XCTAssertEqual(
            particle.position.x,
            expectedParticle.position.x,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            particle.position.y,
            expectedParticle.position.y,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            particle.position.z,
            expectedParticle.position.z,
            accuracy: 0.000_001
        )
        XCTAssertEqual(particle.opacity, 1)
        XCTAssertEqual(
            carrier.lightDistance,
            35 + Float(Int(particleAndLightDraws[6] % 5) - 2)
        )
        XCTAssertNotEqual(carrier.position, carrierAtCreation.position)
        let preparedPlan = try makeMetalWorldPlan(
            level: eligible.level,
            playerView: emitted.playerView
        )
        let retainedPlan = try updateMetalWorldPlan(
            preparedPlan,
            level: eligible.level,
            playerView: emitted.playerView,
            trainingGuidebotYellowFlares:
                emitted.trainingGuidebotYellowFlares,
            trainingGuidebotYellowFlareParticles:
                emitted.trainingGuidebotYellowFlareParticles
        )
        XCTAssertTrue(retainedPlan.draws.contains {
            $0.model == carrier.model
                && $0.objectHandle == UInt32.max - 1_000
        })
        XCTAssertTrue(retainedPlan.draws.contains {
            $0.texture == particle.texture
                && $0.objectHandle == UInt32.max - 2_000
        })
        XCTAssertTrue(retainedPlan.draws.contains { draw in
            draw.vertices.contains {
                $0.dynamicLight.x > 0
                    || $0.dynamicLight.y > 0
                    || $0.dynamicLight.z > 0
            }
        })

        let player = try XCTUnwrap(eligible.level.objects.first {
            $0.handle == eligible.level.defaultPlayerBinding?.objectHandle
        })
        var attachedObject = try continuationObject(eligible.continuation)
        attachedObject["frameDuration"] = 0.1
        var attachedState = try XCTUnwrap(
            attachedObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        attachedState["timeUntilNextFlare"] = 3.5
        attachedState["yellowFlareParticles"] = []
        var attachedFlares = try XCTUnwrap(
            attachedState["yellowFlares"] as? [[String: Any]]
        )
        attachedFlares[0]["roomSourceIndex"] = {
            if case let .room(room) = player.location { return room }
            return -1
        }()
        attachedFlares[0]["position"] = [
            "x": player.position.x,
            "y": player.position.y,
            "z": player.position.z,
        ]
        attachedFlares[0]["orientation"] = [
            "right": [
                "x": player.orientation.right.x,
                "y": player.orientation.right.y,
                "z": player.orientation.right.z,
            ],
            "up": [
                "x": player.orientation.up.x,
                "y": player.orientation.up.y,
                "z": player.orientation.up.z,
            ],
            "forward": [
                "x": player.orientation.forward.x,
                "y": player.orientation.forward.y,
                "z": player.orientation.forward.z,
            ],
        ]
        attachedFlares[0]["velocity"] = ["x": 0, "y": 0, "z": 0]
        attachedFlares[0]["stuckObjectHandle"] = player.handle
        attachedFlares[0]["stuckObjectOffset"] = [
            "x": 0, "y": 0, "z": 0,
        ]
        attachedFlares[0]["stuckObjectOrientation"] = [
            "right": ["x": 1, "y": 0, "z": 0],
            "up": ["x": 0, "y": 1, "z": 0],
            "forward": ["x": 0, "y": 0, "z": 1],
        ]
        attachedState["yellowFlares"] = attachedFlares
        attachedObject["trainingRobotGuidebotState"] = attachedState
        let attached = try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: attachedObject)
            ),
            resumedAtTimestamp: 20.3
        )
        let attachedFrame = attached.update(
            at: 20.4,
            input: .init(forward: 1, yaw: 1)
        )
        let attachedCarrier = try XCTUnwrap(
            attachedFrame.trainingGuidebotYellowFlares.only
        )
        XCTAssertEqual(
            attachedCarrier.position,
            attachedFrame.playerView.camera.position
        )
        XCTAssertNotEqual(attachedCarrier.position, player.position)
        XCTAssertFalse(attachedFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
        let freshBaseRestore = try PlayerSimulation(
            level: level,
            continuation: attached.continuation,
            resumedAtTimestamp: 20.5
        )
        let freshBaseFrame = freshBaseRestore.update(
            at: 20.6,
            input: .zero
        )
        XCTAssertEqual(
            freshBaseFrame.trainingGuidebotYellowFlares.count,
            1
        )
        XCTAssertFalse(freshBaseFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })

        var incoherentAttachedObject = attachedObject
        var incoherentAttachedState = try XCTUnwrap(
            incoherentAttachedObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var incoherentAttachedFlares = try XCTUnwrap(
            incoherentAttachedState["yellowFlares"]
                as? [[String: Any]]
        )
        incoherentAttachedFlares[0]["position"] = [
            "x": player.position.x + 1,
            "y": player.position.y,
            "z": player.position.z,
        ]
        incoherentAttachedState["yellowFlares"] =
            incoherentAttachedFlares
        incoherentAttachedObject["trainingRobotGuidebotState"] =
            incoherentAttachedState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: eligible.level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: incoherentAttachedObject
                    )
                ),
                resumedAtTimestamp: 20.3
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var outsideObject = try continuationObject(eligible.continuation)
        var outsideState = try XCTUnwrap(
            outsideObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var outsideFlares = try XCTUnwrap(
            outsideState["yellowFlares"] as? [[String: Any]]
        )
        outsideFlares[0]["position"] = [
            "x": 100_000, "y": 100_000, "z": 100_000,
        ]
        outsideState["yellowFlares"] = outsideFlares
        outsideObject["trainingRobotGuidebotState"] = outsideState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: eligible.level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(withJSONObject: outsideObject)
                ),
                resumedAtTimestamp: 20.3
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var nearWallObject = try continuationObject(
            eligible.continuation
        )
        nearWallObject["frameDuration"] = 0.01
        var nearWallState = try XCTUnwrap(
            nearWallObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        nearWallState["timeUntilNextFlare"] = 3.5
        nearWallState["yellowFlareParticles"] = []
        var nearWallFlares = try XCTUnwrap(
            nearWallState["yellowFlares"] as? [[String: Any]]
        )
        var nearWallFlare = try XCTUnwrap(nearWallFlares.only)
        let roomCenter = try XCTUnwrap(
            eligible.level.rooms.first { $0.sourceIndex == 1 }
        ).pathPoint
        let forward = carrier.orientation.forward
        let maximumComponent = max(
            abs(forward.x),
            abs(forward.y),
            abs(forward.z)
        )
        let nearWallDistance =
            (500 - carrier.collisionRadius) / maximumComponent - 0.2
        nearWallFlare["position"] = [
            "x": Double(roomCenter.x + forward.x * nearWallDistance),
            "y": Double(roomCenter.y + forward.y * nearWallDistance),
            "z": Double(roomCenter.z + forward.z * nearWallDistance),
        ]
        nearWallFlare["velocity"] = [
            "x": Double(forward.x * 100),
            "y": Double(forward.y * 100),
            "z": Double(forward.z * 100),
        ]
        nearWallFlare["lastParticleDropTime"] =
            nearWallObject["gameTime"]
        nearWallFlares[0] = nearWallFlare
        nearWallState["yellowFlares"] = nearWallFlares
        nearWallObject["trainingRobotGuidebotState"] = nearWallState
        let nearWall = try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: nearWallObject)
            ),
            resumedAtTimestamp: 21
        )
        let stuckFrame = nearWall.update(at: 21.01, input: .zero)
        XCTAssertEqual(
            try XCTUnwrap(stuckFrame.trainingGuidebotYellowFlares.only)
                .velocity,
            .zero
        )
        XCTAssertTrue(
            stuckFrame.trainingGuidebotYellowFlareParticles.isEmpty
        )
        XCTAssertFalse(stuckFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })

        var exactZeroObject = try continuationObject(nearWall.continuation)
        exactZeroObject["frameDuration"] = 0.01
        var exactZeroState = try XCTUnwrap(
            exactZeroObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        exactZeroState["timeUntilNextFlare"] = 3.5
        exactZeroState["yellowFlareParticles"] = []
        var exactZeroFlares = try XCTUnwrap(
            exactZeroState["yellowFlares"] as? [[String: Any]]
        )
        exactZeroFlares[0]["lifeRemaining"] = 0.01
        exactZeroFlares[0]["lastParticleDropTime"] =
            exactZeroObject["gameTime"]
        exactZeroState["yellowFlares"] = exactZeroFlares
        exactZeroObject["trainingRobotGuidebotState"] = exactZeroState
        let exactZero = try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: exactZeroObject)
            ),
            resumedAtTimestamp: 21.5
        )
        let exactZeroFrame = exactZero.update(at: 21.51, input: .zero)
        XCTAssertEqual(
            try XCTUnwrap(exactZeroFrame.trainingGuidebotYellowFlares.only)
                .lifeRemaining,
            0,
            accuracy: 0.000_001
        )

        var expiryObject = try continuationObject(nearWall.continuation)
        expiryObject["frameDuration"] = 0.01
        var expiryState = try XCTUnwrap(
            expiryObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        expiryState["timeUntilNextFlare"] = 3.5
        expiryState["yellowFlareParticles"] = []
        var expiringFlares = try XCTUnwrap(
            expiryState["yellowFlares"] as? [[String: Any]]
        )
        expiringFlares[0]["position"] = [
            "x": roomCenter.x,
            "y": roomCenter.y,
            "z": roomCenter.z,
        ]
        expiringFlares[0]["velocity"] = ["x": 0, "y": 0, "z": 0]
        expiringFlares[0]["lifeRemaining"] = 0.005
        expiringFlares[0]["lastParticleDropTime"] = 0
        expiryState["yellowFlares"] = expiringFlares
        expiryObject["trainingRobotGuidebotState"] = expiryState
        let expiryInitialRandomState = try randomState(
            in: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: expiryObject)
            )
        )
        let expiry = try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: expiryObject)
            ),
            resumedAtTimestamp: 22
        )
        let expiredFrame = expiry.update(at: 22.01, input: .zero)
        XCTAssertTrue(expiredFrame.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareParticles.count,
            1
        )
        let timeoutExplosion = try XCTUnwrap(
            expiredFrame.trainingGuidebotYellowFlareTimeoutExplosions.only
        )
        XCTAssertEqual(timeoutExplosion.texture.sourceName, "FlarePuff")
        XCTAssertEqual(timeoutExplosion.size, 2)
        XCTAssertEqual(timeoutExplosion.lifetime, 0.2)
        XCTAssertEqual(timeoutExplosion.lifeRemaining, 0.19)
        XCTAssertEqual(timeoutExplosion.opacity, 1)
        XCTAssertEqual(timeoutExplosion.position, roomCenter)
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .map(\.sourceAttemptIndex),
            Array(0..<9)
        )
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .map(\.sourceObjectSlot),
            [17, 8, 41, 42, 43, 44, 45, 46, 47]
        )
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .filter(\.receivedControlOnCreationFrame)
                .map(\.sourceAttemptIndex),
            [0, 2, 3, 4, 5, 6, 7, 8]
        )
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .map(\.lifeRemaining),
            [0.19, 0.2, 0.19, 0.19, 0.19, 0.19, 0.19, 0.19, 0.19]
        )
        XCTAssertTrue(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .allSatisfy { $0.lightDistance == 6 }
        )
        let centerSpark = try XCTUnwrap(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks.first {
                $0.sourceAttemptIndex == 0
            }
        )
        let centerOrigin = Vector3(
            x: roomCenter.x + centerSpark.orientation.forward.x * 0.05,
            y: roomCenter.y + centerSpark.orientation.forward.y * 0.05,
            z: roomCenter.z + centerSpark.orientation.forward.z * 0.05
        )
        let centerInitialVelocity = Vector3(
            x: centerSpark.orientation.forward.x * 17,
            y: centerSpark.orientation.forward.y * 17,
            z: centerSpark.orientation.forward.z * 17
        )
        let centerExpected = expectedMotion(
            position: centerOrigin,
            velocity: centerInitialVelocity,
            duration: 0.01
        )
        XCTAssertEqual(centerSpark.position.x, centerExpected.position.x)
        XCTAssertEqual(centerSpark.position.y, centerExpected.position.y)
        XCTAssertEqual(centerSpark.position.z, centerExpected.position.z)
        XCTAssertEqual(centerSpark.velocity.x, centerExpected.velocity.x)
        XCTAssertEqual(centerSpark.velocity.y, centerExpected.velocity.y)
        XCTAssertEqual(centerSpark.velocity.z, centerExpected.velocity.z)
        let lowerSlotSpark = try XCTUnwrap(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks.first {
                $0.sourceObjectSlot == 8
            }
        )
        XCTAssertEqual(lowerSlotSpark.position, centerOrigin)
        XCTAssertEqual(
            lowerSlotSpark.velocity,
            .init(
                x: lowerSlotSpark.orientation.forward.x * 17,
                y: lowerSlotSpark.orientation.forward.y * 17,
                z: lowerSlotSpark.orientation.forward.z * 17
            )
        )
        XCTAssertEqual(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparkParticles
                .count,
            8
        )
        let timeoutPlan = try updateMetalWorldPlan(
            try makeMetalWorldPlan(
                level: expiry.level,
                playerView: expiredFrame.playerView
            ),
            level: expiry.level,
            playerView: expiredFrame.playerView,
            trainingGuidebotYellowFlareParticles:
                expiredFrame.trainingGuidebotYellowFlareParticles,
            trainingGuidebotYellowFlareTimeoutExplosions:
                expiredFrame.trainingGuidebotYellowFlareTimeoutExplosions,
            trainingGuidebotYellowFlareTimeoutSparks:
                expiredFrame.trainingGuidebotYellowFlareTimeoutSparks,
            trainingGuidebotYellowFlareTimeoutSparkParticles:
                expiredFrame
                    .trainingGuidebotYellowFlareTimeoutSparkParticles
        )
        XCTAssertTrue(timeoutPlan.draws.contains {
            $0.texture?.sourceName == "FlarePuff"
                && $0.objectHandle == UInt32.max - 3_000
        })
        XCTAssertEqual(
            timeoutPlan.draws.filter {
                guard let handle = $0.objectHandle else { return false }
                return handle <= UInt32.max - 4_000
                    && handle > UInt32.max - 4_009
            }.count,
            9
        )
        XCTAssertTrue(timeoutPlan.draws.contains { draw in
            guard let handle = draw.objectHandle,
                  handle <= UInt32.max - 4_000,
                  handle > UInt32.max - 4_009 else {
                return false
            }
            return draw.vertices.contains {
                $0.dynamicLight.x > 0
                    || $0.dynamicLight.y > 0
                    || $0.dynamicLight.z > 0
            }
        })
        XCTAssertEqual(
            try randomState(in: expiry.continuation),
            (0..<54).reduce(expiryInitialRandomState) {
                state, _ in nextState(state)
            }
        )

        var longCreationFrameObject = expiryObject
        longCreationFrameObject["frameDuration"] = 0.21
        let longCreationFrameStart = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: longCreationFrameObject
            )
        )
        let longCreationFrame = try PlayerSimulation(
            level: eligible.level,
            continuation: longCreationFrameStart,
            resumedAtTimestamp: 22.5
        )
        let longCreationFrameResult = longCreationFrame.update(
            at: 22.71,
            input: .zero
        )
        XCTAssertTrue(
            longCreationFrameResult
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty
        )
        XCTAssertEqual(
            longCreationFrameResult
                .trainingGuidebotYellowFlareTimeoutSparks
                .map(\.sourceAttemptIndex),
            [1]
        )
        XCTAssertTrue(
            longCreationFrameResult
                .trainingGuidebotYellowFlareTimeoutSparks
                .allSatisfy { $0.lifeRemaining >= 0 }
        )
        XCTAssertTrue(
            longCreationFrameResult
                .trainingGuidebotYellowFlareTimeoutSparkParticles
                .allSatisfy { $0.lifeRemaining >= 0 }
        )
        XCTAssertEqual(
            try randomState(in: longCreationFrame.continuation),
            (0..<54).reduce(expiryInitialRandomState) {
                state, _ in nextState(state)
            }
        )
        XCTAssertNoThrow(try PlayerSimulation(
            level: eligible.level,
            continuation: longCreationFrame.continuation,
            resumedAtTimestamp: 22.72
        ))
        let postExpiryRandomState = try randomState(
            in: expiry.continuation
        )
        XCTAssertFalse(expiredFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
        let expiredRestore = try PlayerSimulation(
            level: eligible.level,
            continuation: expiry.continuation,
            resumedAtTimestamp: 23
        )
        let expiredRestoreFrame = expiredRestore.update(
            at: 23.01,
            input: .zero
        )
        XCTAssertTrue(
            expiredRestoreFrame.trainingGuidebotYellowFlares.isEmpty
        )
        XCTAssertEqual(
            expiredRestoreFrame
                .trainingGuidebotYellowFlareTimeoutExplosions.count,
            1
        )
        XCTAssertEqual(
            expiredRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparks.count,
            9
        )
        XCTAssertEqual(
            expiredRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.count,
            9
        )
        XCTAssertEqual(
            try randomState(in: expiredRestore.continuation),
            (0..<6).reduce(postExpiryRandomState) {
                state, _ in nextState(state)
            }
        )
        XCTAssertTrue(
            expiredRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparks
                .allSatisfy { $0.lightDistance == 6 }
        )
        let restoredCenterSpark = try XCTUnwrap(
            expiredRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparks.first {
                    $0.sourceAttemptIndex == 0
                }
        )
        let restoredCenterExpected = expectedMotion(
            position: centerSpark.position,
            velocity: centerSpark.velocity,
            duration: 0.01
        )
        XCTAssertEqual(
            restoredCenterSpark.position.x,
            restoredCenterExpected.position.x
        )
        XCTAssertEqual(
            restoredCenterSpark.position.y,
            restoredCenterExpected.position.y
        )
        XCTAssertEqual(
            restoredCenterSpark.position.z,
            restoredCenterExpected.position.z
        )
        XCTAssertEqual(
            restoredCenterSpark.velocity.x,
            restoredCenterExpected.velocity.x
        )
        XCTAssertEqual(
            restoredCenterSpark.velocity.y,
            restoredCenterExpected.velocity.y
        )
        XCTAssertEqual(
            restoredCenterSpark.velocity.z,
            restoredCenterExpected.velocity.z
        )
        XCTAssertFalse(expiredRestoreFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
        let boundedTimeoutRandomState = try randomState(
            in: expiredRestore.continuation
        )
        let boundedTimeoutFrame = expiredRestore.update(
            at: 23.02,
            input: .zero
        )
        XCTAssertEqual(
            try XCTUnwrap(
                boundedTimeoutFrame
                    .trainingGuidebotYellowFlareTimeoutExplosions.only
            ).lifeRemaining,
            0.17,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                boundedTimeoutFrame
                    .trainingGuidebotYellowFlareTimeoutSparks.first {
                        $0.sourceAttemptIndex == 0
                    }
            ).lifeRemaining,
            0.17,
            accuracy: 0.000_001
        )
        XCTAssertNotEqual(
            try XCTUnwrap(
                boundedTimeoutFrame
                    .trainingGuidebotYellowFlareTimeoutSparkParticles.first
            ).position,
            try XCTUnwrap(
                expiredRestoreFrame
                    .trainingGuidebotYellowFlareTimeoutSparkParticles.first
            ).position
        )
        XCTAssertEqual(
            try randomState(in: expiredRestore.continuation),
            boundedTimeoutRandomState
        )

        var finalNegativeObject = try continuationObject(
            expiry.continuation
        )
        finalNegativeObject["frameDuration"] = 0.01
        var finalNegativeState = try XCTUnwrap(
            finalNegativeObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        finalNegativeState["timeUntilNextFlare"] = 3.5
        var finalNegativeSparks = try XCTUnwrap(
            finalNegativeState["yellowFlareTimeoutSparks"]
                as? [[String: Any]]
        )
        let finalNegativeGameTime = try XCTUnwrap(
            (finalNegativeObject["gameTime"] as? NSNumber)?.floatValue
        )
        for index in finalNegativeSparks.indices {
            if finalNegativeSparks[index]["receivedControlOnCreationFrame"]
                as? Bool == true {
                finalNegativeSparks[index]["lifeRemaining"] = 0.005
                finalNegativeSparks[index]["lastParticleDropTime"] =
                    finalNegativeGameTime
            } else {
                finalNegativeSparks[index]["lifeRemaining"] = 0.1
            }
        }
        let finalNegativeAttemptIndex = try XCTUnwrap(
            finalNegativeSparks.firstIndex {
                $0["sourceAttemptIndex"] as? Int == 0
            }
        )
        let survivingAttemptIndex = try XCTUnwrap(
            finalNegativeSparks.firstIndex {
                $0["sourceAttemptIndex"] as? Int == 1
            }
        )
        finalNegativeSparks[finalNegativeAttemptIndex][
            "lastParticleDropTime"
        ] = 0
        finalNegativeSparks[survivingAttemptIndex][
            "lastParticleDropTime"
        ] = finalNegativeGameTime
        finalNegativeState["yellowFlareTimeoutSparks"] =
            finalNegativeSparks
        finalNegativeObject["trainingRobotGuidebotState"] =
            finalNegativeState
        let finalNegativeStart = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: finalNegativeObject)
        )
        let finalNegativeRandomState = try randomState(
            in: finalNegativeStart
        )
        let finalNegative = try PlayerSimulation(
            level: eligible.level,
            continuation: finalNegativeStart,
            resumedAtTimestamp: 24
        )
        let finalNegativeFrame = finalNegative.update(
            at: 24.01,
            input: .zero
        )
        XCTAssertEqual(
            finalNegativeFrame.trainingGuidebotYellowFlareTimeoutSparks
                .map(\.sourceAttemptIndex),
            [1]
        )
        XCTAssertEqual(
            finalNegativeFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.count,
            9
        )
        XCTAssertEqual(
            try randomState(in: finalNegative.continuation),
            (0..<6).reduce(finalNegativeRandomState) {
                state, _ in nextState(state)
            }
        )

        var exactZeroChildObject = try continuationObject(
            expiry.continuation
        )
        exactZeroChildObject["frameDuration"] = 0.01
        var exactZeroChildState = try XCTUnwrap(
            exactZeroChildObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var exactZeroChildSparks = try XCTUnwrap(
            exactZeroChildState["yellowFlareTimeoutSparks"]
                as? [[String: Any]]
        )
        for index in exactZeroChildSparks.indices
        where exactZeroChildSparks[index][
            "receivedControlOnCreationFrame"
        ] as? Bool == true {
            exactZeroChildSparks[index]["lifeRemaining"] = 0.01
            exactZeroChildSparks[index]["lastParticleDropTime"] =
                finalNegativeGameTime
        }
        let exactZeroChildStartPosition = try XCTUnwrap(
            exactZeroChildSparks.first {
                $0["sourceAttemptIndex"] as? Int == 0
            }?["position"] as? [String: NSNumber]
        )
        exactZeroChildState["yellowFlareTimeoutSparks"] =
            exactZeroChildSparks
        exactZeroChildObject["trainingRobotGuidebotState"] =
            exactZeroChildState
        let exactZeroChild = try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: exactZeroChildObject
                )
            ),
            resumedAtTimestamp: 24.5
        )
        let exactZeroChildFrame = exactZeroChild.update(
            at: 24.51,
            input: .zero
        )
        let exactZeroControlledChild = try XCTUnwrap(
            exactZeroChildFrame
                .trainingGuidebotYellowFlareTimeoutSparks.first {
                    $0.sourceAttemptIndex == 0
                }
        )
        XCTAssertEqual(
            exactZeroControlledChild.lifeRemaining,
            0,
            accuracy: 0.000_001
        )
        XCTAssertNotEqual(
            exactZeroControlledChild.position.y,
            try XCTUnwrap(
                exactZeroChildStartPosition["y"]?.floatValue
            )
        )
        XCTAssertEqual(exactZeroControlledChild.lightDistance, 6)

        var exactZeroVisualObject = try continuationObject(
            expiry.continuation
        )
        exactZeroVisualObject["frameDuration"] = 0.01
        var exactZeroVisualState = try XCTUnwrap(
            exactZeroVisualObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var exactZeroVisualParticles = try XCTUnwrap(
            exactZeroVisualState["yellowFlareTimeoutSparkParticles"]
                as? [[String: Any]]
        )
        exactZeroVisualParticles[0]["lifeRemaining"] = 0.01
        exactZeroVisualState["yellowFlareTimeoutSparkParticles"] =
            exactZeroVisualParticles
        exactZeroVisualObject["trainingRobotGuidebotState"] =
            exactZeroVisualState
        let exactZeroVisual = try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: exactZeroVisualObject
                )
            ),
            resumedAtTimestamp: 25
        )
        let exactZeroVisualFrame = exactZeroVisual.update(
            at: 25.01,
            input: .zero
        )
        XCTAssertTrue(
            exactZeroVisualFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles
                .contains { abs($0.lifeRemaining) < 0.000_001 }
        )

        func capacityContinuation(
            count: Int
        ) throws -> PlayerSimulationContinuation {
            var object = try continuationObject(expiry.continuation)
            object["frameDuration"] = 0.01
            var state = try XCTUnwrap(
                object["trainingRobotGuidebotState"] as? [String: Any]
            )
            var sparks = try XCTUnwrap(
                state["yellowFlareTimeoutSparks"] as? [[String: Any]]
            )
            for index in sparks.indices {
                sparks[index]["lastParticleDropTime"] = 0
            }
            let particles = try XCTUnwrap(
                state["yellowFlareTimeoutSparkParticles"]
                    as? [[String: Any]]
            )
            state["yellowFlareTimeoutSparks"] = sparks
            state["yellowFlareTimeoutSparkParticles"] =
                (0..<count).map { particles[$0 % particles.count] }
            object["trainingRobotGuidebotState"] = state
            return try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        }
        let fullCapacityStart = try capacityContinuation(count: 54)
        let fullCapacityRandomState = try randomState(
            in: fullCapacityStart
        )
        let fullCapacity = try PlayerSimulation(
            level: eligible.level,
            continuation: fullCapacityStart,
            resumedAtTimestamp: 26
        )
        let fullCapacityFrame = fullCapacity.update(
            at: 26.01,
            input: .zero
        )
        XCTAssertEqual(
            fullCapacityFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.count,
            54
        )
        XCTAssertEqual(
            try randomState(in: fullCapacity.continuation),
            fullCapacityRandomState
        )
        let oneFreeStart = try capacityContinuation(count: 53)
        let oneFreeRandomState = try randomState(in: oneFreeStart)
        let oneFree = try PlayerSimulation(
            level: eligible.level,
            continuation: oneFreeStart,
            resumedAtTimestamp: 26.5
        )
        XCTAssertEqual(
            oneFree.update(at: 26.51, input: .zero)
                .trainingGuidebotYellowFlareTimeoutSparkParticles.count,
            54
        )
        XCTAssertEqual(
            try randomState(in: oneFree.continuation),
            (0..<6).reduce(oneFreeRandomState) {
                state, _ in nextState(state)
            }
        )

        let timeoutDefinition = try XCTUnwrap(
            eligible.level.trainingRobotGuidebotChain?
                .yellowFlare?.timeout
        )
        let animationFrames = try XCTUnwrap(
            timeoutDefinition.childAnimationFrames
        )
        let sourceFrameTime = try XCTUnwrap(
            timeoutDefinition.childSourceFrameTime
        )
        XCTAssertEqual(animationFrames.count, 6)
        XCTAssertTrue(
            expiredFrame.trainingGuidebotYellowFlareTimeoutSparks
                .allSatisfy {
                    $0.texture
                        == animationFrames[
                            Int(expiredFrame.systemsGameTime / sourceFrameTime)
                                % animationFrames.count
                        ]
                }
        )
        XCTAssertTrue(
            expiredFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles
                .allSatisfy {
                    $0.texture == animationFrames[0] && $0.opacity == 1
                }
        )

        var agedVisualObject = try continuationObject(
            expiry.continuation
        )
        agedVisualObject["frameDuration"] = 0.01
        let agedVisualGameTime = try XCTUnwrap(
            (agedVisualObject["gameTime"] as? NSNumber)?.floatValue
        )
        var agedVisualState = try XCTUnwrap(
            agedVisualObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var agedVisualParticles = try XCTUnwrap(
            agedVisualState["yellowFlareTimeoutSparkParticles"]
                as? [[String: Any]]
        )
        let testedNormalizedAges = animationFrames.indices.map {
            (Float($0) + 0.5) / Float(animationFrames.count)
        }
        for index in animationFrames.indices {
            let normalizedAge = testedNormalizedAges[index]
            agedVisualParticles[index]["lifetime"] = 0.3
            agedVisualParticles[index]["lifeRemaining"] =
                0.3 * (1 - normalizedAge)
            agedVisualParticles[index]["creationTime"] =
                agedVisualGameTime - 0.3 * normalizedAge
        }
        agedVisualState["yellowFlareTimeoutSparkParticles"] =
            agedVisualParticles
        agedVisualObject["trainingRobotGuidebotState"] =
            agedVisualState
        let agedVisual = try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: agedVisualObject
                )
            ),
            resumedAtTimestamp: 27
        )
        let agedVisualFrame = agedVisual.update(
            at: 27.01,
            input: .zero
        )
        let presentedAgedParticles = Array(
            agedVisualFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles
                .prefix(animationFrames.count)
        )
        XCTAssertEqual(
            presentedAgedParticles.map(\.texture),
            animationFrames
        )
        let finalTestedNormalizedAge = try XCTUnwrap(
            testedNormalizedAges.last
        )
        XCTAssertEqual(
            try XCTUnwrap(presentedAgedParticles.last).opacity,
            2 * (1 - finalTestedNormalizedAge),
            accuracy: 0.000_1
        )

        let quiescing = try PlayerSimulation(
            level: eligible.level,
            continuation: expiry.continuation,
            resumedAtTimestamp: 28
        )
        var quiescentFrame: PlayerSimulationFrame?
        for frameIndex in 1...100 {
            let candidate = quiescing.update(
                at: 28 + Double(frameIndex) * 0.01,
                input: .zero
            )
            if candidate
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty,
               candidate.trainingGuidebotYellowFlareTimeoutSparks.isEmpty,
               candidate
                .trainingGuidebotYellowFlareTimeoutSparkParticles.isEmpty {
                quiescentFrame = candidate
                break
            }
        }
        let terminalFrame = try XCTUnwrap(quiescentFrame)
        let terminalObject = try continuationObject(
            quiescing.continuation
        )
        let terminalState = try XCTUnwrap(
            terminalObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(
            terminalState["yellowFlareTimeoutReachedFollowingFrame"]
                as? Bool,
            true
        )
        let terminalRestore = try PlayerSimulation(
            level: eligible.level,
            continuation: quiescing.continuation,
            resumedAtTimestamp: 30
        )
        let terminalRestoreFrame = terminalRestore.update(
            at: 30.01,
            input: .zero
        )
        XCTAssertTrue(
            terminalRestoreFrame
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty
        )
        XCTAssertTrue(
            terminalRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparks.isEmpty
        )
        XCTAssertTrue(
            terminalRestoreFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.isEmpty
        )
        let terminalPlan = try updateMetalWorldPlan(
            timeoutPlan,
            level: eligible.level,
            playerView: terminalFrame.playerView,
            trainingGuidebotYellowFlareParticles:
                terminalFrame.trainingGuidebotYellowFlareParticles,
            trainingGuidebotYellowFlareTimeoutExplosions:
                terminalFrame.trainingGuidebotYellowFlareTimeoutExplosions,
            trainingGuidebotYellowFlareTimeoutSparks:
                terminalFrame.trainingGuidebotYellowFlareTimeoutSparks,
            trainingGuidebotYellowFlareTimeoutSparkParticles:
                terminalFrame
                    .trainingGuidebotYellowFlareTimeoutSparkParticles
        )
        XCTAssertFalse(terminalPlan.draws.contains { draw in
            guard let handle = draw.objectHandle else { return false }
            return handle == UInt32.max - 3_000
                || (handle <= UInt32.max - 4_000
                    && handle > UInt32.max - 4_009)
                || (handle <= UInt32.max - 5_000
                    && handle > UInt32.max - 5_054)
        })

        var laterParentObject = try continuationObject(
            quiescing.continuation
        )
        laterParentObject["frameDuration"] = 0.01
        var laterParentState = try XCTUnwrap(
            laterParentObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        laterParentState["timeUntilNextFlare"] = 0.005
        laterParentObject["trainingRobotGuidebotState"] =
            laterParentState
        let laterParent = try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: laterParentObject
                )
            ),
            resumedAtTimestamp: 31
        )
        let laterParentFrame = laterParent.update(
            at: 31.01,
            input: .zero
        )
        XCTAssertEqual(laterParentFrame.trainingGuidebotYellowFlares.count, 1)
        var laterExpiryObject = try continuationObject(
            laterParent.continuation
        )
        laterExpiryObject["frameDuration"] = 0.01
        var laterExpiryState = try XCTUnwrap(
            laterExpiryObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var laterFlares = try XCTUnwrap(
            laterExpiryState["yellowFlares"] as? [[String: Any]]
        )
        laterFlares[0]["lifeRemaining"] = 0.005
        laterFlares[0]["lastParticleDropTime"] =
            laterExpiryObject["gameTime"]
        laterExpiryState["yellowFlares"] = laterFlares
        laterExpiryObject["trainingRobotGuidebotState"] =
            laterExpiryState
        let laterExpiry = try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: laterExpiryObject
                )
            ),
            resumedAtTimestamp: 31.1
        )
        let laterExpiryFrame = laterExpiry.update(
            at: 31.11,
            input: .zero
        )
        XCTAssertTrue(laterExpiryFrame.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertTrue(
            laterExpiryFrame
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty
        )
        XCTAssertTrue(
            laterExpiryFrame
                .trainingGuidebotYellowFlareTimeoutSparks.isEmpty
        )
        XCTAssertTrue(
            laterExpiryFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.isEmpty
        )

        var hostileChildLightObject = try continuationObject(
            expiredRestore.continuation
        )
        var hostileChildLightState = try XCTUnwrap(
            hostileChildLightObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var hostileChildLightSparks = try XCTUnwrap(
            hostileChildLightState["yellowFlareTimeoutSparks"]
                as? [[String: Any]]
        )
        hostileChildLightSparks[0]["presentedLightDistance"] = 8
        hostileChildLightState["yellowFlareTimeoutSparks"] =
            hostileChildLightSparks
        hostileChildLightObject["trainingRobotGuidebotState"] =
            hostileChildLightState
        XCTAssertThrowsError(try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: hostileChildLightObject
                )
            ),
            resumedAtTimestamp: 23.02
        )) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var inconsistentLatchObject = try continuationObject(
            expiry.continuation
        )
        var inconsistentLatchState = try XCTUnwrap(
            inconsistentLatchObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        inconsistentLatchState[
            "yellowFlareTimeoutReachedFollowingFrame"
        ] = false
        inconsistentLatchObject["trainingRobotGuidebotState"] =
            inconsistentLatchState
        XCTAssertThrowsError(try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: inconsistentLatchObject
                )
            ),
            resumedAtTimestamp: 23
        )) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var missingVisualAgeObject = try continuationObject(
            expiry.continuation
        )
        var missingVisualAgeState = try XCTUnwrap(
            missingVisualAgeObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var missingVisualAgeParticles = try XCTUnwrap(
            missingVisualAgeState[
                "yellowFlareTimeoutSparkParticles"
            ] as? [[String: Any]]
        )
        missingVisualAgeParticles[0].removeValue(forKey: "creationTime")
        missingVisualAgeState[
            "yellowFlareTimeoutSparkParticles"
        ] = missingVisualAgeParticles
        missingVisualAgeObject["trainingRobotGuidebotState"] =
            missingVisualAgeState
        XCTAssertThrowsError(try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: missingVisualAgeObject
                )
            ),
            resumedAtTimestamp: 23
        )) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var incompleteTimeoutObject = try continuationObject(
            expiry.continuation
        )
        var incompleteTimeoutState = try XCTUnwrap(
            incompleteTimeoutObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        incompleteTimeoutState.removeValue(
            forKey: "yellowFlareTimeoutSparkParticles"
        )
        incompleteTimeoutObject["trainingRobotGuidebotState"] =
            incompleteTimeoutState
        XCTAssertThrowsError(try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: incompleteTimeoutObject
                )
            ),
            resumedAtTimestamp: 23
        )) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var duplicateTimeoutObject = try continuationObject(
            expiry.continuation
        )
        var duplicateTimeoutState = try XCTUnwrap(
            duplicateTimeoutObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var duplicateSparks = try XCTUnwrap(
            duplicateTimeoutState["yellowFlareTimeoutSparks"]
                as? [[String: Any]]
        )
        duplicateSparks.append(try XCTUnwrap(duplicateSparks.first))
        duplicateTimeoutState["yellowFlareTimeoutSparks"] =
            duplicateSparks
        duplicateTimeoutObject["trainingRobotGuidebotState"] =
            duplicateTimeoutState
        XCTAssertThrowsError(try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: duplicateTimeoutObject
                )
            ),
            resumedAtTimestamp: 23
        )) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var missingTimeoutObject = try continuationObject(
            expiry.continuation
        )
        var missingTimeoutState = try XCTUnwrap(
            missingTimeoutObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var missingSparks = try XCTUnwrap(
            missingTimeoutState["yellowFlareTimeoutSparks"]
                as? [[String: Any]]
        )
        missingSparks.removeLast()
        missingTimeoutState["yellowFlareTimeoutSparks"] =
            missingSparks
        missingTimeoutObject["trainingRobotGuidebotState"] =
            missingTimeoutState
        XCTAssertThrowsError(try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: missingTimeoutObject
                )
            ),
            resumedAtTimestamp: 23
        )) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var legacyTimeoutObject = try continuationObject(
            expiry.continuation
        )
        var legacyTimeoutState = try XCTUnwrap(
            legacyTimeoutObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        legacyTimeoutState.removeValue(
            forKey: "yellowFlareTimeoutExplosions"
        )
        legacyTimeoutState.removeValue(
            forKey: "yellowFlareTimeoutSparks"
        )
        legacyTimeoutState.removeValue(
            forKey: "yellowFlareTimeoutSparkParticles"
        )
        legacyTimeoutState.removeValue(
            forKey: "yellowFlareTimeoutReachedFollowingFrame"
        )
        legacyTimeoutObject["trainingRobotGuidebotState"] =
            legacyTimeoutState
        let legacyTimeoutRestore = try PlayerSimulation(
            level: eligible.level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: legacyTimeoutObject
                )
            ),
            resumedAtTimestamp: 23
        )
        let legacyTimeoutFrame = legacyTimeoutRestore.update(
            at: 23.01,
            input: .zero
        )
        XCTAssertTrue(
            legacyTimeoutFrame
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty
        )
        XCTAssertTrue(
            legacyTimeoutFrame
                .trainingGuidebotYellowFlareTimeoutSparks.isEmpty
        )

        var parentOnlyLevelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(eligible.level)
            ) as? [String: Any]
        )
        var parentOnlyChain = try XCTUnwrap(
            parentOnlyLevelObject["trainingRobotGuidebotChain"]
                as? [String: Any]
        )
        var parentOnlyFlare = try XCTUnwrap(
            parentOnlyChain["yellowFlare"] as? [String: Any]
        )
        parentOnlyFlare.removeValue(forKey: "timeout")
        parentOnlyChain["yellowFlare"] = parentOnlyFlare
        parentOnlyLevelObject["trainingRobotGuidebotChain"] =
            parentOnlyChain
        let parentOnlyLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: parentOnlyLevelObject
            )
        )
        var parentOnlyObject = expiryObject
        var parentOnlyState = try XCTUnwrap(
            parentOnlyObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        parentOnlyState.removeValue(
            forKey: "yellowFlareTimeoutExplosions"
        )
        parentOnlyState.removeValue(
            forKey: "yellowFlareTimeoutSparks"
        )
        parentOnlyState.removeValue(
            forKey: "yellowFlareTimeoutSparkParticles"
        )
        parentOnlyState.removeValue(
            forKey: "yellowFlareTimeoutReachedFollowingFrame"
        )
        parentOnlyObject["trainingRobotGuidebotState"] =
            parentOnlyState
        let parentOnlyRestore = try PlayerSimulation(
            level: parentOnlyLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: parentOnlyObject
                )
            ),
            resumedAtTimestamp: 24
        )
        let parentOnlyFrame = parentOnlyRestore.update(
            at: 24.01,
            input: .zero
        )
        XCTAssertTrue(parentOnlyFrame.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertTrue(
            parentOnlyFrame
                .trainingGuidebotYellowFlareTimeoutExplosions.isEmpty
        )
        XCTAssertTrue(
            parentOnlyFrame
                .trainingGuidebotYellowFlareTimeoutSparks.isEmpty
        )
        XCTAssertTrue(
            parentOnlyFrame
                .trainingGuidebotYellowFlareTimeoutSparkParticles.isEmpty
        )

        var oneFrameLevelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(eligible.level)
            ) as? [String: Any]
        )
        var oneFrameChain = try XCTUnwrap(
            oneFrameLevelObject["trainingRobotGuidebotChain"]
                as? [String: Any]
        )
        var oneFrameFlare = try XCTUnwrap(
            oneFrameChain["yellowFlare"] as? [String: Any]
        )
        var oneFrameTimeout = try XCTUnwrap(
            oneFrameFlare["timeout"] as? [String: Any]
        )
        oneFrameTimeout.removeValue(forKey: "childAnimationFrames")
        oneFrameTimeout.removeValue(forKey: "childSourceFrameTime")
        oneFrameFlare["timeout"] = oneFrameTimeout
        oneFrameChain["yellowFlare"] = oneFrameFlare
        oneFrameLevelObject["trainingRobotGuidebotChain"] =
            oneFrameChain
        var oneFrameMaterials = try XCTUnwrap(
            oneFrameLevelObject["presentationMaterials"]
                as? [[String: Any]]
        )
        oneFrameMaterials.removeAll { material in
            guard let texture = material["texture"] as? [String: Any],
                  let sourceName = texture["sourceName"] as? String else {
                return false
            }
            return sourceName.hasPrefix("yellowspark.oaf frame ")
        }
        oneFrameLevelObject["presentationMaterials"] =
            oneFrameMaterials
        var oneFrameManifest = try XCTUnwrap(
            oneFrameLevelObject["dependencyManifest"]
                as? [String: Any]
        )
        var oneFrameDependencies = try XCTUnwrap(
            oneFrameManifest["current"] as? [[String: Any]]
        )
        oneFrameDependencies.removeAll { dependency in
            guard let source = dependency["source"] as? [String: Any],
                  let sourceName = source["sourceName"] as? String else {
                return false
            }
            return sourceName.hasPrefix("yellowspark.oaf frame ")
        }
        oneFrameManifest["current"] = oneFrameDependencies
        oneFrameLevelObject["dependencyManifest"] = oneFrameManifest
        let oneFrameLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: oneFrameLevelObject
            )
        )
        let oneFrameTimeoutDefinition = try XCTUnwrap(
            oneFrameLevel.trainingRobotGuidebotChain?
                .yellowFlare?.timeout
        )
        XCTAssertTrue(oneFrameTimeoutDefinition.hasCoherentChildAnimationBinding)
        XCTAssertNoThrow(
            try validateTrainingGuidebotYellowFlareAnimationBinding(
                timeout: oneFrameTimeoutDefinition,
                materials: oneFrameLevel.presentationMaterials,
                dependencies: oneFrameLevel.dependencyManifest.current
            )
        )
        let oneFrameRestore = try PlayerSimulation(
            level: oneFrameLevel,
            continuation: expiry.continuation,
            resumedAtTimestamp: 32
        )
        let oneFrame = oneFrameRestore.update(
            at: 32.01,
            input: .zero
        )
        XCTAssertTrue(
            oneFrame.trainingGuidebotYellowFlareTimeoutSparks
                .allSatisfy { $0.texture.sourceName == "yellowspark" }
        )
        XCTAssertTrue(
            oneFrame.trainingGuidebotYellowFlareTimeoutSparkParticles
                .allSatisfy { $0.texture.sourceName == "yellowspark" }
        )

        var incompleteBindingObject = oneFrameLevelObject
        var incompleteBindingChain = try XCTUnwrap(
            incompleteBindingObject["trainingRobotGuidebotChain"]
                as? [String: Any]
        )
        var incompleteBindingFlare = try XCTUnwrap(
            incompleteBindingChain["yellowFlare"] as? [String: Any]
        )
        var incompleteBindingTimeout = try XCTUnwrap(
            incompleteBindingFlare["timeout"] as? [String: Any]
        )
        incompleteBindingTimeout["childAnimationFrames"] =
            animationFrames.map {
                [
                    "storedIndex": $0.storedIndex,
                    "sourceName": $0.sourceName,
                ]
            }
        incompleteBindingFlare["timeout"] = incompleteBindingTimeout
        incompleteBindingChain["yellowFlare"] = incompleteBindingFlare
        incompleteBindingObject["trainingRobotGuidebotChain"] =
            incompleteBindingChain
        let incompleteBinding = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: incompleteBindingObject
            )
        )
        XCTAssertFalse(
            try XCTUnwrap(
                incompleteBinding.trainingRobotGuidebotChain?
                    .yellowFlare?.timeout
            ).hasCoherentChildAnimationBinding
        )
        XCTAssertThrowsError(
            try validateTrainingGuidebotYellowFlareAnimationBinding(
                timeout: incompleteBinding.trainingRobotGuidebotChain?
                    .yellowFlare?.timeout,
                materials: incompleteBinding.presentationMaterials,
                dependencies: incompleteBinding.dependencyManifest.current
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency(
                    "Training Guidebot Yellow flare animation binding"
                )
            )
        }

        var wrongCadenceObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(eligible.level)
            ) as? [String: Any]
        )
        var wrongCadenceChain = try XCTUnwrap(
            wrongCadenceObject["trainingRobotGuidebotChain"]
                as? [String: Any]
        )
        var wrongCadenceFlare = try XCTUnwrap(
            wrongCadenceChain["yellowFlare"] as? [String: Any]
        )
        var wrongCadenceTimeout = try XCTUnwrap(
            wrongCadenceFlare["timeout"] as? [String: Any]
        )
        wrongCadenceTimeout["childSourceFrameTime"] = 0.071
        wrongCadenceFlare["timeout"] = wrongCadenceTimeout
        wrongCadenceChain["yellowFlare"] = wrongCadenceFlare
        wrongCadenceObject["trainingRobotGuidebotChain"] =
            wrongCadenceChain
        let wrongCadenceLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: wrongCadenceObject)
        )
        let wrongCadenceDefinition = try XCTUnwrap(
            wrongCadenceLevel.trainingRobotGuidebotChain?
                .yellowFlare?.timeout
        )
        XCTAssertFalse(wrongCadenceDefinition.hasCoherentChildAnimationBinding)
        XCTAssertThrowsError(
            try validateTrainingGuidebotYellowFlareAnimationBinding(
                timeout: wrongCadenceDefinition,
                materials: wrongCadenceLevel.presentationMaterials,
                dependencies: wrongCadenceLevel.dependencyManifest.current
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency(
                    "Training Guidebot Yellow flare animation binding"
                )
            )
        }

        var compatibleLevelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(level)
            ) as? [String: Any]
        )
        var compatibleChain = try XCTUnwrap(
            compatibleLevelObject["trainingRobotGuidebotChain"]
                as? [String: Any]
        )
        compatibleChain.removeValue(forKey: "yellowFlare")
        compatibleLevelObject["trainingRobotGuidebotChain"] = compatibleChain
        let compatibleLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: compatibleLevelObject)
        )
        let compatibleSeed = PlayerSimulation(
            level: compatibleLevel,
            presentationReadyTimestamp: 0
        )
        _ = compatibleSeed.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        var compatibleObject = try continuationObject(
            compatibleSeed.continuation
        )
        compatibleObject["authoritativeRandomState"] = NSNumber(
            value: initialRandomState
        )
        var compatibleState = try XCTUnwrap(
            compatibleObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        compatibleState["guidebotMode"] = "ambient"
        compatibleState["guidebotModeTime"] = 0.1
        compatibleState["nextAmbientTime"] = 100.0
        compatibleState["timeUntilNextFlare"] = 0.05
        compatibleState["nextPowerupCheckTime"] = 100.0
        compatibleObject["trainingRobotGuidebotState"] = compatibleState
        let compatible = try PlayerSimulation(
            level: compatibleLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: compatibleObject)
            ),
            resumedAtTimestamp: 30
        )
        let compatibleFrame = compatible.update(at: 30.1, input: .zero)
        XCTAssertEqual(
            try randomState(in: compatible.continuation),
            nextState(initialRandomState)
        )
        XCTAssertTrue(compatibleFrame.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertTrue(
            compatibleFrame.trainingGuidebotYellowFlareParticles.isEmpty
        )
        XCTAssertFalse(compatibleFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
    }
    func testTrainingGuidebotUsesVerifiedBoundaryNodesAroundBlockedDirectLine() throws {
        var level = makeSliceTenContactLevel(clearance: 20)
        let player = level.objects.first { $0.handle == 2_048 }!
        guard case let .room(roomSourceIndex) = player.location else {
            return XCTFail("expected indoor player")
        }
        let distractorRoomSourceIndex = try XCTUnwrap(
            level.rooms.first {
                $0.sourceIndex != roomSourceIndex
            }?.sourceIndex
        )
        let wallOffset = Vector3(
            x: player.orientation.right.x * 25,
            y: player.orientation.right.y * 25,
            z: player.orientation.right.z * 25
        )
        let forwardTen = Vector3(
            x: player.orientation.forward.x * 10,
            y: player.orientation.forward.y * 10,
            z: player.orientation.forward.z * 10
        )
        let forwardThirty = Vector3(
            x: player.orientation.forward.x * 30,
            y: player.orientation.forward.y * 30,
            z: player.orientation.forward.z * 30
        )
        let forwardForty = Vector3(
            x: player.orientation.forward.x * 40,
            y: player.orientation.forward.y * 40,
            z: player.orientation.forward.z * 40
        )
        let beforeWall = Vector3(
            x: player.position.x + forwardTen.x + wallOffset.x,
            y: player.position.y + forwardTen.y + wallOffset.y,
            z: player.position.z + forwardTen.z + wallOffset.z
        )
        let beyondWall = Vector3(
            x: player.position.x + forwardThirty.x + wallOffset.x,
            y: player.position.y + forwardThirty.y + wallOffset.y,
            z: player.position.z + forwardThirty.z + wallOffset.z
        )
        let laterVisibleStart = Vector3(
            x: beforeWall.x + player.orientation.forward.x * 2,
            y: beforeWall.y + player.orientation.forward.y * 2,
            z: beforeWall.z + player.orientation.forward.z * 2
        )
        let destination = Vector3(
            x: player.position.x + forwardForty.x,
            y: player.position.y + forwardForty.y,
            z: player.position.z + forwardForty.z
        )
        level = replacing(
            level,
            indoorNavigation: .init(
                sourceHighestRoomPlusTerrainRegions:
                    level.rooms.map(\.sourceIndex).max()! + 8,
                sourceWasVerified: true,
                rooms: [
                    .init(
                        sourceIndex: roomSourceIndex,
                        nodes: [
                            .init(
                                position: beforeWall,
                                edges: [
                                    .init(
                                        destinationRoomSourceIndex:
                                            roomSourceIndex,
                                        destinationNodeIndex: 1,
                                        flags: 0,
                                        cost: 20,
                                        maximumRadius: 6
                                    ),
                                ]
                            ),
                            .init(
                                position: beyondWall,
                                edges: [
                                    .init(
                                        destinationRoomSourceIndex:
                                            roomSourceIndex,
                                        destinationNodeIndex: 0,
                                        flags: 0,
                                        cost: 20,
                                        maximumRadius: 6
                                    ),
                                    .init(
                                        destinationRoomSourceIndex:
                                            roomSourceIndex,
                                        destinationNodeIndex: 2,
                                        flags: 0,
                                        cost: 20,
                                        maximumRadius: 6
                                    ),
                                ]
                            ),
                            .init(
                                position: laterVisibleStart,
                                edges: [
                                    .init(
                                        destinationRoomSourceIndex:
                                            distractorRoomSourceIndex,
                                        destinationNodeIndex: 0,
                                        flags: 0,
                                        cost: 1,
                                        maximumRadius: 6
                                    ),
                                    .init(
                                        destinationRoomSourceIndex:
                                            roomSourceIndex,
                                        destinationNodeIndex: 1,
                                        flags: 0,
                                        cost: 20,
                                        maximumRadius: 6
                                    ),
                                ]
                            ),
                        ]
                    ),
                    .init(
                        sourceIndex: distractorRoomSourceIndex,
                        nodes: [
                            .init(
                                position: laterVisibleStart,
                                edges: [
                                    .init(
                                        destinationRoomSourceIndex:
                                            roomSourceIndex,
                                        destinationNodeIndex: 2,
                                        flags: 0,
                                        cost: 1,
                                        maximumRadius: 6
                                    ),
                                ]
                            ),
                        ]
                    ),
                ]
            )
        )
        XCTAssertNoThrow(try level.validate())

        XCTAssertEqual(
            trainingGuidebotRoute(
                in: level,
                startRoomSourceIndex: roomSourceIndex,
                start: player.position,
                startForward: player.orientation.forward,
                destinationRoomSourceIndex: roomSourceIndex,
                destination: destination,
                radius: 1
            ),
            .success(.init(
                mode: .boundaryNodes,
                points: [laterVisibleStart, beyondWall, destination],
                roomSourceIndices: [roomSourceIndex],
                nodeReferences: [
                    .init(roomSourceIndex: roomSourceIndex, nodeIndex: 2),
                    .init(roomSourceIndex: roomSourceIndex, nodeIndex: 1),
                ]
            ))
        )
    }

    func testTrainingGuidebotMovesThroughAllocatedRouteAndResumesDeterministically() throws {
        let level = makeTrainingGuidebotBlockedMovementLevel()
        let player = try XCTUnwrap(
            level.objects.first { $0.handle == 2_048 }
        )
        guard case let .room(playerRoomSourceIndex) = player.location else {
            return XCTFail("expected indoor player")
        }
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.1
        var frame = simulation.update(
            at: timestamp,
            input: .init(deploysTrainingGuidebot: true)
        )
        var guidebot = try XCTUnwrap(frame.trainingGuidebot)
        XCTAssertEqual(guidebot.route.mode, .boundaryNodes)
        XCTAssertEqual(guidebot.activeSteeringMode, .allocatedRoute)
        XCTAssertGreaterThan(
            guidebot.velocity.x * player.orientation.right.x
                + guidebot.velocity.y * player.orientation.right.y
                + guidebot.velocity.z * player.orientation.right.z,
            0
        )
        XCTAssertEqual(
            try guidebotRoutePointIndex(in: simulation.continuation),
            0
        )

        for _ in 0..<19 {
            guard try guidebotRoutePointIndex(
                in: simulation.continuation
            ) == 0 else {
                break
            }
            timestamp += 0.1
            frame = simulation.update(at: timestamp, input: .zero)
            guidebot = try XCTUnwrap(frame.trainingGuidebot)
            XCTAssertEqual(guidebot.activeSteeringMode, .allocatedRoute)
            XCTAssertEqual(
                simulation.level.objects.first {
                    $0.instanceName == "GuideBotB"
                }?.location,
                .room(playerRoomSourceIndex)
            )
        }
        XCTAssertEqual(
            try guidebotRoutePointIndex(in: simulation.continuation),
            1
        )

        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        XCTAssertEqual(restored.continuation, continuation)

        var restoredTimestamp = 100.0
        for _ in 0..<12 {
            timestamp += 0.1
            restoredTimestamp += 0.1
            let originalFrame = simulation.update(
                at: timestamp,
                input: .zero
            )
            let restoredFrame = restored.update(
                at: restoredTimestamp,
                input: .zero
            )
            XCTAssertEqual(
                originalFrame.trainingGuidebot,
                restoredFrame.trainingGuidebot
            )
            XCTAssertEqual(simulation.continuation, restored.continuation)
            XCTAssertEqual(
                restored.level.objects.first {
                    $0.instanceName == "GuideBotB"
                }?.location,
                .room(playerRoomSourceIndex)
            )
        }
        let finalGuidebot = try XCTUnwrap(restored.update(
            at: restoredTimestamp + 0.1,
            input: .zero
        ).trainingGuidebot)
        let finalPosition = finalGuidebot.position
        let finalDelta = Vector3(
            x: finalPosition.x - player.position.x,
            y: finalPosition.y - player.position.y,
            z: finalPosition.z - player.position.z
        )
        let forwardTravel =
            finalDelta.x * player.orientation.forward.x
                + finalDelta.y * player.orientation.forward.y
                + finalDelta.z * player.orientation.forward.z
        XCTAssertGreaterThan(forwardTravel, 30)
        XCTAssertEqual(
            try guidebotRoutePointIndex(in: restored.continuation),
            finalGuidebot.route.points.count - 1
        )
        XCTAssertNotEqual(finalGuidebot.activeSteeringMode, .direct)
    }

    func testContinuationRejectsGuidebotAndProjectileOutsideRecordedRooms() throws {
        let level = makeTrainingGuidebotBlockedMovementLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = simulation.update(at: 0.100_1, input: .zero)
        _ = simulation.update(
            at: 0.100_2,
            input: .init(firesPrimaryWeapon: true)
        )
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: continuationData
        )
        XCTAssertNoThrow(
            try PlayerSimulation(
                level: level,
                continuation: continuation,
                resumedAtTimestamp: 100
            )
        )

        for mutation in ["guidebot", "projectile"] {
            var hostileObject = try XCTUnwrap(
                JSONSerialization.jsonObject(with: continuationData)
                    as? [String: Any]
            )
            var hostileState = try XCTUnwrap(
                hostileObject["trainingRobotGuidebotState"]
                    as? [String: Any]
            )
            let outsidePosition: [String: Any] = [
                "x": 1_000_000,
                "y": 1_000_000,
                "z": 1_000_000,
            ]
            if mutation == "guidebot" {
                var guidebot = try XCTUnwrap(
                    hostileState["guidebot"] as? [String: Any]
                )
                guidebot["position"] = outsidePosition
                hostileState["guidebot"] = guidebot
            } else {
                var projectiles = try XCTUnwrap(
                    hostileState["projectiles"] as? [[String: Any]]
                )
                XCTAssertFalse(projectiles.isEmpty)
                projectiles[0]["position"] = outsidePosition
                hostileState["projectiles"] = projectiles
            }
            hostileObject["trainingRobotGuidebotState"] = hostileState
            let hostileContinuation = try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: hostileObject
                )
            )
            XCTAssertThrowsError(
                try PlayerSimulation(
                    level: level,
                    continuation: hostileContinuation,
                    resumedAtTimestamp: 100
                ),
                mutation
            ) {
                XCTAssertEqual(
                    $0 as? PlayerSimulationContinuationError,
                    .invalidState
                )
            }
        }
    }
    func testF4BirthCopiesLivePlayerAndMovesGuidebotOnReachedGoal() throws {
        let level = makeTrainingRobotGuidebotLevel()
        let player = try XCTUnwrap(level.objects.first { $0.handle == 2_048 })
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        let guidebot = try XCTUnwrap(frame.trainingGuidebot)

        XCTAssertEqual(guidebot.spawnPosition, player.position)
        XCTAssertEqual(guidebot.orientation, player.orientation)
        XCTAssertEqual(guidebot.spawnVelocity, Vector3(
            x: player.orientation.forward.x * 40,
            y: player.orientation.forward.y * 40,
            z: player.orientation.forward.z * 40
        ))
        XCTAssertEqual(guidebot.destination, Vector3(
            x: player.position.x + player.orientation.forward.x * 200,
            y: player.position.y + player.orientation.forward.y * 200,
            z: player.position.z + player.orientation.forward.z * 200
        ))
        XCTAssertEqual(guidebot.route.mode, .direct)
        XCTAssertEqual(guidebot.activeSteeringMode, .direct)
        XCTAssertNotEqual(guidebot.spawnPosition, guidebot.position)

        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
        )
        XCTAssertEqual(
            continuation,
            simulation.continuation
        )
    }

    func testGuidebotBirthPreservesInheritedSpeedAndGoalCompletionDecelerates() throws {
        var level = makeTrainingRobotGuidebotLevel()
        let safeRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 1 }
        )
        let safeRoom = level.rooms[safeRoomIndex]
        let safeCenter = safeRoom.pathPoint
        level.rooms[safeRoomIndex] = addingSourceContainmentShell(
            to: .init(
                sourceIndex: safeRoom.sourceIndex,
                name: safeRoom.name,
                pathPoint: safeCenter,
                vertices: [],
                faces: [],
                portals: []
            ),
            center: safeCenter,
            texture: level.surfacePhysics[0].texture,
            halfExtent: 500
        )
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(1)
        level.objects[playerIndex].position = safeCenter
        let chain = try XCTUnwrap(level.trainingRobotGuidebotChain)
        let inheritedSimulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var inheritedPlayerSpeed: Float = 0
        for frameIndex in 1...20 {
            let frame = inheritedSimulation.update(
                at: Double(frameIndex) * 0.1,
                input: .init(forward: 1)
            )
            inheritedPlayerSpeed = sqrt(
                frame.velocity.x * frame.velocity.x
                    + frame.velocity.y * frame.velocity.y
                    + frame.velocity.z * frame.velocity.z
            )
        }
        XCTAssertGreaterThan(inheritedPlayerSpeed, 20)
        let inheritedFrame = inheritedSimulation.update(
            at: 2.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        let inheritedGuidebot = try XCTUnwrap(
            inheritedFrame.trainingGuidebot
        )
        let inheritedSpeed = sqrt(
            inheritedGuidebot.velocity.x * inheritedGuidebot.velocity.x
                + inheritedGuidebot.velocity.y * inheritedGuidebot.velocity.y
                + inheritedGuidebot.velocity.z * inheritedGuidebot.velocity.z
        )
        XCTAssertEqual(
            inheritedSpeed,
            inheritedPlayerSpeed
                + chain.guidebot.birthForwardVelocity
                - chain.guidebot.maximumDeltaVelocity * 0.1,
            accuracy: Float(0.000_1)
        )

        let shortGoalLevel = replacing(
            level,
            trainingRobotGuidebotChain: .init(
                destroyRobotObjectHandle: chain.destroyRobotObjectHandle,
                guidebotObjectHandle: chain.guidebotObjectHandle,
                destroyRobotRoomSourceIndex:
                    chain.destroyRobotRoomSourceIndex,
                destroyRobotFlags: chain.destroyRobotFlags,
                destructionDelay: chain.destructionDelay,
                destructionMessage: chain.destructionMessage,
                exitInstruction: chain.exitInstruction,
                destructionVoiceSourceName:
                    chain.destructionVoiceSourceName,
                deployedGuidebotObjectType:
                    chain.deployedGuidebotObjectType,
                deployedGuidebotMessage: chain.deployedGuidebotMessage,
                deployedGuidebotVoiceSourceName:
                    chain.deployedGuidebotVoiceSourceName,
                combat: chain.combat,
                guidebot: .init(
                    collisionRadius: chain.guidebot.collisionRadius,
                    maximumVelocity: chain.guidebot.maximumVelocity,
                    maximumDeltaVelocity:
                        chain.guidebot.maximumDeltaVelocity,
                    birthForwardVelocity:
                        chain.guidebot.birthForwardVelocity,
                    goalForwardDistance: 0.5,
                    goalCircleDistance:
                        chain.guidebot.goalCircleDistance
                )
            )
        )
        let completionSimulation = PlayerSimulation(
            level: shortGoalLevel,
            presentationReadyTimestamp: 0
        )
        let completionFrame = completionSimulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        let completionGuidebot = try XCTUnwrap(
            completionFrame.trainingGuidebot
        )
        let completionSpeed = sqrt(
            completionGuidebot.velocity.x * completionGuidebot.velocity.x
                + completionGuidebot.velocity.y
                    * completionGuidebot.velocity.y
                + completionGuidebot.velocity.z
                    * completionGuidebot.velocity.z
        )
        XCTAssertEqual(
            completionSpeed,
            Float(20.000_002),
            accuracy: Float(0.000_1)
        )
        XCTAssertEqual(completionGuidebot.activeSteeringMode, .stopped)
    }

    func testDeployedGuidebotContinuationRestoresPresentationWithoutRepeatingScript060() throws {
        let level = makeTrainingRobotGuidebotLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var galleryTimestamp = 0.0
        for frameIndex in 1...20 {
            galleryTimestamp = Double(frameIndex) * 0.1
            let frame = simulation.update(
                at: galleryTimestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                break
            }
        }
        let deployed = simulation.update(
            at: galleryTimestamp + 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertNotNil(deployed.trainingGuidebot)
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
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
            "x": restoredRoomPoint.x,
            "y": restoredRoomPoint.y,
            "z": restoredRoomPoint.z,
        ]
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: continuationObject)
        )
        for (field, value) in [
            ("roomSourceIndex", 99_999),
            ("routePointIndex", 99_999),
        ] {
            var hostileObject = try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(continuation)
                ) as? [String: Any]
            )
            var hostileState = try XCTUnwrap(
                hostileObject["trainingRobotGuidebotState"]
                    as? [String: Any]
            )
            var hostileGuidebot = try XCTUnwrap(
                hostileState["guidebot"] as? [String: Any]
            )
            hostileGuidebot[field] = value
            hostileState["guidebot"] = hostileGuidebot
            hostileObject["trainingRobotGuidebotState"] = hostileState
            let hostileContinuation = try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: hostileObject
                )
            )
            XCTAssertThrowsError(
                try PlayerSimulation(
                    level: restorationLevel,
                    continuation: hostileContinuation,
                    resumedAtTimestamp: 100
                )
            ) {
                XCTAssertEqual(
                    $0 as? PlayerSimulationContinuationError,
                    .invalidState
                )
            }
        }

        let restored = try PlayerSimulation(
            level: restorationLevel,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        XCTAssertEqual(restored.continuation, continuation)
        let guidebot = try XCTUnwrap(
            restored.level.objects.first { $0.instanceName == "GuideBotB" }
        )
        XCTAssertTrue(restored.level.objectPresentations.contains {
            $0.objectHandle == guidebot.handle
                && $0.primaryModel.sourceName
                    .caseInsensitiveCompare("Buddybot.oof")
                    == .orderedSame
        })
        let resumed = restored.update(at: 100.1, input: .zero)
        XCTAssertNotNil(resumed.trainingGuidebot)
        XCTAssertTrue(resumed.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(resumed.enabledPlayerControls, .all)
    }

    func testGuidebotRouteContinuationUsesItsClosedBarrierAllocationState() throws {
        var level = makeTrainingRobotGuidebotLevel()
        let chain = try XCTUnwrap(level.trainingRobotGuidebotChain)
        level = replacing(
            level,
            trainingRobotGuidebotChain: .init(
                destroyRobotObjectHandle: chain.destroyRobotObjectHandle,
                guidebotObjectHandle: chain.guidebotObjectHandle,
                destroyRobotRoomSourceIndex:
                    chain.destroyRobotRoomSourceIndex,
                destroyRobotFlags: chain.destroyRobotFlags,
                destructionDelay: chain.destructionDelay,
                destructionMessage: chain.destructionMessage,
                exitInstruction: chain.exitInstruction,
                destructionVoiceSourceName:
                    chain.destructionVoiceSourceName,
                deployedGuidebotObjectType:
                    chain.deployedGuidebotObjectType,
                deployedGuidebotMessage: chain.deployedGuidebotMessage,
                deployedGuidebotVoiceSourceName:
                    chain.deployedGuidebotVoiceSourceName,
                combat: chain.combat,
                guidebot: .init(
                    collisionRadius: chain.guidebot.collisionRadius,
                    maximumVelocity: chain.guidebot.maximumVelocity,
                    maximumDeltaVelocity:
                        chain.guidebot.maximumDeltaVelocity,
                    birthForwardVelocity:
                        chain.guidebot.birthForwardVelocity,
                    goalForwardDistance: 2,
                    goalCircleDistance:
                        chain.guidebot.goalCircleDistance
                )
            )
        )
        let portalCenter = RoomCamera.trainingRoom3.position
        for roomSourceIndex in [2, 3] {
            let roomIndex = try XCTUnwrap(
                level.rooms.firstIndex {
                    $0.sourceIndex == roomSourceIndex
                }
            )
            for vertexIndex in 0..<4 {
                let vertex =
                    level.rooms[roomIndex].vertices[vertexIndex]
                level.rooms[roomIndex].vertices[vertexIndex] = .init(
                    x: portalCenter.x
                        + (vertexIndex == 0 || vertexIndex == 3 ? 20 : -20),
                    y: vertex.y,
                    z: portalCenter.z
                        + (vertexIndex < 2 ? 20 : -20)
                )
            }
        }
        let room2Index = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 2 }
        )
        for vertexIndex in 4..<8 {
            level.rooms[room2Index].vertices[vertexIndex] = .init(
                x: portalCenter.x
                    + (vertexIndex == 4 || vertexIndex == 7 ? 20 : -20),
                y: portalCenter.y + 20,
                z: portalCenter.z
                    + (vertexIndex < 6 ? 20 : -20)
            )
        }
        let room3Index = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 3 }
        )
        for vertexIndex in 12..<16 {
            level.rooms[room3Index].vertices[vertexIndex] = .init(
                x: portalCenter.x
                    + (vertexIndex == 12 || vertexIndex == 15 ? 20 : -20),
                y: portalCenter.y - 20,
                z: portalCenter.z
                    + (vertexIndex < 14 ? 20 : -20)
            )
        }
        let gallerySimulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var galleryTimestamp = 0.0
        for frameIndex in 1...20 {
            galleryTimestamp = Double(frameIndex) * 0.1
            let frame = gallerySimulation.update(
                at: galleryTimestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                break
            }
        }
        var reversedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(gallerySimulation.continuation)
            ) as? [String: Any]
        )
        reversedObject["playerOrientation"] = [
            "right": ["x": -1, "y": 0, "z": 0],
            "up": ["x": 0, "y": 0, "z": 1],
            "forward": ["x": 0, "y": 1, "z": 0],
        ]
        reversedObject["playerPosition"] = [
            "x": portalCenter.x,
            "y": portalCenter.y + 1.5,
            "z": portalCenter.z,
        ]
        reversedObject["velocity"] = ["x": 0, "y": 0, "z": 0]
        let reversedContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: reversedObject)
        )
        let simulation = try PlayerSimulation(
            level: level,
            continuation: reversedContinuation,
            resumedAtTimestamp: 100
        )
        let deployed = simulation.update(
            at: 100.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertNotNil(deployed.trainingGuidebot?.routeFailure)
        simulation.destroyTrainingRobot(handle: 4_112)
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
        )

        XCTAssertNoThrow(
            try PlayerSimulation(
                level: level,
                continuation: continuation,
                resumedAtTimestamp: 200
            )
        )
    }

    func testTrainingGalleryTriggerRequiresPlayerCenterPassThrough() {
        let level = makeTrainingGalleryBarrierLevel()
        let barrier = level.trainingGalleryBarrier!
        let room = level.rooms.first {
            $0.sourceIndex == barrier.triggerRoomSourceIndex
        }!
        let face = room.faces[barrier.triggerFaceIndex]
        let faceCenter = face.corners.reduce(Vector3.zero) {
            let vertex = room.vertices[$1.vertexIndex]
            return Vector3(
                x: $0.x + vertex.x,
                y: $0.y + vertex.y,
                z: $0.z + vertex.z
            )
        }
        let divisor = Float(face.corners.count)
        let center = Vector3(
            x: faceCenter.x / divisor,
            y: faceCenter.y / divisor,
            z: faceCenter.z / divisor
        )
        let normal = canonicalFaceNormal(room: room, face: face)!
        let radius: Float = 1
        let start = Vector3(
            x: center.x + normal.x * 2,
            y: center.y + normal.y * 2,
            z: center.z + normal.z * 2
        )
        let sphereOverlap = traceIndoorMovement(
            in: level,
            startRoom: room.sourceIndex,
            start: start,
            end: .init(
                x: center.x + normal.x * 0.5,
                y: center.y + normal.y * 0.5,
                z: center.z + normal.z * 0.5
            ),
            radius: radius
        )
        XCTAssertFalse(sphereOverlap.passedPortalFaces.contains {
            $0.roomSourceIndex == barrier.triggerRoomSourceIndex
                && $0.faceIndex == barrier.triggerFaceIndex
        })

        let centerCrossing = traceIndoorMovement(
            in: level,
            startRoom: room.sourceIndex,
            start: start,
            end: .init(
                x: center.x - normal.x * 0.5,
                y: center.y - normal.y * 0.5,
                z: center.z - normal.z * 0.5
            ),
            radius: radius
        )
        XCTAssertTrue(centerCrossing.passedPortalFaces.contains {
            $0.roomSourceIndex == barrier.triggerRoomSourceIndex
                && $0.faceIndex == barrier.triggerFaceIndex
        })
    }

    @MainActor
    func testTrainingGalleryAudioFailureStillPresentsHUD() {
        var presentedActions: [String] = []
        RevivalGameplayView.presentTrainingFeedback(
            voicePrecedesHUDMessages: true,
            attemptVoice: {
                presentedActions.append("voice")
                throw NSError(domain: "TrainingVoiceTest", code: 1)
            },
            presentHUDMessages: {
                presentedActions.append("hud")
            }
        )
        XCTAssertEqual(presentedActions, ["voice", "hud"])

        let sameFrameReturn: [TrainingOpeningFeedback] = [
            .init(
                hudMessages: ["GB: Returning to ship."],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: "GBotAcceptOrder.wav"
            ),
            .init(
                hudMessages: ["GB: Entering ship!"],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true
            ),
            .init(
                hudMessages: ["Excellent!"],
                voiceSourceName: "proceed6.osf",
                voicePrecedesHUDMessages: true
            )
        ]
        var orderedPresentation: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            sameFrameReturn,
            attemptVoice: {
                orderedPresentation.append("voice:\($0)")
            },
            attemptSound: { name, _ in
                orderedPresentation.append("sound:\(name)")
            },
            presentHUDMessages: {
                orderedPresentation.append(
                    "hud:\($0.joined(separator: "|"))"
                )
            }
        )
        XCTAssertEqual(orderedPresentation, [
            "sound:GBotAcceptOrder.wav",
            "hud:GB: Returning to ship.",
            "hud:GB: Entering ship!",
            "voice:proceed6.osf",
            "hud:Excellent!",
        ])
    }

    @MainActor
    func testTrainingFeedbackSequenceAttemptsOnlyFinalStreamingVoice() {
        let feedback: [TrainingOpeningFeedback] = [
            .init(
                hudMessages: ["first"],
                voiceSourceName: "return1.osf",
                voicePrecedesHUDMessages: true,
                soundSourceName: "first.wav"
            ),
            .init(
                hudMessages: ["second"],
                voiceSourceName: "welcome.osf",
                voicePrecedesHUDMessages: true,
                soundSourceName: "second.wav"
            ),
            .init(
                hudMessages: ["third"],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: "third.wav"
            ),
        ]
        var presentation: [String] = []

        RevivalGameplayView.presentTrainingFeedbackSequence(
            feedback,
            attemptVoice: {
                presentation.append("voice:\($0)")
            },
            attemptSound: { name, _ in
                presentation.append("sound:\(name)")
            },
            presentHUDMessages: {
                presentation.append("hud:\($0.joined(separator: "|"))")
            }
        )

        XCTAssertEqual(presentation, [
            "sound:first.wav",
            "hud:first",
            "voice:welcome.osf",
            "sound:second.wav",
            "hud:second",
            "sound:third.wav",
            "hud:third",
        ])
    }

private func guidebotRoutePointIndex(
    in continuation: PlayerSimulationContinuation
) throws -> Int {
    let object = try XCTUnwrap(
        JSONSerialization.jsonObject(
            with: JSONEncoder().encode(continuation)
        ) as? [String: Any]
    )
    let state = try XCTUnwrap(
        object["trainingRobotGuidebotState"] as? [String: Any]
    )
    let guidebot = try XCTUnwrap(state["guidebot"] as? [String: Any])
    return try XCTUnwrap(guidebot["routePointIndex"] as? Int)
}
}
