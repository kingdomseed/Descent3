// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/DallasFuncs.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): aCreatePopupView (:1812),
// aClosePopupView (:1834), aEndLevel (:2535), aFailLevel (:2554),
// aSoundPlayObject (:2772), aAddObjectToInventory (:4277), and
// qObjIsPlayer (:5185). The DALLAS names are kept.

extension GameWorld {
    /// aCreatePopupView (DallasFuncs.cpp:1812): MSAFE_MISC_POPUP_CAMERA.
    mutating func aCreatePopupView(
        _ gunpoint: Int32,
        _ objref: ObjectHandle,
        _ time: Float,
        _ zoom: Float
    ) {
        createPopupView(
            viewer: objref,
            time: time,
            scalar: zoom,
            gun: Int(gunpoint)
        )
    }

    /// aClosePopupView (DallasFuncs.cpp:1834): MSAFE_MISC_CLOSE_POPUP.
    mutating func aClosePopupView() {
        closePopupView()
    }

    /// aEndLevel (DallasFuncs.cpp:2535): MSAFE_MISC_END_LEVEL with success.
    mutating func aEndLevel() {
        endLevel(success: true)
    }

    /// aFailLevel (DallasFuncs.cpp:2554): MSAFE_MISC_END_LEVEL with failure.
    mutating func aFailLevel() {
        endLevel(success: false)
    }

    /// aSoundPlayObject (DallasFuncs.cpp:2772): MSAFE_SOUND_OBJECT, which
    /// does not use the volume (multisafe.cpp:1973).
    mutating func aSoundPlayObject(
        _ soundnum: Int,
        _ objref: ObjectHandle,
        _ volume: Float,
        level: Level
    ) {
        soundPlay3D(objref, soundnum, level: level)
    }

    /// aAddObjectToInventory (DallasFuncs.cpp:4277): MSAFE_INVEN_ADD_OBJECT
    /// with no name; a non-spewable object gets INVAF_NOTSPEWABLE.
    mutating func aAddObjectToInventory(
        _ object: ObjectHandle,
        _ playerObject: ObjectHandle,
        _ spewable: Bool,
        level: Level
    ) {
        inventoryAddObject(
            playerObject,
            item: object,
            flags: spewable ? 0 : PlayerInventory.AddFlag.notSpewable,
            level: level
        )
    }

    /// qObjIsPlayer (DallasFuncs.cpp:5185): MSAFE_OBJECT_TYPE is OBJ_PLAYER.
    func qObjIsPlayer(_ objref: ObjectHandle) -> Bool {
        objectType(objref) == .player
    }
}
