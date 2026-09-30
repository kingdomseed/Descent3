import XCTest

extension WorldRenderingTests {
    func testKillbotEntryClosesPortalRoom5AndRunsTimedInstructionAcrossReload()
        throws
    {
        let level = scriptingTrainingCameraMonitorLevel(
            makeTrainingKillbotEntryLevel(),
            guideBot: false
        )
        try level.validate()
        let initialSimulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        let initialContinuationObject = try XCTUnwrap(
            testWorldObject(initialSimulation.world)
        )
        let gallerySimulation = try GameSession(
            level: level,
            world: (decodeTestWorld(initialContinuationObject)).rebased(onto: level),
            resumedAtTimestamp: 0
        )
        // Scripts 036 and 029 ran (TrainingRobotScriptTests), and Script
        // 032 (TrainingGuideBotScriptTests).
        gallerySimulation.applyTrainingScript036Outcome()
        gallerySimulation.world.trainingMission.script032Count = 1
        gallerySimulation.world.hudShowControls = false
        let destroyedContinuationObject = try XCTUnwrap(
            testWorldObject(gallerySimulation.world)
        )
        let simulation = try GameSession(
            level: level,
            world: (decodeTestWorld(destroyedContinuationObject)).rebased(onto: level),
            resumedAtTimestamp: 0
        )
        var timestamp = 0.1
        _ = simulation.update(
            at: timestamp,
            input: .zero
        )
        timestamp += 0.1
        let used = simulation.update(
            at: timestamp,
            input: .init(usesInventory: true)
        )
        // This level has no Guide-Bot, so qGetBuddyObj is not a robot and
        // Script 058 (TrainingMission.cpp:1444) runs in the use frame.
        var script058: PlayerSimulationFrame? =
            used.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) ? used : nil
        timestamp += 0.1
        _ = simulation.update(
            at: timestamp,
            input: .zero
        )
        for _ in 1...100 where script058 == nil {
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
        timestamp = max(timestamp, Double(returned.gameTime)) + 0.1
        XCTAssertTrue(
            simulation.update(at: timestamp, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )
        // The opening goals stay out of the flight (Script 014 would run).
        simulation.parkTrainingGoals()
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
                // The player flies from where Script 058 found it to the
                // Portal3 trigger.
                XCTAssertLessThan(frameIndex, 40)
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
            simulation.returnMarkerLightDistance,
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
        // Script 036's FlashLight-2 light and DestroyBot2's deletion.
        XCTAssertEqual(simulation.galleryMarkerLightDistance, 50)
        XCTAssertNil(simulation.world.objects[ObjectHandle(4_112)])
        // qGetBuddyObj is not a robot (TrainingMission.cpp:1445).
        XCTAssertNotEqual(
            simulation.world.objectType(simulation.world.buddyHandle),
            .robot
        )
        let cameraState = try XCTUnwrap(
            continuationObject["trainingCameraMonitorState"]
                as? [String: Any]
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

    @MainActor
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
        // Scripts 043-046 counted the RASBots (TrainingMission.cpp:
        // 2090-2172) and Script 047 the invulnerability pickup; the cloak
        // pickup's EVT_COLLIDE runs Script 048, and the level EVT_INTERVAL
        // then runs Script 034 (:1403-1415), whose level timer 9 runs
        // Script 049 (:1603-1612).
        let level = addingTrainingMissionScripting(
            makeTrainingCloakPickupLevel()
        )
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
        for name in ["script043Count", "script044Count", "script045Count",
                     "script046Count", "script047Count"] {
            try setTrainingCounter(&readyObject, name, 1)
        }
        try deferringOsirisTimers(&readyObject, to: 1_000)
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
        // The pilot at rest on the pickup: the contact the move into it
        // makes (EVT_COLLIDE, collide.cpp:2493).
        simulation.collidePlayer(with: "CloakPowerup2")

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
        let marker = ObjectHandle(chain.markerLightObjectHandle)
        XCTAssertEqual(level.findObjectName("FlashLight-4"), marker)
        func markerDistance(_ session: GameSession) -> Float? {
            session.world.objects[marker]?.localLighting?.lightDistance
        }
        XCTAssertEqual(simulation.world.testTrainingMission?.script048Count, 1)
        XCTAssertEqual(simulation.world.testTrainingMission?.script034Count, 1)
        XCTAssertEqual(markerDistance(simulation), 50)
        XCTAssertFalse(frame.trainingOpeningFeedback.contains {
            $0.voiceSourceName == "proceed5.osf"
        })
        let timer = try XCTUnwrap(simulation.world.osirisTimers.entries.first {
            $0.isUsed && $0.owner == .level && $0.id == 9
        })
        XCTAssertEqual(timer.end, simulation.world.gameTime + 2, accuracy: 0.11)
        let triggeredData = try JSONEncoder().encode(simulation.world)

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: triggeredData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        try assertBarrierIsOpen(in: restored.runtimeLevel)
        var log: [String] = []
        for frameIndex in 1...20 {
            frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: .zero
            )
            log += presentationLog(frame)
        }
        XCTAssertEqual(restored.world.testTrainingMission?.script049Count, 1)
        let proceed = try XCTUnwrap(
            log.firstIndex(of: "hud:\(trainingText("ProceedtoLastRoom"))")
        )
        XCTAssertGreaterThan(proceed, 0)
        XCTAssertEqual(log[proceed - 1], "hud:\(trainingText("GoodJob"))")
        XCTAssertEqual(
            log.filter { $0 == "hud:\(trainingText("ProceedtoLastRoom"))" }
                .count,
            1
        )
        XCTAssertEqual(log.filter { $0 == "voice:proceed5.osf" }.count, 1)
        let repeated = restored.update(at: 102.1, input: .zero)
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(markerDistance(restored), 50)

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
        XCTAssertEqual(markerDistance(completed), 50)
    }

    func testScript050ClosesPortalRoomSixInSourceOrderAndSurvivesReload()
        throws
    {
        let level = addingTrainingMissionScripting(
            makeTrainingFinalRoomEntryLevel(),
            messages: fixtureTrainingMessages
        )
        try level.validate()
        let marker = ObjectHandle(
            try XCTUnwrap(level.trainingLastRoomChain).markerLightObjectHandle
        )
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
        XCTAssertEqual(
            simulation.world.objects[marker]?.localLighting?.lightDistance, 0
        )
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
            restored.world.objects[marker]?.localLighting?.lightDistance, 0
        )

        let tailSession = try GameSession(
            level: level,
            world: (script050ReadyContinuation(
                in: level,
                // Due at this frame's Gametime (Osiris_ProcessTimers runs
                // with the pre-update Gametime, GameLoop.cpp:3013).
                timerRemaining: 0
            )).rebased(onto: level),
            resumedAtTimestamp: 0
        )
        let sameFrameTail = tailSession.update(at: 0.1, input: .zero)
        // The trigger's Script 050 runs in the physics move, before the
        // level timer 9 that runs Script 049 in the same frame.
        let tail = presentationLog(sameFrameTail)
        let entered = try XCTUnwrap(
            tail.firstIndex(of: "hud:\(chain.instructionMessage)")
        )
        let proceed = try XCTUnwrap(
            tail.firstIndex(of: "hud:\(trainingText("ProceedtoLastRoom"))")
        )
        XCTAssertLessThan(entered, proceed)
        XCTAssertTrue(tail[proceed...].contains("voice:proceed5.osf"))
    }
}
