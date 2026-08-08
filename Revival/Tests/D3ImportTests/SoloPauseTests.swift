import AppKit
import XCTest

extension WorldRenderingTests {
    @MainActor
    func testPhysicalPPresentsBlockingSoloPauseAndClearsHeldInput() throws {
        _ = NSApplication.shared
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var heldInput: [InputSnapshot] = []
        view.heldInputChanged = { heldInput.append($0) }
        view.setGameplayActive(true)

        let heldW = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "w",
            charactersIgnoringModifiers: "w",
            isARepeat: false,
            keyCode: 13
        ))
        let physicalP = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0.01,
            windowNumber: 0,
            context: nil,
            characters: "p",
            charactersIgnoringModifiers: "p",
            isARepeat: false,
            keyCode: 35
        ))
        let repeatedP = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0.02,
            windowNumber: 0,
            context: nil,
            characters: "p",
            charactersIgnoringModifiers: "p",
            isARepeat: true,
            keyCode: 35
        ))

        view.keyDown(with: heldW)
        XCTAssertEqual(heldInput.last?.forward, 1)

        var inspectedModal = false
        DispatchQueue.main.async {
            guard let modalWindow = NSApplication.shared.modalWindow else {
                XCTFail("physical P did not present the Pause alert")
                return
            }
            inspectedModal = true
            XCTAssertEqual(
                NSApplication.shared.windows.filter { $0 === modalWindow }.count,
                1
            )
            let descendants = Self.descendants(of: modalWindow.contentView)
            let text = descendants.compactMap {
                ($0 as? NSTextField)?.stringValue
            }
            XCTAssertTrue(text.contains("Pause"))
            XCTAssertTrue(text.contains(
                "The game is paused.\nPress P or click OK to resume."
            ))
            let buttons = descendants.compactMap { $0 as? NSButton }
            XCTAssertEqual(buttons.map(\.title), ["OK"])
            XCTAssertEqual(heldInput.last, .zero)
            NSApplication.shared.sendEvent(repeatedP)
            XCTAssertTrue(NSApplication.shared.modalWindow === modalWindow)
            buttons.only?.performClick(nil)
        }
        view.keyDown(with: physicalP)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertTrue(inspectedModal)
        XCTAssertEqual(heldInput.last, .zero)

        var repeatOpenedModal = false
        DispatchQueue.main.async {
            repeatOpenedModal = NSApplication.shared.modalWindow != nil
            if repeatOpenedModal {
                let descendants = Self.descendants(
                    of: NSApplication.shared.modalWindow?.contentView
                )
                descendants.compactMap { $0 as? NSButton }
                    .only?.performClick(nil)
            }
        }
        view.keyDown(with: repeatedP)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertFalse(repeatOpenedModal)
        XCTAssertNil(NSApplication.shared.modalWindow)
    }

    @MainActor
    private static func descendants(of view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return view.subviews + view.subviews.flatMap { descendants(of: $0) }
    }
}
