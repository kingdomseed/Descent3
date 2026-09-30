// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/object.cpp: ResetObjectList (:1389),
// ObjAllocate (:1605), ObjFree (:1637), ObjCreate handle signature
// (:1700-1707), ResetFreeObjects (:3105), ObjGet (:3231), and the level-load
// slot placement in Descent3/LoadLevel.cpp (:3847-3922).

import Foundation

/// The fixed object array with its last-freed-first-reused free list.
/// Iteration visits used slots in ascending slot order.
struct ObjectTable: Codable, Equatable, Sendable {
    /// MAX_OBJECTS (`object_external_struct.h:107`).
    static let capacity = 1_500

    /// `Objects[i]`, with `nil` for OBJ_NONE.
    private(set) var slots: [GameObject?]
    /// `Objects[i].handle`. A free slot keeps its last handle, so the next
    /// `ObjCreate` in that slot advances the signature count.
    private(set) var handles: [ObjectHandle]
    /// The free region of `free_obj_list`. The last element is the next slot
    /// that `ObjAllocate` returns, and `ObjFree` appends.
    private(set) var freeSlots: [Int]

    /// An empty table after `ResetObjectList` (`object.cpp:1389`).
    init() {
        slots = Array(repeating: nil, count: Self.capacity)
        handles = (0..<Self.capacity).map { ObjectHandle(UInt32($0)) }
        freeSlots = []
        resetFreeSlots()
    }

    /// The table after the level loader reads CHUNK_OBJECT_HANDLES and
    /// CHUNK_OBJECTS (`LoadLevel.cpp:3847-3922`). Each placed object keeps
    /// its stored handle, so it goes to the slot that handle names.
    init(level: Level) {
        self.init()
        for handle in level.retiredObjectHandles {
            let handle = ObjectHandle(handle)
            handles[handle.slot] = handle
        }
        let visibleHandles = Set(
            level.objectPresentations.filter(\.isVisible).map(\.objectHandle)
        )
        for placed in level.objects {
            let handle = ObjectHandle(placed.handle)
            handles[handle.slot] = handle
            slots[handle.slot] = GameObject(
                handle: handle,
                type: ObjectType(rawValue: placed.type)!,
                renderType: visibleHandles.contains(placed.handle)
                    ? .polyobj
                    : .none,
                location: placed.location,
                position: placed.position,
                orientation: placed.orientation,
                // ReadObject keeps only OBJECT_SAVE_LOAD_FLAGS
                // (OF_OUTSIDE_MINE) of the stored flags (LoadLevel.cpp:1660);
                // ObjInit sets the rest (GameWorld.objInitPlacedObjects).
                flags: placed.flags & GameObject.outsideMineFlag
            )
        }
        resetFreeSlots()
    }

    /// ResetFreeObjects (`object.cpp:3105`): the lowest free slot is
    /// allocated first.
    private mutating func resetFreeSlots() {
        freeSlots = slots.indices.reversed().filter { slots[$0] == nil }
    }

    var count: Int { Self.capacity - freeSlots.count }

    /// ObjGet (`object.cpp:3231`): a handle whose signature no longer matches
    /// its slot returns `nil`.
    subscript(handle: ObjectHandle) -> GameObject? {
        get {
            guard handle != .none,
                  handle.slot < Self.capacity,
                  let object = slots[handle.slot],
                  object.handle == handle
            else {
                return nil
            }
            return object
        }
        set {
            guard handle != .none,
                  handle.slot < Self.capacity,
                  let object = slots[handle.slot],
                  object.handle == handle
            else {
                return
            }
            precondition(newValue.map { $0.handle == handle } ?? true)
            guard let newValue else {
                delete(handle)
                return
            }
            slots[handle.slot] = newValue
        }
    }

    /// ObjAllocate plus the ObjCreate handle step (`object.cpp:1605`,
    /// `:1700-1707`). Returns `nil` when every slot is used.
    mutating func create(
        type: ObjectType,
        renderType: ObjectRenderType,
        location: SpatialLocation,
        position: Vector3,
        orientation: Matrix3
    ) -> ObjectHandle? {
        guard let slot = freeSlots.popLast() else { return nil }
        let handle = handles[slot].nextSignature()
        handles[slot] = handle
        slots[slot] = GameObject(
            handle: handle,
            type: type,
            renderType: renderType,
            location: location,
            position: position,
            orientation: orientation
        )
        return handle
    }

    /// ObjFree (`object.cpp:1637`): the freed slot is the next one reused.
    /// A stale handle does nothing.
    mutating func delete(_ handle: ObjectHandle) {
        guard self[handle] != nil else { return }
        slots[handle.slot] = nil
        freeSlots.append(handle.slot)
    }
}

extension ObjectTable: Sequence {
    struct Iterator: IteratorProtocol {
        fileprivate var base: IndexingIterator<[GameObject?]>

        mutating func next() -> GameObject? {
            while let slot = base.next() {
                if let object = slot { return object }
            }
            return nil
        }
    }

    /// Used objects in ascending slot order.
    func makeIterator() -> Iterator {
        Iterator(base: slots.makeIterator())
    }
}
