import XCTest

// Osiris dispatch and timers on synthetic worlds. Legacy:
// Descent3/OsirisLoadandBind.cpp Osiris_BindScriptsToObject (:1427),
// Osiris_CallLevelEvent (:1948), Osiris_CallEvent (:2111), and the timers
// (:2254-2560).
final class OsirisTests: XCTestCase {
    private enum Slot: Equatable {
        case custom, level, mission, defaultScript
    }

    private let allSlots: [Slot] = [.custom, .level, .mission, .defaultScript]

    func testObjectChainRunsCustomLevelMissionDefaultWhileChained() {
        var calls: [Slot] = []
        let runsDefault = osirisCallObjectChain(
            allSlots,
            event: .collide(it: .none)
        ) { slot, _ in
            calls.append(slot)
            return .all
        }
        XCTAssertEqual(calls, allSlots)
        XCTAssertTrue(runsDefault)
    }

    func testObjectChainStopsWithoutContinueChainAndKeepsLastDefaultBit() {
        var calls: [Slot] = []
        // The level slot stops the chain but keeps the default action.
        XCTAssertTrue(osirisCallObjectChain(
            allSlots,
            event: .created
        ) { slot, _ in
            calls.append(slot)
            return slot == .level ? .continueDefault : .all
        })
        XCTAssertEqual(calls, [.custom, .level])

        // An earlier slot that drops the default action does not decide it:
        // only the last called slot's continueDefault counts.
        calls = []
        XCTAssertTrue(osirisCallObjectChain(
            allSlots,
            event: .created
        ) { slot, _ in
            calls.append(slot)
            return slot == .custom ? .continueChain : .all
        })
        XCTAssertEqual(calls, allSlots)

        calls = []
        XCTAssertFalse(osirisCallObjectChain(
            allSlots,
            event: .created
        ) { slot, _ in
            calls.append(slot)
            return slot == .mission ? [] : .all
        })
        XCTAssertEqual(calls, [.custom, .level, .mission])

        XCTAssertFalse(osirisCallObjectChain(
            allSlots,
            event: .created
        ) { _, _ in .continueChain })
    }

    func testObjectChainSendsAINotifyChildEventFirstAndIgnoresItsResult() {
        var calls: [(Slot, ScriptEvent)] = []
        let event = ScriptEvent.aiNotify(.goalFail, it: .none)
        let runsDefault = osirisCallObjectChain(
            [Slot.custom, .defaultScript],
            event: event
        ) { slot, event in
            calls.append((slot, event))
            // A child event result that stops the chain is ignored.
            return event == .ainGoalFail ? [] : .all
        }
        XCTAssertTrue(runsDefault)
        XCTAssertEqual(calls.map(\.0), [.custom, .custom, .defaultScript, .defaultScript])
        XCTAssertEqual(
            calls.map(\.1),
            [.ainGoalFail, event, .ainGoalFail, event]
        )
        XCTAssertNil(ScriptEvent.aiNotify(.other, it: .none).objectChildEvent)
        XCTAssertEqual(
            ScriptEvent.aiNotify(.seeTarget, it: .none).objectChildEvent,
            .ainSeePlayer
        )
        // A level or trigger script gets only the goal child events.
        XCTAssertNil(
            ScriptEvent.aiNotify(.seeTarget, it: .none).levelChildEvent
        )
    }

    func testLevelScriptGetsEventThenChildEventWhoseResultWins() {
        var calls: [ScriptEvent] = []
        let event = ScriptEvent.aiNotify(.goalComplete, it: .none)
        let runsDefault = osirisCallSingleScript(event: event) { event in
            calls.append(event)
            return event == .ainGoalComplete ? .continueChain : .all
        }
        XCTAssertEqual(calls, [event, .ainGoalComplete])
        XCTAssertFalse(runsDefault)
        XCTAssertTrue(osirisCallSingleScript(event: .levelStart) { _ in .all })
    }

    func testBindingGivesTrainingCustomScriptsByObjectName() throws {
        var level = makeSliceSixObjectRenderLevel()
        let forwardIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 12_301 }
        )
        let startIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 12_300 }
        )
        level.objects[forwardIndex] = renamed(
            level.objects[forwardIndex],
            "forwardgoal"
        )
        level.objects[startIndex] = renamed(level.objects[startIndex], nil)
        let unscripted = GameWorld(level: level)
        XCTAssertEqual(unscripted.levelModule, .none)
        XCTAssertNil(unscripted.objects[ObjectHandle(12_301)]?.scripts)

        let world = GameWorld(level: addingTrainingMissionScripting(level))
        // GetCOScriptList: ForwardGoal (Object_handles[21]) has
        // ID_CUSTOM_OBJECT_300D = 0x001. The name compare ignores case.
        XCTAssertEqual(
            world.objects[ObjectHandle(12_301)]?.scripts,
            ObjectScripts(custom: 0x001, level: nil)
        )
        // A scriptable object with no custom script and no generic script
        // in the level module has no scripts.
        XCTAssertNil(world.objects[ObjectHandle(12_300)]?.scripts)
        // The player cannot hold scripts.
        XCTAssertNil(world.objects[ObjectHandle(2_048)]?.scripts)

        var copy = world
        XCTAssertTrue(
            copy.osirisCallEvent(ObjectHandle(12_300), .created, level: level)
        )
        XCTAssertEqual(copy, world)
    }

    func testTimerHandlesUseCounterAndSlot() {
        var world = GameWorld(level: makeSliceSixObjectRenderLevel())
        let first = world.osirisCreateTimer(
            .init(target: .level, id: 7, interval: 1)
        )
        let second = world.osirisCreateTimer(
            .init(target: .level, id: 8, interval: 1)
        )
        // FORM_HANDLE: counter << 8 | slot.
        XCTAssertEqual(first, 1 << 8 | 0)
        XCTAssertEqual(second, 2 << 8 | 1)
        XCTAssertTrue(world.osirisTimers.exists(first))
        XCTAssertEqual(world.osirisTimers.handle(forID: 8), second)
        XCTAssertEqual(
            world.osirisTimers.timeRemaining(second, gameTime: 0.25),
            0.75
        )
    }

    func testOneShotTimerSignalsOnceWhenGameTimeReachesItsEnd() {
        var world = GameWorld(level: makeSliceSixObjectRenderLevel())
        world.gameTime = 2
        let handle = world.osirisCreateTimer(
            .init(target: .level, id: 4, interval: 1)
        )
        var sent: [(OsirisTimerTarget, ScriptEvent)] = []
        func process(at time: Float) {
            world.gameTime = time
            world.osirisProcessTimers { _, target, event in
                sent.append((target, event))
            }
        }
        process(at: 2.9)
        XCTAssertTrue(sent.isEmpty)
        process(at: 3)
        XCTAssertEqual(sent.map(\.0), [.level])
        XCTAssertEqual(sent.map(\.1), [.timer(id: 4, gameTime: 3)])
        XCTAssertFalse(world.osirisTimers.exists(handle))
        process(at: 10)
        XCTAssertEqual(sent.count, 1)
    }

    func testRepeatingTimersCountDownOrRunForever() {
        var world = GameWorld(level: makeSliceSixObjectRenderLevel())
        let counted = world.osirisCreateTimer(
            .init(target: .level, id: 1, interval: 0.5, repeatCount: 3)
        )
        let endless = world.osirisCreateTimer(
            .init(target: .level, id: 2, interval: 0.5, repeatCount: -1)
        )
        var ids: [Int32] = []
        for step in 1...8 {
            world.gameTime = Float(step) * 0.5
            world.osirisProcessTimers { _, _, event in
                if case let .timer(id, _) = event { ids.append(id) }
            }
        }
        XCTAssertEqual(ids.filter { $0 == 1 }.count, 3)
        XCTAssertEqual(ids.filter { $0 == 2 }.count, 8)
        XCTAssertFalse(world.osirisTimers.exists(counted))
        XCTAssertTrue(world.osirisTimers.exists(endless))
    }

    func testCancelSendsTimerCancelOnceTheHandleMatches() {
        var world = GameWorld(level: makeSliceSixObjectRenderLevel())
        let handle = world.osirisCreateTimer(
            .init(target: .level, id: 3, interval: 5)
        )
        var sent: [ScriptEvent] = []
        // A handle whose counter does not match its entry does nothing.
        world.osirisCancelTimer(handle + (1 << 8)) { _, _, event in
            sent.append(event)
        }
        XCTAssertTrue(sent.isEmpty)
        world.osirisCancelTimer(handle) { _, target, event in
            XCTAssertEqual(target, .level)
            sent.append(event)
        }
        XCTAssertEqual(sent, [.timerCancel(handle: handle, detonated: false)])
        XCTAssertFalse(world.osirisTimers.exists(handle))
        world.gameTime = 10
        world.osirisProcessTimers { _, _, event in sent.append(event) }
        XCTAssertEqual(sent.count, 1)
    }

    func testDeadDetonatorCancelsTimerAndDeadOwnerDropsIt() {
        var world = GameWorld(level: makeSliceSixObjectRenderLevel())
        let detonator = ObjectHandle(12_300)
        let owner = ObjectHandle(12_299)
        let detonated = world.osirisCreateTimer(
            .init(target: .level, id: 5, interval: 1, detonator: detonator)
        )
        let orphaned = world.osirisCreateTimer(
            .init(target: .object(owner), id: 6, interval: 1)
        )
        world.objects.delete(detonator)
        world.objects.delete(owner)
        var sent: [(OsirisTimerTarget, ScriptEvent)] = []
        world.osirisProcessTimers { _, target, event in
            sent.append((target, event))
        }
        XCTAssertEqual(sent.map(\.0), [.level])
        XCTAssertEqual(
            sent.map(\.1),
            [.timerCancel(handle: detonated, detonated: true)]
        )
        XCTAssertFalse(world.osirisTimers.exists(detonated))
        // The owner is gone, so the timer ends with no event.
        XCTAssertFalse(world.osirisTimers.exists(orphaned))
    }

    func testTimerCreatedByAHandlerInALaterEntryRunsInTheSamePass() {
        var world = GameWorld(level: makeSliceSixObjectRenderLevel())
        world.osirisCreateTimer(.init(target: .level, id: 1, interval: 0))
        var ids: [Int32] = []
        world.osirisProcessTimers { world, _, event in
            guard case let .timer(id, _) = event else { return }
            ids.append(id)
            if id == 1 {
                world.osirisCreateTimer(
                    .init(target: .level, id: 2, interval: 0)
                )
            }
        }
        XCTAssertEqual(ids, [1, 2])
    }

    /// Osiris_TimerExists and Osiris_TimerTimeRemaining check the slot
    /// range (OsirisLoadandBind.cpp:2530, :2548), so the -1 that a full
    /// table returns from Osiris_CreateTimer is simply not a timer.
    func testTimerQueriesRejectHandlesOutsideTheTable() {
        var world = GameWorld(level: makeSliceSixObjectRenderLevel())
        for id in 0..<Int32(OsirisTimers.capacity) {
            XCTAssertNotEqual(
                world.osirisCreateTimer(
                    .init(target: .level, id: id, interval: 1)
                ),
                -1
            )
        }
        let full = world.osirisCreateTimer(
            .init(target: .level, id: 99, interval: 1)
        )
        XCTAssertEqual(full, -1)
        XCTAssertFalse(world.osirisTimers.exists(full))
        XCTAssertEqual(world.osirisTimers.timeRemaining(full, gameTime: 0), -1)
        XCTAssertFalse(world.osirisTimers.exists(0x40))
        XCTAssertEqual(world.osirisTimers.timeRemaining(0x40, gameTime: 0), -1)
    }

    /// The save boundary rejects timer and script state the runtime would
    /// trap on: a repeat count below -1 and script ids the level module does
    /// not bind.
    func testLoadValidationRejectsHostileTimersAndScriptBindings() throws {
        let level = makeTrainingScript003Level()
        let world = GameWorld(level: level)
        XCTAssertNoThrow(try world.validate(against: level))
        let object = try XCTUnwrap(testWorldObject(world))

        func decoded(_ edit: (inout [String: Any]) throws -> Void) throws
            -> GameWorld
        {
            var copy = object
            try edit(&copy)
            return try decodeTestWorld(copy)
        }
        let hostileRepeat = try decoded { object in
            var timers = try XCTUnwrap(object["osirisTimers"] as? [String: Any])
            var entries = try XCTUnwrap(timers["entries"] as? [[String: Any]])
            entries[0]["repeats"] = true
            entries[0]["repeatCount"] = Int(Int32.min)
            timers["entries"] = entries
            object["osirisTimers"] = timers
        }
        XCTAssertThrowsError(try hostileRepeat.validate(against: level))

        let bound = try XCTUnwrap(world.objects.first { $0.scripts != nil })
        let custom = try XCTUnwrap(bound.scripts?.custom)
        let hostileBindings: [ObjectScripts?] = [
            ObjectScripts(custom: custom, level: 0),
            ObjectScripts(custom: custom + 100, level: nil),
            nil, // a cleared required binding
        ]
        for scripts in hostileBindings {
            var hostile = world
            hostile.objects[bound.handle]?.scripts = scripts
            XCTAssertThrowsError(try hostile.validate(against: level))
        }
    }

    /// RenderObject draws no OBJ_DUMMY object (renderobject.cpp:1214). A
    /// ghost keeps its render type, so unghosting shows it again.
    func testGhostedObjectIsNotRenderedAndUnghostingShowsIt() throws {
        let level = makeSliceSixObjectRenderLevel()
        let view = defaultPlayerView(in: level)
        var world = GameWorld(level: level)
        func admitted() throws -> [UInt32] {
            try extractWorldForRendering(
                level,
                objects: world.objects,
                roomStates: world.rooms,
                camera: view.camera,
                startRoomSourceIndex: view.roomSourceIndex,
                excludedObjectHandle: view.objectHandle
            ).admittedObjectHandles
        }
        XCTAssertTrue(try admitted().contains(12_301))
        world.aObjGhostSet(1, ObjectHandle(12_301))
        XCTAssertEqual(world.objects[ObjectHandle(12_301)]?.renderType, .polyobj)
        XCTAssertFalse(try admitted().contains(12_301))
        world.aObjGhostSet(0, ObjectHandle(12_301))
        XCTAssertTrue(try admitted().contains(12_301))
    }

    func testPlayerInvulnerabilityEndsAtDoPlayerFrame() {
        var world = GameWorld(level: makeSliceSixObjectRenderLevel())
        world.setObjectInvulnerable(ObjectHandle(2_048), true, lifetime: 0.15)
        XCTAssertEqual(world.playerInvulnerableTime, 0.15)
        world.doPlayerInvulnerabilityFrame(frameTime: 0.1)
        XCTAssertNotNil(world.playerInvulnerableTime)
        world.doPlayerInvulnerabilityFrame(frameTime: 0.1)
        XCTAssertNil(world.playerInvulnerableTime)
    }
}
