// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/object.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): ObjDoFrameAll's loop over the
// objects in ascending slots and its tail (:2926-3004), ObjDoFrame (:2615)
// for the objects other than the player, TimeoutObject (:2156), and
// ObjDeleteDead (:2004).
//
// ObjDoFrameAll is one ascending-slot loop that
// includes the player (object.cpp:2969). The player's ObjDoFrame is still
// the session's player move (PlayerSimulationUpdate.swift), so the session
// runs this loop in two parts around it: the slots below the player's, the
// player's move, then the slots above; then `objDoFrameAllTail`. For the
// other objects this runs last_pos, lifeleft, the control (AIDoFrame,
// DoDyingFrame, DoDebrisFrame, DoSplinterFrame, DoExplosionFrame;
// WeaponDoFrame's parent-collision timer is read where a weapon moves), the
// lifeleft timeout, and the movement (AI, weapon, shockwave, and generic
// physics), and the object's EVT_INTERVAL. The animation and effects
// arrive with the general object frame (M2). ObjDeleteDead keeps the order of the
// original; the level goal inform and the inventory removal arrive with
// level goals and inventory (M1 step 9), and no imported object sets their
// flags before then.

import Foundation

extension GameWorld {
    /// ObjDoFrameAll's loop (object.cpp:2969) for the live objects in
    /// `slots`, in ascending order. An object made during the loop in a
    /// later slot is processed in the same pass, as the C++ loop reads
    /// Highest_object_index each time. The player object is skipped: it
    /// moves (and gets its EVT_INTERVAL) in the session. It is the only
    /// player object: GameWorld's init deletes the others, as
    /// DeleteMultiplayerObjects does in single player (Player.cpp:1365).
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

    /// The end of ObjDoFrameAll (object.cpp:2992-3003): the visual effects
    /// move, and then everything that died is deleted.
    mutating func objDoFrameAllTail(level: Level) {
        visEffectMoveAll(level: level)
        objDeleteDead(level: level)
    }

    /// ObjDoFrame (object.cpp:2615) for an object other than the player.
    private mutating func objDoFrame(_ handle: ObjectHandle, level: Level) {
        guard var object = objects[handle] else { return }
        object.lastPosition = object.position
        if let lifeLeft = object.lifeLeft {
            object.lifeLeft = lifeLeft - frameDuration
        }
        objects[handle] = object
        // The control: CT_DYING, CT_AI, CT_DEBRIS, CT_SPLINTER, or
        // CT_EXPLOSION.
        if object.dying != nil {
            doDyingFrame(handle, level: level)
        } else if object.ai != nil {
            aiDoFrame(handle, level: level)
        } else if object.debris != nil {
            doDebrisFrame(handle, level: level)
        } else if object.type == .splinter, object.splinterFace != nil {
            doSplinterFrame(handle, level: level)
        } else if object.type == .fireball, object.fireball != nil {
            doExplosionFrame(handle)
        }
        // Death of old age: TimeoutObject and SetObjectDeadFlag.
        if let aged = objects[handle],
           aged.flags & GameObject.deadFlag == 0,
           let lifeLeft = aged.lifeLeft, lifeLeft < 0 {
            timeoutObject(handle, level: level)
            objects[handle]?.flags |= GameObject.deadFlag
        }
        // A dead object stops here (object.cpp:2777).
        guard let moving = objects[handle],
              moving.flags & GameObject.deadFlag == 0
        else {
            return
        }
        // do_physics_sim does not move a ghosted object (physics.cpp:751).
        if moving.type != .dummy {
            switch moving.type {
            case .weapon:
                moveWeapon(handle, level: level)
            case .shockwave:
                shockwaveConcussiveForce(handle, level: level)
            default:
                if moving.physics != nil,
                   moving.ai == nil || moving.dying != nil {
                    movePhysicsObject(handle, level: level)
                } else if moving.ai != nil, moving.usesPhysics {
                    moveAIObject(handle, level: level)
                }
            }
        }
        objectIntervalEvent(handle, level: level)
    }

    /// The object's EVT_INTERVAL after its movement (object.cpp:2868-2876),
    /// with this frame's Frametime and Gametime.
    mutating func objectIntervalEvent(_ handle: ObjectHandle, level: Level) {
        guard objects[handle] != nil else { return }
        osirisCallEvent(
            handle,
            .interval(frameTime: frameDuration, gameTime: gameTime),
            level: level
        )
    }

    /// TimeoutObject (object.cpp:2156).
    private mutating func timeoutObject(
        _ handle: ObjectHandle,
        level: Level
    ) {
        switch objects[handle]?.type {
        case .weapon:
            timeoutWeapon(handle, level: level)
        case .shockwave:
            shockwaveConcussiveForce(handle, level: level)
        default:
            break
        }
    }

    /// ObjDeleteDead (object.cpp:2004), run after the ObjDoFrameAll loop:
    /// for each dead object in slot order, a ghost is unghosted, an attached
    /// polygon object's attach parent hears EVT_CHILD_DIED, the object's
    /// scripts hear EVT_DESTROY (dying), its scripts are detached, and it is
    /// deleted (the player is not). The dead visual effects go last.
    mutating func objDeleteDead(level: Level) {
        for slot in 0..<ObjectTable.capacity {
            guard var object = objects.slots[slot],
                  object.flags & GameObject.deadFlag != 0
            else {
                continue
            }
            let handle = object.handle
            if object.type == .dummy {
                unghostObject(handle)
                object = objects[handle]!
            }
            if object.flags & GameObject.polygonObjectFlag != 0 {
                if object.flags & GameObject.attachedFlag != 0 {
                    osirisCallEvent(
                        object.attachUltimateHandle,
                        .childDied(it: handle),
                        level: level
                    )
                }
                // UnattachFromParent and UnattachChildren.
                objects[handle]?.flags &= ~GameObject.attachedFlag
                objects[handle]?.attachUltimateHandle = .none
            }
            osirisCallEvent(handle, .destroy(isDying: true), level: level)
            // Osiris_DetachScriptsFromObject.
            objects[handle]?.scripts = nil
            if objects[handle]?.type != .player {
                objects.delete(handle)
            }
        }
        visEffectDeleteDead()
    }
}
