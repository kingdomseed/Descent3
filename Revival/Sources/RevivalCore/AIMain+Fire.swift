// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/AImain.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): ai_fire (:5116), with
// MAX_NOT_SEE_TARGET_FIRE_TIME and DEFAULT_FIRE_DOT (:5112-5114). A battery
// with a firing animation (WBF_ANIM_LOCAL or WBF_ANIM_FULL) waits for the
// animation system; the turret sound needs AI sounds. Both arrive in M2.

import Foundation

extension GameWorld {
    /// MAX_NOT_SEE_TARGET_FIRE_TIME (AImain.cpp:5112).
    private static let maximumNotSeeTargetFireTime: Float = 2
    /// DEFAULT_FIRE_DOT (AImain.cpp:5114).
    private static let defaultFireDot: Float = 0.93

    /// ai_fire (AImain.cpp:5116): turn each battery's turrets toward the
    /// last seen target position, then fire a ready battery whose aim is
    /// close enough.
    mutating func aiFire(_ handle: ObjectHandle, level: Level) {
        guard let object = objects[handle], let ai = object.ai,
              let infoIndex = object.info,
              let model = level.placedObjectModel(handle),
              let modelBatteries = model.weaponBatteries
        else {
            return
        }
        let info = level.objectInfos![infoIndex]
        guard ai.flags & ObjectAIFrame.fireFlag != 0 else {
            // A ranged-attack status fires only through AIG_FIRE_AT_OBJ
            // animations (M2).
            return
        }
        if (gameTime - ai.lastSeeTargetTime > 4
            && gameTime - ai.lastHearTargetTime > 4)
            || ai.awareness <= ObjectAIFrame.awareBarely {
            objects[handle]?.ai?.statusRegister &=
                ~ObjectAIFrame.rangedAttackStatus
            return
        }

        for batteryIndex in modelBatteries.indices
        where info.weaponBatteries.indices.contains(batteryIndex) {
            guard let current = objects[handle],
                  current.weaponBatteries[batteryIndex].flags
                    & DynamicWeaponBattery.enabledFlag != 0
            else {
                continue
            }
            let staticBattery = info.weaponBatteries[batteryIndex]
            let modelBattery = modelBatteries[batteryIndex]
            if staticBattery.flags
                & CanonicalWeaponBattery.useCustomMaxDistanceFlag != 0,
               staticBattery.aiming3DDistance
                < (current.ai?.distToTargetActual ?? 0) {
                continue
            }
            guard modelBattery.gunpoints.indices.contains(
                staticBattery.aimingGunpointIndex
            ) else {
                continue
            }
            let aimingGunpoint =
                modelBattery.gunpoints[staticBattery.aimingGunpointIndex]
            let target = current.ai?.lastSeeTargetPosition ?? .zero
            var bestDot: Float = -.infinity
            var haveDot = false

            func aimDot(_ object: GameObject) -> Float {
                let gun = weaponCalcGun(object, gunpoint: aimingGunpoint,
                                        model: model)
                var toward = target - gun.point
                let length = sqrt(dot(toward, toward))
                toward = length > 0 ? toward / length : toward
                return dot(gun.normal, toward)
            }

            // A battery with no turret, or one fixed turret, aims with its
            // gun point (AImain.cpp:5171-5197).
            let turrets = modelBattery.turrets
            if turrets.isEmpty || (turrets.count == 1
                && turretFieldOfView(model, turrets[0]) == 0) {
                if isBatteryReady(handle, battery: batteryIndex,
                                  info: staticBattery) {
                    // WBF_FIRE_FVEC aims the object's forward vector from
                    // the gun point; otherwise the gun point's normal.
                    let gun = weaponCalcGun(
                        current, gunpoint: aimingGunpoint, model: model
                    )
                    let normal = staticBattery.flags
                        & CanonicalWeaponBattery.fireForwardFlag != 0
                        ? current.orientation.forward : gun.normal
                    var toward = target - gun.point
                    let length = sqrt(dot(toward, toward))
                    toward = length > 0 ? toward / length : toward
                    bestDot = dot(normal, toward)
                    haveDot = true
                }
            }

            for (turretIndex, submodel) in turrets.enumerated() {
                guard var turning = objects[handle] else { return }
                var battery = turning.weaponBatteries[batteryIndex]
                let rebel = turning.ai.map {
                    $0.flags & ObjectAIFrame.teamMask
                        == ObjectAIFrame.teamRebel
                } ?? false
                let speedScale = rebel
                    ? 1 : Difficulty.aiTurretSpeed[Difficulty.level]
                let rotationsPerSecond =
                    turretRotationsPerSecond(model, submodel) * speedScale
                let fov = turretFieldOfView(model, submodel)
                var nextMoveStill = false
                if fov > 0 {
                    let minimumInvalid = fov
                    let maximumInvalid = 1 - minimumInvalid
                    let constrain = minimumInvalid < 0.5
                    let still = battery.turretAngles[turretIndex]
                    var right = still - frameDuration * rotationsPerSecond
                    while right < 0 { right += 1 }
                    if constrain, right > minimumInvalid,
                       right < maximumInvalid {
                        right = maximumInvalid
                    }
                    var left = still + frameDuration * rotationsPerSecond
                    while left > 1 { left -= 1 }
                    if constrain, left > minimumInvalid,
                       left < maximumInvalid {
                        left = minimumInvalid
                    }
                    func dotAt(_ angle: Float) -> Float {
                        var probe = turning
                        probe.weaponBatteries[batteryIndex]
                            .turretAngles[turretIndex] = angle
                        return aimDot(probe)
                    }
                    let stillDot = dotAt(still)
                    let rightDot = dotAt(right)
                    let leftDot = dotAt(left)
                    var best = DynamicWeaponBattery.moveStill
                    let dots = [stillDot, rightDot, leftDot]
                    if rightDot > stillDot {
                        best = DynamicWeaponBattery.moveRight
                    }
                    if leftDot > dots[Int(best)] {
                        best = DynamicWeaponBattery.moveLeft
                    }
                    battery.turretAngles[turretIndex] =
                        [still, right, left][Int(best)]
                    battery.turretDirections[turretIndex] = rightDot > leftDot
                        ? DynamicWeaponBattery.moveRight
                        : DynamicWeaponBattery.moveLeft
                    battery.turretNextThinkTimes[turretIndex] +=
                        turretThinkInterval(model, submodel)
                    bestDot = dots[Int(best)]
                    haveDot = true
                } else {
                    let direction = battery.turretDirections[turretIndex]
                    var angle = battery.turretAngles[turretIndex]
                    let minimumInvalid = fov
                    let maximumInvalid = 1 - minimumInvalid
                    let constrain = direction != DynamicWeaponBattery.moveStill
                        && minimumInvalid < 0.5
                    if direction == DynamicWeaponBattery.moveRight {
                        angle -= frameDuration * rotationsPerSecond
                        while angle < 0 { angle += 1 }
                        if constrain, angle > minimumInvalid,
                           angle < maximumInvalid {
                            angle = maximumInvalid
                            nextMoveStill = true
                        }
                    } else if direction == DynamicWeaponBattery.moveLeft {
                        angle += frameDuration * rotationsPerSecond
                        while angle > 1 { angle -= 1 }
                        if constrain, angle > minimumInvalid,
                           angle < maximumInvalid {
                            angle = minimumInvalid
                            nextMoveStill = true
                        }
                    }
                    battery.turretAngles[turretIndex] = angle
                    if isBatteryReady(handle, battery: batteryIndex,
                                      info: staticBattery) {
                        var probe = turning
                        probe.weaponBatteries[batteryIndex] = battery
                        bestDot = aimDot(probe)
                        haveDot = true
                    }
                }
                if nextMoveStill {
                    battery.turretDirections[turretIndex] =
                        DynamicWeaponBattery.moveStill
                }
                turning.weaponBatteries[batteryIndex] = battery
                objects[handle] = turning
            }

            guard let firing = objects[handle], let firingAI = firing.ai
            else {
                return
            }
            guard gameTime - firingAI.lastSeeTargetTime
                    < Self.maximumNotSeeTargetFireTime
                    || gameTime - firingAI.lastHearTargetTime
                        < Self.maximumNotSeeTargetFireTime,
                  isBatteryReady(handle, battery: batteryIndex,
                                 info: staticBattery),
                  haveDot
            else {
                continue
            }
            let fireDot = staticBattery.flags
                & CanonicalWeaponBattery.useCustomFOVFlag != 0
                ? staticBattery.aiming3DDot
                : Self.defaultFireDot
            guard bestDot >= fireDot else { continue }
            var noFire = false
            if firingAI.aggression == 0,
               firingAI.memory[0].numberOfTimesHit == 0 {
                noFire = true
                if let targetObject = objects[firingAI.targetHandle],
                   case let .room(room) = firing.location {
                    let sight = traceIndoorMovement(
                        in: level,
                        roomStates: rooms,
                        startRoom: room,
                        start: firing.position,
                        end: targetObject.position,
                        radius: 0.01
                    )
                    if case .noHit = sight.outcome { noFire = false }
                }
            }
            if noFire {
                objects[handle]?.ai?.statusRegister &=
                    ~ObjectAIFrame.rangedAttackStatus
                let delay = 1 + psRandFraction()
                objects[handle]?.weaponBatteries[batteryIndex].lastFireTime =
                    gameTime + delay
                continue
            }
            guard staticBattery.flags & CanonicalWeaponBattery.animationMask
                    == 0
            else {
                continue
            }
            fireBattery(handle, battery: batteryIndex, info: staticBattery,
                        level: level)
            objects[handle]?.ai?.statusRegister &=
                ~ObjectAIFrame.rangedAttackStatus
        }
    }

    private func turretFieldOfView(_ model: CanonicalModel,
                                   _ submodel: Int) -> Float {
        guard case let .turret(fov, _, _, _) =
                model.submodels[submodel].presentation
        else {
            return 0
        }
        return fov
    }

    private func turretRotationsPerSecond(_ model: CanonicalModel,
                                          _ submodel: Int) -> Float {
        guard case let .turret(_, rps, _, _) =
                model.submodels[submodel].presentation
        else {
            return 0
        }
        return rps
    }

    private func turretThinkInterval(_ model: CanonicalModel,
                                     _ submodel: Int) -> Float {
        guard case let .turret(_, _, interval, _) =
                model.submodels[submodel].presentation
        else {
            return 0
        }
        return interval
    }
}
