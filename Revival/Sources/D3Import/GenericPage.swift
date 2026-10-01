// SPDX-License-Identifier: GPL-3.0-or-later
//
// Reads the object and weapon tables the runtime uses for placed objects.
// Translated from manage/generic.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): mng_ReadNewGenericPage (:1083) and
// mng_SetAndLoadGeneric's AI allocation (:1840); from manage/manage.cpp,
// mng_ReadPhysicsChunk (:2359), mng_ReadWeaponBatteryChunk (:2423), and
// mng_ReadLightingChunk (:2471); the ship page batteries the player starts
// with (InitPlayerNewShip, Descent3/Player.cpp:1502-1508); and from
// model/polymodel.cpp, the GPNT
// (:1618) and WBAT (:1686) chunks of ReadNewModelFile. The weapon pages come
// from the existing weapon page reader (PresentationImport.swift).

import Foundation

/// The fields of one generic page (mngs_generic_page) the object tables
/// carry.
struct RetailGenericPage: Equatable, Sendable {
    let name: String
    let type: UInt8
    /// `image_name`: the primary model.
    let primaryModelName: String
    /// `module_name` (version 18): the game module of the page's default
    /// script.
    let moduleName: String
    /// `script_name_override` (version 19).
    let scriptNameOverride: String
    let size: Float
    let lightDistance: Float
    let lighting: ObjectLightPresentation
    let hitPoints: Int32
    let flags: UInt32
    let ai: CanonicalAIInfo
    /// `static_wb`, all MAX_WBS_PER_OBJ (21).
    let weaponBatteries: [RetailWeaponBattery]
    /// `weapon_name[wb][gp]`.
    let weaponNames: [[String]]
    /// `fire_sound_name[wb][mask]`.
    let fireSoundNames: [[String]]
    /// `score`.
    let score: Int16
    /// `impact_size`, `impact_time`, and `damage`.
    let impact: CanonicalObjectImpact
    /// `death_types` and `death_probabilities` (version 22 and later).
    let deathTypes: [CanonicalDeathType]
    /// `phys_info` (mng_ReadPhysicsChunk).
    let physics: ObjectPhysics
    /// The death spew: `f_dspew` and each spew's percent, number, and page.
    let deathSpew: CanonicalDeathSpew
    /// `sound_name[GSI_EXPLODE]`, or empty.
    let explodeSoundName: String
}

/// otype_wb_info as mng_ReadWeaponBatteryChunk reads it.
struct RetailWeaponBattery: Equatable, Sendable {
    let fireMasks: [UInt8]
    let fireWaits: [Float]
    let numberOfMasks: Int
    let aimingGunpointIndex: Int
    let aimingFlags: UInt8
    let aiming3DDot: Float
    let aiming3DDistance: Float
    let aimingXZDot: Float
    let flags: UInt16
    let quadFireMask: UInt8
}

/// AI_NOTIFIES_ALWAYS_ON (aistruct_external.h:316): AIN_ANIM_COMPLETE,
/// NEW_MOVEMENT, PLAYER_SEES_YOU, GOAL_COMPLETE, GOAL_FAIL, GOAL_ERROR,
/// USER_DEFINED, TARGET_DIED, TARGET_INVALID, BUMPED_OBJ, MELEE_HIT,
/// MELEE_ATTACK_FRAME, SCRIPTED_GOAL, SCRIPTED_ENABLER, SCRIPTED_INFLUENCE,
/// SCRIPTED_ORIENT, MOVIE_START, MOVIE_END.
let aiNotifiesAlwaysOn: UInt32 = [21, 1, 5, 9, 10, 11, 16, 7, 17, 22, 23, 24,
                                 19, 20, 25, 26, 27, 28]
    .reduce(0) { $0 | (UInt32(1) << UInt32($1)) }

/// MAX_WBS_PER_OBJ (robotfirestruct.h:32).
let maximumWeaponBatteriesPerObject = 21

enum GenericPageImportError: Error, Equatable {
    case unsupportedVersion(String)
    case invalidValue(String)
    case missingPage(String)
    case missingModel(String)
    case invalidModelGuns(String)
}

/// mng_ReadNewGenericPage (manage/generic.cpp:1083) for every generic page
/// (PAGETYPE_GENERIC, 10) of a table file.
func parseRetailGenericPages(_ data: Data) throws -> [RetailGenericPage] {
    var offset = 0
    var pages: [RetailGenericPage] = []
    while offset < data.count {
        guard data.count - offset >= 5 else {
            throw RetailTextureTableError.truncated
        }
        let type = data[offset]
        let length = Int(
            UInt32(data[offset + 1])
                | UInt32(data[offset + 2]) << 8
                | UInt32(data[offset + 3]) << 16
                | UInt32(data[offset + 4]) << 24
        )
        guard length >= 4, length - 4 <= data.count - offset - 5 else {
            throw RetailTextureTableError.invalidPageLength
        }
        if type == 10 {
            var cursor = RetailPageCursor(
                Data(data[(offset + 5)..<(offset + 1 + length)])
            )
            pages.append(try readRetailGenericPage(&cursor))
        }
        offset += 1 + length
    }
    return pages
}

private func readRetailGenericPage(
    _ cursor: inout RetailPageCursor
) throws -> RetailGenericPage {
    let version = Int(try cursor.readUInt16())
    // Versions below 15 use the old weapon battery chunk; version 22 is
    // rejected by the game itself (generic.cpp:1296).
    guard version >= 24 else {
        throw GenericPageImportError.unsupportedVersion("generic \(version)")
    }
    let type = try cursor.readUInt8()
    let name = try cursor.readCString()
    let primaryModelName = try cursor.readCString(allowEmpty: true)
    _ = try cursor.readCString(allowEmpty: true)   // med_image_name
    _ = try cursor.readCString(allowEmpty: true)   // lo_image_name
    let impact = CanonicalObjectImpact(
        size: try cursor.readFloat(),
        time: try cursor.readFloat(),
        damage: try cursor.readFloat()
    )
    let score = Int16(bitPattern: try cursor.readUInt16())  // version >= 24
    if type == 7, version >= 25 { try cursor.skip(2) }  // ammo_count
    _ = try cursor.readCString(allowEmpty: true)   // script name
    let moduleName = version >= 18
        ? try cursor.readCString(allowEmpty: true) : ""
    let scriptNameOverride = version >= 19
        ? try cursor.readCString(allowEmpty: true) : ""
    if try cursor.readUInt8() != 0 {
        _ = try cursor.readCString(allowEmpty: true)   // description
    }
    _ = try cursor.readCString(allowEmpty: true)   // icon_name
    try cursor.skip(8)                             // LOD distances
    // mng_ReadPhysicsChunk (manage.cpp:2359).
    let physicsMass = try cursor.readFloat()
    let physicsDrag = try cursor.readFloat()
    _ = try cursor.readFloat()                     // full_thrust
    let physicsFlags = try cursor.readUInt32()
    _ = try cursor.readFloat()                     // rotdrag
    _ = try cursor.readFloat()                     // full_rotthrust
    let physicsBounces = Int32(bitPattern: try cursor.readUInt32())
    _ = try cursor.readFloat()                     // velocity.z
    let physicsSpin = Vector3(
        x: try cursor.readFloat(),
        y: try cursor.readFloat(),
        z: try cursor.readFloat()
    )
    _ = try cursor.readFloat()                     // wiggle_amplitude
    _ = try cursor.readFloat()                     // wiggles_per_sec
    let physicsRestitution = try cursor.readFloat()
    try cursor.skip(12)                            // hit_die_dot, turnroll
    let size = try cursor.readFloat()
    // mng_ReadLightingChunk (manage.cpp:2471).
    let lightDistance = try cursor.readFloat()
    let primaryColor = Vector3(
        x: try cursor.readFloat(),
        y: try cursor.readFloat(),
        z: try cursor.readFloat()
    )
    let timeInterval = try cursor.readFloat()
    let flickerDistance = try cursor.readFloat()
    let directionalDot = try cursor.readFloat()
    let secondaryColor = Vector3(
        x: try cursor.readFloat(),
        y: try cursor.readFloat(),
        z: try cursor.readFloat()
    )
    let lightFlags = try cursor.readUInt32()
    let timebits = try cursor.readUInt32()
    let angle = try cursor.readUInt8()
    let lightingRenderType = try cursor.readUInt8()
    let hitPoints = try cursor.readInt32()
    let flags = try cursor.readUInt32()

    let aiFlags = try cursor.readUInt32()
    let aiClass = try cursor.readUInt8()
    let aiType = try cursor.readUInt8()
    let movementType = try cursor.readUInt8()
    let movementSubtype = try cursor.readUInt8()
    let fov = try cursor.readFloat()
    let maxVelocity = try cursor.readFloat()
    let maxDeltaVelocity = try cursor.readFloat()
    let maxTurnRate = try cursor.readFloat()
    let notifyFlags = try cursor.readUInt32() | aiNotifiesAlwaysOn
    let maxDeltaTurnRate = try cursor.readFloat()
    let circleDistance = try cursor.readFloat()
    let attackVelocityPercent = try cursor.readFloat()
    let dodgePercent = try cursor.readFloat()
    let dodgeVelocityPercent = try cursor.readFloat()
    let fleeVelocityPercent = try cursor.readFloat()
    let meleeDamage = [try cursor.readFloat(), try cursor.readFloat()]
    let meleeLatency = [try cursor.readFloat(), try cursor.readFloat()]
    let curiosity = try cursor.readFloat()
    let nightVision = try cursor.readFloat()
    let fogVision = try cursor.readFloat()
    let leadAccuracy = try cursor.readFloat()
    let leadVariance = try cursor.readFloat()
    let fireSpread = try cursor.readFloat()
    let fightTeam = try cursor.readFloat()
    let fightSame = try cursor.readFloat()
    let aggression = try cursor.readFloat()
    let hearing = try cursor.readFloat()
    let frustration = try cursor.readFloat()
    let roaming = try cursor.readFloat()
    let lifePreservation = try cursor.readFloat()
    let avoidFriendsDistance = try cursor.readFloat()   // version >= 16
    let biasedFlightImportance = try cursor.readFloat() // version >= 17
    let biasedFlightMinimum = try cursor.readFloat()
    let biasedFlightMaximum = try cursor.readFloat()

    // The death spew (generic.cpp:1237-1244); each entry rereads
    // f_dspew, so the last byte stands. Then animations (version >= 20:
    // shorts).
    var spewFlags: UInt8 = 0
    var spewEntries: [CanonicalDeathSpew.Entry] = []
    for _ in 0..<2 {
        spewFlags = try cursor.readUInt8()
        let percent = try cursor.readFloat()
        let number = Int16(bitPattern: try cursor.readUInt16())
        let spewName = try cursor.readCString(allowEmpty: true)
        spewEntries.append(.init(
            pageName: spewName,
            percent: percent,
            number: number
        ))
    }
    try cursor.skip(5 * 24 * (2 + 2 + 4))

    // mng_ReadWeaponBatteryChunk (manage.cpp:2423), version 2.
    var batteries: [RetailWeaponBattery] = []
    for _ in 0..<maximumWeaponBatteriesPerObject {
        try cursor.skip(8)                    // energy and ammo usage
        try cursor.skip(8 * 2)                // gp_weapon_index
        var masks: [UInt8] = []
        var waits: [Float] = []
        for _ in 0..<8 {
            masks.append(try cursor.readUInt8())
            waits.append(try cursor.readFloat())
            try cursor.skip(16)               // animation times and frames
        }
        let numberOfMasks = Int(try cursor.readUInt8())
        let aimingGunpointIndex = Int(try cursor.readUInt16())
        let aimingFlags = try cursor.readUInt8()
        let aiming3DDot = try cursor.readFloat()
        let aiming3DDistance = try cursor.readFloat()
        let aimingXZDot = try cursor.readFloat()
        let batteryFlags = try cursor.readUInt16()
        let quadFireMask = try cursor.readUInt8()
        batteries.append(.init(
            fireMasks: masks,
            fireWaits: waits,
            numberOfMasks: numberOfMasks,
            aimingGunpointIndex: aimingGunpointIndex,
            aimingFlags: aimingFlags,
            aiming3DDot: aiming3DDot,
            aiming3DDistance: aiming3DDistance,
            aimingXZDot: aimingXZDot,
            flags: batteryFlags,
            quadFireMask: quadFireMask
        ))
    }
    var weaponNames: [[String]] = []
    for _ in 0..<maximumWeaponBatteriesPerObject {
        weaponNames.append(try (0..<8).map { _ in
            try cursor.readCString(allowEmpty: true)
        })
    }
    // MAX_OBJ_SOUNDS (2) object sounds; before version 26 a third,
    // obsolete one follows (generic.cpp:1274-1281). Then MAX_AI_SOUNDS (5).
    let objectSounds = [
        try cursor.readCString(allowEmpty: true),
        try cursor.readCString(allowEmpty: true),
    ]
    if version < 26 { _ = try cursor.readCString(allowEmpty: true) }
    for _ in 0..<5 { _ = try cursor.readCString(allowEmpty: true) }
    var fireSoundNames: [[String]] = []
    for _ in 0..<maximumWeaponBatteriesPerObject {
        fireSoundNames.append(try (0..<8).map { _ in
            try cursor.readCString(allowEmpty: true)
        })
    }
    // NUM_MOVEMENT_CLASSES (5) x NUM_ANIMS_PER_CLASS (24) animation sounds,
    // then the respawn scalar (version >= 21) and the death types
    // (version >= 22, generic.cpp:1297-1324).
    for _ in 0..<(5 * 24) { _ = try cursor.readCString(allowEmpty: true) }
    _ = try cursor.readFloat()
    let deathTypeCount = Int(try cursor.readUInt16())
    guard deathTypeCount <= CanonicalDeathType.maximumCount else {
        throw GenericPageImportError.invalidValue(name)
    }
    var deathTypes: [CanonicalDeathType] = []
    for _ in 0..<deathTypeCount {
        var deathType = CanonicalDeathType(
            flags: try cursor.readUInt32(),
            delayMinimum: try cursor.readFloat(),
            delayMaximum: try cursor.readFloat(),
            probability: try cursor.readUInt8()
        )
        // Before version 27, only OLD_DF_DELAY_MIN_MAX kept its delays
        // (generic.cpp:1316-1322). The DF_UNUSED clear there changes a
        // local copy only, so the stored flags stay as read.
        if version < 27, deathType.flags & 0x3 != 0x1 {
            deathType.delayMinimum = 0
            deathType.delayMaximum = 0
        }
        deathTypes.append(deathType)
    }
    let values = [size, lightDistance, timeInterval, flickerDistance,
                  directionalDot, fov, maxVelocity, maxDeltaVelocity,
                  maxTurnRate, maxDeltaTurnRate, circleDistance,
                  leadAccuracy, fireSpread, aggression, lifePreservation,
                  avoidFriendsDistance, impact.size, impact.time,
                  impact.damage, physicsMass, physicsDrag,
                  physicsRestitution]
        + deathTypes.flatMap { [$0.delayMinimum, $0.delayMaximum] }
        + spewEntries.map(\.percent)
    guard values.allSatisfy(\.isFinite),
          isFinite(primaryColor), isFinite(secondaryColor),
          isFinite(physicsSpin)
    else {
        throw GenericPageImportError.invalidValue(name)
    }
    return .init(
        name: name,
        type: type,
        primaryModelName: primaryModelName,
        moduleName: moduleName,
        scriptNameOverride: scriptNameOverride,
        size: size,
        lightDistance: lightDistance,
        lighting: .init(
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            timeInterval: timeInterval,
            flickerDistance: flickerDistance,
            directionalDot: directionalDot,
            flags: lightFlags,
            timebits: timebits,
            angle: angle,
            lightingRenderType: lightingRenderType
        ),
        hitPoints: hitPoints,
        flags: flags,
        ai: .init(
            flags: aiFlags,
            aiClass: aiClass,
            aiType: aiType,
            movementType: movementType,
            movementSubtype: movementSubtype,
            fov: fov,
            maxVelocity: maxVelocity,
            maxDeltaVelocity: maxDeltaVelocity,
            maxTurnRate: maxTurnRate,
            notifyFlags: notifyFlags,
            maxDeltaTurnRate: maxDeltaTurnRate,
            circleDistance: circleDistance,
            attackVelocityPercent: attackVelocityPercent,
            dodgePercent: dodgePercent,
            dodgeVelocityPercent: dodgeVelocityPercent,
            fleeVelocityPercent: fleeVelocityPercent,
            meleeDamage: meleeDamage,
            meleeLatency: meleeLatency,
            curiosity: curiosity,
            nightVision: nightVision,
            fogVision: fogVision,
            leadAccuracy: leadAccuracy,
            leadVariance: leadVariance,
            fireSpread: fireSpread,
            fightTeam: fightTeam,
            fightSame: fightSame,
            aggression: aggression,
            hearing: hearing,
            frustration: frustration,
            roaming: roaming,
            lifePreservation: lifePreservation,
            avoidFriendsDistance: avoidFriendsDistance,
            biasedFlightImportance: biasedFlightImportance,
            biasedFlightMinimum: biasedFlightMinimum,
            biasedFlightMaximum: biasedFlightMaximum
        ),
        weaponBatteries: batteries,
        weaponNames: weaponNames,
        fireSoundNames: fireSoundNames,
        score: score,
        impact: impact,
        deathTypes: deathTypes,
        physics: ObjectPhysics(
            flags: physicsFlags,
            mass: physicsMass,
            drag: physicsDrag,
            restitution: physicsRestitution,
            numberOfBounces: physicsBounces,
            rotationalVelocity: physicsSpin
        ),
        deathSpew: CanonicalDeathSpew(flags: spewFlags, entries: spewEntries),
        explodeSoundName: objectSounds[1]
    )
}

/// The generic pages of the table and its overlay, by lowercased name; an
/// overlay page replaces the table's page of the same name.
func resolveRetailGenericPages(
    table: Data,
    overlay: Data
) throws -> [String: RetailGenericPage] {
    var pages: [String: RetailGenericPage] = [:]
    for page in try parseRetailGenericPages(table) + parseRetailGenericPages(overlay) {
        pages[page.name.lowercased()] = page
    }
    return pages
}

/// The GPNT (model/polymodel.cpp:1618) and WBAT (:1686) chunks of an OOF
/// model: its gun points and weapon batteries. Gun point and turret lists
/// past MAX_WB_GUNPOINTS and MAX_WB_TURRETS (8) are read and dropped, as
/// ReadNewModelFile does.
func readOutrageModelGuns(
    _ data: Data,
    name: String
) throws -> (gunpoints: [ModelGunpoint], batteries: [ModelWeaponBattery]) {
    var cursor = OutrageModelCursor(data)
    guard try cursor.readASCII(4) == "PSPO" else {
        throw OutrageModelImportError.invalidHeader
    }
    var version = Int(try cursor.readInt32())
    if version < 18 { version *= 100 }
    guard version >= 1_908 else {
        throw OutrageModelImportError.unsupportedVersion(version)
    }
    var gunpoints: [ModelGunpoint] = []
    var batteries: [ModelWeaponBattery] = []
    while !cursor.isAtEnd {
        let chunkName = try cursor.readASCII(4)
        let count = try cursor.readCount(
            maximum: cursor.remaining,
            name: chunkName
        )
        var chunk = try cursor.readSubcursor(count)
        if chunkName == "GPNT" {
            let gunCount = try chunk.readCount(maximum: 1_000, name: "guns")
            for _ in 0..<gunCount {
                let parent = Int(try chunk.readInt32())
                let position = try chunk.readVector()
                let normal = try chunk.readVector()
                gunpoints.append(.init(
                    parent: parent,
                    position: position,
                    normal: normal
                ))
            }
            try chunk.requireEnd(chunkName)
        } else if chunkName == "WBAT" {
            // num_wbs indexes the object's MAX_WBS_PER_OBJ (21) static and
            // dynamic batteries (robotfirestruct.h:32).
            let batteryCount = try chunk.readCount(
                maximum: 1_000,
                name: "batteries"
            )
            guard batteryCount <= maximumWeaponBatteriesPerObject else {
                throw GenericPageImportError.invalidModelGuns(name)
            }
            for _ in 0..<batteryCount {
                let gunCount = try chunk.readCount(maximum: 1_000, name: "gps")
                let guns = try (0..<gunCount).map { _ in
                    Int(try chunk.readInt32())
                }
                let turretCount = try chunk.readCount(
                    maximum: 1_000,
                    name: "turrets"
                )
                let turrets = try (0..<turretCount).map { _ in
                    Int(try chunk.readInt32())
                }
                batteries.append(.init(
                    gunpoints: Array(guns.prefix(8)),
                    turrets: Array(turrets.prefix(8))
                ))
            }
            try chunk.requireEnd(chunkName)
        }
    }
    guard gunpoints.allSatisfy({
        isFinite($0.position) && isFinite($0.normal) && $0.parent >= 0
    }), batteries.allSatisfy({ battery in
        battery.gunpoints.allSatisfy { gunpoints.indices.contains($0) }
    }) else {
        throw GenericPageImportError.invalidModelGuns(name)
    }
    return (gunpoints, batteries)
}

extension Level {
    /// The object tables for the placed objects (additive in package schema
    /// 12): one object_info per generic page a placed generic object uses
    /// or the engine creates at level start (the Guide-Bot), the gun points
    /// and weapon batteries of those pages' models, the ship batteries
    /// `shipBatteries` with the ship model's guns, and the weapons
    /// all those batteries fire. `soundKey` maps a sound page name to the
    /// level's canonical clip key, importing the clip if needed;
    /// `modelPayload` returns an OOF by lowercased name; `textureFrames`
    /// returns the imported frames of a texture (an explosion or a
    /// particle), if any, and `fireImage` a bitmap or vclip fire image.
    func addingObjectTables(
        genericPages: [String: RetailGenericPage],
        shipBatteries: [RetailShipWeaponBattery] = [],
        weapon: (String) throws -> RetailWeaponPresentationSelection,
        weaponModel: (String) -> SourceResource?,
        modelPayload: (String) -> Data?,
        textureFrames: (String) -> [SourceResource] = { _ in [] },
        fireImage: (String) -> CanonicalWeaponImage? = { _ in nil },
        soundKey: (String) throws -> String
    ) throws -> Level {
        var level = self
        var infos: [CanonicalObjectInfo] = []
        var weaponNames: [String] = []
        var modelGuns: [String: (gunpoints: [ModelGunpoint],
                                 batteries: [ModelWeaponBattery])] = [:]
        func guns(of modelName: String) throws
            -> (gunpoints: [ModelGunpoint], batteries: [ModelWeaponBattery])
        {
            let key = modelName.lowercased()
            if let known = modelGuns[key] { return known }
            guard let payload = modelPayload(key) else {
                throw GenericPageImportError.missingModel(modelName)
            }
            let guns = try readOutrageModelGuns(payload, name: modelName)
            modelGuns[key] = guns
            return guns
        }
        // IS_GENERIC: robot, powerup, clutter, building. The placed objects'
        // pages, then the pages the engine creates at level start: in single
        // player AIInitAll makes ROBOT_GUIDEBOT for a player
        // (AImain.cpp:3833), when the tables have that page.
        let genericTypes: Set<UInt8> = [2, 7, 11, 16]
        var pageNames = objects
            .filter { genericTypes.contains($0.type) }
            .compactMap { $0.definition?.sourceName }
        if objects.contains(where: {
            $0.type == D3SourceIdentity.playerObjectType
        }), genericPages[CanonicalObjectInfo.guideBotPageName.lowercased()] != nil {
            pageNames.append(CanonicalObjectInfo.guideBotPageName)
        }
        for name in pageNames where !infos.contains(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) {
            guard let page = genericPages[name.lowercased()] else {
                throw GenericPageImportError.missingPage(name)
            }
            let controlsAI = page.flags & CanonicalObjectInfo.controlAIFlag != 0
            var batteries: [CanonicalWeaponBattery] = []
            if controlsAI, !page.primaryModelName.isEmpty {
                // The page's model batteries (WBAT) with the page's
                // static_wb (ObjInit's WBClearInfo, ObjInit.cpp:815).
                let guns = try guns(of: page.primaryModelName)
                for (index, modelBattery) in guns.batteries.enumerated() {
                    let retail = page.weaponBatteries[index]
                    let maskCount = max(1, min(8, retail.numberOfMasks))
                    let masks = Array(retail.fireMasks.prefix(maskCount))
                    let gunCount = modelBattery.gunpoints.count
                    let weaponsFired = page.weaponNames[index]
                        .prefix(gunCount)
                    // A gun point fires when any mask sets its bit.
                    for (bit, weaponName) in weaponsFired.enumerated()
                    where masks.contains(where: { $0 & (1 << bit) != 0 })
                        && !weaponNames.contains(where: {
                            $0.caseInsensitiveCompare(weaponName)
                                == .orderedSame
                        }) {
                        weaponNames.append(weaponName)
                    }
                    // A gun point no mask fires keeps no weapon.
                    let gunpointWeapons = weaponsFired.enumerated().map {
                        bit, weaponName in
                        masks.contains(where: { $0 & (1 << bit) != 0 })
                            ? weaponName : ""
                    }
                    batteries.append(.init(
                        gunpointWeapons: gunpointWeapons,
                        fireMasks: masks,
                        fireWaits: Array(retail.fireWaits.prefix(maskCount)),
                        fireSounds: try page.fireSoundNames[index]
                            .prefix(maskCount)
                            .map { name in
                                name.isEmpty ? "" : try soundKey(name)
                            },
                        aimingGunpointIndex: retail.aimingGunpointIndex,
                        aimingFlags: retail.aimingFlags,
                        aiming3DDot: retail.aiming3DDot,
                        aiming3DDistance: retail.aiming3DDistance,
                        aimingXZDot: retail.aimingXZDot,
                        flags: retail.flags,
                        quadFireMask: retail.quadFireMask
                    ))
                }
            }
            infos.append(try Self.canonicalObjectInfo(
                page,
                weaponBatteries: batteries,
                soundKey: soundKey
            ))
        }
        // The pages a death makes objects from without placing them: the
        // spewed objects (DoDeathSpew, fireball.cpp:1134) and the dead
        // models (CreateDeadObject, fireball.cpp:1316). They have no AI
        // batteries here.
        let deadModels = [
            "swatter": "swatter(deadmodel)",
            "hangturret": "Securityturret(DEAD)",
            "lance": "Lance(DEAD)",
            "l10 swatter": "swatter(deadmodel)",
        ]
        var madePages: [String] = []
        for info in infos {
            for entry in info.deathSpew?.entries ?? []
            where entry.number > 0 && !entry.pageName.isEmpty {
                madePages.append(entry.pageName)
            }
            if info.type == 2, let dead = deadModels[info.name.lowercased()] {
                madePages.append(dead)
            }
        }
        for name in madePages {
            guard !infos.contains(where: {
                      $0.name.caseInsensitiveCompare(name) == .orderedSame
                  }),
                  let page = genericPages[name.lowercased()]
            else {
                continue
            }
            infos.append(try Self.canonicalObjectInfo(
                page,
                weaponBatteries: [],
                soundKey: soundKey
            ))
        }
        // The ship batteries fire from the ship model's battery 0
        // (WeaponFire.cpp:2977); their gun points follow its gun points.
        var shipWeaponBatteries: [CanonicalShipWeaponBattery] = []
        if !shipBatteries.isEmpty,
           let ship = shipDefinitions.first {
            let guns = try guns(of: ship.primaryModel.sourceName)
            let gunCount = guns.batteries.first?.gunpoints.count ?? 0
            for retail in shipBatteries {
                let weaponsFired = retail.weaponNames.prefix(gunCount)
                for (bit, weaponName) in weaponsFired.enumerated()
                where retail.fireMasks.contains(where: { $0 & (1 << bit) != 0 })
                    && !weaponNames.contains(where: {
                        $0.caseInsensitiveCompare(weaponName) == .orderedSame
                    }) {
                    weaponNames.append(weaponName)
                }
                shipWeaponBatteries.append(.init(
                    index: retail.index,
                    battery: .init(
                        gunpointWeapons: weaponsFired.enumerated().map {
                            bit, weaponName in
                            retail.fireMasks.contains(where: {
                                $0 & (1 << bit) != 0
                            }) ? weaponName : ""
                        },
                        fireMasks: retail.fireMasks,
                        fireWaits: retail.fireWaits,
                        fireSounds: try retail.fireSoundNames.map { name in
                            name.isEmpty ? "" : try soundKey(name)
                        },
                        aimingGunpointIndex: 0,
                        aimingFlags: 0,
                        aiming3DDot: 0,
                        aiming3DDistance: 0,
                        aimingXZDot: 0,
                        flags: retail.flags,
                        quadFireMask: 0
                    ),
                    energyUsage: retail.energyUsage,
                    ammoUsage: retail.ammoUsage,
                    fireFlags: retail.fireFlags
                ))
            }
        }
        // Each weapon's spawns join the table (spawn_handle and
        // alternate_spawn_handle, weaponpage.cpp:782).
        var weapons: [CanonicalWeapon] = []
        var pending = weaponNames
        while !pending.isEmpty {
            let name = pending.removeFirst()
            guard !weapons.contains(where: {
                $0.name.caseInsensitiveCompare(name) == .orderedSame
            }) else {
                continue
            }
            let canonical = try Self.canonicalWeapon(
                try weapon(name),
                weaponModel: weaponModel,
                textureFrames: textureFrames,
                fireImage: fireImage,
                soundKey: soundKey
            )
            weapons.append(canonical)
            if let spawn = canonical.spawn {
                pending.append(spawn.weapon)
                if !spawn.alternateWeapon.isEmpty {
                    pending.append(spawn.alternateWeapon)
                }
            }
        }
        level.models = models.map { model in
            var model = model
            if let guns = modelGuns[model.source.sourceName.lowercased()] {
                model.gunpoints = guns.gunpoints
                model.weaponBatteries = guns.batteries
            }
            return model
        }
        level.objectInfos = infos
        level.weapons = weapons
        if !shipWeaponBatteries.isEmpty {
            level.shipDefinitions[0].weaponBatteries = shipWeaponBatteries
        }
        return level.appendingTextureDependencies(
            weapons.flatMap(\.presentationTextures),
            provenance:
                "manage/weaponpage.cpp:653-901; Descent3/WeaponFire.cpp:3058-3201"
        )
    }

    /// The canonical weapon of a retail weapon page (weaponpage.cpp:782):
    /// its model (unless the page draws a bitmap or vclip, whose fire image
    /// `fireImage` gives), its particles and spawns, and the sounds the
    /// runtime plays: WSI_IMPACT_WALL, WSI_FLYING, WSI_IMPACT_ROBOT, and
    /// WSI_BOUNCE (weapon.h:263-266). `textureFrames` gives the imported
    /// frames of the explosion and particle textures.
    static func canonicalWeapon(
        _ page: RetailWeaponPresentationSelection,
        weaponModel: (String) -> SourceResource?,
        textureFrames: (String) -> [SourceResource],
        fireImage: (String) -> CanonicalWeaponImage?,
        soundKey: (String) throws -> String
    ) throws -> CanonicalWeapon {
        let sounds = try page.soundLogicalNames.enumerated().map {
            index, sound in
            [1, 2, 3, 4].contains(index) && !sound.isEmpty
                ? try soundKey(sound) : ""
        }
        let usesModel = page.weaponFlags
            & (CanonicalWeapon.imageBitmapFlag
                | CanonicalWeapon.imageVClipFlag) == 0
        return .init(
            name: page.name,
            flags: page.weaponFlags,
            model: usesModel ? weaponModel(page.fireImageName) : nil,
            size: page.modelPageSize,
            customSize: page.customSize,
            mass: page.mass,
            drag: page.drag,
            physicsFlags: page.physicsFlags,
            speed: page.speed,
            fullThrust: page.fullThrust,
            lifetime: page.lifetime,
            playerDamage: page.playerDamage,
            genericDamage: page.genericDamage,
            sounds: sounds + Array(repeating: "", count: 7 - sounds.count),
            impact: .init(
                size: page.impactSize,
                time: page.impactTime,
                playerDamage: page.impactPlayerDamage,
                genericDamage: page.impactGenericDamage,
                force: page.impactForce
            ),
            explosion: .init(
                hasImage: !page.explosionTextureName.isEmpty,
                frames: page.explosionTextureName.isEmpty
                    ? [] : textureFrames(page.explosionTextureName),
                lifetime: page.explosionLifetime,
                size: page.explosionSize
            ),
            lightDistance: page.lightDistance,
            lighting: page.lightPresentation,
            fireImage: usesModel
                ? nil
                : fireImage(page.fireImageName)
                    ?? .init(frames: [], frameTime: 0),
            particles: page.particleCount > 0 && !page.particleName.isEmpty
                ? .init(
                    count: page.particleCount,
                    lifetime: page.particleLifetime,
                    size: page.particleSize,
                    frames: textureFrames(page.particleName)
                )
                : nil,
            spawn: page.timeoutSpawnCount > 0
                && !page.timeoutSpawnName.isEmpty
                ? .init(
                    weapon: page.timeoutSpawnName,
                    count: page.timeoutSpawnCount,
                    alternateWeapon: page.alternateSpawnName,
                    alternateChance: page.alternateSpawnChance
                )
                : nil
        )
    }

    /// The canonical object_info of a retail generic page (ObjInit,
    /// objinit.cpp:807) with the given weapon batteries.
    static func canonicalObjectInfo(
        _ page: RetailGenericPage,
        weaponBatteries: [CanonicalWeaponBattery],
        soundKey: (String) throws -> String
    ) throws -> CanonicalObjectInfo {
        .init(
            name: page.name,
            type: page.type,
            flags: page.flags,
            size: page.size,
            hitPoints: page.hitPoints,
            lightDistance: page.lightDistance,
            lighting: page.lighting,
            ai: page.flags & CanonicalObjectInfo.controlAIFlag != 0
                ? page.ai : nil,
            weaponBatteries: weaponBatteries,
            score: page.score,
            impact: page.impact,
            deathTypes: page.deathTypes,
            explodeSound: page.explodeSoundName.isEmpty
                ? "" : try soundKey(page.explodeSoundName),
            deathSpew: page.deathSpew,
            physics: page.physics,
            moduleName: canonicalGameModuleName(page.moduleName),
            scriptNameOverride: page.scriptNameOverride.isEmpty
                ? nil : page.scriptNameOverride
        )
    }
}
