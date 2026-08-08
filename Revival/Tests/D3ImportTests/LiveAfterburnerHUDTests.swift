import AppKit
import XCTest

extension WorldRenderingTests {
    @MainActor
    func testNormalShiftUpdatesTheLiveTextAfterburnerHUD() throws {
        func afterburnerItem(in view: RevivalGameplayView) throws -> NSTextField {
            try XCTUnwrap(
                view.subviews.compactMap { $0 as? NSTextField }.first {
                    $0.accessibilityIdentifier() == "Live Afterburner HUD"
                },
                "ordinary Training play must expose one identified Afterburner item"
            )
        }

        func frameFuel(_ frame: PlayerSimulationFrame) throws -> Float {
            try XCTUnwrap(
                Mirror(reflecting: frame).children.first {
                    $0.label == "afterburnerFuel"
                }?.value as? Float,
                "the final frame must carry the sole post-update Afterburner fuel"
            )
        }

        func shiftEvent(
            modifiers: NSEvent.ModifierFlags,
            timestamp: TimeInterval
        ) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(
                with: .flagsChanged,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: timestamp,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: 56
            ))
        }

        func restoreControlsThroughNormalTraining(
            in simulation: PlayerSimulation,
            startingAt timestamp: inout Double
        ) -> PlayerSimulationFrame {
            var frame = simulation.update(at: timestamp, input: .zero)
            for fires in [true, false, true, false, true, false, true] {
                timestamp += fires ? 0.01 : 0.25
                frame = simulation.update(
                    at: timestamp,
                    input: .init(firesPrimaryWeapon: fires)
                )
            }
            return frame
        }

        var level = makeTrainingRobotGuidebotLevel()
        let player = try XCTUnwrap(level.objects.first { $0.handle == 2_048 })
        let robotIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 4_112 }
        )
        level.objects[robotIndex].position = Vector3(
            x: player.position.x + player.orientation.forward.x * 20,
            y: player.position.y + player.orientation.forward.y * 20,
            z: player.position.z + player.orientation.forward.z * 20
        )
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        var timestamp = 0.1
        let controlsRestored = restoreControlsThroughNormalTraining(
            in: simulation,
            startingAt: &timestamp
        )
        XCTAssertEqual(controlsRestored.enabledPlayerControls, .all)
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == 4_112
        })

        timestamp += 0.1
        let freshFrame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(simulation.afterburnerFuel, 5)

        var playerInput = PlayerInputState(rampDuration: 0)
        let view = RevivalGameplayView(
            frame: NSRect(x: 0, y: 0, width: 1_280, height: 720),
            device: nil
        )
        view.heldInputChanged = { playerInput.setHeld($0) }
        view.setGameplayActive(true)
        view.flagsChanged(with: try shiftEvent(
            modifiers: [.shift],
            timestamp: timestamp + 0.01
        ))
        timestamp += 0.1
        let shiftedFrame = simulation.update(
            at: timestamp,
            input: playerInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(simulation.afterburnerFuel, 4.9, accuracy: 0.000_001)

        view.flagsChanged(with: try shiftEvent(
            modifiers: [],
            timestamp: timestamp + 0.01
        ))
        timestamp += 0.1
        let rechargedFrame = simulation.update(
            at: timestamp,
            input: playerInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(simulation.afterburnerFuel, 5, accuracy: 0.000_001)
        XCTAssertEqual(simulation.energy, 99.3, accuracy: 0.000_01)

        let truncationSimulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        var truncationTimestamp = 0.1
        let truncationControls = restoreControlsThroughNormalTraining(
            in: truncationSimulation,
            startingAt: &truncationTimestamp
        )
        XCTAssertEqual(truncationControls.enabledPlayerControls, .all)
        truncationTimestamp += 0.1
        _ = truncationSimulation.update(
            at: truncationTimestamp,
            input: .zero
        )
        truncationTimestamp += 0.06
        _ = truncationSimulation.update(
            at: truncationTimestamp,
            input: .zero
        )
        var truncationInput = PlayerInputState(rampDuration: 0)
        let truncationView = RevivalGameplayView(frame: view.frame, device: nil)
        truncationView.heldInputChanged = { truncationInput.setHeld($0) }
        truncationView.setGameplayActive(true)
        truncationView.flagsChanged(with: try shiftEvent(
            modifiers: [.shift],
            timestamp: truncationTimestamp + 0.01
        ))
        truncationTimestamp += 0.1
        let truncationFrame = truncationSimulation.update(
            at: truncationTimestamp,
            input: truncationInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(
            truncationSimulation.afterburnerFuel,
            4.94,
            accuracy: 0.000_001
        )

        simulation.afterburnerFuel = 1.5
        simulation.energy = 5
        timestamp += 0.1
        let warningFrame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(simulation.afterburnerFuel, 1.5)

        timestamp += 0.1
        let rearFrame = simulation.update(
            at: timestamp,
            input: .init(rearViewPressed: true, rearViewHeld: true)
        )
        XCTAssertTrue(rearFrame.rearViewIsActive)

        let finalLevel = makeTrainingFinalGoalLevel()
        let finalChain = try XCTUnwrap(finalLevel.trainingFinalGoalChain)
        let goal = try XCTUnwrap(finalLevel.objects.first {
            $0.handle == finalChain.goalObjectHandle
        })
        let initialFinalSimulation = PlayerSimulation(
            level: finalLevel,
            presentationReadyTimestamp: 0
        )
        initialFinalSimulation.destroyTrainingRobot(handle: 4_112)
        initialFinalSimulation.destroyTrainingRASBot1(handle: 2_074)
        initialFinalSimulation.destroyTrainingRASBot2(handle: 2_075)
        initialFinalSimulation.destroyTrainingRASBot3(handle: 2_077)
        initialFinalSimulation.destroyTrainingRASBot4(handle: 2_078)
        initialFinalSimulation.destroyTrainingLastBot1(handle: 4_127)
        initialFinalSimulation.destroyTrainingLastBot2(handle: 2_080)
        initialFinalSimulation.destroyTrainingLastBot3(handle: 2_081)
        initialFinalSimulation.destroyTrainingLastBot4(handle: 2_082)
        initialFinalSimulation.destroyTrainingLastBot5(handle: 2_083)
        _ = initialFinalSimulation.update(at: 0.1, input: .zero)
        var ready = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    initialFinalSimulation.continuation
                )
            ) as? [String: Any]
        )
        ready["playerLocation"] = [
            "room": ["_0": finalChain.goalRoomSourceIndex],
        ]
        ready["playerPosition"] = [
            "x": goal.position.x,
            "y": goal.position.y,
            "z": goal.position.z,
        ]
        let finalSimulation = try PlayerSimulation(
            level: finalLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: ready)
            ),
            resumedAtTimestamp: 0
        )
        let finalFrame = finalSimulation.update(at: 0.2, input: .zero)
        XCTAssertNotNil(finalFrame.trainingFinalGoal)

        let project = try makeProject(importedBase: level)
        let editorSimulation = project.makePlayerPlaySession()
            .makePlayerSimulation(presentationReadyTimestamp: 0)
        _ = editorSimulation.update(at: 0.1, input: .zero)
        var editorInput = PlayerInputState(rampDuration: 0)
        let editorView = RevivalGameplayView(frame: view.frame, device: nil)
        editorView.heldInputChanged = { editorInput.setHeld($0) }
        editorView.setGameplayActive(true)
        editorView.flagsChanged(with: try shiftEvent(
            modifiers: [.shift],
            timestamp: 0.11
        ))
        let editorFrame = editorSimulation.update(
            at: 0.2,
            input: editorInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(
            editorSimulation.afterburnerFuel,
            4.9,
            accuracy: 0.000_001
        )

        try view.presentTrainingOpening(frame: freshFrame, voiceClips: [])
        view.layoutSubtreeIfNeeded()
        let item = try afterburnerItem(in: view)
        XCTAssertEqual(item.stringValue, "Afterburner: 100%")
        XCTAssertEqual(item.accessibilityLabel(), "Afterburner")
        XCTAssertFalse(item.isHidden)
        XCTAssertGreaterThanOrEqual(item.frame.minX, 160 + 24)
        XCTAssertLessThanOrEqual(item.frame.maxX, 1_120 - 24)

        XCTAssertEqual(try frameFuel(shiftedFrame), 4.9, accuracy: 0.000_001)
        try view.presentTrainingOpening(frame: shiftedFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 98%")
        XCTAssertEqual(item.accessibilityLabel(), "Afterburner")

        try view.presentTrainingOpening(frame: rechargedFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 100%")

        try view.presentTrainingOpening(frame: truncationFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 98%")

        try view.presentTrainingOpening(frame: warningFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 30%")
        XCTAssertEqual(
            item.accessibilityLabel(),
            "Afterburner, low fuel warning"
        )
        XCTAssertEqual(item.textColor, .systemRed)
        XCTAssertEqual(
            item.font,
            .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        )

        try view.presentTrainingOpening(frame: rearFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        try view.presentTrainingOpening(frame: warningFrame, voiceClips: [])
        XCTAssertFalse(item.isHidden)
        try view.presentTrainingOpening(frame: finalFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        try editorView.presentTrainingOpening(
            frame: editorFrame,
            voiceClips: []
        )
        let editorItem = try afterburnerItem(in: editorView)
        XCTAssertEqual(editorItem.stringValue, "Afterburner: 98%")
    }
}
