import XCTest

/// The engine calls around the translated GuideBot and GBPowerup classes:
/// save validation, the source integer widths, the module's own rand(),
/// the BOA path search, the player's contact with a robot, the object
/// EVT_INTERVAL, and the module import checks.
final class GuideBotEngineTests: XCTestCase {
    private func session(_ level: Level = makeGuideBotGoalLevel(),
                         seed: UInt32 = 1) -> GameSession {
        GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
    }

    /// The MSVC C library rand() (holdrand * 214013 + 2531011, bits 16-30)
    /// from `state`: the next `count` values and the state after them.
    private func msvcRand(_ state: UInt32, count: Int) -> ([Int32], UInt32) {
        var state = state
        var values: [Int32] = []
        for _ in 0..<count {
            state = state &* 214_013 &+ 2_531_011
            values.append(Int32((state >> 16) & 0x7fff))
        }
        return (values, state)
    }

    // MARK: Save validation

    /// A saved object_info index out of the level's table is rejected
    /// before the script bindings read the page through it.
    func testLoadRejectsAnOutOfRangeObjectInfoWithoutTrapping() throws {
        let level = makeGuideBotGoalLevel()
        let world = session(level).world
        let helper = try XCTUnwrap(world.testGuideBot?.ambientCamera)
        XCTAssertNotNil(world.objects[helper]?.info)
        for info in [-1, 99_999] {
            var hostile = world
            hostile.objects[helper]?.info = info
            XCTAssertThrowsError(try hostile.validate(against: level))
        }
    }

    // MARK: Source integer widths

    /// Inventory counts are C ints (Inventory.h:233) and the Guide-Bot's
    /// powerup counts are signed chars (AIGame.cpp:1478); the released
    /// MSVC build wraps both.
    func testInventoryAndPowerupCountsWrapAtTheirSourceWidths() throws {
        var inventory = PlayerInventory()
        inventory.add(type: 2, id: 7)
        let encoded = try JSONEncoder().encode(inventory)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var items = try XCTUnwrap(object["items"] as? [[String: Any]])
        items[0]["count"] = Int(Int32.max)
        object["items"] = items
        inventory = try JSONDecoder().decode(
            PlayerInventory.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        inventory.add(type: 2, id: 7)
        XCTAssertEqual(inventory.items.first?.count, Int32.min)
        items[0]["count"] = Int(Int32.max) + 1
        object["items"] = items
        XCTAssertThrowsError(try JSONDecoder().decode(
            PlayerInventory.self,
            from: JSONSerialization.data(withJSONObject: object)
        ))

        let simulation = session()
        let me = simulation.world.buddyHandle
        let helper = try XCTUnwrap(simulation.world.testGuideBot?.ambientCamera)
        simulation.world.updateGuideBot(me) { $0.powerups[1] = 127 }
        GuideBotScript.pickUpPowerup(me, type: 1, it: helper,
                                     &simulation.world, simulation.level)
        XCTAssertEqual(simulation.world.testGuideBot?.powerups[1], -128)
    }

    // MARK: The module's rand()

    /// The module draws from its own C library state, which starts at 1,
    /// not from ps_rand. DoInit in the ship draws nothing (AIGame.cpp:5671);
    /// the release's SetMode(GBM_BIRTH) draws the flare and visibility
    /// times (:4587-4590).
    func testTheModuleRandIsItsOwnCLibraryStream() throws {
        var world = GameWorld(level: makeGuideBotGoalLevel(),
                              authoritativeRandomSeed: 99)
        let psState = world.authoritativeRandomState
        XCTAssertEqual(world.gameModuleRandomState, 1)
        XCTAssertEqual(world.aigameRand(), 41)
        XCTAssertEqual(world.aigameRand(), 18_467)
        XCTAssertEqual(world.authoritativeRandomState, psState)

        func released(seed: UInt32) -> GameSession {
            let simulation = session(seed: seed)
            XCTAssertEqual(simulation.world.gameModuleRandomState, 1)
            var timestamp = 0.0
            simulation.runFrames(
                1,
                from: &timestamp,
                firstInput: .init(deploysTrainingGuidebot: true)
            )
            return simulation
        }
        let simulation = released(seed: 1)
        let (draws, state) = msvcRand(1, count: 2)
        let memory = try XCTUnwrap(simulation.world.testGuideBot)
        XCTAssertEqual(memory.mode, GuideBotScript.birthMode)
        XCTAssertEqual(memory.timeUntilNextFlare,
                       3 + Float(draws[0]) / Float(0x7fff))
        XCTAssertEqual(memory.timeUntilNextPlayerVisibilityCheck,
                       0.5 + 0.5 * (Float(draws[1]) / Float(0x7fff)))
        XCTAssertEqual(simulation.world.gameModuleRandomState, state)
        // A different ps_rand seed does not move the module's draws.
        let other = released(seed: 0x1357_9bdf)
        XCTAssertEqual(other.world.testGuideBot?.timeUntilNextFlare,
                       memory.timeUntilNextFlare)
        XCTAssertEqual(other.world.gameModuleRandomState, state)
    }

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
                    pair = (room.sourceIndex, portal.connectedRoom, index,
                            back)
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

    // MARK: The player's contact with a robot

    /// ENABLE_COLLISION_POLY_SPHERE(OBJ_ROBOT, OBJ_PLAYER) sets both
    /// directions (collide.cpp:2549, :2619): a player who flies into a
    /// waiting Guide-Bot marked for pickup collects it (DoCollide,
    /// AIGame.cpp:5510).
    func testThePlayerCollectsAStationaryGuideBotMarkedForPickup() throws {
        let simulation = session()
        var timestamp = 0.0
        simulation.runToTestGuideBotAmbient()
        timestamp = 3.5
        simulation.runFrames(
            1,
            from: &timestamp,
            firstInput: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertEqual(simulation.world.testGuideBot?.isMarkedForPickup, true)
        // Park it ahead of the player, unable to move.
        let me = simulation.world.buddyHandle
        let player = simulation.world.testPlayerObject
        simulation.world.setAIMaxSpeed(me, 0)
        simulation.world.objects[me]?.position =
            player.position + player.orientation.forward * 40
        simulation.world.objects[me]?.location = player.location
        simulation.world.objects[me]?.velocity = .zero
        simulation.world.objects[me]?.parent = .none
        var entered = false
        for _ in 1...60 {
            let frames = simulation.runFrames(
                1,
                from: &timestamp,
                firstInput: .init(forward: 1)
            )
            if hudMessages(frames).contains("GB: Entering ship!") {
                entered = true
                break
            }
        }
        XCTAssertTrue(entered)
        XCTAssertEqual(simulation.world.testGuideBot?.mode,
                       GuideBotScript.inShipMode)
    }

    // MARK: The object EVT_INTERVAL

    /// Every object's frame ends with its EVT_INTERVAL (object.cpp:2868):
    /// the Guide-Bot's anti-virus conversion runs out after its time
    /// (AIGame.cpp:6150), even while the Guide-Bot is in the ship.
    func testTheAntivirusConversionRunsOutOnTheObjectInterval() throws {
        // The buddy powerup is an AI object; any AI object converts.
        let (level, robot) = makeGuideBotPowerupLevel()
        let simulation = session(level)
        let me = simulation.world.buddyHandle
        XCTAssertNotNil(simulation.world.objects[robot]?.ai)
        simulation.world.aiClearFlags(robot, ObjectAIFrame.teamMask)
        simulation.world.aiSetFlags(robot, ObjectAIFrame.teamRebel)
        let revertTime = simulation.world.gameTime + 0.25
        simulation.world.updateGuideBot(me) {
            $0.antivirusRobots = [robot]
            $0.antivirusRevertTimes = [revertTime]
        }
        var timestamp = 0.0
        simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(simulation.world.testGuideBot?.antivirusRobots, [robot])
        simulation.runFrames(4, from: &timestamp)
        XCTAssertEqual(simulation.world.testGuideBot?.antivirusRobots, [])
        XCTAssertEqual(
            (simulation.world.objects[robot]?.ai?.flags ?? 1)
                & ObjectAIFrame.teamMask,
            ObjectAIFrame.teamPTMC
        )
    }

    /// GBPowerup's EVT_INTERVAL counts down its HUD message time
    /// (AIGame.cpp:8311): a player touching it reads TXT_GB_POWERUP, then
    /// not again until a second of intervals has passed.
    func testTheGuideBotPowerupMessageWaitsOneSecondOfIntervals() throws {
        let (level, powerup) = makeGuideBotPowerupLevel()
        let simulation = session(level)
        let player = simulation.world.testPlayerObject.handle
        let text = AIGame.text(GBPowerupScript.powerupText, level: level)
        var timestamp = 0.0
        func touch() -> Bool {
            simulation.world.collideTwoObjects(player, powerup,
                                               level: simulation.level)
            return hudMessages(simulation.runFrames(1, from: &timestamp))
                .contains(text)
        }
        XCTAssertTrue(touch())
        simulation.runFrames(4, from: &timestamp)
        XCTAssertFalse(touch())
        simulation.runFrames(6, from: &timestamp)
        XCTAssertTrue(touch())
    }

    // MARK: MakeBOA

    /// Real content, opt-in (REVIVAL_TRAINING_PACKAGE): MakeBOA at load
    /// (BOA.cpp:2020), run on the imported Training level without its
    /// stored tables, remakes what the level file stores: the small-portal
    /// flags, the path points, the costs, and each indoor pair's next room,
    /// blockage, sound, and robot flags.
    func testMakeBOARemakesTheStoredTrainingTables() throws {
        guard let path = ProcessInfo.processInfo.environment[
            "REVIVAL_TRAINING_PACKAGE"
        ] else {
            throw XCTSkip("set REVIVAL_TRAINING_PACKAGE to a training.revival")
        }
        let stored = try loadCanonicalLevel(from: URL(fileURLWithPath: path))
        let storedTables = try XCTUnwrap(stored.boaTables)
        // Without the tables, the small-portal flags, and the path points
        // the file stores, so MakeBOA must remake them all.
        var bare = stored
        bare.boaTables = nil
        for room in bare.rooms.indices {
            bare.rooms[room].pathPoint = .zero
            for portal in bare.rooms[room].portals.indices {
                bare.rooms[room].portals[portal].flags &= ~4
                bare.rooms[room].portals[portal].pathPoint = .zero
            }
        }
        let made = bare.madeByMakeBOA()
        let tables = try XCTUnwrap(made.boaTables)
        var mismatches: [String] = []
        for (room, madeRoom) in zip(stored.rooms, made.rooms) {
            for (index, (portal, madePortal)) in zip(
                room.portals, madeRoom.portals
            ).enumerated() {
                if portal.flags & 4 != madePortal.flags & 4 {
                    mismatches.append("small \(room.sourceIndex):\(index)")
                }
                if vectorDistance(portal.pathPoint, madePortal.pathPoint)
                    > 0.01 {
                    mismatches.append("portal point \(room.sourceIndex):\(index)")
                }
                let a = storedTables.cost(room.sourceIndex, index)
                let b = tables.cost(room.sourceIndex, index)
                if abs(a - b) > 0.01 {
                    mismatches.append("cost \(room.sourceIndex):\(index) \(a) \(b)")
                }
            }
            if vectorDistance(room.pathPoint, madeRoom.pathPoint) > 0.01 {
                mismatches.append("room point \(room.sourceIndex)")
            }
        }
        let used = stored.rooms.map(\.sourceIndex)
        let mask: UInt16 = BOATables.roomMask | BOATables.blockageFlag
            | BOATables.tooSmallForRobotFlag | 0x0800
        for i in used {
            for j in used where storedTables.entry(i, j) & mask
                != tables.entry(i, j) & mask {
                mismatches.append(
                    "entry \(i),\(j) \(storedTables.entry(i, j)) \(tables.entry(i, j))"
                )
            }
        }
        XCTAssertEqual(mismatches.count, 0,
                       mismatches.prefix(40).joined(separator: "; "))
    }

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

    /// In single player StartLevel deletes every other player object
    /// (DeleteMultiplayerObjects, Player.cpp:1365; gamesequence.cpp:1572),
    /// so its slot is the next one ObjCreate takes.
    func testTheOtherPlayerObjectsAreDeletedAtLevelStart() throws {
        let level = makeTrainingRASBot1DeathLevel()
        let player = try XCTUnwrap(level.defaultPlayerBinding).objectHandle
        let others = level.objects.filter {
            $0.type == 4 && $0.handle != player
        }
        XCTAssertFalse(others.isEmpty)
        let world = GameWorld(level: level)
        XCTAssertEqual(world.objects.filter { $0.type == .player }.count, 1)
        for other in others {
            XCTAssertNil(world.objects[ObjectHandle(other.handle)])
        }
        XCTAssertEqual(world.objects.freeSlots.last,
                       ObjectHandle(others.last!.handle).slot)
    }

    // MARK: Module import checks

    /// A page the module creates must be in the tables (Obj_FindID); the
    /// package needs it too.
    func testAMissingModuleObjectPageIsAnImportAndPackageError() throws {
        XCTAssertThrowsError(try gameModuleObjectPage(
            "Invisiblepowerup", genericPages: [:]
        )) { error in
            XCTAssertEqual(error as? GameModuleImportError,
                           .unresolvedObject("Invisiblepowerup"))
        }
        var level = makeGuideBotGoalLevel()
        XCTAssertNoThrow(try level.validateGameModules())
        level.objectInfos = level.objectInfos?.filter {
            $0.name != fixtureInvisiblePowerupInfo.name
        }
        XCTAssertThrowsError(try level.validateGameModules())
    }
}

/// The Guide-Bot goal level with a buddyantivirus GBPowerup (handle 4136)
/// beside the player.
func makeGuideBotPowerupLevel() -> (Level, ObjectHandle) {
    var level = makeGuideBotGoalLevel(goalDistance: 300)
    let player = level.objects.first {
        $0.handle == level.defaultPlayerBinding?.objectHandle
    }!
    let antivirus = CanonicalObjectInfo(
        name: "buddyantivirus",
        type: 7,
        flags: 0x3,
        size: 4.732_707_5,
        hitPoints: 100,
        lightDistance: 0,
        lighting: fixtureNoLight,
        ai: fixtureAIInfo(
            flags: 0x0003_0040,
            aiType: 5,
            movementType: 1,
            fov: 0,
            notifyFlags: 0x1ff9_f2a2
        ),
        weaponBatteries: [],
        physics: .init(flags: 0x4, mass: 1, drag: 1, restitution: 1),
        moduleName: "aigame",
        scriptNameOverride: "GBPowerup"
    )
    level = level.addingObjectInfo(antivirus)
    level.objects.append(PlacedObject(
        handle: 4_136,
        type: 7,
        storedID: 300,
        definition: .init(storedIndex: 300, sourceName: "buddyantivirus"),
        instanceName: "GB powerup",
        flags: 0,
        doorShields: nil,
        location: player.location,
        position: player.position
            + player.orientation.forward * 60
            + player.orientation.right * 20,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 4_136,
        primaryModel: level.models[0].source,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil
    ))
    return (level, ObjectHandle(4_136))
}
