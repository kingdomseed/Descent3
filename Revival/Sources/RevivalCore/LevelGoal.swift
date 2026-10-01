// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/levelgoal.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): lgoal::GoalComplete (:189),
// lgoal::GetStatus with LO_SET_SPECIFIED (:390), levelgoals::DoFrame
// (:1067), levelgoals::InitLevel (:1146), and levelgoals::Inform (:1220);
// and from physics/collide.cpp, check_lg_inform (:2366). `Level_goals` is
// `GameWorld.goals` (indexed like `Level.goals`) and its `m_flags` is
// `GameWorld.levelGoalFlags`. A goal's `m_goal_completed` is its
// LGF_COMPLETED bit: only Inform and DoFrame set the flags here, and both
// set them together. The room goals' RF_INFORM_RELINK_TO_LG and the
// LGF_COMP_ENTER inform of ObjSetPos (object.cpp:3166) arrive with object
// room changes in M2 (architecture.md section 9).

/// LIT_ goal item types (Descent3/levelgoal_external.h:26-30).
enum LevelGoalItemType {
    static let terrainCell: UInt8 = 0
    static let internalRoom: UInt8 = 1
    static let object: UInt8 = 2
    static let trigger: UInt8 = 3
    static let anyMine: UInt8 = 4
}

/// LGF_ goal flags (Descent3/levelgoal_external.h:38-60).
enum LevelGoalFlag {
    static let secondaryGoal: UInt32 = 0x0000_0002
    static let enabled: UInt32 = 0x0000_0004
    static let completed: UInt32 = 0x0000_0008
    static let guideBotDoesNotKnowLocation: UInt32 = 0x0000_0020
    static let notLocationBased: UInt32 = 0x0000_0040
    static let failed: UInt32 = 0x0000_0080
    static let completeActivate: UInt32 = 0x0000_0100
    static let completeEnter: UInt32 = 0x0000_0200
    static let completeDestroy: UInt32 = 0x0000_0400
    static let completePlayerWeapon: UInt32 = 0x0000_0800
    static let completePlayer: UInt32 = 0x0000_1000
    static let completeDallas: UInt32 = 0x0000_2000
    /// LGF_COMP_MASK.
    static let completeMask: UInt32 = completeActivate | completeEnter
        | completeDestroy | completePlayerWeapon | completePlayer
        | completeDallas
}

/// The level's `m_flags` (Descent3/levelgoal_external.h:23).
enum LevelGoalsFlag {
    static let allPrimariesDone: UInt32 = 0x02
}

extension GameObject {
    /// OF_INFORM_PLAYER_COLLIDE_TO_LG (object_external.h:300).
    static let informPlayerCollideToLevelGoalsFlag: UInt32 = 0x1000_0000
    /// OF_INFORM_PLAYER_WEAPON_COLLIDE_TO_LG (object_external.h:301).
    static let informPlayerWeaponCollideToLevelGoalsFlag: UInt32 =
        0x2000_0000
}

/// The HUD text of a completed goal: TXT_COMPLETED_HUD (stringtable.h:316)
/// is the English "Completed" until the engine string table arrives (M4).
let levelGoalCompletedText = "Completed"

extension GameWorld {
    /// The handle a goal item names: an object item's object handle, or the
    /// room or trigger number.
    func levelGoalItemHandle(_ goal: Int, item: Int) -> Int32 {
        guard goals.indices.contains(goal),
              goals[goal].items.indices.contains(item)
        else {
            return -1
        }
        let entry = goals[goal].items[item]
        return Int32(bitPattern: entry.objectHandle ?? entry.sourceHandle)
    }

    /// levelgoals::InitLevel (levelgoal.cpp:1146): every object and trigger
    /// loses its inform flags, and then each item of a goal sets the inform
    /// flag its completion type asks for.
    mutating func levelGoalsInitLevel(level: Level) {
        let informFlags = GameObject.informPlayerCollideToLevelGoalsFlag
            | GameObject.informPlayerWeaponCollideToLevelGoalsFlag
            | GameObject.informDestroyToLevelGoalsFlag
        for slot in 0..<ObjectTable.capacity {
            guard let object = objects.slots[slot] else { continue }
            objects[object.handle]?.flags &= ~informFlags
        }
        for index in triggerFlags.indices {
            triggerFlags[index] &= ~TriggerFlag.informActivateToLevelGoals
        }
        for (goalIndex, goal) in goals.enumerated() {
            let completion = goal.status & LevelGoalFlag.completeMask
            for itemIndex in goal.items.indices {
                let item = goal.items[itemIndex]
                let handle = levelGoalItemHandle(goalIndex, item: itemIndex)
                switch item.type {
                case LevelGoalItemType.object:
                    let objectHandle = ObjectHandle(UInt32(bitPattern: handle))
                    guard objects[objectHandle] != nil else { continue }
                    if completion == LevelGoalFlag.completePlayer {
                        objects[objectHandle]?.flags |=
                            GameObject.informPlayerCollideToLevelGoalsFlag
                    } else if completion == LevelGoalFlag.completePlayerWeapon {
                        objects[objectHandle]?.flags |=
                            GameObject.informPlayerWeaponCollideToLevelGoalsFlag
                    } else if completion == LevelGoalFlag.completeDestroy {
                        objects[objectHandle]?.flags |=
                            GameObject.informDestroyToLevelGoalsFlag
                    }
                case LevelGoalItemType.trigger:
                    if triggerFlags.indices.contains(Int(handle)),
                       completion == LevelGoalFlag.completeActivate {
                        triggerFlags[Int(handle)] |=
                            TriggerFlag.informActivateToLevelGoals
                    }
                default:
                    break
                }
            }
        }
    }

    /// levelgoals::Inform (levelgoal.cpp:1220): the first not-done item of
    /// each matching goal that names `handle` is done. The original's
    /// all-items check sets item `j` again instead of reading item `k`
    /// (:1255-1261), so every item reads done and the goal completes at
    /// once; that is kept. EVT_LEVEL_GOAL_ITEM_COMPLETE follows the goal's
    /// completion.
    mutating func levelGoalsInform(
        type: UInt8,
        completion: UInt32,
        handle: Int32,
        level: Level
    ) {
        for goalIndex in goals.indices {
            let flags = goals[goalIndex].status
            if flags & LevelGoalFlag.enabled == 0,
               [LevelGoalFlag.completeActivate, LevelGoalFlag.completeEnter,
                LevelGoalFlag.completePlayerWeapon,
                LevelGoalFlag.completePlayer].contains(completion) {
                continue
            }
            let current = flags & LevelGoalFlag.completeMask
            if flags != LevelGoalFlag.completeDallas, current != completion {
                continue
            }
            for itemIndex in goals[goalIndex].items.indices {
                let item = goals[goalIndex].items[itemIndex]
                if item.done || type != item.type
                    || levelGoalItemHandle(goalIndex, item: itemIndex) != handle
                {
                    continue
                }
                goals[goalIndex].items[itemIndex].done = true
                levelGoalSetStatus(
                    goalIndex,
                    LevelGoalFlag.completed,
                    level: level
                )
                osirisCallLevelEvent(
                    .levelGoalItemComplete(goal: goalIndex),
                    level: level
                )
            }
        }
    }

    /// lgoal::GetStatus with LO_SET_SPECIFIED (levelgoal.cpp:390): the
    /// flags are set, and a goal that becomes completed runs GoalComplete.
    mutating func levelGoalSetStatus(
        _ goal: Int,
        _ value: UInt32,
        announce: Bool = true,
        level: Level
    ) {
        let wasCompleted =
            goals[goal].status & LevelGoalFlag.completed != 0
        goals[goal].status |= value
        if value & LevelGoalFlag.completed != 0, !wasCompleted {
            levelGoalComplete(goal, announce: announce, level: level)
        }
    }

    /// lgoal::GoalComplete (levelgoal.cpp:189): the level script hears
    /// EVT_LEVEL_GOAL_COMPLETE, and then an enabled goal shows
    /// "Completed <name>" as a persistent HUD message with
    /// SOUND_GOAL_COMPLETE. A loaded goal always has a name string, so an
    /// empty name shows too. The persistent center message and the game
    /// message log arrive with the HUD (M4); the text is an ordinary HUD
    /// message until then (architecture.md section 9).
    private mutating func levelGoalComplete(
        _ goal: Int,
        announce: Bool,
        level: Level
    ) {
        osirisCallLevelEvent(.levelGoalComplete(goal: goal), level: level)
        let current = goals[goal]
        if announce, current.status & LevelGoalFlag.enabled != 0 {
            addHUDMessage("\(levelGoalCompletedText) \(current.name)")
            play3DSound(EngineSound.goalComplete)
        }
    }

    /// levelgoals::DoFrame (levelgoal.cpp:1067): an enabled goal whose first
    /// item is a terrain cell completes while the player is outside, and
    /// one whose first item is "any mine" while the player is inside. When
    /// no primary goal is active, the level script hears
    /// EVT_ALL_LEVEL_GOALS_COMPLETE once.
    mutating func levelGoalsDoFrame(level: Level) {
        let player = level.defaultPlayerBinding.flatMap {
            objects[ObjectHandle($0.objectHandle)]
        }
        let playerIsOutside: Bool
        if case .terrainCell = player?.location {
            playerIsOutside = true
        } else {
            playerIsOutside = false
        }
        for goalIndex in goals.indices {
            let flags = goals[goalIndex].status
            guard flags & (LevelGoalFlag.completed | LevelGoalFlag.failed)
                    == 0,
                  flags & LevelGoalFlag.enabled != 0,
                  let first = goals[goalIndex].items.first
            else {
                continue
            }
            let done: Bool
            switch first.type {
            case LevelGoalItemType.terrainCell:
                done = playerIsOutside
            case LevelGoalItemType.anyMine:
                done = !playerIsOutside
            default:
                continue
            }
            if done {
                levelGoalSetStatus(
                    goalIndex,
                    LevelGoalFlag.completed,
                    level: level
                )
            }
        }
        if levelGoalActiveGoals(secondary: false).isEmpty,
           levelGoalFlags & LevelGoalsFlag.allPrimariesDone == 0 {
            levelGoalFlags |= LevelGoalsFlag.allPrimariesDone
            osirisCallLevelEvent(.allLevelGoalsComplete, level: level)
        }
    }

    /// check_lg_inform (collide.cpp:2366) for `a` hit by `b`. The original
    /// passes the OF_INFORM_ flag as the completion type, which no goal's
    /// LGF_COMP_ type matches; that is kept.
    mutating func checkLevelGoalInform(
        _ a: ObjectHandle,
        _ b: ObjectHandle,
        level: Level
    ) {
        guard let objectA = objects[a], let objectB = objects[b] else {
            return
        }
        let handle = Int32(bitPattern: a.rawValue)
        let either = GameObject.informPlayerCollideToLevelGoalsFlag
            | GameObject.informPlayerWeaponCollideToLevelGoalsFlag
        if objectA.flags & either != 0, objectB.type == .player {
            let weapon = objectA.flags
                & GameObject.informPlayerWeaponCollideToLevelGoalsFlag != 0
            levelGoalsInform(
                type: LevelGoalItemType.object,
                completion: weapon
                    ? GameObject.informPlayerWeaponCollideToLevelGoalsFlag
                    : GameObject.informPlayerCollideToLevelGoalsFlag,
                handle: handle,
                level: level
            )
        }
        if objectA.flags
            & GameObject.informPlayerWeaponCollideToLevelGoalsFlag != 0,
           objectB.type == .weapon,
           objects[objectUltimateParent(b)]?.type == .player {
            levelGoalsInform(
                type: LevelGoalItemType.object,
                completion:
                    GameObject.informPlayerWeaponCollideToLevelGoalsFlag,
                handle: handle,
                level: level
            )
        }
    }
}
