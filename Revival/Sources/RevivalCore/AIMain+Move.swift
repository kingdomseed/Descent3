// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/AImain.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): AIMoveTowardsDir (:1707),
// AIMoveTowardsPosition (:1734), AITurnTowardsDir (:2110),
// AITurnTowardsMatrix (:2181), AIDoOrientVelocity (:4351),
// AIDoOrientDefault (:4362), AIDoOrient (:4383), AIDetermineSpeed (:4509),
// and ai_move (:4529) for the goals translated so far (AIGoal.swift); and
// from physics/physics.cpp, the move of an AI object's velocity.
//
// Scope (M1 step 6): ai_move's current-goal movement and orientation. The
// blend goals (dodge, melee, get-around), friend and wall avoidance, and
// flocking arrive with their goal types in M2. The physics move of an AI
// object keeps its velocity (AIDoFrame sets thrust to cancel drag,
// AImain.cpp:6108-6118) and stops at a wall; the wall slide response
// arrives with the general object physics in M2.

import Foundation

extension GameWorld {
    /// ONE_DEGREE_ARC_COS and FIVE_DEGREE_ARC_COS (AImain.cpp:2106).
    private static let oneDegreeArcCosine: Float = 0.999_85
    private static let fiveDegreeArcCosine: Float = 0.9962
    /// CHECK_VIS_INFREQUENTLY_TIME (AImain.cpp:1550).
    private static let inactiveStopTime: Float = 7

    /// AIDetermineSpeed (AImain.cpp:4509): the goal's GF_SPEED_ class,
    /// if faster.
    private func aiDetermineSpeed(_ ai: ObjectAIFrame, flags: UInt32,
                                  speed: inout Float) {
        var goalSpeed: Float = 1
        switch flags & AIGoal.speedMask {
        case 0xc000_0000: goalSpeed = ai.attackVelocityPercent
        case 0x4000_0000: goalSpeed = ai.dodgeVelocityPercent
        case 0x8000_0000: goalSpeed = ai.fleeVelocityPercent
        default: break
        }
        if goalSpeed > speed { speed = goalSpeed }
    }

    /// ai_move (AImain.cpp:4529) for the current goal.
    mutating func aiMove(_ handle: ObjectHandle, level: Level) {
        guard var object = objects[handle], var ai = object.ai else { return }
        ai.movementDirection = .zero
        var turned = true
        var goalFound = false
        var highestInfluenceGoal = -1
        var highestSpeed: Float = 0

        if ai.flags & ObjectAIFrame.persistentFlag == 0,
           gameTime - ai.lastSeeTargetTime > Self.inactiveStopTime,
           gameTime - ai.lastHearTargetTime > Self.inactiveStopTime,
           ai.awareness == ObjectAIFrame.awareNone {
            object.velocity = .zero
            object.ai = ai
            objects[handle] = object
            return
        }
        if object.usesPhysics,
           ai.awareness >= ObjectAIFrame.awareBarely
            || ai.flags & ObjectAIFrame.persistentFlag != 0 {
            objects[handle]?.ai = ai
            var goalDirection = Vector3.zero
            var goalMoved = false
            var goalSet = false
            var influence: Float = 0
            if let current = goalGetCurrentGoal(handle) {
                goalFound = true
                highestInfluenceGoal = current
                turned = false
                let goal = objects[handle]!.ai!.goals[current]
                influence = goal.influence
                aiDetermineSpeed(objects[handle]!.ai!, flags: goal.flags,
                                 speed: &highestSpeed)
                if goal.type == AIGoal.followPathType,
                   objects[handle]!.ai!.path.numberOfPaths > 0 {
                    let step = aiPathMoveTurnTowardsNode(handle, level: level)
                    goalDirection = step.direction
                    goalMoved = step.moved
                    goalSet = true
                }
            } else if var still = objects[handle], var stillAI = still.ai {
                let result = aiMoveTowardsPosition(
                    &still, &stillAI, position: still.position, scale: 1,
                    stopAtEndPoint: false
                )
                goalMoved = result.moved
                goalSet = true
                still.ai = stillAI
                objects[handle] = still
            }
            guard var moving = objects[handle], var movingAI = moving.ai else {
                return
            }
            if !goalMoved, goalSet {
                movingAI.movementDirection = movingAI.movementDirection
                    + goalDirection * influence
                var direction = movingAI.movementDirection
                let length = sqrt(dot(direction, direction))
                if length == 0 {
                    // vm_MakeRandomVector.
                    let half = Float(Self.randMax / 2)
                    direction = Vector3(
                        x: Float(psRand()) - half,
                        y: Float(psRand()) - half,
                        z: Float(psRand()) - half
                    )
                    let randomLength = sqrt(dot(direction, direction))
                    direction = randomLength > 0
                        ? direction / randomLength : direction
                } else {
                    direction = direction / length
                }
                movingAI.movementDirection = direction
                aiMoveTowardsDir(&moving, movingAI, direction: direction,
                                 scale: highestSpeed)
                turned = false
            }
            moving.ai = movingAI
            objects[handle] = moving
        } else {
            object.ai = ai
            objects[handle] = object
        }

        guard let final = objects[handle]?.ai else { return }
        if (!turned
            || (!goalFound
                && gameTime - final.lastSeeTargetTime < 5
                && gameTime - final.lastHearTargetTime < 5
                && final.flags & ObjectAIFrame.fireFlag != 0)),
           final.maxTurnRate > 0 {
            aiDoOrient(handle, goalIndex: highestInfluenceGoal, level: level)
        }
    }

    /// AIMoveTowardsDir (AImain.cpp:1707): accelerate toward
    /// `direction * max_velocity * scale` by at most max_delta_velocity.
    func aiMoveTowardsDir(_ object: inout GameObject, _ ai: ObjectAIFrame,
                          direction: Vector3, scale: Float) {
        let accelerationScale = scale < 1 ? 1 : scale
        let goalVelocity = direction * (ai.maxVelocity * scale)
        var difference = goalVelocity - object.velocity
        let delta = sqrt(dot(difference, difference))
        difference = delta > 0 ? difference / delta : difference
        let maximumDelta =
            frameDuration * ai.maxDeltaVelocity * accelerationScale
        if delta > maximumDelta {
            object.velocity = object.velocity + difference * maximumDelta
        } else {
            object.velocity = goalVelocity
        }
    }

    /// AIMoveTowardsPosition (AImain.cpp:1734). Returns the direction to
    /// the position, whether the call already set the velocity, and
    /// whether the object stopped at the end point.
    func aiMoveTowardsPosition(
        _ object: inout GameObject,
        _ ai: inout ObjectAIFrame,
        position: Vector3,
        scale: Float,
        stopAtEndPoint: Bool
    ) -> (direction: Vector3, moved: Bool, atEnd: Bool) {
        let accelerationScale = scale < 1 ? 1 : scale
        if stopAtEndPoint {
            if vectorDistance(position, object.position) <= 0.2 {
                object.velocity = .zero
                return (.zero, true, true)
            }
            let secondsToStop = (ai.maxVelocity * scale)
                / (ai.maxDeltaVelocity * accelerationScale)
            let distanceToStop = ai.maxVelocity * scale * secondsToStop
            var direction = position - object.position
            let distanceToTarget = sqrt(dot(direction, direction))
            direction = direction / distanceToTarget
            if distanceToTarget < distanceToStop {
                let speed = ai.maxVelocity * scale
                    * (distanceToTarget / distanceToStop)
                if distanceToTarget <= speed * frameDuration {
                    object.velocity = direction
                        * ((distanceToTarget / frameDuration) + 0.09)
                } else {
                    object.velocity = direction * (speed + 0.1)
                }
                return (direction, true, false)
            }
        }
        if position == object.position {
            if object.velocity != .zero {
                var difference = Vector3.zero - object.velocity
                let delta = sqrt(dot(difference, difference))
                difference = difference / delta
                let maximumDelta =
                    frameDuration * ai.maxDeltaVelocity * accelerationScale
                if delta > maximumDelta {
                    object.velocity = object.velocity
                        + difference * maximumDelta
                } else {
                    object.velocity = .zero
                }
            }
            return (.zero, true, false)
        }
        var direction = position - object.position
        direction = direction / sqrt(dot(direction, direction))
        return (direction, false, false)
    }

    /// AIDoOrient (AImain.cpp:4383) for the goal flags translated so far.
    private mutating func aiDoOrient(_ handle: ObjectHandle, goalIndex: Int,
                                     level: Level) {
        guard goalIndex >= 0, var object = objects[handle],
              let ai = object.ai, object.usesPhysics
        else {
            return
        }
        let goal = ai.goals[goalIndex]
        if goal.flags & AIGoal.orientTargetFlag != 0 {
            if objects[ai.targetHandle] != nil {
                aiTurnTowardsPosition(&object, ai.lastSeeTargetPosition)
            } else {
                aiDoOrientVelocity(&object)
            }
        } else if goal.flags & AIGoal.orientVelocityFlag != 0 {
            aiDoOrientVelocity(&object)
        } else if goal.flags & AIGoal.orientPathNodeFlag != 0 {
            let path = ai.path
            let reverse = goal.flags & AIGoal.pathMoveReverseFlag != 0
            let nodes = level.paths[path.pathID].nodes
            let current = path.currentNodePosition(level)
            var forward = object.orientation.forward
            var up = object.orientation.up
            let neighborNode: Int?
            let neighborPosition: Vector3?
            if reverse, !path.isAtEnd {
                neighborNode = path.currentNode + 1
                neighborPosition = path.nextNodePosition(level)
            } else if !reverse, !path.isAtStart {
                neighborNode = path.currentNode - 1
                neighborPosition = path.previousNodePosition(level)
            } else {
                neighborNode = nil
                neighborPosition = nil
            }
            if let neighborNode, let neighborPosition {
                var line = current - neighborPosition
                let lineLength = sqrt(dot(line, line))
                line = line / lineLength
                let projection = dot(object.position - neighborPosition, line)
                if projection > 0 {
                    // Past the segment: the path should have moved on.
                    if projection > lineLength { return }
                    let currentScale = projection / lineLength
                    let neighborScale = 1 - currentScale
                    forward = nodes[path.currentNode].forward * currentScale
                        + nodes[neighborNode].forward * neighborScale
                    up = nodes[path.currentNode].up * currentScale
                        + nodes[neighborNode].up * neighborScale
                }
            }
            aiTurnTowardsMatrix(
                &object,
                turnRate: ai.maxTurnRate,
                goal: sourceOrientation(forward: forward, up: up)
            )
        } else if ai.flags & ObjectAIFrame.orientToVelocityFlag != 0
                    || (ai.awareness <= ObjectAIFrame.awareBarely
                        && ai.aggression < 0.4)
                    || objects[ai.targetHandle] == nil {
            // AIDoOrientDefault (AImain.cpp:4362).
            aiDoOrientVelocity(&object)
        } else {
            aiTurnTowardsPosition(&object, ai.lastSeeTargetPosition)
        }
        objects[handle] = object
    }

    /// AIDoOrientVelocity (AImain.cpp:4351).
    private func aiDoOrientVelocity(_ object: inout GameObject) {
        let speed = sqrt(dot(object.velocity, object.velocity))
        if speed > 0.1, let ai = object.ai {
            aiTurnTowardsDir(&object, direction: object.velocity / speed,
                             turnRate: ai.maxTurnRate)
        }
    }

    /// Turning toward a point, as AIDoOrient does for its target.
    private func aiTurnTowardsPosition(_ object: inout GameObject,
                                       _ position: Vector3) {
        var toward = position - object.position
        let distance = sqrt(dot(toward, toward))
        guard distance > 0.1, let ai = object.ai else { return }
        toward = toward / distance
        aiTurnTowardsDir(&object, direction: toward, turnRate: ai.maxTurnRate)
    }

    /// AITurnTowardsDir (AImain.cpp:2110): turn the forward vector toward
    /// `direction` by at most `turnRate * Frametime` angle units. The C++
    /// passes an unset up axis to vm_DeltaAngVecNorm (:2130); Revival
    /// passes none, so the angle keeps its sign (architecture.md
    /// section 9). The turn frame is vm_VectorToMatrix of the forward
    /// vector and forward x goal (:2140-2144), with DoVectorToMatrix's
    /// fallback when that cross product is zero; the new forward vector is
    /// the frame turned max_angle about its up vector (vm_AnglesToMatrix
    /// with heading max_angle, :2150-2155).
    func aiTurnTowardsDir(_ object: inout GameObject, direction: Vector3,
                          turnRate: Float) {
        let forward = object.orientation.forward
        let cosine = dot(forward, direction)
        if direction == .zero || cosine >= Self.oneDegreeArcCosine {
            return
        }
        if object.size > 32, cosine >= Self.fiveDegreeArcCosine {
            return
        }
        // FixAcos: the angle in 1/65536 turns.
        let goalAngle = Float(Int(
            acos(max(-1, min(1, cosine))) * (65_536 / (2 * Float.pi))
        ))
        guard goalAngle != 0 else { return }
        let maximumAngle = turnRate * frameDuration
        var newForward: Vector3
        if goalAngle > maximumAngle {
            let right = maximumAngle != 32_767 && maximumAngle != 32_768
                ? vectorToMatrixRight(
                    forward: forward,
                    up: sourceVectorCross(forward, direction)
                )
                : object.orientation.right
            let radians = maximumAngle * (2 * Float.pi / 65_536)
            newForward = forward * cos(radians) + right * sin(radians)
        } else {
            newForward = direction
        }
        object.orientation = sourceOrthogonalized(Matrix3(
            right: object.orientation.right,
            up: object.orientation.up,
            forward: newForward
        ))
    }

    /// The right vector of vm_VectorToMatrix(forward, up, NULL)
    /// (DoVectorToMatrix, vecmat/vector.cpp:474-543): right = up x forward
    /// normalized, or, when the up vector is zero or parallel to forward,
    /// the right vector the forward vector alone gives (bad_vector2).
    private func vectorToMatrixRight(forward: Vector3, up: Vector3) -> Vector3 {
        sourceVectorToMatrix(forward: forward, up: up).right
    }

    private func normalizedOrZero(_ vector: Vector3) -> Vector3 {
        let length = sqrt(dot(vector, vector))
        return length > 0 ? vector / length : .zero
    }

    /// AITurnTowardsMatrix (AImain.cpp:2181): turn toward `goal` by at most
    /// `turnRate * Frametime` angle units, split over bank, heading, and
    /// pitch.
    func aiTurnTowardsMatrix(_ object: inout GameObject, turnRate: Float,
                             goal: Matrix3) {
        let maximumAngle = turnRate * frameDuration
        let relative = sourceMatrixMultiply(
            sourceTransposed(object.orientation),
            goal
        )
        let angles = sourceExtractAngles(relative)
        func distance(_ angle: Int) -> Float {
            Float(angle > 32_768 ? 65_536 - angle : angle)
        }
        let bank = distance(angles.roll)
        let heading = distance(angles.yaw)
        let pitch = distance(angles.pitch)
        let magnitude = sqrt(bank * bank + heading * heading + pitch * pitch)
        if magnitude <= maximumAngle {
            object.orientation = sourceOrthogonalized(goal)
            return
        }
        let scale = maximumAngle / magnitude
        func scaled(_ original: Int, _ distance: Float) -> Int16 {
            let value = distance * scale
            let angle = original > 32_768 ? Int(65_535 - value) : Int(value)
            return Int16(bitPattern: UInt16(truncatingIfNeeded: angle))
        }
        let increment = sourceRotationMatrix(
            pitch: scaled(angles.pitch, pitch),
            yaw: scaled(angles.yaw, heading),
            roll: scaled(angles.roll, bank)
        )
        object.orientation = sourceOrthogonalized(
            sourceMatrixMultiply(object.orientation, increment)
        )
    }

    /// The physics move of an AI object (do_physics_sim for MT_PHYSICS):
    /// its velocity carried through the rooms. A wall stops it.
    mutating func moveAIObject(_ handle: ObjectHandle, level: Level) {
        guard var object = objects[handle], object.usesPhysics,
              object.velocity != .zero,
              case let .room(room) = object.location
        else {
            return
        }
        let trace = traceIndoorMovement(
            in: level,
            roomStates: rooms,
            startRoom: room,
            start: object.position,
            end: object.position + object.velocity * frameDuration,
            radius: object.size
        )
        object.position = trace.finalPosition
        object.location = .room(trace.containingRoomSourceIndex)
        if case .wallHit = trace.outcome {
            object.velocity = .zero
        }
        objects[handle] = object
    }
}
