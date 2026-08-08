import XCTest

final class WorldRenderingTests: XCTestCase {}

extension Array {
    var only: Element? { count == 1 ? self[0] : nil }
}

func makeCoronaEvaluationLevel(
    blocked: Bool = false,
    objectBlocked: Bool = false,
    objectPresentationVisible: Bool = true
) -> Level {
    let base = makeMinimalCanonicalLevel()
    let light = SourceResource(storedIndex: 1, sourceName: "light")
    let blocker = SourceResource(storedIndex: 2, sourceName: "blocker")
    let candidateVertices = [
        Vector3(x: -1, y: 21, z: -1),
        Vector3(x: 1, y: 21, z: -1),
        Vector3(x: 1, y: 21, z: 1),
        Vector3(x: -1, y: 21, z: 1),
    ]
    let blockerVertices = [
        Vector3(x: -5, y: 10, z: -5),
        Vector3(x: 5, y: 10, z: -5),
        Vector3(x: 5, y: 10, z: 5),
        Vector3(x: -5, y: 10, z: 5),
    ]
    let corners = [
        FaceCorner(vertexIndex: 0, u: 0, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 1, u: 1, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 2, u: 1, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 3, u: 0, v: 1, alpha: 255),
    ]
    var faces = [
        LevelFace(
            corners: corners,
            flags: 0,
            portalIndex: nil,
            texture: light,
            allowsLightCorona: true
        ),
    ]
    var portals: [LevelPortal] = []
    if blocked {
        faces.append(
            LevelFace(
                corners: corners.map {
                    FaceCorner(
                        vertexIndex: $0.vertexIndex + 4,
                        u: $0.u,
                        v: $0.v,
                        alpha: $0.alpha
                    )
                },
                flags: 0,
                portalIndex: 0,
                texture: blocker
            )
        )
        portals.append(
            .init(flags: 1, faceIndex: 1, connectedRoom: 4, connectedPortal: 0)
        )
    }
    let room3 = LevelRoom(
        sourceIndex: 3,
        vertices: candidateVertices + blockerVertices,
        faces: faces,
        portals: portals
    )
    let room4 = LevelRoom(
        sourceIndex: 4,
        vertices: blockerVertices,
        faces: blocked ? [
            .init(
                corners: Array(corners.reversed()),
                flags: 0,
                portalIndex: 0,
                texture: blocker
            ),
        ] : [],
        portals: blocked ? [
            .init(flags: 1, faceIndex: 0, connectedRoom: 3, connectedPortal: 0),
        ] : []
    )
    let blockerModelSource = SourceResource(storedIndex: 3, sourceName: "blocker.oof")
    let blockerObject = PlacedObject(
        handle: 99,
        type: 2,
        storedID: 0,
        definition: nil,
        instanceName: nil,
        flags: 0,
        doorShields: nil,
        location: .room(3),
        position: .init(x: 0, y: 10, z: 0),
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
    )
    let blockerModel = CanonicalModel(
        source: blockerModelSource,
        collisionRadius: 2,
        submodels: [
            .init(
                sourceIndex: 0,
                parentIndex: nil,
                offset: .zero,
                vertices: [
                    .init(position: .init(x: -2, y: 0, z: -2), alpha: 1),
                    .init(position: .init(x: 2, y: 0, z: -2), alpha: 1),
                    .init(position: .init(x: 0, y: 0, z: 2), alpha: 1),
                ],
                faces: [],
                presentation: .standard
            ),
        ],
        bounds: .init(
            minimum: .init(x: -2, y: 0, z: -2),
            maximum: .init(x: 2, y: 0, z: 2)
        ),
        sourceArchive: "test.hog",
        sourceSHA256: String(repeating: "d", count: 64)
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: blocked ? [room3, room4] : [room3],
        terrain: base.terrain,
        objects: objectBlocked ? [blockerObject] : [],
        paths: [],
        goals: [],
        triggers: [],
        playerStartFlags: [],
        lightmaps: .init(pages: [], infos: []),
        presentationMaterials: [
            .init(
                texture: light,
                bitmapSourceName: "light.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                blend: .opaque,
                lightmapBlend: .none,
                waterProcedural: nil,
                lightCorona: .init(
                    assetIndex: 0,
                    tint: .init(x: 0.25, y: 0.5, z: 0.75),
                    blend: .additiveSourceAlpha(opacity: 102)
                ),
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "a", count: 64)
            ),
            .init(
                texture: blocker,
                bitmapSourceName: "blocker.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                blend: .opaque,
                lightmapBlend: .none,
                waterProcedural: nil,
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "b", count: 64)
            ),
        ],
        presentationCoronaAssets: [
            .init(
                source: .init(storedIndex: 0, sourceName: "flare"),
                bitmapSourceName: "flare.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "c", count: 64)
            ),
        ],
        models: objectBlocked ? [blockerModel] : [],
        objectPresentations: objectBlocked ? [
            .init(
                objectHandle: blockerObject.handle,
                primaryModel: blockerModelSource,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil,
                isVisible: objectPresentationVisible
            ),
        ] : [],
        dependencyManifest: .init(current: [], historicalEagerBaseline: nil),
        sourceChunks: base.sourceChunks
    )
}

func makeSourceContainmentRoom(
    center: Vector3,
    texture: SourceResource,
    sourceIndex: Int = 3,
    halfExtent: Float = 1
) -> LevelRoom {
    let vertices = [
        Vector3(
            x: center.x - halfExtent,
            y: center.y - halfExtent,
            z: center.z - halfExtent
        ),
        Vector3(
            x: center.x + halfExtent,
            y: center.y - halfExtent,
            z: center.z - halfExtent
        ),
        Vector3(
            x: center.x + halfExtent,
            y: center.y + halfExtent,
            z: center.z - halfExtent
        ),
        Vector3(
            x: center.x - halfExtent,
            y: center.y + halfExtent,
            z: center.z - halfExtent
        ),
        Vector3(
            x: center.x - halfExtent,
            y: center.y - halfExtent,
            z: center.z + halfExtent
        ),
        Vector3(
            x: center.x + halfExtent,
            y: center.y - halfExtent,
            z: center.z + halfExtent
        ),
        Vector3(
            x: center.x + halfExtent,
            y: center.y + halfExtent,
            z: center.z + halfExtent
        ),
        Vector3(
            x: center.x - halfExtent,
            y: center.y + halfExtent,
            z: center.z + halfExtent
        ),
    ]
    func face(_ indices: [Int]) -> LevelFace {
        LevelFace(
            corners: indices.enumerated().map { index, vertexIndex in
                FaceCorner(
                    vertexIndex: vertexIndex,
                    u: index == 1 || index == 2 ? 1 : 0,
                    v: index >= 2 ? 1 : 0,
                    alpha: 255
                )
            },
            flags: 0,
            portalIndex: nil,
            texture: texture
        )
    }
    return LevelRoom(
        sourceIndex: sourceIndex,
        vertices: vertices,
        faces: [
            face([0, 3, 7, 4]),
            face([1, 5, 6, 2]),
            face([0, 4, 5, 1]),
            face([3, 2, 6, 7]),
            face([0, 1, 2, 3]),
            face([4, 7, 6, 5]),
        ],
        portals: []
    )
}

func addingSourceContainmentShell(
    to room: LevelRoom,
    center: Vector3,
    texture: SourceResource,
    halfExtent: Float
) -> LevelRoom {
    let shell = makeSourceContainmentRoom(
        center: center,
        texture: texture,
        sourceIndex: room.sourceIndex,
        halfExtent: halfExtent
    )
    let vertexOffset = room.vertices.count
    let shellFaces = shell.faces.map { face in
        LevelFace(
            corners: face.corners.map {
                .init(
                    vertexIndex: $0.vertexIndex + vertexOffset,
                    u: $0.u,
                    v: $0.v,
                    alpha: $0.alpha
                )
            },
            flags: face.flags,
            portalIndex: nil,
            texture: face.texture
        )
    }
    return LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: room.vertices + shell.vertices,
        faces: room.faces + shellFaces,
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
}

func alienForceFieldWaterDefinition() -> WaterProceduralDefinition {
    let raw: [(WaterProceduralElementKind, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)] = [
        (.heightBlob, 20, 40, 100, 127, 58, 186, 13),
        (.heightBlob, 20, 40, 100, 0, 59, 13, 240),
        (.heightBlob, 20, 40, 100, 0, 58, 240, 173),
        (.heightBlob, 20, 40, 100, 62, 1, 173, 186),
        (.heightBlob, 20, 40, 100, 62, 126, 186, 13),
        (.heightBlob, 20, 40, 100, 62, 3, 13, 240),
        (.noOp, 0, 1, 1, 91, 38, 240, 173),
    ]
    return WaterProceduralDefinition(
        evaluationIntervalSeconds: 0,
        lightingShift: 7,
        dampingShift: 6,
        elements: raw.map {
            WaterProceduralElement(
                kind: $0.0,
                frequency: $0.1,
                speed: $0.2,
                size: $0.3,
                x1: $0.4,
                y1: $0.5,
                x2: $0.6,
                y2: $0.7
            )
        }
    )
}

func makeSelectedRoomRenderLevel() -> Level {
    let base = makeMinimalCanonicalLevel()
    let forceField = SourceResource(storedIndex: 3, sourceName: "force-field")
    let wall = SourceResource(storedIndex: 0, sourceName: "wall")
    let quad = [
        FaceCorner(vertexIndex: 0, u: 1, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 1, u: 0, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 2, u: 0, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 3, u: 1, v: 0, alpha: 255),
    ]
    let reversedQuad = [quad[3], quad[2], quad[1], quad[0]]
    let forwardVertices = [
        Vector3(x: 1, y: 2, z: 1),
        Vector3(x: -1, y: 2, z: 1),
        Vector3(x: -1, y: 2, z: -1),
        Vector3(x: 1, y: 2, z: -1),
        Vector3(x: 0.5, y: 4, z: 0.5),
        Vector3(x: -0.5, y: 4, z: 0.5),
        Vector3(x: -0.5, y: 4, z: -0.5),
        Vector3(x: 0.5, y: 4, z: -0.5),
        Vector3(x: 0.5, y: 6, z: 0.5),
        Vector3(x: -0.5, y: 6, z: 0.5),
        Vector3(x: -0.5, y: 6, z: -0.5),
        Vector3(x: 0.5, y: 6, z: -0.5),
        Vector3(x: 1, y: -2, z: 1),
        Vector3(x: -1, y: -2, z: 1),
        Vector3(x: -1, y: -2, z: -1),
        Vector3(x: 1, y: -2, z: -1),
    ]
    func corners(_ offset: Int, reversed: Bool = false) -> [FaceCorner] {
        let source = reversed ? reversedQuad : quad
        return source.map {
            FaceCorner(
                vertexIndex: $0.vertexIndex + offset,
                u: $0.u,
                v: $0.v,
                alpha: $0.alpha
            )
        }
    }
    let room2 = LevelRoom(
        sourceIndex: 2,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(4), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(0, reversed: true), flags: 0, portalIndex: 1, texture: forceField),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 1, connectedPortal: 0),
            .init(flags: 1, faceIndex: 1, connectedRoom: 3, connectedPortal: 0),
        ]
    )
    let room3 = LevelRoom(
        sourceIndex: 3,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(0), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(12, reversed: true), flags: 0, portalIndex: 1, texture: forceField),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 2, connectedPortal: 1),
            .init(faceIndex: 1, connectedRoom: 4, connectedPortal: 0),
        ]
    )
    let room1 = LevelRoom(
        sourceIndex: 1,
        vertices: forwardVertices + [
            Vector3(x: 12, y: 6, z: 0.5),
            Vector3(x: 10, y: 6, z: 0.5),
            Vector3(x: 10, y: 6, z: -0.5),
            Vector3(x: 12, y: 6, z: -0.5),
        ],
        faces: [
            .init(corners: corners(4, reversed: true), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(8), flags: 0, portalIndex: nil, texture: wall),
            .init(corners: corners(16), flags: 0, portalIndex: nil, texture: wall),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 2, connectedPortal: 0),
        ]
    )
    let room4 = LevelRoom(
        sourceIndex: 4,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(12), flags: 0, portalIndex: 0, texture: forceField),
        ],
        portals: [.init(faceIndex: 0, connectedRoom: 3, connectedPortal: 1)]
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: [room1, room2, room3, room4],
        terrain: base.terrain,
        objects: [],
        paths: [],
        goals: [],
        triggers: [],
        playerStartFlags: [],
        lightmaps: .init(pages: [], infos: []),
        surfacePhysics: [
            .init(texture: wall, behavior: .blocking),
            .init(texture: forceField, behavior: .forceField),
        ],
        presentationMaterials: [
            .init(
                texture: forceField,
                bitmapSourceName: "force-field.ogf",
                image: .init(
                    width: 128,
                    height: 128,
                    rgba8: Data(repeating: 255, count: 128 * 128 * 4)
                ),
                blend: .additiveSourceAlpha(opacity: 178),
                lightmapBlend: .none,
                waterProcedural: alienForceFieldWaterDefinition(),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "a", count: 64)
            ),
            .init(
                texture: wall,
                bitmapSourceName: "wall.ogf",
                image: .init(
                    width: 2,
                    height: 2,
                    rgba8: Data(repeating: 255, count: 16)
                ),
                blend: .opaque,
                lightmapBlend: .multiply,
                waterProcedural: nil,
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "b", count: 64)
            ),
        ],
        dependencyManifest: .init(
            current: [
                .init(
                    category: "texture",
                    source: wall,
                    state: "presentation-payload-imported",
                    provenance: "test"
                ),
                .init(category: "texture", source: forceField, state: "presentation-payload-imported", provenance: "test"),
            ],
            historicalEagerBaseline: nil
        ),
        sourceChunks: base.sourceChunks
    )
}

func makeSliceSixObjectRenderLevel() -> Level {
    let base = makeSelectedRoomRenderLevel()
    let cameraOrigin = RoomCamera.trainingRoom3.position
    func translated(_ point: Vector3) -> Vector3 {
        .init(
            x: point.x + cameraOrigin.x,
            y: point.y + cameraOrigin.y,
            z: point.z + cameraOrigin.z
        )
    }
    let rooms = base.rooms.map { room in
        LevelRoom(
            sourceIndex: room.sourceIndex,
            name: room.name,
            pathPoint: translated(room.pathPoint),
            vertices: room.vertices.map(translated),
            faces: room.faces,
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
    }
    let modelTexture = SourceResource(storedIndex: 50, sourceName: "model-surface")
    let modelSources = [
        SourceResource(storedIndex: 0, sourceName: "PyroGL.OOF"),
        SourceResource(storedIndex: 1, sourceName: "PyroGLMed.OOF"),
        SourceResource(storedIndex: 2, sourceName: "PyroGLLo.OOF"),
        SourceResource(storedIndex: 3, sourceName: "PyroDeath.OOF"),
        SourceResource(storedIndex: 4, sourceName: "invisiblepowerup.OOF"),
    ]
    let shipSource = SourceResource(storedIndex: 0, sourceName: "Pyro-GL")
    let modelVertices = [
        ModelVertex(
            position: .init(x: -5, y: 0, z: -0.4),
            alpha: 1
        ),
        ModelVertex(
            position: .init(x: 5, y: 0, z: -0.4),
            alpha: 1
        ),
        ModelVertex(
            position: .init(x: 0, y: 0, z: 0.4),
            alpha: 1
        ),
    ]
    let modelCorners = [
        ModelFaceCorner(vertexIndex: 0, u: 0, v: 0),
        ModelFaceCorner(vertexIndex: 1, u: 1, v: 0),
        ModelFaceCorner(vertexIndex: 2, u: 0.5, v: 1),
    ]
    let models = modelSources.map { source in
        CanonicalModel(
            source: source,
            collisionRadius: source == modelSources[0]
                ? Float(bitPattern: 0x40d9_5869)
                : 1,
            submodels: [
                .init(
                    sourceIndex: 0,
                    parentIndex: 1,
                    offset: .zero,
                    vertices: modelVertices,
                    faces: [
                        .init(
                            normal: .init(x: 0, y: -1, z: 0),
                            corners: modelCorners,
                            material: .texture(modelTexture)
                        ),
                        .init(
                            normal: .init(x: 0, y: 1, z: 0),
                            corners: Array(modelCorners.reversed()),
                            material: .sourceColor(red: 32, green: 64, blue: 96)
                        ),
                    ],
                    presentation: .standard
                ),
                .init(
                    sourceIndex: 1,
                    parentIndex: nil,
                    offset: .init(x: 3, y: 0, z: 0),
                    vertices: [],
                    faces: [],
                    presentation: .standard
                ),
                .init(
                    sourceIndex: 2,
                    parentIndex: nil,
                    offset: .init(x: 3, y: 0, z: 0),
                    vertices: modelVertices,
                    faces: [
                        .init(
                            normal: .init(x: 0, y: -1, z: 0),
                            corners: modelCorners,
                            material: .sourceColor(red: 255, green: 0, blue: 255)
                        ),
                    ],
                    presentation: .custom
                ),
                .init(
                    sourceIndex: 3,
                    parentIndex: nil,
                    offset: .init(x: 3, y: 0, z: 0),
                    vertices: modelVertices,
                    faces: [
                        .init(
                            normal: .init(x: 0, y: -1, z: 0),
                            corners: modelCorners,
                            material: .texture(modelTexture)
                        ),
                    ],
                    presentation: .facing
                ),
                .init(
                    sourceIndex: 4,
                    parentIndex: nil,
                    offset: .init(x: 3, y: 0, z: 0),
                    vertices: modelVertices,
                    faces: [
                        .init(
                            normal: .init(x: 0, y: 1, z: 0),
                            corners: modelCorners,
                            material: .texture(modelTexture)
                        ),
                    ],
                    presentation: .rotate(
                        rate: 1,
                        axis: .init(x: 0, y: 1, z: 0)
                    )
                ),
            ],
            bounds: .init(
                minimum: .init(x: -2, y: 0, z: -0.4),
                maximum: .init(x: 8, y: 0, z: 0.4)
            ),
            sourceArchive: base.source.profileFiles[0].relativePath,
            sourceSHA256: String(repeating: "e", count: 64)
        )
    }
    let identity = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: 1)
    )
    let invisibleDefinition = SourceResource(
        storedIndex: 67,
        sourceName: "Invisiblepowerup"
    )
    func object(
        handle: UInt32,
        type: UInt8,
        storedID: Int,
        name: String?,
        room: Int,
        position: Vector3
    ) -> PlacedObject {
        PlacedObject(
            handle: handle,
            type: type,
            storedID: storedID,
            definition: type == 7 ? invisibleDefinition : nil,
            instanceName: name,
            flags: 0,
            doorShields: nil,
            location: .room(room),
            position: position,
            orientation: identity,
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
    }
    let objects = [
        object(handle: 2_048, type: 4, storedID: 0, name: nil, room: 1,
               position: .init(x: 2_060.6497, y: -131.22517, z: 2_204.4216)),
        object(handle: 6_147, type: 7, storedID: 67, name: "StartCourse", room: 3,
               position: .init(x: 2_061.4604, y: -230.09009, z: 2_203.0276)),
        object(handle: 2_052, type: 4, storedID: 2, name: nil, room: 1,
               position: .init(x: 1_962.3759, y: -130.63771, z: 2_206.575)),
        object(handle: 18_441, type: 7, storedID: 67, name: "UpGoal", room: 1,
               position: .init(x: 2_060.6682, y: -25.897497, z: 2_204.6843)),
        object(handle: 12_299, type: 7, storedID: 67, name: "LeftGoal", room: 1,
               position: .init(x: 1_958.2805, y: -131.22517, z: 2_205.8071)),
        object(handle: 12_300, type: 7, storedID: 67, name: "StartGoal", room: 1,
               position: .init(x: 2_062.7678, y: -134.19601, z: 2_201.679)),
        object(handle: 12_301, type: 7, storedID: 67, name: "ForwardGoal", room: 1,
               position: .init(x: 2_060.4836, y: -131.22517, z: 2_310.928)),
    ]
    let pyroPresentation = ObjectPresentationReference(
        objectHandle: 2_048,
        primaryModel: modelSources[0],
        mediumModel: modelSources[1],
        lowModel: modelSources[2],
        dyingModel: modelSources[3],
        mediumDistance: 75,
        lowDistance: 100
    )
    let objectPresentations = [pyroPresentation,
        .init(
            objectHandle: 2_052,
            primaryModel: modelSources[0],
            mediumModel: modelSources[1],
            lowModel: modelSources[2],
            dyingModel: modelSources[3],
            mediumDistance: 75,
            lowDistance: 100
        ),
    ] + objects.filter { $0.type == 7 }.map {
        ObjectPresentationReference(
            objectHandle: $0.handle,
            primaryModel: modelSources[4],
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        )
    }
    let modelMaterial = PresentationMaterial(
        texture: modelTexture,
        bitmapSourceName: "model-surface.ogf",
        image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 128])),
        blend: .sourceAlpha(opacity: 255),
        lightmapBlend: .none,
        waterProcedural: nil,
        sourceArchive: base.source.profileFiles[0].relativePath,
        sourceSHA256: String(repeating: "f", count: 64)
    )
    let dependencies = base.dependencyManifest.current + [
        DependencyRecord(
            category: "object-definition",
            source: invisibleDefinition,
            state: "identity-recorded",
            provenance: "synthetic Slice 6 fixture"
        ),
        DependencyRecord(
            category: "texture",
            source: modelTexture,
            state: "presentation-payload-imported",
            provenance: "synthetic Slice 6 fixture"
        ),
    ] + modelSources.map {
        DependencyRecord(
            category: "model",
            source: $0,
            state: "presentation-payload-imported",
            provenance: "synthetic Slice 6 fixture"
        )
    } + [
        DependencyRecord(
            category: "ship-definition",
            source: shipSource,
            state: "canonical-typed-definition",
            provenance: "synthetic Slice 9 fixture"
        ),
    ]
    let ship = CanonicalShipDefinition(
        source: shipSource,
        primaryModel: modelSources[0],
        presentationSize: 6.676084041595459,
        physics: .init(
            mass: 30,
            drag: 90,
            fullThrust: 5_400,
            behaviors: [.turnroll, .wiggle, .usesThrust],
            rotationalDrag: 225,
            fullRotationalThrust: 6_860_000,
            numberOfBounces: -1,
            initialForwardVelocity: 0,
            initialAngularVelocity: .zero,
            wiggleAmplitude: 0.17,
            wigglesPerSecond: 0.9,
            coefficientOfRestitution: 1,
            hitDieDot: -1,
            maximumTurnrollRate: 8_000,
            turnrollRatio: 0.13
        )
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: rooms,
        terrain: base.terrain,
        objects: objects,
        paths: base.paths,
        goals: base.goals,
        triggers: base.triggers,
        playerStartFlags: [0, 0],
        lightmaps: base.lightmaps,
        surfacePhysics: base.surfacePhysics,
        presentationMaterials: base.presentationMaterials + [modelMaterial],
        models: models,
        shipDefinitions: [ship],
        defaultPlayerBinding: .init(
            playerID: 0,
            objectHandle: 2_048,
            ship: shipSource
        ),
        objectPresentations: objectPresentations,
        dependencyManifest: .init(
            current: dependencies,
            historicalEagerBaseline: nil
        ),
        sourceChunks: base.sourceChunks
    )
}

func makeFastPlayerHeadlightLevel(
    includesVisibleObject: Bool = true,
    halfExtent: Float = 400
) -> Level {
    var level = makeSliceSixObjectRenderLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    level.rooms = [
        makeSourceContainmentRoom(
            center: player.position,
            texture: level.surfacePhysics[0].texture,
            sourceIndex: 1,
            halfExtent: halfExtent
        ),
    ]
    level.objects.removeAll {
        $0.handle != 2_048
            && (!includesVisibleObject || $0.handle != 12_301)
    }
    let retainedHandles = Set(level.objects.map(\.handle))
    level.objectPresentations.removeAll {
        !retainedHandles.contains($0.objectHandle)
    }
    return level
}
