// SPDX-License-Identifier: GPL-3.0-or-later
//
// Imports the presentation of a level's rooms: the textures of the faces
// the player's start can reach, their light coronas, and the lightmap pages
// those faces use. Source provenance:
// - Descent3/gametexture.cpp and manage/texpage.cpp: the texture pages, their
//   bitmaps or vclips (an animated page shows its vclip's frames), and the
//   light corona of a page with a light (PresentationImport.swift).
// - Descent3/lightmap_info.cpp: the face lightmap infos and their pages.
// - The rooms the start reaches through portals in both directions
//   (ReciprocalPortalComponent.swift).

import Foundation

enum RoomPresentationImportError: Error, Equatable {
    case missingPlayerStart
}

extension Level {
    /// The level with its room presentation: one material per texture of a
    /// face in the rooms the player's start reaches, those faces' corona
    /// bitmaps, and their lightmap pages.
    func addingRoomPresentation(sources: ImportSources) throws -> Level {
        guard let player = objects.first(where: {
                  $0.type == D3SourceIdentity.playerObjectType && $0.storedID == 0
              }),
              case let .room(startRoom) = player.location
        else {
            throw RoomPresentationImportError.missingPlayerStart
        }
        let reachedRooms = reciprocalPortalComponent(
            rooms: rooms,
            startRoomSourceIndex: startRoom
        )
        let faces = rooms
            .filter { reachedRooms.contains($0.sourceIndex) }
            .sorted { $0.sourceIndex < $1.sourceIndex }
            .flatMap(\.faces)
        var textureByName: [String: SourceResource] = [:]
        for face in faces {
            textureByName[face.texture.sourceName.lowercased()] = face.texture
        }
        let definitions = try resolveRetailTextureDefinitions(
            table: sources.table,
            overlay: sources.overlay,
            names: Set(textureByName.keys)
        )
        let coronaAssets = try makePresentationCoronaAssets(
            definitions,
            sources: sources
        )
        let materials = try makePresentationMaterials(
            definitions,
            textureByName: textureByName,
            sources: sources
        )
        let lightmapPages = Set(faces.compactMap { face in
            face.lightmapInfoIndex.map { lightmaps.infos[$0].pageIndex }
        })
        return addingPresentationMaterials(
            materials,
            retainingLightmapPages: lightmapPages,
            coronaAssets: coronaAssets
        )
    }
}

/// The frames of an animated texture page (TF_ANIMATED): the texture is
/// its first frame, and each later frame of its vclip is named
/// "<bitmap> frame <n>" (DrawVisEffect and GetWeaponFireImage show them,
/// viseffect.cpp:1900, weapon.cpp:608).
struct AnimatedTextureAdmission: Equatable, Sendable {
    let resources: [SourceResource]
    let images: [Outrage1555Image]
    let sourceFrameTime: Float
}

func admitAnimatedTextureFrames(
    texture: SourceResource,
    bitmapSourceName: String,
    animation: Outrage1555Animation
) throws -> AnimatedTextureAdmission {
    guard !animation.frames.isEmpty,
          animation.sourceFrameTime.isFinite,
          animation.sourceFrameTime > 0 else {
        throw D3ImportOperationError.missingPresentationAsset(
            bitmapSourceName
        )
    }
    let resources = [texture] + (1..<animation.frames.count).map {
        SourceResource(
            storedIndex: texture.storedIndex,
            sourceName: "\(bitmapSourceName) frame \($0)"
        )
    }
    return .init(
        resources: resources,
        images: animation.frames,
        sourceFrameTime: animation.sourceFrameTime
    )
}

/// The OAF vclip of this name, decoded.
func reachedOutrageAnimation(
    named name: String,
    sources: ImportSources
) throws -> Outrage1555Animation {
    guard let payload = sources.payload(named: name) else {
        throw D3ImportOperationError.missingPresentationAsset(name)
    }
    return try decodeReachedOutrage16OAF(payload)
}

/// One material per texture definition: a still page shows its bitmap, an
/// animated page its first frame, and an animated page in
/// `allFrameTextures` (lowercased page names) every frame of its vclip.
func makePresentationMaterials(
    _ definitions: [RetailTextureDefinition],
    textureByName: [String: SourceResource],
    sources: ImportSources,
    allFrameTextures: Set<String> = []
) throws -> [PresentationMaterial] {
    let coronaNames = Set(definitions.compactMap { $0.lightCorona?.bitmapSourceName }).sorted()
    let coronaIndexByName = Dictionary(
        uniqueKeysWithValues: coronaNames.enumerated().map { ($0.element, $0.offset) }
    )
    return try definitions.flatMap { definition throws -> [PresentationMaterial] in
        guard let (library, entry, _) = sources.firstEntry(
                  named: definition.bitmapSourceName
              ),
              let texture = textureByName[definition.name.lowercased()] else {
            throw D3ImportOperationError.missingPresentationAsset(definition.bitmapSourceName)
        }
        let payload = library.payload(entry)
        let images: [(texture: SourceResource, image: Outrage1555Image)]
        if definition.bitmapSourceName.lowercased().hasSuffix(".oaf") {
            let animation = try decodeReachedOutrage16OAF(payload)
            if allFrameTextures.contains(definition.name.lowercased()) {
                let admitted = try admitAnimatedTextureFrames(
                    texture: texture,
                    bitmapSourceName: definition.bitmapSourceName,
                    animation: animation
                )
                images = Array(zip(admitted.resources, admitted.images))
            } else {
                images = [(texture, animation.frames[0])]
            }
        } else {
            images = [(texture, try decodeReachedOutrage16OGF(payload))]
        }
        return images.map { frame in
            PresentationMaterial(
                texture: frame.texture,
                bitmapSourceName: definition.bitmapSourceName,
                image: .init(
                    width: frame.image.width,
                    height: frame.image.height,
                    rgba8: frame.image.rgba8
                ),
                blend: definition.blend,
                lightmapBlend: definition.lightmapBlend,
                waterProcedural: definition.waterProcedural,
                lightCorona: definition.lightCorona.map {
                    PresentationLightCorona(
                        assetIndex: coronaIndexByName[$0.bitmapSourceName]!,
                        tint: $0.tint,
                        blend: $0.blend
                    )
                },
                sourceArchive: library.relativePath,
                sourceSHA256: canonicalSHA256(payload)
            )
        }
    }
}

/// The corona bitmap of each light texture, in name order.
func makePresentationCoronaAssets(
    _ definitions: [RetailTextureDefinition],
    sources: ImportSources
) throws -> [PresentationCoronaAsset] {
    let names = Set(definitions.compactMap { $0.lightCorona?.bitmapSourceName }).sorted()
    return try names.enumerated().map { index, name in
        guard let (library, entry, _) = sources.firstEntry(named: name) else {
            throw D3ImportOperationError.missingPresentationAsset(name)
        }
        let payload = library.payload(entry)
        let image = try decodeReachedOutrage16OGF(payload)
        return PresentationCoronaAsset(
            source: .init(storedIndex: index, sourceName: name),
            bitmapSourceName: name,
            image: .init(width: image.width, height: image.height, rgba8: image.rgba8),
            sourceArchive: library.relativePath,
            sourceSHA256: canonicalSHA256(payload)
        )
    }
}
