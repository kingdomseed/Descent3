// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/viseffect.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): VisEffectAllocate (:522),
// VisEffectInitType (:553), VisEffectCreate (:569), VisEffectDeleteDead
// (:782), CreateRandomLineSparks (:815), CreateRandomSparks (:854),
// VisEffectSetDeadFlag (:2002), VisEffectMoveOne (:2014) and
// VisEffectMoveAll (:2170); with the Fireballs table (Descent3/fireball.cpp:
// 622), CreateFireball's visual form (fireball.cpp:839), the random
// explosion pickers (fireball.cpp:2388-2416), and do_vis_physics_sim
// (physics/physics.cpp:2422).
//
// The list keeps MAX_VIS_EFFECTS entries, so a full list refuses an effect
// as the original does, and a refused effect takes none of its random
// draws. VisEffectCreate refuses an effect in a room no frame rendered in
// the last 5 seconds. `Katmai` is always true in the released game
// (descent.cpp:429), so the spark makers make twice the sparks asked for.
// The effects are simulated; drawing them is presentation (M2 for the
// types other than the custom explosion and the line spark).

import Foundation

/// One `vis_effect` of type VIS_FIREBALL.
struct VisEffect: Codable, Equatable, Sendable {
    /// MAX_VIS_EFFECTS (viseffect_external.h:56).
    static let capacity = 5_000

    // Fireball ids (fireball_external.h:22-72).
    static let mediumExplosion2ID: UInt8 = 0
    static let smallExplosion2ID: UInt8 = 1
    static let mediumExplosionID: UInt8 = 2
    static let mediumExplosion3ID: UInt8 = 3
    static let bigExplosionID: UInt8 = 4
    static let billowingID: UInt8 = 5
    static let smallExplosionID: UInt8 = 6
    static let blackSmokeID: UInt8 = 8
    static let blastRingID: UInt8 = 9
    static let customExplosionID: UInt8 = 11
    static let hotSparkID: UInt8 = 15
    static let coolSparkID: UInt8 = 16
    static let fadingLineID: UInt8 = 19
    static let blueBlastRingID: UInt8 = 22
    static let particleID: UInt8 = 23
    static let napalmBallID: UInt8 = 25
    static let lightningBoltID: UInt8 = 31

    // VF_ flags (viseffect_external.h:63-71).
    static let usesLifeLeftFlag: UInt16 = 1
    static let deadFlag: UInt16 = 4
    static let planarFlag: UInt16 = 8
    static let expandFlag: UInt16 = 32
    static let attachedFlag: UInt16 = 64

    /// The Fireballs[] entry.
    var id: UInt8
    /// `roomnum`.
    var roomSourceIndex: Int
    var position: Vector3
    /// `end_pos`: the plane normal of a VF_PLANAR effect.
    var endPosition = Vector3.zero
    var velocity = Vector3.zero
    var mass: Float = 0
    var drag: Float = 0
    var size: Float
    var lifeLeft: Float
    var lifetime: Float
    var creationTime: Float
    /// The PF_ flags of its physics.
    var physicsFlags: UInt32 = 0
    /// `movement_type == MT_PHYSICS`.
    var usesPhysics = false
    var flags: UInt16
    /// `lighting_color`, a 16-bit RGB color.
    var lightingColor: UInt16 = 0
    /// `custom_handle`: the weapon whose explosion image (a custom
    /// explosion) or particle texture (a particle) this effect shows. The
    /// C++ keeps the texture handle; the texture is the weapon page's.
    var customWeapon: Int? = nil

    /// The object an attached effect (a lightning bolt) follows, and the
    /// vertices of its submodel it spans (`attach_info`).
    var attachedObject: ObjectHandle? = nil
    var attachedSubmodel = 0
    var attachedVertex = 0
    var attachedEndVertex = 0

    /// The FT_ types of the Fireballs[] entries (fireball.h).
    enum FireballType { case explosion, smoke, effect, spark }

    /// Fireballs[] (fireball.cpp:622-674): each id's type, total_life, and
    /// size.
    static func table(id: UInt8) -> (type: FireballType, life: Float, size: Float) {
        switch id {
        case 0: (.explosion, 0.9, 3)
        case 1: (.explosion, 0.9, 2)
        case 2, 3, 4: (.explosion, 0.9, 3)
        case 5: (.explosion, 1, 1)
        case 6: (.explosion, 1, 2)
        case 7: (.smoke, 0.7, 0.7)
        case 8: (.smoke, 0.7, 1)
        case 9: (.effect, 1, 1)
        case 10: (.smoke, 0.4, 0.7)
        case 11: (.explosion, 0.7, 3)
        case 12: (.explosion, 0.7, 0.7)
        case 13: (.smoke, 0.7, 1)
        case 14: (.effect, 1, 1)
        case 15, 16, 17: (id == 17 ? .effect : .spark, 1, 1)
        case 18, 19, 20, 21, 22, 23: (.effect, 0.7, 3)
        case 24: (.effect, 1, 2)
        case 25, 26, 27: (.explosion, 1, 2)
        case 49: (.explosion, 0.9, 3)
        case 50: (.spark, 1, 1)
        default: (.effect, 1, 2)
        }
    }
}

/// GR_RGB16's OPAQUE_FLAG (lib/grdefs.h).
let sourceOpaqueFlag16: UInt16 = 0x8000

/// GR_RGB16 (lib/grdefs.h:87): 5 bits each of red, green, and blue. Each
/// argument is converted to uint8_t first, as the C++ parameters are.
func sourceRGB16(_ red: Float, _ green: Float, _ blue: Float) -> UInt16 {
    func byte(_ value: Float) -> UInt16 {
        UInt16(UInt8(truncatingIfNeeded: Int(value)))
    }
    return (byte(red) >> 3) << 10 + (byte(green) >> 3) << 5
        + (byte(blue) >> 3)
}

extension GameWorld {
    /// VisEffectCreate (viseffect.cpp:569) for VIS_FIREBALL with
    /// VisEffectInitType (:553): returns the new effect's index, or nil when
    /// the room was not rendered in the last 5 seconds or the list is full.
    mutating func visEffectCreate(
        id: UInt8,
        roomSourceIndex: Int,
        position: Vector3,
        level: Level
    ) -> Int? {
        guard let room = level.rooms.firstIndex(where: {
                  $0.sourceIndex == roomSourceIndex
              }),
              gameTime - rooms[room].lastRenderTime <= 5,
              visEffects.count < VisEffect.capacity
        else {
            return nil
        }
        let table = VisEffect.table(id: id)
        var effect = VisEffect(
            id: id,
            roomSourceIndex: roomSourceIndex,
            position: position,
            size: table.size,
            lifeLeft: table.life,
            lifetime: table.life,
            creationTime: gameTime,
            flags: VisEffect.usesLifeLeftFlag
        )
        if table.type == .explosion, id != VisEffect.customExplosionID,
           id != VisEffect.napalmBallID {
            effect.lightingColor = sourceOpaqueFlag16
                | sourceRGB16(255, 180, 20)
        }
        visEffects.append(effect)
        return visEffects.count - 1
    }

    /// GetRandomSmallExplosion (fireball.cpp:2403).
    mutating func randomSmallExplosion() -> UInt8 {
        psRand() % 2 == 0
            ? VisEffect.smallExplosionID
            : VisEffect.smallExplosion2ID
    }

    /// GetRandomMediumExplosion (fireball.cpp:2396).
    mutating func randomMediumExplosion() -> UInt8 {
        [VisEffect.mediumExplosionID, VisEffect.mediumExplosion2ID,
         VisEffect.mediumExplosion3ID][Int(psRand() % 3)]
    }

    /// GetRandomExplosion (fireball.cpp:2388): above
    /// EXTRA_EXPLOSION_THRESHOLD (15) a big explosion, with no draw.
    mutating func randomExplosion(size: Float) -> UInt8 {
        size > 15 ? VisEffect.bigExplosionID : randomMediumExplosion()
    }

    /// CreateFireball (fireball.cpp:839) with VISUAL_FIREBALL.
    mutating func createFireball(
        position: Vector3,
        id: UInt8,
        roomSourceIndex: Int,
        level: Level
    ) -> Int? {
        visEffectCreate(
            id: id,
            roomSourceIndex: roomSourceIndex,
            position: position,
            level: level
        )
    }

    /// CreateRandomSparks (viseffect.cpp:854): hot or cool sparks that fly
    /// out in random directions. Each spark draws its kind first; one that
    /// gets a list entry then draws its direction, speed, size, and life.
    mutating func createRandomSparks(
        _ count: Int,
        position: Vector3,
        roomSourceIndex: Int,
        whichID: UInt8? = nil,
        forceScalar: Float = 1,
        level: Level
    ) {
        for _ in 0..<(count * 2) {
            var id = psRand() % 2 != 0
                ? VisEffect.hotSparkID : VisEffect.coolSparkID
            if let whichID { id = whichID }
            guard let index = visEffectCreate(
                id: id,
                roomSourceIndex: roomSourceIndex,
                position: position,
                level: level
            ) else {
                continue
            }
            var spark = visEffects[index]
            spark.usesPhysics = true
            spark.mass = 100
            spark.drag = 0.1
            spark.physicsFlags |= WeaponPhysics.gravityFlag
                | WeaponPhysics.noCollideFlag
            var direction = Vector3(
                x: Float(psRand() % 100 - 50),
                y: Float(psRand() % 100),
                z: Float(psRand() % 100 - 50)
            )
            direction = direction == .zero
                ? direction : sourceVectorNormalized(direction)
            spark.velocity = direction * Float(10 + psRand() % 10)
                * forceScalar
            spark.size = Float(0.2 + Double(psRand() % 10) * 0.01)
            spark.flags |= VisEffect.usesLifeLeftFlag
            let lifetime = Float(1 + Double(psRand() % 10) * 0.15)
            spark.lifeLeft = lifetime
            spark.lifetime = lifetime
            visEffects[index] = spark
        }
    }

    /// CreateRandomParticles (viseffect.cpp:900): `count` particles of the
    /// weapon's particle texture. Each that gets a list entry falls with
    /// gravity and draws its direction, speed, size, and life. The
    /// direction is normalized with vm_NormalizeVectorFast.
    mutating func createRandomParticles(
        _ count: Int,
        position: Vector3,
        roomSourceIndex: Int,
        weapon: Int,
        size: Float,
        life: Float,
        level: Level
    ) {
        let tenthLife = life / 10
        let tenthSize = size / 10
        for _ in 0..<count {
            guard let index = visEffectCreate(
                id: VisEffect.particleID,
                roomSourceIndex: roomSourceIndex,
                position: position,
                level: level
            ) else {
                continue
            }
            var particle = visEffects[index]
            particle.usesPhysics = true
            particle.mass = 100
            particle.drag = 0.1
            particle.physicsFlags |= WeaponPhysics.gravityFlag
                | WeaponPhysics.noCollideFlag
            let x = Float(psRand() % 100 - 50)
            let y = Float(psRand() % 100)
            let z = Float(psRand() % 100 - 50)
            particle.velocity = osirisNormalizedFast(
                Vector3(x: x, y: y, z: z)
            ) * Float(10 + psRand() % 10)
            particle.size = size + Float(psRand() % 11 - 5) * tenthSize
            particle.flags |= VisEffect.usesLifeLeftFlag
            let lifetime = life + Float(psRand() % 11 - 5) * tenthLife
            particle.lifeLeft = lifetime
            particle.lifetime = lifetime
            particle.customWeapon = weapon
            visEffects[index] = particle
        }
    }

    /// CreateRandomLineSparks (viseffect.cpp:815) with force scalar 1:
    /// twice `count` sparks (Katmai); each that gets a list entry takes its
    /// random direction, speed, size, and life.
    mutating func createRandomLineSparks(
        _ count: Int,
        position: Vector3,
        roomSourceIndex: Int,
        color: UInt16,
        level: Level
    ) {
        for _ in 0..<(count * 2) {
            guard let index = visEffectCreate(
                id: VisEffect.fadingLineID,
                roomSourceIndex: roomSourceIndex,
                position: position,
                level: level
            ) else {
                continue
            }
            var spark = visEffects[index]
            spark.usesPhysics = true
            spark.mass = 500
            spark.drag = 0.001
            spark.physicsFlags |= WeaponPhysics.gravityFlag
                | WeaponPhysics.noCollideFlag
            var direction = Vector3(
                x: Float(psRand() % 100 - 50),
                y: Float(psRand() % 100),
                z: Float(psRand() % 100 - 50)
            )
            direction = direction == .zero
                ? direction : sourceVectorNormalized(direction)
            spark.velocity = direction * Float(20 + psRand() % 10)
            spark.size = Float(0.7 + Double(psRand() % 10) * 0.04)
            spark.flags |= VisEffect.usesLifeLeftFlag
            let lifetime = Float(1 + Double(psRand() % 10) * 0.15)
            spark.lifeLeft = lifetime
            spark.lifetime = lifetime
            if color == 0 {
                spark.lightingColor = sourceRGB16(
                    Float(200 + psRand() % 50),
                    Float(150 + psRand() % 50),
                    Float(psRand() % 50)
                )
            } else {
                spark.lightingColor = color
            }
            visEffects[index] = spark
        }
    }

    /// VisEffectMoveAll (viseffect.cpp:2170), run after the ObjDoFrameAll
    /// loop: each effect ages, moves by its physics, and is marked dead
    /// when its life runs out.
    mutating func visEffectMoveAll(level: Level) {
        for index in visEffects.indices {
            var effect = visEffects[index]
            if effect.flags & VisEffect.usesLifeLeftFlag != 0 {
                effect.lifeLeft -= frameDuration
            }
            if effect.usesPhysics {
                visPhysicsSim(&effect, level: level)
            }
            if effect.flags & VisEffect.usesLifeLeftFlag != 0,
               effect.lifeLeft < 0 {
                effect.flags |= VisEffect.deadFlag
            }
            // VisEffectMoveOne (viseffect.cpp:2037-2047): an attached
            // effect dies with its object, when its handle's signature no
            // longer matches, or when the player it follows is dying.
            if effect.flags & VisEffect.attachedFlag != 0 {
                let owner = effect.attachedObject.flatMap { objects[$0] }
                if owner == nil
                    || owner!.flags & GameObject.deadFlag != 0
                    || (owner!.type == .player && playerDeath != nil) {
                    effect.flags |= VisEffect.deadFlag
                }
            }
            visEffects[index] = effect
        }
    }

    /// do_vis_physics_sim (physics.cpp:2422) for an effect with
    /// PF_NO_COLLIDE: the drag and gravity integration with no wall test.
    private func visPhysicsSim(_ effect: inout VisEffect, level: Level) {
        guard frameDuration > 0, effect.flags & VisEffect.deadFlag == 0
        else {
            return
        }
        if abs(effect.velocity.x) < 0.000_001,
           abs(effect.velocity.y) < 0.000_001,
           abs(effect.velocity.z) < 0.000_001,
           effect.physicsFlags & WeaponPhysics.gravityFlag == 0 {
            return
        }
        if effect.physicsFlags & WeaponPhysics.fixedVelocityFlag != 0 {
            effect.position = effect.position
                + effect.velocity * frameDuration
        } else if effect.mass > 0, effect.drag > 0 {
            let gravity = effect.physicsFlags & WeaponPhysics.gravityFlag != 0
                ? level.metadata.gravity * effect.mass : 0
            let motion = analyticLinearMotion(
                position: effect.position,
                velocity: effect.velocity,
                force: .init(x: 0, y: gravity, z: 0),
                mass: effect.mass,
                drag: effect.drag,
                duration: frameDuration
            )
            effect.position = motion.position
            effect.velocity = motion.velocity
        }
    }

    /// VisEffectDeleteDead (viseffect.cpp:782), run at the end of
    /// ObjDeleteDead.
    mutating func visEffectDeleteDead() {
        visEffects.removeAll { $0.flags & VisEffect.deadFlag != 0 }
    }
}
