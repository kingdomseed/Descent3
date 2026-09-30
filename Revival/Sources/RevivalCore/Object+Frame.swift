// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/object.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): ObjDoFrameAll's loop over the
// objects in ascending slots, ObjDoFrame (:2615) for CT_AI and weapon
// objects, and ObjDeleteDead (:2004) for dead weapons.
//
// Scope (M1 step 6): ObjDoFrameAll is one ascending-slot loop that
// includes the player (object.cpp:2969). The player's ObjDoFrame is still
// the session's player move (PlayerSimulationUpdate.swift), so the session
// runs this loop in two parts around it: the slots below the player's, the
// player's move, then the slots above. For the other objects this runs
// last_pos, lifeleft, the AI control (AIDoFrame), the lifeleft timeout, and
// the physics move of AI and weapon objects. The object EVT_INTERVAL,
// animation, effects, and the dead-object sequence of robots
// (EVT_CHILD_DIED, EVT_DESTROY) arrive with the general object frame and
// KillObject (M1 step 7, M2).

import Foundation

extension GameWorld {
    /// ObjDoFrameAll's loop (object.cpp:2969) for the live objects in
    /// `slots`, in ascending order. An object made during the loop in a
    /// later slot is processed in the same pass, as the C++ loop reads
    /// Highest_object_index each time. A player object is skipped: the
    /// bound player moves in the session, and an unused player start does
    /// nothing in single player.
    mutating func objDoFrameSlots(_ slots: Range<Int>, level: Level) {
        for slot in slots {
            guard let object = objects.slots[slot],
                  object.type != .player,
                  object.flags & GameObject.deadFlag == 0
            else {
                continue
            }
            objDoFrame(object.handle, level: level)
        }
    }

    /// ObjDoFrame (object.cpp:2615) for AI and weapon objects.
    private mutating func objDoFrame(_ handle: ObjectHandle, level: Level) {
        guard var object = objects[handle] else { return }
        object.lastPosition = object.position
        if let lifeLeft = object.lifeLeft {
            object.lifeLeft = lifeLeft - frameDuration
        }
        objects[handle] = object
        if object.ai != nil {
            aiDoFrame(handle, level: level)
        }
        // Death of old age: TimeoutObject and SetObjectDeadFlag. A weapon's
        // timeout effects arrive with visual effects.
        if let lifeLeft = objects[handle]?.lifeLeft, lifeLeft < 0 {
            objects[handle]?.flags |= GameObject.deadFlag
        }
        guard let moving = objects[handle],
              moving.flags & GameObject.deadFlag == 0
        else {
            return
        }
        if moving.type == .weapon {
            moveWeapon(handle, level: level)
        } else if moving.ai != nil {
            moveAIObject(handle, level: level)
        }
    }

    /// ObjDeleteDead (object.cpp:2004), run after the ObjDoFrameAll loop,
    /// for dead weapons: they free their slots. A weapon has no scripts,
    /// level goals, or inventory, so none of the robot death sequence
    /// applies to it.
    mutating func objDeleteDead() {
        for slot in 0..<ObjectTable.capacity {
            guard let object = objects.slots[slot],
                  object.flags & GameObject.deadFlag != 0,
                  object.type == .weapon
            else {
                continue
            }
            objects.delete(object.handle)
        }
    }
}
