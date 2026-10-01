// SPDX-License-Identifier: GPL-3.0-or-later
//
// Imports what a level's objects and weapons reach: the object pages, the
// weapons and their spawns, the polymodels of the pages, the ship, and the
// weapons, the textures those models and weapons show, and each object's
// presentation. Source provenance:
// - Descent3/ship.h:127 DEFAULT_SHIP: the player's ship page.
// - Descent3/ObjInit.cpp:718-807 ObjInitGeneric and ObjInitPlayer: a
//   generic object shows its page's polymodels, the player its ship's.
// - Descent3/AImain.cpp:3833 AIInitAll: the Guide-Bot page
//   (GenericPage.swift adds it to the object tables).
// - model/polymodel.cpp:1762 ReadNewModelFile's TXTR chunk: each model
//   texture slot's texture page (resolveRetailModelTextureSlots).
// - manage/weaponpage.cpp:653-901 and Descent3/WeaponFire.cpp: a weapon's
//   polymodel or bitmap or vclip fire image, its particles, and its
//   explosion; an animated texture keeps all its frames
//   (viseffect.cpp:1900, weapon.cpp:608).
// The object pages and weapons come from the object tables and the game
// modules (GenericPage.swift, GameModuleImport.swift). A first pass with
// no models finds them, so every model and texture they reach is imported
// before the tables are built.

import Foundation

/// DEFAULT_FRAMETIME (Descent3/vclip.cpp:176): PageInVClip replaces a
/// vclip's stored frame time with it (:323-334).
let vclipDefaultFrameTime: Float = 0.07

/// LoadWeaponFireImage (Descent3/weapon.cpp:627-654): a bitmap or vclip
/// fire image is loaded from the file the weapon page names, through
/// LoadTextureImage (gametexture.cpp:543): an OAF is a vclip whose frames
/// GetWeaponFireImage steps at DEFAULT_FRAMETIME (weapon.cpp:608), any other
/// file one bitmap. `texture` is the identity of frame 0 (a texture slot no
/// page uses); frame n is "<file> frame <n>". WF_SATURATE draws the bitmap
/// saturated (DrawWeaponObject, AT_SATURATE). A missing file is an import
/// error. (A vclip a texture page already shows is shared instead:
/// AllocLoadVClip finds it by name, vclip.cpp:426.)
func importWeaponFireImage(
    _ weapon: RetailWeaponPresentationSelection,
    texture: SourceResource,
    sources: ImportSources
) throws -> (image: CanonicalWeaponImage, materials: [PresentationMaterial]) {
    let name = weapon.fireImageName
    guard let (library, entry, _) = sources.firstEntry(named: name) else {
        throw D3ImportOperationError.missingPresentationAsset(name)
    }
    let payload = library.payload(entry)
    let isVClip = name.lowercased().hasSuffix(".oaf")
    let images = isVClip
        ? try decodeReachedOutrage16OAF(payload).frames
        : [try decodeReachedOutrage16OGF(payload)]
    let resources = images.indices.map {
        $0 == 0 ? texture : SourceResource(
            storedIndex: texture.storedIndex,
            sourceName: "\(name) frame \($0)"
        )
    }
    let saturateFlag: UInt32 = 1 << 10
    let blend: PresentationBlend = weapon.weaponFlags & saturateFlag != 0
        ? .additiveSourceAlpha(opacity: 255)
        : .sourceAlpha(opacity: 255)
    let materials = zip(resources, images).map { texture, image in
        PresentationMaterial(
            texture: texture,
            bitmapSourceName: name,
            image: .init(width: image.width, height: image.height, rgba8: image.rgba8),
            blend: blend,
            lightmapBlend: .none,
            waterProcedural: nil,
            sourceArchive: library.relativePath,
            sourceSHA256: canonicalSHA256(payload)
        )
    }
    return (
        .init(frames: resources, frameTime: isVClip ? vclipDefaultFrameTime : 0),
        materials
    )
}

/// The texture pages a weapon shows with every frame: its explosion and
/// particle textures by the names the page gives (`byName`, keyed by the
/// lowercased name), and, for a bitmap or vclip fire image, the page that
/// shows that file, whose vclip the weapon shares (AllocLoadVClip finds a
/// loaded vclip by name, vclip.cpp:426; `sharedFireImages`, keyed by the
/// lowercased file name).
func resolveWeaponTextureDefinitions(
    _ weapons: [RetailWeaponPresentationSelection],
    table: Data,
    overlay: Data
) throws -> (
    byName: [String: RetailTextureDefinition],
    sharedFireImages: [String: RetailTextureDefinition]
) {
    var names: Set<String> = []
    var shared: [String: RetailTextureDefinition] = [:]
    for weapon in weapons {
        if !weapon.explosionTextureName.isEmpty {
            names.insert(weapon.explosionTextureName)
        }
        if weapon.particleCount > 0, !weapon.particleName.isEmpty {
            names.insert(weapon.particleName)
        }
        let imageFlags = CanonicalWeapon.imageBitmapFlag | CanonicalWeapon.imageVClipFlag
        if weapon.weaponFlags & imageFlags != 0, !weapon.fireImageName.isEmpty,
           let page = try resolveRetailTextureShowingBitmap(
               table: table,
               overlay: overlay,
               bitmapName: weapon.fireImageName
           ) {
            // The page already selected by its bitmap; resolving its name
            // again could find another page whose bitmap stem is that name.
            shared[weapon.fireImageName.lowercased()] = page
        }
    }
    let requested = names.sorted()
    let definitions = try resolveRetailTextureDefinitions(
        table: table,
        overlay: overlay,
        names: names
    )
    var byName: [String: RetailTextureDefinition] = [:]
    for (name, definition) in zip(requested, definitions) {
        byName[name.lowercased()] = definition
    }
    return (byName, shared)
}

/// DEFAULT_SHIP (Descent3/ship.h:127).
let defaultShipPageName = "Pyro-GL"

enum ObjectPresentationImportError: Error, Equatable {
    case missingPlayer
    case missingShip(String)
}

extension Level {
    /// The level with its objects' presentation, the default player ship,
    /// the object tables, and the game module data.
    func addingObjectsAndWeapons(
        sources: ImportSources,
        sounds: inout SoundImportCache
    ) throws -> Level {
        let genericPages = try resolveRetailGenericPages(
            table: sources.table,
            overlay: sources.overlay
        )
        let modelPages = try resolveRetailModelPages(
            table: sources.table,
            overlay: sources.overlay
        )
        var weaponPages: [String: RetailWeaponPresentationSelection] = [:]
        func weaponPage(_ name: String) throws -> RetailWeaponPresentationSelection {
            let key = name.lowercased()
            if let known = weaponPages[key] { return known }
            let page = try resolveRetailWeaponPresentation(
                table: sources.table,
                overlay: sources.overlay,
                named: name
            )
            weaponPages[key] = page
            return page
        }
        func usesModel(_ page: RetailWeaponPresentationSelection) -> Bool {
            page.weaponFlags
                & (CanonicalWeapon.imageBitmapFlag | CanonicalWeapon.imageVClipFlag)
                == 0
        }
        guard let player = objects.first(where: {
            $0.type == D3SourceIdentity.playerObjectType && $0.storedID == 0
        }) else {
            throw ObjectPresentationImportError.missingPlayer
        }
        guard let shipPage = modelPages[defaultShipPageName.lowercased()],
              let retailShip = shipPage.shipDefinition
        else {
            throw ObjectPresentationImportError.missingShip(defaultShipPageName)
        }
        // InitPlayerNewShip gives the laser and the Concussion
        // (Player.cpp:1502-1503); FireFlareFromPlayer fires FLARE_INDEX.
        let shipBatteries = (retailShip.weaponBatteries ?? []).filter {
            [PlayerWeaponState.laserIndex, PlayerWeaponState.concussionIndex,
             PlayerWeaponState.flareIndex].contains($0.index)
        }
        let shipSource = SourceResource(storedIndex: 0, sourceName: retailShip.name)
        let binding = DefaultPlayerBinding(
            playerID: 0,
            objectHandle: player.handle,
            ship: shipSource
        )
        func ship(primaryModel: SourceResource) -> CanonicalShipDefinition {
            .init(
                source: shipSource,
                primaryModel: primaryModel,
                presentationSize: retailShip.presentationSize,
                physics: retailShip.physics
            )
        }

        // The first pass: the object pages and weapons the tables and the
        // game modules reach, with no models yet.
        var discovery = try addingDefaultPlayerShip(
            ship(primaryModel: .init(storedIndex: 0, sourceName: shipPage.primaryModelName)),
            binding: binding
        ).addingObjectTables(
            genericPages: genericPages,
            shipBatteries: shipBatteries,
            weapon: weaponPage,
            weaponModel: { _ in nil },
            modelPayload: { sources.payload(named: $0) },
            soundKey: { try sounds.page(named: $0).logicalName }
        )
        discovery = try discovery.addingGameModules(
            archives: sources.scriptArchives,
            genericPages: genericPages,
            soundPage: { try sounds.page(named: $0) },
            soundClip: { try sounds.clip(named: $0) },
            weapon: weaponPage,
            weaponModel: { _ in nil }
        )
        // The pages of the objects at level start have models: the placed
        // generic objects' pages and the Guide-Bot's. An object made later
        // from another page (a death spew, a dead model, a game module's
        // object) keeps the page size and is not drawn (M2).
        let genericTypes: Set<UInt8> = [2, 7, 11, 16]
        let startPageNames = Set(
            objects.filter { genericTypes.contains($0.type) }
                .compactMap { $0.definition?.sourceName.lowercased() }
                + [CanonicalObjectInfo.guideBotPageName.lowercased()]
        )
        let reachedPages = (discovery.objectInfos ?? []).compactMap {
            startPageNames.contains($0.name.lowercased())
                ? modelPages[$0.name.lowercased()] : nil
        }
        let reachedWeapons = try (discovery.weapons ?? []).map {
            try weaponPage($0.name)
        }

        // The models: the ship's, each reached page's, and each polymodel
        // weapon's, in legacy name order.
        var modelNames: [String] = []
        func reach(_ name: String?) {
            guard let name, !name.isEmpty,
                  !modelNames.contains(where: {
                      $0.caseInsensitiveCompare(name) == .orderedSame
                  })
            else {
                return
            }
            modelNames.append(name)
        }
        for page in [shipPage] + reachedPages {
            reach(page.primaryModelName)
            reach(page.mediumModelName)
            reach(page.lowModelName)
            reach(page.dyingModelName)
        }
        for weapon in reachedWeapons where usesModel(weapon) {
            reach(weapon.fireImageName)
        }
        modelNames.sort(by: legacyNameOrder)
        var payloadByName: [String: (data: Data, archive: String)] = [:]
        var slotNamesByModel: [String: [String]] = [:]
        var referencedSlotsByModel: [String: Set<Int>] = [:]
        for name in modelNames {
            guard let (library, entry, _) = sources.firstEntry(named: name) else {
                throw D3ImportOperationError.missingPresentationAsset(name)
            }
            let key = name.lowercased()
            let payload = library.payload(entry)
            payloadByName[key] = (payload, library.relativePath)
            slotNamesByModel[key] = try reachedOutrageModelTextureNames(payload)
            referencedSlotsByModel[key] =
                try reachedOutrageModelReferencedTextureSlotIndices(payload)
        }
        func isSampleTexture(_ name: String) -> Bool {
            name.caseInsensitiveCompare("SAMPLE TEXTURE") == .orderedSame
        }
        let slotNames = Set(slotNamesByModel.flatMap { key, names in
            referencedSlotsByModel[key]!.map { names[$0] }
        }.filter { !isSampleTexture($0) })
        let slotDefinitions = try resolveRetailModelTextureSlots(
            table: sources.table,
            overlay: sources.overlay,
            slotNames: slotNames,
            animationFrameNames: { bitmap in
                sources.payload(named: bitmap).flatMap {
                    try? outrageAnimationFrameNames($0)
                }
            }
        )

        // The weapons' explosion and particle textures, and the pages that
        // show their fire images: every frame.
        let weaponTextures = try resolveWeaponTextureDefinitions(
            reachedWeapons,
            table: sources.table,
            overlay: sources.overlay
        )
        let weaponDefinitionByName = weaponTextures.byName
        let weaponDefinitions = weaponTextures.byName.keys.sorted().map {
            weaponTextures.byName[$0]!
        } + weaponTextures.sharedFireImages.keys.sorted().map {
            weaponTextures.sharedFireImages[$0]!
        }
        var definitionByIndex: [Int: RetailTextureDefinition] = [:]
        for definition in slotDefinitions.keys.sorted().map({ slotDefinitions[$0]! })
            + weaponDefinitions
        where definitionByIndex[definition.storedIndex] == nil {
            definitionByIndex[definition.storedIndex] = definition
        }
        let definitions = definitionByIndex.keys.sorted().map {
            definitionByIndex[$0]!
        }
        let textureByName = Dictionary(
            definitions.map {
                ($0.name.lowercased(),
                 SourceResource(storedIndex: $0.storedIndex, sourceName: $0.name))
            },
            uniquingKeysWith: { first, _ in first }
        )
        var materials = try makePresentationMaterials(
            definitions,
            textureByName: textureByName,
            sources: sources,
            allFrameTextures: Set(
                weaponDefinitions.map { $0.name.lowercased() }
            )
        )
        func allFrames(
            _ definition: RetailTextureDefinition
        ) throws -> [SourceResource] {
            let texture = textureByName[definition.name.lowercased()]!
            return definition.bitmapSourceName.lowercased().hasSuffix(".oaf")
                ? try admitAnimatedTextureFrames(
                    texture: texture,
                    bitmapSourceName: definition.bitmapSourceName,
                    animation: reachedOutrageAnimation(
                        named: definition.bitmapSourceName,
                        sources: sources
                    )
                ).resources
                : [texture]
        }
        var weaponTextureFrames: [String: [SourceResource]] = [:]
        for (name, definition) in weaponDefinitionByName {
            weaponTextureFrames[name] = try allFrames(definition)
        }
        // Each bitmap or vclip fire image: a shared page's frames, or the
        // file itself in a texture slot past the table's pages.
        var fireImages: [String: CanonicalWeaponImage] = [:]
        var nextFireTextureIndex = try retailTexturePageCount(
            table: sources.table,
            overlay: sources.overlay
        )
        for weapon in reachedWeapons
        where !usesModel(weapon) && !weapon.fireImageName.isEmpty
            && fireImages[weapon.fireImageName.lowercased()] == nil {
            let key = weapon.fireImageName.lowercased()
            if let page = weaponTextures.sharedFireImages[key] {
                fireImages[key] = .init(
                    frames: try allFrames(page),
                    frameTime: weapon.fireImageName.lowercased().hasSuffix(".oaf")
                        ? vclipDefaultFrameTime : 0
                )
                continue
            }
            let imported = try importWeaponFireImage(
                weapon,
                texture: .init(
                    storedIndex: nextFireTextureIndex,
                    sourceName: weapon.fireImageName
                ),
                sources: sources
            )
            nextFireTextureIndex += 1
            fireImages[key] = imported.image
            materials += imported.materials
        }
        func textureFrames(_ name: String) -> [SourceResource] {
            weaponTextureFrames[name.lowercased()]
                ?? textureByName[name.lowercased()].map { [$0] }
                ?? []
        }
        func fireImage(_ name: String) -> CanonicalWeaponImage? {
            fireImages[name.lowercased()]
        }

        // The models, each slot showing its texture.
        let modelSources = Dictionary(
            uniqueKeysWithValues: modelNames.enumerated().map {
                ($0.element.lowercased(),
                 SourceResource(storedIndex: $0.offset, sourceName: $0.element))
            }
        )
        let models = try modelNames.map { name in
            let key = name.lowercased()
            let payload = payloadByName[key]!
            let referenced = referencedSlotsByModel[key]!
            let slots = slotNamesByModel[key]!.enumerated().map {
                index, slotName -> SourceResource? in
                guard referenced.contains(index), !isSampleTexture(slotName),
                      let definition = slotDefinitions[slotName.lowercased()]
                else {
                    return nil
                }
                return SourceResource(
                    storedIndex: definition.storedIndex,
                    sourceName: definition.name
                )
            }
            return try parseReachedOutrageModel(
                payload.data,
                sourceName: name,
                sourceIndex: modelSources[key]!.storedIndex,
                sourceArchive: payload.archive,
                textureResources: slots
            )
        }
        func pagePresentation(
            _ page: RetailModelPageSelection
        ) -> ObjectPagePresentation? {
            guard let primary = modelSources[page.primaryModelName.lowercased()]
            else {
                return nil
            }
            return .init(
                primaryModel: primary,
                mediumModel: page.mediumModelName.map { modelSources[$0.lowercased()]! },
                lowModel: page.lowModelName.map { modelSources[$0.lowercased()]! },
                dyingModel: page.dyingModelName.map { modelSources[$0.lowercased()]! },
                mediumDistance: page.mediumDistance,
                lowDistance: page.lowDistance
            )
        }
        // Each placed player shows the ship, and each placed generic object
        // its page (ObjInitPlayer, ObjInitGeneric).
        let objectPresentations = objects.compactMap {
            object -> ObjectPresentationReference? in
            let page: RetailModelPageSelection?
            if object.type == D3SourceIdentity.playerObjectType {
                page = shipPage
            } else if genericTypes.contains(object.type),
                      let name = object.definition?.sourceName {
                page = modelPages[name.lowercased()]
            } else {
                page = nil
            }
            return page.flatMap(pagePresentation)?
                .reference(objectHandle: object.handle)
        }

        var level = addingObjectPresentation(
            models: models,
            objectPresentations: objectPresentations,
            materials: materials
        ).addingDefaultPlayerShip(
            ship(primaryModel: modelSources[shipPage.primaryModelName.lowercased()]!),
            binding: binding
        )
        var addedClips: [CanonicalSoundClip] = []
        let knownClips = level.soundClips
        level = try level.addingObjectTables(
            genericPages: genericPages,
            shipBatteries: shipBatteries,
            weapon: weaponPage,
            weaponModel: { modelSources[$0.lowercased()] },
            modelPayload: { payloadByName[$0]?.data ?? sources.payload(named: $0) },
            textureFrames: textureFrames,
            fireImage: fireImage,
            soundKey: { name in
                let clip = try sounds.clip(named: name)
                if !(knownClips + addedClips).contains(where: {
                    $0.logicalName == clip.logicalName
                }) {
                    addedClips.append(clip)
                }
                return clip.logicalName
            }
        ).appendingSoundClips(addedClips)
        level = try level.addingGameModules(
            archives: sources.scriptArchives,
            genericPages: genericPages,
            soundPage: { try sounds.page(named: $0) },
            soundClip: { try sounds.clip(named: $0) },
            weapon: weaponPage,
            weaponModel: { modelSources[$0.lowercased()] },
            textureFrames: textureFrames,
            fireImage: fireImage
        )
        // The models of the level-start pages, for the objects made from
        // them at run time (the Guide-Bot).
        level.objectInfos = level.objectInfos?.map { info in
            var info = info
            if startPageNames.contains(info.name.lowercased()) {
                info.presentation = modelPages[info.name.lowercased()]
                    .flatMap(pagePresentation)
            }
            return info
        }
        return level
    }
}
