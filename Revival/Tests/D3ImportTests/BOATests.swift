import XCTest

/// The BOA room tables and routes (Descent3/BOA.cpp, aipath.cpp
/// AIFindAltPath): MakeBOA, the loaded-table checks, and the route nodes.
final class BOATests: XCTestCase {
    // MARK: AIFindAltPath

    /// AIFindAltPath (aipath.cpp:62) draws one ps_rand per step it prices,
    /// in its pq's order, and returns the rooms and the unscaled length.
    func testAIFindAltPathDrawsOnePSRandPerPricedStep() throws {
        // A level with its BOA tables made, whose portals are then marked
        // big enough for robots (this synthetic level's are small).
        var level = makeTrainingManeuverFollowLevel().withLoadedBOATables()
        for room in level.rooms.indices {
            for portal in level.rooms[room].portals.indices {
                level.rooms[room].portals[portal].flags &= ~4
            }
        }

        var world = GameSession(level: level, presentationReadyTimestamp: 0)
            .world
        let tables = level.effectiveBOATables
        // A room with an open portal into a room with an open way back.
        var pair: (from: Int, to: Int, out: Int, back: Int)?
        for room in level.rooms where pair == nil {
            for (index, portal) in room.portals.enumerated()
            where world.boaPassablePortal(room: room.sourceIndex,
                                          portal: index, level: level) {
                let back = world.boaDetermineStartRoomPortal(
                    portal.connectedRoom, room.sourceIndex, level: level
                )
                if back >= 0 {
                    pair = (room.sourceIndex, portal.connectedRoom, index, back)
                    break
                }
            }
        }

        let route = try XCTUnwrap(pair)
        let before = world.authoritativeRandomState
        let found = try XCTUnwrap(world.aiFindAltPath(
            nil, from: route.from, to: route.to, level: level
        ))
        XCTAssertEqual(found.rooms, [route.from, route.to])
        XCTAssertEqual(found.length,
                       tables.cost(route.from, route.out)
                        + tables.cost(route.to, route.back))
        // The start room prices each of its passable portals once.
        let priced = try XCTUnwrap(level.boaRoom(route.from)).portals.indices
            .filter { index in
                world.boaPassablePortal(room: route.from, portal: index,
                                        level: level)
                    && tables.cost(route.from, index) >= 0
                    && world.boaDetermineStartRoomPortal(
                        level.boaRoom(route.from)!.portals[index]
                            .connectedRoom,
                        route.from,
                        level: level
                    ) != -1
            }.count
        var expected = before
        for _ in 0..<priced { expected = expected &* 214_013 &+ 2_531_011 }
        XCTAssertGreaterThan(priced, 0)
        XCTAssertEqual(world.authoritativeRandomState, expected)
        // The same room costs nothing and draws nothing.
        let same = world.authoritativeRandomState
        XCTAssertEqual(world.aiFindAltPath(nil, from: route.from,
                                           to: route.from, level: level)?.rooms,
                       [route.from])
        XCTAssertEqual(world.authoritativeRandomState, same)
    }

    // MARK: The object EVT_INTERVAL

    /// find_small_portals measures a portal face in the frame of its
    /// reversed normal (ComputeBOAVisFaceUpperLeft, BOA.cpp:1395, with the
    /// table trig of fix.cpp): a 10 by 4 rectangle measures 10 by 4 however
    /// it is turned, and a side under 6 marks the portal too small.
    func testPortalFacesAreMeasuredInTheirOwnPlane() throws {
        func rectangle(yaw: Float) -> (LevelRoom, LevelFace) {
            let c = cosf(yaw), s = sinf(yaw)
            let points: [(Float, Float)] = [(0, 0), (0, 4), (10, 4), (10, 0)]
            let vertices = points.map {
                Vector3(x: c * $0.0 + 3, y: $0.1 - 7, z: s * $0.0 + 11)
            }

            let face = LevelFace(
                corners: (0..<4).map {
                    FaceCorner(vertexIndex: $0, u: 0, v: 0, alpha: 255,
                               lightmapU: nil, lightmapV: nil)
                },
                flags: 0,
                portalIndex: nil,
                texture: SourceResource(storedIndex: 0, sourceName: "t")
            )
            return (LevelRoom(sourceIndex: 0, vertices: vertices,
                              faces: [face], portals: []), face)
        }
        for yaw in [Float(0), 0.5, 2.1, 4] {
            let (room, face) = rectangle(yaw: yaw)
            let (x, y) = boaVisFaceExtents(room: room, face: face)
            XCTAssertEqual(x, 10, accuracy: 0.01, "yaw \(yaw)")
            XCTAssertEqual(y, 4, accuracy: 0.01, "yaw \(yaw)")
        }
    }

    /// While MakeBOA runs, a rendered portal still passes when its texture
    /// is breakable or a force field (BOA.cpp:259-263), so it gets a cost.
    func testMakeBOACostsRenderedBreakableAndForceFieldPortals() throws {
        let base = makeTrainingManeuverFollowLevel()
        let roomIndex = try XCTUnwrap(base.rooms.firstIndex {
            $0.portals.contains { $0.connectedRoom >= 0 }
        })
        let portalIndex = try XCTUnwrap(base.rooms[roomIndex].portals
            .firstIndex { $0.connectedRoom >= 0 })
        let texture = base.rooms[roomIndex].faces[
            base.rooms[roomIndex].portals[portalIndex].faceIndex
        ].texture
        func cost(textureFlags: UInt32) -> Float {
            var level = base
            level.rooms[roomIndex].portals[portalIndex].flags = 1
            level.surfacePhysics = level.surfacePhysics.map { entry in
                guard entry.texture == texture else { return entry }
                var entry = entry
                entry.textureFlags = textureFlags
                return entry
            }
            return level.madeByMakeBOA().boaTables!.cost(
                level.rooms[roomIndex].sourceIndex, portalIndex
            )
        }
        XCTAssertEqual(cost(textureFlags: 0), -1)
        XCTAssertGreaterThan(cost(textureFlags: 1 << 20), 0)
        XCTAssertGreaterThan(cost(textureFlags: 1 << 5), 0)
    }

    /// A portal that passes on one side but not the other: FindPath's
    /// BOA_DetermineStartRoomPortal finds no way back (-1). The original
    /// then reads BOA_cost_array[next][-1] (BOA.cpp:1003, undefined);
    /// AIFindAltPath skips such a step (aipath.cpp:141), and so does
    /// MakeBOA here: the one-sided portal is no route, every cost stays
    /// -1 or a distance, and making the tables ends.
    func testMakeBOASkipsAPortalWithNoPassableWayBack() throws {
        var level = makeTrainingManeuverFollowLevel()
        func isOpen(_ portal: LevelPortal) -> Bool {
            (portal.flags & 1 == 0 || portal.flags & 2 != 0)
                && portal.flags & 32 == 0 && portal.connectedRoom >= 0
        }

        let fromIndex = try XCTUnwrap(level.rooms.firstIndex {
            $0.portals.contains(where: isOpen)
        })
        let portal = try XCTUnwrap(
            level.rooms[fromIndex].portals.first(where: isOpen)
        )
        let toIndex = try XCTUnwrap(level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        })
        // Close only the far side (rendered, not fly-through).
        level.rooms[toIndex].portals[portal.connectedPortal].flags =
            (level.rooms[toIndex].portals[portal.connectedPortal].flags | 1)
                & ~2
        let from = level.rooms[fromIndex].sourceIndex
        let to = level.rooms[toIndex].sourceIndex
        let onlyPortal = level.rooms[fromIndex].portals.filter {
            $0.connectedRoom == to
        }.count == 1
        let tables = try XCTUnwrap(level.madeByMakeBOA().boaTables)
        XCTAssertTrue(tables.costs.allSatisfy { $0 == -1 || $0 >= 0 })
        XCTAssertTrue(tables.isValid(for: level))
        if onlyPortal {
            XCTAssertNotEqual(Int(tables.entry(from, to) & BOATables.roomMask),
                              to)
        }
    }

    /// compute_costs writes -1 or a distance (BOA.cpp:892-899); a loaded
    /// table with another negative cost is rejected.
    func testBOATablesWithANegativeCostAreRejected() throws {
        let level = makeTrainingManeuverFollowLevel().withLoadedBOATables()
        let tables = try XCTUnwrap(level.boaTables)
        var costs = tables.costs
        costs[0] = -0.5
        XCTAssertFalse(BOATables(highestRoomIndex: tables.highestRoomIndex,
                                 array: tables.array, costs: costs)
            .isValid(for: level))
    }

    /// BOAGetMineChecksum's inputs are checked first: a face naming a
    /// missing vertex or portal, or a coordinate whose floor is not a C
    /// int, gives no checksum (an import error), never a trap.
    func testTheMineChecksumRefusesMalformedGeometry() throws {
        let level = makeTrainingManeuverFollowLevel()
        XCTAssertNotNil(boaMineChecksum(rooms: level.rooms,
                                        terrain: level.terrain))
        var vertexIndex = level.rooms
        let corner = vertexIndex[0].faces[0].corners[0]
        vertexIndex[0].faces[0] = LevelFace(
            corners: [FaceCorner(vertexIndex: 99_999, u: corner.u,
                                 v: corner.v, alpha: corner.alpha,
                                 lightmapU: nil, lightmapV: nil)]
                + vertexIndex[0].faces[0].corners.dropFirst(),
            flags: vertexIndex[0].faces[0].flags,
            portalIndex: vertexIndex[0].faces[0].portalIndex,
            texture: vertexIndex[0].faces[0].texture
        )
        XCTAssertNil(boaMineChecksum(rooms: vertexIndex,
                                     terrain: level.terrain))
        var huge = level.rooms
        huge[0].vertices[corner.vertexIndex] = Vector3(x: 1e20, y: 0, z: 0)
        XCTAssertNil(boaMineChecksum(rooms: huge, terrain: level.terrain))
    }

    /// A loaded table whose next-room chain loops (1 to 2 to 1) is
    /// rejected; the "no route" markers (BOA_NO_PATH, a room pointing to
    /// itself) are not.
    func testBOATablesWhoseRouteLoopsAreRejected() throws {
        let level = makeTrainingManeuverFollowLevel().withLoadedBOATables()
        let tables = try XCTUnwrap(level.boaTables)
        XCTAssertTrue(tables.isValid(for: level))
        let used = level.rooms.map(\.sourceIndex).sorted()
        XCTAssertGreaterThanOrEqual(used.count, 3)
        let (a, b, target) = (used[0], used[1], used[2])
        func with(_ changes: [(Int, Int, UInt16)]) -> BOATables {
            var array = tables.array
            for (i, j, value) in changes {
                array[i * tables.size + j] = value
            }
            return BOATables(highestRoomIndex: tables.highestRoomIndex,
                             array: array, costs: tables.costs)
        }

        let loop = with([(a, target, UInt16(b)), (b, target, UInt16(a))])
        XCTAssertFalse(loop.isValid(for: level))
        var looping = level
        looping.boaTables = loop
        XCTAssertThrowsError(try looping.validate())
        XCTAssertTrue(with([(a, target, UInt16(tables.noPath))])
            .isValid(for: level))
        XCTAssertTrue(with([(a, target, UInt16(a))]).isValid(for: level))
        XCTAssertFalse(with([(a, target, 999)]).isValid(for: level))
    }

    /// A room has at most MAX_PATH_PORTALS portals (compute_costs asserts
    /// it, BOA.cpp:883): BOA_cost_array has that many columns.
    func testARoomWithMoreThanFortyPortalsIsRejected() throws {
        var level = makeTrainingManeuverFollowLevel()
        let portal = try XCTUnwrap(level.rooms[0].portals.first)
        level.rooms[0].portals += Array(repeating: portal, count: 41)
        XCTAssertThrowsError(try level.validate()) { error in
            XCTAssertEqual(error as? LevelValidationError,
                           .invalidCount("room portals"))
        }
    }

    /// With two portals between the same rooms, the route's node is the
    /// portal BOA_DetermineStartRoomPortal picks (the passable one), as
    /// AIGenerateAltBNodePath does (aipath.cpp:654), not the first.
    func testRouteNodesUseThePassablePortalBetweenTwoRooms() throws {
        var level = makeTrainingManeuverFollowLevel()
        func isOpen(_ portal: LevelPortal) -> Bool {
            (portal.flags & 1 == 0 || portal.flags & 2 != 0)
                && portal.flags & 32 == 0 && portal.connectedRoom >= 0
        }

        let roomIndex = try XCTUnwrap(level.rooms.firstIndex {
            $0.portals.contains(where: isOpen)
        })
        let openIndex = try XCTUnwrap(
            level.rooms[roomIndex].portals.firstIndex(where: isOpen)
        )
        let open = level.rooms[roomIndex].portals[openIndex]
        // A closed duplicate (rendered, not fly-through) before it.
        var closed = open
        closed.flags = (closed.flags | 1) & ~2
        level.rooms[roomIndex].portals.insert(closed, at: 0)
        level = level.withLoadedBOATables()
        for room in level.rooms.indices {
            for index in level.rooms[room].portals.indices {
                level.rooms[room].portals[index].flags &= ~4
            }
        }
        level.rooms[roomIndex].portals[0].pathPoint =
            level.rooms[roomIndex].portals[openIndex + 1].pathPoint
                + Vector3(x: 50, y: 0, z: 0)
        let world = GameWorld(level: level)
        let from = level.rooms[roomIndex].sourceIndex
        let nodes = try XCTUnwrap(world.boaPortalNodes(
            [from, open.connectedRoom], level: level
        ))
        XCTAssertEqual(nodes.map(\.position),
                       [level.rooms[roomIndex].portals[openIndex + 1]
                        .pathPoint])
    }

    /// BOA_GetNextRoom over the tables MakeBOA makes for a level without
    /// stored ones: a route across an open portal (not rendered, or
    /// rendered fly-through; BOA.cpp:259) passes each portal's path point
    /// (architecture.md section 9).
    func testBOARouteCrossesPortalPathPoints() throws {
        let level = makeTrainingManeuverFollowLevel()
        let world = GameSession(level: level, presentationReadyTimestamp: 0)
            .world
        func isOpen(_ portal: LevelPortal) -> Bool {
            (portal.flags & 1 == 0 || portal.flags & 2 != 0)
                && portal.flags & 32 == 0
                && level.rooms.contains { $0.sourceIndex == portal.connectedRoom }
        }

        let room = try XCTUnwrap(level.rooms.first {
            $0.portals.contains(where: isOpen)
        })
        let portal = try XCTUnwrap(room.portals.first(where: isOpen))
        let rooms = try XCTUnwrap(world.boaRoomRoute(
            from: room.sourceIndex, to: portal.connectedRoom, level: level
        ))
        XCTAssertEqual(rooms, [room.sourceIndex, portal.connectedRoom])
        XCTAssertNil(world.boaRoomRoute(from: room.sourceIndex, to: -5,
                                        level: level))
    }

    /// The boundary node selector takes the direction to each node with
    /// vm_NormalizeVector: a start on a node gives the x unit vector, not a
    /// trap.
    func testBoundaryNodeRouteFromANodeDoesNotTrap() throws {
        let base = makeTrainingManeuverFollowLevel()
        let world = GameSession(level: base, presentationReadyTimestamp: 0)
            .world
        let player = world.testPlayerObject
        guard case let .room(room) = player.location else {
            return XCTFail("indoor player")
        }

        let start = player.position
        let node = IndoorNavigationNode(
            position: start,
            edges: [.init(destinationRoomSourceIndex: room,
                          destinationNodeIndex: 0, flags: 0, cost: 1,
                          maximumRadius: 100)]
        )
        let level = replacing(
            base,
            indoorNavigation: .init(
                sourceHighestRoomPlusTerrainRegions: 0, sourceWasVerified: true,
                rooms: [.init(sourceIndex: room, nodes: [node])]
            )
        )
        // An end past a wall blocks the straight line, so the route takes
        // the boundary nodes.
        let directions: [Vector3] = [
            .init(x: 1, y: 0, z: 0), .init(x: -1, y: 0, z: 0),
            .init(x: 0, y: 1, z: 0), .init(x: 0, y: -1, z: 0),
            .init(x: 0, y: 0, z: 1), .init(x: 0, y: 0, z: -1),
        ]
        let end = try XCTUnwrap(directions.map { start + $0 * 5_000 }.first {
            !world.boaProbeIsClear(room: room, start: start, end: $0,
                                   radius: 5, level: level)
        })
        let route = world.boaRoute(
            startRoom: room, start: start,
            startForward: player.orientation.forward, endRoom: room,
            end: end, radius: 5, level: level
        )
        XCTAssertEqual(route?.map(\.position), [start])
    }
}
