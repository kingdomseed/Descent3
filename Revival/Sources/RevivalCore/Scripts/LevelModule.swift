// SPDX-License-Identifier: GPL-3.0-or-later
//
// The closed set of compiled level scripts (architecture.md section 6).
// Legacy: Osiris_LoadLevelModule (Descent3/OsirisLoadandBind.cpp:943) loads
// the module named by the level file, and the engine then calls the
// module's exports (InitializeDLL, GetGOScriptID, GetCOScriptList,
// GetTriggerScriptID, and each script's CallEvent). Here each module is
// compiled Swift. This file only lists the modules and routes the calls to
// them. It holds no behavior.

/// The loaded level module and its state. `none` is a level with no
/// compiled script.
enum LevelModule: Codable, Equatable, Sendable {
    case none
    case trainingMission(TrainingMissionState)

    /// Osiris_LoadLevelModule and the module's InitializeDLL. The module is
    /// the canonical level script name (`LevelScripting.levelScript`).
    static func load(level: Level) -> LevelModule {
        switch level.scripting?.levelScript {
        case "trainingmission":
            .trainingMission(TrainingMissionScript.initializeDLL())
        default:
            .none
        }
    }

    /// The names a compiled level script looks up at run time, for D3Import.
    /// `name` is the canonical level script name (`LevelScripting.levelScript`).
    static func scriptReferences(
        forLevelScript name: String
    ) -> LevelScriptReferences? {
        switch name {
        case "trainingmission": TrainingMissionScript.references
        default: nil
        }
    }

    /// Whether saved module state fits the module the level loads.
    func isValidSavedState(forLoaded loaded: LevelModule) -> Bool {
        switch (self, loaded) {
        case (.none, .none):
            true
        case let (.trainingMission(state), .trainingMission):
            TrainingMissionScript.isValidSavedState(state)
        default:
            false
        }
    }

    /// GetGOScriptID.
    func genericScriptID(pageName: String, isDoor: Bool) -> Int32? {
        switch self {
        case .none:
            nil
        case .trainingMission:
            TrainingMissionScript.genericScriptID(
                pageName: pageName,
                isDoor: isDoor
            )
        }
    }

    /// GetCOScriptList.
    func customScriptList(
        level: Level
    ) -> [(handle: ObjectHandle, id: Int32)] {
        switch self {
        case .none: []
        case .trainingMission:
            TrainingMissionScript.customScriptList(level: level)
        }
    }

    /// GetTriggerScriptID for one trigger's room and face.
    func triggerScriptID(triggerIndex: Int, level: Level) -> Int32? {
        switch self {
        case .none: nil
        case .trainingMission:
            TrainingMissionScript.triggerScriptID(
                triggerIndex: triggerIndex,
                level: level
            )
        }
    }

    /// The level script's CallEvent.
    static func callLevelEvent(
        _ event: ScriptEvent,
        world: inout GameWorld,
        level: Level
    ) -> ChainFlags {
        switch world.levelModule {
        case .none:
            .all
        case .trainingMission:
            TrainingMissionScript.callLevelEvent(
                event,
                world: &world,
                level: level
            )
        }
    }

    /// A custom object script's CallEvent.
    static func callCustomObjectEvent(
        id: Int32,
        event: ScriptEvent,
        me: ObjectHandle,
        world: inout GameWorld,
        level: Level
    ) -> ChainFlags {
        switch world.levelModule {
        case .none:
            .all
        case .trainingMission:
            TrainingMissionScript.callCustomObjectEvent(
                id: id,
                event: event,
                me: me,
                world: &world,
                level: level
            )
        }
    }

    /// A generic object script's CallEvent. Only modules whose
    /// GetGOScriptID returns ids can be reached here.
    static func callGenericObjectEvent(
        id: Int32,
        event: ScriptEvent,
        me: ObjectHandle,
        world: inout GameWorld,
        level: Level
    ) -> ChainFlags {
        switch world.levelModule {
        case .none, .trainingMission:
            preconditionFailure("The module has no generic object scripts.")
        }
    }

    /// A trigger script's CallEvent.
    static func callTriggerEvent(
        id: Int32,
        event: ScriptEvent,
        world: inout GameWorld,
        level: Level
    ) -> ChainFlags {
        switch world.levelModule {
        case .none:
            .all
        case .trainingMission:
            TrainingMissionScript.callTriggerEvent(
                id: id,
                event: event,
                world: &world,
                level: level
            )
        }
    }
}
