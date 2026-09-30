// SPDX-License-Identifier: GPL-3.0-or-later
//
// The BOA tables and the room queries that read them. Translated from
// Descent3/BOA.cpp (Descent 3, Copyright (C) 2024 Parallax Software,
// GPL-3.0-or-later): BOA_Array and BOA_cost_array (:172-173), as
// ReadBOAChunk loads them (LoadLevel.cpp:3050); BOA_PassablePortal (:208),
// BOA_LockedDoor (:272), BOA_DetermineStartRoomPortal (:328),
// BOA_ComputeMinDist (:383), BOA_HasPossibleBlockage (:499), and
// BOA_GetNextRoom (:566); and, for a level without stored tables, the part
// of MakeBOA (:2020) they need: clear_BOA (:858), compute_costs (:875),
// FindPath with update_path_info (:912-1080), compute_next_segs (:1085),
// and compute_blockage_info (:1135).
//
// Indoor rooms only: a room number is the room's source index, and the
// terrain regions (BOA_INDEX of an outside room) arrive with the terrain in
// M3. A level without stored tables (the synthetic test levels; D3Import
// always stores them) builds them at load without find_small_portals,
// BOA_ComputePathPoints, and the sound and visibility passes
// (architecture.md section 9).

import Foundation

/// BOA_Array and BOA_cost_array for rooms 0...highestRoomIndex + 8.
struct BOATables: Codable, Equatable, Sendable {
    /// MAX_PATH_PORTALS (BOA.h:123).
    static let maximumPathPortals = 40
    /// BOA_ROOM_MASK (BOA.h:194).
    static let roomMask: UInt16 = 0x03ff
    /// BOAF_BLOCKAGE (BOA.h:229).
    static let blockageFlag: UInt16 = 0x4000
    /// BOAF_TOO_SMALL_FOR_ROBOT (BOA.h:233).
    static let tooSmallForRobotFlag: UInt16 = 0x8000
    /// MAX_BOA_TERRAIN_REGIONS (BOA.h:124).
    static let maximumTerrainRegions = 8

    /// Highest_room_index when the tables were made.
    let highestRoomIndex: Int
    /// BOA_Array, row-major, `size` x `size`.
    let array: [UInt16]
    /// BOA_cost_array, row-major, `size` x MAX_PATH_PORTALS.
    let costs: [Float]

    /// Rows and columns: Highest_room_index + 8, inclusive.
    var size: Int { highestRoomIndex + Self.maximumTerrainRegions + 1 }
    /// BOA_NO_PATH (BOA.h:198).
    var noPath: Int { highestRoomIndex + 9 }

    func entry(_ i: Int, _ j: Int) -> UInt16 {
        guard (0..<size).contains(i), (0..<size).contains(j) else {
            return UInt16(noPath)
        }
        return array[i * size + j]
    }

    func cost(_ room: Int, _ portal: Int) -> Float {
        guard (0..<size).contains(room),
              (0..<Self.maximumPathPortals).contains(portal)
        else {
            return -1
        }
        return costs[room * Self.maximumPathPortals + portal]
    }

    /// The checks of a loaded table: its size matches the level's highest
    /// room, every cost is finite, and every next-room chain between two
    /// rooms reaches its destination within the room count or ends at a
    /// "no route" marker: BOA_NO_PATH, or a room that points to itself
    /// (clear_BOA, BOA.cpp:863). The mine checksum does not cover the
    /// table's contents; tables MakeBOA made always pass (FindPath writes
    /// shortest-route successors).
    func isValid(for level: Level) -> Bool {
        let used = Set(level.rooms.map(\.sourceIndex))
        guard highestRoomIndex == (used.max() ?? -1),
              array.count == size * size,
              costs.count == size * Self.maximumPathPortals,
              // compute_costs writes -1 or a distance (BOA.cpp:892-899).
              costs.allSatisfy({ $0 == -1 || ($0.isFinite && $0 >= 0) })
        else {
            return false
        }
        for start in used {
            for end in used where end != start {
                var current = start
                var steps = 0
                while current != end {
                    let next = Int(entry(current, end) & Self.roomMask)
                    if next == noPath || next == current { break }
                    guard used.contains(next), steps < used.count else {
                        return false
                    }
                    current = next
                    steps += 1
                }
            }
        }
        return true
    }
}

extension Level {
    /// The room with this source index (Rooms[i] when used).
    func boaRoom(_ room: Int) -> LevelRoom? {
        rooms.first { $0.sourceIndex == room }
    }

    /// The level as it is loaded: MakeBOA (BOA.cpp:2020) remakes the BOA
    /// tables, the small-portal flags, and the path points when the level
    /// has no stored tables (BOATables+Make.swift).
    func withLoadedBOATables() -> Level {
        boaTables == nil ? madeByMakeBOA() : self
    }

    /// The level's BOA tables: the stored ones, or the ones MakeBOA makes
    /// at load.
    var effectiveBOATables: BOATables {
        boaTables ?? madeByMakeBOA().boaTables!
    }
}

/// pq::pop (BOA.h:162): the first item, from the head, with the lowest
/// cost; items are pushed at the head.
func boaPop(_ queue: inout [Int], costs: [Float]) -> Int? {
    guard !queue.isEmpty else { return nil }
    var best = 0
    for index in queue.indices where costs[queue[index]] < costs[queue[best]] {
        best = index
    }
    return queue.remove(at: best)
}

extension GameWorld {
    /// BOA_PassablePortal (BOA.cpp:208) at run time, with the current portal
    /// flags: a portal that joins a room, has a cost (or is in an external
    /// room), is not too small for a robot (unless for sound), and is not
    /// rendered closed or blocked.
    func boaPassablePortal(room: Int, portal: Int, forSound: Bool = false,
                           level: Level) -> Bool {
        guard let index = level.rooms.firstIndex(where: {
            $0.sourceIndex == room
        }),
            level.rooms[index].portals.indices.contains(portal)
        else {
            return false
        }
        let levelRoom = level.rooms[index]
        guard levelRoom.portals[portal].connectedRoom >= 0 else {
            return false
        }
        let external: UInt32 = 1 << 2
        if level.effectiveBOATables.cost(room, portal) < 0,
           levelRoom.flags & external == 0 {
            return false
        }
        let flags = rooms[index].portalFlags[portal]
        let renderFaces: UInt32 = 1
        let renderedFlythrough: UInt32 = 2
        let tooSmallForRobot: UInt32 = 4
        let block: UInt32 = 32
        if !forSound, flags & tooSmallForRobot != 0 { return false }
        if (flags & renderFaces != 0 && flags & renderedFlythrough == 0)
            || flags & block != 0 {
            return false
        }
        return true
    }

    /// BOA_DetermineStartRoomPortal (BOA.cpp:328) between indoor rooms:
    /// the first passable portal of `start` into `end`, or -1.
    func boaDetermineStartRoomPortal(_ start: Int, _ end: Int,
                                     level: Level) -> Int {
        guard start >= 0, end >= 0, let room = level.boaRoom(start) else {
            return -1
        }
        for (index, portal) in room.portals.enumerated()
        where boaPassablePortal(room: start, portal: index, level: level)
            && portal.connectedRoom == end {
            return index
        }
        return -1
    }

    /// BOA_LockedDoor (BOA.cpp:272) for an object: a door room whose door
    /// object the object cannot open (DoorwayOpenable, doorway.cpp:540) and
    /// that is less than half open. Global_keys is 0, and the door keeps
    /// its level-start position (doors arrive in M2).
    func boaLockedDoor(_ handle: ObjectHandle?, room: Int,
                       level: Level) -> Bool {
        let doorFlag: UInt32 = 1 << 1
        guard let levelRoom = level.boaRoom(room),
              levelRoom.flags & doorFlag != 0,
              let door = levelRoom.door
        else {
            return false
        }
        let locked: UInt8 = 4
        let keyOnlyOne: UInt8 = 8
        func openable(by opener: GameObject?) -> Bool {
            if door.flags & locked != 0 { return false }
            if door.keysNeeded == 0 { return true }
            guard let opener else { return false }
            let keys: UInt8
            switch opener.type {
            case .player: keys = 0
            case .robot: keys = 0
            case .building where opener.ai != nil: keys = 0
            default: return false
            }
            return door.flags & keyOnlyOne != 0
                ? keys & door.keysNeeded != 0
                : keys & door.keysNeeded == door.keysNeeded
        }
        guard let handle else {
            return door.flags & locked != 0 && door.position < 0.5
        }
        guard objects.contains(where: {
            $0.type == .door && $0.location == .room(room)
        }) else {
            return false
        }
        return !openable(by: objects[handle]) && door.position < 0.5
    }

    /// BOA_GetNextRoom (BOA.cpp:566).
    func boaGetNextRoom(_ start: Int, _ end: Int, level: Level) -> Int {
        let tables = level.effectiveBOATables
        guard start >= 0, end >= 0,
              level.boaRoom(start) != nil, level.boaRoom(end) != nil
        else {
            return tables.noPath
        }
        return Int(tables.entry(start, end) & BOATables.roomMask)
    }

    /// BOA_HasPossibleBlockage (BOA.cpp:499).
    func boaHasPossibleBlockage(_ start: Int, _ end: Int,
                                level: Level) -> Bool {
        guard start >= 0, end >= 0,
              level.boaRoom(start) != nil, level.boaRoom(end) != nil
        else {
            return false
        }
        return level.effectiveBOATables.entry(start, end)
            & BOATables.blockageFlag != 0
    }

    /// BOAF_TOO_SMALL_FOR_ROBOT of BOA_Array[start][end].
    func boaTooSmallForRobot(_ start: Int, _ end: Int, level: Level) -> Bool {
        level.effectiveBOATables.entry(start, end)
            & BOATables.tooSmallForRobotFlag != 0
    }

    /// BOA_ComputeMinDist (BOA.cpp:383) without the blockage count: the
    /// BOA_NEXT_ROOM route length, or `nil` when there is none.
    func boaComputeMinDist(_ start: Int, _ end: Int, maximumCheckDistance:
                           Float = 0, level: Level) -> Float? {
        if start == end { return 0 }
        let tables = level.effectiveBOATables
        guard start >= 0, end >= 0,
              level.boaRoom(start) != nil, level.boaRoom(end) != nil
        else {
            return nil
        }
        var distance: Float = 0
        var current = end
        var last: Int
        var lastPortal = -1
        // The legacy loop ends because the successors lead to `start`
        // (loaded tables are checked for that, `isValid`); the room count
        // bounds it here too.
        var steps = 0
        repeat {
            steps += 1
            if steps > level.rooms.count + 1 { return nil }
            last = current
            current = Int(tables.entry(current, start) & BOATables.roomMask)
            if last == current || current == tables.noPath { return nil }
            if last != current {
                lastPortal = boaDetermineStartRoomPortal(last, current,
                                                         level: level)
            }
            if last == end {
                let thisPortal = boaDetermineStartRoomPortal(current, last,
                                                             level: level)
                if current != start, thisPortal >= 0 {
                    distance += tables.cost(current, thisPortal)
                }
                if maximumCheckDistance > 0, maximumCheckDistance < distance {
                    return nil
                }
            } else if current == start {
                distance += tables.cost(last, lastPortal)
                if maximumCheckDistance > 0, maximumCheckDistance < distance {
                    return nil
                }
            } else {
                let thisPortal = boaDetermineStartRoomPortal(current, last,
                                                             level: level)
                if lastPortal >= 0, thisPortal >= 0 {
                    distance += tables.cost(last, lastPortal)
                        + tables.cost(current, thisPortal)
                    if maximumCheckDistance > 0,
                       maximumCheckDistance < distance {
                        return nil
                    }
                }
            }
        } while current != start && current != last
            && current != tables.noPath
        return current == tables.noPath ? nil : distance
    }

    /// AIFindAltPath (aipath.cpp:62): the cheapest room route from `start`
    /// to `end` through passable portals and unlocked doors, each step's
    /// cost scaled by 1 +/- 0.1 from one ps_rand draw, in the order of its
    /// pq; AIUpdatePathInfo's rooms (AIAltPath), and the route length when
    /// found. An external room (a building on the terrain) is skipped:
    /// terrain regions arrive in M3.
    mutating func aiFindAltPath(
        _ handle: ObjectHandle?,
        from start: Int,
        to end: Int,
        level: Level
    ) -> (rooms: [Int], length: Float)? {
        guard start != -1, end != -1,
              level.boaRoom(start) != nil, level.boaRoom(end) != nil
        else {
            return nil
        }
        let tables = level.effectiveBOATables
        let external: UInt32 = 1 << 2
        var nodes: [(room: Int, parent: Int, cost: Float)] = [(start, -1, 0)]
        var queue = [0]
        var nodeOfRoom = [Int: Int]()
        var found = false
        let halfRandMax = Float(GameWorld.randMax) / 2
        while let current = boaPop(&queue, costs: nodes.map(\.cost)) {
            let node = nodes[current]
            nodeOfRoom[node.room] = current
            if node.room == end {
                found = true
                break
            }
            guard let room = level.boaRoom(node.room) else { continue }
            for (counter, portal) in room.portals.enumerated() {
                guard boaPassablePortal(room: node.room, portal: counter,
                                        level: level)
                else {
                    continue
                }
                let next = portal.connectedRoom
                guard let nextRoom = level.boaRoom(next),
                      nextRoom.flags & external == 0,
                      next != tables.noPath,
                      !boaLockedDoor(handle, room: next, level: level)
                else {
                    continue
                }
                var nextPortal = 0
                if next != node.room {
                    nextPortal = boaDetermineStartRoomPortal(next, node.room,
                                                             level: level)
                }
                guard nextPortal != -1,
                      tables.cost(node.room, counter) >= 0
                else {
                    continue
                }
                let draw = Float(psRand())
                let newCost = node.cost
                    + (1 + 0.1 * (draw - halfRandMax) / halfRandMax)
                        * (tables.cost(node.room, counter)
                            + tables.cost(next, nextPortal))
                if let existing = nodeOfRoom[next] {
                    guard !(nodes[existing].cost < newCost) else { continue }
                    nodes[existing].cost = newCost
                    nodes[existing].parent = node.room
                } else {
                    nodes.append((next, node.room, newCost))
                    nodeOfRoom[next] = nodes.count - 1
                    queue.insert(nodes.count - 1, at: 0)
                }
            }
        }
        guard found else { return nil }
        // AIUpdatePathInfo: the parents from the end, reversed. A parent
        // chain longer than the rooms cannot happen in the original.
        var route: [Int] = []
        var room = end
        while room != -1, route.count <= level.rooms.count {
            route.append(room)
            room = nodes[nodeOfRoom[room]!].parent
        }
        route.reverse()
        var length: Float = 0
        for (current, next) in zip(route, route.dropFirst()) {
            let currentPortal = boaDetermineStartRoomPortal(current, next,
                                                            level: level)
            let nextPortal = boaDetermineStartRoomPortal(next, current,
                                                         level: level)
            length += tables.cost(current, currentPortal)
                + tables.cost(next, nextPortal)
        }
        return (route, length)
    }
}
