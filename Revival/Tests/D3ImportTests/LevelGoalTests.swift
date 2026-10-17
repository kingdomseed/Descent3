import XCTest

// The level goals (Descent3/levelgoal.cpp): InitLevel (:1146), Inform
// (:1220), GetStatus and GoalComplete (:390, :189), and DoFrame (:1067).
final class LevelGoalTests: XCTestCase {
    private func world(_ level: Level = makeTrainingCameraMonitorLevel())
        -> (GameWorld, Level)
    {
        (GameWorld(level: level), level)
    }

    /// Inform's all-items check reads item j again (levelgoal.cpp:1255),
    /// so a goal completes when its first item is done; each done item
    /// sends EVT_LEVEL_GOAL_ITEM_COMPLETE after the completion.
    func testInformCompletesAGoalOnItsFirstDoneItem() throws {
        var level = makeTrainingCameraMonitorLevel()
        var goal = level.goals[0]
        goal.items.append(.init(
            type: LevelGoalItemType.object, sourceHandle: 6_183,
            objectHandle: 6_183, done: false
        ))
        level = replacing(level, goals: [goal])
        try level.validate()
        var world = GameWorld(level: level)

        world.levelGoalsInform(
            type: LevelGoalItemType.object,
            completion: LevelGoalFlag.completeDestroy,
            handle: Int32(bitPattern: 6_183), level: level
        )

        XCTAssertEqual(world.goals[0].items.map(\.done), [false, true])
        XCTAssertNotEqual(world.goals[0].status & LevelGoalFlag.completed, 0)
        // Another completion type does not match the goal.
        var other = GameWorld(level: level)
        other.levelGoalsInform(
            type: LevelGoalItemType.object,
            completion: LevelGoalFlag.completePlayer,
            handle: Int32(bitPattern: 6_183), level: level
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
                type: LevelGoalItemType.trigger, sourceHandle: UInt32(trigger),
                objectHandle: nil, done: false
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
            world.levelGoalFlags & LevelGoalsFlag.allPrimariesDone, 0
        )
    }
}
