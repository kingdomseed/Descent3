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
        // IsTargetLocal (AImain.cpp:4122) assigns rather than compares
        // the rooms, so any target outside room 0 counts as local.
        let targetIsLocal = objects[ai.targetHandle] != nil
            && object.location != .room(0)
        if object.usesPhysics,
           targetIsLocal || ai.awareness >= ObjectAIFrame.awareBarely
            || ai.flags & ObjectAIFrame.persistentFlag != 0 {
            objects[handle]?.ai = ai
            var avoided = false
            // The blend goals (AImain.cpp:4614-4668).
            for index in ObjectAIFrame.activationLevels
                ..< ObjectAIFrame.maximumGoals {
                guard objects[handle]?.ai?.goals[index].used == true,
                      goalIsGoalEnabled(handle, index, level: level),
                      let goal = objects[handle]?.ai?.goals[index],
                      goal.type == AIGoal.getAroundObjectType
                else {
                    continue
                }
                goalFound = true
                guard let me = objects[handle],
                      let other = objects[goal.objectHandle],
                      other.handle != handle,
                      !objectsAreRelated(me, other)
                else {
                    continue
                }
                let distance = goal.circleDistance
                let current = max(
                    0,
                    vectorDistance(me.position, other.position)
                        - me.size - other.size
                )
                guard current <= distance else { continue }
                let scale = goal.influence * ((distance - current) / distance)
                if let away = aiGoalAvoid(me, other, distance: distance) {
                    let direction = objects[handle]!.ai!.movementDirection
                    objects[handle]?.ai?.movementDirection =
                        direction + away * scale
                    avoided = true
                    aiDetermineSpeed(objects[handle]!.ai!, flags: goal.flags,
                                     speed: &highestSpeed)
                }
            }
            if let me = objects[handle], let meAI = me.ai,
               meAI.flags & ObjectAIFrame.autoAvoidFriendsFlag != 0 {
                goalFound = true
                if avoidFriends(handle, level: level) {
                    avoided = true
                    aiDetermineSpeed(objects[handle]!.ai!, flags: 0,
                                     speed: &highestSpeed)
                }
            }
            var goalDirection = Vector3.zero
            var goalMoved = false
            var goalSet = false
            var influence: Float = 0
            if let current = goalGetCurrentGoal(handle, level: level) {
                goalFound = true
                highestInfluenceGoal = current
                turned = false
                let goal = objects[handle]!.ai!.goals[current]
                influence = goal.influence
                aiDetermineSpeed(objects[handle]!.ai!, flags: goal.flags,
                                 speed: &highestSpeed)
                let step = aiMoveCurrentGoal(handle, current, level: level)
                goalDirection = step.direction
                goalMoved = step.moved
                goalSet = step.set
            } else if !avoided, var still = objects[handle],
                      var stillAI = still.ai {
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
            if avoided || (!goalMoved && goalSet) {
                if !goalMoved, goalSet {
                    movingAI.movementDirection = movingAI.movementDirection
                        + goalDirection * influence
                }
                // vm_NormalizeVector, then a random direction when the
                // length is 0 (AImain.cpp:4980-4983). A NaN direction (a 0
                // circle distance at the goal) fails `mag > 0` and so has
                // length 0 too (vecmat/vector.cpp:175).
                var direction = movingAI.movementDirection
                if vmNormalizeVector(&direction) == 0 {
                    // vm_MakeRandomVector.
                    let half = Float(Self.randMax / 2)
                    direction = Vector3(
                        x: Float(psRand()) - half,
                        y: Float(psRand()) - half,
                        z: Float(psRand()) - half
                    )
                    vmNormalizeVector(&direction)
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

    /// The current goal's case of ai_move (AImain.cpp:4715-4990) for the
    /// translated goal types: the movement direction, whether the call
    /// already set the velocity, and whether it gave a direction.
    private mutating func aiMoveCurrentGoal(
        _ handle: ObjectHandle,
        _ index: Int,
        level: Level
    ) -> (direction: Vector3, moved: Bool, set: Bool) {
        guard var object = objects[handle], var ai = object.ai else {
            return (.zero, false, false)
        }
        let goal = ai.goals[index]
        switch goal.type {
        case Self.guardAreaGoalType:
            guard goal.statusRegister & ObjectAIFrame.circleDistanceStatus
                == 0 else {
                return (.zero, false, false)
            }
            if case let .room(room) = object.location,
               goal.roomSourceIndex != room {
                ai.goals[index].roomSourceIndex = room
                ai.goals[index].position = object.position
            }
            let result = aiMoveTowardsPosition(
                &object, &ai, position: ai.goals[index].position, scale: 1,
                stopAtEndPoint: false
            )
            object.ai = ai
            objects[handle] = object
            return (result.direction, result.moved, true)
        case AIGoal.getToObjectType, AIGoal.getToPositionType,
             AIGoal.followPathType:
            let seesGoal = goal.statusRegister
                & ObjectAIFrame.seesGoalStatus != 0
                && goal.flags & AIGoal.useBlineIfSeesGoalFlag != 0
            if ai.path.numberOfPaths > 0, !seesGoal {
                let step = aiPathMoveTurnTowardsNode(handle, level: level)
                return (step.direction, step.moved, true)
            }
            if goal.type == AIGoal.getToPositionType {
                let stops = abs(goal.circleDistance) < 0.001
                let result = aiMoveTowardsPosition(
                    &object, &ai, position: goal.position, scale: 1,
                    stopAtEndPoint: stops
                )
                object.ai = ai
                objects[handle] = object
                if result.atEnd, stops {
                    goalClearGoal(handle, index, reason: .goalComplete,
                                  level: level)
                }
                return (result.direction, result.moved, true)
            }
            if goal.type == AIGoal.getToObjectType,
               let target = objects[goal.objectHandle] {
                let result = aiMoveTowardsPosition(
                    &object, &ai, position: target.position, scale: 1,
                    stopAtEndPoint: false
                )
                object.ai = ai
                objects[handle] = object
                return (result.direction, result.moved, true)
            }
            return (.zero, false, false)
        case AIGoal.moveRelativeObjectVectorType:
            guard let target = objects[goal.objectHandle] else {
                goalClearGoal(handle, index, reason: .goalInvalid,
                              level: level)
                return (.zero, false, false)
            }
            var vectorID = goal.subtype & ~1
            let toward = goal.subtype & 1 != 0
            if ![AIGoal.forwardSubtype, AIGoal.rightSubtype,
                 AIGoal.upSubtype].contains(vectorID) {
                vectorID = AIGoal.forwardSubtype
                ai.goals[index].subtype = AIGoal.forwardSubtype
                    | (toward ? 1 : 0)
            }
            let vector = vectorID == AIGoal.rightSubtype
                ? target.orientation.right
                : vectorID == AIGoal.upSubtype
                    ? target.orientation.up : target.orientation.forward
            let result = moveRelativeObjectVector(
                &object, &ai, vector: vector, target: target,
                circleDistance: goal.circleDistance, toward: toward
            )
            object.ai = ai
            objects[handle] = object
            if result.done {
                goalClearGoal(handle, index, reason: .goalComplete,
                              level: level)
            }
            return (result.direction, result.moved, true)
        case AIGoal.moveRelativeObjectType:
            let circle = goal.circleDistance
            if ai.distToTargetPerceived < 0.7 * circle {
                // move_away_from_position (AImain.cpp:1849). The flee sound
                // needs the AI sounds (M2).
                var away = object.position - ai.lastSeeTargetPosition
                let length = sqrt(dot(away, away))
                away = length > 0 ? away / length : away
                return (away, false, true)
            }
            if goal.statusRegister & ObjectAIFrame.circleDistanceStatus != 0 {
                let time = (Int(gameTime) + handle.slot) % 8
                let relative = ai.flags & ObjectAIFrame.orientToVelocityFlag
                    != 0 ? objects[goal.objectHandle] : object
                let direction: Vector3
                if let relative {
                    direction = time < 2 ? relative.orientation.right
                        : time < 4 ? relative.orientation.right * -1
                        : time < 6 ? relative.orientation.up
                        : relative.orientation.up * -1
                } else {
                    direction = object.orientation.right
                }
                return (direction, false, true)
            }
            let result = aiMoveTowardsPosition(
                &object, &ai, position: ai.lastSeeTargetPosition, scale: 1,
                stopAtEndPoint: false
            )
            object.ai = ai
            objects[handle] = object
            return (result.direction, result.moved, true)
        default:
            return (.zero, false, false)
        }
    }

    /// move_relative_object_vec (AImain.cpp:1802): get to the side of
    /// `target` along `vector` (its negative when `toward`), at the circle
    /// distance. Done when within the object's size of that point.
    private func moveRelativeObjectVector(
        _ object: inout GameObject,
        _ ai: inout ObjectAIFrame,
        vector: Vector3,
        target: GameObject,
        circleDistance: Float,
        toward: Bool
    ) -> (direction: Vector3, moved: Bool, done: Bool) {
        let fromTarget = object.position - target.position
        let opposite = toward ? vector * -1 : vector
        var done = false
        let goalPosition: Vector3
        if dot(fromTarget, opposite) > 0 {
            let normal = opposite * dot(opposite, fromTarget)
            let plane = fromTarget - normal
            let direction = plane == .zero
                ? target.orientation.right
                : vmNormalized(plane)
            goalPosition = target.position
                + direction * (object.size + target.size + circleDistance)
        } else {
            goalPosition = target.position
                - opposite * (object.size + target.size + circleDistance)
            if vectorDistance(goalPosition, object.position) < object.size {
                done = true
            }
        }
        let result = aiMoveTowardsPosition(
            &object, &ai, position: goalPosition, scale: 1,
            stopAtEndPoint: false
        )
        return (result.direction, result.moved, done)
    }

    /// AiGoalAvoid (AImain.cpp:4075): the direction away from `other`.
    /// Each vm_NormalizeVector of a zero vector gives the x unit vector.
    private func aiGoalAvoid(_ object: GameObject, _ other: GameObject,
                             distance: Float) -> Vector3? {
        guard object.usesPhysics else { return nil }
        let otherVelocity = other.usesPhysics || other.type == .player
            ? objectVelocity(other) : .zero
        let toAvoid = other.position - object.position
        var relative = object.velocity - otherVelocity
        if abs(relative.x) < 0.1, abs(relative.y) < 0.1,
           abs(relative.z) < 0.1 {
            return vmNormalized(toAvoid * -1)
        }
        vmNormalizeVector(&relative)
        let along = dot(relative, toAvoid)
        if along <= 0 {
            return vmNormalized(toAvoid * -1)
        }
        let side = (toAvoid - relative * along) * -1
        let point = other.position + side * distance
        return vmNormalized(point - object.position)
    }

    /// ObjectsAreRelated (WeaponFire.cpp:962) for the parent links the
    /// runtime keeps.
    func objectsAreRelated(_ a: GameObject, _ b: GameObject) -> Bool {
        a.parent == b.handle || b.parent == a.handle
            || (a.parent != .none && a.parent == b.parent)
    }

    /// AIObjFriend (AImain.cpp:5606) in single player.
    func aiObjFriend(_ object: GameObject, _ target: GameObject,
                     level: Level) -> Bool {
        guard target.type == .player || target.ai != nil,
              object.type == .player || object.ai != nil,
              object.type != .ghost, object.type != .powerup,
              object.flags & GameObject.destroyedFlag == 0
        else {
            return false
        }
        if target.ai != nil, !target.usesPhysics,
           (level.placedObjectModel(target.handle)?.weaponBatteries?.count
                ?? 0) == 0 {
            return false
        }
        if object.type == .player, playerDeath != nil { return false }
        let team = aiGetTeam(object)
        let targetTeam = aiGetTeam(target)
        if target.ai?.targetHandle == object.handle { return false }
        if team == ObjectAIFrame.teamHostile { return false }
        if objectsAreRelated(object, target) { return true }
        switch team {
        case ObjectAIFrame.teamPTMC:
            return targetTeam == ObjectAIFrame.teamPTMC
        case ObjectAIFrame.teamNeutral:
            return targetTeam == ObjectAIFrame.teamNeutral
        default:
            return targetTeam == ObjectAIFrame.teamRebel
                || team == ObjectAIFrame.teamRebel || targetTeam == team
        }
    }

    /// AIF_AUTO_AVOID_FRIENDS (AImain.cpp:4670-4720): turn away from the
    /// friends within `avoid_friends_distance`. The near list is the
    /// objects in the object's room and the rooms its portals join, in slot
    /// order, at most 10 (fvi_QuickDistObjectList). Returns whether it
    /// avoided any.
    private mutating func avoidFriends(_ handle: ObjectHandle,
                                       level: Level) -> Bool {
        guard let object = objects[handle], let ai = object.ai,
              case let .room(room) = object.location
        else {
            return false
        }
        // fvi_QuickDistObjectList(pos, room, dist + size, 10, false, true)
        // (AImain.cpp:4686): players and AI objects of a type the ray
        // collides with (findintersection.cpp:2237-2239; an OBJ_DUMMY does
        // not), whose box meets the query box, in the object's room and
        // then the rooms it sees; at most 10. The object itself is in the
        // list and takes a place (:4692 skips it).
        let reach = ai.avoidFriendsDistance + object.size
        let rayCollides: Set<ObjectType> = [
            .robot, .player, .weapon, .powerup, .clutter, .building, .door,
            .room,
        ]
        let near = objects.filter { other in
            guard rayCollides.contains(other.type),
                  other.type == .player || other.ai != nil,
                  case let .room(otherRoom) = other.location,
                  otherRoom == room
                    || boaIsVisible(object.location, other.location,
                                    level: level)
            else {
                return false
            }
            let delta = other.position - object.position
            let extent = reach + other.size
            return abs(delta.x) <= extent && abs(delta.y) <= extent
                && abs(delta.z) <= extent
        }.sorted {
            ($0.location == object.location ? 0 : 1, $0.handle.slot)
                < ($1.location == object.location ? 0 : 1, $1.handle.slot)
        }.prefix(10)
        var avoided = false
        for other in near {
            guard other.type != .powerup, other.handle != handle,
                  !objectsAreRelated(object, other),
                  aiObjFriend(object, other, level: level)
            else {
                continue
            }
            let current = max(
                0,
                vectorDistance(object.position, other.position)
                    - object.size - other.size
            )
            guard current <= ai.avoidFriendsDistance,
                  let away = aiGoalAvoid(object, other,
                                         distance: ai.avoidFriendsDistance)
            else {
                continue
            }
            // `if (scale < 0.01f) scale = 0.01f;` (AImain.cpp:4704) keeps a
            // NaN, as Swift's max would not.
            var scale = 1 - current / ai.avoidFriendsDistance
            if scale < 0.01 { scale = 0.01 }
            let direction = objects[handle]!.ai!.movementDirection
            objects[handle]?.ai?.movementDirection = direction + away * scale
            avoided = true
        }
        return avoided
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
        } else if goal.isObjectGoal,
                  goal.flags & AIGoal.orientGoalObjectFlag != 0 {
            if let goalObject = objects[goal.objectHandle],
               goalObject.handle == ai.targetHandle {
                aiTurnTowardsPosition(&object, ai.lastSeeTargetPosition)
            } else if let goalObject = objects[goal.objectHandle] {
                aiTurnTowardsPosition(&object, goalObject.position)
            } else {
                aiDoOrientVelocity(&object)
            }
        } else if goal.flags & AIGoal.orientVelocityFlag != 0 {
            aiDoOrientVelocity(&object)
        } else if goal.flags & AIGoal.orientScriptedFlag != 0 {
            objects[handle] = object
            aiNotifyScriptedOrient(handle, goalIndex: goalIndex, level: level)
            return
        } else if goal.flags & AIGoal.orientPathNodeFlag != 0 {
            let path = ai.path
            // Only a static path turns the object (AImain.cpp:4443).
            guard !path.isDynamic, path.numberOfPaths > 0 else { return }
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
    /// its velocity carried through the rooms. A wall stops it. A ghosted
    /// object does not move (physics.cpp:751). A robot that meets the
    /// player on the way stops there, the pair's EVT_COLLIDE goes out
    /// (collide_two_objects), and the rest of the move goes on past the
    /// player (the ignore list, physics.cpp:1535); the bump response of the
    /// pair arrives with the general physics (M2).
    mutating func moveAIObject(_ handle: ObjectHandle, level: Level) {
        guard let start = objects[handle], start.usesPhysics,
              start.type != .dummy,
              start.velocity != .zero,
              case .room = start.location
        else {
            return
        }
        let end = start.position + start.velocity * frameDuration
        var ignored: [ObjectHandle] = []
        while var object = objects[handle], object.type != .dummy,
              case let .room(room) = object.location {
            let trace = traceIndoorMovement(
                in: level,
                roomStates: rooms,
                startRoom: room,
                start: object.position,
                end: end,
                radius: object.size
            )
            if object.type == .robot,
               let hit = nearestMoveObjectHit(
                   handle,
                   start: object.position,
                   end: trace.finalPosition,
                   radius: object.size,
                   visitedRoomSourceIndices: trace.visitedRoomSourceIndices,
                   ignored: ignored,
                   level: level
               ) {
                let move = trace.finalPosition - object.position
                let length = sqrt(dot(move, move))
                let reached = traceIndoorMovement(
                    in: level,
                    roomStates: rooms,
                    startRoom: room,
                    start: object.position,
                    end: length > 0
                        ? object.position + move * (hit.distance / length)
                        : object.position,
                    radius: object.size
                )
                object.position = reached.finalPosition
                object.location = .room(reached.containingRoomSourceIndex)
                objects[handle] = object
                ignored.append(hit.handle)
                collideTwoObjects(handle, hit.handle, level: level)
                continue
            }
            object.position = trace.finalPosition
            object.location = .room(trace.containingRoomSourceIndex)
            if case .wallHit = trace.outcome {
                object.velocity = .zero
            }
            objects[handle] = object
            break
        }
    }
}
