import XCTest

final class WorldRenderingTests: XCTestCase {
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

    func testPlayerSimulationPreservesPriorFrameTimingAndNestedPauseRebasing() {
        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 10
        )

        let first = simulation.update(at: 10.016, input: .zero)
        XCTAssertEqual(first.systemsFrameDuration, 0.1, accuracy: 0.000_001)
        XCTAssertEqual(first.systemsGameTime, 0, accuracy: 0.000_001)
        XCTAssertEqual(first.storedFrameDuration, 0.016, accuracy: 0.000_001)
        XCTAssertEqual(first.gameTime, 0.016, accuracy: 0.000_001)

        let second = simulation.update(at: 10.05, input: .zero)
        XCTAssertEqual(second.systemsFrameDuration, 0.016, accuracy: 0.000_001)
        XCTAssertEqual(second.systemsGameTime, 0.016, accuracy: 0.000_001)
        XCTAssertEqual(second.storedFrameDuration, 0.034, accuracy: 0.000_001)
        XCTAssertEqual(second.gameTime, 0.05, accuracy: 0.000_001)

        simulation.stopTime(at: 10.06)
        simulation.stopTime(at: 10.07)
        simulation.startTime(at: 11)
        simulation.startTime(at: 12)
        let resumed = simulation.update(at: 12.04, input: .zero)
        XCTAssertEqual(resumed.storedFrameDuration, 0.05, accuracy: 0.000_001)
        XCTAssertEqual(resumed.gameTime, 0.1, accuracy: 0.000_001)
    }

    func testVariableDeltaDecisionMatchesBoundedFixedCadenceReferenceTrace() {
        func run(measuredDeltas: [Double]) -> PlayerSimulationFrame {
            let simulation = PlayerSimulation(
                level: makeSliceSixObjectRenderLevel(),
                presentationReadyTimestamp: 0
            )
            var timestamp = 0.0
            var frame: PlayerSimulationFrame?
            for measuredDelta in measuredDeltas {
                timestamp += measuredDelta
                frame = simulation.update(
                    at: timestamp,
                    input: .init(forward: 1)
                )
            }
            return frame!
        }

        // Both traces consume exactly 0.25 seconds of old-delta systems time:
        // the historical 0.1 first duration plus all measured deltas except the
        // final stored duration. The 120 Hz trace is a bounded research
        // comparison, not a second production mode.
        let variable = run(measuredDeltas: [0.018, 0.044, 0.031, 0.057, 0.016])
        let fixed = run(
            measuredDeltas: Array(repeating: 1.0 / 120.0, count: 19)
        )
        XCTAssertEqual(variable.velocity.z, fixed.velocity.z, accuracy: 0.000_01)
        XCTAssertEqual(
            variable.playerView.camera.position.z,
            fixed.playerView.camera.position.z,
            accuracy: 0.000_3
        )
        XCTAssertEqual(variable.playerView.roomSourceIndex, fixed.playerView.roomSourceIndex)
        XCTAssertEqual(variable.wallContact, fixed.wallContact)
    }

    func testSelectedVariableDeltaKeepsReachedCarrierCollisionBoostAndWiggleWithinCadenceTolerances() throws {
        let jitter = [0.018, 0.044, 0.031, 0.057, 0.016]
        let cadence120 = Array(repeating: 1.0 / 120.0, count: 19)

        func runCarrierCollision(
            measuredDeltas: [Double]
        ) -> (
            frame: PlayerSimulationFrame,
            input: InputSnapshot,
            firstContact: IndoorWallContact?
        ) {
            let base = makeSliceSixObjectRenderLevel()
            let clearance = defaultPlayerView(in: base).collisionRadius + 0.5
            let simulation = PlayerSimulation(
                level: makeSliceTenContactLevel(clearance: clearance),
                presentationReadyTimestamp: 0
            )
            var inputState = PlayerInputState()
            inputState.setHeld(.init(forward: 1, sideways: 1))
            var timestamp = 0.0
            var frame: PlayerSimulationFrame?
            var input = InputSnapshot.zero
            var firstContact: IndoorWallContact?
            for measuredDelta in measuredDeltas {
                input = inputState.snapshot(
                    frameDuration: simulation.frameDuration
                )
                timestamp += measuredDelta
                frame = simulation.update(at: timestamp, input: input)
                if firstContact == nil {
                    firstContact = frame?.wallContact
                }
            }
            return (frame!, input, firstContact)
        }

        let variableCarrier = runCarrierCollision(measuredDeltas: jitter)
        let fixedCarrier = runCarrierCollision(measuredDeltas: cadence120)
        XCTAssertEqual(
            variableCarrier.input.forward,
            fixedCarrier.input.forward,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            variableCarrier.input.sideways,
            fixedCarrier.input.sideways,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            variableCarrier.frame.playerView.roomSourceIndex,
            fixedCarrier.frame.playerView.roomSourceIndex
        )
        XCTAssertEqual(
            try XCTUnwrap(variableCarrier.firstContact).roomSourceIndex,
            try XCTUnwrap(fixedCarrier.firstContact).roomSourceIndex
        )
        XCTAssertEqual(
            try XCTUnwrap(variableCarrier.firstContact).faceIndex,
            try XCTUnwrap(fixedCarrier.firstContact).faceIndex
        )
        XCTAssertEqual(
            variableCarrier.frame.velocity.x,
            fixedCarrier.frame.velocity.x,
            accuracy: 2.6
        )
        XCTAssertEqual(
            variableCarrier.frame.playerView.camera.position.x,
            fixedCarrier.frame.playerView.camera.position.x,
            accuracy: 0.24
        )

        func runBoostAndWiggle(
            level: Level,
            measuredDeltas: [Double],
            input: InputSnapshot
        ) -> (frame: PlayerSimulationFrame, fuel: Float, falloff: Float) {
            let simulation = PlayerSimulation(
                level: level,
                presentationReadyTimestamp: 0
            )
            simulation.setIndoorAutoLevelMode(.off)
            var timestamp = 0.0
            var frame: PlayerSimulationFrame?
            for measuredDelta in measuredDeltas {
                timestamp += measuredDelta
                frame = simulation.update(at: timestamp, input: input)
            }
            return (
                frame!,
                simulation.afterburnerFuel,
                simulation.wiggleFalloff
            )
        }

        let variableBoost = runBoostAndWiggle(
            level: makeSliceThirteenWiggleLevel(),
            measuredDeltas: jitter,
            input: .init(afterburner: 1)
        )
        let fixedBoost = runBoostAndWiggle(
            level: makeSliceThirteenWiggleLevel(),
            measuredDeltas: cadence120,
            input: .init(afterburner: 1)
        )
        XCTAssertEqual(variableBoost.fuel, fixedBoost.fuel, accuracy: 0.000_004)
        XCTAssertEqual(variableBoost.falloff, fixedBoost.falloff, accuracy: 0.000_001)
        XCTAssertEqual(
            variableBoost.frame.velocity.z,
            fixedBoost.frame.velocity.z,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            variableBoost.frame.playerView.camera.position.z,
            fixedBoost.frame.playerView.camera.position.z,
            accuracy: 0.001_6
        )

        let variablePortal = runBoostAndWiggle(
            level: makeSliceThirteenPortalWiggleLevel(),
            measuredDeltas: jitter,
            input: .zero
        )
        let fixedPortal = runBoostAndWiggle(
            level: makeSliceThirteenPortalWiggleLevel(),
            measuredDeltas: cadence120,
            input: .zero
        )
        XCTAssertEqual(
            variablePortal.frame.playerView.roomSourceIndex,
            fixedPortal.frame.playerView.roomSourceIndex
        )
        XCTAssertEqual(variablePortal.frame.playerView.roomSourceIndex, 99)
    }

    func testPlayerSimulationUsesPyroAnalyticThrustWithoutDiagonalNormalization() {
        let level = makeSliceSixObjectRenderLevel()
        let start = defaultPlayerView(in: level).camera.position
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016,
            input: .init(forward: 1, sideways: 1)
        )

        let decay = exp(-3.0 * 0.1)
        let expectedVelocity = Float(60 * (1 - decay))
        let expectedDisplacement = Float(60 * 0.1 - 20 * (1 - decay))
        XCTAssertEqual(frame.velocity.x, expectedVelocity, accuracy: 0.000_01)
        XCTAssertEqual(frame.velocity.y, 0, accuracy: 0.000_01)
        XCTAssertEqual(frame.velocity.z, expectedVelocity, accuracy: 0.000_01)
        XCTAssertEqual(
            frame.playerView.camera.position.x,
            start.x + expectedDisplacement,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.playerView.camera.position.z,
            start.z + expectedDisplacement,
            accuracy: 0.000_1
        )
    }

    func testPlayerSimulationUsesSampledBasisThenCommitsRotationalFlight() {
        let level = makeSliceSixObjectRenderLevel()
        let start = defaultPlayerView(in: level).camera.position
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016,
            input: .init(vertical: 1, pitch: 0.75, yaw: 1)
        )

        XCTAssertEqual(
            frame.angularVelocity.x,
            12_065.218,
            accuracy: 0.001
        )
        XCTAssertEqual(
            frame.angularVelocity.y,
            16_086.958,
            accuracy: 0.001
        )
        XCTAssertEqual(frame.angularVelocity.z, 0, accuracy: 0.001)
        XCTAssertEqual(frame.turnrollFixedAngle, -800, accuracy: 0.001)

        let camera = frame.playerView.camera
        XCTAssertEqual(
            camera.target.x - camera.position.x,
            0.152_529_84,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            camera.target.y - camera.position.y,
            -0.115_366_35,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            camera.target.z - camera.position.z,
            0.981_542_3,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.playerView.camera.position.x,
            start.x,
            accuracy: 0.000_1
        )
        XCTAssertGreaterThan(frame.playerView.camera.position.y, start.y)
        XCTAssertEqual(
            frame.playerView.camera.position.z,
            start.z,
            accuracy: 0.000_1
        )
    }

    func testPlayerSimulationAppliesIsolatedRollToAngularVelocityAndCameraUp() {
        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        let start = defaultPlayerView(in: simulation.level)

        let frame = simulation.update(
            at: 0.016,
            input: .init(roll: 1)
        )

        XCTAssertGreaterThan(frame.angularVelocity.z, 0)
        XCTAssertNotEqual(frame.playerView.camera.up, start.camera.up)
        XCTAssertEqual(
            frame.playerView.camera.target.x - frame.playerView.camera.position.x,
            start.camera.target.x - start.camera.position.x,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.playerView.camera.target.y - frame.playerView.camera.position.y,
            start.camera.target.y - start.camera.position.y,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.playerView.camera.target.z - frame.playerView.camera.position.z,
            start.camera.target.z - start.camera.position.z,
            accuracy: 0.000_1
        )
    }

    func testIndoorNewPlayerAutolevelCanBeTurnedOffAfterSourceDelay() {
        let active = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        let disabled = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        disabled.setIndoorAutoLevelMode(.off)

        let initialInput = InputSnapshot(directLookPitchRadians: 0.25)
        _ = active.update(at: 0.016, input: initialInput)
        _ = disabled.update(at: 0.016, input: initialInput)

        var activeFrame: PlayerSimulationFrame!
        var disabledFrame: PlayerSimulationFrame!
        for frameIndex in 2...110 {
            let timestamp = Double(frameIndex) * 0.016
            activeFrame = active.update(at: timestamp, input: .zero)
            disabledFrame = disabled.update(at: timestamp, input: .zero)
        }

        let activePitch = abs(
            activeFrame.playerView.camera.target.y
                - activeFrame.playerView.camera.position.y
        )
        let disabledPitch = abs(
            disabledFrame.playerView.camera.target.y
                - disabledFrame.playerView.camera.position.y
        )
        XCTAssertLessThan(activePitch, disabledPitch)
        XCTAssertEqual(disabledPitch, sin(0.25), accuracy: 0.000_1)
    }

    func testPlayerSimulationCommitsContactResponseToSamePlayerAndRoom() throws {
        let simulation = PlayerSimulation(
            level: makeSliceTenContactLevel(),
            presentationReadyTimestamp: 0
        )
        var timestamp = 0.1
        var contactFrame: PlayerSimulationFrame?
        for _ in 0..<100 {
            let frame = simulation.update(
                at: timestamp,
                input: .init(forward: 1)
            )
            timestamp += 0.1
            if frame.wallContact != nil {
                contactFrame = frame
                break
            }
        }

        let frame = try XCTUnwrap(contactFrame)
        let contact = try XCTUnwrap(frame.wallContact)
        let player = try XCTUnwrap(
            simulation.level.objects.first {
                $0.handle == frame.playerView.objectHandle
            }
        )
        XCTAssertEqual(player.position, frame.playerView.camera.position)
        XCTAssertEqual(
            player.location,
            .room(frame.playerView.roomSourceIndex)
        )
        XCTAssertEqual(contact.roomSourceIndex, frame.playerView.roomSourceIndex)
        XCTAssertGreaterThan(
            contact.normal.x * frame.velocity.x
                + contact.normal.y * frame.velocity.y
                + contact.normal.z * frame.velocity.z,
            0
        )
        XCTAssertLessThan(frame.playerView.camera.position.z, 2_310.928)
    }

    func testBaseAfterburnerUsesReleasedBoostFuelAndProjectionState() {
        let boosted = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        let ordinary = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )

        let boostedFrame = boosted.update(
            at: 0.1,
            input: .init(afterburner: 1)
        )
        let ordinaryFrame = ordinary.update(
            at: 0.1,
            input: .init(forward: 1)
        )

        XCTAssertTrue(boosted.afterburnerIsActive)
        XCTAssertEqual(boosted.afterburnerFuel, 4.9, accuracy: 0.000_001)
        XCTAssertEqual(boosted.energy, 100)
        XCTAssertEqual(boosted.afterburnerMagnitude, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(
            boostedFrame.velocity.z,
            ordinaryFrame.velocity.z * 1.6 * 1.8,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            boostedFrame.playerView.camera.projection.horizontalFieldOfViewRadians,
            PerspectiveProjection.sourceDefault.horizontalFieldOfViewRadians
                * (1 + 0.2 * 0.08),
            accuracy: 0.000_001
        )

        var timestamp = 0.2
        while boosted.afterburnerFuel > 0 {
            _ = boosted.update(at: timestamp, input: .init(afterburner: 1))
            timestamp += 0.1
        }
        XCTAssertTrue(boosted.afterburnerIsActive)
        XCTAssertEqual(boosted.afterburnerFuel, 0)

        _ = boosted.update(at: timestamp, input: .init(afterburner: 1))
        XCTAssertFalse(boosted.afterburnerIsActive)
    }

    func testReleasedAfterburnerPunchKeepsStrictFuelBoundaries() {
        func thrustRatio(
            afterburnerFrames: Int
        ) -> Float {
            let simulations = (0..<3).map { _ in
                PlayerSimulation(
                    level: makeSliceSixObjectRenderLevel(),
                    presentationReadyTimestamp: 0
                )
            }
            var timestamp = 0.125
            for simulation in simulations {
                _ = simulation.update(at: timestamp, input: .zero)
            }
            for _ in 0..<afterburnerFrames {
                timestamp += 0.125
                for simulation in simulations {
                    _ = simulation.update(
                        at: timestamp,
                        input: .init(afterburner: 0.000_001)
                    )
                }
            }
            timestamp += 0.125
            let boosted = simulations[0].update(
                at: timestamp,
                input: .init(afterburner: 1)
            )
            let ordinary = simulations[1].update(
                at: timestamp,
                input: .init(forward: 1)
            )
            let coasting = simulations[2].update(
                at: timestamp,
                input: .zero
            )
            return (boosted.velocity.z - coasting.velocity.z)
                / (ordinary.velocity.z - coasting.velocity.z)
        }

        XCTAssertEqual(thrustRatio(afterburnerFrames: 4), 1.6, accuracy: 0.000_01)
        XCTAssertEqual(
            thrustRatio(afterburnerFrames: 6),
            1.6 * 1.4,
            accuracy: 0.000_01
        )
        XCTAssertEqual(thrustRatio(afterburnerFrames: 8), 1.6, accuracy: 0.000_01)
    }

    func testReleasedAfterburnerLinearPunchPreservesDoublePromotion() {
        XCTAssertEqual(
            sourceAfterburnerForwardControl(
                afterburner: 1,
                fuel: 4.400_000_1
            ).bitPattern,
            0x4027_ef9e
        )
        XCTAssertEqual(
            sourceAfterburnerForwardControl(
                afterburner: 1,
                fuel: Float(bitPattern: 0x408a_0003)
            ).bitPattern,
            0x4019_99a9
        )

        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        for frame in 1...6 {
            _ = simulation.update(
                at: Double(frame) * 0.1,
                input: .init(afterburner: 0.000_001)
            )
        }
        let ship = simulation.level.shipDefinitions.first {
            $0.source == simulation.level.defaultPlayerBinding!.ship
        }!
        let fuel = simulation.afterburnerFuel
        let punch = Float(
            1 + ((Double(fuel) - 4) / 0.5) * 0.8
        )
        let forwardControl = Float(1.6 * Double(punch))
        let force = Float(
            Double(ship.physics.fullThrust) * Double(forwardControl)
        )
        let q = Double(force) / Double(ship.physics.drag)
        let decay = exp(
            -(Double(ship.physics.drag) / Double(ship.physics.mass))
                * Double(simulation.frameDuration)
        )
        let expectedVelocity = Float(
            (Double(simulation.velocity.z) - q) * decay + q
        )

        let frame = simulation.update(
            at: 0.7,
            input: .init(afterburner: 1)
        )

        XCTAssertEqual(frame.velocity.z.bitPattern, expectedVelocity.bitPattern)
    }

    func testReleasedNoCoolerRechargeConsumesEnergyAboveThreshold() {
        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        var timestamp = 0.1

        _ = simulation.update(at: timestamp, input: .init(afterburner: 1))
        timestamp += 0.1
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp += 0.1
        XCTAssertEqual(simulation.afterburnerFuel, 5, accuracy: 0.000_001)
        XCTAssertEqual(simulation.energy, 99.9, accuracy: 0.000_01)

        while simulation.energy > 5 {
            _ = simulation.update(
                at: timestamp,
                input: .init(afterburner: 1)
            )
            timestamp += 0.1
            _ = simulation.update(at: timestamp, input: .zero)
            timestamp += 0.1
        }
        _ = simulation.update(at: timestamp, input: .init(afterburner: 1))
        timestamp += 0.1
        let depletedFuel = simulation.afterburnerFuel
        let thresholdEnergy = simulation.energy
        _ = simulation.update(at: timestamp, input: .zero)

        XCTAssertLessThan(depletedFuel, 5)
        XCTAssertEqual(simulation.afterburnerFuel, depletedFuel)
        XCTAssertEqual(simulation.energy, thresholdEnergy)
    }

    func testReleasedRechargeConsumesUntrimmedFrameWhenFuelCaps() {
        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )

        _ = simulation.update(at: 0.125, input: .zero)
        _ = simulation.update(at: 0.625, input: .init(afterburner: 1))
        XCTAssertEqual(simulation.afterburnerFuel, 4.875)
        _ = simulation.update(at: 1.125, input: .zero)

        XCTAssertEqual(simulation.afterburnerFuel, 5)
        XCTAssertEqual(simulation.energy, 99.5)
    }

    func testPyroWiggleIsSourceQuantizedAuthoritativeMovementWithFalloff() {
        let stationary = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(),
            presentationReadyTimestamp: 0
        )
        let thrusting = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(),
            presentationReadyTimestamp: 0
        )
        let start = defaultPlayerView(in: stationary.level).camera.position

        let stationaryFrame = stationary.update(at: 0.1, input: .zero)
        let thrustingFrame = thrusting.update(
            at: 0.1,
            input: .init(forward: 1)
        )

        XCTAssertEqual(stationary.wiggleFalloff, 0)
        XCTAssertEqual(thrusting.wiggleFalloff, 0.05, accuracy: 0.000_001)
        XCTAssertEqual(
            stationaryFrame.playerView.camera.position.z - start.z,
            0.091_064_45,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            thrustingFrame.playerView.camera.position.z - start.z,
            0.086_425_78,
            accuracy: 0.000_001
        )
    }

    func testPyroWiggleUsesReleasedFloatSineTableQuantization() {
        var level = makeSliceThirteenWiggleLevel()
        var objects = level.objects
        let playerIndex = objects.firstIndex { $0.handle == 2_048 }!
        objects[playerIndex].position = .zero
        level = replacing(level, objects: objects)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        _ = simulation.update(at: 0.1, input: .zero)
        let frame = simulation.update(at: 0.2, input: .zero)

        XCTAssertEqual(
            frame.playerView.camera.position.z.bitPattern,
            0x3e3a_8b68
        )
    }

    func testPyroWiggleUsesPostMouselookPreRotationUpAxis() {
        let simulation = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(),
            presentationReadyTimestamp: 0
        )
        let start = defaultPlayerView(in: simulation.level).camera.position

        let frame = simulation.update(
            at: 0.1,
            input: .init(directLookPitchRadians: .pi / 2)
        )

        XCTAssertLessThan(frame.playerView.camera.position.y, start.y - 0.09)
        XCTAssertEqual(
            frame.playerView.camera.position.z,
            start.z,
            accuracy: 0.000_01
        )
    }

    func testPyroWiggleRetainsTenPercentMovementAtFullFalloff() {
        let simulation = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(),
            presentationReadyTimestamp: 0
        )
        simulation.setIndoorAutoLevelMode(.off)
        var timestamp = 0.1

        for _ in 0..<20 {
            _ = simulation.update(
                at: timestamp,
                input: .init(afterburner: 0.000_02)
            )
            timestamp += 0.1
        }
        let priorPosition = defaultPlayerView(in: simulation.level).camera.position
        let frame = simulation.update(
            at: timestamp,
            input: .init(afterburner: 0.000_02)
        )

        XCTAssertEqual(simulation.wiggleFalloff, 1)
        XCTAssertGreaterThan(
            abs(frame.playerView.camera.position.z - priorPosition.z),
            0.000_1
        )
    }

    func testPyroWiggleCommitsReturnedRoomAfterPortalCrossing() {
        let simulation = PlayerSimulation(
            level: makeSliceThirteenPortalWiggleLevel(),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(at: 0.1, input: .zero)

        XCTAssertEqual(frame.playerView.roomSourceIndex, 99)
        XCTAssertEqual(
            simulation.level.objects.first { $0.handle == 2_048 }!.location,
            .room(99)
        )
    }

    func testPyroWiggleRefusesMovementOnIndoorContact() {
        let open = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(),
            presentationReadyTimestamp: 0
        )
        let blocked = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(blocked: true),
            presentationReadyTimestamp: 0
        )
        let blockedStart = defaultPlayerView(in: blocked.level).camera.position

        let openFrame = open.update(at: 0.1, input: .zero)
        let blockedFrame = blocked.update(at: 0.1, input: .zero)

        XCTAssertGreaterThan(openFrame.playerView.camera.position.z, blockedStart.z)
        XCTAssertEqual(blockedFrame.playerView.camera.position, blockedStart)
        XCTAssertNil(blockedFrame.wallContact)
    }

    func testPlayerSimulationSlidesAndRetracesRemainingFrameAfterContact() throws {
        let base = makeSliceSixObjectRenderLevel()
        let clearance = defaultPlayerView(in: base).collisionRadius + 0.5
        let simulation = PlayerSimulation(
            level: makeSliceTenContactLevel(clearance: clearance),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016,
            input: .init(forward: 1, sideways: 1)
        )
        let contact = try XCTUnwrap(frame.wallContact)

        XCTAssertGreaterThan(
            frame.playerView.camera.position.x,
            contact.contactPoint.x + 0.1
        )
        XCTAssertLessThanOrEqual(
            frame.playerView.camera.position.z,
            contact.contactPoint.z
                + contact.normal.z * frame.playerView.collisionRadius
        )
        XCTAssertGreaterThan(frame.velocity.x, 0)
        XCTAssertLessThanOrEqual(frame.velocity.z, 0)
        XCTAssertLessThan(abs(frame.velocity.z), frame.velocity.x * 0.03)

        XCTAssertEqual(frame.velocity.x, 15.360_591, accuracy: 0.000_1)
        XCTAssertEqual(frame.velocity.z, -0.015_361_632, accuracy: 0.000_1)
    }

    func testIndoorTraceCombinesTwoExactNearestWallNormals() throws {
        let level = makeSliceElevenCornerLevel(clearance: 20)
        let view = defaultPlayerView(in: level)
        let trace = traceIndoorMovement(
            in: level,
            startRoom: view.roomSourceIndex,
            start: view.camera.position,
            end: Vector3(
                x: view.camera.position.x + 20,
                y: view.camera.position.y,
                z: view.camera.position.z + 20
            ),
            radius: view.collisionRadius
        )

        guard case let .wallHit(contact) = trace.outcome else {
            return XCTFail("Expected the equal-distance corner contact.")
        }
        let component = -Float(1 / sqrt(2.0))
        XCTAssertEqual(contact.normal.x, component, accuracy: 0.000_001)
        XCTAssertEqual(contact.normal.y, 0, accuracy: 0.000_001)
        XCTAssertEqual(contact.normal.z, component, accuracy: 0.000_001)
    }

    func testPlayerSimulationUsesSourceDefaultForceFieldBounce() throws {
        let simulation = PlayerSimulation(
            level: makeSliceElevenForceFieldLevel(clearance: 20),
            presentationReadyTimestamp: 0
        )
        var timestamp = 0.1
        var contactFrame: PlayerSimulationFrame?
        for _ in 0..<100 {
            let frame = simulation.update(
                at: timestamp,
                input: .init(forward: 1)
            )
            timestamp += 0.1
            if frame.wallContact != nil {
                contactFrame = frame
                break
            }
        }

        let frame = try XCTUnwrap(contactFrame)
        let contact = try XCTUnwrap(frame.wallContact)
        let collisionCenterZ = contact.contactPoint.z
            + contact.normal.z * frame.playerView.collisionRadius
        XCTAssertLessThan(frame.playerView.camera.position.z, collisionCenterZ - 1)
        XCTAssertLessThan(frame.velocity.z, -90)
    }

    func testNearImmediateContactUsesReleasedNormalNudge() throws {
        let base = makeSliceSixObjectRenderLevel()
        let clearance = defaultPlayerView(in: base).collisionRadius - 0.0005
        let simulation = PlayerSimulation(
            level: makeSliceTenContactLevel(clearance: clearance),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016,
            input: .init(forward: 0.001_351)
        )
        let contact = try XCTUnwrap(frame.wallContact)
        let attemptedDistance = Float(
            60 * 0.1 - 20 * (1 - exp(-3.0 * 0.1))
        )
        let movedTime = frame.systemsFrameDuration
            * contact.distance
            / attemptedDistance

        XCTAssertEqual(movedTime, 0, accuracy: 0.000_001)
        let outwardVelocity = contact.normal.x * frame.velocity.x
            + contact.normal.y * frame.velocity.y
            + contact.normal.z * frame.velocity.z
        XCTAssertGreaterThan(outwardVelocity, 0.3)
    }

    func testPlayerSimulationStopsAtReleasedNineContactLimit() throws {
        let base = makeSliceSixObjectRenderLevel()
        let clearance = defaultPlayerView(in: base).collisionRadius - 0.0005
        let simulation = PlayerSimulation(
            level: makeSliceElevenTrappedLevel(clearance: clearance),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.1,
            input: .init(forward: 1)
        )

        XCTAssertNotNil(frame.wallContact)
        XCTAssertEqual(frame.velocity, .zero)
    }

    func testReciprocalPortalComponentIgnoresPresentationPassabilityAndDisconnectedRooms() {
        let level = makeSelectedRoomRenderLevel()
        let disconnected = LevelRoom(
            sourceIndex: 99,
            vertices: [],
            faces: [],
            portals: []
        )

        XCTAssertEqual(
            reciprocalPortalComponent(
                rooms: level.rooms + [disconnected],
                startRoomSourceIndex: 1
            ),
            Set([1, 2, 3, 4])
        )
    }

    func testDefaultPlayerViewDerivesCanonicalPoseRadiusAndExcludesViewer() throws {
        let level = makeSliceSixObjectRenderLevel()
        let view = defaultPlayerView(in: level)

        XCTAssertEqual(view.playerID, 0)
        XCTAssertEqual(view.objectHandle, 2_048)
        XCTAssertEqual(view.roomSourceIndex, 1)
        XCTAssertEqual(
            view.camera.position,
            .init(x: 2_060.6497, y: -131.22517, z: 2_204.4216)
        )
        XCTAssertEqual(
            view.camera.target,
            .init(x: 2_060.6497, y: -131.22517, z: 2_205.4216)
        )
        XCTAssertEqual(view.camera.up, .init(x: 0, y: 1, z: 0))
        XCTAssertEqual(
            view.collisionRadius,
            level.shipDefinitions[0].presentationSize * 0.8
        )

        let extraction = try extractWorldForRendering(level, playerView: view)
        XCTAssertEqual(extraction.admittedObjectHandles, [12_301, 12_300])
        XCTAssertFalse(extraction.admittedObjectHandles.contains(view.objectHandle))

        let plan = try makeMetalWorldPlan(level: level, playerView: view)
        XCTAssertEqual(plan.camera, view.camera)
        XCTAssertGreaterThan(plan.preparedDraws.count, plan.draws.count)
        XCTAssertEqual(
            plan.activeDrawIndices.map { plan.preparedDraws[$0] },
            plan.draws
        )
        XCTAssertFalse(plan.draws.contains { $0.objectHandle == view.objectHandle })
    }

    func testSourceProjectionPreservesVerticalFramingAcrossFullDrawableAspect() {
        let fourByThree = PerspectiveProjection.sourceDefault
        let wide = fourByThree.withAspectRatio(16.0 / 9.0)
        let fourByThreeVerticalScale =
            (1 / tan(fourByThree.horizontalFieldOfViewRadians / 2))
            * fourByThree.aspectRatio
        let wideVerticalScale =
            (1 / tan(wide.horizontalFieldOfViewRadians / 2))
            * wide.aspectRatio
        XCTAssertEqual(
            fourByThree.horizontalFieldOfViewRadians,
            3.14 * 72 / 180,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            wideVerticalScale,
            fourByThreeVerticalScale,
            accuracy: 0.000_001
        )
        XCTAssertLessThan(
            1 / tan(wide.horizontalFieldOfViewRadians / 2),
            1 / tan(fourByThree.horizontalFieldOfViewRadians / 2)
        )

        let portrait = fullDrawableMetalViewport(
            drawableWidth: 1_170,
            drawableHeight: 2_532
        )
        XCTAssertEqual(portrait.originX, 0)
        XCTAssertEqual(portrait.originY, 0)
        XCTAssertEqual(portrait.width, 1_170)
        XCTAssertEqual(portrait.height, 2_532)

        let landscape = fullDrawableMetalViewport(
            drawableWidth: 2_360,
            drawableHeight: 1_640
        )
        XCTAssertEqual(landscape.originX, 0)
        XCTAssertEqual(landscape.originY, 0)
        XCTAssertEqual(landscape.width, 2_360)
        XCTAssertEqual(landscape.height, 1_640)
    }

    func testRoomThreeConvexShellContainmentAcceptsItsBoundaryAndRejectsPastIt() {
        let center = RoomCamera.trainingRoom3.position
        let room = makeSourceContainmentRoom(
            center: center,
            texture: .init(storedIndex: 0, sourceName: "wall")
        )

        XCTAssertTrue(
            sourceRoomThreeContains(
                .init(x: center.x - 0.5, y: center.y, z: center.z),
                in: room
            )
        )
        XCTAssertTrue(
            sourceRoomThreeContains(
                .init(x: center.x, y: center.y + 1, z: center.z),
                in: room
            )
        )
        XCTAssertFalse(
            sourceRoomThreeContains(
                .init(x: center.x, y: center.y + 1.25, z: center.z),
                in: room
            )
        )
    }

    func testEvaluatesTypedCoronaNearCutoffAndRenderedPortalOcclusion() throws {
        let camera = RoomCamera(
            position: .zero,
            target: .init(x: 0, y: 1, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        let visible = try extractWorldForRendering(
            makeCoronaEvaluationLevel(blocked: false),
            camera: camera,
            startRoomSourceIndex: 3
        )
        let corona = try XCTUnwrap(visible.lightCoronas.only)
        XCTAssertEqual(corona.roomSourceIndex, 3)
        XCTAssertEqual(corona.faceIndex, 0)
        XCTAssertEqual(corona.assetIndex, 0)
        XCTAssertEqual(corona.size, 4, accuracy: 0.000_001)
        XCTAssertEqual(corona.center, .init(x: 0, y: 20.75, z: 0))
        XCTAssertEqual(corona.tint, .init(x: 0.25, y: 0.5, z: 0.75))
        XCTAssertEqual(corona.blend, .additiveSourceAlpha(opacity: 102))
        let plan = try makeMetalWorldPlan(
            level: makeCoronaEvaluationLevel(blocked: false),
            camera: camera,
            startRoomSourceIndex: 3
        )
        XCTAssertEqual(plan.preparedLightCoronaCandidates, [corona])
        XCTAssertEqual(
            plan.draws.count,
            visible.opaqueDrawItems.count
                + visible.modelDrawItems.count
                + visible.translucentDrawItems.count
        )

        let nearCamera = RoomCamera(
            position: .init(x: 0, y: 1, z: 0),
            target: .init(x: 0, y: 2, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        XCTAssertTrue(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(blocked: false),
                camera: nearCamera,
                startRoomSourceIndex: 3
            ).lightCoronas.isEmpty
        )
        XCTAssertTrue(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(blocked: true),
                camera: camera,
                startRoomSourceIndex: 3
            ).lightCoronas.isEmpty
        )
        XCTAssertTrue(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(objectBlocked: true),
                camera: camera,
                startRoomSourceIndex: 3
            ).lightCoronas.isEmpty
        )
        XCTAssertEqual(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(objectBlocked: true),
                camera: camera,
                startRoomSourceIndex: 3,
                excludedObjectHandle: 99
            ).lightCoronas.count,
            1
        )
    }

    func testEvaluatesTypedWaterOnTheSimulationOwnedSixtyHertzVisualTick() throws {
        var base = Data()
        base.reserveCapacity(128 * 128 * 4)
        for y in 0..<128 {
            for x in 0..<128 {
                base.append(UInt8(x))
                base.append(UInt8(y))
                base.append(UInt8(x ^ y))
                base.append(UInt8((x + y) & 0xff))
            }
        }
        var evaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )

        let frame0 = evaluator.rgba8(visualTick: 0)
        XCTAssertEqual(
            evaluator.rgba8(visualTick: 0),
            frame0
        )
        let frame1 = evaluator.rgba8(visualTick: 1)
        var frame15 = frame1
        for frame in 2...15 {
            frame15 = evaluator.rgba8(visualTick: frame)
        }

        XCTAssertEqual(
            canonicalSHA256(frame0),
            "c93b482fca480de0b038229dc4713132eccaa80565d4de49290ad298fb3ff3d3"
        )
        XCTAssertEqual(
            canonicalSHA256(frame1),
            "d3807e29ea90fef543de25265f4340e6c97154bf0ed09885b4ba967b23d1d25d"
        )
        XCTAssertEqual(
            canonicalSHA256(frame15),
            "a6421e077e293fe63fb6d67f6977fdf575028ff946a0f229e3b21d366afbdeb0"
        )

        var boundedSequentialEvaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )
        var boundedSequentialFrame = boundedSequentialEvaluator.rgba8(visualTick: 0)
        for frame in 1...7 {
            boundedSequentialFrame = boundedSequentialEvaluator.rgba8(visualTick: frame)
        }
        var boundedSkippedEvaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )
        _ = boundedSkippedEvaluator.rgba8(visualTick: 0)
        XCTAssertEqual(
            boundedSkippedEvaluator.rgba8(visualTick: 7),
            boundedSequentialFrame
        )

        var skippedEvaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )
        _ = skippedEvaluator.rgba8(visualTick: 0)
        let directlyDemandedFrame15 = skippedEvaluator.rgba8(visualTick: 15)
        XCTAssertEqual(
            canonicalSHA256(directlyDemandedFrame15),
            "314d89786dd2c0ae2917f3fe44d420a469a9eede2a424d7256e6a87beccb2d49"
        )
    }

    func testPreservesSplitGreenShadeTableSemantics() throws {
        var base = Data()
        base.reserveCapacity(128 * 128 * 4)
        for _ in 0..<(128 * 128) {
            base.append(contentsOf: [0, 90, 0, 255])
        }
        var evaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: .init(
                evaluationIntervalSeconds: 0,
                lightingShift: 0,
                dampingShift: 6,
                elements: [
                    .init(
                        kind: .heightBlob,
                        frequency: 0,
                        speed: 29,
                        size: 1,
                        x1: 64,
                        y1: 64,
                        x2: 0,
                        y2: 0
                    ),
                ]
            )
        )

        let frame0 = evaluator.rgba8(visualTick: 0)

        let discriminatingPixelOffset = (64 * 128 + 65) * 4
        XCTAssertEqual(
            Array(frame0[discriminatingPixelOffset..<(discriminatingPixelOffset + 4)]),
            [0, 0, 0, 255]
        )
        XCTAssertEqual(
            canonicalSHA256(frame0),
            "e5495353fb1b915327813cc39a74d33aebf4484f023039fb485d77a38c9c678b"
        )
    }

    func testTraversesTheTwoAlignedRenderedPortalsAndStopsAtRoomOne() throws {
        let level = makeSelectedRoomRenderLevel()
        let camera = RoomCamera(
            position: .zero,
            target: .init(x: 0, y: 1, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )

        let extraction = try extractWorldForRendering(
            level,
            camera: camera,
            startRoomSourceIndex: 3
        )

        XCTAssertEqual(extraction.visibleRoomSourceIndices, [3, 2, 1])
        XCTAssertEqual(
            extraction.translucentDrawItems.map {
                "\($0.roomSourceIndex):\($0.faceIndex)"
            },
            ["2:0", "3:0"]
        )
        XCTAssertEqual(
            extraction.opaqueDrawItems.map {
                "\($0.roomSourceIndex):\($0.faceIndex)"
            },
            ["1:1"]
        )
        XCTAssertFalse(
            extraction.opaqueDrawItems.contains {
                $0.roomSourceIndex == 1 && $0.faceIndex == 2
            }
        )
        XCTAssertFalse(
            extraction.portalEdges.contains(where: { $0.roomSourceIndex == 4 })
        )
    }

    func testAdmitsTheFixedSliceSixObjectsAndSelectsTheSourceLOD() throws {
        let level = makeSliceSixObjectRenderLevel()
        try level.validate()

        let extraction = try extractWorldForRendering(
            level,
            camera: .trainingRoom3,
            startRoomSourceIndex: 3
        )

        XCTAssertEqual(
            extraction.admittedObjectHandles,
            [18_441, 2_048, 12_300, 6_147]
        )
        XCTAssertEqual(
            Set(extraction.modelDrawItems.map(\.objectHandle)),
            Set(extraction.admittedObjectHandles)
        )
        XCTAssertEqual(
            Set(
                extraction.modelDrawItems
                    .filter { $0.objectHandle == 2_048 }
                    .map(\.model)
            ),
            [.init(storedIndex: 1, sourceName: "PyroGLMed.OOF")]
        )
        XCTAssertFalse(extraction.admittedObjectHandles.contains(2_052))
        XCTAssertTrue(
            extraction.modelDrawItems.contains {
                $0.objectHandle == 6_147
                    && $0.material == .sourceColor(red: 32, green: 64, blue: 96)
            }
        )
        XCTAssertFalse(extraction.modelDrawItems.contains { $0.submodelIndex == 2 })
    }
}

private extension Array {
    var only: Element? { count == 1 ? self[0] : nil }
}

func makeCoronaEvaluationLevel(
    blocked: Bool = false,
    objectBlocked: Bool = false
) -> Level {
    let base = makeMinimalCanonicalLevel()
    let light = SourceResource(storedIndex: 1, sourceName: "light")
    let blocker = SourceResource(storedIndex: 2, sourceName: "blocker")
    let candidateVertices = [
        Vector3(x: -1, y: 21, z: -1),
        Vector3(x: 1, y: 21, z: -1),
        Vector3(x: 1, y: 21, z: 1),
        Vector3(x: -1, y: 21, z: 1),
    ]
    let blockerVertices = [
        Vector3(x: -5, y: 10, z: -5),
        Vector3(x: 5, y: 10, z: -5),
        Vector3(x: 5, y: 10, z: 5),
        Vector3(x: -5, y: 10, z: 5),
    ]
    let corners = [
        FaceCorner(vertexIndex: 0, u: 0, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 1, u: 1, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 2, u: 1, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 3, u: 0, v: 1, alpha: 255),
    ]
    var faces = [
        LevelFace(
            corners: corners,
            flags: 0,
            portalIndex: nil,
            texture: light,
            allowsLightCorona: true
        ),
    ]
    var portals: [LevelPortal] = []
    if blocked {
        faces.append(
            LevelFace(
                corners: corners.map {
                    FaceCorner(
                        vertexIndex: $0.vertexIndex + 4,
                        u: $0.u,
                        v: $0.v,
                        alpha: $0.alpha
                    )
                },
                flags: 0,
                portalIndex: 0,
                texture: blocker
            )
        )
        portals.append(
            .init(flags: 1, faceIndex: 1, connectedRoom: 4, connectedPortal: 0)
        )
    }
    let room3 = LevelRoom(
        sourceIndex: 3,
        vertices: candidateVertices + blockerVertices,
        faces: faces,
        portals: portals
    )
    let room4 = LevelRoom(
        sourceIndex: 4,
        vertices: blockerVertices,
        faces: blocked ? [
            .init(
                corners: Array(corners.reversed()),
                flags: 0,
                portalIndex: 0,
                texture: blocker
            ),
        ] : [],
        portals: blocked ? [
            .init(flags: 1, faceIndex: 0, connectedRoom: 3, connectedPortal: 0),
        ] : []
    )
    let blockerModelSource = SourceResource(storedIndex: 3, sourceName: "blocker.oof")
    let blockerObject = PlacedObject(
        handle: 99,
        type: 2,
        storedID: 0,
        definition: nil,
        instanceName: nil,
        flags: 0,
        doorShields: nil,
        location: .room(3),
        position: .init(x: 0, y: 10, z: 0),
        orientation: .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        ),
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    )
    let blockerModel = CanonicalModel(
        source: blockerModelSource,
        collisionRadius: 2,
        submodels: [
            .init(
                sourceIndex: 0,
                parentIndex: nil,
                offset: .zero,
                vertices: [
                    .init(position: .init(x: -2, y: 0, z: -2), alpha: 1),
                    .init(position: .init(x: 2, y: 0, z: -2), alpha: 1),
                    .init(position: .init(x: 0, y: 0, z: 2), alpha: 1),
                ],
                faces: [],
                presentation: .standard
            ),
        ],
        bounds: .init(
            minimum: .init(x: -2, y: 0, z: -2),
            maximum: .init(x: 2, y: 0, z: 2)
        ),
        sourceArchive: "test.hog",
        sourceSHA256: String(repeating: "d", count: 64)
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: blocked ? [room3, room4] : [room3],
        terrain: base.terrain,
        objects: objectBlocked ? [blockerObject] : [],
        paths: [],
        goals: [],
        triggers: [],
        playerStartFlags: [],
        lightmaps: .init(pages: [], infos: []),
        presentationMaterials: [
            .init(
                texture: light,
                bitmapSourceName: "light.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                blend: .opaque,
                lightmapBlend: .none,
                waterProcedural: nil,
                lightCorona: .init(
                    assetIndex: 0,
                    tint: .init(x: 0.25, y: 0.5, z: 0.75),
                    blend: .additiveSourceAlpha(opacity: 102)
                ),
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "a", count: 64)
            ),
            .init(
                texture: blocker,
                bitmapSourceName: "blocker.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                blend: .opaque,
                lightmapBlend: .none,
                waterProcedural: nil,
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "b", count: 64)
            ),
        ],
        presentationCoronaAssets: [
            .init(
                source: .init(storedIndex: 0, sourceName: "flare"),
                bitmapSourceName: "flare.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "c", count: 64)
            ),
        ],
        models: objectBlocked ? [blockerModel] : [],
        objectPresentations: objectBlocked ? [
            .init(
                objectHandle: blockerObject.handle,
                primaryModel: blockerModelSource,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil
            ),
        ] : [],
        dependencyManifest: .init(current: [], historicalEagerBaseline: nil),
        sourceChunks: base.sourceChunks
    )
}

func makeSourceContainmentRoom(
    center: Vector3,
    texture: SourceResource
) -> LevelRoom {
    let vertices = [
        Vector3(x: center.x - 1, y: center.y - 1, z: center.z - 1),
        Vector3(x: center.x + 1, y: center.y - 1, z: center.z - 1),
        Vector3(x: center.x + 1, y: center.y + 1, z: center.z - 1),
        Vector3(x: center.x - 1, y: center.y + 1, z: center.z - 1),
        Vector3(x: center.x - 1, y: center.y - 1, z: center.z + 1),
        Vector3(x: center.x + 1, y: center.y - 1, z: center.z + 1),
        Vector3(x: center.x + 1, y: center.y + 1, z: center.z + 1),
        Vector3(x: center.x - 1, y: center.y + 1, z: center.z + 1),
    ]
    func face(_ indices: [Int]) -> LevelFace {
        LevelFace(
            corners: indices.enumerated().map { index, vertexIndex in
                FaceCorner(
                    vertexIndex: vertexIndex,
                    u: index == 1 || index == 2 ? 1 : 0,
                    v: index >= 2 ? 1 : 0,
                    alpha: 255
                )
            },
            flags: 0,
            portalIndex: nil,
            texture: texture
        )
    }
    return LevelRoom(
        sourceIndex: 3,
        vertices: vertices,
        faces: [
            face([0, 3, 7, 4]),
            face([1, 5, 6, 2]),
            face([0, 4, 5, 1]),
            face([3, 2, 6, 7]),
            face([0, 1, 2, 3]),
            face([4, 7, 6, 5]),
        ],
        portals: []
    )
}

private func alienForceFieldWaterDefinition() -> WaterProceduralDefinition {
    let raw: [(WaterProceduralElementKind, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)] = [
        (.heightBlob, 20, 40, 100, 127, 58, 186, 13),
        (.heightBlob, 20, 40, 100, 0, 59, 13, 240),
        (.heightBlob, 20, 40, 100, 0, 58, 240, 173),
        (.heightBlob, 20, 40, 100, 62, 1, 173, 186),
        (.heightBlob, 20, 40, 100, 62, 126, 186, 13),
        (.heightBlob, 20, 40, 100, 62, 3, 13, 240),
        (.noOp, 0, 1, 1, 91, 38, 240, 173),
    ]
    return WaterProceduralDefinition(
        evaluationIntervalSeconds: 0,
        lightingShift: 7,
        dampingShift: 6,
        elements: raw.map {
            WaterProceduralElement(
                kind: $0.0,
                frequency: $0.1,
                speed: $0.2,
                size: $0.3,
                x1: $0.4,
                y1: $0.5,
                x2: $0.6,
                y2: $0.7
            )
        }
    )
}

func makeSelectedRoomRenderLevel() -> Level {
    let base = makeMinimalCanonicalLevel()
    let forceField = SourceResource(storedIndex: 3, sourceName: "force-field")
    let wall = SourceResource(storedIndex: 0, sourceName: "wall")
    let quad = [
        FaceCorner(vertexIndex: 0, u: 1, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 1, u: 0, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 2, u: 0, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 3, u: 1, v: 0, alpha: 255),
    ]
    let reversedQuad = [quad[3], quad[2], quad[1], quad[0]]
    let forwardVertices = [
        Vector3(x: 1, y: 2, z: 1),
        Vector3(x: -1, y: 2, z: 1),
        Vector3(x: -1, y: 2, z: -1),
        Vector3(x: 1, y: 2, z: -1),
        Vector3(x: 0.5, y: 4, z: 0.5),
        Vector3(x: -0.5, y: 4, z: 0.5),
        Vector3(x: -0.5, y: 4, z: -0.5),
        Vector3(x: 0.5, y: 4, z: -0.5),
        Vector3(x: 0.5, y: 6, z: 0.5),
        Vector3(x: -0.5, y: 6, z: 0.5),
        Vector3(x: -0.5, y: 6, z: -0.5),
        Vector3(x: 0.5, y: 6, z: -0.5),
        Vector3(x: 1, y: -2, z: 1),
        Vector3(x: -1, y: -2, z: 1),
        Vector3(x: -1, y: -2, z: -1),
        Vector3(x: 1, y: -2, z: -1),
    ]
    func corners(_ offset: Int, reversed: Bool = false) -> [FaceCorner] {
        let source = reversed ? reversedQuad : quad
        return source.map {
            FaceCorner(
                vertexIndex: $0.vertexIndex + offset,
                u: $0.u,
                v: $0.v,
                alpha: $0.alpha
            )
        }
    }
    let room2 = LevelRoom(
        sourceIndex: 2,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(4), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(0, reversed: true), flags: 0, portalIndex: 1, texture: forceField),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 1, connectedPortal: 0),
            .init(flags: 1, faceIndex: 1, connectedRoom: 3, connectedPortal: 0),
        ]
    )
    let room3 = LevelRoom(
        sourceIndex: 3,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(0), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(12, reversed: true), flags: 0, portalIndex: 1, texture: forceField),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 2, connectedPortal: 1),
            .init(faceIndex: 1, connectedRoom: 4, connectedPortal: 0),
        ]
    )
    let room1 = LevelRoom(
        sourceIndex: 1,
        vertices: forwardVertices + [
            Vector3(x: 12, y: 6, z: 0.5),
            Vector3(x: 10, y: 6, z: 0.5),
            Vector3(x: 10, y: 6, z: -0.5),
            Vector3(x: 12, y: 6, z: -0.5),
        ],
        faces: [
            .init(corners: corners(4, reversed: true), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(8), flags: 0, portalIndex: nil, texture: wall),
            .init(corners: corners(16), flags: 0, portalIndex: nil, texture: wall),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 2, connectedPortal: 0),
        ]
    )
    let room4 = LevelRoom(
        sourceIndex: 4,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(12), flags: 0, portalIndex: 0, texture: forceField),
        ],
        portals: [.init(faceIndex: 0, connectedRoom: 3, connectedPortal: 1)]
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: [room1, room2, room3, room4],
        terrain: base.terrain,
        objects: [],
        paths: [],
        goals: [],
        triggers: [],
        playerStartFlags: [],
        lightmaps: .init(pages: [], infos: []),
        presentationMaterials: [
            .init(
                texture: forceField,
                bitmapSourceName: "force-field.ogf",
                image: .init(
                    width: 2,
                    height: 2,
                    rgba8: Data(repeating: 255, count: 16)
                ),
                blend: .additiveSourceAlpha(opacity: 178),
                lightmapBlend: .none,
                waterProcedural: nil,
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "a", count: 64)
            ),
            .init(
                texture: wall,
                bitmapSourceName: "wall.ogf",
                image: .init(
                    width: 2,
                    height: 2,
                    rgba8: Data(repeating: 255, count: 16)
                ),
                blend: .opaque,
                lightmapBlend: .multiply,
                waterProcedural: nil,
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "b", count: 64)
            ),
        ],
        dependencyManifest: .init(
            current: [
                .init(
                    category: "texture",
                    source: wall,
                    state: "presentation-payload-imported",
                    provenance: "test"
                ),
                .init(category: "texture", source: forceField, state: "presentation-payload-imported", provenance: "test"),
            ],
            historicalEagerBaseline: nil
        ),
        sourceChunks: base.sourceChunks
    )
}

func makeSliceSixObjectRenderLevel() -> Level {
    let base = makeSelectedRoomRenderLevel()
    let cameraOrigin = RoomCamera.trainingRoom3.position
    func translated(_ point: Vector3) -> Vector3 {
        .init(
            x: point.x + cameraOrigin.x,
            y: point.y + cameraOrigin.y,
            z: point.z + cameraOrigin.z
        )
    }
    let rooms = base.rooms.map { room in
        LevelRoom(
            sourceIndex: room.sourceIndex,
            name: room.name,
            pathPoint: translated(room.pathPoint),
            vertices: room.vertices.map(translated),
            faces: room.faces,
            portals: room.portals,
            flags: room.flags,
            pulseTime: room.pulseTime,
            pulseOffset: room.pulseOffset,
            mirrorFaceIndex: room.mirrorFaceIndex,
            door: room.door,
            volumeLights: room.volumeLights,
            fog: room.fog,
            ambientSoundPattern: room.ambientSoundPattern,
            reverb: room.reverb,
            damage: room.damage,
            damageType: room.damageType
        )
    }
    let modelTexture = SourceResource(storedIndex: 50, sourceName: "model-surface")
    let modelSources = [
        SourceResource(storedIndex: 0, sourceName: "PyroGL.OOF"),
        SourceResource(storedIndex: 1, sourceName: "PyroGLMed.OOF"),
        SourceResource(storedIndex: 2, sourceName: "PyroGLLo.OOF"),
        SourceResource(storedIndex: 3, sourceName: "PyroDeath.OOF"),
        SourceResource(storedIndex: 4, sourceName: "invisiblepowerup.OOF"),
    ]
    let shipSource = SourceResource(storedIndex: 0, sourceName: "Pyro-GL")
    let modelVertices = [
        ModelVertex(
            position: .init(x: -5, y: 0, z: -0.4),
            alpha: 1
        ),
        ModelVertex(
            position: .init(x: 5, y: 0, z: -0.4),
            alpha: 1
        ),
        ModelVertex(
            position: .init(x: 0, y: 0, z: 0.4),
            alpha: 1
        ),
    ]
    let modelCorners = [
        ModelFaceCorner(vertexIndex: 0, u: 0, v: 0),
        ModelFaceCorner(vertexIndex: 1, u: 1, v: 0),
        ModelFaceCorner(vertexIndex: 2, u: 0.5, v: 1),
    ]
    let models = modelSources.map { source in
        CanonicalModel(
            source: source,
            collisionRadius: source == modelSources[0]
                ? Float(bitPattern: 0x40d9_5869)
                : 1,
            submodels: [
                .init(
                    sourceIndex: 0,
                    parentIndex: 1,
                    offset: .zero,
                    vertices: modelVertices,
                    faces: [
                        .init(
                            normal: .init(x: 0, y: -1, z: 0),
                            corners: modelCorners,
                            material: .texture(modelTexture)
                        ),
                        .init(
                            normal: .init(x: 0, y: 1, z: 0),
                            corners: Array(modelCorners.reversed()),
                            material: .sourceColor(red: 32, green: 64, blue: 96)
                        ),
                    ],
                    presentation: .standard
                ),
                .init(
                    sourceIndex: 1,
                    parentIndex: nil,
                    offset: .init(x: 3, y: 0, z: 0),
                    vertices: [],
                    faces: [],
                    presentation: .standard
                ),
                .init(
                    sourceIndex: 2,
                    parentIndex: nil,
                    offset: .init(x: 3, y: 0, z: 0),
                    vertices: modelVertices,
                    faces: [
                        .init(
                            normal: .init(x: 0, y: -1, z: 0),
                            corners: modelCorners,
                            material: .sourceColor(red: 255, green: 0, blue: 255)
                        ),
                    ],
                    presentation: .custom
                ),
            ],
            bounds: .init(
                minimum: .init(x: -2, y: 0, z: -0.4),
                maximum: .init(x: 8, y: 0, z: 0.4)
            ),
            sourceArchive: base.source.profileFiles[0].relativePath,
            sourceSHA256: String(repeating: "e", count: 64)
        )
    }
    let identity = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: 1)
    )
    let invisibleDefinition = SourceResource(
        storedIndex: 67,
        sourceName: "Invisiblepowerup"
    )
    func object(
        handle: UInt32,
        type: UInt8,
        storedID: Int,
        name: String?,
        room: Int,
        position: Vector3
    ) -> PlacedObject {
        PlacedObject(
            handle: handle,
            type: type,
            storedID: storedID,
            definition: type == 7 ? invisibleDefinition : nil,
            instanceName: name,
            flags: 0,
            doorShields: nil,
            location: .room(room),
            position: position,
            orientation: identity,
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
    }
    let objects = [
        object(handle: 2_048, type: 4, storedID: 0, name: nil, room: 1,
               position: .init(x: 2_060.6497, y: -131.22517, z: 2_204.4216)),
        object(handle: 6_147, type: 7, storedID: 67, name: "StartCourse", room: 3,
               position: .init(x: 2_061.4604, y: -230.09009, z: 2_203.0276)),
        object(handle: 2_052, type: 4, storedID: 2, name: nil, room: 1,
               position: .init(x: 1_962.3759, y: -130.63771, z: 2_206.575)),
        object(handle: 18_441, type: 7, storedID: 67, name: "UpGoal", room: 1,
               position: .init(x: 2_060.6682, y: -25.897497, z: 2_204.6843)),
        object(handle: 12_299, type: 7, storedID: 67, name: "LeftGoal", room: 1,
               position: .init(x: 1_958.2805, y: -131.22517, z: 2_205.8071)),
        object(handle: 12_300, type: 7, storedID: 67, name: "StartGoal", room: 1,
               position: .init(x: 2_062.7678, y: -134.19601, z: 2_201.679)),
        object(handle: 12_301, type: 7, storedID: 67, name: "ForwardGoal", room: 1,
               position: .init(x: 2_060.4836, y: -131.22517, z: 2_310.928)),
    ]
    let pyroPresentation = ObjectPresentationReference(
        objectHandle: 2_048,
        primaryModel: modelSources[0],
        mediumModel: modelSources[1],
        lowModel: modelSources[2],
        dyingModel: modelSources[3],
        mediumDistance: 75,
        lowDistance: 100
    )
    let objectPresentations = [pyroPresentation,
        .init(
            objectHandle: 2_052,
            primaryModel: modelSources[0],
            mediumModel: modelSources[1],
            lowModel: modelSources[2],
            dyingModel: modelSources[3],
            mediumDistance: 75,
            lowDistance: 100
        ),
    ] + objects.filter { $0.type == 7 }.map {
        ObjectPresentationReference(
            objectHandle: $0.handle,
            primaryModel: modelSources[4],
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        )
    }
    let modelMaterial = PresentationMaterial(
        texture: modelTexture,
        bitmapSourceName: "model-surface.ogf",
        image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 128])),
        blend: .sourceAlpha(opacity: 255),
        lightmapBlend: .none,
        waterProcedural: nil,
        sourceArchive: base.source.profileFiles[0].relativePath,
        sourceSHA256: String(repeating: "f", count: 64)
    )
    let dependencies = base.dependencyManifest.current + [
        DependencyRecord(
            category: "object-definition",
            source: invisibleDefinition,
            state: "identity-recorded",
            provenance: "synthetic Slice 6 fixture"
        ),
        DependencyRecord(
            category: "texture",
            source: modelTexture,
            state: "presentation-payload-imported",
            provenance: "synthetic Slice 6 fixture"
        ),
    ] + modelSources.map {
        DependencyRecord(
            category: "model",
            source: $0,
            state: "presentation-payload-imported",
            provenance: "synthetic Slice 6 fixture"
        )
    } + [
        DependencyRecord(
            category: "ship-definition",
            source: shipSource,
            state: "canonical-typed-definition",
            provenance: "synthetic Slice 9 fixture"
        ),
    ]
    let ship = CanonicalShipDefinition(
        source: shipSource,
        primaryModel: modelSources[0],
        presentationSize: 6.676084041595459,
        physics: .init(
            mass: 30,
            drag: 90,
            fullThrust: 5_400,
            behaviors: [.turnroll, .wiggle, .usesThrust],
            rotationalDrag: 225,
            fullRotationalThrust: 6_860_000,
            numberOfBounces: -1,
            initialForwardVelocity: 0,
            initialAngularVelocity: .zero,
            wiggleAmplitude: 0.17,
            wigglesPerSecond: 0.9,
            coefficientOfRestitution: 1,
            hitDieDot: -1,
            maximumTurnrollRate: 8_000,
            turnrollRatio: 0.13
        )
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: rooms,
        terrain: base.terrain,
        objects: objects,
        paths: base.paths,
        goals: base.goals,
        triggers: base.triggers,
        playerStartFlags: [0, 0],
        lightmaps: base.lightmaps,
        presentationMaterials: base.presentationMaterials + [modelMaterial],
        models: models,
        shipDefinitions: [ship],
        defaultPlayerBinding: .init(
            playerID: 0,
            objectHandle: 2_048,
            ship: shipSource
        ),
        objectPresentations: objectPresentations,
        dependencyManifest: .init(
            current: dependencies,
            historicalEagerBaseline: nil
        ),
        sourceChunks: base.sourceChunks
    )
}

func makeSliceTenContactLevel(clearance: Float = 20) -> Level {
    let level = makeSliceSixObjectRenderLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z + clearance
    let vertices = room.vertices + [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let contactRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    var rooms = level.rooms
    rooms[roomIndex] = contactRoom
    return replacing(level, rooms: rooms)
}

func makeSliceThirteenWiggleLevel(blocked: Bool = false) -> Level {
    let base = makeSliceSixObjectRenderLevel()
    let radius = defaultPlayerView(in: base).collisionRadius
    let level = blocked
        ? makeSliceTenContactLevel(clearance: radius + 0.01)
        : base
    var objects = level.objects
    let playerIndex = objects.firstIndex { $0.handle == 2_048 }!
    objects[playerIndex].orientation = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 0, z: 1),
        forward: .init(x: 0, y: -1, z: 0)
    )
    return replacing(level, objects: objects)
}

func makeSliceThirteenPortalWiggleLevel() -> Level {
    let level = makeSliceThirteenWiggleLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z + 0.04
    let portalVertices = [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
    ]
    let corners = (0..<4).map {
        FaceCorner(
            vertexIndex: firstVertex + $0,
            u: 0,
            v: 0,
            alpha: 255
        )
    }
    let portalFace = LevelFace(
        corners: corners,
        flags: 0,
        portalIndex: room.portals.count,
        texture: room.faces[0].texture
    )
    let sourceRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: room.vertices + portalVertices,
        faces: room.faces + [portalFace],
        portals: room.portals + [
            .init(
                faceIndex: room.faces.count,
                connectedRoom: 99,
                connectedPortal: 0
            ),
        ],
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    let connectedRoom = LevelRoom(
        sourceIndex: 99,
        vertices: portalVertices,
        faces: [
            .init(
                corners: corners.reversed().map {
                    FaceCorner(
                        vertexIndex: $0.vertexIndex - firstVertex,
                        u: $0.u,
                        v: $0.v,
                        alpha: $0.alpha
                    )
                },
                flags: 0,
                portalIndex: 0,
                texture: room.faces[0].texture
            ),
        ],
        portals: [
            .init(faceIndex: 0, connectedRoom: 1, connectedPortal: room.portals.count),
        ]
    )
    var rooms = level.rooms
    rooms[roomIndex] = sourceRoom
    rooms.append(connectedRoom)
    return replacing(level, rooms: rooms)
}

func makeSliceElevenCornerLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let x = player.position.x + clearance
    let vertices = room.vertices + [
        Vector3(x: x, y: player.position.y - 20, z: player.position.z - 20),
        Vector3(x: x, y: player.position.y - 20, z: player.position.z + 20),
        Vector3(x: x, y: player.position.y + 20, z: player.position.z + 20),
        Vector3(x: x, y: player.position.y + 20, z: player.position.z - 20),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let cornerRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    var rooms = level.rooms
    rooms[roomIndex] = cornerRoom
    return replacing(level, rooms: rooms)
}

func makeSliceElevenForceFieldLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let texture = level.rooms.first { $0.sourceIndex == 1 }!.faces.last!.texture
    return replacing(
        level,
        surfacePhysics: level.surfacePhysics.map {
            $0.texture == texture
                ? .init(texture: $0.texture, behavior: .forceField)
                : $0
        }
    )
}

func makeSliceElevenTrappedLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z - clearance
    let vertices = room.vertices + [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let trappedRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    var rooms = level.rooms
    rooms[roomIndex] = trappedRoom
    return replacing(level, rooms: rooms)
}
