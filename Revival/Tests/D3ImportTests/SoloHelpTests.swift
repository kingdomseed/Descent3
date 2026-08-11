import AppKit
import XCTest

final class SoloHelpTests: XCTestCase {
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

        let heldW = try makeKeyEvent(
            keyCode: 13,
            characters: "w",
            timestamp: 0
        )
        let physicalF1 = try makeKeyEvent(
            keyCode: 122,
            timestamp: 0.01
        )
        let repeatedF1 = try makeKeyEvent(
            keyCode: 122,
            isRepeat: true,
            timestamp: 0.02
        )
        let closeF1 = try makeKeyEvent(
            keyCode: 122,
            timestamp: 0.03
        )
        let expectedRows = [
            "W/S — Forward/reverse thrust",
            "A/D — Slide left/right",
            "R/F — Slide up/down",
            "Arrow keys — Pitch/yaw",
            "Q/E — Bank",
            "Mouse — Look",
            "Left-click — Primary fire",
            "Space or right-click — Secondary fire",
            "Shift — Afterburner",
            "G — Flare",
            "H — Headlight",
            "V — Rear view",
            "Backslash — Inventory use",
            "F4 — GuideBot",
            "P — Pause",
            "F9 — Quicksave",
            "Option-F3 — Quickload",
            "F1 — Close",
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
            let descendants = Self.descendants(of: modalWindow.contentView)
            let text = descendants.compactMap {
                ($0 as? NSTextField)?.stringValue
            }.filter { !$0.isEmpty }
            XCTAssertEqual(
                Set(text),
                Set(["Keys", expectedRows.joined(separator: "\n")])
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
                Self.descendants(of: modalWindow.contentView)
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
    private func makeKeyEvent(
        keyCode: UInt16,
        characters: String = "",
        isRepeat: Bool = false,
        timestamp: TimeInterval
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: timestamp,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: isRepeat,
            keyCode: keyCode
        ))
    }

    @MainActor
    private static func descendants(of view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return view.subviews + view.subviews.flatMap { descendants(of: $0) }
    }
}
