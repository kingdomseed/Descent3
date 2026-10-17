import AppKit
import XCTest

/// A key-down event as AppKit delivers it.
@MainActor
func makeKeyEvent(
    keyCode: UInt16, characters: String = "",
    modifiers: NSEvent.ModifierFlags = [], isRepeat: Bool = false,
    timestamp: TimeInterval = 0
) throws -> NSEvent {
    try XCTUnwrap(NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: modifiers,
        timestamp: timestamp, windowNumber: 0, context: nil,
        characters: characters, charactersIgnoringModifiers: characters,
        isARepeat: isRepeat, keyCode: keyCode
    ))
}

/// Every view under `view`, depth first.
@MainActor
func viewDescendants(of view: NSView?) -> [NSView] {
    guard let view else { return [] }
    return view.subviews + view.subviews.flatMap { viewDescendants(of: $0) }
}
