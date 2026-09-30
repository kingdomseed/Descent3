// SPDX-License-Identifier: GPL-3.0-or-later
//
// The canonical game-table values that the runtime reads for objects and
// weapons. Translated from Descent3/objinfo.h (object_info, the OIF_ flags,
// :333-346), Descent3/aistruct.h (t_ai_info), lib/robotfirestruct.h
// (otype_wb_info, poly_wb_info, the WBF_ flags), Descent3/weapon.h (weapon,
// the WF_ and WSI_ values), and lib/polymodel.h (w_bank gun points). D3Import
// fills them from the generic and weapon pages (manage/generic.cpp:1083,
// manage/weaponpage.cpp:782) and from the model's GPNT and WBAT chunks
// (model/polymodel.cpp:1618, :1686). Package schema 12 carries them as
// optional additive fields; a package without them has no AI objects.

import Foundation

/// object_info (objinfo.h) for one generic page that a placed object uses.
struct CanonicalObjectInfo: Codable, Equatable, Sendable {
    /// OIF_CONTROL_AI (objinfo.h:333).
    static let controlAIFlag: UInt32 = 0x01
    /// OIF_USES_PHYSICS (objinfo.h:334).
    static let usesPhysicsFlag: UInt32 = 0x02
    /// OIF_DESTROYABLE (objinfo.h:335).
    static let destroyableFlag: UInt32 = 0x04
    /// OIF_AI_SCRIPTED_DEATH (objinfo.h:340).
    static let aiScriptedDeathFlag: UInt32 = 0x100
    /// OIF_DO_CEILING_CHECK.
    static let doCeilingCheckFlag: UInt32 = 0x200
    /// OIF_NO_DIFF_SCALE_DAMAGE (objinfo.h:344).
    static let noDifficultyScaleDamageFlag: UInt32 = 0x800
    /// OIF_NO_DIFF_SCALE_MOVE (objinfo.h:345).
    static let noDifficultyScaleMoveFlag: UInt32 = 0x1000

    /// The page name. A placed object uses it when its definition name
    /// matches (stricmp, as FindObjectIDName does).
    let name: String
    /// The OBJ_ type the page defines.
    let type: UInt8
    /// The OIF_ flags.
    let flags: UInt32
    /// `size`.
    let size: Float
    /// `hit_points`.
    let hitPoints: Int32
    /// `lighting_info`: its light distance and its flicker and colors.
    let lightDistance: Float
    let lighting: ObjectLightPresentation
    /// `ai_info`. The game allocates it only for a page with OIF_CONTROL_AI
    /// (mng_SetAndLoadGeneric, manage/generic.cpp:1846).
    let ai: CanonicalAIInfo?
    /// `static_wb`, limited to the model's `num_wbs` batteries. Only an AI
    /// page carries them here: ai_fire (AImain.cpp:5116) is the only reader
    /// that the runtime translates.
    let weaponBatteries: [CanonicalWeaponBattery]
    /// `score`, which PlayerScoreAdd gives the player who kills the object
    /// (damage.cpp:1216). Absent in packages imported before M1 step 7.
    var score: Int16? = nil
    /// `impact_size`, `impact_time`, and `damage`, which ObjInitGeneric
    /// copies to the object for the shockwave of its death
    /// (ObjInit.cpp:760-764).
    var impact: CanonicalObjectImpact? = nil
    /// `death_types` with their `death_probabilities` (objinfo.h:502-503),
    /// all MAX_DEATH_TYPES (4) of them, which KillObject picks from
    /// (damage.cpp:1037).
    var deathTypes: [CanonicalDeathType]? = nil
    /// `sounds[GSI_EXPLODE]` (object_external.h:351): the page's explode
    /// sound, or empty for SOUND_NONE_INDEX. Absent before this field.
    var explodeSound: String? = nil
    /// `f_dspew`, `dspew`, `dspew_percent`, and `dspew_number`
    /// (objinfo.h:383-385): what DoDeathSpew throws out.
    var deathSpew: CanonicalDeathSpew? = nil
    /// `phys_info`: the physics a page with OIF_USES_PHYSICS gives the
    /// objects made from it at run time (ObjInit.cpp:774).
    var physics: ObjectPhysics? = nil
}

/// The death spew of an object page.
struct CanonicalDeathSpew: Codable, Equatable, Sendable {
    /// DSF_ONLY_IF_PLAYER_HAS_OBJ_1 and DSF_ONLY_IF_NO_1 (objinfo.h:384-385).
    static let onlyIfPlayerHasFirstFlag: UInt8 = 1
    static let onlyIfNoFirstFlag: UInt8 = 2

    struct Entry: Codable, Equatable, Sendable {
        /// The spewed page (`dspew_name`), found by FindObjectIDName.
        let pageName: String
        let percent: Float
        let number: Int16
    }

    let flags: UInt8
    /// MAX_DSPEW_TYPES (2) entries.
    let entries: [Entry]
}

/// The impact fields of an object page (objinfo.h).
struct CanonicalObjectImpact: Codable, Equatable, Sendable {
    let size: Float
    let time: Float
    let damage: Float
}

/// One `death_info` of an object page with its probability
/// (objinfo.h:391-395, :502-503).
struct CanonicalDeathType: Codable, Equatable, Sendable {
    /// MAX_DEATH_TYPES (objinfo.h:388).
    static let maximumCount = 4

    /// The DF_ flags (deathinfo_external.h:61-106).
    let flags: UInt32
    var delayMinimum: Float
    var delayMaximum: Float
    /// 0 to 100 percent.
    let probability: UInt8
}

/// The flicker and color fields of `light_info` (lib/object_external_struct.h),
/// read by mng_ReadLightingChunk (manage/manage.cpp:2471).
struct ObjectLightPresentation:
    Codable, Equatable, Sendable
{
    let primaryColor: Vector3
    let secondaryColor: Vector3
    let timeInterval: Float
    let flickerDistance: Float
    let directionalDot: Float
    let flags: UInt32
    let timebits: UInt32
    let angle: UInt8
    let lightingRenderType: UInt8
}

/// t_ai_info (aistruct.h), as mng_ReadNewGenericPage reads it
/// (manage/generic.cpp:1170-1226). `notifyFlags` already includes
/// AI_NOTIFIES_ALWAYS_ON. The AI sounds are not imported: no translated
/// path plays them yet.
struct CanonicalAIInfo: Codable, Equatable, Sendable {
    var flags: UInt32
    var aiClass: UInt8
    var aiType: UInt8
    var movementType: UInt8
    var movementSubtype: UInt8
    var fov: Float
    var maxVelocity: Float
    var maxDeltaVelocity: Float
    var maxTurnRate: Float
    var notifyFlags: UInt32
    var maxDeltaTurnRate: Float
    var circleDistance: Float
    var attackVelocityPercent: Float
    var dodgePercent: Float
    var dodgeVelocityPercent: Float
    var fleeVelocityPercent: Float
    var meleeDamage: [Float]
    var meleeLatency: [Float]
    var curiosity: Float
    var nightVision: Float
    var fogVision: Float
    var leadAccuracy: Float
    var leadVariance: Float
    var fireSpread: Float
    var fightTeam: Float
    var fightSame: Float
    var aggression: Float
    var hearing: Float
    var frustration: Float
    var roaming: Float
    var lifePreservation: Float
    var avoidFriendsDistance: Float
    var biasedFlightImportance: Float
    var biasedFlightMinimum: Float
    var biasedFlightMaximum: Float
}

/// otype_wb_info (robotfirestruct.h:49), read by mng_ReadWeaponBatteryChunk
/// (manage/manage.cpp:2423). Gun point weapons and firing-mask sounds are
/// names; the game resolves them at page load (FindWeaponName,
/// mng_GetGuaranteedSoundPage).
struct CanonicalWeaponBattery: Codable, Equatable, Sendable {
    /// WBF_USE_CUSTOM_FOV.
    static let useCustomFOVFlag: UInt16 = 32
    /// WBF_USE_CUSTOM_MAX_DIST.
    static let useCustomMaxDistanceFlag: UInt16 = 128
    /// WBF_RANDOM_FIRE_ORDER.
    static let randomFireOrderFlag: UInt16 = 8
    /// WBF_ANIM_MASKS.
    static let animationMask: UInt16 = 6
    /// WBF_FIRE_FVEC.
    static let fireForwardFlag: UInt16 = 512
    /// WBF_AIM_FVEC.
    static let aimForwardFlag: UInt16 = 1024
    /// WBF_FIRE_TARGET.
    static let fireTargetFlag: UInt16 = 2048

    /// `gp_weapon_index` as weapon page names, one per gun point of the
    /// model battery (`poly_wb.num_gps`). A gun point no firing mask sets
    /// has an empty name.
    let gunpointWeapons: [String]
    /// `gp_fire_masks` for the first `num_masks` masks.
    let fireMasks: [UInt8]
    /// `gp_fire_wait`, one per mask.
    let fireWaits: [Float]
    /// `fm_fire_sound_index` as sound page names, one per mask. An empty
    /// name is SOUND_NONE_INDEX.
    let fireSounds: [String]
    let aimingGunpointIndex: Int
    let aimingFlags: UInt8
    let aiming3DDot: Float
    let aiming3DDistance: Float
    let aimingXZDot: Float
    /// The WBF_ flags.
    let flags: UInt16
    let quadFireMask: UInt8
}

/// The weapon page values (weapon.h `weapon`) that firing, flight, and a
/// hit read. Read by mng_ReadNewWeaponPage (manage/weaponpage.cpp:782).
struct CanonicalWeapon: Codable, Equatable, Sendable {
    /// WF_IMAGE_BITMAP (weapon.h:219).
    static let imageBitmapFlag: UInt32 = 1 << 1
    /// WF_MATTER_WEAPON (weapon.h:221).
    static let matterWeaponFlag: UInt32 = 1 << 3
    /// WF_IMAGE_VCLIP (weapon.h:223).
    static let imageVClipFlag: UInt32 = 1 << 5
    /// WF_ELECTRICAL (weapon.h:222).
    static let electricalFlag: UInt32 = 1 << 4
    /// WF_BLAST_RING (weapon.h:229).
    static let blastRingFlag: UInt32 = 1 << 11
    /// WF_PLANAR_BLAST (weapon.h:230).
    static let planarBlastFlag: UInt32 = 1 << 12
    /// WF_SPAWNS_TIMEOUT (weapon.h:234).
    static let spawnsTimeoutFlag: UInt32 = 1 << 16
    /// WF_EXPAND (weapon.h:235).
    static let expandFlag: UInt32 = 1 << 17
    /// WF_NAPALM (weapon.h:238).
    static let napalmFlag: UInt32 = 1 << 20
    /// WF_TIMEOUT_WALL (weapon.h:244).
    static let timeoutWallFlag: UInt32 = 1 << 26
    /// WF_CUSTOM_SIZE (weapon.h:249).
    static let customSizeFlag: UInt32 = 1 << 31
    /// WSI_IMPACT_WALL (weapon.h:263).
    static let impactWallSound = 1
    /// WSI_IMPACT_ROBOT (weapon.h:265).
    static let impactRobotSound = 3

    let name: String
    /// The WF_ flags.
    let flags: UInt32
    /// The fire image as a model, when the weapon draws a polygon model.
    let model: SourceResource?
    /// `size`: the fire model's size (PageInPolymodel), or the page size.
    let size: Float
    let customSize: Float
    let mass: Float
    let drag: Float
    /// The PF_ flags of `phys_info`.
    let physicsFlags: UInt32
    /// `phys_info.velocity.z`, the launch speed.
    let speed: Float
    let fullThrust: Float
    let lifetime: Float
    let playerDamage: Float
    let genericDamage: Float
    /// `sounds`, as sound page names. An empty name is SOUND_NONE_INDEX.
    let sounds: [String]
    /// `impact_size`, `impact_time`, `impact_player_damage`,
    /// `impact_generic_damage`, and `impact_force`, which ObjInitWeapon
    /// copies to the weapon object (ObjInit.cpp:1002-1006). Absent in
    /// packages imported before M1 step 7.
    var impact: CanonicalWeaponImpact? = nil
    /// The explosion DoWeaponExploded shows (`explode_image_handle`,
    /// `explode_time`, `explode_size`).
    var explosion: CanonicalWeaponExplosion? = nil
    /// `lighting_info`: the light of the flying weapon.
    var lightDistance: Float? = nil
    var lighting: ObjectLightPresentation? = nil
}

/// The shockwave values of a weapon page (weapon.h).
struct CanonicalWeaponImpact: Codable, Equatable, Sendable {
    let size: Float
    let time: Float
    let playerDamage: Float
    let genericDamage: Float
    let force: Float
}

/// The explosion of a weapon page. `frames` are the imported frames of the
/// explosion texture's animation, shown evenly over the explosion's life;
/// they are empty when the texture is not imported yet, and then the visual
/// effect is created but not drawn.
struct CanonicalWeaponExplosion: Codable, Equatable, Sendable {
    /// Whether `explode_image_handle` names a texture (> 0). Without one,
    /// DoWeaponExploded picks a random small explosion (WeaponFire.cpp:3154).
    let hasImage: Bool
    let frames: [SourceResource]
    /// `explode_time`.
    let lifetime: Float
    /// `explode_size`.
    let size: Float
}

/// A model gun point (`w_bank`, lib/polymodel.h), read from the GPNT chunk.
struct ModelGunpoint: Codable, Equatable, Sendable {
    /// The submodel the point is attached to.
    let parent: Int
    let position: Vector3
    let normal: Vector3
}

/// poly_wb_info (robotfirestruct.h:35), read from the WBAT chunk.
struct ModelWeaponBattery: Codable, Equatable, Sendable {
    /// `gp_index`: gun point indices, at most MAX_WB_GUNPOINTS.
    let gunpoints: [Int]
    /// `turret_index`: turret submodels, most mobile first.
    let turrets: [Int]
}

extension Level {
    /// The object_info of a placed object (Object_info[obj->id]), matched
    /// by the object's definition name.
    func objectInfo(for handle: ObjectHandle) -> CanonicalObjectInfo? {
        guard let infos = objectInfos,
              let placed = objects.first(where: {
                  $0.handle == handle.rawValue
              }),
              let name = placed.definition?.sourceName
        else {
            return nil
        }
        return infos.first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    /// FindWeaponName: the weapon page with this name (stricmp).
    func weapon(named name: String) -> CanonicalWeapon? {
        weapons?.first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    /// The primary model of a placed object.
    func placedObjectModel(_ handle: ObjectHandle) -> CanonicalModel? {
        guard let presentation = objectPresentations.first(where: {
            $0.objectHandle == handle.rawValue
        }) else {
            return nil
        }
        return models.first { $0.source == presentation.primaryModel }
    }

    /// Structural checks for the object and weapon tables. Import already
    /// resolved every name; this rejects a damaged package.
    func validateObjectTables() throws {
        func require(_ condition: Bool, _ what: String) throws {
            guard condition else {
                throw LevelValidationError.invalidObjectTables(what)
            }
        }
        let weaponNames = Set((weapons ?? []).map { $0.name.lowercased() })
        try require(
            weaponNames.count == (weapons ?? []).count,
            "weapon names"
        )
        let soundNames = Set(soundClips.map { $0.logicalName.lowercased() })
        for weapon in weapons ?? [] {
            try require(
                [weapon.size, weapon.customSize, weapon.mass, weapon.drag,
                 weapon.speed, weapon.fullThrust, weapon.lifetime,
                 weapon.playerDamage, weapon.genericDamage]
                    .allSatisfy(\.isFinite)
                    && weapon.sounds.count == 7
                    && weapon.sounds.allSatisfy {
                        $0.isEmpty || soundNames.contains($0.lowercased())
                    }
                    && weapon.model.map { model in
                        models.contains { $0.source == model }
                    } != false,
                "weapon \(weapon.name)"
            )
        }
        let infoNames = Set((objectInfos ?? []).map { $0.name.lowercased() })
        try require(
            infoNames.count == (objectInfos ?? []).count,
            "object info names"
        )
        for info in objectInfos ?? [] {
            try require(
                info.size.isFinite && info.size >= 0
                    && (info.ai == nil) == (info.flags
                        & CanonicalObjectInfo.controlAIFlag == 0)
                    && info.weaponBatteries.allSatisfy { battery in
                        !battery.fireMasks.isEmpty
                            && battery.fireMasks.count <= 8
                            && battery.fireWaits.count
                                == battery.fireMasks.count
                            && battery.fireSounds.count
                                == battery.fireMasks.count
                            && battery.gunpointWeapons.count <= 8
                            && battery.fireWaits.allSatisfy(\.isFinite)
                            && [battery.aiming3DDot,
                                battery.aiming3DDistance,
                                battery.aimingXZDot].allSatisfy(\.isFinite)
                            && battery.gunpointWeapons.allSatisfy {
                                $0.isEmpty
                                    || weaponNames.contains($0.lowercased())
                            }
                            && battery.fireSounds.allSatisfy {
                                $0.isEmpty
                                    || soundNames.contains($0.lowercased())
                            }
                    }
                    && (info.explodeSound.map {
                        $0.isEmpty || soundNames.contains($0.lowercased())
                    } ?? true)
                    && (info.physics.map {
                        $0.mass.isFinite && $0.mass >= 0 && $0.drag.isFinite
                            && $0.drag >= 0 && $0.restitution.isFinite
                            && isFinite($0.rotationalVelocity)
                    } ?? true)
                    && (info.deathSpew.map {
                        $0.entries.count <= 2
                            && $0.entries.allSatisfy { $0.percent.isFinite }
                    } ?? true),
                "object info \(info.name)"
            )
            if let ai = info.ai {
                try require(
                    [ai.fov, ai.maxVelocity, ai.maxDeltaVelocity,
                     ai.maxTurnRate, ai.maxDeltaTurnRate,
                     ai.circleDistance, ai.leadAccuracy, ai.fireSpread,
                     ai.aggression, ai.lifePreservation,
                     ai.avoidFriendsDistance].allSatisfy(\.isFinite)
                        && ai.meleeDamage.count == 2
                        && ai.meleeLatency.count == 2,
                    "AI info \(info.name)"
                )
            }
        }
        // Each placed AI object's page against its model, as WBFireBattery
        // (robotfire.cpp:111) reads them: one page battery per model
        // battery (ObjInit.cpp:815), a weapon entry per gun point, and a
        // weapon for every gun point a firing mask sets.
        for placed in objects where [2, 7, 11, 16].contains(placed.type) {
            guard let name = placed.definition?.sourceName,
                  let info = objectInfos?.first(where: {
                      $0.name.caseInsensitiveCompare(name) == .orderedSame
                  }),
                  info.ai != nil
            else {
                continue
            }
            let modelBatteries = placedObjectModel(
                ObjectHandle(placed.handle)
            )?.weaponBatteries ?? []
            try require(
                info.weaponBatteries.count == modelBatteries.count
                    && zip(info.weaponBatteries, modelBatteries).allSatisfy {
                        page, model in
                        page.gunpointWeapons.count == model.gunpoints.count
                            && page.fireMasks.allSatisfy { mask in
                                model.gunpoints.indices.allSatisfy { bit in
                                    mask & (UInt8(1) << UInt8(bit)) == 0
                                        || weaponNames.contains(
                                            page.gunpointWeapons[bit]
                                                .lowercased()
                                        )
                                }
                            }
                    },
                "object \(placed.handle) guns"
            )
        }
        for model in models {
            let gunpoints = model.gunpoints ?? []
            try require(
                gunpoints.allSatisfy { gunpoint in
                    model.submodels.indices.contains(gunpoint.parent)
                        && [gunpoint.position.x, gunpoint.position.y,
                            gunpoint.position.z, gunpoint.normal.x,
                            gunpoint.normal.y, gunpoint.normal.z]
                            .allSatisfy(\.isFinite)
                }
                    && (model.weaponBatteries ?? []).allSatisfy { battery in
                        battery.gunpoints.count <= 8
                            && battery.turrets.count <= 8
                            && battery.gunpoints.allSatisfy {
                                gunpoints.indices.contains($0)
                            }
                            && battery.turrets.allSatisfy { index in
                                model.submodels.indices.contains(index)
                                    && {
                                        if case .turret = model
                                            .submodels[index].presentation {
                                            return true
                                        }
                                        return false
                                    }()
                            }
                    },
                "model guns \(model.source.sourceName)"
            )
        }
    }
}
