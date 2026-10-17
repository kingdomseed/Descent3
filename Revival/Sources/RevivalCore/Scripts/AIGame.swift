// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/AIGame.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): the module's shared code: the
// string table access GetStringFromTable (:50) and its TXT indices
// (:59-203), the script ids and names (:254-341, ScriptInfo), GetGOScriptID
// (:2449), IsGoalFinishedNotify (:2759), and the random numbers of the
// module (rand() and RAND_MAX). The classes are in AIGame+<Class>.swift.
//
// The module's rand() is the C library generator of the released DLL, on
// its own state in `GameWorld` (sources.md; architecture.md section 9).

import Foundation

/// The AIGame game module.
enum AIGame {
    /// The module's canonical name (get_full_path_to_module,
    /// OsirisLoadandBind.cpp:884).
    static let moduleName = "aigame"

    /// ScriptInfo (AIGame.cpp:283) for the classes translated so far. The
    /// other classes (the robots, the thief, and the weapons' scripts)
    /// arrive with them in M2; until then their pages bind no script.
    private static let scriptNames: [(name: String, id: DefaultScript.ID)] = [
        ("Guidebot", .guideBot),
        ("GBPowerup", .gbPowerup),
    ]

    /// GetGOScriptID (AIGame.cpp:2449): the script whose name matches the
    /// page name (stricmp).
    static func getGOScriptID(_ pageName: String) -> DefaultScript.ID? {
        scriptNames.first {
            $0.name.caseInsensitiveCompare(pageName) == .orderedSame
        }?.id
    }

    /// The names the module looks up at run time (Sound_FindId, Wpn_FindID,
    /// and the Obj_FindID of the objects it creates), and the size of its
    /// string table: TXT(145) is the highest index it reads.
    static let references = GameModuleReferences(
        soundNames: [
            "GBExpulsionA", "GBotAcceptOrder1", "GBotConcern1",
            "GBotEngineB1", "GBotEuphoria1", "GBotExcited1", "GBotGreetB1",
            "GBotHurt1", "GBotPlayerKillBot1", "Flare", "Powerup pickup",
        ],
        weaponNames: ["Yellow flare"],
        objectPageNames: ["Invisiblepowerup"],
        stringCount: 146
    )

    /// String_table's missing and empty entries (AIGame.cpp:47-48).
    static let errorString = "!!ERROR MISSING STRING!!"

    /// GetStringFromTable (AIGame.cpp:50): TXT(index) of the module's table.
    static func text(_ index: Int, level: Level) -> String {
        guard let strings = level.gameModules?.first(where: {
            $0.module == moduleName
        })?.strings,
            strings.indices.contains(index)
        else {
            return errorString
        }
        return strings[index]
    }

    /// RAND_MAX of the module's C library (0x7fff).
    static let randMax: Int32 = 0x7fff

    /// IsGoalFinishedNotify (AIGame.cpp:2759).
    static func isGoalFinishedNotify(_ type: AINotifyType) -> Bool {
        [.goalComplete, .goalInvalid, .goalFail, .goalError].contains(type)
    }
}

extension GameWorld {
    /// The module's `rand()`: the rand of the MSVC C library the released
    /// Windows DLL used (`holdrand * 214013 + 2531011`, bits 16-30), on the
    /// module's own state (`gameModuleRandomState`), not `ps_rand`.
    mutating func aigameRand() -> Int32 {
        gameModuleRandomState =
            gameModuleRandomState &* 214_013 &+ 2_531_011
        return Int32((gameModuleRandomState >> 16) & 0x7fff)
    }

    /// The module's `(float)rand() / (float)RAND_MAX`.
    mutating func aigameRandFraction() -> Float {
        Float(aigameRand()) / Float(AIGame.randMax)
    }
}
