import XCTest

// The Training fixtures of the late lessons: the RAS and last robots, the
// two pickups, the last room, and the final goal.

extension Level {
    /// The Training fixtures' player (handle 2048).
    fileprivate var trainingPlayer: PlacedObject {
        objects.first { $0.handle == 2_048 }!
    }

    fileprivate mutating func moveObject(_ handle: UInt32, to position: Vector3) {
        objects[objects.firstIndex { $0.handle == handle }!].position = position
    }

    /// A copy of the player's room with no portals or lightmaps as room
    /// `sourceIndex`, unless the level has that room.
    fileprivate mutating func addClosedCopyOfPlayerRoom(
        _ sourceIndex: Int, _ name: String
    ) {
        guard case let .room(playerRoom) = trainingPlayer.location,
              let room = rooms.first(where: { $0.sourceIndex == playerRoom })
        else {
            preconditionFailure("Synthetic Training player is indoor")
        }
        guard !rooms.contains(where: { $0.sourceIndex == sourceIndex }) else {
            return
        }
        rooms.append(replacing(
            room, sourceIndex: sourceIndex, name: name,
            faces: room.faces.map {
                replacing($0, portalIndex: .some(nil), lightmapInfoIndex: .some(nil))
            },
            portals: []
        ))
    }

    /// A RAS1 Light Security Flyer drawn with the model (or, `withLOD`,
    /// every level of detail) of the object `drawnAs`.
    fileprivate mutating func addRASFlyer(
        _ handle: UInt32, _ name: String, location: SpatialLocation,
        position: Vector3, orientation: Matrix3, drawnAs other: UInt32,
        withLOD: Bool = false
    ) {
        objects.append(.fixture(
            handle: handle, type: 2, storedID: 106,
            definition: .init(
                storedIndex: 106, sourceName: "RAS1 Light Security Flyer"
            ),
            name: name, flags: 5_121, location: location, position: position,
            orientation: orientation
        ))
        let drawn = objectPresentations.first { $0.objectHandle == other }!
        objectPresentations.append(
            withLOD
                ? .init(
                    objectHandle: handle, primaryModel: drawn.primaryModel,
                    mediumModel: drawn.mediumModel, lowModel: drawn.lowModel,
                    dyingModel: drawn.dyingModel,
                    mediumDistance: drawn.mediumDistance,
                    lowDistance: drawn.lowDistance
                )
                : .fixture(handle, drawn.primaryModel)
        )
    }
}

func makeTrainingRASBot1DeathLevel() -> Level {
    var level = makeTrainingKillbotEntryLevel()
    let player = level.trainingPlayer
    level.addRASFlyer(
        2_074, "RASBot1", location: player.location,
        position: player.position + player.orientation.forward * 20,
        orientation: player.orientation, drawnAs: 4_112
    )
    return rescriptedTrainingLevel(level)
}

func makeTrainingRASBot2DeathLevel() -> Level {
    var level = makeTrainingRASBot1DeathLevel()
    let player = level.trainingPlayer
    level.moveObject(2_074, to: player.position + player.orientation.right * 20)
    level.addRASFlyer(
        2_075, "RASBot2", location: player.location,
        position: player.position + player.orientation.forward * 20,
        orientation: player.orientation, drawnAs: 2_074
    )
    return rescriptedTrainingLevel(level)
}

func makeTrainingRASBot3DeathLevel() -> Level {
    var level = makeTrainingRASBot2DeathLevel()
    let player = level.trainingPlayer
    level.addClosedCopyOfPlayerRoom(42, "RASBot3 Room")
    level.moveObject(2_075, to: player.position - player.orientation.right * 20)
    level.addRASFlyer(
        2_077, "RASBot3", location: .room(42),
        position: player.position + player.orientation.forward * 20,
        orientation: player.orientation, drawnAs: 2_075
    )
    return rescriptedTrainingLevel(level)
}

func makeTrainingRASBot4DeathLevel() -> Level {
    var level = makeTrainingRASBot3DeathLevel()
    let player = level.trainingPlayer
    level.addClosedCopyOfPlayerRoom(0, "RASBot4 Room")
    level.addRASFlyer(
        2_078, "RASBot4", location: .room(0),
        position: player.position + player.orientation.forward * 20,
        orientation: player.orientation, drawnAs: 2_077
    )
    return rescriptedTrainingLevel(level)
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
        replacing(
            originalRoom,
            sourceIndex: 12,
            name: "Invuln Room",
            faces: originalRoom.faces.map {
                replacing($0, portalIndex: .some(nil), lightmapInfoIndex: .some(nil))
            },
            portals: []
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
        .fixture(
            handle: 2_076, type: 7, storedID: 3,
            definition: .init(storedIndex: 3, sourceName: "Invulnerability"),
            name: "InvulnPowerup2", flags: 5_120, location: .room(12),
            position: pickupRoom.pathPoint, orientation: player.orientation,
            containsType: 255
        ))
    level.objectPresentations.append(.fixture(2_076, model.source))
    let template = level.soundClips.first!
    let pickup = CanonicalSoundClip(
        logicalName: "Powerup pickup", sourceName: "Power03.wav",
        sourceEntryIndex: 499, sampleRate: template.sampleRate,
        channelCount: template.channelCount, frameCount: template.frameCount,
        pcm16LittleEndian: template.pcm16LittleEndian,
        pcmSHA256: template.pcmSHA256, sourceArchive: template.sourceArchive,
        sourceSHA256: template.sourceSHA256, importVolume: 1
    )
    let activated = CanonicalSoundClip(
        logicalName: "Invulnerability on", sourceName: "Invon.wav",
        sourceEntryIndex: 500, sampleRate: template.sampleRate,
        channelCount: template.channelCount, frameCount: template.frameCount,
        pcm16LittleEndian: template.pcm16LittleEndian,
        pcmSHA256: template.pcmSHA256, sourceArchive: template.sourceArchive,
        sourceSHA256: template.sourceSHA256, importVolume: 0.5
    )
    let expired = CanonicalSoundClip(
        logicalName: "Invulnerability off", sourceName: "Invoff.wav",
        sourceEntryIndex: 501, sampleRate: template.sampleRate,
        channelCount: template.channelCount, frameCount: template.frameCount,
        pcm16LittleEndian: template.pcm16LittleEndian,
        pcmSHA256: template.pcmSHA256, sourceArchive: template.sourceArchive,
        sourceSHA256: template.sourceSHA256, importVolume: 0.5
    )
    // InvulnPowerup2's page names the generic module, whose GenericScript
    // picks it up through msafe_DoPowerup (multisafe.cpp:2467).
    level = addingFixtureObjectDefinitions(
        level.addingObjectInfo(fixtureGenericPowerupInfo("Invulnerability")),
        [.init(storedIndex: 3, sourceName: "Invulnerability")]
    )
    // Package schema 11 carried the pickups (the generic module's data
    // with it).
    return withFixtureGameModules(rescriptedTrainingLevel(replacing(
        addingFixtureAudio(level, soundClips: [pickup, activated, expired]),
        schemaVersion: 11
    )))
}

func makeTrainingCloakPickupLevel() -> Level {
    var level = makeTrainingInvulnerabilityPickupLevel()
    if !level.rooms.contains(where: { $0.sourceIndex == 11 }) {
        let template = level.rooms.first { $0.sourceIndex == 12 }!
        level.rooms.append(replacing(
            template, sourceIndex: 11, name: "Cloak Room", portals: []
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
                        category: "model", source: $0,
                        state: "presentation-payload-imported",
                        provenance: "d3.hog"
                    )
                },
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    level.objects.append(.fixture(
        handle: 2_073, type: 7, storedID: 4,
        definition: .init(storedIndex: 4, sourceName: "Cloak"),
        name: "CloakPowerup2", flags: 5_120, location: .room(11),
        position: pickupRoom.pathPoint, orientation: player.orientation,
        containsType: 255
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_073, primaryModel: cloakModelSources[0],
        mediumModel: cloakModelSources[1], lowModel: cloakModelSources[2],
        dyingModel: nil, mediumDistance: 35, lowDistance: 50
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
    let cloakLevel = addingFixtureAudio(
        addingFixtureObjectDefinitions(
            level.addingObjectInfo(fixtureGenericPowerupInfo("Cloak")),
            [.init(storedIndex: 4, sourceName: "Cloak")]
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
            flags: 1, faceIndex: sourcePortal.faceIndex,
            connectedRoom: connectedSourceIndex,
            connectedPortal: connectedPortalIndex, boundaryNodeIndex: -1,
            pathPoint: sourcePortal.pathPoint, combineMaster: -1
        ))
        var connectedFaces = sourceConnectedRoom.faces.enumerated().map {
            faceIndex, face in
            replacing(
                face,
                portalIndex: .some(
                    faceIndex == sourceReciprocal.faceIndex
                        ? connectedPortalIndex : nil
                )
            )
        }

        var connectedPortals: [LevelPortal] = []
        if portalIndex == 0 {
            for auxiliaryPortalIndex in 0..<3 {
                let faceIndex = connectedFaces.count
                connectedFaces.append(replacing(
                    sourceConnectedRoom.faces[ sourceReciprocal.faceIndex ],
                    portalIndex: auxiliaryPortalIndex
                ))
                connectedPortals.append(.init(
                    flags: 1, faceIndex: faceIndex,
                    connectedRoom: 60 + auxiliaryPortalIndex,
                    connectedPortal: 0, boundaryNodeIndex: -1,
                    pathPoint: sourceReciprocal.pathPoint, combineMaster: -1
                ))
                let auxiliaryFace = lastRoomTemplate.faces[
                    sourcePortal.faceIndex
                ]
                connectedRooms.append(replacing(
                    lastRoomTemplate,
                    sourceIndex: 60 + auxiliaryPortalIndex,
                    name: "P6 auxiliary \(auxiliaryPortalIndex)",
                    faces: [replacing(auxiliaryFace, portalIndex: 0)],
                    portals: [
                        .init(
                            flags: 1, faceIndex: 0, connectedRoom: 41,
                            connectedPortal: auxiliaryPortalIndex,
                            boundaryNodeIndex: -1,
                            pathPoint: sourcePortal.pathPoint, combineMaster: -1
                        )
                    ]
                ))
            }
        }
        connectedPortals.append(.init(
            flags: 1, faceIndex: sourceReciprocal.faceIndex, connectedRoom: 44,
            connectedPortal: portalIndex, boundaryNodeIndex: -1,
            pathPoint: sourceReciprocal.pathPoint, combineMaster: -1
        ))
        connectedRooms.append(replacing(
            sourceConnectedRoom, sourceIndex: connectedSourceIndex,
            name: "P6 neighbor \(portalIndex)", faces: connectedFaces,
            portals: connectedPortals
        ))
    }

    let lastRoom = replacing(
        lastRoomTemplate, sourceIndex: 44, name: "PortalRoom6",
        portals: lastRoomPortals
    )
    lastRoomLevel.rooms.append(contentsOf: [lastRoom] + connectedRooms)
    lastRoomLevel.objects.append(.fixture(
        handle: 4_117,
        type: 11,
        storedID: 205,
        definition: .init(
            storedIndex: 205, sourceName: "Blinking Red Light-DM"
        ),
        name: "FlashLight-4",
        flags: 4_096,
        location: .room(44),
        position: lastRoom.pathPoint,
        orientation: player.orientation
    ))
    return rescriptedTrainingLevel(lastRoomLevel)
}

func makeTrainingFinalRoomEntryLevel() -> Level {
    let level = makeTrainingCloakPickupLevel()
    // Portal4 on face 1 of PortalRoom6 (source room 44), whose
    // TriggerScript_0002 runs Script 050 (TrainingMission.cpp:2368).
    let trigger = LevelTrigger(
        name: "Portal4", roomIndex: 44, faceIndex: 1, flags: 8, activator: 1
    )
    // The trigger face has FF_HAS_TRIGGER (CheckTrigger, trigger.cpp:196).
    var rooms = level.rooms
    let roomIndex = rooms.firstIndex { $0.sourceIndex == 44 }!
    let face = rooms[roomIndex].faces[1]
    rooms[roomIndex].faces[1] = replacing(
        face, flags: face.flags | LevelFace.hasTriggerFlag
    )
    let pcm = Data(repeating: 0, count: 2)
    return rescriptedTrainingLevel(
        addingFixtureAudio(
            replacing(
                level, rooms: rooms, triggers: level.triggers + [trigger],
                surfacePhysics: level.surfacePhysics
            ),
            voiceClips: [.silent(
                "intro7.osf", index: 16,
                sourceSHA256: "7348ded9ee2c6735ea712b52647f0bfa7478a508c03c10af5f837741a836c67f"
            )]
        )
    )
}

func makeTrainingLastBot1DeathLevel() -> Level {
    var level = makeTrainingFinalRoomEntryLevel()
    let player = level.trainingPlayer
    level.addClosedCopyOfPlayerRoom(14, "LastBot1 Room")
    level.addRASFlyer(
        4_127, "LastBot1", location: .room(14),
        position: player.position + player.orientation.forward * 20,
        orientation: player.orientation, drawnAs: 2_078
    )
    return rescriptedTrainingLevel(level)
}

func makeTrainingLastBot2DeathLevel() -> Level {
    var level = makeTrainingLastBot1DeathLevel()
    let player = level.trainingPlayer
    level.addClosedCopyOfPlayerRoom(46, "LastBot2 Room")
    level.addRASFlyer(
        2_080, "LastBot2", location: .room(46),
        position: player.position + player.orientation.forward * 30,
        orientation: player.orientation, drawnAs: 4_127, withLOD: true
    )
    return rescriptedTrainingLevel(level)
}

func makeTrainingLastBot3DeathLevel() -> Level {
    var level = makeTrainingLastBot2DeathLevel()
    let player = level.trainingPlayer
    level.addClosedCopyOfPlayerRoom(47, "LastBot3 Room")
    level.addRASFlyer(
        2_081, "LastBot3", location: .room(47),
        position: player.position + player.orientation.forward * 30,
        orientation: player.orientation, drawnAs: 2_080, withLOD: true
    )
    return rescriptedTrainingLevel(level)
}

func makeTrainingLastBot4DeathLevel() -> Level {
    var level = makeTrainingLastBot3DeathLevel()
    let lastBot3 = level.objects.first { $0.handle == 2_081 }!
    level.addRASFlyer(
        2_082, "LastBot4", location: .room(47), position: lastBot3.position,
        orientation: lastBot3.orientation, drawnAs: 2_081, withLOD: true
    )
    return rescriptedTrainingLevel(level)
}

func makeTrainingLastBot5DeathLevel() -> Level {
    var level = makeTrainingLastBot4DeathLevel()
    level.addClosedCopyOfPlayerRoom(48, "LastBot5 Room")
    let lastBot4 = level.objects.first { $0.handle == 2_082 }!
    level.addRASFlyer(
        2_083, "LastBot5", location: .room(48), position: lastBot4.position,
        orientation: lastBot4.orientation, drawnAs: 2_082, withLOD: true
    )
    return rescriptedTrainingLevel(level)
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
            flags: 1, faceIndex: sourcePortal.faceIndex,
            connectedRoom: connectedSourceIndex, connectedPortal: 0,
            boundaryNodeIndex: -1, pathPoint: sourcePortal.pathPoint,
            combineMaster: -1
        ))
        connectedRooms.append(replacing(
            sourceConnectedRoom,
            sourceIndex: connectedSourceIndex,
            name: "P7 neighbor \(portalIndex)",
            faces: sourceConnectedRoom.faces.enumerated().map {
                faceIndex, face in
                replacing(
                    face,
                    portalIndex: .some(faceIndex == reciprocal.faceIndex ? 0 : nil)
                )
            },
            portals: [
                .init(
                    flags: 1, faceIndex: reciprocal.faceIndex,
                    connectedRoom: 16, connectedPortal: portalIndex,
                    boundaryNodeIndex: -1, pathPoint: reciprocal.pathPoint,
                    combineMaster: -1
                )
            ]
        ))
    }

    let barrier = replacing(
        template, sourceIndex: 16, name: "PortalRoom7", portals: barrierPortals
    )
    level.rooms.append(contentsOf: [barrier] + connectedRooms)
    let player = level.objects.first {
        $0.handle == 2_048
    }!
    level.objects.append(.fixture(
        handle: 4_118,
        type: 11,
        storedID: 205,
        definition: .init(
            storedIndex: 205, sourceName: "Blinking Red Light-DM"
        ),
        name: "FlashLight-5",
        flags: 4_096,
        location: .room(16),
        position: barrier.pathPoint,
        orientation: player.orientation
    ))
    let pcm = Data(repeating: 0, count: 2)
    return rescriptedTrainingLevel(
        addingFixtureAudio(
            level,
            voiceClips: [.silent(
                "done.osf", index: 9, sourceSHA256: canonicalSHA256(pcm)
            )]
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
        center: player.position, texture: roomTemplate.faces[0].texture,
        sourceIndex: 17, halfExtent: 100
    )
    level.rooms.removeAll { $0.sourceIndex == 17 }
    level.rooms.append(room)
    let goal = PlacedObject.fixture(
        handle: 6_180,
        type: 7,
        storedID: 67,
        definition: .init(storedIndex: 67, sourceName: "Invisiblepowerup"),
        name: "FinalGoal",
        flags: 4_096,
        location: .room(17),
        position: player.position,
        orientation: .init(
            right: .init(x: -1, y: 0, z: 0), up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: -1)
        )
    )
    level.objects.append(goal)
    let modelSource = SourceResource(
        storedIndex: 4, sourceName: "invisiblepowerup.OOF"
    )
    level.objectPresentations.append(.fixture(
        goal.handle, modelSource, isVisible: false
    ))
    var models = level.models
    if let modelIndex = models.firstIndex(where: {
        $0.source == modelSource
    }) {
        let model = models[modelIndex]
        models[modelIndex] = CanonicalModel(
            source: model.source,
            collisionRadius: Float(bitPattern: 0x40a0_84bf),
            submodels: model.submodels, bounds: model.bounds,
            sourceArchive: model.sourceArchive, sourceSHA256: model.sourceSHA256
        )
    }
    level = replacing(
        level,
        metadata: .init(
            name: "Training Mission", designer: level.metadata.designer,
            copyright: level.metadata.copyright, notes: level.metadata.notes,
            gravity: level.metadata.gravity,
            alwaysCheckCeiling: level.metadata.alwaysCheckCeiling,
            ceilingHeight: level.metadata.ceilingHeight
        ),
        models: models
    )
    return rescriptedTrainingLevel(level)
}

/// The frame in which Script 057 (FinalGoal's EVT_COLLIDE,
/// TrainingMission.cpp:2309) ended Training through aEndLevel: the player
/// shot down the ten robots (each scores its page's 200, PlayerScoreAdd),
/// the last five ran Scripts 051-055 and 035, and then the player flew into
/// FinalGoal. The session's sequencer made the level end frame.
func trainingLevelEndFrame(
    headlightIsOn: Bool = false
) throws -> (session: GameSession, frame: PlayerSimulationFrame) {
    let level = addingTrainingMissionScripting(makeTrainingFinalGoalLevel())
    try level.validate()
    let session = GameSession(level: level, presentationReadyTimestamp: 0)
    session.killRobotsAsPlayer([
        4_112, 2_074, 2_075, 2_077, 2_078, 4_127, 2_080, 2_081, 2_082, 2_083,
    ])
    _ = session.update(at: 0.1, input: .zero)
    session.world.playerHeadlightIsOn = headlightIsOn
    let frame = session.touch("FinalGoal", at: 0.2)
    return (session, frame)
}
