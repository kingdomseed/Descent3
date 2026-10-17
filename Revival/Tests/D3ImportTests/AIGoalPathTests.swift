import XCTest

// The goal types, enablers, dynamic paths, and BOA room routes that the
// AIGame scripts use (AIGoal.cpp GoalAddGoal :941, GoalDoFrame :606,
// GoalIsGoalEnabled :1409; aipath.cpp AIPathAllocPath :977; AImain.cpp
// ai_move :4529), on the synthetic maneuver level with FollowBot1, a flyer.
final class AIGoalPathTests: XCTestCase {
    /// A session with FollowBot1 awake, goal-free, and `offset` from the
    /// player in the player's room.
    private func followBotSession(
        offset: Vector3
    ) throws -> (GameSession, ObjectHandle, Level) {
        let level = makeTrainingManeuverFollowLevel()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        let bot = level.findObjectName("FollowBot1")
        session.world.aAISetState(1, bot)
        session.world.goalClearAll(bot, level: level)
        let player = session.world.testPlayerObject
        var object = try XCTUnwrap(session.world.objects[bot])
        object.location = player.location
        object.position = player.position + offset
        object.velocity = .zero
        // A persistent object runs its goals at any awareness
        // (AImain.cpp:6121).
        object.ai?.flags |= ObjectAIFrame.persistentFlag
        session.world.objects[bot] = object
        return (session, bot, level)
    }

    private func run(_ session: GameSession, frames: Int,
                     from start: inout Double) {
        for _ in 0..<frames {
            start += 0.1
            _ = session.update(at: start, input: .zero)
        }
    }

    /// GoalAddGoal(AIG_GET_TO_POS) keeps the position and room, marks the
    /// goal GF_CIRCLE_POS (AIGoal.cpp:1195-1199), and gives it a path
    /// (AIPathAllocPath): a clear straight line is a path of the end point
    /// only. The flyer then moves to it, and GoalDoFrame completes the goal
    /// at its circle distance (COMPLETEATPOS, AIGoal.cpp:694).
    func testGetToPositionPathsMovesAndCompletes() throws {
        let (session, bot, level) = try followBotSession(
            offset: .init(x: 0, y: 0, z: 0)
        )
        let player = session.world.testPlayerObject
        guard case let .room(room) = player.location else {
            return XCTFail("indoor player")
        }

        let start = try XCTUnwrap(session.world.objects[bot]).position
        let target = start + player.orientation.forward * 15
        let slot = session.world.goalAddGoal(
            bot, type: AIGoal.getToPositionType, .position(target, room: room),
            level: 1, flags: AIGoal.notifiesFlag, guid: 77, world: level
        )
        XCTAssertEqual(slot, 1)
        let goal = try XCTUnwrap(session.world.objects[bot]?.ai?.goals[1])
        XCTAssertEqual(goal.guid, 77)
        XCTAssertNotEqual(goal.flags & AIGoal.circlePositionFlag, 0)
        XCTAssertEqual(goal.roomSourceIndex, room)
        session.world.objects[bot]?.ai?.goals[1].circleDistance = 2

        var time = 0.0
        run(session, frames: 1, from: &time)
        let path = try XCTUnwrap(session.world.objects[bot]?.ai?.path)
        XCTAssertEqual(path.numberOfPaths, 1)
        XCTAssertEqual(path.dynamicNodes.last?.position, target)
        XCTAssertEqual(path.goalIndex, 1)

        run(session, frames: 40, from: &time)
        let moved = try XCTUnwrap(session.world.objects[bot])
        XCTAssertLessThan(vectorDistance(moved.position, target),
                          vectorDistance(start, target))
        XCTAssertEqual(moved.ai?.goals[1].used, false)
        XCTAssertEqual(moved.ai?.path.numberOfPaths, 0)
    }

    /// An object goal needs its object to exist (GoalIsGoalEnabled,
    /// AIGoal.cpp:1420-1437; a ghosted object is OBJ_DUMMY, not the
    /// OBJ_GHOST it tests, so it stays a goal), and an AIE_GT_AWARENESS
    /// enabler holds only above its awareness (:1476).
    func testObjectGoalAndEnablersDecideTheCurrentGoal() throws {
        let (session, bot, level) = try followBotSession(
            offset: .init(x: 0, y: 5, z: 0)
        )
        let player = level.findObjectName("DodgeTurrett")
        session.world.goalAddGoal(
            bot, type: AIGoal.getToObjectType, .object(player), level: 2,
            world: level
        )
        XCTAssertEqual(session.world.goalGetCurrentGoal(bot, level: level), 2)
        XCTAssertNotEqual(
            session.world.objects[bot]!.ai!.goals[2].flags
                & AIGoal.circleObjectFlag, 0
        )
        session.world.ghostObject(player)
        XCTAssertEqual(session.world.goalGetCurrentGoal(bot, level: level), 2)
        session.world.unghostObject(player)
        var gone = session.world
        gone.objects.delete(player)
        XCTAssertNil(gone.goalGetCurrentGoal(bot, level: level))

        XCTAssertEqual(session.world.goalAddEnabler(
            bot, goalIndex: 2, type: AIGoalEnabler.greaterAwareness,
            value: 50, percent: 1, interval: 0
        ), 0)
        session.world.objects[bot]?.ai?.awareness = 40
        XCTAssertNil(session.world.goalGetCurrentGoal(bot, level: level))
        session.world.objects[bot]?.ai?.awareness = 60
        XCTAssertEqual(session.world.goalGetCurrentGoal(bot, level: level), 2)
        // The AIDoFreud emotion enablers arrive in M2.
        XCTAssertEqual(session.world.goalAddEnabler(
            bot, goalIndex: 2, type: AIGoalEnabler.fear,
            value: 0.5, percent: 1, interval: 0
        ), -1)
    }

    /// AIG_MOVE_RELATIVE_OBJ_VEC with GST_NEG_FVEC (toward) moves the object
    /// to the point in front of the goal object at the circle distance
    /// (move_relative_object_vec, AImain.cpp:1802).
    func testMoveRelativeObjectVectorGoesInFrontOfTheObject() throws {
        let (session, bot, level) = try followBotSession(
            offset: .init(x: 0, y: 0, z: 0)
        )
        let player = session.world.testPlayerObject
        var botObject = try XCTUnwrap(session.world.objects[bot])
        botObject.position = player.position - player.orientation.forward * 10
        session.world.objects[bot] = botObject
        session.world.goalAddGoal(
            bot, type: AIGoal.moveRelativeObjectVectorType,
            .object(player.handle), level: 0,
            flags: AIGoal.keepAtCompletionFlag,
            subtype: AIGoal.negativeForwardSubtype, world: level
        )
        session.world.objects[bot]?.ai?.goals[0].circleDistance = 4
        var time = 0.0
        run(session, frames: 30, from: &time)
        let moved = try XCTUnwrap(session.world.objects[bot])
        let playerNow = session.world.testPlayerObject
        XCTAssertGreaterThan(
            dot(moved.position - playerNow.position,
                playerNow.orientation.forward),
            0
        )
    }

    /// A world saved on a dynamic path loads (the path nodes are checked at
    /// load) and continues exactly like the uninterrupted world.
    func testSaveContinuationMidRoute() throws {
        let (session, bot, level) = try followBotSession(
            offset: .init(x: 0, y: 0, z: 0)
        )
        let player = session.world.testPlayerObject
        guard case let .room(room) = player.location else {
            return XCTFail("indoor player")
        }

        let target = session.world.objects[bot]!.position
            + player.orientation.forward * 30
        session.world.goalAddGoal(
            bot, type: AIGoal.getToPositionType,
            .position(target, room: room), level: 1, world: level
        )
        var time = 0.0
        run(session, frames: 3, from: &time)
        XCTAssertEqual(session.world.objects[bot]?.ai?.path.isDynamic, true)
        let data = try JSONEncoder().encode(session.world)
        let restored = try GameSession(
            level: level,
            world: JSONDecoder().decode(GameWorld.self, from: data),
            resumedAtTimestamp: time
        )
        var restoredTime = time
        run(session, frames: 10, from: &time)
        run(restored, frames: 10, from: &restoredTime)
        XCTAssertEqual(restored.world, session.world)
    }

    /// AIInit ends with GoalInitTypeGoals (AImain.cpp:3799): an Evader1
    /// flyer starts with its relative-movement goal in slot 1 and, with a
    /// circle distance, a get-around blend goal at 0.55 of it
    /// (AIGoal.cpp:1340-1360).
    func testEvaderFlyerStartsWithItsTypeGoals() throws {
        let level = makeTrainingManeuverFollowLevel()
        let world = GameSession(level: level, presentationReadyTimestamp: 0)
            .world
        let ai = try XCTUnwrap(
            world.objects[level.findObjectName("FollowBot1")]?.ai
        )
        XCTAssertEqual(ai.aiType, ObjectAIFrame.evader1Type)
        XCTAssertEqual(ai.goals[1].type, AIGoal.moveRelativeObjectType)
        XCTAssertNotEqual(ai.goals[1].flags & AIGoal.objectIsTargetFlag, 0)
        XCTAssertEqual(ai.goals[1].enablers.map(\.type), [
            AIGoalEnabler.greaterAwareness,
            AIGoalEnabler.lessOrEqualLastSeeTargetInterval,
        ])
        XCTAssertEqual(ai.goals[4].type, AIGoal.getAroundObjectType)
        XCTAssertEqual(ai.goals[4].circleDistance, ai.circleDistance * 0.55)
    }

    /// AiGoalAvoid (AImain.cpp:4075) normalizes with vm_NormalizeVector,
    /// which turns a zero vector into the x unit vector
    /// (vecmat/vector.cpp:175): a friend at the same point pushes along x.
    /// A ghosted friend (OBJ_DUMMY) is not in the near list
    /// (findintersection.cpp:2237).
    func testAvoidingACoincidentFriendUsesTheUnitXFallback() throws {
        let (session, bot, level) = try followBotSession(
            offset: .init(x: 0, y: 0, z: 0)
        )
        let turret = level.findObjectName("DodgeTurrett")
        var friend = try XCTUnwrap(session.world.objects[turret])
        let botObject = try XCTUnwrap(session.world.objects[bot])
        friend.location = botObject.location
        friend.position = botObject.position
        friend.usesPhysics = true
        session.world.objects[turret] = friend
        session.world.objects[bot]?.ai?.flags |=
            ObjectAIFrame.autoAvoidFriendsFlag
        var ghosted = session.world
        var time = 0.0
        run(session, frames: 1, from: &time)
        let direction = try XCTUnwrap(
            session.world.objects[bot]?.ai?.movementDirection
        )
        XCTAssertEqual(direction, Vector3(x: 1, y: 0, z: 0))

        ghosted.ghostObject(turret)
        let ghostSession = try GameSession(
            level: level, world: ghosted, resumedAtTimestamp: 0
        )
        var ghostTime = 0.0
        run(ghostSession, frames: 1, from: &ghostTime)
        XCTAssertEqual(
            ghostSession.world.objects[bot]?.ai?.movementDirection, .zero
        )
    }

    /// A page may give a circle distance of 0 (the Evader2 get-around goal
    /// takes it as is, AIGoal.cpp:1331). ai_move then divides 0 by 0 for
    /// an object at the goal (AImain.cpp:4649); the NaN direction fails
    /// vm_NormalizeVector's `mag > 0` (vecmat/vector.cpp:175), so the move
    /// takes a random direction (AImain.cpp:4980-4983). The world stays
    /// finite and saves; a non-finite circle distance is refused.
    func testZeroCircleGetAroundGoalMovesRandomlyAndSaves() throws {
        let (session, bot, level) = try followBotSession(
            offset: .init(x: 0, y: 0, z: 0)
        )
        let slot = session.world.goalAddGoal(
            bot, type: AIGoal.getAroundObjectType,
            .object(session.world.testPlayerObject.handle),
            level: GameWorld.activationBlendLevel, world: level
        )
        session.world.objects[bot]?.ai?.goals[slot].circleDistance = 0
        var time = 0.0
        run(session, frames: 2, from: &time)
        let direction = try XCTUnwrap(
            session.world.objects[bot]?.ai?.movementDirection
        )
        XCTAssertTrue(direction.x.isFinite && direction.y.isFinite
                      && direction.z.isFinite)
        XCTAssertEqual(sqrt(dot(direction, direction)), 1, accuracy: 1e-4)
        XCTAssertNoThrow(try GameSession(
            level: level, world: session.world, resumedAtTimestamp: time
        ))
        session.world.objects[bot]?.ai?.goals[slot].circleDistance = .nan
        XCTAssertThrowsError(try GameSession(
            level: level, world: session.world, resumedAtTimestamp: time
        ))
    }

    /// AIObjFriend (AImain.cpp:5637-5643): besides ObjectsAreRelated, an
    /// object and its direct parent or child are friends with no time
    /// limit.
    func testAIObjFriendKeepsDirectParentLinks() throws {
        let level = withTrainingGuideBot(makeTrainingGuidebotYellowFlareLevel())
        var world = GameWorld(level: level)
        let me = world.buddyHandle
        let player = world.testPlayerObject
        world.objects[me]?.ai?.flags &= ~ObjectAIFrame.teamMask
        world.objects[me]?.ai?.flags |= ObjectAIFrame.teamPTMC
        world.objects[me]?.parent = player.handle
        world.gameTime = 10
        let buddy = try XCTUnwrap(world.objects[me])
        XCTAssertFalse(world.objectsAreRelated(buddy, player, level: level))
        XCTAssertTrue(world.aiObjFriend(buddy, player, level: level))
        world.objects[me]?.parent = .none
        XCTAssertFalse(world.aiObjFriend(
            try XCTUnwrap(world.objects[me]), player, level: level
        ))
    }

    /// AIGoalFollowPathSimple with GF_PATH_CIRCLE_AT_END (the flags of
    /// Script 023, TrainingMission.cpp:1523) moves the object to each node
    /// of the path in order and back to node 0 after the last node
    /// (AIPathMoveTurnTowardsNode, aipath.cpp:332).
    func testFollowPathGoalVisitsTheNodesInOrderAndCircles() throws {
        let (session, followBot) = try syntheticPathSession()
        session.world.aAISetState(1, followBot)
        session.world.aAIGoalFollowPathSimple(
            followBot, 0, 9_437_444, 0, 3, level: session.level
        )
        var visited: [Int] = []
        var timestamp = 0.0
        for _ in 0..<600 {
            timestamp += 0.05
            _ = session.update(at: timestamp, input: .zero)
            let node = try XCTUnwrap(
                session.world.objects[followBot]?.ai?.path.currentNode
            )
            if visited.last != node { visited.append(node) }
            if visited.count >= 5 { break }
        }
        XCTAssertEqual(visited, [0, 1, 2, 3, 0])
        let goal = try XCTUnwrap(session.world.objects[followBot]?.ai?.goals[3])
        XCTAssertTrue(goal.used)
        XCTAssertEqual(goal.type, AIGoal.followPathType)
    }

    /// Without GF_PATH_CIRCLE_AT_END or GF_KEEP_AT_COMPLETION, the end of
    /// the path completes the goal: GoalPathComplete clears it with
    /// AIN_GOAL_COMPLETE (AIGoal.cpp GoalClearGoal), which frees the slot.
    func testFollowPathGoalWithoutCircleCompletesAndClears() throws {
        let (session, followBot) = try syntheticPathSession()
        session.world.aAISetState(1, followBot)
        session.world.aAIGoalFollowPathSimple(
            followBot, 0, 0x1100, 0, 3, level: session.level
        )
        XCTAssertNotNil(activeFollowPath(session.world, followBot.rawValue))
        var timestamp = 0.0
        for _ in 0..<600
        where activeFollowPath(session.world, followBot.rawValue) != nil {
            timestamp += 0.05
            _ = session.update(at: timestamp, input: .zero)
        }
        XCTAssertNil(activeFollowPath(session.world, followBot.rawValue))
        let end = session.level.paths[0].nodes[3].position
        let position = try XCTUnwrap(session.world.objects[followBot]?.position)
        XCTAssertLessThan(sqrt(dot(position - end, position - end)), 10)
    }
}
