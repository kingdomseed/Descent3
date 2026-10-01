import XCTest

// The player's inventory (Descent3/Inventory.cpp) and the level goals
// (Descent3/levelgoal.cpp) on synthetic worlds: AddObject (:393), Use
// (:678) with its CONTINUE_DEFAULT removal (:819-821), UseInventoryItem
// (:1485), RemoveNode and ValidatePos (:908, :1393), ObjDeleteDead's goal
// inform and inventory removal (object.cpp:2004-2011), and
// levelgoals::InitLevel (:1146), Inform (:1220), GetStatus and
// GoalComplete (:390, :189), and DoFrame (:1067).
final class InventoryLevelGoalTests: XCTestCase {
    private let monitor = ObjectHandle(6_167)

    /// The Camera Monitor fixture with no level module: its one goal
    /// ("Locate the Camera Monitor", LGF_ENABLED | LGF_COMP_DESTROY) names
    /// the monitor, whose page has OIF_INVEN_SELECTABLE and
    /// OIF_INVEN_NOREMOVE.
    private func world(_ level: Level = makeTrainingCameraMonitorLevel())
        -> (GameWorld, Level)
    {
        (GameWorld(level: level), level)
    }

    private func player(_ world: GameWorld) -> ObjectHandle {
        world.testPlayerObject.handle
    }

    func testAddObjectInformsTheGoalGhostsTheObjectAndSelectsIt() throws {
        var (world, level) = world()
        XCTAssertNotEqual(
            (world.objects[monitor]?.flags ?? 0)
                & GameObject.informDestroyToLevelGoalsFlag,
            0
        )

        XCTAssertTrue(world.inventoryAddObject(
            player(world),
            item: monitor,
            flags: PlayerInventory.AddFlag.notSpewable,
            level: level
        ))

        XCTAssertEqual(world.goals[0].status, 1_036)
        XCTAssertEqual(world.goals[0].items.map(\.done), [true])
        XCTAssertEqual(world.presentationRequests, [
            .hudMessage("Completed Locate the Camera Monitor"),
            .sound(name: "GoalComplete", volume: 1),
        ])
        let object = try XCTUnwrap(world.objects[monitor])
        XCTAssertEqual(object.type, .dummy)
        XCTAssertNotEqual(object.flags & GameObject.inPlayerInventoryFlag, 0)
        let item = try XCTUnwrap(world.playerInventory.selectedItem)
        XCTAssertEqual(item.object, monitor)
        XCTAssertEqual(item.type, ObjectType.powerup.rawValue)
        XCTAssertEqual(
            item.itemFlags,
            PlayerInventory.ItemFlag.object
                | PlayerInventory.ItemFlag.selectable
                | PlayerInventory.ItemFlag.noRemoveOnUse
                | PlayerInventory.ItemFlag.notSpewable
        )

        // A completed goal does not complete again.
        world.presentationRequests = []
        world.levelGoalsInform(
            type: LevelGoalItemType.object,
            completion: LevelGoalFlag.completeDestroy,
            handle: Int32(bitPattern: monitor.rawValue),
            level: level
        )
        XCTAssertTrue(world.presentationRequests.isEmpty)
        // An object that is not a player gets nothing.
        XCTAssertFalse(world.inventoryAddObject(
            monitor,
            item: ObjectHandle(6_183),
            flags: 0,
            level: level
        ))
    }

    /// The item leaves only when the use's scripts return CONTINUE_DEFAULT;
    /// the monitor's OIF_INVEN_NOREMOVE keeps its object, which loses
    /// OF_INPLAYERINVENTORY and stays a ghost.
    func testUseRemovesAnObjectItemWhenTheScriptsContinueDefault() throws {
        var (world, level) = world()
        world.inventoryAddObject(
            player(world),
            item: monitor,
            flags: 0,
            level: level
        )

        XCTAssertTrue(world.useInventoryItem(level: level))

        XCTAssertTrue(world.playerInventory.items.isEmpty)
        XCTAssertNil(world.playerInventory.position)
        let object = try XCTUnwrap(world.objects[monitor])
        XCTAssertEqual(object.type, .dummy)
        XCTAssertEqual(object.flags & GameObject.inPlayerInventoryFlag, 0)
        XCTAssertEqual(object.flags & GameObject.deadFlag, 0)
        XCTAssertFalse(world.useInventoryItem(level: level))
    }

    /// A type and id item (the Guide-Bot in the ship) makes an object of
    /// its page at the player and sends it EVT_USE (Inventory.cpp:782-806).
    /// GuideBot::DoUse (AIGame.cpp:5590) re-inits the player's Guide-Bot,
    /// which leaves the ship, and returns its result: the item leaves the
    /// inventory, and the used object dies.
    func testUsingTheGuideBotItemReleasesTheGuideBot() throws {
        let level = makeGuideBotGoalLevel()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        let page = session.world.objectFindID("GuideBot", level: level)
        XCTAssertTrue(session.world.playerInventory.checkItem(
            type: ObjectType.robot.rawValue,
            id: page
        ))
        XCTAssertEqual(
            session.world.testGuideBot?.mode,
            GuideBotScript.inShipMode
        )

        _ = session.update(at: 0.1, input: .init(usesInventory: true))

        XCTAssertFalse(session.world.playerInventory.checkItem(
            type: ObjectType.robot.rawValue,
            id: page
        ))
        XCTAssertEqual(
            session.world.testGuideBot?.mode,
            GuideBotScript.birthMode
        )
        // Only the Guide-Bot itself has the GuideBot page.
        XCTAssertEqual(
            session.world.objects.filter { $0.info == page }.count,
            1
        )
    }

    /// When the use's scripts drop CONTINUE_DEFAULT the item stays: with no
    /// Guide-Bot, DoUse's EVT_AI_NOTIFY goes nowhere and returns false.
    func testUseKeepsTheItemWhenTheScriptsDropContinueDefault() throws {
        let level = makeGuideBotGoalLevel()
        var world = GameWorld(level: level)
        let page = world.objectFindID("GuideBot", level: level)
        world.buddyHandle = .none

        XCTAssertFalse(world.inventoryUsePosition(level: level))

        XCTAssertTrue(world.playerInventory.checkItem(
            type: ObjectType.robot.rawValue,
            id: page
        ))
        // The used object dies (no OIF_INVEN_NOREMOVE) at the next
        // ObjDeleteDead.
        let used = try XCTUnwrap(world.objects.first {
            $0.info == page && $0.flags & GameObject.deadFlag != 0
        })
        world.objDeleteDead(level: level)
        XCTAssertNil(world.objects[used.handle])
    }

    /// RemoveNode moves a removed selection to the next item, and
    /// ValidatePos skips items that cannot be selected.
    func testRemovingTheSelectedItemSelectsTheNextSelectableItem() {
        var inventory = PlayerInventory()
        inventory.add(type: 7, id: 1, pageFlags: 0x08)
        inventory.add(type: 7, id: 2, pageFlags: 0)
        inventory.add(type: 7, id: 3, pageFlags: 0x08)
        XCTAssertEqual(inventory.position, 2)
        inventory.add(type: 7, id: 2, pageFlags: 0)
        XCTAssertEqual(inventory.items[1].count, 2)
        XCTAssertEqual(inventory.position, 2)

        inventory.remove(type: 7, id: 3)

        // pos->next wraps to the root, which is selectable.
        XCTAssertEqual(inventory.position, 0)
        inventory.remove(type: 7, id: 1)
        // The only item left cannot be selected.
        XCTAssertNil(inventory.position)
        XCTAssertEqual(inventory.items.map(\.id), [2])
        XCTAssertTrue(inventory.isValidSavedState)
    }

    /// ObjDeleteDead informs the goals of a dead OF_INFORM_DESTROY_TO_LG
    /// object and removes a dead object from the inventory, before
    /// EVT_DESTROY (object.cpp:2004-2011).
    func testObjDeleteDeadInformsGoalsAndEmptiesTheInventory() throws {
        var (world, level) = world()
        world.objects[monitor]?.flags |= GameObject.deadFlag

        world.objDeleteDead(level: level)

        XCTAssertNil(world.objects[monitor])
        XCTAssertEqual(world.goals[0].status, 1_036)

        var (held, _) = self.world()
        held.inventoryAddObject(player(held), item: monitor, flags: 0,
                                level: level)
        held.objects[monitor]?.flags |= GameObject.deadFlag
        held.objDeleteDead(level: level)
        XCTAssertNil(held.objects[monitor])
        XCTAssertTrue(held.playerInventory.items.isEmpty)
    }

    /// Inform's all-items check reads item j again (levelgoal.cpp:1255),
    /// so a goal completes when its first item is done; each done item
    /// sends EVT_LEVEL_GOAL_ITEM_COMPLETE after the completion.
    func testInformCompletesAGoalOnItsFirstDoneItem() throws {
        var level = makeTrainingCameraMonitorLevel()
        var goal = level.goals[0]
        goal.items.append(.init(
            type: LevelGoalItemType.object,
            sourceHandle: 6_183,
            objectHandle: 6_183,
            done: false
        ))
        level = replacing(level, goals: [goal])
        try level.validate()
        var world = GameWorld(level: level)

        world.levelGoalsInform(
            type: LevelGoalItemType.object,
            completion: LevelGoalFlag.completeDestroy,
            handle: Int32(bitPattern: 6_183),
            level: level
        )

        XCTAssertEqual(world.goals[0].items.map(\.done), [false, true])
        XCTAssertNotEqual(
            world.goals[0].status & LevelGoalFlag.completed,
            0
        )
        // Another completion type does not match the goal.
        var other = GameWorld(level: level)
        other.levelGoalsInform(
            type: LevelGoalItemType.object,
            completion: LevelGoalFlag.completePlayer,
            handle: Int32(bitPattern: 6_183),
            level: level
        )
        XCTAssertEqual(other.goals, GameWorld(level: level).goals)
    }

    /// A trigger goal's trigger gets TF_INFORM_ACTIVATE_TO_LG at
    /// InitLevel, and the trigger's activation informs the goals
    /// (trigger.cpp:254).
    func testTriggerActivationCompletesItsGoal() throws {
        var level = makeTrainingKillbotEntryLevel()
        let trigger = try XCTUnwrap(level.triggers.firstIndex {
            $0.name == "Portal3"
        })
        level.goals = [.init(
            status: LevelGoalFlag.enabled | LevelGoalFlag.completeActivate,
            priority: 0,
            list: 0,
            name: "Enter the KillBot room",
            itemName: "",
            description: "",
            completionMessage: "",
            items: [.init(
                type: LevelGoalItemType.trigger,
                sourceHandle: UInt32(trigger),
                objectHandle: nil,
                done: false
            )]
        )]
        var world = GameWorld(level: level)
        XCTAssertNotEqual(
            world.triggerFlags[trigger]
                & TriggerFlag.informActivateToLevelGoals,
            0
        )

        world.objCheckTriggers(
            world.testPlayerObject.handle,
            recordedFaces: [.init(roomSourceIndex: 2, faceIndex: 1)],
            level: level
        )

        XCTAssertNotEqual(world.goals[0].status & LevelGoalFlag.completed, 0)
        XCTAssertEqual(
            world.presentationRequests.suffix(2),
            [
                .hudMessage("Completed Enter the KillBot room"),
                .sound(name: "GoalComplete", volume: 1),
            ]
        )
    }

    /// DoFrame marks LF_ALL_PRIMARIES_DONE once no primary goal is active.
    func testDoFrameMarksAllPrimaryGoalsDoneOnce() {
        var (world, level) = world()
        world.levelGoalsDoFrame(level: level)
        XCTAssertEqual(world.levelGoalFlags & LevelGoalsFlag.allPrimariesDone, 0)

        world.levelGoalSetStatus(0, LevelGoalFlag.completed, level: level)
        world.levelGoalsDoFrame(level: level)

        XCTAssertNotEqual(
            world.levelGoalFlags & LevelGoalsFlag.allPrimariesDone,
            0
        )
    }

    /// A goal pending in a save completes after the load; the inventory
    /// and the goal keep their state across a save, and a save with a
    /// stale or out-of-range inventory entry is refused.
    func testPendingGoalAndInventoryContinueAcrossASave() throws {
        let level = makeTrainingCameraMonitorLevel()
        var (pending, _) = world(level)
        pending.presentationRequests = []
        let restoredPending = try GameSession(
            level: level,
            world: JSONDecoder().decode(
                GameWorld.self,
                from: JSONEncoder().encode(pending)
            ),
            resumedAtTimestamp: 10
        )
        XCTAssertEqual(restoredPending.world.goals[0].status, 1_028)
        restoredPending.world.inventoryAddObject(
            player(restoredPending.world),
            item: monitor,
            flags: 0,
            level: level
        )
        XCTAssertEqual(restoredPending.world.goals[0].status, 1_036)
        restoredPending.world.presentationRequests = []

        let data = try JSONEncoder().encode(restoredPending.world)
        let held = try GameSession(
            level: level,
            world: JSONDecoder().decode(GameWorld.self, from: data),
            resumedAtTimestamp: 20
        )
        XCTAssertEqual(held.world.playerInventory, restoredPending.world.playerInventory)

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var inventory = try XCTUnwrap(object["playerInventory"] as? [String: Any])
        inventory["position"] = 3
        object["playerInventory"] = inventory
        let badPosition = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertThrowsError(try badPosition.validate(against: level))

        var stale = restoredPending.world
        stale.objects.delete(monitor)
        XCTAssertThrowsError(try stale.validate(against: level))
    }
}
