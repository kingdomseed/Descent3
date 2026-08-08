import XCTest

extension WorldRenderingTests {
    func testAfterburnerInputBypassesRampCombinesCarriersAndClearsInactiveGameplay() {
        var input = PlayerInputState(rampDuration: 0.5)
        input.setHeld(.init(forward: 1, afterburner: 1))
        input.setController(.init(afterburner: 0.75))

        let first = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(first.forward, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(first.afterburner, 1)

        input.setGameplayActive(false, simulation: nil, at: 1)
        XCTAssertEqual(input.snapshot(frameDuration: 0.1), .zero)

        XCTAssertEqual(
            RevivalGameplayView.heldInput(for: [], afterburner: true),
            .init(afterburner: 1)
        )
        XCTAssertEqual(
            RevivalGameplayView.controllerInput(
                leftX: 0,
                leftY: 0,
                rightX: 0,
                rightY: 0,
                leftTrigger: 0,
                rightTrigger: 0,
                leftShoulder: 0,
                rightShoulder: 0,
                afterburner: 0.6
            ),
            .init(afterburner: 0.6)
        )
    }

    func testInputSnapshotRampsHeldAxesAndClearsInactiveGameplay() {
        var ramp = PlayerInputRamp(rampDuration: 0.5)

        let first = ramp.snapshot(
            held: .init(forward: 1, sideways: -1),
            frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(first.forward, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(first.sideways, -0.2, accuracy: 0.000_001)
        XCTAssertEqual(first.vertical, 0)
        XCTAssertEqual(first.pitch, 0)
        XCTAssertEqual(first.yaw, 0)
        XCTAssertEqual(first.roll, 0)

        let second = ramp.snapshot(
            held: .init(forward: 1, sideways: -1),
            frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(second.forward, 0.4, accuracy: 0.000_001)
        XCTAssertEqual(second.sideways, -0.4, accuracy: 0.000_001)

        let released = ramp.snapshot(
            held: .zero,
            frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(released, .zero)
        let restarted = ramp.snapshot(
            held: .init(forward: 1),
            frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(restarted.forward, 0.2, accuracy: 0.000_001)
        let reversed = ramp.snapshot(
            held: .init(forward: -1),
            frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(reversed.forward, -0.4, accuracy: 0.000_001)

        XCTAssertEqual(
            ramp.snapshot(
                held: .init(forward: 1, sideways: 1),
                frameDuration: 0.1,
                gameplayIsActive: false
            ),
            .zero
        )
        XCTAssertEqual(
            ramp.snapshot(
                held: .zero,
                frameDuration: 0.1,
                gameplayIsActive: true
            ),
            .zero
        )

        var immediate = PlayerInputRamp(rampDuration: 0)
        XCTAssertEqual(
            immediate.snapshot(
                held: .init(forward: -0.01, sideways: 0.25),
                frameDuration: 0,
                gameplayIsActive: true
            ),
            .init(forward: -1, sideways: 1)
        )
    }

    func testPlayerInputStateCombinesKeyboardControllerAndOneShotMousePerAxis() {
        var input = PlayerInputState(rampDuration: 0.35)
        input.setHeld(
            .init(
                forward: 1,
                sideways: -1,
                vertical: 1,
                pitch: -1,
                yaw: 1,
                roll: -1
            )
        )
        input.setController(
            .init(
                forward: 0.2,
                sideways: 0.1,
                vertical: 0.3,
                pitch: 0.2,
                yaw: 0.4,
                roll: 0.1
            )
        )
        input.accumulateMouseDelta(x: 10, y: -5)

        let first = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(first.forward, 0.485_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.sideways, -0.185_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.vertical, 0.585_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.pitch, -0.080_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.yaw, 0.695_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.roll, -0.185_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.directLookPitchRadians, 0)
        XCTAssertEqual(first.directLookYawRadians, 0)

        let second = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(second.pitch, -0.371_428_6, accuracy: 0.000_001)
        XCTAssertEqual(second.yaw, 0.971_428_6, accuracy: 0.000_001)

        input.mouseLookEnabled = true
        input.accumulateMouseDelta(x: 10, y: -5)
        let mouseLook = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(mouseLook.pitch, -0.657_142_9, accuracy: 0.000_001)
        XCTAssertEqual(mouseLook.yaw, 1, accuracy: 0.000_001)
        XCTAssertEqual(
            mouseLook.directLookPitchRadians,
            Float.pi / 1_000,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            mouseLook.directLookYawRadians,
            Float.pi / 500,
            accuracy: 0.000_001
        )
        let drained = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(drained.directLookPitchRadians, 0)
        XCTAssertEqual(drained.directLookYawRadians, 0)
    }

    func testPlayerInputStateClearsAndRebasesAcrossFocusChanges() {
        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 10
        )
        var input = PlayerInputState(rampDuration: 0.5)
        input.setHeld(.init(forward: 1))
        input.setController(.init(sideways: 0.75, roll: -0.5))
        input.accumulateMouseDelta(x: 25, y: -10)
        XCTAssertEqual(
            input.snapshot(frameDuration: 0.1).forward,
            0.2,
            accuracy: 0.000_001
        )

        input.setGameplayActive(false, simulation: simulation, at: 10)
        input.setGameplayActive(false, simulation: simulation, at: 15)
        input.setHeld(.init(forward: 1))
        XCTAssertFalse(input.gameplayIsActive)
        XCTAssertEqual(input.snapshot(frameDuration: 0.1), .zero)

        input.setGameplayActive(true, simulation: simulation, at: 20)
        input.setHeld(.init(forward: 1))
        XCTAssertTrue(input.gameplayIsActive)
        let resumed = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(resumed.forward, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(resumed.sideways, 0)
        XCTAssertEqual(resumed.roll, 0)
        XCTAssertEqual(resumed.pitch, 0)
        XCTAssertEqual(resumed.yaw, 0)
        XCTAssertEqual(
            simulation.update(at: 20.016, input: .zero).storedFrameDuration,
            0.016,
            accuracy: 0.000_001
        )
    }

    func testConcreteAppKitOwnerMapsSixAxesAndSourceControllerDeadzone() {
        XCTAssertEqual(
            RevivalGameplayView.heldInput(
                for: [13, 0, 15, 126, 124, 12]
            ),
            .init(
                forward: 1,
                sideways: -1,
                vertical: 1,
                pitch: -1,
                yaw: 1,
                roll: 1
            )
        )
        XCTAssertEqual(
            RevivalGameplayView.heldInput(
                for: [13, 1, 0, 2, 15, 3, 126, 125, 123, 124, 12, 14]
            ),
            .zero
        )

        let controller = RevivalGameplayView.controllerInput(
            leftX: 0.6,
            leftY: 0.7,
            rightX: 0.4,
            rightY: 0.6,
            leftTrigger: 0.2,
            rightTrigger: 0.6,
            leftShoulder: 1,
            rightShoulder: 0
        )
        XCTAssertEqual(controller.forward, 0.625, accuracy: 0.000_001)
        XCTAssertEqual(controller.sideways, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(controller.vertical, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(controller.pitch, -0.5, accuracy: 0.000_001)
        XCTAssertEqual(controller.yaw, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(controller.roll, 1, accuracy: 0.000_001)
    }

    @MainActor
    func testFullScreenPlayerRearViewUsesReleasedInputTimingCameraAndContinuation()
        throws
    {
        XCTAssertTrue(
            RevivalGameplayView.requestsRearView(
                keyCode: 9,
                isRepeat: false,
                gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsRearView(
                keyCode: 9,
                isRepeat: true,
                gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsRearView(
                keyCode: 9,
                isRepeat: false,
                gameplayIsActive: false
            )
        )
        XCTAssertEqual(
            RevivalGameplayView.heldInput(for: [15]).vertical,
            1,
            "R remains upward thrust; physical V owns rear view"
        )

        var physicalInput = PlayerInputState(rampDuration: 0)
        physicalInput.setRearView(pressed: true, held: true)
        let pressed = physicalInput.snapshot(frameDuration: 0.1)
        XCTAssertTrue(pressed.rearViewPressed)
        XCTAssertTrue(pressed.rearViewHeld)
        let held = physicalInput.snapshot(frameDuration: 0.1)
        XCTAssertFalse(held.rearViewPressed)
        XCTAssertTrue(held.rearViewHeld)
        var quickPhysicalInput = PlayerInputState(rampDuration: 0)
        quickPhysicalInput.setRearView(pressed: true, held: true)
        quickPhysicalInput.setRearView(pressed: false, held: false)
        XCTAssertTrue(
            quickPhysicalInput.snapshot(frameDuration: 0.1).rearViewPressed,
            "a normal key-up preserves the already-observed down pulse"
        )
        quickPhysicalInput.setRearView(pressed: true, held: true)
        quickPhysicalInput.cancelRearViewInput()
        XCTAssertFalse(
            quickPhysicalInput.snapshot(frameDuration: 0.1).rearViewPressed,
            "capture teardown cancels an unsnapshotted physical pulse"
        )
        physicalInput.setGameplayActive(false, simulation: nil, at: 1)
        XCTAssertFalse(
            physicalInput.snapshot(frameDuration: 0.1).rearViewHeld,
            "focus and gameplay teardown clear physical hold state"
        )

        let quick = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        let entered = quick.update(
            at: 0.1,
            input: .init(rearViewPressed: true, rearViewHeld: true)
        )
        let committedForward = defaultPlayerView(in: quick.level)
        XCTAssertTrue(entered.rearViewIsActive)
        XCTAssertEqual(
            entered.playerView.camera.position,
            committedForward.camera.position
        )
        XCTAssertEqual(entered.playerView.camera.up, committedForward.camera.up)
        XCTAssertEqual(
            entered.playerView.camera.target.x - entered.playerView.camera.position.x,
            -(committedForward.camera.target.x
                - committedForward.camera.position.x),
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            entered.playerView.camera.target.y - entered.playerView.camera.position.y,
            -(committedForward.camera.target.y
                - committedForward.camera.position.y),
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            entered.playerView.camera.target.z - entered.playerView.camera.position.z,
            -(committedForward.camera.target.z
                - committedForward.camera.position.z),
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            entered.playerView.camera.projection,
            committedForward.camera.projection
        )
        XCTAssertFalse(
            RevivalGameplayView.showsOrdinaryGameplayOverlays(
                rearViewIsActive: entered.rearViewIsActive
            )
        )
        let toggled = quick.update(at: 0.2, input: .zero)
        XCTAssertTrue(
            toggled.rearViewIsActive,
            "release before the hold branch runs leaves the view toggled"
        )
        let exited = quick.update(
            at: 0.3,
            input: .init(rearViewPressed: true, rearViewHeld: true)
        )
        XCTAssertFalse(exited.rearViewIsActive)
        XCTAssertTrue(
            RevivalGameplayView.showsOrdinaryGameplayOverlays(
                rearViewIsActive: exited.rearViewIsActive
            )
        )

        let masked = PlayerSimulation(
            level: makeTrainingScript003Level(),
            presentationReadyTimestamp: 0
        )
        let maskedRear = masked.update(
            at: 0.1,
            input: .init(
                sideways: 1,
                rearViewPressed: true,
                rearViewHeld: true
            )
        )
        XCTAssertEqual(maskedRear.enabledPlayerControls, [.forward])
        XCTAssertTrue(
            maskedRear.rearViewIsActive,
            "the Training movement/weapon mask does not suppress rear view"
        )

        let moving = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        let movedRear = moving.update(
            at: 0.1,
            input: .init(
                sideways: 1,
                pitch: 0.75,
                rearViewPressed: true,
                rearViewHeld: true
            )
        )
        let committedPlayer = try XCTUnwrap(
            moving.level.objects.first {
                $0.handle == movedRear.playerView.objectHandle
            }
        )
        XCTAssertEqual(movedRear.playerView.camera.position, committedPlayer.position)
        XCTAssertEqual(movedRear.playerView.camera.up, committedPlayer.orientation.up)
        XCTAssertEqual(
            movedRear.playerView.camera.target.x
                - movedRear.playerView.camera.position.x,
            -committedPlayer.orientation.forward.x,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            movedRear.playerView.camera.target.y
                - movedRear.playerView.camera.position.y,
            -committedPlayer.orientation.forward.y,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            movedRear.playerView.camera.target.z
                - movedRear.playerView.camera.position.z,
            -committedPlayer.orientation.forward.z,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            committedPlayer.location,
            .room(movedRear.playerView.roomSourceIndex)
        )

        let cameraMonitorLevel = makeTrainingCameraMonitorLevel()
        let cameraMonitor = PlayerSimulation(
            level: cameraMonitorLevel,
            presentationReadyTimestamp: 0
        )
        _ = cameraMonitor.update(at: 0.1, input: .init(usesInventory: true))
        let rearWithMonitor = cameraMonitor.update(
            at: 0.2,
            input: .init(
                usesInventory: true,
                rearViewPressed: true,
                rearViewHeld: true
            )
        )
        XCTAssertTrue(rearWithMonitor.rearViewIsActive)
        XCTAssertNotNil(
            rearWithMonitor.trainingCameraMonitor,
            "the independent auxiliary camera stays live and unflipped"
        )

        let yellowLevel = try makePlayerYellowFlareLevel()
        let yellowRear = PlayerSimulation(
            level: yellowLevel,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x2468_ace0
        )
        let yellowForward = PlayerSimulation(
            level: yellowLevel,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x2468_ace0
        )
        let yellowRearFrame = yellowRear.update(
            at: 0.1,
            input: .init(
                sideways: 1,
                firesPlayerFlare: true,
                rearViewPressed: true,
                rearViewHeld: true
            )
        )
        let yellowForwardFrame = yellowForward.update(
            at: 0.1,
            input: .init(sideways: 1, firesPlayerFlare: true)
        )
        XCTAssertTrue(yellowRearFrame.rearViewIsActive)
        XCTAssertEqual(
            yellowRearFrame.trainingGuidebotYellowFlares,
            yellowForwardFrame.trainingGuidebotYellowFlares,
            "rear processing follows flare creation and changes no carrier"
        )
        let yellowRearObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(yellowRear.continuation)
            ) as? [String: Any]
        )
        let yellowForwardObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(yellowForward.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            yellowRearObject["authoritativeRandomState"] as? NSNumber,
            yellowForwardObject["authoritativeRandomState"] as? NSNumber
        )

        let persistenceLevel = makeTrainingRASBot1DeathLevel()
        let heldSimulation = PlayerSimulation(
            level: persistenceLevel,
            presentationReadyTimestamp: 0
        )
        _ = heldSimulation.update(
            at: 0.1,
            input: .init(rearViewPressed: true, rearViewHeld: true)
        )
        var exactObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(heldSimulation.continuation)
            ) as? [String: Any]
        )
        var exactState = try XCTUnwrap(
            exactObject["playerRearViewState"] as? [String: Any]
        )
        let savedGameTime = try XCTUnwrap(
            (exactObject["gameTime"] as? NSNumber)?.floatValue
        )
        exactState["entryGameTime"] = savedGameTime - 1.0 / 16.0
        exactObject["playerRearViewState"] = exactState
        let exactContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: exactObject)
        )
        let exact = try PlayerSimulation(
            level: persistenceLevel,
            continuation: exactContinuation,
            resumedAtTimestamp: 10
        )
        XCTAssertTrue(
            exact.update(
                at: 10.01,
                input: .init(rearViewHeld: true)
            ).rearViewIsActive,
            "exactly 1/16 does not arm leave mode"
        )
        var exactAfterObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(exact.continuation)
            ) as? [String: Any]
        )
        var exactAfterState = try XCTUnwrap(
            exactAfterObject["playerRearViewState"] as? [String: Any]
        )
        XCTAssertEqual(exactAfterState["leaveMode"] as? Bool, false)
        let restoredUnarmed = try PlayerSimulation(
            level: persistenceLevel,
            continuation: exactContinuation,
            resumedAtTimestamp: 15
        )
        XCTAssertTrue(
            restoredUnarmed.update(at: 15.1, input: .zero)
                .rearViewIsActive,
            "an unarmed restored toggle remains without a physical hold"
        )
        _ = exact.update(at: 10.02, input: .init(rearViewHeld: true))
        exactAfterObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(exact.continuation)
            ) as? [String: Any]
        )
        exactAfterState = try XCTUnwrap(
            exactAfterObject["playerRearViewState"] as? [String: Any]
        )
        XCTAssertEqual(exactAfterState["leaveMode"] as? Bool, true)
        XCTAssertFalse(
            exact.update(at: 10.03, input: .zero).rearViewIsActive,
            "release after strict-greater hold leaves rear view"
        )

        var restoredArmedObject = exactObject
        var restoredArmedState = exactState
        restoredArmedState["leaveMode"] = true
        restoredArmedObject["playerRearViewState"] = restoredArmedState
        let restoredArmed = try PlayerSimulation(
            level: persistenceLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: restoredArmedObject)
            ),
            resumedAtTimestamp: 20
        )
        XCTAssertFalse(
            restoredArmed.update(at: 20.1, input: .zero).rearViewIsActive
        )

        var oldObject = exactObject
        oldObject.removeValue(forKey: "playerRearViewState")
        let old = try PlayerSimulation(
            level: persistenceLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: oldObject)
            ),
            resumedAtTimestamp: 30
        )
        XCTAssertFalse(old.update(at: 30.1, input: .zero).rearViewIsActive)

        var invalidObject = exactObject
        var invalidState = exactState
        invalidState["entryGameTime"] = savedGameTime + 0.001
        invalidObject["playerRearViewState"] = invalidState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: persistenceLevel,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(withJSONObject: invalidObject)
                ),
                resumedAtTimestamp: 40
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var wrongSchemaObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(quick.continuation)
            ) as? [String: Any]
        )
        wrongSchemaObject["playerRearViewState"] = exactState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: quick.level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: wrongSchemaObject
                    )
                ),
                resumedAtTimestamp: 50
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    func testF4RequestsGuidebotDeploymentOnlyDuringGameplay() {
        XCTAssertTrue(
            RevivalGameplayView.requestsGuidebotDeployment(
                keyCode: 118,
                gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsGuidebotDeployment(
                keyCode: 118,
                gameplayIsActive: false
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsGuidebotDeployment(
                keyCode: 117,
                gameplayIsActive: true
            )
        )
        var playerInput = PlayerInputState(rampDuration: 0)
        playerInput.requestGuidebotDeployment()
        XCTAssertTrue(
            playerInput.snapshot(frameDuration: 0.1)
                .deploysTrainingGuidebot
        )
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1)
                .deploysTrainingGuidebot
        )
    }

    @MainActor
    func testScript060UsesOneNativeGuidebotGoalMenuAndPausedOneShotCommand() {
        let menu = RevivalGameplayView.trainingGuidebotGoalMenu(
            target: nil,
            action: nil
        )
        XCTAssertEqual(menu.title, "GB Command Menu")
        XCTAssertEqual(menu.items.count, 1)
        XCTAssertEqual(menu.items[0].title, "1. Get to Camera Monitor")
        XCTAssertEqual(menu.items[0].keyEquivalent, "1")
        XCTAssertTrue(menu.items[0].keyEquivalentModifierMask.isEmpty)
        XCTAssertEqual(menu.items[0].tag, 3)
        XCTAssertTrue(
            RevivalGameplayView.cancelsTrainingGuidebotGoalMenu(
                keyCode: 118
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.cancelsTrainingGuidebotGoalMenu(
                keyCode: 53
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.cancelsTrainingGuidebotGoalMenu(
                keyCode: 18
            )
        )

        var input = PlayerInputState(rampDuration: 0)
        input.setHeld(.init(forward: 1))
        input.setGameplayActive(false, simulation: nil, at: 1)
        input.requestTrainingGuidebotActiveGoal()
        XCTAssertEqual(input.snapshot(frameDuration: 0.1), .zero)
        input.setGameplayActive(true, simulation: nil, at: 2)
        input.requestTrainingGuidebotActiveGoal()
        XCTAssertTrue(
            input.snapshot(frameDuration: 0.1)
                .requestsTrainingGuidebotActiveGoal
        )
        XCTAssertFalse(
            input.snapshot(frameDuration: 0.1)
                .requestsTrainingGuidebotActiveGoal
        )
    }

    @MainActor
    func testScript059UsesOneNativeGuidebotReturnMenuAndPausedContextualCommand()
    {
        let menu = RevivalGameplayView.trainingGuidebotReturnToShipMenu(
            target: nil,
            action: nil
        )
        XCTAssertEqual(menu.title, "GB Command Menu")
        XCTAssertEqual(menu.items.count, 1)
        XCTAssertEqual(menu.items[0].title, "1. Return to ship")
        XCTAssertEqual(menu.items[0].keyEquivalent, "1")
        XCTAssertTrue(menu.items[0].keyEquivalentModifierMask.isEmpty)
        XCTAssertEqual(menu.items[0].tag, 43)
        XCTAssertTrue(
            RevivalGameplayView.cancelsTrainingGuidebotReturnToShipMenu(
                keyCode: 118
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.cancelsTrainingGuidebotReturnToShipMenu(
                keyCode: 53
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.cancelsTrainingGuidebotReturnToShipMenu(
                keyCode: 18
            )
        )

        var input = PlayerInputState(rampDuration: 0)
        input.setHeld(.init(forward: 1))
        input.setGameplayActive(false, simulation: nil, at: 1)
        input.requestGuidebotDeployment()
        XCTAssertEqual(input.snapshot(frameDuration: 0.1), .zero)
        input.setGameplayActive(true, simulation: nil, at: 2)
        input.requestGuidebotDeployment()
        XCTAssertTrue(
            input.snapshot(frameDuration: 0.1)
                .deploysTrainingGuidebot
        )
        XCTAssertFalse(
            input.snapshot(frameDuration: 0.1)
                .deploysTrainingGuidebot
        )
    }

    func testBackslashRequestsOneInventoryUseOnlyDuringGameplay() {
        XCTAssertTrue(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 42,
                isRepeat: false,
                gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 42,
                isRepeat: true,
                gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 42,
                isRepeat: false,
                gameplayIsActive: false
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 43,
                isRepeat: false,
                gameplayIsActive: true
            )
        )
    }

    @MainActor
    func testHRequestsOneFastPlayerHeadlightToggleAndRestoresSilently()
        throws
    {
        XCTAssertTrue(
            RevivalGameplayView.requestsHeadlightToggle(
                keyCode: 4,
                isRepeat: false,
                gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsHeadlightToggle(
                keyCode: 4,
                isRepeat: true,
                gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsHeadlightToggle(
                keyCode: 4,
                isRepeat: false,
                gameplayIsActive: false
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsHeadlightToggle(
                keyCode: 5,
                isRepeat: false,
                gameplayIsActive: true
            )
        )

        var playerInput = PlayerInputState(rampDuration: 0)
        playerInput.requestHeadlightToggle()
        let firstInput = playerInput.snapshot(frameDuration: 0.1)
        XCTAssertTrue(firstInput.togglesHeadlight)
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1).togglesHeadlight
        )

        let level = makeFastPlayerHeadlightLevel()
        let initialPlayerPosition = defaultPlayerView(in: level)
            .camera.position
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        let initialContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        let onFrame = simulation.update(
            at: 0.1,
            input: .init(sideways: 1, togglesHeadlight: true)
        )
        XCTAssertEqual(
            onFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Headlight turned on."],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: "Headlight1",
                    soundEventVolume: 1
                ),
            ]
        )
        var presentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            onFrame.trainingOpeningFeedback,
            attemptVoice: { _ in
                XCTFail("Headlight feedback has no voice")
            },
            attemptSound: { name, volume in
                presentationOrder.append("sound:\(name):\(volume ?? -1)")
                throw TrainingOpeningPresentationError.soundPlaybackFailed(
                    name
                )
            },
            presentHUDMessages: {
                presentationOrder.append(contentsOf: $0.map { "hud:\($0)" })
            }
        )
        XCTAssertEqual(
            presentationOrder,
            [
                "sound:Headlight1:1.0",
                "hud:Headlight turned on.",
            ],
            "missing optional audio stays silent without suppressing HUD"
        )
        let onLight = try XCTUnwrap(onFrame.playerFastHeadlight)
        XCTAssertEqual(onLight.roomSourceIndex, 1)
        XCTAssertEqual(onLight.lightDistance, 20)
        XCTAssertEqual(
            onLight.position.x,
            onFrame.playerView.camera.position.x,
            accuracy: 0.000_1
        )
        XCTAssertNotEqual(
            onFrame.playerView.camera.position.x,
            initialPlayerPosition.x,
            "the fast trace must originate after non-collinear movement"
        )
        XCTAssertEqual(
            onLight.position.y,
            onFrame.playerView.camera.position.y,
            accuracy: 0.000_1
        )
        XCTAssertGreaterThan(
            onLight.position.z,
            onFrame.playerView.camera.position.z
        )
        XCTAssertLessThan(
            onLight.position.z
                - onFrame.playerView.camera.position.z,
            150,
            "the nearer visible ForwardGoal object wins over the wall"
        )

        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            continuationObject["playerHeadlightIsOn"] as? Bool,
            true
        )
        XCTAssertEqual(
            continuationObject["authoritativeRandomState"] as? NSNumber,
            initialContinuationObject["authoritativeRandomState"] as? NSNumber,
            "fast headlight consumes no authoritative RNG"
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: continuationObject
                )
            ),
            resumedAtTimestamp: 0.1
        ).update(at: 0.2, input: .zero)
        XCTAssertNotNil(restored.playerFastHeadlight)
        XCTAssertTrue(restored.trainingOpeningFeedback.isEmpty)

        continuationObject.removeValue(forKey: "playerHeadlightIsOn")
        let oldRestore = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: continuationObject
                )
            ),
            resumedAtTimestamp: 0.1
        ).update(at: 0.2, input: .zero)
        XCTAssertNil(oldRestore.playerFastHeadlight)
        XCTAssertTrue(oldRestore.trainingOpeningFeedback.isEmpty)

        let schemaSevenLevel = makeTrainingRASBot1DeathLevel()
        let schemaSevenInitial = PlayerSimulation(
            level: schemaSevenLevel,
            presentationReadyTimestamp: 0
        )
        var schemaSevenObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    schemaSevenInitial.continuation
                )
            ) as? [String: Any]
        )
        XCTAssertEqual(schemaSevenObject["schemaVersion"] as? Int, 7)
        let schemaSevenRandomState =
            schemaSevenObject["authoritativeRandomState"] as? NSNumber
        schemaSevenObject["playerHeadlightIsOn"] = true
        let schemaSevenOn = try PlayerSimulation(
            level: schemaSevenLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: schemaSevenObject
                )
            ),
            resumedAtTimestamp: 0
        )
        let schemaSevenOnFrame = schemaSevenOn.update(
            at: 0.1,
            input: .zero
        )
        XCTAssertNotNil(schemaSevenOnFrame.playerFastHeadlight)
        XCTAssertFalse(schemaSevenOnFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Headlight1"
                || $0.hudMessages.contains {
                    $0.hasPrefix("Headlight turned ")
                }
        })
        let schemaSevenOnObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(schemaSevenOn.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            schemaSevenOnObject["authoritativeRandomState"] as? NSNumber,
            schemaSevenRandomState
        )
        schemaSevenObject.removeValue(forKey: "playerHeadlightIsOn")
        let schemaSevenOld = try PlayerSimulation(
            level: schemaSevenLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: schemaSevenObject
                )
            ),
            resumedAtTimestamp: 0
        )
        let schemaSevenOldFrame = schemaSevenOld.update(
            at: 0.1,
            input: .zero
        )
        XCTAssertNil(schemaSevenOldFrame.playerFastHeadlight)
        XCTAssertFalse(schemaSevenOldFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Headlight1"
                || $0.hudMessages.contains {
                    $0.hasPrefix("Headlight turned ")
                }
        })
        let schemaSevenOldObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(schemaSevenOld.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            schemaSevenOldObject["authoritativeRandomState"] as? NSNumber,
            schemaSevenRandomState
        )

        let offFrame = simulation.update(
            at: 0.2,
            input: .init(togglesHeadlight: true)
        )
        XCTAssertNil(offFrame.playerFastHeadlight)
        XCTAssertEqual(
            offFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Headlight turned off."],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: "Headlight1",
                    soundEventVolume: 1
                ),
            ]
        )

        let clearLevel = makeFastPlayerHeadlightLevel(
            includesVisibleObject: false,
            halfExtent: 400
        )
        let clearFrame = PlayerSimulation(
            level: clearLevel,
            presentationReadyTimestamp: 0
        ).update(at: 0.1, input: .init(togglesHeadlight: true))
        XCTAssertEqual(
            try XCTUnwrap(clearFrame.playerFastHeadlight).position.z
                - clearFrame.playerView.camera.position.z,
            299.75,
            accuracy: 0.001,
            "a clear 300-unit trace lights its endpoint backed by forward/4"
        )

        let wallLevel = makeFastPlayerHeadlightLevel(
            includesVisibleObject: false,
            halfExtent: 100
        )
        let wallFrame = PlayerSimulation(
            level: wallLevel,
            presentationReadyTimestamp: 0
        ).update(at: 0.1, input: .init(togglesHeadlight: true))
        XCTAssertEqual(
            try XCTUnwrap(wallFrame.playerFastHeadlight).position.z
                - wallFrame.playerView.camera.position.z,
            99.75,
            accuracy: 0.001,
            "the nearer wall wins and the result is backed by forward/4"
        )
    }

    func testCameraMonitorPopupBorderAndReachedSoundUseAppKitOwner() throws {
        let frame = RevivalGameplayView.cameraMonitorFrame(
            drawableWidth: 1_200,
            drawableHeight: 900
        )
        XCTAssertEqual(frame.origin.x, 59.375)
        XCTAssertEqual(frame.origin.y, 9.375)
        XCTAssertEqual(frame.width, 281.25)
        XCTAssertEqual(frame.height, 281.25)

        let clip = try XCTUnwrap(
            makeTrainingCameraMonitorLevel().soundClips.first
        )
        let wave = RevivalGameplayView.waveData(for: clip)
        XCTAssertEqual(String(data: wave.prefix(4), encoding: .utf8), "RIFF")
        XCTAssertEqual(wave.count, clip.pcm16LittleEndian.count + 44)
    }

    func testInventoryUseRequestIsOneShotAndClearsWhileGameplayIsInactive() {
        var input = PlayerInputState(rampDuration: 0)
        input.requestInventoryUse()
        XCTAssertTrue(input.snapshot(frameDuration: 0.1).usesInventory)
        XCTAssertFalse(input.snapshot(frameDuration: 0.1).usesInventory)

        input.setGameplayActive(false, simulation: nil, at: 1)
        input.requestInventoryUse()
        XCTAssertFalse(input.snapshot(frameDuration: 0.1).usesInventory)
    }
}
