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
        let simulation = PlayerSimulation(
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
