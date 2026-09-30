// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/fireball.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): DestroyObject (:1344), DoDyingFrame
// (:1428), MakeShockwave (:1752), and DoConcussiveForce (:1788); with
// phys_apply_force (physics/physics.cpp:2544) for the player.
//
// DestroyObject keeps the order of its effects, their object allocations,
// and their ps_rand draws (Fireball+Effects.swift); only their
// presentation is deferred (architecture.md section 9). A robot's physics
// flags and mass are not imported, so concussive force pushes only the
// player.

import Foundation

extension GameWorld {
    /// FADE_TIME (fireball.cpp:1342).
    private static let fadeTime: Float = 2

    /// DestroyObject (fireball.cpp:1344): the blast ring, the shockwave,
    /// the explosion sound, the death spew, the fireball and its extras,
    /// the dying model, the debris, and the splinters, in that order; then
    /// the object stays as remains, fades, or leaves its dead object and is
    /// marked dead.
    mutating func destroyObject(
        _ handle: ObjectHandle,
        explosionMagnitude: Float,
        deathFlags: UInt32,
        level: Level
    ) {
        guard var object = objects[handle] else { return }
        object.flags |= GameObject.dyingFlag
        objects[handle] = object
        if deathFlags & DeathFlags.blastRing != 0 {
            createObjectBlastRing(handle, level: level)
        }
        if deathFlags & (DeathFlags.fireball | DeathFlags.breaksApart) != 0 {
            // The player's shake is presentation.
            makeShockwave(
                exploding: handle,
                parent: handle,
                impact: objectImpact(object, level: level),
                level: level
            )
        }
        guard let exploding = objects[handle] else { return }
        if deathFlags & DeathFlags.delaySound == 0 {
            playObjectExplosionSound(exploding, level: level)
        }
        if exploding.isGeneric {
            doDeathSpew(handle, level: level)
        }
        var fireball: Int?
        if deathFlags & DeathFlags.fireball != 0 {
            let sizeScale: Float
            switch deathFlags & DeathFlags.explosionSizeMask {
            case DeathFlags.explosionMedium: sizeScale = 1
            case DeathFlags.explosionLarge: sizeScale = 1.6
            default: sizeScale = 0.5
            }
            fireball = createObjectFireball(
                handle,
                sizeScale: sizeScale,
                level: level
            )
            createExtraFireballs(handle, sizeScale: sizeScale, level: level)
        }
        if let dyingModel = level.objectPresentations.first(where: {
            $0.objectHandle == handle.rawValue
        })?.dyingModel {
            objects[handle]?.model = dyingModel
        }
        if deathFlags & DeathFlags.breaksApart != 0 {
            breakApartModel(
                handle,
                explosionMagnitude: explosionMagnitude,
                deathFlags: deathFlags,
                level: level
            )
        }
        if deathFlags & DeathFlags.fireball != 0 {
            let fireballLife = fireball.map { visEffects[$0].lifeLeft } ?? 2
            // Indoors the splinters live half the fireball's life.
            createSplintersFromBody(
                handle,
                lifetime: fireballLife / 2,
                level: level
            )
        }
        guard var object = objects[handle] else { return }
        if deathFlags & DeathFlags.remains != 0 {
            // CT_NONE, OBJ_DEBRIS so it does no idle animation, MT_NONE.
            object.dying = nil
            object.ai = nil
            object.weaponBatteries = []
            object.type = .debris
            object.usesPhysics = false
            object.physics = nil
            object.velocity = .zero
            objects[handle] = object
        } else if deathFlags & DeathFlags.fadeAway != 0 {
            object.dying = nil
            object.ai = nil
            object.weaponBatteries = []
            object.lifeLeft = Self.fadeTime
            objects[handle] = object
        } else {
            createDeadObject(handle, level: level)
            objects[handle]?.flags |= GameObject.deadFlag
        }
    }

    /// The impact values ObjInitGeneric copies from the object page
    /// (ObjInit.cpp:760-764).
    private func objectImpact(
        _ object: GameObject,
        level: Level
    ) -> CanonicalWeaponImpact? {
        guard let impact = object.info.flatMap({
            level.objectInfos?[$0].impact
        }) else {
            return nil
        }
        return CanonicalWeaponImpact(
            size: impact.size,
            time: impact.time,
            playerDamage: impact.damage,
            genericDamage: impact.damage,
            force: impact.damage * 50
        )
    }

    /// DoDyingFrame (fireball.cpp:1428): the delay runs down; when it runs
    /// out the object is destroyed and its killer scores, and until then
    /// its sparks, fireballs, and smoke go on.
    mutating func doDyingFrame(_ handle: ObjectHandle, level: Level) {
        guard var object = objects[handle], var dying = object.dying else {
            return
        }
        dying.delayTime -= frameDuration
        object.dying = dying
        objects[handle] = object
        guard dying.delayTime < 0 else {
            doDyingEffects(handle, level: level)
            return
        }
        destroyObject(
            handle,
            explosionMagnitude: 30,
            deathFlags: dying.deathFlags,
            level: level
        )
        // The score reads the object after DestroyObject
        // (fireball.cpp:1440): remains are OBJ_DEBRIS, not generic.
        if dying.killerPlayer != nil,
           let destroyed = objects[handle], destroyed.isGeneric,
           let score = destroyed.info.flatMap({
               level.objectInfos?[$0].score
           }) {
            playerScoreAdd(Int(score))
        }
    }

    /// MakeShockwave (fireball.cpp:1752): with an impact time, an
    /// OBJ_SHOCKWAVE that grows for that time; with none, the concussive
    /// force at once. The shockwave's parent is the top of the parent
    /// chain.
    mutating func makeShockwave(
        exploding handle: ObjectHandle,
        parent: ObjectHandle,
        impact: CanonicalWeaponImpact?,
        level: Level
    ) {
        guard let exploding = objects[handle],
              case let .room(room) = exploding.location
        else {
            return
        }
        let impact = impact ?? CanonicalWeaponImpact(
            size: 0, time: 0, playerDamage: 0, genericDamage: 0, force: 0
        )
        guard impact.time > 0 else {
            var noList: [UInt32]? = nil
            doConcussiveForce(
                position: exploding.position,
                roomSourceIndex: room,
                exploding: handle,
                parent: parent,
                impact: impact,
                effectDistance: impact.size,
                damagedList: &noList,
                level: level
            )
            return
        }
        var top = objects[parent] != nil ? parent : ObjectHandle.none
        var current = parent
        var steps = 0
        while let next = objects[current]?.parent, objects[next] != nil,
              steps < ObjectTable.capacity {
            top = next
            current = next
            steps += 1
        }
        guard let created = objects.create(
            type: .shockwave,
            renderType: .none,
            location: exploding.location,
            position: exploding.position,
            orientation: Matrix3(
                right: .init(x: 1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: 1)
            )
        ) else {
            return
        }
        objects[created]?.parent = top
        objects[created]?.creationTime = gameTime
        objects[created]?.lifeLeft = impact.time
        objects[created]?.shockwave = ShockwaveInfo(
            size: impact.size,
            time: impact.time,
            playerDamage: impact.playerDamage,
            genericDamage: impact.genericDamage,
            force: impact.force
        )
    }

    /// The MT_SHOCKWAVE movement of an OBJ_SHOCKWAVE in ObjDoFrame
    /// (object.cpp:2819), and its TimeoutObject (object.cpp:2161): the
    /// concussive force at the shockwave's current radius.
    mutating func shockwaveConcussiveForce(
        _ handle: ObjectHandle,
        level: Level
    ) {
        guard let shockwave = objects[handle],
              let info = shockwave.shockwave,
              case let .room(room) = shockwave.location
        else {
            return
        }
        let impact = CanonicalWeaponImpact(
            size: info.size,
            time: info.time,
            playerDamage: info.playerDamage,
            genericDamage: info.genericDamage,
            force: info.force
        )
        let distance = min(
            info.size,
            info.size * ((gameTime - shockwave.creationTime) / info.time)
        )
        var damagedList: [UInt32]? = info.damagedList
        doConcussiveForce(
            position: shockwave.position,
            roomSourceIndex: room,
            exploding: handle,
            parent: shockwave.parent,
            impact: impact,
            effectDistance: distance,
            damagedList: &damagedList,
            level: level
        )
        if let damagedList {
            objects[handle]?.shockwave?.damagedList = damagedList
        }
    }

    /// DoConcussiveForce (fireball.cpp:1788) with player_scalar 1: each
    /// weapon, robot, building, player, door, and clutter within reach that
    /// the explosion can see gets damage and force that fall off to zero at
    /// `impact.size`. A shockwave damages each object once (`damagedList`).
    private mutating func doConcussiveForce(
        position: Vector3,
        roomSourceIndex: Int,
        exploding: ObjectHandle,
        parent: ObjectHandle,
        impact: CanonicalWeaponImpact,
        effectDistance: Float,
        damagedList: inout [UInt32]?,
        level: Level
    ) {
        guard impact.size > 0 else { return }
        let killer = objects[parent] != nil ? parent : ObjectHandle.none
        let types: Set<ObjectType> = [
            .weapon, .robot, .building, .player, .door, .clutter,
        ]
        for slot in 0..<ObjectTable.capacity {
            guard let hit = objects.slots[slot],
                  types.contains(hit.type),
                  hit.handle != exploding,
                  hit.flags & GameObject.deadFlag == 0,
                  case .room = hit.location
            else {
                continue
            }
            if hit.type == .weapon, let index = hit.weapon,
               let flags = level.weapons?[index].physicsFlags {
                if flags & WeaponPhysics.ignoreConcussiveForcesFlag != 0 {
                    continue
                }
                if flags & WeaponPhysics.ignoreOwnConcussiveForcesFlag != 0,
                   objectUltimateParent(hit.handle)
                    == objectUltimateParent(exploding) {
                    continue
                }
            }
            // The objects' centers less the hit object's size. Revival
            // uses the object size for a polygon object's wall_size
            // (architecture.md section 9).
            let distance = max(0, vectorDistance(hit.position, position) - hit.size)
            guard distance <= effectDistance else { continue }
            if damagedList != nil {
                let index = slot >> 5
                let bit = UInt32(1) << UInt32(slot % 32)
                if damagedList![index] & bit != 0 { continue }
                damagedList![index] |= bit
            }
            guard boaIsVisible(
                hit.location,
                .room(roomSourceIndex),
                level: level
            ) else {
                continue
            }
            let away = hit.position - position
            let start = away == .zero
                ? position
                : position + sourceVectorNormalized(away) * 0.05
            let trace = traceIndoorMovement(
                in: level,
                roomStates: rooms,
                startRoom: roomSourceIndex,
                start: start,
                end: hit.position,
                radius: 0
            )
            guard case .noHit = trace.outcome else { continue }
            let damage = hit.type == .player
                ? impact.playerDamage
                    - (distance / impact.size) * impact.playerDamage
                : impact.genericDamage
                    - (distance / impact.size) * impact.genericDamage
            var force = impact.force - (distance / impact.size) * impact.force
            if hit.type == .clutter { force *= 0.5 }
            // vm_GetNormalizedDirFast from the explosion to the object.
            let direction = away == .zero ? away : sourceVectorNormalized(away)
            if hit.type == .player,
               let binding = level.defaultPlayerBinding,
               let ship = level.shipDefinitions.first(where: {
                   $0.source == binding.ship
               }),
               ship.physics.mass != 0 {
                velocity = velocity + direction * force / ship.physics.mass
            }
            guard damage != 0 else { continue }
            if hit.type == .player {
                applyDamageToPlayer(
                    hit.handle,
                    killer: killer,
                    damage: damage,
                    level: level
                )
            } else if hit.isGeneric || hit.type == .door {
                applyDamageToGeneric(
                    hit.handle,
                    killer: killer,
                    damageType: .concussive,
                    damage: damage,
                    level: level
                )
            }
        }
    }
}
