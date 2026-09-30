// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/robotfire.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): WBIsBatteryReady (:88),
// WBFireBattery (:111, the AI path), and WBClearInfo (:282), with the
// dynamic_wb_info state of lib/robotfirestruct.h (:80). The fire cadence is
// the maintained-fork correction 3MASTERED dbd611e4 (docs/revival/
// sources.md section 2): a battery is ready when last_fire_time + wait <=
// Gametime, and a continuous burst keeps its sub-frame overshoot.
// Animated batteries (WBF_ANIM_LOCAL/FULL), quad fire, and the player and
// multiplayer branches arrive with the robots and ship weapons that use them.

import Foundation

/// dynamic_wb_info (robotfirestruct.h:80) of one model battery.
struct DynamicWeaponBattery: Codable, Equatable, Sendable {
    /// MAX_WB_TURRETS (robotfirestruct_external.h:24).
    static let maximumTurrets = 8
    /// WB_MOVE_STILL, WB_MOVE_RIGHT, WB_MOVE_LEFT (robotfirestruct.h:76).
    static let moveStill: UInt8 = 0
    static let moveRight: UInt8 = 1
    static let moveLeft: UInt8 = 2
    /// DWBF_ENABLED | DWBF_AUTOMATIC.
    static let enabledFlag: UInt32 = 1
    static let automaticFlag: UInt32 = 2

    var lastFireTime: Float = -1
    var currentFiringMask = 0
    var turretAngles = Array(repeating: Float(0), count: maximumTurrets)
    var turretNextThinkTimes = Array(repeating: Float(0), count: maximumTurrets)
    var turretDirections = Array(repeating: moveStill, count: maximumTurrets)
    var flags: UInt32 = enabledFlag | automaticFlag
}

extension GameWorld {
    /// WBClearInfo (robotfire.cpp:282): one cleared battery per model
    /// battery.
    static func clearedWeaponBatteries(count: Int) -> [DynamicWeaponBattery] {
        Array(repeating: DynamicWeaponBattery(), count: count)
    }

    /// WBGetFireWait (3MASTERED dbd611e4): gp_fire_wait of the current
    /// mask. The player recharge scalar and quad time do not reach an AI
    /// battery.
    private func fireWait(
        _ battery: DynamicWeaponBattery,
        _ info: CanonicalWeaponBattery
    ) -> Float {
        info.fireWaits[battery.currentFiringMask]
    }

    /// WBIsBatteryReady (robotfire.cpp:88), with the inclusive test of
    /// 3MASTERED dbd611e4.
    func isBatteryReady(_ handle: ObjectHandle, battery index: Int,
                        info: CanonicalWeaponBattery) -> Bool {
        guard let battery = objects[handle]?.weaponBatteries[index] else {
            return false
        }
        return battery.lastFireTime + fireWait(battery, info) <= gameTime
    }

    /// WBFireBattery (robotfire.cpp:111) for an AI object: fire every gun
    /// point of the current mask, play the mask's fire sound, then move the
    /// fire time and the mask on, and record the next weapon's speed.
    mutating func fireBattery(
        _ handle: ObjectHandle,
        battery index: Int,
        info: CanonicalWeaponBattery,
        level: Level
    ) {
        guard let object = objects[handle],
              let model = level.placedObjectModel(handle),
              let modelBattery = model.weaponBatteries?[index]
        else {
            return
        }
        let battery = object.weaponBatteries[index]
        let fireMask = info.fireMasks[battery.currentFiringMask]
        var averagePosition = Vector3.zero
        var numberFired = 0
        for bit in 0..<modelBattery.gunpoints.count
        where fireMask & (UInt8(1) << UInt8(bit)) != 0 {
            let weaponName = info.gunpointWeapons[bit]
            if let weapon = fireWeaponFromObject(
                handle,
                weaponName: weaponName,
                gunpoint: modelBattery.gunpoints[bit],
                forceForward: info.flags
                    & CanonicalWeaponBattery.fireForwardFlag != 0,
                forceTarget: info.flags
                    & CanonicalWeaponBattery.fireTargetFlag != 0,
                level: level
            ), let fired = objects[weapon] {
                averagePosition = averagePosition + fired.position
                numberFired += 1
            }
        }
        if numberFired > 0 {
            let sound = info.fireSounds[battery.currentFiringMask]
            if !sound.isEmpty {
                play3DSound(sound)
            }
        }

        guard var updated = objects[handle] else { return }
        var dynamic = updated.weaponBatteries[index]
        // WBAdvanceFireTime (3MASTERED dbd611e4).
        let wait = fireWait(dynamic, info)
        let scheduled = dynamic.lastFireTime + wait
        let overdue = gameTime - scheduled
        let continuityWindow = max(wait, frameDuration * 1.5)
        if dynamic.lastFireTime >= 0, overdue >= 0,
           overdue <= continuityWindow {
            dynamic.lastFireTime = scheduled
        } else {
            dynamic.lastFireTime = gameTime
        }
        if info.flags & CanonicalWeaponBattery.randomFireOrderFlag != 0 {
            dynamic.currentFiringMask = Int(
                Float(psRand()) / Float(GameWorld.randMax)
                    * Float(info.fireMasks.count)
            )
        } else {
            dynamic.currentFiringMask += 1
        }
        if dynamic.currentFiringMask >= info.fireMasks.count {
            dynamic.currentFiringMask = 0
        }
        updated.weaponBatteries[index] = dynamic

        // The speed of the next shot, which AIDetermineAimPoint leads with.
        if var ai = updated.ai {
            let nextMask = info.fireMasks[dynamic.currentFiringMask]
            for bit in 0..<modelBattery.gunpoints.count
            where nextMask & (UInt8(1) << UInt8(bit)) != 0 {
                let weapon = level.weapon(named: info.gunpointWeapons[bit])
                if let weapon,
                   weapon.physicsFlags & WeaponPhysics.fixedVelocityFlag
                    != 0 {
                    ai.weaponSpeed = weapon.speed
                } else if let weapon,
                          weapon.physicsFlags & WeaponPhysics.usesThrustFlag
                            != 0 {
                    ai.weaponSpeed = weapon.fullThrust / weapon.drag
                } else {
                    ai.weaponSpeed = 0
                }
                break
            }
            updated.ai = ai
        }
        objects[handle] = updated
    }
}
