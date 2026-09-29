import XCTest

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
    return rescriptedTrainingLevel(
        level
    )
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
    return rescriptedTrainingLevel(
        level
    )
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
    return rescriptedTrainingLevel(
        level.addingTrainingRobotGuidebotChain(
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
    )
}

func makeTrainingGuidebotYellowFlareLevel() -> Level {
    var level = makeTrainingRobotGuidebotLevel()
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    level.rooms[roomIndex] = addingSourceContainmentShell(
        to: room,
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
    return rescriptedTrainingLevel(
        replacing(
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
    return rescriptedTrainingLevel(
        level.addingTrainingCameraMonitorChain(
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
    return rescriptedTrainingLevel(
        replacing(
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
    )
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
