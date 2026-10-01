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
    // FollowBot1's page: a flying robot with AI.
    level = level.addingObjectInfo(fixtureFlyerInfo)
    return rescriptedTrainingLevel(
        level
    )
}

func makeTrainingMovingTargetHandoffLevel() -> Level {
    var level = makeTrainingManeuverFollowLevel()
    let gyro = try! XCTUnwrap(
        level.objectPresentations.first { $0.objectHandle == 8_200 }?
            .primaryModel
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
                isVisible: true
            ),
            .init(
                objectHandle: 4_113,
                primaryModel: gyro,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil,
                isVisible: true
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
    // The blue laser model is the player's laser weapon's model.
    return rescriptedTrainingLevel(
        level
    ).addingFixturePlayerWeapons()
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
    // DestroyBot2's page: a destroyable RAS1 flyer (no AI here).
    level = level.addingObjectInfo(fixtureTargetRobotInfo)
    return rescriptedTrainingLevel(
        level.addingTrainingRobotGuidebotChain(
            .init(
                guidebotObjectHandle: 6_164,
                deployedGuidebotObjectType: 2,
                deployedGuidebotMessage:
                    "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
                deployedGuidebotVoiceSourceName: "guidebotb.osf",
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
    ).addingFixturePlayerWeapons()
}

/// The Training Guide-Bot level in a large shell around room 1, with the
/// player there and the Yellow flare weapons (`addingFixtureYellowFlare`).
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
    return rescriptedTrainingLevel(level.addingFixtureYellowFlare())
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
    // The Camera Monitor's page: OIF_INVEN_SELECTABLE and
    // OIF_INVEN_NOREMOVE, as the retail page.
    level = level.addingObjectInfo(CanonicalObjectInfo(
        name: "Camera Monitor",
        type: 7,
        flags: 0x4a,
        size: 2,
        hitPoints: 100,
        lightDistance: 0,
        lighting: fixtureNoLight,
        ai: nil,
        weaponBatteries: []
    ))
    // Package schema 10 carried the Camera Monitor's streams and sounds.
    level = replacing(level, schemaVersion: 10)
    return rescriptedTrainingLevel(
        addingFixtureAudio(
            level,
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

/// The Camera Monitor level with the KillBot room entry: the Portal3
/// trigger on face 1 of PortalRoom5 (source room 2 here), whose
/// TriggerScript_0001 runs Script 042 (TrainingMission.cpp:2347), and the
/// streams of Scripts 042 and 039. Portal2 moves to face 0 of its room.
func makeTrainingKillbotEntryLevel() -> Level {
    let level = makeTrainingCameraMonitorLevel()
    let barrierRoomSourceIndex = 2
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
    let trigger = LevelTrigger(
        name: "Portal3",
        roomIndex: barrierRoomSourceIndex,
        faceIndex: 1,
        flags: 8,
        activator: 1
    )
    var rooms = level.rooms
    let triggerRoomIndex = rooms.firstIndex {
        $0.sourceIndex == barrierRoomSourceIndex
    }!
    for faceIndex in [0, trigger.faceIndex] {
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
        addingFixtureAudio(
            replacing(
                level,
                rooms: rooms,
                triggers: triggers,
                surfacePhysics: level.surfacePhysics,
                trainingGalleryBarrier: syntheticGallery
            ),
            voiceClips: addedVoices
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
