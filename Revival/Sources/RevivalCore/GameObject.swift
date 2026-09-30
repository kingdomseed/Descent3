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
    /// `shields` of a generic object: its page hit points at ObjInit, less
    /// the damage ApplyDamageToGeneric applies. The player's shields are
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
    /// `dynamic_wb`: one per model weapon battery of a CT_AI object, and
    /// MAX_WBS_PER_OBJ (21) for the player.
    var weaponBatteries: [DynamicWeaponBattery] = []
    /// `creation_time`: the Gametime of ObjCreate.
    var creationTime: Float = 0
    /// `ctype.dying_info` while the object has CT_DYING (KillObject with a
    /// delay, damage.cpp:1221-1245).
    var dying: ObjectDyingInfo? = nil
    /// The impact values and `mtype.shock_info` of an OBJ_SHOCKWAVE
    /// (MakeShockwave, fireball.cpp:1752).
    var shockwave: ShockwaveInfo? = nil
    /// `attach_ultimate_handle` while OF_ATTACHED is set.
    var attachUltimateHandle: ObjectHandle = .none
    /// PF_NO_COLLIDE_PARENT of a weapon: its parent is not hit.
    var noCollideParent = false
    /// `mtype.phys_info` of an object the generic physics moves (debris,
    /// splinters, spewed powerups, and dying objects that fall or fly;
    /// ObjectPhysics.swift). Weapons and AI objects keep their own movers.
    var physics: ObjectPhysics? = nil
    /// `ctype.debris_info` while the object has CT_DEBRIS.
    var debris: DebrisInfo? = nil
    /// CT_SPLINTER: the face of its model's submodel 0 it shows.
    var splinterFace: Int? = nil
    /// `ctype.blast_info` of an OBJ_FIREBALL (CT_EXPLOSION).
    var fireball: FireballObjectInfo? = nil
    /// `rtype.pobj_info.model_num` when it is not the placed object's
    /// primary model: a debris piece's or splinter's parent model, or a
    /// dying object's `dying_model_num`.
    var model: SourceResource? = nil
    /// `rtype.pobj_info.subobj_flags` of a debris piece: the one submodel
    /// it shows.
    var submodel: Int? = nil
}

/// `ctype.debris_info` (object_external_struct.h).
struct DebrisInfo: Codable, Equatable, Sendable {
    /// The DF_ flags of the death that made it.
    var deathFlags: UInt32
    var lastSmokeTime: Float = -1
}

/// `ctype.blast_info` and the Fireballs[] id of an OBJ_FIREBALL.
struct FireballObjectInfo: Codable, Equatable, Sendable {
    var id: UInt8
    var maximumSize: Float
    var lifetime: Float
}

/// `ctype.dying_info` (object_external_struct.h).
struct ObjectDyingInfo: Codable, Equatable, Sendable {
    /// The DF_ flags.
    var deathFlags: UInt32
    var delayTime: Float
    /// `killer_playernum`, or nil for -1.
    var killerPlayer: Int?
    var lastSparkTime: Float = -1
    var lastFireballTime: Float = -1
    var lastSmokeTime: Float = -1
}

/// An OBJ_SHOCKWAVE's impact values and `shock_info.damaged_list`
/// (object_external_struct.h:376).
struct ShockwaveInfo: Codable, Equatable, Sendable {
    /// `(MAX_OBJECTS / 32) + 1` words.
    static let damagedListWordCount = ObjectTable.capacity / 32 + 1

    let size: Float
    let time: Float
    let playerDamage: Float
    let genericDamage: Float
    let force: Float
    /// One bit per object slot that the shockwave already reached.
    var damagedList = Array(repeating: UInt32(0), count: damagedListWordCount)
}

extension GameObject {
    /// OF_DEAD (`object_external.h:270`).
    static let deadFlag: UInt32 = 0x0000_0002
    /// OF_FORCE_CEILING_CHECK.
    static let forceCeilingCheckFlag: UInt32 = 0x0000_0001
    /// OF_OUTSIDE_MINE: OBJECT_SAVE_LOAD_FLAGS (object_external.h:310).
    static let outsideMineFlag: UInt32 = 0x0000_0200
    /// OF_BIG_OBJECT.
    static let bigObjectFlag: UInt32 = 0x0000_0800
    /// OF_DESTROYED (`object_external.h:271`).
    static let destroyedFlag: UInt32 = 0x0000_0004
    /// OF_ATTACHED (`object_external.h:273`).
    static let attachedFlag: UInt32 = 0x0000_0010
    /// OF_AI_DO_DEATH (`object_external.h:275`).
    static let aiDoDeathFlag: UInt32 = 0x0000_0040
    /// OF_DESTROYABLE (`object_external.h:279`).
    static let destroyableFlag: UInt32 = 0x0000_0400
    /// OF_POLYGON_OBJECT (`object_external.h:281`).
    static let polygonObjectFlag: UInt32 = 0x0000_1000
    /// OF_DYING (`object_external.h:282`).
    static let dyingFlag: UInt32 = 0x0000_2000
    /// OF_USE_DESTROYED_POLYMODEL (`object_external.h:283`).
    static let useDestroyedPolymodelFlag: UInt32 = 0x0000_4000
    /// OF_NO_OBJECT_COLLISIONS (`object_external.h:286`).
    static let noObjectCollisionsFlag: UInt32 = 0x0001_0000
    /// OF_AI_DEATH (`object_external.h:293`).
    static let aiDeathFlag: UInt32 = 0x0080_0000
    /// OF_INPLAYERINVENTORY (`object_external.h:299`).
    static let inPlayerInventoryFlag: UInt32 = 0x0800_0000
    /// OF_INFORM_DESTROY_TO_LG (`object_external.h:302`).
    static let informDestroyToLevelGoalsFlag: UInt32 = 0x4000_0000

    /// IS_GENERIC (`object_external.h`): robot, powerup, clutter, building.
    var isGeneric: Bool {
        [.robot, .powerup, .clutter, .building].contains(type)
    }
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
