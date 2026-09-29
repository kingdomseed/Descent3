import XCTest

extension WorldRenderingTests {
    func testKillbotEntryClosesPortalRoom5AndRunsTimedInstructionAcrossReload()
        throws
    {
        let level = makeTrainingKillbotEntryLevel()
        try level.validate()
        let initialSimulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        var initialContinuationObject = try XCTUnwrap(
            testWorldObject(initialSimulation.world)
        )
        var initialGalleryState = try XCTUnwrap(
            initialContinuationObject["trainingGalleryBarrierState"]
                as? [String: Any]
        )
        initialGalleryState["wasTriggered"] = true
        initialGalleryState["markerLightDistance"] = 0
        initialContinuationObject["trainingGalleryBarrierState"] =
            initialGalleryState
        let gallerySimulation = try GameSession(
            level: level,
            world: (decodeTestWorld(initialContinuationObject)).rebased(onto: level),
            resumedAtTimestamp: 0
        )
        gallerySimulation.destroyTrainingRobot(handle: 4_112)
        var destroyedContinuationObject = try XCTUnwrap(
            testWorldObject(gallerySimulation.world)
        )
        var destroyedRobotState = try XCTUnwrap(
            destroyedContinuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        destroyedRobotState.removeValue(
            forKey: "destructionTimerRemaining"
        )
        destroyedRobotState["destructionFeedbackWasPresented"] = true
        destroyedRobotState["enabledControlHUDIsVisible"] = false
        destroyedContinuationObject["trainingRobotGuidebotState"] =
            destroyedRobotState
        let simulation = try GameSession(
            level: level,
            world: (decodeTestWorld(destroyedContinuationObject)).rebased(onto: level),
            resumedAtTimestamp: 0
        )
        var timestamp = 0.1
        _ = simulation.update(
            at: timestamp,
            input: .init(deploysTrainingGuidebot: true)
        )
        timestamp += 0.1
        _ = simulation.update(
            at: timestamp,
            input: .init(usesInventory: true)
        )
        timestamp += 0.1
        _ = simulation.update(
            at: timestamp,
            input: .init(deploysTrainingGuidebot: true)
        )
        var script058: PlayerSimulationFrame?
        for _ in 1...100 {
            timestamp += 0.1
            let frame = simulation.update(
                at: timestamp,
                input: .zero
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                script058 = frame
                break
            }
        }
        let returned = try XCTUnwrap(script058)
        timestamp = Double(returned.gameTime) + 0.1
        XCTAssertTrue(
            simulation.update(at: timestamp, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )
        var entered: PlayerSimulationFrame?
        for frameIndex in 1...40 {
            timestamp += 0.1
            let frame = simulation.update(
                at: timestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "intro6.osf"
            }) {
                XCTAssertEqual(frameIndex, 1)
                entered = frame
                break
            }
        }
        let entry = try XCTUnwrap(entered)
        XCTAssertEqual(entry.trainingOpeningFeedback.last, .init(
            hudMessages: [
                "Now you are on your own in this room. There are 4 robots and 2 powerups. Get the powerups and kill the robots.",
            ],
            voiceSourceName: "intro6.osf",
            voicePrecedesHUDMessages: false
        ))
        XCTAssertEqual(
            entry.trainingGuidebotReturnMarkerLightDistance,
            0
        )
        assertTrainingGuidebotReturnBarrier(
            level: simulation.runtimeLevel,
            rendersFaces: true
        )

        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: continuationData
            ) as? [String: Any]
        )
        XCTAssertEqual(
            containingIndoorRoomSourceIndex(
                in: simulation.runtimeLevel,
                position: entry.playerView.camera.position,
                candidates: [entry.playerView.roomSourceIndex]
            ),
            entry.playerView.roomSourceIndex
        )
        let galleryState = try XCTUnwrap(
            continuationObject["trainingGalleryBarrierState"]
                as? [String: Any]
        )
        XCTAssertEqual(galleryState["wasTriggered"] as? Bool, true)
        XCTAssertEqual(galleryState["markerLightDistance"] as? Double, 50)
        let robotState = try XCTUnwrap(
            continuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(robotState["robotWasDestroyed"] as? Bool, true)
        XCTAssertEqual(robotState["guidebotEnteredShip"] as? Bool, true)
        let cameraState = try XCTUnwrap(
            continuationObject["trainingCameraMonitorState"]
                as? [String: Any]
        )
        XCTAssertEqual(cameraState["script058WasPresented"] as? Bool, true)
        XCTAssertEqual(
            cameraState["returnMarkerLightDistance"] as? Double,
            50
        )
        let killbotEntryState = try XCTUnwrap(
            continuationObject["trainingKillbotEntryState"]
                as? [String: Any]
        )
        XCTAssertEqual(
            try XCTUnwrap(
                killbotEntryState["followupTimerRemaining"] as? Double
            ),
            13,
            accuracy: 0.000_001
        )
        let continuation = try JSONDecoder().decode(
            GameWorld.self,
            from: continuationData
        )
        let restored = try GameSession(
            level: level,
            world: continuation.rebased(onto: level),
            resumedAtTimestamp: 100
        )
        assertTrainingGuidebotReturnBarrier(
            level: restored.runtimeLevel,
            rendersFaces: true
        )

        for frameIndex in 1...129 {
            let frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: .zero
            )
            XCTAssertFalse(
                frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebotf.osf"
                })
            )
        }
        let followupTimestamp = 113.0
        let timer14 = restored.update(
            at: followupTimestamp,
            input: .zero
        )
        XCTAssertEqual(timer14.trainingOpeningFeedback.last, .init(
            hudMessages: [
                "Some parts of this area are very dark.  Turn on your headlight or fire flares to see.  Use your guidebot if you need help finding a robot or powerup.",
            ],
            voiceSourceName: "guidebotf.osf",
            voicePrecedesHUDMessages: true
        ))
        XCTAssertTrue(
            restored.update(
                at: followupTimestamp + 0.1,
                input: .zero
            ).trainingOpeningFeedback.allSatisfy {
                $0.voiceSourceName != "guidebotf.osf"
            }
        )
    }

    func testRASBot1DeathUsesPrimaryLaserOnceAndSurvivesReload() throws {
        let level = makeTrainingRASBot1DeathLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingRASBot1DeathChain)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        var timestamp = 0.0
        for _ in 1...3 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )

        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let deathState = try XCTUnwrap(
            continuationObject["trainingRASBot1DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)
        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedContinuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        let repeatedDeathState = try XCTUnwrap(
            repeatedContinuationObject["trainingRASBot1DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(
            repeatedDeathState["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuationData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        _ = restored.update(
            at: 100.25,
            input: .init(firesPrimaryWeapon: true)
        )
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
    }

    @MainActor
    func testFollowBotDeathRestoresEnergyAndStartsMovingTargetHandoff()
        throws
    {
        var level = makeTrainingMovingTargetHandoffLevel()
        try level.validate()
        let lesson = try XCTUnwrap(
            level.trainingDodgeAttempt?.maneuverFollow
        )
        let handoff = try XCTUnwrap(lesson.destructionHandoff)
        let destroyBot2Initial = try XCTUnwrap(
            level.objects.first {
                $0.handle == handoff.destroyBot2ObjectHandle
            }
        )
        let project = try makeProject(importedBase: level)
        level = replacing(
            level,
            trainingRobotGuidebotChain: .init(
                destroyRobotObjectHandle:
                    handoff.destroyBot2ObjectHandle,
                guidebotObjectHandle: 12_288,
                destroyRobotRoomSourceIndex: 37,
                destroyRobotFlags: 5_121,
                destructionDelay: 2,
                destructionMessage: "Excellent!",
                exitInstruction:
                    "Now go through the open doorway, and into the next room.",
                destructionVoiceSourceName: "proceed5.osf",
                deployedGuidebotObjectType: 2,
                deployedGuidebotMessage: "",
                deployedGuidebotVoiceSourceName: "",
                combat: .stockTraining,
                guidebot: .stockTraining
            )
        )
        let playerHandle = try XCTUnwrap(
            level.defaultPlayerBinding?.objectHandle
        )
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == playerHandle }
        )
        level.objects[playerIndex].location = .room(37)
        level.objects[playerIndex].position = .init(
            x: 2_059.3496,
            y: -723.2588,
            z: 2_400.1072
        )
        level.objects[playerIndex].orientation = .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )
        let roomIndex = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 37 }
        )
        let originalRoom = level.rooms[roomIndex]
        let containment = makeSourceContainmentRoom(
            center: level.objects[playerIndex].position,
            texture: level.surfacePhysics[0].texture,
            sourceIndex: 37,
            halfExtent: 500
        )
        var faces = containment.faces
        let portals = originalRoom.portals.enumerated().map {
            portalIndex, portal in
            let face = faces[portalIndex]
            faces[portalIndex] = .init(
                corners: face.corners,
                flags: face.flags,
                portalIndex: portalIndex,
                texture: face.texture,
                lightmapInfoIndex: face.lightmapInfoIndex,
                allowsLightCorona: face.allowsLightCorona,
                lightMultiple: face.lightMultiple,
                special: face.special
            )
            return LevelPortal(
                flags: portal.flags,
                faceIndex: portalIndex,
                connectedRoom: portal.connectedRoom,
                connectedPortal: portal.connectedPortal,
                boundaryNodeIndex: portal.boundaryNodeIndex,
                pathPoint: portal.pathPoint,
                combineMaster: portal.combineMaster
            )
        }
        level.rooms[roomIndex] = replacing(
            originalRoom,
            vertices: containment.vertices,
            faces: faces,
            portals: portals
        )
        let galleryRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 2 }
        )
        for portalIndex in [1, 0] {
            level.rooms[galleryRoomIndex]
                .portals[portalIndex].flags |= 1
            let portal =
                level.rooms[galleryRoomIndex].portals[portalIndex]
            let reciprocalRoomIndex = try XCTUnwrap(
                level.rooms.firstIndex {
                    $0.sourceIndex == portal.connectedRoom
                }
            )
            level.rooms[reciprocalRoomIndex]
                .portals[portal.connectedPortal].flags |= 1
        }
        level = replacing(
            level,
            trainingGalleryBarrier: .init(
                triggerName: "Portal2",
                triggerRoomSourceIndex: 37,
                triggerFaceIndex: 0,
                barrierRoomSourceIndex: 2,
                orderedPortalIndices: [1, 0],
                markerLightObjectHandle: 6_163,
                openMarkerLightDistance: 50,
                successMessage: "Excellent!",
                guidebotInstruction: "",
                voiceSourceName: ""
            )
        )
        let destroyBot1Index = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == handoff.destroyBot1ObjectHandle
            }
        )
        let firstMovingNode = level.paths[handoff.movingPathIndex]
            .nodes[0]
        let pathForwardLength = sqrt(
            firstMovingNode.forward.x * firstMovingNode.forward.x
                + firstMovingNode.forward.y * firstMovingNode.forward.y
                + firstMovingNode.forward.z * firstMovingNode.forward.z
        )
        let pathForward = Vector3(
            x: firstMovingNode.forward.x / pathForwardLength,
            y: firstMovingNode.forward.y / pathForwardLength,
            z: firstMovingNode.forward.z / pathForwardLength
        )
        let pathRightRaw = Vector3(
            x:
                firstMovingNode.up.y * pathForward.z
                - firstMovingNode.up.z * pathForward.y,
            y:
                firstMovingNode.up.z * pathForward.x
                - firstMovingNode.up.x * pathForward.z,
            z:
                firstMovingNode.up.x * pathForward.y
                - firstMovingNode.up.y * pathForward.x
        )
        let pathRightLength = sqrt(
            pathRightRaw.x * pathRightRaw.x
                + pathRightRaw.y * pathRightRaw.y
                + pathRightRaw.z * pathRightRaw.z
        )
        let pathRight = Vector3(
            x: pathRightRaw.x / pathRightLength,
            y: pathRightRaw.y / pathRightLength,
            z: pathRightRaw.z / pathRightLength
        )
        let pathUp = Vector3(
            x:
                pathForward.y * pathRight.z
                - pathForward.z * pathRight.y,
            y:
                pathForward.z * pathRight.x
                - pathForward.x * pathRight.z,
            z:
                pathForward.x * pathRight.y
                - pathForward.y * pathRight.x
        )
        level.objects[destroyBot1Index].orientation = .init(
            right: pathRight,
            up: pathUp,
            forward: pathForward
        )
        let seed = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        var continuationObject = try XCTUnwrap(
            testWorldObject(seed.world)
        )
        continuationObject["frameDuration"] = 0.1
        continuationObject["gameTime"] = 1
        continuationObject["energy"] = 50.1
        continuationObject["playerControllerBitflags"] =
            lesson.rotationalControlMask
            | lesson.weaponControlMask
        try deferringOsirisTimers(&continuationObject, to: 1_000)
        var galleryState = try XCTUnwrap(
            continuationObject["trainingGalleryBarrierState"]
                as? [String: Any]
        )
        galleryState["markerLightDistance"] = 0
        continuationObject["trainingGalleryBarrierState"] =
            galleryState
        var dodgeState = try XCTUnwrap(
            continuationObject["trainingDodgeAttemptState"]
                as? [String: Any]
        )
        dodgeState["script033Count"] = 1
        dodgeState["script016Count"] = 1
        dodgeState["script017Count"] = 1
        dodgeState["script019Count"] = 1
        dodgeState["script018Count"] = 1
        dodgeState["script020Count"] = 1
        dodgeState["markerLightDistance"] = 0
        continuationObject["trainingDodgeAttemptState"] =
            dodgeState
        var maneuverState = try XCTUnwrap(
            continuationObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        maneuverState["script021Count"] = 1
        maneuverState["script022Count"] = 1
        maneuverState["script024Count"] = 1
        maneuverState["script023Count"] = 1
        maneuverState["script025Count"] = 1
        maneuverState["script026Count"] = 1
        maneuverState["followBotIsPowered"] = true
        maneuverState["followBotTeamFlags"] = 65_536
        maneuverState.removeValue(forKey: "activePathIndex")
        continuationObject["trainingManeuverFollowState"] =
            maneuverState
        var simulation = try GameSession(
            level: level,
            world: (decodeTestWorld(continuationObject)).rebased(onto: level),
            resumedAtTimestamp: 10
        )

        var frame = simulation.update(
            at: 10.25,
            input: .init(firesPrimaryWeapon: true)
        )
        XCTAssertEqual(simulation.energy, 50)
        XCTAssertEqual(frame.trainingPrimaryProjectiles.count, 2)
        XCTAssertTrue(
            frame.trainingPrimaryProjectiles.allSatisfy {
                $0.model == handoff.projectileModel
            }
        )
        let preparedPlan = try makeMetalWorldPlan(
            level: simulation.runtimeLevel,
            playerView: frame.playerView
        )
        let projectilePlan = try updateMetalWorldPlan(
            preparedPlan,
            level: simulation.level,
            objects: simulation.world.objects,
            roomStates: simulation.world.rooms,
            playerView: frame.playerView,
            trainingPrimaryProjectiles:
                frame.trainingPrimaryProjectiles
        )
        XCTAssertEqual(
            Set(projectilePlan.draws.compactMap {
                $0.model == handoff.projectileModel
                    ? $0.objectHandle : nil
            }),
            Set([UInt32.max - 41, UInt32.max - 40])
        )
        var continuationState = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        var continuedManeuver = try XCTUnwrap(
            continuationState["trainingManeuverFollowState"]
                as? [String: Any]
        )
        var continuedDestruction = try XCTUnwrap(
            continuedManeuver["destruction"] as? [String: Any]
        )
        XCTAssertEqual(
            continuedDestruction["script031Count"] as? Int,
            1
        )
        XCTAssertEqual(
            continuedDestruction["followBotShields"] as? Double,
            55
        )

        var timestamp = 10.25
        while simulation.runtimeLevel.objects.contains(where: {
            $0.handle == handoff.followBotObjectHandle
        }) {
            timestamp += 0.25
            frame = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
            XCTAssertLessThan(timestamp, 15)
        }
        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == handoff.followBotObjectHandle
        })
        continuationState = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        continuedManeuver = try XCTUnwrap(
            continuationState["trainingManeuverFollowState"]
                as? [String: Any]
        )
        continuedDestruction = try XCTUnwrap(
            continuedManeuver["destruction"] as? [String: Any]
        )
        XCTAssertEqual(
            continuedDestruction["script037Count"] as? Int,
            1
        )
        XCTAssertEqual(
            continuedDestruction["levelTimer11Remaining"] as? Double,
            2
        )
        XCTAssertEqual(
            continuedDestruction["script027Count"] as? Int,
            0
        )

        repeat {
            timestamp += 0.25
            frame = simulation.update(at: timestamp, input: .zero)
            XCTAssertLessThan(timestamp, 18)
        } while frame.trainingOpeningFeedback.isEmpty
        XCTAssertEqual(
            frame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [handoff.successMessage],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: [handoff.movingInstruction],
                    voiceSourceName: handoff.voiceSourceName,
                    voicePrecedesHUDMessages: false
                ),
            ]
        )
        let continuationAfterHandoff = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        let maneuverAfterHandoff = try XCTUnwrap(
            continuationAfterHandoff[
                "trainingManeuverFollowState"
            ] as? [String: Any]
        )
        let destructionAfterHandoff = try XCTUnwrap(
            maneuverAfterHandoff["destruction"] as? [String: Any]
        )
        XCTAssertEqual(
            destructionAfterHandoff["script027Count"] as? Int,
            1
        )
        XCTAssertEqual(
            frame.trainingMovingTarget?.activePathIndex,
            handoff.movingPathIndex
        )
        XCTAssertEqual(
            project.trainingManeuverFollowRuntimeDiagnostic(
                frame: frame
            ),
            "\(project.trainingManeuverFollowSourceDiagnostic!) / active moving target DestroyBot1 path \(handoff.movingPathIndex) node 0 room 37 failure none"
        )
        XCTAssertTrue(
            editorPlayStatusMessage(
                project: project,
                frame: frame
            ).contains("active moving target DestroyBot1")
        )
        let destroyBot1BeforeMotion = try XCTUnwrap(
            simulation.runtimeLevel.objects.first {
                $0.handle == handoff.destroyBot1ObjectHandle
            }
        )
        timestamp += 0.25
        frame = simulation.update(at: timestamp, input: .zero)
        let destroyBot1AfterMotion = try XCTUnwrap(
            simulation.runtimeLevel.objects.first {
                $0.handle == handoff.destroyBot1ObjectHandle
            }
        )
        let displacement = Vector3(
            x:
                destroyBot1AfterMotion.position.x
                - destroyBot1BeforeMotion.position.x,
            y:
                destroyBot1AfterMotion.position.y
                - destroyBot1BeforeMotion.position.y,
            z:
                destroyBot1AfterMotion.position.z
                - destroyBot1BeforeMotion.position.z
        )
        let displacementLength = sqrt(
            displacement.x * displacement.x
                + displacement.y * displacement.y
                + displacement.z * displacement.z
        )
        XCTAssertGreaterThan(displacementLength, 0)
        let movingDirection = Vector3(
            x: displacement.x / displacementLength,
            y: displacement.y / displacementLength,
            z: displacement.z / displacementLength
        )
        let initialAlignment =
            destroyBot1BeforeMotion.orientation.forward.x
                * movingDirection.x
            + destroyBot1BeforeMotion.orientation.forward.y
                * movingDirection.y
            + destroyBot1BeforeMotion.orientation.forward.z
                * movingDirection.z
        let movedAlignment =
            destroyBot1AfterMotion.orientation.forward.x
                * movingDirection.x
            + destroyBot1AfterMotion.orientation.forward.y
                * movingDirection.y
            + destroyBot1AfterMotion.orientation.forward.z
                * movingDirection.z
        XCTAssertGreaterThan(movedAlignment, initialAlignment)

        var oldSchemaSeven = continuationAfterHandoff
        var oldSchemaSevenManeuver = try XCTUnwrap(
            oldSchemaSeven["trainingManeuverFollowState"]
                as? [String: Any]
        )
        var oldSchemaSevenDestruction = try XCTUnwrap(
            oldSchemaSevenManeuver["destruction"]
                as? [String: Any]
        )
        oldSchemaSevenDestruction.removeValue(
            forKey: "destroyBot1Destruction"
        )
        oldSchemaSevenManeuver["destruction"] =
            oldSchemaSevenDestruction
        oldSchemaSeven["trainingManeuverFollowState"] =
            oldSchemaSevenManeuver
        let oldSchemaSevenSimulation = try GameSession(
            level: level,
            world: (decodeTestWorld(oldSchemaSeven)).rebased(onto: level),
            resumedAtTimestamp: 150
        )
        let oldSchemaSevenFrame = oldSchemaSevenSimulation.update(
            at: 150.25,
            input: .zero
        )
        XCTAssertTrue(
            oldSchemaSevenFrame.trainingOpeningFeedback.isEmpty
        )
        XCTAssertEqual(
            oldSchemaSevenFrame.trainingMovingTarget?.objectHandle,
            handoff.destroyBot1ObjectHandle
        )

        func restoringAim(
            _ source: GameSession,
            at target: PlacedObject,
            timestamp: Double
        ) throws -> GameSession {
            let sourceContinuationData = try JSONEncoder().encode(
                source.world
            )
            var aimedContinuation = try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: sourceContinuationData
                ) as? [String: Any]
            )
            aimedContinuation["playerLocation"] = [
                "room": ["_0": 37],
            ]
            aimedContinuation["playerPosition"] = [
                "x": target.position.x
                    - target.orientation.forward.x * 10,
                "y": target.position.y
                    - target.orientation.forward.y * 10,
                "z": target.position.z
                    - target.orientation.forward.z * 10,
            ]
            aimedContinuation["playerOrientation"] = [
                "right": [
                    "x": target.orientation.right.x,
                    "y": target.orientation.right.y,
                    "z": target.orientation.right.z,
                ],
                "up": [
                    "x": target.orientation.up.x,
                    "y": target.orientation.up.y,
                    "z": target.orientation.up.z,
                ],
                "forward": [
                    "x": target.orientation.forward.x,
                    "y": target.orientation.forward.y,
                    "z": target.orientation.forward.z,
                ],
            ]
            aimedContinuation["velocity"] = [
                "x": 0,
                "y": 0,
                "z": 0,
            ]
            aimedContinuation["angularVelocity"] = [
                "x": 0,
                "y": 0,
                "z": 0,
            ]
            return try GameSession(
                level: level,
                world: (decodeTestWorld(aimedContinuation)).rebased(onto: level),
                resumedAtTimestamp: timestamp
            )
        }

        timestamp = 200
        for _ in 0..<4 {
            simulation = try restoringAim(
                simulation,
                at: try XCTUnwrap(
                    simulation.runtimeLevel.objects.first {
                        $0.handle == handoff.destroyBot1ObjectHandle
                    }
                ),
                timestamp: timestamp
            )
            timestamp += 0.25
            frame = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }
        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == handoff.destroyBot1ObjectHandle
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == handoff.destroyBot2ObjectHandle
        })
        XCTAssertTrue(frame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            frame.trainingMovingTarget?.objectHandle,
            handoff.destroyBot2ObjectHandle
        )
        XCTAssertEqual(
            frame.trainingMovingTarget?.activePathIndex,
            handoff.movingPathIndex
        )
        XCTAssertEqual(
            project.trainingManeuverFollowRuntimeDiagnostic(
                frame: frame
            ),
            "\(project.trainingManeuverFollowSourceDiagnostic!) / active moving target DestroyBot2 path \(handoff.movingPathIndex) node \(frame.trainingMovingTarget!.pathNodeIndex) room 37 failure none"
        )
        var script028Continuation = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        var script028Maneuver = try XCTUnwrap(
            script028Continuation[
                "trainingManeuverFollowState"
            ] as? [String: Any]
        )
        var script028Destruction = try XCTUnwrap(
            script028Maneuver["destruction"] as? [String: Any]
        )
        let destroyBot1Destruction = try XCTUnwrap(
            script028Destruction["destroyBot1Destruction"]
                as? [String: Any]
        )
        XCTAssertEqual(
            destroyBot1Destruction["destroyBot1Shields"] as? Double,
            -5
        )
        XCTAssertEqual(
            destroyBot1Destruction["destroyBot1WasDestroyed"] as? Bool,
            true
        )
        XCTAssertEqual(
            destroyBot1Destruction["script028Count"] as? Int,
            1
        )
        XCTAssertEqual(
            script028Destruction["destroyBot2IsVisible"] as? Bool,
            true
        )

        let destroyBot2BeforeMotion = try XCTUnwrap(
            simulation.runtimeLevel.objects.first {
                $0.handle == handoff.destroyBot2ObjectHandle
            }
        )
        XCTAssertEqual(
            destroyBot2BeforeMotion.position,
            destroyBot2Initial.position
        )
        XCTAssertEqual(
            destroyBot2BeforeMotion.orientation,
            destroyBot2Initial.orientation
        )
        timestamp += 0.25
        frame = simulation.update(at: timestamp, input: .zero)
        let destroyBot2AfterMotion = try XCTUnwrap(
            simulation.runtimeLevel.objects.first {
                $0.handle == handoff.destroyBot2ObjectHandle
            }
        )
        XCTAssertNotEqual(
            destroyBot2AfterMotion.position,
            destroyBot2BeforeMotion.position
        )

        let script028Restored = try GameSession(
            level: level,
            world: simulation.world.rebased(onto: level),
            resumedAtTimestamp: 300
        )
        let script028Silent = script028Restored.update(
            at: 300.25,
            input: .zero
        )
        XCTAssertTrue(script028Silent.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            script028Silent.trainingMovingTarget?.objectHandle,
            handoff.destroyBot2ObjectHandle
        )
        simulation = script028Restored
        timestamp = 400
        var movingTargetPlan: MetalWorldPlan?
        for volleyIndex in 0..<4 {
            simulation = try restoringAim(
                simulation,
                at: try XCTUnwrap(
                    simulation.runtimeLevel.objects.first {
                        $0.handle == handoff.destroyBot2ObjectHandle
                    }
                ),
                timestamp: timestamp
            )
            if volleyIndex == 3 {
                let prepared = try makeMetalWorldPlan(
                    level: simulation.runtimeLevel,
                    playerView: defaultPlayerView(
                        in: simulation.runtimeLevel
                    )
                )
                XCTAssertTrue(prepared.draws.contains {
                    $0.objectHandle
                        == handoff.destroyBot2ObjectHandle
                })
                movingTargetPlan = prepared
            }
            timestamp += 0.25
            frame = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
            if volleyIndex == 2 {
                XCTAssertTrue(simulation.runtimeLevel.objects.contains {
                    $0.handle
                        == handoff.destroyBot2ObjectHandle
                })
                let threeVolleyContinuation = try XCTUnwrap(
                    testWorldObject(simulation.world)
                )
                let threeVolleyRobotState = try XCTUnwrap(
                    threeVolleyContinuation[
                        "trainingRobotGuidebotState"
                    ] as? [String: Any]
                )
                XCTAssertEqual(
                    threeVolleyRobotState[
                        "robotShields"
                    ] as? Double,
                    10
                )
            }
        }
        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == handoff.destroyBot2ObjectHandle
        })
        XCTAssertTrue(frame.trainingOpeningFeedback.isEmpty)
        XCTAssertNil(frame.trainingMovingTarget)
        XCTAssertEqual(frame.enabledPlayerControls, .all)
        XCTAssertTrue(frame.showsEnabledPlayerControls)
        XCTAssertEqual(frame.trainingGalleryMarkerLightDistance, 50)
        assertTrainingGalleryBarrier(
            level: simulation.runtimeLevel,
            rendersFaces: false
        )
        let destroyedTargetPlan = try updateMetalWorldPlan(
            try XCTUnwrap(movingTargetPlan),
            level: simulation.level,
            objects: simulation.world.objects,
            roomStates: simulation.world.rooms,
            playerView: frame.playerView
        )
        XCTAssertFalse(destroyedTargetPlan.draws.contains {
            $0.objectHandle == handoff.destroyBot2ObjectHandle
        })
        script028Continuation = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        let guidebotState = try XCTUnwrap(
            script028Continuation["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(guidebotState["robotShields"] as? Double, -5)
        XCTAssertEqual(
            guidebotState["robotWasDestroyed"] as? Bool,
            true
        )
        XCTAssertEqual(
            guidebotState["destructionTimerRemaining"] as? Double,
            2
        )
        XCTAssertEqual(
            guidebotState["destructionFeedbackWasPresented"] as? Bool,
            false
        )
        XCTAssertEqual(
            guidebotState["controlsWereRestored"] as? Bool,
            true
        )
        XCTAssertEqual(
            guidebotState["enabledControlHUDIsVisible"] as? Bool,
            true
        )

        script028Maneuver = try XCTUnwrap(
            script028Continuation[
                "trainingManeuverFollowState"
            ] as? [String: Any]
        )
        script028Destruction = try XCTUnwrap(
            script028Maneuver["destruction"] as? [String: Any]
        )
        XCTAssertEqual(
            script028Destruction["destroyBot2IsVisible"] as? Bool,
            false
        )
        let postDeathDestroyBot1State = try XCTUnwrap(
            script028Destruction["destroyBot1Destruction"]
                as? [String: Any]
        )
        let postDeathDestroyBot2Motion = try XCTUnwrap(
            postDeathDestroyBot1State["destroyBot2Motion"]
                as? [String: Any]
        )
        XCTAssertNil(postDeathDestroyBot2Motion["activePathIndex"])
        XCTAssertEqual(
            postDeathDestroyBot2Motion["pathNodeIndex"] as? Int,
            0
        )
        XCTAssertEqual(
            postDeathDestroyBot2Motion["velocity"] as? [String: Double],
            ["x": 0, "y": 0, "z": 0]
        )

        let pendingTimerSimulation = try GameSession(
            level: level,
            world: simulation.world.rebased(onto: level),
            resumedAtTimestamp: 500
        )
        XCTAssertFalse(pendingTimerSimulation.runtimeLevel.objects.contains {
            $0.handle == handoff.destroyBot2ObjectHandle
        })
        assertTrainingGalleryBarrier(
            level: pendingTimerSimulation.runtimeLevel,
            rendersFaces: false
        )
        var timerFrame = pendingTimerSimulation.update(
            at: 500.25,
            input: .zero
        )
        XCTAssertTrue(timerFrame.trainingOpeningFeedback.isEmpty)
        var pendingTimerObject = try XCTUnwrap(
            testWorldObject(pendingTimerSimulation.world)
        )
        var pendingTimerState = try XCTUnwrap(
            pendingTimerObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(
            pendingTimerState["destructionTimerRemaining"] as? Double,
            1.75
        )
        for tick in 2...7 {
            timerFrame = pendingTimerSimulation.update(
                at: 500 + Double(tick) * 0.25,
                input: .zero
            )
            XCTAssertTrue(timerFrame.trainingOpeningFeedback.isEmpty)
        }
        timerFrame = pendingTimerSimulation.update(
            at: 502,
            input: .zero
        )
        XCTAssertEqual(
            timerFrame.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Excellent!",
                    "Now go through the open doorway, and into the next room.",
                ],
                voiceSourceName: "proceed5.osf",
                voicePrecedesHUDMessages: false
            )]
        )
        XCTAssertFalse(timerFrame.showsEnabledPlayerControls)
        let oneShotFrame = pendingTimerSimulation.update(
            at: 502.25,
            input: .zero
        )
        XCTAssertTrue(oneShotFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertFalse(oneShotFrame.showsEnabledPlayerControls)
        pendingTimerObject = try XCTUnwrap(
            testWorldObject(pendingTimerSimulation.world)
        )
        pendingTimerState = try XCTUnwrap(
            pendingTimerObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertNil(
            pendingTimerState["destructionTimerRemaining"]
        )
        XCTAssertEqual(
            pendingTimerState["destructionFeedbackWasPresented"]
                as? Bool,
            true
        )
        XCTAssertEqual(
            pendingTimerState["enabledControlHUDIsVisible"] as? Bool,
            false
        )

        let presentedTimerSimulation = try GameSession(
            level: level,
            world: pendingTimerSimulation.world.rebased(onto: level),
            resumedAtTimestamp: 600
        )
        let presentedTimerFrame = presentedTimerSimulation.update(
            at: 600.25,
            input: .zero
        )
        XCTAssertTrue(
            presentedTimerFrame.trainingOpeningFeedback.isEmpty
        )
        XCTAssertFalse(
            presentedTimerFrame.showsEnabledPlayerControls
        )
        XCTAssertNil(presentedTimerFrame.trainingMovingTarget)
        XCTAssertFalse(presentedTimerSimulation.runtimeLevel.objects.contains {
            $0.handle == handoff.destroyBot2ObjectHandle
        })
        assertTrainingGalleryBarrier(
            level: presentedTimerSimulation.runtimeLevel,
            rendersFaces: false
        )

        var timerCoincidence = continuationObject
        var timerManeuver = try XCTUnwrap(
            timerCoincidence["trainingManeuverFollowState"]
                as? [String: Any]
        )
        var timerDestruction = try XCTUnwrap(
            timerManeuver["destruction"] as? [String: Any]
        )
        timerDestruction["levelTimer11Remaining"] = 0.05
        timerManeuver["destruction"] = timerDestruction
        timerCoincidence["trainingManeuverFollowState"] =
            timerManeuver
        let coincidentSimulation = try GameSession(
            level: level,
            world: (decodeTestWorld(timerCoincidence)).rebased(onto: level),
            resumedAtTimestamp: 20
        )
        let coincidentFrame = coincidentSimulation.update(
            at: 20.25,
            input: .zero
        )
        XCTAssertEqual(
            coincidentFrame.trainingMovingTarget?.activePathIndex,
            handoff.movingPathIndex
        )
        XCTAssertNoThrow(
            try GameSession(
                level: level,
                world: coincidentSimulation.world.rebased(onto: level),
                resumedAtTimestamp: 30
            )
        )

        let restored = try GameSession(
            level: level,
            world: simulation.world.rebased(onto: level),
            resumedAtTimestamp: 100
        )
        let silent = restored.update(at: 100.25, input: .zero)
        XCTAssertTrue(silent.trainingOpeningFeedback.isEmpty)
        XCTAssertNil(silent.trainingMovingTarget)
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == handoff.destroyBot2ObjectHandle
        })
        assertTrainingGalleryBarrier(
            level: restored.runtimeLevel,
            rendersFaces: false
        )
    }

    func testRASBot2DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        let level = makeTrainingRASBot2DeathLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingRASBot2DeathChain)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == 2_074
        })
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let deathState = try XCTUnwrap(
            continuationObject["trainingRASBot2DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        XCTAssertEqual(
            (repeatedObject["trainingRASBot2DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuationData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.runtimeLevel.objects.contains {
            $0.handle == 2_074
        })
    }

    func testRASBot3DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingRASBot3DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(42)
        let chain = try XCTUnwrap(level.trainingRASBot3DeathChain)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == 2_074
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == 2_075
        })
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let deathState = try XCTUnwrap(
            continuationObject["trainingRASBot3DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        XCTAssertEqual(
            (repeatedObject["trainingRASBot3DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuationData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.runtimeLevel.objects.contains {
            $0.handle == 2_074
        })
        XCTAssertTrue(restored.runtimeLevel.objects.contains {
            $0.handle == 2_075
        })
    }

    func testRASBot4DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingRASBot4DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(0)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_077 }
        )
        level.objects[fartherTargetIndex].location = .room(0)
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingRASBot4DeathChain)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == 2_074
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == 2_075
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == 2_077
        })
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let deathState = try XCTUnwrap(
            continuationObject["trainingRASBot4DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        XCTAssertEqual(
            (repeatedObject["trainingRASBot4DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuationData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.runtimeLevel.objects.contains {
            $0.handle == 2_074
        })
        XCTAssertTrue(restored.runtimeLevel.objects.contains {
            $0.handle == 2_075
        })
        XCTAssertTrue(restored.runtimeLevel.objects.contains {
            $0.handle == 2_077
        })
    }

    func testLastBot1DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingLastBot1DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(14)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_078 }
        )
        level.objects[fartherTargetIndex].location = .room(14)
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingLastBot1DeathChain)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == 2_078
        })
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let deathState = try XCTUnwrap(
            continuationObject["trainingLastBot1DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        XCTAssertEqual(
            (repeatedObject["trainingLastBot1DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuationData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.runtimeLevel.objects.contains {
            $0.handle == 2_078
        })

    }

    func testLastBot2DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingLastBot2DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(46)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 4_127 }
        )
        level.objects[fartherTargetIndex].location = .room(46)
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingLastBot2DeathChain)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == 4_127
        })
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let deathState = try XCTUnwrap(
            continuationObject["trainingLastBot2DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        XCTAssertEqual(
            (repeatedObject["trainingLastBot2DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuationData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.runtimeLevel.objects.contains {
            $0.handle == 4_127
        })

    }

    func testLastBot3DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingLastBot3DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(47)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_080 }
        )
        level.objects[fartherTargetIndex].location = .room(47)
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingLastBot3DeathChain)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == 2_080
        })
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let deathState = try XCTUnwrap(
            continuationObject["trainingLastBot3DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        XCTAssertEqual(
            (repeatedObject["trainingLastBot3DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuationData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.runtimeLevel.objects.contains {
            $0.handle == 2_080
        })

    }

    func testLastBot4DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingLastBot4DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(47)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_081 }
        )
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingLastBot4DeathChain)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == 2_081
        })
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let deathState = try XCTUnwrap(
            continuationObject["trainingLastBot4DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        XCTAssertEqual(
            (repeatedObject["trainingLastBot4DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuationData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.runtimeLevel.objects.contains {
            $0.handle == 2_081
        })

    }

    func testLastBot5DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingLastBot5DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(48)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_082 }
        )
        level.objects[fartherTargetIndex].location = .room(48)
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingLastBot5DeathChain)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.runtimeLevel.objects.contains {
            $0.handle == 2_082
        })
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let deathState = try XCTUnwrap(
            continuationObject["trainingLastBot5DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        XCTAssertEqual(
            (repeatedObject["trainingLastBot5DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuationData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.runtimeLevel.objects.contains {
            $0.handle == 2_082
        })

    }
    func testInvulnPowerup2ConsumesOnceAndExpiresAcrossContinuation()
        throws
    {
        let level = makeTrainingInvulnerabilityPickupLevel()
        try level.validate()
        var runtimeLevel = level
        let playerIndex = runtimeLevel.objects.firstIndex {
            $0.handle == 2_048
        }!
        let pickupObject = runtimeLevel.objects.first {
            $0.handle == 2_076
        }!
        let chain = try XCTUnwrap(
            runtimeLevel.trainingInvulnerabilityPickupChain
        )
        let playerRadius = defaultPlayerView(
            in: runtimeLevel
        ).collisionRadius
        let combinedRadius =
            playerRadius + chain.pickupCollisionRadius
        runtimeLevel.objects[playerIndex].location = .room(12)
        runtimeLevel.objects[playerIndex].position = .init(
            x: pickupObject.position.x + combinedRadius + 0.01,
            y: pickupObject.position.y,
            z: pickupObject.position.z
        )
        let outside = GameSession(
            level: runtimeLevel,
            presentationReadyTimestamp: 0
        )
        let outsideFrame = outside.update(at: 0.1, input: .init())
        XCTAssertNil(outsideFrame.trainingInvulnerabilityRemaining)
        XCTAssertTrue(
            outside.runtimeLevel.objects.contains {
                $0.handle == chain.pickupObjectHandle
            })

        runtimeLevel.objects[playerIndex].position = .init(
            x: pickupObject.position.x + combinedRadius - 0.01,
            y: pickupObject.position.y,
            z: pickupObject.position.z
        )
        let simulation = GameSession(
            level: runtimeLevel,
            presentationReadyTimestamp: 0
        )

        let pickup = simulation.update(at: 0.1, input: .init())

        XCTAssertEqual(
            try XCTUnwrap(
                pickup.trainingInvulnerabilityRemaining
            ),
            29.9,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            pickup.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Invulnerability On"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "Invon.wav"
                ),
                .init(
                    hudMessages: [],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "Power03.wav"
                ),
            ])
        XCTAssertFalse(
            simulation.runtimeLevel.objects.contains {
                $0.handle == chain.pickupObjectHandle
            })
        XCTAssertEqual(
            RevivalGameplayView.invulnerabilityStatusText(
                remaining: pickup.trainingInvulnerabilityRemaining
            ),
            "INVULNERABLE 29.9"
        )
        let pulseStart = try XCTUnwrap(
            RevivalGameplayView.invulnerabilityMonitorPulse(
                remaining: pickup.trainingInvulnerabilityRemaining,
                gameTime: 12,
                drawableWidth: 1_600,
                drawableHeight: 900
            )
        )
        let pulseQuarter = try XCTUnwrap(
            RevivalGameplayView.invulnerabilityMonitorPulse(
                remaining: pickup.trainingInvulnerabilityRemaining,
                gameTime: 12.25,
                drawableWidth: 1_600,
                drawableHeight: 900
            )
        )
        XCTAssertEqual(pulseStart.frame.width, pulseStart.frame.height)
        XCTAssertEqual(
            pulseQuarter.frame.width,
            pulseQuarter.frame.height
        )
        XCTAssertEqual(
            pulseQuarter.frame.width / pulseStart.frame.width,
            1.03,
            accuracy: 0.000_1
        )
        XCTAssertEqual(pulseStart.alpha, 1, accuracy: 0.000_1)
        XCTAssertEqual(pulseQuarter.alpha, 0.875, accuracy: 0.000_1)
        let portraitPulse = try XCTUnwrap(
            RevivalGameplayView.invulnerabilityMonitorPulse(
                remaining: pickup.trainingInvulnerabilityRemaining,
                gameTime: 12.25,
                drawableWidth: 900,
                drawableHeight: 1_600
            )
        )
        XCTAssertEqual(
            portraitPulse.frame.width,
            portraitPulse.frame.height
        )
        XCTAssertNil(
            RevivalGameplayView.invulnerabilityMonitorPulse(
                remaining: nil,
                gameTime: 12.25,
                drawableWidth: 1_600,
                drawableHeight: 900
            )
        )

        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let invulnerabilityState = try XCTUnwrap(
            continuationObject["trainingInvulnerabilityPickupState"]
                as? [String: Any]
        )
        XCTAssertEqual(invulnerabilityState["wasConsumed"] as? Bool, true)
        XCTAssertEqual(
            try XCTUnwrap(
                invulnerabilityState["remainingDuration"] as? Double
            ),
            29.9,
            accuracy: 0.000_1
        )

        let restored = try GameSession(
            level: runtimeLevel,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuationData
            )).rebased(onto: runtimeLevel),
            resumedAtTimestamp: 100
        )
        let afterReload = restored.update(at: 100.1, input: .init())
        XCTAssertEqual(
            try XCTUnwrap(
                afterReload.trainingInvulnerabilityRemaining
            ),
            29.8,
            accuracy: 0.000_1
        )
        XCTAssertTrue(afterReload.trainingOpeningFeedback.isEmpty)

        let handoff = restored.update(at: 130.0, input: .init())
        XCTAssertEqual(
            try XCTUnwrap(
                handoff.trainingInvulnerabilityRemaining
            ),
            29.7,
            accuracy: 0.000_1
        )
        XCTAssertTrue(handoff.trainingOpeningFeedback.isEmpty)
        let expired = restored.update(at: 130.1, input: .init())
        XCTAssertNil(expired.trainingInvulnerabilityRemaining)
        XCTAssertEqual(
            expired.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Invulnerability Off"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "Invoff.wav"
                )
            ])
        XCTAssertEqual(
            RevivalGameplayView.invulnerabilityStatusText(
                remaining: expired.trainingInvulnerabilityRemaining
            ),
            ""
        )

        let postExpiry = try GameSession(
            level: runtimeLevel,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: JSONEncoder().encode(restored.world)
            )).rebased(onto: runtimeLevel),
            resumedAtTimestamp: 200
        )
        let repeated = postExpiry.update(at: 200.1, input: .init())
        XCTAssertNil(repeated.trainingInvulnerabilityRemaining)
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertFalse(
            postExpiry.runtimeLevel.objects.contains {
                $0.handle == chain.pickupObjectHandle
            })
    }

    func testCloakPowerup2FadesAndPersistsItsStockVisibilityEffect()
        throws
    {
        var level = makeTrainingCloakPickupLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingCloakPickupChain)
        let pickup = try XCTUnwrap(level.objects.first {
            $0.handle == chain.pickupObjectHandle
        })
        let playerIndex = level.objects.firstIndex {
            $0.handle == 2_048
        }!
        let combinedRadius =
            defaultPlayerView(in: level).collisionRadius
            + chain.pickupCollisionRadius
        level.objects[playerIndex].location =
            .room(chain.pickupRoomSourceIndex)
        level.objects[playerIndex].position = .init(
            x: pickup.position.x + combinedRadius - 0.01,
            y: pickup.position.y,
            z: pickup.position.z
        )
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        var frame = simulation.update(at: 0.1, input: .zero)

        XCTAssertEqual(frame.trainingCloak?.phase, .fadingOut)
        XCTAssertEqual(
            try XCTUnwrap(frame.trainingCloak?.objectAlpha),
            0.908,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Cloak On"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "ShpCloakOn.wav"
                ),
                .init(
                    hudMessages: [],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "Power03.wav"
                ),
            ]
        )
        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == chain.pickupObjectHandle
        })
        for frameIndex in 2...10 {
            frame = simulation.update(
                at: Double(frameIndex) * 0.1,
                input: .zero
            )
        }
        XCTAssertEqual(frame.trainingCloak?.phase, .cloaked)
        XCTAssertEqual(frame.trainingCloak?.objectAlpha, 0.13)
        XCTAssertEqual(
            RevivalGameplayView.cloakStatusPresentation(
                frame.trainingCloak
            ).cloakText,
            "CLK"
        )
        let warningPulse =
            RevivalGameplayView.cloakStatusPresentation(.init(
                phase: .cloaked,
                phaseRemaining: 2.25,
                phaseDuration: 30
            ))
        XCTAssertEqual(warningPulse.cloakText, "CLK")
        XCTAssertEqual(
            warningPulse.shipOpacity,
            128.0 / 255,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            warningPulse.cloakOpacity,
            127.0 / 255,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            warningPulse.shipOpacity + warningPulse.cloakOpacity,
            1,
            accuracy: 0.000_1
        )
        let shipMonitorPath =
            RevivalGameplayView.cloakShipMonitorPath(
                in: CGRect(x: 0, y: 0, width: 96, height: 28)
            )
        XCTAssertFalse(shipMonitorPath.isEmpty)
        XCTAssertGreaterThan(
            shipMonitorPath.boundingBoxOfPath.width,
            shipMonitorPath.boundingBoxOfPath.height
        )
        XCTAssertGreaterThan(
            shipMonitorPath.boundingBoxOfPath.height,
            10
        )
        let continuationData = try JSONEncoder().encode(
            simulation.world
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        let cloakState = try XCTUnwrap(
            continuationObject["trainingCloakPickupState"]
                as? [String: Any]
        )
        XCTAssertEqual(cloakState["wasConsumed"] as? Bool, true)
        XCTAssertEqual(cloakState["phase"] as? String, "cloaked")

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuationData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        frame = restored.update(at: 100.1, input: .zero)
        XCTAssertEqual(frame.trainingCloak?.phase, .cloaked)
        XCTAssertTrue(frame.trainingOpeningFeedback.isEmpty)

        var nearExpiryObject = continuationObject
        var nearExpiryState = cloakState
        nearExpiryState["phaseRemaining"] = 0.1
        nearExpiryObject["trainingCloakPickupState"] = nearExpiryState
        let nearExpiry = try GameSession(
            level: level,
            world: (decodeTestWorld(nearExpiryObject)).rebased(onto: level),
            resumedAtTimestamp: 200
        )
        let fadeIn = nearExpiry.update(at: 200.1, input: .zero)
        XCTAssertEqual(fadeIn.trainingCloak?.phase, .fadingIn)
        XCTAssertEqual(fadeIn.trainingCloak?.objectAlpha, 0.08)
        XCTAssertEqual(
            fadeIn.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Cloak Off"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "ShpCloakOffBeep.wav"
                )
            ]
        )
        XCTAssertEqual(
            RevivalGameplayView.cloakStatusPresentation(
                fadeIn.trainingCloak
            ).cloakText,
            ""
        )
        var finalFrame = fadeIn
        for frameIndex in 2...11 {
            finalFrame = nearExpiry.update(
                at: 200 + Double(frameIndex) * 0.1,
                input: .zero
            )
        }
        XCTAssertNil(finalFrame.trainingCloak)
        XCTAssertTrue(finalFrame.trainingOpeningFeedback.isEmpty)

        let postExpiry = try GameSession(
            level: level,
            world: nearExpiry.world.rebased(onto: level),
            resumedAtTimestamp: 300
        )
        let repeated = postExpiry.update(at: 300.1, input: .zero)
        XCTAssertNil(repeated.trainingCloak)
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertFalse(postExpiry.runtimeLevel.objects.contains {
            $0.handle == chain.pickupObjectHandle
        })
    }

    func testCloakPowerup2SixthProducerRunsScript034AndTimerNineOnce()
        throws
    {
        let level = makeTrainingCloakPickupLevel()
        let cloak = try XCTUnwrap(level.trainingCloakPickupChain)
        let pickup = try XCTUnwrap(level.objects.first {
            $0.handle == cloak.pickupObjectHandle
        })
        let initial = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        var readyObject = try XCTUnwrap(
            testWorldObject(initial.world)
        )
        for key in [
            "trainingRASBot1DeathState",
            "trainingRASBot2DeathState",
            "trainingRASBot3DeathState",
            "trainingRASBot4DeathState",
        ] {
            readyObject[key] = [
                "wasDestroyed": true,
                "shields": -5,
            ]
        }
        readyObject["trainingInvulnerabilityPickupState"] = [
            "scriptWasTriggered": true,
            "wasConsumed": true,
        ]
        readyObject["playerLocation"] = [
            "room": ["_0": cloak.pickupRoomSourceIndex]
        ]
        readyObject["playerPosition"] = [
            "x": pickup.position.x,
            "y": pickup.position.y,
            "z": pickup.position.z,
        ]
        let simulation = try GameSession(
            level: level,
            world: (decodeTestWorld(readyObject)).rebased(onto: level),
            resumedAtTimestamp: 0
        )

        var frame = simulation.update(at: 0.1, input: .zero)

        let chain = try XCTUnwrap(level.trainingLastRoomChain)
        func assertBarrierIsOpen(in level: Level) throws {
            let barrier = try XCTUnwrap(level.rooms.first {
                $0.sourceIndex == chain.barrierRoomSourceIndex
            })
            for portalIndex in chain.orderedPortalIndices {
                let portal = barrier.portals[portalIndex]
                XCTAssertEqual(portal.flags & 1, 0)
                let connected = try XCTUnwrap(level.rooms.first {
                    $0.sourceIndex == portal.connectedRoom
                })
                XCTAssertEqual(
                    connected.portals[portal.connectedPortal].flags & 1,
                    0
                )
            }
        }
        XCTAssertEqual(chain.orderedPortalIndices, [1, 0])
        try assertBarrierIsOpen(in: simulation.runtimeLevel)
        XCTAssertEqual(frame.trainingLastRoomMarkerLightDistance, 50)
        XCTAssertFalse(frame.trainingOpeningFeedback.contains {
            $0.voiceSourceName == "proceed5.osf"
        })
        let triggeredData = try JSONEncoder().encode(
            simulation.world
        )
        let triggeredObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: triggeredData)
                as? [String: Any]
        )
        let triggeredState = try XCTUnwrap(
            triggeredObject["trainingLastRoomState"]
                as? [String: Any]
        )
        XCTAssertEqual(triggeredState["wasTriggered"] as? Bool, true)
        XCTAssertEqual(
            try XCTUnwrap(
                triggeredState["timerRemaining"] as? Double
            ),
            2,
            accuracy: 0.000_1
        )

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: triggeredData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        try assertBarrierIsOpen(in: restored.runtimeLevel)
        for frameIndex in 1...20 {
            frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: .zero
            )
        }
        XCTAssertEqual(
            frame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [
                        "Excellent!",
                        "Now proceed through the doorway that just opened to begin the last stage of your training.",
                    ],
                    voiceSourceName: "proceed5.osf",
                    voicePrecedesHUDMessages: false
                )
            ]
        )
        let repeated = restored.update(at: 102.1, input: .zero)
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(repeated.trainingLastRoomMarkerLightDistance, 50)

        let completed = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: JSONEncoder().encode(restored.world)
            )).rebased(onto: level),
            resumedAtTimestamp: 200
        )
        try assertBarrierIsOpen(in: completed.runtimeLevel)
        let resumedCompleted = completed.update(
            at: 200.1,
            input: .zero
        )
        XCTAssertTrue(
            resumedCompleted.trainingOpeningFeedback.isEmpty
        )
        XCTAssertEqual(
            resumedCompleted.trainingLastRoomMarkerLightDistance,
            50
        )
    }

    func testScript050ClosesPortalRoomSixInSourceOrderAndSurvivesReload()
        throws
    {
        let level = makeTrainingFinalRoomEntryLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingFinalRoomEntryChain)
        let simulation = try GameSession(
            level: level,
            world: (script050ReadyContinuation(in: level)).rebased(onto: level),
            resumedAtTimestamp: 0
        )

        let frame = simulation.update(at: 0.1, input: .zero)

        XCTAssertEqual(
            frame.trainingOpeningFeedback.suffix(2),
            [
                .init(
                    hudMessages: [chain.successMessage],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true
                ),
                .init(
                    hudMessages: [chain.instructionMessage],
                    voiceSourceName: chain.voiceSourceName,
                    voicePrecedesHUDMessages: true
                ),
            ]
        )
        let closedRoom = try XCTUnwrap(simulation.runtimeLevel.rooms.first {
            $0.sourceIndex
                == level.trainingLastRoomChain?.barrierRoomSourceIndex
        })
        for portalIndex in [1, 0] {
            let portal = closedRoom.portals[portalIndex]
            XCTAssertNotEqual(portal.flags & 1, 0)
            let connected = try XCTUnwrap(
                simulation.runtimeLevel.rooms.first {
                    $0.sourceIndex == portal.connectedRoom
                }
            )
            XCTAssertNotEqual(
                connected.portals[portal.connectedPortal].flags & 1,
                0
            )
        }
        XCTAssertEqual(frame.trainingLastRoomMarkerLightDistance, 0)
        let continuedData = try JSONEncoder().encode(
            simulation.world
        )
        let continuedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuedData)
                as? [String: Any]
        )
        XCTAssertEqual(
            (
                continuedObject["trainingFinalRoomEntryState"]
                    as? [String: Any]
            )?["wasTriggered"] as? Bool,
            true
        )

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: continuedData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        let repeated = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            repeated.trainingLastRoomMarkerLightDistance,
            0
        )

        let sameFrameTail = try GameSession(
            level: level,
            world: (script050ReadyContinuation(
                in: level,
                timerRemaining: 0.1
            )).rebased(onto: level),
            resumedAtTimestamp: 0
        ).update(at: 0.1, input: .zero)
        XCTAssertEqual(
            sameFrameTail.trainingOpeningFeedback.suffix(3),
            [
                .init(
                    hudMessages: [chain.successMessage],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true
                ),
                .init(
                    hudMessages: [chain.instructionMessage],
                    voiceSourceName: chain.voiceSourceName,
                    voicePrecedesHUDMessages: true
                ),
                .init(
                    hudMessages:
                        level.trainingLastRoomChain?.completionMessages
                        ?? [],
                    voiceSourceName: "proceed5.osf",
                    voicePrecedesHUDMessages: false
                ),
            ]
        )
    }
    func testFourPrimaryLaserVolleysDestroyTrainingRobotThroughNormalPlay() throws {
        var level = makeTrainingRobotGuidebotLevel()
        let player = try XCTUnwrap(level.objects.first { $0.handle == 2_048 })
        let robotIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 4_112 }
        )
        level.objects[robotIndex].position = Vector3(
            x: player.position.x + player.orientation.forward.x * 20,
            y: player.position.y + player.orientation.forward.y * 20,
            z: player.position.z + player.orientation.forward.z * 20
        )
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        for (timestamp, fires) in [
            (0.1, true),
            (0.35, false),
            (0.36, true),
            (0.61, false),
            (0.62, true),
            (0.87, false),
            (0.88, true),
        ] {
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: fires)
            )
        }

        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == 4_112
        })
        assertTrainingGalleryBarrier(
            level: simulation.runtimeLevel,
            rendersFaces: false
        )
    }
}
