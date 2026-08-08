// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

func sourceExtractAngles(
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
func sourceFixedAngleUnits(_ fixedAngleUnits: Float) -> Int16 {
    Int16(truncatingIfNeeded: Int64(fixedAngleUnits.rounded(.towardZero)))
}

func sourceFixedAngleRadians(_ radians: Float) -> Int16 {
    sourceFixedAngleUnits(radians * (65_536 / (2 * Float.pi)))
}

func sourceRotationMatrix(
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

func sourceMatrixMultiply(_ lhs: Matrix3, _ rhs: Matrix3) -> Matrix3 {
    Matrix3(
        right: sourceTransform(rhs.right, by: lhs),
        up: sourceTransform(rhs.up, by: lhs),
        forward: sourceTransform(rhs.forward, by: lhs)
    )
}

func sourceTransposed(_ matrix: Matrix3) -> Matrix3 {
    Matrix3(
        right: Vector3(
            x: matrix.right.x,
            y: matrix.up.x,
            z: matrix.forward.x
        ),
        up: Vector3(
            x: matrix.right.y,
            y: matrix.up.y,
            z: matrix.forward.y
        ),
        forward: Vector3(
            x: matrix.right.z,
            y: matrix.up.z,
            z: matrix.forward.z
        )
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

func sourceOrthogonalized(_ matrix: Matrix3) -> Matrix3 {
    let forward = sourceNormalized(matrix.forward)
    let right = sourceNormalized(sourceVectorCross(matrix.up, forward))
    return Matrix3(
        right: right,
        up: sourceVectorCross(forward, right),
        forward: forward
    )
}

private func sourceNormalized(_ value: Vector3) -> Vector3 {
    let magnitude = sqrt(dot(value, value))
    precondition(magnitude > 0)
    return value / magnitude
}
func vectorDistance(_ lhs: Vector3, _ rhs: Vector3) -> Float {
    let x = rhs.x - lhs.x
    let y = rhs.y - lhs.y
    let z = rhs.z - lhs.z
    return sqrt(x * x + y * y + z * z)
}
func sourceVectorNormalized(_ value: Vector3) -> Vector3 {
    let magnitude = sqrt(dot(value, value))
    precondition(magnitude > 0, "camera basis vectors must be nonzero")
    return value / magnitude
}

func sourceOrientation(
    forward targetForward: Vector3,
    up targetUp: Vector3
) -> Matrix3 {
    let forward = sourceVectorNormalized(targetForward)
    let right = sourceVectorNormalized(sourceVectorCross(targetUp, forward))
    return .init(
        right: right,
        up: sourceVectorNormalized(sourceVectorCross(forward, right)),
        forward: forward
    )
}
func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
    Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
    Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

func transform(_ value: Vector3, by matrix: Matrix3) -> Vector3 {
    matrix.right * value.x + matrix.up * value.y + matrix.forward * value.z
}

func transform(_ value: Matrix3, by matrix: Matrix3) -> Matrix3 {
    .init(
        right: transform(value.right, by: matrix),
        up: transform(value.up, by: matrix),
        forward: transform(value.forward, by: matrix)
    )
}

func inverseTransform(_ value: Vector3, by matrix: Matrix3) -> Vector3 {
    .init(
        x: dot(value, matrix.right),
        y: dot(value, matrix.up),
        z: dot(value, matrix.forward)
    )
}

func inverseTransform(_ value: Matrix3, by matrix: Matrix3) -> Matrix3 {
    .init(
        right: inverseTransform(value.right, by: matrix),
        up: inverseTransform(value.up, by: matrix),
        forward: inverseTransform(value.forward, by: matrix)
    )
}

func * (lhs: Vector3, rhs: Float) -> Vector3 {
    Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
}

func / (lhs: Vector3, rhs: Float) -> Vector3 {
    Vector3(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
}

func dot(_ lhs: Vector3, _ rhs: Vector3) -> Float {
    lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}

func sourceVectorCross(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    Vector3(
        x: lhs.y * rhs.z - lhs.z * rhs.y,
        y: lhs.z * rhs.x - lhs.x * rhs.z,
        z: lhs.x * rhs.y - lhs.y * rhs.x
    )
}
