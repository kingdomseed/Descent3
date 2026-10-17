import AppKit
import XCTest

// The live text HUD of the gameplay view (pre-M4, architecture.md section
// 9): shields, energy, and afterburner, their low warnings, and when they
// hide.
extension RevivalGameplayViewTests {
    @MainActor
    func testNormalPrimaryFireUpdatesTheLiveTextEnergyHUD() throws {
        func energyItem(in view: RevivalGameplayView) throws -> NSTextField {
            try XCTUnwrap(
                view.subviews.compactMap { $0 as? NSTextField }.first {
                    $0.accessibilityIdentifier() == "Live Energy HUD"
                },
                "ordinary Training play must expose one identified Energy item"
            )
        }

        let level = makeTrainingRobotGuidebotLevel()
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        let view = RevivalGameplayView(
            frame: NSRect(x: 0, y: 0, width: 1_280, height: 720), device: nil
        )
        let initialFrame = simulation.update(at: 0.01, input: .zero)
        try view.presentGameplayFrame(frame: initialFrame, voiceClips: [])
        view.layoutSubtreeIfNeeded()

        let item = try energyItem(in: view)
        XCTAssertEqual(item.stringValue, "Energy: 100")
        XCTAssertEqual(item.accessibilityLabel(), "Energy")
        XCTAssertFalse(item.isHidden)
        XCTAssertGreaterThanOrEqual(item.frame.minX, 160 + 24)
        XCTAssertLessThanOrEqual(item.frame.maxX, 1_120 - 24)

        let firedFrame = simulation.update(
            at: 0.02, input: .init(firesPrimaryWeapon: true)
        )
        XCTAssertEqual(simulation.energy, 99.85, accuracy: 0.000_01)
        try view.presentGameplayFrame(frame: firedFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Energy: 099")
        XCTAssertEqual(item.accessibilityLabel(), "Energy")

        simulation.energy = 20
        let warningFrame = simulation.update(at: 0.03, input: .zero)
        XCTAssertEqual(simulation.energy, 20)
        try view.presentGameplayFrame(frame: warningFrame, voiceClips: [])
        XCTAssertEqual(
            item.stringValue,
            String(format: "Energy: %03d", Int(simulation.energy))
        )
        XCTAssertEqual(item.accessibilityLabel(), "Energy, low energy warning")
        XCTAssertEqual(item.textColor, .systemRed)

        let rearFrame = simulation.update(
            at: 0.04, input: .init(rearViewPressed: true, rearViewHeld: true)
        )
        XCTAssertTrue(rearFrame.rearViewIsActive)
        try view.presentGameplayFrame(frame: rearFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        try view.presentGameplayFrame(frame: warningFrame, voiceClips: [])
        XCTAssertFalse(item.isHidden)

        // Script 057 ends the level (TrainingMission.cpp:2309).
        let finalFrame = try trainingLevelEndFrame().frame
        XCTAssertNotNil(finalFrame.levelEnd)
        try view.presentGameplayFrame(frame: finalFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        let project = try makeProject(
            importedBase: makeTrainingRobotGuidebotLevel()
        )
        let editorSimulation = project.makePlayerPlaySession()
            .makePlayerSimulation(presentationReadyTimestamp: 0)
        editorSimulation.enableAllPlayerControls()
        _ = editorSimulation.update(at: 0.01, input: .zero)
        let editorFrame = editorSimulation.update(
            at: 0.02, input: .init(firesPrimaryWeapon: true)
        )
        let editorView = RevivalGameplayView(frame: view.frame, device: nil)
        try editorView.presentGameplayFrame(frame: editorFrame, voiceClips: [])
        let editorItem = try energyItem(in: editorView)
        XCTAssertEqual(editorItem.stringValue, "Energy: 099")
    }

    @MainActor
    func testNormalTrainingPresentsLiveTextShieldsHUD() throws {
        func hudItem(
            identifiedBy identifier: String, in view: RevivalGameplayView
        ) throws -> NSTextField {
            try XCTUnwrap(
                view.subviews.compactMap { $0 as? NSTextField }.first {
                    $0.accessibilityIdentifier() == identifier
                },
                "ordinary Training play must expose \(identifier)"
            )
        }

        let level = makeTrainingRobotGuidebotLevel()
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        let view = RevivalGameplayView(
            frame: NSRect(x: 0, y: 0, width: 1_280, height: 720), device: nil
        )
        let initialFrame = simulation.update(at: 0.01, input: .zero)
        try view.presentGameplayFrame(frame: initialFrame, voiceClips: [])
        view.layoutSubtreeIfNeeded()

        let shieldsItem = try hudItem(
            identifiedBy: "Live Shields HUD", in: view
        )
        let energyItem = try hudItem(identifiedBy: "Live Energy HUD", in: view)
        let afterburnerItem = try hudItem(
            identifiedBy: "Live Afterburner HUD", in: view
        )
        XCTAssertEqual(shieldsItem.stringValue, "Shields: 100")
        XCTAssertEqual(shieldsItem.accessibilityLabel(), "Shields")
        XCTAssertFalse(shieldsItem.isHidden)
        XCTAssertGreaterThanOrEqual(shieldsItem.frame.minX, 160 + 24)
        XCTAssertLessThanOrEqual(shieldsItem.frame.maxX, 1_120 - 24)
        XCTAssertFalse(shieldsItem.frame.intersects(energyItem.frame))
        XCTAssertFalse(shieldsItem.frame.intersects(afterburnerItem.frame))
        XCTAssertEqual(energyItem.stringValue, "Energy: 100")
        XCTAssertEqual(energyItem.accessibilityLabel(), "Energy")
        XCTAssertEqual(afterburnerItem.stringValue, "Afterburner: 100%")
        XCTAssertEqual(afterburnerItem.accessibilityLabel(), "Afterburner")

        simulation.shields = 20.75
        let truncatedFrame = simulation.update(at: 0.02, input: .zero)
        try view.presentGameplayFrame(frame: truncatedFrame, voiceClips: [])
        XCTAssertEqual(shieldsItem.stringValue, "Shields: 020")
        XCTAssertEqual(shieldsItem.accessibilityLabel(), "Shields")
        XCTAssertEqual(shieldsItem.textColor, .systemGreen)
        XCTAssertEqual(
            shieldsItem.font,
            .monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        )
        XCTAssertEqual(energyItem.stringValue, "Energy: 100")
        XCTAssertEqual(afterburnerItem.stringValue, "Afterburner: 100%")

        simulation.shields = 20
        let warningFrame = simulation.update(at: 0.03, input: .zero)
        try view.presentGameplayFrame(frame: warningFrame, voiceClips: [])
        XCTAssertEqual(shieldsItem.stringValue, "Shields: 020")
        XCTAssertEqual(
            shieldsItem.accessibilityLabel(), "Shields, low shields warning"
        )
        XCTAssertEqual(shieldsItem.textColor, .systemRed)
        XCTAssertEqual(
            shieldsItem.font,
            .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        )
        XCTAssertEqual(energyItem.stringValue, "Energy: 100")
        XCTAssertEqual(afterburnerItem.stringValue, "Afterburner: 100%")

        let rearFrame = simulation.update(
            at: 0.04, input: .init(rearViewPressed: true, rearViewHeld: true)
        )
        XCTAssertTrue(rearFrame.rearViewIsActive)
        try view.presentGameplayFrame(frame: rearFrame, voiceClips: [])
        XCTAssertTrue(shieldsItem.isHidden)

        try view.presentGameplayFrame(frame: warningFrame, voiceClips: [])
        XCTAssertFalse(shieldsItem.isHidden)
        XCTAssertFalse(energyItem.isHidden)
        XCTAssertFalse(afterburnerItem.isHidden)

        // Script 057 ends the level (TrainingMission.cpp:2309).
        let finalFrame = try trainingLevelEndFrame().frame
        XCTAssertNotNil(finalFrame.levelEnd)
        try view.presentGameplayFrame(frame: finalFrame, voiceClips: [])
        XCTAssertTrue(shieldsItem.isHidden)
        XCTAssertNotNil(try? hudItem(identifiedBy: "Live Energy HUD", in: view))
        XCTAssertNotNil(try? hudItem(
            identifiedBy: "Live Afterburner HUD", in: view
        ))

        let project = try makeProject(
            importedBase: makeTrainingRobotGuidebotLevel()
        )
        let editorSimulation = project.makePlayerPlaySession()
            .makePlayerSimulation(presentationReadyTimestamp: 0)
        // The unmodified editor session of a package level: the Training
        // module's Script 000 leaves only forward on
        // (TrainingMission.cpp:1461).
        let editorFrame = editorSimulation.update(at: 0.01, input: .zero)
        XCTAssertEqual(editorFrame.enabledPlayerControls, [.forward])
        XCTAssertTrue(editorFrame.showsEnabledPlayerControls)
        let editorView = RevivalGameplayView(frame: view.frame, device: nil)
        try editorView.presentGameplayFrame(frame: editorFrame, voiceClips: [])
        let editorShieldsItem = try hudItem(
            identifiedBy: "Live Shields HUD", in: editorView
        )
        XCTAssertEqual(editorShieldsItem.stringValue, "Shields: 100")
        XCTAssertEqual(editorShieldsItem.accessibilityLabel(), "Shields")
        XCTAssertEqual(
            try hudItem(identifiedBy: "Live Energy HUD", in: editorView)
                .stringValue,
            "Energy: 100"
        )
        XCTAssertEqual(
            try hudItem(
                identifiedBy: "Live Afterburner HUD", in: editorView
            ).stringValue,
            "Afterburner: 100%"
        )
    }

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
            modifiers: NSEvent.ModifierFlags, timestamp: TimeInterval
        ) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(
                with: .flagsChanged, location: .zero, modifierFlags: modifiers,
                timestamp: timestamp, windowNumber: 0, context: nil,
                characters: "", charactersIgnoringModifiers: "",
                isARepeat: false, keyCode: 56
            ))
        }

        func restoreControlsThroughNormalTraining(
            in simulation: GameSession, startingAt timestamp: inout Double
        ) -> PlayerSimulationFrame {
            var frame = simulation.update(at: timestamp, input: .zero)
            for fires in [true, false, true, false, true, false, true] {
                timestamp += fires ? 0.01 : 0.25
                frame = simulation.update(
                    at: timestamp, input: .init(firesPrimaryWeapon: fires)
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
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        var timestamp = 0.1
        let controlsRestored = restoreControlsThroughNormalTraining(
            in: simulation, startingAt: &timestamp
        )
        XCTAssertEqual(controlsRestored.enabledPlayerControls, .all)
        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == 4_112
        })

        timestamp += 0.1
        let freshFrame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(simulation.afterburnerFuel, 5)

        var playerInput = PlayerInputState(rampDuration: 0)
        let view = RevivalGameplayView(
            frame: NSRect(x: 0, y: 0, width: 1_280, height: 720), device: nil
        )
        view.heldInputChanged = { playerInput.setHeld($0) }
        view.setGameplayActive(true)
        view.flagsChanged(with: try shiftEvent(
            modifiers: [.shift], timestamp: timestamp + 0.01
        ))
        timestamp += 0.1
        let shiftedFrame = simulation.update(
            at: timestamp, input: playerInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(simulation.afterburnerFuel, 4.9, accuracy: 0.000_001)

        view.flagsChanged(with: try shiftEvent(
            modifiers: [], timestamp: timestamp + 0.01
        ))
        timestamp += 0.1
        let rechargedFrame = simulation.update(
            at: timestamp, input: playerInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(simulation.afterburnerFuel, 5, accuracy: 0.000_001)
        XCTAssertEqual(simulation.energy, 99.3, accuracy: 0.000_01)

        let truncationSimulation = GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        var truncationTimestamp = 0.1
        let truncationControls = restoreControlsThroughNormalTraining(
            in: truncationSimulation, startingAt: &truncationTimestamp
        )
        XCTAssertEqual(truncationControls.enabledPlayerControls, .all)
        truncationTimestamp += 0.1
        _ = truncationSimulation.update(at: truncationTimestamp, input: .zero)
        truncationTimestamp += 0.06
        _ = truncationSimulation.update(at: truncationTimestamp, input: .zero)
        var truncationInput = PlayerInputState(rampDuration: 0)
        let truncationView = RevivalGameplayView(frame: view.frame, device: nil)
        truncationView.heldInputChanged = { truncationInput.setHeld($0) }
        truncationView.setGameplayActive(true)
        truncationView.flagsChanged(with: try shiftEvent(
            modifiers: [.shift], timestamp: truncationTimestamp + 0.01
        ))
        truncationTimestamp += 0.1
        let truncationFrame = truncationSimulation.update(
            at: truncationTimestamp,
            input: truncationInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(
            truncationSimulation.afterburnerFuel, 4.94, accuracy: 0.000_001
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

        // Script 057 ends the level (TrainingMission.cpp:2309).
        let finalFrame = try trainingLevelEndFrame().frame
        XCTAssertNotNil(finalFrame.levelEnd)

        let project = try makeProject(importedBase: level)
        let editorSimulation = project.makePlayerPlaySession()
            .makePlayerSimulation(presentationReadyTimestamp: 0)
        editorSimulation.enableAllPlayerControls()
        _ = editorSimulation.update(at: 0.1, input: .zero)
        var editorInput = PlayerInputState(rampDuration: 0)
        let editorView = RevivalGameplayView(frame: view.frame, device: nil)
        editorView.heldInputChanged = { editorInput.setHeld($0) }
        editorView.setGameplayActive(true)
        editorView.flagsChanged(with: try shiftEvent(
            modifiers: [.shift], timestamp: 0.11
        ))
        let editorFrame = editorSimulation.update(
            at: 0.2, input: editorInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(
            editorSimulation.afterburnerFuel, 4.9, accuracy: 0.000_001
        )

        try view.presentGameplayFrame(frame: freshFrame, voiceClips: [])
        view.layoutSubtreeIfNeeded()
        let item = try afterburnerItem(in: view)
        XCTAssertEqual(item.stringValue, "Afterburner: 100%")
        XCTAssertEqual(item.accessibilityLabel(), "Afterburner")
        XCTAssertFalse(item.isHidden)
        XCTAssertGreaterThanOrEqual(item.frame.minX, 160 + 24)
        XCTAssertLessThanOrEqual(item.frame.maxX, 1_120 - 24)

        XCTAssertEqual(try frameFuel(shiftedFrame), 4.9, accuracy: 0.000_001)
        try view.presentGameplayFrame(frame: shiftedFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 98%")
        XCTAssertEqual(item.accessibilityLabel(), "Afterburner")

        try view.presentGameplayFrame(frame: rechargedFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 100%")

        try view.presentGameplayFrame(frame: truncationFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 98%")

        try view.presentGameplayFrame(frame: warningFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 30%")
        XCTAssertEqual(
            item.accessibilityLabel(), "Afterburner, low fuel warning"
        )
        XCTAssertEqual(item.textColor, .systemRed)
        XCTAssertEqual(
            item.font, .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        )

        try view.presentGameplayFrame(frame: rearFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        try view.presentGameplayFrame(frame: warningFrame, voiceClips: [])
        XCTAssertFalse(item.isHidden)
        try view.presentGameplayFrame(frame: finalFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        try editorView.presentGameplayFrame(frame: editorFrame, voiceClips: [])
        let editorItem = try afterburnerItem(in: editorView)
        XCTAssertEqual(editorItem.stringValue, "Afterburner: 98%")
    }
}
