// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/generic.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): GetGOScriptID (:177) and
// GenericScript::CallEvent (:310), the default script of every powerup
// whose page names the "generic" module. The RapidFire, ForceWall, and
// WingNut scripts and GenericDoor arrive with their weapons and doors in
// M2; until then those pages get no default script (architecture.md
// section 9). The module's string table is not read yet.

enum GenericModule {
    /// The module's canonical name (the lowercased file stem).
    static let moduleName = "generic"

    /// ScriptIDInfo (generic.cpp:85): the named scripts.
    private static let namedScripts = ["RapidFire", "Forcewall", "GoWingNut"]

    /// GetGOScriptID (generic.cpp:177): a named script's id, or
    /// GENERIC_POWERUP_SCRIPTID for any other object and
    /// GENERIC_DOOR_SCRIPTID for a door. `nil` for the scripts that are
    /// not translated yet.
    static func getGOScriptID(_ name: String, isDoor: Bool) -> DefaultScript.ID? {
        if isDoor {
            return nil
        }
        if namedScripts.contains(where: {
            $0.caseInsensitiveCompare(name) == .orderedSame
        }) {
            return nil
        }
        return .genericPowerup
    }

    /// The names the module looks up at run time: none for the powerup
    /// script.
    static let references = GameModuleReferences(
        soundNames: [],
        weaponNames: [],
        objectPageNames: [],
        stringCount: 0
    )
}

enum GenericPowerupScript {
    /// GenericScript::CallEvent (generic.cpp:310): a player that touches
    /// the powerup gets it through MSafe_DoPowerup.
    static func callEvent(
        _ event: ScriptEvent,
        me: ObjectHandle,
        world: inout GameWorld,
        level: Level
    ) -> ChainFlags {
        if case let .collide(it) = event,
           world.objects[it]?.type == .player {
            world.doPowerup(me, player: it, level: level)
        }
        return .all
    }
}
