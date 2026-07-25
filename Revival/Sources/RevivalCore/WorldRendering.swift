// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct PerspectiveProjection: Codable, Equatable, Sendable {
    let horizontalFieldOfViewRadians: Float
    let aspectRatio: Float

    static let sourceDefault = PerspectiveProjection(
        horizontalFieldOfViewRadians: 3.14 * 72 / 180,
        aspectRatio: 4.0 / 3.0
    )

    static let squareNinetyDegrees = PerspectiveProjection(
        horizontalFieldOfViewRadians: .pi / 2,
        aspectRatio: 1
    )

    func withAspectRatio(_ aspectRatio: Float) -> PerspectiveProjection {
        precondition(aspectRatio.isFinite && aspectRatio > 0)
        let verticalTangent = tan(horizontalFieldOfViewRadians / 2) / self.aspectRatio
        return PerspectiveProjection(
            horizontalFieldOfViewRadians: 2 * atan(verticalTangent * aspectRatio),
            aspectRatio: aspectRatio
        )
    }
}

struct RoomCamera: Codable, Equatable, Sendable {
    let position: Vector3
    let target: Vector3
    let up: Vector3
    let projection: PerspectiveProjection

    init(
        position: Vector3,
        target: Vector3,
        up: Vector3,
        projection: PerspectiveProjection = .sourceDefault
    ) {
        self.position = position
        self.target = target
        self.up = up
        self.projection = projection
    }

    static let trainingRoom3 = RoomCamera(
        position: .init(x: 2_061.7124, y: -220.75536, z: 2_206.3005),
        target: .init(x: 2_061.7124, y: -200, z: 2_206.3005),
        up: .init(x: 0, y: 0, z: 1)
    )
}

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
        directLookYawRadians: Float = 0
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
        mouseDeltaX = 0
        mouseDeltaY = 0
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
            directLookYawRadians: mouseLookEnabled ? deltaX * directScale : 0
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

struct PlayerView: Equatable, Sendable {
    let playerID: Int
    let objectHandle: UInt32
    let roomSourceIndex: Int
    let camera: RoomCamera
    let collisionRadius: Float
}

func reciprocalPortalComponent(
    rooms: [LevelRoom],
    startRoomSourceIndex: Int
) -> Set<Int> {
    let roomsBySourceIndex = Dictionary(
        uniqueKeysWithValues: rooms.map { ($0.sourceIndex, $0) }
    )
    guard roomsBySourceIndex[startRoomSourceIndex] != nil else {
        return []
    }

    var reached: Set<Int> = [startRoomSourceIndex]
    var pending = [startRoomSourceIndex]
    while let sourceIndex = pending.popLast() {
        let room = roomsBySourceIndex[sourceIndex]!
        for (portalIndex, portal) in room.portals.enumerated() {
            guard let destination = roomsBySourceIndex[portal.connectedRoom],
                  destination.portals.indices.contains(portal.connectedPortal)
            else {
                continue
            }
            let reciprocal = destination.portals[portal.connectedPortal]
            guard reciprocal.connectedRoom == sourceIndex,
                  reciprocal.connectedPortal == portalIndex,
                  reached.insert(destination.sourceIndex).inserted
            else {
                continue
            }
            pending.append(destination.sourceIndex)
        }
    }
    return reached
}

func defaultPlayerView(
    in level: Level,
    projection: PerspectiveProjection = .sourceDefault
) -> PlayerView {
    let binding = level.defaultPlayerBinding!
    let object = level.objects.first { $0.handle == binding.objectHandle }!
    let ship = level.shipDefinitions.first { $0.source == binding.ship }!
    guard case let .room(roomSourceIndex) = object.location else {
        preconditionFailure("The validated default player start is indoor.")
    }
    return PlayerView(
        playerID: binding.playerID,
        objectHandle: object.handle,
        roomSourceIndex: roomSourceIndex,
        camera: RoomCamera(
            position: object.position,
            target: object.position + object.orientation.forward,
            up: object.orientation.up,
            projection: projection
        ),
        collisionRadius: ship.presentationSize * 0.8
    )
}

struct PlayerSimulationFrame: Equatable, Sendable {
    let systemsFrameDuration: Float
    let systemsGameTime: Float
    let storedFrameDuration: Float
    let gameTime: Float
    let playerView: PlayerView
    let velocity: Vector3
    let angularVelocity: Vector3
    let turnrollFixedAngle: Float
    let wallContact: IndoorWallContact?
}

enum IndoorAutoLevelMode: Int, Sendable {
    case off = 0
    case standard = 1
    case newPlayer = 2
}

final class PlayerSimulation {
    private(set) var level: Level
    private(set) var frameDuration: Float = 0.1
    private(set) var gameTime: Float = 0
    private(set) var velocity = Vector3.zero
    private(set) var angularVelocity: Vector3
    private(set) var turnrollFixedAngle: Float = 0
    private(set) var indoorAutoLevelMode = IndoorAutoLevelMode.newPlayer
    private(set) var afterburnerFuel: Float = 5
    private(set) var afterburnerIsActive = false
    private(set) var energy: Float = 100
    private(set) var afterburnerMagnitude: Float = 0
    private(set) var wiggleFalloff: Float = 0

    private var lastTimestamp: Double
    private var lastThrustTime: Float = 0
    private var pauseDepth = 0
    private var pauseTimestamp: Double?

    init(level: Level, presentationReadyTimestamp: Double) {
        precondition(presentationReadyTimestamp.isFinite)
        precondition(level.defaultPlayerBinding != nil)
        self.level = level
        let binding = level.defaultPlayerBinding!
        let ship = level.shipDefinitions.first { $0.source == binding.ship }!
        angularVelocity = ship.physics.initialAngularVelocity
        lastTimestamp = presentationReadyTimestamp
    }

    func update(at timestamp: Double, input: InputSnapshot) -> PlayerSimulationFrame {
        precondition(timestamp.isFinite && timestamp >= lastTimestamp)
        precondition(pauseDepth == 0)
        let systemsFrameDuration = frameDuration
        let systemsGameTime = gameTime

        let binding = level.defaultPlayerBinding!
        let objectIndex = level.objects.firstIndex {
            $0.handle == binding.objectHandle
        }!
        var object = level.objects[objectIndex]
        let ship = level.shipDefinitions.first { $0.source == binding.ship }!
        guard case let .room(startRoom) = object.location else {
            preconditionFailure("The Slice 10 player simulation is indoor.")
        }
        var orientation = object.orientation
        if input.directLookPitchRadians != 0 || input.directLookYawRadians != 0 {
            orientation = sourceMatrixMultiply(
                orientation,
                sourceRotationMatrix(
                    pitch: sourceFixedAngleRadians(
                        input.directLookPitchRadians
                    ),
                    yaw: sourceFixedAngleRadians(
                        input.directLookYawRadians
                    ),
                    roll: 0
                )
            )
        }
        let linearThrustOrientation = orientation
        var forwardControl = input.forward
        if input.afterburner > 0 {
            if afterburnerFuel > 0 {
                afterburnerIsActive = true
                forwardControl = sourceAfterburnerForwardControl(
                    afterburner: input.afterburner,
                    fuel: afterburnerFuel
                )
                afterburnerFuel -= systemsFrameDuration
                if afterburnerFuel < 0 {
                    afterburnerFuel = 0
                }
            } else {
                afterburnerIsActive = false
            }
        } else {
            afterburnerIsActive = false
            if afterburnerFuel < 5, energy > 5 {
                afterburnerFuel += systemsFrameDuration
                if afterburnerFuel > 5 {
                    afterburnerFuel = 5
                }
                energy -= systemsFrameDuration
            }
        }
        let force = Vector3(
            x: ship.physics.fullThrust * (
                linearThrustOrientation.forward.x * forwardControl
                    + linearThrustOrientation.up.x * input.vertical
                    + linearThrustOrientation.right.x * input.sideways
            ),
            y: ship.physics.fullThrust * (
                linearThrustOrientation.forward.y * forwardControl
                    + linearThrustOrientation.up.y * input.vertical
                    + linearThrustOrientation.right.y * input.sideways
            ),
            z: ship.physics.fullThrust * (
                linearThrustOrientation.forward.z * forwardControl
                    + linearThrustOrientation.up.z * input.vertical
                    + linearThrustOrientation.right.z * input.sideways
            )
        )
        let view = defaultPlayerView(in: level)
        var position = object.position
        var roomSourceIndex = startRoom
        if ship.physics.behaviors.contains(.wiggle) {
            if sqrt(dot(force, force)) < 0.1 {
                wiggleFalloff -= systemsFrameDuration / 2
            } else {
                wiggleFalloff += systemsFrameDuration / 2
            }
            wiggleFalloff = max(0, min(1, wiggleFalloff))
            let scale = max(0.1, 1 - wiggleFalloff)
            let wiggle = ship.physics.wiggleAmplitude * scale * (
                sourceFixedSine(
                    gameTime: systemsGameTime,
                    wigglesPerSecond: ship.physics.wigglesPerSecond
                )
                    - sourceFixedSine(
                        gameTime: systemsGameTime - systemsFrameDuration,
                        wigglesPerSecond: ship.physics.wigglesPerSecond
                    )
            )
            let trace = traceIndoorMovement(
                in: level,
                startRoom: roomSourceIndex,
                start: position,
                end: position + linearThrustOrientation.up * wiggle,
                radius: view.collisionRadius
            )
            if case .noHit = trace.outcome {
                position = trace.finalPosition
                roomSourceIndex = trace.containingRoomSourceIndex
            }
        }
        if turnrollFixedAngle != 0 {
            orientation = sourceMatrixMultiply(
                orientation,
                sourceRotationMatrix(
                    pitch: 0,
                    yaw: 0,
                    roll: sourceFixedAngleUnits(-turnrollFixedAngle)
                )
            )
        }

        var rotationalThrust = Vector3(
            x: ship.physics.fullRotationalThrust
                * max(-0.75, min(0.75, input.pitch)),
            y: ship.physics.fullRotationalThrust * input.yaw,
            z: ship.physics.fullRotationalThrust * input.roll
        )
        if forwardControl != 0 || input.sideways != 0 || input.vertical != 0
            || rotationalThrust != .zero {
            lastThrustTime = gameTime
        }
        rotationalThrust = sourceIndoorAutoLevelThrust(
            rotationalThrust,
            orientation: orientation,
            storedOrientation: object.orientation,
            fullRotationalThrust: ship.physics.fullRotationalThrust,
            turnrollFixedAngle: turnrollFixedAngle,
            mode: indoorAutoLevelMode,
            gameTime: gameTime,
            lastThrustTime: lastThrustTime
        )
        angularVelocity = analyticAngularVelocity(
            velocity: angularVelocity,
            force: rotationalThrust,
            mass: ship.physics.mass,
            drag: ship.physics.rotationalDrag,
            duration: systemsFrameDuration
        )
        orientation = sourceMatrixMultiply(
            orientation,
            sourceRotationMatrix(
                pitch: sourceFixedAngleUnits(
                    angularVelocity.x * systemsFrameDuration
                ),
                yaw: sourceFixedAngleUnits(
                    angularVelocity.y * systemsFrameDuration
                ),
                roll: sourceFixedAngleUnits(
                    angularVelocity.z * systemsFrameDuration
                )
            )
        )
        if ship.physics.behaviors.contains(.turnroll) {
            let desired = max(
                -32_000,
                min(
                    32_000,
                    -angularVelocity.y * ship.physics.turnrollRatio
                )
            )
            let maximumChange = Float(
                Int(ship.physics.maximumTurnrollRate * systemsFrameDuration)
            )
            if abs(desired - turnrollFixedAngle) > maximumChange {
                turnrollFixedAngle += desired > turnrollFixedAngle
                    ? maximumChange
                    : -maximumChange
            } else {
                turnrollFixedAngle = Float(Int(desired))
            }
        }
        if turnrollFixedAngle != 0 {
            orientation = sourceMatrixMultiply(
                orientation,
                sourceRotationMatrix(
                    pitch: 0,
                    yaw: 0,
                    roll: sourceFixedAngleUnits(turnrollFixedAngle)
                )
            )
        }
        orientation = sourceOrthogonalized(orientation)
        object.orientation = orientation
        level.objects[objectIndex].orientation = orientation

        var remainingDuration = systemsFrameDuration
        var responseForce = force
        var wallContact: IndoorWallContact?
        var collisionCount = 0
        while remainingDuration > 0 && collisionCount < 9 {
            let integrated = analyticLinearMotion(
                position: position,
                velocity: velocity,
                force: responseForce,
                mass: ship.physics.mass,
                drag: ship.physics.drag,
                duration: remainingDuration
            )
            let trace = traceIndoorMovement(
                in: level,
                startRoom: roomSourceIndex,
                start: position,
                end: integrated.position,
                radius: view.collisionRadius
            )
            guard case let .wallHit(contact) = trace.outcome else {
                position = trace.finalPosition
                roomSourceIndex = trace.containingRoomSourceIndex
                velocity = integrated.velocity
                remainingDuration = 0
                break
            }

            wallContact = wallContact ?? contact
            let attemptedDistance = vectorDistance(position, integrated.position)
            let priorRemainingDuration = remainingDuration
            remainingDuration = attemptedDistance > 0
                ? priorRemainingDuration
                    * ((attemptedDistance - contact.distance) / attemptedDistance)
                : 0
            let movedTime = priorRemainingDuration - remainingDuration
            if movedTime > 0.0001 {
                velocity = Vector3(
                    x: (trace.finalPosition.x - position.x) / movedTime,
                    y: (trace.finalPosition.y - position.y) / movedTime,
                    z: (trace.finalPosition.z - position.z) / movedTime
                )
            }
            position = trace.finalPosition
            roomSourceIndex = trace.containingRoomSourceIndex

            let normalVelocity = dot(contact.normal, velocity)
            if surfacePhysicsBehavior(for: contact, in: level) == .forceField {
                velocity = velocity + contact.normal * (-4 * normalVelocity)
            } else {
                let speedBeforeResponse = sqrt(dot(velocity, velocity))
                let normalForce = dot(contact.normal, responseForce)
                responseForce = responseForce
                    + contact.normal * (-1.001 * normalForce)
                velocity = velocity
                    + contact.normal * (-1.001 * normalVelocity)
                if remainingDuration == priorRemainingDuration {
                    velocity = velocity + contact.normal
                }
                let projectedSpeed = sqrt(dot(velocity, velocity))
                if projectedSpeed > 0 {
                    velocity = velocity / projectedSpeed
                        * ((projectedSpeed + speedBeforeResponse) / 2)
                }
            }
            collisionCount += 1
        }
        if remainingDuration > 0 {
            velocity = .zero
        }
        level.objects[objectIndex].position = position
        level.objects[objectIndex].location = .room(roomSourceIndex)

        if afterburnerIsActive {
            afterburnerMagnitude += 2 * systemsFrameDuration
        } else {
            afterburnerMagnitude -= 2 * systemsFrameDuration
        }
        afterburnerMagnitude = max(0, min(1, afterburnerMagnitude))
        let projection = PerspectiveProjection(
            horizontalFieldOfViewRadians:
                PerspectiveProjection.sourceDefault.horizontalFieldOfViewRadians
                * (1 + afterburnerMagnitude * 0.08),
            aspectRatio: PerspectiveProjection.sourceDefault.aspectRatio
        )

        frameDuration = Float(timestamp - lastTimestamp)
        lastTimestamp = timestamp
        gameTime += frameDuration

        return PlayerSimulationFrame(
            systemsFrameDuration: systemsFrameDuration,
            systemsGameTime: systemsGameTime,
            storedFrameDuration: frameDuration,
            gameTime: gameTime,
            playerView: defaultPlayerView(in: level, projection: projection),
            velocity: velocity,
            angularVelocity: angularVelocity,
            turnrollFixedAngle: turnrollFixedAngle,
            wallContact: wallContact
        )
    }

    func stopTime(at timestamp: Double) {
        precondition(timestamp.isFinite && timestamp >= lastTimestamp)
        if pauseDepth == 0 {
            pauseTimestamp = timestamp
        }
        pauseDepth += 1
    }

    func setIndoorAutoLevelMode(_ mode: IndoorAutoLevelMode) {
        indoorAutoLevelMode = mode
    }

    func startTime(at timestamp: Double) {
        precondition(timestamp.isFinite)
        guard pauseDepth > 0 else { return }
        pauseDepth -= 1
        if pauseDepth == 0 {
            let pausedAt = pauseTimestamp!
            precondition(timestamp >= pausedAt)
            lastTimestamp += timestamp - pausedAt
            pauseTimestamp = nil
        }
    }
}

func sourceAfterburnerForwardControl(
    afterburner: Float,
    fuel: Float
) -> Float {
    var punch: Float = 1
    if fuel > 4.5 {
        punch = 1.8
    } else if fuel > 4, fuel < 4.5 {
        var normalizedFuel = Float(Double(fuel) - 5.0 * 0.8)
        normalizedFuel = Float(Double(normalizedFuel) / (5.0 * 0.1))
        punch = Float(1.0 + Double(normalizedFuel) * 0.8)
    }
    return Float(Double(afterburner) * 1.6 * Double(punch))
}

private func sourceFixedSine(
    gameTime: Float,
    wigglesPerSecond: Float
) -> Float {
    let sourceValue = Int(gameTime * wigglesPerSecond * 65_535) % 65_535
    let angle = UInt16(truncatingIfNeeded: sourceValue)
    let index = Int(angle >> 8) & 0xff
    let fraction = Int(angle & 0xff)
    let sourcePi: Float = 3.141592654
    let firstRadians = Float(
        Double(index) / 256 * 2 * Double(sourcePi)
    )
    let secondRadians = Float(
        Double(index + 1) / 256 * 2 * Double(sourcePi)
    )
    let first = sin(firstRadians)
    let second = sin(secondRadians)
    return Float(
        Double(first)
            + Double(second - first) * Double(fraction) / 256
    )
}

private func sourceIndoorAutoLevelThrust(
    _ input: Vector3,
    orientation: Matrix3,
    storedOrientation: Matrix3,
    fullRotationalThrust: Float,
    turnrollFixedAngle: Float,
    mode: IndoorAutoLevelMode,
    gameTime: Float,
    lastThrustTime: Float
) -> Vector3 {
    guard mode != .off else { return input }
    var result = input
    let angles = sourceExtractAngles(orientation)
    let firedRecently = gameTime < 1.5
    var pitchWasLeveled = false

    if mode == .newPlayer,
       !firedRecently,
       lastThrustTime + 1.5 < gameTime {
        let bound = 750
        var pitch = angles.pitch
        if pitch > bound,
           pitch < 65_535 - bound,
           abs(pitch - 32_768) > bound {
            pitchWasLeveled = true
            if storedOrientation.up.y < 0 {
                pitch = (pitch + 16_384) & 0xffff
            }
            let scale = min(1, 1.05 - abs(storedOrientation.up.y))
            if pitch < 16_834 {
                result = Vector3(
                    x: result.x - scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            } else if pitch < 32_768 {
                result = Vector3(
                    x: result.x + scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            } else if pitch < 49_152 {
                result = Vector3(
                    x: result.x - scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            } else {
                result = Vector3(
                    x: result.x + scale * fullRotationalThrust,
                    y: result.y,
                    z: result.z
                )
            }
        }
    }

    guard !pitchWasLeveled, abs(result.z) < 100 else { return result }
    let maximumTilt: Float = mode == .newPlayer ? 13_750 : 11_000
    let pitchIsBeyondTilt: Bool
    if angles.pitch < 32_768 {
        pitchIsBeyondTilt =
            Float(abs(angles.pitch - 16_834)) > maximumTilt
    } else {
        pitchIsBeyondTilt =
            Float(abs(angles.pitch - 49_152)) > maximumTilt
    }
    guard pitchIsBeyondTilt else { return result }

    let turnrollBound = turnrollFixedAngle == 0
        ? 10
        : Int(abs(turnrollFixedAngle))
    guard angles.roll > turnrollBound,
          angles.roll < 65_535 - turnrollBound else {
        return result
    }

    var scale: Float
    if angles.pitch < 32_768 {
        scale = (
            Float(abs(16_834 - angles.pitch)) - maximumTilt
        ) / (16_384 - maximumTilt)
    } else {
        scale = (
            Float(abs(49_152 - angles.pitch)) - maximumTilt
        ) / (16_384 - maximumTilt)
    }
    if angles.roll < 32_768 {
        let bankDistance = angles.roll > 28_672
            ? 28_672 - 16_834
            : abs(16_834 - angles.roll)
        var bankScale = 1.04 - Float(bankDistance) / 16_384
        bankScale *= bankScale
        scale *= bankScale
        if firedRecently { scale *= 0.25 }
        result = Vector3(
            x: result.x,
            y: result.y,
            z: result.z - scale * 2 * fullRotationalThrust
        )
    } else {
        let bankDistance = angles.roll < 36_864
            ? 49_152 - 36_864
            : abs(49_152 - angles.roll)
        var bankScale = 1.04 - Float(bankDistance) / 16_384
        bankScale *= bankScale
        scale *= bankScale
        if firedRecently { scale *= 0.25 }
        result = Vector3(
            x: result.x,
            y: result.y,
            z: result.z + scale * 2 * fullRotationalThrust
        )
    }
    return result
}

private func sourceExtractAngles(
    _ matrix: Matrix3
) -> (pitch: Int, yaw: Int, roll: Int) {
    if abs(matrix.forward.x) < 0.000_01,
       abs(matrix.forward.z) < 0.000_01 {
        return (
            matrix.forward.y > 0 ? 0xc000 : 0x4000,
            sourceFixedAtan2(
                cosine: matrix.right.x,
                sine: -matrix.right.z
            ),
            0
        )
    }
    let yaw = sourceFixedAtan2(
        cosine: matrix.forward.z,
        sine: matrix.forward.x
    )
    let yawRadians = Float(yaw) * (2 * Float.pi / 65_536)
    let sinYaw = sin(yawRadians)
    let cosYaw = cos(yawRadians)
    let cosPitch = abs(sinYaw) > abs(cosYaw)
        ? matrix.forward.x / sinYaw
        : matrix.forward.z / cosYaw
    let pitch = sourceFixedAtan2(
        cosine: cosPitch,
        sine: -matrix.forward.y
    )
    let roll = sourceFixedAtan2(
        cosine: matrix.up.y / cosPitch,
        sine: matrix.right.y / cosPitch
    )
    return (pitch, yaw, roll)
}

private func sourceFixedAtan2(cosine: Float, sine: Float) -> Int {
    let radians = atan2(sine, cosine)
    let positive = radians < 0 ? radians + 2 * Float.pi : radians
    return Int(positive * (65_536 / (2 * Float.pi))) & 0xffff
}

private func analyticAngularVelocity(
    velocity: Vector3,
    force: Vector3,
    mass: Float,
    drag: Float,
    duration: Float
) -> Vector3 {
    precondition(mass > 0 && drag > 0 && duration >= 0)
    let oneOverDrag = 1.0 / Double(drag)
    let decay = exp(-(Double(drag) / Double(mass)) * Double(duration))
    func component(_ velocity: Float, _ force: Float) -> Float {
        let forceOverDrag = Double(force) * oneOverDrag
        return Float(
            (Double(velocity) - forceOverDrag) * decay + forceOverDrag
        )
    }
    return Vector3(
        x: component(velocity.x, force.x),
        y: component(velocity.y, force.y),
        z: component(velocity.z, force.z)
    )
}

private func sourceFixedAngleUnits(_ fixedAngleUnits: Float) -> Int16 {
    Int16(truncatingIfNeeded: Int64(fixedAngleUnits.rounded(.towardZero)))
}

private func sourceFixedAngleRadians(_ radians: Float) -> Int16 {
    sourceFixedAngleUnits(radians * (65_536 / (2 * Float.pi)))
}

private func sourceRotationMatrix(
    pitch: Int16,
    yaw: Int16,
    roll: Int16
) -> Matrix3 {
    let radiansPerUnit = 2 * Float.pi / 65_536
    let pitchRadians = Float(pitch) * radiansPerUnit
    let yawRadians = Float(yaw) * radiansPerUnit
    let rollRadians = Float(roll) * radiansPerUnit
    let sinPitch = sin(pitchRadians)
    let cosPitch = cos(pitchRadians)
    let sinRoll = sin(rollRadians)
    let cosRoll = cos(rollRadians)
    let sinYaw = sin(yawRadians)
    let cosYaw = cos(yawRadians)
    let sinRollSinYaw = sinRoll * sinYaw
    let cosRollCosYaw = cosRoll * cosYaw
    let cosRollSinYaw = cosRoll * sinYaw
    let sinRollCosYaw = sinRoll * cosYaw
    return Matrix3(
        right: Vector3(
            x: cosRollCosYaw + sinPitch * sinRollSinYaw,
            y: sinRoll * cosPitch,
            z: sinPitch * sinRollCosYaw - cosRollSinYaw
        ),
        up: Vector3(
            x: sinPitch * cosRollSinYaw - sinRollCosYaw,
            y: cosRoll * cosPitch,
            z: sinRollSinYaw + sinPitch * cosRollCosYaw
        ),
        forward: Vector3(
            x: sinYaw * cosPitch,
            y: -sinPitch,
            z: cosYaw * cosPitch
        )
    )
}

private func sourceMatrixMultiply(_ lhs: Matrix3, _ rhs: Matrix3) -> Matrix3 {
    Matrix3(
        right: sourceTransform(rhs.right, by: lhs),
        up: sourceTransform(rhs.up, by: lhs),
        forward: sourceTransform(rhs.forward, by: lhs)
    )
}

private func sourceTransform(_ value: Vector3, by matrix: Matrix3) -> Vector3 {
    Vector3(
        x: matrix.right.x * value.x
            + matrix.up.x * value.y
            + matrix.forward.x * value.z,
        y: matrix.right.y * value.x
            + matrix.up.y * value.y
            + matrix.forward.y * value.z,
        z: matrix.right.z * value.x
            + matrix.up.z * value.y
            + matrix.forward.z * value.z
    )
}

private func sourceOrthogonalized(_ matrix: Matrix3) -> Matrix3 {
    let forward = sourceNormalized(matrix.forward)
    let right = sourceNormalized(cross(matrix.up, forward))
    return Matrix3(
        right: right,
        up: cross(forward, right),
        forward: forward
    )
}

private func sourceNormalized(_ value: Vector3) -> Vector3 {
    let magnitude = sqrt(dot(value, value))
    precondition(magnitude > 0)
    return value / magnitude
}

private func surfacePhysicsBehavior(
    for contact: IndoorWallContact,
    in level: Level
) -> SurfacePhysicsBehavior {
    let room = level.rooms.first { $0.sourceIndex == contact.roomSourceIndex }!
    let texture = room.faces[contact.faceIndex].texture
    return level.surfacePhysics.first { $0.texture == texture }!.behavior
}

private func analyticLinearMotion(
    position: Vector3,
    velocity: Vector3,
    force: Vector3,
    mass: Float,
    drag: Float,
    duration: Float
) -> (position: Vector3, velocity: Vector3) {
    precondition(mass > 0 && drag > 0 && duration >= 0)
    func component(_ p: Float, _ v: Float, _ force: Float) -> (Float, Float) {
        let p = Double(p)
        let v = Double(v)
        let force = Double(force)
        let mass = Double(mass)
        let drag = Double(drag)
        let duration = Double(duration)
        let q = force / drag
        let massOverDrag = mass / drag
        let decay = exp(-(drag / mass) * duration)
        return (
            Float(p + q * duration + massOverDrag * (v - q) * (1 - decay)),
            Float((v - q) * decay + q)
        )
    }
    let x = component(position.x, velocity.x, force.x)
    let y = component(position.y, velocity.y, force.y)
    let z = component(position.z, velocity.z, force.z)
    return (
        Vector3(x: x.0, y: y.0, z: z.0),
        Vector3(x: x.1, y: y.1, z: z.1)
    )
}

private func vectorDistance(_ lhs: Vector3, _ rhs: Vector3) -> Float {
    let x = rhs.x - lhs.x
    let y = rhs.y - lhs.y
    let z = rhs.z - lhs.z
    return sqrt(x * x + y * y + z * z)
}

enum PortalPresentation: String, Codable, Equatable, Sendable {
    case renderedSurface
    case openBoundary
}

struct RenderPortalEdge: Codable, Equatable, Sendable {
    let roomSourceIndex: Int
    let portalIndex: Int
    let faceIndex: Int
    let connectedRoom: Int
    let connectedPortal: Int
    let presentation: PortalPresentation
}

struct WorldRenderVertex: Equatable, Sendable {
    let position: Vector3
    let u: Float
    let v: Float
    let lightmapU: Float
    let lightmapV: Float
    let alpha: Float
}

struct RoomDrawItem: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let texture: SourceResource
    let blend: PresentationBlend
    let lightmapBlend: PresentationLightmapBlend
    let lightmapPageIndex: Int?
    let vertices: [WorldRenderVertex]
    let triangleIndices: [UInt32]
}

struct ModelDrawItem: Equatable, Sendable {
    let objectHandle: UInt32
    let roomSourceIndex: Int
    let model: SourceResource
    let submodelIndex: Int
    let faceIndex: Int
    let material: ModelFaceMaterial
    let blend: PresentationBlend
    let vertices: [WorldRenderVertex]
    let triangleIndices: [UInt32]
}

struct WorldLightCorona: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let assetIndex: Int
    let center: Vector3
    let size: Float
    let firstVertex: Vector3
    let normal: Vector3
    let tint: Vector3
    let blend: PresentationBlend
}

struct WorldRenderExtraction: Equatable, Sendable {
    let visibleRoomSourceIndices: [Int]
    let opaqueDrawItems: [RoomDrawItem]
    let translucentDrawItems: [RoomDrawItem]
    let admittedObjectHandles: [UInt32]
    let modelDrawItems: [ModelDrawItem]
    let lightCoronas: [WorldLightCorona]
    let portalEdges: [RenderPortalEdge]
}

struct SourceVisibleFace: Equatable, Hashable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
}

struct SourceVisibleWorld: Equatable, Sendable {
    let visibleRoomSourceIndices: [Int]
    let faces: [SourceVisibleFace]
    let portalEdges: [RenderPortalEdge]
    let objectClipWindowsByRoom: [Int: [SourceClipWindow]]
}

enum RoomRenderExtractionError: Error, Equatable {
    case missingRoom(Int)
    case missingMaterial(String)
    case missingLightmap(Int)
    case missingCoronaAsset(Int)
}

struct WaterProceduralEvaluator: Sendable {
    private static let dimension = 128
    private static let pixelCount = dimension * dimension

    private let sourceRGBA8: [UInt8]
    private let definition: WaterProceduralDefinition
    private var current = [Int16](repeating: 0, count: pixelCount)
    private var previous = [Int16](repeating: 0, count: pixelCount)
    private var output = Data(repeating: 0, count: pixelCount * 4)
    private var lastVisualTick: Int?

    init(
        image: CanonicalRGBA8Image,
        definition: WaterProceduralDefinition
    ) {
        precondition(
            image.width == Self.dimension
                && image.height == Self.dimension
                && image.rgba8.count == Self.pixelCount * 4
                && definition.lightingShift < 16
                && definition.dampingShift < 16
                && definition.elements.count <= 64
                && definition.evaluationIntervalSeconds.isFinite
                && definition.evaluationIntervalSeconds >= 0,
            "Water evaluators require validated canonical inputs."
        )
        sourceRGBA8 = [UInt8](image.rgba8)
        self.definition = definition
    }

    mutating func rgba8(visualTick: Int) -> Data {
        if lastVisualTick == visualTick { return output }

        let elapsedTicks = lastVisualTick.map { visualTick - $0 } ?? 1
        let stepCount = (1...8).contains(elapsedTicks) ? elapsedTicks : 1
        for step in stride(from: stepCount - 1, through: 0, by: -1) {
            injectStaticElements(frameCount: visualTick - step)
            output = renderCurrentWater()
            calculateNextWater()
            swap(&current, &previous)
        }
        lastVisualTick = visualTick
        return output
    }

    private mutating func injectStaticElements(frameCount: Int) {
        for (elementIndex, element) in definition.elements.enumerated() {
            guard element.kind == .heightBlob else { continue }
            let frequency = Int(element.frequency)
            if frequency != 0 && (frameCount + elementIndex) % frequency != 0 {
                continue
            }
            injectHeightBlob(element)
        }
    }

    private mutating func injectHeightBlob(_ element: WaterProceduralElement) {
        let centerX = Int(element.x1)
        let centerY = Int(element.y1)
        let radius = Int(element.size)
        let radiusSquared = radius * radius
        var left = -radius
        var top = -radius
        var right = radius
        var bottom = radius
        if centerX - radius < 1 { left -= centerX - radius - 1 }
        if centerY - radius < 1 { top -= centerY - radius - 1 }
        if centerX + radius > Self.dimension - 1 {
            right -= centerX + radius - Self.dimension + 1
        }
        if centerY + radius > Self.dimension - 1 {
            bottom -= centerY + radius - Self.dimension + 1
        }
        guard left < right, top < bottom else { return }
        let height = Int16(element.speed)
        for y in top..<bottom {
            let ySquared = y * y
            for x in left..<right where x * x + ySquared < radiusSquared {
                let index = (centerY + y) * Self.dimension + centerX + x
                current[index] = current[index] &+ height
            }
        }
    }

    private func renderCurrentWater() -> Data {
        var rgba8 = [UInt8](repeating: 0, count: Self.pixelCount * 4)
        for y in 0..<Self.dimension {
            let previousY = y == 0 ? Self.dimension - 1 : y - 1
            let nextY = y == Self.dimension - 1 ? 0 : y + 1
            for x in 0..<Self.dimension {
                let previousX = x == 0 ? Self.dimension - 1 : x - 1
                let nextX = x == Self.dimension - 1 ? 0 : x + 1
                let index = y * Self.dimension + x
                let dx = Int(current[y * Self.dimension + previousX])
                    - Int(current[y * Self.dimension + nextX])
                let dy = Int(current[previousY * Self.dimension + x])
                    - Int(current[nextY * Self.dimension + x])
                let sampleX = (x + (dx >> 3)) & (Self.dimension - 1)
                let sampleY = (y + (dy >> 3)) & (Self.dimension - 1)
                let sample = (sampleY * Self.dimension + sampleX) * 4
                let shade = min(
                    63,
                    max(0, 32 - (dx >> Int(definition.lightingShift)))
                )
                let destination = index * 4
                let shaded = shadedRGB(
                    red: sourceRGBA8[sample] >> 3,
                    green: sourceRGBA8[sample + 1] >> 3,
                    blue: sourceRGBA8[sample + 2] >> 3,
                    shade: shade
                )
                rgba8[destination] = expandFiveBits(shaded.red)
                rgba8[destination + 1] = expandFiveBits(shaded.green)
                rgba8[destination + 2] = expandFiveBits(shaded.blue)
                rgba8[destination + 3] = 255
            }
        }
        return Data(rgba8)
    }

    private func shadedRGB(
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        shade: Int
    ) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let normalized = Float(shade) / 63
        let low = min(normalized / 0.5, 1)
        let high = max((normalized - 0.5) / 0.5, 0)
        let shadedRed = min(Int(Float(red) * low + 31 * high), 31)
        let shadedBlue = min(Int(Float(blue) * low + 31 * high), 31)
        let lowGreen = min(Int(Float(green & 0x07) * low + 7 * high), 7)
        let highGreen = min(Int(Float(green & 0x18) * low + 24 * high), 24)
        return (
            UInt8(shadedRed),
            UInt8(lowGreen + highGreen),
            UInt8(shadedBlue)
        )
    }

    private mutating func calculateNextWater() {
        for y in 0..<Self.dimension {
            let north = y == 0 ? Self.dimension - 1 : y - 1
            let south = y == Self.dimension - 1 ? 0 : y + 1
            for x in 0..<Self.dimension {
                let west = x == 0 ? Self.dimension - 1 : x - 1
                let east = x == Self.dimension - 1 ? 0 : x + 1
                let index = y * Self.dimension + x
                var next = (
                    Int(current[north * Self.dimension + x])
                        + Int(current[south * Self.dimension + x])
                        + Int(current[y * Self.dimension + west])
                        + Int(current[y * Self.dimension + east])
                ) >> 1
                next -= Int(previous[index])
                next -= next >> Int(definition.dampingShift)
                previous[index] = Int16(truncatingIfNeeded: next)
            }
        }
    }
}

private func expandFiveBits(_ value: UInt8) -> UInt8 {
    value << 3 | value >> 2
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int
) throws -> WorldRenderExtraction {
    try extractWorldForRendering(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: nil
    )
}

func extractWorldForRendering(
    _ level: Level,
    playerView: PlayerView
) throws -> WorldRenderExtraction {
    try extractWorldForRendering(
        level,
        camera: playerView.camera,
        startRoomSourceIndex: playerView.roomSourceIndex,
        excludedObjectHandle: playerView.objectHandle
    )
}

func extractPreparedRoomDrawItems(
    _ level: Level,
    startRoomSourceIndex: Int
) throws -> [RoomDrawItem] {
    let component = reciprocalPortalComponent(
        rooms: level.rooms,
        startRoomSourceIndex: startRoomSourceIndex
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var items: [RoomDrawItem] = []
    for room in level.rooms
        .filter({ component.contains($0.sourceIndex) })
        .sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
        for faceIndex in room.faces.indices {
            let face = room.faces[faceIndex]
            guard faceIsRenderable(room, face: face) else { continue }
            guard let material = materialByTexture[face.texture] else {
                throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
            }
            items.append(
                try makeDrawItem(
                    room: room,
                    faceIndex: faceIndex,
                    material: material,
                    lightmaps: level.lightmaps
                )
            )
        }
    }
    return items
}

func extractPreparedModelDrawItems(
    _ level: Level,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?
) -> [ModelDrawItem] {
    let component = reciprocalPortalComponent(
        rooms: level.rooms,
        startRoomSourceIndex: startRoomSourceIndex
    )
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var items: [ModelDrawItem] = []
    for object in level.objects {
        guard object.handle != excludedObjectHandle,
              case let .room(roomSourceIndex) = object.location,
              component.contains(roomSourceIndex),
              let presentation = presentationByHandle[object.handle] else {
            continue
        }
        var seen: Set<SourceResource> = []
        for source in [
            presentation.primaryModel,
            presentation.mediumModel,
            presentation.lowModel,
        ].compactMap({ $0 }) where seen.insert(source).inserted {
            items += makeModelDrawItems(
                object: object,
                model: modelBySource[source]!,
                materialByTexture: materialByTexture,
                camera: .trainingRoom3,
                cullBackfaces: false
            )
        }
    }
    return items
}

func extractWorldForRendering(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?
) throws -> WorldRenderExtraction {
    let visibility = try extractSourceVisibleWorld(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        portalBlends: Dictionary(
            uniqueKeysWithValues: level.presentationMaterials.map {
                ($0.texture, $0.blend)
            }
        )
    )
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    let view = CameraView(camera)

    var opaqueDrawItems: [RoomDrawItem] = []
    var translucentDrawItems: [(depth: Float, item: RoomDrawItem)] = []
    let facesByRoom = Dictionary(grouping: visibility.faces, by: \.roomSourceIndex)
    for roomSourceIndex in visibility.visibleRoomSourceIndices.reversed() {
        let room = roomBySourceIndex[roomSourceIndex]!
        for faceIndex in (facesByRoom[roomSourceIndex] ?? []).map(\.faceIndex).sorted() {
            let face = room.faces[faceIndex]
            guard faceIsRenderable(room, face: face) else { continue }
            guard let material = materialByTexture[face.texture] else {
                throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
            }
            let item = try makeDrawItem(
                room: room,
                faceIndex: faceIndex,
                material: material,
                lightmaps: level.lightmaps
            )
            if case .additiveSourceAlpha = material.blend {
                let depth = item.vertices.reduce(Float.zero) {
                    $0 + view.project($1.position).depth
                } / Float(item.vertices.count)
                translucentDrawItems.append((depth, item))
            } else {
                opaqueDrawItems.append(item)
            }
        }
    }
    translucentDrawItems.sort {
        if $0.depth != $1.depth { return $0.depth > $1.depth }
        if $0.item.roomSourceIndex != $1.item.roomSourceIndex {
            return $0.item.roomSourceIndex < $1.item.roomSourceIndex
        }
        return $0.item.faceIndex < $1.item.faceIndex
    }
    let lightCoronas = try extractSourceLightCoronas(
        level,
        camera: camera,
        visibility: visibility,
        startRoomSourceIndex: startRoomSourceIndex,
        excludedObjectHandle: excludedObjectHandle
    )
    let objectPresentation = extractObjectPresentation(
        level,
        camera: camera,
        startRoomSourceIndex: startRoomSourceIndex,
        visibility: visibility,
        excludedObjectHandle: excludedObjectHandle
    )
    return WorldRenderExtraction(
        visibleRoomSourceIndices: visibility.visibleRoomSourceIndices,
        opaqueDrawItems: opaqueDrawItems,
        translucentDrawItems: translucentDrawItems.map(\.item),
        admittedObjectHandles: objectPresentation.handles,
        modelDrawItems: objectPresentation.drawItems,
        lightCoronas: lightCoronas,
        portalEdges: visibility.portalEdges
    )
}

private func extractObjectPresentation(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    visibility: SourceVisibleWorld,
    excludedObjectHandle: UInt32?
) -> (handles: [UInt32], drawItems: [ModelDrawItem]) {
    guard !level.objectPresentations.isEmpty else { return ([], []) }
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    let visibleRooms = Set(visibility.visibleRoomSourceIndices)
    let view = CameraView(camera)
    var accepted: [(depth: Float, ordinal: Int, object: PlacedObject,
                    presentation: ObjectPresentationReference, model: CanonicalModel)] = []
    for (ordinal, object) in level.objects.enumerated() {
        guard object.handle != excludedObjectHandle,
              let presentation = presentationByHandle[object.handle],
              case let .room(roomSourceIndex) = object.location,
              visibleRooms.contains(roomSourceIndex),
              let primary = modelBySource[presentation.primaryModel] else {
            continue
        }
        let size = sourceObjectPresentationSize(model: primary, objectType: object.type)
        guard sourceObjectIsPortalSafe(
            object,
            size: size,
            startRoomSourceIndex: startRoomSourceIndex,
            clipWindowsByRoom: visibility.objectClipWindowsByRoom,
            view: view
        ), sourceSphereIsVisible(object.position, radius: size, view: view) else {
            continue
        }
        let depth = view.depth(of: object.position)
        let selectedSource = sourceLODModel(presentation, depth: depth)
        guard let model = modelBySource[selectedSource] else {
            preconditionFailure("validated object presentation references must resolve")
        }
        accepted.append((depth, ordinal, object, presentation, model))
    }
    accepted.sort {
        $0.depth == $1.depth ? $0.ordinal < $1.ordinal : $0.depth > $1.depth
    }
    return (
        accepted.map { $0.object.handle },
        accepted.flatMap {
            makeModelDrawItems(
                object: $0.object,
                model: $0.model,
                materialByTexture: materialByTexture,
                camera: camera
            )
        }
    )
}

func sourceObjectPresentationSize(
    model: CanonicalModel,
    objectType: UInt8
) -> Float {
    let offsets = accumulatedModelOffsets(model)
    var maximumDistanceSquared: Float = 0
    for submodel in model.submodels {
        let offset = offsets[submodel.sourceIndex]
        for vertex in submodel.vertices {
            let transformed = offset + vertex.position
            maximumDistanceSquared = max(
                maximumDistanceSquared,
                dot(transformed, transformed)
            )
        }
    }
    var size = sqrt(maximumDistanceSquared) + 0.01
    if objectType == 7 { size *= 2 }
    return size
}

private func sourceObjectIsPortalSafe(
    _ object: PlacedObject,
    size: Float,
    startRoomSourceIndex: Int,
    clipWindowsByRoom: [Int: [SourceClipWindow]],
    view: CameraView
) -> Bool {
    guard case let .room(roomSourceIndex) = object.location else { return false }
    if roomSourceIndex == startRoomSourceIndex { return true }
    return (clipWindowsByRoom[roomSourceIndex] ?? []).contains { window in
        sourceCubeIntersectsWindow(
            center: object.position,
            halfExtent: size,
            view: view,
            window: window
        )
    }
}

private func sourceCubeIntersectsWindow(
    center: Vector3,
    halfExtent: Float,
    view: CameraView,
    window: SourceClipWindow
) -> Bool {
    var combined = UInt8.max
    for x in [-halfExtent, halfExtent] {
        for y in [-halfExtent, halfExtent] {
            for z in [-halfExtent, halfExtent] {
                let point = view.project(center + .init(x: x, y: y, z: z))
                if point.depth <= 0 { return true }
                combined &= clipCode(point, window: window)
            }
        }
    }
    return combined == 0
}

private func sourceSphereIsVisible(
    _ position: Vector3,
    radius: Float,
    view: CameraView
) -> Bool {
    let relative = position - view.eye
    let horizontal = dot(relative, view.right)
    let vertical = dot(relative, view.up)
    let depth = dot(relative, view.forward)
    guard depth >= -radius else { return false }
    let horizontalHalfFOV = atan(1 / view.horizontalProjectionScale)
    let verticalHalfFOV = atan(1 / view.verticalProjectionScale)
    guard abs(horizontal) * cos(horizontalHalfFOV)
            - depth * sin(horizontalHalfFOV) <= radius,
          abs(vertical) * cos(verticalHalfFOV)
            - depth * sin(verticalHalfFOV) <= radius else {
        return false
    }
    return true
}

private func sourceLODModel(
    _ presentation: ObjectPresentationReference,
    depth: Float
) -> SourceResource {
    if let mediumDistance = presentation.mediumDistance,
       depth >= mediumDistance {
        if let lowDistance = presentation.lowDistance,
           depth >= lowDistance {
            return presentation.lowModel
                ?? presentation.mediumModel
                ?? presentation.primaryModel
        }
        return presentation.mediumModel ?? presentation.primaryModel
    }
    return presentation.primaryModel
}

private func makeModelDrawItems(
    object: PlacedObject,
    model: CanonicalModel,
    materialByTexture: [SourceResource: PresentationMaterial],
    camera: RoomCamera,
    cullBackfaces: Bool = true
) -> [ModelDrawItem] {
    guard case let .room(roomSourceIndex) = object.location else {
        preconditionFailure("model presentation is indoor in the Slice 6 island")
    }
    let offsets = accumulatedModelOffsets(model)
    var opaque: [ModelDrawItem] = []
    var alpha: [ModelDrawItem] = []
    for submodel in model.submodels.sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
        guard submodel.presentation == .standard else { continue }
        let offset = offsets[submodel.sourceIndex]
        for (faceIndex, face) in submodel.faces.enumerated() {
            let transformedNormal = transform(face.normal, by: object.orientation)
            let firstLocal = offset + submodel.vertices[face.corners[0].vertexIndex].position
            let firstWorld = object.position + transform(firstLocal, by: object.orientation)
            guard !cullBackfaces
                    || dot(camera.position - firstWorld, transformedNormal) >= 0 else {
                continue
            }
            let vertices = face.corners.map { corner in
                let source = submodel.vertices[corner.vertexIndex]
                let local = offset + source.position
                return WorldRenderVertex(
                    position: object.position + transform(local, by: object.orientation),
                    u: corner.u,
                    v: corner.v,
                    lightmapU: 0,
                    lightmapV: 0,
                    alpha: source.alpha
                )
            }
            var indices: [UInt32] = []
            for index in 1..<(vertices.count - 1) {
                indices.append(contentsOf: [0, UInt32(index), UInt32(index + 1)])
            }
            let blend: PresentationBlend
            switch face.material {
            case let .texture(texture):
                guard let material = materialByTexture[texture] else {
                    preconditionFailure("validated model materials must resolve")
                }
                blend = material.blend
            case .sourceColor:
                blend = .sourceAlpha(opacity: 255)
            }
            let item = ModelDrawItem(
                objectHandle: object.handle,
                roomSourceIndex: roomSourceIndex,
                model: model.source,
                submodelIndex: submodel.sourceIndex,
                faceIndex: faceIndex,
                material: face.material,
                blend: blend,
                vertices: vertices,
                triangleIndices: indices
            )
            switch blend {
            case .opaque: opaque.append(item)
            case .sourceAlpha, .additiveSourceAlpha: alpha.append(item)
            }
        }
    }
    return opaque + alpha
}

private func accumulatedModelOffsets(_ model: CanonicalModel) -> [Vector3] {
    var offsets = [Vector3?](repeating: nil, count: model.submodels.count)

    func resolve(_ sourceIndex: Int) -> Vector3 {
        if let offset = offsets[sourceIndex] { return offset }

        let submodel = model.submodels[sourceIndex]
        let parentOffset = submodel.parentIndex.map(resolve) ?? .zero
        let offset = parentOffset + submodel.offset
        offsets[sourceIndex] = offset
        return offset
    }

    return model.submodels.indices.map(resolve)
}

func extractSourceLightCoronas(
    _ level: Level,
    camera: RoomCamera,
    visibility: SourceVisibleWorld,
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32? = nil
) throws -> [WorldLightCorona] {
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    let materialByTexture = Dictionary(
        uniqueKeysWithValues: level.presentationMaterials.map { ($0.texture, $0) }
    )
    var result: [WorldLightCorona] = []
    for visibleFace in visibility.faces {
        let room = roomBySourceIndex[visibleFace.roomSourceIndex]!
        let face = room.faces[visibleFace.faceIndex]
        guard face.portalIndex == nil,
              face.allowsLightCorona,
              let corona = materialByTexture[face.texture]?.lightCorona else {
            continue
        }
        guard level.presentationCoronaAssets.indices.contains(corona.assetIndex) else {
            throw RoomRenderExtractionError.missingCoronaAsset(corona.assetIndex)
        }
        let geometry = sourceFaceCoronaGeometry(room: room, face: face)
        let eyeOffset = geometry.center - camera.position
        let distance = sqrt(dot(eyeOffset, eyeOffset))
        guard distance >= geometry.size * 5 else { continue }
        guard !sourceCoronaRayIsOccluded(
            from: camera.position,
            to: geometry.center,
            level: level,
            visibleRoomSourceIndices: visibility.visibleRoomSourceIndices,
            startRoomSourceIndex: startRoomSourceIndex,
            excludedObjectHandle: excludedObjectHandle
        ) else {
            continue
        }
        result.append(
            WorldLightCorona(
                roomSourceIndex: room.sourceIndex,
                faceIndex: visibleFace.faceIndex,
                assetIndex: corona.assetIndex,
                center: geometry.center,
                size: geometry.size,
                firstVertex: room.vertices[face.corners[0].vertexIndex],
                normal: faceNormal(room, face: face),
                tint: corona.tint,
                blend: corona.blend
            )
        )
    }
    return result
}

private func sourceFaceCoronaGeometry(
    room: LevelRoom,
    face: LevelFace
) -> (center: Vector3, size: Float) {
    let first = room.vertices[face.corners[0].vertexIndex]
    var totalArea: Float = 0
    var weightedX: Float = 0
    var weightedY: Float = 0
    var weightedZ: Float = 0
    for index in 1..<(face.corners.count - 1) {
        let second = room.vertices[face.corners[index].vertexIndex]
        let third = room.vertices[face.corners[index + 1].vertexIndex]
        let perpendicular = cross(second - first, third - first)
        let area = sqrt(dot(perpendicular, perpendicular)) / 2
        totalArea += area
        weightedX += ((first.x + second.x + third.x) / 3) * area
        weightedY += ((first.y + second.y + third.y) / 3) * area
        weightedZ += ((first.z + second.z + third.z) / 3) * area
    }
    precondition(totalArea > 0, "validated corona faces must have positive area")
    let normal = faceNormal(room, face: face)
    return (
        Vector3(
            x: weightedX / totalArea + normal.x / 4,
            y: weightedY / totalArea + normal.y / 4,
            z: weightedZ / totalArea + normal.z / 4
        ),
        2 * sqrt(totalArea)
    )
}

private func sourceCoronaRayIsOccluded(
    from origin: Vector3,
    to destination: Vector3,
    level: Level,
    visibleRoomSourceIndices: [Int],
    startRoomSourceIndex: Int,
    excludedObjectHandle: UInt32?
) -> Bool {
    let ray = destination - origin
    let distance = sqrt(dot(ray, ray))
    let direction = ray / distance
    let visibleRooms = Set(visibleRoomSourceIndices)
    if case let .wallHit(contact) = traceIndoorMovement(
        in: level,
        startRoom: startRoomSourceIndex,
        start: origin,
        end: destination,
        radius: 0
    ).outcome, contact.distance < distance - 0.000_1 {
        return true
    }
    let presentationByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map { ($0.objectHandle, $0) }
    )
    let modelBySource = Dictionary(
        uniqueKeysWithValues: level.models.map { ($0.source, $0) }
    )
    for object in level.objects {
        guard object.handle != excludedObjectHandle,
              object.type == 2 || object.type == 4,
              case let .room(roomSourceIndex) = object.location,
              visibleRooms.contains(roomSourceIndex),
              let presentation = presentationByHandle[object.handle],
              let model = modelBySource[presentation.primaryModel] else {
            continue
        }
        let radius = sourceObjectPresentationSize(
            model: model,
            objectType: object.type
        )
        let originToCenter = object.position - origin
        let projectedDistance = dot(originToCenter, direction)
        guard projectedDistance > 0, projectedDistance < distance else { continue }
        let closest = origin + direction * projectedDistance
        let centerOffset = object.position - closest
        if dot(centerOffset, centerOffset) <= radius * radius {
            return true
        }
    }
    return false
}

func extractSourceVisibleWorld(
    _ level: Level,
    camera: RoomCamera,
    startRoomSourceIndex: Int,
    portalBlends: [SourceResource: PresentationBlend]
) throws -> SourceVisibleWorld {
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
    )
    guard roomBySourceIndex[startRoomSourceIndex] != nil else {
        throw RoomRenderExtractionError.missingRoom(startRoomSourceIndex)
    }
    let view = CameraView(camera)
    var roomDepth = [startRoomSourceIndex: 0]
    var seenRooms: Set<Int> = []
    var visibleRoomSourceIndices: [Int] = []
    var visibleFacesByRoom: [Int: Set<Int>] = [:]
    var portalEdges: [RenderPortalEdge] = []
    var objectClipWindowsByRoom: [Int: [SourceClipWindow]] = [:]

    func renderPastPortal(_ room: LevelRoom, portalIndex: Int) throws -> Bool {
        let portal = room.portals[portalIndex]
        guard portal.flags & 0x0000_0001 != 0 else { return true }
        let face = room.faces[portal.faceIndex]
        guard let blend = portalBlends[face.texture] else {
            throw RoomRenderExtractionError.missingMaterial(face.texture.sourceName)
        }
        if case .additiveSourceAlpha = blend { return true }
        return false
    }

    func visit(_ roomSourceIndex: Int, window: ClipWindow, depth: Int) throws {
        guard let room = roomBySourceIndex[roomSourceIndex] else {
            throw RoomRenderExtractionError.missingRoom(roomSourceIndex)
        }
        if seenRooms.insert(roomSourceIndex).inserted {
            visibleRoomSourceIndices.append(roomSourceIndex)
        }
        objectClipWindowsByRoom[roomSourceIndex, default: []].append(window)
        if visibleFacesByRoom[roomSourceIndex] == nil {
            visibleFacesByRoom[roomSourceIndex] = depth == 0
                ? Set(room.faces.indices.filter {
                    faceIsFrontFacing(room, faceIndex: $0, eye: camera.position)
                })
                : []
        }

        for (portalIndex, portal) in room.portals.enumerated() {
            portalEdges.append(
                RenderPortalEdge(
                    roomSourceIndex: roomSourceIndex,
                    portalIndex: portalIndex,
                    faceIndex: portal.faceIndex,
                    connectedRoom: portal.connectedRoom,
                    connectedPortal: portal.connectedPortal,
                    presentation: portal.flags & 0x0000_0001 != 0
                        ? .renderedSurface
                        : .openBoundary
                )
            )
            if let connectedDepth = roomDepth[portal.connectedRoom], connectedDepth < depth {
                continue
            }
            guard faceIsFrontFacing(room, faceIndex: portal.faceIndex, eye: camera.position),
                  let portalWindow = projectedPortalWindow(
                      room,
                      faceIndex: portal.faceIndex,
                      view: view,
                      parent: window
                  ) else {
                continue
            }
            guard try renderPastPortal(room, portalIndex: portalIndex) else { continue }
            guard let connected = roomBySourceIndex[portal.connectedRoom] else {
                throw RoomRenderExtractionError.missingRoom(portal.connectedRoom)
            }
            var marked = visibleFacesByRoom[portal.connectedRoom] ?? []
            for faceIndex in connected.faces.indices where
                faceIsFrontFacing(connected, faceIndex: faceIndex, eye: camera.position)
                && faceIntersectsWindow(
                    connected,
                    faceIndex: faceIndex,
                    view: view,
                    window: portalWindow
                ) {
                marked.insert(faceIndex)
            }
            visibleFacesByRoom[portal.connectedRoom] = marked
            roomDepth[portal.connectedRoom] = depth + 1
            try visit(portal.connectedRoom, window: portalWindow, depth: depth + 1)
            roomDepth[portal.connectedRoom] = 255
        }
    }

    try visit(
        startRoomSourceIndex,
        window: .init(left: -1, top: 1, right: 1, bottom: -1),
        depth: 0
    )
    return SourceVisibleWorld(
        visibleRoomSourceIndices: visibleRoomSourceIndices,
        faces: visibleRoomSourceIndices.flatMap { roomSourceIndex in
            let room = roomBySourceIndex[roomSourceIndex]!
            return (visibleFacesByRoom[roomSourceIndex] ?? []).sorted().compactMap {
                faceIsRenderable(room, face: room.faces[$0])
                    ? SourceVisibleFace(roomSourceIndex: roomSourceIndex, faceIndex: $0)
                    : nil
            }
        },
        portalEdges: portalEdges,
        objectClipWindowsByRoom: objectClipWindowsByRoom
    )
}

func sourceRoomThreeContains(_ point: Vector3, in room: LevelRoom) -> Bool {
    precondition(
        room.sourceIndex == 3,
        "Slice 3 camera containment is defined only for source room 3"
    )
    return sourceConvexRoomContains(point, in: room)
}

func sourceConvexRoomContains(_ point: Vector3, in room: LevelRoom) -> Bool {
    room.faces.allSatisfy { face in
        let first = room.vertices[face.corners[0].vertexIndex]
        return dot(point - first, faceNormal(room, face: face)) >= 0
    }
}

private func faceIsRenderable(_ room: LevelRoom, face: LevelFace) -> Bool {
    guard let portalIndex = face.portalIndex else { return true }
    return room.portals[portalIndex].flags & 0x0000_0001 != 0
}

private func makeDrawItem(
    room: LevelRoom,
    faceIndex: Int,
    material: PresentationMaterial,
    lightmaps: LightmapCatalog
) throws -> RoomDrawItem {
    let face = room.faces[faceIndex]
    let lightmapPageIndex: Int?
    if let infoIndex = face.lightmapInfoIndex {
        let pageIndex = lightmaps.infos[infoIndex].pageIndex
        let page = lightmaps.pages[pageIndex]
        guard page.rgba8?.count == page.width * page.height * 4 else {
            throw RoomRenderExtractionError.missingLightmap(pageIndex)
        }
        lightmapPageIndex = pageIndex
    } else {
        lightmapPageIndex = nil
    }
    let vertices = face.corners.map { corner in
        WorldRenderVertex(
            position: room.vertices[corner.vertexIndex],
            u: corner.u,
            v: corner.v,
            lightmapU: corner.lightmapU ?? 0,
            lightmapV: corner.lightmapV ?? 0,
            alpha: Float(corner.alpha) / 255
        )
    }
    var triangleIndices: [UInt32] = []
    for index in 1..<(vertices.count - 1) {
        triangleIndices.append(contentsOf: [0, UInt32(index), UInt32(index + 1)])
    }
    return RoomDrawItem(
        roomSourceIndex: room.sourceIndex,
        faceIndex: faceIndex,
        texture: face.texture,
        blend: material.blend,
        lightmapBlend: material.lightmapBlend,
        lightmapPageIndex: lightmapPageIndex,
        vertices: vertices,
        triangleIndices: triangleIndices
    )
}

private struct CameraView {
    let eye: Vector3
    let right: Vector3
    let up: Vector3
    let forward: Vector3
    let horizontalProjectionScale: Float
    let verticalProjectionScale: Float

    init(_ camera: RoomCamera) {
        eye = camera.position
        forward = normalized(camera.target - camera.position)
        right = normalized(cross(forward, camera.up))
        up = cross(right, forward)
        precondition(
            camera.projection.horizontalFieldOfViewRadians.isFinite
                && camera.projection.aspectRatio.isFinite
                && camera.projection.horizontalFieldOfViewRadians > 0
                && camera.projection.horizontalFieldOfViewRadians < .pi
                && camera.projection.aspectRatio > 0,
            "camera projection must be finite and positive"
        )
        horizontalProjectionScale = 1 / tan(
            camera.projection.horizontalFieldOfViewRadians / 2
        )
        verticalProjectionScale = horizontalProjectionScale * camera.projection.aspectRatio
    }

    func project(_ point: Vector3) -> ProjectedPoint {
        let relative = point - eye
        let depth = dot(relative, forward)
        return ProjectedPoint(
            x: dot(relative, right) * horizontalProjectionScale / depth,
            y: dot(relative, up) * verticalProjectionScale / depth,
            depth: depth
        )
    }

    func depth(of point: Vector3) -> Float {
        dot(point - eye, forward)
    }
}

private struct ProjectedPoint {
    let x: Float
    let y: Float
    let depth: Float
}

struct SourceClipWindow: Equatable, Sendable {
    let left: Float
    let top: Float
    let right: Float
    let bottom: Float
}

private typealias ClipWindow = SourceClipWindow

private func projectedPortalWindow(
    _ room: LevelRoom,
    faceIndex: Int,
    view: CameraView,
    parent: ClipWindow
) -> ClipWindow? {
    guard faceIntersectsWindow(room, faceIndex: faceIndex, view: view, window: parent) else {
        return nil
    }
    let points = room.faces[faceIndex].corners.map {
        view.project(room.vertices[$0.vertexIndex])
    }
    guard points.allSatisfy({ $0.depth > 0 }) else { return nil }
    let left = max(parent.left, points.map(\.x).min()!)
    let right = min(parent.right, points.map(\.x).max()!)
    let bottom = max(parent.bottom, points.map(\.y).min()!)
    let top = min(parent.top, points.map(\.y).max()!)
    guard left <= right, bottom <= top else { return nil }
    return ClipWindow(left: left, top: top, right: right, bottom: bottom)
}

private func faceIntersectsWindow(
    _ room: LevelRoom,
    faceIndex: Int,
    view: CameraView,
    window: ClipWindow
) -> Bool {
    let points = room.faces[faceIndex].corners.map {
        view.project(room.vertices[$0.vertexIndex])
    }
    let codes = points.map { clipCode($0, window: window) }
    let combinedAnd = codes.reduce(UInt8.max, &)
    if combinedAnd != 0 { return false }
    let combinedOr = codes.reduce(UInt8.zero, |)
    if combinedOr == 0 { return true }
    for index in points.indices {
        let start = points[index]
        let end = points[(index + 1) % points.count]
        if lineIntersectsLine(start, end, window.left, window.top, window.right, window.top)
            || lineIntersectsLine(start, end, window.right, window.top, window.right, window.bottom)
            || lineIntersectsLine(start, end, window.right, window.bottom, window.left, window.bottom)
            || lineIntersectsLine(start, end, window.left, window.bottom, window.left, window.top) {
            return true
        }
    }
    return false
}

private func clipCode(_ point: ProjectedPoint, window: ClipWindow) -> UInt8 {
    guard point.depth > 0 else { return 0x10 }
    var code: UInt8 = 0
    if point.x < window.left { code |= 0x01 }
    if point.x > window.right { code |= 0x02 }
    if point.y > window.top { code |= 0x04 }
    if point.y < window.bottom { code |= 0x08 }
    return code
}

private func lineIntersectsLine(
    _ start: ProjectedPoint,
    _ end: ProjectedPoint,
    _ x1: Float,
    _ y1: Float,
    _ x2: Float,
    _ y2: Float
) -> Bool {
    var numerator = (start.y - y1) * (x2 - x1) - (start.x - x1) * (y2 - y1)
    let denominator = (end.x - start.x) * (y2 - y1) - (end.y - start.y) * (x2 - x1)
    let r = numerator / denominator
    if (0...1).contains(r) { return true }
    numerator = (start.y - y1) * (end.x - start.x) - (start.x - x1) * (end.y - start.y)
    let s = numerator / denominator
    return (0...1).contains(s)
}

private func faceIsFrontFacing(_ room: LevelRoom, faceIndex: Int, eye: Vector3) -> Bool {
    let face = room.faces[faceIndex]
    let normal = faceNormal(room, face: face)
    let first = room.vertices[face.corners[0].vertexIndex]
    return dot(eye - first, normal) > 0
}

private func faceNormal(_ room: LevelRoom, face: LevelFace) -> Vector3 {
    guard let normal = canonicalFaceNormal(room: room, face: face) else {
        preconditionFailure("validated faces must have a usable normal")
    }
    return normal
}

private func normalized(_ value: Vector3) -> Vector3 {
    let magnitude = sqrt(dot(value, value))
    precondition(magnitude > 0, "camera basis vectors must be nonzero")
    return value / magnitude
}

private func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
    Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

private func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
    Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

private func transform(_ value: Vector3, by matrix: Matrix3) -> Vector3 {
    matrix.right * value.x + matrix.up * value.y + matrix.forward * value.z
}

private func * (lhs: Vector3, rhs: Float) -> Vector3 {
    Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
}

private func / (lhs: Vector3, rhs: Float) -> Vector3 {
    Vector3(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
}

private func dot(_ lhs: Vector3, _ rhs: Vector3) -> Float {
    lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}

private func cross(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    Vector3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}
