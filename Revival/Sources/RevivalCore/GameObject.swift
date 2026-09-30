// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/object.h (handle masks, :640-644),
// Descent3/object_external.h (OBJ_ and RT_ constants, :153-266),
// and lib/object_external_struct.h (struct object, :401, and light_info).

import Foundation

/// A slot number plus a signature count, as in `object.h:642-644`.
/// The low 11 bits select the slot. The high 21 bits count reuse of the slot,
/// so a handle kept past `ObjFree` no longer matches the reused slot.
struct ObjectHandle: Codable, Hashable, Sendable {
    static let slotMask: UInt32 = 0x7ff            // HANDLE_OBJNUM_MASK
    static let countMask: UInt32 = 0xffff_f800     // HANDLE_COUNT_MASK
    static let countIncrement: UInt32 = 0x800      // HANDLE_COUNT_INCREMENT
    /// OBJECT_HANDLE_NONE (`object_external.h:156`).
    static let none = ObjectHandle(0xffff_ffff)

    let rawValue: UInt32

    init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    var slot: Int { Int(rawValue & Self.slotMask) }

    init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(UInt32.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// The handle `ObjCreate` gives the next object in the same slot
    /// (`object.cpp:1702-1707`). The C++ traps when the count reaches all
    /// ones and then lets it wrap to zero, the "never used" count that
    /// `ObjGet` rejects. Revival skips zero so every allocated handle keeps a
    /// nonzero count.
    func nextSignature() -> ObjectHandle {
        var next = rawValue &+ Self.countIncrement
        if next & Self.countMask == 0 {
            next &+= Self.countIncrement
        }
        return ObjectHandle(next)
    }
}

/// OBJ_ types (`object_external.h:159-185`). A free slot is `nil` in the
/// table, so OBJ_NONE has no case.
enum ObjectType: UInt8, Codable, Sendable {
    case wall = 0
    case fireball = 1
    case robot = 2
    case shard = 3
    case player = 4
    case weapon = 5
    case viewer = 6
    case powerup = 7
    case debris = 8
    case camera = 9
    case shockwave = 10
    case clutter = 11
    case ghost = 12
    case light = 13
    case coop = 14
    case marker = 15
    case building = 16
    case door = 17
    case room = 18
    case particle = 19
    case splinter = 20
    case dummy = 21
    case observer = 22
    case debugLine = 23
    case soundSource = 24
    case waypoint = 25
}

/// The RT_ render types in use (`object_external.h:257-258`).
/// `MSAFE_OBJECT_NO_RENDER` (`multisafe.cpp:1733`) sets `RT_NONE`.
enum ObjectRenderType: UInt8, Codable, Sendable {
    case none = 0
    case polyobj = 1
}

/// The runtime object (`struct object`, `object_external_struct.h:401`).
/// It holds only the fields that the current runtime reads or writes.
/// Later work adds the remaining fields as their systems arrive.
struct GameObject: Codable, Equatable, Sendable {
    let handle: ObjectHandle
    var type: ObjectType
    var renderType: ObjectRenderType
    /// `roomnum`: a room or a terrain cell.
    var location: SpatialLocation
    var position: Vector3
    var orientation: Matrix3
    /// The OF_ flags (`object_external.h:269-301`).
    var flags: UInt32 = 0
    /// `dummy_type`: the real type of a ghosted (OBJ_DUMMY) object.
    var dummyType: ObjectType? = nil
    /// The object's own `lighting_info` after ObjSetLocalLighting. `nil`
    /// uses the object page's lighting.
    var localLighting: ObjectLocalLighting? = nil
    /// `ai_info` of a CT_AI object. The object page decides CT_AI
    /// (objinit.cpp:807).
    var ai: ObjectAIFrame? = nil
    /// `osiris_script`: the bound scripts.
    var scripts: ObjectScripts? = nil
    /// `id` of a generic object: the index of its object_info in
    /// `Level.objectInfos`.
    var info: Int? = nil
    /// `id` of a weapon object: the index of its weapon in `Level.weapons`.
    var weapon: Int? = nil
    /// `size`.
    var size: Float = 0
    /// `shields` of a generic object: its page hit points at ObjInit.
    /// Damage changes it from M1 step 7. The player's shields are
    /// `GameWorld.shields`.
    var shields: Float = 0
    /// `movement_type`: MT_PHYSICS or MT_NONE.
    var usesPhysics = false
    /// `mtype.phys_info.velocity` of an object that the object frame moves.
    /// The player's velocity is `GameWorld.velocity`.
    var velocity = Vector3.zero
    /// `last_pos`: the position before the latest physics move.
    var lastPosition = Vector3.zero
    /// `parent_handle`.
    var parent: ObjectHandle = .none
    /// `lifeleft` while OF_USES_LIFELEFT is set; `nil` while it is clear.
    var lifeLeft: Float? = nil
    /// `dynamic_wb`: one per model weapon battery of a CT_AI object.
    var weaponBatteries: [DynamicWeaponBattery] = []
}

extension GameObject {
    /// OF_DEAD (`object_external.h:270`).
    static let deadFlag: UInt32 = 0x0000_0002
    /// OF_DESTROYABLE (`object_external.h:279`).
    static let destroyableFlag: UInt32 = 0x0000_0400
    /// OF_NO_OBJECT_COLLISIONS (`object_external.h:286`).
    static let noObjectCollisionsFlag: UInt32 = 0x0001_0000
}

/// The script-set fields of `light_info` (MSAFE_OBJECT_LIGHT_DIST and
/// MSAFE_OBJECT_LIGHT_COLOR, multisafe.cpp:1821-1841). A field that no
/// script set keeps the page value, so it is `nil` here.
struct ObjectLocalLighting: Codable, Equatable, Sendable {
    /// `light_distance`.
    var lightDistance: Float?
    /// `red_light1`, `green_light1`, `blue_light1`.
    var color: Vector3?
}
