// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/osiris_vector.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): vm_GetMagnitudeFast (:233) and
// vm_VectorNormalizeFast (:265), the approximate normalization that level
// scripts link against.

import Foundation

/// vm_GetMagnitudeFast (osiris_vector.cpp:233): the largest component plus
/// 3/8 of the middle and 3/16 of the smallest.
func osirisMagnitudeFast(_ vector: Vector3) -> Float {
    var a = abs(vector.x)
    var b = abs(vector.y)
    var c = abs(vector.z)
    if a < b { swap(&a, &b) }
    if b < c {
        swap(&b, &c)
        if a < b { swap(&a, &b) }
    }
    let bc = (b / 4) + (c / 8)
    return a + bc + (bc / 2)
}

/// vm_VectorNormalizeFast (osiris_vector.cpp:265). A zero vector stays zero.
func osirisNormalizedFast(_ vector: Vector3) -> Vector3 {
    let magnitude = osirisMagnitudeFast(vector)
    return magnitude == 0 ? .zero : vector / magnitude
}
