import XCTest

extension WorldRenderingTests {
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
