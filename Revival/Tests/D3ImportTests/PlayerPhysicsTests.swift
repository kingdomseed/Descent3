import XCTest

// The player's flight, afterburner, wiggle, and wall contacts
// (PlayerSimulationPhysics.swift: physics.cpp, Player.cpp, controls.cpp).

final class PlayerPhysicsTests: XCTestCase {
    func testPlayerSimulationPreservesPriorFrameTimingAndNestedPauseRebasing() {
        let simulation = GameSession(
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
            let simulation = GameSession(
                level: makeSliceSixObjectRenderLevel(),
                presentationReadyTimestamp: 0
            )
            var timestamp = 0.0
            var frame: PlayerSimulationFrame?
            for measuredDelta in measuredDeltas {
                timestamp += measuredDelta
                frame = simulation.update(
                    at: timestamp, input: .init(forward: 1)
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
            fixed.playerView.camera.position.z, accuracy: 0.000_3
        )
        XCTAssertEqual(variable.playerView.roomSourceIndex, fixed.playerView.roomSourceIndex)
        XCTAssertEqual(variable.wallContact, fixed.wallContact)
    }

    func testSelectedVariableDeltaKeepsReachedCarrierCollisionBoostAndWiggleWithinCadenceTolerances() throws {
        let jitter = [0.018, 0.044, 0.031, 0.057, 0.016]
        let cadence120 = Array(repeating: 1.0 / 120.0, count: 19)

        func runCarrierCollision(measuredDeltas: [Double]) -> (
            frame: PlayerSimulationFrame, input: InputSnapshot,
            firstContact: IndoorWallContact?
        ) {
            let base = makeSliceSixObjectRenderLevel()
            let clearance = defaultPlayerView(in: base).collisionRadius + 0.5
            let simulation = GameSession(
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
            variableCarrier.input.forward, fixedCarrier.input.forward,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            variableCarrier.input.sideways, fixedCarrier.input.sideways,
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
            variableCarrier.frame.velocity.x, fixedCarrier.frame.velocity.x,
            accuracy: 2.6
        )
        XCTAssertEqual(
            variableCarrier.frame.playerView.camera.position.x,
            fixedCarrier.frame.playerView.camera.position.x, accuracy: 0.24
        )

        func runBoostAndWiggle(
            level: Level, measuredDeltas: [Double], input: InputSnapshot
        ) -> (frame: PlayerSimulationFrame, fuel: Float, falloff: Float) {
            let simulation = GameSession(
                level: level, presentationReadyTimestamp: 0
            )
            simulation.setIndoorAutoLevelMode(.off)
            var timestamp = 0.0
            var frame: PlayerSimulationFrame?
            for measuredDelta in measuredDeltas {
                timestamp += measuredDelta
                frame = simulation.update(at: timestamp, input: input)
            }
            return (
                frame!, simulation.afterburnerFuel, simulation.wiggleFalloff
            )
        }

        let variableBoost = runBoostAndWiggle(
            level: makeSliceThirteenWiggleLevel(), measuredDeltas: jitter,
            input: .init(afterburner: 1)
        )
        let fixedBoost = runBoostAndWiggle(
            level: makeSliceThirteenWiggleLevel(), measuredDeltas: cadence120,
            input: .init(afterburner: 1)
        )
        XCTAssertEqual(variableBoost.fuel, fixedBoost.fuel, accuracy: 0.000_004)
        XCTAssertEqual(variableBoost.falloff, fixedBoost.falloff, accuracy: 0.000_001)
        XCTAssertEqual(
            variableBoost.frame.velocity.z, fixedBoost.frame.velocity.z,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            variableBoost.frame.playerView.camera.position.z,
            fixedBoost.frame.playerView.camera.position.z, accuracy: 0.001_6
        )

        let variablePortal = runBoostAndWiggle(
            level: makeSliceThirteenPortalWiggleLevel(), measuredDeltas: jitter,
            input: .zero
        )
        let fixedPortal = runBoostAndWiggle(
            level: makeSliceThirteenPortalWiggleLevel(),
            measuredDeltas: cadence120, input: .zero
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
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016, input: .init(forward: 1, sideways: 1)
        )

        let decay = exp(-3.0 * 0.1)
        let expectedVelocity = Float(60 * (1 - decay))
        let expectedDisplacement = Float(60 * 0.1 - 20 * (1 - decay))
        XCTAssertEqual(frame.velocity.x, expectedVelocity, accuracy: 0.000_01)
        XCTAssertEqual(frame.velocity.y, 0, accuracy: 0.000_01)
        XCTAssertEqual(frame.velocity.z, expectedVelocity, accuracy: 0.000_01)
        XCTAssertEqual(
            frame.playerView.camera.position.x, start.x + expectedDisplacement,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.playerView.camera.position.z, start.z + expectedDisplacement,
            accuracy: 0.000_1
        )
    }

    func testPlayerSimulationUsesSampledBasisThenCommitsRotationalFlight() {
        let level = makeSliceSixObjectRenderLevel()
        let start = defaultPlayerView(in: level).camera.position
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016, input: .init(vertical: 1, pitch: 0.75, yaw: 1)
        )

        XCTAssertEqual(frame.angularVelocity.x, 12_065.218, accuracy: 0.001)
        XCTAssertEqual(frame.angularVelocity.y, 16_086.958, accuracy: 0.001)
        XCTAssertEqual(frame.angularVelocity.z, 0, accuracy: 0.001)
        XCTAssertEqual(frame.turnrollFixedAngle, -800, accuracy: 0.001)

        let camera = frame.playerView.camera
        XCTAssertEqual(
            camera.target.x - camera.position.x, 0.152_529_84, accuracy: 0.000_1
        )
        XCTAssertEqual(
            camera.target.y - camera.position.y, -0.115_366_35,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            camera.target.z - camera.position.z, 0.981_542_3, accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.playerView.camera.position.x, start.x, accuracy: 0.000_1
        )
        XCTAssertGreaterThan(frame.playerView.camera.position.y, start.y)
        XCTAssertEqual(
            frame.playerView.camera.position.z, start.z, accuracy: 0.000_1
        )
    }

    func testPlayerSimulationAppliesIsolatedRollToAngularVelocityAndCameraUp() {
        let simulation = GameSession(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        let start = defaultPlayerView(in: simulation.runtimeLevel)

        let frame = simulation.update(at: 0.016, input: .init(roll: 1))

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

    func testSustainedPrimaryFirePreventsPitchAutolevelUntilRecentFireExpires() {
        let simulation = GameSession(
            level: makeFastPlayerHeadlightLevel(includesVisibleObject: false)
                .addingFixturePlayerWeapons(),
            presentationReadyTimestamp: 0
        )
        for frame in 1...125 {
            _ = simulation.update(at: Double(frame) * 0.016, input: .zero)
        }
        _ = simulation.update(
            at: 2.016,
            input: .init(directLookPitchRadians: 0.25, firesPrimaryWeapon: true)
        )
        for frame in 127...250 {
            _ = simulation.update(
                at: Double(frame) * 0.016, input: .init(firesPrimaryWeapon: true)
            )
        }
        let firingPlayer = simulation.world.testPlayerObject
        XCTAssertGreaterThan(firingPlayer.weaponBatteries[0].lastFireTime, 3.5)
        XCTAssertLessThan(simulation.energy, 99.85)
        XCTAssertEqual(abs(firingPlayer.orientation.forward.y), sin(0.25), accuracy: 0.000_1)

        for frame in 251...310 {
            _ = simulation.update(at: Double(frame) * 0.016, input: .zero)
        }
        XCTAssertEqual(
            abs(simulation.world.testPlayerObject.orientation.forward.y),
            sin(0.25), accuracy: 0.000_1
        )
        for frame in 311...375 {
            _ = simulation.update(at: Double(frame) * 0.016, input: .zero)
        }
        XCTAssertLessThan(
            abs(simulation.world.testPlayerObject.orientation.forward.y),
            sin(0.25)
        )
    }

    func testIndoorNewPlayerAutolevelCanBeTurnedOffAfterSourceDelay() {
        let active = GameSession(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        let disabled = GameSession(
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
        let simulation = GameSession(
            level: makeSliceTenContactLevel(), presentationReadyTimestamp: 0
        )
        var timestamp = 0.1
        var contactFrame: PlayerSimulationFrame?
        for _ in 0..<100 {
            let frame = simulation.update(
                at: timestamp, input: .init(forward: 1)
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
            simulation.runtimeLevel.objects.first {
                $0.handle == frame.playerView.objectHandle
            }
        )
        XCTAssertEqual(player.position, frame.playerView.camera.position)
        XCTAssertEqual(player.location, .room(frame.playerView.roomSourceIndex))
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
        let boosted = GameSession(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        let ordinary = GameSession(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )

        let boostedFrame = boosted.update(at: 0.1, input: .init(afterburner: 1))
        let ordinaryFrame = ordinary.update(at: 0.1, input: .init(forward: 1))

        XCTAssertTrue(boosted.afterburnerIsActive)
        XCTAssertEqual(boosted.afterburnerFuel, 4.9, accuracy: 0.000_001)
        XCTAssertEqual(boosted.energy, 100)
        XCTAssertEqual(boosted.afterburnerMagnitude, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(
            boostedFrame.velocity.z, ordinaryFrame.velocity.z * 1.6 * 1.8,
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
        func thrustRatio(afterburnerFrames: Int) -> Float {
            let simulations = (0..<3).map { _ in
                GameSession(
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
                        at: timestamp, input: .init(afterburner: 0.000_001)
                    )
                }
            }
            timestamp += 0.125
            let boosted = simulations[0].update(
                at: timestamp, input: .init(afterburner: 1)
            )
            let ordinary = simulations[1].update(
                at: timestamp, input: .init(forward: 1)
            )
            let coasting = simulations[2].update(at: timestamp, input: .zero)
            return (boosted.velocity.z - coasting.velocity.z)
                / (ordinary.velocity.z - coasting.velocity.z)
        }

        XCTAssertEqual(thrustRatio(afterburnerFrames: 4), 1.6, accuracy: 0.000_01)
        XCTAssertEqual(
            thrustRatio(afterburnerFrames: 6), 1.6 * 1.4, accuracy: 0.000_01
        )
        XCTAssertEqual(thrustRatio(afterburnerFrames: 8), 1.6, accuracy: 0.000_01)
    }

    func testReleasedAfterburnerLinearPunchPreservesDoublePromotion() {
        XCTAssertEqual(
            sourceAfterburnerForwardControl(
                afterburner: 1, fuel: 4.400_000_1
            ).bitPattern,
            0x4027_ef9e
        )
        XCTAssertEqual(
            sourceAfterburnerForwardControl(
                afterburner: 1, fuel: Float(bitPattern: 0x408a_0003)
            ).bitPattern,
            0x4019_99a9
        )

        let simulation = GameSession(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        for frame in 1...6 {
            _ = simulation.update(
                at: Double(frame) * 0.1, input: .init(afterburner: 0.000_001)
            )
        }

        let ship = simulation.level.shipDefinitions.first {
            $0.source == simulation.level.defaultPlayerBinding!.ship
        }!
        let fuel = simulation.afterburnerFuel
        let punch = Float(1 + ((Double(fuel) - 4) / 0.5) * 0.8)
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

        let frame = simulation.update(at: 0.7, input: .init(afterburner: 1))

        XCTAssertEqual(frame.velocity.z.bitPattern, expectedVelocity.bitPattern)
    }

    func testReleasedNoCoolerRechargeConsumesEnergyAboveThreshold() {
        let simulation = GameSession(
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
            _ = simulation.update(at: timestamp, input: .init(afterburner: 1))
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
        let simulation = GameSession(
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
        let stationary = GameSession(
            level: makeSliceThirteenWiggleLevel(), presentationReadyTimestamp: 0
        )
        let thrusting = GameSession(
            level: makeSliceThirteenWiggleLevel(), presentationReadyTimestamp: 0
        )
        let start = defaultPlayerView(in: stationary.level).camera.position

        let stationaryFrame = stationary.update(at: 0.1, input: .zero)
        let thrustingFrame = thrusting.update(at: 0.1, input: .init(forward: 1))

        XCTAssertEqual(stationary.wiggleFalloff, 0)
        XCTAssertEqual(thrusting.wiggleFalloff, 0.05, accuracy: 0.000_001)
        XCTAssertEqual(
            stationaryFrame.playerView.camera.position.z - start.z,
            0.091_064_45, accuracy: 0.000_001
        )
        XCTAssertEqual(
            thrustingFrame.playerView.camera.position.z - start.z, 0.086_425_78,
            accuracy: 0.000_001
        )
    }

    func testPyroWiggleUsesReleasedFloatSineTableQuantization() {
        var level = makeSliceThirteenWiggleLevel()
        var objects = level.objects
        let playerIndex = objects.firstIndex { $0.handle == 2_048 }!
        objects[playerIndex].position = .zero
        level = replacing(level, objects: objects)
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0
        )

        _ = simulation.update(at: 0.1, input: .zero)
        let frame = simulation.update(at: 0.2, input: .zero)

        XCTAssertEqual(
            frame.playerView.camera.position.z.bitPattern, 0x3e3a_8b68
        )
    }

    func testPyroWiggleUsesPostMouselookPreRotationUpAxis() {
        let simulation = GameSession(
            level: makeSliceThirteenWiggleLevel(), presentationReadyTimestamp: 0
        )
        let start = defaultPlayerView(in: simulation.runtimeLevel).camera.position

        let frame = simulation.update(
            at: 0.1, input: .init(directLookPitchRadians: .pi / 2)
        )

        XCTAssertLessThan(frame.playerView.camera.position.y, start.y - 0.09)
        XCTAssertEqual(
            frame.playerView.camera.position.z, start.z, accuracy: 0.000_01
        )
    }

    func testPyroWiggleRetainsTenPercentMovementAtFullFalloff() {
        let simulation = GameSession(
            level: makeSliceThirteenWiggleLevel(), presentationReadyTimestamp: 0
        )
        simulation.setIndoorAutoLevelMode(.off)
        var timestamp = 0.1

        for _ in 0..<20 {
            _ = simulation.update(
                at: timestamp, input: .init(afterburner: 0.000_02)
            )
            timestamp += 0.1
        }

        let priorPosition = defaultPlayerView(in: simulation.runtimeLevel).camera.position
        let frame = simulation.update(
            at: timestamp, input: .init(afterburner: 0.000_02)
        )

        XCTAssertEqual(simulation.wiggleFalloff, 1)
        XCTAssertGreaterThan(
            abs(frame.playerView.camera.position.z - priorPosition.z), 0.000_1
        )
    }

    func testPyroWiggleCommitsReturnedRoomAfterPortalCrossing() {
        let simulation = GameSession(
            level: makeSliceThirteenPortalWiggleLevel(),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(at: 0.1, input: .zero)

        XCTAssertEqual(frame.playerView.roomSourceIndex, 99)
        XCTAssertEqual(
            simulation.runtimeLevel.objects.first { $0.handle == 2_048 }!.location,
            .room(99)
        )
    }

    func testPyroWiggleRefusesMovementOnIndoorContact() {
        let open = GameSession(
            level: makeSliceThirteenWiggleLevel(), presentationReadyTimestamp: 0
        )
        let blocked = GameSession(
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
        let simulation = GameSession(
            level: makeSliceTenContactLevel(clearance: clearance),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016, input: .init(forward: 1, sideways: 1)
        )
        let contact = try XCTUnwrap(frame.wallContact)

        XCTAssertGreaterThan(
            frame.playerView.camera.position.x, contact.contactPoint.x + 0.1
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
                x: view.camera.position.x + 20, y: view.camera.position.y,
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
        let simulation = GameSession(
            level: makeSliceElevenForceFieldLevel(clearance: 20),
            presentationReadyTimestamp: 0
        )
        var timestamp = 0.1
        var contactFrame: PlayerSimulationFrame?
        for _ in 0..<100 {
            let frame = simulation.update(
                at: timestamp, input: .init(forward: 1)
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
        let simulation = GameSession(
            level: makeSliceTenContactLevel(clearance: clearance),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016, input: .init(forward: 0.001_351)
        )
        let contact = try XCTUnwrap(frame.wallContact)
        let attemptedDistance = Float(60 * 0.1 - 20 * (1 - exp(-3.0 * 0.1)))
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
        let simulation = GameSession(
            level: makeSliceElevenTrappedLevel(clearance: clearance),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(at: 0.1, input: .init(forward: 1))

        XCTAssertNotNil(frame.wallContact)
        XCTAssertEqual(frame.velocity, .zero)
    }

    func testReciprocalPortalComponentIgnoresPresentationPassabilityAndDisconnectedRooms() {
        let level = makeSelectedRoomRenderLevel()
        let disconnected = LevelRoom(
            sourceIndex: 99, vertices: [], faces: [], portals: []
        )

        XCTAssertEqual(
            reciprocalPortalComponent(
                rooms: level.rooms + [disconnected], startRoomSourceIndex: 1
            ),
            Set([1, 2, 3, 4])
        )
    }

    /// do_physics_sim checks objects on each move it makes
    /// (physics.cpp:986-1080): after a wall contact the rest of the move
    /// starts at the contact. A pickup that the straight start-to-final
    /// chord passes, but neither actual move segment does, is not touched;
    /// one on the first segment is (GenericScript's pickup, generic.cpp:310).
    func testPickupUsesTheMoveSegmentsAroundAWallContact() throws {
        func missesSphere(
            start: Vector3, end: Vector3, center: Vector3, radius: Float
        ) -> Bool {
            let movement = Vector3(
                x: end.x - start.x, y: end.y - start.y, z: end.z - start.z
            )
            let toCenter = Vector3(
                x: center.x - start.x, y: center.y - start.y,
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
                x: center.x - closest.x, y: center.y - closest.y,
                z: center.z - closest.z
            )
            return distance.x * distance.x
                + distance.y * distance.y
                + distance.z * distance.z
                > radius * radius
        }

        let contactLevel = makeSliceTenContactLevel(clearance: 20)
        let baseline = GameSession(
            level: contactLevel, presentationReadyTimestamp: 0
        )
        _ = baseline.update(at: 2, input: .zero)
        let start = defaultPlayerView(in: baseline.runtimeLevel).camera.position
        let baselineFrame = baseline.update(
            at: 4, input: .init(forward: 1, sideways: 1)
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
                start: start, end: contactCenter, center: candidate,
                radius: pickupRadius
            ),
            missesSphere(
                start: contactCenter, end: final, center: candidate,
                radius: pickupRadius
            ) {
                falseChordPoint = candidate
                break
            }
        }

        let pickupPosition = try XCTUnwrap(falseChordPoint)

        /// A slice-ten session with one runtime Invulnerability powerup of
        /// size 0.01 at `position` in the player's room.
        func session(pickupAt position: Vector3) throws
            -> (GameSession, ObjectHandle)
        {
            var info = fixtureGenericPowerupInfo("Invulnerability")
            info = CanonicalObjectInfo(
                name: info.name, type: info.type, flags: info.flags, size: 0.01,
                hitPoints: info.hitPoints, lightDistance: info.lightDistance,
                lighting: info.lighting, ai: nil, weaponBatteries: []
            )
            var level = contactLevel.addingObjectInfo(info)
            let last = level.objectInfos!.count - 1
            level.objectInfos?[last].moduleName = GenericModule.moduleName
            let session = GameSession(level: level, presentationReadyTimestamp: 0)
            _ = session.update(at: 2, input: .zero)
            let pickup = session.world.objCreate(
                type: .powerup, id: level.objectInfos!.count - 1,
                room: baselineFrame.playerView.roomSourceIndex,
                position: position, orientation: nil, parent: .none,
                level: level
            )
            XCTAssertEqual(
                session.world.objects[pickup]?.scripts?.defaultScript,
                .genericPowerup
            )
            return (session, pickup)
        }

        let (missed, missedPickup) = try session(pickupAt: pickupPosition)
        _ = missed.update(at: 4, input: .init(forward: 1, sideways: 1))
        XCTAssertNil(missed.world.playerInvulnerableTime)
        XCTAssertNotNil(missed.world.objects[missedPickup])
        XCTAssertTrue(missed.world.playerInventory.items.isEmpty)

        // On the first segment, near the wall contact, it is touched.
        let onPath = Vector3(
            x: (start.x + contactCenter.x) / 2,
            y: (start.y + contactCenter.y) / 2,
            z: (start.z + contactCenter.z) / 2
        )
        let (touched, touchedPickup) = try session(pickupAt: onPath)
        _ = touched.update(at: 4, input: .init(forward: 1, sideways: 1))
        XCTAssertNotNil(touched.world.playerInvulnerableTime)
        XCTAssertNil(touched.world.objects[touchedPickup])
    }
}
