// SPDX-License-Identifier: GPL-3.0-or-later
//
// The table trig of fix/fix.cpp and the angle and matrix functions of
// vecmat/vector.cpp (Descent 3, Copyright (C) 2024 Parallax Software,
// GPL-3.0-or-later) that MakeBOA uses: InitMathTables (:77), FixSin (:102),
// FixCos (:114), FixAsin (:129), FixAcos (:151), FixAtan2 (:177);
// vm_NormalizeVector (:175), vm_GetPerp (:195), vm_SinCosToMatrix,
// vm_AnglesToMatrix (:422), DoVectorToMatrix and vm_VectorToMatrix (:549)
// for a forward vector only, and vm_ExtractAnglesFromMatrix (:584). An
// angle is a 16-bit fraction of a turn; `scalar` is Float.

import Foundation

enum FixMath {
    /// PI (fix.h:79), a float.
    private static let pi: Float = 3.141592654
    /// F1_0 (fix.h:87).
    private static let one = 1 << 16

    /// sincos_table: 256 entries, 64 more for the cosine, 1 more to
    /// interpolate.
    private static let sinCosTable: [Float] = (0..<321).map { index in
        let radians = Float(Double(index) / 256.0 * 2 * Double(pi))
        return sinf(radians)
    }

    private static func fixed(_ value: Float) -> Int {
        Int(Int32(value * 65536))
    }

    /// asin_table and acos_table, one quadrant, the last entry repeated.
    private static let arcTables: (asin: [Int], acos: [Int]) = {
        var asin = [Int](repeating: 0, count: 257)
        var acos = [Int](repeating: 0, count: 257)
        for index in 0..<256 {
            let s = asinf(Float(index) / 256) / (pi * 2)
            let c = acosf(Float(index) / 256) / (pi * 2)
            asin[index] = Int(UInt16(truncatingIfNeeded: fixed(s)))
            acos[index] = Int(UInt16(truncatingIfNeeded: fixed(c)))
        }
        asin[256] = asin[255]
        acos[256] = acos[255]
        return (asin, acos)
    }()

    static func sin(_ angle: UInt16) -> Float {
        let index = Int(angle >> 8) & 0xff
        let fraction = Double(angle & 0xff)
        let s0 = sinCosTable[index]
        let s1 = sinCosTable[index + 1]
        return Float(Double(s0) + Double(s1 - s0) * fraction / 256.0)
    }

    static func cos(_ angle: UInt16) -> Float {
        let index = Int(angle >> 8) & 0xff
        let fraction = Double(angle & 0xff)
        let c0 = sinCosTable[index + 64]
        let c1 = sinCosTable[index + 65]
        return Float(Double(c0) + Double(c1 - c0) * fraction / 256.0)
    }

    static func asin(_ value: Float) -> UInt16 {
        let fixedValue = fixed(Swift.abs(value))
        if fixedValue >= one { return 0x4000 }
        let index = (fixedValue >> 8) & 0xff
        let fraction = fixedValue & 0xff
        var angle = arcTables.asin[index]
        angle += ((arcTables.asin[index + 1] - angle) * fraction) >> 8
        if value < 0 { angle = one - angle }
        return UInt16(truncatingIfNeeded: angle)
    }

    static func acos(_ value: Float) -> UInt16 {
        let fixedValue = fixed(Swift.abs(value))
        if fixedValue >= one { return 0 }
        let index = (fixedValue >> 8) & 0xff
        let fraction = fixedValue & 0xff
        var angle = arcTables.acos[index]
        angle += ((arcTables.acos[index + 1] - angle) * fraction) >> 8
        if value < 0 { angle = 0x8000 - angle }
        return UInt16(truncatingIfNeeded: angle)
    }

    /// FixAtan2: the left-handed angle whose cosine and sine have this
    /// ratio.
    static func atan2(_ cosine: Float, _ sine: Float) -> UInt16 {
        let q = sine * sine + cosine * cosine
        let m = sqrtf(q)
        if m == 0 { return 0 }
        if Swift.abs(sine) < Swift.abs(cosine) {
            var t = Int(asin(sine / m))
            if cosine < 0 { t = 0x8000 - t }
            return UInt16(truncatingIfNeeded: t)
        } else {
            var t = Int(acos(cosine / m))
            if sine < 0 { t = one - t }
            return UInt16(truncatingIfNeeded: t)
        }
    }

    /// vm_NormalizeVector: the unit vector and the magnitude (a zero
    /// vector becomes the x axis with magnitude 0).
    static func normalize(_ v: Vector3) -> (Vector3, Float) {
        let magnitude = Float(Foundation.sqrt(Double(v.x * v.x + v.y * v.y
            + v.z * v.z)))
        guard magnitude > 0 else { return (Vector3(x: 1, y: 0, z: 0), 0) }
        return (Vector3(x: v.x / magnitude, y: v.y / magnitude,
                        z: v.z / magnitude), magnitude)
    }

    /// vector::cross3.
    static func cross(_ a: Vector3, _ b: Vector3) -> Vector3 {
        Vector3(x: a.y * b.z - b.y * a.z,
                y: a.z * b.x - b.z * a.x,
                z: a.x * b.y - b.x * a.y)
    }

    /// vm_VectorToMatrix(m, fvec, NULL, NULL).
    static func matrix(forward: Vector3) -> Matrix3 {
        let (z, _) = normalize(forward)
        if z.x == 0 && z.z == 0 {
            return Matrix3(
                right: Vector3(x: 1, y: 0, z: 0),
                up: Vector3(x: 0, y: 0, z: z.y < 0 ? 1 : -1),
                forward: z
            )
        }
        let (x, _) = normalize(Vector3(x: z.z, y: 0, z: -z.x))
        return Matrix3(right: x, up: cross(z, x), forward: z)
    }

    /// vm_ExtractAnglesFromMatrix: pitch, heading, bank.
    static func angles(_ m: Matrix3) -> (p: UInt16, h: UInt16, b: UInt16) {
        let epsilon = 0.00001
        if Swift.abs(Double(m.forward.x)) < epsilon,
           Swift.abs(Double(m.forward.z)) < epsilon {
            return (m.forward.y > 0 ? 0xc000 : 0x4000,
                    atan2(m.right.x, -m.right.z), 0)
        }
        let h = atan2(m.forward.z, m.forward.x)
        let sinh = sin(h)
        let cosh = cos(h)
        let cosp = Swift.abs(sinh) > Swift.abs(cosh)
            ? m.forward.x / sinh
            : m.forward.z / cosh
        let p = atan2(cosp, -m.forward.y)
        let sinb = m.right.y / cosp
        let cosb = m.up.y / cosp
        let b = atan2(cosb, sinb)
        return (p, h, b)
    }

    /// vm_AnglesToMatrix through vm_SinCosToMatrix.
    static func matrix(p: UInt16, h: UInt16, b: UInt16) -> Matrix3 {
        let sinp = sin(p), cosp = cos(p)
        let sinb = sin(b), cosb = cos(b)
        let sinh = sin(h), cosh = cos(h)
        let sbsh = sinb * sinh
        let cbch = cosb * cosh
        let cbsh = cosb * sinh
        let sbch = sinb * cosh
        return Matrix3(
            right: Vector3(x: cbch + sinp * sbsh, y: sinb * cosp,
                           z: sinp * sbch - cbsh),
            up: Vector3(x: sinp * cbsh - sbch, y: cosb * cosp,
                        z: sbsh + sinp * cbch),
            forward: Vector3(x: sinh * cosp, y: -sinp, z: cosh * cosp)
        )
    }

    /// vm_MatrixMulVector: the vector in the matrix's frame.
    static func rotate(_ v: Vector3, _ m: Matrix3) -> Vector3 {
        Vector3(
            x: v.x * m.right.x + v.y * m.right.y + v.z * m.right.z,
            y: v.x * m.up.x + v.y * m.up.y + v.z * m.up.z,
            z: v.x * m.forward.x + v.y * m.forward.y + v.z * m.forward.z
        )
    }
}
