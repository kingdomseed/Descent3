// SPDX-License-Identifier: GPL-3.0-or-later
//
// The room route queries of Descent3/BOA.cpp (Descent 3, Copyright (C)
// 2024 Parallax Software, GPL-3.0-or-later) that the runtime uses:
// BOA_IsVisible, BOA_GetNextRoom, and the route nodes that
// AIGenerateBOAPath and AIGenerateBNodePath (aipath.cpp:791, :906) add to a
// dynamic path.
//
// Accepted difference (architecture.md section 9): the original reads the
// CBOA tables that the level editor computed (BOA_Array, the BNode lists).
// Revival derives the room route from the level's reciprocal portals, with
// the fewest rooms first. A route that stays in one room and whose straight
// line is blocked follows the room's verified boundary nodes; a route that
// crosses rooms goes through each portal's path point. The straight-line
// probe traces the walls only.

import Foundation

extension GameWorld {
    /// BOA_IsVisible: whether one room can see another. Revival uses the
    /// rooms joined by reciprocal portals (architecture.md section 9).
    func boaIsVisible(_ from: SpatialLocation, _ to: SpatialLocation,
                      level: Level) -> Bool {
        guard case let .room(fromRoom) = from, case let .room(toRoom) = to
        else {
            return false
        }
        return fromRoom == toRoom
            || reciprocalPortalComponent(
                rooms: level.rooms,
                startRoomSourceIndex: fromRoom
            ).contains(toRoom)
    }

    /// The BOA_GetNextRoom chain from `start` to `destination`: the rooms
    /// in order, `start` first, or `nil` for BOA_NO_PATH. Breadth first
    /// over the portals in room and portal order.
    func boaRoomRoute(from start: Int, to destination: Int,
                      level: Level) -> [Int]? {
        let roomBySourceIndex = Dictionary(
            uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
        )
        guard roomBySourceIndex[start] != nil,
              roomBySourceIndex[destination] != nil
        else {
            return nil
        }
        if start == destination { return [start] }
        var queue = [start]
        var head = 0
        var predecessor: [Int: Int] = [:]
        var visited: Set<Int> = [start]
        while head < queue.count {
            let room = queue[head]
            head += 1
            for portal in roomBySourceIndex[room]!.portals {
                let next = portal.connectedRoom
                guard roomBySourceIndex[next] != nil,
                      visited.insert(next).inserted
                else {
                    continue
                }
                predecessor[next] = room
                if next == destination {
                    var result = [destination]
                    while result.last != start {
                        result.append(predecessor[result.last!]!)
                    }
                    return Array(result.reversed())
                }
                queue.append(next)
            }
        }
        return nil
    }

    /// The nodes a dynamic path takes before its end point (the node
    /// generation of AIPathAllocPath, aipath.cpp:1016-1100), or `nil` when
    /// no route exists. A clear straight line adds none.
    func boaRoute(
        startRoom: Int,
        start: Vector3,
        startForward: Vector3,
        endRoom: Int,
        end: Vector3,
        radius: Float,
        level: Level
    ) -> [AIPathNode]? {
        guard let rooms = boaRoomRoute(from: startRoom, to: endRoom,
                                       level: level)
        else {
            return nil
        }
        if boaProbeIsClear(room: startRoom, start: start, end: end,
                           radius: radius, level: level) {
            return []
        }
        if startRoom != endRoom {
            let roomBySourceIndex = Dictionary(
                uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) }
            )
            var nodes: [AIPathNode] = []
            for (room, next) in zip(rooms, rooms.dropFirst()) {
                guard let portal = roomBySourceIndex[room]?.portals.first(
                    where: { $0.connectedRoom == next }
                ) else {
                    return nil
                }
                nodes.append(AIPathNode(position: portal.pathPoint,
                                        roomSourceIndex: next))
            }
            return nodes
        }
        return boaBoundaryNodeRoute(
            room: startRoom,
            start: start,
            startForward: startForward,
            end: end,
            radius: radius,
            level: level
        )
    }

    /// The boundary node route in one room (BNode_FindClosestLocalVisible-
    /// BNode and BNode_FindPath, used by AIGenerateBNodePath): the last
    /// visible node ahead of the start (or else the last visible one) within
    /// 800 units, the visible node nearest the end, and the cheapest edge
    /// path between them. The probes use a quarter of the radius, at most 20.
    private func boaBoundaryNodeRoute(
        room: Int,
        start: Vector3,
        startForward: Vector3,
        end: Vector3,
        radius: Float,
        level: Level
    ) -> [AIPathNode]? {
        guard let graph = level.indoorNavigation, graph.sourceWasVerified,
              let navigation = graph.rooms.first(where: {
                  $0.sourceIndex == room
              })
        else {
            return nil
        }
        let nodes = navigation.nodes
        let probeRadius = min(radius / 4, 20)
        let visibleStart = nodes.indices.filter {
            vectorDistance(start, nodes[$0].position) < 800
                && boaProbeIsClear(room: room, start: start,
                                   end: nodes[$0].position,
                                   radius: probeRadius, level: level)
        }
        let forwardStart = visibleStart.filter {
            dot(startForward, vmNormalized(nodes[$0].position - start)) > 0
        }
        func quickDistance(_ index: Int) -> Float {
            let delta = nodes[index].position - end
            return abs(delta.x) + abs(delta.y) + abs(delta.z)
        }
        let visibleEnd = nodes.indices.filter {
            nodes[$0].edges.contains { $0.maximumRadius >= probeRadius }
                && boaProbeIsClear(room: room, start: nodes[$0].position,
                                   end: end, radius: probeRadius,
                                   level: level)
        }
        let endNode = visibleEnd.min { quickDistance($0) < quickDistance($1) }
            ?? nodes.indices.filter { quickDistance($0) < 800 }
                .min { quickDistance($0) < quickDistance($1) }
        guard let startNode = forwardStart.last ?? visibleStart.last,
              let endNode,
              let path = boaBoundaryNodePath(navigation, from: startNode,
                                             to: endNode)
        else {
            return nil
        }
        return path.map {
            AIPathNode(position: nodes[$0].position, roomSourceIndex: room)
        }
    }

    /// BNode_FindPath: the cheapest edge path in one room, ties to the
    /// later pending node.
    private func boaBoundaryNodePath(
        _ room: IndoorNavigationRoom,
        from start: Int,
        to destination: Int
    ) -> [Int]? {
        var distances = [start: 0]
        var predecessor: [Int: Int] = [:]
        var pending = [start]
        var visited: Set<Int> = []
        while !pending.isEmpty {
            let index = pending.indices.min {
                let lhs = distances[pending[$0], default: .max]
                let rhs = distances[pending[$1], default: .max]
                return lhs == rhs ? $0 > $1 : lhs < rhs
            }!
            let current = pending.remove(at: index)
            guard visited.insert(current).inserted else { continue }
            if current == destination {
                var result = [current]
                while result.last != start {
                    result.append(predecessor[result.last!]!)
                }
                return result.reversed()
            }
            for edge in room.nodes[current].edges
            where edge.destinationRoomSourceIndex == room.sourceIndex
                && room.nodes.indices.contains(edge.destinationNodeIndex) {
                let next = edge.destinationNodeIndex
                let candidate = distances[current]! + edge.cost
                if candidate <= distances[next, default: .max] {
                    distances[next] = candidate
                    predecessor[next] = current
                    pending.append(next)
                }
            }
        }
        return nil
    }

    /// Whether a sphere of `radius` moves from `start` to `end` without
    /// hitting a wall.
    func boaProbeIsClear(room: Int, start: Vector3, end: Vector3,
                         radius: Float, level: Level) -> Bool {
        if case .noHit = traceIndoorMovement(
            in: level,
            roomStates: rooms,
            startRoom: room,
            start: start,
            end: end,
            radius: radius
        ).outcome {
            return true
        }
        return false
    }
}
