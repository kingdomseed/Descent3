// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/Inventory.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): a player's inventory of type and
// id items and object items: Inventory::Add (:502) for a non-weapon type,
// AddObjectItem (:604), AddObject (:393), Use (:678), UsePos (:869),
// Remove (:879), RemoveNode (:908), FindItem (:966), CheckItem (:984),
// GetPosTypeID (:1199), ValidatePos (:1393), UseInventoryItem (:1485), and
// InventoryRemoveObject (:1517). The countermeasures (OBJ_WEAPON items),
// the item names, descriptions, and icons, and the inventory selection keys
// arrive with the HUD and the full inventory (M2 and M4).

/// Players[0].inventory: its items in list order, from `root`. An item
/// added again counts up; Remove counts down and drops the item at 0. An
/// object item (INVF_OBJECT) is one object the player holds.
struct PlayerInventory: Codable, Equatable, Sendable {
    /// MAX_UNIQUE_INVEN_ITEMS (Inventory.h:189).
    static let maximumUniqueItems = 10

    /// INVF_ item flags (Inventory.h:191-198).
    enum ItemFlag {
        /// INVF_SELECTABLE and INVF_USEABLE share 0x0003.
        static let selectable: UInt32 = 0x0003
        static let useable: UInt32 = 0x0003
        static let missionItem: UInt32 = 0x0004
        static let noRemoveOnUse: UInt32 = 0x0008
        static let visibleWhenUsed: UInt32 = 0x0010
        static let object: UInt32 = 0x0020
        static let notSpewable: UInt32 = 0x0040
        static let timeoutOnSpew: UInt32 = 0x0080
    }

    /// INVAF_ add flags (Inventory.h:200-203).
    enum AddFlag {
        static let notSpewable: UInt32 = 0x0001
        static let timeoutOnSpew: UInt32 = 0x0002
        static let levelLast: UInt32 = 0x0004
    }

    struct Item: Codable, Equatable, Sendable {
        /// The OBJ_ type (`otype` of an object item).
        var type: UInt8
        /// The object page (object id; `oid` of an object item).
        var id: Int
        /// `int count` (Inventory.h:233). An object item counts 1.
        var count: Int32
        /// `iflags`: the INVF_ flags.
        var itemFlags: UInt32 = 0
        /// The object an INVF_OBJECT item holds (`type` holds its handle in
        /// the C++). `nil` for a type and id item.
        var object: ObjectHandle? = nil
    }

    private(set) var items: [Item] = []
    /// `pos`: the index of the selected item in `items`, or `nil`.
    private(set) var position: Int?

    /// OIF_ object page flags (objinfo.h:336-340) that set item flags.
    enum PageFlag {
        static let selectable: UInt32 = 0x08
        static let missionItem: UInt32 = 0x20
        static let noRemove: UInt32 = 0x40
        static let visibleWhenUsed: UInt32 = 0x80
    }

    /// The INVF_ flags the page flags and add flags give a new item
    /// (AddObjectItem :640-656 and AddObject :450-466). The OIF_INVEN_
    /// NONUSEABLE test is commented out in the original, so INVF_USEABLE
    /// comes only with INVF_SELECTABLE (the same bits). INVAF_LEVELLAST
    /// sets `INVAF_LEVELLAST` (0x4, the INVF_MISSIONITEM bit) in both.
    private static func itemFlags(pageFlags: UInt32, addFlags: UInt32)
        -> UInt32
    {
        var flags: UInt32 = 0
        if pageFlags & PageFlag.selectable != 0 {
            flags |= ItemFlag.selectable
        }
        if pageFlags & PageFlag.missionItem != 0 {
            flags |= ItemFlag.missionItem
        }
        if pageFlags & PageFlag.noRemove != 0 {
            flags |= ItemFlag.noRemoveOnUse
        }
        if pageFlags & PageFlag.visibleWhenUsed != 0 {
            flags |= ItemFlag.visibleWhenUsed
        }
        if addFlags & AddFlag.notSpewable != 0 {
            flags |= ItemFlag.notSpewable
        }
        if addFlags & AddFlag.timeoutOnSpew != 0 {
            flags |= ItemFlag.timeoutOnSpew
        }
        if addFlags & AddFlag.levelLast != 0 {
            flags |= ItemFlag.missionItem
        }
        return flags
    }

    /// Add and AddObjectItem for a non-weapon type: a new type and id goes
    /// at the end of the list, a known one counts up. A selectable item
    /// becomes the selected one. Returns false when the list is full.
    @discardableResult
    mutating func add(
        type: UInt8,
        id: Int,
        pageFlags: UInt32,
        addFlags: UInt32 = 0
    ) -> Bool {
        guard items.count < Self.maximumUniqueItems else { return false }
        let index: Int
        if let found = findItem(type: type, id: id) {
            // A C int that the released MSVC build wraps.
            items[found].count &+= 1
            index = found
        } else {
            items.append(.init(
                type: type,
                id: id,
                count: 1,
                itemFlags: Self.itemFlags(
                    pageFlags: pageFlags,
                    addFlags: addFlags
                )
            ))
            index = items.count - 1
        }
        if items[index].itemFlags & ItemFlag.selectable != 0 {
            position = index
        }
        return true
    }

    /// AddObject (:393) after its checks: a new INVF_OBJECT item for the
    /// object at the end of the list. Returns false when the list is full.
    @discardableResult
    mutating func addObject(
        _ handle: ObjectHandle,
        type: UInt8,
        id: Int,
        pageFlags: UInt32,
        addFlags: UInt32
    ) -> Bool {
        guard items.count < Self.maximumUniqueItems else { return false }
        items.append(.init(
            type: type,
            id: id,
            count: 1,
            itemFlags: ItemFlag.object
                | Self.itemFlags(pageFlags: pageFlags, addFlags: addFlags),
            object: handle
        ))
        if items[items.count - 1].itemFlags & ItemFlag.selectable != 0 {
            position = items.count - 1
        }
        return true
    }

    /// FindItem (:966) for a type and id item.
    func findItem(type: UInt8, id: Int) -> Int? {
        items.firstIndex {
            $0.object == nil && $0.type == type && $0.id == id
        }
    }

    /// FindItem (:966) for an object item (type = the handle, id = -1).
    func findObjectItem(_ handle: ObjectHandle) -> Int? {
        items.firstIndex { $0.object == handle }
    }

    /// CheckItem (:984) for a type and id item.
    func checkItem(type: UInt8, id: Int) -> Bool {
        findItem(type: type, id: id) != nil
    }

    /// CheckItem (:984) for an object item.
    func checkObjectItem(_ handle: ObjectHandle) -> Bool {
        findObjectItem(handle) != nil
    }

    /// The selected item (GetPosTypeID), or `nil` when there is none.
    var selectedItem: Item? {
        position.map { items[$0] }
    }

    /// Remove (:879) of a type and id item: the item counts down and leaves
    /// the list at 0. Returns false when there is no such item.
    @discardableResult
    mutating func remove(type: UInt8, id: Int) -> Bool {
        guard let index = findItem(type: type, id: id) else { return false }
        items[index].count &-= 1
        if items[index].count <= 0 {
            removeNode(index)
        }
        return true
    }

    /// Remove (:879) of an object item: it always leaves the list. The
    /// caller clears the object's OF_INPLAYERINVENTORY.
    @discardableResult
    mutating func removeObject(_ handle: ObjectHandle) -> Bool {
        guard let index = findObjectItem(handle) else { return false }
        removeNode(index)
        return true
    }

    /// RemoveNode (:908): a selected item passes the selection on to the
    /// next item in the circular list, then ValidatePos moves it forward to
    /// a selectable one.
    private mutating func removeNode(_ index: Int) {
        var movesPosition = false
        if let selected = position {
            if selected == index {
                if items.count > 1 {
                    movesPosition = true
                    // pos = pos->next: the next item, wrapping to the root.
                    position = index + 1 < items.count ? index + 1 : 0
                } else {
                    position = nil
                }
            }
        }
        items.remove(at: index)
        if let selected = position, selected > index {
            position = selected - 1
        }
        if movesPosition {
            validatePosition(forward: true)
        }
    }

    /// ValidatePos (:1393): a selection on an item that cannot be selected
    /// moves to the next selectable item in the given direction, or clears.
    private mutating func validatePosition(forward: Bool) {
        guard let start = position,
              items[start].itemFlags & ItemFlag.selectable == 0
        else {
            return
        }
        var node = forward
            ? (start + 1) % items.count
            : (start + items.count - 1) % items.count
        while node != start {
            if items[node].itemFlags & ItemFlag.selectable != 0 {
                position = node
                return
            }
            node = forward
                ? (node + 1) % items.count
                : (node + items.count - 1) % items.count
        }
        position = nil
    }

    /// Whether the saved list keeps the shape the runtime makes.
    var isValidSavedState: Bool {
        items.count <= Self.maximumUniqueItems
            && position.map { items.indices.contains($0) } ?? true
            && items.allSatisfy {
                $0.count > 0
                    && ($0.object == nil
                        || $0.count == 1
                            && $0.itemFlags & ItemFlag.object != 0)
                    && ($0.object != nil
                        || $0.itemFlags & ItemFlag.object == 0)
            }
            && Set(items.compactMap(\.object)).count
                == items.compactMap(\.object).count
    }
}

extension GameWorld {
    /// The object page flags of a page index, or 0.
    func objectPageFlags(_ id: Int, level: Level) -> UInt32 {
        guard let infos = level.objectInfos, infos.indices.contains(id) else {
            return 0
        }
        return infos[id].flags
    }

    /// Inventory::AddObject (:393) for the player: a level goal hears that
    /// the object was taken (OF_INFORM_DESTROY_TO_LG), a ghosted object is
    /// unghosted, the object gets OF_INPLAYERINVENTORY, and then it is
    /// ghosted while the player holds it. Only generic objects go in.
    @discardableResult
    mutating func inventoryAddObjectItem(
        _ handle: ObjectHandle,
        addFlags: UInt32,
        level: Level
    ) -> Bool {
        guard playerInventory.items.count < PlayerInventory.maximumUniqueItems,
              let object = objects[handle]
        else {
            return false
        }
        if object.flags & GameObject.informDestroyToLevelGoalsFlag != 0 {
            levelGoalsInform(
                type: LevelGoalItemType.object,
                completion: LevelGoalFlag.completeDestroy,
                handle: Int32(bitPattern: handle.rawValue),
                level: level
            )
        }
        if objects[handle]?.type == .dummy {
            unghostObject(handle)
        }
        guard let added = objects[handle],
              added.isGeneric,
              let id = added.info
        else {
            return false
        }
        playerInventory.addObject(
            handle,
            type: added.type.rawValue,
            id: id,
            pageFlags: objectPageFlags(id, level: level),
            addFlags: addFlags
        )
        objects[handle]?.flags |= GameObject.inPlayerInventoryFlag
        ghostObject(handle)
        return true
    }

    /// UseInventoryItem (:1485): the selected item is used. Returns false
    /// when nothing is selected.
    @discardableResult
    mutating func useInventoryItem(level: Level) -> Bool {
        guard playerInventory.selectedItem != nil else { return false }
        inventoryUsePosition(level: level)
        return true
    }

    /// Inventory::UsePos (:869) and Use (:678) of a non-weapon item for the
    /// player. An object item uses its object; a type and id item makes a
    /// new object of that page at the player. The object's scripts get
    /// EVT_USE. The item leaves the inventory only when the scripts return
    /// CONTINUE_DEFAULT (:819-821); otherwise an object item's object goes
    /// back in. Unless the item has INVF_NOREMOVEONUSE, the object then
    /// dies. Returns whether the item was used up.
    @discardableResult
    mutating func inventoryUsePosition(level: Level) -> Bool {
        guard let index = playerInventory.position,
              let player = level.defaultPlayerBinding
                .map({ ObjectHandle($0.objectHandle) }),
              let playerObject = objects[player]
        else {
            return false
        }
        let item = playerInventory.items[index]
        guard item.itemFlags & PlayerInventory.ItemFlag.useable != 0 else {
            return false
        }
        let removeOnUse =
            item.itemFlags & PlayerInventory.ItemFlag.noRemoveOnUse == 0
        let visibleWhenCreated =
            item.itemFlags & PlayerInventory.ItemFlag.visibleWhenUsed != 0
        let used: ObjectHandle
        if let handle = item.object {
            // The object already exists.
            guard objects[handle] != nil else { return false }
            objects[handle]?.flags &= ~GameObject.inPlayerInventoryFlag
            if visibleWhenCreated {
                unghostObject(handle)
            }
            used = handle
        } else {
            guard case let .room(room) = playerObject.location,
                  let type = ObjectType(rawValue: item.type),
                  let created = createInventoryObject(
                      type: type,
                      id: item.id,
                      room: room,
                      position: playerObject.position,
                      parent: player,
                      visibleWhenCreated: visibleWhenCreated,
                      level: level
                  )
            else {
                return false
            }
            used = created
        }
        // Osiris_CallEvent can delete the item (GuideBot::SetMode
        // GBM_BIRTH), so the item is found again by its type and id.
        let usedUp = osirisCallEvent(used, .use(it: player), level: level)
        if usedUp {
            if let handle = item.object {
                if playerInventory.removeObject(handle) {
                    objects[handle]?.flags &= ~GameObject.inPlayerInventoryFlag
                }
            } else {
                playerInventory.remove(type: item.type, id: item.id)
            }
        } else if item.object != nil {
            objects[used]?.flags |= GameObject.inPlayerInventoryFlag
        }
        if removeOnUse {
            objects[used]?.flags |= GameObject.deadFlag
        }
        return usedUp
    }

    /// The object Use makes for a type and id item (:782-801): ObjCreate at
    /// the player, with the player as parent. Unless the item is visible
    /// when used, a non-AI object gets CT_NONE, and every one gets MT_NONE
    /// and RT_NONE. Its flags become the item's (0), and then
    /// InitObjectScripts binds its scripts.
    private mutating func createInventoryObject(
        type: ObjectType,
        id: Int,
        room: Int,
        position: Vector3,
        parent: ObjectHandle,
        visibleWhenCreated: Bool,
        level: Level
    ) -> ObjectHandle? {
        guard [.robot, .powerup, .clutter, .building].contains(type),
              let infos = level.objectInfos,
              infos.indices.contains(id),
              let created = createGenericObject(
                  infoIndex: id,
                  info: infos[id],
                  roomSourceIndex: room,
                  position: position,
                  orientation: Self.identityOrientation,
                  level: level
              )
        else {
            return nil
        }
        objects[created]?.parent = parent
        if !visibleWhenCreated {
            objects[created]?.usesPhysics = false
            objects[created]?.physics = nil
            objects[created]?.renderType = .none
        }
        objects[created]?.flags = 0
        initObjectScripts(created, level: level)
        return created
    }

    /// InventoryRemoveObject (:1517): an object that dies in the player's
    /// inventory leaves it.
    mutating func inventoryRemoveObject(_ handle: ObjectHandle) {
        guard let object = objects[handle],
              object.flags & GameObject.inPlayerInventoryFlag != 0,
              playerInventory.checkObjectItem(handle)
        else {
            return
        }
        playerInventory.removeObject(handle)
        objects[handle]?.flags &= ~GameObject.inPlayerInventoryFlag
    }
}
