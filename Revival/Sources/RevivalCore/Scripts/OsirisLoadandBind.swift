// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/OsirisLoadandBind.cpp (Descent 3, Copyright (C)
// 2024 Parallax Software, GPL-3.0-or-later): Osiris_BindScriptsToObject
// (:1427), Osiris_CallLevelEvent (:1948), Osiris_CallTriggerEvent (:2007),
// and Osiris_CallEvent (:2111). The event numbers and results come from
// scripts/osiris_common.h (:357-400). The scripts are compiled Swift, so DLL
// loading, module reference counts, and instance memory are gone: a slot
// holds the script id that the level module dispatches on.

/// The Osiris events (osiris_common.h:363-400) with the payload fields of
/// tOSIRISEventInfo that the translated scripts read. EVT_SAVESTATE,
/// EVT_RESTORESTATE, and EVT_MEMRESTORE are dropped: Codable `GameWorld`
/// replaces them (architecture.md section 6).
enum ScriptEvent: Equatable, Sendable {
    case interval(frameTime: Float, gameTime: Float)      // EVT_INTERVAL
    case aiFrame                                           // EVT_AI_FRAME
    case damaged(it: ObjectHandle, damage: Float)          // EVT_DAMAGED
    case collide(it: ObjectHandle)                         // EVT_COLLIDE
    case created                                           // EVT_CREATED
    case destroy(isDying: Bool)                            // EVT_DESTROY
    case timer(id: Int32, gameTime: Float)                 // EVT_TIMER
    case use(it: ObjectHandle)                             // EVT_USE
    case aiNotify(AINotifyType, it: ObjectHandle)          // EVT_AI_NOTIFY
    case aiInit                                            // EVT_AI_INIT
    case levelStart                                        // EVT_LEVELSTART
    case levelEnd                                          // EVT_LEVELEND
    case changeSegment(room: Int)                          // EVT_CHANGESEG
    case timerCancel(handle: Int32, detonated: Bool)       // EVT_TIMERCANCEL
    case ainObjectKilled                                   // EVT_AIN_OBJKILLED
    case ainSeePlayer                                      // EVT_AIN_SEEPLAYER
    case ainWeaponHitObject                                // EVT_AIN_WHITOBJECT
    case ainGoalComplete                                   // EVT_AIN_GOALCOMPLETE
    case ainGoalFail                                       // EVT_AIN_GOALFAIL
    case ainMeleeHit                                       // EVT_AIN_MELEE_HIT
    case ainMeleeAttackFrame                               // EVT_AIN_MELEE_ATTACK_FRAME
    case ainMovieStart                                     // EVT_AIN_MOVIE_START
    case ainMovieEnd                                       // EVT_AIN_MOVIE_END
    case matcenCreate(it: ObjectHandle, matcen: Int)       // EVT_MATCEN_CREATE
    case doorActivate                                      // EVT_DOOR_ACTIVATE
    case doorClose                                         // EVT_DOOR_CLOSE
    case childDied(it: ObjectHandle)                       // EVT_CHILD_DIED
    case levelGoalComplete(goal: Int)                      // EVT_LEVEL_GOAL_COMPLETE
    case allLevelGoalsComplete                             // EVT_ALL_LEVEL_GOALS_COMPLETE
    case levelGoalItemComplete(goal: Int)                  // EVT_LEVEL_GOAL_ITEM_COMPLETE
    case playerMovieStart                                  // EVT_PLAYER_MOVIE_START
    case playerMovieEnd                                    // EVT_PLAYER_MOVIE_END
    case playerRespawn(it: ObjectHandle)                   // EVT_PLAYER_RESPAWN
    case playerDies(it: ObjectHandle)                      // EVT_PLAYER_DIES
}

/// The AIN_ notify types that Osiris maps to a child event
/// (OsirisLoadandBind.cpp:2139-2175).
enum AINotifyType: Equatable, Sendable {
    case objectKilled
    case seeTarget
    case weaponHitObject
    case goalComplete
    case goalInvalid
    case goalFail
    case goalError
    case meleeHit
    case meleeAttackFrame
    case movieStart
    case movieEnd
    /// Any other notify type. It has no child event.
    case other
}

/// The value a script's CallEvent returns (osiris_common.h:357-358).
struct ChainFlags: OptionSet, Equatable, Sendable {
    let rawValue: UInt16

    /// CONTINUE_CHAIN: the next script in the chain gets the event.
    static let continueChain = ChainFlags(rawValue: 0x0100)
    /// CONTINUE_DEFAULT: the engine runs its own default action.
    static let continueDefault = ChainFlags(rawValue: 0x0001)
    /// What every DALLAS-generated CallEvent returns.
    static let all: ChainFlags = [.continueChain, .continueDefault]
}

/// The scripts bound to one object (tOSIRISScript). Each slot holds a script
/// id in the level module. The mission and default (game module) slots join
/// this list when their modules are translated (M1 step 8 adds the
/// `AIGame` default scripts); until then no object has them.
struct ObjectScripts: Codable, Equatable, Sendable {
    /// The custom object script (COS) id from GetCOScriptList.
    var custom: Int32?
    /// The level module's generic object script (GOS) id from
    /// GetGOScriptID.
    var level: Int32?
}

/// A bound slot, in Osiris_CallEvent's chain order.
enum ObjectScriptSlot: Equatable, Sendable {
    case custom(Int32)
    case level(Int32)
}

extension ScriptEvent {
    /// The child event Osiris_CallEvent sends first to each object script
    /// slot for an EVT_AI_NOTIFY (OsirisLoadandBind.cpp:2139-2175).
    var objectChildEvent: ScriptEvent? {
        guard case let .aiNotify(type, _) = self else { return nil }
        switch type {
        case .objectKilled: return .ainObjectKilled
        case .seeTarget: return .ainSeePlayer
        case .weaponHitObject: return .ainWeaponHitObject
        case .goalComplete: return .ainGoalComplete
        case .goalInvalid, .goalFail, .goalError: return .ainGoalFail
        case .meleeHit: return .ainMeleeHit
        case .meleeAttackFrame: return .ainMeleeAttackFrame
        case .movieStart: return .ainMovieStart
        case .movieEnd: return .ainMovieEnd
        case .other: return nil
        }
    }

    /// The child event Osiris_CallLevelEvent and Osiris_CallTriggerEvent send
    /// after an EVT_AI_NOTIFY. Only the goal types have one
    /// (OsirisLoadandBind.cpp:1964-1979, :2029-2044).
    var levelChildEvent: ScriptEvent? {
        guard case let .aiNotify(type, _) = self else { return nil }
        switch type {
        case .goalComplete: return .ainGoalComplete
        case .goalInvalid, .goalFail, .goalError: return .ainGoalFail
        default: return nil
        }
    }
}

/// The chain of Osiris_CallEvent (OsirisLoadandBind.cpp:2177-2250). Each
/// bound slot first gets the child event, if any, and then the event. The
/// chain goes on while a slot returns `continueChain`. The result is the
/// `continueDefault` bit of the last event call; the child event's result is
/// ignored.
func osirisCallObjectChain<Slot>(
    _ slots: [Slot],
    event: ScriptEvent,
    call: (Slot, ScriptEvent) -> ChainFlags
) -> Bool {
    let childEvent = event.objectChildEvent
    var result = ChainFlags.all
    for slot in slots {
        guard result.contains(.continueChain) else { break }
        if let childEvent {
            _ = call(slot, childEvent)
        }
        result = call(slot, event)
    }
    return result.contains(.continueDefault)
}

/// The single-script call of Osiris_CallLevelEvent and
/// Osiris_CallTriggerEvent (OsirisLoadandBind.cpp:1988-1996, :2052-2060):
/// the event first, then the child event, whose result replaces the
/// event's result.
func osirisCallSingleScript(
    event: ScriptEvent,
    call: (ScriptEvent) -> ChainFlags
) -> Bool {
    var result = call(event)
    if let childEvent = event.levelChildEvent {
        result = call(childEvent)
    }
    return result.contains(.continueDefault)
}

extension ObjectScripts {
    /// The bound slots in chain order (custom, level, then mission and
    /// default when those exist).
    var chain: [ObjectScriptSlot] {
        [custom.map(ObjectScriptSlot.custom), level.map(ObjectScriptSlot.level)]
            .compactMap { $0 }
    }
}

extension GameWorld {
    /// Osiris_BindScriptsToObject (OsirisLoadandBind.cpp:1427). The object
    /// type decides whether it can hold scripts, using the real type of a
    /// ghosted object. Then the level module gives its generic script for
    /// the object's page name, and its custom script for the object's
    /// handle. The call sends no events.
    mutating func osirisBindScriptsToObject(
        _ handle: ObjectHandle,
        level: Level
    ) {
        guard var object = objects[handle], object.scripts == nil,
              let scripts = osirisScripts(for: object, level: level)
        else {
            return
        }
        object.scripts = scripts
        objects[handle] = object
    }

    /// The scripts Osiris_BindScriptsToObject gives `object` from the loaded
    /// level module, or `nil` when it gets none. Save validation uses it too.
    func osirisScripts(for object: GameObject, level: Level) -> ObjectScripts? {
        let handle = object.handle
        let realType = object.type == .dummy
            ? object.dummyType ?? object.type
            : object.type
        guard LevelScripting.scriptableObjectTypes.contains(realType.rawValue)
        else {
            return nil
        }
        let customOnly =
            realType.rawValue == LevelScripting.customOnlyObjectType
        let pageName = customOnly
            ? nil
            : level.scripting?.objects
                .first { $0.objectHandle == handle.rawValue }?
                .defaultScriptName
        var scripts = ObjectScripts()
        if let pageName {
            scripts.level = levelModule.genericScriptID(
                pageName: pageName,
                isDoor: realType == .door
            )
        }
        scripts.custom = levelModule.customScriptList(level: level)
            .first { $0.handle == handle }?.id
        return scripts == ObjectScripts() ? nil : scripts
    }

    /// Osiris_CallEvent (OsirisLoadandBind.cpp:2111). Returns whether the
    /// engine runs its default action. An object with no scripts returns
    /// `true`.
    @discardableResult
    mutating func osirisCallEvent(
        _ handle: ObjectHandle,
        _ event: ScriptEvent,
        level: Level
    ) -> Bool {
        guard let scripts = objects[handle]?.scripts else { return true }
        return osirisCallObjectChain(scripts.chain, event: event) {
            slot, event in
            switch slot {
            case let .custom(id):
                LevelModule.callCustomObjectEvent(
                    id: id,
                    event: event,
                    me: handle,
                    world: &self,
                    level: level
                )
            case let .level(id):
                LevelModule.callGenericObjectEvent(
                    id: id,
                    event: event,
                    me: handle,
                    world: &self,
                    level: level
                )
            }
        }
    }

    /// Osiris_CallLevelEvent (OsirisLoadandBind.cpp:1948). With no level
    /// module loaded it returns `true`.
    @discardableResult
    mutating func osirisCallLevelEvent(
        _ event: ScriptEvent,
        level: Level
    ) -> Bool {
        guard levelModule != .none else { return true }
        return osirisCallSingleScript(event: event) { event in
            LevelModule.callLevelEvent(event, world: &self, level: level)
        }
    }

    /// Osiris_CallTriggerEvent (OsirisLoadandBind.cpp:2007). The trigger's
    /// script is the one the level module names for its room and face
    /// (GetTriggerScriptID, bound at level start by InitTriggerScript).
    @discardableResult
    mutating func osirisCallTriggerEvent(
        _ triggerIndex: Int,
        _ event: ScriptEvent,
        level: Level
    ) -> Bool {
        guard level.triggers.indices.contains(triggerIndex),
              let id = levelModule.triggerScriptID(
                  triggerIndex: triggerIndex,
                  level: level
              )
        else {
            return true
        }
        return osirisCallSingleScript(event: event) { event in
            LevelModule.callTriggerEvent(
                id: id,
                event: event,
                world: &self,
                level: level
            )
        }
    }

    /// The level start sequence from StartLevel (gamesequence.cpp:1584,
    /// :1600) and InitLevelScript (Mission.cpp:1687): the timers are reset,
    /// the level module is loaded, EVT_LEVELSTART goes to it, and then
    /// AssignScriptsForLevel (ObjScript.cpp:164) runs InitObjectScripts
    /// (ObjScript.cpp:199) for every object in slot order: bind, then
    /// EVT_AI_INIT for an AI object, then EVT_CREATED. A restored game skips
    /// all of this, as the original skips EVT_LEVELSTART when IsRestoredGame
    /// is set; the saved world already holds the result.
    mutating func startLevelScripts(level: Level) {
        startLevelScripts(level: level) { world, handle, event in
            world.osirisCallEvent(handle, event, level: level)
        }
    }

    /// The level start sequence with the object events passed in, so a test
    /// can record them.
    mutating func startLevelScripts(
        level: Level,
        sendObjectEvent: (inout GameWorld, ObjectHandle, ScriptEvent) -> Void
    ) {
        osirisTimers.resetAll()
        levelModule = LevelModule.load(level: level)
        osirisCallLevelEvent(.levelStart, level: level)
        for slot in 0..<ObjectTable.capacity {
            guard let object = objects.slots[slot], object.scripts == nil
            else {
                continue
            }
            osirisBindScriptsToObject(object.handle, level: level)
            // A CT_AI object is one with an AI frame (ObjScript.cpp:206).
            if objects[object.handle]?.ai != nil {
                sendObjectEvent(&self, object.handle, .aiInit)
            }
            sendObjectEvent(&self, object.handle, .created)
        }
    }
}
