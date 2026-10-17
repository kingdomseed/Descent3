// SPDX-License-Identifier: GPL-3.0-or-later
//
// MakeBOA (Descent3/BOA.cpp:2020; Descent 3, Copyright (C) 2024 Parallax
// Software, GPL-3.0-or-later), which the game runs at load when the level's
// stored BOA tables do not match its mine checksum: find_small_portals
// (:1943) with ComputeBOAVisFaceUpperLeft (:1395), BOA_ComputePathPoints
// (:1370) with ValidateRoomPathPoint (:1328) and IsPathPointValid (:1288),
// clear_BOA (:858), compute_costs (:875), compute_next_segs (:1085) with
// FindPath and update_path_info (:912-1080), compute_blockage_info
// (:1135), compute_sound_dist_info (:813), and compute_robot_path_info
// (:1969). BOA_PassablePortal (:208) and BOA_DetermineStartRoomPortal
// (:328) take their BOA_f_making_boa rules while it runs.
//
// Indoor rooms only (architecture.md section 9): compute_mine_info and
// compute_terrain_region_info give the terrain region rows, which only
// outdoor routes read (M3); their rows keep clear_BOA's values here. The
// ray casts of IsPathPointValid trace the room's faces only
// (`indoorRoomSweepHitsFace`), as the rest of the port's walls-only fvi.

import Foundation

extension Level {
    /// The level after MakeBOA: its small-portal flags and path points
    /// remade, and its BOA tables made.
    func madeByMakeBOA() -> Level {
        var level = self
        let highest = rooms.map(\.sourceIndex).max() ?? -1
        let size = highest + BOATables.maximumTerrainRegions + 1
        let noPath = highest + 9
        let portalCap = BOATables.maximumPathPortals
        let indexOf = Dictionary(uniqueKeysWithValues: rooms.enumerated()
            .map { ($1.sourceIndex, $0) })
        let textureFlags = Dictionary(
            surfacePhysics.map { ($0.texture, $0.textureFlags ?? 0) },
            uniquingKeysWith: { first, _ in first }
        )
        let external: UInt32 = 1 << 2
        let door: UInt32 = 1 << 1
        let manualPathPoint: UInt32 = 1 << 26
        let tooSmall: UInt32 = 4
        let ascending = rooms.map(\.sourceIndex).sorted()

        // find_small_portals.
        for index in level.rooms.indices {
            let room = level.rooms[index]
            for portalIndex in room.portals.indices {
                let face = room.faces[room.portals[portalIndex].faceIndex]
                let (xdiff, ydiff) = boaVisFaceExtents(room: room, face: face)
                if xdiff < 6 || ydiff < 6 {
                    level.rooms[index].portals[portalIndex].flags |= tooSmall
                } else {
                    level.rooms[index].portals[portalIndex].flags &= ~tooSmall
                }
            }
        }

        // BOA_PassablePortal while making the BOA.
        func makingPassable(_ roomNumber: Int, _ portal: Int,
                            invalidList: Bool = false) -> Bool {
            guard let index = indexOf[roomNumber] else { return false }
            let room = level.rooms[index]
            guard room.portals.indices.contains(portal) else { return false }
            let flags = room.portals[portal].flags
            if room.portals[portal].connectedRoom < 0 { return false }
            if invalidList, flags & tooSmall != 0 { return false }
            if flags & 32 != 0, flags & 64 == 0 { return false }
            if flags & 1 != 0, flags & 2 == 0 {
                let texture = room.faces[room.portals[portal].faceIndex]
                    .texture
                let breakableOrForceField: UInt32 = (1 << 20) | (1 << 5)
                if (textureFlags[texture] ?? 0) & breakableOrForceField == 0 {
                    return false
                }
            }
            return true
        }

        // BOA_ComputePathPoints.
        func faceCenter(_ room: LevelRoom, _ face: LevelFace) -> Vector3 {
            var sum = Vector3.zero
            for corner in face.corners {
                sum = sum + room.vertices[corner.vertexIndex]
            }
            let count = Float(face.corners.count)
            return Vector3(x: sum.x / count, y: sum.y / count,
                           z: sum.z / count)
        }
        func isPathPointValid(_ roomNumber: Int, _ position: Vector3) -> Bool {
            let room = level.rooms[indexOf[roomNumber]!]
            if room.flags & external != 0 { return true }
            for (portalIndex, portal) in room.portals.enumerated()
            where makingPassable(roomNumber, portalIndex) {
                if indoorRoomSweepHitsFace(room: room, start: portal.pathPoint,
                                           end: position, radius: 5) {
                    return false
                }
            }
            return true
        }
        for roomNumber in ascending {
            let index = indexOf[roomNumber]!
            let room = level.rooms[index]
            for portalIndex in room.portals.indices {
                level.rooms[index].portals[portalIndex].pathPoint =
                    faceCenter(room, room.faces[room.portals[portalIndex]
                        .faceIndex])
            }
            guard room.flags & manualPathPoint == 0 else { continue }
            var minimum = Vector3(x: 9_999_999, y: 9_999_999, z: 9_999_999)
            var maximum = Vector3(x: -9_999_999, y: -9_999_999,
                                  z: -9_999_999)
            for face in room.faces {
                for corner in face.corners {
                    let v = room.vertices[corner.vertexIndex]
                    minimum = Vector3(x: Swift.min(minimum.x, v.x),
                                      y: Swift.min(minimum.y, v.y),
                                      z: Swift.min(minimum.z, v.z))
                    maximum = Vector3(x: Swift.max(maximum.x, v.x),
                                      y: Swift.max(maximum.y, v.y),
                                      z: Swift.max(maximum.z, v.z))
                }
            }
            let center = maximum + minimum
            level.rooms[index].pathPoint = Vector3(
                x: center.x / 2, y: center.y / 2, z: center.z / 2
            )
            // ValidateRoomPathPoint.
            if isPathPointValid(roomNumber, level.rooms[index].pathPoint) {
                continue
            }
            let span = maximum - minimum
            let diff = Vector3(x: span.x / 12, y: span.y / 12, z: span.z / 12)
            search: for i in 1..<11 {
                for j in 1..<11 {
                    for k in 1..<11 {
                        let point = Vector3(
                            x: minimum.x + diff.x * Float(i),
                            y: minimum.y + diff.y * Float(j),
                            z: minimum.z + diff.z * Float(k)
                        )
                        if isPathPointValid(roomNumber, point) {
                            level.rooms[index].pathPoint = point
                            break search
                        }
                    }
                }
            }
        }

        // clear_BOA.
        var array = [UInt16](repeating: 0, count: size * size)
        for i in 0..<size {
            for j in 0..<size { array[i * size + j] = UInt16(i) }
        }
        // compute_costs.
        var costs = [Float](repeating: -1, count: size * portalCap)
        for roomNumber in ascending {
            let room = level.rooms[indexOf[roomNumber]!]
            var sum = Vector3.zero
            for vertex in room.vertices { sum = sum + vertex }
            let count = Float(room.vertices.count)
            let center = Vector3(x: sum.x / count, y: sum.y / count,
                                 z: sum.z / count)
            for (portalIndex, portal) in room.portals.enumerated()
            where makingPassable(roomNumber, portalIndex) {
                costs[roomNumber * portalCap + portalIndex] = vectorDistance(
                    center, faceCenter(room, room.faces[portal.faceIndex])
                )
            }
        }
        func cost(_ room: Int, _ portal: Int) -> Float {
            guard (0..<size).contains(room), (0..<portalCap).contains(portal)
            else {
                return -1
            }
            return costs[room * portalCap + portal]
        }
        // BOA_DetermineStartRoomPortal while making (or, for the blockage
        // pass, with the run-time rules for sound).
        func startPortal(_ start: Int, _ end: Int,
                         invalidList: Bool = false) -> Int {
            guard let index = indexOf[start] else { return -1 }
            for (portalIndex, portal) in level.rooms[index].portals.enumerated()
            where makingPassable(start, portalIndex, invalidList: invalidList)
                && portal.connectedRoom == end {
                return portalIndex
            }
            return -1
        }
        func runtimeSoundStartPortal(_ start: Int, _ end: Int) -> Int {
            guard let index = indexOf[start] else { return -1 }
            let room = level.rooms[index]
            for (portalIndex, portal) in room.portals.enumerated() {
                if portal.connectedRoom < 0 { continue }
                if cost(start, portalIndex) < 0, room.flags & external == 0 {
                    continue
                }
                let flags = portal.flags
                if (flags & 1 != 0 && flags & 2 == 0) || flags & 32 != 0 {
                    continue
                }
                if portal.connectedRoom == end { return portalIndex }
            }
            return -1
        }
        func next(_ i: Int, _ j: Int) -> Int {
            Int(array[i * size + j] & BOATables.roomMask)
        }

        // FindPath with its pq and update_path_info.
        func findPath(_ i: Int, _ j: Int) {
            var nodes: [(room: Int, parent: Int, cost: Float)] = [(i, -1, 0)]
            var queue = [0]
            var nodeOfRoom = [Int: Int]()
            while let current = boaPop(&queue, costs: nodes.map(\.cost)) {
                let node = nodes[current]
                nodeOfRoom[node.room] = current
                if node.room == j {
                    // update_path_info, bounded by the room count: with
                    // non-negative steps a parent chain never loops.
                    var end = j
                    var outer = 0
                    while end != i, outer <= rooms.count {
                        var cur = end
                        var parent = nodes[nodeOfRoom[end]!].parent
                        var inner = 0
                        while parent != -1, inner <= rooms.count {
                            array[parent * size + end] = UInt16(cur)
                            cur = nodes[nodeOfRoom[cur]!].parent
                            parent = nodes[nodeOfRoom[cur]!].parent
                            inner += 1
                        }
                        end = nodes[nodeOfRoom[end]!].parent
                        outer += 1
                    }
                    return
                }
                guard let index = indexOf[node.room] else { continue }
                for (counter, portal) in level.rooms[index].portals.enumerated()
                where makingPassable(node.room, counter) {
                    let nextRoom = portal.connectedRoom
                    guard nextRoom >= 0, nextRoom != noPath,
                          indexOf[nextRoom] != nil
                    else {
                        continue
                    }
                    let nextPortal = nextRoom != node.room
                        ? startPortal(nextRoom, node.room) : 0
                    // No passable way back: the original reads
                    // BOA_cost_array[next][-1] (BOA.cpp:1003, undefined).
                    // The step is skipped, as AIFindAltPath skips it
                    // (aipath.cpp:141).
                    guard nextPortal >= 0 else { continue }
                    let newCost = node.cost + cost(node.room, counter)
                        + cost(nextRoom, nextPortal)
                    if let existing = nodeOfRoom[nextRoom] {
                        guard nodes[existing].cost > newCost else { continue }
                        nodes[existing].cost = newCost
                        nodes[existing].parent = node.room
                    } else {
                        nodes.append((nextRoom, node.room, newCost))
                        nodeOfRoom[nextRoom] = nodes.count - 1
                        queue.insert(nodes.count - 1, at: 0)
                    }
                }
            }
            array[i * size + j] = UInt16(noPath)
        }
        // compute_next_segs.
        let indoor = ascending.filter {
            level.rooms[indexOf[$0]!].flags & external == 0
        }
        let indoorSet = Set(indoor)
        for i in indoor {
            for j in indoor.reversed() {
                if i != j, array[i * size + j] == UInt16(i) { findPath(i, j) }
                if i != j, array[j * size + i] == UInt16(j) { findPath(j, i) }
            }
        }
        // A route walk: the legacy loops end because FindPath's successors
        // lead to the destination; the room count bounds them here too.
        let stepLimit = rooms.count + 1
        // compute_blockage_info.
        for i in indoor {
            for j in ascending where i != j {
                var cur = i
                guard next(cur, j) != noPath, next(cur, j) != cur else {
                    continue
                }
                var steps = 0
                repeat {
                    if level.rooms[indexOf[cur]!].flags & door != 0 {
                        array[i * size + j] |= BOATables.blockageFlag
                        break
                    }
                    let last = cur
                    cur = next(cur, j)
                    if last != cur, runtimeSoundStartPortal(last, cur) == -1 {
                        array[i * size + j] |= BOATables.blockageFlag
                        break
                    }
                    steps += 1
                } while cur != j && steps < stepLimit && indexOf[cur] != nil
            }
        }
        // compute_sound_dist_info (the indoor rooms).
        let soundProp: UInt16 = 0x0800
        for i in 0..<size {
            for j in 0...i {
                array[i * size + j] |= soundProp
                array[j * size + i] |= soundProp
                if (i > highest || j > highest) && i != j {
                    array[i * size + j] &= ~soundProp
                    array[j * size + i] &= ~soundProp
                }
            }
        }
        func makingMinDist(_ start: Int, _ end: Int,
                           maximum: Float) -> Float? {
            if start == end { return 0 }
            guard indexOf[start] != nil, indexOf[end] != nil else {
                return nil
            }
            var distance: Float = 0
            var current = end
            var last: Int
            var lastPortal = -1
            var steps = 0
            repeat {
                last = current
                current = next(current, start)
                if last == current || current == noPath
                    || indexOf[current] == nil {
                    return nil
                }
                lastPortal = startPortal(last, current)
                if last == end {
                    let thisPortal = startPortal(current, last)
                    if current != start, thisPortal >= 0 {
                        distance += cost(current, thisPortal)
                    }
                } else if current == start {
                    distance += cost(last, lastPortal)
                } else {
                    let thisPortal = startPortal(current, last)
                    if lastPortal >= 0, thisPortal >= 0 {
                        distance += cost(last, lastPortal)
                            + cost(current, thisPortal)
                    }
                }
                if maximum > 0, maximum < distance { return nil }
                steps += 1
            } while current != start && steps < stepLimit
            return current == start ? distance : nil
        }
        for i in 0...Swift.max(highest, 0) {
            for j in 0..<i {
                let distance = indexOf[i] != nil && indexOf[j] != nil
                    ? makingMinDist(i, j, maximum: 400) : nil
                if distance.map({ $0 > 400 }) ?? true {
                    array[i * size + j] &= ~soundProp
                    array[j * size + i] &= ~soundProp
                }
            }
        }
        // compute_robot_path_info.
        for i in indoor {
            for j in ascending where i != j && indoorSet.contains(i) {
                var cur = i
                guard next(cur, j) != noPath, next(cur, j) != cur else {
                    continue
                }
                var steps = 0
                repeat {
                    let last = cur
                    cur = next(cur, j)
                    if last != cur,
                       startPortal(last, cur, invalidList: true) == -1 {
                        array[i * size + j] |= BOATables.tooSmallForRobotFlag
                        break
                    }
                    steps += 1
                } while cur != j && steps < stepLimit && indexOf[cur] != nil
            }
        }
        level.boaTables = BOATables(highestRoomIndex: highest, array: array,
                                    costs: costs)
        return level
    }
}

/// ComputeBOAVisFaceUpperLeft's grid size (BOA.cpp:1395): the face's
/// width and height in the frame of its reversed normal, from
/// vm_VectorToMatrix, vm_ExtractAnglesFromMatrix, and vm_AnglesToMatrix.
func boaVisFaceExtents(room: LevelRoom, face: LevelFace) -> (Float, Float) {
    // ComputeNormal (room.cpp:825): the normal of the three corners with
    // the largest cross product.
    var normal = Vector3.zero
    var largest: Float = 0
    let count = face.corners.count
    for index in 0..<count {
        let a = room.vertices[face.corners[index].vertexIndex]
        let b = room.vertices[face.corners[(index + 1) % count].vertexIndex]
        let c = room.vertices[face.corners[(index + 2) % count].vertexIndex]
        let (candidate, magnitude) = FixMath.normalize(
            FixMath.cross(b - a, c - b)
        )
        if magnitude > largest {
            normal = candidate
            largest = magnitude
        }
    }
    var sum = Vector3.zero
    for corner in face.corners {
        sum = sum + room.vertices[corner.vertexIndex]
    }
    let average = Vector3(x: sum.x / Float(count), y: sum.y / Float(count),
                          z: sum.z / Float(count))
    let faceMatrix = FixMath.matrix(
        forward: Vector3(x: -normal.x, y: -normal.y, z: -normal.z)
    )
    let angles = FixMath.angles(faceMatrix)
    let transform = FixMath.matrix(p: angles.p, h: angles.h, b: angles.b)
    let rotated = face.corners.map {
        FixMath.rotate(room.vertices[$0.vertexIndex] - average, transform)
    }
    var left = 0, top = 0, right = 0, bottom = 0
    var leftX: Float = 900_000, topY: Float = -900_000
    var rightX: Float = -900_000, bottomY: Float = 900_000
    for (index, vertex) in rotated.enumerated() {
        if vertex.x < leftX { left = index; leftX = vertex.x }
    }
    for (index, vertex) in rotated.enumerated() {
        if vertex.y > topY { top = index; topY = vertex.y }
    }
    for (index, vertex) in rotated.enumerated() {
        if vertex.x > rightX { right = index; rightX = vertex.x }
    }
    for (index, vertex) in rotated.enumerated() {
        if vertex.y < bottomY { bottom = index; bottomY = vertex.y }
    }
    return (rotated[right].x - rotated[left].x,
            rotated[top].y - rotated[bottom].y)
}
