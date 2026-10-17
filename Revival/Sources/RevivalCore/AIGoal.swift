// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/AIGoal.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): GoalClearGoal (:528), GoalDoFrame
// (:606), GoalPathComplete (:834), GoalClearAll (:860), GoalAllocSlot
// (:869), GoalAddGoal (:941), GoalAddEnabler (:1230), GoalInitTypeGoals
// (:1295), GoalIsGoalEnabled (:1409), and GoalGetCurrentGoal (:1522); from
// Descent3/AImain.cpp, AIStatusCircleFrame (:4028); and from
// Descent3/osiris_predefs.cpp, osipf_AIGoalFollowPathSimple (:555).
//
// The goal types translated are AIG_FOLLOW_PATH, AIG_GET_TO_OBJ,
// AIG_GET_TO_POS, AIG_GUARD_AREA, AIG_MOVE_RELATIVE_OBJ,
// AIG_MOVE_RELATIVE_OBJ_VEC, and AIG_GET_AROUND_OBJ. The others (wander,
// dodge, melee, attach, animation, and fire goals) arrive with their ai_move
// branches in M2; GoalInitTypeGoals gives the AI types whose goals are
// among these, and only clears the goals of the others. The enablers that
// read the AIDoFreud emotions (AIE_FEAR, AIE_ANGRY, AIE_CURIOUS,
// AIE_FRUSTRATED) arrive with AIDoFreud in M2, so GoalAddEnabler refuses
// them. A path goal's "no need to update the path" probe traces the walls
// only (BOA.swift).

import Foundation

/// The argument of GoalAddGoal (the `arg_struct` of each goal type).
enum AIGoalArgument: Equatable, Sendable {
    /// AIG_FOLLOW_PATH with its `path_information`.
    case followPath(pathID: Int, nextNode: Int, startNode: Int, endNode: Int)
    /// An object handle (AIG_GET_TO_OBJ, AIG_GET_AROUND_OBJ,
    /// AIG_MOVE_RELATIVE_OBJ, and AIG_MOVE_RELATIVE_OBJ_VEC's `handle`).
    case object(ObjectHandle)
    /// A position in a room (AIG_GET_TO_POS and AIG_GUARD_AREA).
    case position(Vector3, room: Int)
}

extension GameWorld {
    /// MAX_INFLUENCE (aistruct_external.h:272).
    private static let maximumInfluence: Float = 10_000
    /// ACTIVATION_BLEND_LEVEL (aistruct_external.h:280).
    static let activationBlendLevel = 100
    /// AIG_GUARD_AREA (aistruct_external.h:192).
    static let guardAreaGoalType: UInt32 = 0x0000_0400

    /// osipf_AIGoalFollowPathSimple (osiris_predefs.cpp:555): follow game
    /// path `pathID` from its first node (its last, for
    /// GF_PATH_MOVE_REVERSE_DIR) in goal slot `slot`. Returns the goal
    /// slot, or -1.
    @discardableResult
    mutating func aiGoalFollowPathSimple(
        _ handle: ObjectHandle,
        pathID: Int,
        guid: Int32,
        flags: UInt32,
        slot: Int,
        level: Level
    ) -> Int {
        guard objects[handle]?.ai != nil,
              level.paths.indices.contains(pathID)
        else {
            return -1
        }
        let lastNode = level.paths[pathID].nodes.count - 1
        return goalAddGoal(
            handle,
            type: AIGoal.followPathType,
            .followPath(
                pathID: pathID,
                nextNode: flags & AIGoal.pathMoveReverseFlag != 0
                    ? lastNode : 0,
                startNode: 0,
                endNode: lastNode
            ),
            level: slot,
            influence: 1,
            flags: flags,
            guid: guid,
            world: level
        )
    }

    /// GoalAddGoal (AIGoal.cpp:941) for the translated goal types.
    @discardableResult
    mutating func goalAddGoal(
        _ handle: ObjectHandle,
        type: UInt32,
        _ argument: AIGoalArgument,
        level activationLevel: Int,
        influence: Float = 1,
        flags: UInt32 = 0,
        guid: Int32 = -1,
        subtype: Int8 = 0,
        world level: Level
    ) -> Int {
        let slot = goalAllocSlot(
            handle,
            level: activationLevel,
            influence: influence,
            world: level
        )
        guard slot >= 0, var ai = objects[handle]?.ai else { return -1 }
        var goal = AIGoal()
        goal.used = true
        goal.type = type
        goal.influence = influence
        goal.startTime = gameTime
        goal.flags = flags
        goal.statusRegister = 0
        goal.circleDistance = ai.circleDistance
        goal.guid = guid
        goal.creationTime = gameTime
        goal.subtype = subtype
        goal.uniqueID = aiUniqueGoalID
        aiUniqueGoalID &+= 1
        switch (type, argument) {
        case let (AIGoal.followPathType,
                  .followPath(pathID, nextNode, startNode, endNode)):
            goal.pathID = pathID
            goal.staticPathCurrentNode = nextNode
            goal.staticPathStartNode = startNode
            goal.staticPathEndNode = endNode
            goal.nextPathTime = gameTime
        case let (AIGoal.getToObjectType, .object(target)):
            if let goalObject = objects[target] {
                goal.objectHandle = target
                goal.position = goalObject.position
            } else {
                goal.objectHandle = .none
            }
            goal.nextPathTime = gameTime
        case let (AIGoal.getToPositionType, .position(position, room)):
            goal.position = position
            goal.roomSourceIndex = room
            goal.nextPathTime = gameTime
        case let (Self.guardAreaGoalType, .position(position, room)):
            goal.position = position
            goal.roomSourceIndex = room
        case let (_, .object(target)):
            // AIG_GET_AROUND_OBJ, AIG_MOVE_RELATIVE_OBJ, and
            // AIG_MOVE_RELATIVE_OBJ_VEC keep the handle.
            goal.objectHandle = target
        default:
            preconditionFailure("GoalAddGoal: argument for goal \(type)")
        }
        // The goal's circle flags (AIGoal.cpp:1195-1215).
        if goal.isObjectGoal {
            goal.flags |= AIGoal.circleObjectFlag
        } else if goal.isPositionGoal {
            goal.flags |= AIGoal.circlePositionFlag
        }
        if goal.type & AIGoal.targetOnlyGoalTypes != 0 {
            goal.flags |= AIGoal.objectIsTargetFlag
        }
        if goal.flags & AIGoal.objectIsTargetFlag != 0 {
            goal.objectHandle = ai.targetHandle
            if ai.statusRegister & ObjectAIFrame.circleDistanceStatus != 0 {
                goal.statusRegister |= ObjectAIFrame.circleDistanceStatus
            } else {
                goal.statusRegister &= ~ObjectAIFrame.circleDistanceStatus
            }
            goal.distanceToGoal = ai.distToTargetActual
        }
        ai.goals[slot] = goal
        objects[handle]?.ai = ai

        if goalGetCurrentGoal(handle, level: level) == slot,
           goal.flags & AIGoal.forceAwarenessFlag != 0,
           let awareness = objects[handle]?.ai?.awareness,
           awareness < ObjectAIFrame.awareMostly {
            objects[handle]?.ai?.awareness = ObjectAIFrame.awareMostly
        }
        return slot
    }

    /// GoalAddEnabler (AIGoal.cpp:1230). Returns the enabler index, or -1.
    /// The AIDoFreud emotion enablers arrive with AIDoFreud (M2).
    @discardableResult
    mutating func goalAddEnabler(
        _ handle: ObjectHandle,
        goalIndex: Int,
        type: UInt8,
        value: Float,
        statusFlags: UInt32 = 0,
        percent: Float,
        interval: Float
    ) -> Int {
        guard var ai = objects[handle]?.ai,
              (0..<ObjectAIFrame.maximumGoals).contains(goalIndex),
              ai.goals[goalIndex].enablers.count < AIGoal.maximumEnablers,
              ![AIGoalEnabler.fear, AIGoalEnabler.angry,
                AIGoalEnabler.curious, AIGoalEnabler.frustrated]
                .contains(type),
              (AIGoalEnabler.near...AIGoalEnabler.clearTime).contains(type)
        else {
            return -1
        }
        ai.goals[goalIndex].enablers.append(AIGoalEnabler(
            type: type,
            value: value,
            statusFlags: statusFlags,
            percent: percent,
            checkInterval: interval,
            lastCheckTime: gameTime
        ))
        objects[handle]?.ai = ai
        return ai.goals[goalIndex].enablers.count - 1
    }

    /// GoalAllocSlot (AIGoal.cpp:869): an activation level is its own slot;
    /// the blend level takes a free slot above the levels, or the weakest
    /// flushable one.
    private mutating func goalAllocSlot(
        _ handle: ObjectHandle,
        level activationLevel: Int,
        influence: Float,
        world level: Level
    ) -> Int {
        guard let ai = objects[handle]?.ai else { return -1 }
        let influence = min(max(influence, 0), Self.maximumInfluence)
        var slot: Int
        if activationLevel < ObjectAIFrame.activationLevels {
            slot = max(activationLevel, 0)
            if ai.goals[slot].used {
                if ai.goals[slot].flags & AIGoal.nonflushableFlag == 0 {
                    goalClearGoal(handle, slot, reason: nil, level: level)
                } else {
                    slot = -1
                }
            }
        } else {
            slot = ObjectAIFrame.activationLevels
            var lowestSlot = -1
            var lowestInfluence = Self.maximumInfluence + 1
            while slot < ObjectAIFrame.maximumGoals, ai.goals[slot].used {
                let goal = ai.goals[slot]
                if goal.influence < lowestInfluence,
                   goal.flags & AIGoal.nonflushableFlag == 0 {
                    lowestSlot = slot
                    lowestInfluence = goal.influence
                }
                slot += 1
            }
            if slot >= ObjectAIFrame.maximumGoals,
               lowestInfluence < influence {
                slot = lowestSlot
                goalClearGoal(handle, slot, reason: nil, level: level)
            }
        }
        guard slot >= 0, slot < ObjectAIFrame.maximumGoals else {
            return -1
        }
        objects[handle]?.ai?.goals[slot].used = true
        return slot
    }

    /// GoalClearGoal (AIGoal.cpp:528). A reason notifies the object first
    /// (AINotify); a script that reuses the slot during that call keeps its
    /// new goal (GF_IN_CLEAR).
    mutating func goalClearGoal(
        _ handle: ObjectHandle,
        _ index: Int,
        reason: AINotifyType?,
        level: Level
    ) {
        guard objects[handle]?.ai != nil else { return }
        objects[handle]!.ai!.goals[index].flags |= AIGoal.inClearFlag
        var shouldContinue = true
        if let reason {
            shouldContinue = aiNotifyGoal(handle, reason, goalIndex: index,
                                          level: level)
        }
        guard var ai = objects[handle]?.ai,
              ai.goals[index].flags & AIGoal.inClearFlag != 0
        else {
            return
        }
        ai.goals[index].flags &= ~AIGoal.inClearFlag
        objects[handle]?.ai = ai
        if reason == .goalComplete,
           ai.goals[index].flags & AIGoal.keepAtCompletionFlag != 0 {
            return
        }
        if ai.goals[index].flags & AIGoal.nonflushableFlag != 0,
           reason != nil {
            return
        }
        guard shouldContinue else { return }
        ai.goals[index].used = false
        if ai.path.goalUniqueID == ai.goals[index].uniqueID {
            ai.path.free()
        }
        objects[handle]?.ai = ai
    }

    /// GoalClearAll (AIGoal.cpp:860).
    mutating func goalClearAll(_ handle: ObjectHandle, level: Level) {
        for index in 0..<ObjectAIFrame.maximumGoals {
            goalClearGoal(handle, index, reason: nil, level: level)
        }
    }

    /// GoalInitTypeGoals (AIGoal.cpp:1295): the goals an AI type starts
    /// with. The goals of AIT_STALKER (AIG_WANDER_AROUND) and AIT_MELEE1
    /// (AIG_MELEE_TARGET) arrive with those goal types in M2.
    mutating func goalInitTypeGoals(_ handle: ObjectHandle, type: UInt8,
                                    level: Level) {
        guard let object = objects[handle], let ai = object.ai else { return }
        let aware = ObjectAIFrame.awareBarely
        let time: Float = 25
        goalClearAll(handle, level: level)
        switch type {
        case ObjectAIFrame.evader2Type:
            guard case let .room(room) = object.location else { return }
            goalAddGoal(handle, type: Self.guardAreaGoalType,
                        .position(object.position, room: room), level: 1,
                        flags: AIGoal.nonflushableFlag, world: level)
            objects[handle]?.ai?.goals[1].circleDistance = object.size * 2
            goalAddEnabler(handle, goalIndex: 1,
                           type: AIGoalEnabler.greaterAwareness,
                           value: aware, percent: 1, interval: 0)
            goalAddEnabler(handle, goalIndex: 1,
                           type: AIGoalEnabler.lessOrEqualLastSeeTargetInterval,
                           value: time, percent: 1, interval: 0)
            let index = goalAddGoal(
                handle, type: AIGoal.getAroundObjectType, .object(.none),
                level: Self.activationBlendLevel, influence: 3,
                flags: AIGoal.nonflushableFlag | AIGoal.objectIsTargetFlag,
                world: level
            )
            if index != -1 {
                goalAddEnabler(handle, goalIndex: index,
                               type: AIGoalEnabler.near,
                               value: ai.circleDistance, percent: 1,
                               interval: 0)
                objects[handle]?.ai?.goals[index].circleDistance =
                    ai.circleDistance
            }
        case ObjectAIFrame.evader1Type:
            goalAddGoal(
                handle, type: AIGoal.moveRelativeObjectType,
                .object(ai.targetHandle), level: 1,
                flags: 0xc000_0000 | AIGoal.nonflushableFlag, world: level
            )
            goalAddEnabler(handle, goalIndex: 1,
                           type: AIGoalEnabler.greaterAwareness,
                           value: aware, percent: 1, interval: 0)
            goalAddEnabler(handle, goalIndex: 1,
                           type: AIGoalEnabler.lessOrEqualLastSeeTargetInterval,
                           value: time, percent: 1, interval: 0)
            objects[handle]?.ai?.goals[1].flags |= AIGoal.objectIsTargetFlag
            if ai.circleDistance > 0 {
                let index = goalAddGoal(
                    handle, type: AIGoal.getAroundObjectType, .object(.none),
                    level: Self.activationBlendLevel, influence: 3,
                    flags: AIGoal.nonflushableFlag
                        | AIGoal.objectIsTargetFlag,
                    world: level
                )
                if index != -1 {
                    goalAddEnabler(handle, goalIndex: index,
                                   type: AIGoalEnabler.near,
                                   value: ai.circleDistance * 0.55,
                                   percent: 1, interval: 0)
                    objects[handle]?.ai?.goals[index].circleDistance =
                        ai.circleDistance * 0.55
                }
            }
        default:
            break
        }
    }

    /// GoalIsGoalEnabled (AIGoal.cpp:1409). An object goal needs its object
    /// alive and not ghosted; the enablers are and'ed.
    mutating func goalIsGoalEnabled(_ handle: ObjectHandle,
                                    _ index: Int,
                                    level: Level) -> Bool {
        guard let object = objects[handle], let ai = object.ai else {
            return false
        }
        let goal = ai.goals[index]
        if goal.isObjectGoal {
            var goalObject: GameObject?
            if goal.flags & AIGoal.objectIsTargetFlag != 0 {
                goalObject = objects[ai.targetHandle]
            } else if goal.flags & (AIGoal.objectsAreSpeciesFlag
                                    | AIGoal.objectsAreEnemiesFlag
                                    | AIGoal.objectsAreFriendsFlag) != 0 {
                goalObject = nil
            } else {
                goalObject = objects[goal.objectHandle]
            }
            guard let goalObject, goalObject.type != .ghost,
                  goalObject.flags
                    & (GameObject.dyingFlag | GameObject.destroyedFlag) == 0,
                  !(goalObject.type == .player && playerDeath != nil)
            else {
                return false
            }
        }
        for (enablerIndex, enabler) in goal.enablers.enumerated() {
            let enabled: Bool
            switch enabler.type {
            case AIGoalEnabler.aiStatusFlag:
                enabled = enabler.statusFlags & ai.statusRegister != 0
            case AIGoalEnabler.near:
                enabled = goal.distanceToGoal <= enabler.value
            case AIGoalEnabler.far:
                enabled = goal.distanceToGoal >= enabler.value
            case AIGoalEnabler.scripted:
                enabled = aiNotifyScriptedEnabler(
                    handle, goalIndex: index, enablerIndex: enablerIndex,
                    level: level
                )
            case AIGoalEnabler.greaterAwareness:
                enabled = ai.awareness > enabler.value
            case AIGoalEnabler.lessOrEqualAwareness:
                enabled = ai.awareness <= enabler.value
            case AIGoalEnabler.lessOrEqualLastSeeTargetInterval:
                enabled = gameTime - ai.lastSeeTargetTime <= enabler.value
                    || gameTime - ai.lastHearTargetTime <= enabler.value
            case AIGoalEnabler.greaterLastSeeTargetInterval:
                enabled = gameTime - ai.lastSeeTargetTime > enabler.value
                    || gameTime - ai.lastHearTargetTime > enabler.value
            case AIGoalEnabler.delayTime:
                enabled = enabler.value < gameTime - goal.creationTime
            case AIGoalEnabler.clearTime:
                enabled = enabler.value >= gameTime - goal.creationTime
                if !enabled {
                    goalClearGoal(handle, index, reason: nil, level: level)
                }
            default:
                preconditionFailure("GoalAddEnabler refuses this enabler")
            }
            if !enabled { return false }
        }
        return true
    }

    /// GoalGetCurrentGoal (AIGoal.cpp:1522): the highest used, enabled
    /// activation-level goal.
    mutating func goalGetCurrentGoal(_ handle: ObjectHandle,
                                     level: Level) -> Int? {
        for index in stride(from: ObjectAIFrame.activationLevels - 1,
                            through: 0, by: -1) {
            guard objects[handle]?.ai?.goals[index].used == true else {
                continue
            }
            if goalIsGoalEnabled(handle, index, level: level) {
                return index
            }
        }
        return nil
    }

    /// AIStatusCircleFrame (AImain.cpp:4028): sets or clears AISR_CIRCLE_DIST
    /// in `status` for a distance against a circle distance. Reaching the
    /// circle with a goal object sends AIN_NEAR_TARGET.
    mutating func aiStatusCircleFrame(
        _ handle: ObjectHandle,
        goalObject: ObjectHandle?,
        distance: Float,
        circleDistance: Float,
        status: inout UInt32,
        level: Level
    ) {
        guard let ai = objects[handle]?.ai else { return }
        let persistent = ai.flags & ObjectAIFrame.persistentFlag != 0
        if status & ObjectAIFrame.circleDistanceStatus != 0 {
            if distance > circleDistance * 1.5
                || (ai.awareness <= ObjectAIFrame.awareBarely && !persistent) {
                status &= ~ObjectAIFrame.circleDistanceStatus
            }
        } else if distance <= circleDistance + 0.1,
                  ai.awareness >= ObjectAIFrame.awareBarely || persistent {
            status |= ObjectAIFrame.circleDistanceStatus
            if let goalObject {
                aiNotifyNearTarget(handle, target: goalObject, level: level)
            }
        }
    }

    /// GoalDoFrame (AIGoal.cpp:606) for the translated goal types.
    mutating func goalDoFrame(_ handle: ObjectHandle, level: Level) {
        guard objects[handle]?.ai != nil else { return }
        let currentTask = goalGetCurrentGoal(handle, level: level)
        if let ai = objects[handle]?.ai, ai.path.numberOfPaths > 0,
           currentTask.map({ ai.goals[$0].uniqueID }) != ai.path.goalUniqueID {
            objects[handle]?.ai?.path.free()
        }
        for index in 0..<ObjectAIFrame.maximumGoals {
            guard let object = objects[handle], let ai = object.ai,
                  ai.goals[index].used
            else {
                continue
            }
            var goal = ai.goals[index]
            if goal.flags & AIGoal.clearIfNotCurrentFlag != 0,
               index != currentTask {
                goalClearGoal(handle, index, reason: nil, level: level)
                continue
            }
            if goal.flags & AIGoal.objectIsTargetFlag != 0 {
                goal.objectHandle = ai.targetHandle
                if ai.statusRegister & ObjectAIFrame.seesGoalStatus != 0 {
                    goal.statusRegister |= ObjectAIFrame.seesGoalStatus
                } else {
                    goal.statusRegister &= ~ObjectAIFrame.seesGoalStatus
                }
            } else {
                // Only target and position goals see their goal.
                goal.statusRegister &= ~ObjectAIFrame.seesGoalStatus
                if goal.isPositionGoal,
                   object.location == goal.roomSourceIndex.map({
                       SpatialLocation.room($0)
                   }) {
                    goal.statusRegister |= ObjectAIFrame.seesGoalStatus
                }
            }
            objects[handle]?.ai?.goals[index] = goal
            if goal.flags & AIGoal.circleObjectFlag != 0 {
                let goalObject = objects[goal.objectHandle]
                if goal.flags & AIGoal.objectIsTargetFlag != 0 {
                    goal.distanceToGoal = ai.distToTargetActual
                } else if let goalObject {
                    goal.distanceToGoal = max(
                        0,
                        vectorDistance(object.position, goalObject.position)
                            - object.size - goalObject.size
                    )
                }
                var status = goal.statusRegister
                if let goalObject {
                    objects[handle]?.ai?.goals[index].distanceToGoal =
                        goal.distanceToGoal
                    aiStatusCircleFrame(
                        handle,
                        goalObject: goalObject.handle,
                        distance: goal.distanceToGoal,
                        circleDistance: goal.circleDistance,
                        status: &status,
                        level: level
                    )
                } else {
                    status &= ~ObjectAIFrame.circleDistanceStatus
                }
                objects[handle]?.ai?.goals[index].distanceToGoal =
                    goal.distanceToGoal
                objects[handle]?.ai?.goals[index].statusRegister = status
            } else if goal.isPositionGoal {
                let distance = vectorDistance(object.position, goal.position)
                var status = goal.statusRegister
                objects[handle]?.ai?.goals[index].distanceToGoal = distance
                aiStatusCircleFrame(
                    handle,
                    goalObject: nil,
                    distance: distance,
                    circleDistance: goal.circleDistance,
                    status: &status,
                    level: level
                )
                objects[handle]?.ai?.goals[index].statusRegister = status
            }
        }

        guard let current = goalGetCurrentGoal(handle, level: level),
              var ai = objects[handle]?.ai
        else {
            return
        }
        let goal = ai.goals[current]
        if goal.flags & AIGoal.forceAwarenessFlag != 0,
           ai.awareness < ObjectAIFrame.awareMostly {
            ai.awareness = ObjectAIFrame.awareMostly
            objects[handle]?.ai = ai
        }
        if goal.type == AIGoal.followPathType {
            if ai.path.goalUniqueID == goal.uniqueID,
               ai.path.numberOfPaths > 0 {
                ai.goals[current].staticPathCurrentNode = ai.path.currentNode
                ai.goals[current].staticPathStartNode = ai.path.startNode
                ai.goals[current].staticPathEndNode = ai.path.endNode
                objects[handle]?.ai = ai
            } else {
                aiPathSetAsStaticPath(
                    handle,
                    goalIndex: current,
                    pathID: goal.pathID,
                    startNode: goal.staticPathStartNode,
                    endNode: goal.staticPathEndNode,
                    currentNode: goal.staticPathCurrentNode
                )
            }
        }
        let goalObject = goal.isObjectGoal ? objects[goal.objectHandle] : nil
        let atCircle =
            goal.statusRegister & ObjectAIFrame.circleDistanceStatus != 0
        if goal.type & AIGoal.completeAtObjectTypes != 0,
           goalObject != nil, atCircle {
            goalClearGoal(handle, current, reason: .goalComplete, level: level)
        } else if goal.type & AIGoal.completeAtPositionTypes != 0, atCircle {
            goalClearGoal(handle, current, reason: .goalComplete, level: level)
        } else if gameTime > goal.nextPathTime || ai.path.numberOfPaths == 0,
                  goal.type != AIGoal.followPathType {
            var makePath = false
            var killGoal = false
            var endPosition = Vector3.zero
            var endRoom: Int?
            if goal.isObjectGoal {
                if let goalObject {
                    makePath = true
                    endPosition = goalObject.position
                    if case let .room(room) = goalObject.location {
                        endRoom = room
                    }
                } else {
                    killGoal = true
                }
            } else if goal.isPositionGoal {
                makePath = true
                endPosition = goal.position
                endRoom = goal.roomSourceIndex
            }
            if makePath,
               goalPathIsCurrent(handle, end: endPosition, level: level) {
                makePath = false
            }
            if makePath, let endRoom {
                aiPathAllocPath(handle, goalIndex: current, endRoom: endRoom,
                                endPosition: endPosition, level: level)
            }
            if killGoal {
                goalClearGoal(handle, current, reason: .goalInvalid,
                              level: level)
            } else {
                let nextPathTime = gameTime + Self.minimumNextPathInterval
                    + psRandFraction()
                objects[handle]?.ai?.goals[current].nextPathTime =
                    nextPathTime
            }
        }
    }

    /// GoalDoFrame's "no need to update the path" check (AIGoal.cpp:737-765,
    /// :782-808): the path's end is within 5 units of the goal, and the
    /// object, out of the current node's room, sees that node with a
    /// quarter of its size.
    private func goalPathIsCurrent(_ handle: ObjectHandle, end: Vector3,
                                   level: Level) -> Bool {
        guard let object = objects[handle], let ai = object.ai,
              ai.path.numberOfPaths != 0,
              vectorDistance(ai.path.nodePosition(ai.path.endNode, level),
                             end) < 5,
              case let .room(room) = object.location,
              let pathRoom = ai.path.currentNodeRoom(level),
              room != pathRoom
        else {
            return false
        }
        return boaProbeIsClear(room: room, start: object.position,
                               end: ai.path.currentNodePosition(level),
                               radius: object.size / 4, level: level)
    }

    /// GoalPathComplete (AIGoal.cpp:834): a goal bound to an object that
    /// moved since the goal began paths to it again; any other goal
    /// completes.
    mutating func goalPathComplete(_ handle: ObjectHandle, level: Level) {
        guard let current = goalGetCurrentGoal(handle, level: level),
              let goal = objects[handle]?.ai?.goals[current]
        else {
            return
        }
        if goal.type & AIGoal.completeAtObjectTypes != 0 {
            if let goalObject = objects[goal.objectHandle],
               goal.position != goalObject.position {
                if case let .room(room) = goalObject.location,
                   aiPathAllocPath(handle, goalIndex: current, endRoom: room,
                                   endPosition: goalObject.position,
                                   level: level) {
                    let nextPathTime = gameTime
                        + Self.minimumNextPathInterval + psRandFraction()
                    objects[handle]?.ai?.goals[current].nextPathTime =
                        nextPathTime
                }
            } else {
                goalClearGoal(handle, current, reason: .goalComplete,
                              level: level)
            }
        } else {
            goalClearGoal(handle, current, reason: .goalComplete, level: level)
        }
    }
}
