// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct InputSnapshot: Equatable, Sendable {
    let forward: Float
    let sideways: Float
    let vertical: Float
    let pitch: Float
    let yaw: Float
    let roll: Float
    let afterburner: Float
    let directLookPitchRadians: Float
    let directLookYawRadians: Float
    let firesPrimaryWeapon: Bool
    let firesSecondaryWeapon: Bool
    let firesPlayerFlare: Bool
    let deploysTrainingGuidebot: Bool
    let requestsTrainingGuidebotActiveGoal: Bool
    let usesInventory: Bool
    let togglesHeadlight: Bool
    let rearViewPressed: Bool
    let rearViewHeld: Bool

    static let zero = InputSnapshot()

    init(
        forward: Float = 0,
        sideways: Float = 0,
        vertical: Float = 0,
        pitch: Float = 0,
        yaw: Float = 0,
        roll: Float = 0,
        afterburner: Float = 0,
        directLookPitchRadians: Float = 0,
        directLookYawRadians: Float = 0,
        firesPrimaryWeapon: Bool = false,
        firesSecondaryWeapon: Bool = false,
        firesPlayerFlare: Bool = false,
        deploysTrainingGuidebot: Bool = false,
        requestsTrainingGuidebotActiveGoal: Bool = false,
        usesInventory: Bool = false,
        togglesHeadlight: Bool = false,
        rearViewPressed: Bool = false,
        rearViewHeld: Bool = false
    ) {
        precondition(
            directLookPitchRadians.isFinite && directLookYawRadians.isFinite
        )
        self.forward = max(-1, min(1, forward))
        self.sideways = max(-1, min(1, sideways))
        self.vertical = max(-1, min(1, vertical))
        self.pitch = max(-1, min(1, pitch))
        self.yaw = max(-1, min(1, yaw))
        self.roll = max(-1, min(1, roll))
        self.afterburner = max(0, min(1, afterburner))
        self.directLookPitchRadians = directLookPitchRadians
        self.directLookYawRadians = directLookYawRadians
        self.firesPrimaryWeapon = firesPrimaryWeapon
        self.firesSecondaryWeapon = firesSecondaryWeapon
        self.firesPlayerFlare = firesPlayerFlare
        self.deploysTrainingGuidebot = deploysTrainingGuidebot
        self.requestsTrainingGuidebotActiveGoal =
            requestsTrainingGuidebotActiveGoal
        self.usesInventory = usesInventory
        self.togglesHeadlight = togglesHeadlight
        self.rearViewPressed = rearViewPressed
        self.rearViewHeld = rearViewHeld
    }
}

struct PlayerControlMask: OptionSet, Codable, Equatable, Sendable {
    let rawValue: UInt32

    static let forward = Self(rawValue: 1 << 0)
    static let reverse = Self(rawValue: 1 << 1)
    static let left = Self(rawValue: 1 << 2)
    static let right = Self(rawValue: 1 << 3)
    static let up = Self(rawValue: 1 << 4)
    static let down = Self(rawValue: 1 << 5)
    static let pitchUp = Self(rawValue: 1 << 6)
    static let pitchDown = Self(rawValue: 1 << 7)
    static let headingLeft = Self(rawValue: 1 << 8)
    static let headingRight = Self(rawValue: 1 << 9)
    static let bankLeft = Self(rawValue: 1 << 10)
    static let bankRight = Self(rawValue: 1 << 11)
    static let primaryWeapon = Self(rawValue: 1 << 12)
    static let secondaryWeapon = Self(rawValue: 1 << 13)
    static let afterburner = Self(rawValue: 1 << 14)
    static let all = Self(rawValue: .max)
}

func trainingPlayerControlMask(
    galleryWasTriggered: Bool,
    controlsWereRestored: Bool,
    openingControls: PlayerControlMask?
) -> PlayerControlMask {
    if controlsWereRestored {
        return .all
    }
    if galleryWasTriggered {
        return PlayerControlMask(rawValue: 0)
    }
    return openingControls ?? .all
}

extension InputSnapshot {
    func applying(_ controls: PlayerControlMask) -> InputSnapshot {
        InputSnapshot(
            forward: forward >= 0
                ? (controls.contains(.forward) ? forward : 0)
                : (controls.contains(.reverse) ? forward : 0),
            sideways: sideways >= 0
                ? (controls.contains(.right) ? sideways : 0)
                : (controls.contains(.left) ? sideways : 0),
            vertical: vertical >= 0
                ? (controls.contains(.up) ? vertical : 0)
                : (controls.contains(.down) ? vertical : 0),
            pitch: pitch >= 0
                ? (controls.contains(.pitchDown) ? pitch : 0)
                : (controls.contains(.pitchUp) ? pitch : 0),
            yaw: yaw >= 0
                ? (controls.contains(.headingRight) ? yaw : 0)
                : (controls.contains(.headingLeft) ? yaw : 0),
            roll: roll >= 0
                ? (controls.contains(.bankRight) ? roll : 0)
                : (controls.contains(.bankLeft) ? roll : 0),
            afterburner: controls.contains(.afterburner) ? afterburner : 0,
            directLookPitchRadians:
                controls.contains(.pitchUp) || controls.contains(.pitchDown)
                    ? directLookPitchRadians
                    : 0,
            directLookYawRadians:
                controls.contains(.headingLeft) || controls.contains(.headingRight)
                    ? directLookYawRadians
                    : 0,
            firesPrimaryWeapon:
                controls.contains(.primaryWeapon) && firesPrimaryWeapon,
            firesSecondaryWeapon:
                controls.contains(.secondaryWeapon) && firesSecondaryWeapon,
            firesPlayerFlare: firesPlayerFlare,
            deploysTrainingGuidebot: deploysTrainingGuidebot,
            requestsTrainingGuidebotActiveGoal:
                requestsTrainingGuidebotActiveGoal,
            usesInventory: usesInventory,
            togglesHeadlight: togglesHeadlight,
            rearViewPressed: rearViewPressed,
            rearViewHeld: rearViewHeld
        )
    }
}

struct PlayerInputRamp: Sendable {
    let rampDuration: Float

    private var state = InputSnapshot.zero
    private var previousHeld = InputSnapshot.zero

    init(rampDuration: Float = 0.35) {
        precondition(rampDuration.isFinite && rampDuration >= 0)
        self.rampDuration = rampDuration
    }

    mutating func snapshot(
        held: InputSnapshot,
        frameDuration: Float,
        gameplayIsActive: Bool
    ) -> InputSnapshot {
        precondition(frameDuration.isFinite && frameDuration >= 0)
        guard gameplayIsActive else {
            state = .zero
            previousHeld = .zero
            return .zero
        }
        guard rampDuration > 0 else {
            state = .zero
            previousHeld = held
            return InputSnapshot(
                forward: inputSign(held.forward),
                sideways: inputSign(held.sideways),
                vertical: inputSign(held.vertical),
                pitch: inputSign(held.pitch),
                yaw: inputSign(held.yaw),
                roll: inputSign(held.roll),
                afterburner: held.afterburner,
                directLookPitchRadians: 0,
                directLookYawRadians: 0
            )
        }

        state = InputSnapshot(
            forward: ramped(held.forward, state.forward, previousHeld.forward, frameDuration),
            sideways: ramped(held.sideways, state.sideways, previousHeld.sideways, frameDuration),
            vertical: ramped(held.vertical, state.vertical, previousHeld.vertical, frameDuration),
            pitch: ramped(held.pitch, state.pitch, previousHeld.pitch, frameDuration),
            yaw: ramped(held.yaw, state.yaw, previousHeld.yaw, frameDuration),
            roll: ramped(held.roll, state.roll, previousHeld.roll, frameDuration),
            afterburner: held.afterburner,
            directLookPitchRadians: 0,
            directLookYawRadians: 0
        )
        previousHeld = held
        return state
    }

    private func ramped(
        _ held: Float,
        _ current: Float,
        _ previous: Float,
        _ frameDuration: Float
    ) -> Float {
        guard held != 0 else { return 0 }
        var ramp = current * rampDuration
        if previous != 0, held.sign != previous.sign {
            ramp = -ramp
        }
        ramp += inputSign(held) * frameDuration
        return max(-rampDuration, min(rampDuration, ramp)) / rampDuration
    }

    private func inputSign(_ value: Float) -> Float {
        value < 0 ? -1 : value > 0 ? 1 : 0
    }
}

struct PlayerInputState: Sendable {
    private var ramp: PlayerInputRamp
    private var held = InputSnapshot.zero
    private var controller = InputSnapshot.zero
    private var mouseDeltaX: Float = 0
    private var mouseDeltaY: Float = 0
    private var guidebotDeploymentIsPending = false
    private var guidebotActiveGoalRequestIsPending = false
    private var primaryFireIsHeld = false
    private var secondaryFireIsHeld = false
    private var playerFlareIsPending = false
    private var inventoryUseIsPending = false
    private var headlightToggleIsPending = false
    private var rearViewPressIsPending = false
    private var rearViewIsHeld = false
    private(set) var gameplayIsActive = true
    var mouseLookEnabled = false

    init(rampDuration: Float = 0.35) {
        ramp = PlayerInputRamp(rampDuration: rampDuration)
    }

    mutating func setHeld(_ snapshot: InputSnapshot) {
        held = gameplayIsActive ? snapshot : .zero
    }

    mutating func setController(_ snapshot: InputSnapshot) {
        controller = gameplayIsActive ? snapshot : .zero
    }

    mutating func accumulateMouseDelta(x: Float, y: Float) {
        precondition(x.isFinite && y.isFinite)
        guard gameplayIsActive else { return }
        mouseDeltaX += x
        mouseDeltaY += y
    }

    mutating func requestGuidebotDeployment() {
        guard gameplayIsActive else { return }
        guidebotDeploymentIsPending = true
    }

    mutating func requestTrainingGuidebotActiveGoal() {
        guard gameplayIsActive else { return }
        guidebotActiveGoalRequestIsPending = true
    }

    mutating func setPrimaryFireHeld(_ isHeld: Bool) {
        primaryFireIsHeld = gameplayIsActive && isHeld
    }

    mutating func setSecondaryFireHeld(_ isHeld: Bool) {
        secondaryFireIsHeld = gameplayIsActive && isHeld
    }

    mutating func requestInventoryUse() {
        guard gameplayIsActive else { return }
        inventoryUseIsPending = true
    }

    mutating func requestPlayerFlare() {
        guard gameplayIsActive else { return }
        playerFlareIsPending = true
    }

    mutating func cancelPlayerFlareRequest() {
        playerFlareIsPending = false
    }

    mutating func requestHeadlightToggle() {
        guard gameplayIsActive else { return }
        headlightToggleIsPending = true
    }

    mutating func setRearView(pressed: Bool, held: Bool) {
        guard gameplayIsActive else {
            rearViewPressIsPending = false
            rearViewIsHeld = false
            return
        }
        rearViewPressIsPending = rearViewPressIsPending || pressed
        rearViewIsHeld = held
    }

    mutating func cancelRearViewInput() {
        rearViewPressIsPending = false
        rearViewIsHeld = false
    }

    mutating func snapshot(frameDuration: Float) -> InputSnapshot {
        let keyboard = ramp.snapshot(
            held: held,
            frameDuration: frameDuration,
            gameplayIsActive: gameplayIsActive
        )
        guard gameplayIsActive else {
            mouseDeltaX = 0
            mouseDeltaY = 0
            return .zero
        }
        let deltaX = mouseDeltaX
        let deltaY = mouseDeltaY
        let deploysTrainingGuidebot = guidebotDeploymentIsPending
        let requestsTrainingGuidebotActiveGoal =
            guidebotActiveGoalRequestIsPending
        let firesPrimaryWeapon = primaryFireIsHeld
        let firesSecondaryWeapon = secondaryFireIsHeld
        let firesPlayerFlare = playerFlareIsPending
        let usesInventory = inventoryUseIsPending
        let togglesHeadlight = headlightToggleIsPending
        let rearViewPressed = rearViewPressIsPending
        let rearViewHeld = rearViewIsHeld
        mouseDeltaX = 0
        mouseDeltaY = 0
        guidebotDeploymentIsPending = false
        guidebotActiveGoalRequestIsPending = false
        inventoryUseIsPending = false
        headlightToggleIsPending = false
        playerFlareIsPending = false
        rearViewPressIsPending = false
        let mouseNormalizer = 10_000 * max(frameDuration, 0.005)
        let mouseYaw = mouseLookEnabled ? 0 : deltaX / mouseNormalizer
        let mousePitch = mouseLookEnabled ? 0 : -deltaY / mouseNormalizer
        let directScale = 2 * Float.pi / 10_000
        return InputSnapshot(
            forward: keyboard.forward + controller.forward,
            sideways: keyboard.sideways + controller.sideways,
            vertical: keyboard.vertical + controller.vertical,
            pitch: max(
                -0.75,
                min(0.75, keyboard.pitch + controller.pitch + mousePitch)
            ),
            yaw: keyboard.yaw + controller.yaw + mouseYaw,
            roll: keyboard.roll + controller.roll,
            afterburner: max(keyboard.afterburner, controller.afterburner),
            directLookPitchRadians: mouseLookEnabled ? -deltaY * directScale : 0,
            directLookYawRadians: mouseLookEnabled ? deltaX * directScale : 0,
            firesPrimaryWeapon: firesPrimaryWeapon,
            firesSecondaryWeapon: firesSecondaryWeapon,
            firesPlayerFlare: firesPlayerFlare,
            deploysTrainingGuidebot: deploysTrainingGuidebot,
            requestsTrainingGuidebotActiveGoal:
                requestsTrainingGuidebotActiveGoal,
            usesInventory: usesInventory,
            togglesHeadlight: togglesHeadlight,
            rearViewPressed: rearViewPressed,
            rearViewHeld: rearViewHeld
        )
    }

    mutating func setGameplayActive(
        _ active: Bool,
        simulation: PlayerSimulation?,
        at timestamp: Double
    ) {
        precondition(timestamp.isFinite)
        if !active {
            held = .zero
            controller = .zero
            mouseDeltaX = 0
            mouseDeltaY = 0
            guidebotDeploymentIsPending = false
            guidebotActiveGoalRequestIsPending = false
            primaryFireIsHeld = false
            secondaryFireIsHeld = false
            playerFlareIsPending = false
            inventoryUseIsPending = false
            headlightToggleIsPending = false
            rearViewPressIsPending = false
            rearViewIsHeld = false
            _ = ramp.snapshot(
                held: .zero,
                frameDuration: simulation?.frameDuration ?? 0,
                gameplayIsActive: false
            )
        }
        guard active != gameplayIsActive else { return }
        if active {
            simulation?.startTime(at: timestamp)
        } else {
            simulation?.stopTime(at: timestamp)
        }
        gameplayIsActive = active
    }
}
