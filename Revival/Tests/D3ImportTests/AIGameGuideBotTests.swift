import XCTest

/// The translated GuideBot class (scripts/AIGame.cpp:4517-6855) and its
/// engine: AIInitAll's Guide-Bot (AImain.cpp:3833), the buddy menu's
/// commands, and the object sound loop.
final class AIGameGuideBotTests: XCTestCase {
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

    private func session(_ level: Level = makeGuideBotGoalLevel(),
                         seed: UInt32 = 1) -> GameSession {
        GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
    }

    /// Releases the Guide-Bot on the first frame and runs until it is in
    /// GBM_AMBIENT and its parent link is gone (3 s after its birth).
    private func releasedAmbient(_ session: GameSession,
                                 timestamp: inout Double) {
        session.releaseOrRecallTestGuideBot()
        session.runFrames(35, from: &timestamp)
    }

    /// AIInitAll makes the Guide-Bot at the player, parented to it and
    /// ghosted, as Buddy_handle (AImain.cpp:3833-3839); ResetPlayerObject
    /// puts it in the inventory (Player.cpp:1451); EVT_AI_INIT runs DoInit
    /// (AIGame.cpp:5579): the invisible helper 10 units ahead, three
    /// extinguishers, no sounds, GBM_IN_SHIP, and the level start as the
    /// last sound time.
    func testAIInitAllMakesTheGhostedGuideBotAndDoInitItsHelper() throws {
        let level = makeGuideBotGoalLevel()
        let world = session(level).world
        let player = world.testPlayerObject
        let buddy = try XCTUnwrap(world.testGuideBotObject)
        // ObjCreate takes the lowest free slot of the loaded table and the
        // next handle count of that slot (object.cpp:1700).
        let loaded = ObjectTable(level: level)
        let slot = try XCTUnwrap(
            (0..<ObjectTable.capacity).first { loaded.slots[$0] == nil }
        )
        XCTAssertEqual(buddy.handle, loaded.handles[slot].nextSignature())
        XCTAssertEqual(buddy.type, .dummy)
        XCTAssertEqual(buddy.dummyType, .robot)
        XCTAssertEqual(buddy.parent, player.handle)
        XCTAssertEqual(buddy.location, player.location)
        XCTAssertEqual(buddy.position, player.position)
        XCTAssertEqual(buddy.orientation, GameWorld.identityOrientation)
        XCTAssertEqual(buddy.renderType, .polyobj)
        let ai = try XCTUnwrap(buddy.ai)
        XCTAssertEqual(ai.flags & ObjectAIFrame.teamMask,
                       ObjectAIFrame.teamRebel)
        XCTAssertNotEqual(ai.flags & ObjectAIFrame.dodgeFlag, 0)
        let page = world.objectFindID("GuideBot", level: level)
        // The GuideBot page (0x110f) has OIF_INVEN_SELECTABLE, so the item
        // is selectable and usable and becomes the selected one
        // (AddObjectItem, Inventory.cpp:640-660).
        XCTAssertEqual(world.playerInventory.items, [
            .init(
                type: ObjectType.robot.rawValue, id: page, count: 1,
                itemFlags: PlayerInventory.ItemFlag.selectable
            ),
        ])
        XCTAssertEqual(world.playerInventory.position, 0)

        let memory = try XCTUnwrap(world.testGuideBot)
        XCTAssertEqual(memory.mode, GuideBotScript.inShipMode)
        XCTAssertEqual(memory.player, player.handle)
        XCTAssertEqual(memory.name, "GB")
        XCTAssertEqual(memory.powerups, [3, 0, 0, 0, 0])
        XCTAssertEqual(memory.sounds, [-1, -1, -1, -1, -1])
        XCTAssertEqual(memory.lastSoundTime, 0)
        XCTAssertEqual(memory.maximumSpeed, 60)
        XCTAssertEqual(
            memory.powerupPages[4],
            world.objectFindID("buddyantivirus", level: level)
        )
        let helper = try XCTUnwrap(world.objects[memory.ambientCamera])
        XCTAssertEqual(helper.type, .powerup)
        XCTAssertEqual(helper.renderType, .none)
        XCTAssertEqual(helper.parent, buddy.handle)
        XCTAssertEqual(
            helper.position, player.position + player.orientation.forward * 10
        )
        XCTAssertNoThrow(try world.validate(against: level))
    }

    /// MakeCommandList (AIGame.cpp:4879): in the ship the menu has Exit
    /// ship and Rename; while the birth runs it has nothing; in GBM_AMBIENT
    /// it offers the active goal ("Get to" its location, :5405), the finds,
    /// the extinguisher, and Return to ship, but not Exit ship.
    func testMenuOffersExitInTheShipAndTheGoalOnlyInAmbient() throws {
        let simulation = session()
        let inShip = try XCTUnwrap(
            simulation.world.guideBotMenu(level: simulation.level)
        )
        XCTAssertEqual(inShip.title, "GB Command Menu")
        XCTAssertEqual(inShip.commands.map(\.id), [0, 2])
        XCTAssertEqual(inShip.commands.map(\.text),
                       ["Exit ship", "Rename GB Unit"])
        XCTAssertEqual(inShip.commands[1].dialogText, "Enter GuideBot name:")
        XCTAssertTrue(simulation.testBuddyMenuOffers(GuideBotScript.exitShipCommand))
        XCTAssertFalse(simulation.testBuddyMenuOffers(GuideBotScript.findActiveGoal0))

        var timestamp = 0.0
        simulation.releaseOrRecallTestGuideBot()
        simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode, GuideBotScript.birthMode
        )
        XCTAssertEqual(
            simulation.world.guideBotMenu(level: simulation.level)?.commands, []
        )
        XCTAssertFalse(simulation.testBuddyMenuOffers(GuideBotScript.findActiveGoal0))
        XCTAssertFalse(simulation.testBuddyMenuOffers(GuideBotScript.exitShipCommand))

        simulation.runFrames(14, from: &timestamp)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode, GuideBotScript.ambientMode
        )
        let ambient = try XCTUnwrap(
            simulation.world.guideBotMenu(level: simulation.level)
        )
        let ids = ambient.commands.map(\.id)
        XCTAssertEqual(ids.first, GuideBotScript.findActiveGoal0)
        XCTAssertEqual(ambient.commands.first?.text, "Get to Camera Monitor")
        XCTAssertTrue(ids.contains(GuideBotScript.returnToShipCommand))
        XCTAssertTrue(ids.contains(GuideBotScript.findEnergyCenterCommand))
        XCTAssertTrue(ids.contains(GuideBotScript.escortShipCommand))
        // Three extinguishers (GBC_EXTINGUISH, :4927), and chatter is on.
        XCTAssertTrue(ids.contains(36))
        XCTAssertTrue(ids.contains(GuideBotScript.noChatterCommand))
        XCTAssertFalse(ids.contains(GuideBotScript.allowChatterCommand))
        XCTAssertFalse(ids.contains(GuideBotScript.exitShipCommand))
        XCTAssertFalse(ids.contains(GuideBotScript.findOutsideCommand))
        XCTAssertEqual(simulation.world.testGuideBot?.numberOfPrimaryGoals, 1)
        XCTAssertTrue(simulation.testBuddyMenuOffers(GuideBotScript.findActiveGoal0))
        XCTAssertTrue(simulation.testBuddyMenuOffers(GuideBotScript.returnToShipCommand))
    }

    /// GBC_EXIT_SHIP sends EVT_USE to the Guide-Bot (AIGame.cpp:5243);
    /// DoUse sends COM_REINIT to the player's buddy (:5548), whose DoInit
    /// starts GBM_BIRTH (:5609): at the player with the player's orientation
    /// and parent, the player's velocity plus 40 forward, out of the ghost
    /// and the inventory, with GBExpulsionA at the player and a GET_TO_POS
    /// goal 200 units ahead (:4633-4705).
    func testExitShipSendsUseAndStartsTheBirthAtThePlayer() throws {
        let level = makeGuideBotGoalLevel()
        let simulation = session(level)
        simulation.world.velocity = .init(x: 3, y: 0, z: 0)
        let playerBefore = simulation.world.testPlayerObject
        var timestamp = 0.0
        simulation.releaseOrRecallTestGuideBot()
        let released = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(soundNames(released), ["GBExpulsionA"])
        XCTAssertTrue(hudMessages(released).isEmpty)
        let memory = try XCTUnwrap(simulation.world.testGuideBot)
        XCTAssertEqual(memory.mode, GuideBotScript.birthMode)
        XCTAssertEqual(memory.lastCommand, -1)
        XCTAssertEqual(memory.isParented, true)
        XCTAssertEqual(memory.nextAmbientTime, 1.2)
        let buddy = try XCTUnwrap(simulation.world.testGuideBotObject)
        XCTAssertEqual(buddy.type, .robot)
        XCTAssertEqual(buddy.parent, playerBefore.handle)
        XCTAssertEqual(buddy.orientation, playerBefore.orientation)
        XCTAssertEqual(buddy.creationTime, 0)
        XCTAssertTrue(simulation.world.playerInventory.items.isEmpty)
        let goal = try XCTUnwrap(buddy.ai?.goals[1])
        XCTAssertTrue(goal.used)
        XCTAssertEqual(goal.type, AIGoal.getToPositionType)
        XCTAssertEqual(goal.circleDistance, 1)
        XCTAssertEqual(
            goal.position,
            playerBefore.position + playerBefore.orientation.forward * 200
        )
        XCTAssertEqual(goal.flags & AIGoal.notifiesFlag, AIGoal.notifiesFlag)
        // The birth velocity (player velocity + 40 forward) moved it this
        // frame from the player's place.
        XCTAssertNotEqual(buddy.position, playerBefore.position)
        XCTAssertNoThrow(try simulation.world.validate(against: level))
    }

    /// GBM_BIRTH lasts until mode_time, which DoFrame adds each frame's
    /// Frametime to, exceeds 1.2 s (AIGame.cpp:5893); SetMode(GBM_AMBIENT)
    /// then clears the goals (AI_SetType), draws the next flare time and
    /// visibility check time in that order (:4586-4587), and ReInitAmbient
    /// draws the side of the helper to fly to (:4527).
    func testBirthBecomesAmbientAfterOnePointTwoSecondsWithItsDraws() throws {
        let simulation = session(seed: 0x2468_ACE1)
        var timestamp = 0.0
        var modeTime: Float = 0
        var ambientFrame: Int?
        for frame in 1...20 {
            let frameTime = simulation.world.frameDuration
            timestamp += 0.1
            if frame == 1 {
                simulation.releaseOrRecallTestGuideBot()
            }

            let before = simulation.world
            _ = simulation.update(at: timestamp, input: .zero)
            // SetMode(GBM_BIRTH) runs at the frame's start (the menu
            // command), and that frame's DoFrame already adds its Frametime.
            modeTime += frameTime
            let mode = simulation.world.testGuideBot?.mode
            if modeTime > 1.2 {
                XCTAssertEqual(mode, GuideBotScript.ambientMode)
                ambientFrame = frame
                // The mode change drew the flare time, the visibility time,
                // and the ambient side (rand() % 6), in that order, from the
                // module's own rand() (AIGame.cpp:4587-4590, :4526).
                let memory = try XCTUnwrap(simulation.world.testGuideBot)
                var state = before.gameModuleRandomState
                var draws: [Int32] = []
                for _ in 0..<3 {
                    state = state &* 214_013 &+ 2_531_011
                    draws.append(Int32((state >> 16) & 0x7fff))
                }
                XCTAssertEqual(memory.timeUntilNextFlare,
                               3 + Float(draws[0]) / Float(0x7fff))
                XCTAssertEqual(
                    memory.timeUntilNextPlayerVisibilityCheck,
                    0.5 + 0.5 * (Float(draws[1]) / Float(0x7fff))
                )
                XCTAssertEqual(simulation.world.gameModuleRandomState, state)
                XCTAssertEqual(memory.modeTime, 0)
                let goals = try XCTUnwrap(
                    simulation.world.testGuideBotObject?.ai?.goals
                )
                XCTAssertEqual(goals[0].type,
                               AIGoal.moveRelativeObjectVectorType)
                XCTAssertEqual(goals[0].objectHandle, memory.ambientCamera)
                XCTAssertEqual(goals[0].circleDistance, 4)
                XCTAssertFalse([AIGoal.negativeUpSubtype, AIGoal.upSubtype]
                    .contains(goals[0].subtype))
                XCTAssertFalse(goals[1].used)
                XCTAssertEqual(before.testGuideBot?.mode,
                               GuideBotScript.birthMode)
                break
            }
            XCTAssertEqual(mode, GuideBotScript.birthMode, "frame \(frame)")
            // GBM_BIRTH draws nothing after the release's SetMode.
            if frame > 1 {
                XCTAssertEqual(simulation.world.gameModuleRandomState,
                               before.gameModuleRandomState)
            }
        }
        XCTAssertNotNil(ambientFrame)
    }

    /// DoFrame's normal branch starts the engine sound, GBotEngineB1, a
    /// looping page that follows its object (AIGame.cpp:6236); it does not
    /// run in GBM_BIRTH (:5893 returns). The sound system stops a linked
    /// sound whose object is ghosted (hlsoundlib.cpp:722), and SetMode's
    /// Sound_Stop does nothing (osiris_predefs.cpp:2906).
    func testTheEngineSoundLoopsWithTheGuideBotAndStopsInTheShip() throws {
        let simulation = session()
        var timestamp = 0.0
        simulation.releaseOrRecallTestGuideBot()
        let birth = simulation.runFrames(12, from: &timestamp)
        XCTAssertTrue(birth.allSatisfy { $0.objectSoundLoops.isEmpty })
        let ambient = simulation.runFrames(4, from: &timestamp)
        let loop = try XCTUnwrap(ambient.last?.objectSoundLoops.only)
        XCTAssertEqual(loop.soundName, "GBotEngineB1")
        XCTAssertEqual(
            loop.position, simulation.world.testGuideBotObject?.position
        )
        XCTAssertEqual(
            simulation.world.testGuideBot?.sounds[GuideBotScript.ambientSound],
            loop.handle
        )
        // The loop is state, not a one-shot request.
        XCTAssertFalse(soundNames(ambient).contains("GBotEngineB1"))

        simulation.world.updateGuideBot(simulation.world.buddyHandle) {
            $0.isMarkedForPickup = true
        }
        GuideBotScript.doCollide(
            simulation.world.buddyHandle,
            it: simulation.world.testPlayerObject.handle, &simulation.world,
            simulation.level
        )
        XCTAssertEqual(simulation.world.testGuideBotObject?.type, .dummy)
        XCTAssertEqual(simulation.world.testGuideBot?.sounds,
                       [-1, -1, -1, -1, -1])
        _ = simulation.runFrames(1, from: &timestamp)
        XCTAssertTrue(simulation.world.soundSystem.objectLoops.isEmpty)
    }

    /// DoMessage plays its sound only when the last one is more than 2.5 s
    /// old (AIGame.cpp:4542), and DoInit set that time at level start
    /// (:5683); a message in the gate still reaches the HUD.
    func testMessageSoundGateAllowsOneSoundPerTwoAndAHalfSeconds() throws {
        let simulation = session()
        var timestamp = 0.0
        releasedAmbient(simulation, timestamp: &timestamp)
        XCTAssertGreaterThan(simulation.world.gameTime, 2.5)
        simulation.selectTestBuddyCommand(GuideBotScript.findActiveGoal0)
        let accepted = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(hudMessages(accepted), ["GB: On my way!"])
        XCTAssertEqual(soundNames(accepted), ["GBotAcceptOrder1"])
        let soundTime = try XCTUnwrap(simulation.world.testGuideBot)
            .lastSoundTime
        simulation.releaseOrRecallTestGuideBot()
        let gated = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(hudMessages(gated), ["GB: Returning to ship."])
        XCTAssertFalse(soundNames(gated).contains("GBotAcceptOrder1"))
        XCTAssertEqual(simulation.world.testGuideBot?.lastSoundTime, soundTime)
    }

    /// The goal command (AIGame.cpp:4971-5040): the first active primary
    /// goal's object item is reachable, so "On my way!", a GET_TO_OBJ goal
    /// with circle 20, and the common goals that first bring the Guide-Bot
    /// to the player (:4946). At the goal, DoNotify says so and adds the
    /// return to the player (:5696-5709); back at the player, the greeting
    /// (:5711-5724), whose draw picks "Come on!" or "Let's go!".
    func testGoalCommandRoutesToTheGoalAndReturnsToThePlayer() throws {
        let level = makeGuideBotGoalLevel()
        let simulation = session(level)
        var timestamp = 0.0
        releasedAmbient(simulation, timestamp: &timestamp)
        simulation.selectTestBuddyCommand(GuideBotScript.findActiveGoal0)
        let accepted = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(hudMessages(accepted), ["GB: On my way!"])
        let goals = try XCTUnwrap(simulation.world.testGuideBotObject?.ai?.goals)
        XCTAssertEqual(goals[1].type, AIGoal.getToObjectType)
        XCTAssertEqual(goals[1].objectHandle, ObjectHandle(6_167))
        XCTAssertEqual(goals[1].circleDistance, 20)
        XCTAssertEqual(
            goals[1].flags & (AIGoal.keepAtCompletionFlag
                | AIGoal.notifiesFlag),
            AIGoal.keepAtCompletionFlag | AIGoal.notifiesFlag
        )
        XCTAssertEqual(goals[2].type, AIGoal.moveRelativeObjectVectorType)
        XCTAssertEqual(goals[2].subtype, AIGoal.negativeForwardSubtype)
        XCTAssertEqual(goals[3].type, AIGoal.getToObjectType)
        XCTAssertEqual(goals[3].circleDistance, 20)
        XCTAssertEqual(simulation.world.testGuideBot?.lastCommand, 3)

        var arrival: Int?
        var greeting: String?
        let monitor = try XCTUnwrap(
            simulation.world.objects[ObjectHandle(6_167)]
        )
        for frame in 1...400 {
            let messages = hudMessages(simulation.runFrames(1, from: &timestamp))
            if messages.contains(
                "GB: I am at the goal, coming back to get you."
            ) {
                arrival = frame
                let buddy = try XCTUnwrap(simulation.world.testGuideBotObject)
                XCTAssertLessThanOrEqual(
                    vectorDistance(buddy.position, monitor.position)
                        - buddy.size - monitor.size,
                    20.1 * 1.5
                )
                let returning = try XCTUnwrap(buddy.ai?.goals[2])
                XCTAssertEqual(returning.guid,
                               GuideBotScript.returnedToPlayerGUID)
                XCTAssertEqual(returning.circleDistance, 30)
                XCTAssertTrue(try XCTUnwrap(buddy.ai?.goals[1]).used)
            }
            if let line = messages.first(where: {
                $0 == "GB: Come on!" || $0 == "GB: Let's go!"
            }), arrival != nil {
                greeting = line
                break
            }
        }
        XCTAssertNotNil(arrival)
        XCTAssertNotNil(greeting)
        let buddy = try XCTUnwrap(simulation.world.testGuideBotObject)
        XCTAssertLessThanOrEqual(
            simulation.world.objectDistance(
                buddy.handle, simulation.world.testPlayerObject.handle,
                subtractingSizes: true
            ),
            30.1 * 1.5
        )
        XCTAssertFalse(try XCTUnwrap(buddy.ai?.goals[2]).used)
    }

    /// A goal the Guide-Bot does not know the place of gets "I do not have
    /// nav. data on this goal." and no goal (AIGame.cpp:4999).
    func testGoalWithoutGuideBotLocationGetsNoNavigationMessage() throws {
        var level = makeGuideBotGoalLevel()
        let index = try XCTUnwrap(level.goals.firstIndex {
            $0.name == "Locate the Camera Monitor"
        })
        let goal = level.goals[index]
        level.goals[index] = LevelGoal(
            status: goal.status | LevelGoalFlag.guideBotDoesNotKnowLocation,
            priority: goal.priority, list: goal.list, name: goal.name,
            itemName: goal.itemName, description: goal.description,
            completionMessage: goal.completionMessage, items: goal.items
        )
        let simulation = session(level)
        var timestamp = 0.0
        releasedAmbient(simulation, timestamp: &timestamp)
        XCTAssertTrue(simulation.testBuddyMenuOffers(GuideBotScript.findActiveGoal0))
        simulation.selectTestBuddyCommand(GuideBotScript.findActiveGoal0)
        let refused = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(
            hudMessages(refused), ["GB: I do not have nav. data on this goal."]
        )
        XCTAssertEqual(soundNames(refused), ["GBotConcern1"])
        XCTAssertFalse(
            try XCTUnwrap(simulation.world.testGuideBotObject?.ai?.goals[1])
                .used
        )
    }

    /// The return command (AIGame.cpp:5143) marks the Guide-Bot for pickup
    /// and sends it into the player (circle -10); the robot's move meets
    /// the player (collide_two_objects), DoCollide enters the ship
    /// (:5510), and SetMode(GBM_ENTER_SHIP) says so, puts it back in the
    /// inventory, and ghosts it (:4618-4663). The exit command then starts a
    /// new birth.
    func testReturnToShipEntersTheShipAndTheExitCommandReleasesAgain() throws {
        let level = makeGuideBotGoalLevel()
        let simulation = session(level)
        var timestamp = 0.0
        releasedAmbient(simulation, timestamp: &timestamp)
        simulation.releaseOrRecallTestGuideBot()
        let requested = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(hudMessages(requested), ["GB: Returning to ship."])
        let returning = try XCTUnwrap(
            simulation.world.testGuideBotObject?.ai?.goals[1]
        )
        XCTAssertEqual(returning.objectHandle,
                       simulation.world.testPlayerObject.handle)
        XCTAssertEqual(returning.circleDistance, -10)
        XCTAssertEqual(
            (simulation.world.testGuideBotObject?.ai?.flags ?? 0)
                & ObjectAIFrame.autoAvoidFriendsFlag,
            0
        )
        var entered = false
        for _ in 1...200 {
            let frame = simulation.runFrames(1, from: &timestamp)
            if hudMessages(frame).contains("GB: Entering ship!") {
                entered = true
                break
            }
        }
        XCTAssertTrue(entered)
        XCTAssertEqual(simulation.world.testGuideBotObject?.type, .dummy)
        XCTAssertEqual(simulation.world.testGuideBot?.mode,
                       GuideBotScript.inShipMode)
        XCTAssertEqual(simulation.world.playerInventory.items.count, 1)
        XCTAssertTrue(simulation.testBuddyMenuOffers(GuideBotScript.exitShipCommand))

        simulation.releaseOrRecallTestGuideBot()
        let again = simulation.runFrames(1, from: &timestamp)
        XCTAssertTrue(soundNames(again).contains("GBExpulsionA"))
        XCTAssertEqual(simulation.world.testGuideBot?.mode,
                       GuideBotScript.birthMode)
        XCTAssertEqual(simulation.world.testGuideBotObject?.type, .robot)
    }

    /// A saved world in the middle of the goal command loads and advances
    /// exactly as the uninterrupted world (architecture.md section 7).
    func testSaveContinuationInTheMiddleOfTheGoalCommand() throws {
        let level = makeGuideBotGoalLevel()
        let simulation = session(level, seed: 0x1357_9BDF)
        var timestamp = 0.0
        releasedAmbient(simulation, timestamp: &timestamp)
        simulation.selectTestBuddyCommand(GuideBotScript.findActiveGoal0)
        simulation.runFrames(20, from: &timestamp)
        XCTAssertTrue(
            try XCTUnwrap(simulation.world.testGuideBotObject?.ai?.goals[1])
                .used
        )
        let saved = try JSONDecoder().decode(
            GameWorld.self, from: JSONEncoder().encode(simulation.world)
        )
        XCTAssertEqual(saved, simulation.world)
        let restored = try GameSession(
            level: level, world: saved, resumedAtTimestamp: timestamp
        )
        var restoredTimestamp = timestamp
        let original = simulation.runFrames(80, from: &timestamp)
        let resumed = restored.runFrames(80, from: &restoredTimestamp)
        XCTAssertEqual(restored.world, simulation.world)
        XCTAssertEqual(hudMessages(resumed), hudMessages(original))
    }

    /// DoPowerupCheck (AIGame.cpp:6002) finds a Guide-Bot powerup within
    /// 200 units and starts the get-powerup sub-mode (:4561); the GBPowerup
    /// script gives itself to the Guide-Bot within 5 units (:8260), and the
    /// pickup counts it and removes it (:5369).
    func testPowerupCheckFetchesAGuideBotPowerup() throws {
        var level = makeGuideBotGoalLevel(goalDistance: 300)
        let player = try XCTUnwrap(level.objects.first {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        let antivirus = CanonicalObjectInfo(
            name: "buddyantivirus",
            type: 7,
            flags: 0x3,
            size: 4.732_707_5,
            hitPoints: 100,
            lightDistance: 0,
            lighting: fixtureNoLight,
            ai: fixtureAIInfo(
                flags: 0x0003_0040, aiType: 5, movementType: 1, fov: 0,
                notifyFlags: 0x1ff9_f2a2
            ),
            weaponBatteries: [],
            physics: .init(flags: 0x4, mass: 1, drag: 1, restitution: 1),
            moduleName: "aigame",
            scriptNameOverride: "GBPowerup"
        )
        level = level.addingObjectInfo(antivirus)
        let placed = PlacedObject.fixture(
            handle: 4_136,
            type: 7,
            storedID: 300,
            definition: .init(storedIndex: 300, sourceName: "buddyantivirus"),
            name: "GB powerup",
            location: player.location,
            position: player.position
                + player.orientation.forward * 60
                + player.orientation.right * 20,
            orientation: player.orientation
        )
        level.objects.append(placed)
        level.objectPresentations.append(.fixture(4_136, level.models[0].source))
        let simulation = session(level)
        XCTAssertEqual(simulation.world.gbPowerup(ObjectHandle(4_136))?.type, 4)
        var timestamp = 0.0
        simulation.releaseOrRecallTestGuideBot()
        let frames = simulation.runFrames(200, from: &timestamp)
        let messages = hudMessages(frames)
        XCTAssertTrue(messages.contains("GB: TXT_GB_I_FOUND_A_GB_POWERUP"))
        XCTAssertTrue(messages.contains("GB: I got a temporary Anti-Virus!"))
        XCTAssertEqual(simulation.world.testGuideBot?.powerups[4], 1)
        XCTAssertEqual(simulation.world.testGuideBot?.subMode, 0)
        XCTAssertNil(simulation.world.objects[ObjectHandle(4_136)])
        XCTAssertTrue(
            try XCTUnwrap(
                simulation.world.guideBotMenu(level: level)
            ).commands.contains { $0.id == 40 }
        )
    }

    /// The Guide-Bot's flare in GBM_AMBIENT (AIGame.cpp:6106-6120): its
    /// EVT_AI_FRAME resets the flare timer with one draw of the module's
    /// rand() and no ps_rand draw. With goal slots 2 and 3 used it fires
    /// nothing; with only slot 1 used it plays Flare and fires a Yellow
    /// flare through MSAFE_OBJECT_FIRE_WEAPON from its center, along its
    /// heading, with itself as parent, still with no ps_rand draw (the
    /// Guide-Bot has no fire spread at Rookie).
    func testGuideBotFiresAYellowFlareThroughMultisafe() throws {
        let seed: UInt32 = 0x1357_9bdf
        let level = withTrainingGuideBot(makeTrainingGuidebotYellowFlareLevel())
        let flareIndex = try XCTUnwrap(level.weapons?.firstIndex {
            $0.name == "Yellow flare"
        })
        let seedSession = GameSession(
            level: level, presentationReadyTimestamp: 0
        )
        seedSession.runToTestGuideBotAmbient()
        func moduleFraction(after state: UInt32) -> (Float, UInt32) {
            let next = state &* 214_013 &+ 2_531_011
            return (Float((next >> 16) & 0x7fff) / Float(0x7fff), next)
        }

        func scriptFrame(helpers: Bool) -> (GameWorld, GameWorld) {
            var world = seedSession.world
            world.authoritativeRandomState = seed
            world.prepareTestGuideBotFlare(
                helperSlotsAreUsed: helpers, level: level
            )
            let start = world
            _ = GuideBotScript.callEvent(.aiFrame, me: world.buddyHandle,
                                         world: &world, level: level)
            return (start, world)
        }

        let (blockedStart, blocked) = scriptFrame(helpers: true)
        let (fraction, moduleState) =
            moduleFraction(after: blockedStart.gameModuleRandomState)
        XCTAssertEqual(blocked.authoritativeRandomState, seed)
        XCTAssertEqual(blocked.gameModuleRandomState, moduleState)
        XCTAssertEqual(blocked.testGuideBot?.timeUntilNextFlare, 3 + fraction)
        XCTAssertTrue(blocked.objects.filter {
            $0.weapon == flareIndex
        }.isEmpty)

        let (start, fired) = scriptFrame(helpers: false)
        XCTAssertEqual(fired.authoritativeRandomState, seed)
        XCTAssertEqual(
            fired.gameModuleRandomState,
            moduleFraction(after: start.gameModuleRandomState).1
        )
        let buddy = try XCTUnwrap(start.testGuideBotObject)
        let flare = try XCTUnwrap(
            fired.objects.filter { $0.weapon == flareIndex }.only
        )
        XCTAssertEqual(flare.parent, buddy.handle)
        XCTAssertEqual(flare.position, buddy.position)
        XCTAssertEqual(flare.location, buddy.location)
        XCTAssertEqual(flare.orientation.forward.x,
                       buddy.orientation.forward.x, accuracy: 1e-5)
        XCTAssertEqual(flare.orientation.forward.y,
                       buddy.orientation.forward.y, accuracy: 1e-5)
        XCTAssertEqual(flare.orientation.forward.z,
                       buddy.orientation.forward.z, accuracy: 1e-5)
        XCTAssertTrue(flare.noCollideParent)
        let speed = sqrt(dot(flare.velocity, flare.velocity))
        let rebel = (buddy.ai?.flags ?? 0) & ObjectAIFrame.teamMask
            == ObjectAIFrame.teamRebel
        XCTAssertEqual(
            speed,
            100 * (rebel ? 1 : Difficulty.aiWeaponSpeed[Difficulty.level]),
            accuracy: 1e-3
        )
    }

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

    /// Inventory counts are C ints (Inventory.h:233) and the Guide-Bot's
    /// powerup counts are signed chars (AIGame.cpp:1478); the released
    /// MSVC build wraps both.
    func testInventoryAndPowerupCountsWrapAtTheirSourceWidths() throws {
        var inventory = PlayerInventory()
        inventory.add(type: 2, id: 7, pageFlags: 0)
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
        inventory.add(type: 2, id: 7, pageFlags: 0)
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
            simulation.releaseOrRecallTestGuideBot()
            simulation.runFrames(1, from: &timestamp)
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

    /// ENABLE_COLLISION_POLY_SPHERE(OBJ_ROBOT, OBJ_PLAYER) sets both
    /// directions (collide.cpp:2549, :2619): a player who flies into a
    /// waiting Guide-Bot marked for pickup collects it (DoCollide,
    /// AIGame.cpp:5510).
    func testThePlayerCollectsAStationaryGuideBotMarkedForPickup() throws {
        let simulation = session()
        var timestamp = 0.0
        simulation.runToTestGuideBotAmbient()
        timestamp = 3.5
        simulation.releaseOrRecallTestGuideBot()
        simulation.runFrames(1, from: &timestamp)
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
                1, from: &timestamp, firstInput: .init(forward: 1)
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
            type: ObjectType.robot.rawValue, id: page
        ))
        XCTAssertEqual(
            session.world.testGuideBot?.mode, GuideBotScript.inShipMode
        )

        _ = session.update(at: 0.1, input: .init(usesInventory: true))

        XCTAssertFalse(session.world.playerInventory.checkItem(
            type: ObjectType.robot.rawValue, id: page
        ))
        XCTAssertEqual(
            session.world.testGuideBot?.mode, GuideBotScript.birthMode
        )
        // Only the Guide-Bot itself has the GuideBot page.
        XCTAssertEqual(
            session.world.objects.filter { $0.info == page }.count,
            1
        )
    }
}
