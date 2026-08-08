import XCTest

extension WorldRenderingTests {
    func testCameraMonitorPickupUseAndTimedViewContinueOnceAcrossReload() throws {
        let level = makeTrainingCameraMonitorLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingCameraMonitorChain)
        let securityCamera = try XCTUnwrap(level.objects.first {
            $0.handle == chain.securityCameraObjectHandle
        })
        let securityCameraRoom = try XCTUnwrap({
            if case let .room(room) = securityCamera.location { return room }
            return nil
        }())
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        let pickup = simulation.update(
            at: 0.1,
            input: .init(usesInventory: true)
        )
        XCTAssertEqual(
            pickup.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Excellent.  You now have the Camera Monitor.  Press the Use Inventory key to activate it!",
                ],
                voiceSourceName: "guidebotc.osf",
                voicePrecedesHUDMessages: true,
                soundSourceName: "PupC.wav"
            )]
        )
        XCTAssertNil(pickup.trainingCameraMonitor)
        XCTAssertFalse(
            simulation.level.objectPresentations.contains {
                $0.objectHandle == chain.pickupObjectHandle
                    && $0.isVisible
            }
        )
        XCTAssertTrue(
            simulation.level.objects.contains {
                $0.handle == chain.pickupObjectHandle
            }
        )

        let heldContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: heldContinuation,
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(
            restored.level.objectPresentations.contains {
                $0.objectHandle == chain.pickupObjectHandle
                    && $0.isVisible
            }
        )

        let used = restored.update(
            at: 100.1,
            input: .init(usesInventory: true)
        )
        XCTAssertEqual(
            used.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Now recall the Guidebot by pressing F4 and selecting \"Return to Ship\".  Move to the next area when he returns.",
                ],
                voiceSourceName: "guidebotd.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        let popup = try XCTUnwrap(used.trainingCameraMonitor)
        XCTAssertEqual(popup.remainingDuration, 10, accuracy: 0.000_1)
        XCTAssertEqual(popup.roomSourceIndex, securityCameraRoom)
        XCTAssertEqual(
            popup.camera.position,
            securityCamera.position
        )
        XCTAssertEqual(
            popup.camera.target,
            .init(
                x: securityCamera.position.x
                    - securityCamera.orientation.forward.x,
                y: securityCamera.position.y
                    - securityCamera.orientation.forward.y,
                z: securityCamera.position.z
                    - securityCamera.orientation.forward.z
            )
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.pickupObjectHandle
        })

        let usedContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(restored.continuation)
        )
        let resumedPopup = try PlayerSimulation(
            level: level,
            continuation: usedContinuation,
            resumedAtTimestamp: 200
        )
        let afterReload = resumedPopup.update(at: 200.1, input: .zero)
        XCTAssertTrue(afterReload.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            try XCTUnwrap(afterReload.trainingCameraMonitor)
                .remainingDuration,
            9.9,
            accuracy: 0.000_1
        )

        var lastFrame = afterReload
        for frameIndex in 2...99 {
            lastFrame = resumedPopup.update(
                at: 200 + Double(frameIndex) * 0.1,
                input: .zero
            )
        }
        XCTAssertNotNil(lastFrame.trainingCameraMonitor)
        _ = resumedPopup.update(at: 210, input: .zero)
        let closed = resumedPopup.update(at: 210.1, input: .zero)
        XCTAssertNil(closed.trainingCameraMonitor)
        XCTAssertTrue(closed.trainingOpeningFeedback.isEmpty)
        XCTAssertTrue(
            resumedPopup.update(at: 212.2, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )
    }

    func testGuidebotReturnCollisionRunsScript058OnceAcrossReload() throws {
        let level = makeTrainingCameraMonitorLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingCameraMonitorChain)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = simulation.update(at: 0.2, input: .init(usesInventory: true))
        let requested = simulation.update(
            at: 0.3,
            input: .init(deploysTrainingGuidebot: true)
        )
        let returnRandomState = try XCTUnwrap(
            (
                try XCTUnwrap(
                    JSONSerialization.jsonObject(
                        with: JSONEncoder().encode(
                            simulation.continuation
                        )
                    ) as? [String: Any]
                )["authoritativeRandomState"] as? NSNumber
            )?.uint32Value
        )
        XCTAssertEqual(requested.trainingOpeningFeedback, [
            .init(
                hudMessages: ["GB: Returning to ship."],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true
            ),
        ])
        var completed: PlayerSimulationFrame?
        for frameIndex in 4...100 {
            let frame = simulation.update(
                at: Double(frameIndex) * 0.1,
                input: .zero
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                completed = frame
                break
            }
        }
        let script058 = try XCTUnwrap(completed)
        XCTAssertEqual(script058.trainingOpeningFeedback, [
            .init(
                hudMessages: ["GB: Entering ship!"],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true
            ),
            .init(
                hudMessages: ["Excellent!"],
                voiceSourceName: "proceed6.osf",
                voicePrecedesHUDMessages: true
            ),
        ])
        XCTAssertNil(script058.trainingGuidebot)
        XCTAssertFalse(script058.trainingGuidebotAmbientEngineIsActive)
        XCTAssertEqual(
            script058.trainingGuidebotReturnMarkerLightDistance,
            50
        )
        assertTrainingGuidebotReturnBarrier(
            level: simulation.level,
            rendersFaces: false
        )
        XCTAssertFalse(simulation.level.objectPresentations.contains {
            $0.objectHandle
                == level.trainingRobotGuidebotChain?.guidebotObjectHandle
                && $0.isVisible
        })
        let completedRandomState = try XCTUnwrap(
            (
                try XCTUnwrap(
                    JSONSerialization.jsonObject(
                        with: JSONEncoder().encode(
                            simulation.continuation
                        )
                    ) as? [String: Any]
                )["authoritativeRandomState"] as? NSNumber
            )?.uint32Value
        )
        XCTAssertEqual(
            completedRandomState,
            returnRandomState,
            "The deferred return-to-ship branch must not consume the authoritative stream."
        )
        let postReturnFrame = simulation.update(
            at: Double(script058.gameTime) + 0.1,
            input: .zero
        )
        XCTAssertNil(postReturnFrame.trainingGuidebot)
        XCTAssertTrue(postReturnFrame.trainingOpeningFeedback.isEmpty)

        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        let afterReload = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(afterReload.trainingOpeningFeedback.isEmpty)
        XCTAssertNil(afterReload.trainingGuidebot)
        XCTAssertFalse(afterReload.trainingGuidebotAmbientEngineIsActive)
        XCTAssertEqual(
            afterReload.trainingGuidebotReturnMarkerLightDistance,
            chain.returnToShip?.openMarkerLightDistance
        )
        assertTrainingGuidebotReturnBarrier(
            level: restored.level,
            rendersFaces: false
        )

        var legacyTerminalObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(continuation)
            ) as? [String: Any]
        )
        legacyTerminalObject.removeValue(
            forKey: "authoritativeRandomState"
        )
        var legacyTerminalState = try XCTUnwrap(
            legacyTerminalObject["trainingRobotGuidebotState"]
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
            legacyTerminalState.removeValue(forKey: key)
        }
        legacyTerminalObject["trainingRobotGuidebotState"] =
            legacyTerminalState
        XCTAssertNoThrow(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: legacyTerminalObject
                    )
                ),
                resumedAtTimestamp: 200
            )
        )
    }

    @MainActor
    func testInShipReleaseGuidebotCommandReusesBirthAfterScript039() throws {
        let baseLevel = makeTrainingKillbotEntryLevel()
        let syntheticReleaseSound = CanonicalSoundClip(
            logicalName: "GBExpulsionA",
            sourceName: "GBExpulsionA.wav",
            sourceEntryIndex: 1_246,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: Data(repeating: 0, count: 2),
            pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
            sourceArchive: "d3.hog",
            sourceSHA256: String(repeating: "9", count: 64),
            importVolume: 0.5
        )
        let syntheticAmbientEngineSound = CanonicalSoundClip(
            logicalName: "GBotEngineB1",
            sourceName: "GBotEngineB.wav",
            sourceEntryIndex: 1_262,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: Data(repeating: 0, count: 2),
            pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
            sourceArchive: "d3.hog",
            sourceSHA256: String(repeating: "8", count: 64),
            importVolume: 0.1
        )
        var levelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(baseLevel)
            ) as? [String: Any]
        )
        var source = try XCTUnwrap(
            levelObject["source"] as? [String: Any]
        )
        source["archiveSHA256"] = String(repeating: "0", count: 64)
        var profileFiles = try XCTUnwrap(
            source["profileFiles"] as? [[String: Any]]
        )
        if !profileFiles.contains(where: {
            $0["relativePath"] as? String == "d3.hog"
        }) {
            profileFiles.append([
                "relativePath": "d3.hog",
                "byteCount": 194_030_423,
                "sha256":
                    "a0f1cb2c1a73da828a5fd4e80d6544b63da04e177dc2b894d9e6418296bc24c6",
            ])
        }
        source["profileFiles"] = profileFiles
        levelObject["source"] = source
        var releaseChain = try XCTUnwrap(
            levelObject["trainingRobotGuidebotChain"] as? [String: Any]
        )
        releaseChain["releaseSoundSourceName"] = "GBExpulsionA.wav"
        releaseChain["ambientEngineSoundSourceName"] = "GBotEngineB.wav"
        levelObject["trainingRobotGuidebotChain"] = releaseChain
        var soundClips = try XCTUnwrap(
            levelObject["soundClips"] as? [[String: Any]]
        )
        soundClips.append(try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(syntheticReleaseSound)
            ) as? [String: Any]
        ))
        soundClips.append(try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(syntheticAmbientEngineSound)
            ) as? [String: Any]
        ))
        levelObject["soundClips"] = soundClips
        var dependencyManifest = try XCTUnwrap(
            levelObject["dependencyManifest"] as? [String: Any]
        )
        var currentDependencies = try XCTUnwrap(
            dependencyManifest["current"] as? [[String: Any]]
        )
        currentDependencies.append(try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(DependencyRecord(
                    category: "sound",
                    source: .init(
                        storedIndex: 1_246,
                        sourceName: "GBExpulsionA.wav"
                    ),
                    state: "canonical-pcm-imported",
                    provenance: "synthetic canonical fixture"
                ))
            ) as? [String: Any]
        ))
        currentDependencies.append(try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(DependencyRecord(
                    category: "sound",
                    source: .init(
                        storedIndex: 1_262,
                        sourceName: "GBotEngineB.wav"
                    ),
                    state: "canonical-pcm-imported",
                    provenance: "synthetic canonical fixture"
                ))
            ) as? [String: Any]
        ))
        dependencyManifest["current"] = currentDependencies
        levelObject["dependencyManifest"] = dependencyManifest
        let level = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: levelObject)
        )
        let decodedReleaseSound = try XCTUnwrap(level.soundClips.first {
            $0.sourceName == "GBExpulsionA.wav"
        })
        XCTAssertEqual(decodedReleaseSound, syntheticReleaseSound)
        XCTAssertEqual(
            level.soundClips.first {
                $0.sourceName == "GBotEngineB.wav"
            },
            syntheticAmbientEngineSound
        )
        XCTAssertEqual(
            decodedReleaseSound.pcmSHA256,
            canonicalSHA256(decodedReleaseSound.pcm16LittleEndian)
        )
        XCTAssertTrue(level.source.profileFiles.contains {
            $0.relativePath == decodedReleaseSound.sourceArchive
        })
        XCTAssertTrue(level.dependencyManifest.current.contains {
            $0.category == "sound"
                && $0.source == .init(
                    storedIndex: decodedReleaseSound.sourceEntryIndex,
                    sourceName: decodedReleaseSound.sourceName
                )
        })
        XCTAssertEqual(
            Set(level.soundClips.map { $0.sourceName.lowercased() }).count,
            level.soundClips.count
        )
        try level.validate()
        let initialSimulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var initialContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(initialSimulation.continuation)
            ) as? [String: Any]
        )
        var initialGalleryState = try XCTUnwrap(
            initialContinuationObject["trainingGalleryBarrierState"]
                as? [String: Any]
        )
        initialGalleryState["wasTriggered"] = true
        initialGalleryState["markerLightDistance"] = 0
        initialContinuationObject["trainingGalleryBarrierState"] =
            initialGalleryState
        let gallerySimulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: initialContinuationObject
                )
            ),
            resumedAtTimestamp: 0
        )
        gallerySimulation.destroyTrainingRobot(handle: 4_112)
        var readyContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(gallerySimulation.continuation)
            ) as? [String: Any]
        )
        var readyRobotState = try XCTUnwrap(
            readyContinuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        readyRobotState.removeValue(forKey: "destructionTimerRemaining")
        readyRobotState["destructionFeedbackWasPresented"] = true
        readyRobotState["enabledControlHUDIsVisible"] = false
        readyContinuationObject["trainingRobotGuidebotState"] =
            readyRobotState
        let simulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: readyContinuationObject
                )
            ),
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
        for _ in 1...100 {
            timestamp += 0.1
            let frame = simulation.update(at: timestamp, input: .zero)
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                break
            }
        }
        timestamp += 0.1
        let portalEntry = simulation.update(
            at: timestamp,
            input: .init(forward: 1)
        )
        XCTAssertTrue(portalEntry.trainingOpeningFeedback.contains(where: {
            $0.voiceSourceName == "intro6.osf"
        }))
        var script039: PlayerSimulationFrame?
        for _ in 1...130 {
            timestamp += 0.1
            let frame = simulation.update(at: timestamp, input: .zero)
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebotf.osf"
            }) {
                script039 = frame
                break
            }
        }
        let script039Frame = try XCTUnwrap(script039)
        XCTAssertTrue(simulation.trainingGuidebotReleaseCommandIsAvailable)

        let menu = RevivalGameplayView.trainingGuidebotReleaseMenu(
            target: nil,
            action: nil
        )
        XCTAssertEqual(menu.title, "GB Command Menu")
        XCTAssertEqual(menu.items.count, 1)
        XCTAssertEqual(menu.items[0].title, "1. Release Guidebot")
        XCTAssertEqual(menu.items[0].keyEquivalent, "1")
        XCTAssertTrue(menu.items[0].keyEquivalentModifierMask.isEmpty)
        XCTAssertEqual(menu.items[0].tag, 0)
        XCTAssertTrue(
            RevivalGameplayView.cancelsTrainingGuidebotReleaseMenu(
                keyCode: 118
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.cancelsTrainingGuidebotReleaseMenu(
                keyCode: 53
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.cancelsTrainingGuidebotReleaseMenu(
                keyCode: 18
            )
        )

        let canonicalPlayer = try XCTUnwrap(level.objects.first {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        var releaseContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        releaseContinuationObject["playerPosition"] = [
            "x": canonicalPlayer.position.x,
            "y": canonicalPlayer.position.y,
            "z": canonicalPlayer.position.z,
        ]
        releaseContinuationObject["playerLocation"] = try JSONSerialization
            .jsonObject(with: JSONEncoder().encode(canonicalPlayer.location))
        releaseContinuationObject["playerOrientation"] = [
            "right": [
                "x": canonicalPlayer.orientation.right.x,
                "y": canonicalPlayer.orientation.right.y,
                "z": canonicalPlayer.orientation.right.z,
            ],
            "up": [
                "x": canonicalPlayer.orientation.up.x,
                "y": canonicalPlayer.orientation.up.y,
                "z": canonicalPlayer.orientation.up.z,
            ],
            "forward": [
                "x": canonicalPlayer.orientation.forward.x,
                "y": canonicalPlayer.orientation.forward.y,
                "z": canonicalPlayer.orientation.forward.z,
            ],
        ]
        releaseContinuationObject["velocity"] = [
            "x": Float.zero,
            "y": Float.zero,
            "z": Float.zero,
        ]
        releaseContinuationObject["frameDuration"] = Float.zero
        let releaseSimulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: releaseContinuationObject
                )
            ),
            resumedAtTimestamp: 100
        )
        XCTAssertTrue(
            releaseSimulation.trainingGuidebotReleaseCommandIsAvailable
        )
        let player = try XCTUnwrap(releaseSimulation.level.objects.first {
            $0.handle
                == releaseSimulation.level.defaultPlayerBinding?.objectHandle
        })
        let inheritedVelocity = releaseSimulation.continuation.velocity
        let feedbackCountBeforeRelease =
            script039Frame.trainingOpeningFeedback.count
        let releaseStateBefore = try XCTUnwrap(
            releaseContinuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        let messageSoundTimeBeforeRelease =
            releaseStateBefore["lastMessageSoundTime"] as? NSNumber
        let randomStateBeforeRelease = try XCTUnwrap(
            (releaseContinuationObject["authoritativeRandomState"]
                as? NSNumber)?.uint32Value
        )
        let released = releaseSimulation.update(
            at: 100.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertFalse(released.trainingGuidebotAmbientEngineIsActive)
        let guidebot = try XCTUnwrap(released.trainingGuidebot)
        XCTAssertEqual(guidebot.spawnPosition, player.position)
        XCTAssertEqual(guidebot.orientation, player.orientation)
        XCTAssertEqual(
            guidebot.spawnVelocity,
            Vector3(
                x: inheritedVelocity.x
                    + player.orientation.forward.x * 40,
                y: inheritedVelocity.y
                    + player.orientation.forward.y * 40,
                z: inheritedVelocity.z
                    + player.orientation.forward.z * 40
            )
        )
        XCTAssertEqual(released.trainingOpeningFeedback, [
            .init(
                hudMessages: [],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: "GBExpulsionA.wav"
            ),
        ])
        var soundAttempts: [String] = []
        var presentedHUDMessages: [String] = []
        var hudPresentationCount = 0
        RevivalGameplayView.presentTrainingFeedbackSequence(
            released.trainingOpeningFeedback,
            attemptVoice: { _ in },
            attemptSound: { sourceName, eventVolume in
                XCTAssertNil(eventVolume)
                soundAttempts.append(sourceName)
            },
            presentHUDMessages: {
                hudPresentationCount += 1
                presentedHUDMessages.append(contentsOf: $0)
            }
        )
        XCTAssertEqual(soundAttempts, ["GBExpulsionA.wav"])
        XCTAssertEqual(hudPresentationCount, 0)
        XCTAssertTrue(presentedHUDMessages.isEmpty)
        XCTAssertFalse(
            releaseSimulation.trainingGuidebotReleaseCommandIsAvailable
        )
        XCTAssertTrue(releaseSimulation.level.objectPresentations.contains {
            $0.objectHandle
                == level.trainingRobotGuidebotChain?.guidebotObjectHandle
                && $0.isVisible
        })
        let releasedContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(releaseSimulation.continuation)
            ) as? [String: Any]
        )
        let releasedState = try XCTUnwrap(
            releasedContinuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        let releasedGuidebot = try XCTUnwrap(
            releasedState["guidebot"] as? [String: Any]
        )
        XCTAssertEqual(releasedGuidebot["task"] as? String, "outbound")
        XCTAssertEqual(
            releasedState["lastMessageSoundTime"] as? NSNumber,
            messageSoundTimeBeforeRelease
        )
        let randomStateAfterRelease = try XCTUnwrap(
            (releasedContinuationObject["authoritativeRandomState"]
                as? NSNumber)?.uint32Value
        )
        let firstModeState =
            randomStateBeforeRelease &* 214_013 &+ 2_531_011
        let secondModeState = firstModeState &* 214_013 &+ 2_531_011
        XCTAssertEqual(randomStateAfterRelease, secondModeState)
        XCTAssertEqual(
            script039Frame.trainingOpeningFeedback.count,
            feedbackCountBeforeRelease
        )

        var ambientTransitionFrame: PlayerSimulationFrame?
        var ambientTimestamp = 100.1
        for _ in 1...20 {
            ambientTimestamp += 0.1
            let frame = releaseSimulation.update(
                at: ambientTimestamp,
                input: .zero
            )
            let continuationObject = try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(
                        releaseSimulation.continuation
                    )
                ) as? [String: Any]
            )
            let state = try XCTUnwrap(
                continuationObject["trainingRobotGuidebotState"]
                    as? [String: Any]
            )
            if state["guidebotMode"] as? String == "ambient" {
                ambientTransitionFrame = frame
                break
            }
            XCTAssertFalse(frame.trainingGuidebotAmbientEngineIsActive)
        }
        XCTAssertFalse(
            try XCTUnwrap(ambientTransitionFrame)
                .trainingGuidebotAmbientEngineIsActive,
            "The released GBM_BIRTH branch returns on the transition frame."
        )
        ambientTimestamp += 0.1
        let firstNormalAmbientFrame = releaseSimulation.update(
            at: ambientTimestamp,
            input: .zero
        )
        XCTAssertTrue(
            firstNormalAmbientFrame.trainingGuidebotAmbientEngineIsActive
        )
        let ambientMix = try XCTUnwrap(
            RevivalGameplayView.trainingGuidebotAmbientEngineSpatialMix(
                frame: firstNormalAmbientFrame,
                rooms: level.rooms
            )
        )
        XCTAssertGreaterThanOrEqual(ambientMix.volumeScale, 0)
        XCTAssertLessThanOrEqual(ambientMix.volumeScale, 1)
        XCTAssertGreaterThanOrEqual(ambientMix.pan, -1)
        XCTAssertLessThanOrEqual(ambientMix.pan, 1)
        let listener = PlayerView(
            playerID: 0,
            objectHandle: 1,
            roomSourceIndex: 1,
            camera: .init(
                position: .zero,
                target: .init(x: 0, y: 0, z: 1),
                up: .init(x: 0, y: 1, z: 0),
                projection: .sourceDefault
            ),
            collisionRadius: 1
        )
        let sameRoom = LevelRoom(
            sourceIndex: 1,
            vertices: [],
            faces: [],
            portals: []
        )
        XCTAssertEqual(
            try XCTUnwrap(
                RevivalGameplayView.trainingGuidebotAmbientEngineSpatialMix(
                    sourcePosition: .init(x: 0, y: 0, z: 10),
                    sourceRoomSourceIndex: 1,
                    listener: listener,
                    rooms: [sameRoom]
                )
            ).volumeScale,
            1,
            accuracy: 0.000_001
        )
        let rightMix = try XCTUnwrap(
            RevivalGameplayView.trainingGuidebotAmbientEngineSpatialMix(
                sourcePosition: .init(x: 55, y: 0, z: 0),
                sourceRoomSourceIndex: 1,
                listener: listener,
                rooms: [sameRoom]
            )
        )
        XCTAssertEqual(rightMix.volumeScale, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(rightMix.pan, 1, accuracy: 0.000_001)
        XCTAssertEqual(
            try XCTUnwrap(
                RevivalGameplayView.trainingGuidebotAmbientEngineSpatialMix(
                    sourcePosition: .init(x: -55, y: 0, z: 0),
                    sourceRoomSourceIndex: 1,
                    listener: listener,
                    rooms: [sameRoom]
                )
            ).pan,
            -1,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                RevivalGameplayView.trainingGuidebotAmbientEngineSpatialMix(
                    sourcePosition: .init(x: 0, y: 0, z: 100),
                    sourceRoomSourceIndex: 1,
                    listener: listener,
                    rooms: [sameRoom]
                )
            ).volumeScale,
            0,
            accuracy: 0.000_001
        )
        let sourcePortal = LevelPortal(
            faceIndex: 0,
            connectedRoom: 2,
            connectedPortal: 0,
            pathPoint: .init(x: 20, y: 0, z: 0)
        )
        let firstReciprocal = LevelPortal(
            faceIndex: 0,
            connectedRoom: 1,
            connectedPortal: 0,
            pathPoint: .init(x: 20, y: 0, z: 0)
        )
        let secondPortal = LevelPortal(
            faceIndex: 1,
            connectedRoom: 3,
            connectedPortal: 0,
            pathPoint: .init(x: 80, y: 0, z: 0)
        )
        let secondReciprocal = LevelPortal(
            faceIndex: 0,
            connectedRoom: 2,
            connectedPortal: 1,
            pathPoint: .init(x: 80, y: 0, z: 0)
        )
        let portalRooms = [
            LevelRoom(
                sourceIndex: 1,
                vertices: [],
                faces: [],
                portals: [sourcePortal]
            ),
            LevelRoom(
                sourceIndex: 2,
                vertices: [],
                faces: [],
                portals: [firstReciprocal, secondPortal]
            ),
            LevelRoom(
                sourceIndex: 3,
                vertices: [],
                faces: [],
                portals: [secondReciprocal]
            ),
        ]
        let portalListener = PlayerView(
            playerID: listener.playerID,
            objectHandle: listener.objectHandle,
            roomSourceIndex: 3,
            camera: listener.camera,
            collisionRadius: listener.collisionRadius
        )
        let routedMix = try XCTUnwrap(
            RevivalGameplayView.trainingGuidebotAmbientEngineSpatialMix(
                sourcePosition: .zero,
                sourceRoomSourceIndex: 1,
                listener: portalListener,
                rooms: portalRooms
            )
        )
        XCTAssertEqual(routedMix.volumeScale, 0, accuracy: 0.000_001)
        XCTAssertEqual(routedMix.pan, 1, accuracy: 0.000_001)
        let shortSourcePortal = LevelPortal(
            faceIndex: 0,
            connectedRoom: 2,
            connectedPortal: 0,
            pathPoint: .init(x: 10, y: 0, z: 0)
        )
        let shortFirstReciprocal = LevelPortal(
            faceIndex: 0,
            connectedRoom: 1,
            connectedPortal: 0,
            pathPoint: .init(x: 10, y: 0, z: 0)
        )
        let shortSecondPortal = LevelPortal(
            faceIndex: 1,
            connectedRoom: 3,
            connectedPortal: 0,
            pathPoint: .init(x: 20, y: 0, z: 0)
        )
        let shortSecondReciprocal = LevelPortal(
            faceIndex: 0,
            connectedRoom: 2,
            connectedPortal: 1,
            pathPoint: .init(x: 20, y: 0, z: 0)
        )
        let doorMix = try XCTUnwrap(
            RevivalGameplayView.trainingGuidebotAmbientEngineSpatialMix(
                sourcePosition: .zero,
                sourceRoomSourceIndex: 1,
                listener: portalListener,
                rooms: [
                    LevelRoom(
                        sourceIndex: 1,
                        vertices: [],
                        faces: [],
                        portals: [shortSourcePortal]
                    ),
                    LevelRoom(
                        sourceIndex: 2,
                        vertices: [],
                        faces: [],
                        portals: [
                            shortFirstReciprocal,
                            shortSecondPortal,
                        ],
                        door: .init(
                            flags: 0,
                            keysNeeded: 0,
                            definition: .init(
                                storedIndex: 0,
                                sourceName: "TestDoor"
                            ),
                            position: 0
                        )
                    ),
                    LevelRoom(
                        sourceIndex: 3,
                        vertices: [],
                        faces: [],
                        portals: [shortSecondReciprocal]
                    ),
                ]
            )
        )
        XCTAssertEqual(
            doorMix.volumeScale,
            Float(2) / 15,
            accuracy: 0.000_001
        )
        XCTAssertEqual(doorMix.pan, 1, accuracy: 0.000_001)
        let disconnectedListener = PlayerView(
            playerID: listener.playerID,
            objectHandle: listener.objectHandle,
            roomSourceIndex: 4,
            camera: listener.camera,
            collisionRadius: listener.collisionRadius
        )
        XCTAssertNil(
            RevivalGameplayView.trainingGuidebotAmbientEngineSpatialMix(
                sourcePosition: .zero,
                sourceRoomSourceIndex: 1,
                listener: disconnectedListener,
                rooms: [
                    sameRoom,
                    LevelRoom(
                        sourceIndex: 4,
                        vertices: [],
                        faces: [],
                        portals: []
                    ),
                ]
            )
        )
        let ambientContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(releaseSimulation.continuation)
            ) as? [String: Any]
        )
        XCTAssertNil(ambientContinuationObject["guidebotAmbientEngineActive"])

        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: releasedContinuationObject
            )
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 200
        )
        let silent = restored.update(at: 200.1, input: .zero)
        XCTAssertNotNil(silent.trainingGuidebot)
        XCTAssertTrue(silent.trainingOpeningFeedback.isEmpty)

        let ambientContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: ambientContinuationObject
            )
        )
        let restoredAmbient = try PlayerSimulation(
            level: level,
            continuation: ambientContinuation,
            resumedAtTimestamp: 250
        )
        let resumedAmbient = restoredAmbient.update(
            at: 250.1,
            input: .zero
        )
        XCTAssertTrue(
            resumedAmbient.trainingGuidebotAmbientEngineIsActive
        )
        XCTAssertTrue(resumedAmbient.trainingOpeningFeedback.isEmpty)

        var compatibleLevelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(level)
            ) as? [String: Any]
        )
        var compatibleChain = try XCTUnwrap(
            compatibleLevelObject["trainingRobotGuidebotChain"]
                as? [String: Any]
        )
        compatibleChain.removeValue(forKey: "releaseSoundSourceName")
        compatibleChain.removeValue(
            forKey: "ambientEngineSoundSourceName"
        )
        compatibleLevelObject["trainingRobotGuidebotChain"] = compatibleChain
        compatibleLevelObject["soundClips"] = try XCTUnwrap(
            compatibleLevelObject["soundClips"] as? [[String: Any]]
        ).filter {
            let sourceName = $0["sourceName"] as? String
            return sourceName != "GBExpulsionA.wav"
                && sourceName != "GBotEngineB.wav"
        }
        var compatibleManifest = try XCTUnwrap(
            compatibleLevelObject["dependencyManifest"] as? [String: Any]
        )
        compatibleManifest["current"] = try XCTUnwrap(
            compatibleManifest["current"] as? [[String: Any]]
        ).filter { dependency in
            guard dependency["category"] as? String == "sound",
                  let source = dependency["source"] as? [String: Any]
            else {
                return true
            }
            let sourceName = source["sourceName"] as? String
            return sourceName != "GBExpulsionA.wav"
                && sourceName != "GBotEngineB.wav"
        }
        compatibleLevelObject["dependencyManifest"] = compatibleManifest
        let compatibleLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: compatibleLevelObject)
        )
        try compatibleLevel.validate()
        let compatibleSimulation = try PlayerSimulation(
            level: compatibleLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: releaseContinuationObject
                )
            ),
            resumedAtTimestamp: 300
        )
        let compatibleRelease = compatibleSimulation.update(
            at: 300.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertNotNil(compatibleRelease.trainingGuidebot)
        XCTAssertTrue(compatibleRelease.trainingOpeningFeedback.isEmpty)

        var hostileLevelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(level)
            ) as? [String: Any]
        )
        hostileLevelObject["soundClips"] = try XCTUnwrap(
            hostileLevelObject["soundClips"] as? [[String: Any]]
        ).filter {
            $0["sourceName"] as? String != "GBotEngineB.wav"
        }
        var hostileManifest = try XCTUnwrap(
            hostileLevelObject["dependencyManifest"] as? [String: Any]
        )
        hostileManifest["current"] = try XCTUnwrap(
            hostileManifest["current"] as? [[String: Any]]
        ).filter { dependency in
            guard dependency["category"] as? String == "sound",
                  let source = dependency["source"] as? [String: Any]
            else {
                return true
            }
            return source["sourceName"] as? String != "GBotEngineB.wav"
        }
        hostileLevelObject["dependencyManifest"] = hostileManifest
        let hostileLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(withJSONObject: hostileLevelObject)
        )
        XCTAssertThrowsError(try hostileLevel.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training robot Guidebot chain")
            )
        }

        var mismatchedPlayerObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(continuation)
            ) as? [String: Any]
        )
        var mismatchedPlayerPosition = try XCTUnwrap(
            mismatchedPlayerObject["playerPosition"] as? [String: Any]
        )
        mismatchedPlayerPosition["x"] = try XCTUnwrap(
            mismatchedPlayerPosition["x"] as? Double
        ) + 10
        mismatchedPlayerObject["playerPosition"] =
            mismatchedPlayerPosition
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: mismatchedPlayerObject
                    )
                ),
                resumedAtTimestamp: 200
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var hostileObject = try XCTUnwrap(
            ambientContinuationObject
        )
        var hostileState = try XCTUnwrap(
            hostileObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        var hostileGuidebot = try XCTUnwrap(
            hostileState["guidebot"] as? [String: Any]
        )
        func offsetX(_ key: String, in object: inout [String: Any])
            throws
        {
            var value = try XCTUnwrap(object[key] as? [String: Any])
            value["x"] = try XCTUnwrap(value["x"] as? Double) + 10_000
            object[key] = value
        }
        for key in [
            "spawnPosition",
            "allocationStartPosition",
            "position",
            "destination",
            "routeDestination",
        ] {
            try offsetX(key, in: &hostileGuidebot)
        }
        var hostileRoute = try XCTUnwrap(
            hostileGuidebot["route"] as? [String: Any]
        )
        var hostilePoints = try XCTUnwrap(
            hostileRoute["points"] as? [[String: Any]]
        )
        hostilePoints[0]["x"] = try XCTUnwrap(
            hostilePoints[0]["x"] as? Double
        ) + 10_000
        hostileRoute["points"] = hostilePoints
        hostileGuidebot["route"] = hostileRoute
        hostileState["guidebot"] = hostileGuidebot
        hostileObject["trainingRobotGuidebotState"] = hostileState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: hostileObject
                    )
                ),
                resumedAtTimestamp: 200
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }
    func testGuidebotReturnTracksLivePlayerMovementInSameFrame()
        throws
    {
        let level = makeTrainingCameraMonitorLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = simulation.update(at: 0.2, input: .init(usesInventory: true))
        _ = simulation.update(
            at: 0.3,
            input: .init(deploysTrainingGuidebot: true)
        )

        let followingMovedPlayer = simulation.update(
            at: 0.4,
            input: .init(forward: 1)
        )

        XCTAssertEqual(
            followingMovedPlayer.trainingGuidebot?.destination,
            followingMovedPlayer.playerView.camera.position
        )
    }

    func testGuidebotReturnReallocatesWhenLivePlayerChangesRooms()
        throws
    {
        var level = makeTrainingCameraMonitorLevel()
        let targetPosition = Vector3(
            x: 10_000,
            y: 10_000,
            z: 10_000
        )
        let targetRoom = makeSourceContainmentRoom(
            center: targetPosition,
            texture: level.surfacePhysics[0].texture,
            sourceIndex: 999,
            halfExtent: 100
        )
        level.rooms.append(targetRoom)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = simulation.update(at: 0.2, input: .init(usesInventory: true))
        let requested = simulation.update(
            at: 0.3,
            input: .init(deploysTrainingGuidebot: true)
        )
        let guidebot = try XCTUnwrap(requested.trainingGuidebot)
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        var playerLocation = try XCTUnwrap(
            continuationObject["playerLocation"] as? [String: Any]
        )
        playerLocation["room"] = ["_0": targetRoom.sourceIndex]
        continuationObject["playerLocation"] = playerLocation
        continuationObject["playerPosition"] = [
            "x": targetPosition.x,
            "y": targetPosition.y,
            "z": targetPosition.z,
        ]
        let movedPlayerContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: continuationObject
            )
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: movedPlayerContinuation,
            resumedAtTimestamp: 100
        )

        let reallocated = restored.update(at: 100.1, input: .zero)

        let reallocatedGuidebot = try XCTUnwrap(
            reallocated.trainingGuidebot
        )
        let liveTarget = reallocated.playerView.camera.position
        XCTAssertEqual(reallocatedGuidebot.destination, liveTarget)
        if reallocatedGuidebot.routeFailure == nil {
            XCTAssertEqual(
                reallocatedGuidebot.route.roomSourceIndices.last,
                targetRoom.sourceIndex
            )
        } else {
            XCTAssertEqual(reallocatedGuidebot.route.mode, .direct)
            XCTAssertEqual(
                reallocatedGuidebot.route.points,
                [liveTarget]
            )
            XCTAssertNotEqual(
                reallocatedGuidebot.route,
                guidebot.route
            )
        }
    }

    func testGuidebotCrossRoomReturnReachesScript058() throws {
        var level = makeTrainingCameraMonitorLevel()
        let start = RoomCamera.trainingRoom3.position
        let turn = Vector3(x: start.x, y: start.y + 200, z: start.z)
        let destination = Vector3(
            x: start.x + 400,
            y: start.y + 200,
            z: start.z
        )
        let blockingTexture = try XCTUnwrap(
            level.surfacePhysics.first {
                $0.behavior == .blocking
            }?.texture
        )
        let returnTexture = SourceResource(
            storedIndex: 908,
            sourceName: "Alien Force Field_1"
        )
        func portalFace(
            _ face: LevelFace,
            portalIndex: Int
        ) -> LevelFace {
            .init(
                corners: face.corners,
                flags: face.flags,
                portalIndex: portalIndex,
                texture: returnTexture
            )
        }
        var room3 = makeSourceContainmentRoom(
            center: start,
            texture: blockingTexture,
            sourceIndex: 3,
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
                    faceIndex: 3,
                    connectedRoom: 2,
                    connectedPortal: 0,
                    pathPoint: .init(
                        x: start.x,
                        y: start.y + 100,
                        z: start.z
                    )
                ),
            ]
        )
        var room2 = makeSourceContainmentRoom(
            center: turn,
            texture: blockingTexture,
            sourceIndex: 2,
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
                    faceIndex: 2,
                    connectedRoom: 3,
                    connectedPortal: 0,
                    pathPoint: .init(
                        x: start.x,
                        y: start.y + 100,
                        z: start.z
                    )
                ),
                .init(
                    faceIndex: 1,
                    connectedRoom: 1,
                    connectedPortal: 0,
                    pathPoint: .init(
                        x: start.x + 100,
                        y: start.y + 200,
                        z: start.z
                    )
                ),
            ]
        )
        var room1 = makeSourceContainmentRoom(
            center: destination,
            texture: blockingTexture,
            sourceIndex: 1,
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
                        x: start.x + 100,
                        y: start.y + 200,
                        z: start.z
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
                sourceWasVerified: true,
                rooms: []
            )
        )
        let guidebotDefinition = try XCTUnwrap(
            level.trainingRobotGuidebotChain?.guidebot
        )
        let allocated = try trainingGuidebotRoute(
            in: level,
            startRoomSourceIndex: 3,
            start: start,
            startForward: .init(x: 1, y: 0, z: 0),
            destinationRoomSourceIndex: 1,
            destination: destination,
            radius: max(0, guidebotDefinition.collisionRadius - 0.1)
        ).get()
        XCTAssertEqual(allocated.mode, .roomPortals)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = simulation.update(at: 0.2, input: .init(usesInventory: true))

        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        continuationObject["playerLocation"] = [
            "room": ["_0": 1],
        ]
        continuationObject["playerPosition"] = [
            "x": destination.x,
            "y": destination.y,
            "z": destination.z,
        ]
        let movedPlayerContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: continuationObject
            )
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: movedPlayerContinuation,
            resumedAtTimestamp: 100
        )

        var completed: PlayerSimulationFrame?
        for frameIndex in 1...200 {
            let frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: frameIndex == 1
                    ? .init(deploysTrainingGuidebot: true)
                    : .zero
            )
            if frameIndex == 1 {
                XCTAssertEqual(
                    frame.trainingGuidebot?.route.mode,
                    .roomPortals
                )
                XCTAssertEqual(
                    frame.trainingGuidebot?.route
                        .roomSourceIndices.last,
                    1
                )
                XCTAssertGreaterThan(
                    frame.trainingGuidebot?.route
                        .roomSourceIndices.count ?? 0,
                    1
                )
            }
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                completed = frame
                break
            }
        }

        let script058 = try XCTUnwrap(completed)
        XCTAssertNil(script058.trainingGuidebot)
        XCTAssertEqual(
            script058.trainingGuidebotReturnMarkerLightDistance,
            50
        )
        assertTrainingGuidebotReturnBarrier(
            level: restored.level,
            rendersFaces: false
        )
    }

    func testContinuationRejectsUnrequestedGuidebotReturnTask() throws {
        let level = makeTrainingCameraMonitorLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        var robotState = try XCTUnwrap(
            continuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(robotState["returnWasRequested"] as? Bool, false)
        var guidebot = try XCTUnwrap(
            robotState["guidebot"] as? [String: Any]
        )
        guidebot["task"] = "returnToShip"
        robotState["guidebot"] = guidebot
        continuationObject["trainingRobotGuidebotState"] = robotState
        let hostileContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: continuationObject
            )
        )

        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
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

    func testCameraMonitorPickupCompletesLocateGoalAcrossReload() throws {
        let level = makeTrainingCameraMonitorLevel()
        let locateGoal = try XCTUnwrap(level.goals.first {
            $0.name == "Locate the Camera Monitor"
        })
        XCTAssertEqual(locateGoal.status, 1_028)
        XCTAssertEqual(locateGoal.items, [
            .init(
                type: 2,
                sourceHandle: 6_167,
                objectHandle: 6_167,
                done: false
            ),
        ])
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        _ = simulation.update(at: 0.1, input: .zero)

        let completedGoal = try XCTUnwrap(simulation.level.goals.first {
            $0.name == "Locate the Camera Monitor"
        })
        XCTAssertEqual(completedGoal.status, 1_036)
        XCTAssertEqual(completedGoal.items.map(\.done), [true])
        let restored = try PlayerSimulation(
            level: level,
            continuation: simulation.continuation,
            resumedAtTimestamp: 100
        )
        let restoredGoal = try XCTUnwrap(restored.level.goals.first {
            $0.name == "Locate the Camera Monitor"
        })
        XCTAssertEqual(restoredGoal.status, 1_036)
        XCTAssertEqual(restoredGoal.items.map(\.done), [true])
    }

    func testCameraMonitorPopupStartsInTracedGunpointRoom() throws {
        var level = makeTrainingCameraMonitorLevel()
        let chain = try XCTUnwrap(level.trainingCameraMonitorChain)
        let cameraIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == chain.securityCameraObjectHandle
        })
        var reachedPortal: (
            startRoom: Int,
            connectedRoom: Int,
            cameraCenter: Vector3,
            gunpoint: Vector3
        )?
        for candidateRoom in level.rooms {
            for portal in candidateRoom.portals {
                let face = candidateRoom.faces[portal.faceIndex]
                let vertices = face.corners.map {
                    candidateRoom.vertices[$0.vertexIndex]
                }
                var center = Vector3.zero
                for vertex in vertices {
                    center = .init(
                        x: center.x + vertex.x,
                        y: center.y + vertex.y,
                        z: center.z + vertex.z
                    )
                }
                let count = Float(vertices.count)
                center = .init(
                    x: center.x / count,
                    y: center.y / count,
                    z: center.z / count
                )
                guard let normal = canonicalFaceNormal(
                    room: candidateRoom,
                    face: face
                ) else {
                    continue
                }
                let positive = Vector3(
                    x: center.x + normal.x * 0.01,
                    y: center.y + normal.y * 0.01,
                    z: center.z + normal.z * 0.01
                )
                let negative = Vector3(
                    x: center.x - normal.x * 0.01,
                    y: center.y - normal.y * 0.01,
                    z: center.z - normal.z * 0.01
                )
                let positiveIsInside =
                    containingIndoorRoomSourceIndex(
                        in: level,
                        position: positive,
                        candidates: [candidateRoom.sourceIndex]
                    ) == candidateRoom.sourceIndex
                let candidateCenter =
                    positiveIsInside ? positive : negative
                let candidateGunpoint =
                    positiveIsInside ? negative : positive
                let trace = traceIndoorMovement(
                    in: level,
                    startRoom: candidateRoom.sourceIndex,
                    start: candidateCenter,
                    end: candidateGunpoint,
                    radius: 0
                )
                if trace.containingRoomSourceIndex
                    == portal.connectedRoom {
                    reachedPortal = (
                        candidateRoom.sourceIndex,
                        portal.connectedRoom,
                        candidateCenter,
                        candidateGunpoint
                    )
                    break
                }
            }
            if reachedPortal != nil { break }
        }
        let portalFixture = try XCTUnwrap(reachedPortal)
        let connectedRoomSourceIndex = portalFixture.connectedRoom
        let cameraCenter = portalFixture.cameraCenter
        let gunpoint = portalFixture.gunpoint
        level.objects[cameraIndex].location =
            .room(portalFixture.startRoom)
        level.objects[cameraIndex].position = cameraCenter
        level.objects[cameraIndex].orientation = .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )
        let movedChain = TrainingCameraMonitorChain(
            pickupObjectHandle: chain.pickupObjectHandle,
            securityCameraObjectHandle:
                chain.securityCameraObjectHandle,
            pickupCollisionRadius: chain.pickupCollisionRadius,
            pickupMessage: chain.pickupMessage,
            pickupVoiceSourceName: chain.pickupVoiceSourceName,
            pickupSoundSourceName: chain.pickupSoundSourceName,
            useMessage: chain.useMessage,
            useVoiceSourceName: chain.useVoiceSourceName,
            popupDuration: chain.popupDuration,
            popupZoom: chain.popupZoom,
            cameraGunpointIndex: chain.cameraGunpointIndex,
            cameraLocalPosition: .init(
                x: gunpoint.x - cameraCenter.x,
                y: gunpoint.y - cameraCenter.y,
                z: gunpoint.z - cameraCenter.z
            ),
            cameraLocalForward: .init(x: 0, y: 1, z: 0),
            completionTimerDuration: chain.completionTimerDuration
        )
        level = replacing(
            level,
            objects: level.objects,
            trainingCameraMonitorChain: movedChain
        )
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(at: 0.1, input: .zero)

        let used = simulation.update(
            at: 0.2,
            input: .init(usesInventory: true)
        )

        XCTAssertEqual(
            used.trainingCameraMonitor?.roomSourceIndex,
            connectedRoomSourceIndex
        )
    }

    func testCameraMonitorPickupUsesAcceptedWallResponseSegments() throws {
        func missesSphere(
            start: Vector3,
            end: Vector3,
            center: Vector3,
            radius: Float
        ) -> Bool {
            let movement = Vector3(
                x: end.x - start.x,
                y: end.y - start.y,
                z: end.z - start.z
            )
            let toCenter = Vector3(
                x: center.x - start.x,
                y: center.y - start.y,
                z: center.z - start.z
            )
            let lengthSquared =
                movement.x * movement.x
                + movement.y * movement.y
                + movement.z * movement.z
            let fraction = lengthSquared > 0
                ? max(0, min(
                    1,
                    (
                        toCenter.x * movement.x
                        + toCenter.y * movement.y
                        + toCenter.z * movement.z
                    ) / lengthSquared
                ))
                : 0
            let closest = Vector3(
                x: start.x + movement.x * fraction,
                y: start.y + movement.y * fraction,
                z: start.z + movement.z * fraction
            )
            let distance = Vector3(
                x: center.x - closest.x,
                y: center.y - closest.y,
                z: center.z - closest.z
            )
            return distance.x * distance.x
                + distance.y * distance.y
                + distance.z * distance.z
                > radius * radius
        }
        let contactLevel = makeSliceTenContactLevel(clearance: 20)
        let baseline = PlayerSimulation(
            level: contactLevel,
            presentationReadyTimestamp: 0
        )
        _ = baseline.update(at: 2, input: .zero)
        let start = defaultPlayerView(in: baseline.level).camera.position
        let baselineFrame = baseline.update(
            at: 4,
            input: .init(forward: 1, sideways: 1)
        )
        let contact = try XCTUnwrap(baselineFrame.wallContact)
        let final = baselineFrame.playerView.camera.position
        let contactCenter = Vector3(
            x:
                contact.contactPoint.x
                + contact.normal.x
                    * baselineFrame.playerView.collisionRadius,
            y:
                contact.contactPoint.y
                + contact.normal.y
                    * baselineFrame.playerView.collisionRadius,
            z:
                contact.contactPoint.z
                + contact.normal.z
                    * baselineFrame.playerView.collisionRadius
        )
        let pickupRadius =
            baselineFrame.playerView.collisionRadius + 0.01
        var falseChordPoint: Vector3?
        for tenth in 1..<10 {
            let fraction = Float(tenth) / 10
            let candidate = Vector3(
                x: start.x + (final.x - start.x) * fraction,
                y: start.y + (final.y - start.y) * fraction,
                z: start.z + (final.z - start.z) * fraction
            )
            if missesSphere(
                start: start,
                end: contactCenter,
                center: candidate,
                radius: pickupRadius
            ),
            missesSphere(
                start: contactCenter,
                end: final,
                center: candidate,
                radius: pickupRadius
            ) {
                falseChordPoint = candidate
                break
            }
        }
        let pickupPosition = try XCTUnwrap(falseChordPoint)
        let cameraFixture = makeTrainingCameraMonitorLevel()
        let sourceChain = try XCTUnwrap(
            cameraFixture.trainingCameraMonitorChain
        )
        var pickup = try XCTUnwrap(cameraFixture.objects.first {
            $0.handle == sourceChain.pickupObjectHandle
        })
        pickup.location = .room(
            baselineFrame.playerView.roomSourceIndex
        )
        pickup.position = pickupPosition
        let chain = TrainingCameraMonitorChain(
            pickupObjectHandle: sourceChain.pickupObjectHandle,
            securityCameraObjectHandle:
                sourceChain.securityCameraObjectHandle,
            pickupCollisionRadius: 0.01,
            pickupMessage: sourceChain.pickupMessage,
            pickupVoiceSourceName: sourceChain.pickupVoiceSourceName,
            pickupSoundSourceName: sourceChain.pickupSoundSourceName,
            useMessage: sourceChain.useMessage,
            useVoiceSourceName: sourceChain.useVoiceSourceName,
            popupDuration: sourceChain.popupDuration,
            popupZoom: sourceChain.popupZoom,
            cameraGunpointIndex: sourceChain.cameraGunpointIndex,
            cameraLocalPosition: sourceChain.cameraLocalPosition,
            cameraLocalForward: sourceChain.cameraLocalForward,
            completionTimerDuration:
                sourceChain.completionTimerDuration
        )
        let level = replacing(
            contactLevel,
            schemaVersion: 10,
            objects: contactLevel.objects + [pickup],
            trainingCameraMonitorChain: chain
        )
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(at: 2, input: .zero)

        let frame = simulation.update(
            at: 4,
            input: .init(forward: 1, sideways: 1)
        )

        XCTAssertTrue(frame.trainingOpeningFeedback.isEmpty)
    }
}
