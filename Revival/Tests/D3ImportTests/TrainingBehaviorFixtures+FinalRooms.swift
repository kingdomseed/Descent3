import XCTest

func makeTrainingRASBot1DeathLevel() -> Level {
    var level = makeTrainingKillbotEntryLevel()
    let chain = level.trainingRobotGuidebotChain!
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    let robotModel = level.objectPresentations.first {
        $0.objectHandle == chain.destroyRobotObjectHandle
    }!.primaryModel
    let robotPosition = Vector3(
        x: player.position.x + player.orientation.forward.x * 20,
        y: player.position.y + player.orientation.forward.y * 20,
        z: player.position.z + player.orientation.forward.z * 20
    )
    level.objects.append(.init(
        handle: 2_074,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "RASBot1",
        flags: 5_121,
        doorShields: nil,
        location: player.location,
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_074,
        primaryModel: robotModel,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil
    ))
    return rescriptedTrainingLevel(
        level.addingTrainingRASBot1DeathChain(.init(
            robotObjectHandle: 2_074,
            robotRoomSourceIndex: {
                guard case let .room(roomSourceIndex) = player.location else {
                    preconditionFailure("Synthetic Training player is indoor")
                }
                return roomSourceIndex
            }(),
            robotFlags: 5_121,
            combat: .stockTraining
        ))
    )
}

func makeTrainingRASBot2DeathLevel() -> Level {
    var level = makeTrainingRASBot1DeathLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let rasBot1Index = level.objects.firstIndex { $0.handle == 2_074 }!
    level.objects[rasBot1Index].position = .init(
        x: player.position.x + player.orientation.right.x * 20,
        y: player.position.y + player.orientation.right.y * 20,
        z: player.position.z + player.orientation.right.z * 20
    )
    let robotModel = level.objectPresentations.first {
        $0.objectHandle == 2_074
    }!.primaryModel
    let robotPosition = Vector3(
        x: player.position.x + player.orientation.forward.x * 20,
        y: player.position.y + player.orientation.forward.y * 20,
        z: player.position.z + player.orientation.forward.z * 20
    )
    level.objects.append(.init(
        handle: 2_075,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "RASBot2",
        flags: 5_121,
        doorShields: nil,
        location: player.location,
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_075,
        primaryModel: robotModel,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil
    ))
    return rescriptedTrainingLevel(
        level.addingTrainingRASBot2DeathChain(.init(
            robotObjectHandle: 2_075,
            robotRoomSourceIndex: {
                guard case let .room(roomSourceIndex) = player.location else {
                    preconditionFailure("Synthetic Training player is indoor")
                }
                return roomSourceIndex
            }(),
            robotFlags: 5_121,
            combat: .stockTraining
        ))
    )
}

func makeTrainingRASBot3DeathLevel() -> Level {
    var level = makeTrainingRASBot2DeathLevel()
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    guard case let .room(playerRoomSourceIndex) = player.location,
          let playerRoom = level.rooms.first(where: {
              $0.sourceIndex == playerRoomSourceIndex
          }) else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    if !level.rooms.contains(where: { $0.sourceIndex == 42 }) {
        level.rooms.append(.init(
            sourceIndex: 42,
            name: "RASBot3 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let rasBot2Index = level.objects.firstIndex { $0.handle == 2_075 }!
    level.objects[rasBot2Index].position = .init(
        x: player.position.x - player.orientation.right.x * 20,
        y: player.position.y - player.orientation.right.y * 20,
        z: player.position.z - player.orientation.right.z * 20
    )
    let robotModel = level.objectPresentations.first {
        $0.objectHandle == 2_075
    }!.primaryModel
    let robotPosition = Vector3(
        x: player.position.x + player.orientation.forward.x * 20,
        y: player.position.y + player.orientation.forward.y * 20,
        z: player.position.z + player.orientation.forward.z * 20
    )
    level.objects.append(.init(
        handle: 2_077,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "RASBot3",
        flags: 5_121,
        doorShields: nil,
        location: .room(42),
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_077,
        primaryModel: robotModel,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil
    ))
    return rescriptedTrainingLevel(
        level.addingTrainingRASBot3DeathChain(.init(
            robotObjectHandle: 2_077,
            robotRoomSourceIndex: 42,
            robotFlags: 5_121,
            combat: .stockTraining
        ))
    )
}

func makeTrainingRASBot4DeathLevel() -> Level {
    var level = makeTrainingRASBot3DeathLevel()
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    guard case let .room(playerRoomSourceIndex) = player.location,
          let playerRoom = level.rooms.first(where: {
              $0.sourceIndex == playerRoomSourceIndex
          }) else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    if !level.rooms.contains(where: { $0.sourceIndex == 0 }) {
        level.rooms.append(.init(
            sourceIndex: 0,
            name: "RASBot4 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let robotModel = level.objectPresentations.first {
        $0.objectHandle == 2_077
    }!.primaryModel
    let robotPosition = Vector3(
        x: player.position.x + player.orientation.forward.x * 20,
        y: player.position.y + player.orientation.forward.y * 20,
        z: player.position.z + player.orientation.forward.z * 20
    )
    level.objects.append(.init(
        handle: 2_078,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "RASBot4",
        flags: 5_121,
        doorShields: nil,
        location: .room(0),
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_078,
        primaryModel: robotModel,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil
    ))
    return rescriptedTrainingLevel(
        level.addingTrainingRASBot4DeathChain(.init(
            robotObjectHandle: 2_078,
            robotRoomSourceIndex: 0,
            robotFlags: 5_121,
            combat: .stockTraining
        ))
    )
}

func makeTrainingInvulnerabilityPickupLevel() -> Level {
    var level = makeTrainingRASBot4DeathLevel()
    let playerIndex = level.objects.firstIndex {
        $0.handle == 2_048
    }!
    let originalPlayer = level.objects[playerIndex]
    let originalRoomSourceIndex: Int
    if case .room(let sourceIndex) = originalPlayer.location {
        originalRoomSourceIndex = sourceIndex
    } else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    let originalRoom = level.rooms.first {
        $0.sourceIndex == originalRoomSourceIndex
    }!
    level.rooms.append(
        .init(
            sourceIndex: 12,
            name: "Invuln Room",
            pathPoint: originalRoom.pathPoint,
            vertices: originalRoom.vertices,
            faces: originalRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: originalRoom.flags,
            pulseTime: originalRoom.pulseTime,
            pulseOffset: originalRoom.pulseOffset,
            mirrorFaceIndex: originalRoom.mirrorFaceIndex,
            door: originalRoom.door,
            volumeLights: originalRoom.volumeLights,
            fog: originalRoom.fog,
            ambientSoundPattern: originalRoom.ambientSoundPattern,
            reverb: originalRoom.reverb,
            damage: originalRoom.damage,
            damageType: originalRoom.damageType
        ))
    let pickupRoom = level.rooms.last!
    let player = level.objects[playerIndex]
    let presentation = level.objectPresentations.first {
        $0.objectHandle == 2_078
    }!
    let model = level.models.first {
        $0.source == presentation.primaryModel
    }!
    level.objects.append(
        .init(
            handle: 2_076,
            type: 7,
            storedID: 3,
            definition: .init(
                storedIndex: 3,
                sourceName: "Invulnerability"
            ),
            instanceName: "InvulnPowerup2",
            flags: 5_120,
            doorShields: nil,
            location: .room(12),
            position: pickupRoom.pathPoint,
            orientation: player.orientation,
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        ))
    level.objectPresentations.append(
        .init(
            objectHandle: 2_076,
            primaryModel: model.source,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        ))
    let template = level.soundClips.first!
    let pickup = CanonicalSoundClip(
        logicalName: "Powerup pickup",
        sourceName: "Power03.wav",
        sourceEntryIndex: 499,
        sampleRate: template.sampleRate,
        channelCount: template.channelCount,
        frameCount: template.frameCount,
        pcm16LittleEndian: template.pcm16LittleEndian,
        pcmSHA256: template.pcmSHA256,
        sourceArchive: template.sourceArchive,
        sourceSHA256: template.sourceSHA256,
        importVolume: 1
    )
    let activated = CanonicalSoundClip(
        logicalName: "Invulnerability on",
        sourceName: "Invon.wav",
        sourceEntryIndex: 500,
        sampleRate: template.sampleRate,
        channelCount: template.channelCount,
        frameCount: template.frameCount,
        pcm16LittleEndian: template.pcm16LittleEndian,
        pcmSHA256: template.pcmSHA256,
        sourceArchive: template.sourceArchive,
        sourceSHA256: template.sourceSHA256,
        importVolume: 0.5
    )
    let expired = CanonicalSoundClip(
        logicalName: "Invulnerability off",
        sourceName: "Invoff.wav",
        sourceEntryIndex: 501,
        sampleRate: template.sampleRate,
        channelCount: template.channelCount,
        frameCount: template.frameCount,
        pcm16LittleEndian: template.pcm16LittleEndian,
        pcmSHA256: template.pcmSHA256,
        sourceArchive: template.sourceArchive,
        sourceSHA256: template.sourceSHA256,
        importVolume: 0.5
    )
    return rescriptedTrainingLevel(
        level.addingTrainingInvulnerabilityPickupChain(
            .init(
                pickupObjectHandle: 2_076,
                pickupRoomSourceIndex: 12,
                pickupObjectFlags: 5_120,
                pickupCollisionRadius: model.collisionRadius,
                duration: 30,
                activatedMessage: "Invulnerability On",
                expiredMessage: "Invulnerability Off",
                pickupSoundSourceName: "Power03.wav",
                activatedSoundSourceName: "Invon.wav",
                expiredSoundSourceName: "Invoff.wav"
            ),
            soundClips: [pickup, activated, expired]
        )
    )
}

func makeTrainingCloakPickupLevel() -> Level {
    var level = makeTrainingInvulnerabilityPickupLevel()
    if !level.rooms.contains(where: { $0.sourceIndex == 11 }) {
        let template = level.rooms.first { $0.sourceIndex == 12 }!
        level.rooms.append(.init(
            sourceIndex: 11,
            name: "Cloak Room",
            pathPoint: template.pathPoint,
            vertices: template.vertices,
            faces: template.faces,
            portals: [],
            flags: template.flags,
            pulseTime: template.pulseTime,
            pulseOffset: template.pulseOffset,
            mirrorFaceIndex: template.mirrorFaceIndex,
            door: template.door,
            volumeLights: template.volumeLights,
            fog: template.fog,
            ambientSoundPattern: template.ambientSoundPattern,
            reverb: template.reverb,
            damage: template.damage,
            damageType: template.damageType
        ))
    }
    let pickupRoom = level.rooms.first { $0.sourceIndex == 11 }!
    let player = level.objects.first { $0.handle == 2_048 }!
    let presentation = level.objectPresentations.first {
        $0.objectHandle == 2_076
    }!
    let modelTemplate = level.models.first {
        $0.source == presentation.primaryModel
    }!
    let cloakModelSources = [
        SourceResource(storedIndex: 20, sourceName: "cloak.OOF"),
        SourceResource(storedIndex: 21, sourceName: "CloakMed.OOF"),
        SourceResource(storedIndex: 22, sourceName: "CloakLow.OOF"),
    ]
    let cloakModelHashes = [
        "ccce90c9dbc266c0a22ab00339689059888719b212116191049ef4396ebc5baa",
        "7b6e66b1ad23328b43dc007de7cb2b8806397f69bab95647e350554f479e0c6b",
        "38754663d76df10a7d6d41e241cfe2fc08b9f7fb99addb41cb5ed1fc205f119f",
    ]
    let cloakModels = zip(cloakModelSources, cloakModelHashes).map {
        source, hash in
        CanonicalModel(
            source: source,
            collisionRadius:
                source == cloakModelSources[0]
                    ? 1.223_636_7
                    : modelTemplate.collisionRadius,
            submodels: modelTemplate.submodels,
            bounds: modelTemplate.bounds,
            sourceArchive: "d3.hog",
            sourceSHA256: hash
        )
    }
    level = replacing(
        level,
        source: replacing(
            level.source,
            profileFiles:
                level.source.profileFiles
                + [
                    .init(
                        relativePath: "d3.hog",
                        byteCount: 194_030_423,
                        sha256:
                            "a0f1cb2c1a73da828a5fd4e80d6544b63da04e177dc2b894d9e6418296bc24c6"
                    )
                ]
        ),
        models: level.models + cloakModels,
        dependencyManifest: .init(
            current:
                level.dependencyManifest.current
                + cloakModelSources.map {
                    DependencyRecord(
                        category: "model",
                        source: $0,
                        state: "presentation-payload-imported",
                        provenance: "d3.hog"
                    )
                },
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    level.objects.append(.init(
        handle: 2_073,
        type: 7,
        storedID: 4,
        definition: .init(storedIndex: 4, sourceName: "Cloak"),
        instanceName: "CloakPowerup2",
        flags: 5_120,
        doorShields: nil,
        location: .room(11),
        position: pickupRoom.pathPoint,
        orientation: player.orientation,
        containsType: 255,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_073,
        primaryModel: cloakModelSources[0],
        mediumModel: cloakModelSources[1],
        lowModel: cloakModelSources[2],
        dyingModel: nil,
        mediumDistance: 35,
        lowDistance: 50
    ))
    let pickupPCM = Data(repeating: 0, count: 15_189 * 2)
    let pickup = CanonicalSoundClip(
        logicalName: "Powerup pickup",
        sourceName: "Power03.wav",
        sourceEntryIndex: 2_657,
        sampleRate: 22_050,
        channelCount: 1,
        frameCount: 15_189,
        pcm16LittleEndian: pickupPCM,
        pcmSHA256: canonicalSHA256(pickupPCM),
        sourceArchive: "d3.hog",
        sourceSHA256:
            "1e16aae37b233dd724d4baa001f48b83681fbc33eb16d21269cd52c5b7e8cea3",
        importVolume: 1
    )
    level = replacing(
        level,
        soundClips:
            level.soundClips.filter { $0.sourceName != "Power03.wav" }
            + [pickup],
        dependencyManifest: .init(
            current: level.dependencyManifest.current.filter {
                !(
                    $0.category == "sound"
                        && $0.source.sourceName == "Power03.wav"
                )
            } + [
                .init(
                    category: "sound",
                    source: .init(
                        storedIndex: pickup.sourceEntryIndex,
                        sourceName: pickup.sourceName
                    ),
                    state: "canonical-pcm-imported",
                    provenance:
                        "\(pickup.sourceArchive) \(pickup.sourceSHA256)"
                )
            ],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    let cloakOnPCM = Data(repeating: 0, count: 33_046 * 2)
    let cloakOn = CanonicalSoundClip(
        logicalName: "Cloak on",
        sourceName: "ShpCloakOn.wav",
        sourceEntryIndex: 3_247,
        sampleRate: 22_050,
        channelCount: 1,
        frameCount: 33_046,
        pcm16LittleEndian: cloakOnPCM,
        pcmSHA256: canonicalSHA256(cloakOnPCM),
        sourceArchive: "d3.hog",
        sourceSHA256:
            "27d19947e58370b18722fbcbe2fba64bf5094e3752a069bd1d2e1ed76e70c58e",
        importVolume: 0.5
    )
    let cloakOffPCM = Data(repeating: 0, count: 45_609 * 2)
    let cloakOff = CanonicalSoundClip(
        logicalName: "Cloak off",
        sourceName: "ShpCloakOffBeep.wav",
        sourceEntryIndex: 3_246,
        sampleRate: 22_050,
        channelCount: 1,
        frameCount: 45_609,
        pcm16LittleEndian: cloakOffPCM,
        pcmSHA256: canonicalSHA256(cloakOffPCM),
        sourceArchive: "d3.hog",
        sourceSHA256:
            "29c9bb2fe254a9c2e75b8ae0f13b60627088294f075fbd74eae449e76c767154",
        importVolume: 0.5
    )
    let cloakLevel = level.addingTrainingCloakPickupChain(
        .init(
            pickupObjectHandle: 2_073,
            pickupRoomSourceIndex: 11,
            pickupObjectFlags: 5_120,
            pickupCollisionRadius: cloakModels[0].collisionRadius,
            fadeDuration: 1,
            cloakDuration: 30,
            activatedMessage: "Cloak On",
            expiredMessage: "Cloak Off",
            pickupSoundSourceName: "Power03.wav",
            activatedSoundSourceName: "ShpCloakOn.wav",
            expiredSoundSourceName: "ShpCloakOffBeep.wav"
        ),
        soundClips: [cloakOn, cloakOff]
    )
    var lastRoomLevel = cloakLevel
    let lastRoomTemplate = lastRoomLevel.rooms.first {
        $0.sourceIndex == 2
    }!
    precondition(lastRoomTemplate.portals.count == 2)
    var lastRoomPortals: [LevelPortal] = []
    var connectedRooms: [LevelRoom] = []
    for portalIndex in lastRoomTemplate.portals.indices {
        let sourcePortal = lastRoomTemplate.portals[portalIndex]
        let sourceConnectedRoom = lastRoomLevel.rooms.first {
            $0.sourceIndex == sourcePortal.connectedRoom
        }!
        let sourceReciprocal =
            sourceConnectedRoom.portals[sourcePortal.connectedPortal]
        let connectedSourceIndex = portalIndex == 0 ? 41 : 45
        let connectedPortalIndex = portalIndex == 0 ? 3 : 0
        lastRoomPortals.append(.init(
            flags: 1,
            faceIndex: sourcePortal.faceIndex,
            connectedRoom: connectedSourceIndex,
            connectedPortal: connectedPortalIndex,
            boundaryNodeIndex: -1,
            pathPoint: sourcePortal.pathPoint,
            combineMaster: -1
        ))
        var connectedFaces = sourceConnectedRoom.faces.enumerated().map {
            faceIndex, face in
            LevelFace(
                corners: face.corners,
                flags: face.flags,
                portalIndex:
                    faceIndex == sourceReciprocal.faceIndex
                        ? connectedPortalIndex : nil,
                texture: face.texture,
                lightmapInfoIndex: face.lightmapInfoIndex,
                allowsLightCorona: face.allowsLightCorona,
                lightMultiple: face.lightMultiple,
                special: face.special
            )
        }
        var connectedPortals: [LevelPortal] = []
        if portalIndex == 0 {
            for auxiliaryPortalIndex in 0..<3 {
                let faceIndex = connectedFaces.count
                connectedFaces.append(.init(
                    corners: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].corners,
                    flags: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].flags,
                    portalIndex: auxiliaryPortalIndex,
                    texture: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].texture,
                    lightmapInfoIndex: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].lightmapInfoIndex,
                    allowsLightCorona: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].allowsLightCorona,
                    lightMultiple: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].lightMultiple,
                    special: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].special
                ))
                connectedPortals.append(.init(
                    flags: 1,
                    faceIndex: faceIndex,
                    connectedRoom: 60 + auxiliaryPortalIndex,
                    connectedPortal: 0,
                    boundaryNodeIndex: -1,
                    pathPoint: sourceReciprocal.pathPoint,
                    combineMaster: -1
                ))
                let auxiliaryFace = lastRoomTemplate.faces[
                    sourcePortal.faceIndex
                ]
                connectedRooms.append(.init(
                    sourceIndex: 60 + auxiliaryPortalIndex,
                    name: "P6 auxiliary \(auxiliaryPortalIndex)",
                    pathPoint: lastRoomTemplate.pathPoint,
                    vertices: lastRoomTemplate.vertices,
                    faces: [
                        .init(
                            corners: auxiliaryFace.corners,
                            flags: auxiliaryFace.flags,
                            portalIndex: 0,
                            texture: auxiliaryFace.texture,
                            lightmapInfoIndex:
                                auxiliaryFace.lightmapInfoIndex,
                            allowsLightCorona:
                                auxiliaryFace.allowsLightCorona,
                            lightMultiple: auxiliaryFace.lightMultiple,
                            special: auxiliaryFace.special
                        )
                    ],
                    portals: [
                        .init(
                            flags: 1,
                            faceIndex: 0,
                            connectedRoom: 41,
                            connectedPortal: auxiliaryPortalIndex,
                            boundaryNodeIndex: -1,
                            pathPoint: sourcePortal.pathPoint,
                            combineMaster: -1
                        )
                    ],
                    flags: lastRoomTemplate.flags,
                    pulseTime: lastRoomTemplate.pulseTime,
                    pulseOffset: lastRoomTemplate.pulseOffset,
                    mirrorFaceIndex: lastRoomTemplate.mirrorFaceIndex,
                    door: lastRoomTemplate.door,
                    volumeLights: lastRoomTemplate.volumeLights,
                    fog: lastRoomTemplate.fog,
                    ambientSoundPattern:
                        lastRoomTemplate.ambientSoundPattern,
                    reverb: lastRoomTemplate.reverb,
                    damage: lastRoomTemplate.damage,
                    damageType: lastRoomTemplate.damageType
                ))
            }
        }
        connectedPortals.append(.init(
            flags: 1,
            faceIndex: sourceReciprocal.faceIndex,
            connectedRoom: 44,
            connectedPortal: portalIndex,
            boundaryNodeIndex: -1,
            pathPoint: sourceReciprocal.pathPoint,
            combineMaster: -1
        ))
        connectedRooms.append(.init(
            sourceIndex: connectedSourceIndex,
            name: "P6 neighbor \(portalIndex)",
            pathPoint: sourceConnectedRoom.pathPoint,
            vertices: sourceConnectedRoom.vertices,
            faces: connectedFaces,
            portals: connectedPortals,
            flags: sourceConnectedRoom.flags,
            pulseTime: sourceConnectedRoom.pulseTime,
            pulseOffset: sourceConnectedRoom.pulseOffset,
            mirrorFaceIndex: sourceConnectedRoom.mirrorFaceIndex,
            door: sourceConnectedRoom.door,
            volumeLights: sourceConnectedRoom.volumeLights,
            fog: sourceConnectedRoom.fog,
            ambientSoundPattern:
                sourceConnectedRoom.ambientSoundPattern,
            reverb: sourceConnectedRoom.reverb,
            damage: sourceConnectedRoom.damage,
            damageType: sourceConnectedRoom.damageType
        ))
    }
    let lastRoom = LevelRoom(
        sourceIndex: 44,
        name: "PortalRoom6",
        pathPoint: lastRoomTemplate.pathPoint,
        vertices: lastRoomTemplate.vertices,
        faces: lastRoomTemplate.faces,
        portals: lastRoomPortals,
        flags: lastRoomTemplate.flags,
        pulseTime: lastRoomTemplate.pulseTime,
        pulseOffset: lastRoomTemplate.pulseOffset,
        mirrorFaceIndex: lastRoomTemplate.mirrorFaceIndex,
        door: lastRoomTemplate.door,
        volumeLights: lastRoomTemplate.volumeLights,
        fog: lastRoomTemplate.fog,
        ambientSoundPattern: lastRoomTemplate.ambientSoundPattern,
        reverb: lastRoomTemplate.reverb,
        damage: lastRoomTemplate.damage,
        damageType: lastRoomTemplate.damageType
    )
    lastRoomLevel.rooms.append(contentsOf: [lastRoom] + connectedRooms)
    lastRoomLevel.objects.append(.init(
        handle: 4_117,
        type: 11,
        storedID: 205,
        definition: .init(
            storedIndex: 205,
            sourceName: "Blinking Red Light-DM"
        ),
        instanceName: "FlashLight-4",
        flags: 4_096,
        doorShields: nil,
        location: .room(44),
        position: lastRoom.pathPoint,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    return rescriptedTrainingLevel(
        lastRoomLevel.addingTrainingLastRoomChain(.init(
            barrierRoomSourceIndex: 44,
            orderedPortalIndices: [1, 0],
            markerLightObjectHandle: 4_117,
            markerLightPresentation: .init(
                primaryColor: .init(x: 1, y: 0.25, z: 0),
                secondaryColor: .zero,
                timeInterval: 0.5,
                flickerDistance: 0.2,
                directionalDot: 0,
                flags: 4,
                timebits: .max,
                angle: 0,
                lightingRenderType: 2
            ),
            openMarkerLightDistance: 50,
            timerDuration: 2,
            completionMessages: [
                "Excellent!",
                "Now proceed through the doorway that just opened to begin the last stage of your training.",
            ],
            completionVoiceSourceName: "proceed5.osf"
        ))
    )
}

func makeTrainingFinalRoomEntryLevel() -> Level {
    let level = makeTrainingCloakPickupLevel()
    let chain = TrainingFinalRoomEntryChain(
        triggerName: "Portal4",
        triggerRoomSourceIndex: 44,
        triggerFaceIndex: 1,
        successMessage: "Excellent!",
        instructionMessage:
            "Now for your final and most difficult task. Locate and destroy the last 5 robots.",
        voiceSourceName: "intro7.osf"
    )
    let trigger = LevelTrigger(
        name: chain.triggerName,
        roomIndex: chain.triggerRoomSourceIndex,
        faceIndex: chain.triggerFaceIndex,
        flags: 8,
        activator: 1
    )
    let pcm = Data(repeating: 0, count: 2)
    return rescriptedTrainingLevel(
        replacing(
            level,
            triggers: level.triggers + [trigger]
        ).addingTrainingFinalRoomEntryChain(
            chain,
            voiceClip: .init(
                sourceName: chain.voiceSourceName,
                sourceEntryIndex: 16,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: pcm,
                pcmSHA256: canonicalSHA256(pcm),
                sourceArchive: "missions/training.mn3",
                sourceSHA256:
                    "7348ded9ee2c6735ea712b52647f0bfa7478a508c03c10af5f837741a836c67f"
            )
        )
    )
}

func makeTrainingLastBot1DeathLevel() -> Level {
    var level = makeTrainingFinalRoomEntryLevel()
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    guard case let .room(playerRoomSourceIndex) = player.location,
          let playerRoom = level.rooms.first(where: {
              $0.sourceIndex == playerRoomSourceIndex
          }) else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    if !level.rooms.contains(where: { $0.sourceIndex == 14 }) {
        level.rooms.append(.init(
            sourceIndex: 14,
            name: "LastBot1 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let robotModel = level.objectPresentations.first {
        $0.objectHandle == 2_078
    }!.primaryModel
    let robotPosition = Vector3(
        x: player.position.x
            + player.orientation.forward.x * 20,
        y: player.position.y
            + player.orientation.forward.y * 20,
        z: player.position.z
            + player.orientation.forward.z * 20
    )
    level.objects.append(.init(
        handle: 4_127,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "LastBot1",
        flags: 5_121,
        doorShields: nil,
        location: .room(14),
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 4_127,
        primaryModel: robotModel,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil
    ))
    return rescriptedTrainingLevel(
        level.addingTrainingLastBot1DeathChain(.init(
            robotObjectHandle: 4_127,
            robotRoomSourceIndex: 14,
            robotFlags: 5_121,
            combat: .stockTraining
        ))
    )
}

func makeTrainingLastBot2DeathLevel() -> Level {
    var level = makeTrainingLastBot1DeathLevel()
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    guard case let .room(playerRoomSourceIndex) = player.location,
          let playerRoom = level.rooms.first(where: {
              $0.sourceIndex == playerRoomSourceIndex
          }) else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    if !level.rooms.contains(where: { $0.sourceIndex == 46 }) {
        level.rooms.append(.init(
            sourceIndex: 46,
            name: "LastBot2 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let lastBot1Presentation = level.objectPresentations.first {
        $0.objectHandle == 4_127
    }!
    let robotPosition = Vector3(
        x: player.position.x
            + player.orientation.forward.x * 30,
        y: player.position.y
            + player.orientation.forward.y * 30,
        z: player.position.z
            + player.orientation.forward.z * 30
    )
    level.objects.append(.init(
        handle: 2_080,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "LastBot2",
        flags: 5_121,
        doorShields: nil,
        location: .room(46),
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_080,
        primaryModel: lastBot1Presentation.primaryModel,
        mediumModel: lastBot1Presentation.mediumModel,
        lowModel: lastBot1Presentation.lowModel,
        dyingModel: lastBot1Presentation.dyingModel,
        mediumDistance: lastBot1Presentation.mediumDistance,
        lowDistance: lastBot1Presentation.lowDistance
    ))
    return rescriptedTrainingLevel(
        level.addingTrainingLastBot2DeathChain(.init(
            robotObjectHandle: 2_080,
            robotRoomSourceIndex: 46,
            robotFlags: 5_121,
            combat: .stockTraining
        ))
    )
}

func makeTrainingLastBot3DeathLevel() -> Level {
    var level = makeTrainingLastBot2DeathLevel()
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    guard case let .room(playerRoomSourceIndex) = player.location,
          let playerRoom = level.rooms.first(where: {
              $0.sourceIndex == playerRoomSourceIndex
          }) else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    if !level.rooms.contains(where: { $0.sourceIndex == 47 }) {
        level.rooms.append(.init(
            sourceIndex: 47,
            name: "LastBot3 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let lastBot2Presentation = level.objectPresentations.first {
        $0.objectHandle == 2_080
    }!
    let robotPosition = Vector3(
        x: player.position.x
            + player.orientation.forward.x * 30,
        y: player.position.y
            + player.orientation.forward.y * 30,
        z: player.position.z
            + player.orientation.forward.z * 30
    )
    level.objects.append(.init(
        handle: 2_081,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "LastBot3",
        flags: 5_121,
        doorShields: nil,
        location: .room(47),
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_081,
        primaryModel: lastBot2Presentation.primaryModel,
        mediumModel: lastBot2Presentation.mediumModel,
        lowModel: lastBot2Presentation.lowModel,
        dyingModel: lastBot2Presentation.dyingModel,
        mediumDistance: lastBot2Presentation.mediumDistance,
        lowDistance: lastBot2Presentation.lowDistance
    ))
    return rescriptedTrainingLevel(
        level.addingTrainingLastBot3DeathChain(.init(
            robotObjectHandle: 2_081,
            robotRoomSourceIndex: 47,
            robotFlags: 5_121,
            combat: .stockTraining
        ))
    )
}

func makeTrainingLastBot4DeathLevel() -> Level {
    var level = makeTrainingLastBot3DeathLevel()
    let lastBot3 = level.objects.first { $0.handle == 2_081 }!
    let lastBot3Presentation = level.objectPresentations.first {
        $0.objectHandle == 2_081
    }!
    level.objects.append(.init(
        handle: 2_082,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "LastBot4",
        flags: 5_121,
        doorShields: nil,
        location: .room(47),
        position: lastBot3.position,
        orientation: lastBot3.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_082,
        primaryModel: lastBot3Presentation.primaryModel,
        mediumModel: lastBot3Presentation.mediumModel,
        lowModel: lastBot3Presentation.lowModel,
        dyingModel: lastBot3Presentation.dyingModel,
        mediumDistance: lastBot3Presentation.mediumDistance,
        lowDistance: lastBot3Presentation.lowDistance
    ))
    return rescriptedTrainingLevel(
        level.addingTrainingLastBot4DeathChain(.init(
            robotObjectHandle: 2_082,
            robotRoomSourceIndex: 47,
            robotFlags: 5_121,
            combat: .stockTraining
        ))
    )
}

func makeTrainingLastBot5DeathLevel() -> Level {
    var level = makeTrainingLastBot4DeathLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let playerRoomSourceIndex: Int
    switch player.location {
    case let .room(sourceIndex):
        playerRoomSourceIndex = sourceIndex
    case .terrainCell:
        preconditionFailure("Synthetic Training player is indoor")
    }
    let playerRoom = level.rooms.first {
        $0.sourceIndex == playerRoomSourceIndex
    }!
    if !level.rooms.contains(where: { $0.sourceIndex == 48 }) {
        level.rooms.append(.init(
            sourceIndex: 48,
            name: "LastBot5 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let lastBot4 = level.objects.first { $0.handle == 2_082 }!
    let lastBot4Presentation = level.objectPresentations.first {
        $0.objectHandle == 2_082
    }!
    level.objects.append(.init(
        handle: 2_083,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "LastBot5",
        flags: 5_121,
        doorShields: nil,
        location: .room(48),
        position: lastBot4.position,
        orientation: lastBot4.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_083,
        primaryModel: lastBot4Presentation.primaryModel,
        mediumModel: lastBot4Presentation.mediumModel,
        lowModel: lastBot4Presentation.lowModel,
        dyingModel: lastBot4Presentation.dyingModel,
        mediumDistance: lastBot4Presentation.mediumDistance,
        lowDistance: lastBot4Presentation.lowDistance
    ))
    return rescriptedTrainingLevel(
        level.addingTrainingLastBot5DeathChain(.init(
            robotObjectHandle: 2_083,
            robotRoomSourceIndex: 48,
            robotFlags: 5_121,
            combat: .stockTraining
        ))
    )
}

func makeTrainingFinalBotsCompletionLevel() -> Level {
    var level = makeTrainingLastBot5DeathLevel()
    let template = level.rooms.first {
        $0.sourceIndex == 2
    }!
    precondition(template.portals.count == 2)
    var barrierPortals: [LevelPortal] = []
    var connectedRooms: [LevelRoom] = []
    for portalIndex in template.portals.indices {
        let sourcePortal = template.portals[portalIndex]
        let sourceConnectedRoom = level.rooms.first {
            $0.sourceIndex == sourcePortal.connectedRoom
        }!
        let reciprocal =
            sourceConnectedRoom.portals[sourcePortal.connectedPortal]
        let connectedSourceIndex = 70 + portalIndex
        barrierPortals.append(.init(
            flags: 1,
            faceIndex: sourcePortal.faceIndex,
            connectedRoom: connectedSourceIndex,
            connectedPortal: 0,
            boundaryNodeIndex: -1,
            pathPoint: sourcePortal.pathPoint,
            combineMaster: -1
        ))
        connectedRooms.append(.init(
            sourceIndex: connectedSourceIndex,
            name: "P7 neighbor \(portalIndex)",
            pathPoint: sourceConnectedRoom.pathPoint,
            vertices: sourceConnectedRoom.vertices,
            faces: sourceConnectedRoom.faces.enumerated().map {
                faceIndex, face in
                .init(
                    corners: face.corners,
                    flags: face.flags,
                    portalIndex:
                        faceIndex == reciprocal.faceIndex ? 0 : nil,
                    texture: face.texture,
                    lightmapInfoIndex: face.lightmapInfoIndex,
                    allowsLightCorona: face.allowsLightCorona,
                    lightMultiple: face.lightMultiple,
                    special: face.special
                )
            },
            portals: [
                .init(
                    flags: 1,
                    faceIndex: reciprocal.faceIndex,
                    connectedRoom: 16,
                    connectedPortal: portalIndex,
                    boundaryNodeIndex: -1,
                    pathPoint: reciprocal.pathPoint,
                    combineMaster: -1
                )
            ],
            flags: sourceConnectedRoom.flags,
            pulseTime: sourceConnectedRoom.pulseTime,
            pulseOffset: sourceConnectedRoom.pulseOffset,
            mirrorFaceIndex: sourceConnectedRoom.mirrorFaceIndex,
            door: sourceConnectedRoom.door,
            volumeLights: sourceConnectedRoom.volumeLights,
            fog: sourceConnectedRoom.fog,
            ambientSoundPattern:
                sourceConnectedRoom.ambientSoundPattern,
            reverb: sourceConnectedRoom.reverb,
            damage: sourceConnectedRoom.damage,
            damageType: sourceConnectedRoom.damageType
        ))
    }
    let barrier = LevelRoom(
        sourceIndex: 16,
        name: "PortalRoom7",
        pathPoint: template.pathPoint,
        vertices: template.vertices,
        faces: template.faces,
        portals: barrierPortals,
        flags: template.flags,
        pulseTime: template.pulseTime,
        pulseOffset: template.pulseOffset,
        mirrorFaceIndex: template.mirrorFaceIndex,
        door: template.door,
        volumeLights: template.volumeLights,
        fog: template.fog,
        ambientSoundPattern: template.ambientSoundPattern,
        reverb: template.reverb,
        damage: template.damage,
        damageType: template.damageType
    )
    level.rooms.append(contentsOf: [barrier] + connectedRooms)
    let player = level.objects.first {
        $0.handle == 2_048
    }!
    level.objects.append(.init(
        handle: 4_118,
        type: 11,
        storedID: 205,
        definition: .init(
            storedIndex: 205,
            sourceName: "Blinking Red Light-DM"
        ),
        instanceName: "FlashLight-5",
        flags: 4_096,
        doorShields: nil,
        location: .room(16),
        position: barrier.pathPoint,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    let chain = TrainingFinalBotsCompletionChain(
        barrierRoomSourceIndex: 16,
        orderedPortalIndices: [0, 1],
        markerLightObjectHandle: 4_118,
        markerLightPresentation: .init(
            primaryColor: .init(x: 1, y: 0.25, z: 0),
            secondaryColor: .zero,
            timeInterval: 0.5,
            flickerDistance: 0.2,
            directionalDot: 0,
            flags: 4,
            timebits: .max,
            angle: 0,
            lightingRenderType: 2
        ),
        openMarkerLightDistance: 50,
        timerDuration: 2,
        completionMessage:
            "Great Job! Now fly through the opened doorway to end your training. Good job Recruit!",
        completionVoiceSourceName: "done.osf"
    )
    let pcm = Data(repeating: 0, count: 2)
    return rescriptedTrainingLevel(
        level.addingTrainingFinalBotsCompletionChain(
            chain,
            voiceClip: .init(
                sourceName: chain.completionVoiceSourceName,
                sourceEntryIndex: 9,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: pcm,
                pcmSHA256: canonicalSHA256(pcm),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: canonicalSHA256(pcm)
            )
        )
    )
}

func makeTrainingFinalGoalLevel() -> Level {
    var level = makeTrainingFinalBotsCompletionLevel()
    let roomTemplate = level.rooms.first {
        $0.sourceIndex == 1
    }!
    let player = level.objects.first { $0.handle == 2_048 }!
    let room = makeSourceContainmentRoom(
        center: player.position,
        texture: roomTemplate.faces[0].texture,
        sourceIndex: 17,
        halfExtent: 100
    )
    level.rooms.removeAll { $0.sourceIndex == 17 }
    level.rooms.append(room)
    let goal = PlacedObject(
        handle: 6_180,
        type: 7,
        storedID: 67,
        definition: .init(
            storedIndex: 67,
            sourceName: "Invisiblepowerup"
        ),
        instanceName: "FinalGoal",
        flags: 4_096,
        doorShields: nil,
        location: .room(17),
        position: player.position,
        orientation: .init(
            right: .init(x: -1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: -1)
        ),
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    )
    level.objects.append(goal)
    let modelSource = SourceResource(
        storedIndex: 4,
        sourceName: "invisiblepowerup.OOF"
    )
    level.objectPresentations.append(.init(
        objectHandle: goal.handle,
        primaryModel: modelSource,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil,
        isVisible: false
    ))
    var models = level.models
    if let modelIndex = models.firstIndex(where: {
        $0.source == modelSource
    }) {
        let model = models[modelIndex]
        models[modelIndex] = CanonicalModel(
            source: model.source,
            collisionRadius: Float(bitPattern: 0x40a0_84bf),
            submodels: model.submodels,
            bounds: model.bounds,
            sourceArchive: model.sourceArchive,
            sourceSHA256: model.sourceSHA256
        )
    }
    level = replacing(
        level,
        metadata: .init(
            name: "Training Mission",
            designer: level.metadata.designer,
            copyright: level.metadata.copyright,
            notes: level.metadata.notes,
            gravity: level.metadata.gravity,
            alwaysCheckCeiling: level.metadata.alwaysCheckCeiling,
            ceilingHeight: level.metadata.ceilingHeight
        ),
        models: models
    )
    return rescriptedTrainingLevel(
        level.addingTrainingFinalGoalChain(.init(
            goalObjectHandle: goal.handle,
            goalRoomSourceIndex: 17,
            goalObjectFlags: goal.flags,
            goalCollisionRadius: Float(bitPattern: 0x40a0_84bf)
        ))
    )
}
