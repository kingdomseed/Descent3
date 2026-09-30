import XCTest

func makeTrainingGalleryBarrierLevel() -> Level {
    var level = makeSliceSixObjectRenderLevel()
    let cameraOrigin = RoomCamera.trainingRoom3.position
    let barrierRoomIndex = level.rooms.firstIndex {
        $0.sourceIndex == 2
    }!
    for portalIndex in level.rooms[barrierRoomIndex].portals.indices {
        level.rooms[barrierRoomIndex].portals[portalIndex].flags &= ~UInt32(1)
        let portal = level.rooms[barrierRoomIndex].portals[portalIndex]
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex].portals[portal.connectedPortal].flags
            &= ~UInt32(1)
    }
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    level.objects[playerIndex].location = .room(2)
    level.objects[playerIndex].position = .init(
        x: cameraOrigin.x,
        y: cameraOrigin.y + 2.5,
        z: cameraOrigin.z
    )
    level.objects[playerIndex].orientation = .init(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 0, z: 1),
        forward: .init(x: 0, y: -1, z: 0)
    )
    level.objects.append(.init(
        handle: 6_163,
        type: 11,
        storedID: 67,
        definition: level.objects.first { $0.handle == 12_301 }!.definition,
        instanceName: "FlashLight-2",
        flags: 0,
        doorShields: nil,
        location: .room(2),
        position: cameraOrigin,
        orientation: .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        ),
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    let trigger = LevelTrigger(
        name: "Portal2",
        roomIndex: 2,
        faceIndex: 1,
        flags: 8,
        activator: 1
    )
    let triggerFace = level.rooms[barrierRoomIndex].faces[trigger.faceIndex]
    level.rooms[barrierRoomIndex].faces[trigger.faceIndex] = .init(
        corners: triggerFace.corners,
        flags: triggerFace.flags | 0x0010,
        portalIndex: triggerFace.portalIndex,
        texture: triggerFace.texture,
        lightmapInfoIndex: triggerFace.lightmapInfoIndex,
        allowsLightCorona: triggerFace.allowsLightCorona,
        lightMultiple: triggerFace.lightMultiple,
        special: triggerFace.special
    )
    level = replacing(level, triggers: [trigger])
    return rescriptedTrainingLevel(
        level.addingTrainingGalleryBarrier(
            .init(
                triggerName: trigger.name,
                triggerRoomSourceIndex: trigger.roomIndex,
                triggerFaceIndex: trigger.faceIndex,
                barrierRoomSourceIndex: 2,
                orderedPortalIndices: [1, 0],
                markerLightObjectHandle: 6_163,
                openMarkerLightDistance: 50,
                successMessage: "Excellent!",
                guidebotInstruction:
                    "Your ship is equipped with a utility robot called a Guidebot.  Release him now with F4.",
                voiceSourceName: "guidebota.osf"
            ),
            voiceClip: .init(
                sourceName: "guidebota.osf",
                sourceEntryIndex: 0,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: Data(repeating: 0, count: 2),
                pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "a", count: 64)
            )
        )
    )
}

/// The Training opening lessons' level (TrainingMission.cpp Scripts
/// 000-015): the Slice 6 room with the opening goals, the streams and the
/// MenuBeepEnter sound the scripts play, room 2 named PortalRoom1, and the
/// Training level module.
func makeTrainingScript003Level() -> Level {
    var level = makeSliceSixObjectRenderLevel()
    let portalRoomOne = level.rooms.firstIndex { $0.sourceIndex == 2 }!
    level.rooms[portalRoomOne].name = "PortalRoom1"
    let pcm = Data(repeating: 0, count: 2)
    let clips = [
        ("welcome.osf", 38),
        ("return1.osf", 28),
        ("left1.osf", 18),
        ("return2.osf", 29),
        ("up1.osf", 37),
        ("return3.osf", 30),
        ("repeat.osf", 25),
        ("lright.osf", 19),
        ("udown.osf", 36),
        ("proceed1.osf", 21),
        ("intro1.osf", 10),
    ].map { name, index in
        CanonicalVoiceClip(
            sourceName: name,
            sourceEntryIndex: index,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: pcm,
            pcmSHA256: canonicalSHA256(pcm),
            sourceArchive: "missions/training.mn3",
            sourceSHA256: String(repeating: "a", count: 64)
        )
    }
    let scripted = level.addingAudioClips(
        voiceClips: clips,
        soundClips: [
            .init(
                logicalName: "MenuBeepEnter",
                sourceName: "MenuBeepSelectC.wav",
                sourceEntryIndex: 0,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: pcm,
                pcmSHA256: canonicalSHA256(pcm),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "b", count: 64),
                importVolume: 0.7
            ),
            .init(
                logicalName: "PupC1",
                sourceName: "Powerup pickup.wav",
                sourceEntryIndex: 1,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: pcm,
                pcmSHA256: canonicalSHA256(pcm),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "b", count: 64),
                importVolume: 1
            ),
        ]
    )
    // Script 000 and Script 002 come from the Training level module.
    return addingTrainingMissionScripting(scripted)
}

func makeTrainingScript015Level() -> Level {
    var level = makeTrainingScript003Level()
    let finishPosition = Vector3(
        x: 2_062.5024,
        y: -650.74756,
        z: 2_206.0369
    )
    let invisibleDefinition = level.objects.first {
        $0.handle == 6_147
    }!.definition
    level.objects.append(.init(
        handle: 6_150,
        type: 7,
        storedID: 67,
        definition: invisibleDefinition,
        instanceName: "FinishCourse",
        flags: 4_096,
        doorShields: nil,
        location: .room(50),
        position: finishPosition,
        orientation: .init(
            right: .init(x: -1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: -0),
            forward: .init(x: -0, y: -0, z: -1)
        ),
        containsType: 255,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    let invisibleModel = SourceResource(
        storedIndex: 6,
        sourceName: "finishcourse-invisiblepowerup.OOF"
    )
    let modelRadius: Float = 5.016_204_4
    let finishModel = CanonicalModel(
        source: invisibleModel,
        collisionRadius: modelRadius,
        submodels: [
            .init(
                sourceIndex: 0,
                parentIndex: nil,
                offset: .zero,
                vertices: [
                    .init(
                        position: .init(x: -modelRadius, y: 0, z: 0),
                        alpha: 1
                    ),
                    .init(
                        position: .init(x: modelRadius, y: 0, z: 0),
                        alpha: 1
                    ),
                ],
                faces: [],
                presentation: .standard
            ),
        ],
        bounds: .init(
            minimum: .init(x: -modelRadius, y: 0, z: 0),
            maximum: .init(x: modelRadius, y: 0, z: 0)
        ),
        sourceArchive: level.source.profileFiles[0].relativePath,
        sourceSHA256: String(repeating: "d", count: 64)
    )
    level.objectPresentations.append(.init(
        objectHandle: 6_150,
        primaryModel: invisibleModel,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil,
        isVisible: false
    ))

    let texture = level.surfacePhysics[0].texture
    typealias PortalConnection = (
        faceIndex: Int,
        room: Int,
        portal: Int,
        reversesFace: Bool
    )
    func portalRoom(
        sourceIndex: Int,
        name: String?,
        center: Vector3,
        faceCount: Int,
        connections: [PortalConnection]
    ) -> LevelRoom {
        let shell = makeSourceContainmentRoom(
            center: center,
            texture: texture,
            sourceIndex: sourceIndex,
            halfExtent: 200
        )
        var faces = shell.faces
        while faces.count < faceCount {
            faces.append(shell.faces[0])
        }
        let portals = connections.enumerated().map {
            portalIndex, connection in
            let face = shell.faces[0]
            faces[connection.faceIndex] = .init(
                corners: connection.reversesFace
                    ? Array(face.corners.reversed())
                    : face.corners,
                flags: face.flags,
                portalIndex: portalIndex,
                texture: face.texture
            )
            return LevelPortal(
                flags: 1,
                faceIndex: connection.faceIndex,
                connectedRoom: connection.room,
                connectedPortal: connection.portal
            )
        }
        return LevelRoom(
            sourceIndex: sourceIndex,
            name: name,
            pathPoint: shell.pathPoint,
            vertices: shell.vertices,
            faces: faces,
            portals: portals
        )
    }
    level.rooms.append(portalRoom(
        sourceIndex: 35,
        name: nil,
        center: finishPosition,
        faceCount: 21,
        connections: [(20, 49, 0, false)]
    ))
    level.rooms.append(portalRoom(
        sourceIndex: 49,
        name: "PortalRoom2",
        center: finishPosition,
        faceCount: 2,
        connections: [
            (1, 35, 0, true),
            (0, 50, 0, false),
        ]
    ))
    level.rooms.append(portalRoom(
        sourceIndex: 50,
        name: nil,
        center: finishPosition,
        faceCount: 1,
        connections: [(0, 49, 1, true)]
    ))

    let pcm = Data(repeating: 0, count: 2)
    let proceed2 = CanonicalVoiceClip(
        sourceName: "proceed2.osf",
        sourceEntryIndex: 22,
        sampleRate: 22_050,
        channelCount: 1,
        frameCount: 1,
        pcm16LittleEndian: pcm,
        pcmSHA256: canonicalSHA256(pcm),
        sourceArchive: "missions/training.mn3",
        sourceSHA256: String(repeating: "c", count: 64)
    )
    let dependency = DependencyRecord(
        category: "voice",
        source: .init(
            storedIndex: proceed2.sourceEntryIndex,
            sourceName: proceed2.sourceName
        ),
        state: "canonical-pcm-imported",
        provenance: "\(proceed2.sourceArchive) \(proceed2.sourceSHA256)"
    )
    let modelDependency = DependencyRecord(
        category: "model",
        source: invisibleModel,
        state: "presentation-payload-imported",
        provenance: "synthetic Script 015 fixture"
    )
    return rescriptedTrainingLevel(
        replacing(
            level,
            rooms: level.rooms,
            objects: level.objects,
            models: level.models + [finishModel],
            objectPresentations: level.objectPresentations,
            voiceClips: level.voiceClips + [proceed2],
            dependencyManifest: .init(
                current: level.dependencyManifest.current
                    + [modelDependency, dependency],
                historicalEagerBaseline:
                    level.dependencyManifest.historicalEagerBaseline
            )
        )
    )
}

func makeTrainingDodgeAttemptLevel() -> Level {
    var level = makeTrainingScript015Level()
    let invisibleDefinition = level.objects.first {
        $0.handle == 6_150
    }!.definition
    let identity = Matrix3(
        right: .init(x: -1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: -1)
    )
    level.objects.append(contentsOf: [
        .init(
            handle: 4_106,
            type: 7,
            storedID: 67,
            definition: invisibleDefinition,
            instanceName: "StartDodge",
            flags: 4_096,
            doorShields: nil,
            location: .room(35),
            position: .init(
                x: 2_061.8765,
                y: -752.8663,
                z: 2_199.4517
            ),
            orientation: identity,
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        ),
        .init(
            handle: 12_302,
            type: 7,
            storedID: 67,
            definition: invisibleDefinition,
            instanceName: "DoneDodgeingGoal",
            flags: 4_096,
            doorShields: nil,
            location: .room(35),
            position: .init(
                x: 2_061.31,
                y: -755.9523,
                z: 2_421.182
            ),
            orientation: identity,
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        ),
        .init(
            handle: 8_199,
            type: 2,
            storedID: 115,
            definition: .init(
                storedIndex: 115,
                sourceName: "Hangturret"
            ),
            instanceName: "DodgeTurrett",
            flags: 5_120,
            doorShields: nil,
            location: .room(35),
            position: .init(
                x: 2_061.69,
                y: -701.7448,
                z: 2_356.2942
            ),
            orientation: .init(
                right: .init(
                    x: -1,
                    y: -0.000_013_950_893,
                    z: -0.000_097_655_844
                ),
                up: .init(
                    x: -0.000_013_950_893,
                    y: 1,
                    z: -0.000_000_001_362_392
                ),
                forward: .init(
                    x: 0.000_097_655_844,
                    y: -0.000_000_000_000_005_722_752,
                    z: -1
                )
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        ),
        .init(
            handle: 4_120,
            type: 11,
            storedID: 205,
            definition: .init(
                storedIndex: 205,
                sourceName: "Blinking Red Light-DM"
            ),
            instanceName: "FlashLight-1",
            flags: 4_096,
            doorShields: nil,
            location: .room(36),
            position: .init(
                x: 2_061.6824,
                y: -745.7475,
                z: 2_441.2942
            ),
            orientation: .init(
                right: .init(
                    x: 0.000_097_656_244,
                    y: 0,
                    z: -1
                ),
                up: .init(
                    x: 0.000_012_207_031,
                    y: -1,
                    z: 0.000_000_001_192_092_9
                ),
                forward: .init(
                    x: -1,
                    y: -0.000_012_207_031,
                    z: -0.000_097_656_244
                )
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        ),
    ])

    let invisibleModel = level.objectPresentations.first {
        $0.objectHandle == 6_150
    }!.primaryModel
    let turretModel = SourceResource(
        storedIndex: 115,
        sourceName: "securityturret.OOF"
    )
    let projectileModel = SourceResource(
        storedIndex: 57,
        sourceName: "RedLaser.OOF"
    )
    let modelTemplate = level.models[0]
    let submodelTemplate = modelTemplate.submodels[0]
    let outerOffset = Vector3(
        x: -0.079_373_36,
        y: -1.241_355_9,
        z: 0.097_942_59
    )
    let headOffset = Vector3(
        x: -1.132_905,
        y: -1.353_618_6,
        z: 0.311_014_4
    )
    let turretSubmodels: [ModelSubmodel] = [
        .init(
            sourceIndex: 0,
            parentIndex: nil,
            offset: .zero,
            vertices: submodelTemplate.vertices,
            faces: submodelTemplate.faces,
            presentation: .standard
        ),
        .init(
            sourceIndex: 1,
            parentIndex: 0,
            offset: outerOffset,
            vertices: submodelTemplate.vertices,
            faces: submodelTemplate.faces,
            presentation: .turret(
                fieldOfView: 0.5,
                rotationsPerSecond: 0.125,
                thinkInterval: 10,
                axis: .init(x: 0, y: -1, z: 0)
            )
        ),
        .init(
            sourceIndex: 2,
            parentIndex: 1,
            offset: headOffset,
            vertices: submodelTemplate.vertices,
            faces: submodelTemplate.faces,
            presentation: .turret(
                fieldOfView: 0.125,
                rotationsPerSecond: 0.125,
                thinkInterval: 10,
                axis: .init(
                    x: 1,
                    y: -3.410_774_8e-16,
                    z: -4.371_139e-8
                )
            )
        ),
    ]
    let turretPoints = turretSubmodels.flatMap { submodel in
        let offset: Vector3
        switch submodel.sourceIndex {
        case 1:
            offset = outerOffset
        case 2:
            offset = .init(
                x: outerOffset.x + headOffset.x,
                y: outerOffset.y + headOffset.y,
                z: outerOffset.z + headOffset.z
            )
        default:
            offset = .zero
        }
        return submodel.vertices.map {
            Vector3(
                x: offset.x + $0.position.x,
                y: offset.y + $0.position.y,
                z: offset.z + $0.position.z
            )
        }
    }
    let turretBounds = ModelBounds(
        minimum: .init(
            x: turretPoints.map(\.x).min()!,
            y: turretPoints.map(\.y).min()!,
            z: turretPoints.map(\.z).min()!
        ),
        maximum: .init(
            x: turretPoints.map(\.x).max()!,
            y: turretPoints.map(\.y).max()!,
            z: turretPoints.map(\.z).max()!
        )
    )
    let turretCanonicalModel = CanonicalModel(
        source: turretModel,
        collisionRadius: 5.552_946,
        submodels: turretSubmodels,
        bounds: turretBounds,
        sourceArchive: modelTemplate.sourceArchive,
        sourceSHA256: String(repeating: "8", count: 64)
    )
    let projectileCanonicalModel = CanonicalModel(
        source: projectileModel,
        collisionRadius: 4.878_135,
        submodels: modelTemplate.submodels,
        bounds: modelTemplate.bounds,
        sourceArchive: modelTemplate.sourceArchive,
        sourceSHA256: String(repeating: "7", count: 64)
    )
    level = replacing(
        level,
        models:
            level.models
            + [turretCanonicalModel, projectileCanonicalModel]
    )
    level.objectPresentations.append(contentsOf: [
        .init(
            objectHandle: 4_106,
            primaryModel: invisibleModel,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        ),
        .init(
            objectHandle: 12_302,
            primaryModel: invisibleModel,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        ),
        .init(
            objectHandle: 8_199,
            primaryModel: turretModel,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        ),
    ])

    let room35Index = level.rooms.firstIndex {
        $0.sourceIndex == 35
    }!
    var room35 = level.rooms[room35Index]
    let room35Face = room35.faces[0]
    room35.faces.append(
        .init(
            corners: room35Face.corners,
            flags: room35Face.flags,
            portalIndex: room35.portals.count,
            texture: room35Face.texture,
            lightmapInfoIndex: room35Face.lightmapInfoIndex,
            allowsLightCorona: room35Face.allowsLightCorona,
            lightMultiple: room35Face.lightMultiple,
            special: room35Face.special
        ))
    room35.portals.append(
        .init(
            flags: 1,
            faceIndex: room35.faces.count - 1,
            connectedRoom: 36,
            connectedPortal: 0
        ))
    level.rooms[room35Index] = room35
    let texture = level.surfacePhysics[0].texture
    func room(
        sourceIndex: Int,
        name: String?,
        connections: [(room: Int, portal: Int)]
    ) -> LevelRoom {
        let shell = makeSourceContainmentRoom(
            center: .init(x: 2_061.68, y: -745.75, z: 2_441.29),
            texture: texture,
            sourceIndex: sourceIndex,
            halfExtent: 100
        )
        var faces = shell.faces
        while faces.count < connections.count {
            faces.append(shell.faces[0])
        }
        let portals = connections.enumerated().map { index, connection in
            let face = faces[index]
            faces[index] = .init(
                corners: face.corners,
                flags: face.flags,
                portalIndex: index,
                texture: face.texture,
                lightmapInfoIndex: face.lightmapInfoIndex,
                allowsLightCorona: face.allowsLightCorona,
                lightMultiple: face.lightMultiple,
                special: face.special
            )
            return LevelPortal(
                flags: 1,
                faceIndex: index,
                connectedRoom: connection.room,
                connectedPortal: connection.portal
            )
        }
        return .init(
            sourceIndex: sourceIndex,
            name: name,
            pathPoint: shell.pathPoint,
            vertices: shell.vertices,
            faces: faces,
            portals: portals
        )
    }
    level.rooms.append(
        room(
            sourceIndex: 36,
            name: "PortalRoom3",
            connections: [(35, 1), (37, 0)]
        ))
    level.rooms.append(
        room(
            sourceIndex: 37,
            name: nil,
            connections: [(36, 1)]
        ))
    func matchReciprocalPortalGeometry(
        sourceRoomSourceIndex: Int,
        sourcePortalIndex: Int,
        connectedRoomSourceIndex: Int,
        connectedPortalIndex: Int
    ) {
        let sourceRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == sourceRoomSourceIndex
        }!
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == connectedRoomSourceIndex
        }!
        let sourcePortal =
            level.rooms[sourceRoomIndex].portals[sourcePortalIndex]
        let sourceFace =
            level.rooms[sourceRoomIndex].faces[sourcePortal.faceIndex]
        let reciprocalPoints = sourceFace.corners.reversed().map {
            level.rooms[sourceRoomIndex].vertices[$0.vertexIndex]
        }
        let connectedPortal =
            level.rooms[connectedRoomIndex]
            .portals[connectedPortalIndex]
        let connectedFace =
            level.rooms[connectedRoomIndex]
            .faces[connectedPortal.faceIndex]
        let firstVertex =
            level.rooms[connectedRoomIndex].vertices.count
        level.rooms[connectedRoomIndex].vertices.append(
            contentsOf: reciprocalPoints
        )
        let corners = reciprocalPoints.indices.map { index in
            let template = connectedFace.corners[
                index % connectedFace.corners.count
            ]
            return FaceCorner(
                vertexIndex: firstVertex + index,
                u: template.u,
                v: template.v,
                alpha: template.alpha,
                lightmapU: template.lightmapU,
                lightmapV: template.lightmapV
            )
        }
        level.rooms[connectedRoomIndex]
            .faces[connectedPortal.faceIndex] = .init(
                corners: corners,
                flags: connectedFace.flags,
                portalIndex: connectedFace.portalIndex,
                texture: connectedFace.texture,
                lightmapInfoIndex:
                    connectedFace.lightmapInfoIndex,
                allowsLightCorona:
                    connectedFace.allowsLightCorona,
                lightMultiple: connectedFace.lightMultiple,
                special: connectedFace.special
            )
    }
    matchReciprocalPortalGeometry(
        sourceRoomSourceIndex: 35,
        sourcePortalIndex: 1,
        connectedRoomSourceIndex: 36,
        connectedPortalIndex: 0
    )
    matchReciprocalPortalGeometry(
        sourceRoomSourceIndex: 36,
        sourcePortalIndex: 1,
        connectedRoomSourceIndex: 37,
        connectedPortalIndex: 0
    )

    let pcm = Data(repeating: 0, count: 2)
    let dodgeVoices = [
        "intro2.osf",
        "almost.osf",
        "proceed3.osf",
        "proceed4.osf",
    ]
        .enumerated().map { index, name in
            CanonicalVoiceClip(
                sourceName: name,
                sourceEntryIndex: 100 + index,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: pcm,
                pcmSHA256: canonicalSHA256(pcm),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "9", count: 64)
            )
        }
    let dodgeSounds = [
        ("WpmLaserBlueFire", "LaserAHitB.wav"),
        ("LazorHitshrt", "Lazor1Hit.wav"),
    ].enumerated().map { index, value in
        CanonicalSoundClip(
            logicalName: value.0,
            sourceName: value.1,
            sourceEntryIndex: 200 + index,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: pcm,
            pcmSHA256: canonicalSHA256(pcm),
            sourceArchive: level.source.profileFiles[0].relativePath,
            sourceSHA256: String(repeating: "6", count: 64),
            importVolume: 1
        )
    }
    level = replacing(
        level,
        voiceClips: level.voiceClips + dodgeVoices,
        soundClips: level.soundClips + dodgeSounds,
        dependencyManifest: .init(
            current: level.dependencyManifest.current
                + [
                    .init(
                        category: "object-definition",
                        source: .init(
                            storedIndex: 115,
                            sourceName: "Hangturret"
                        ),
                        state: "identity-recorded",
                        provenance: "synthetic timed dodge fixture"
                    ),
                    .init(
                        category: "object-definition",
                        source: .init(
                            storedIndex: 205,
                            sourceName: "Blinking Red Light-DM"
                        ),
                        state: "identity-recorded",
                        provenance: "synthetic timed dodge fixture"
                    ),
                    .init(
                        category: "model",
                        source: turretModel,
                        state: "presentation-payload-imported",
                        provenance: "synthetic timed dodge fixture"
                    ),
                    .init(
                        category: "model",
                        source: projectileModel,
                        state: "presentation-payload-imported",
                        provenance: "synthetic timed dodge fixture"
                    ),
                ]
                + dodgeVoices.map {
                    .init(
                        category: "voice",
                        source: .init(
                            storedIndex: $0.sourceEntryIndex,
                            sourceName: $0.sourceName
                        ),
                        state: "canonical-pcm-imported",
                        provenance:
                            "\($0.sourceArchive) \($0.sourceSHA256)"
                    )
                }
                + dodgeSounds.map {
                    .init(
                        category: "sound",
                        source: .init(
                            storedIndex: $0.sourceEntryIndex,
                            sourceName: $0.sourceName
                        ),
                        state: "canonical-pcm-imported",
                        provenance:
                            "\($0.sourceArchive) \($0.sourceSHA256)"
                    )
                },
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    // The object tables: the turret page, the flash light page, the red
    // laser, and the turret model's gun points and battery.
    level = level
        .addingObjectInfo(fixtureTurretInfo)
        .addingObjectInfo(fixtureFlashLightInfo)
        .addingWeapon(fixtureRedLaser(model: projectileModel))
        .settingModelGuns(
            turretModel,
            gunpoints: fixtureTurretGunpoints,
            batteries: fixtureTurretBatteries
        )
    return rescriptedTrainingLevel(
        level
    )
}

func replacingTrainingRoom(
    _ room: LevelRoom,
    sourceIndex: Int,
    portals: [LevelPortal]
) -> LevelRoom {
    LevelRoom(
        sourceIndex: sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: room.vertices,
        faces: room.faces,
        portals: portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
}

func script050ReadyContinuation(
    in level: Level,
    timerRemaining: Float = 1.5
) throws -> GameWorld {
    let chain = try XCTUnwrap(level.trainingFinalRoomEntryChain)
    let room = try XCTUnwrap(level.rooms.first {
        $0.sourceIndex == chain.triggerRoomSourceIndex
    })
    let face = room.faces[chain.triggerFaceIndex]
    let centerSum = face.corners.reduce(Vector3.zero) {
        let vertex = room.vertices[$1.vertexIndex]
        return .init(
            x: $0.x + vertex.x,
            y: $0.y + vertex.y,
            z: $0.z + vertex.z
        )
    }
    let divisor = Float(face.corners.count)
    let center = Vector3(
        x: centerSum.x / divisor,
        y: centerSum.y / divisor,
        z: centerSum.z / divisor
    )
    let normal = try XCTUnwrap(
        canonicalFaceNormal(room: room, face: face)
    )
    let playerRadius = defaultPlayerView(in: level).collisionRadius
    let initial = GameSession(
        level: level,
        presentationReadyTimestamp: 0
    )
    var object = try XCTUnwrap(
        testWorldObject(initial.world)
    )
    // Scripts 043-046 ran as the four RAS bots died.
    if (object["levelModule"] as? [String: Any])?["trainingMission"] != nil {
        for name in ["script043Count", "script044Count", "script045Count",
                     "script046Count"] {
            try setTrainingCounter(&object, name, 1)
        }
    }
    object["trainingInvulnerabilityPickupState"] = [
        "scriptWasTriggered": true,
        "wasConsumed": true,
    ]
    object["trainingCloakPickupState"] = [
        "scriptWasTriggered": true,
        "wasConsumed": true,
    ]
    // Scripts 047 and 048 counted the pickups.
    if (object["levelModule"] as? [String: Any])?["trainingMission"] != nil {
        for name in ["script047Count", "script048Count", "script034Count"] {
            try setTrainingCounter(&object, name, 1)
        }
    }
    object["playerLocation"] = [
        "room": ["_0": chain.triggerRoomSourceIndex]
    ]
    object["playerPosition"] = [
        "x": center.x + normal.x * (playerRadius + 1),
        "y": center.y + normal.y * (playerRadius + 1),
        "z": center.z + normal.z * (playerRadius + 1),
    ]
    object["velocity"] = [
        "x": -normal.x * 100,
        "y": -normal.y * 100,
        "z": -normal.z * 100,
    ]
    // The world those producer states imply: the four robots and the two
    // pickups are gone, and Script 048 opened the last-room barrier.
    var world = try decodeTestWorld(object)
    for handle in [
        2_074, 2_075, 2_077, 2_078,
        level.trainingInvulnerabilityPickupChain?.pickupObjectHandle,
        level.trainingCloakPickupChain?.pickupObjectHandle,
    ] {
        world.objects.delete(ObjectHandle(try XCTUnwrap(handle)))
    }
    // Script 034 opened the last-room barrier, lit FlashLight-4, and set
    // level timer 9 (TrainingMission.cpp:1403-1415).
    openTrainingLastRoomBarrier(in: &world, level: level)
    world.setObjectLightDistance(ObjectHandle(chain034Marker(level)), 50)
    if world.levelModule != .none {
        world.aSetLevelTimer(timerRemaining, 9)
    }
    return world
}

/// FlashLight-4, the last-room marker.
private func chain034Marker(_ level: Level) -> UInt32 {
    level.trainingLastRoomChain!.markerLightObjectHandle
}

func assertTrainingGuidebotReturnBarrier(
    level: Level,
    rendersFaces: Bool
) {
    let chain = level.trainingCameraMonitorChain!.returnToShip!
    let room = level.rooms.first {
        $0.sourceIndex == chain.barrierRoomSourceIndex
    }!
    for portalIndex in chain.orderedPortalIndices {
        let portal = room.portals[portalIndex]
        XCTAssertEqual(portal.flags & 1 != 0, rendersFaces)
        let connectedRoom = level.rooms.first {
            $0.sourceIndex == portal.connectedRoom
        }!
        XCTAssertEqual(
            connectedRoom.portals[portal.connectedPortal].flags & 1 != 0,
            rendersFaces
        )
    }
}

func makeTrainingGuidebotBlockedMovementLevel() -> Level {
    var level = makeTrainingRobotGuidebotLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let chain = level.trainingRobotGuidebotChain!
    level = replacing(
        level,
        trainingRobotGuidebotChain: .init(
            guidebotObjectHandle: chain.guidebotObjectHandle,
            deployedGuidebotObjectType:
                chain.deployedGuidebotObjectType,
            deployedGuidebotMessage: chain.deployedGuidebotMessage,
            deployedGuidebotVoiceSourceName:
                chain.deployedGuidebotVoiceSourceName,
            guidebot: .init(
                collisionRadius: chain.guidebot.collisionRadius,
                maximumVelocity: chain.guidebot.maximumVelocity,
                maximumDeltaVelocity:
                    chain.guidebot.maximumDeltaVelocity,
                birthForwardVelocity:
                    chain.guidebot.birthForwardVelocity,
                goalForwardDistance: 40,
                goalCircleDistance:
                    chain.guidebot.goalCircleDistance
            )
        )
    )
    guard case let .room(roomSourceIndex) = player.location else {
        preconditionFailure("expected indoor player")
    }
    let roomIndex = level.rooms.firstIndex {
        $0.sourceIndex == roomSourceIndex
    }!
    func point(forward: Float, right: Float, up: Float = 0) -> Vector3 {
        Vector3(
            x: player.position.x
                + player.orientation.forward.x * forward
                + player.orientation.right.x * right
                + player.orientation.up.x * up,
            y: player.position.y
                + player.orientation.forward.y * forward
                + player.orientation.right.y * right
                + player.orientation.up.y * up,
            z: player.position.z
                + player.orientation.forward.z * forward
                + player.orientation.right.z * right
                + player.orientation.up.z * up
        )
    }
    var room = addingSourceContainmentShell(
        to: level.rooms[roomIndex],
        center: player.position,
        texture: level.surfacePhysics[0].texture,
        halfExtent: 100
    )
    let firstWallVertex = room.vertices.count
    let wallVertices = [
        point(forward: 20, right: -10, up: -20),
        point(forward: 20, right: 10, up: -20),
        point(forward: 20, right: 10, up: 20),
        point(forward: 20, right: -10, up: 20),
    ]
    room = .init(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: room.vertices + wallVertices,
        faces: room.faces + [
            .init(
                corners: (0..<4).reversed().map {
                    .init(
                        vertexIndex: firstWallVertex + $0,
                        u: 0,
                        v: 0,
                        alpha: 255
                    )
                },
                flags: 0,
                portalIndex: nil,
                texture: level.surfacePhysics[0].texture
            ),
        ],
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    level.rooms[roomIndex] = room

    let firstRoutePoint = point(forward: 12, right: 25)
    let secondRoutePoint = point(forward: 30, right: 25)
    level = replacing(
        level,
        indoorNavigation: .init(
            sourceHighestRoomPlusTerrainRegions:
                level.rooms.map(\.sourceIndex).max()! + 8,
            sourceWasVerified: true,
            rooms: [
                .init(
                    sourceIndex: roomSourceIndex,
                    nodes: [
                        .init(
                            position: secondRoutePoint,
                            edges: [
                                .init(
                                    destinationRoomSourceIndex:
                                        roomSourceIndex,
                                    destinationNodeIndex: 1,
                                    flags: 0,
                                    cost: 18,
                                    maximumRadius: 6
                                ),
                            ]
                        ),
                        .init(
                            position: firstRoutePoint,
                            edges: [
                                .init(
                                    destinationRoomSourceIndex:
                                        roomSourceIndex,
                                    destinationNodeIndex: 0,
                                    flags: 0,
                                    cost: 18,
                                    maximumRadius: 6
                                ),
                            ]
                        ),
                    ]
                ),
            ]
        )
    )
    return rescriptedTrainingLevel(
        level
    )
}

func assertTrainingGalleryBarrier(
    level: Level,
    rendersFaces: Bool,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let barrier = level.trainingGalleryBarrier!
    let room = level.rooms.first {
        $0.sourceIndex == barrier.barrierRoomSourceIndex
    }!
    for portalIndex in barrier.orderedPortalIndices {
        let portal = room.portals[portalIndex]
        XCTAssertEqual(
            portal.flags & 1 != 0,
            rendersFaces,
            file: file,
            line: line
        )
        let connectedRoom = level.rooms.first {
            $0.sourceIndex == portal.connectedRoom
        }!
        XCTAssertEqual(
            connectedRoom.portals[portal.connectedPortal].flags & 1 != 0,
            rendersFaces,
            file: file,
            line: line
        )
    }
}
