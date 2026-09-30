// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/damage.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): KillPlayer (:760),
// ApplyDamageToPlayer (:807) in single player, GenerateDefaultDeath
// (:959), both KillObject forms (:1037, :1175), and ApplyDamageToGeneric
// (:1290); and PlayerScoreAdd (Descent3/Player.cpp:3853).
//
// With InitiatePlayerDeath (Descent3/Player.cpp:2057), StartPlayerDeath's
// state changes (:2109-2239), PlayerChooseDeathFate (:2072), and
// SetFallingPhysics and SetFlyingPhysics (damage.cpp:1083, :1121; in
// Fireball+Effects.swift).
//
// The armor scalars are 1: the pilot and ship values are not imported yet,
// and the retail ship pages set 1. The player damage and invulnerability
// sounds and effects make no draws and are presentation (M2), as are the
// weapon damage effects (WF_MICROWAVE, WF_NAPALM, WF_FREEZE), which no
// Training weapon has. The dying player's frames, explosion, spew, and
// respawn are the death sequence of M2: until then a dying player stays
// dying (architecture.md section 9). Death animations are not imported, so
// GenerateDefaultDeath and DF_DELAY_FROM_ANIM see none.

import Foundation

/// The GD_ damage types (damage_external.h:32-40).
enum GenericDamageType: Int, Codable, Sendable {
    case scripted = 0
    case electric = 1
    case concussive = 2
    case fire = 3
    case matter = 4
    case energy = 5
    case physics = 6
    case meleeAttack = 7
    case volatileHiss = 8
}

/// The DF_ death flags (deathinfo_external.h:64-106) that KillObject and
/// DestroyObject read.
enum DeathFlags {
    static let delayFromAnimation: UInt32 = 0x000_0002
    static let delaySparks: UInt32 = 0x000_0004
    static let delayLosesAntigravity: UInt32 = 0x000_0008
    static let fireball: UInt32 = 0x000_0020
    static let breaksApart: UInt32 = 0x000_0040
    static let blastRing: UInt32 = 0x000_0080
    static let remains: UInt32 = 0x000_0100
    static let contactFireball: UInt32 = 0x000_1000
    static let contactBreaksApart: UInt32 = 0x000_2000
    static let debrisSmokes: UInt32 = 0x001_0000
    static let debrisFireball: UInt32 = 0x002_0000
    static let delayFlying: UInt32 = 0x010_0000
    static let delayFadeAway: UInt32 = 0x040_0000
    static let fadeAway: UInt32 = 0x080_0000
    static let delaySound: UInt32 = 0x100_0000
    static let delaySmokes: UInt32 = 0x000_0010
    static let delayFireball: UInt32 = 0x020_0000
    static let delayNoTumbleFly: UInt32 = 0x200_0000
    static let explosionSizeMask: UInt32 = 0x000_0c00
    static let explosionMedium: UInt32 = 0x000_0400
    static let explosionLarge: UInt32 = 0x000_0800
    static let debrisBlastRing: UInt32 = 0x004_0000
    static let debrisRemains: UInt32 = 0x008_0000
}

extension GameWorld {
    /// ObjGetUltimateParent (object.cpp): the first ancestor that has no
    /// parent, or the object itself.
    func objectUltimateParent(_ handle: ObjectHandle) -> ObjectHandle {
        var current = handle
        var steps = 0
        while let parent = objects[current]?.parent,
              objects[parent] != nil,
              steps < ObjectTable.capacity {
            current = parent
            steps += 1
        }
        return current
    }

    /// ApplyDamageToPlayer (damage.cpp:807) for player 0 in single player.
    /// A weapon killer is replaced by its ultimate parent. An invulnerable
    /// player, or one without OF_DESTROYABLE, takes nothing. Returns whether
    /// the player was damaged.
    @discardableResult
    mutating func applyDamageToPlayer(
        _ player: ObjectHandle,
        killer: ObjectHandle = .none,
        damage: Float,
        level: Level
    ) -> Bool {
        guard let playerObject = objects[player],
              playerObject.type == .player
        else {
            return false
        }
        var killer = killer
        if objects[killer]?.type == .weapon {
            killer = objectUltimateParent(killer)
        }
        // A dying or dead player takes nothing (damage.cpp:827-830).
        if playerDeath != nil { return false }
        if playerInvulnerableTime != nil
            || playerObject.flags & GameObject.destroyableFlag == 0 {
            return false
        }
        // DecreasePlayerShields (damage.cpp:679).
        shields -= damage
        if shields < 0 {
            killPlayer(player, killer: killer, level: level)
        }
        return true
    }

    /// KillPlayer (damage.cpp:760) in single player: the killer is kept,
    /// the level script hears EVT_PLAYER_DIES, and InitiatePlayerDeath
    /// starts the death (a robot killer makes it a melee death).
    private mutating func killPlayer(
        _ player: ObjectHandle,
        killer: ObjectHandle,
        level: Level
    ) {
        let killer = objects[killer] == nil ? ObjectHandle.none : killer
        osirisCallLevelEvent(.playerDies(it: player), level: level)
        initiatePlayerDeath(
            player,
            killer: killer,
            melee: objects[killer]?.type == .robot
        )
    }

    /// InitiatePlayerDeath (Player.cpp:2057) and the state changes of
    /// StartPlayerDeath (Player.cpp:2109-2239): PLAYER_FLAGS_DYING, both
    /// weapons stop firing (ClearPlayerFiring), the death is counted, the
    /// fate is chosen, and the ship loses its controls (CT_NONE).
    private mutating func initiatePlayerDeath(
        _ player: ObjectHandle,
        killer: ObjectHandle,
        melee: Bool
    ) {
        guard playerDeath == nil else { return }
        for index in playerWeapons.indices {
            playerWeapons[index].firingTime = 0
        }
        playerDeathsLevel &+= 1
        let fate = playerChooseDeathFate(damage: -shields, melee: melee)
        playerDeath = PlayerDeathState(
            fate: fate,
            killer: killer,
            initialDeathTime: gameTime
        )
    }

    /// PlayerChooseDeathFate (Player.cpp:2072). Revival has no terrain
    /// yet, so the outside-only DEATH_BREAKUP never applies.
    private mutating func playerChooseDeathFate(
        damage: Float,
        melee: Bool
    ) -> PlayerDeathState.Fate {
        if damage <= 100 || melee {
            return psRand() % 4 != 3 ? .d2Style : .fall
        }
        return .instant
    }

    /// PlayerScoreAdd (Player.cpp:3853) for player 0.
    mutating func playerScoreAdd(_ points: Int) {
        guard points != 0 else { return }
        // The int and int16_t counters wrap in their source widths
        // (player.h:416, player_external_struct.h:150).
        if points > 0 {
            playerKillsLevel &+= 1
        } else {
            playerFriendlyKillsLevel &+= 1
        }
        playerScore &+= Int32(truncatingIfNeeded: points)
    }

    /// ApplyDamageToGeneric (damage.cpp:1290) in single player. `killer` is
    /// the weapon or object that did the damage. The object's scripts hear
    /// EVT_DAMAGED before its shields drop; shields below zero kill it.
    /// Returns whether damage was applied.
    @discardableResult
    mutating func applyDamageToGeneric(
        _ hit: ObjectHandle,
        killer: ObjectHandle,
        damageType: GenericDamageType,
        damage: Float,
        level: Level
    ) -> Bool {
        guard let object = objects[hit],
              object.type != .dummy,
              object.flags & GameObject.aiDeathFlag == 0
        else {
            return false
        }
        var damage = damage
        let pageFlags = object.info.flatMap { level.objectInfos?[$0].flags }
            ?? 0
        let noScale = object.isGeneric
            && pageFlags & CanonicalObjectInfo.noDifficultyScaleDamageFlag != 0
        if damageType != .scripted, !noScale {
            damage *= Difficulty.robotDamage[Difficulty.level]
        }
        var killer = killer
        if objects[killer]?.type == .weapon {
            killer = objectUltimateParent(killer)
        }
        guard object.flags & GameObject.destroyableFlag != 0,
              object.flags & GameObject.useDestroyedPolymodelFlag == 0
        else {
            return false
        }
        // The script cannot change the damage yet: ScriptEvent carries it
        // by value, and no translated script handles EVT_DAMAGED.
        osirisCallEvent(
            hit,
            .damaged(it: objects[killer] == nil ? .none : killer,
                     damage: damage),
            level: level
        )
        guard damage != 0, var damaged = objects[hit] else { return false }
        damaged.shields -= damage
        if damaged.shields < 0,
           damaged.flags & GameObject.aiDoDeathFlag != 0 {
            damaged.shields = 0
            damaged.flags |= GameObject.aiDeathFlag
        }
        objects[hit] = damaged
        if damaged.shields < 0,
           damaged.flags & GameObject.dyingFlag == 0 {
            killObject(hit, killer: killer, damage: damage, level: level)
        }
        return true
    }

    /// KillObject (damage.cpp:1037): the page picks the death, or
    /// GenerateDefaultDeath does.
    mutating func killObject(
        _ handle: ObjectHandle,
        killer: ObjectHandle,
        damage: Float,
        level: Level
    ) {
        guard let object = objects[handle],
              object.flags & (GameObject.dyingFlag | GameObject.deadFlag) == 0
        else {
            return
        }
        var deathFlags: UInt32?
        var delayTime: Float = 0
        if object.isGeneric,
           let types = object.info.flatMap({ level.objectInfos?[$0].deathTypes }) {
            // In range 1 to 100.
            var r = Int(psRand()) * 100 / (Int(GameWorld.randMax) + 1) + 1
            for type in types {
                let p = Int(type.probability)
                if r <= p {
                    deathFlags = type.flags
                    delayTime = type.delayMinimum
                        + (type.delayMaximum - type.delayMinimum)
                            * Float(psRand()) / Float(GameWorld.randMax)
                    break
                }
                r -= p
            }
        }
        let flags: UInt32
        if let deathFlags {
            flags = deathFlags
        } else {
            (flags, delayTime) = generateDefaultDeath(handle)
        }
        killObject(
            handle,
            killer: killer,
            damage: damage,
            deathFlags: flags,
            delayTime: delayTime,
            level: level
        )
    }

    /// GenerateDefaultDeath (damage.cpp:959), for an object with no death
    /// animation. No imported object walks, so MT_WALKING never applies.
    private mutating func generateDefaultDeath(
        _ handle: ObjectHandle
    ) -> (flags: UInt32, delay: Float) {
        let object = objects[handle]!
        var flags: UInt32 = 0
        var delay: Float = 0
        let isAIBuilding = object.type == .building && object.ai != nil
        if (object.type != .robot && !isAIBuilding) || psRand() % 3 != 0 {
            // Quick death.
            if psRand() % 3 == 0 {
                flags |= DeathFlags.blastRing
            }
        } else {
            var alternateDeath = false
            if psRand() % 2 == 1 {
                flags = DeathFlags.delaySparks
                alternateDeath = true
            }
            if object.type == .robot || isAIBuilding {
                if alternateDeath || !object.usesPhysics {
                    flags = DeathFlags.delaySparks
                    delay = 3
                    alternateDeath = true
                } else {
                    flags = 0
                }
                if !alternateDeath {
                    delay = 2
                }
            } else {
                flags |= DeathFlags.delayFlying
                delay = object.orientation.up.y == 1 ? 2 : 0.7
            }
            if psRand() % 8 == 0 {
                flags |= DeathFlags.blastRing
            }
        }
        flags |= DeathFlags.fireball | DeathFlags.breaksApart
            | DeathFlags.contactFireball | DeathFlags.contactBreaksApart
            | DeathFlags.debrisSmokes | DeathFlags.debrisFireball
        return (flags, delay)
    }

    /// KillObject (damage.cpp:1175) with a chosen death: the object is
    /// dying. With no delay it is destroyed now and its killer scores;
    /// otherwise it gets CT_DYING until DoDyingFrame destroys it.
    mutating func killObject(
        _ handle: ObjectHandle,
        killer: ObjectHandle,
        damage: Float,
        deathFlags: UInt32,
        delayTime: Float,
        level: Level
    ) {
        guard var object = objects[handle],
              object.flags & (GameObject.dyingFlag | GameObject.deadFlag) == 0
        else {
            return
        }
        object.flags |= GameObject.dyingFlag
        objects[handle] = object
        // DF_DELAY_FROM_ANIM takes GetDeathAnimTime, which is 0 with no
        // death animation.
        let delay = deathFlags & DeathFlags.delayFromAnimation != 0
            ? 0 : delayTime
        let killerIsPlayer = objects[killer]?.type == .player
        if delay == 0 {
            if deathFlags & DeathFlags.blastRing != 0,
               case let .room(room) = object.location {
                // 0 to 2 more blast rings, 0.1 s apart, from a copy of the
                // object (DoBlastRingEvent).
                let extras = Int(psRand() % 3)
                for index in 0..<extras {
                    createNewEvent(
                        length: Float(index) * 0.1 + 0.1,
                        action: .blastRing(
                            position: object.position,
                            size: object.size,
                            roomSourceIndex: room
                        )
                    )
                }
            }
            if killerIsPlayer, object.isGeneric,
               let score = object.info.flatMap({
                   level.objectInfos?[$0].score
               }) {
                playerScoreAdd(Int(score))
            }
            destroyObject(
                handle,
                explosionMagnitude: damage * 3,
                deathFlags: deathFlags,
                level: level
            )
        } else {
            // SetObjectControlType(CT_DYING): the AI frame stops, and
            // DoDyingFrame counts the delay down.
            object.dying = ObjectDyingInfo(
                deathFlags: deathFlags,
                delayTime: delay,
                killerPlayer: killerIsPlayer && object.isGeneric ? 0 : nil
            )
            objects[handle] = object
            if deathFlags & DeathFlags.delayLosesAntigravity != 0 {
                setFallingPhysics(handle, level: level)
            }
            if deathFlags & DeathFlags.delayFlying != 0 {
                setFlyingPhysics(
                    handle,
                    tumbles: deathFlags & DeathFlags.delayNoTumbleFly == 0
                )
                if deathFlags & DeathFlags.fireball != 0 {
                    createObjectFireball(handle, level: level)
                }
            }
            // DF_DELAY_FADE_AWAY's fade is presentation.
            if deathFlags & DeathFlags.delaySound != 0,
               let dying = objects[handle] {
                playObjectExplosionSound(dying, level: level)
            }
        }
    }
}

/// The death of player 0: `Players[0].flags` PLAYER_FLAGS_DYING or
/// PLAYER_FLAGS_DEAD (player_external.h:80-81), `killer_objnum`, and the
/// `Death[0]` values StartPlayerDeath sets (Player.cpp:2109-2239).
struct PlayerDeathState: Codable, Equatable, Sendable {
    /// DEATH_INSTANT to DEATH_D2STYLE (Player.cpp:2000-2003).
    enum Fate: Int, Codable, Sendable {
        case instant = 0
        case fall = 1
        case breakup = 2
        case d2Style = 3

        /// `max_time_dying` (Player.cpp:2226-2233).
        var maximumTimeDying: Float {
            switch self {
            case .fall: 3
            case .instant: 2.5
            case .breakup: 4
            case .d2Style: 2
            }
        }
    }

    var fate: Fate
    /// PLAYER_FLAGS_DEAD once the dying ends; PLAYER_FLAGS_DYING before.
    var isDead = false
    var killer: ObjectHandle
    /// `initial_death_time`.
    var initialDeathTime: Float
}
