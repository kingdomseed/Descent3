import AppKit
import XCTest

extension WorldRenderingTests {
    @MainActor
    func testNormalTrainingPresentsLiveTextShieldsHUD() throws {
        func hudItem(
            identifiedBy identifier: String,
            in view: RevivalGameplayView
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

        let shieldsItem = try hudItem(
            identifiedBy: "Live Shields HUD",
            in: view
        )
        let energyItem = try hudItem(
            identifiedBy: "Live Energy HUD",
            in: view
        )
        let afterburnerItem = try hudItem(
            identifiedBy: "Live Afterburner HUD",
            in: view
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
        try view.presentGameplayFrame(
            frame: truncatedFrame,
            voiceClips: []
        )
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
            shieldsItem.accessibilityLabel(),
            "Shields, low shields warning"
        )
        XCTAssertEqual(shieldsItem.textColor, .systemRed)
        XCTAssertEqual(
            shieldsItem.font,
            .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        )
        XCTAssertEqual(energyItem.stringValue, "Energy: 100")
        XCTAssertEqual(afterburnerItem.stringValue, "Afterburner: 100%")

        let rearFrame = simulation.update(
            at: 0.04,
            input: .init(rearViewPressed: true, rearViewHeld: true)
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
        XCTAssertNotNil(try? hudItem(
            identifiedBy: "Live Energy HUD",
            in: view
        ))
        XCTAssertNotNil(try? hudItem(
            identifiedBy: "Live Afterburner HUD",
            in: view
        ))

        let project = try makeProject(
            importedBase: makeTrainingRobotGuidebotLevel()
        )
        let editorSimulation = project.makePlayerPlaySession()
            .makePlayerSimulation(
                presentationReadyTimestamp: 0
            )
        let editorFrame = editorSimulation.update(at: 0.01, input: .zero)
        let editorView = RevivalGameplayView(frame: view.frame, device: nil)
        try editorView.presentGameplayFrame(
            frame: editorFrame,
            voiceClips: []
        )
        let editorShieldsItem = try hudItem(
            identifiedBy: "Live Shields HUD",
            in: editorView
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
                identifiedBy: "Live Afterburner HUD",
                in: editorView
            ).stringValue,
            "Afterburner: 100%"
        )
    }
}
