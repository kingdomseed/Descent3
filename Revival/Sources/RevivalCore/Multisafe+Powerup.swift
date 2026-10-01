// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/multisafe.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): msafe_DoPowerup (:2467), the
// engine side of a default powerup script's pickup, with the Invulnerability
// and Cloak branches of HandleCommonPowerups (:2774-2797). The other common,
// weapon, countermeasure, and inventory powerups (HandleCommonPowerups,
// HandleWeaponPowerups, HandleCounterMeasurePowerups, and
// HandleInventoryPowerups) arrive with the full powerup and inventory
// tables in M2; until then a powerup of those pages is not handled, as an
// unknown page is not (architecture.md section 9). Multiplayer routing is
// dropped.

extension GameWorld {
    /// msafe_DoPowerup (multisafe.cpp:2467) for `powerup` touched by
    /// `player`: the page's handler runs, and a powerup it picks up dies
    /// and plays SOUND_POWERUP_PICKUP.
    mutating func doPowerup(
        _ powerup: ObjectHandle,
        player: ObjectHandle,
        level: Level
    ) {
        guard let object = objects[powerup],
              objects[player]?.type == .player,
              let id = object.info,
              let infos = level.objectInfos,
              infos.indices.contains(id)
        else {
            return
        }
        let name = infos[id].name
        guard let pickup = handleCommonPowerups(
            name,
            player: player,
            level: level
        ) else {
            return
        }
        if pickup {
            // SetObjectDeadFlag: its `playsound` flag only marks the
            // multiplayer removal message.
            objects[powerup]?.flags |= GameObject.deadFlag
            play3DSound(EngineSound.powerupPickup)
        }
    }

    /// The Invulnerability and Cloak branches of HandleCommonPowerups
    /// (multisafe.cpp:2774-2797). Returns whether the powerup is picked
    /// up, or `nil` when the page is not handled.
    private mutating func handleCommonPowerups(
        _ name: String,
        player: ObjectHandle,
        level: Level
    ) -> Bool? {
        if name.caseInsensitiveCompare("Invulnerability") == .orderedSame {
            if playerInvulnerableTime == nil {
                // 30 seconds.
                makePlayerInvulnerable(time: 30, playSoundAndMessage: true)
                return true
            }
            addHUDMessage(EngineText.invulnerabilityAlready)
            return false
        }
        if name.caseInsensitiveCompare("Cloak") == .orderedSame {
            // The player always has effect_info.
            let flags = objects[player]?.effect?.typeFlags ?? 0
            if flags & (ObjectEffectInfo.fadingOutFlag
                        | ObjectEffectInfo.cloakedFlag) == 0 {
                // 30 seconds.
                makeObjectInvisible(player, time: 30)
                return true
            }
            addHUDMessage(EngineText.cloakAlready)
            return false
        }
        return nil
    }
}
