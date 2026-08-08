// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

func segmentSphereHitFraction(
    start: Vector3,
    end: Vector3,
    center: Vector3,
    radius: Float
) -> Float? {
    let movement = end - start
    let offset = start - center
    let a = dot(movement, movement)
    guard a > 0 else {
        return dot(offset, offset) <= radius * radius ? 0 : nil
    }
    let b = 2 * dot(offset, movement)
    let c = dot(offset, offset) - radius * radius
    if c <= 0 { return 0 }
    let discriminant = b * b - 4 * a * c
    guard discriminant >= 0 else { return nil }
    let root = sqrt(discriminant)
    let first = (-b - root) / (2 * a)
    let second = (-b + root) / (2 * a)
    if (0...1).contains(first) { return first }
    if (0...1).contains(second) { return second }
    return nil
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

func sourceFixedSine(
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

func sourceIndoorAutoLevelThrust(
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
func analyticAngularVelocity(
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
func surfacePhysicsBehavior(
    for contact: IndoorWallContact,
    in level: Level
) -> SurfacePhysicsBehavior {
    let room = level.rooms.first { $0.sourceIndex == contact.roomSourceIndex }!
    let texture = room.faces[contact.faceIndex].texture
    return level.surfacePhysics.first { $0.texture == texture }!.behavior
}

func analyticLinearMotion(
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
