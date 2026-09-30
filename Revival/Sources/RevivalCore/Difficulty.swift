// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/difficulty.cpp (the per-level tables, :26-40)
// and Descent3/difficulty_external.h (the DIFFICULTY_ levels, :22-29). The
// tables the translated AI and weapons read are here; the others arrive with
// their readers.

import Foundation

/// The difficulty tables, indexed by DIFF_LEVEL.
enum Difficulty {
    /// MAX_DIFFICULTY_LEVELS (difficulty_external.h:22).
    static let levelCount = 5
    /// DIFFICULTY_TRAINEE (difficulty_external.h:25).
    static let trainee = 0
    /// DIFFICULTY_HOTSHOT (difficulty_external.h:27).
    static let hotshot = 2
    /// DIFF_LEVEL. Revival plays at Rookie (DIFFICULTY_ROOKIE,
    /// difficulty_external.h:26), the level its Training result reports,
    /// until the options menu (M4) lets the pilot choose.
    static let level = 1

    static let aiSpeed: [Float] = [0.70, 0.80, 1.00, 1.10, 1.20]
    static let aiRotationSpeed: [Float] = [0.70, 0.80, 1.00, 1.10, 1.20]
    static let aiCircleDistance: [Float] = [1.10, 1.00, 1.00, 1.00, 1.00]
    static let aiVisibilityDistance: [Float] = [0.80, 0.90, 1.00, 1.10, 1.20]
    static let aiDodgePercent: [Float] = [0.04, 0.10, 1.00, 1.00, 1.50]
    static let aiDodgeSpeed: [Float] = [0.20, 0.30, 1.00, 1.25, 1.50]
    static let aiWeaponSpeed: [Float] = [0.50, 0.75, 1.00, 1.20, 1.40]
    static let aiTurretSpeed: [Float] = [0.6, 0.7, 1.0, 1.0, 1.0]
    static let aiMinimumFireSpread: [Float] = [0.30, 0.15, 0.0, 0.0, 0.0]
}
