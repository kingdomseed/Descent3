import XCTest

extension WorldRenderingTests {
    func testScripts035And056OpenPortalRoomSevenThenPresentOnceAfterTimer()
        throws
    {
        // The Training module runs Scripts 051-055 as the five last bots
        // die (TrainingMission.cpp:2204-2307), then Script 035 in the level
        // EVT_INTERVAL (:1417-1429) and Script 056 on level timer 10
        // (:1614-1622).
        let level = addingTrainingMissionScripting(
            makeTrainingFinalBotsCompletionLevel()
        )
        try level.validate()
        // PortalRoom7 (source room 16 here) and its marker, FlashLight-5.
        let barrierRoomSourceIndex = 16
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        simulation.killRobotsAsPlayer([4_127, 2_080, 2_081, 2_082, 2_083])
        var frame = simulation.update(at: 0.1, input: .zero)
        for counter in [\TrainingMissionState.script051Count,
                        \.script052Count, \.script053Count,
                        \.script054Count, \.script055Count] {
            XCTAssertEqual(
                simulation.world.testTrainingMission?[keyPath: counter],
                1
            )
        }

        func assertBarrierIsOpen(in level: Level) throws {
            let barrier = try XCTUnwrap(level.rooms.first {
                $0.sourceIndex == barrierRoomSourceIndex
            })
            for portalIndex in [0, 1] {
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

        try assertBarrierIsOpen(in: simulation.runtimeLevel)
        XCTAssertEqual(simulation.world.testTrainingMission?.script035Count, 1)
        let marker = ObjectHandle(4_118)
        XCTAssertEqual(level.findObjectName("FlashLight-5"), marker)
        XCTAssertEqual(
            simulation.world.objects[marker]?.localLighting?.lightDistance,
            50
        )
        XCTAssertFalse(frame.presentationFeedback.contains {
            $0.voiceSourceName == "done.osf"
        })
        let timer = try XCTUnwrap(simulation.world.osirisTimers.entries.first {
            $0.isUsed && $0.owner == .level && $0.id == 10
        })
        XCTAssertEqual(timer.end, simulation.world.gameTime + 2, accuracy: 0.11)
        let pendingData = try JSONEncoder().encode(simulation.world)

        let restored = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: pendingData
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
        XCTAssertEqual(restored.world.testTrainingMission?.script056Count, 1)
        XCTAssertEqual(
            log.filter { $0 == "hud:\(trainingText("AllDone"))" }.count, 1
        )
        XCTAssertEqual(log.filter { $0 == "voice:done.osf" }.count, 1)
        XCTAssertTrue(
            restored.update(
                at: 102.1,
                input: .zero
            ).presentationFeedback.isEmpty
        )

        let completed = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self,
                from: JSONEncoder().encode(restored.world)
            )).rebased(onto: level),
            resumedAtTimestamp: 200
        )
        try assertBarrierIsOpen(in: completed.runtimeLevel)
        XCTAssertTrue(
            completed.update(
                at: 200.1,
                input: .zero
            ).presentationFeedback.isEmpty
        )
    }

    /// Script 057 (FinalGoal's EVT_COLLIDE, TrainingMission.cpp:2309-2321)
    /// calls aEndLevel (DallasFuncs.cpp:2535), whose MSAFE_MISC_END_LEVEL
    /// sets GAMESTATE_LVLEND (multisafe.cpp:2079). After the frame the
    /// sequencer suspends the controls and runs EndLevel's results
    /// (gamesequence.cpp:1240-1243, :1891).
    @MainActor
    func testScript057FinalGoalEndsTrainingThroughAEndLevel()
        throws
    {
        let (simulation, frame) = try trainingLevelEndFrame(
            headlightIsOn: true
        )
        XCTAssertEqual(simulation.world.testTrainingMission?.script057Count, 1)
        XCTAssertEqual(simulation.world.gameStateRequest, .levelEnd)
        let finalGoal = try XCTUnwrap(frame.levelEnd)
        XCTAssertNil(
            frame.playerFastHeadlight,
            "the final result suppresses an otherwise-on headlight"
        )
        XCTAssertEqual(finalGoal.endLevelState, .succeeded)
        XCTAssertTrue(finalGoal.controlsAreSuspended)
        XCTAssertEqual(
            finalGoal.postLevelResult,
            .init(
                title: "Mission Successful",
                levelName: "Training Mission",
                difficulty: .rookie,
                // Script 000 ghosts DestroyBot2 (TrainingMission.cpp:1488),
                // so nine robots die.
                score: 1_800,
                elapsedTime: 0.1,
                enemyKills: 9,
                shields: simulation.shields,
                energy: simulation.energy,
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
            RevivalGameplayView.levelEndText(
                finalGoal.presentation
            ),
            "Mission Successful\nTraining Mission\nDifficulty: Rookie"
        )
        XCTAssertEqual(
            RevivalGameplayView.postLevelResultText(
                finalGoal.postLevelResult
            ),
            """
            Mission Successful
            Training Mission
            Difficulty: Rookie
            Score: 1800
            Time: 0:00
            Enemies Killed: 9
            Shields: 100
            Energy: 100
            Deaths: 0
            Restores: 0
            """
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                keyCode: 36,
                resultIsPresented: true,
                presentationElapsedTime: 2
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                keyCode: 36,
                resultIsPresented: true,
                presentationElapsedTime: 1.999
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                keyCode: 36,
                resultIsPresented: false,
                presentationElapsedTime: 2
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                keyCode: 49,
                resultIsPresented: true,
                presentationElapsedTime: 2
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                keyCode: 53,
                resultIsPresented: true,
                presentationElapsedTime: 2
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 1.999,
                queuedKey: false,
                mouseButtonIsPressed: true,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 2,
                queuedKey: true,
                mouseButtonIsPressed: false,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 2,
                queuedKey: false,
                mouseButtonIsPressed: true,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 2,
                queuedKey: false,
                mouseButtonIsPressed: false,
                controllerButtonIsPressed: true
            )
        )
        XCTAssertEqual(
            simulation.levelOutcome,
            .awaitingResultAcknowledgement
        )
        XCTAssertEqual(simulation.acknowledgeLevelResult(), .completed)
        XCTAssertEqual(simulation.levelOutcome, .completed)
        XCTAssertEqual(simulation.acknowledgeLevelResult(), .completed)

        // An ended level is not saved: the world still asks for the level
        // end, which a save refuses.
        XCTAssertThrowsError(try GameSession(
            level: simulation.level,
            world: simulation.world,
            resumedAtTimestamp: 100
        ))
    }

    @MainActor
    func testCompletedTrainingSessionOffersOneDirectRestartAction() throws {
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var restartRequests = 0
        view.playAgainRequested = {
            restartRequests += 1
        }

        view.presentContentReadyState(
            completedLevelName: "Training Mission"
        )

        let contentReadyLabel = try XCTUnwrap(
            view.subviews.compactMap { $0 as? NSTextField }.first {
                $0.stringValue.hasPrefix("Training Mission completed.")
            }
        )
        let restartButton = try XCTUnwrap(
            view.subviews.compactMap { $0 as? NSButton }.first {
                $0.title == "Play Again"
            }
        )
        XCTAssertFalse(restartButton.isHidden)
        XCTAssertTrue(restartButton.isEnabled)
        XCTAssertEqual(
            contentReadyLabel.stringValue,
            """
            Training Mission completed.

            Play again, open canonical content, or quit.
            """
        )
        view.requestPlayAgain()
        XCTAssertEqual(restartRequests, 1)

        view.setPlayAgainAvailable(false)
        XCTAssertFalse(restartButton.isEnabled)
        view.requestPlayAgain()
        XCTAssertEqual(restartRequests, 1)

        view.setPlayAgainAvailable(true)
        XCTAssertTrue(restartButton.isEnabled)
        view.requestPlayAgain()
        XCTAssertEqual(restartRequests, 2)

        view.prepareForLevelSession()
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

        let (simulation, completionFrame) = try trainingLevelEndFrame()
        XCTAssertEqual(
            completionFrame.levelEnd?.endLevelState,
            .succeeded
        )
        XCTAssertEqual(
            simulation.levelOutcome,
            .awaitingResultAcknowledgement
        )

        let package = CanonicalPackageReference(
            identitySHA256: String(repeating: "a", count: 64),
            missionKey: "descent3.mission.pilot-training",
            levelKey: "descent3.level.training-mission"
        )
        let completed = try library.recordMissionCompletion(
            profileID: profileID,
            package: package,
            missionName: "Pilot Training"
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
            simulation.levelOutcome,
            .awaitingResultAcknowledgement,
            "Released EndLevel writes mission progress before result acknowledgement"
        )

        XCTAssertEqual(simulation.acknowledgeLevelResult(), .completed)
    }

    /// CurrentPilotUpdateMissionStatus (pilot.cpp:1463): a pilot keeps one
    /// progress record per mission, keyed by the package's mission key.
    func testMissionCompletionIsKeyedByMissionKey() throws {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-mission-progress-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let library = PilotProfileLibrary(rootURL: rootURL)
        let profileID = try XCTUnwrap(
            library.createProfile(named: "Alice").profiles.first?.id
        )
        func package(_ mission: String, _ digit: Character) -> CanonicalPackageReference {
            .init(
                identitySHA256: String(repeating: digit, count: 64),
                missionKey: mission,
                levelKey: mission + ".level-1"
            )
        }
        _ = try library.recordMissionCompletion(
            profileID: profileID,
            package: package("descent3.mission.first", "a"),
            missionName: "First"
        )
        _ = try library.recordMissionCompletion(
            profileID: profileID,
            package: package("descent3.mission.second", "b"),
            missionName: "Second"
        )
        // A new package of the first mission replaces its record, even when
        // the mission's NAME changed.
        let replaced = try library.recordMissionCompletion(
            profileID: profileID,
            package: package("descent3.mission.first", "c"),
            missionName: "First Renamed"
        )
        let progress = try XCTUnwrap(replaced.profiles.first?.missionProgress)
        XCTAssertEqual(
            progress.map(\.package.missionKey),
            ["descent3.mission.second", "descent3.mission.first"]
        )
        XCTAssertEqual(progress.map(\.missionName), ["Second", "First Renamed"])
        XCTAssertEqual(
            progress.last?.package.identitySHA256,
            String(repeating: "c", count: 64)
        )
        // Two missions with the same NAME keep separate records.
        let sameName = try library.recordMissionCompletion(
            profileID: profileID,
            package: package("descent3.mission.third", "d"),
            missionName: "Second"
        )
        XCTAssertEqual(
            sameName.profiles.first?.missionProgress.map(\.package.missionKey),
            ["descent3.mission.second", "descent3.mission.first",
             "descent3.mission.third"]
        )
        XCTAssertEqual(try library.load(), sameName)
        XCTAssertThrowsError(try library.recordMissionCompletion(
            profileID: profileID,
            package: package("descent3.mission.fourth", "e"),
            missionName: ""
        ))
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
