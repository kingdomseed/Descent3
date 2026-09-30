// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/Inventory.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): the type and id items of a
// player's inventory: Inventory::Add (:502) for a non-weapon type,
// AddObjectItem (:604), Remove (:879), RemoveNode (:908), FindItem
// (:966), and CheckItem (:984). The object items, the countermeasures,
// Use, the selected position, and the item names and icons arrive with the
// inventory in M1 step 9; the Guide-Bot is the only item before then.

/// Players[0].inventory: its type and id items in list order. An item
/// added again counts up; Remove counts down and drops the item at 0.
struct PlayerInventory: Codable, Equatable, Sendable {
    /// MAX_UNIQUE_INVEN_ITEMS (Inventory.h:189).
    static let maximumUniqueItems = 10

    struct Item: Codable, Equatable, Sendable {
        /// The OBJ_ type.
        var type: UInt8
        /// The object page (object id).
        var id: Int
        /// `int count` (Inventory.h:233).
        var count: Int32
    }

    private(set) var items: [Item] = []

    /// Add and AddObjectItem: a new type and id goes at the end of the
    /// list, a known one counts up. Returns false when the list is full.
    @discardableResult
    mutating func add(type: UInt8, id: Int) -> Bool {
        guard items.count < Self.maximumUniqueItems else { return false }
        if let index = items.firstIndex(where: {
            $0.type == type && $0.id == id
        }) {
            // A C int that the released MSVC build wraps.
            items[index].count &+= 1
        } else {
            items.append(.init(type: type, id: id, count: 1))
        }
        return true
    }

    /// Remove: the item counts down and leaves the list at 0. Returns false
    /// when there is no such item.
    @discardableResult
    mutating func remove(type: UInt8, id: Int) -> Bool {
        guard let index = items.firstIndex(where: {
            $0.type == type && $0.id == id
        }) else {
            return false
        }
        items[index].count &-= 1
        if items[index].count <= 0 {
            items.remove(at: index)
        }
        return true
    }

    /// CheckItem.
    func checkItem(type: UInt8, id: Int) -> Bool {
        items.contains { $0.type == type && $0.id == id }
    }
}
