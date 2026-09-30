// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/AIGoal.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): GoalClearGoal (:528), GoalDoFrame
// (:606), GoalPathComplete (:834), GoalClearAll (:860), GoalAllocSlot
// (:869), GoalAddGoal (:941), GoalIsGoalEnabled (:1409), and
// GoalGetCurrentGoal (:1522); and from Descent3/osiris_predefs.cpp,
// osipf_AIGoalFollowPathSimple (:555).
//
// The goal type translated so far is AIG_FOLLOW_PATH, the one Training's
// scripts give. The other types (and their enablers, path making, and the
// per-type goals of GoalInitTypeGoals) arrive with ai_move's other branches
// in M2.

import Foundation

/// The argument of GoalAddGoal for a goal type.
enum AIGoalArgument: Equatable, Sendable {
    /// AIG_FOLLOW_PATH with its `path_information`.
    case followPath(pathID: Int, nextNode: Int, startNode: Int, endNode: Int)
}

extension GameWorld {
    /// MAX_INFLUENCE (aistruct_external.h:272).
    private static let maximumInfluence: Float = 10_000
    /// ACTIVATION_BLEND_LEVEL (aistruct_external.h:280).
    static let activationBlendLevel = 100

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

    /// GoalAddGoal (AIGoal.cpp:941).
    @discardableResult
    mutating func goalAddGoal(
        _ handle: ObjectHandle,
        _ argument: AIGoalArgument,
        level activationLevel: Int,
        influence: Float,
        flags: UInt32,
        guid: Int32,
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
        goal.influence = influence
        goal.startTime = gameTime
        goal.flags = flags
        goal.statusRegister = 0
        goal.circleDistance = ai.circleDistance
        goal.guid = guid
        goal.creationTime = gameTime
        goal.uniqueID = aiUniqueGoalID
        aiUniqueGoalID &+= 1
        switch argument {
        case let .followPath(pathID, nextNode, startNode, endNode):
            goal.type = AIGoal.followPathType
            goal.pathID = pathID
            goal.staticPathCurrentNode = nextNode
            goal.staticPathStartNode = startNode
            goal.staticPathEndNode = endNode
            goal.nextPathTime = gameTime
        }
        // A follow-path goal is neither an object, position, nor
        // target-only goal, so no GF_CIRCLE_ or GF_OBJ_IS_TARGET flag.
        ai.goals[slot] = goal
        objects[handle]?.ai = ai

        if goalGetCurrentGoal(handle) == slot,
           goal.flags & AIGoal.forceAwarenessFlag != 0,
           ai.awareness < ObjectAIFrame.awareMostly {
            objects[handle]?.ai?.awareness = ObjectAIFrame.awareMostly
        }
        return slot
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

    /// GoalGetCurrentGoal (AIGoal.cpp:1522): the highest used, enabled
    /// activation-level goal. A follow-path goal has no enablers, so
    /// GoalIsGoalEnabled (AIGoal.cpp:1409) returns true for it.
    func goalGetCurrentGoal(_ handle: ObjectHandle) -> Int? {
        guard let ai = objects[handle]?.ai else { return nil }
        for index in stride(from: ObjectAIFrame.activationLevels - 1,
                            through: 0, by: -1)
        where ai.goals[index].used {
            return index
        }
        return nil
    }

    /// GoalDoFrame (AIGoal.cpp:606) for the translated goal types.
    mutating func goalDoFrame(_ handle: ObjectHandle, level: Level) {
        guard var ai = objects[handle]?.ai else { return }
        let currentTask = goalGetCurrentGoal(handle)
        if ai.path.numberOfPaths > 0,
           currentTask.map({ ai.goals[$0].uniqueID }) != ai.path.goalUniqueID {
            ai.path.free()
            objects[handle]?.ai = ai
        }
        for index in 0..<ObjectAIFrame.maximumGoals {
            guard let goal = objects[handle]?.ai?.goals[index], goal.used
            else {
                continue
            }
            if goal.flags & AIGoal.clearIfNotCurrentFlag != 0,
               index != currentTask {
                goalClearGoal(handle, index, reason: nil, level: level)
                continue
            }
            // Only target and position goals see their goal
            // (AIGoal.cpp:637-644).
            objects[handle]?.ai?.goals[index].statusRegister &=
                ~ObjectAIFrame.seesGoalStatus
        }

        guard let current = goalGetCurrentGoal(handle),
              var updated = objects[handle]?.ai
        else {
            return
        }
        let goal = updated.goals[current]
        if goal.flags & AIGoal.forceAwarenessFlag != 0,
           updated.awareness < ObjectAIFrame.awareMostly {
            updated.awareness = ObjectAIFrame.awareMostly
            objects[handle]?.ai = updated
        }
        if goal.type == AIGoal.followPathType {
            if updated.path.goalUniqueID == goal.uniqueID,
               updated.path.numberOfPaths > 0 {
                updated.goals[current].staticPathCurrentNode =
                    updated.path.currentNode
                updated.goals[current].staticPathStartNode =
                    updated.path.startNode
                updated.goals[current].staticPathEndNode = updated.path.endNode
                objects[handle]?.ai = updated
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
    }

    /// GoalPathComplete (AIGoal.cpp:834): a path goal that is not bound to
    /// an object completes.
    mutating func goalPathComplete(_ handle: ObjectHandle, level: Level) {
        guard let current = goalGetCurrentGoal(handle) else { return }
        goalClearGoal(handle, current, reason: .goalComplete, level: level)
    }
}
