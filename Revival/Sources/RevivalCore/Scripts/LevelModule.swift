// SPDX-License-Identifier: GPL-3.0-or-later
//
// The closed set of compiled level scripts (architecture.md section 6).
// Legacy: Osiris_LoadLevelModule (Descent3/OsirisLoadandBind.cpp:943) loads
// the module named by the level file. Here each module is compiled Swift, and
// this file only lists them. It holds no behavior. M1 step 4 adds the module
// state cases and the event dispatch switch.

enum LevelModule {
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
}
