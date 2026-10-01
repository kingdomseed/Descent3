// SPDX-License-Identifier: GPL-3.0-or-later
//
// The closed set of compiled game-module (default) scripts (architecture.md
// section 6). Legacy: Osiris_BindScriptsToObject (Descent3/
// OsirisLoadandBind.cpp:1427) loads the object's default module
// (Osiris_LoadGameModule, :1146), asks its GetGOScriptID for the page name,
// makes the instance with CreateInstance, and sends each event to the
// instance's CallEvent (Osiris_CallEvent, :2111). Here each module is
// compiled Swift. This file only lists the scripts and routes the calls to
// them. It holds no behavior.

/// One game-module script instance, stored on its object (the Osiris
/// instance memory).
enum DefaultScript: Codable, Equatable, Sendable {
    /// AIGame `GuideBot` (AIGame.cpp:1538).
    case guideBot(GuideBotState)
    /// AIGame `GBPowerup` (AIGame.cpp:1280).
    case gbPowerup(GBPowerupState)
    /// generic `GenericScript` (generic.cpp:87), the default powerup
    /// script. It has no state.
    case genericPowerup

    /// The script identity, without its state.
    enum ID: Equatable, Sendable {
        case guideBot
        case gbPowerup
        case genericPowerup
    }

    var id: ID {
        switch self {
        case .guideBot: .guideBot
        case .gbPowerup: .gbPowerup
        case .genericPowerup: .genericPowerup
        }
    }

    /// The module's GetGOScriptID for a page name. `module` is the canonical
    /// module name (`ObjectScriptBinding.defaultModuleName`). A module that
    /// is not compiled in gives no script.
    static func scriptID(
        module: String,
        pageName: String,
        isDoor: Bool = false
    ) -> ID? {
        switch module {
        case AIGame.moduleName:
            AIGame.getGOScriptID(pageName)
        case GenericModule.moduleName:
            GenericModule.getGOScriptID(pageName, isDoor: isDoor)
        default:
            nil
        }
    }

    /// CreateInstance: a new instance with its state not yet initialized.
    init(_ id: ID) {
        switch id {
        case .guideBot: self = .guideBot(GuideBotState())
        case .gbPowerup: self = .gbPowerup(GBPowerupState())
        case .genericPowerup: self = .genericPowerup
        }
    }

    /// The module of each script.
    static func module(of id: ID) -> String {
        switch id {
        case .guideBot, .gbPowerup: AIGame.moduleName
        case .genericPowerup: GenericModule.moduleName
        }
    }

    /// The names a compiled module looks up at run time, for D3Import and
    /// package validation.
    static func references(module: String) -> GameModuleReferences? {
        switch module {
        case AIGame.moduleName: AIGame.references
        case GenericModule.moduleName: GenericModule.references
        default: nil
        }
    }

    /// Whether saved script state fits the runtime's assumptions.
    var isValidSavedState: Bool {
        switch self {
        case let .guideBot(state): GuideBotScript.isValidSavedState(state)
        case let .gbPowerup(state): GBPowerupScript.isValidSavedState(state)
        case .genericPowerup: true
        }
    }

    /// The instance's CallEvent. The instance is read from the object each
    /// time, so a call that re-enters the engine sees the latest state.
    static func callEvent(
        _ event: ScriptEvent,
        me: ObjectHandle,
        world: inout GameWorld,
        level: Level
    ) -> ChainFlags {
        switch world.objects[me]?.scripts?.defaultScript?.id {
        case .guideBot:
            GuideBotScript.callEvent(event, me: me, world: &world, level: level)
        case .gbPowerup:
            GBPowerupScript.callEvent(
                event,
                me: me,
                world: &world,
                level: level
            )
        case .genericPowerup:
            GenericPowerupScript.callEvent(
                event,
                me: me,
                world: &world,
                level: level
            )
        case nil:
            .all
        }
    }
}

/// The names one compiled game module references at run time. D3Import puts
/// them into the package; the runtime resolves them by name, as the module's
/// `Sound_FindId`, `Wpn_FindID`, and `Obj_FindID` calls do.
struct GameModuleReferences: Equatable, Sendable {
    /// Sound pages the module plays.
    let soundNames: [String]
    /// Weapon pages the module fires, with their timeout spawns.
    let weaponNames: [String]
    /// Object pages the module creates.
    let objectPageNames: [String]
    /// The number of strings the module's `.str` table must have: one more
    /// than the highest `TXT()` index it uses.
    let stringCount: Int
}
