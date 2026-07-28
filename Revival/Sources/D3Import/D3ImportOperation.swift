// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import Foundation

struct PreparedArchiveInventory: Codable, Equatable, Sendable {
    let relativePath: String
    let byteCount: Int
    let sha256: String
    let entryCount: Int
}

struct CanonicalLevelCounts: Codable, Equatable, Sendable {
    let usedRooms: Int
    let roomVertices: Int
    let faces: Int
    let faceVertices: Int
    let directedPortals: Int
    let usedObjects: Int
    let terrainCells: Int
    let paths: Int
    let goals: Int
    let triggers: Int
    let lightmapInfos: Int
}

struct DependencyCategoryCount: Codable, Equatable, Sendable {
    let category: String
    let count: Int
}

struct RoomPortalEvidence: Codable, Equatable, Sendable {
    let index: Int
    let faceIndex: Int
    let connectedRoom: Int
    let connectedPortal: Int
    let flags: UInt32
}

struct RoomObjectEvidence: Codable, Equatable, Sendable {
    let slot: Int
    let type: UInt8
    let storedID: Int
    let sourceName: String
    let referenceRuntimeIndex: Int?
    let instanceName: String?
}

struct RoomThreeEvidence: Codable, Equatable, Sendable {
    let faces: Int
    let portals: [RoomPortalEvidence]
    let objects: [RoomObjectEvidence]
}

struct CanonicalPackageDigests: Codable, Equatable, Sendable {
    let contentSHA256: String
    let levelSHA256: String
}

struct D3ImportReport: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let contract: Int
    let result: String
    let promotionOccurred: Bool
    let diagnostics: [String]
    let scope: String
    let completedMissionKeys: [String]
    let completedLevelKeys: [String]
    let profileIdentifier: String
    let missionKey: String
    let levelKey: String
    let source: LevelSource
    let archives: [PreparedArchiveInventory]
    let usedRoomSourceIndices: [Int]
    let counts: CanonicalLevelCounts
    let roomThree: RoomThreeEvidence
    let dependencies: [DependencyCategoryCount]
    let currentDependencies: [DependencyRecord]
    let sourceEntries: [SourceChunkRecord]
    let historicalEagerBaseline: EagerDependencyBaseline?
    let package: CanonicalPackageDigests
}

typealias D3ImportCancellationCheck = () -> Int32?

func blockD3ImportCancellationSignals() {
    var signals = sigset_t()
    precondition(sigemptyset(&signals) == 0)
    precondition(sigaddset(&signals, SIGINT) == 0)
    precondition(sigaddset(&signals, SIGTERM) == 0)
    let result = pthread_sigmask(SIG_BLOCK, &signals, nil)
    precondition(result == 0)
}

func pendingD3ImportCancellationSignal() -> Int32? {
    var pending = sigset_t()
    precondition(sigpending(&pending) == 0)
    for signal in [SIGINT, SIGTERM] where sigismember(&pending, signal) == 1 {
        var selected = sigset_t()
        precondition(sigemptyset(&selected) == 0)
        precondition(sigaddset(&selected, signal) == 0)
        var observed: Int32 = 0
        let result = sigwait(&selected, &observed)
        precondition(result == 0)
        return observed
    }
    return nil
}

func makeD3ImportReport(
    level: Level,
    scope: String,
    archives: [PreparedArchiveInventory],
    packageContentSHA256: String,
    packageLevelSHA256: String
) -> D3ImportReport {
    let room = level.rooms.first(where: { $0.sourceIndex == 3 })!
    let roomThree = RoomThreeEvidence(
        faces: room.faces.count,
        portals: room.portals.enumerated().map { index, portal in
            RoomPortalEvidence(
                index: index,
                faceIndex: portal.faceIndex,
                connectedRoom: portal.connectedRoom,
                connectedPortal: portal.connectedPortal,
                flags: portal.flags
            )
        },
        objects: level.objects.filter {
            if case .room(3) = $0.location { return true }
            return false
        }.map { object in
            let definition = object.definition!
            return RoomObjectEvidence(
                slot: object.slot,
                type: object.type,
                storedID: object.storedID,
                sourceName: definition.sourceName,
                referenceRuntimeIndex: definition.referenceRuntimeIndex,
                instanceName: object.instanceName
            )
        }
    )
    let groupedDependencies = Dictionary(grouping: level.dependencyManifest.current, by: \.category)
    return D3ImportReport(
        schemaVersion: 2,
        contract: 1,
        result: "promoted",
        promotionOccurred: true,
        diagnostics: [],
        scope: scope,
        completedMissionKeys: [level.missionKey],
        completedLevelKeys: [level.levelKey],
        profileIdentifier: level.source.profileIdentifier,
        missionKey: level.missionKey,
        levelKey: level.levelKey,
        source: level.source,
        archives: archives,
        usedRoomSourceIndices: level.rooms.map(\.sourceIndex),
        counts: CanonicalLevelCounts(
            usedRooms: level.rooms.count,
            roomVertices: level.rooms.reduce(0) { $0 + $1.vertices.count },
            faces: level.rooms.reduce(0) { $0 + $1.faces.count },
            faceVertices: level.rooms.reduce(0) { count, room in
                count + room.faces.reduce(0) { $0 + $1.corners.count }
            },
            directedPortals: level.rooms.reduce(0) { $0 + $1.portals.count },
            usedObjects: level.objects.count,
            terrainCells: level.terrain.heights.count,
            paths: level.paths.count,
            goals: level.goals.count,
            triggers: level.triggers.count,
            lightmapInfos: level.lightmaps.infos.count
        ),
        roomThree: roomThree,
        dependencies: groupedDependencies.sorted(by: { $0.key < $1.key }).map {
            DependencyCategoryCount(category: $0.key, count: $0.value.count)
        },
        currentDependencies: level.dependencyManifest.current,
        sourceEntries: level.sourceChunks,
        historicalEagerBaseline: level.dependencyManifest.historicalEagerBaseline,
        package: CanonicalPackageDigests(
            contentSHA256: packageContentSHA256,
            levelSHA256: packageLevelSHA256
        )
    )
}

@discardableResult
func runD3Import(
    _ arguments: D3ImportArguments,
    cancellationCheck: D3ImportCancellationCheck
) throws -> D3ImportReport {
    try throwIfD3ImportCancelled(cancellationCheck)
    try validateD3ImportPaths(arguments)

    let profile = PreparedRetailProfile.training
    let trainingFile = profile.files.first {
        $0.relativePath == "missions/training.mn3"
    }!
    let training = try readValidatedPreparedRetailFile(trainingFile, at: arguments.source)
    let trainingArchive = try! parseHOG2(training.data)
    var inventoryByPath = [
        trainingFile.relativePath: archiveInventory(training, trainingArchive),
    ]
    let trainingData = training.data

    let descriptorEntry = trainingArchive.uniqueEntry(named: "training.msn")
    let mission = try! parseTrainingMission(trainingData.subdata(in: descriptorEntry.payloadRange))
    let levelEntry = trainingArchive.uniqueEntry(named: mission.mineSourceName)
    let levelData = trainingData.subdata(in: levelEntry.payloadRange)

    let source = LevelSource(
        profileIdentifier: profile.identifier,
        profileFiles: profile.files.map {
            SourceFileFingerprint(
                relativePath: $0.relativePath,
                byteCount: $0.byteCount,
                sha256: $0.sha256
            )
        },
        archiveSHA256: "fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54",
        levelSHA256: "915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41",
        d3lvVersion: 127,
        archiveEntryName: levelEntry.sourceName,
        archiveEntryOffset: levelEntry.payloadRange.lowerBound,
        archiveEntryByteCount: levelData.count,
        referenceChecksum: "6db74a2eb0c563de4eb11e6d4e91e59c",
        referenceChecksumBasis: "pinned-source-provenance-implied-by-exact-level-sha256"
    )
    let parsedLevel = try! parseD3LV127(levelData, source: source)

    let mercFile = profile.files.first { $0.relativePath == "merc.hog" }!
    let merc = try readValidatedPreparedRetailFile(mercFile, at: arguments.source)
    let mercArchive = try! parseHOG2(merc.data)
    inventoryByPath[mercFile.relativePath] = archiveInventory(merc, mercArchive)
    let tableData = merc.data.subdata(in: mercArchive.uniqueEntry(named: "Table.gam").payloadRange)

    let extra13File = profile.files.first { $0.relativePath == "extra13.hog" }!
    let extra13 = try readValidatedPreparedRetailFile(extra13File, at: arguments.source)
    let extra13Archive = try! parseHOG2(extra13.data)
    inventoryByPath[extra13File.relativePath] = archiveInventory(extra13, extra13Archive)
    let overlayData = extra13.data.subdata(
        in: extra13Archive.uniqueEntry(named: "extra.gam").payloadRange
    )
    let residentFaceTextures = Set(parsedLevel.rooms.flatMap {
        $0.faces.map(\.texture)
    })
    let surfacePhysics = try resolveRetailSurfacePhysics(
        table: tableData,
        overlay: overlayData,
        textures: residentFaceTextures
    )
    let topologyLevel = parsedLevel.addingSurfacePhysics(surfacePhysics)

    let extraFile = profile.files.first { $0.relativePath == "extra.hog" }!
    let extra = try readValidatedPreparedRetailFile(extraFile, at: arguments.source)
    let extraArchive = try! parseHOG2(extra.data)
    inventoryByPath[extraFile.relativePath] = archiveInventory(extra, extraArchive)
    let d3File = profile.files.first { $0.relativePath == "d3.hog" }!
    let d3 = try readValidatedPreparedRetailFile(d3File, at: arguments.source)
    let d3Archive = try! parseHOG2(d3.data)
    inventoryByPath[d3File.relativePath] = archiveInventory(d3, d3Archive)

    let presentationArchives = [
        IndexedPreparedArchive(validated: extra13, archive: extra13Archive),
        IndexedPreparedArchive(validated: merc, archive: mercArchive),
        IndexedPreparedArchive(validated: extra, archive: extraArchive),
        IndexedPreparedArchive(validated: d3, archive: d3Archive),
    ]
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: topologyLevel.rooms.map { ($0.sourceIndex, $0) }
    )
    let playerObject = topologyLevel.objects.first {
        $0.type == D3SourceIdentity.playerObjectType && $0.storedID == 0
    }!
    guard case .room(let playerRoomSourceIndex) = playerObject.location else {
        preconditionFailure("Training player 0 must start in a room")
    }
    precondition(
        playerObject.handle == 2_048
            && playerRoomSourceIndex == 1
            && playerObject.position == .init(
                x: 2_060.6497,
                y: -131.22517,
                z: 2_204.4216
            )
            && playerObject.orientation == .init(
                right: .init(x: 1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: 1)
            )
    )
    let presentationRoomIndices = reciprocalPortalComponent(
        rooms: topologyLevel.rooms,
        startRoomSourceIndex: playerRoomSourceIndex
    )
    precondition(
        presentationRoomIndices.count == 48
            && presentationRoomIndices == Set(topologyLevel.rooms.map(\.sourceIndex))
    )
    let componentEvidence = presentationRoomIndices.sorted().map {
        "\($0)\n"
    }.joined()
    precondition(
        topologyLevel.rooms.reduce(0) { $0 + $1.portals.count } == 112
            && canonicalSHA256(Data(componentEvidence.utf8))
                == "eb1bbb096d75873279fd0dc02d3c599052ba94f129e6f0f539867144c5c4a712"
    )
    let presentationFaceReferences = topologyLevel.rooms
        .filter { presentationRoomIndices.contains($0.sourceIndex) }
        .flatMap { room in
            room.faces.indices.map {
                SourceVisibleFace(roomSourceIndex: room.sourceIndex, faceIndex: $0)
            }
        }
        .sorted {
            ($0.roomSourceIndex, $0.faceIndex) < ($1.roomSourceIndex, $1.faceIndex)
        }
    precondition(presentationFaceReferences.count == 3_485)
    var lightmapPageByInfo: [Int: Int] = [:]
    let perFaceLightmapEvidence = presentationFaceReferences.compactMap { reference -> String? in
        let face = roomBySourceIndex[reference.roomSourceIndex]!.faces[reference.faceIndex]
        guard let infoIndex = face.lightmapInfoIndex else { return nil }
        let pageIndex = topologyLevel.lightmaps.infos[infoIndex].pageIndex
        lightmapPageByInfo[infoIndex] = pageIndex
        return "\(reference.roomSourceIndex):\(reference.faceIndex):\(infoIndex):\(pageIndex)\n"
    }.joined()
    precondition(
        perFaceLightmapEvidence.utf8.count > 0
            && perFaceLightmapEvidence.filter({ $0 == "\n" }).count == 3_454
            && canonicalSHA256(Data(perFaceLightmapEvidence.utf8))
                == "8466bc5b21fb3d4fe3f703778eaed28c15ef6d4cf4833d296e0f766e71e1ba7d"
    )
    let uniqueLightmapEvidence = lightmapPageByInfo.keys.sorted().map {
        "\($0):\(lightmapPageByInfo[$0]!)\n"
    }.joined()
    precondition(
        lightmapPageByInfo.count == 2_486
            && canonicalSHA256(Data(uniqueLightmapEvidence.utf8))
                == "4f8cf214788187dadf30f987d08c077ed2576346cd64a48d1795da83cee2bcde"
    )
    let textureByName = presentationFaceReferences.reduce(
        into: [String: SourceResource]()
    ) { result, reference in
        let texture = roomBySourceIndex[reference.roomSourceIndex]!
            .faces[reference.faceIndex].texture
        result[texture.sourceName.lowercased()] = texture
    }
    let roomMaterialEvidence = textureByName.values.sorted {
        if $0.storedIndex != $1.storedIndex {
            return $0.storedIndex < $1.storedIndex
        }
        return $0.sourceName < $1.sourceName
    }.map {
        "\($0.storedIndex):\($0.sourceName)\n"
    }.joined()
    precondition(
        textureByName.count == 22
            && canonicalSHA256(Data(roomMaterialEvidence.utf8))
                == "50a51f618ae1c7fa0cbe62f911b584cb3b1d7961a384ac48e5ff6ff8a40056aa"
    )
    let definitions = try! resolveRetailTextureDefinitions(
        table: tableData,
        overlay: overlayData,
        names: Set(textureByName.keys)
    )
    let coronaAssets = makePresentationCoronaAssets(
        definitions,
        archives: presentationArchives
    )
    precondition(
        coronaAssets.map(\.source.sourceName) == ["StarFlare6.ogf"]
            && coronaAssets[0].sourceSHA256
                == "fa5d633a1af6fe1c07632ac40da19eeb30e21f08cb84dc6be83a0626709710c2"
            && canonicalSHA256(coronaAssets[0].image.rgba8)
                == "2649897647d5b3b3584b5c6c474f53a95ab5f397bb3ecb76bb92cef66c1c5e3f"
    )
    let materials = try makePresentationMaterials(
        definitions,
        textureByName: textureByName,
        archives: presentationArchives
    )
    let coronaByTexture = Dictionary(
        uniqueKeysWithValues: materials.compactMap { material in
            material.lightCorona.map { (material.texture.storedIndex, $0) }
        }
    )
    precondition(
        Set(coronaByTexture.keys) == [908, 1_199, 1_202, 1_204, 1_205, 1_332]
            && coronaByTexture[1_205]?.tint
                == .init(x: Float(16) / 18, y: 1, z: 1)
            && coronaByTexture[1_332]?.tint
                == .init(x: 0.2, y: 0.2, z: 0.2),
        "unexpected corona textures: \(coronaByTexture.keys.sorted())"
    )
    let reachedLightmapPages = Set(presentationFaceReferences.compactMap { reference -> Int? in
        let face = roomBySourceIndex[reference.roomSourceIndex]!.faces[reference.faceIndex]
        return face.lightmapInfoIndex.map { topologyLevel.lightmaps.infos[$0].pageIndex }
    })
    precondition(reachedLightmapPages == Set(0..<20))
    let roomPresentationLevel = topologyLevel.addingPresentationMaterials(
        materials,
        retainingLightmapPages: reachedLightmapPages,
        coronaAssets: coronaAssets
    )
    let reachedPages = try resolveReachedObjectModelPages(
        table: tableData,
        overlay: overlayData,
        shipName: "Pyro-GL",
        genericName: "Invisiblepowerup"
    )
    let guidebotPage = try resolveRetailGenericModelPage(
        table: tableData,
        overlay: overlayData,
        name: "GuideBot"
    )
    let destroyRobotPage = try resolveRetailGenericModelPage(
        table: tableData,
        overlay: overlayData,
        name: "RAS1 Light Security Flyer"
    )
    let cameraMonitorPage = try resolveRetailGenericModelPage(
        table: tableData,
        overlay: overlayData,
        name: "Camera Monitor"
    )
    let invulnerabilityPage = try resolveRetailGenericModelPage(
        table: tableData,
        overlay: overlayData,
        name: "Invulnerability"
    )
    let cloakPage = try resolveRetailGenericModelPage(
        table: tableData,
        overlay: overlayData,
        name: "Cloak"
    )
    let securityCameraPage = try resolveRetailGenericModelPage(
        table: tableData,
        overlay: overlayData,
        name: "new wall cam"
    )
    let returnMarkerLightPage = try resolveRetailGenericModelPage(
        table: tableData,
        overlay: overlayData,
        name: "Blinking Red Light-DM"
    )
    let returnMarkerLightPresentation =
        returnMarkerLightPage.genericLight!
    let reachedModelNames = Set([
        reachedPages.ship.primaryModelName,
        reachedPages.ship.mediumModelName,
        reachedPages.ship.lowModelName,
        reachedPages.ship.dyingModelName,
        reachedPages.generic.primaryModelName,
        reachedPages.generic.mediumModelName,
        reachedPages.generic.lowModelName,
        guidebotPage.primaryModelName,
        guidebotPage.mediumModelName,
        guidebotPage.lowModelName,
        destroyRobotPage.primaryModelName,
        destroyRobotPage.mediumModelName,
        destroyRobotPage.lowModelName,
        cameraMonitorPage.primaryModelName,
        cameraMonitorPage.mediumModelName,
        cameraMonitorPage.lowModelName,
        invulnerabilityPage.primaryModelName,
        invulnerabilityPage.mediumModelName,
        invulnerabilityPage.lowModelName,
        cloakPage.primaryModelName,
        cloakPage.mediumModelName,
        cloakPage.lowModelName,
    ].compactMap { $0 })
    let sortedModelNames = reachedModelNames.sorted {
        $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
    }
    var modelPayloadByName: [String: (data: Data, archive: String)] = [:]
    var textureNamesByModel: [String: [String]] = [:]
    var referencedTextureSlotsByModel: [String: Set<Int>] = [:]
    for name in sortedModelNames {
        guard let indexed = presentationArchives.first(where: {
            $0.archive.entry(named: name) != nil
        }), let entry = indexed.archive.entry(named: name) else {
            throw D3ImportOperationError.missingPresentationAsset(name)
        }
        let payload = indexed.validated.data.subdata(in: entry.payloadRange)
        modelPayloadByName[name.lowercased()] = (
            payload,
            indexed.validated.file.relativePath
        )
        textureNamesByModel[name.lowercased()] = try reachedOutrageModelTextureNames(payload)
        referencedTextureSlotsByModel[name.lowercased()]
            = try reachedOutrageModelReferencedTextureSlotIndices(payload)
    }
    let reachedTextureNames = Set(textureNamesByModel.flatMap { key, names in
        referencedTextureSlotsByModel[key]!.sorted().map { names[$0] }
    }).filter { $0.caseInsensitiveCompare("SAMPLE TEXTURE") != .orderedSame }
    let reachedGyroFlasherFrame = "SecFlyLit-Flashers000"
    let reachedGyroFlareDefinitions = try resolveRetailTextureDefinitions(
        table: tableData,
        overlay: overlayData,
        names: ["red flare"]
    )
    precondition(reachedGyroFlareDefinitions.count == 1)
    let reachedGyroFlareDefinition = reachedGyroFlareDefinitions[0]
    let resolvedReachedTextureDefinitions = try resolveRetailTextureDefinitions(
        table: tableData,
        overlay: overlayData,
        names: Set(reachedTextureNames.filter {
            $0.caseInsensitiveCompare(reachedGyroFlasherFrame)
                != .orderedSame
        })
    )
    let reachedTextureDefinitions = Dictionary(
        (resolvedReachedTextureDefinitions + [reachedGyroFlareDefinition]).map {
            ($0.storedIndex, $0)
        },
        uniquingKeysWith: { first, _ in first }
    ).values.sorted { $0.storedIndex < $1.storedIndex }
    let modelTextureByName = Dictionary(
        uniqueKeysWithValues: reachedTextureDefinitions.map {
            ($0.name.lowercased(), SourceResource(storedIndex: $0.storedIndex, sourceName: $0.name))
        }
    )
    var modelTextureBySlotName = modelTextureByName
    for definition in reachedTextureDefinitions {
        let bitmapKey = URL(fileURLWithPath: definition.bitmapSourceName)
            .deletingPathExtension().lastPathComponent.lowercased()
        modelTextureBySlotName[bitmapKey] = modelTextureByName[definition.name.lowercased()]!
    }
    modelTextureBySlotName[reachedGyroFlasherFrame.lowercased()]
        = modelTextureByName[reachedGyroFlareDefinition.name.lowercased()]
    precondition(
        modelTextureBySlotName[reachedGyroFlasherFrame.lowercased()] != nil
    )
    let modelMaterials = try makePresentationMaterials(
        reachedTextureDefinitions,
        textureByName: modelTextureByName,
        archives: presentationArchives
    )
    let modelSources = Dictionary(
        uniqueKeysWithValues: sortedModelNames.enumerated().map {
            ($0.element.lowercased(), SourceResource(storedIndex: $0.offset, sourceName: $0.element))
        }
    )
    let reachedModels = try sortedModelNames.map { name in
        let key = name.lowercased()
        let payload = modelPayloadByName[key]!
        let slots = textureNamesByModel[key]!.enumerated().map {
            index, textureName -> SourceResource? in
            guard referencedTextureSlotsByModel[key]!.contains(index) else { return nil }
            guard textureName.caseInsensitiveCompare("SAMPLE TEXTURE") != .orderedSame else {
                return nil
            }
            return modelTextureBySlotName[textureName.lowercased()]
        }
        guard slots.enumerated().allSatisfy({ index, source in
            !referencedTextureSlotsByModel[key]!.contains(index)
                || source != nil || textureNamesByModel[key]![index]
                .caseInsensitiveCompare("SAMPLE TEXTURE") == .orderedSame
        }) else {
            throw D3ImportOperationError.missingPresentationAsset(name)
        }
        return try parseReachedOutrageModel(
            payload.data,
            sourceName: name,
            sourceIndex: modelSources[key]!.storedIndex,
            sourceArchive: payload.archive,
            textureResources: slots
        )
    }
    let pyroModel = reachedModels.first {
        $0.source.sourceName.caseInsensitiveCompare("PyroGL.OOF") == .orderedSame
    }!
    precondition(
        pyroModel.sourceSHA256
            == "0b004302ffe60a50e39b8f8261a3c11ca0044f11000ef6e039527e4c1ebff75b"
            && pyroModel.collisionRadius.bitPattern == 0x40d9_5869
    )
    let ship = reachedPages.ship
    let generic = reachedPages.generic
    let reachedObjectPresentations = topologyLevel.objects.compactMap {
        object -> ObjectPresentationReference? in
        let page: RetailModelPageSelection
        if object.type == D3SourceIdentity.playerObjectType {
            guard case .room(let room) = object.location,
                  room == 1 || room == 3 else {
                return nil
            }
            page = ship
        } else if object.definition?.sourceName.caseInsensitiveCompare(generic.name)
            == .orderedSame {
            guard case .room(let room) = object.location,
                  room == 1 || room == 3 else {
                return nil
            }
            page = generic
        } else if object.handle == 2_081
                    || object.handle == 2_082
                    || object.handle == 2_083 {
            page = destroyRobotPage
        } else if object.handle == 4_112
                    || object.handle == 2_074
                    || object.handle == 2_075
                    || object.handle == 2_077
                    || object.handle == 2_078
                    || object.handle == 4_127
                    || object.handle == 2_080,
                  object.definition?.sourceName.caseInsensitiveCompare(
                      destroyRobotPage.name
            ) == .orderedSame
        {
            page = destroyRobotPage
        } else if object.handle == 6_167,
                  object.definition?.sourceName.caseInsensitiveCompare(
                      cameraMonitorPage.name
            ) == .orderedSame
        {
            page = cameraMonitorPage
        } else if object.handle == 2_076,
            object.definition?.sourceName.caseInsensitiveCompare(
                invulnerabilityPage.name
            ) == .orderedSame
        {
            page = invulnerabilityPage
        } else if object.handle == 2_073,
            object.definition?.sourceName.caseInsensitiveCompare(
                cloakPage.name
            ) == .orderedSame
        {
            page = cloakPage
        } else {
            return nil
        }
        return ObjectPresentationReference(
            objectHandle: object.handle,
            primaryModel: modelSources[page.primaryModelName.lowercased()]!,
            mediumModel: page.mediumModelName.map { modelSources[$0.lowercased()]! },
            lowModel: page.lowModelName.map { modelSources[$0.lowercased()]! },
            dyingModel: page.dyingModelName.map { modelSources[$0.lowercased()]! },
            mediumDistance: page.mediumDistance,
            lowDistance: page.lowDistance
        )
    }
    precondition(reachedObjectPresentations.count == 20)
    let presentedHandles = Set(reachedObjectPresentations.map(\.objectHandle))
    let deferredRoomObjects = topologyLevel.objects.filter {
        guard case .room = $0.location else { return false }
        return $0.handle != playerObject.handle && !presentedHandles.contains($0.handle)
    }
    precondition(deferredRoomObjects.count == 19)
    let objectPresentationLevel = roomPresentationLevel.addingObjectPresentation(
        models: reachedModels,
        objectPresentations: reachedObjectPresentations,
        materials: modelMaterials
    )
    precondition(modelMaterials.allSatisfy { material in
        objectPresentationLevel.presentationMaterials.contains {
            $0.texture == material.texture
        }
    })
    let retailShip = ship.shipDefinition!
    precondition(
        retailShip.name == "Pyro-GL"
            && retailShip.presentationSize == 6.676084041595459
            && retailShip.physics.mass == 30
            && retailShip.physics.drag == 90
            && retailShip.physics.fullThrust == 5_400
            && retailShip.physics.behaviors == [.turnroll, .wiggle, .usesThrust]
            && retailShip.physics.rotationalDrag == 225
            && retailShip.physics.fullRotationalThrust == 6_860_000
            && retailShip.physics.numberOfBounces == -1
            && retailShip.physics.initialForwardVelocity == 0
            && retailShip.physics.initialAngularVelocity == .zero
            && retailShip.physics.wiggleAmplitude == 0.17
            && retailShip.physics.wigglesPerSecond == 0.9
            && retailShip.physics.coefficientOfRestitution == 1
            && retailShip.physics.hitDieDot == -1
            && retailShip.physics.maximumTurnrollRate == 8_000
            && retailShip.physics.turnrollRatio == 0.13
    )
    let shipSource = SourceResource(storedIndex: 0, sourceName: retailShip.name)
    let playerLevel = objectPresentationLevel.addingDefaultPlayerShip(
        .init(
            source: shipSource,
            primaryModel: modelSources[ship.primaryModelName.lowercased()]!,
            presentationSize: retailShip.presentationSize,
            physics: retailShip.physics
        ),
        binding: .init(
            playerID: 0,
            objectHandle: playerObject.handle,
            ship: shipSource
        )
    )
    let messageEntry = trainingArchive.uniqueEntry(named: "TrainingMission.msg")
    let messages = try parseTrainingMessages(
        trainingData.subdata(in: messageEntry.payloadRange)
    )
    let forwardGoal = playerLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("ForwardGoal") == .orderedSame
    }!
    precondition(forwardGoal.handle == 12_301 && forwardGoal.type == 7)
    let voiceNames = [
        "Welcome.osf",
        "Return1.osf",
        "GuideBotA.osf",
        "GuideBotB.osf",
        "proceed5.osf",
        "GuideBotC.osf",
        "GuideBotD.osf",
        "proceed6.osf",
        "intro6.osf",
        "GuideBotF.osf",
        "Intro7.osf",
    ]
    let voiceClips = try voiceNames.map { name -> CanonicalVoiceClip in
        let entry = trainingArchive.uniqueEntry(named: name)
        let entryIndex = trainingArchive.entries.firstIndex(of: entry)!
        let payload = trainingData.subdata(in: entry.payloadRange)
        let decoded = try decodeOSFACMVoice(payload)
        return CanonicalVoiceClip(
            sourceName: name.lowercased(),
            sourceEntryIndex: entryIndex,
            sampleRate: decoded.sampleRate,
            channelCount: decoded.channelCount,
            frameCount: decoded.frameCount,
            pcm16LittleEndian: decoded.pcm16LittleEndian,
            pcmSHA256: canonicalSHA256(decoded.pcm16LittleEndian),
            sourceArchive: trainingFile.relativePath,
            sourceSHA256: canonicalSHA256(payload)
        )
    }
    let openingLevel = playerLevel.addingTrainingOpeningLesson(
        .init(
            forwardGoalObjectHandle: forwardGoal.handle,
            welcomeDelay: 1,
            welcomeMessage: messages["Welcome"]!,
            forwardInstruction: messages["GoForward"]!,
            welcomeVoiceSourceName: "welcome.osf",
            successMessage: messages["GoodJob"]!,
            reverseInstruction: messages["GoBackwards"]!,
            successVoiceSourceName: "return1.osf"
        ),
        voiceClips: Array(voiceClips.prefix(2))
    )
    let galleryTrigger = openingLevel.triggers.first {
        $0.name.caseInsensitiveCompare("Portal2") == .orderedSame
    }!
    let galleryRoom = openingLevel.rooms.first {
        $0.name?.caseInsensitiveCompare("PortalRoom4") == .orderedSame
    }!
    let markerLight = openingLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("FlashLight-2")
            == .orderedSame
    }!
    precondition(
        galleryTrigger.roomIndex == galleryRoom.sourceIndex
            && galleryTrigger.faceIndex == 1
            && galleryTrigger.flags == 8
            && galleryTrigger.activator == 1
            && galleryRoom.sourceIndex == 38
            && galleryRoom.portals.count == 2
            && galleryRoom.portals[0].faceIndex == 0
            && galleryRoom.portals[1].faceIndex == 1
            && galleryRoom.faces[0].texture.sourceName
                == "Alien Force Field_1"
            && galleryRoom.faces[1].texture.sourceName
                == "Alien Force Field_1"
            && markerLight.handle == 6_163
            && markerLight.type == 11
    )
    let galleryLevel = openingLevel.addingTrainingGalleryBarrier(
        .init(
            triggerName: galleryTrigger.name,
            triggerRoomSourceIndex: galleryTrigger.roomIndex,
            triggerFaceIndex: galleryTrigger.faceIndex,
            barrierRoomSourceIndex: galleryRoom.sourceIndex,
            orderedPortalIndices: [1, 0],
            markerLightObjectHandle: markerLight.handle,
            openMarkerLightDistance: 50,
            successMessage: messages["GoodJob"]!,
            guidebotInstruction: messages["GBIntro"]!,
            voiceSourceName: "guidebota.osf"
        ),
        voiceClip: voiceClips[2]
    )
    let destroyRobot = galleryLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("DestroyBot2")
            == .orderedSame
    }!
    precondition(
        destroyRobot.handle == 4_112
            && destroyRobot.type == 2
            && destroyRobot.storedID == 106
            && destroyRobot.definition?.sourceName
                == "RAS1 Light Security Flyer"
            && destroyRobot.flags == 5_121
            && destroyRobot.location == .room(37)
    )
    let robotGuidebotLevel = galleryLevel.addingTrainingRobotGuidebotChain(
        .init(
            destroyRobotObjectHandle: destroyRobot.handle,
            guidebotObjectHandle: 6_164,
            destroyRobotRoomSourceIndex: 37,
            destroyRobotFlags: 5_121,
            destructionDelay: 2,
            destructionMessage: messages["GoodJob"]!,
            exitInstruction: messages["ExitManuveur"]!,
            destructionVoiceSourceName: "proceed5.osf",
            deployedGuidebotObjectType: 2,
            deployedGuidebotMessage: messages["GetCameraMonitor"]!,
            deployedGuidebotVoiceSourceName: "guidebotb.osf",
            combat: .stockTraining,
            guidebot: .stockTraining
        ),
        voiceClips: [voiceClips[3], voiceClips[4]]
    )
    let cameraMonitor = robotGuidebotLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("CameraMonitor")
            == .orderedSame
    }!
    let securityCamera = robotGuidebotLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("SecurityCamera")
            == .orderedSame
    }!
    let returnMarkerLight = robotGuidebotLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("FlashLight-3")
            == .orderedSame
    }!
    let returnBarrierRoom = robotGuidebotLevel.rooms.first {
        $0.name?.caseInsensitiveCompare("PortalRoom5") == .orderedSame
    }!
    let killbotEntryTrigger = robotGuidebotLevel.triggers.first {
        $0.name.caseInsensitiveCompare("Portal3") == .orderedSame
    }!
    let finalRoomEntryTrigger = robotGuidebotLevel.triggers.first {
        $0.name.caseInsensitiveCompare("Portal4") == .orderedSame
    }!
    let rasBot1 = robotGuidebotLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("RASBot1")
            == .orderedSame
    }!
    let rasBot2 = robotGuidebotLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("RASBot2")
            == .orderedSame
    }!
    let rasBot3 = robotGuidebotLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("RASBot3")
            == .orderedSame
    }!
    let rasBot4 = robotGuidebotLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("RASBot4")
            == .orderedSame
    }!
    let lastBot1 = robotGuidebotLevel.objects.first {
        $0.instanceName == "LastBot1"
    }!
    let lastBot2 = robotGuidebotLevel.objects.first {
        $0.instanceName == "LastBot2"
    }!
    let lastBot3 = robotGuidebotLevel.objects.first {
        $0.instanceName == "LastBot3"
    }!
    let lastBot4 = robotGuidebotLevel.objects.first {
        $0.instanceName == "LastBot4"
    }!
    let lastBot5 = robotGuidebotLevel.objects.first {
        $0.instanceName == "LastBot5"
    }!
    let invulnerabilityPickup = robotGuidebotLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("InvulnPowerup2")
            == .orderedSame
    }!
    let lastRoomMarker = robotGuidebotLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("FlashLight-4")
            == .orderedSame
    }!
    let lastRoomBarrier = robotGuidebotLevel.rooms.first {
        $0.name?.caseInsensitiveCompare("PortalRoom6")
            == .orderedSame
    }!
    let cloakPickup = robotGuidebotLevel.objects.first {
        $0.instanceName?.caseInsensitiveCompare("CloakPowerup2")
            == .orderedSame
    }!
    let cameraMonitorModel = reachedModels.first {
        $0.source.sourceName.caseInsensitiveCompare(
            cameraMonitorPage.primaryModelName
        ) == .orderedSame
    }!
    let invulnerabilityModel = reachedModels.first {
        $0.source.sourceName.caseInsensitiveCompare(
            invulnerabilityPage.primaryModelName
        ) == .orderedSame
    }!
    let cloakModel = reachedModels.first {
        $0.source.sourceName.caseInsensitiveCompare(
            cloakPage.primaryModelName
        ) == .orderedSame
    }!
    guard
        let securityCameraArchive = presentationArchives.first(
            where: {
            $0.archive.entry(
                named: securityCameraPage.primaryModelName
            ) != nil
        }
        ),
        let securityCameraEntry = securityCameraArchive.archive.entry(
            named: securityCameraPage.primaryModelName
        )
    else {
        throw D3ImportOperationError.missingPresentationAsset(
            securityCameraPage.primaryModelName
        )
    }
    let securityCameraPayload =
        securityCameraArchive.validated.data.subdata(
            in: securityCameraEntry.payloadRange
        )
    let securityCameraGunpoint = try reachedOutrageModelGunpoint(
        securityCameraPayload,
        index: 0
    )
    let pickupSoundPage = try resolveRetailSoundPage(
        table: tableData,
        overlay: overlayData,
        named: "PupC1"
    )
    let pickupSoundEntry = d3Archive.uniqueEntry(
        named: pickupSoundPage.sourceName
    )
    let pickupSoundPayload = d3.data.subdata(
        in: pickupSoundEntry.payloadRange
    )
    let pickupSound = try decodeReachedPCM16WAV(pickupSoundPayload)
    let invulnerabilityPickupSoundPage = try resolveRetailSoundPage(
        table: tableData,
        overlay: overlayData,
        named: "Powerup pickup"
    )
    let invulnerabilityPickupSoundEntry = d3Archive.uniqueEntry(
        named: invulnerabilityPickupSoundPage.sourceName
    )
    let invulnerabilityPickupSoundEntryIndex =
        d3Archive.entries.firstIndex(
            of: invulnerabilityPickupSoundEntry
        )!
    let invulnerabilityPickupSoundPayload = d3.data.subdata(
        in: invulnerabilityPickupSoundEntry.payloadRange
    )
    let invulnerabilityPickupSound = try decodeReachedPCM16WAV(
        invulnerabilityPickupSoundPayload
    )
    let returnSoundPage = try resolveRetailSoundPage(
        table: tableData,
        overlay: overlayData,
        named: "GBotAcceptOrder1"
    )
    let returnSoundEntry = d3Archive.uniqueEntry(
        named: returnSoundPage.sourceName
    )
    let returnSoundEntryIndex =
        d3Archive.entries.firstIndex(of: returnSoundEntry)!
    let returnSoundPayload = d3.data.subdata(
        in: returnSoundEntry.payloadRange
    )
    let returnSound = try decodeReachedPCM16WAV(returnSoundPayload)
    let invulnerabilityOnSoundPage = try resolveRetailSoundPage(
        table: tableData,
        overlay: overlayData,
        named: "Invulnerability on"
    )
    let invulnerabilityOnSoundEntry = d3Archive.uniqueEntry(
        named: invulnerabilityOnSoundPage.sourceName
    )
    let invulnerabilityOnSoundEntryIndex =
        d3Archive.entries.firstIndex(of: invulnerabilityOnSoundEntry)!
    let invulnerabilityOnSoundPayload = d3.data.subdata(
        in: invulnerabilityOnSoundEntry.payloadRange
    )
    let invulnerabilityOnSound = try decodeReachedPCM16WAV(
        invulnerabilityOnSoundPayload
    )
    let invulnerabilityOffSoundPage = try resolveRetailSoundPage(
        table: tableData,
        overlay: overlayData,
        named: "Invulnerability off"
    )
    let invulnerabilityOffSoundEntry = d3Archive.uniqueEntry(
        named: invulnerabilityOffSoundPage.sourceName
    )
    let invulnerabilityOffSoundEntryIndex =
        d3Archive.entries.firstIndex(of: invulnerabilityOffSoundEntry)!
    let invulnerabilityOffSoundPayload = d3.data.subdata(
        in: invulnerabilityOffSoundEntry.payloadRange
    )
    let invulnerabilityOffSound = try decodeReachedPCM16WAV(
        invulnerabilityOffSoundPayload
    )
    let cloakOnSoundPage = try resolveRetailSoundPage(
        table: tableData,
        overlay: overlayData,
        named: "Cloak on"
    )
    let cloakOnSoundEntry = d3Archive.uniqueEntry(
        named: cloakOnSoundPage.sourceName
    )
    let cloakOnSoundEntryIndex =
        d3Archive.entries.firstIndex(of: cloakOnSoundEntry)!
    let cloakOnSoundPayload = d3.data.subdata(
        in: cloakOnSoundEntry.payloadRange
    )
    let cloakOnSound = try decodeReachedPCM16WAV(cloakOnSoundPayload)
    let cloakOffSoundPage = try resolveRetailSoundPage(
        table: tableData,
        overlay: overlayData,
        named: "Cloak off"
    )
    let cloakOffSoundEntry = d3Archive.uniqueEntry(
        named: cloakOffSoundPage.sourceName
    )
    let cloakOffSoundEntryIndex =
        d3Archive.entries.firstIndex(of: cloakOffSoundEntry)!
    let cloakOffSoundPayload = d3.data.subdata(
        in: cloakOffSoundEntry.payloadRange
    )
    let cloakOffSound = try decodeReachedPCM16WAV(cloakOffSoundPayload)
    let cameraMonitorLevel =
        robotGuidebotLevel
        .addingTrainingCameraMonitorChain(
        .init(
            pickupObjectHandle: cameraMonitor.handle,
            securityCameraObjectHandle: securityCamera.handle,
            pickupCollisionRadius: cameraMonitorModel.collisionRadius,
            pickupMessage: messages["UseCameraMonitor"]!,
            pickupVoiceSourceName: "guidebotc.osf",
            pickupSoundSourceName: pickupSoundPage.sourceName,
            useMessage: messages["GBExtra"]!,
            useVoiceSourceName: "guidebotd.osf",
            popupDuration: 10,
            popupZoom: 1,
            cameraGunpointIndex: 0,
            cameraLocalPosition: securityCameraGunpoint.position,
            cameraLocalForward: securityCameraGunpoint.forward,
            completionTimerDuration: 2,
            returnToShip: .init(
                markerLightObjectHandle: returnMarkerLight.handle,
                markerLightPresentation: .init(
                    primaryColor:
                        returnMarkerLightPresentation.primaryColor,
                    secondaryColor:
                        returnMarkerLightPresentation.secondaryColor,
                    timeInterval:
                        returnMarkerLightPresentation.timeInterval,
                    flickerDistance:
                        returnMarkerLightPresentation.flickerDistance,
                    directionalDot:
                        returnMarkerLightPresentation.directionalDot,
                    flags: returnMarkerLightPresentation.flags,
                    timebits: returnMarkerLightPresentation.timebits,
                    angle: returnMarkerLightPresentation.angle,
                    lightingRenderType:
                        returnMarkerLightPresentation.lightingRenderType
                ),
                barrierRoomSourceIndex: returnBarrierRoom.sourceIndex,
                orderedPortalIndices: [0, 1],
                openMarkerLightDistance: 50,
                returnMessage: "GB: Returning to ship.",
                returnSoundSourceName: returnSoundPage.sourceName,
                arrivalMessage: "GB: Entering ship!",
                successMessage: messages["GoodJob"]!,
                successVoiceSourceName: "proceed6.osf",
                killbotEntry: .init(
                    triggerName: killbotEntryTrigger.name,
                    triggerRoomSourceIndex:
                        killbotEntryTrigger.roomIndex,
                    triggerFaceIndex: killbotEntryTrigger.faceIndex,
                    orderedPortalIndices: [1, 0],
                    closedMarkerLightDistance: 0,
                    entryMessage: messages["KillBotIntro"]!,
                    entryVoiceSourceName: "intro6.osf",
                    followupDelay: 13,
                    followupMessage: messages["KillBot2"]!,
                    followupVoiceSourceName: "guidebotf.osf"
                )
            )
        ),
        voiceClips: Array(voiceClips[5...9]),
        soundClips: [
            .init(
                logicalName: pickupSoundPage.logicalName,
                sourceName: pickupSoundPage.sourceName,
                sourceEntryIndex: pickupSoundPage.storedIndex,
                sampleRate: pickupSound.sampleRate,
                channelCount: pickupSound.channelCount,
                frameCount: pickupSound.frameCount,
                pcm16LittleEndian: pickupSound.pcm16LittleEndian,
                pcmSHA256: canonicalSHA256(
                    pickupSound.pcm16LittleEndian
                ),
                sourceArchive: d3File.relativePath,
                sourceSHA256: canonicalSHA256(pickupSoundPayload),
                importVolume: pickupSoundPage.importVolume
            ),
            .init(
                logicalName: returnSoundPage.logicalName,
                sourceName: returnSoundPage.sourceName,
                sourceEntryIndex: returnSoundEntryIndex,
                sampleRate: returnSound.sampleRate,
                channelCount: returnSound.channelCount,
                frameCount: returnSound.frameCount,
                pcm16LittleEndian: returnSound.pcm16LittleEndian,
                pcmSHA256: canonicalSHA256(
                    returnSound.pcm16LittleEndian
                ),
                sourceArchive: d3File.relativePath,
                sourceSHA256: canonicalSHA256(returnSoundPayload),
                importVolume: returnSoundPage.importVolume
            ),
        ]
        )
    precondition(
        cameraMonitor.handle == 6_167
            && cameraMonitor.type == 7
            && cameraMonitor.storedID == 91
            && cameraMonitor.flags == 4_096
            && securityCamera.handle == 6_183
            && securityCamera.type == 2
            && securityCamera.storedID == 114
            && securityCamera.flags == 5_120
            && returnMarkerLight.handle == 10_245
            && returnMarkerLight.type == 11
            && returnMarkerLight.storedID == 205
            && returnMarkerLight.location == .room(40)
            && returnBarrierRoom.sourceIndex == 40
            && returnBarrierRoom.portals.count == 2
            && killbotEntryTrigger.roomIndex
                == returnBarrierRoom.sourceIndex
            && killbotEntryTrigger.faceIndex == 1
            && killbotEntryTrigger.flags == 8
            && killbotEntryTrigger.activator == 1
    )
    precondition(
        rasBot1.handle == 2_074
            && rasBot1.type == 2
            && rasBot1.storedID == 106
            && rasBot1.definition?.sourceName
                == "RAS1 Light Security Flyer"
            && rasBot1.flags == 5_121
            && rasBot1.location == .room(11)
    )
    precondition(
        rasBot2.handle == 2_075
            && rasBot2.type == 2
            && rasBot2.storedID == 106
            && rasBot2.definition?.sourceName
                == "RAS1 Light Security Flyer"
            && rasBot2.flags == 5_121
            && rasBot2.location == .room(12)
    )
    precondition(
        rasBot3.handle == 2_077
            && rasBot3.type == 2
            && rasBot3.storedID == 106
            && rasBot3.definition?.sourceName
                == "RAS1 Light Security Flyer"
            && rasBot3.flags == 5_121
            && rasBot3.location == .room(42)
    )
    precondition(
        rasBot4.handle == 2_078
            && rasBot4.type == 2
            && rasBot4.storedID == 106
            && rasBot4.definition?.sourceName
                == "RAS1 Light Security Flyer"
            && rasBot4.flags == 5_121
            && rasBot4.location == .room(0)
    )
    precondition(
        lastBot1.handle == 4_127
            && lastBot1.type == 2
            && lastBot1.storedID == 106
            && lastBot1.definition?.sourceName
                == "RAS1 Light Security Flyer"
            && lastBot1.instanceName == "LastBot1"
            && lastBot1.flags == 5_121
            && lastBot1.location == .room(14)
    )
    precondition(
        lastBot2.handle == 2_080
            && lastBot2.type == 2
            && lastBot2.storedID == 106
            && lastBot2.definition?.sourceName
                == "RAS1 Light Security Flyer"
            && lastBot2.instanceName == "LastBot2"
            && lastBot2.flags == 5_121
            && lastBot2.location == .room(46)
    )
    precondition(
        lastBot3.handle == 2_081
            && lastBot3.type == 2
            && lastBot3.storedID == 106
            && lastBot3.definition?.sourceName
                == "RAS1 Light Security Flyer"
            && lastBot3.instanceName == "LastBot3"
            && lastBot3.flags == 5_121
            && lastBot3.location == .room(47)
    )
    precondition(
        lastBot4.handle == 2_082
            && lastBot4.type == 2
            && lastBot4.storedID == 106
            && lastBot4.definition?.sourceName
                == "RAS1 Light Security Flyer"
            && lastBot4.instanceName == "LastBot4"
            && lastBot4.flags == 5_121
            && lastBot4.location == .room(47)
    )
    precondition(
        lastBot5.handle == 2_083
            && lastBot5.type == 2
            && lastBot5.storedID == 106
            && lastBot5.definition?.sourceName
                == "RAS1 Light Security Flyer"
            && lastBot5.instanceName == "LastBot5"
            && lastBot5.flags == 5_121
            && lastBot5.location == .room(48)
    )
    precondition(
        invulnerabilityPickup.handle == 2_076
            && invulnerabilityPickup.type == 7
            && invulnerabilityPickup.storedID == 3
            && invulnerabilityPickup.definition
                == .init(
                    storedIndex: 3,
                    sourceName: "Invulnerability"
                )
            && invulnerabilityPickup.flags == 5_120
            && invulnerabilityPickup.location == .room(12)
    )
    precondition(
        cloakPickup.handle == 2_073
            && cloakPickup.type == 7
            && cloakPickup.storedID == 4
            && cloakPickup.definition
                == .init(storedIndex: 4, sourceName: "Cloak")
            && cloakPickup.flags == 5_120
            && cloakPickup.location == .room(11)
    )
    let rasBot1Level = cameraMonitorLevel.addingTrainingRASBot1DeathChain(
        .init(
            robotObjectHandle: rasBot1.handle,
            robotRoomSourceIndex: 11,
            robotFlags: rasBot1.flags,
            combat: .stockTraining
        )
    )
    let rasBot2Level = rasBot1Level.addingTrainingRASBot2DeathChain(
        .init(
            robotObjectHandle: rasBot2.handle,
            robotRoomSourceIndex: 12,
            robotFlags: rasBot2.flags,
            combat: .stockTraining
        )
    )
    let rasBot3Level = rasBot2Level.addingTrainingRASBot3DeathChain(
        .init(
            robotObjectHandle: rasBot3.handle,
            robotRoomSourceIndex: 42,
            robotFlags: rasBot3.flags,
            combat: .stockTraining
        )
    )
    let rasBot4Level = rasBot3Level.addingTrainingRASBot4DeathChain(
        .init(
            robotObjectHandle: rasBot4.handle,
            robotRoomSourceIndex: 0,
            robotFlags: rasBot4.flags,
            combat: .stockTraining
        )
    )
    let invulnerabilityLevel =
        rasBot4Level.addingTrainingInvulnerabilityPickupChain(
        .init(
            pickupObjectHandle: invulnerabilityPickup.handle,
            pickupRoomSourceIndex: 12,
            pickupObjectFlags: invulnerabilityPickup.flags,
            pickupCollisionRadius:
                invulnerabilityModel.collisionRadius,
            duration: 30,
            activatedMessage: "Invulnerability On",
            expiredMessage: "Invulnerability Off",
            pickupSoundSourceName:
                invulnerabilityPickupSoundPage.sourceName,
            activatedSoundSourceName:
                invulnerabilityOnSoundPage.sourceName,
            expiredSoundSourceName:
                invulnerabilityOffSoundPage.sourceName
        ),
        soundClips: [
            .init(
                logicalName:
                    invulnerabilityPickupSoundPage.logicalName,
                sourceName:
                    invulnerabilityPickupSoundPage.sourceName,
                sourceEntryIndex:
                    invulnerabilityPickupSoundEntryIndex,
                sampleRate: invulnerabilityPickupSound.sampleRate,
                channelCount:
                    invulnerabilityPickupSound.channelCount,
                frameCount: invulnerabilityPickupSound.frameCount,
                pcm16LittleEndian:
                    invulnerabilityPickupSound.pcm16LittleEndian,
                pcmSHA256: canonicalSHA256(
                    invulnerabilityPickupSound.pcm16LittleEndian
                ),
                sourceArchive: d3File.relativePath,
                sourceSHA256: canonicalSHA256(
                    invulnerabilityPickupSoundPayload
                ),
                importVolume:
                    invulnerabilityPickupSoundPage.importVolume
            ),
            .init(
                logicalName:
                    invulnerabilityOnSoundPage.logicalName,
                sourceName:
                    invulnerabilityOnSoundPage.sourceName,
                sourceEntryIndex:
                    invulnerabilityOnSoundEntryIndex,
                sampleRate: invulnerabilityOnSound.sampleRate,
                channelCount: invulnerabilityOnSound.channelCount,
                frameCount: invulnerabilityOnSound.frameCount,
                pcm16LittleEndian:
                    invulnerabilityOnSound.pcm16LittleEndian,
                pcmSHA256: canonicalSHA256(
                    invulnerabilityOnSound.pcm16LittleEndian
                ),
                sourceArchive: d3File.relativePath,
                sourceSHA256: canonicalSHA256(
                    invulnerabilityOnSoundPayload
                ),
                importVolume:
                    invulnerabilityOnSoundPage.importVolume * 0.5
            ),
            .init(
                logicalName:
                    invulnerabilityOffSoundPage.logicalName,
                sourceName:
                    invulnerabilityOffSoundPage.sourceName,
                sourceEntryIndex:
                    invulnerabilityOffSoundEntryIndex,
                sampleRate: invulnerabilityOffSound.sampleRate,
                channelCount: invulnerabilityOffSound.channelCount,
                frameCount: invulnerabilityOffSound.frameCount,
                pcm16LittleEndian:
                    invulnerabilityOffSound.pcm16LittleEndian,
                pcmSHA256: canonicalSHA256(
                    invulnerabilityOffSound.pcm16LittleEndian
                ),
                sourceArchive: d3File.relativePath,
                sourceSHA256: canonicalSHA256(
                    invulnerabilityOffSoundPayload
                ),
                importVolume:
                    invulnerabilityOffSoundPage.importVolume * 0.5
            ),
        ]
        )
    let cloakLevel =
        invulnerabilityLevel.addingTrainingCloakPickupChain(
        .init(
            pickupObjectHandle: cloakPickup.handle,
            pickupRoomSourceIndex: 11,
            pickupObjectFlags: cloakPickup.flags,
            pickupCollisionRadius: cloakModel.collisionRadius,
            fadeDuration: 1,
            cloakDuration: 30,
            activatedMessage: "Cloak On",
            expiredMessage: "Cloak Off",
            pickupSoundSourceName:
                invulnerabilityPickupSoundPage.sourceName,
            activatedSoundSourceName: cloakOnSoundPage.sourceName,
            expiredSoundSourceName: cloakOffSoundPage.sourceName
        ),
        soundClips: [
            .init(
                logicalName: cloakOnSoundPage.logicalName,
                sourceName: cloakOnSoundPage.sourceName,
                sourceEntryIndex: cloakOnSoundEntryIndex,
                sampleRate: cloakOnSound.sampleRate,
                channelCount: cloakOnSound.channelCount,
                frameCount: cloakOnSound.frameCount,
                pcm16LittleEndian: cloakOnSound.pcm16LittleEndian,
                pcmSHA256: canonicalSHA256(
                    cloakOnSound.pcm16LittleEndian
                ),
                sourceArchive: d3File.relativePath,
                sourceSHA256: canonicalSHA256(cloakOnSoundPayload),
                importVolume: cloakOnSoundPage.importVolume * 0.5
            ),
            .init(
                logicalName: cloakOffSoundPage.logicalName,
                sourceName: cloakOffSoundPage.sourceName,
                sourceEntryIndex: cloakOffSoundEntryIndex,
                sampleRate: cloakOffSound.sampleRate,
                channelCount: cloakOffSound.channelCount,
                frameCount: cloakOffSound.frameCount,
                pcm16LittleEndian: cloakOffSound.pcm16LittleEndian,
                pcmSHA256: canonicalSHA256(
                    cloakOffSound.pcm16LittleEndian
                ),
                sourceArchive: d3File.relativePath,
                sourceSHA256: canonicalSHA256(cloakOffSoundPayload),
                importVolume: cloakOffSoundPage.importVolume * 0.5
            ),
        ]
        )
    precondition(
        lastRoomBarrier.sourceIndex == 44
            && lastRoomBarrier.portals.count == 2
            && lastRoomBarrier.portals[0].flags & 1 != 0
            && lastRoomBarrier.portals[1].flags & 1 != 0
            && lastRoomMarker.handle == 4_117
            && lastRoomMarker.type == 11
            && lastRoomMarker.storedID == 205
            && lastRoomMarker.definition
                == .init(
                    storedIndex: 205,
                    sourceName: "Blinking Red Light-DM"
                )
            && lastRoomMarker.flags == 4_096
            && lastRoomMarker.location == .room(44)
    )
    let lastRoomLevel = cloakLevel.addingTrainingLastRoomChain(.init(
        barrierRoomSourceIndex: 44,
        orderedPortalIndices: [1, 0],
        markerLightObjectHandle: lastRoomMarker.handle,
        markerLightPresentation: .init(
            primaryColor:
                returnMarkerLightPresentation.primaryColor,
            secondaryColor:
                returnMarkerLightPresentation.secondaryColor,
            timeInterval:
                returnMarkerLightPresentation.timeInterval,
            flickerDistance:
                returnMarkerLightPresentation.flickerDistance,
            directionalDot:
                returnMarkerLightPresentation.directionalDot,
            flags: returnMarkerLightPresentation.flags,
            timebits: returnMarkerLightPresentation.timebits,
            angle: returnMarkerLightPresentation.angle,
            lightingRenderType:
                returnMarkerLightPresentation.lightingRenderType
        ),
        openMarkerLightDistance: 50,
        timerDuration: 2,
        completionMessages: [
            "Excellent!",
            "Now proceed through the doorway that just opened to begin the last stage of your training.",
        ],
        completionVoiceSourceName: "proceed5.osf"
    ))
    precondition(
        finalRoomEntryTrigger.roomIndex == 44
            && finalRoomEntryTrigger.faceIndex == 1
            && finalRoomEntryTrigger.flags == 8
            && finalRoomEntryTrigger.activator == 1
    )
    let finalRoomEntryLevel =
        lastRoomLevel.addingTrainingFinalRoomEntryChain(
            .init(
                triggerName: finalRoomEntryTrigger.name,
                triggerRoomSourceIndex:
                    finalRoomEntryTrigger.roomIndex,
                triggerFaceIndex: finalRoomEntryTrigger.faceIndex,
                successMessage: messages["GoodJob"]!,
                instructionMessage: messages["FinalSessionIntro"]!,
                voiceSourceName: "intro7.osf"
            ),
            voiceClip: voiceClips[10]
        )
    let lastBot1Level =
        finalRoomEntryLevel.addingTrainingLastBot1DeathChain(
        .init(
            robotObjectHandle: lastBot1.handle,
            robotRoomSourceIndex: 14,
            robotFlags: lastBot1.flags,
            combat: .stockTraining
        )
    )
    let lastBot2Level = lastBot1Level.addingTrainingLastBot2DeathChain(
        .init(
            robotObjectHandle: lastBot2.handle,
            robotRoomSourceIndex: 46,
            robotFlags: lastBot2.flags,
            combat: .stockTraining
        )
    )
    let lastBot3Level = lastBot2Level.addingTrainingLastBot3DeathChain(
        .init(
            robotObjectHandle: lastBot3.handle,
            robotRoomSourceIndex: 47,
            robotFlags: lastBot3.flags,
            combat: .stockTraining
        )
    )
    let lastBot4Level = lastBot3Level.addingTrainingLastBot4DeathChain(
        .init(
            robotObjectHandle: lastBot4.handle,
            robotRoomSourceIndex: 47,
            robotFlags: lastBot4.flags,
            combat: .stockTraining
        )
    )
    let level = lastBot4Level.addingTrainingLastBot5DeathChain(
        .init(
            robotObjectHandle: lastBot5.handle,
            robotRoomSourceIndex: 48,
            robotFlags: lastBot5.flags,
            combat: .stockTraining
        )
    )
    let playerView = defaultPlayerView(in: level)
    let initialExtraction = try extractWorldForRendering(level, playerView: playerView)
    precondition(
        initialExtraction.opaqueDrawItems.count
            + initialExtraction.translucentDrawItems.count == 232
    )
    let initialFaceSHA256 = canonicalSHA256(Data(
        (initialExtraction.opaqueDrawItems + initialExtraction.translucentDrawItems)
            .sorted {
                $0.roomSourceIndex == $1.roomSourceIndex
                    ? $0.faceIndex < $1.faceIndex
                    : $0.roomSourceIndex < $1.roomSourceIndex
            }
            .map { "\($0.roomSourceIndex):\($0.faceIndex)\n" }
            .joined()
            .utf8
    ))
    precondition(
        initialFaceSHA256
            == "9540339832d41b1ff667a9a08a627e989694fec246509a081e08413544838100"
    )
    precondition(initialExtraction.admittedObjectHandles == [12_300])
    precondition(
        initialExtraction.lightCoronas.map {
            "\($0.roomSourceIndex):\($0.faceIndex)"
        } == ["1:296"]
    )

    let ppicsFile = profile.files.first { $0.relativePath == "ppics.hog" }!
    let ppics = try readValidatedPreparedRetailFile(ppicsFile, at: arguments.source)
    let ppicsArchive = try! parseHOG2(ppics.data)
    inventoryByPath[ppicsFile.relativePath] = archiveInventory(ppics, ppicsArchive)
    let inventories = profile.files.map { inventoryByPath[$0.relativePath]! }

    try writeCanonicalPackage(level, to: arguments.staging)
    let stagedLevel = try loadCanonicalLevel(from: arguments.staging)
    precondition(stagedLevel == level)
    let contentData = try Data(
        contentsOf: arguments.staging.appending(path: "content.json"),
        options: .mappedIfSafe
    )
    let canonicalLevelData = try Data(
        contentsOf: arguments.staging
            .appending(path: "levels", directoryHint: .isDirectory)
            .appending(path: level.levelKey, directoryHint: .isDirectory)
            .appending(path: "level.json"),
        options: .mappedIfSafe
    )
    let report = makeD3ImportReport(
        level: level,
        scope: arguments.scope,
        archives: inventories,
        packageContentSHA256: canonicalSHA256(contentData),
        packageLevelSHA256: canonicalSHA256(canonicalLevelData)
    )
    let reportData = try! canonicalJSONData(report)
    try promoteCanonicalPackage(
        from: arguments.staging,
        to: arguments.destination,
        reportData: reportData,
        reportURL: arguments.report,
        cancellationCheck: cancellationCheck
    )
    return report
}

private func parseTrainingMessages(_ data: Data) throws -> [String: String] {
    guard let text = String(data: data, encoding: .utf8) else {
        throw D3ImportOperationError.missingPresentationAsset("TrainingMission.msg")
    }
    var messages: [String: String] = [:]
    for rawLine in text.split(whereSeparator: \.isNewline) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty,
              !line.hasPrefix("//"),
              let separator = line.firstIndex(of: "=") else {
            continue
        }
        let key = String(line[..<separator])
            .trimmingCharacters(in: .whitespaces)
        let value = String(line[line.index(after: separator)...])
            .trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !value.isEmpty, messages[key] == nil else {
            throw D3ImportOperationError.missingPresentationAsset("TrainingMission.msg")
        }
        messages[key] = value
    }
    guard ["Welcome", "GoForward", "GoodJob", "GoBackwards"].allSatisfy({
        messages[$0] != nil
    }) else {
        throw D3ImportOperationError.missingPresentationAsset("TrainingMission.msg")
    }
    return messages
}

private struct IndexedPreparedArchive {
    let validated: ValidatedPreparedRetailFile
    let archive: HOG2Archive
}

private func makePresentationMaterials(
    _ definitions: [RetailTextureDefinition],
    textureByName: [String: SourceResource],
    archives: [IndexedPreparedArchive]
) throws -> [PresentationMaterial] {
    let coronaNames = Set(definitions.compactMap { $0.lightCorona?.bitmapSourceName }).sorted()
    let coronaIndexByName = Dictionary(
        uniqueKeysWithValues: coronaNames.enumerated().map { ($0.element, $0.offset) }
    )
    return try definitions.map { definition throws -> PresentationMaterial in
        guard let indexed = archives.first(where: { archive in
            archive.archive.entry(named: definition.bitmapSourceName) != nil
        }), let entry = indexed.archive.entry(named: definition.bitmapSourceName),
              let texture = textureByName[definition.name.lowercased()] else {
            throw D3ImportOperationError.missingPresentationAsset(definition.bitmapSourceName)
        }
        let payload = indexed.validated.data.subdata(in: entry.payloadRange)
        let image = try decodeReachedOutrage16OGF(payload)
        return PresentationMaterial(
            texture: texture,
            bitmapSourceName: definition.bitmapSourceName,
            image: .init(width: image.width, height: image.height, rgba8: image.rgba8),
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
            sourceArchive: indexed.validated.file.relativePath,
            sourceSHA256: canonicalSHA256(payload)
        )
    }
}

private func makePresentationCoronaAssets(
    _ definitions: [RetailTextureDefinition],
    archives: [IndexedPreparedArchive]
) -> [PresentationCoronaAsset] {
    let names = Set(definitions.compactMap { $0.lightCorona?.bitmapSourceName }).sorted()
    return names.enumerated().map { index, name in
        let indexed = archives.first { archive in
            archive.archive.entry(named: name) != nil
        }!
        let entry = indexed.archive.uniqueEntry(named: name)
        let payload = indexed.validated.data.subdata(in: entry.payloadRange)
        let image = try! decodeReachedOutrage16OGF(payload)
        return PresentationCoronaAsset(
            source: .init(storedIndex: index, sourceName: name),
            bitmapSourceName: name,
            image: .init(width: image.width, height: image.height, rgba8: image.rgba8),
            sourceArchive: indexed.validated.file.relativePath,
            sourceSHA256: canonicalSHA256(payload)
        )
    }
}

private func archiveInventory(
    _ validated: ValidatedPreparedRetailFile,
    _ archive: HOG2Archive
) -> PreparedArchiveInventory {
    PreparedArchiveInventory(
        relativePath: validated.file.relativePath,
        byteCount: validated.file.byteCount,
        sha256: validated.file.sha256,
        entryCount: archive.entries.count
    )
}

func validateD3ImportPaths(_ arguments: D3ImportArguments) throws {
    let source = arguments.source.resolvingSymlinksInPath().standardizedFileURL
    let staging = arguments.staging.resolvingSymlinksInPath().standardizedFileURL
    let destination = arguments.destination.resolvingSymlinksInPath().standardizedFileURL
    let report = arguments.report.resolvingSymlinksInPath().standardizedFileURL

    try requireSourceDirectory(arguments.source)
    try requireOutputDirectory(arguments.staging.deletingLastPathComponent())
    try requireOutputDirectory(arguments.destination.deletingLastPathComponent())
    try requireOutputDirectory(arguments.report.deletingLastPathComponent())

    guard !pathsAreEquivalent(staging, destination),
          pathsAreEquivalent(
              staging.deletingLastPathComponent(),
              destination.deletingLastPathComponent()
          ) else {
        throw D3ImportOperationError.stagingIsNotDestinationAdjacent
    }

    let packagePaths = [staging, destination]
    guard pathsAreEquivalent(
        report.deletingLastPathComponent(),
        destination.deletingLastPathComponent()
    ) else {
        throw D3ImportOperationError.invalidOutputPath
    }
    guard packagePaths.allSatisfy({ pathIsDisjoint($0, source) }),
          packagePaths.allSatisfy({ pathIsDisjoint($0, report) }) else {
        throw D3ImportOperationError.overlappingPaths
    }

    if FileManager.default.fileExists(atPath: arguments.report.path) {
        let values = try arguments.report.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw D3ImportOperationError.invalidOutputPath
        }
    }
}

struct ValidatedPreparedRetailFile: Equatable, Sendable {
    let file: PreparedRetailFile
    let data: Data
}

func readValidatedPreparedRetailFile(
    _ file: PreparedRetailFile,
    at sourceURL: URL
) throws -> ValidatedPreparedRetailFile {
    try requireSourceDirectory(sourceURL)
    let components = file.relativePath.split(separator: "/", omittingEmptySubsequences: false)
    precondition(components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }))
    let fileName = components.last!

    let sourceRoot = sourceURL.resolvingSymlinksInPath().standardizedFileURL
    var parent = sourceRoot
    for component in components.dropLast() {
        parent.append(path: String(component), directoryHint: .isDirectory)
        let values = try parent.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw D3ImportOperationError.invalidPreparedFile(file.relativePath)
        }
    }
    let url = parent.appending(path: String(fileName))
    let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
    guard descriptor >= 0 else {
        throw D3ImportOperationError.invalidPreparedFile(file.relativePath)
    }
    let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)

    var status = stat()
    guard fstat(descriptor, &status) == 0,
          status.st_mode & S_IFMT == S_IFREG else {
        throw D3ImportOperationError.invalidPreparedFile(file.relativePath)
    }
    guard status.st_size == file.byteCount else {
        throw D3ImportOperationError.preparedFileSizeMismatch(file.relativePath)
    }
    let data = try handle.readToEnd() ?? Data()
    guard data.count == file.byteCount else {
        throw D3ImportOperationError.preparedFileSizeMismatch(file.relativePath)
    }
    guard canonicalSHA256(data) == file.sha256 else {
        throw D3ImportOperationError.preparedFileDigestMismatch(file.relativePath)
    }
    return ValidatedPreparedRetailFile(file: file, data: data)
}

func promoteCanonicalPackage(
    from stagingURL: URL,
    to destinationURL: URL,
    reportData: Data,
    reportURL: URL,
    cancellationCheck: D3ImportCancellationCheck
) throws {
    let packageDirectory = open(
        stagingURL.deletingLastPathComponent().path,
        O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
    )
    guard packageDirectory >= 0 else {
        throw D3ImportOperationError.invalidOutputDirectory
    }
    defer { close(packageDirectory) }
    guard flock(packageDirectory, LOCK_EX) == 0 else {
        throw D3ImportOperationError.promotionLockFailed(errno)
    }
    try throwIfD3ImportCancelled(cancellationCheck)

    let hadDestination = FileManager.default.fileExists(atPath: destinationURL.path)
    if hadDestination {
        _ = try loadCanonicalLevel(from: destinationURL)
    }

    let hadReport = FileManager.default.fileExists(atPath: reportURL.path)
    let reportCandidate = reportURL.deletingLastPathComponent().appending(
        path: ".\(reportURL.lastPathComponent).\(UUID().uuidString).candidate"
    )
    try reportData.write(to: reportCandidate)

    let reportFlags = hadReport
        ? UInt32(RENAME_SWAP | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
        : UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
    if renameatx_np(
        packageDirectory,
        reportCandidate.lastPathComponent,
        packageDirectory,
        reportURL.lastPathComponent,
        reportFlags
    ) != 0 {
        removePromotionArtifact(reportCandidate)
        throw D3ImportOperationError.reportPromotionFailed
    }

    do {
        try throwIfD3ImportCancelled(cancellationCheck)
        let packageFlags = hadDestination
            ? UInt32(RENAME_SWAP | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
            : UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
        guard renameatx_np(
            packageDirectory,
            stagingURL.lastPathComponent,
            packageDirectory,
            destinationURL.lastPathComponent,
            packageFlags
        ) == 0 else {
            throw D3ImportOperationError.packagePromotionFailed
        }
    } catch {
        let rollbackSource = hadReport ? reportCandidate.lastPathComponent : reportURL.lastPathComponent
        let rollbackTarget = hadReport ? reportURL.lastPathComponent : reportCandidate.lastPathComponent
        let rollbackFlags = hadReport
            ? UInt32(RENAME_SWAP | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
            : UInt32(RENAME_EXCL | RENAME_NOFOLLOW_ANY | RENAME_RESOLVE_BENEATH)
        guard renameatx_np(
            packageDirectory,
            rollbackSource,
            packageDirectory,
            rollbackTarget,
            rollbackFlags
        ) == 0 else {
            throw D3ImportOperationError.reportRollbackFailed(errno)
        }
        removePromotionArtifact(reportCandidate)
        throw error
    }

    if hadDestination { removePromotionArtifact(stagingURL) }
    if hadReport { removePromotionArtifact(reportCandidate) }
}

private func throwIfD3ImportCancelled(_ check: D3ImportCancellationCheck) throws {
    if let signal = check() {
        throw D3ImportOperationError.cancelled(signal)
    }
}

private func removePromotionArtifact(_ url: URL) {
    do {
        try FileManager.default.removeItem(at: url)
    } catch {
        fputs(
            "D3Import: warning: retained promotion artifact \(url.lastPathComponent): \(error)\n",
            stderr
        )
    }
}

struct D3ImportArguments: Equatable, Sendable {
    let contract: Int
    let source: URL
    let staging: URL
    let destination: URL
    let scope: String
    let report: URL

    static func parse(_ arguments: [String]) throws -> D3ImportArguments {
        let allowedFlags = Set([
            "--contract", "--source", "--staging", "--destination", "--scope", "--report",
        ])
        guard arguments.count == 13 else { throw D3ImportOperationError.invalidArguments }

        var values: [String: String] = [:]
        for index in stride(from: 1, to: arguments.count, by: 2) {
            let flag = arguments[index]
            guard allowedFlags.contains(flag), values[flag] == nil else {
                throw D3ImportOperationError.invalidArguments
            }
            values[flag] = arguments[index + 1]
        }
        guard values.count == allowedFlags.count,
              let contractText = values["--contract"],
              let contract = Int(contractText),
              contract == 1,
              let source = values["--source"], !source.isEmpty,
              let staging = values["--staging"], !staging.isEmpty,
              let destination = values["--destination"], !destination.isEmpty,
              let scope = values["--scope"],
              [
                  "descent3.level.training-mission",
                  "descent3.mission.pilot-training",
              ].contains(scope),
              let report = values["--report"], !report.isEmpty else {
            throw D3ImportOperationError.invalidArguments
        }

        return D3ImportArguments(
            contract: contract,
            source: URL(fileURLWithPath: source).standardizedFileURL,
            staging: URL(fileURLWithPath: staging).standardizedFileURL,
            destination: URL(fileURLWithPath: destination).standardizedFileURL,
            scope: scope,
            report: URL(fileURLWithPath: report).standardizedFileURL
        )
    }
}

enum D3ImportOperationError: Error, Equatable {
    case invalidArguments
    case invalidSourceDirectory
    case invalidPreparedFile(String)
    case preparedFileSizeMismatch(String)
    case preparedFileDigestMismatch(String)
    case missingPresentationAsset(String)
    case stagingIsNotDestinationAdjacent
    case overlappingPaths
    case invalidOutputDirectory
    case invalidOutputPath
    case cancelled(Int32)
    case packagePromotionFailed
    case reportPromotionFailed
    case reportRollbackFailed(Int32)
    case promotionLockFailed(Int32)
}

private func requireOutputDirectory(_ url: URL) throws {
    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true else {
        throw D3ImportOperationError.invalidOutputDirectory
    }
}

private func requireSourceDirectory(_ url: URL) throws {
    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true else {
        throw D3ImportOperationError.invalidSourceDirectory
    }
}

private func pathIsDisjoint(_ first: URL, _ second: URL) -> Bool {
    !pathIsAncestorOrEqual(first, second) && !pathIsAncestorOrEqual(second, first)
}

private func pathIsAncestorOrEqual(_ ancestor: URL, _ descendant: URL) -> Bool {
    let ancestorComponents = ancestor.pathComponents
    let descendantComponents = descendant.pathComponents
    guard ancestorComponents.count <= descendantComponents.count else { return false }
    return zip(ancestorComponents, descendantComponents).allSatisfy {
        $0.caseInsensitiveCompare($1) == .orderedSame
    }
}

private func pathsAreEquivalent(_ first: URL, _ second: URL) -> Bool {
    let firstComponents = first.pathComponents
    let secondComponents = second.pathComponents
    guard firstComponents.count == secondComponents.count else { return false }
    return zip(firstComponents, secondComponents).allSatisfy {
        $0.caseInsensitiveCompare($1) == .orderedSame
    }
}
