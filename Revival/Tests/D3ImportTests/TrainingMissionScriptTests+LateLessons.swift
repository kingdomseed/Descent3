import XCTest

// The late lessons of TrainingMission.cpp on the Osiris runtime: the
// Camera Monitor pickup and use (Scripts 040 and 059, :2057-2084, with
// Scripts 038 and 041), TriggerScript_0001 (Script 042, :2347-2366) and
// level timer 14 (Script 039), the InvulnPowerup2 and CloakPowerup2
// scripts (Scripts 047 and 048, :2174-2200) with the generic module's
// powerup script, Script 034 and its timer 9 (Script 049), Portal4 (Script
// 050, :2368-2387), the final bots and timer 10 (Scripts 035 and 056), and
// FinalGoal (Script 057, :2309), which ends the level.
extension TrainingMissionScriptTests {
    /// `level` with the Training module, PortalRoom5 named, and no
    /// Guide-Bot.
    private func session(_ level: Level) throws -> GameSession {
        let scripted = scriptingTrainingCameraMonitorLevel(
            level, guideBot: false
        )
        try scripted.validate()
        let session = GameSession(
            level: scripted, presentationReadyTimestamp: 0
        )
        // Script 002's first HUD message has run.
        session.world.trainingMission.script002Count = 1
        return session
    }

    /// The presentation of the frames from `start`, 0.1 s apart, through
    /// `end`.
    private func run(
        _ session: GameSession, from start: Double, through end: Double
    ) -> [String] {
        var log: [String] = []
        var timestamp = start
        while timestamp <= end + 0.000_1 {
            log += presentationLog(session.update(at: timestamp, input: .zero))
            timestamp += 0.1
        }
        return log
    }

    /// Script 042: crossing Portal3 (the trigger's EVT_COLLIDE from
    /// ObjCheckTriggers) sets level timer 14 for 13 s, turns FlashLight-3
    /// off, shows KillBotIntro, plays intro6, and closes PortalRoom5's two
    /// portals, once. Script 039 then plays GuidebotF and shows KillBot2 on
    /// the timer.
    func testPortal3RunsScript042AndItsTimerRunsScript039AcrossReload() throws {
        let simulation = try session(makeTrainingKillbotEntryLevel())
        let player = simulation.world.testPlayerObject.handle
        simulation.world.setObjectLightDistance(
            simulation.level.findObjectName("FlashLight-3"), 50
        )

        simulation.world.objCheckTriggers(
            player, recordedFaces: [.init(roomSourceIndex: 2, faceIndex: 1)],
            level: simulation.level
        )
        let entered = simulation.update(at: 0.1, input: .zero)

        XCTAssertEqual(presentationLog(entered), [
            "hud:\(trainingText("KillBotIntro"))", "voice:intro6.osf",
        ])
        XCTAssertEqual(simulation.world.testTrainingMission?.script042Count, 1)
        XCTAssertEqual(simulation.returnMarkerLightDistance, 0)
        let room = try XCTUnwrap(simulation.level.rooms.firstIndex {
            $0.sourceIndex == 2
        })
        XCTAssertTrue(simulation.world.rooms[room].portalFlags.allSatisfy {
            $0 & LevelPortal.renderFacesFlag != 0
        })
        let timer = try XCTUnwrap(simulation.world.osirisTimers.entries.first {
            $0.isUsed && $0.owner == .level && $0.id == 14
        })
        XCTAssertEqual(timer.end, 13, accuracy: 0.000_1)
        // Portal3 is a one-shot trigger (TF_ONESHOT): it does not fire again.
        simulation.world.objCheckTriggers(
            player, recordedFaces: [.init(roomSourceIndex: 2, faceIndex: 1)],
            level: simulation.level
        )
        XCTAssertEqual(simulation.world.testTrainingMission?.script042Count, 1)

        let resumed = try restored(simulation, at: 100)
        let log = run(resumed, from: 100.1, through: 113.1)
        XCTAssertEqual(log, [
            "voice:guidebotf.osf", "hud:\(trainingText("KillBot2"))",
        ])
        XCTAssertEqual(resumed.world.testTrainingMission?.script039Count, 1)
    }

    /// Script 047 counts the InvulnPowerup2 pickup; the powerup's generic
    /// default script then runs msafe_DoPowerup's Invulnerability branch:
    /// MakePlayerInvulnerable for 30 s with its sound and message
    /// (Player.cpp:1576), the powerup dies, and SOUND_POWERUP_PICKUP plays.
    /// DoPlayerFrame counts the time down; at the end MakePlayerVulnerable
    /// plays "Invulnerability off" and shows TXT_INVULNOFF (:1597, :1816).
    func testInvulnPowerup2RunsScript047AndExpiresAcrossReload() throws {
        let simulation = try session(makeTrainingInvulnerabilityPickupLevel())
        let pickup = simulation.level.findObjectName("InvulnPowerup2")
        XCTAssertEqual(
            simulation.world.objects[pickup]?.scripts?.defaultScript,
            .genericPowerup
        )

        // Script 000's aObjMakeInvuln(player, 0) (TrainingMission.cpp:1468)
        // leaves the player invulnerable until the first DoPlayerFrame, and
        // the pickup refuses an invulnerable player (multisafe.cpp:2777).
        _ = simulation.update(at: 0.1, input: .zero)
        XCTAssertNil(simulation.world.playerInvulnerableTime)
        let frame = simulation.touch("InvulnPowerup2", at: 0.2)

        XCTAssertEqual(presentationLog(frame), [
            "sound:Invulnerability on", "hud:Invulnerability On",
            "sound:Powerup pickup",
        ])
        XCTAssertEqual(frame.presentationFeedback.first?.soundEventVolume, 0.5)
        XCTAssertEqual(simulation.world.testTrainingMission?.script047Count, 1)
        XCTAssertNil(simulation.world.objects[pickup])
        XCTAssertEqual(
            try XCTUnwrap(frame.playerInvulnerabilityRemaining), 29.9,
            accuracy: 0.000_1
        )
        let shields = simulation.shields
        XCTAssertFalse(simulation.world.applyDamageToPlayer(
            simulation.world.testPlayerObject.handle, killer: .none, damage: 10,
            level: simulation.level
        ))
        XCTAssertEqual(simulation.shields, shields)

        // A save in the middle of the invulnerability continues it.
        _ = run(simulation, from: 0.3, through: 15.2)
        let resumed = try restored(simulation, at: 100)
        XCTAssertEqual(
            try XCTUnwrap(resumed.world.playerInvulnerableTime), 14.9,
            accuracy: 0.001
        )
        XCTAssertTrue(resumed.world.playerInvulnerabilityAnnounces)
        let log = run(resumed, from: 100.1, through: 116)
        XCTAssertEqual(log, [
            "sound:Invulnerability off", "hud:Invulnerability Off",
        ])
        XCTAssertNil(resumed.world.playerInvulnerableTime)
    }

    /// Script 048 counts the CloakPowerup2 pickup; msafe_DoPowerup's Cloak
    /// branch runs MakeObjectInvisible for 30 s (object_lighting.cpp:572):
    /// "Cloak on" and TXT_CLOAKON, a 1-second fade out, then the cloak, in
    /// which the robots do not see the player (AIDetermineObjVisLevel,
    /// AImain.cpp:1645), then MakeObjectVisible's "Cloak off" and
    /// TXT_MSG_CLOAKOFF and a 1-second fade in (ObjDoEffects,
    /// object.cpp:2447). With the four RAS bots and the invulnerability
    /// already counted, this sixth producer runs Script 034 in the same
    /// frame, and its timer 9 runs Script 049.
    func testCloakPowerup2RunsScript048ThenScript034AndCloaksAcrossReload()
        throws
    {
        let simulation = try session(makeTrainingCloakPickupLevel())
        for counter in [\TrainingMissionState.script043Count,
                        \.script044Count, \.script045Count,
                        \.script046Count, \.script047Count] {
            simulation.world.trainingMission[keyPath: counter] = 1
        }

        let player = simulation.world.testPlayerObject.handle

        let frame = simulation.touch("CloakPowerup2", at: 0.1)

        XCTAssertEqual(presentationLog(frame), [
            "sound:Cloak on", "hud:Cloak On", "sound:Powerup pickup",
        ])
        let mission = try XCTUnwrap(simulation.world.testTrainingMission)
        XCTAssertEqual(mission.script048Count, 1)
        XCTAssertEqual(mission.script034Count, 1)
        XCTAssertEqual(
            simulation.world.objects[
                simulation.level.findObjectName("FlashLight-4")
            ]?.localLighting?.lightDistance,
            50
        )
        let cloak = try XCTUnwrap(frame.playerCloak)
        XCTAssertEqual(cloak.phase, .fadingOut)
        XCTAssertEqual(cloak.phaseRemaining, 0.9, accuracy: 0.000_1)
        XCTAssertEqual(cloak.phaseDuration, 1)

        let fadeLog = run(simulation, from: 0.2, through: 1.1)
        XCTAssertEqual(fadeLog, [])
        let cloaked = try XCTUnwrap(
            ObjectCloakFrame(simulation.world.objects[player]?.effect)
        )
        XCTAssertEqual(cloaked.phase, .cloaked)
        let robot = try XCTUnwrap(simulation.world.objects[ObjectHandle(2_074)])
        XCTAssertEqual(
            simulation.world.aiDetermineObjVisLevel(
                robot, simulation.world.testPlayerObject
            ),
            0
        )

        // Script 034's level timer 9 (2 s) runs Script 049.
        let timerLog = run(simulation, from: 1.2, through: 2.2)
        XCTAssertEqual(timerLog, [
            "hud:\(trainingText("GoodJob"))",
            "hud:\(trainingText("ProceedtoLastRoom"))", "voice:proceed5.osf",
        ])

        let resumed = try restored(simulation, at: 100)
        XCTAssertEqual(
            ObjectCloakFrame(resumed.world.objects[player]?.effect)?.phase,
            .cloaked
        )
        // The cloak ends 30 s after the fade (about 28.9 s after the
        // save), and the fade in takes 1 s.
        var endLog: [String] = []
        var timestamp = 100.1
        while endLog.isEmpty, timestamp < 131 {
            endLog = presentationLog(resumed.update(at: timestamp, input: .zero))
            timestamp += 0.1
        }
        XCTAssertEqual(endLog, ["sound:Cloak off", "hud:Cloak Off"])
        XCTAssertEqual(timestamp, 128.9, accuracy: 0.15)
        XCTAssertEqual(
            ObjectCloakFrame(resumed.world.objects[player]?.effect)?.phase,
            .fadingIn
        )
        XCTAssertTrue(run(resumed, from: timestamp, through: timestamp + 1.1)
            .isEmpty)
        XCTAssertNil(ObjectCloakFrame(resumed.world.objects[player]?.effect))
    }

    /// Script 050: crossing Portal4 turns FlashLight-4 off, shows GoodJob,
    /// closes PortalRoom6's two portals, plays intro7, and shows
    /// FinalSessionIntro, in source order, once.
    func testPortal4RunsScript050AndClosesTheLastRoomAcrossReload() throws {
        let level = scriptingTrainingCameraMonitorLevel(
            makeTrainingFinalRoomEntryLevel(), guideBot: false
        )
        try level.validate()
        let simulation = try GameSession(
            level: level, world: script050ReadyContinuation(in: level),
            resumedAtTimestamp: 0
        )
        let room = try XCTUnwrap(level.rooms.firstIndex {
            $0.sourceIndex == 44
        })
        XCTAssertTrue(simulation.world.rooms[room].portalFlags.allSatisfy {
            $0 & LevelPortal.renderFacesFlag == 0
        })

        let entered = simulation.update(at: 0.1, input: .zero)

        XCTAssertEqual(presentationLog(entered), [
            "hud:\(trainingText("GoodJob"))", "voice:intro7.osf",
            "hud:\(trainingText("FinalSessionIntro"))",
        ])
        XCTAssertEqual(simulation.world.testTrainingMission?.script050Count, 1)
        XCTAssertEqual(
            simulation.world.objects[level.findObjectName("FlashLight-4")]?
                .localLighting?.lightDistance,
            0
        )
        XCTAssertTrue(simulation.world.rooms[room].portalFlags.allSatisfy {
            $0 & LevelPortal.renderFacesFlag != 0
        })

        let resumed = try restored(simulation, at: 100)
        XCTAssertTrue(resumed.world.rooms[room].portalFlags.allSatisfy {
            $0 & LevelPortal.renderFacesFlag != 0
        })
        XCTAssertEqual(resumed.world.testTrainingMission?.script050Count, 1)
    }

    /// The Camera Monitor fixture with the Training module and no
    /// Guide-Bot, so Script 058 follows Script 059 at once.
    private func cameraMonitorSession() throws -> GameSession {
        let level = scriptingTrainingCameraMonitorLevel(
            makeTrainingCameraMonitorLevel(), guideBot: false
        )
        try level.validate()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        // Script 002's first HUD message has run.
        session.world.trainingMission.script002Count = 1
        return session
    }

    /// Script 040: the player touches the Camera Monitor. GuideBotC plays,
    /// PupC1 plays on the monitor, aAddObjectToInventory takes it
    /// (Inventory::AddObject, Inventory.cpp:393: the level goal hears of
    /// the OF_INFORM_DESTROY_TO_LG object and completes, and the monitor is
    /// ghosted in the inventory), and UseCameraMonitor shows. The level
    /// goals' DoFrame then counts no active primary goal
    /// (EVT_ALL_LEVEL_GOALS_COMPLETE, levelgoal.cpp:1129-1135).
    func testCameraMonitorPickupRunsScript040AndCompletesLocateGoal() throws {
        let simulation = try cameraMonitorSession()
        let monitor = simulation.level.findObjectName("CameraMonitor")
        // Level_goals.InitLevel marks the goal's object (levelgoal.cpp:1200).
        XCTAssertNotEqual(
            (simulation.world.objects[monitor]?.flags ?? 0)
                & GameObject.informDestroyToLevelGoalsFlag,
            0
        )
        XCTAssertEqual(simulation.world.goals[0].status, 1_028)

        let frame = simulation.touch("CameraMonitor", at: 0.1)

        XCTAssertEqual(presentationLog(frame), [
            "voice:guidebotc.osf", "sound:PupC1",
            "hud:Completed Locate the Camera Monitor", "sound:GoalComplete",
            "hud:\(trainingText("UseCameraMonitor"))",
        ])
        XCTAssertEqual(simulation.world.testTrainingMission?.script040Count, 1)
        let held = try XCTUnwrap(simulation.world.objects[monitor])
        XCTAssertEqual(held.type, .dummy)
        XCTAssertEqual(held.dummyType, .powerup)
        XCTAssertNotEqual(held.flags & GameObject.inPlayerInventoryFlag, 0)
        XCTAssertEqual(
            simulation.world.playerInventory.selectedItem?.object, monitor
        )
        XCTAssertEqual(simulation.world.goals[0].status, 1_036)
        XCTAssertEqual(simulation.world.goals[0].items.map(\.done), [true])
        XCTAssertNotEqual(
            simulation.world.levelGoalFlags & LevelGoalsFlag.allPrimariesDone, 0
        )

        // The held monitor and the completed goal survive a save, and the
        // pickup does not run again.
        let resumed = try restored(simulation, at: 100)
        XCTAssertEqual(resumed.world.playerInventory, simulation.world.playerInventory)
        XCTAssertEqual(resumed.world.goals, simulation.world.goals)
        XCTAssertTrue(presentationLog(resumed.update(at: 100.1, input: .zero))
            .isEmpty)
    }

    /// Script 059: the inventory use key uses the selected monitor
    /// (UseInventoryItem, Inventory.cpp:1485). Its custom script plays
    /// GuideBotD, shows GBExtra, opens a 10-second popup view from the
    /// SecurityCamera's gun 0 (aCreatePopupView), and returns
    /// CONTINUE_DEFAULT, so the item leaves the inventory
    /// (Inventory.cpp:819-821). The page's OIF_INVEN_NOREMOVE keeps the
    /// object (a ghost) alive. With no Guide-Bot out, Script 058 runs in
    /// the same frame's level interval, and Script 038 sets level timer 13,
    /// whose Script 041 counts 2 seconds later.
    func testCameraMonitorUseRunsScript059AndTimesThePopupViewAcrossReload()
        throws
    {
        let simulation = try cameraMonitorSession()
        _ = simulation.touch("CameraMonitor", at: 0.1)
        let monitor = simulation.level.findObjectName("CameraMonitor")
        let camera = simulation.level.findObjectName("SecurityCamera")
        let held = try restored(simulation, at: 10)

        let used = held.update(at: 10.1, input: .init(usesInventory: true))

        XCTAssertEqual(presentationLog(used), [
            "voice:guidebotd.osf", "hud:\(trainingText("GBExtra"))",
            "voice:proceed6.osf", "hud:\(trainingText("GoodJob"))",
        ])
        let mission = try XCTUnwrap(held.world.testTrainingMission)
        XCTAssertEqual(mission.script059Count, 1)
        XCTAssertEqual(mission.script058Count, 1)
        XCTAssertEqual(mission.script038Count, 1)
        XCTAssertTrue(held.world.playerInventory.items.isEmpty)
        XCTAssertNil(held.world.playerInventory.selectedItem)
        let ghost = try XCTUnwrap(held.world.objects[monitor])
        XCTAssertEqual(ghost.type, .dummy)
        XCTAssertEqual(ghost.flags & GameObject.inPlayerInventoryFlag, 0)
        XCTAssertEqual(ghost.flags & GameObject.deadFlag, 0)

        let cameraObject = try XCTUnwrap(held.world.objects[camera])
        let popup = try XCTUnwrap(used.popupView)
        XCTAssertTrue(popup.isPopup)
        XCTAssertEqual(popup.viewerObjectHandle, camera.rawValue)
        XCTAssertEqual(popup.remainingDuration, 10)
        // The fixture camera has no model, so the view is its own.
        XCTAssertEqual(popup.camera.position, cameraObject.position)
        XCTAssertEqual(
            popup.camera.target,
            cameraObject.position + cameraObject.orientation.forward
        )
        // SVF_POPUP | SVF_BIGGER | SVF_TIMED, at D3_DEFAULT_ZOOM / 1; the
        // render step counted the previous Frametime.
        XCTAssertEqual(held.world.smallViews[0].flags, 11)
        XCTAssertEqual(held.world.smallViews[0].zoom, SmallView.defaultZoom)
        XCTAssertEqual(held.world.smallViews[0].timer, 9.9, accuracy: 0.000_1)
        XCTAssertNotNil(held.world.osirisTimers.entries.first {
            $0.isUsed && $0.owner == .level && $0.id == 13
        })

        // The popup and the pending timer 13 survive a save.
        let popupContinuation = try restored(held, at: 200)
        let afterReload = popupContinuation.update(at: 200.1, input: .zero)
        XCTAssertEqual(
            try XCTUnwrap(afterReload.popupView).remainingDuration, 9.9,
            accuracy: 0.000_1
        )
        var frames = [afterReload]
        var timestamp = 200.1
        for _ in 1...105 {
            timestamp += 0.1
            frames.append(popupContinuation.update(at: timestamp, input: .zero))
        }
        XCTAssertEqual(
            popupContinuation.world.testTrainingMission?.script041Count, 1
        )
        // The window closes when its timer passes 0 after its last frame,
        // 10 s of 0.1 s frames after the use (Float time).
        let lastOpen = try XCTUnwrap(frames.lastIndex { $0.popupView != nil })
        XCTAssertTrue((98...99).contains(lastOpen))
        XCTAssertLessThan(
            try XCTUnwrap(frames[lastOpen].popupView).remainingDuration,
            0.1 + 0.000_1
        )
        XCTAssertFalse(popupContinuation.world.smallViews[0].isActive)
        XCTAssertTrue(frames.dropFirst().allSatisfy {
            presentationLog($0).isEmpty
        })
    }

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
            level: level, presentationReadyTimestamp: 0
        )

        simulation.killRobotsAsPlayer([4_127, 2_080, 2_081, 2_082, 2_083])
        var frame = simulation.update(at: 0.1, input: .zero)
        for counter in [\TrainingMissionState.script051Count,
                        \.script052Count, \.script053Count,
                        \.script054Count, \.script055Count] {
            XCTAssertEqual(
                simulation.world.testTrainingMission?[keyPath: counter], 1
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
                    connected.portals[portal.connectedPortal].flags & 1, 0
                )
            }
        }

        try assertBarrierIsOpen(in: simulation.runtimeLevel)
        XCTAssertEqual(simulation.world.testTrainingMission?.script035Count, 1)
        let marker = ObjectHandle(4_118)
        XCTAssertEqual(level.findObjectName("FlashLight-5"), marker)
        XCTAssertEqual(
            simulation.world.objects[marker]?.localLighting?.lightDistance, 50
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
                GameWorld.self, from: pendingData
            )).rebased(onto: level),
            resumedAtTimestamp: 100
        )
        try assertBarrierIsOpen(in: restored.runtimeLevel)
        var log: [String] = []
        for frameIndex in 1...20 {
            frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1, input: .zero
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
                at: 102.1, input: .zero
            ).presentationFeedback.isEmpty
        )

        let completed = try GameSession(
            level: level,
            world: (JSONDecoder().decode(
                GameWorld.self, from: JSONEncoder().encode(restored.world)
            )).rebased(onto: level),
            resumedAtTimestamp: 200
        )
        try assertBarrierIsOpen(in: completed.runtimeLevel)
        XCTAssertTrue(
            completed.update(
                at: 200.1, input: .zero
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
        let (simulation, frame) = try trainingLevelEndFrame(headlightIsOn: true)
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
        _ = simulation.update(at: 0.3, input: .init(firesPrimaryWeapon: true))
        XCTAssertEqual(
            simulation.energy, finalGoal.postLevelResult.energy,
            accuracy: 0.000_001,
            "successful final-result suspension cannot spend another volley"
        )
        XCTAssertEqual(
            finalGoal.presentation,
            .init(
                title: "Mission Successful", levelName: "Training Mission",
                difficulty: .rookie, showsHUD: false, playsGameplayAudio: false,
                showsCockpit: false, showsHeadlightIndicator: false
            )
        )
        XCTAssertEqual(
            RevivalGameplayView.levelEndText(finalGoal.presentation),
            "Mission Successful\nTraining Mission\nDifficulty: Rookie"
        )
        XCTAssertEqual(
            RevivalGameplayView.postLevelResultText(finalGoal.postLevelResult),
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
                keyCode: 36, resultIsPresented: true, presentationElapsedTime: 2
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                keyCode: 36, resultIsPresented: true,
                presentationElapsedTime: 1.999
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                keyCode: 36, resultIsPresented: false,
                presentationElapsedTime: 2
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                keyCode: 49, resultIsPresented: true, presentationElapsedTime: 2
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                keyCode: 53, resultIsPresented: true, presentationElapsedTime: 2
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                resultIsPresented: true, presentationElapsedTime: 1.999,
                queuedKey: false, mouseButtonIsPressed: true,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                resultIsPresented: true, presentationElapsedTime: 2,
                queuedKey: true, mouseButtonIsPressed: false,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                resultIsPresented: true, presentationElapsedTime: 2,
                queuedKey: false, mouseButtonIsPressed: true,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsLevelResultAcknowledgement(
                resultIsPresented: true, presentationElapsedTime: 2,
                queuedKey: false, mouseButtonIsPressed: false,
                controllerButtonIsPressed: true
            )
        )
        XCTAssertEqual(simulation.levelOutcome, .awaitingResultAcknowledgement)
        XCTAssertEqual(simulation.acknowledgeLevelResult(), .completed)
        XCTAssertEqual(simulation.levelOutcome, .completed)
        XCTAssertEqual(simulation.acknowledgeLevelResult(), .completed)

        // An ended level is not saved: the world still asks for the level
        // end, which a save refuses.
        XCTAssertThrowsError(try GameSession(
            level: simulation.level, world: simulation.world,
            resumedAtTimestamp: 100
        ))
    }
}
