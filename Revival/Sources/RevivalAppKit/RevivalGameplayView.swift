// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreGraphics
@preconcurrency import GameController
import MetalKit

@MainActor
final class RevivalGameplayView: MTKView {
    var heldInputChanged: ((InputSnapshot) -> Void)?
    var controllerInputChanged: ((InputSnapshot) -> Void)?

    private var heldKeys: Set<UInt16> = []
    private var pendingMouseX: Float = 0
    private var pendingMouseY: Float = 0
    private var activeController: GCController?
    private var gameplayIsActive = false
    private var mouseIsCaptured = false
    private var afterburnerIsHeld = false

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect, device: (any MTLDevice)?) {
        super.init(frame: frameRect, device: device)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("Revival gameplay views are created programmatically.")
    }

    deinit {
        activeController?.extendedGamepad?.valueChangedHandler = nil
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            releaseMouse()
            return
        }
        guard Self.gameplayKeyCodes.contains(event.keyCode) else {
            super.keyDown(with: event)
            return
        }
        heldKeys.insert(event.keyCode)
        publishHeldInput()
    }

    override func keyUp(with event: NSEvent) {
        guard Self.gameplayKeyCodes.contains(event.keyCode) else {
            super.keyUp(with: event)
            return
        }
        heldKeys.remove(event.keyCode)
        publishHeldInput()
    }

    override func flagsChanged(with event: NSEvent) {
        guard event.keyCode == 56 || event.keyCode == 60 else {
            super.flagsChanged(with: event)
            return
        }
        afterburnerIsHeld = event.modifierFlags.contains(.shift)
        publishHeldInput()
    }

    override func mouseDown(with event: NSEvent) {
        guard gameplayIsActive else {
            super.mouseDown(with: event)
            return
        }
        captureMouse()
    }

    override func mouseMoved(with event: NSEvent) {
        guard gameplayIsActive && mouseIsCaptured else {
            super.mouseMoved(with: event)
            return
        }
        pendingMouseX += Float(event.deltaX)
        pendingMouseY += Float(event.deltaY)
    }

    func setGameplayActive(_ active: Bool) {
        gameplayIsActive = active
        if active {
            publishHeldInput()
            connectController(GCController.controllers().first)
        } else {
            disconnectController()
            clearInput()
        }
    }

    func drainMouseDelta() -> (x: Float, y: Float) {
        let result = (pendingMouseX, pendingMouseY)
        pendingMouseX = 0
        pendingMouseY = 0
        return result
    }

    func clearInput() {
        heldKeys.removeAll()
        afterburnerIsHeld = false
        pendingMouseX = 0
        pendingMouseY = 0
        heldInputChanged?(.zero)
        controllerInputChanged?(.zero)
        releaseMouse()
    }

    nonisolated static func heldInput(
        for keyCodes: Set<UInt16>,
        afterburner: Bool = false
    ) -> InputSnapshot {
        InputSnapshot(
            forward: direction(positive: 13, negative: 1, in: keyCodes),
            sideways: direction(positive: 2, negative: 0, in: keyCodes),
            vertical: direction(positive: 15, negative: 3, in: keyCodes),
            pitch: direction(positive: 125, negative: 126, in: keyCodes),
            yaw: direction(positive: 124, negative: 123, in: keyCodes),
            roll: direction(positive: 12, negative: 14, in: keyCodes),
            afterburner: afterburner ? 1 : 0
        )
    }

    nonisolated static func controllerInput(
        leftX: Float,
        leftY: Float,
        rightX: Float,
        rightY: Float,
        leftTrigger: Float,
        rightTrigger: Float,
        leftShoulder: Float,
        rightShoulder: Float,
        afterburner: Float = 0
    ) -> InputSnapshot {
        InputSnapshot(
            forward: adjusted(leftY),
            sideways: adjusted(leftX),
            vertical: adjusted(rightTrigger) - adjusted(leftTrigger),
            pitch: -adjusted(rightY),
            yaw: adjusted(rightX),
            roll: leftShoulder - rightShoulder,
            afterburner: afterburner
        )
    }

    private func publishHeldInput() {
        heldInputChanged?(
            Self.heldInput(for: heldKeys, afterburner: afterburnerIsHeld)
        )
    }

    private func publishControllerInput() {
        guard gameplayIsActive,
              let gamepad = activeController?.extendedGamepad else {
            controllerInputChanged?(.zero)
            return
        }
        controllerInputChanged?(
            Self.controllerInput(
                leftX: gamepad.leftThumbstick.xAxis.value,
                leftY: gamepad.leftThumbstick.yAxis.value,
                rightX: gamepad.rightThumbstick.xAxis.value,
                rightY: gamepad.rightThumbstick.yAxis.value,
                leftTrigger: gamepad.leftTrigger.value,
                rightTrigger: gamepad.rightTrigger.value,
                leftShoulder: gamepad.leftShoulder.value,
                rightShoulder: gamepad.rightShoulder.value,
                afterburner: gamepad.buttonA.value
            )
        )
    }

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard gameplayIsActive,
              activeController == nil,
              let controller = notification.object as? GCController else {
            return
        }
        connectController(controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        guard notification.object as? GCController === activeController else {
            return
        }
        connectController(
            GCController.controllers().first { $0 !== activeController }
        )
    }

    private func connectController(_ controller: GCController?) {
        guard gameplayIsActive else { return }
        activeController?.extendedGamepad?.valueChangedHandler = nil
        activeController = controller
        controller?.handlerQueue = .main
        controller?.extendedGamepad?.valueChangedHandler = {
            [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.publishControllerInput()
            }
        }
        publishControllerInput()
    }

    private func disconnectController() {
        activeController?.extendedGamepad?.valueChangedHandler = nil
        activeController = nil
    }

    private func captureMouse() {
        guard !mouseIsCaptured else { return }
        mouseIsCaptured = true
        NSCursor.hide()
        CGAssociateMouseAndMouseCursorPosition(0)
    }

    private func releaseMouse() {
        guard mouseIsCaptured else { return }
        mouseIsCaptured = false
        pendingMouseX = 0
        pendingMouseY = 0
        CGAssociateMouseAndMouseCursorPosition(1)
        NSCursor.unhide()
    }

    nonisolated private static func direction(
        positive: UInt16,
        negative: UInt16,
        in keyCodes: Set<UInt16>
    ) -> Float {
        (keyCodes.contains(positive) ? 1 : 0)
            - (keyCodes.contains(negative) ? 1 : 0)
    }

    nonisolated private static func adjusted(_ value: Float) -> Float {
        let deadzone: Float = 0.2
        if value > deadzone {
            return min(1, (value - deadzone) / (1 - deadzone))
        }
        if value < -deadzone {
            return max(-1, (value + deadzone) / (1 - deadzone))
        }
        return 0
    }

    private static let gameplayKeyCodes: Set<UInt16> = [
        0, 1, 2, 3, 12, 13, 14, 15, 123, 124, 125, 126,
    ]
}
