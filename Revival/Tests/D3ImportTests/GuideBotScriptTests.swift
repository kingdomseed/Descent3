import XCTest

/// A Training world with the translated Guide-Bot, the player and the
/// Camera Monitor (the level's one active goal) in a large room 39, the
/// monitor `goalDistance` units ahead of the player.
func makeGuideBotGoalLevel(goalDistance: Float = 120) -> Level {
    var level = makeTrainingCameraMonitorLevel()
    let playerIndex = level.objects.firstIndex {
        $0.handle == level.defaultPlayerBinding?.objectHandle
    }!
    let pickupIndex = level.objects.firstIndex { $0.handle == 6_167 }!
    let player = level.objects[playerIndex]
    let forward = player.orientation.forward
    level.rooms.append(makeSourceContainmentRoom(
        center: player.position + forward * 60,
        texture: level.surfacePhysics[0].texture,
        sourceIndex: 39,
        halfExtent: 200
    ))
    level.objects[playerIndex].location = .room(39)
    level.objects[pickupIndex].location = .room(39)
    level.objects[pickupIndex].position =
        player.position + forward * goalDistance
    return withTrainingGuideBot(level)
}

/// The translated GuideBot class (scripts/AIGame.cpp:4517-6855) and its
/// engine: AIInitAll's Guide-Bot (AImain.cpp:3833), the buddy menu's
/// commands, and the object sound loop.
final class GuideBotScriptTests: XCTestCase {
    private func session(_ level: Level = makeGuideBotGoalLevel(),
                         seed: UInt32 = 1) -> GameSession {
        GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
    }

    /// Releases the Guide-Bot on the first frame and runs until it is in
    /// GBM_AMBIENT and its parent link is gone (3 s after its birth).
    private func releasedAmbient(_ session: GameSession,
                                 timestamp: inout Double) {
        session.releaseOrRecallTestGuideBot()
        session.runFrames(
            35,
            from: &timestamp
        )
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
        XCTAssertEqual(buddy.handle, ObjectHandle(6_164))
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
        XCTAssertEqual(world.playerInventory.items, [
            .init(type: ObjectType.robot.rawValue, id: page, count: 1),
        ])

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
            helper.position,
            player.position + player.orientation.forward * 10
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
        simulation.runFrames(
            1,
            from: &timestamp
        )
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode,
            GuideBotScript.birthMode
        )
        XCTAssertEqual(
            simulation.world.guideBotMenu(level: simulation.level)?.commands,
            []
        )
        XCTAssertFalse(simulation.testBuddyMenuOffers(GuideBotScript.findActiveGoal0))
        XCTAssertFalse(simulation.testBuddyMenuOffers(GuideBotScript.exitShipCommand))

        simulation.runFrames(14, from: &timestamp)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode,
            GuideBotScript.ambientMode
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
        let released = simulation.runFrames(
            1,
            from: &timestamp
        )
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
        XCTAssertNoThrow(
            try simulation.world.validate(against: level)
        )
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
        let birth = simulation.runFrames(
            12,
            from: &timestamp
        )
        XCTAssertTrue(birth.allSatisfy { $0.objectSoundLoops.isEmpty })
        let ambient = simulation.runFrames(4, from: &timestamp)
        let loop = try XCTUnwrap(ambient.last?.objectSoundLoops.only)
        XCTAssertEqual(loop.soundName, "GBotEngineB1")
        XCTAssertEqual(
            loop.position,
            simulation.world.testGuideBotObject?.position
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
            it: simulation.world.testPlayerObject.handle,
            &simulation.world,
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
        let accepted = simulation.runFrames(
            1,
            from: &timestamp
        )
        XCTAssertEqual(hudMessages(accepted), ["GB: On my way!"])
        XCTAssertEqual(soundNames(accepted), ["GBotAcceptOrder1"])
        let soundTime = try XCTUnwrap(simulation.world.testGuideBot)
            .lastSoundTime
        simulation.releaseOrRecallTestGuideBot()
        let gated = simulation.runFrames(
            1,
            from: &timestamp
        )
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
        let accepted = simulation.runFrames(
            1,
            from: &timestamp
        )
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
                buddy.handle,
                simulation.world.testPlayerObject.handle,
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
            priority: goal.priority,
            list: goal.list,
            name: goal.name,
            itemName: goal.itemName,
            description: goal.description,
            completionMessage: goal.completionMessage,
            items: goal.items
        )
        let simulation = session(level)
        var timestamp = 0.0
        releasedAmbient(simulation, timestamp: &timestamp)
        XCTAssertTrue(simulation.testBuddyMenuOffers(GuideBotScript.findActiveGoal0))
        simulation.selectTestBuddyCommand(GuideBotScript.findActiveGoal0)
        let refused = simulation.runFrames(
            1,
            from: &timestamp
        )
        XCTAssertEqual(
            hudMessages(refused),
            ["GB: I do not have nav. data on this goal."]
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
        let requested = simulation.runFrames(
            1,
            from: &timestamp
        )
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
        let again = simulation.runFrames(
            1,
            from: &timestamp
        )
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
        simulation.runFrames(
            20,
            from: &timestamp
        )
        XCTAssertTrue(
            try XCTUnwrap(simulation.world.testGuideBotObject?.ai?.goals[1])
                .used
        )
        let saved = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(simulation.world)
        )
        XCTAssertEqual(saved, simulation.world)
        let restored = try GameSession(
            level: level,
            world: saved,
            resumedAtTimestamp: timestamp
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
        let placed = PlacedObject(
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
        )
        level.objects.append(placed)
        level.objectPresentations.append(.init(
            objectHandle: 4_136,
            primaryModel: level.models[0].source,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        ))
        let simulation = session(level)
        XCTAssertEqual(simulation.world.gbPowerup(ObjectHandle(4_136))?.type, 4)
        var timestamp = 0.0
        simulation.releaseOrRecallTestGuideBot()
        let frames = simulation.runFrames(
            200,
            from: &timestamp
        )
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

    /// Real content, opt-in (REVIVAL_TRAINING_PACKAGE, engineering.md
    /// section 2): the imported aigame module data, AIInitAll's takeover of
    /// the placed GuideBotB, its retail menu, and the release through the
    /// exit command to GBM_AMBIENT.
    func testImportedTrainingPackageReleasesTheTranslatedGuideBot() throws {
        guard let path = ProcessInfo.processInfo.environment[
            "REVIVAL_TRAINING_PACKAGE"
        ] else {
            throw XCTSkip("set REVIVAL_TRAINING_PACKAGE to a training.revival")
        }
        let level = try loadCanonicalLevel(from: URL(fileURLWithPath: path))
        let module = try XCTUnwrap(level.gameModules?.only)
        XCTAssertEqual(module.module, AIGame.moduleName)
        XCTAssertGreaterThanOrEqual(module.strings.count, 146)
        XCTAssertEqual(
            module.sounds.map(\.name),
            AIGame.references.soundNames
        )
        XCTAssertNotEqual(
            GameWorld(level: level).weaponFindID("Yellow flare", level: level),
            -1
        )
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        let buddy = simulation.world.buddyHandle
        XCTAssertEqual(buddy, level.findObjectName("GuideBotB"))
        XCTAssertEqual(simulation.world.objectType(buddy), .dummy)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode,
            GuideBotScript.inShipMode
        )
        let menu = try XCTUnwrap(
            simulation.world.guideBotMenu(level: simulation.level)
        )
        XCTAssertEqual(menu.commands.first?.id, 0)
        XCTAssertEqual(menu.commands.first?.text, "Exit ship")

        var timestamp = 0.0
        simulation.releaseOrRecallTestGuideBot()
        let released = simulation.runFrames(
            1,
            from: &timestamp
        )
        XCTAssertEqual(soundNames(released), ["GBExpulsionA"])
        XCTAssertEqual(simulation.world.objectType(buddy), .robot)
        simulation.runFrames(14, from: &timestamp)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode,
            GuideBotScript.ambientMode
        )
        XCTAssertEqual(simulation.world.soundSystem.objectLoops.count, 1)
    }

}
