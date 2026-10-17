// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/WeaponFire.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): ObjectsAreRelated (:962),
// CreateAndFireWeapon (:1210), WeaponDoFrame (:1621), WeaponCalcGun
// (:1723), FireWeaponFromObject (:1809), DoWeaponExploded (:3058),
// CreateTimeoutSpawnFromWeapon (:3162), and TimeoutWeapon (:3348); from
// Descent3/ObjInit.cpp, ObjInitWeapon (:965); and from physics/physics.cpp
// (do_physics_sim, :683-1583) and physics/collide.cpp
// (collide_weapon_and_wall, :1087), the flight of a weapon and its wall hit.
// The turret angles come from SetNormalizedTimeObj (model/polymodel.cpp).
// The player's firing is in WeaponFire+Player.swift, and the weapon's object
// hits in Collide.swift.
//
// Weapons fly with fixed velocity or with drag and gravity, hit walls and
// objects, explode, stick (PF_STICK), drop particles, time out and spawn
// their children, and, as energy weapons, bounce off force fields
// (collide.cpp:1117, physics.cpp:1317). A PF_NO_COLLIDE weapon moves with
// no collision (physics.cpp:958). Not yet here: the WPC_ wall-hit
// precomputation (an optimization), homing, thrust, wind, bounces off
// ordinary walls, impact spawns, weapon-to-weapon hits, volatile and lava
// surfaces, scorches, breakable glass, the weapon's wall triggers, muzzle
// flashes, smoke trails, the spin of a weapon's model, and electrical
// weapons (M2).

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

    /// FireWeaponFromObject (WeaponFire.cpp:1809). Only a CT_AI object
    /// spreads its fire. Returns the new weapon, or `nil` when none was
    /// made.
    @discardableResult
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
              })
        else {
            return nil
        }
        var position: Vector3
        var direction: Vector3
        let model = level.polygonModel(of: object)
        if gunpoint == -1 {
            // Gun -1 fires from the object's center (WeaponFire.cpp:1826).
            position = object.position
            direction = object.orientation.forward
        } else if let model {
            if gunpoint >= (model.gunpoints?.count ?? 0) {
                position = object.position
                direction = object.orientation.forward
            } else if forceForward {
                position = weaponCalcGun(
                    object, gunpoint: gunpoint, model: model
                ).point
                direction = object.orientation.forward
            } else if forceTarget, let ai = object.ai,
                      ai.vecToTargetPerceived != .zero {
                position = weaponCalcGun(
                    object, gunpoint: gunpoint, model: model
                ).point
                direction = ai.vecToTargetPerceived
            } else {
                let gun = weaponCalcGun(
                    object, gunpoint: gunpoint, model: model
                )
                position = gun.point
                direction = gun.normal
            }
        } else {
            return nil
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
    /// (object.cpp:1605). A weapon fired by a weapon takes that weapon's
    /// parent.
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
        // ObjInitWeapon: every weapon is RT_WEAPON (ObjInit.cpp:1011).
        guard let created = objects.create(
            type: .weapon,
            renderType: .weapon,
            location: .room(clear.containingRoomSourceIndex),
            position: position,
            // vm_VectorToMatrix(dir, parent's up) (WeaponFire.cpp:1273),
            // which also takes a heading along the parent's up.
            orientation: sourceVectorToMatrix(
                forward: direction,
                up: parent.orientation.up
            )
        ) else {
            return nil
        }
        var object = objects[created]!
        object.weapon = weaponIndex
        object.creationTime = gameTime
        object.lastDropTime = 0
        // PF_NO_COLLIDE_PARENT (ObjInit.cpp:1008).
        object.noCollideParent = true
        // ObjInitWeapon: a weapon drawn with a model is a polygon object
        // (ObjInit.cpp:1019).
        if weapon.model != nil {
            object.flags |= GameObject.polygonObjectFlag
        }
        object.parent = parent.flags & GameObject.attachedFlag != 0
            ? parent.attachUltimateHandle
            : handle
        // The highest creator that is not a weapon is the parent.
        var ancestor = objects[handle]
        var steps = 0
        while let current = ancestor, current.type == .weapon,
              steps < ObjectTable.capacity {
            ancestor = objects[current.parent]
            if let ancestor { object.parent = ancestor.handle }
            steps += 1
        }
        object.usesPhysics = true
        object.lifeLeft = weapon.lifetime
        object.size = weapon.flags & CanonicalWeapon.customSizeFlag != 0
            ? weapon.customSize
            : weapon.size
        // A robot's shots fly at Diff_ai_weapon_speed, a rebel's and the
        // player's at full speed (the player's weapon_speed_scalar is 1).
        let firer = objects[object.parent]
        let scalar: Float
        if firer == nil || firer?.type != .player {
            scalar = firer?.ai.map {
                $0.flags & ObjectAIFrame.teamMask == ObjectAIFrame.teamRebel
            } == true
                ? 1
                : Difficulty.aiWeaponSpeed[Difficulty.level]
        } else {
            scalar = 1
        }
        object.velocity = direction * (weapon.speed * scalar)
        if weapon.physicsFlags & WeaponPhysics.usesParentVelocityFlag != 0,
           parent.type != .weapon {
            let parentVelocity = objectVelocity(parent)
            let forwardSpeed = dot(parentVelocity, parent.orientation.forward)
            let forward = forwardSpeed > 0
                ? parent.orientation.forward * forwardSpeed
                : Vector3.zero
            object.velocity = object.velocity + forward
                + parent.orientation.right
                    * (0.1 * dot(parentVelocity, parent.orientation.right))
                + parent.orientation.up
                    * (0.1 * dot(parentVelocity, parent.orientation.up))
        }
        objects[created] = object
        return created
    }

    /// MAX_WEAPON_NOT_HIT_PARENT_TIME (weapon.h:205): until then a weapon
    /// keeps PF_NO_COLLIDE_PARENT (ObjInit.cpp:1008, WeaponFire.cpp:1627).
    static let weaponNotHitParentTime: Float = 3

    /// MAX_NON_PLAYER_SIM_LOOPS (physics.cpp:48).
    private static let maximumSimLoops = 5

    /// SOUND_FORCEFIELD_BOUNCE (sounds.h:122). The static sound table is
    /// not imported yet, so the name plays nothing until M2.
    static let forceFieldBounceSound = ""

    /// WeaponDoFrame (WeaponFire.cpp:1621), the CT_WEAPON control of
    /// ObjDoFrame: the weapon loses PF_NO_COLLIDE_PARENT after
    /// MAX_WEAPON_NOT_HIT_PARENT_TIME, and a weapon with particles drops one
    /// behind it each `1 / particle_count` seconds (CreateRandomParticles).
    /// Weapon coronas are on (Detail_settings, init.cpp:1228). Thrust,
    /// homing, smoke trails, and rings arrive with the weapons that use them
    /// (M2).
    mutating func weaponDoFrame(_ handle: ObjectHandle, level: Level) {
        guard let weapon = objects[handle],
              let weaponIndex = weapon.weapon
        else {
            return
        }
        if Self.weaponNotHitParentTime + weapon.creationTime < gameTime {
            objects[handle]?.noCollideParent = false
        }
        let definition = level.weapons![weaponIndex]
        guard let particles = definition.particles, particles.count > 0,
              case let .room(room) = weapon.location
        else {
            return
        }
        let position = weapon.position - weapon.orientation.forward
            * weapon.size
        let interval = 1 / Float(particles.count)
        if gameTime - (weapon.lastDropTime ?? 0) > interval {
            createRandomParticles(
                1,
                position: position,
                roomSourceIndex: room,
                weapon: weaponIndex,
                size: particles.size,
                life: particles.lifetime,
                level: level
            )
            objects[handle]?.lastDropTime = gameTime
        }
    }

    /// The physics move of a weapon in ObjDoFrame (do_physics_sim,
    /// physics.cpp:683-1583). A dead, attached, or unmoving weapon does not
    /// move (:750, :836-849). Each pass moves the weapon over the time
    /// left, a fixed-velocity weapon in a line and any other with its drag
    /// and gravity (:823-831), to the nearest wall or object on the move. A
    /// PF_NO_COLLIDE weapon just takes the end of the move and keeps its room
    /// (:957-968). The weapon takes the hit point and its room before the
    /// collision runs (ObjSetPos, :1142), and the time left shrinks by the
    /// part of the move made (:1171-1191). An object hit runs
    /// collide_two_objects, and a weapon it stuck to the object stops there
    /// (:1516). A wall hit runs collide_weapon_and_wall; then a PF_STICK
    /// weapon stops on the wall (MT_NONE, noting a portal face, :1290-1315),
    /// and an energy weapon that hit a force field reflects (:1317-1394) and
    /// flies on with the time left. A weapon with gravity faces its velocity
    /// (:1214, :1439). A dead weapon, or MAX_NON_PLAYER_SIM_LOOPS passes,
    /// ends the move. `last_pos` is the position the move started from
    /// (:1583).
    mutating func moveWeapon(_ handle: ObjectHandle, level: Level) {
        guard let initial = objects[handle],
              let weaponIndex = initial.weapon,
              initial.flags & (GameObject.deadFlag | GameObject.attachedFlag)
                == 0,
              frameDuration > 0,
              case .room = initial.location
        else {
            return
        }
        let definition = level.weapons![weaponIndex]
        let flags = definition.physicsFlags
        let gravity: Vector3
        if flags & WeaponPhysics.gravityFlag != 0 {
            gravity = .init(x: 0, y: level.metadata.gravity * definition.mass,
                            z: 0)
        } else if flags & WeaponPhysics.reverseGravityFlag != 0 {
            gravity = .init(x: 0,
                            y: -level.metadata.gravity * definition.mass,
                            z: 0)
        } else {
            gravity = .zero
        }
        func tiny(_ v: Vector3) -> Bool {
            abs(v.x) <= 0.000_001 && abs(v.y) <= 0.000_001
                && abs(v.z) <= 0.000_001
        }
        if tiny(initial.velocity), flags & WeaponPhysics.gravityFlag == 0 {
            return
        }
        let radius = flags & WeaponPhysics.pointCollideWallsFlag != 0
            ? 0 : initial.size
        let initialPosition = initial.position
        var remaining = frameDuration
        var passes = 0
        defer {
            if objects[handle] != nil {
                objects[handle]?.lastPosition = initialPosition
            }
        }
        while remaining > 0, passes < Self.maximumSimLoops {
            passes += 1
            guard var weapon = objects[handle],
                  weapon.flags & GameObject.deadFlag == 0,
                  weapon.usesPhysics,
                  case let .room(room) = weapon.location
            else {
                return
            }
            let start = weapon.position
            let end: Vector3
            var endVelocity = weapon.velocity
            if flags & WeaponPhysics.fixedVelocityFlag != 0
                || definition.mass <= 0 || definition.drag <= 0 {
                end = start + weapon.velocity * remaining
            } else {
                let motion = analyticLinearMotion(
                    position: start,
                    velocity: weapon.velocity,
                    force: gravity,
                    mass: definition.mass,
                    drag: definition.drag,
                    duration: remaining
                )
                end = motion.position
                endVelocity = motion.velocity
            }
            if flags & WeaponPhysics.noCollideFlag != 0 {
                weapon.velocity = endVelocity
                weapon.position = end
                objects[handle] = weapon
                return
            }
            let trace = traceIndoorMovement(
                in: level,
                roomStates: rooms,
                startRoom: room,
                start: start,
                end: end,
                radius: radius
            )
            let attempted = vectorDistance(start, end)
            if let hit = weaponMoveObjectHit(
                weapon,
                start: start,
                end: trace.finalPosition,
                visitedRoomSourceIndices: trace.visitedRoomSourceIndices,
                level: level
            ) {
                let move = trace.finalPosition - start
                let length = sqrt(dot(move, move))
                let hitPosition = length > 0
                    ? start + move * (hit.distance / length)
                    : start
                // ObjSetPos with fvi's hit room: the room past the last
                // portal the move crossed before the hit point.
                let toHit = traceIndoorMovement(
                    in: level,
                    roomStates: rooms,
                    startRoom: room,
                    start: start,
                    end: hitPosition,
                    radius: 0
                )
                var hitRoom = room
                if let last = toHit.passedPortalFaces.last,
                   let portal = level.rooms.first(where: {
                       $0.sourceIndex == last.roomSourceIndex
                   })?.portals.first(where: {
                       $0.faceIndex == last.faceIndex
                   }) {
                    hitRoom = portal.connectedRoom
                }
                weapon.position = hitPosition
                weapon.location = .room(hitRoom)
                weapon.velocity = endVelocity
                objects[handle] = weapon
                remaining = attempted > 0
                    ? remaining * max(0, (attempted - vectorDistance(start, hitPosition)) / attempted)
                    : 0
                collideTwoObjects(handle, hit.handle, link: hit.link,
                                  level: level)
                // A weapon that stuck to the object moves with it now.
                if objects[handle]?.objectLink != nil { return }
                continue
            }
            weapon.position = trace.finalPosition
            weapon.location = .room(trace.containingRoomSourceIndex)
            weapon.velocity = endVelocity
            guard case let .wallHit(contact) = trace.outcome else {
                faceVelocityIfFalling(&weapon, flags: flags)
                objects[handle] = weapon
                return
            }
            objects[handle] = weapon
            let prior = remaining
            remaining = attempted > 0
                ? prior * max(0, (attempted - contact.distance) / attempted)
                : 0
            let movedTime = prior - remaining
            if movedTime > 0.0001 {
                weapon.velocity = (trace.finalPosition - start) / movedTime
                objects[handle] = weapon
            }
            let forceField =
                surfacePhysicsBehavior(for: contact, in: level) == .forceField
            collideWeaponAndWall(
                handle,
                normal: contact.normal,
                forceField: forceField,
                level: level
            )
            guard var bounced = objects[handle],
                  bounced.flags & GameObject.deadFlag == 0
            else {
                return
            }
            if !forceField, flags & ObjectPhysics.stickFlag != 0 {
                // PF_STICK (physics.cpp:1290-1315): the weapon stops on the
                // wall; on a portal face it notes the portal.
                bounced.usesPhysics = false
                if let face = level.rooms.first(where: {
                       $0.sourceIndex == contact.roomSourceIndex
                   })?.faces[contact.faceIndex],
                   let portal = face.portalIndex {
                    bounced.flags |= GameObject.stuckOnPortalFlag
                    bounced.stuckPortal = .init(
                        roomSourceIndex: contact.roomSourceIndex,
                        portal: portal
                    )
                }
                bounced.velocity = .zero
                objects[handle] = bounced
                return
            }
            if forceField {
                // A weapon that hits a force field loses PF_NO_COLLIDE_PARENT
                // (physics.cpp:1280) and is mirrored off the wall (:1318,
                // :1365). It faces its new heading (:1439).
                bounced.noCollideParent = false
                let wallPart = dot(contact.normal, bounced.velocity) * 2
                bounced.velocity = bounced.velocity - contact.normal * wallPart
                if bounced.velocity != .zero {
                    bounced.orientation = sourceVectorToMatrix(
                        forward: bounced.velocity,
                        up: bounced.orientation.up
                    )
                }
                objects[handle] = bounced
            }
        }
    }

    /// A weapon with PF_GRAVITY or PF_WIND faces its velocity after a move
    /// that hit nothing (physics.cpp:1214).
    private func faceVelocityIfFalling(_ weapon: inout GameObject,
                                       flags: UInt32) {
        if flags & (WeaponPhysics.gravityFlag | WeaponPhysics.windFlag) != 0,
           weapon.velocity != .zero {
            weapon.orientation = sourceVectorToMatrix(
                forward: weapon.velocity,
                up: weapon.orientation.up
            )
        }
    }

    /// collide_weapon_and_wall (collide.cpp:1087) for a weapon that does
    /// not bounce. An energy weapon that hits a force field (TF_FORCEFIELD)
    /// plays SOUND_FORCEFIELD_BOUNCE and lives on (collide.cpp:1117-1136). A
    /// PF_STICK weapon plays its WSI_BOUNCE sound and lives on (:1241-1257);
    /// the physics then stops it. Any other hit plays the wall impact sound,
    /// explodes, and dies (:1216-1240). Scorches, triggers, breakable glass,
    /// special surfaces, impact spawns, and AIN_HEAR_NOISE arrive in M2.
    private mutating func collideWeaponAndWall(
        _ handle: ObjectHandle,
        normal: Vector3,
        forceField: Bool,
        level: Level
    ) {
        guard let weaponIndex = objects[handle]?.weapon else { return }
        let definition = level.weapons![weaponIndex]
        if forceField,
           definition.flags & CanonicalWeapon.matterWeaponFlag == 0 {
            play3DSound(Self.forceFieldBounceSound)
            return
        }
        if definition.physicsFlags & ObjectPhysics.stickFlag != 0 {
            play3DSound(definition.sounds[CanonicalWeapon.bounceSound])
            return
        }
        play3DSound(definition.sounds[CanonicalWeapon.impactWallSound])
        doWeaponExploded(handle, normal: normal, level: level)
        objects[handle]?.flags |= GameObject.deadFlag
    }

    /// The object check of a weapon's move (FQ_CHECK_OBJS): the nearest
    /// object whose CollisionResult pair with a weapon is translated, in the
    /// rooms the move visits, skipping related objects (ObjectsAreRelated,
    /// findintersection.cpp:3362). A polygon object is checked with the
    /// weapon's sphere against its model (RESULT_CHECK_SPHERE_POLY,
    /// findintersection.cpp:3459), which also gives the submodel frame a
    /// sticking weapon keeps (hit_subobj_pos, newstyle_fi.cpp:216); a sphere
    /// object is checked with check_vector_to_object, where two moving
    /// objects that separate do not hit (:1771). A tie goes to the lower
    /// slot.
    private func weaponMoveObjectHit(
        _ weapon: GameObject,
        start: Vector3,
        end: Vector3,
        visitedRoomSourceIndices: [Int],
        level: Level
    ) -> (handle: ObjectHandle, distance: Float, link: ObjectLinkInfo?)? {
        var nearest: (handle: ObjectHandle, distance: Float,
                      link: ObjectLinkInfo?)?
        for object in objects where object.handle != weapon.handle {
            guard object.flags & GameObject.deadFlag == 0,
                  object.flags & GameObject.noObjectCollisionsFlag == 0,
                  case let .room(room) = object.location,
                  visitedRoomSourceIndices.contains(room),
                  !objectsAreRelated(weapon, object, level: level)
            else {
                continue
            }
            let distance: Float?
            var link: ObjectLinkInfo?
            switch collisionResult(.weapon, object.type) {
            case .nothing, .polySphere:
                continue
            case .spherePoly:
                let hit = level.polygonModel(of: object).flatMap {
                    polyCollideObject(
                        model: $0,
                        position: object.position,
                        orientation: object.orientation,
                        p0: start,
                        p1: end,
                        radius: weapon.size
                    )
                }
                distance = hit?.distance
                if let hit {
                    link = ObjectLinkInfo(
                        parentHandle: object.handle,
                        submodel: hit.submodel,
                        position: hit.submodelIntersection,
                        forward: inverseTransform(
                            weapon.orientation.forward,
                            by: object.orientation
                        ),
                        up: inverseTransform(
                            weapon.orientation.up,
                            by: object.orientation
                        )
                    )
                }
            case .sphereSphere:
                if dot(object.position - weapon.position,
                       objectVelocity(object) - weapon.velocity) >= 0 {
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
            nearest = (object.handle, distance, link)
        }
        return nearest
    }

    /// ObjectsAreRelated (WeaponFire.cpp:962): whether two objects must not
    /// collide. Linked objects, PF_NO_COLLIDE objects, attached objects, a
    /// non-weapon and the non-weapon it made within 3 s, a weapon and its
    /// parent (or an object attached to its parent) while it has
    /// PF_NO_COLLIDE_PARENT, and two weapons (unless siblings that may hit
    /// each other) are related. A weapon's PF_ flags are its page's; the
    /// runtime clears PF_NO_COLLIDE_PARENT in `noCollideParent`. No object
    /// has the chaff chunk page, a door, or PF_PERSISTENT yet, so those
    /// cases (:984-996, :1011-1017) do not arise (M2).
    func objectsAreRelated(_ a: GameObject, _ b: GameObject,
                           level: Level) -> Bool {
        func physicsFlags(_ object: GameObject) -> UInt32 {
            if let weapon = object.weapon {
                return level.weapons?[weapon].physicsFlags ?? 0
            }
            return object.physics?.flags ?? 0
        }
        if a.objectLink != nil || b.objectLink != nil { return true }
        if a.type != .shockwave,
           physicsFlags(a) & WeaponPhysics.noCollideFlag != 0 {
            return true
        }
        if b.type != .shockwave,
           physicsFlags(b) & WeaponPhysics.noCollideFlag != 0 {
            return true
        }
        if a.type == .building, a.usesPhysics, b.type == .powerup {
            return true
        }
        if b.type == .building, b.usesPhysics, a.type == .powerup {
            return true
        }
        if areObjectsAttached(a, b) { return true }
        if a.type != .weapon, b.type != .weapon {
            return (gameTime < a.creationTime + 3 && a.parent == b.handle)
                || (gameTime < b.creationTime + 3 && b.parent == a.handle)
        }
        // See if b is the parent of a.
        if a.type == .weapon, a.noCollideParent {
            if a.parent == b.handle { return true }
            if let parent = objects[a.parent], areObjectsAttached(b, parent) {
                return true
            }
        }
        // See if a is the parent of b.
        if b.type == .weapon, b.noCollideParent {
            if b.parent == a.handle { return true }
            if let parent = objects[b.parent], areObjectsAttached(a, parent) {
                return true
            }
        }
        guard a.type == .weapon, b.type == .weapon else { return false }
        // Siblings hit each other only with PF_HITS_SIBLINGS; other weapons
        // never do.
        if a.parent == b.parent {
            return physicsFlags(a) & WeaponPhysics.hitsSiblingsFlag == 0
                && physicsFlags(b) & WeaponPhysics.hitsSiblingsFlag == 0
        }
        return true
    }

    /// AreObjectsAttached (WeaponFire.cpp:944).
    private func areObjectsAttached(_ a: GameObject, _ b: GameObject) -> Bool {
        let aAttached = a.flags & GameObject.attachedFlag != 0
        let bAttached = b.flags & GameObject.attachedFlag != 0
        guard aAttached || bAttached else { return false }
        if aAttached, a.attachUltimateHandle == b.handle
            || (bAttached && a.attachUltimateHandle == b.attachUltimateHandle) {
            return true
        }
        return bAttached && b.attachUltimateHandle == a.handle
    }

    /// DoWeaponExploded (WeaponFire.cpp:3058): the shockwave (or the
    /// concussive force at once), then the explosion effect, which a
    /// non-matter weapon does not show when it hits the viewer (the
    /// player). `hitObject` is the object it hit, if any.
    mutating func doWeaponExploded(
        _ handle: ObjectHandle,
        normal: Vector3? = nil,
        hitObject: ObjectHandle = .none,
        level: Level
    ) {
        guard let weapon = objects[handle],
              let weaponIndex = weapon.weapon
        else {
            return
        }
        let definition = level.weapons![weaponIndex]
        if definition.flags & CanonicalWeapon.electricalFlag != 0 { return }
        makeShockwave(
            exploding: handle,
            parent: weapon.parent,
            impact: definition.impact,
            level: level
        )
        guard let weapon = objects[handle],
              case let .room(room) = weapon.location
        else {
            return
        }
        let normal = normal ?? weapon.orientation.forward
        if objects[hitObject]?.type == .player,
           definition.flags & CanonicalWeapon.matterWeaponFlag == 0 {
            return
        }
        let explosion = definition.explosion
        let hasImage = explosion?.hasImage == true
        let color = definition.lighting.map {
            0x8000 | sourceRGB16(
                $0.secondaryColor.x * 255,
                $0.secondaryColor.y * 255,
                $0.secondaryColor.z * 255
            )
        } ?? 0x8000
        let planar = definition.flags & CanonicalWeapon.planarBlastFlag != 0
        if definition.flags & CanonicalWeapon.blastRingFlag != 0 {
            // A blast ring (BLAST_RING_INDEX) arrives with the fireball
            // table (M2); it takes no random draw.
            return
        }
        let id = hasImage
            ? VisEffect.customExplosionID : randomSmallExplosion()
        guard let index = visEffectCreate(
            id: id,
            roomSourceIndex: room,
            position: weapon.position,
            level: level
        ) else {
            return
        }
        var effect = visEffects[index]
        if hasImage, let explosion {
            effect.size = explosion.size
            effect.lifetime = explosion.lifetime
            effect.lifeLeft = explosion.lifetime
            effect.customWeapon = weaponIndex
            effect.lightingColor = color
        }
        // A planar blast lies on the hit surface. Only a custom or a planar
        // explosion takes WF_EXPAND (WeaponFire.cpp:3122-3127, :3152).
        if planar {
            effect.flags |= VisEffect.planarFlag
            effect.endPosition = normal
        }
        if (planar || hasImage),
           definition.flags & CanonicalWeapon.expandFlag != 0 {
            effect.flags |= VisEffect.expandFlag
        }
        visEffects[index] = effect
    }

    /// TimeoutWeapon (WeaponFire.cpp:3348): a WF_SPAWNS_TIMEOUT weapon
    /// explodes along its heading and makes its spawn; a matter weapon that
    /// spawns nothing, and a WF_TIMEOUT_WALL weapon, explode as they time
    /// out. Robot spawns arrive with countermeasures (M2).
    mutating func timeoutWeapon(_ handle: ObjectHandle, level: Level) {
        guard let weapon = objects[handle],
              let weaponIndex = weapon.weapon
        else {
            return
        }
        let definition = level.weapons![weaponIndex]
        if definition.flags & CanonicalWeapon.spawnsTimeoutFlag != 0,
           definition.spawn != nil {
            doWeaponExploded(handle, normal: weapon.orientation.forward,
                             level: level)
            createTimeoutSpawnFromWeapon(handle, level: level)
        }
        if definition.flags & CanonicalWeapon.matterWeaponFlag != 0,
           definition.flags & CanonicalWeapon.spawnsTimeoutFlag == 0,
           definition.spawn == nil {
            play3DSound(definition.sounds[CanonicalWeapon.impactWallSound])
            doWeaponExploded(
                handle,
                normal: .init(x: 0, y: 1, z: 0),
                level: level
            )
        }
        if definition.flags & CanonicalWeapon.timeoutWallFlag != 0 {
            play3DSound(definition.sounds[CanonicalWeapon.impactWallSound])
            doWeaponExploded(handle, level: level)
        }
    }

    /// CreateTimeoutSpawnFromWeapon (WeaponFire.cpp:3162): the alternate
    /// spawn is chosen with one draw when the page has one; then the first
    /// child fires along the weapon's heading from half its size ahead, and
    /// each other child fires from the same point on a ring 1/16 of a turn
    /// off the heading (FixSin and FixCos of the ring angle, as 4096-unit
    /// pitch and heading twists).
    mutating func createTimeoutSpawnFromWeapon(_ handle: ObjectHandle,
                                               level: Level) {
        guard let weapon = objects[handle],
              let weaponIndex = weapon.weapon,
              let spawn = level.weapons![weaponIndex].spawn,
              var spawnIndex = level.weapons!.firstIndex(where: {
                  $0.name.caseInsensitiveCompare(spawn.weapon) == .orderedSame
              })
        else {
            return
        }
        if !spawn.alternateWeapon.isEmpty, spawn.alternateChance > 0,
           let alternate = level.weapons!.firstIndex(where: {
               $0.name.caseInsensitiveCompare(spawn.alternateWeapon)
                   == .orderedSame
           }),
           psRand() % 100 < Int32(spawn.alternateChance) {
            spawnIndex = alternate
        }
        let count = spawn.count
        let position = weapon.position
            + weapon.orientation.forward * weapon.size / 2
        for child in 0..<count {
            if child == 0 {
                _ = createAndFireWeapon(
                    position: position,
                    direction: weapon.orientation.forward,
                    parent: handle,
                    weaponIndex: spawnIndex,
                    level: level
                )
            } else {
                let norm = Float(child - 1) / (Float(count) - 1)
                let angle = UInt16(truncatingIfNeeded: Int(norm * 65_536))
                let xTwist = Int(FixMath.cos(angle) * 4_096)
                let yTwist = Int(FixMath.sin(angle) * 4_096)
                let twist = sourceTransposed(FixMath.matrix(
                    p: UInt16(truncatingIfNeeded: xTwist),
                    h: UInt16(truncatingIfNeeded: yTwist),
                    b: 0
                ))
                let orientation = sourceMatrixMultiply(
                    weapon.orientation,
                    twist
                )
                _ = createAndFireWeapon(
                    position: position,
                    direction: orientation.forward,
                    parent: handle,
                    weaponIndex: spawnIndex,
                    level: level
                )
            }
        }
    }
}

/// The PF_ flags a weapon's physics reads (object_external.h:313-336).
enum WeaponPhysics {
    static let usesThrustFlag: UInt32 = 0x40
    static let gravityFlag: UInt32 = 0x80
    static let windFlag: UInt32 = 0x200
    static let ignoreOwnConcussiveForcesFlag: UInt32 = 0x100
    static let usesParentVelocityFlag: UInt32 = 0x400
    static let fixedVelocityFlag: UInt32 = 0x800
    static let hitsSiblingsFlag: UInt32 = 0x4000
    static let reverseGravityFlag: UInt32 = 0x8000
    static let noCollideFlag: UInt32 = 0x10000
    static let pointCollideWallsFlag: UInt32 = 0x40000
    static let ignoreConcussiveForcesFlag: UInt32 = 0x200000
}
