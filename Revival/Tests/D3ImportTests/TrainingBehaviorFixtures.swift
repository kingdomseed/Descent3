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
    return level.addingTrainingGalleryBarrier(
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
}

func makeTrainingScript003Level() -> Level {
    let level = makeSliceSixObjectRenderLevel()
    let startGoalHandle: UInt32 = 12_300
    let presentation = level.objectPresentations.first {
        $0.objectHandle == startGoalHandle
    }!
    let model = level.models.first {
        $0.source == presentation.primaryModel
    }!
    let leftGoalHandle: UInt32 = 12_299
    let leftPresentation = level.objectPresentations.first {
        $0.objectHandle == leftGoalHandle
    }!
    let leftModel = level.models.first {
        $0.source == leftPresentation.primaryModel
    }!
    let forwardGoalHandle: UInt32 = 12_301
    let forwardPresentation = level.objectPresentations.first {
        $0.objectHandle == forwardGoalHandle
    }!
    let forwardModel = level.models.first {
        $0.source == forwardPresentation.primaryModel
    }!
    let upGoalHandle: UInt32 = 18_441
    let upGoalPresentation = level.objectPresentations.first {
        $0.objectHandle == upGoalHandle
    }!
    let upGoalModel = level.models.first {
        $0.source == upGoalPresentation.primaryModel
    }!
    let startCourseHandle: UInt32 = 6_147
    let startCoursePresentation = level.objectPresentations.first {
        $0.objectHandle == startCourseHandle
    }!
    let startCourseModel = level.models.first {
        $0.source == startCoursePresentation.primaryModel
    }!
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
    return level.addingTrainingOpeningLesson(
        .init(
            forwardGoalObjectHandle: 12_301,
            welcomeDelay: 1,
            welcomeMessage: "Welcome to the Descent 3 Training session.",
            forwardInstruction: "Move forward until you stop.",
            welcomeVoiceSourceName: "welcome.osf",
            successMessage: "Excellent!",
            reverseInstruction:
                "Now use the reverse Key to return to where you started!",
            successVoiceSourceName: "return1.osf",
            returnLeft: .init(
                startGoalObjectHandle: startGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: model,
                    objectType: 7
                ),
                instruction: "Now Go Left until you stop.",
                voiceSourceName: "left1.osf"
            ),
            returnRight: .init(
                leftGoalObjectHandle: leftGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: leftModel,
                    objectType: 7
                ),
                successMessage: "Excellent!",
                instruction:
                    "Now Slide right until you return to the start position.",
                voiceSourceName: "return2.osf"
            ),
            returnUp: .init(
                startGoalObjectHandle: startGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: model,
                    objectType: 7
                ),
                successMessage: "Excellent!",
                instruction: "Now Slide up  until you stop.",
                voiceSourceName: "up1.osf"
            ),
            returnDown: .init(
                upGoalObjectHandle: 18_441,
                collisionRadius: sourceObjectPresentationSize(
                    model: model,
                    objectType: 7
                ),
                successMessage: "Excellent!",
                instruction:
                    "Now Slide down until you return to the start position.",
                voiceSourceName: "return3.osf"
            ),
            repeatForward: .init(
                startGoalObjectHandle: startGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: model,
                    objectType: 7
                ),
                successMessage: "Excellent!",
                repeatMessage: "Let's repeat the exercise we just did.",
                forwardInstruction: "Move forward until you stop.",
                voiceSourceName: "repeat.osf"
            ),
            repeatForwardGoal: .init(
                forwardGoalObjectHandle: forwardGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: forwardModel,
                    objectType: 7
                ),
                reverseInstruction:
                    "Now use the reverse Key to return to where you started!",
                soundLogicalName: "MenuBeepEnter"
            ),
            repeatReturnLeft: .init(
                startGoalObjectHandle: startGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: model,
                    objectType: 7
                ),
                instruction: "Now Go Left until you stop.",
                voiceSourceName: "lright.osf"
            ),
            repeatReturnRight: .init(
                leftGoalObjectHandle: leftGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: leftModel,
                    objectType: 7
                ),
                instruction:
                    "Now Slide right until you return to the start position.",
                soundLogicalName: "MenuBeepEnter"
            ),
            repeatReturnUp: .init(
                startGoalObjectHandle: startGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: model,
                    objectType: 7
                ),
                instruction: "Now Slide up  until you stop.",
                voiceSourceName: "udown.osf"
            ),
            repeatReturnDown: .init(
                upGoalObjectHandle: upGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: upGoalModel,
                    objectType: 7
                ),
                instruction:
                    "Now Slide down until you return to the start position.",
                soundLogicalName: "MenuBeepEnter"
            ),
            continueToCourse: .init(
                startGoalObjectHandle: startGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: model,
                    objectType: 7
                ),
                portalRoomSourceIndex: 2,
                orderedPortalIndices: [0, 1],
                instruction:
                    "Continue Sliding down to start the next step.",
                voiceSourceName: "proceed1.osf"
            ),
            startCourse: .init(
                startCourseObjectHandle: startCourseHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: startCourseModel,
                    objectType: 7
                ),
                portalRoomSourceIndex: 2,
                portalIndex: 1,
                instruction:
                    "Now, manuever through this tunnel using the sliding skills you just learned.",
                voiceSourceName: "intro1.osf",
                enabledControlMask: 63
            )
        ),
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
        ]
    )
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

    var lesson = level.trainingOpeningLesson!
    lesson.finishCourse = .init(
        finishCourseObjectHandle: 6_150,
        collisionRadius: sourceObjectPresentationSize(
            model: finishModel,
            objectType: 7
        ),
        portalRoomSourceIndex: 49,
        orderedPortalIndices: [0, 1],
        successMessage: "Excellent!",
        instruction: "Continue Sliding down to start the next step.",
        voiceSourceName: "proceed2.osf",
        enabledControlMask: 32
    )
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
    return replacing(
        level,
        rooms: level.rooms,
        objects: level.objects,
        models: level.models + [finishModel],
        objectPresentations: level.objectPresentations,
        trainingOpeningLesson: lesson,
        voiceClips: level.voiceClips + [proceed2],
        dependencyManifest: .init(
            current: level.dependencyManifest.current
                + [modelDependency, dependency],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
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
    level.trainingDodgeAttempt = .init(
        startDodgeObjectHandle: 4_106,
        startDodgeCollisionRadius: 10.052_409,
        doneDodgeingGoalObjectHandle: 12_302,
        doneDodgeingGoalCollisionRadius: 10.052_409,
        dodgeTurretObjectHandle: 8_199,
        flashLightObjectHandle: 4_120,
        triggerDelay: 10,
        successDelay: 20,
        almostDoneDelay: 14,
        portalRoomTwoSourceIndex: 49,
        portalRoomThreeSourceIndex: 36,
        orderedPortalIndices: [0, 1],
        disabledControlMask: 3,
        enabledDodgeControlMask: 60,
        successControlMask: 3,
        introduction: "Next you are going to practice dodging.",
        instruction:
            "To complete this step, dodge the turrett fire for 20 seconds.",
        hitInstruction: "Oops, you were hit! Keep moving!",
        almostDoneInstruction:
            "You are almost done! Keep up the good work!",
        successMessage: "Excellent!",
        leaveInstruction:
            "Now using your sliding skills, proceed forward to the flashing green light.",
        introductionVoiceSourceName: "intro2.osf",
        almostDoneVoiceSourceName: "almost.osf",
        successVoiceSourceName: "proceed3.osf",
        restoredPlayerShields: 100,
        successMarkerLightDistance: 50,
        markerLightPresentation: .init(
            primaryColor: .init(x: 0.2, y: 1, z: 0.2),
            secondaryColor: .zero,
            timeInterval: 0.5,
            flickerDistance: 0.2,
            directionalDot: 0,
            flags: 4,
            timebits: .max,
            angle: 0,
            lightingRenderType: 2
        ),
        turret: .init(
            model: turretModel,
            collisionRadius: 5.402_855_4,
            fieldOfViewDot: -1,
            maximumTargetDistance: 1_000,
            fireAlignmentDot: 0.93,
            fixedLeadAccuracy: 0.81,
            fireWait: 1,
            gunpoints: [
                .init(
                    x: 1.706_505_8,
                    y: -2.224_015_2,
                    z: 2.190_463_5
                ),
                .init(
                    x: 0.457_947_73,
                    y: -2.224_015_2,
                    z: 2.190_463_5
                ),
            ],
            aimingGunpoint: .init(
                x: 1.085_584_6,
                y: -2.224_015_2,
                z: 2.190_463_5
            ),
            gunpointForward: .init(
                x: 0,
                y: -0.707_105_7,
                z: 0.707_107_84
            ),
            gunpointParentSubmodelIndex: 2,
            joints: [
                .init(
                    submodelIndex: 1,
                    parentSubmodelIndex: 0,
                    rotationAxis: .init(x: 0, y: -1, z: 0),
                    fieldOfView: 0.5,
                    rotationsPerSecond: 0.125,
                    thinkInterval: 10
                ),
                .init(
                    submodelIndex: 2,
                    parentSubmodelIndex: 1,
                    rotationAxis: .init(
                        x: 1,
                        y: -3.410_774_8e-16,
                        z: -4.371_139e-8
                    ),
                    fieldOfView: 0.125,
                    rotationsPerSecond: 0.125,
                    thinkInterval: 10
                ),
            ],
            projectileSourceName: "Laser Level 1 - Red",
            projectileModel: projectileModel,
            fireSoundSourceName: "WpmLaserBlueFire",
            impactSoundSourceName: "LazorHitshrt",
            projectileDamage: 6.75,
            projectileRadius: 0.5,
            projectileSpeed: 200,
            projectileLifetime: 5
        )
    )
    level.trainingDodgeAttempt?.dodgeExit = .init(
        objectHandle: 12_302,
        collisionRadius: 10.052_409,
        markerLightObjectHandle: 4_120,
        markerLightDistance: 50,
        portalRoomSourceIndex: 36,
        orderedPortalIndices: [0, 1],
        disabledControlMask: 62,
        instruction:
            "Now keep moving forward into the next room.",
        voiceSourceName: "proceed4.osf"
    )
    return level
}

func makeTrainingManeuverFollowLevel() -> Level {
    var level = makeTrainingDodgeAttemptLevel()
    let invisibleDefinition = level.objects.first {
        $0.handle == 6_150
    }!.definition
    let invisibleModel = level.objectPresentations.first {
        $0.objectHandle == 6_150
    }!.primaryModel
    let identity = Matrix3(
        right: .init(x: -1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: -1)
    )
    let followBotOrientation = Matrix3(
        right: .init(
            x: -0.999_645_05,
            y: -0.010_065_023,
            z: 0.024_667_98
        ),
        up: .init(
            x: -0.008_759_673,
            y: 0.998_584_4,
            z: 0.052_465_245
        ),
        forward: .init(
            x: -0.025_161_121,
            y: 0.052_230_537,
            z: -0.998_318_1
        )
    )
    level.objects.append(contentsOf: [
        .init(
            handle: 2_063,
            type: 7,
            storedID: 67,
            definition: invisibleDefinition,
            instanceName: "ManuverRoomCenter",
            flags: 4_096,
            doorShields: nil,
            location: .room(37),
            position: .init(
                x: 2_061.7336,
                y: -755.4103,
                z: 2_566.1135
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
            handle: 8_200,
            type: 2,
            storedID: 106,
            definition: .init(
                storedIndex: 106,
                sourceName: "RAS1 Light Security Flyer"
            ),
            instanceName: "FollowBot1",
            flags: 5_121,
            doorShields: nil,
            location: .room(37),
            position: .init(
                x: 2_059.3496,
                y: -723.2588,
                z: 2_469.1072
            ),
            orientation: followBotOrientation,
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
    let gyro = SourceResource(
        storedIndex: 106,
        sourceName: "gyro.OOF"
    )
    let template = level.models[0]
    level = replacing(
        level,
        source: replacing(
            level.source,
            profileFiles: level.source.profileFiles + [
                .init(
                    relativePath: "d3.hog",
                    byteCount: 1,
                    sha256: String(repeating: "d", count: 64)
                ),
            ]
        ),
        paths: [
            .init(
                name: "FollowLoop1",
                flags: 0,
                nodes: [
                    pathNode(
                        2_092.3477, -723.2839, 2_475.0989,
                        -0.999_637_8, -0.010_080_075, 0.024_955_332,
                        -0.008_759_689_5, 0.998_584_33, 0.052_465_282
                    ),
                    pathNode(
                        2_120.8862, -725.230_83, 2_516.9202,
                        0.443_545_25, -0.043_143_31, 0.895_213,
                        -0.008_759_731, 0.998_584_33, 0.052_465_245
                    ),
                    pathNode(
                        2_132.2334, -727.802_37, 2_567.7603,
                        -0.155_969_68, -0.053_189_583, 0.986_328_7,
                        -0.008_759_797, 0.998_584_33, 0.052_465_29
                    ),
                    pathNode(
                        2_105.4128, -729.7712, 2_600.7546,
                        -0.652_316_63, -0.045_472_786, 0.756_581_25,
                        -0.008_759_798_5, 0.998_584_33, 0.052_465_282
                    ),
                    pathNode(
                        2_078.9663, -731.614_75, 2_631.4287,
                        -0.652_316_63, -0.045_472_786, 0.756_581_25,
                        -0.008_759_798_5, 0.998_584_33, 0.052_465_282
                    ),
                    pathNode(
                        2_046.4663, -731.9499, 2_632.3801,
                        -0.996_973_45, -0.004_668_452, -0.077_602_65,
                        -0.008_759_799, 0.998_584_4, 0.052_465_282
                    ),
                    pathNode(
                        2_023.0117, -731.8655, 2_626.8577,
                        -0.805_366_2, 0.024_053_827, -0.592_289_3,
                        -0.008_759_8, 0.998_584_33, 0.052_465_275
                    ),
                    pathNode(
                        2_007.6753, -730.662_84, 2_601.4045,
                        -0.364_299_4, 0.045_674_63, -0.930_161_2,
                        -0.008_759_801, 0.998_584_4, 0.052_465_275
                    ),
                    pathNode(
                        2_003.6691, -729.142, 2_571.789,
                        0.080_688_6, 0.053_002_07, -0.995_329_2,
                        -0.008_759_827, 0.998_584_33, 0.052_465_275
                    ),
                    pathNode(
                        1_987.4816, -726.8468, 2_525.4,
                        -0.352_754_15, 0.046_008_28, -0.934_584_26,
                        -0.008_759_827, 0.998_584_33, 0.052_465_267
                    ),
                    pathNode(
                        2_005.9342, -725.277_34, 2_498.6106,
                        0.646_923_4, 0.045_667_43, -0.761_186_3,
                        -0.008_759_825, 0.998_584_4, 0.052_465_27
                    ),
                    pathNode(
                        2_035.6516, -724.0875, 2_480.9272,
                        0.931_484_94, 0.027_230_46, -0.362_759_32,
                        -0.008_759_825, 0.998_584_33, 0.052_465_27
                    ),
                    pathNode(
                        2_068.726, -723.599_37, 2_477.1624,
                        0.994_420_6, 0.003_183_510_4, 0.105_440_035,
                        -0.008_759_849, 0.998_584_33, 0.052_465_554
                    ),
                ]
            ),
            .init(
                name: "GoToDie",
                flags: 0,
                nodes: [
                    pathNode(
                        2_126.0396, -731.692_57, 2_555.0505,
                        -0.968_044_1, -0.248_761_6, 0.031_754_155,
                        -0.249_600_16, 0.968_002_9, -0.025_886_48
                    ),
                ]
            ),
        ],
        models: level.models + [
            .init(
                source: gyro,
                collisionRadius: 3.841_456_2,
                submodels: template.submodels,
                bounds: template.bounds,
                sourceArchive: "d3.hog",
                sourceSHA256:
                    "896cc33ba0c7ec00fd2fd693a0e8f10868a47076eda0b7914cc90a790e87eb61"
            ),
        ],
        objectPresentations: level.objectPresentations + [
            .init(
                objectHandle: 2_063,
                primaryModel: invisibleModel,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil,
                isVisible: false
            ),
            .init(
                objectHandle: 8_200,
                primaryModel: gyro,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil
            ),
        ]
    )
    let pcm = Data(repeating: 0, count: 2)
    let voices = [
        "intro3.osf", "pitch.osf", "bank.osf", "follow.osf", "intro4.osf",
    ].enumerated().map { index, sourceName in
        CanonicalVoiceClip(
            sourceName: sourceName,
            sourceEntryIndex: 300 + index,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: pcm,
            pcmSHA256: canonicalSHA256(pcm),
            sourceArchive: "missions/training.mn3",
            sourceSHA256: String(repeating: "a", count: 64)
        )
    }
    level = replacing(
        level,
        voiceClips: level.voiceClips + voices,
        dependencyManifest: .init(
            current: level.dependencyManifest.current + [
                .init(
                    category: "object-definition",
                    source: .init(
                        storedIndex: 106,
                        sourceName: "RAS1 Light Security Flyer"
                    ),
                    state: "identity-recorded",
                    provenance: "synthetic maneuver-follow fixture"
                ),
                .init(
                    category: "model",
                    source: gyro,
                    state: "presentation-payload-imported",
                    provenance: "synthetic maneuver-follow fixture"
                ),
            ] + voices.map {
                .init(
                    category: "voice",
                    source: .init(
                        storedIndex: $0.sourceEntryIndex,
                        sourceName: $0.sourceName
                    ),
                    state: "canonical-pcm-imported",
                    provenance: "synthetic maneuver-follow fixture"
                )
            },
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    level.trainingDodgeAttempt?.maneuverFollow = .init(
        maneuverObjectHandle: 2_063,
        maneuverCollisionRadius: 10.052_409,
        flashLightObjectHandle: 4_120,
        portalRoomSourceIndex: 36,
        orderedPortalIndices: [1, 0],
        headingControlMask: 768,
        pitchControlMask: 192,
        bankControlMask: 3_072,
        rotationalControlMask: 4_032,
        weaponControlMask: 12_288,
        headingDuration: 20,
        pitchDuration: 12,
        bankDuration: 15,
        followDuration: 20,
        followBotObjectHandle: 8_200,
        friendlyTeamFlags: 65_536,
        followPathIndex: 0,
        followPathGoalFlags: 9_437_444,
        destroyPathIndex: 1,
        destroyPathGoalFlags: 4_352,
        goalSlot: 0,
        goalPriority: 3,
        maneuverIntroduction:
            "Now you are going to learn the other controls, which are pitch, heading and bank.",
        headingInstruction:
            "Now your heading controls are enabled. Try them out by rotating to the left and right.",
        successMessage: "Excellent!",
        pitchInstruction:
            "Now your pitch controls are enabled. Try them out by pitching up and down.",
        bankInstruction:
            "Now your bank controls are enabled. Try them out by banking to the left and right.",
        followIntroduction:
            "Now you will use the rotational skills you just learned to follow one of the two robots that are circling this room",
        followInstruction:
            "Keep one of the robots on your screen for 20 seconds using only your rotational controls to complete this step.",
        weaponsEnabledInstruction:
            "Now your weapons have been enabled. There is a primary and a secondary.",
        destroyInstruction: "Now, destroy the robot.",
        headingVoiceSourceName: "intro3.osf",
        pitchVoiceSourceName: "pitch.osf",
        bankVoiceSourceName: "bank.osf",
        followVoiceSourceName: "follow.osf",
        weaponVoiceSourceName: "intro4.osf",
        followBot: .init(
            model: gyro,
            collisionRadius: 4.576_441_8,
            maximumVelocity: 40,
            maximumDeltaVelocity: 80,
            maximumTurnRate: 12_000,
            maximumDeltaTurnRate: 16_000,
            circleDistance: 25
        )
    )
    return level
}

func makeTrainingMovingTargetHandoffLevel() -> Level {
    var level = makeTrainingManeuverFollowLevel()
    let gyro = try! XCTUnwrap(
        level.trainingDodgeAttempt?.maneuverFollow?.followBot.model
    )
    let definition = try! XCTUnwrap(
        level.objects.first { $0.handle == 8_200 }?.definition
    )
    level.objects.append(contentsOf: [
        .init(
            handle: 4_112,
            type: 2,
            storedID: 106,
            definition: definition,
            instanceName: "DestroyBot2",
            flags: 5_121,
            doorShields: nil,
            location: .room(37),
            position: .init(
                x: 2_121.0835,
                y: -787.4891,
                z: 2_556.6667
            ),
            orientation: .init(
                right: .init(
                    x: 0.060_053_87,
                    y: -0.047_255_82,
                    z: -0.997_076
                ),
                up: .init(
                    x: 0.142_230_26,
                    y: 0.989_091_93,
                    z: -0.038_310_897
                ),
                forward: .init(
                    x: 0.988_010_17,
                    y: -0.139_513_64,
                    z: 0.066_12
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
            handle: 4_113,
            type: 2,
            storedID: 106,
            definition: definition,
            instanceName: "DestroyBot1",
            flags: 5_121,
            doorShields: nil,
            location: .room(37),
            position: .init(
                x: 1_998.6289,
                y: -789.663_15,
                z: 2_556.2332
            ),
            orientation: .init(
                right: .init(
                    x: -0.004_710_059,
                    y: 0.044_023_126,
                    z: 0.999_019_44
                ),
                up: .init(
                    x: -0.180_763_14,
                    y: 0.982_535_3,
                    z: -0.044_148_97
                ),
                forward: .init(
                    x: -0.983_515_4,
                    y: -0.180_793_82,
                    z: 0.003_329_959
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
    let projectile = SourceResource(
        storedIndex: 16,
        sourceName: "bluelaser.OOF"
    )
    let modelTemplate = level.models[0]
    let voicePCM = Data(repeating: 0, count: 172_565 * 2)
    let voice = CanonicalVoiceClip(
        sourceName: "kill1.osf",
        sourceEntryIndex: 17,
        sampleRate: 22_050,
        channelCount: 1,
        frameCount: 172_565,
        pcm16LittleEndian: voicePCM,
        pcmSHA256: canonicalSHA256(voicePCM),
        sourceArchive: "missions/training.mn3",
        sourceSHA256:
            "d2ea757ac472b40781ce62a7dbd45649e3abce3f4884edf1303048e3cf36be7e"
    )
    level = replacing(
        level,
        source: replacing(
            level.source,
            archiveSHA256: String(repeating: "b", count: 64)
        ),
        models: level.models + [
            .init(
                source: projectile,
                collisionRadius: 4.920_813,
                submodels: modelTemplate.submodels,
                bounds: modelTemplate.bounds,
                sourceArchive: "d3.hog",
                sourceSHA256:
                    "717a9a2ac254eba76c7992fc834e3a5bc3992f86674af972afd9cf0c2967b31b"
            ),
        ],
        objectPresentations: level.objectPresentations + [
            .init(
                objectHandle: 4_112,
                primaryModel: gyro,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil,
                isVisible: false
            ),
            .init(
                objectHandle: 4_113,
                primaryModel: gyro,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil,
                isVisible: false
            ),
        ],
        voiceClips: level.voiceClips + [voice],
        dependencyManifest: .init(
            current: level.dependencyManifest.current + [
                .init(
                    category: "model",
                    source: projectile,
                    state: "presentation-payload-imported",
                    provenance: "synthetic blue laser fixture"
                ),
                .init(
                    category: "voice",
                    source: .init(
                        storedIndex: voice.sourceEntryIndex,
                        sourceName: voice.sourceName
                    ),
                    state: "canonical-pcm-imported",
                    provenance: "synthetic moving-target fixture"
                ),
            ],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    level.trainingDodgeAttempt?.maneuverFollow?
        .destructionHandoff = .init(
            followBotObjectHandle: 8_200,
            destroyBot2ObjectHandle: 4_112,
            destroyBot1ObjectHandle: 4_113,
            combat: .stockTraining,
            projectileModel: projectile,
            destructionDelay: 2,
            levelTimerID: 11,
            movingTeamFlags: 65_536,
            movingPathIndex: 0,
            movingPathGoalFlags: 8_392_960,
            goalID: -1,
            goalPriority: 3,
            successMessage: "Excellent!",
            movingInstruction:
                "Now destroy 2 more robots. This time they will be moving.",
            voiceSourceName: "kill1.osf"
        )
    return level
}

private func pathNode(
    _ x: Float,
    _ y: Float,
    _ z: Float,
    _ forwardX: Float,
    _ forwardY: Float,
    _ forwardZ: Float,
    _ upX: Float,
    _ upY: Float,
    _ upZ: Float
) -> GamePathNode {
    .init(
        position: .init(x: x, y: y, z: z),
        location: .room(37),
        flags: 0,
        forward: .init(
            x: forwardX,
            y: forwardY,
            z: forwardZ
        ),
        up: .init(x: upX, y: upY, z: upZ)
    )
}

func makeTrainingRobotGuidebotLevel() -> Level {
    var level = makeTrainingGalleryBarrierLevel()
    let buddySource = SourceResource(
        storedIndex: 200,
        sourceName: "Buddybot.oof"
    )
    let gyroSource = SourceResource(
        storedIndex: 201,
        sourceName: "gyro.OOF"
    )
    let modelTemplate = level.models[0]
    level = replacing(
        level,
        models: level.models + [
            .init(
                source: buddySource,
                collisionRadius: 5.659_440_5,
                submodels: modelTemplate.submodels,
                bounds: modelTemplate.bounds,
                sourceArchive: modelTemplate.sourceArchive,
                sourceSHA256: String(repeating: "d", count: 64)
            ),
            .init(
                source: gyroSource,
                collisionRadius: 4.576_441_8,
                submodels: modelTemplate.submodels,
                bounds: modelTemplate.bounds,
                sourceArchive: modelTemplate.sourceArchive,
                sourceSHA256: String(repeating: "e", count: 64)
            ),
        ],
        objectPresentations: level.objectPresentations + [
            .init(
                objectHandle: 4_112,
                primaryModel: gyroSource,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil
            ),
        ],
        dependencyManifest: .init(
            current: level.dependencyManifest.current + [
                .init(
                    category: "model",
                    source: buddySource,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
                .init(
                    category: "model",
                    source: gyroSource,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
            ],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    let template = level.objects.first { $0.handle == 12_301 }!
    level.objects.append(.init(
        handle: 4_112,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "DestroyBot2",
        flags: 5_121,
        doorShields: nil,
        location: .room(2),
        position: template.position,
        orientation: template.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level = replacing(
        level,
        dependencyManifest: .init(
            current: level.dependencyManifest.current + [
                .init(
                    category: "object-definition",
                    source: .init(
                        storedIndex: 106,
                        sourceName: "RAS1 Light Security Flyer"
                    ),
                    state: "identity-recorded",
                    provenance: "synthetic canonical fixture"
                ),
            ],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    return level.addingTrainingRobotGuidebotChain(
        .init(
            destroyRobotObjectHandle: 4_112,
            guidebotObjectHandle: 6_164,
            destroyRobotRoomSourceIndex: 2,
            destroyRobotFlags: 5_121,
            destructionDelay: 2,
            destructionMessage: "Excellent!",
            exitInstruction:
                "Now go through the open doorway, and into the next room.",
            destructionVoiceSourceName: "proceed5.osf",
            deployedGuidebotObjectType: 2,
            deployedGuidebotMessage:
                "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
            deployedGuidebotVoiceSourceName: "guidebotb.osf",
            combat: .stockTraining,
            guidebot: .stockTraining
        ),
        voiceClips: [
            .init(
                sourceName: "proceed5.osf",
                sourceEntryIndex: 1,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: Data(repeating: 0, count: 2),
                pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "b", count: 64)
            ),
            .init(
                sourceName: "guidebotb.osf",
                sourceEntryIndex: 2,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: Data(repeating: 0, count: 2),
                pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "c", count: 64)
            ),
        ]
    )
}

func makeTrainingGuidebotYellowFlareLevel() -> Level {
    var level = makeTrainingRobotGuidebotLevel()
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    level.rooms[roomIndex] = addingSourceContainmentShell(
        to: .init(
            sourceIndex: room.sourceIndex,
            name: room.name,
            pathPoint: room.pathPoint,
            vertices: [],
            faces: [],
            portals: []
        ),
        center: room.pathPoint,
        texture: level.surfacePhysics[0].texture,
        halfExtent: 500
    )
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    level.objects[playerIndex].location = .room(1)
    level.objects[playerIndex].position = room.pathPoint
    let chain = level.trainingRobotGuidebotChain!
    let templateModel = level.models.first {
        $0.source.sourceName.caseInsensitiveCompare("Buddybot.oof")
            == .orderedSame
    }!
    let modelSource = SourceResource(
        storedIndex: level.models.count,
        sourceName: "FlareYellowBright.OOF"
    )
    let flareModel = CanonicalModel(
        source: modelSource,
        collisionRadius: Float(bitPattern: 0x405f_d5ea),
        submodels: templateModel.submodels,
        bounds: templateModel.bounds,
        sourceArchive: templateModel.sourceArchive,
        sourceSHA256:
            "fa0f92ba8d3ea0d348766c2cf56897935a0a1afe211378729b5781d773fb9ed4"
    )
    let templateMaterial = level.presentationMaterials[0]
    let particleTexture = SourceResource(
        storedIndex: 878,
        sourceName: "yellowspark"
    )
    let animationFrames = [particleTexture] + Array(
        trainingGuidebotYellowFlareAnimationFrames.dropFirst()
    )
    let particleMaterials = animationFrames.map { frame in
        PresentationMaterial(
            texture: frame,
            bitmapSourceName: "yellowspark.oaf",
            image: templateMaterial.image,
            blend: .additiveSourceAlpha(opacity: 255),
            lightmapBlend: .none,
            waterProcedural: nil,
            sourceArchive: templateMaterial.sourceArchive,
            sourceSHA256:
                "eabf95db1e5c17235b65a7b938081d40e44736456112acbc4a1ff99126051194"
        )
    }
    let explosionTexture = SourceResource(
        storedIndex: 900,
        sourceName: "FlarePuff"
    )
    let explosionMaterial = PresentationMaterial(
        texture: explosionTexture,
        bitmapSourceName: "FlarePuff.oaf",
        image: templateMaterial.image,
        blend: .additiveSourceAlpha(opacity: 102),
        lightmapBlend: .none,
        waterProcedural: nil,
        sourceArchive: templateMaterial.sourceArchive,
        sourceSHA256:
            "9416910ac344a0e3a9dd35ef596300147b7014972c73974a88546351ca92835c"
    )
    let pcm = Data(repeating: 0, count: 2)
    let sound = CanonicalSoundClip(
        logicalName: "Flare",
        sourceName: "Flare.wav",
        sourceEntryIndex: 1_158,
        sampleRate: 22_050,
        channelCount: 1,
        frameCount: 1,
        pcm16LittleEndian: pcm,
        pcmSHA256: canonicalSHA256(pcm),
        sourceArchive: templateModel.sourceArchive,
        sourceSHA256: String(repeating: "f", count: 64),
        importVolume: 0.300_000_07
    )
    let timeout = TrainingGuidebotYellowFlareTimeoutDefinition(
        explosionTexture: explosionTexture,
        explosionLifetime: 0.2,
        explosionSize: 2,
        childSource: .init(
            storedIndex: 54,
            sourceName: "YellowFlareSparks"
        ),
        childTexture: particleTexture,
        childCount: 9,
        childWeaponFlags: 1_056,
        childPhysicsFlags: 2_556_032,
        childCollisionRadius: 0.2,
        childSpeed: 17,
        childLifetime: 0.2,
        childMass: 0.1,
        childDrag: 0.1,
        childCoefficientOfRestitution: 1,
        childLightDistance: 6,
        childLightPresentation: .init(
            primaryColor: .init(x: 1, y: 1, z: 0.5),
            secondaryColor: .zero,
            timeInterval: 0,
            flickerDistance: 0,
            directionalDot: 0,
            flags: 0,
            timebits: 0,
            angle: 0,
            lightingRenderType: 0
        ),
        childParticleCount: 25,
        childParticleInterval: 0.04,
        childParticleSize: 0.3,
        childParticleLifetime: 0.3,
        childAnimationFrames: animationFrames,
        childSourceFrameTime: 0.07
    )
    let yellowFlare = TrainingGuidebotYellowFlareDefinition(
        source: .init(storedIndex: 3, sourceName: "Yellow flare"),
        model: modelSource,
        particleTexture: particleTexture,
        fireSoundSourceName: sound.sourceName,
        weaponFlags: 0x8001_0000,
        physicsFlags: 0x2000_0810,
        modelPageSize: Float(bitPattern: 0x405f_d5ea),
        collisionRadius: 0.1,
        speed: 100,
        lifetime: 15,
        mass: 0.1,
        drag: 0.0001,
        coefficientOfRestitution: 1,
        lightDistance: 35,
        lightPresentation: .init(
            primaryColor: .init(x: 1, y: 1, z: 0.8),
            secondaryColor: .zero,
            timeInterval: 0.2,
            flickerDistance: 5,
            directionalDot: 0,
            flags: 16,
            timebits: UInt32.max,
            angle: 0,
            lightingRenderType: 0
        ),
        particleCount: 25,
        particleInterval: 0.04,
        particleSize: 0.2,
        particleLifetime: 0.3,
        timeout: timeout
    )
    let boundChain = TrainingRobotGuidebotChain(
        destroyRobotObjectHandle: chain.destroyRobotObjectHandle,
        guidebotObjectHandle: chain.guidebotObjectHandle,
        destroyRobotRoomSourceIndex: chain.destroyRobotRoomSourceIndex,
        destroyRobotFlags: chain.destroyRobotFlags,
        destructionDelay: chain.destructionDelay,
        destructionMessage: chain.destructionMessage,
        exitInstruction: chain.exitInstruction,
        destructionVoiceSourceName:
            chain.destructionVoiceSourceName,
        deployedGuidebotObjectType:
            chain.deployedGuidebotObjectType,
        deployedGuidebotMessage: chain.deployedGuidebotMessage,
        deployedGuidebotVoiceSourceName:
            chain.deployedGuidebotVoiceSourceName,
        releaseSoundSourceName: chain.releaseSoundSourceName,
        ambientEngineSoundSourceName:
            chain.ambientEngineSoundSourceName,
        yellowFlare: yellowFlare,
        combat: chain.combat,
        guidebot: chain.guidebot
    )
    let dependencies = level.dependencyManifest.current + [
        DependencyRecord(
            category: "weapon-definition",
            source: yellowFlare.source,
            state: "canonical-page-bound",
            provenance: "synthetic Yellow flare fixture"
        ),
        .init(
            category: "model",
            source: modelSource,
            state: "presentation-payload-imported",
            provenance: "synthetic Yellow flare fixture"
        ),
    ] + animationFrames.map { frame in
        .init(
            category: "texture",
            source: frame,
            state: "presentation-payload-imported",
            provenance: "synthetic Yellow flare fixture"
        )
    } + [
        .init(
            category: "weapon-definition",
            source: timeout.childSource,
            state: "canonical-page-bound",
            provenance: "synthetic Yellow flare timeout fixture"
        ),
        .init(
            category: "texture",
            source: explosionTexture,
            state: "presentation-payload-imported",
            provenance: "synthetic Yellow flare timeout fixture"
        ),
        .init(
            category: "sound",
            source: .init(
                storedIndex: sound.sourceEntryIndex,
                sourceName: sound.sourceName
            ),
            state: "canonical-pcm-imported",
            provenance: "synthetic Yellow flare fixture"
        ),
    ]
    return replacing(
        level,
        presentationMaterials:
            level.presentationMaterials
                + particleMaterials + [explosionMaterial],
        models: level.models + [flareModel],
        trainingRobotGuidebotChain: boundChain,
        soundClips: level.soundClips + [sound],
        dependencyManifest: .init(
            current: dependencies,
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
}
func makeTrainingCameraMonitorLevel() -> Level {
    var level = makeTrainingRobotGuidebotLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let returnBarrierRoomIndex = level.rooms.firstIndex {
        $0.sourceIndex == 2
    }!
    let sourceForceField = level.rooms[returnBarrierRoomIndex]
        .faces[
            level.rooms[returnBarrierRoomIndex].portals[0].faceIndex
        ].texture
    let stockReturnForceField = SourceResource(
        storedIndex: 908,
        sourceName: "Alien Force Field_1"
    )
    var rooms = level.rooms
    for portalIndex in [0, 1] {
        let portal = rooms[returnBarrierRoomIndex].portals[portalIndex]
        rooms[returnBarrierRoomIndex].faces[portal.faceIndex].texture =
            stockReturnForceField
        let reciprocalRoomIndex = rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        let reciprocal = rooms[reciprocalRoomIndex]
            .portals[portal.connectedPortal]
        rooms[reciprocalRoomIndex].faces[reciprocal.faceIndex].texture =
            stockReturnForceField
    }
    let sourceForceFieldMaterial = level.presentationMaterials.first {
        $0.texture == sourceForceField
    }!
    level = replacing(
        level,
        rooms: rooms,
        surfacePhysics: level.surfacePhysics + [
            .init(
                texture: stockReturnForceField,
                behavior: .forceField
            ),
        ],
        presentationMaterials: level.presentationMaterials + [
            .init(
                texture: stockReturnForceField,
                bitmapSourceName: "Alien Force Field_1.ogf",
                image: sourceForceFieldMaterial.image,
                blend: sourceForceFieldMaterial.blend,
                lightmapBlend: sourceForceFieldMaterial.lightmapBlend,
                waterProcedural: sourceForceFieldMaterial.waterProcedural,
                sourceArchive: sourceForceFieldMaterial.sourceArchive,
                sourceSHA256: String(repeating: "8", count: 64)
            ),
        ],
        dependencyManifest: .init(
            current: level.dependencyManifest.current + [
                .init(
                    category: "texture",
                    source: stockReturnForceField,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
            ],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    let cameraMonitorSource = SourceResource(
        storedIndex: 9_000,
        sourceName: "monitor.OOF"
    )
    let modelTemplate = level.models[0]
    let cameraMonitorModels = level.models.contains {
        $0.source == cameraMonitorSource
    }
        ? level.models
        : level.models + [
            .init(
                source: cameraMonitorSource,
                collisionRadius: 2,
                submodels: modelTemplate.submodels,
                bounds: modelTemplate.bounds,
                sourceArchive: modelTemplate.sourceArchive,
                sourceSHA256: String(repeating: "f", count: 64)
            ),
        ]
    level = replacing(
        level,
        models: cameraMonitorModels,
        objectPresentations: level.objectPresentations + [
            .init(
                objectHandle: 6_167,
                primaryModel: cameraMonitorSource,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil
            ),
        ],
        dependencyManifest: .init(
            current: level.dependencyManifest.current.map { dependency in
                guard dependency.category == "model",
                      dependency.source == cameraMonitorSource else {
                    return dependency
                }
                return .init(
                    category: dependency.category,
                    source: dependency.source,
                    state: "presentation-payload-imported",
                    provenance: dependency.provenance
                )
            } + (level.dependencyManifest.current.contains {
                $0.category == "model"
                    && $0.source == cameraMonitorSource
            } ? [] : [
                .init(
                    category: "model",
                    source: cameraMonitorSource,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
            ]),
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    if let pickupIndex = level.objects.firstIndex(where: {
        $0.handle == 6_167
    }) {
        level.objects[pickupIndex].location = player.location
        level.objects[pickupIndex].position = player.position
        level.objects[pickupIndex].orientation = player.orientation
    } else {
        level.objects.append(.init(
            handle: 6_167,
            type: 7,
            storedID: 91,
            definition: .init(
                storedIndex: 91,
                sourceName: "Camera Monitor"
            ),
            instanceName: "CameraMonitor",
            flags: 4_096,
            doorShields: nil,
            location: player.location,
            position: player.position,
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
    }
    if let cameraIndex = level.objects.firstIndex(where: {
        $0.handle == 6_183
    }) {
        level.objects[cameraIndex].location = player.location
        level.objects[cameraIndex].position = player.position
        level.objects[cameraIndex].orientation = player.orientation
    } else {
        level.objects.append(.init(
            handle: 6_183,
            type: 2,
            storedID: 114,
            definition: .init(
                storedIndex: 114,
                sourceName: "new wall cam"
            ),
            instanceName: "SecurityCamera",
            flags: 5_120,
            doorShields: nil,
            location: player.location,
            position: player.position,
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
    }
    level.objects.append(.init(
        handle: 10_245,
        type: 11,
        storedID: 205,
        definition: .init(
            storedIndex: 205,
            sourceName: "Blinking Red Light-DM"
        ),
        instanceName: "FlashLight-3",
        flags: 4_096,
        doorShields: nil,
        location: player.location,
        position: player.position,
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
    level = replacing(
        level,
        dependencyManifest: .init(
            current: level.dependencyManifest.current + [
                .init(
                    category: "object-definition",
                    source: .init(
                        storedIndex: 91,
                        sourceName: "Camera Monitor"
                    ),
                    state: "identity-recorded",
                    provenance: "synthetic canonical fixture"
                ),
                .init(
                    category: "object-definition",
                    source: .init(
                        storedIndex: 114,
                        sourceName: "new wall cam"
                    ),
                    state: "identity-recorded",
                    provenance: "synthetic canonical fixture"
                ),
                .init(
                    category: "object-definition",
                    source: .init(
                        storedIndex: 205,
                        sourceName: "Blinking Red Light-DM"
                    ),
                    state: "identity-recorded",
                    provenance: "synthetic canonical fixture"
                ),
            ].filter { candidate in
                !level.dependencyManifest.current.contains {
                    $0.category == candidate.category
                        && $0.source == candidate.source
                }
            },
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    if case let .room(playerRoomSourceIndex) = player.location,
       let playerRoomIndex = level.rooms.firstIndex(where: {
           $0.sourceIndex == playerRoomSourceIndex
       }) {
        level.rooms[playerRoomIndex] = addingSourceContainmentShell(
            to: level.rooms[playerRoomIndex],
            center: player.position,
            texture: level.surfacePhysics[0].texture,
            halfExtent: 500
        )
    }
    level = replacing(
        level,
        goals: level.goals + [
            .init(
                status: 1_028,
                priority: 0,
                list: 0,
                name: "Locate the Camera Monitor",
                itemName: "Camera Monitor",
                description: "Find and pickup the Camera Monitor",
                completionMessage: "",
                items: [
                    .init(
                        type: 2,
                        sourceHandle: 6_167,
                        objectHandle: 6_167,
                        done: false
                    ),
                ]
            ),
        ]
    )
    return level.addingTrainingCameraMonitorChain(
        .init(
            pickupObjectHandle: 6_167,
            securityCameraObjectHandle: 6_183,
            pickupCollisionRadius: 2,
            pickupMessage:
                "Excellent.  You now have the Camera Monitor.  Press the Use Inventory key to activate it!",
            pickupVoiceSourceName: "guidebotc.osf",
            pickupSoundSourceName: "PupC.wav",
            useMessage:
                "Now recall the Guidebot by pressing F4 and selecting \"Return to Ship\".  Move to the next area when he returns.",
            useVoiceSourceName: "guidebotd.osf",
            popupDuration: 10,
            popupZoom: 1,
            cameraGunpointIndex: 0,
            cameraLocalPosition: .zero,
            cameraLocalForward: .init(x: 0, y: 0, z: -1),
            completionTimerDuration: 2,
            returnToShip: .init(
                markerLightObjectHandle: 10_245,
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
                barrierRoomSourceIndex: 2,
                orderedPortalIndices: [0, 1],
                openMarkerLightDistance: 50,
                returnMessage: "GB: Returning to ship.",
                returnSoundSourceName: "GBotAcceptOrder.wav",
                arrivalMessage: "GB: Entering ship!",
                successMessage: "Excellent!",
                successVoiceSourceName: "proceed6.osf"
            )
        ),
        voiceClips: [
            syntheticVoiceClip(
                name: "guidebotc.osf",
                sourceEntryIndex: 6,
                sourceHash: "1"
            ),
            syntheticVoiceClip(
                name: "guidebotd.osf",
                sourceEntryIndex: 7,
                sourceHash: "2"
            ),
            syntheticVoiceClip(
                name: "proceed6.osf",
                sourceEntryIndex: 26,
                sourceHash: "4"
            ),
        ],
        soundClips: [
            .init(
                logicalName: "PupC1",
                sourceName: "PupC.wav",
                sourceEntryIndex: 3,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: Data(repeating: 0, count: 2),
                pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "3", count: 64),
                importVolume: 1
            ),
            .init(
                logicalName: "GBotAcceptOrder1",
                sourceName: "GBotAcceptOrder.wav",
                sourceEntryIndex: 1_257,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: Data(repeating: 0, count: 2),
                pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "5", count: 64),
                importVolume: 1
            ),
        ]
    )
}

func makeTrainingKillbotEntryLevel(
    followupDelay: Float = 13
) -> Level {
    let level = makeTrainingCameraMonitorLevel()
    let camera = level.trainingCameraMonitorChain!
    let returnChain = camera.returnToShip!
    let addedVoices = [
        syntheticVoiceClip(
            name: "intro6.osf",
            sourceEntryIndex: 25,
            sourceHash: "6"
        ),
        syntheticVoiceClip(
            name: "guidebotf.osf",
            sourceEntryIndex: 27,
            sourceHash: "7"
        ),
    ]
    let killbotEntry = TrainingKillbotEntryChain(
        triggerName: "Portal3",
        triggerRoomSourceIndex: returnChain.barrierRoomSourceIndex,
        triggerFaceIndex: 1,
        orderedPortalIndices: [1, 0],
        closedMarkerLightDistance: 0,
        entryMessage:
            "Now you are on your own in this room. There are 4 robots and 2 powerups. Get the powerups and kill the robots.",
        entryVoiceSourceName: "intro6.osf",
        followupDelay: followupDelay,
        followupMessage:
            "Some parts of this area are very dark.  Turn on your headlight or fire flares to see.  Use your guidebot if you need help finding a robot or powerup.",
        followupVoiceSourceName: "guidebotf.osf"
    )
    let updatedReturn = TrainingGuidebotReturnChain(
        markerLightObjectHandle: returnChain.markerLightObjectHandle,
        markerLightPresentation: returnChain.markerLightPresentation,
        barrierRoomSourceIndex: returnChain.barrierRoomSourceIndex,
        orderedPortalIndices: returnChain.orderedPortalIndices,
        openMarkerLightDistance: returnChain.openMarkerLightDistance,
        returnMessage: returnChain.returnMessage,
        returnSoundSourceName: returnChain.returnSoundSourceName,
        arrivalMessage: returnChain.arrivalMessage,
        successMessage: returnChain.successMessage,
        successVoiceSourceName: returnChain.successVoiceSourceName,
        killbotEntry: killbotEntry
    )
    let updatedCamera = TrainingCameraMonitorChain(
        pickupObjectHandle: camera.pickupObjectHandle,
        securityCameraObjectHandle: camera.securityCameraObjectHandle,
        pickupCollisionRadius: camera.pickupCollisionRadius,
        pickupMessage: camera.pickupMessage,
        pickupVoiceSourceName: camera.pickupVoiceSourceName,
        pickupSoundSourceName: camera.pickupSoundSourceName,
        useMessage: camera.useMessage,
        useVoiceSourceName: camera.useVoiceSourceName,
        popupDuration: camera.popupDuration,
        popupZoom: camera.popupZoom,
        cameraGunpointIndex: camera.cameraGunpointIndex,
        cameraLocalPosition: camera.cameraLocalPosition,
        cameraLocalForward: camera.cameraLocalForward,
        completionTimerDuration: camera.completionTimerDuration,
        returnToShip: updatedReturn
    )
    let trigger = LevelTrigger(
        name: killbotEntry.triggerName,
        roomIndex: killbotEntry.triggerRoomSourceIndex,
        faceIndex: killbotEntry.triggerFaceIndex,
        flags: 8,
        activator: 1
    )
    var rooms = level.rooms
    let triggerRoomIndex = rooms.firstIndex {
        $0.sourceIndex == killbotEntry.triggerRoomSourceIndex
    }!
    for faceIndex in [0, killbotEntry.triggerFaceIndex] {
        let triggerFace = rooms[triggerRoomIndex].faces[faceIndex]
        rooms[triggerRoomIndex].faces[faceIndex] = .init(
            corners: triggerFace.corners,
            flags: triggerFace.flags | 0x0010,
            portalIndex: triggerFace.portalIndex,
            texture: triggerFace.texture,
            lightmapInfoIndex: triggerFace.lightmapInfoIndex,
            allowsLightCorona: triggerFace.allowsLightCorona,
            lightMultiple: triggerFace.lightMultiple,
            special: triggerFace.special
        )
    }
    let gallery = level.trainingGalleryBarrier!
    let syntheticGallery = TrainingGalleryBarrier(
        triggerName: gallery.triggerName,
        triggerRoomSourceIndex: gallery.triggerRoomSourceIndex,
        triggerFaceIndex: 0,
        barrierRoomSourceIndex: gallery.barrierRoomSourceIndex,
        orderedPortalIndices: gallery.orderedPortalIndices,
        markerLightObjectHandle: gallery.markerLightObjectHandle,
        openMarkerLightDistance: gallery.openMarkerLightDistance,
        successMessage: gallery.successMessage,
        guidebotInstruction: gallery.guidebotInstruction,
        voiceSourceName: gallery.voiceSourceName
    )
    let triggers = level.triggers.map { candidate in
        candidate.name == gallery.triggerName
            ? .init(
                name: candidate.name,
                roomIndex: candidate.roomIndex,
                faceIndex: 0,
                flags: candidate.flags,
                activator: candidate.activator
            )
            : candidate
    } + [trigger]
    return replacing(
        level,
        rooms: rooms,
        triggers: triggers,
        surfacePhysics: level.surfacePhysics,
        trainingGalleryBarrier: syntheticGallery,
        trainingCameraMonitorChain: updatedCamera,
        voiceClips: level.voiceClips + addedVoices,
        dependencyManifest: .init(
            current: level.dependencyManifest.current
                + addedVoices.map {
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
                },
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
}

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
    return level.addingTrainingRASBot1DeathChain(.init(
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
    return level.addingTrainingRASBot2DeathChain(.init(
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
    return level.addingTrainingRASBot3DeathChain(.init(
        robotObjectHandle: 2_077,
        robotRoomSourceIndex: 42,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
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
    return level.addingTrainingRASBot4DeathChain(.init(
        robotObjectHandle: 2_078,
        robotRoomSourceIndex: 0,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
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
    return level.addingTrainingInvulnerabilityPickupChain(
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
    return lastRoomLevel.addingTrainingLastRoomChain(.init(
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
    return replacing(
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
    return level.addingTrainingLastBot1DeathChain(.init(
        robotObjectHandle: 4_127,
        robotRoomSourceIndex: 14,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
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
    return level.addingTrainingLastBot2DeathChain(.init(
        robotObjectHandle: 2_080,
        robotRoomSourceIndex: 46,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
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
    return level.addingTrainingLastBot3DeathChain(.init(
        robotObjectHandle: 2_081,
        robotRoomSourceIndex: 47,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
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
    return level.addingTrainingLastBot4DeathChain(.init(
        robotObjectHandle: 2_082,
        robotRoomSourceIndex: 47,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
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
    return level.addingTrainingLastBot5DeathChain(.init(
        robotObjectHandle: 2_083,
        robotRoomSourceIndex: 48,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
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
    return level.addingTrainingFinalBotsCompletionChain(
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
    return level.addingTrainingFinalGoalChain(.init(
        goalObjectHandle: goal.handle,
        goalRoomSourceIndex: 17,
        goalObjectFlags: goal.flags,
        goalCollisionRadius: Float(bitPattern: 0x40a0_84bf)
    ))
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
) throws -> PlayerSimulationContinuation {
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
    let initial = PlayerSimulation(
        level: level,
        presentationReadyTimestamp: 0
    )
    var object = try XCTUnwrap(
        JSONSerialization.jsonObject(
            with: JSONEncoder().encode(initial.continuation)
        ) as? [String: Any]
    )
    for key in [
        "trainingRASBot1DeathState",
        "trainingRASBot2DeathState",
        "trainingRASBot3DeathState",
        "trainingRASBot4DeathState",
    ] {
        object[key] = [
            "wasDestroyed": true,
            "shields": -5,
        ]
    }
    object["trainingInvulnerabilityPickupState"] = [
        "scriptWasTriggered": true,
        "wasConsumed": true,
    ]
    object["trainingCloakPickupState"] = [
        "scriptWasTriggered": true,
        "wasConsumed": true,
    ]
    object["trainingLastRoomState"] = [
        "wasTriggered": true,
        "markerLightDistance": 50,
        "timerRemaining": timerRemaining,
        "wasPresented": false,
    ]
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
    return try JSONDecoder().decode(
        PlayerSimulationContinuation.self,
        from: JSONSerialization.data(withJSONObject: object)
    )
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

private func syntheticVoiceClip(
    name: String,
    sourceEntryIndex: Int,
    sourceHash: Character
) -> CanonicalVoiceClip {
    .init(
        sourceName: name,
        sourceEntryIndex: sourceEntryIndex,
        sampleRate: 22_050,
        channelCount: 1,
        frameCount: 1,
        pcm16LittleEndian: Data(repeating: 0, count: 2),
        pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
        sourceArchive: "missions/training.mn3",
        sourceSHA256: String(repeating: sourceHash, count: 64)
    )
}

func makeTrainingGuidebotBlockedMovementLevel() -> Level {
    var level = makeTrainingRobotGuidebotLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let chain = level.trainingRobotGuidebotChain!
    level = replacing(
        level,
        trainingRobotGuidebotChain: .init(
            destroyRobotObjectHandle: chain.destroyRobotObjectHandle,
            guidebotObjectHandle: chain.guidebotObjectHandle,
            destroyRobotRoomSourceIndex:
                chain.destroyRobotRoomSourceIndex,
            destroyRobotFlags: chain.destroyRobotFlags,
            destructionDelay: chain.destructionDelay,
            destructionMessage: chain.destructionMessage,
            exitInstruction: chain.exitInstruction,
            destructionVoiceSourceName:
                chain.destructionVoiceSourceName,
            deployedGuidebotObjectType:
                chain.deployedGuidebotObjectType,
            deployedGuidebotMessage: chain.deployedGuidebotMessage,
            deployedGuidebotVoiceSourceName:
                chain.deployedGuidebotVoiceSourceName,
            combat: chain.combat,
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
    return level
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
