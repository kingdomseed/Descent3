// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from physics/collide.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): the CollisionResult table that
// CollideInit (:2585) fills, and collide_two_objects (:2393) with its
// script hook (:2474-2497); from physics/findintersection.cpp, the
// object check of fvi_rooms_objs (:3325-3590): sphere against sphere
// (check_vector_to_object :1747, check_vector_to_sphere_1 :1174) and sphere
// against a polygon model (PolyCollide.swift). The physics loop that calls
// them for an object hit is do_physics_sim (physics/physics.cpp:1503-1560).
//
// The translated pairs are the ones whose collision response exists: the
// player and a powerup (ENABLE_COLLISION_SPHERE_SPHERE, :2624), whose
// response is the script alone (NO_COLLISION(OBJ_PLAYER, OBJ_POWERUP),
// :2519), and the player and a weapon (:2623), whose response is
// collide_player_and_weapon (WeaponFire.swift). The other pairs (robots,
// clutter, doors) bump or damage; they join this table with Damage and the
// general object frame (M1 step 7, M2).

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
    case (.player, .weapon):
        .polySphere     // ENABLE_COLLISION_POLY_SPHERE, collide.cpp:2623
    case (.weapon, .player):
        .spherePoly     // collide.cpp:2623 (ENABLE_COLLISION_POLY_SPHERE)
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
    /// collide_two_objects (collide.cpp:2393) in single player. The level
    /// goal informs (check_lg_inform, :2410) need object flags that no
    /// imported object sets yet. The dying or dead player check (:2476)
    /// arrives with player death (M1 step 7). Each object's script chain
    /// gets EVT_COLLIDE, and then the pair's response runs: for the player
    /// and a powerup there is none (:2519); for the player and a weapon it
    /// is collide_player_and_weapon (:2500).
    mutating func collideTwoObjects(
        _ a: ObjectHandle,
        _ b: ObjectHandle,
        level: Level
    ) {
        for call in collideScriptEvents(a, b) {
            osirisCallEvent(call.me, call.event, level: level)
        }
        switch (objects[a]?.type, objects[b]?.type) {
        case (.player, .weapon):
            collidePlayerAndWeapon(player: a, weapon: b, level: level)
        case (.weapon, .player):
            collidePlayerAndWeapon(player: b, weapon: a, level: level)
        default:
            break
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
    ) -> (handle: ObjectHandle, distance: Float)? {
        guard let moving = objects[mover],
              moving.flags & GameObject.noObjectCollisionsFlag == 0
        else {
            return nil
        }
        var nearest: (handle: ObjectHandle, distance: Float)?
        for object in objects where object.handle != mover {
            guard !ignored.contains(object.handle),
                  object.flags & GameObject.noObjectCollisionsFlag == 0,
                  object.flags & GameObject.deadFlag == 0,
                  case let .room(room) = object.location,
                  visitedRoomSourceIndices.contains(room)
            else {
                continue
            }
            let distance: Float?
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
                distance = level.polygonModel(of: moving).flatMap {
                    polyCollideObject(
                        model: $0,
                        position: start,
                        orientation: moving.orientation,
                        p0: object.position,
                        p1: object.position + (start - end),
                        radius: object.size
                    )?.distance
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
            nearest = (object.handle, distance)
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
        return placedObjectModel(object.handle)
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
