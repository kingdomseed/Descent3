// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/WeaponFire.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): FireWeaponFromPlayer (:2830) and
// StopWeapon (:2787) in single player, called from the player's ObjDoFrame
// (Descent3/object.cpp:2433-2436); with the player_weapon state of
// Descent3/player.h.
//
// The burst correction is 3MASTERED dbd611e4 (docs/revival/sources.md
// section 2): a new press starts a new burst at Gametime, and the end of a
// secondary burst also resets `firing_time`. Not yet here: fire-on-release
// weapons (SFF_FUSION, SFF_ZOOM), continuous firing sounds, on/off and spray
// weapons, guided and user-timeout missiles, quad fire, and
// AutoSelectWeapon (the weapon selection of M2); no imported ship battery
// uses them.

import Foundation

/// `player_weapon` (player.h) of one weapon type.
struct PlayerWeaponState: Codable, Equatable, Sendable {
    /// MAX_PLAYER_WEAPONS (player_external.h).
    static let maximumPlayerWeapons = 21
    /// LASER_INDEX and CONCUSSION_INDEX (weapon_external.h).
    static let laserIndex = 0
    static let concussionIndex = 10
    /// PW_PRIMARY and PW_SECONDARY.
    static let primary = 0
    static let secondary = 1

    /// The selected ship battery.
    var index: Int
    /// `firing_time`: how long the fire control has been held.
    var firingTime: Float = 0
}

extension GameWorld {
    /// FireWeaponFromPlayer (WeaponFire.cpp:2830) for player 0 with a held
    /// fire control (`isDown`) over `downTime`. A battery the ship does not
    /// carry does nothing.
    mutating func fireWeaponFromPlayer(
        _ player: ObjectHandle,
        weaponType: Int,
        isDown: Bool,
        downTime: Float,
        level: Level
    ) {
        let index = playerWeapons[weaponType].index
        guard let binding = level.defaultPlayerBinding,
              let ship = level.shipDefinitions.first(where: {
                  $0.source == binding.ship
              }),
              let wb = ship.weaponBatteries?.first(where: {
                  $0.index == index
              }),
              objects[player] != nil
        else {
            return
        }
        let canFireNow = isBatteryReady(player, battery: index, info: wb.battery)
        var downTime = downTime
        if isDown, downTime == 0 {
            downTime = 1.0 / 100.0
        }
        if !isDown {
            // The weapon stopped firing: StopWeapon for a primary, and the
            // end of the burst for either type.
            playerWeapons[weaponType].firingTime = 0
            return
        }
        if wb.energyUsage != 0, energy <= 0 {
            addHUDMessage("Not enough energy available to fire this weapon!")
            if weaponType == PlayerWeaponState.primary {
                playerWeapons[weaponType].firingTime = 0
            }
            return
        }
        if wb.ammoUsage != 0, playerWeaponAmmo[index] <= 0 {
            addHUDMessage(weaponType == PlayerWeaponState.primary
                ? "Not enough ammo available to fire this weapon!"
                : "Not enough projectiles available!")
            if weaponType == PlayerWeaponState.primary {
                playerWeapons[weaponType].firingTime = 0
            }
            return
        }
        if index >= 10, wb.ammoUsage > Float(playerWeaponAmmo[index]) {
            addHUDMessage(weaponType == PlayerWeaponState.primary
                ? "Not enough ammo available to fire this weapon!"
                : "Not enough projectiles available!")
            if weaponType == PlayerWeaponState.primary {
                playerWeapons[weaponType].firingTime = 0
            }
            return
        }
        guard canFireNow else { return }
        fireBattery(
            player,
            battery: index,
            info: wb.battery,
            polyBattery: 0,
            startsBurst: playerWeapons[weaponType].firingTime == 0,
            level: level
        )
        energy -= wb.energyUsage
        if energy < 0 { energy = 0 }
        if Float(playerWeaponAmmo[index]) < wb.ammoUsage {
            playerWeaponAmmo[index] = 0
        } else {
            playerWeaponAmmo[index] -= Int(wb.ammoUsage)
        }
        playerWeapons[weaponType].firingTime += downTime
    }
}
