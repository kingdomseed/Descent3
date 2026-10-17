// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/DallasFuncs.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): the AI actions aAISetTeam (:3378)
// and aAIGoalFollowPathSimple (:3638), the object queries qObjCanSeeObj
// (:5316) and qObjEnergy (:5615), the action aObjSetEnergy (:1871), and
// aCancelTimer (:2501). Their engine calls are osipf_AIValue (AIV_I_FLAGS,
// AIV_I_TARGET_HANDLE, Descent3/osiris_predefs.cpp:1096, :1330),
// osipf_AIGoalFollowPathSimple (AIGoal.swift), MSAFE_OBJECT_POS,
// MSAFE_OBJECT_ORIENT, and MSAFE_OBJECT_ENERGY (Descent3/multisafe.cpp:741,
// :748, :865, :1571), and Osiris_CancelTimerID.

import Foundation

extension GameWorld {
    /// aAISetTeam (DallasFuncs.cpp:3378): replace the object's AIF_TEAM_
    /// bits with `team`, then clear its target (AISetTarget).
    mutating func aAISetTeam(_ team: Int32, _ objhandle: ObjectHandle) {
        guard var object = objects[objhandle], var ai = object.ai else {
            return
        }
        ai.flags &= ~ObjectAIFrame.teamMask
        ai.flags |= UInt32(bitPattern: team)
        ai.targetHandle = .none
        ai.lastSeeTargetPosition = object.position
        object.ai = ai
        objects[objhandle] = object
    }

    /// aAIGoalFollowPathSimple (DallasFuncs.cpp:3638): the object follows
    /// the path in goal slot `priority`. A path id of -1 does nothing.
    mutating func aAIGoalFollowPathSimple(
        _ objhandle: ObjectHandle,
        _ pathid: Int,
        _ flags: Int32,
        _ goalid: Int32,
        _ priority: Int,
        level: Level
    ) {
        guard pathid != -1 else { return }
        aiGoalFollowPathSimple(
            objhandle,
            pathID: pathid,
            guid: goalid,
            flags: UInt32(bitPattern: flags),
            slot: priority,
            level: level
        )
    }

    /// MSAFE_OBJECT_POS (multisafe.cpp:741): zero for a stale handle.
    func objectPosition(_ handle: ObjectHandle) -> Vector3 {
        objects[handle]?.position ?? .zero
    }

    /// MSAFE_OBJECT_ORIENT (multisafe.cpp:748): the identity for a stale
    /// handle.
    func objectOrientation(_ handle: ObjectHandle) -> Matrix3 {
        objects[handle]?.orientation ?? Matrix3(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )
    }

    /// qObjCanSeeObj (DallasFuncs.cpp:5316): whether `handletarget` is
    /// inside the `cone` degree view cone of `handlesrc`. The direction is
    /// normalized with the scripts' fast approximation.
    func qObjCanSeeObj(
        _ handletarget: ObjectHandle,
        _ cone: Int32,
        _ handlesrc: ObjectHandle
    ) -> Bool {
        let halfAngle = Double(cone) / 2
        let testAngle = cos(halfAngle * Double.pi / 180)
        let target = objectPosition(handletarget)
        let source = objectPosition(handlesrc)
        let direction = osirisNormalizedFast(target - source)
        let dotProduct = dot(direction, objectOrientation(handlesrc).forward)
        return Double(dotProduct) > testAngle
    }

    /// qObjEnergy (DallasFuncs.cpp:5615): MSAFE_OBJECT_ENERGY, the player's
    /// energy, or 0 for another object or a stale handle.
    func qObjEnergy(_ objref: ObjectHandle) -> Float {
        objects[objref]?.type == .player ? energy : 0
    }

    /// aObjSetEnergy (DallasFuncs.cpp:1871): MSAFE_OBJECT_ENERGY for the
    /// player.
    mutating func aObjSetEnergy(_ objref: ObjectHandle, _ newEnergy: Float) {
        guard objects[objref]?.type == .player else { return }
        energy = newEnergy
    }

    /// aCancelTimer (DallasFuncs.cpp:2501): Scrpt_CancelTimerID.
    mutating func aCancelTimer(_ id: Int32, level: Level) {
        osirisCancelTimerID(id, level: level)
    }
}
