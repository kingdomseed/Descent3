import XCTest

// The player's input state (PlayerInput.swift): held axes and their ramp,
// the keyboard, controller, and mouse carriers, and the one-shot requests
// (controls.cpp).
final class PlayerInputTests: XCTestCase {
    func testInputSnapshotRampsHeldAxesAndClearsInactiveGameplay() {
        var ramp = PlayerInputRamp(rampDuration: 0.5)

        let first = ramp.snapshot(
            held: .init(forward: 1, sideways: -1), frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(first.forward, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(first.sideways, -0.2, accuracy: 0.000_001)
        XCTAssertEqual(first.vertical, 0)
        XCTAssertEqual(first.pitch, 0)
        XCTAssertEqual(first.yaw, 0)
        XCTAssertEqual(first.roll, 0)

        let second = ramp.snapshot(
            held: .init(forward: 1, sideways: -1), frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(second.forward, 0.4, accuracy: 0.000_001)
        XCTAssertEqual(second.sideways, -0.4, accuracy: 0.000_001)

        let released = ramp.snapshot(
            held: .zero, frameDuration: 0.1, gameplayIsActive: true
        )
        XCTAssertEqual(released, .zero)
        let restarted = ramp.snapshot(
            held: .init(forward: 1), frameDuration: 0.1, gameplayIsActive: true
        )
        XCTAssertEqual(restarted.forward, 0.2, accuracy: 0.000_001)
        let reversed = ramp.snapshot(
            held: .init(forward: -1), frameDuration: 0.1, gameplayIsActive: true
        )
        XCTAssertEqual(reversed.forward, -0.4, accuracy: 0.000_001)

        XCTAssertEqual(
            ramp.snapshot(
                held: .init(forward: 1, sideways: 1), frameDuration: 0.1,
                gameplayIsActive: false
            ),
            .zero
        )
        XCTAssertEqual(
            ramp.snapshot(
                held: .zero, frameDuration: 0.1, gameplayIsActive: true
            ),
            .zero
        )

        var immediate = PlayerInputRamp(rampDuration: 0)
        XCTAssertEqual(
            immediate.snapshot(
                held: .init(forward: -0.01, sideways: 0.25), frameDuration: 0,
                gameplayIsActive: true
            ),
            .init(forward: -1, sideways: 1)
        )
    }

    func testPlayerInputStateCombinesKeyboardControllerAndOneShotMousePerAxis() {
        var input = PlayerInputState(rampDuration: 0.35)
        input.setHeld(
            .init(
                forward: 1, sideways: -1, vertical: 1, pitch: -1, yaw: 1,
                roll: -1
            )
        )
        input.setController(
            .init(
                forward: 0.2, sideways: 0.1, vertical: 0.3, pitch: 0.2,
                yaw: 0.4, roll: 0.1
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
            mouseLook.directLookPitchRadians, Float.pi / 1_000,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            mouseLook.directLookYawRadians, Float.pi / 500, accuracy: 0.000_001
        )
        let drained = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(drained.directLookPitchRadians, 0)
        XCTAssertEqual(drained.directLookYawRadians, 0)
    }

    func testPlayerInputStateClearsAndRebasesAcrossFocusChanges() {
        let simulation = GameSession(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 10
        )
        var input = PlayerInputState(rampDuration: 0.5)
        input.setHeld(.init(forward: 1))
        input.setController(.init(sideways: 0.75, roll: -0.5))
        input.accumulateMouseDelta(x: 25, y: -10)
        XCTAssertEqual(
            input.snapshot(frameDuration: 0.1).forward, 0.2, accuracy: 0.000_001
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
            0.016, accuracy: 0.000_001
        )
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
