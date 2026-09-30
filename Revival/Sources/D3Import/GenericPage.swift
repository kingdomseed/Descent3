// SPDX-License-Identifier: GPL-3.0-or-later
//
// Reads the object and weapon tables the runtime uses for placed objects.
// Translated from manage/generic.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): mng_ReadNewGenericPage (:1083) and
// mng_SetAndLoadGeneric's AI allocation (:1840); from manage/manage.cpp,
// mng_ReadPhysicsChunk (:2359), mng_ReadWeaponBatteryChunk (:2423), and
// mng_ReadLightingChunk (:2471); and from model/polymodel.cpp, the GPNT
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
    try cursor.skip(12)                            // impact size, time, damage
    try cursor.skip(2)                             // score (version >= 24)
    if type == 7, version >= 25 { try cursor.skip(2) }  // ammo_count
    _ = try cursor.readCString(allowEmpty: true)   // script name
    if version >= 18 { _ = try cursor.readCString(allowEmpty: true) }
    if version >= 19 { _ = try cursor.readCString(allowEmpty: true) }
    if try cursor.readUInt8() != 0 {
        _ = try cursor.readCString(allowEmpty: true)   // description
    }
    _ = try cursor.readCString(allowEmpty: true)   // icon_name
    try cursor.skip(8)                             // LOD distances
    try cursor.skip(68)                            // mng_ReadPhysicsChunk
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

    // Spew types, animations (version >= 20: shorts).
    for _ in 0..<2 {
        try cursor.skip(1 + 4 + 2)
        _ = try cursor.readCString(allowEmpty: true)
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
    for _ in 0..<2 { _ = try cursor.readCString(allowEmpty: true) }
    if version < 26 { _ = try cursor.readCString(allowEmpty: true) }
    for _ in 0..<5 { _ = try cursor.readCString(allowEmpty: true) }
    var fireSoundNames: [[String]] = []
    for _ in 0..<maximumWeaponBatteriesPerObject {
        fireSoundNames.append(try (0..<8).map { _ in
            try cursor.readCString(allowEmpty: true)
        })
    }
    let values = [size, lightDistance, timeInterval, flickerDistance,
                  directionalDot, fov, maxVelocity, maxDeltaVelocity,
                  maxTurnRate, maxDeltaTurnRate, circleDistance,
                  leadAccuracy, fireSpread, aggression, lifePreservation,
                  avoidFriendsDistance]
    guard values.allSatisfy(\.isFinite),
          isFinite(primaryColor), isFinite(secondaryColor)
    else {
        throw GenericPageImportError.invalidValue(name)
    }
    return .init(
        name: name,
        type: type,
        primaryModelName: primaryModelName,
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
        fireSoundNames: fireSoundNames
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

/// The weapons the AI pages of `placedDefinitions` fire: for each model
/// battery (WBAT) of the page's primary model, the weapons of the gun points
/// a firing mask sets, in first-use order.
func retailAIWeaponNames(
    placedDefinitions: [String],
    genericPages: [String: RetailGenericPage],
    modelPayload: (String) -> Data?
) throws -> [String] {
    var names: [String] = []
    var seen = Set<String>()
    for definition in placedDefinitions {
        guard seen.insert(definition.lowercased()).inserted,
              let page = genericPages[definition.lowercased()],
              page.flags & CanonicalObjectInfo.controlAIFlag != 0
        else {
            continue
        }
        guard let payload = modelPayload(page.primaryModelName.lowercased())
        else {
            throw GenericPageImportError.missingModel(page.primaryModelName)
        }
        let guns = try readOutrageModelGuns(payload, name: page.primaryModelName)
        for (index, battery) in guns.batteries.enumerated() {
            let retail = page.weaponBatteries[index]
            let masks = retail.fireMasks.prefix(max(1, min(8, retail.numberOfMasks)))
            for (bit, weapon) in page.weaponNames[index]
                .prefix(battery.gunpoints.count).enumerated()
            where masks.contains(where: { $0 & (1 << bit) != 0 })
                && !names.contains(where: {
                    $0.caseInsensitiveCompare(weapon) == .orderedSame
                }) {
                names.append(weapon)
            }
        }
    }
    return names
}

extension Level {
    /// The object tables for the placed objects (additive in package schema
    /// 12): one object_info per generic page a placed generic object uses,
    /// the gun points and weapon batteries of those pages' models, and the
    /// weapons their AI batteries fire. `soundKey` maps a sound page name
    /// to the level's canonical clip key, importing the clip if needed;
    /// `modelPayload` returns an OOF by lowercased name.
    func addingObjectTables(
        genericPages: [String: RetailGenericPage],
        weapon: (String) throws -> RetailWeaponPresentationSelection,
        weaponModel: (String) -> SourceResource?,
        modelPayload: (String) -> Data?,
        soundKey: (String) throws -> String
    ) throws -> Level {
        var level = self
        var infos: [CanonicalObjectInfo] = []
        var weaponNames: [String] = []
        var modelGuns: [SourceResource: (gunpoints: [ModelGunpoint],
                                          batteries: [ModelWeaponBattery])] = [:]
        // IS_GENERIC: robot, powerup, clutter, building.
        let genericTypes: Set<UInt8> = [2, 7, 11, 16]
        for placed in objects where genericTypes.contains(placed.type) {
            guard let name = placed.definition?.sourceName,
                  !infos.contains(where: {
                      $0.name.caseInsensitiveCompare(name) == .orderedSame
                  })
            else {
                continue
            }
            guard let page = genericPages[name.lowercased()] else {
                throw GenericPageImportError.missingPage(name)
            }
            let controlsAI = page.flags & CanonicalObjectInfo.controlAIFlag != 0
            var batteries: [CanonicalWeaponBattery] = []
            if controlsAI, let model = placedObjectModel(
                ObjectHandle(placed.handle)
            ) {
                let guns: (gunpoints: [ModelGunpoint],
                           batteries: [ModelWeaponBattery])
                if let known = modelGuns[model.source] {
                    guns = known
                } else {
                    guard let payload = modelPayload(
                        model.source.sourceName.lowercased()
                    ) else {
                        throw GenericPageImportError.missingModel(
                            model.source.sourceName
                        )
                    }
                    guns = try readOutrageModelGuns(
                        payload,
                        name: model.source.sourceName
                    )
                    modelGuns[model.source] = guns
                }
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
            infos.append(.init(
                name: page.name,
                type: page.type,
                flags: page.flags,
                size: page.size,
                hitPoints: page.hitPoints,
                lightDistance: page.lightDistance,
                lighting: page.lighting,
                ai: controlsAI ? page.ai : nil,
                weaponBatteries: batteries
            ))
        }
        var weapons: [CanonicalWeapon] = []
        for name in weaponNames {
            let page = try weapon(name)
            // The sounds the runtime plays: WSI_IMPACT_WALL, WSI_FLYING,
            // and WSI_IMPACT_ROBOT (weapon.h:263-265).
            let sounds = try page.soundLogicalNames.enumerated().map {
                index, sound in
                [1, 2, 3].contains(index) && !sound.isEmpty
                    ? try soundKey(sound) : ""
            }
            let usesModel = page.weaponFlags
                & (CanonicalWeapon.imageBitmapFlag
                    | CanonicalWeapon.imageVClipFlag) == 0
            weapons.append(.init(
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
                sounds: sounds + Array(repeating: "", count: 7 - sounds.count)
            ))
        }
        level.models = models.map { model in
            var model = model
            if let guns = modelGuns[model.source] {
                model.gunpoints = guns.gunpoints
                model.weaponBatteries = guns.batteries
            }
            return model
        }
        level.objectInfos = infos
        level.weapons = weapons
        return level
    }
}
