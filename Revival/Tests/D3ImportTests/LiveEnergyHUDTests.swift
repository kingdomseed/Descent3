import AppKit
import XCTest

extension WorldRenderingTests {
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
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        let view = RevivalGameplayView(
            frame: NSRect(x: 0, y: 0, width: 1_280, height: 720),
            device: nil
        )
        let initialFrame = simulation.update(at: 0.01, input: .zero)
        try view.presentTrainingOpening(
            frame: initialFrame,
            voiceClips: []
        )
        view.layoutSubtreeIfNeeded()

        let item = try energyItem(in: view)
        XCTAssertEqual(item.stringValue, "Energy: 100")
        XCTAssertEqual(item.accessibilityLabel(), "Energy")
        XCTAssertFalse(item.isHidden)
        XCTAssertGreaterThanOrEqual(item.frame.minX, 160 + 24)
        XCTAssertLessThanOrEqual(item.frame.maxX, 1_120 - 24)

        let firedFrame = simulation.update(
            at: 0.02,
            input: .init(firesPrimaryWeapon: true)
        )
        XCTAssertEqual(simulation.energy, 99.85, accuracy: 0.000_01)
        try view.presentTrainingOpening(frame: firedFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Energy: 099")
        XCTAssertEqual(item.accessibilityLabel(), "Energy")

        simulation.energy = 20
        let warningFrame = simulation.update(at: 0.03, input: .zero)
        XCTAssertEqual(simulation.energy, 20)
        try view.presentTrainingOpening(frame: warningFrame, voiceClips: [])
        XCTAssertEqual(
            item.stringValue,
            String(format: "Energy: %03d", Int(simulation.energy))
        )
        XCTAssertEqual(
            item.accessibilityLabel(),
            "Energy, low energy warning"
        )
        XCTAssertEqual(item.textColor, .systemRed)

        let rearFrame = simulation.update(
            at: 0.04,
            input: .init(rearViewPressed: true, rearViewHeld: true)
        )
        XCTAssertTrue(rearFrame.rearViewIsActive)
        try view.presentTrainingOpening(frame: rearFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        try view.presentTrainingOpening(frame: warningFrame, voiceClips: [])
        XCTAssertFalse(item.isHidden)

        let finalLevel = makeTrainingFinalGoalLevel()
        let finalChain = try XCTUnwrap(finalLevel.trainingFinalGoalChain)
        let goal = try XCTUnwrap(finalLevel.objects.first {
            $0.handle == finalChain.goalObjectHandle
        })
        let initialFinalSimulation = GameSession(
            level: finalLevel,
            presentationReadyTimestamp: 0
        )
        // The player shot down the ten robots, and the last five opened
        // the final bots barrier (Scripts 051-055 and 035; this
        // unscripted fixture takes the state the scripts leave).
        initialFinalSimulation.killRobotsAsPlayer([
            4_112, 2_074, 2_075, 2_077, 2_078,
            4_127, 2_080, 2_081, 2_082, 2_083,
        ])
        openTrainingFinalBotsBarrier(in: &initialFinalSimulation.world, level: initialFinalSimulation.level)
        _ = initialFinalSimulation.update(at: 0.1, input: .zero)
        var ready = try XCTUnwrap(
            testWorldObject(initialFinalSimulation.world)
        )
        ready["playerLocation"] = [
            "room": ["_0": finalChain.goalRoomSourceIndex],
        ]
        ready["playerPosition"] = [
            "x": goal.position.x,
            "y": goal.position.y,
            "z": goal.position.z,
        ]
        let finalSimulation = try GameSession(
            level: finalLevel,
            world: (decodeTestWorld(ready)).rebased(onto: finalLevel),
            resumedAtTimestamp: 0
        )
        let finalFrame = finalSimulation.update(at: 0.2, input: .zero)
        XCTAssertNotNil(finalFrame.trainingFinalGoal)
        try view.presentTrainingOpening(frame: finalFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        let project = try makeProject(
            importedBase: makeTrainingRobotGuidebotLevel()
        )
        let editorSimulation = project.makePlayerPlaySession()
            .makePlayerSimulation(
                presentationReadyTimestamp: 0
            )
        _ = editorSimulation.update(at: 0.01, input: .zero)
        let editorFrame = editorSimulation.update(
            at: 0.02,
            input: .init(firesPrimaryWeapon: true)
        )
        let editorView = RevivalGameplayView(frame: view.frame, device: nil)
        try editorView.presentTrainingOpening(
            frame: editorFrame,
            voiceClips: []
        )
        let editorItem = try energyItem(in: editorView)
        XCTAssertEqual(editorItem.stringValue, "Energy: 099")
    }
}
