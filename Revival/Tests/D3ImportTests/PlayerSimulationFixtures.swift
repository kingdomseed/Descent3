import XCTest

func makePlayerYellowFlareLevel() throws -> Level {
    let level = makeTrainingGuidebotYellowFlareLevel()
    var ship = level.shipDefinitions[0]
    ship.playerYellowFlare = .init(
        batteryIndex: 20,
        firingMask: 1,
        weapon: .init(storedIndex: 3, sourceName: "Yellow flare"),
        fireSoundLogicalName: "Flare",
        fireSoundSourceName: "Flare.wav",
        fireWait: 1,
        energyUsage: 0,
        ammoUsage: 0,
        fireFlags: 0,
        weaponFlags: 0,
        gunpointIndex: 0,
        gunpointParentSubmodelIndex: 0,
        gunpointLocalPosition: .init(
            x: 0.000_000_444_4,
            y: -1.046_244_4,
            z: 3.179_825_1
        ),
        gunpointLocalForward: .init(
            x: 0.000_007_629_6,
            y: -0.000_015_258_7,
            z: 1
        )
    )
    return replacing(level, shipDefinitions: [ship])
}

func makePlayerConcussionLevel() throws -> Level {
    var level = try makePlayerYellowFlareLevel()
    let modelSource = SourceResource(
        storedIndex: level.models.count,
        sourceName: "ConcussionMissile.OOF"
    )
    let modelTemplate = level.models[0]
    let concussionModel = CanonicalModel(
        source: modelSource,
        collisionRadius: 1,
        submodels: modelTemplate.submodels,
        bounds: modelTemplate.bounds,
        sourceArchive: modelTemplate.sourceArchive,
        sourceSHA256: String(repeating: "c", count: 64)
    )
    let firstExplosionIndex = level.presentationMaterials.count
    let explosionFrames = [
        SourceResource(
            storedIndex: firstExplosionIndex,
            sourceName: "ExplosionE"
        ),
    ] + (1..<15).map {
        SourceResource(
            storedIndex: firstExplosionIndex,
            sourceName: "ExplosionE.oaf frame \($0)"
        )
    }
    let materialTemplate = level.presentationMaterials[0]
    let explosionMaterials = explosionFrames.map { frame in
        PresentationMaterial(
            texture: frame,
            bitmapSourceName: "ExplosionE.oaf",
            image: materialTemplate.image,
            blend: .additiveSourceAlpha(opacity: 255),
            lightmapBlend: .none,
            waterProcedural: nil,
            sourceArchive: materialTemplate.sourceArchive,
            sourceSHA256: String(repeating: "e", count: 64)
        )
    }
    let soundTemplate = level.soundClips[0]
    func sound(
        logicalName: String,
        sourceName: String,
        entryIndex: Int
    ) -> CanonicalSoundClip {
        .init(
            logicalName: logicalName,
            sourceName: sourceName,
            sourceEntryIndex: entryIndex,
            sampleRate: soundTemplate.sampleRate,
            channelCount: soundTemplate.channelCount,
            frameCount: soundTemplate.frameCount,
            pcm16LittleEndian: soundTemplate.pcm16LittleEndian,
            pcmSHA256: soundTemplate.pcmSHA256,
            sourceArchive: soundTemplate.sourceArchive,
            sourceSHA256: soundTemplate.sourceSHA256,
            importVolume: 1
        )
    }
    var ship = level.shipDefinitions[0]
    ship.playerConcussion = .init(
        batteryIndex: 10,
        firingMasks: [1, 2],
        weapon: .init(storedIndex: 10, sourceName: "Concussion"),
        model: modelSource,
        fireSoundLogicalNames: ["concmissilefire71", "concmissilefire71"],
        fireSoundSourceName: "concmissilefire7.wav",
        impactSoundLogicalName: "Explode1",
        impactSoundSourceName: "Explode1.wav",
        fireWaits: [0.5, 0.5],
        energyUsage: 0,
        ammoUsage: 1,
        fireFlags: 0,
        weaponFlags: 0,
        gunpoints: [
            .init(
                index: 1,
                parentSubmodelIndex: 0,
                localPosition: .init(
                    x: 2.792_412_5,
                    y: -1.186_958_9,
                    z: 2.687_090_9
                ),
                localForward: .init(
                    x: 0.000_007_629_434_5,
                    y: 0.000_003_337_758_7,
                    z: 1
                )
            ),
            .init(
                index: 2,
                parentSubmodelIndex: 0,
                localPosition: .init(
                    x: -2.804_046_4,
                    y: -1.186_885_0,
                    z: 2.687_135_2
                ),
                localForward: .init(
                    x: 0.000_008_106_278,
                    y: 0.000_003_814_590_4,
                    z: 1
                )
            ),
        ],
        collisionRadius: 1,
        speed: 175,
        lifetime: 15,
        rotationalVelocity: 35_000,
        lightDistance: 12.5,
        lightPresentation: .init(
            primaryColor: .init(x: 1, y: 0.5, z: 0),
            secondaryColor: .zero,
            timeInterval: 0,
            flickerDistance: 0,
            directionalDot: 0,
            flags: 0,
            timebits: 0,
            angle: 0,
            lightingRenderType: 0
        ),
        explosionFrames: explosionFrames,
        explosionSourceFrameTime: Float(0.5) / 15,
        explosionSize: 10,
        explosionLifetime: 0.5,
        directRobotDamage: 9,
        shockwaveDuration: 0.1,
        shockwaveRadius: 32,
        shockwaveDamage: 19,
        shockwaveForce: 3_000
    )
    let dependencies = [
        DependencyRecord(
            category: "model",
            source: modelSource,
            state: "presentation-payload-imported",
            provenance: "synthetic canonical fixture"
        ),
    ] + explosionFrames.map {
        DependencyRecord(
            category: "texture",
            source: $0,
            state: "presentation-payload-imported",
            provenance: "synthetic canonical fixture"
        )
    }
    level = replacing(
        level,
        presentationMaterials: level.presentationMaterials + explosionMaterials,
        models: level.models + [concussionModel],
        shipDefinitions: [ship],
        soundClips: level.soundClips + [
            sound(
                logicalName: "concmissilefire71",
                sourceName: "concmissilefire7.wav",
                entryIndex: 20_000
            ),
            sound(
                logicalName: "Explode1",
                sourceName: "Explode1.wav",
                entryIndex: 20_001
            ),
        ],
        dependencyManifest: .init(
            current: level.dependencyManifest.current + dependencies,
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    return level
}

func replacing(
    _ binding: PlayerConcussionBinding,
    gunpoints: [PlayerConcussionGunpoint]
) -> PlayerConcussionBinding {
    PlayerConcussionBinding(
        batteryIndex: binding.batteryIndex,
        firingMasks: binding.firingMasks,
        weapon: binding.weapon,
        model: binding.model,
        fireSoundLogicalNames: binding.fireSoundLogicalNames,
        fireSoundSourceName: binding.fireSoundSourceName,
        impactSoundLogicalName: binding.impactSoundLogicalName,
        impactSoundSourceName: binding.impactSoundSourceName,
        fireWaits: binding.fireWaits,
        energyUsage: binding.energyUsage,
        ammoUsage: binding.ammoUsage,
        fireFlags: binding.fireFlags,
        weaponFlags: binding.weaponFlags,
        gunpoints: gunpoints,
        collisionRadius: binding.collisionRadius,
        speed: binding.speed,
        lifetime: binding.lifetime,
        rotationalVelocity: binding.rotationalVelocity,
        lightDistance: binding.lightDistance,
        lightPresentation: binding.lightPresentation,
        explosionFrames: binding.explosionFrames,
        explosionSourceFrameTime: binding.explosionSourceFrameTime,
        explosionSize: binding.explosionSize,
        explosionLifetime: binding.explosionLifetime,
        directRobotDamage: binding.directRobotDamage,
        shockwaveDuration: binding.shockwaveDuration,
        shockwaveRadius: binding.shockwaveRadius,
        shockwaveDamage: binding.shockwaveDamage,
        shockwaveForce: binding.shockwaveForce
    )
}
func makeSliceTenContactLevel(clearance: Float = 20) -> Level {
    let level = makeSliceSixObjectRenderLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z + clearance
    let vertices = room.vertices + [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let contactRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
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
    var rooms = level.rooms
    rooms[roomIndex] = contactRoom
    return replacing(level, rooms: rooms)
}

func makeSliceThirteenWiggleLevel(blocked: Bool = false) -> Level {
    let base = makeSliceSixObjectRenderLevel()
    let radius = defaultPlayerView(in: base).collisionRadius
    let level = blocked
        ? makeSliceTenContactLevel(clearance: radius + 0.01)
        : base
    var objects = level.objects
    let playerIndex = objects.firstIndex { $0.handle == 2_048 }!
    objects[playerIndex].orientation = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 0, z: 1),
        forward: .init(x: 0, y: -1, z: 0)
    )
    return replacing(level, objects: objects)
}

func makeSliceThirteenPortalWiggleLevel() -> Level {
    let level = makeSliceThirteenWiggleLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z + 0.04
    let portalVertices = [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
    ]
    let corners = (0..<4).map {
        FaceCorner(
            vertexIndex: firstVertex + $0,
            u: 0,
            v: 0,
            alpha: 255
        )
    }
    let portalFace = LevelFace(
        corners: corners,
        flags: 0,
        portalIndex: room.portals.count,
        texture: room.faces[0].texture
    )
    let sourceRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: room.vertices + portalVertices,
        faces: room.faces + [portalFace],
        portals: room.portals + [
            .init(
                faceIndex: room.faces.count,
                connectedRoom: 99,
                connectedPortal: 0
            ),
        ],
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
    let connectedRoom = LevelRoom(
        sourceIndex: 99,
        vertices: portalVertices,
        faces: [
            .init(
                corners: corners.reversed().map {
                    FaceCorner(
                        vertexIndex: $0.vertexIndex - firstVertex,
                        u: $0.u,
                        v: $0.v,
                        alpha: $0.alpha
                    )
                },
                flags: 0,
                portalIndex: 0,
                texture: room.faces[0].texture
            ),
        ],
        portals: [
            .init(faceIndex: 0, connectedRoom: 1, connectedPortal: room.portals.count),
        ]
    )
    var rooms = level.rooms
    rooms[roomIndex] = sourceRoom
    rooms.append(connectedRoom)
    return replacing(level, rooms: rooms)
}

func makeSliceElevenCornerLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let x = player.position.x + clearance
    let vertices = room.vertices + [
        Vector3(x: x, y: player.position.y - 20, z: player.position.z - 20),
        Vector3(x: x, y: player.position.y - 20, z: player.position.z + 20),
        Vector3(x: x, y: player.position.y + 20, z: player.position.z + 20),
        Vector3(x: x, y: player.position.y + 20, z: player.position.z - 20),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let cornerRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
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
    var rooms = level.rooms
    rooms[roomIndex] = cornerRoom
    return replacing(level, rooms: rooms)
}

func makeSliceElevenForceFieldLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let texture = level.rooms.first { $0.sourceIndex == 1 }!.faces.last!.texture
    return replacing(
        level,
        surfacePhysics: level.surfacePhysics.map {
            $0.texture == texture
                ? .init(texture: $0.texture, behavior: .forceField)
                : $0
        }
    )
}

func makeSliceElevenTrappedLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z - clearance
    let vertices = room.vertices + [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let trappedRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
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
    var rooms = level.rooms
    rooms[roomIndex] = trappedRoom
    return replacing(level, rooms: rooms)
}
