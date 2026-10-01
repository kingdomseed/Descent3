// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from physics/collide.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): the CollisionResult table that
// CollideInit (:2585) fills, collide_two_objects (:2393) with its script
// hook (:2474-2497), collide_generic_and_weapon (:2155), and
// collide_player_and_weapon (:2280); from physics/findintersection.cpp, the
// object check of fvi_rooms_objs (:3325-3590): sphere against sphere
// (check_vector_to_object :1747, check_vector_to_sphere_1 :1174) and sphere
// against a polygon model (PolyCollide.swift). The physics loop that calls
// them for an object hit is do_physics_sim (physics/physics.cpp:1503-1560).
//
// The translated pairs are the ones whose collision response exists: the
// player and a powerup (ENABLE_COLLISION_SPHERE_SPHERE, :2624), whose
// response is the script alone (NO_COLLISION(OBJ_PLAYER, OBJ_POWERUP),
// :2519); the player and a weapon (:2623); and a robot, clutter, or
// building and a weapon (:2621, :2626, :2632), where a PF_STICK weapon
// sticks to the object it hit (MakeWeaponStick, :2146). The other pairs
// (the player and robots, weapons and weapons, doors) bump, and they arrive
// with the general physics and doors (M2). bump_two_objects, the weapon's
// impact spawns, and the building surface effects arrive with them.

import Foundation

/// The collision check CollisionResult names for a pair of object types.
enum CollisionCheck: Equatable, Sendable {
    /// RESULT_NOTHING.
    case nothing
    /// RESULT_CHECK_SPHERE_SPHERE.
    case sphereSphere
    /// RESULT_CHECK_SPHERE_POLY: the mover's sphere against the other
    /// object's polygon model.
    case spherePoly
    /// RESULT_CHECK_POLY_SPHERE: the other object's sphere, moving
    /// against the mover, on the mover's polygon model.
    case polySphere
}

/// CollisionResult[a][b] (collide.cpp:2585 CollideInit) for the translated
/// pairs.
func collisionResult(_ a: ObjectType, _ b: ObjectType) -> CollisionCheck {
    switch (a, b) {
    case (.player, .powerup), (.powerup, .player):
        .sphereSphere   // collide.cpp:2624
    case (.robot, .player):
        // ENABLE_COLLISION_POLY_SPHERE(OBJ_ROBOT, OBJ_PLAYER),
        // collide.cpp:2619: a robot's move against the player.
        .polySphere
    case (.player, .robot):
        // Its mirror (the macro sets both, collide.cpp:2549): the player's
        // move against a robot's model. The bump response arrives in M2.
        .spherePoly
    case (.player, .weapon), (.robot, .weapon), (.clutter, .weapon),
         (.building, .weapon):
        // ENABLE_COLLISION_POLY_SPHERE(OBJ_PLAYER/OBJ_ROBOT, OBJ_WEAPON),
        // collide.cpp:2621-2623; ENABLE_COLLISION_SPHERE_POLY(OBJ_WEAPON,
        // OBJ_CLUTTER/OBJ_BUILDING), :2626, :2632.
        .polySphere
    case (.weapon, .player), (.weapon, .robot), (.weapon, .clutter),
         (.weapon, .building):
        .spherePoly
    default:
        .nothing
    }
}

/// The EVT_COLLIDE calls of collide_two_objects (collide.cpp:2488-2496), in
/// order: `a` gets the event with `it` = `b`, then `b` gets it with `it` =
/// `a`.
func collideScriptEvents(
    _ a: ObjectHandle,
    _ b: ObjectHandle
) -> [(me: ObjectHandle, event: ScriptEvent)] {
    [(a, .collide(it: b)), (b, .collide(it: a))]
}

extension GameWorld {
    /// collide_two_objects (collide.cpp:2393) in single player: the level
    /// goal informs (check_lg_inform, :2410), then each object's script
    /// chain gets EVT_COLLIDE, and then the pair's response runs. The dying
    /// or dead player check (:2476) arrives with player death (M2).
    /// `link` is the submodel frame of a weapon's polygon hit
    /// (`hit_info`), which a sticking weapon keeps; without it a sticking
    /// weapon dies like any other.
    mutating func collideTwoObjects(
        _ a: ObjectHandle,
        _ b: ObjectHandle,
        link: ObjectLinkInfo? = nil,
        level: Level
    ) {
        checkLevelGoalInform(a, b, level: level)
        checkLevelGoalInform(b, a, level: level)
        for call in collideScriptEvents(a, b) {
            osirisCallEvent(call.me, call.event, level: level)
        }
        switch (objects[a]?.type, objects[b]?.type) {
        case (.player, .weapon):
            collidePlayerAndWeapon(player: a, weapon: b, link: link,
                                   level: level)
        case (.weapon, .player):
            collidePlayerAndWeapon(player: b, weapon: a, link: link,
                                   level: level)
        case (.robot, .weapon), (.clutter, .weapon), (.building, .weapon):
            collideGenericAndWeapon(a, weapon: b, link: link, level: level)
        case (.weapon, .robot), (.weapon, .clutter), (.weapon, .building):
            collideGenericAndWeapon(b, weapon: a, link: link, level: level)
        default:
            break
        }
    }

    /// The end of a non-electrical weapon's object hit
    /// (collide.cpp:2269-2276, :2335-2341): a PF_STICK weapon with a polygon
    /// hit sticks (MakeWeaponStick, :2146: MT_OBJ_LINKED to the hit
    /// object's submodel); any other weapon dies. A PF_PERSISTENT weapon,
    /// which lives on, arrives with the weapons that use it (M2).
    private mutating func endWeaponObjectHit(
        _ handle: ObjectHandle,
        link: ObjectLinkInfo?,
        level: Level
    ) {
        guard let weaponIndex = objects[handle]?.weapon else { return }
        let sticks = level.weapons![weaponIndex].physicsFlags
            & ObjectPhysics.stickFlag != 0
        if sticks, let link {
            objects[handle]?.objectLink = link
            objects[handle]?.usesPhysics = false
        } else {
            objects[handle]?.flags |= GameObject.deadFlag
        }
    }

    /// collide_player_and_weapon (collide.cpp:2280): the firing AI object
    /// learns it hit, the weapon explodes, the player takes the weapon's
    /// damage, and the weapon dies or sticks.
    mutating func collidePlayerAndWeapon(
        player: ObjectHandle,
        weapon handle: ObjectHandle,
        link: ObjectLinkInfo? = nil,
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
        doWeaponExploded(handle, hitObject: player, level: level)
        let electrical =
            definition.flags & CanonicalWeapon.electricalFlag != 0
        let damage = electrical
            ? definition.playerDamage * frameDuration
            : definition.playerDamage
        if applyDamageToPlayer(
            player,
            killer: handle,
            damage: damage,
            level: level
        ) {
            play3DSound(definition.sounds[CanonicalWeapon.impactRobotSound])
        }
        if !electrical {
            endWeaponObjectHit(handle, link: link, level: level)
        }
    }

    /// collide_generic_and_weapon (collide.cpp:2155): a dying object dies a
    /// little sooner, the weapon's wall impact sound plays and it explodes,
    /// the firer and the hit AI object hear of it, and the object takes the
    /// weapon's generic damage. A damaging energy or matter hit throws 3 to
    /// 8 sparks in the weapon's secondary light color. The weapon dies or
    /// sticks.
    mutating func collideGenericAndWeapon(
        _ hit: ObjectHandle,
        weapon handle: ObjectHandle,
        link: ObjectLinkInfo? = nil,
        level: Level
    ) {
        guard let weapon = objects[handle],
              let weaponIndex = weapon.weapon
        else {
            return
        }
        let definition = level.weapons![weaponIndex]
        let electrical =
            definition.flags & CanonicalWeapon.electricalFlag != 0
        let damageType: GenericDamageType =
            definition.flags & CanonicalWeapon.napalmFlag != 0 ? .fire
            : definition.flags & CanonicalWeapon.matterWeaponFlag != 0
                ? .matter
            : electrical ? .electric : .energy
        if (objects[hit]?.flags ?? 0) & GameObject.dyingFlag != 0 {
            objects[hit]?.dying?.delayTime *= 0.975
        }
        // The AIN_HEAR_NOISE of the impact sound arrives with AI hearing
        // (M2).
        play3DSound(definition.sounds[CanonicalWeapon.impactWallSound])
        doWeaponExploded(handle, hitObject: hit, level: level)
        if objects[weapon.parent]?.ai != nil {
            aiNotifyWeaponHitObject(weapon.parent, target: hit, level: level)
        }
        if objects[hit]?.ai != nil {
            aiNotifyHitByWeapon(hit, weapon: handle, level: level)
        }
        let damage = electrical
            ? definition.genericDamage * frameDuration
            : definition.genericDamage
        if applyDamageToGeneric(
            hit,
            killer: handle,
            damageType: damageType,
            damage: damage,
            level: level
        ) {
            play3DSound(definition.sounds[CanonicalWeapon.impactRobotSound])
            if !electrical, let weapon = objects[handle],
               case let .room(room) = weapon.location {
                let light = definition.lighting?.secondaryColor ?? .zero
                let color = sourceRGB16(
                    light.x * 255, light.y * 255, light.z * 255
                )
                let count = 3 + Int(psRand() % 6)
                createRandomLineSparks(
                    count,
                    position: weapon.position,
                    roomSourceIndex: room,
                    color: color,
                    level: level
                )
            }
        }
        if !electrical {
            endWeaponObjectHit(handle, link: link, level: level)
        }
    }

    /// The object hit of one fvi_FindIntersection call of the player's
    /// physics loop (physics.cpp:986, FQ_CHECK_OBJS): the nearest object
    /// the move from `start` to `end` touches, skipping the objects already
    /// hit this frame (`ignored`, the loop's ignore_obj_list), or `nil`. A
    /// mover with OF_NO_OBJECT_COLLISIONS checks no objects: the loop clears
    /// FQ_CHECK_OBJS for it (physics.cpp:1012). A tie goes to the lower
    /// slot, the order fvi visits objects in.
    func nearestMoveObjectHit(
        _ mover: ObjectHandle,
        start: Vector3,
        end: Vector3,
        radius: Float,
        visitedRoomSourceIndices: [Int],
        ignored: [ObjectHandle],
        level: Level
    ) -> (handle: ObjectHandle, distance: Float, link: ObjectLinkInfo?)? {
        guard let moving = objects[mover],
              moving.flags & GameObject.noObjectCollisionsFlag == 0
        else {
            return nil
        }
        var nearest: (handle: ObjectHandle, distance: Float,
                      link: ObjectLinkInfo?)?
        for object in objects where object.handle != mover {
            guard !ignored.contains(object.handle),
                  // fvi skips related objects (findintersection.cpp:3364).
                  !objectsAreRelated(moving, object, level: level),
                  object.flags & GameObject.noObjectCollisionsFlag == 0,
                  object.flags & GameObject.deadFlag == 0,
                  case let .room(room) = object.location,
                  visitedRoomSourceIndices.contains(room)
            else {
                continue
            }
            let distance: Float?
            var link: ObjectLinkInfo?
            switch collisionResult(moving.type, object.type) {
            case .nothing:
                continue
            case .sphereSphere:
                distance = checkVectorToSphere(
                    start: start,
                    end: end,
                    center: object.position,
                    radius: object.size + radius
                )
            case .polySphere:
                // The other object's sphere moves against the mover by the
                // mover's move, on the mover's model at its start
                // (findintersection.cpp:3487-3510).
                let hit = level.polygonModel(of: moving).flatMap {
                    polyCollideObject(
                        model: $0,
                        position: start,
                        orientation: moving.orientation,
                        p0: object.position,
                        p1: object.position + (start - end),
                        radius: object.size
                    )
                }
                distance = hit?.distance
                // A weapon the move touched keeps the submodel of the
                // mover's model it touched and its place there, for
                // MakeWeaponStick (collide.cpp:2146, :2335). The C++ leaves
                // hit_subobj_pos and the heading unset when the mover is not
                // a weapon (newstyle_fi.cpp:216); the weapon's own place and
                // heading in that frame stand for them.
                if let hit, object.type == .weapon {
                    link = ObjectLinkInfo(
                        parentHandle: mover,
                        submodel: hit.submodel,
                        position: hit.submodelIntersection,
                        forward: inverseTransform(
                            object.orientation.forward,
                            by: moving.orientation
                        ),
                        up: inverseTransform(
                            object.orientation.up,
                            by: moving.orientation
                        )
                    )
                }
            case .spherePoly:
                distance = level.polygonModel(of: object).flatMap {
                    polyCollideObject(
                        model: $0,
                        position: object.position,
                        orientation: object.orientation,
                        p0: start,
                        p1: end,
                        radius: radius
                    )?.distance
                }
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
}

/// check_vector_to_sphere_1 (physics/findintersection.cpp:1174) with
/// f_correcting false and f_init_collisions true, as check_vector_to_object
/// (:1747) calls it for a powerup: the distance along the move at which a
/// sphere of `radius` around the moving point touches `center`, or `nil`.
/// A move away from the center (or no move) never hits. A start inside the
/// sphere hits at distance 0.
func checkVectorToSphere(
    start: Vector3,
    end: Vector3,
    center: Vector3,
    radius: Float
) -> Float? {
    guard radius > 0 else { return nil }
    let line = end - start
    let toCenter = center - start
    guard dot(line, toCenter) > 0 else { return nil }
    let length = sqrt(dot(line, line))
    let direction = line / length
    let closestDistance = dot(direction, toCenter)
    guard closestDistance >= 0, closestDistance < length + radius else {
        return nil
    }
    if dot(toCenter, toCenter) < radius * radius {
        return 0
    }
    let closest = start + direction * closestDistance
    let closestToCenter = vectorDistance(closest, center)
    guard closestToCenter < radius else { return nil }
    let shorten = sqrt(radius * radius - closestToCenter * closestToCenter)
    let distance = closestDistance - shorten
    return distance > length ? nil : distance
}

extension Level {
    /// The polygon model an object collides with: the player ship's model
    /// for the player, the placed presentation's primary model otherwise.
    func polygonModel(of object: GameObject) -> CanonicalModel? {
        if object.type == .player,
           let binding = defaultPlayerBinding,
           object.handle.rawValue == binding.objectHandle {
            guard let ship = shipDefinitions.first(where: {
                $0.source == binding.ship
            }) else {
                return nil
            }
            return models.first { $0.source == ship.primaryModel }
        }
        guard let presentation = objectPresentation(of: object) else {
            return nil
        }
        return models.first { $0.source == presentation.primaryModel }
    }

    /// The `size` ObjInit gives a placed object from its polymodel
    /// (`sourceObjectPresentationSize`), or `nil` for an object with no
    /// model.
    func placedObjectSize(_ handle: ObjectHandle) -> Float? {
        guard let placed = objects.first(where: {
                  $0.handle == handle.rawValue
              }),
              let presentation = objectPresentations.first(where: {
                  $0.objectHandle == handle.rawValue
              }),
              let model = models.first(where: {
                  $0.source == presentation.primaryModel
              })
        else {
            return nil
        }
        return sourceObjectPresentationSize(
            model: model,
            objectType: placed.type
        )
    }
}
