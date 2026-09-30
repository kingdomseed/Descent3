// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/aipath.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): AIPathGetCurrentNodePos (:201),
// AIPathMoveToNextNode (:232), AIPathAtStart (:256), AIPathAtEnd (:263),
// AIPathSetAtEnd (:270), AIPathSetAtStart (:275), AIPathMoveToPrevNode
// (:280), AIPathGetNextNodePos (:308), AIPathGetPrevNodePos (:319),
// AIPathMoveTurnTowardsNode (:332), AIPathInitPath (:537), AIPathFreePath
// (:550), AIPathAddDPath (:564), AIPathAddStaticPath (:590),
// AIPathAddDPathNode (:608), AIPathAllocPath (:977), and
// AIPathSetAsStaticPath (:1126).
//
// A path holds one static game path (AIP_STATIC) or one dynamic path. The
// dynamic path's route comes from BOA.swift: it follows the reciprocal
// portals, not the cached CBOA and BNode tables (architecture.md section 9).
// Walking movement arrives in M2.

import Foundation

extension AIPathInfo {
    /// AIPathInitPath and AIPathFreePath (aipath.cpp:537, :550).
    mutating func free() {
        numberOfPaths = 0
        currentNode = 0
        goalIndex = -1
        goalUniqueID = -1
        dynamicNodes = []
    }

    /// AIPathAtStart (aipath.cpp:256).
    var isAtStart: Bool { currentNode == startNode }

    /// AIPathAtEnd (aipath.cpp:263).
    var isAtEnd: Bool { currentNode == endNode }

    /// AIPathMoveToNextNode (aipath.cpp:232).
    @discardableResult
    mutating func moveToNextNode() -> Bool {
        guard currentNode + 1 <= endNode else { return false }
        currentNode += 1
        return true
    }

    /// AIPathMoveToPrevNode (aipath.cpp:280). A single static path never
    /// steps back past node 0.
    @discardableResult
    mutating func moveToPreviousNode() -> Bool {
        guard currentNode - 1 >= 0 else { return false }
        currentNode -= 1
        return true
    }

    /// The position of node `node` of the path.
    func nodePosition(_ node: Int, _ level: Level) -> Vector3 {
        isDynamic
            ? dynamicNodes[node].position
            : level.paths[pathID].nodes[node].position
    }

    /// AIPathGetCurrentNodePos (aipath.cpp:201).
    func currentNodePosition(_ level: Level) -> Vector3 {
        nodePosition(currentNode, level)
    }

    /// The room of the current node (AIPathGetCurrentNodePos's `room`).
    func currentNodeRoom(_ level: Level) -> Int? {
        if isDynamic { return dynamicNodes[currentNode].roomSourceIndex }
        guard case let .room(room) =
            level.paths[pathID].nodes[currentNode].location
        else {
            return nil
        }
        return room
    }

    /// AIPathGetNextNodePos (aipath.cpp:308).
    func nextNodePosition(_ level: Level) -> Vector3? {
        var probe = self
        guard probe.moveToNextNode() else { return nil }
        return probe.currentNodePosition(level)
    }

    /// AIPathGetPrevNodePos (aipath.cpp:319).
    func previousNodePosition(_ level: Level) -> Vector3? {
        var probe = self
        guard probe.moveToPreviousNode() else { return nil }
        return probe.currentNodePosition(level)
    }
}

extension GameWorld {
    /// AIPathSetAsStaticPath (aipath.cpp:1126): the object's path becomes
    /// game path `pathID` between the two nodes, at `currentNode`, owned by
    /// goal `goalIndex`.
    mutating func aiPathSetAsStaticPath(
        _ handle: ObjectHandle,
        goalIndex: Int,
        pathID: Int,
        startNode: Int,
        endNode: Int,
        currentNode: Int
    ) {
        guard var ai = objects[handle]?.ai else { return }
        ai.path.free()
        ai.path.goalIndex = goalIndex
        ai.path.goalUniqueID = ai.goals[goalIndex].uniqueID
        // AIPathAddStaticPath (aipath.cpp:590).
        ai.path.pathID = pathID
        ai.path.startNode = startNode
        ai.path.endNode = endNode
        ai.path.numberOfPaths = 1
        ai.path.currentNode = currentNode
        objects[handle]?.ai = ai
    }

    /// AIPathMoveTurnTowardsNode (aipath.cpp:332): the direction to the
    /// current node, and the node passing that moves the path on. At the
    /// end of the path the goal circles, reverses, or completes
    /// (GoalPathComplete). Returns the movement direction and whether the
    /// object already moved.
    mutating func aiPathMoveTurnTowardsNode(
        _ handle: ObjectHandle,
        level: Level
    ) -> (direction: Vector3, moved: Bool) {
        guard var object = objects[handle], var ai = object.ai else {
            return (.zero, false)
        }
        let goalIndex = ai.path.goalIndex
        var goal = ai.goals[goalIndex]
        var reverse = goal.flags & AIGoal.pathMoveReverseFlag != 0
        var currentPosition = ai.path.currentNodePosition(level)
        var direction = Vector3.zero
        var moved = false
        var tooFarFromEnd = false
        var forceCompleteStopping = false

        if ((!reverse && ai.path.isAtEnd) || (reverse && ai.path.isAtStart)),
           goal.circleDistance == 0, object.usesPhysics {
            let result = aiMoveTowardsPosition(
                &object, &ai, position: currentPosition, scale: 1,
                stopAtEndPoint: true
            )
            direction = result.direction
            moved = result.moved
            tooFarFromEnd = !result.atEnd
            if !tooFarFromEnd {
                forceCompleteStopping = true
            }
        } else {
            let toNode = currentPosition - object.position
            let length = sqrt(dot(toNode, toNode))
            direction = length > 0 ? toNode / length : .zero
            moved = false
        }

        while true {
            let lastNode = ai.path.currentNode
            var passNode = forceCompleteStopping
            if !passNode {
                if !reverse {
                    if ai.path.isAtStart {
                        if ai.path.isAtEnd {
                            if dot(object.position - currentPosition,
                                   object.lastPosition - currentPosition) <= 0,
                               !tooFarFromEnd {
                                passNode = true
                            }
                        } else if let next = ai.path.nextNodePosition(level),
                                  dot(object.position - currentPosition,
                                      next - currentPosition) >= 0 {
                            passNode = true
                        }
                    } else if let previous =
                                ai.path.previousNodePosition(level) {
                        var line = currentPosition - previous
                        let lineLength = sqrt(dot(line, line))
                        line = lineLength > 0 ? line / lineLength : line
                        if dot(object.position - previous, line)
                            >= lineLength {
                            passNode = true
                        }
                    }
                } else {
                    if ai.path.isAtEnd {
                        if ai.path.isAtStart {
                            if dot(object.position - currentPosition,
                                   object.lastPosition - currentPosition) <= 0,
                               !tooFarFromEnd {
                                passNode = true
                            }
                        } else if let previous =
                                    ai.path.previousNodePosition(level),
                                  dot(object.position - currentPosition,
                                      previous - currentPosition) >= 0 {
                            passNode = true
                        }
                    } else if let next = ai.path.nextNodePosition(level) {
                        var line = currentPosition - next
                        let lineLength = sqrt(dot(line, line))
                        line = lineLength > 0 ? line / lineLength : line
                        if dot(object.position - next, line) >= lineLength {
                            passNode = true
                        }
                    }
                }
            }
            guard passNode else { break }

            if (reverse && ai.path.isAtStart) || (!reverse && ai.path.isAtEnd) {
                switch goal.flags & AIGoal.endOfPathMask {
                case AIGoal.pathReverseAtEndFlag:
                    if reverse {
                        goal.flags &= ~AIGoal.pathMoveReverseFlag
                    } else {
                        goal.flags |= AIGoal.pathMoveReverseFlag
                    }
                    ai.goals[goalIndex] = goal
                    object.ai = ai
                    objects[handle] = object
                case AIGoal.pathCircleAtEndFlag:
                    if reverse {
                        ai.path.currentNode = ai.path.endNode
                    } else {
                        ai.path.currentNode = ai.path.startNode
                    }
                    object.ai = ai
                    objects[handle] = object
                default:
                    object.ai = ai
                    objects[handle] = object
                    // AIPathComplete (aipath.cpp:330) → GoalPathComplete.
                    goalPathComplete(handle, level: level)
                }
                return (direction, moved)
            }
            if goal.flags & AIGoal.pathMoveReverseFlag != 0 {
                ai.path.moveToPreviousNode()
            } else {
                ai.path.moveToNextNode()
            }
            currentPosition = ai.path.currentNodePosition(level)
            reverse = goal.flags & AIGoal.pathMoveReverseFlag != 0
            guard ai.path.currentNode != lastNode else { break }
        }
        object.ai = ai
        objects[handle] = object
        return (direction, moved)
    }

    /// MIN_NEXT_PATH_INTERVAL (aistruct_external.h:338).
    static let minimumNextPathInterval: Float = 2

    /// AIPathAllocPath (aipath.cpp:977): a dynamic path for goal
    /// `goalIndex` from the object's position to `endPosition` in
    /// `endRoom`. When BOA finds no room route the path is freed and the
    /// call fails. A clear straight line (the size probe, fq.rad =
    /// size - 0.1) makes a path of the end point only; otherwise the route
    /// of `boaRoute` (BOA.swift) leads to it. Returns whether a path was
    /// made.
    @discardableResult
    mutating func aiPathAllocPath(
        _ handle: ObjectHandle,
        goalIndex: Int,
        endRoom: Int,
        endPosition: Vector3,
        level: Level
    ) -> Bool {
        guard var object = objects[handle], var ai = object.ai,
              case let .room(startRoom) = object.location
        else {
            return false
        }
        ai.path.free()
        ai.path.goalIndex = goalIndex
        ai.path.goalUniqueID = ai.goals[goalIndex].uniqueID
        guard boaRoomRoute(from: startRoom, to: endRoom, level: level) != nil
        else {
            ai.path.free()
            object.ai = ai
            objects[handle] = object
            return false
        }
        let speed = sqrt(dot(object.velocity, object.velocity))
        let startForward = speed > 0
            ? object.velocity / speed
            : object.orientation.forward
        guard let route = boaRoute(
            startRoom: startRoom,
            start: object.position,
            startForward: startForward,
            endRoom: endRoom,
            end: endPosition,
            radius: max(0.1, object.size - 0.1),
            level: level
        ) else {
            ai.path.free()
            object.ai = ai
            objects[handle] = object
            return false
        }
        // AIPathAddDPath, then AIPathAddDPathNode for each node and the end
        // point.
        ai.path.dynamicNodes = route + [
            AIPathNode(position: endPosition, roomSourceIndex: endRoom),
        ]
        ai.path.numberOfPaths = 1
        ai.path.startNode = 0
        ai.path.endNode = ai.path.dynamicNodes.count - 1
        ai.path.currentNode = 0
        object.ai = ai
        objects[handle] = object
        return true
    }
}
