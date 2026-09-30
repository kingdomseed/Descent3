// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/damage.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): ApplyDamageToPlayer (:807) in single
// player. The armor scalars are 1: the pilot and ship values are not
// imported yet, and the retail ship pages set 1. Player death (KillPlayer),
// the damage sounds (SOUND_HIT_BY_*, from the static sound table), and the
// weapon effects (microwave, freeze, napalm) arrive with player death in
// M1 step 7.

import Foundation

extension GameWorld {
    /// ApplyDamageToPlayer (damage.cpp:807) for player 0: an invulnerable
    /// player takes nothing. Returns whether the player was damaged.
    mutating func applyDamageToPlayer(
        _ player: ObjectHandle,
        damage: Float
    ) -> Bool {
        guard objects[player]?.type == .player else { return false }
        if playerInvulnerableTime != nil {
            return false
        }
        // DecreasePlayerShields.
        shields -= damage
        return true
    }
}
