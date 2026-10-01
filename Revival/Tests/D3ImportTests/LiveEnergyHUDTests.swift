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
        try view.presentGameplayFrame(
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
            .makePlayerSimulation(
                presentationReadyTimestamp: 0
            )
        _ = editorSimulation.update(at: 0.01, input: .zero)
        let editorFrame = editorSimulation.update(
            at: 0.02,
            input: .init(firesPrimaryWeapon: true)
        )
        let editorView = RevivalGameplayView(frame: view.frame, device: nil)
        try editorView.presentGameplayFrame(
            frame: editorFrame,
            voiceClips: []
        )
        let editorItem = try energyItem(in: editorView)
        XCTAssertEqual(editorItem.stringValue, "Energy: 099")
    }
}
