import XCTest

// Object table allocation and identity, translated from object.cpp
// ObjAllocate/ObjFree/ObjCreate (:1605-1707), ResetFreeObjects (:3105),
// and ObjGet (:3231).
final class ObjectTableTests: XCTestCase {
    private func create(_ table: inout ObjectTable) throws -> ObjectHandle {
        try XCTUnwrap(table.create(
            type: .robot,
            renderType: .polyobj,
            location: .room(0),
            position: .zero,
            orientation: .init(
                right: .init(x: 1, y: 0, z: 0), up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: 1)
            )
        ))
    }

    func testAllocationTakesLowestFreeSlotAndReusesLastFreedSlotFirst()
        throws
    {
        var table = ObjectTable()
        let first = try create(&table)
        let second = try create(&table)
        let third = try create(&table)
        XCTAssertEqual([first.slot, second.slot, third.slot], [0, 1, 2])
        // ResetObjectList sets Objects[i].handle = i, and ObjCreate adds
        // HANDLE_COUNT_INCREMENT to the slot's previous handle.
        XCTAssertEqual(
            [first.rawValue, second.rawValue, third.rawValue],
            [0x800, 0x801, 0x802]
        )

        table.delete(second)
        table.delete(first)
        // ObjFree pushes onto free_obj_list[--Num_objects], so the slot
        // freed last is allocated first.
        let reusedFirst = try create(&table)
        let reusedSecond = try create(&table)
        let fresh = try create(&table)
        XCTAssertEqual(
            [reusedFirst.slot, reusedSecond.slot, fresh.slot], [0, 1, 3]
        )
        XCTAssertEqual(reusedFirst.rawValue, 0x1000)
        XCTAssertEqual(reusedSecond.rawValue, 0x1001)
        XCTAssertEqual(table.map(\.handle.slot), [0, 1, 2, 3])
        XCTAssertEqual(table.count, 4)
    }

    func testLevelPlacementKeepsStoredSlotsAndAllocatesAroundThem()
        throws
    {
        let position = Vector3(x: 4, y: 5, z: 6)
        let level = replacing(
            makeMinimalCanonicalLevel(),
            objects: [
                PlacedObject.fixture(
                    handle: 0x1003,
                    type: 6,
                    storedID: 0,
                    location: .room(2),
                    position: position,
                    orientation: .init(
                        right: .init(x: 1, y: 0, z: 0),
                        up: .init(x: 0, y: 1, z: 0),
                        forward: .init(x: 0, y: 0, z: 1)
                    )
                ),
            ],
            retiredObjectHandles: [0x2801]
        )
        var table = ObjectTable(level: level)
        XCTAssertEqual(table.map(\.handle), [ObjectHandle(0x1003)])
        XCTAssertEqual(table[ObjectHandle(0x1003)]?.position, position)
        XCTAssertEqual(table[ObjectHandle(0x1003)]?.type, .viewer)

        // LoadLevel places each object at handle & HANDLE_OBJNUM_MASK and
        // restores retired handles. ResetFreeObjects then hands out the
        // lowest free slots in ascending order.
        let a = try create(&table)
        let b = try create(&table)
        let c = try create(&table)
        let d = try create(&table)
        XCTAssertEqual([a.slot, b.slot, c.slot, d.slot], [0, 1, 2, 4])
        XCTAssertEqual(b.rawValue, 0x3001, "retired handle count advances")
        XCTAssertEqual(table.map(\.handle.slot), [0, 1, 2, 3, 4])
    }

    /// ReadObject keeps only OBJECT_SAVE_LOAD_FLAGS (OF_OUTSIDE_MINE) of the
    /// stored flags (LoadLevel.cpp:1660); ObjInit makes the rest:
    /// ObjSetRenderPolyobj's OF_POLYGON_OBJECT (ObjInit.cpp:633) and the
    /// page's OF_DESTROYABLE, OF_AI_DO_DEATH, and OF_FORCE_CEILING_CHECK
    /// (ObjInit.cpp:766-771); ResetPlayerObject assigns the player's
    /// (Player.cpp:2507).
    func testLoadedObjectsTakeTheirFlagsFromObjInitNotTheLevelFile() throws {
        var level = makeTrainingRobotGuidebotLevel()
        let robot = try XCTUnwrap(level.objects.firstIndex { $0.handle == 4_112 })
        // OF_DEAD, OF_ATTACHED, OF_AI_DO_DEATH, OF_USE_DESTROYED_POLYMODEL,
        // and OF_NO_OBJECT_COLLISIONS.
        level.objects[robot] = placed(
            level.objects[robot], flags: 0x2 | 0x10 | 0x40 | 0x4000 | 0x1_0000
        )
        let player = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        level.objects[player] = placed(
            level.objects[player], flags: 0x2 | 0x1_0000
        )
        let world = GameWorld(level: level)
        // The RAS1 page has OIF_DESTROYABLE and OIF_DO_CEILING_CHECK.
        XCTAssertEqual(
            world.objects[ObjectHandle(4_112)]?.flags,
            GameObject.polygonObjectFlag | GameObject.destroyableFlag
                | GameObject.forceCeilingCheckFlag
        )
        XCTAssertEqual(
            world.testPlayerObject.flags,
            GameObject.polygonObjectFlag | GameObject.destroyableFlag
        )
    }

    func testStaleHandleIsRejectedAfterFreeAndReuse() throws {
        var table = ObjectTable()
        let original = try create(&table)
        table[original]?.position = .init(x: 1, y: 2, z: 3)
        XCTAssertEqual(table[original]?.position, .init(x: 1, y: 2, z: 3))

        table.delete(original)
        XCTAssertNil(table[original])
        let reused = try create(&table)
        XCTAssertEqual(reused.slot, original.slot)
        XCTAssertNotEqual(reused, original)
        XCTAssertNil(table[original], "ObjGet rejects a stale signature")
        XCTAssertNotNil(table[reused])

        table[original]?.position = .init(x: 9, y: 9, z: 9)
        table.delete(original)
        XCTAssertEqual(table[reused]?.position, .zero)
        XCTAssertEqual(table.count, 1)
        XCTAssertNil(table[.none])
    }

    func testSignatureCountWrapSkipsTheNeverUsedCount() {
        let last = ObjectHandle(0xffff_f800 | 7)
        let wrapped = last.nextSignature()
        XCTAssertEqual(wrapped.slot, 7)
        XCTAssertEqual(wrapped.rawValue, 0x0000_0807)
        XCTAssertEqual(
            ObjectHandle(0xffff_f000 | 7).nextSignature().rawValue, 0xffff_f807
        )
    }

    func testFullTableRefusesAllocation() throws {
        var table = ObjectTable()
        for _ in 0..<ObjectTable.capacity {
            _ = try create(&table)
        }
        XCTAssertNil(table.create(
            type: .robot,
            renderType: .none,
            location: .room(0),
            position: .zero,
            orientation: .init(
                right: .init(x: 1, y: 0, z: 0), up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: 1)
            )
        ))
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
}

/// The placed object with other stored flags.
private func placed(_ object: PlacedObject, flags: UInt32) -> PlacedObject {
    PlacedObject.fixture(
        handle: object.handle, type: object.type, storedID: object.storedID,
        definition: object.definition, name: object.instanceName, flags: flags,
        doorShields: object.doorShields, location: object.location,
        position: object.position, orientation: object.orientation,
        containsType: object.containsType, containsID: object.containsID,
        containsCount: object.containsCount, lifeLeft: object.lifeLeft,
        soundSource: object.soundSource,
        inertScriptName: object.inertScriptName,
        inertModuleName: object.inertModuleName,
        lightmapSubmodels: object.lightmapSubmodels
    )
}
