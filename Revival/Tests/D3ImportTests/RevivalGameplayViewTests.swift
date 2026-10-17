import XCTest

// The AppKit gameplay view (RevivalGameplayView.swift): key and controller
// input, the solo pause and help, the buddy menu, quicksave keys, the
// feedback sequence, level end, and the pilot selection.

final class RevivalGameplayViewTests: XCTestCase {
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
                leftX: 0, leftY: 0, rightX: 0, rightY: 0, leftTrigger: 0,
                rightTrigger: 0, leftShoulder: 0, rightShoulder: 0,
                afterburner: 0.6
            ),
            .init(afterburner: 0.6)
        )
    }

    func testConcreteAppKitOwnerMapsSixAxesAndSourceControllerDeadzone() {
        XCTAssertEqual(
            RevivalGameplayView.heldInput(for: [13, 0, 15, 126, 124, 12]),
            .init(
                forward: 1, sideways: -1, vertical: 1, pitch: -1, yaw: 1,
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
            leftX: 0.6, leftY: 0.7, rightX: 0.4, rightY: 0.6, leftTrigger: 0.2,
            rightTrigger: 0.6, leftShoulder: 1, rightShoulder: 0
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
                keyCode: 9, isRepeat: false, gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsRearView(
                keyCode: 9, isRepeat: true, gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsRearView(
                keyCode: 9, isRepeat: false, gameplayIsActive: false
            )
        )
        XCTAssertEqual(
            RevivalGameplayView.heldInput(for: [15]).vertical, 1,
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

        let quick = GameSession(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0, authoritativeRandomSeed: 0x1234_5678
        )
        let entered = quick.update(
            at: 0.1, input: .init(rearViewPressed: true, rearViewHeld: true)
        )
        let committedForward = defaultPlayerView(in: quick.runtimeLevel)
        XCTAssertTrue(entered.rearViewIsActive)
        XCTAssertEqual(
            entered.playerView.camera.position, committedForward.camera.position
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
            at: 0.3, input: .init(rearViewPressed: true, rearViewHeld: true)
        )
        XCTAssertFalse(exited.rearViewIsActive)
        XCTAssertTrue(
            RevivalGameplayView.showsOrdinaryGameplayOverlays(
                rearViewIsActive: exited.rearViewIsActive
            )
        )

        let masked = GameSession(
            level: makeTrainingScript003Level(), presentationReadyTimestamp: 0
        )
        let maskedRear = masked.update(
            at: 0.1,
            input: .init(sideways: 1, rearViewPressed: true, rearViewHeld: true)
        )
        XCTAssertEqual(maskedRear.enabledPlayerControls, [.forward])
        XCTAssertTrue(
            maskedRear.rearViewIsActive,
            "the Training movement/weapon mask does not suppress rear view"
        )

        let moving = GameSession(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        let movedRear = moving.update(
            at: 0.1,
            input: .init(
                sideways: 1, pitch: 0.75, rearViewPressed: true,
                rearViewHeld: true
            )
        )
        let committedPlayer = try XCTUnwrap(
            moving.runtimeLevel.objects.first {
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

        let cameraMonitorLevel = scriptingTrainingCameraMonitorLevel(
            makeTrainingCameraMonitorLevel(), guideBot: false
        )
        let cameraMonitor = GameSession(
            level: cameraMonitorLevel, presentationReadyTimestamp: 0
        )
        _ = cameraMonitor.touch("CameraMonitor", at: 0.1)
        let rearWithMonitor = cameraMonitor.update(
            at: 0.2,
            input: .init(
                usesInventory: true, rearViewPressed: true, rearViewHeld: true
            )
        )
        XCTAssertTrue(rearWithMonitor.rearViewIsActive)
        XCTAssertNotNil(
            rearWithMonitor.popupView,
            "the independent auxiliary camera stays live and unflipped"
        )

        let yellowLevel = try makePlayerYellowFlareLevel()
        let yellowRear = GameSession(
            level: yellowLevel, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x2468_ace0
        )
        let yellowForward = GameSession(
            level: yellowLevel, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x2468_ace0
        )
        let yellowRearFrame = yellowRear.update(
            at: 0.1,
            input: .init(
                sideways: 1, firesPlayerFlare: true, rearViewPressed: true,
                rearViewHeld: true
            )
        )
        let yellowForwardFrame = yellowForward.update(
            at: 0.1, input: .init(sideways: 1, firesPlayerFlare: true)
        )
        XCTAssertTrue(yellowRearFrame.rearViewIsActive)
        _ = yellowForwardFrame
        let rearFlares = yellowRear.world.objects.filter { $0.type == .weapon }
        XCTAssertFalse(rearFlares.isEmpty)
        XCTAssertEqual(
            rearFlares,
            yellowForward.world.objects.filter { $0.type == .weapon },
            "rear processing follows flare creation and changes no flare"
        )
        let yellowRearObject = try XCTUnwrap(testWorldObject(yellowRear.world))
        let yellowForwardObject = try XCTUnwrap(
            testWorldObject(yellowForward.world)
        )
        XCTAssertEqual(
            yellowRearObject["authoritativeRandomState"] as? NSNumber,
            yellowForwardObject["authoritativeRandomState"] as? NSNumber
        )

        let persistenceLevel = makeTrainingRASBot1DeathLevel()
        let heldSimulation = GameSession(
            level: persistenceLevel, presentationReadyTimestamp: 0
        )
        _ = heldSimulation.update(
            at: 0.1, input: .init(rearViewPressed: true, rearViewHeld: true)
        )
        var exactObject = try XCTUnwrap(testWorldObject(heldSimulation.world))
        var exactState = try XCTUnwrap(
            exactObject["playerRearViewState"] as? [String: Any]
        )
        let savedGameTime = try XCTUnwrap(
            (exactObject["gameTime"] as? NSNumber)?.floatValue
        )
        exactState["entryGameTime"] = savedGameTime - 1.0 / 16.0
        exactObject["playerRearViewState"] = exactState
        let exactContinuation = try decodeTestWorld(exactObject)
        let exact = try GameSession(
            level: persistenceLevel,
            world: exactContinuation.rebased(onto: persistenceLevel),
            resumedAtTimestamp: 10
        )
        XCTAssertTrue(
            exact.update(
                at: 10.01, input: .init(rearViewHeld: true)
            ).rearViewIsActive,
            "exactly 1/16 does not arm leave mode"
        )
        var exactAfterObject = try XCTUnwrap(testWorldObject(exact.world))
        var exactAfterState = try XCTUnwrap(
            exactAfterObject["playerRearViewState"] as? [String: Any]
        )
        XCTAssertEqual(exactAfterState["leaveMode"] as? Bool, false)
        let restoredUnarmed = try GameSession(
            level: persistenceLevel,
            world: exactContinuation.rebased(onto: persistenceLevel),
            resumedAtTimestamp: 15
        )
        XCTAssertTrue(
            restoredUnarmed.update(at: 15.1, input: .zero)
                .rearViewIsActive,
            "an unarmed restored toggle remains without a physical hold"
        )
        _ = exact.update(at: 10.02, input: .init(rearViewHeld: true))
        exactAfterObject = try XCTUnwrap(testWorldObject(exact.world))
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
        let restoredArmed = try GameSession(
            level: persistenceLevel,
            world: (decodeTestWorld(restoredArmedObject)).rebased(onto: persistenceLevel),
            resumedAtTimestamp: 20
        )
        XCTAssertFalse(
            restoredArmed.update(at: 20.1, input: .zero).rearViewIsActive
        )

        var oldObject = exactObject
        oldObject.removeValue(forKey: "playerRearViewState")
        let old = try GameSession(
            level: persistenceLevel,
            world: (decodeTestWorld(oldObject)).rebased(onto: persistenceLevel),
            resumedAtTimestamp: 30
        )
        XCTAssertFalse(old.update(at: 30.1, input: .zero).rearViewIsActive)
    }

    /// F4 (GameLoop.cpp:1493) is a one-shot buddy menu request during
    /// gameplay only; a repeat does not ask again.
    func testF4RequestsTheBuddyMenuOnlyDuringGameplay() {
        XCTAssertTrue(RevivalGameplayView.requestsBuddyMenu(
            keyCode: 118, isRepeat: false, gameplayIsActive: true
        ))
        XCTAssertFalse(RevivalGameplayView.requestsBuddyMenu(
            keyCode: 118, isRepeat: false, gameplayIsActive: false
        ))
        XCTAssertFalse(RevivalGameplayView.requestsBuddyMenu(
            keyCode: 118, isRepeat: true, gameplayIsActive: true
        ))
        XCTAssertFalse(RevivalGameplayView.requestsBuddyMenu(
            keyCode: 117, isRepeat: false, gameplayIsActive: true
        ))
        var input = PlayerInputState(rampDuration: 0)
        input.requestBuddyMenu()
        XCTAssertTrue(input.snapshot(frameDuration: 0.1).opensBuddyMenu)
        XCTAssertFalse(input.snapshot(frameDuration: 0.1).opensBuddyMenu)
        input.setGameplayActive(false, simulation: nil, at: 1)
        input.requestBuddyMenu()
        XCTAssertEqual(input.snapshot(frameDuration: 0.1), .zero)
        input.setGameplayActive(true, simulation: nil, at: 2)
        XCTAssertFalse(input.snapshot(frameDuration: 0.1).opensBuddyMenu)
    }

    /// BuddyDisplay's window as a native menu (buddymenu.cpp:95-172): the
    /// title, then "1." to "9." and "A." items with the '1'-'9' and 'a'
    /// accelerators and no modifier; F4 and Escape close it.
    @MainActor
    func testBuddyMenuListsTheGuideBotCommandsWithTheirKeys() {
        let commands = (0..<11).map {
            GuideBotMenu.Command(
                id: Int32($0), text: "Command \($0)",
                dialogText: $0 == 2 ? "Enter GuideBot name:" : nil
            )
        }

        let buddyMenu = BuddyMenu(title: "GB Command Menu", commands: commands)
        let menu = RevivalGameplayView.buddyMenu(
            buddyMenu, target: nil, action: nil
        )
        XCTAssertEqual(menu.items.count, 13)
        XCTAssertEqual(menu.items[0].title, "GB Command Menu")
        XCTAssertFalse(menu.items[0].isEnabled)
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        let items = Array(menu.items.dropFirst(2))
        XCTAssertEqual(items.map(\.tag), Array(0..<11))
        XCTAssertEqual(items[0].title, "1. Command 0")
        XCTAssertEqual(items[8].title, "9. Command 8")
        XCTAssertEqual(items[9].title, "A. Command 9")
        XCTAssertEqual(items[10].title, "B. Command 10")
        XCTAssertEqual(
            items.map(\.keyEquivalent),
            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b"]
        )
        XCTAssertTrue(items.allSatisfy {
            $0.keyEquivalentModifierMask.isEmpty
        })
        XCTAssertTrue(RevivalGameplayView.closesBuddyMenu(keyCode: 118))
        XCTAssertTrue(RevivalGameplayView.closesBuddyMenu(keyCode: 53))
        XCTAssertFalse(RevivalGameplayView.closesBuddyMenu(keyCode: 18))
        // Items past 'z' and the last N_WINDOW_ACCELS entry get no key.
        let long = BuddyMenu(
            title: "",
            commands: (0..<48).map {
                .init(id: 0, text: "\($0)", dialogText: nil)
            }
        )
        XCTAssertEqual(long.acceleratorCharacter(34), "z")
        XCTAssertNil(long.acceleratorCharacter(35))
        XCTAssertNil(long.acceleratorCharacter(47))
    }

    func testBackslashRequestsOneInventoryUseOnlyDuringGameplay() {
        XCTAssertTrue(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 42, isRepeat: false, gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 42, isRepeat: true, gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 42, isRepeat: false, gameplayIsActive: false
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 43, isRepeat: false, gameplayIsActive: true
            )
        )
    }

    @MainActor
    func testHRequestsOneFastPlayerHeadlightToggleAndRestoresSilently()
        throws
    {
        XCTAssertTrue(
            RevivalGameplayView.requestsHeadlightToggle(
                keyCode: 4, isRepeat: false, gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsHeadlightToggle(
                keyCode: 4, isRepeat: true, gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsHeadlightToggle(
                keyCode: 4, isRepeat: false, gameplayIsActive: false
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsHeadlightToggle(
                keyCode: 5, isRepeat: false, gameplayIsActive: true
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
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0
        )
        let initialContinuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        let onFrame = simulation.update(
            at: 0.1, input: .init(sideways: 1, togglesHeadlight: true)
        )
        XCTAssertEqual(
            onFrame.presentationFeedback,
            [
                .init(
                    hudMessages: ["Headlight turned on."], voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: "Headlight1", soundEventVolume: 1
                ),
            ]
        )
        var presentationOrder: [String] = []
        RevivalGameplayView.presentFeedbackSequence(
            onFrame.presentationFeedback,
            attemptVoice: { _ in
                XCTFail("Headlight feedback has no voice")
            },
            attemptSound: { name, volume in
                presentationOrder.append("sound:\(name):\(volume ?? -1)")
                throw GameplayPresentationError.soundPlaybackFailed(name)
            },
            presentHUDMessages: {
                presentationOrder.append(contentsOf: $0.map { "hud:\($0)" })
            }
        )
        XCTAssertEqual(
            presentationOrder,
            ["sound:Headlight1:1.0", "hud:Headlight turned on."],
            "missing optional audio stays silent without suppressing HUD"
        )
        let onLight = try XCTUnwrap(onFrame.playerFastHeadlight)
        XCTAssertEqual(onLight.roomSourceIndex, 1)
        XCTAssertEqual(onLight.lightDistance, 20)
        XCTAssertEqual(
            onLight.position.x, onFrame.playerView.camera.position.x,
            accuracy: 0.000_1
        )
        XCTAssertNotEqual(
            onFrame.playerView.camera.position.x, initialPlayerPosition.x,
            "the fast trace must originate after non-collinear movement"
        )
        XCTAssertEqual(
            onLight.position.y, onFrame.playerView.camera.position.y,
            accuracy: 0.000_1
        )
        XCTAssertGreaterThan(
            onLight.position.z, onFrame.playerView.camera.position.z
        )
        XCTAssertLessThan(
            onLight.position.z
                - onFrame.playerView.camera.position.z,
            150,
            "the nearer visible ForwardGoal object wins over the wall"
        )

        var continuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        XCTAssertEqual(continuationObject["playerHeadlightIsOn"] as? Bool, true)
        XCTAssertEqual(
            continuationObject["authoritativeRandomState"] as? NSNumber,
            initialContinuationObject["authoritativeRandomState"] as? NSNumber,
            "fast headlight consumes no authoritative RNG"
        )
        let restored = try GameSession(
            level: level,
            world: (decodeTestWorld(continuationObject)).rebased(onto: level),
            resumedAtTimestamp: 0.1
        ).update(at: 0.2, input: .zero)
        XCTAssertNotNil(restored.playerFastHeadlight)
        XCTAssertTrue(restored.presentationFeedback.isEmpty)

        continuationObject["playerHeadlightIsOn"] = false
        let oldRestore = try GameSession(
            level: level,
            world: (decodeTestWorld(continuationObject)).rebased(onto: level),
            resumedAtTimestamp: 0.1
        ).update(at: 0.2, input: .zero)
        XCTAssertNil(oldRestore.playerFastHeadlight)
        XCTAssertTrue(oldRestore.presentationFeedback.isEmpty)

        let schemaSevenLevel = makeTrainingRASBot1DeathLevel()
        let schemaSevenInitial = GameSession(
            level: schemaSevenLevel, presentationReadyTimestamp: 0
        )
        var schemaSevenObject = try XCTUnwrap(
            testWorldObject(schemaSevenInitial.world)
        )
        let schemaSevenRandomState =
            schemaSevenObject["authoritativeRandomState"] as? NSNumber
        schemaSevenObject["playerHeadlightIsOn"] = true
        let schemaSevenOn = try GameSession(
            level: schemaSevenLevel,
            world: (decodeTestWorld(schemaSevenObject)).rebased(onto: schemaSevenLevel),
            resumedAtTimestamp: 0
        )
        let schemaSevenOnFrame = schemaSevenOn.update(at: 0.1, input: .zero)
        XCTAssertNotNil(schemaSevenOnFrame.playerFastHeadlight)
        XCTAssertFalse(schemaSevenOnFrame.presentationFeedback.contains {
            $0.soundSourceName == "Headlight1"
                || $0.hudMessages.contains {
                    $0.hasPrefix("Headlight turned ")
                }
        })
        let schemaSevenOnObject = try XCTUnwrap(
            testWorldObject(schemaSevenOn.world)
        )
        XCTAssertEqual(
            schemaSevenOnObject["authoritativeRandomState"] as? NSNumber,
            schemaSevenRandomState
        )
        schemaSevenObject["playerHeadlightIsOn"] = false
        let schemaSevenOld = try GameSession(
            level: schemaSevenLevel,
            world: (decodeTestWorld(schemaSevenObject)).rebased(onto: schemaSevenLevel),
            resumedAtTimestamp: 0
        )
        let schemaSevenOldFrame = schemaSevenOld.update(at: 0.1, input: .zero)
        XCTAssertNil(schemaSevenOldFrame.playerFastHeadlight)
        XCTAssertFalse(schemaSevenOldFrame.presentationFeedback.contains {
            $0.soundSourceName == "Headlight1"
                || $0.hudMessages.contains {
                    $0.hasPrefix("Headlight turned ")
                }
        })
        let schemaSevenOldObject = try XCTUnwrap(
            testWorldObject(schemaSevenOld.world)
        )
        XCTAssertEqual(
            schemaSevenOldObject["authoritativeRandomState"] as? NSNumber,
            schemaSevenRandomState
        )

        let offFrame = simulation.update(
            at: 0.2, input: .init(togglesHeadlight: true)
        )
        XCTAssertNil(offFrame.playerFastHeadlight)
        XCTAssertEqual(
            offFrame.presentationFeedback,
            [
                .init(
                    hudMessages: ["Headlight turned off."], voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: "Headlight1", soundEventVolume: 1
                ),
            ]
        )

        let clearLevel = makeFastPlayerHeadlightLevel(
            includesVisibleObject: false, halfExtent: 400
        )
        let clearFrame = GameSession(
            level: clearLevel, presentationReadyTimestamp: 0
        ).update(at: 0.1, input: .init(togglesHeadlight: true))
        XCTAssertEqual(
            try XCTUnwrap(clearFrame.playerFastHeadlight).position.z
                - clearFrame.playerView.camera.position.z,
            299.75,
            accuracy: 0.001,
            "a clear 300-unit trace lights its endpoint backed by forward/4"
        )

        let wallLevel = makeFastPlayerHeadlightLevel(
            includesVisibleObject: false, halfExtent: 100
        )
        let wallFrame = GameSession(
            level: wallLevel, presentationReadyTimestamp: 0
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
            drawableWidth: 1_200, drawableHeight: 900
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

    @MainActor
    func testPhysicalPPresentsBlockingSoloPauseAndClearsHeldInput() throws {
        _ = NSApplication.shared
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var heldInput: [InputSnapshot] = []
        view.heldInputChanged = { heldInput.append($0) }
        view.setGameplayActive(true)

        let heldW = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "w",
            charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 13
        ))
        let physicalP = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0.01,
            windowNumber: 0, context: nil, characters: "p",
            charactersIgnoringModifiers: "p", isARepeat: false, keyCode: 35
        ))
        let repeatedP = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0.02,
            windowNumber: 0, context: nil, characters: "p",
            charactersIgnoringModifiers: "p", isARepeat: true, keyCode: 35
        ))

        view.keyDown(with: heldW)
        XCTAssertEqual(heldInput.last?.forward, 1)

        var inspectedModal = false
        DispatchQueue.main.async {
            guard let modalWindow = NSApplication.shared.modalWindow else {
                XCTFail("physical P did not present the Pause alert")
                return
            }
            inspectedModal = true
            XCTAssertEqual(
                NSApplication.shared.windows.filter { $0 === modalWindow }.count,
                1
            )
            let descendants = viewDescendants(of: modalWindow.contentView)
            let text = descendants.compactMap {
                ($0 as? NSTextField)?.stringValue
            }
            XCTAssertTrue(text.contains("Pause"))
            XCTAssertTrue(text.contains(
                "The game is paused.\nPress P or click OK to resume."
            ))
            let buttons = descendants.compactMap { $0 as? NSButton }
            XCTAssertEqual(buttons.map(\.title), ["OK"])
            XCTAssertEqual(heldInput.last, .zero)
            NSApplication.shared.sendEvent(repeatedP)
            XCTAssertTrue(NSApplication.shared.modalWindow === modalWindow)
            buttons.only?.performClick(nil)
        }
        view.keyDown(with: physicalP)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertTrue(inspectedModal)
        XCTAssertEqual(heldInput.last, .zero)

        var repeatOpenedModal = false
        DispatchQueue.main.async {
            repeatOpenedModal = NSApplication.shared.modalWindow != nil
            if repeatOpenedModal {
                let descendants = viewDescendants(
                    of: NSApplication.shared.modalWindow?.contentView
                )
                descendants.compactMap { $0 as? NSButton }
                    .only?.performClick(nil)
            }
        }
        view.keyDown(with: repeatedP)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertFalse(repeatOpenedModal)
        XCTAssertNil(NSApplication.shared.modalWindow)
    }

    @MainActor
    func testPhysicalF1PresentsCurrentTrainingKeysAndPausesSoloPlay()
        throws
    {
        _ = NSApplication.shared
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var heldInput: [InputSnapshot] = []
        var pauseChanges: [Bool] = []
        view.heldInputChanged = { heldInput.append($0) }
        view.soloPauseChanged = { pauseChanges.append($0) }
        view.setGameplayActive(true)

        let heldW = try makeKeyEvent(keyCode: 13, characters: "w", timestamp: 0)
        let physicalF1 = try makeKeyEvent(keyCode: 122, timestamp: 0.01)
        let repeatedF1 = try makeKeyEvent(
            keyCode: 122, isRepeat: true, timestamp: 0.02
        )
        let closeF1 = try makeKeyEvent(keyCode: 122, timestamp: 0.03)
        let expectedRows = [
            "W/S — Forward/reverse thrust", "A/D — Slide left/right",
            "R/F — Slide up/down", "Arrow keys — Pitch/yaw", "Q/E — Bank",
            "Mouse — Look", "Left-click — Primary fire",
            "Space or right-click — Secondary fire", "Shift — Afterburner",
            "G — Flare", "H — Headlight", "V — Rear view",
            "Backslash — Inventory use", "F4 — GuideBot", "P — Pause",
            "F9 — Quicksave", "Option-F3 — Quickload", "F1 — Close",
        ]

        view.keyDown(with: heldW)
        XCTAssertEqual(heldInput.last?.forward, 1)

        var inspectedModal = false
        DispatchQueue.main.async {
            guard let modalWindow = NSApplication.shared.modalWindow else {
                XCTFail("physical F1 did not present the Keys alert")
                return
            }
            inspectedModal = true
            XCTAssertEqual(
                NSApplication.shared.windows.filter {
                    $0 === modalWindow
                }.count,
                1
            )
            let descendants = viewDescendants(of: modalWindow.contentView)
            let text = descendants.compactMap {
                ($0 as? NSTextField)?.stringValue
            }.filter { !$0.isEmpty }
            XCTAssertEqual(
                Set(text), Set(["Keys", expectedRows.joined(separator: "\n")])
            )
            let buttons = descendants.compactMap { $0 as? NSButton }
            XCTAssertEqual(buttons.map(\.title), ["OK"])
            XCTAssertEqual(heldInput.last, .zero)
            XCTAssertEqual(pauseChanges, [true])

            NSApplication.shared.sendEvent(repeatedF1)
            XCTAssertTrue(NSApplication.shared.modalWindow === modalWindow)
            NSApplication.shared.sendEvent(closeF1)
        }
        view.keyDown(with: physicalF1)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertTrue(inspectedModal)
        XCTAssertEqual(heldInput.last, .zero)
        XCTAssertEqual(pauseChanges, [true, false])
        XCTAssertNil(NSApplication.shared.modalWindow)

        var repeatOpenedModal = false
        DispatchQueue.main.async {
            repeatOpenedModal = NSApplication.shared.modalWindow != nil
            if let modalWindow = NSApplication.shared.modalWindow {
                viewDescendants(of: modalWindow.contentView)
                    .compactMap { $0 as? NSButton }
                    .only?.performClick(nil)
            }
        }
        view.keyDown(with: repeatedF1)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertFalse(repeatOpenedModal)
        XCTAssertEqual(pauseChanges, [true, false])
        XCTAssertNil(NSApplication.shared.modalWindow)
    }

    @MainActor
    func testHeldSecondaryFirePublishesUntilReleaseAndClearsWhenGameplayStops()
        throws
    {
        var input = PlayerInputState(rampDuration: 0)
        input.setSecondaryFireHeld(true)
        XCTAssertTrue(input.snapshot(frameDuration: 0.1).firesSecondaryWeapon)
        XCTAssertTrue(input.snapshot(frameDuration: 0.1).firesSecondaryWeapon)
        input.setSecondaryFireHeld(false)
        XCTAssertFalse(input.snapshot(frameDuration: 0.1).firesSecondaryWeapon)

        input.setSecondaryFireHeld(true)
        input.setGameplayActive(false, simulation: nil, at: 1)
        XCTAssertFalse(input.snapshot(frameDuration: 0.1).firesSecondaryWeapon)

        let view = RevivalGameplayView(frame: .zero, device: nil)
        var heldChanges: [Bool] = []
        view.secondaryFireHeldChanged = { heldChanges.append($0) }
        view.setGameplayActive(true)
        let spaceDown = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: " ",
            charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49
        ))
        let spaceUp = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyUp, location: .zero, modifierFlags: [], timestamp: 0.01,
            windowNumber: 0, context: nil, characters: " ",
            charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49
        ))
        let rightDown = try XCTUnwrap(NSEvent.mouseEvent(
            with: .rightMouseDown, location: .zero, modifierFlags: [],
            timestamp: 0.02, windowNumber: 0, context: nil, eventNumber: 1,
            clickCount: 1, pressure: 1
        ))
        let rightUp = try XCTUnwrap(NSEvent.mouseEvent(
            with: .rightMouseUp, location: .zero, modifierFlags: [],
            timestamp: 0.03, windowNumber: 0, context: nil, eventNumber: 2,
            clickCount: 1, pressure: 0
        ))
        view.keyDown(with: spaceDown)
        view.keyUp(with: spaceUp)
        view.rightMouseDown(with: rightDown)
        view.rightMouseUp(with: rightUp)
        view.keyDown(with: spaceDown)
        view.clearInput()
        view.rightMouseDown(with: rightDown)
        view.setGameplayActive(false)
        XCTAssertEqual(
            heldChanges, [true, false, true, false, true, false, true, false]
        )
    }

    @MainActor
    func testHeldPrimaryFirePublishesUntilRelease()
        throws
    {
        var playerInput = PlayerInputState(rampDuration: 0)
        playerInput.setPrimaryFireHeld(true)
        XCTAssertTrue(
            playerInput.snapshot(frameDuration: 0.1)
                .firesPrimaryWeapon
        )
        XCTAssertTrue(
            playerInput.snapshot(frameDuration: 0.1)
                .firesPrimaryWeapon
        )
        playerInput.setPrimaryFireHeld(false)
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1)
                .firesPrimaryWeapon
        )

        playerInput.setPrimaryFireHeld(true)
        playerInput.setGameplayActive(false, simulation: nil, at: 1)
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1)
                .firesPrimaryWeapon
        )

        let view = RevivalGameplayView(frame: .zero, device: nil)
        var heldChanges: [Bool] = []
        view.primaryFireHeldChanged = { heldChanges.append($0) }
        view.setGameplayActive(true)
        let mouseDown = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: .zero, modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1,
                clickCount: 1, pressure: 1
            )
        )
        let mouseUp = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseUp, location: .zero, modifierFlags: [],
                timestamp: 0.01, windowNumber: 0, context: nil, eventNumber: 2,
                clickCount: 1, pressure: 0
            )
        )
        view.mouseDown(with: mouseDown)
        view.mouseUp(with: mouseUp)
        view.mouseDown(with: mouseDown)
        view.clearInput()
        view.mouseDown(with: mouseDown)
        view.setGameplayActive(false)
        XCTAssertEqual(heldChanges, [true, false, true, false, true, false])

        // Script 032's aToggleAllPlayerControls(0, 0) clears every control
        // bit, the primary weapon's too (TrainingMission.cpp:2336).
        XCTAssertEqual(
            InputSnapshot(firesPrimaryWeapon: true)
                .applying(PlayerControlMask(rawValue: 0))
                .firesPrimaryWeapon,
            false
        )
    }

    @MainActor
    /// The flare key fires once per press: a repeat does not ask, the
    /// request is a one-shot, and capture teardown or a gameplay stop
    /// clears an unsnapshotted request. The flare itself is
    /// FireFlareFromPlayer (WeaponFireTests).
    func testPlayerFlareRequestIsANonrepeatOneShot() {
        XCTAssertTrue(
            RevivalGameplayView.requestsPlayerFlare(
                keyCode: 5, isRepeat: false, gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsPlayerFlare(
                keyCode: 5, isRepeat: true, gameplayIsActive: true
            )
        )
        XCTAssertEqual(
            RevivalGameplayView.heldInput(for: [3]).vertical, -1,
            "F remains downward thrust"
        )

        var playerInput = PlayerInputState(rampDuration: 0)
        playerInput.requestPlayerFlare()
        XCTAssertTrue(playerInput.snapshot(frameDuration: 0.1).firesPlayerFlare)
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1).firesPlayerFlare
        )
        playerInput.requestPlayerFlare()
        playerInput.cancelPlayerFlareRequest()
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1).firesPlayerFlare,
            "capture teardown clears an unsnapshotted one-shot"
        )
        playerInput.requestPlayerFlare()
        playerInput.setGameplayActive(false, simulation: nil, at: 1)
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1).firesPlayerFlare
        )
    }

    /// The app runs the buddy menu as a solo pause, as F1 and P do
    /// (PauseGame and ResumeGame, GameLoop.cpp:2770, :2780): it pauses the
    /// shell before the modal and resumes it after, and the view never
    /// deactivates gameplay, so the HUD and paused sounds survive. With no
    /// Guide-Bot command no modal opens, and the game resumes.
    @MainActor
    func testTheViewRunsTheMenuAsASoloPause() {
        _ = NSApplication.shared
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var pauseChanges: [Bool] = []
        view.soloPauseChanged = { pauseChanges.append($0) }
        view.setGameplayActive(true)
        let simulation = GameSession(
            level: makeTrainingCameraMonitorLevel(),
            presentationReadyTimestamp: 0
        )
        simulation.buddyMenuIsRequested = true
        view.runBuddyMenu(simulation)
        XCTAssertEqual(pauseChanges, [true, false])
        XCTAssertFalse(simulation.buddyMenuIsRequested)
        XCTAssertNil(simulation.buddyMenu)
        XCTAssertEqual(simulation.pauseDepth, 0)
        XCTAssertEqual(
            simulation.pendingMenuPresentation,
            [.hudMessage(BuddyMenu.noGuideBotText)]
        )
    }

    @MainActor
    func testCompletedTrainingSessionOffersOneDirectRestartAction() throws {
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var restartRequests = 0
        view.playAgainRequested = {
            restartRequests += 1
        }

        view.presentContentReadyState(completedLevelName: "Training Mission")

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
            profiles: [], defaultProfileID: nil, selectedProfileID: nil
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

    @MainActor
    func testTrainingGalleryAudioFailureStillPresentsHUD() {
        var presentedActions: [String] = []
        RevivalGameplayView.presentFeedback(
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

        let sameFrameReturn: [PresentationFeedback] = [
            .init(
                hudMessages: ["GB: Returning to ship."], voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: "GBotAcceptOrder.wav"
            ),
            .init(
                hudMessages: ["GB: Entering ship!"], voiceSourceName: "",
                voicePrecedesHUDMessages: true
            ),
            .init(
                hudMessages: ["Excellent!"], voiceSourceName: "proceed6.osf",
                voicePrecedesHUDMessages: true
            )
        ]
        var orderedPresentation: [String] = []
        RevivalGameplayView.presentFeedbackSequence(
            sameFrameReturn,
            attemptVoice: {
                orderedPresentation.append("voice:\($0)")
            },
            attemptSound: { name, _ in
                orderedPresentation.append("sound:\(name)")
            },
            presentHUDMessages: {
                orderedPresentation.append("hud:\($0.joined(separator: "|"))")
            }
        )
        XCTAssertEqual(orderedPresentation, [
            "sound:GBotAcceptOrder.wav", "hud:GB: Returning to ship.",
            "hud:GB: Entering ship!", "voice:proceed6.osf", "hud:Excellent!",
        ])
    }

    @MainActor
    func testTrainingFeedbackSequenceAttemptsOnlyFinalStreamingVoice() {
        let feedback: [PresentationFeedback] = [
            .init(
                hudMessages: ["first"], voiceSourceName: "return1.osf",
                voicePrecedesHUDMessages: true, soundSourceName: "first.wav"
            ),
            .init(
                hudMessages: ["second"], voiceSourceName: "welcome.osf",
                voicePrecedesHUDMessages: true, soundSourceName: "second.wav"
            ),
            .init(
                hudMessages: ["third"], voiceSourceName: "",
                voicePrecedesHUDMessages: true, soundSourceName: "third.wav"
            ),
        ]
        var presentation: [String] = []

        RevivalGameplayView.presentFeedbackSequence(
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
            "sound:first.wav", "hud:first", "voice:welcome.osf",
            "sound:second.wav", "hud:second", "sound:third.wav", "hud:third",
        ])
    }

    private func requestedSaveAction(
        keyCode: UInt16, modifiers: NSEvent.ModifierFlags = [],
        isRepeat: Bool = false, gameplayIsActive: Bool = true
    ) -> PlayerSaveAction? {
        RevivalGameplayView.requestedPlayerSaveAction(
            keyCode: keyCode, modifierFlags: modifiers, isRepeat: isRepeat,
            gameplayIsActive: gameplayIsActive
        )
    }

    @MainActor
    func testPhysicalEntriesAreNonrepeatAndEditorPlayReportsUnavailable()
        throws
    {
        XCTAssertEqual(requestedSaveAction(keyCode: 101), .quicksave)
        XCTAssertEqual(
            requestedSaveAction(keyCode: 101, modifiers: [.function]),
            .quicksave
        )
        XCTAssertEqual(
            requestedSaveAction(keyCode: 99, modifiers: [.option, .function]),
            .quickload
        )
        XCTAssertNil(requestedSaveAction(keyCode: 99))
        XCTAssertNil(requestedSaveAction(keyCode: 101, modifiers: [.option]))
        XCTAssertNil(requestedSaveAction(keyCode: 101, isRepeat: true))
        XCTAssertNil(requestedSaveAction(keyCode: 101, gameplayIsActive: false))

        _ = NSApplication.shared
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var pauseChanges: [Bool] = []
        view.soloPauseChanged = { pauseChanges.append($0) }
        view.setGameplayActive(true)
        let events = [
            try makeKeyEvent(keyCode: 101, modifiers: [.function]),
            try makeKeyEvent(keyCode: 99, modifiers: [.option, .function]),
        ]
        for event in events {
            var inspectedModal = false
            DispatchQueue.main.async {
                guard let modalWindow = NSApplication.shared.modalWindow else {
                    return XCTFail("save key did not present the unavailable alert")
                }
                inspectedModal = true
                let descendants = viewDescendants(of: modalWindow.contentView)
                let text = descendants.compactMap {
                    ($0 as? NSTextField)?.stringValue
                }
                XCTAssertTrue(text.contains("Save Unavailable"))
                XCTAssertTrue(text.contains(
                    "Save and load are unavailable in disposable editor play."
                ))
                descendants.compactMap { $0 as? NSButton }.only?
                    .performClick(nil)
            }
            view.keyDown(with: event)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            XCTAssertTrue(inspectedModal)
            XCTAssertNil(NSApplication.shared.modalWindow)
        }
        XCTAssertEqual(pauseChanges, [true, false, true, false])
    }

    /// EndLevel(0) after aFailLevel shows a failed result; only EndLevel(1)
    /// records the Training completion (gamesequence.cpp:1240-1262), and the
    /// app's ready state says which.
    @MainActor
    func testOnlyASuccessfulLevelEndRecordsCompletion() throws {
        let level = makeTrainingCameraMonitorLevel()
        let failing = GameSession(level: level, presentationReadyTimestamp: 0)
        failing.world.aFailLevel()
        let failed = try XCTUnwrap(failing.update(at: 0.1, input: .zero).levelEnd)
        XCTAssertFalse(failed.recordsMissionProgress)
        let winning = GameSession(level: level, presentationReadyTimestamp: 0)
        winning.world.aEndLevel()
        let won = try XCTUnwrap(winning.update(at: 0.1, input: .zero).levelEnd)
        XCTAssertTrue(won.recordsMissionProgress)

        let view = RevivalGameplayView(frame: .zero, device: nil)
        view.presentContentReadyState(
            completedLevelName: "Training Mission", succeeded: false
        )
        XCTAssertTrue(view.subviews.compactMap { $0 as? NSTextField }.contains {
            $0.stringValue.hasPrefix("Training Mission failed.")
        })
        view.presentContentReadyState(
            completedLevelName: "Training Mission", succeeded: true
        )
        XCTAssertTrue(view.subviews.compactMap { $0 as? NSTextField }.contains {
            $0.stringValue.hasPrefix("Training Mission completed.")
        })
    }
}
