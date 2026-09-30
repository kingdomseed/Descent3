// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/DallasFuncs.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): the object actions
// aObjSetLightingDist (:2035), aObjSetLightingColor (:2057),
// aObjSetShields (:1849), aSetObjectTimer (:2451), aObjGhostSet (:2896),
// aObjHide (:2916), aObjMakeInvuln (:2937), aAISetState (:3330), and the
// queries qObjIsType (:5292) and qObjShields (:5593).

extension GameWorld {
    /// aObjSetLightingDist (DallasFuncs.cpp:2035).
    mutating func aObjSetLightingDist(_ object: ObjectHandle, _ dist: Float) {
        setObjectLightDistance(object, dist)
    }

    /// aObjSetLightingColor (DallasFuncs.cpp:2057).
    mutating func aObjSetLightingColor(
        _ object: ObjectHandle,
        _ r: Float,
        _ g: Float,
        _ b: Float
    ) {
        setObjectLightColor(object, red: r, green: g, blue: b)
    }

    /// aObjGhostSet (DallasFuncs.cpp:2896): MSAFE_OBJECT_GHOST or
    /// MSAFE_OBJECT_UNGHOST.
    mutating func aObjGhostSet(_ state: Int32, _ object: ObjectHandle) {
        if state != 0 {
            ghostObject(object)
        } else {
            unghostObject(object)
        }
    }

    /// aObjHide (DallasFuncs.cpp:2916): MSAFE_OBJECT_NO_RENDER.
    mutating func aObjHide(_ object: ObjectHandle) {
        setObjectRendered(object.rawValue, false)
    }

    /// aObjMakeInvuln (DallasFuncs.cpp:2937). The time is whole seconds.
    mutating func aObjMakeInvuln(_ object: ObjectHandle, _ time: Int32) {
        setObjectInvulnerable(object, true, lifetime: Float(time))
    }

    /// aAISetState (DallasFuncs.cpp:3330): AI_PowerSwitch.
    mutating func aAISetState(_ state: Int32, _ object: ObjectHandle) {
        aiPowerSwitch(object, on: state != 0)
    }

    /// aObjSetShields (DallasFuncs.cpp:1849): MSAFE_OBJECT_SHIELDS.
    mutating func aObjSetShields(_ objref: ObjectHandle, _ shields: Float) {
        setObjectShields(objref, shields)
    }

    /// qObjIsType (DallasFuncs.cpp:5292): MSAFE_OBJECT_TYPE, which is -1
    /// for a stale handle (multisafe.cpp:902), equals `type`.
    func qObjIsType(_ objhandle: ObjectHandle, _ type: Int32) -> Bool {
        (objectType(objhandle).map { Int32($0.rawValue) } ?? -1) == type
    }

    /// qObjShields (DallasFuncs.cpp:5593): MSAFE_OBJECT_SHIELDS, or -1 for
    /// a stale handle.
    func qObjShields(_ objref: ObjectHandle) -> Float {
        objectShields(objref)
    }

    /// aSetObjectTimer (DallasFuncs.cpp:2451): a one-shot object timer
    /// with no detonator.
    mutating func aSetObjectTimer(
        _ objref: ObjectHandle,
        _ time: Float,
        _ id: Int32
    ) {
        osirisCreateTimer(.init(target: .object(objref), id: id, interval: time))
    }
}
