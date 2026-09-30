// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/WeaponFire.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): WeaponCalcGun (:1723),
// FireWeaponFromObject (:1809, the AI path), and CreateAndFireWeapon
// (:1210); from Descent3/ObjInit.cpp, ObjInitWeapon (:965); and from
// physics/physics.cpp (do_physics_sim, :986-1280) and physics/collide.cpp
// (collide_weapon_and_wall :1087, collide_player_and_weapon :2280), the
// flight of a fixed-velocity weapon. The turret angles come from
// SetNormalizedTimeObj (model/polymodel.cpp).
//
// Scope (M1 step 6): the weapons robots fire at the player. Not yet here:
// muzzle flashes and explosions (DoWeaponExploded, visual effects), the
// WPC_ wall-hit precomputation (an optimization), homing, gravity, bounce,
// thrust, spawning, the player-and-weapon impulse (bump_two_objects), and
// weapon hits on other objects (with Damage, M1 step 7 and M2).

import Foundation

/// SetNormalizedTimeObj's turret part (model/polymodel.cpp): each turret
/// submodel of the model's batteries turns by its battery's
/// `norm_turret_angle`, in turns.
func objectTurretAngles(
    _ object: GameObject,
    model: CanonicalModel
) -> [Int: Float] {
    var angles: [Int: Float] = [:]
    for (batteryIndex, battery) in (model.weaponBatteries ?? []).enumerated()
    where object.weaponBatteries.indices.contains(batteryIndex) {
        for (turretIndex, submodel) in battery.turrets.enumerated() {
            angles[submodel] =
                object.weaponBatteries[batteryIndex].turretAngles[turretIndex]
        }
    }
    return angles
}

extension GameWorld {
    /// WeaponCalcGun (WeaponFire.cpp:1723): the world position and normal of
    /// a model gun point, carried up the submodel chain with the current
    /// turret angles.
    func weaponCalcGun(
        _ object: GameObject,
        gunpoint gunIndex: Int,
        model: CanonicalModel,
        turretAngles: [Int: Float]? = nil
    ) -> (point: Vector3, normal: Vector3) {
        guard let gunpoints = model.gunpoints,
              gunpoints.indices.contains(gunIndex)
        else {
            return (object.position, object.orientation.forward)
        }
        let gunpoint = gunpoints[gunIndex]
        let angles = turretAngles ?? objectTurretAngles(object, model: model)
        var chain: [Int] = []
        var current: Int? = gunpoint.parent
        while let index = current {
            chain.append(index)
            current = model.submodels[index].parentIndex
        }
        chain.reverse()
        var origin = Vector3.zero
        var orientation = Matrix3(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )
        for index in chain {
            let submodel = model.submodels[index]
            origin = origin + transform(submodel.offset, by: orientation)
            guard case let .turret(_, _, _, axis) = submodel.presentation,
                  let angle = angles[index]
            else {
                continue
            }
            let radians = angle * 2 * Float.pi
            let local = Matrix3(
                right: rotate(.init(x: 1, y: 0, z: 0), around: axis,
                              angle: radians),
                up: rotate(.init(x: 0, y: 1, z: 0), around: axis,
                           angle: radians),
                forward: rotate(.init(x: 0, y: 0, z: 1), around: axis,
                                angle: radians)
            )
            orientation = .init(
                right: transform(local.right, by: orientation),
                up: transform(local.up, by: orientation),
                forward: transform(local.forward, by: orientation)
            )
        }
        let modelPoint = origin + transform(gunpoint.position, by: orientation)
        return (
            object.position + transform(modelPoint, by: object.orientation),
            sourceVectorNormalized(
                transform(
                    transform(gunpoint.normal, by: orientation),
                    by: object.orientation
                )
            )
        )
    }

    /// MIN_FIRE_SPREAD and MAX_FIRE_SPREAD (WeaponFire.cpp:1806).
    private static let minimumFireSpread: Float = 5_000
    private static let maximumFireSpread: Float = 16_768

    /// FireWeaponFromObject (WeaponFire.cpp:1809) for a CT_AI object.
    /// Returns the new weapon, or `nil` when none was made.
    mutating func fireWeaponFromObject(
        _ handle: ObjectHandle,
        weaponName: String,
        gunpoint: Int,
        forceForward: Bool,
        forceTarget: Bool,
        level: Level
    ) -> ObjectHandle? {
        guard let object = objects[handle],
              let weaponIndex = level.weapons?.firstIndex(where: {
                  $0.name.caseInsensitiveCompare(weaponName) == .orderedSame
              }),
              let model = level.placedObjectModel(handle)
        else {
            return nil
        }
        var position: Vector3
        var direction: Vector3
        if gunpoint >= (model.gunpoints?.count ?? 0) {
            position = object.position
            direction = object.orientation.forward
        } else if forceForward {
            position = weaponCalcGun(object, gunpoint: gunpoint, model: model)
                .point
            direction = object.orientation.forward
        } else if forceTarget, let ai = object.ai,
                  ai.vecToTargetPerceived != .zero {
            position = weaponCalcGun(object, gunpoint: gunpoint, model: model)
                .point
            direction = ai.vecToTargetPerceived
        } else {
            let gun = weaponCalcGun(object, gunpoint: gunpoint, model: model)
            position = gun.point
            direction = gun.normal
        }

        if let ai = object.ai {
            let minimumSpread =
                Difficulty.aiMinimumFireSpread[Difficulty.level]
            if ai.fireSpread != 0 || minimumSpread != 0 {
                // `DIFF_LEVEL / (MAX_DIFFICULTY_LEVELS - 1)` divides
                // integers, so below Insane the scale is 0.
                let difficultyScale =
                    Float(Difficulty.level / (Difficulty.levelCount - 1))
                let spreadScale =
                    Self.maximumFireSpread * (1 - difficultyScale)
                    + Self.minimumFireSpread * difficultyScale
                var fireSpread = Int16(truncatingIfNeeded:
                    Int(ai.fireSpread * spreadScale))
                if ai.flags & ObjectAIFrame.teamMask
                    != ObjectAIFrame.teamRebel,
                   Float(fireSpread) < minimumSpread * spreadScale {
                    fireSpread = Int16(truncatingIfNeeded:
                        Int(minimumSpread * spreadScale))
                }
                let halfSpread = fireSpread >> 1
                if fireSpread > 0 {
                    func angle(_ world: inout GameWorld) -> Int16 {
                        Int16(truncatingIfNeeded:
                            Int(world.psRand() % Int32(fireSpread))
                                - Int(halfSpread))
                    }
                    let pitch = angle(&self)
                    let heading = angle(&self)
                    let bank = angle(&self)
                    direction = inverseTransform(
                        direction,
                        by: sourceRotationMatrix(
                            pitch: pitch,
                            yaw: heading,
                            roll: bank
                        )
                    )
                }
            }
        }

        guard let weapon = createAndFireWeapon(
            position: position,
            direction: direction,
            parent: handle,
            weaponIndex: weaponIndex,
            level: level
        ) else {
            return nil
        }
        // AINotify(weapon, AIN_OBJ_FIRED, obj) (AImain.cpp:2968): the firing
        // AI object hears it as AIN_FIRED_WEAPON. A CT_AI target's dodge
        // goal (AIG_DODGE_OBJ) arrives with the dodge goals in M2.
        if objects[handle]?.ai != nil {
            osirisCallEvent(
                handle,
                .aiNotify(.other, it: weapon),
                level: level
            )
        }
        // WSI_FLYING.
        play3DSound(level.weapons![weaponIndex].sounds[2])
        return weapon
    }

    /// CreateAndFireWeapon (WeaponFire.cpp:1210) and ObjInitWeapon
    /// (ObjInit.cpp:965). The weapon is made only when the line from the
    /// parent to the gun point is clear; a full object table makes none
    /// (object.cpp:1605).
    mutating func createAndFireWeapon(
        position: Vector3,
        direction: Vector3,
        parent handle: ObjectHandle,
        weaponIndex: Int,
        level: Level
    ) -> ObjectHandle? {
        guard let parent = objects[handle],
              parent.flags & GameObject.deadFlag == 0,
              case let .room(parentRoom) = parent.location
        else {
            return nil
        }
        let clear = traceIndoorMovement(
            in: level,
            roomStates: rooms,
            startRoom: parentRoom,
            start: parent.position,
            end: position,
            radius: 0
        )
        guard case .noHit = clear.outcome else { return nil }
        let weapon = level.weapons![weaponIndex]
        guard let created = objects.create(
            type: .weapon,
            renderType: weapon.model == nil ? .none : .polyobj,
            location: .room(clear.containingRoomSourceIndex),
            position: position,
            orientation: sourceOrientation(
                forward: direction,
                up: parent.orientation.up
            )
        ) else {
            return nil
        }
        var object = objects[created]!
        object.weapon = weaponIndex
        object.parent = handle
        object.usesPhysics = true
        object.lifeLeft = weapon.lifetime
        object.size = weapon.flags & CanonicalWeapon.customSizeFlag != 0
            ? weapon.customSize
            : weapon.size
        // A robot's shots fly at Diff_ai_weapon_speed, a rebel's at full
        // speed.
        let scalar: Float = parent.ai.map {
            $0.flags & ObjectAIFrame.teamMask == ObjectAIFrame.teamRebel
        } == true
            ? 1
            : Difficulty.aiWeaponSpeed[Difficulty.level]
        object.velocity = direction * (weapon.speed * scalar)
        if weapon.physicsFlags & WeaponPhysics.usesParentVelocityFlag != 0 {
            let forwardSpeed = dot(parent.velocity, parent.orientation.forward)
            let forward = forwardSpeed > 0
                ? parent.orientation.forward * forwardSpeed
                : Vector3.zero
            object.velocity = object.velocity + forward
                + parent.orientation.right
                    * (0.1 * dot(parent.velocity, parent.orientation.right))
                + parent.orientation.up
                    * (0.1 * dot(parent.velocity, parent.orientation.up))
        }
        objects[created] = object
        return created
    }

    /// The physics move of a fixed-velocity weapon in ObjDoFrame
    /// (do_physics_sim, physics.cpp:986-1280): the nearest of the walls and
    /// the player on the move ends it. A wall hit plays WSI_IMPACT_WALL and
    /// kills the weapon (collide_weapon_and_wall, collide.cpp:1212-1240).
    /// A player hit runs collide_two_objects.
    mutating func moveWeapon(_ handle: ObjectHandle, level: Level) {
        guard var weapon = objects[handle],
              let weaponIndex = weapon.weapon,
              case let .room(room) = weapon.location
        else {
            return
        }
        let definition = level.weapons![weaponIndex]
        let end = weapon.position + weapon.velocity * frameDuration
        let radius = definition.physicsFlags
            & WeaponPhysics.pointCollideWallsFlag != 0 ? 0 : weapon.size
        let trace = traceIndoorMovement(
            in: level,
            roomStates: rooms,
            startRoom: room,
            start: weapon.position,
            end: end,
            radius: radius
        )
        if let hit = weaponMoveObjectHit(
            weapon,
            start: weapon.position,
            end: trace.finalPosition,
            visitedRoomSourceIndices: trace.visitedRoomSourceIndices,
            level: level
        ) {
            let move = trace.finalPosition - weapon.position
            let length = sqrt(dot(move, move))
            weapon.position = length > 0
                ? weapon.position + move * (hit.distance / length)
                : weapon.position
            objects[handle] = weapon
            collideTwoObjects(handle, hit.handle, level: level)
            return
        }
        weapon.position = trace.finalPosition
        weapon.location = .room(trace.containingRoomSourceIndex)
        if case .wallHit = trace.outcome {
            play3DSound(definition.sounds[CanonicalWeapon.impactWallSound])
            weapon.flags |= GameObject.deadFlag
        }
        objects[handle] = weapon
    }

    /// The object check of a weapon's move (FQ_CHECK_OBJS): the nearest
    /// object whose CollisionResult pair with a weapon is translated, in the
    /// rooms the move visits. The parent is skipped (PF_NO_COLLIDE_PARENT,
    /// ObjInit.cpp:1008). A polygon object (the player) is checked with the
    /// weapon's sphere against its model (RESULT_CHECK_SPHERE_POLY,
    /// findintersection.cpp:3459); a sphere object is checked with
    /// check_vector_to_object, where two moving objects that separate do
    /// not hit (:1771).
    private func weaponMoveObjectHit(
        _ weapon: GameObject,
        start: Vector3,
        end: Vector3,
        visitedRoomSourceIndices: [Int],
        level: Level
    ) -> (handle: ObjectHandle, distance: Float)? {
        var nearest: (handle: ObjectHandle, distance: Float)?
        for object in objects where object.handle != weapon.handle {
            guard object.handle != weapon.parent,
                  object.flags & GameObject.deadFlag == 0,
                  case let .room(room) = object.location,
                  visitedRoomSourceIndices.contains(room)
            else {
                continue
            }
            let distance: Float?
            switch collisionResult(.weapon, object.type) {
            case .nothing, .polySphere:
                continue
            case .spherePoly:
                distance = level.polygonModel(of: object).flatMap {
                    polyCollideObject(
                        model: $0,
                        position: object.position,
                        orientation: object.orientation,
                        p0: start,
                        p1: end,
                        radius: weapon.size
                    )?.distance
                }
            case .sphereSphere:
                let otherVelocity = object.type == .player ? velocity
                    : object.velocity
                if dot(object.position - weapon.position,
                       otherVelocity - weapon.velocity) >= 0 {
                    continue
                }
                distance = checkVectorToSphere(
                    start: start,
                    end: end,
                    center: object.position,
                    radius: object.size + weapon.size
                )
            }
            guard let distance,
                  distance < (nearest?.distance ?? .infinity)
            else {
                continue
            }
            nearest = (object.handle, distance)
        }
        return nearest
    }

    /// collide_player_and_weapon (collide.cpp:2280): the firing AI object
    /// learns it hit, the player takes the weapon's damage, and the weapon
    /// dies.
    mutating func collidePlayerAndWeapon(
        player: ObjectHandle,
        weapon handle: ObjectHandle,
        level: Level
    ) {
        guard let weapon = objects[handle],
              let weaponIndex = weapon.weapon
        else {
            return
        }
        let definition = level.weapons![weaponIndex]
        if objects[weapon.parent]?.ai != nil {
            aiNotifyWeaponHitObject(weapon.parent, target: player,
                                    level: level)
        }
        let electrical =
            definition.flags & CanonicalWeapon.electricalFlag != 0
        let damage = electrical
            ? definition.playerDamage * frameDuration
            : definition.playerDamage
        if applyDamageToPlayer(player, damage: damage) {
            play3DSound(definition.sounds[CanonicalWeapon.impactRobotSound])
        }
        if !electrical {
            objects[handle]?.flags |= GameObject.deadFlag
        }
    }
}

/// The PF_ flags a weapon's physics reads (object_external.h:313-335).
enum WeaponPhysics {
    static let usesThrustFlag: UInt32 = 0x40
    static let usesParentVelocityFlag: UInt32 = 0x400
    static let fixedVelocityFlag: UInt32 = 0x800
    static let pointCollideWallsFlag: UInt32 = 0x40000
}
