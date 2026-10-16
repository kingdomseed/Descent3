import XCTest

// The minimal canonical levels and the field-replacing helpers of the
// level and package tests.

func assertValidationError(
    _ expected: LevelValidationError,
    _ level: Level,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertThrowsError(try level.validate(), file: file, line: line) { error in
        XCTAssertEqual(error as? LevelValidationError, expected, file: file, line: line)
    }
}

func overwriteCanonicalPackageLevel(_ level: Level, at packageURL: URL) throws {
    let levelData = try canonicalJSONData(level)
    try overwriteCanonicalPackageLevelData(
        levelData, identity: level, at: packageURL
    )
}

func overwriteCanonicalPackageLevelData(
    _ levelData: Data, identity level: Level, at packageURL: URL
) throws {
    let manifestURL = packageURL.appending(path: "content.json")
    let currentManifest = try JSONDecoder().decode(
        CanonicalPackageManifest.self, from: Data(contentsOf: manifestURL)
    )
    let currentLevel = currentManifest.levels[0]
    let manifest = CanonicalPackageManifest(
        packageSchemaVersion: currentManifest.packageSchemaVersion,
        importerContractVersion: currentManifest.importerContractVersion,
        profileIdentifier: level.source.profileIdentifier,
        acceptedSourceFiles: level.source.profileFiles,
        campaigns: currentManifest.campaigns,
        levels: [
            .init(
                levelKey: currentLevel.levelKey,
                relativePath: currentLevel.relativePath,
                sha256: canonicalSHA256(levelData)
            ),
        ],
        translatedFeatureCoverage: currentManifest.translatedFeatureCoverage,
        deferredFeatureCoverage: currentManifest.deferredFeatureCoverage,
        source: level.source,
        sourceEntries: level.sourceChunks,
        currentDependencies: level.dependencyManifest.current,
        rights: currentManifest.rights
    )

    try levelData.write(
        to: packageURL.appending(path: "levels/\(level.levelKey)/level.json")
    )
    try canonicalJSONData(manifest).write(to: manifestURL)
}

func replacing(
    _ level: Level, schemaVersion: Int? = nil, missionKey: String? = nil,
    levelKey: String? = nil, source: LevelSource? = nil,
    metadata: LevelMetadata? = nil, rooms: [LevelRoom]? = nil,
    terrain: LevelTerrain? = nil, objects: [PlacedObject]? = nil,
    retiredObjectHandles: [UInt32]? = nil, paths: [GamePath]? = nil,
    goals: [LevelGoal]? = nil, triggers: [LevelTrigger]? = nil,
    playerStartFlags: [UInt32]? = nil,
    indoorNavigation: IndoorNavigationGraph? = nil,
    lightmaps: LightmapCatalog? = nil,
    surfacePhysics: [SurfacePhysicsEntry]? = nil,
    presentationMaterials: [PresentationMaterial]? = nil,
    presentationCoronaAssets: [PresentationCoronaAsset]? = nil,
    models: [CanonicalModel]? = nil,
    shipDefinitions: [CanonicalShipDefinition]? = nil,
    defaultPlayerBinding: DefaultPlayerBinding? = nil,
    objectPresentations: [ObjectPresentationReference]? = nil,
    voiceClips: [CanonicalVoiceClip]? = nil,
    soundClips: [CanonicalSoundClip]? = nil,
    dependencyManifest: DependencyManifest? = nil,
    sourceChunks: [SourceChunkRecord]? = nil
) -> Level {
    var replaced = Level(
        schemaVersion: schemaVersion ?? level.schemaVersion,
        missionKey: missionKey ?? level.missionKey,
        levelKey: levelKey ?? level.levelKey,
        source: source ?? level.source,
        metadata: metadata ?? level.metadata,
        rooms: rooms ?? level.rooms,
        terrain: terrain ?? level.terrain,
        objects: objects ?? level.objects,
        retiredObjectHandles: retiredObjectHandles ?? level.retiredObjectHandles,
        paths: paths ?? level.paths,
        goals: goals ?? level.goals,
        goalFlags: level.goalFlags,
        triggers: triggers ?? level.triggers,
        playerStartFlags: playerStartFlags ?? level.playerStartFlags,
        indoorNavigation: indoorNavigation ?? level.indoorNavigation,
        lightmaps: lightmaps ?? level.lightmaps,
        surfacePhysics: surfacePhysics ?? rooms.map { candidateRooms in
            Set(candidateRooms.flatMap { $0.faces.map(\.texture) }).sorted {
                if $0.storedIndex != $1.storedIndex {
                    return $0.storedIndex < $1.storedIndex
                }
                return $0.sourceName < $1.sourceName
            }.map { .init(texture: $0, behavior: .blocking) }
        } ?? level.surfacePhysics,
        presentationMaterials: presentationMaterials ?? level.presentationMaterials,
        presentationCoronaAssets: presentationCoronaAssets ?? level.presentationCoronaAssets,
        models: models ?? level.models,
        shipDefinitions: shipDefinitions ?? level.shipDefinitions,
        defaultPlayerBinding: defaultPlayerBinding ?? level.defaultPlayerBinding,
        objectPresentations: objectPresentations ?? level.objectPresentations,
        voiceClips: voiceClips ?? level.voiceClips,
        soundClips: soundClips ?? level.soundClips,
        dependencyManifest: dependencyManifest ?? level.dependencyManifest,
        sourceChunks: sourceChunks ?? level.sourceChunks
    )
    replaced.missionName = level.missionName
    replaced.objectInfos = level.objectInfos
    replaced.weapons = level.weapons
    replaced.gameModules = level.gameModules
    replaced.boaTables = level.boaTables
    // A scripted package keeps the level's script data, bound again to the
    // replaced objects and clips.
    return replaced.schemaVersion == Level.scriptedSchemaVersion
        && level.scripting != nil
        ? rescriptedTrainingLevel(replaced.preservingScripting(of: level))
        : replaced
}

func replacing(
    _ source: LevelSource, profileIdentifier: String? = nil,
    profileFiles: [SourceFileFingerprint]? = nil, archiveSHA256: String? = nil,
    levelSHA256: String? = nil, archiveEntryOffset: Int? = nil,
    archiveEntryByteCount: Int? = nil, referenceChecksum: String? = nil,
    referenceChecksumBasis: String? = nil
) -> LevelSource {
    LevelSource(
        profileIdentifier: profileIdentifier ?? source.profileIdentifier,
        profileFiles: profileFiles ?? source.profileFiles,
        archiveSHA256: archiveSHA256 ?? source.archiveSHA256,
        levelSHA256: levelSHA256 ?? source.levelSHA256,
        d3lvVersion: source.d3lvVersion,
        archiveEntryName: source.archiveEntryName,
        archiveEntryOffset: archiveEntryOffset ?? source.archiveEntryOffset,
        archiveEntryByteCount: archiveEntryByteCount ?? source.archiveEntryByteCount,
        referenceChecksum: referenceChecksum ?? source.referenceChecksum,
        referenceChecksumBasis: referenceChecksumBasis ?? source.referenceChecksumBasis
    )
}

func replacing(
    _ portal: LevelPortal, flags: UInt32? = nil, pathPoint: Vector3? = nil,
    combineMaster: Int? = nil
) -> LevelPortal {
    LevelPortal(
        flags: flags ?? portal.flags, faceIndex: portal.faceIndex,
        connectedRoom: portal.connectedRoom,
        connectedPortal: portal.connectedPortal,
        boundaryNodeIndex: portal.boundaryNodeIndex,
        pathPoint: pathPoint ?? portal.pathPoint,
        combineMaster: combineMaster ?? portal.combineMaster
    )
}

func replacing(_ terrain: LevelTerrain, sky: TerrainSky) -> LevelTerrain {
    LevelTerrain(
        heights: terrain.heights, textureCells: terrain.textureCells,
        flags: terrain.flags, light: terrain.light, red: terrain.red,
        green: terrain.green, blue: terrain.blue,
        dynamicLight: terrain.dynamicLight,
        occlusionChecksum: terrain.occlusionChecksum,
        occlusionMap: terrain.occlusionMap, sky: sky
    )
}

func makePlacedObject(
    handle: UInt32 = 2_048,
    type: UInt8 = 6,
    storedID: Int = 0,
    definition: SourceResource? = nil,
    location: SpatialLocation = .room(2),
    position: Vector3 = .zero,
    orientation: Matrix3 = .init(
        right: .init(x: 1, y: 0, z: 0), up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: 1)
    ),
    lifeLeft: Float = 0,
    soundSource: ObjectSoundSource? = nil,
    lightmapSubmodels: [ObjectLightmapSubmodel] = []
) -> PlacedObject {
    PlacedObject.fixture(
        handle: handle, type: type, storedID: storedID, definition: definition,
        location: location, position: position, orientation: orientation,
        lifeLeft: lifeLeft, soundSource: soundSource,
        lightmapSubmodels: lightmapSubmodels
    )
}

func makeMinimalCanonicalPackageLevel(
    levelKey: String = "descent3.level.training-mission"
) -> Level {
    let base = makeMinimalCanonicalLevel(levelKey: levelKey)
    let texture = base.rooms[0].faces[0].texture
    let center = RoomCamera.trainingRoom3.target
    let vertices = [
        Vector3(x: center.x + 1, y: center.y, z: center.z + 1),
        Vector3(x: center.x - 1, y: center.y, z: center.z + 1),
        Vector3(x: center.x - 1, y: center.y, z: center.z - 1),
        Vector3(x: center.x + 1, y: center.y, z: center.z - 1),
    ]
    let room = LevelRoom(
        sourceIndex: 3,
        vertices: vertices,
        faces: [
            .init(
                corners: [
                    .init(vertexIndex: 0, u: 1, v: 1, alpha: 255),
                    .init(vertexIndex: 1, u: 0, v: 1, alpha: 255),
                    .init(vertexIndex: 2, u: 0, v: 0, alpha: 255),
                    .init(vertexIndex: 3, u: 1, v: 0, alpha: 255),
                ],
                flags: 0,
                portalIndex: nil,
                texture: texture
            ),
        ],
        portals: []
    )
    let material = PresentationMaterial(
        texture: texture, bitmapSourceName: "wall.ogf",
        image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
        blend: .opaque, lightmapBlend: .multiply, waterProcedural: nil,
        sourceArchive: base.source.profileFiles[0].relativePath,
        sourceSHA256: String(repeating: "d", count: 64)
    )
    let modelSource = SourceResource(storedIndex: 0, sourceName: "Synthetic.OOF")
    let shipSource = SourceResource(storedIndex: 0, sourceName: "Pyro-GL")
    let player = makePlacedObject(
        handle: 2_048,
        type: D3SourceIdentity.playerObjectType,
        storedID: 0,
        location: .room(3),
        position: RoomCamera.trainingRoom3.position,
        orientation: .init(
            right: .init(x: -1, y: 0, z: 0), up: RoomCamera.trainingRoom3.up,
            forward: .init(x: 0, y: 1, z: 0)
        )
    )
    let model = CanonicalModel(
        source: modelSource,
        collisionRadius: 1,
        submodels: [
            .init(
                sourceIndex: 0,
                parentIndex: nil,
                offset: .zero,
                vertices: [
                    .init(position: .zero, alpha: 1),
                    .init(position: .init(x: 1, y: 0, z: 0), alpha: 1),
                    .init(position: .init(x: 0, y: 1, z: 0), alpha: 1),
                ],
                faces: [
                    .init(
                        normal: .init(x: 0, y: 0, z: 1),
                        corners: [
                            .init(vertexIndex: 0, u: 0, v: 0),
                            .init(vertexIndex: 1, u: 1, v: 0),
                            .init(vertexIndex: 2, u: 0, v: 1),
                        ],
                        material: .texture(texture)
                    ),
                ],
                presentation: .standard
            ),
        ],
        bounds: .init(minimum: .zero, maximum: .init(x: 1, y: 1, z: 0)),
        sourceArchive: base.source.profileFiles[0].relativePath,
        sourceSHA256: String(repeating: "e", count: 64)
    )
    let ship = CanonicalShipDefinition(
        source: shipSource,
        primaryModel: modelSource,
        presentationSize: 1,
        physics: .init(
            mass: 30, drag: 90, fullThrust: 5_400,
            behaviors: [.turnroll, .wiggle, .usesThrust], rotationalDrag: 225,
            fullRotationalThrust: 6_860_000, numberOfBounces: -1,
            initialForwardVelocity: 0, initialAngularVelocity: .zero,
            wiggleAmplitude: 0.17, wigglesPerSecond: 0.9,
            coefficientOfRestitution: 1, hitDieDot: -1,
            maximumTurnrollRate: 8_000, turnrollRatio: 0.13
        )
    )
    return addingTrainingMissionScripting(Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: base.rooms + [room],
        terrain: base.terrain,
        objects: [player],
        retiredObjectHandles: base.retiredObjectHandles,
        paths: base.paths,
        goals: base.goals,
        goalFlags: base.goalFlags,
        triggers: base.triggers,
        playerStartFlags: base.playerStartFlags,
        lightmaps: base.lightmaps,
        presentationMaterials: [material],
        models: [model],
        shipDefinitions: [ship],
        defaultPlayerBinding: .init(
            playerID: 0, objectHandle: player.handle, ship: shipSource
        ),
        objectPresentations: [.fixture(player.handle, modelSource)],
        dependencyManifest: .init(
            current: [
                .init(
                    category: "texture", source: texture,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
                .init(
                    category: "model", source: modelSource,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
                .init(
                    category: "ship-definition", source: shipSource,
                    state: "canonical-typed-definition",
                    provenance: "synthetic canonical fixture"
                ),
            ],
            historicalEagerBaseline: nil
        ),
        sourceChunks: base.sourceChunks
    ))
}

func makeMinimalCanonicalLevel(levelKey: String = "descent3.level.training-mission") -> Level {
    let corners = [
        FaceCorner(vertexIndex: 0, u: 0, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 1, u: 1, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 2, u: 0, v: 1, alpha: 255),
    ]
    let texture = SourceResource(storedIndex: 0, sourceName: "wall")
    let room2 = LevelRoom(
        sourceIndex: 2,
        vertices: [.zero, .init(x: 1, y: 0, z: 0), .init(x: 0, y: 1, z: 0)],
        faces: [.init(corners: corners, flags: 0, portalIndex: 0, texture: texture)],
        portals: [.init(faceIndex: 0, connectedRoom: 4, connectedPortal: 0)]
    )
    let room4 = LevelRoom(
        sourceIndex: 4,
        vertices: [.zero, .init(x: 1, y: 0, z: 0), .init(x: 0, y: 1, z: 0)],
        faces: [.init(corners: Array(corners.reversed()), flags: 0, portalIndex: 0, texture: texture)],
        portals: [.init(faceIndex: 0, connectedRoom: 2, connectedPortal: 0)]
    )
    return Level(
        missionKey: "descent3.mission.pilot-training",
        levelKey: levelKey,
        source: .init(
            profileIdentifier: "test",
            profileFiles: [
                .init(
                    relativePath: "missions/training.mn3", byteCount: 1,
                    sha256: canonicalSHA256(Data("x".utf8))
                ),
            ],
            archiveSHA256: String(repeating: "a", count: 64),
            levelSHA256: String(repeating: "b", count: 64),
            d3lvVersion: 127
        ),
        metadata: LevelMetadata(
            name: "", designer: "", copyright: "", notes: "", gravity: 0,
            alwaysCheckCeiling: false, ceilingHeight: 0
        ),
        rooms: [room2, room4],
        terrain: makeTestLevelTerrain(),
        objects: [],
        paths: [],
        goals: [],
        triggers: [],
        playerStartFlags: [],
        lightmaps: LightmapCatalog(pages: [], infos: []),
        dependencyManifest: .init(
            current: [
                .init(
                    category: "texture", source: texture,
                    state: "identity-recorded",
                    provenance: "synthetic canonical fixture"
                ),
            ],
            historicalEagerBaseline: nil
        ),
        sourceChunks: [
            .init(
                name: "TEST", byteCount: 0,
                sha256: String(repeating: "c", count: 64),
                disposition: "synthetic-test-fixture"
            ),
        ]
    )
}

func removingDefaultPlayerPresentation(from level: Level) -> Level {
    packageLevel(Level(
        schemaVersion: level.schemaVersion,
        missionKey: level.missionKey,
        levelKey: level.levelKey,
        source: level.source,
        metadata: level.metadata,
        rooms: level.rooms,
        terrain: level.terrain,
        objects: [],
        retiredObjectHandles: level.retiredObjectHandles,
        paths: level.paths,
        goals: level.goals,
        goalFlags: level.goalFlags,
        triggers: level.triggers,
        playerStartFlags: level.playerStartFlags,
        lightmaps: level.lightmaps,
        surfacePhysics: level.surfacePhysics,
        presentationMaterials: level.presentationMaterials,
        presentationCoronaAssets: level.presentationCoronaAssets,
        models: [],
        shipDefinitions: [],
        defaultPlayerBinding: nil,
        objectPresentations: [],
        dependencyManifest: .init(
            current: level.dependencyManifest.current.filter { $0.category == "texture" },
            historicalEagerBaseline: level.dependencyManifest.historicalEagerBaseline
        ),
        sourceChunks: level.sourceChunks
    ))
}

func makeTestLevelTerrain() -> LevelTerrain {
    LevelTerrain(
        heights: [UInt8](repeating: 0, count: 65_536),
        textureCells: [TerrainTextureCell](
            repeating: .init(
                texture: .init(storedIndex: 0, sourceName: "wall"),
                rotationAndTile: 0
            ),
            count: 1_024
        ),
        flags: [UInt8](repeating: 0, count: 65_536),
        light: [UInt8](repeating: 0, count: 65_536),
        red: [UInt8](repeating: 0, count: 65_536),
        green: [UInt8](repeating: 0, count: 65_536),
        blue: [UInt8](repeating: 0, count: 65_536),
        dynamicLight: [UInt8](repeating: 0, count: 65_536),
        occlusionChecksum: 0,
        occlusionMap: [UInt8](repeating: 0, count: 8_192),
        sky: nil
    )
}

/// A temporary native package library with `base` installed and active.
/// The caller removes `root`.
func makeActivatedLibrary(_ base: Level) throws -> (
    root: URL, library: CanonicalPackageLibrary,
    activation: ActivatedCanonicalPackage
) {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
        at: root, withIntermediateDirectories: false
    )
    let candidate = root.appending(
        path: "candidate.revival", directoryHint: .isDirectory
    )
    let library = CanonicalPackageLibrary(
        rootURL: root.appending(path: "library", directoryHint: .isDirectory)
    )
    try writeCanonicalPackage(base, to: candidate)
    return (root, library, try library.installAndActivate(from: candidate))
}
