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
                right: .init(x: 1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
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
            [reusedFirst.slot, reusedSecond.slot, fresh.slot],
            [0, 1, 3]
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
                PlacedObject(
                    handle: 0x1003,
                    type: 6,
                    storedID: 0,
                    definition: nil,
                    instanceName: nil,
                    flags: 0,
                    doorShields: nil,
                    location: .room(2),
                    position: position,
                    orientation: .init(
                        right: .init(x: 1, y: 0, z: 0),
                        up: .init(x: 0, y: 1, z: 0),
                        forward: .init(x: 0, y: 0, z: 1)
                    ),
                    containsType: 0,
                    containsID: 0,
                    containsCount: 0,
                    lifeLeft: 0,
                    soundSource: nil,
                    inertScriptName: nil,
                    inertModuleName: nil,
                    lightmapSubmodels: []
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
            ObjectHandle(0xffff_f000 | 7).nextSignature().rawValue,
            0xffff_f807
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
                right: .init(x: 1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: 1)
            )
        ))
    }
}
