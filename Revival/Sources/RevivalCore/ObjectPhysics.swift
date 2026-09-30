// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from physics/physics.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): do_physics_sim (:683-1600) for the
// objects that only the generic physics moves (debris, splinters, spewed
// powerups, and dying objects that fall or fly), with PhysicsDoSimRot's
// fixed-rate rotation (:398-409) and PhysicsApplyConstantForce (:260); and
// from physics/collide.cpp, bump_obj_against_fixed (:1615) with
// ConvertEulerToAxisAmount (:1523), ConvertAxisAmountToEuler (:1569),
// CollideAnglesToMatrix (:1469), and CollideExtractAnglesFromMatrix
// (:1491).
//
// These objects hit only walls: CollisionResult has no pair for debris or
// splinters (collide.cpp:2590-2647), and a spewed powerup's contact with the
// player is the player's move. Wind, the ceiling check, volatile and lava
// surfaces, and the clutter rolling rule arrive in M2 with the terrain and
// the surfaces that use them.

import Foundation

/// `mtype.phys_info` (object_external_struct.h) of an object the generic
/// physics moves.
struct ObjectPhysics: Codable, Equatable, Sendable {
    // PF_ flags (object_external.h:313-336).
    static let bounceFlag: UInt32 = 0x04
    static let stickFlag: UInt32 = 0x10
    static let gravityFlag: UInt32 = 0x80
    static let fixedVelocityFlag: UInt32 = 0x800
    static let fixedRotationalVelocityFlag: UInt32 = 0x1000
    static let noCollideFlag: UInt32 = 0x10000
    static let pointCollideWallsFlag: UInt32 = 0x40000
    /// PHYSICS_UNLIMITED_BOUNCE (physics.h:81).
    static let unlimitedBounces: Int32 = -1

    var flags: UInt32
    var mass: Float
    var drag: Float
    /// `coeff_restitution`.
    var restitution: Float = 0
    /// `num_bounces`.
    var numberOfBounces: Int32 = unlimitedBounces
    /// `rotvel`, in angle units per second about the object's own axes.
    var rotationalVelocity = Vector3.zero
    /// MT_NONE after PF_STICK stopped the object on a wall.
    var isStopped = false
}

extension GameWorld {
    /// MAX_OBJECT_VEL (physics.cpp:77).
    static let maximumObjectVelocity: Float = 100_000
    /// MAX_NON_PLAYER_SIM_LOOPS (physics.cpp:48).
    private static let physicsSimLoops = 5

    /// do_physics_sim (physics.cpp:683) for an object with `physics`.
    mutating func movePhysicsObject(_ handle: ObjectHandle, level: Level) {
        guard let object = objects[handle],
              var physics = object.physics,
              !physics.isStopped,
              object.flags & (GameObject.deadFlag | GameObject.attachedFlag)
                == 0,
              object.type != .dummy,
              frameDuration > 0,
              case .room = object.location
        else {
            return
        }
        let gravity = physics.flags & ObjectPhysics.gravityFlag != 0
            ? Vector3(x: 0, y: level.metadata.gravity * physics.mass, z: 0)
            : .zero
        func tiny(_ v: Vector3) -> Bool {
            abs(v.x) <= 0.000_001 && abs(v.y) <= 0.000_001
                && abs(v.z) <= 0.000_001
        }
        // Nothing moves or spins, and nothing pulls: no simulation.
        if tiny(object.velocity), tiny(physics.rotationalVelocity),
           physics.flags & ObjectPhysics.gravityFlag == 0 {
            return
        }
        var force = gravity
        var remaining = frameDuration
        var passes = 0
        repeat {
            guard var moving = objects[handle],
                  case let .room(room) = moving.location
            else {
                return
            }
            let start = moving.position
            if passes > 0 {
                if physics.flags & ObjectPhysics.gravityFlag != 0 {
                    force = gravity
                } else if physics.flags & ObjectPhysics.bounceFlag != 0 {
                    force = .zero
                }
            }
            // PhysicsDoSimRot on the first pass: a fixed-rate rotater turns
            // by rotvel over the time left.
            if passes == 0,
               physics.flags & ObjectPhysics.fixedRotationalVelocityFlag != 0 {
                let turn = physics.rotationalVelocity * remaining
                moving.orientation = sourceOrthogonalized(sourceMatrixMultiply(
                    moving.orientation,
                    sourceRotationMatrix(
                        pitch: Int16(truncatingIfNeeded: Int(turn.x)),
                        yaw: Int16(truncatingIfNeeded: Int(turn.y)),
                        roll: Int16(truncatingIfNeeded: Int(turn.z))
                    )
                ))
            }
            // PhysicsDoSimLinear.
            let end: Vector3
            var endVelocity: Vector3
            if physics.flags & ObjectPhysics.fixedVelocityFlag != 0 {
                end = start + moving.velocity * remaining
                endVelocity = moving.velocity
            } else if physics.mass > Float.ulpOfOne,
                      physics.drag > Float.ulpOfOne {
                let motion = analyticLinearMotion(
                    position: start,
                    velocity: moving.velocity,
                    force: force,
                    mass: physics.mass,
                    drag: physics.drag,
                    duration: remaining
                )
                end = motion.position
                endVelocity = motion.velocity
            } else {
                end = start + moving.velocity * remaining
                    + force * (0.5 * remaining * remaining)
                endVelocity = moving.velocity + force * remaining
            }
            // PF_NO_COLLIDE: the move needs no collision response.
            if physics.flags & ObjectPhysics.noCollideFlag != 0 {
                moving.position = end
                moving.velocity = endVelocity
                moving.physics = physics
                objects[handle] = moving
                return
            }
            let radius = physics.flags & ObjectPhysics.pointCollideWallsFlag
                != 0 ? 0 : moving.size
            let trace = traceIndoorMovement(
                in: level,
                roomStates: rooms,
                startRoom: room,
                start: start,
                end: end,
                radius: radius
            )
            moving.lastPosition = start
            moving.position = trace.finalPosition
            moving.location = .room(trace.containingRoomSourceIndex)
            moving.velocity = endVelocity
            guard case let .wallHit(contact) = trace.outcome else {
                moving.physics = physics
                objects[handle] = moving
                return
            }
            let attempted = vectorDistance(start, end)
            let prior = remaining
            remaining = attempted > 0
                ? max(0, prior * (attempted - contact.distance) / attempted)
                : 0
            let movedTime = prior - remaining
            if movedTime > 0.0001 {
                moving.velocity = (trace.finalPosition - start) / movedTime
            }
            let forceField =
                surfacePhysicsBehavior(for: contact, in: level) == .forceField
            let normal = contact.normal
            var wallPart = dot(normal, moving.velocity)
            if !forceField, physics.numberOfBounces <= 0,
               physics.flags & ObjectPhysics.stickFlag != 0 {
                // PF_STICK: the object stops on the wall (MT_NONE).
                moving.velocity = .zero
                physics.isStopped = true
                moving.physics = physics
                objects[handle] = moving
                return
            } else if forceField
                || physics.flags & ObjectPhysics.bounceFlag != 0 {
                wallPart *= 2
                if !forceField,
                   physics.flags & ObjectPhysics.bounceFlag != 0,
                   physics.numberOfBounces != ObjectPhysics.unlimitedBounces {
                    if physics.numberOfBounces == 0 {
                        if moving.type != .player,
                           moving.flags & GameObject.dyingFlag != 0,
                           let dying = moving.dying {
                            moving.physics = physics
                            objects[handle] = moving
                            destroyObject(
                                handle,
                                explosionMagnitude: 50,
                                deathFlags: dying.deathFlags,
                                level: level
                            )
                            // DF_REMAINS made the object inert (MT_NONE,
                            // fireball.cpp:1405-1409); a dead object stops
                            // the loop. Either way the move ends here with
                            // the state DestroyObject left.
                            if let after = objects[handle],
                               after.physics == nil
                                || after.flags & GameObject.deadFlag != 0 {
                                return
                            }
                            guard let after = objects[handle] else { return }
                            moving = after
                        } else if moving.type != .player {
                            moving.flags |= GameObject.deadFlag
                        }
                    }
                    physics.numberOfBounces -= 1
                }
                moving.physics = physics
                if !forceField {
                    bumpObjectAgainstFixed(
                        &moving,
                        collisionPoint: contact.contactPoint,
                        normal: normal
                    )
                    if let bumped = moving.physics { physics = bumped }
                } else {
                    moving.velocity = moving.velocity - normal * wallPart
                }
            } else {
                // Slide along the wall; 1.001 keeps it off the plane.
                force = force - normal * (dot(force, normal) * 1.001)
                moving.velocity = moving.velocity
                    - normal * (wallPart * 1.001)
            }
            if !(abs(moving.velocity.x) < Self.maximumObjectVelocity
                && abs(moving.velocity.y) < Self.maximumObjectVelocity
                && abs(moving.velocity.z) < Self.maximumObjectVelocity) {
                moving.velocity = sourceVectorNormalized(moving.velocity)
                    * (Self.maximumObjectVelocity * 0.1)
            }
            moving.physics = physics
            objects[handle] = moving
            passes += 1
        } while remaining > 0 && passes < Self.physicsSimLoops
            && (objects[handle]?.flags ?? GameObject.deadFlag)
                & GameObject.deadFlag == 0
    }

    /// bump_obj_against_fixed (collide.cpp:1615): the impulse of a wall on
    /// a spinning body of the object's mass, size, and restitution.
    private func bumpObjectAgainstFixed(
        _ object: inout GameObject,
        collisionPoint: Vector3,
        normal: Vector3
    ) {
        guard var physics = object.physics, physics.mass != 0 else { return }
        let r1 = collisionPoint - object.position
        let worldRotation = vectorTimesMatrix(
            physics.rotationalVelocity,
            sourceTransposed(object.orientation)
        )
        let (axis, amount) = convertEulerToAxisAmount(worldRotation)
        let n1 = axis * amount
        let w1 = amount != 0 ? sourceVectorCross(n1, r1) : .zero
        let p1 = object.velocity + w1
        let m1: Float = physics.mass <= 0 ? 0.000_000_01 : physics.mass
        let vRel = dot(normal, p1)
        let e = physics.restitution
        var i1 = (2.0 / 5.0) * m1 * object.size * object.size
        if i1 < 0.000_000_1 { i1 = 0.000_000_1 }
        let c1 = sourceVectorCross(r1, normal) / i1
        let cv1 = dot(normal, c1)
        let j = (-(1 + e)) * vRel / (1 / m1 + cv1)
        object.velocity = object.velocity + normal * j / m1
        let jcn = normal * j
        var n2 = sourceVectorCross(r1, jcn) / i1
        let length = sqrt(dot(n2, n2))
        if length > 0 { n2 = n2 / length }
        let euler = convertAxisAmountToEuler(n2, amount: length)
        physics.rotationalVelocity = physics.rotationalVelocity
            + vectorTimesMatrix(euler, object.orientation)
        object.physics = physics
    }

    /// `v * m` (vecmat): the dot product of `v` with each row of `m`.
    private func vectorTimesMatrix(_ v: Vector3, _ m: Matrix3) -> Vector3 {
        Vector3(x: dot(v, m.right), y: dot(v, m.up), z: dot(v, m.forward))
    }

    /// ConvertEulerToAxisAmount (collide.cpp:1523).
    func convertEulerToAxisAmount(
        _ e: Vector3
    ) -> (axis: Vector3, amount: Float) {
        let rotspeed = sqrt(dot(e, e))
        let scale = rotspeed / 0.0001
        if rotspeed == 0 || scale == 0 {
            return (Vector3(x: 0, y: 1, z: 0), 0)
        }
        let en = e / scale
        let m = collideAnglesToMatrix(p: en.x, h: en.y, b: en.z)
        var n = Vector3(
            x: m.up.z - m.forward.y,
            y: m.forward.x - m.right.z,
            z: m.right.y - m.up.x
        )
        guard n != .zero else { return (n, 0) }
        n = sourceVectorNormalized(n)
        let ct = min(1, max(-1, (m.right.x + m.up.y + m.forward.z - 1) / 2))
        let z = sin(acos(ct))
        let w = rotspeed * ((2 * Float.pi) / 65_535)
        if z >= 0 { n = n * -1 }
        return (n, w)
    }

    /// ConvertAxisAmountToEuler (collide.cpp:1569).
    private func convertAxisAmountToEuler(
        _ n: Vector3,
        amount w: Float
    ) -> Vector3 {
        if w == 0 { return .zero }
        let scale = w / 0.0001
        let s = sin(Float(0.0001))
        let c = cos(Float(0.0001))
        let t = 1 - c
        let m = Matrix3(
            right: Vector3(
                x: t * n.x * n.x + c,
                y: t * n.x * n.y - s * n.z,
                z: t * n.x * n.z + s * n.y
            ),
            up: Vector3(
                x: t * n.x * n.y + s * n.z,
                y: t * n.y * n.y + c,
                z: t * n.y * n.z - s * n.x
            ),
            forward: Vector3(
                x: t * n.x * n.z - s * n.y,
                y: t * n.y * n.z + s * n.x,
                z: t * n.z * n.z + c
            )
        )
        let angles = collideExtractAngles(m)
        let units = scale * (65_535 / (2 * Float.pi))
        return angles * units
    }

    /// CollideAnglesToMatrix (collide.cpp:1469), in radians.
    private func collideAnglesToMatrix(p: Float, h: Float, b: Float) -> Matrix3 {
        let sinp = sin(p), cosp = cos(p)
        let sinb = sin(b), cosb = cos(b)
        let sinh = sin(h), cosh = cos(h)
        return Matrix3(
            right: Vector3(
                x: cosb * cosh,
                y: cosb * sinp * sinh - cosp * sinb,
                z: cosb * cosp * sinh + sinb * sinp
            ),
            up: Vector3(
                x: cosh * sinb,
                y: sinb * sinp * sinh + cosp * cosb,
                z: sinb * cosp * sinh - cosb * sinp
            ),
            forward: Vector3(x: -sinh, y: sinp * cosh, z: cosp * cosh)
        )
    }

    /// CollideExtractAnglesFromMatrix (collide.cpp:1491).
    private func collideExtractAngles(_ m: Matrix3) -> Vector3 {
        let sinh = min(1, max(-1, -m.forward.x))
        let h = asin(sinh)
        let cosh = cos(h)
        let sinp = min(1, max(-1, m.forward.y / cosh))
        let sinb = min(1, max(-1, m.up.x / cosh))
        return Vector3(x: asin(sinp), y: h, z: asin(sinb))
    }
}
