import XCTest

extension WorldRenderingTests {
    func testScripts035And056OpenPortalRoomSevenThenPresentOnceAfterTimer()
        throws
    {
        let level = makeTrainingFinalBotsCompletionLevel()
        try level.validate()
        let chain = try XCTUnwrap(
            level.trainingFinalBotsCompletionChain
        )
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        simulation.destroyTrainingLastBot1(handle: 4_127)
        simulation.destroyTrainingLastBot2(handle: 2_080)
        simulation.destroyTrainingLastBot3(handle: 2_081)
        simulation.destroyTrainingLastBot4(handle: 2_082)
        simulation.destroyTrainingLastBot5(handle: 2_083)
        var frame = simulation.update(at: 0.1, input: .zero)

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

        try assertBarrierIsOpen(in: simulation.level)
        XCTAssertEqual(
            frame.trainingFinalBotsMarkerLightDistance,
            50
        )
        XCTAssertFalse(frame.trainingOpeningFeedback.contains {
            $0.voiceSourceName == chain.completionVoiceSourceName
        })
        let pendingData = try JSONEncoder().encode(
            simulation.continuation
        )
        let pendingObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: pendingData)
                as? [String: Any]
        )
        XCTAssertEqual(pendingObject["schemaVersion"] as? Int, 7)
        let pendingState = try XCTUnwrap(
            pendingObject["trainingFinalBotsCompletionState"]
                as? [String: Any]
        )
        XCTAssertEqual(pendingState["wasTriggered"] as? Bool, true)
        XCTAssertEqual(
            try XCTUnwrap(pendingState["timerRemaining"] as? Double),
            2,
            accuracy: 0.000_1
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: pendingData
            ),
            resumedAtTimestamp: 100
        )
        try assertBarrierIsOpen(in: restored.level)
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
                    hudMessages: [chain.completionMessage],
                    voiceSourceName: chain.completionVoiceSourceName,
                    voicePrecedesHUDMessages: false
                )
            ]
        )
        XCTAssertTrue(
            restored.update(
                at: 102.1,
                input: .zero
            ).trainingOpeningFeedback.isEmpty
        )

        let completed = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(restored.continuation)
            ),
            resumedAtTimestamp: 200
        )
        try assertBarrierIsOpen(in: completed.level)
        XCTAssertTrue(
            completed.update(
                at: 200.1,
                input: .zero
            ).trainingOpeningFeedback.isEmpty
        )

        var hostileObject = pendingObject
        var hostileState = pendingState
        hostileState["markerLightDistance"] = 0
        hostileObject["trainingFinalBotsCompletionState"] =
            hostileState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: hostileObject
                    )
                ),
                resumedAtTimestamp: 300
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    @MainActor
    func testScript057FinalGoalEndsTrainingInSourceOrderAndSurvivesReload()
        throws
    {
        let level = makeTrainingFinalGoalLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingFinalGoalChain)
        let goal = try XCTUnwrap(level.objects.first {
            $0.handle == chain.goalObjectHandle
        })
        let initial = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        initial.destroyTrainingRobot(handle: 4_112)
        initial.destroyTrainingRASBot1(handle: 2_074)
        initial.destroyTrainingRASBot2(handle: 2_075)
        initial.destroyTrainingRASBot3(handle: 2_077)
        initial.destroyTrainingRASBot4(handle: 2_078)
        initial.destroyTrainingLastBot1(handle: 4_127)
        initial.destroyTrainingLastBot2(handle: 2_080)
        initial.destroyTrainingLastBot3(handle: 2_081)
        initial.destroyTrainingLastBot4(handle: 2_082)
        initial.destroyTrainingLastBot5(handle: 2_083)
        _ = initial.update(at: 0.1, input: .zero)
        var ready = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(initial.continuation)
            ) as? [String: Any]
        )
        ready["playerLocation"] = [
            "room": ["_0": chain.goalRoomSourceIndex]
        ]
        ready["playerPosition"] = [
            "x": goal.position.x,
            "y": goal.position.y,
            "z": goal.position.z,
        ]
        ready["playerHeadlightIsOn"] = true
        let simulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: ready)
            ),
            resumedAtTimestamp: 0
        )

        let frame = simulation.update(at: 0.2, input: .zero)

        let finalGoal = try XCTUnwrap(frame.trainingFinalGoal)
        XCTAssertNil(
            frame.playerFastHeadlight,
            "the final result suppresses an otherwise-on headlight"
        )
        XCTAssertEqual(finalGoal.endLevelState, .succeeded)
        XCTAssertEqual(finalGoal.scriptActionCounter, 1)
        XCTAssertTrue(finalGoal.controlsAreSuspended)
        XCTAssertEqual(
            finalGoal.postLevelResult,
            .init(
                title: "Mission Successful",
                levelName: "Training Mission",
                difficulty: .rookie,
                score: 2_000,
                elapsedTime: 0.1,
                enemyKills: 10,
                shields: 100,
                energy: 100,
                deaths: 0,
                restores: 0,
                objectives: []
            )
        )
        XCTAssertEqual(frame.enabledPlayerControls, [])
        XCTAssertFalse(frame.showsEnabledPlayerControls)
        _ = simulation.update(
            at: 0.3,
            input: .init(firesPrimaryWeapon: true)
        )
        XCTAssertEqual(
            simulation.energy,
            finalGoal.postLevelResult.energy,
            accuracy: 0.000_001,
            "successful final-result suspension cannot spend another volley"
        )
        XCTAssertEqual(
            finalGoal.presentation,
            .init(
                title: "Mission Successful",
                levelName: "Training Mission",
                difficulty: .rookie,
                showsHUD: false,
                playsGameplayAudio: false,
                showsCockpit: false,
                showsHeadlightIndicator: false
            )
        )
        XCTAssertEqual(
            RevivalGameplayView.trainingEndLevelText(
                finalGoal.presentation
            ),
            "Mission Successful\nTraining Mission\nDifficulty: Rookie"
        )
        XCTAssertEqual(
            RevivalGameplayView.trainingPostLevelResultText(
                finalGoal.postLevelResult
            ),
            """
            Mission Successful
            Training Mission
            Difficulty: Rookie
            Score: 2000
            Time: 0:00
            Enemies Killed: 10
            Shields: 100
            Energy: 100
            Deaths: 0
            Restores: 0
            """
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                keyCode: 36,
                resultIsPresented: true,
                presentationElapsedTime: 2
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                keyCode: 36,
                resultIsPresented: true,
                presentationElapsedTime: 1.999
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                keyCode: 36,
                resultIsPresented: false,
                presentationElapsedTime: 2
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                keyCode: 49,
                resultIsPresented: true,
                presentationElapsedTime: 2
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                keyCode: 53,
                resultIsPresented: true,
                presentationElapsedTime: 2
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 1.999,
                queuedKey: false,
                mouseButtonIsPressed: true,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 2,
                queuedKey: true,
                mouseButtonIsPressed: false,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 2,
                queuedKey: false,
                mouseButtonIsPressed: true,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 2,
                queuedKey: false,
                mouseButtonIsPressed: false,
                controllerButtonIsPressed: true
            )
        )
        XCTAssertEqual(
            simulation.trainingSessionOutcome,
            .awaitingResultAcknowledgement
        )
        XCTAssertEqual(
            simulation.acknowledgeTrainingResult(),
            .completed
        )
        XCTAssertEqual(simulation.trainingSessionOutcome, .completed)
        XCTAssertEqual(
            simulation.acknowledgeTrainingResult(),
            .completed
        )

        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let finalGoalState = try XCTUnwrap(
            continuationObject["trainingFinalGoalState"]
                as? [String: Any]
        )
        XCTAssertEqual(
            finalGoalState["endLevelWasRequested"] as? Bool,
            true
        )
        XCTAssertEqual(
            finalGoalState["scriptActionCounter"] as? Int,
            1
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        let restoredFrame = restored.update(at: 100.1, input: .zero)
        XCTAssertEqual(
            restoredFrame.trainingFinalGoal?.endLevelState,
            .succeeded
        )
        XCTAssertEqual(
            restoredFrame.trainingFinalGoal?.scriptActionCounter,
            1
        )

        var hostile = continuationObject
        var hostileFinalGoalState = finalGoalState
        hostileFinalGoalState["scriptActionCounter"] = 2
        hostile["trainingFinalGoalState"] = hostileFinalGoalState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: hostile
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

    @MainActor
    func testCompletedTrainingSessionOffersOneDirectRestartAction() throws {
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var restartRequests = 0
        view.trainingRestartRequested = {
            restartRequests += 1
        }

        view.presentTrainingContentReadyState(
            completedLevelName: "Training Mission"
        )

        let contentReadyLabel = try XCTUnwrap(
            view.subviews.compactMap { $0 as? NSTextField }.first {
                $0.stringValue.hasPrefix("Training Mission completed.")
            }
        )
        let restartButton = try XCTUnwrap(
            view.subviews.compactMap { $0 as? NSButton }.first {
                $0.title == "Play Training Again"
            }
        )
        XCTAssertFalse(restartButton.isHidden)
        XCTAssertTrue(restartButton.isEnabled)
        XCTAssertEqual(
            contentReadyLabel.stringValue,
            """
            Training Mission completed.

            Play Training Again, open canonical content, or quit.
            """
        )
        view.requestTrainingRestart()
        XCTAssertEqual(restartRequests, 1)

        view.setTrainingRestartAvailable(false)
        XCTAssertFalse(restartButton.isEnabled)
        view.requestTrainingRestart()
        XCTAssertEqual(restartRequests, 1)

        view.setTrainingRestartAvailable(true)
        XCTAssertTrue(restartButton.isEnabled)
        view.requestTrainingRestart()
        XCTAssertEqual(restartRequests, 2)

        view.prepareForTrainingSession()
        XCTAssertTrue(restartButton.isHidden)
        XCTAssertFalse(restartButton.isEnabled)
    }

    func testPilotProfilesRequireConfirmedSelectionAndSurviveReload() throws {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-pilot-lifecycle-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let library = PilotProfileLibrary(rootURL: rootURL)

        XCTAssertTrue(try library.load().profiles.isEmpty)

        let createdAlice = try library.createProfile(named: "Alice")
        let alice = try XCTUnwrap(createdAlice.profiles.first)
        XCTAssertEqual(alice.name, "Alice")
        XCTAssertNil(createdAlice.defaultProfileID)

        let createdBob = try library.createProfile(named: "Bob")
        let bob = try XCTUnwrap(
            createdBob.profiles.first { $0.name == "Bob" }
        )
        XCTAssertNil(createdBob.defaultProfileID)

        let confirmedBob = try library.confirmProfile(bob.id)
        XCTAssertEqual(confirmedBob.defaultProfileID, bob.id)
        XCTAssertEqual(try library.load().defaultProfileID, bob.id)

        _ = alice.id
        XCTAssertEqual(
            try library.load().defaultProfileID,
            bob.id,
            "Tentative browsing followed by Cancel must not change the default"
        )
    }

    func testSuccessfulTrainingCompletionPersistsBeforeAcknowledgement()
        throws
    {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-training-progress-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let library = PilotProfileLibrary(rootURL: rootURL)
        let created = try library.createProfile(named: "Alice")
        let profileID = try XCTUnwrap(created.profiles.first?.id)
        _ = try library.confirmProfile(profileID)

        let level = makeTrainingFinalGoalLevel()
        let chain = try XCTUnwrap(level.trainingFinalGoalChain)
        let goal = try XCTUnwrap(level.objects.first {
            $0.handle == chain.goalObjectHandle
        })
        let initial = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        initial.destroyTrainingRobot(handle: 4_112)
        initial.destroyTrainingRASBot1(handle: 2_074)
        initial.destroyTrainingRASBot2(handle: 2_075)
        initial.destroyTrainingRASBot3(handle: 2_077)
        initial.destroyTrainingRASBot4(handle: 2_078)
        initial.destroyTrainingLastBot1(handle: 4_127)
        initial.destroyTrainingLastBot2(handle: 2_080)
        initial.destroyTrainingLastBot3(handle: 2_081)
        initial.destroyTrainingLastBot4(handle: 2_082)
        initial.destroyTrainingLastBot5(handle: 2_083)
        _ = initial.update(at: 0.1, input: .zero)
        var ready = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(initial.continuation)
            ) as? [String: Any]
        )
        ready["playerLocation"] = [
            "room": ["_0": chain.goalRoomSourceIndex]
        ]
        ready["playerPosition"] = [
            "x": goal.position.x,
            "y": goal.position.y,
            "z": goal.position.z,
        ]
        let simulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: ready)
            ),
            resumedAtTimestamp: 0
        )

        let completionFrame = simulation.update(at: 0.2, input: .zero)
        XCTAssertEqual(
            completionFrame.trainingFinalGoal?.endLevelState,
            .succeeded
        )
        XCTAssertEqual(
            simulation.trainingSessionOutcome,
            .awaitingResultAcknowledgement
        )

        let package = CanonicalPackageReference(
            identitySHA256: String(repeating: "a", count: 64),
            missionKey: "descent3.mission.pilot-training",
            levelKey: "descent3.level.training-mission"
        )
        let completed = try library.recordTrainingCompletion(
            profileID: profileID,
            package: package
        )
        let progress = try XCTUnwrap(
            completed.profiles.first?.missionProgress.first
        )
        XCTAssertEqual(progress.missionName, "Pilot Training")
        XCTAssertEqual(progress.package, package)
        XCTAssertEqual(progress.highestLevel, 0)
        XCTAssertTrue(progress.finished)
        XCTAssertEqual(progress.restoreCount, 0)
        XCTAssertEqual(progress.saveCount, 0)
        XCTAssertEqual(progress.shipPermissions, 0x01)
        XCTAssertEqual(
            try library.load().profiles.first?.missionProgress,
            [progress]
        )
        XCTAssertEqual(
            simulation.trainingSessionOutcome,
            .awaitingResultAcknowledgement,
            "Released EndLevel writes mission progress before result acknowledgement"
        )

        XCTAssertEqual(simulation.acknowledgeTrainingResult(), .completed)
    }

    func testPilotProfileBoundaryRejectsMalformedAndUnsupportedRecords()
        throws
    {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-pilot-boundary-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        let recordURL = rootURL.appending(path: "profiles.json")
        let library = PilotProfileLibrary(rootURL: rootURL)

        try Data(#"{"schemaVersion":2}"#.utf8).write(to: recordURL)
        XCTAssertThrowsError(try library.load()) {
            XCTAssertEqual(
                $0 as? PilotProfileLibraryError,
                .unsupportedSchema(2)
            )
        }

        try Data(
            #"{"schemaVersion":1,"defaultProfileID":null,"profiles":"bad"}"#
                .utf8
        ).write(to: recordURL)
        XCTAssertThrowsError(try library.load()) {
            XCTAssertEqual(
                $0 as? PilotProfileLibraryError,
                .malformedRecord
            )
        }

        let symlinkContainerURL =
            FileManager.default.temporaryDirectory.appending(
                path: "revival-pilot-root-symlink-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        defer {
            try? FileManager.default.removeItem(at: symlinkContainerURL)
        }
        let ownedRootURL = symlinkContainerURL.appending(
            path: "owned",
            directoryHint: .isDirectory
        )
        let linkedRootURL = symlinkContainerURL.appending(
            path: "linked",
            directoryHint: .isDirectory
        )
        _ = try PilotProfileLibrary(rootURL: ownedRootURL)
            .createProfile(named: "Alice")
        try FileManager.default.createSymbolicLink(
            at: linkedRootURL,
            withDestinationURL: ownedRootURL
        )
        XCTAssertThrowsError(
            try PilotProfileLibrary(rootURL: linkedRootURL).load()
        ) {
            XCTAssertEqual(
                $0 as? PilotProfileLibraryError,
                .malformedRecord
            )
        }
    }

    func testPilotProfileAtomicReplacementPreservesPriorRecordOnWriteFailure()
        throws
    {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-pilot-atomic-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: rootURL.path
            )
            try? FileManager.default.removeItem(at: rootURL)
        }
        let recordURL = rootURL.appending(path: "profiles.json")
        let library = PilotProfileLibrary(rootURL: rootURL)
        let created = try library.createProfile(named: "Alice")
        let profileID = try XCTUnwrap(created.profiles.first?.id)
        _ = try library.confirmProfile(profileID)
        let priorData = try Data(contentsOf: recordURL)
        let priorRecord = try library.load()

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: rootURL.path
        )
        XCTAssertThrowsError(try library.createProfile(named: "Bob")) {
            guard case .writeFailed = $0 as? PilotProfileLibraryError else {
                return XCTFail("Expected actionable profile write failure")
            }
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: rootURL.path
        )

        XCTAssertEqual(try Data(contentsOf: recordURL), priorData)
        XCTAssertEqual(try library.load(), priorRecord)

        let replaced = try library.createProfile(named: "Bob")
        XCTAssertEqual(replaced.profiles.map(\.name), ["Alice", "Bob"])
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: rootURL.path),
            ["profiles.json"]
        )
    }

    @MainActor
    func testPilotProfileSelectionRequiresExplicitConfirmation() throws {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-pilot-selection-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let library = PilotProfileLibrary(rootURL: rootURL)
        let aliceRecord = try library.createProfile(named: "Alice")
        let aliceID = try XCTUnwrap(aliceRecord.profiles.first?.id)
        let bobRecord = try library.createProfile(named: "Bob")
        let bobID = try XCTUnwrap(
            bobRecord.profiles.first { $0.name == "Bob" }?.id
        )
        let record = try library.confirmProfile(aliceID)
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var confirmedProfileID: UUID?
        var cancellationCount = 0
        var createdName: String?
        view.pilotProfileConfirmationRequested = {
            confirmedProfileID = $0
        }
        view.pilotProfileCancellationRequested = {
            cancellationCount += 1
        }
        view.pilotProfileCreationRequested = {
            createdName = $0
        }

        view.presentPilotProfileSelection(
            profiles: record.profiles.map { ($0.id, $0.name) },
            defaultProfileID: record.defaultProfileID,
            selectedProfileID: aliceID
        )
        let controls = view.subviews.flatMap { [$0] + $0.subviews }
        let popup = try XCTUnwrap(
            controls.compactMap { $0 as? NSPopUpButton }.first
        )
        popup.selectItem(withTitle: "Bob")
        XCTAssertNil(confirmedProfileID)
        view.requestPilotProfileConfirmation()
        XCTAssertEqual(confirmedProfileID, bobID)
        XCTAssertEqual(try library.load().defaultProfileID, aliceID)

        view.requestPilotProfileCancellation()
        XCTAssertEqual(cancellationCount, 1)

        view.presentPilotProfileSelection(
            profiles: [],
            defaultProfileID: nil,
            selectedProfileID: nil
        )
        let emptyControls = view.subviews.flatMap { [$0] + $0.subviews }
        let cancelButton = try XCTUnwrap(
            emptyControls.compactMap { $0 as? NSButton }.first {
                $0.title == "Cancel"
            }
        )
        XCTAssertFalse(cancelButton.isEnabled)
        let nameField = try XCTUnwrap(
            emptyControls.compactMap { $0 as? NSTextField }.first {
                $0.placeholderString == "Pilot name"
            }
        )
        nameField.stringValue = "Carol"
        view.requestPilotProfileCreation()
        XCTAssertEqual(createdName, "Carol")
    }
}
