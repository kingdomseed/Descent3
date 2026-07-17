// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum D3SourceIdentity {
    static let definitionBearingObjectTypes: Set<UInt8> = [2, 7, 11, 16, 17]
    static let playerObjectType: UInt8 = 4
    static let maximumPlayers = 32

    static func isValidHandle(_ handle: UInt32) -> Bool {
        handle & 0xffff_f800 != 0 && Int(handle & 0x7ff) < 1_500
    }

    static func isSerializedObjectType(_ type: UInt8) -> Bool {
        type < 26 && type != 18
    }

    static func isValidStoredID(_ storedID: Int) -> Bool {
        (0...Int(Int16.max)).contains(storedID)
    }

    static func isValidSerializedObjectIdentity(storedID: Int, type: UInt8) -> Bool {
        guard isValidStoredID(storedID) else { return false }
        switch type {
        case 2, 7, 11, 16: return storedID < 910
        case 17: return storedID < 60
        default: return true
        }
    }

    static func sourceResourceCeiling(for category: String) -> Int? {
        switch category.lowercased() {
        case "texture": return 3_100
        case "object-definition": return 910
        case "door-definition": return 60
        case "lightmap-page", "lightmap-info": return 65_534
        default: return nil
        }
    }

    static func isValidSourceResource(_ source: SourceResource, category: String) -> Bool {
        guard let ceiling = sourceResourceCeiling(for: category),
              (0..<ceiling).contains(source.storedIndex),
              !source.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return source.referenceRuntimeIndex.map { (0..<ceiling).contains($0) } ?? true
    }
}

struct Vector3: Codable, Equatable, Sendable {
    let x: Float
    let y: Float
    let z: Float

    static let zero = Vector3(x: 0, y: 0, z: 0)
}

struct Matrix3: Codable, Equatable, Sendable {
    let right: Vector3
    let up: Vector3
    let forward: Vector3
}

struct SourceResource: Codable, Equatable, Hashable, Sendable {
    let storedIndex: Int
    let sourceName: String
    let referenceRuntimeIndex: Int?

    init(storedIndex: Int, sourceName: String, referenceRuntimeIndex: Int? = nil) {
        self.storedIndex = storedIndex
        self.sourceName = sourceName
        self.referenceRuntimeIndex = referenceRuntimeIndex
    }
}

struct SourceFileFingerprint: Codable, Equatable, Hashable, Sendable {
    let relativePath: String
    let byteCount: Int
    let sha256: String
}

struct LevelSource: Codable, Equatable, Sendable {
    let profileIdentifier: String
    let profileFiles: [SourceFileFingerprint]
    let archiveSHA256: String
    let levelSHA256: String
    let d3lvVersion: Int
    let archiveEntryName: String?
    let archiveEntryOffset: Int?
    let archiveEntryByteCount: Int?
    let referenceChecksum: String?
    let referenceChecksumBasis: String?

    init(
        profileIdentifier: String,
        profileFiles: [SourceFileFingerprint] = [],
        archiveSHA256: String,
        levelSHA256: String,
        d3lvVersion: Int,
        archiveEntryName: String? = nil,
        archiveEntryOffset: Int? = nil,
        archiveEntryByteCount: Int? = nil,
        referenceChecksum: String? = nil,
        referenceChecksumBasis: String? = nil
    ) {
        self.profileIdentifier = profileIdentifier
        self.profileFiles = profileFiles
        self.archiveSHA256 = archiveSHA256
        self.levelSHA256 = levelSHA256
        self.d3lvVersion = d3lvVersion
        self.archiveEntryName = archiveEntryName
        self.archiveEntryOffset = archiveEntryOffset
        self.archiveEntryByteCount = archiveEntryByteCount
        self.referenceChecksum = referenceChecksum
        self.referenceChecksumBasis = referenceChecksumBasis
    }
}

struct LevelMetadata: Codable, Equatable, Sendable {
    let name: String
    let designer: String
    let copyright: String
    let notes: String
    let gravity: Float
    let alwaysCheckCeiling: Bool
    let ceilingHeight: Float

}

struct FaceCorner: Codable, Equatable, Sendable {
    let vertexIndex: Int
    let u: Float
    let v: Float
    let alpha: UInt8
    let lightmapU: Float?
    let lightmapV: Float?

    init(
        vertexIndex: Int,
        u: Float,
        v: Float,
        alpha: UInt8,
        lightmapU: Float? = nil,
        lightmapV: Float? = nil
    ) {
        self.vertexIndex = vertexIndex
        self.u = u
        self.v = v
        self.alpha = alpha
        self.lightmapU = lightmapU
        self.lightmapV = lightmapV
    }
}

struct SpecialFacePoint: Codable, Equatable, Sendable {
    let center: Vector3
    let color: UInt16
}

struct SpecialFace: Codable, Equatable, Sendable {
    let type: UInt8
    let points: [SpecialFacePoint]
    let smoothedVertexNormals: [Vector3]
}

struct LevelFace: Codable, Equatable, Sendable {
    let corners: [FaceCorner]
    let flags: UInt16
    let portalIndex: Int?
    let texture: SourceResource
    let lightmapInfoIndex: Int?
    let lightMultiple: UInt8
    let special: SpecialFace?

    init(
        corners: [FaceCorner],
        flags: UInt16,
        portalIndex: Int?,
        texture: SourceResource,
        lightmapInfoIndex: Int? = nil,
        lightMultiple: UInt8 = 4,
        special: SpecialFace? = nil
    ) {
        self.corners = corners
        self.flags = flags
        self.portalIndex = portalIndex
        self.texture = texture
        self.lightmapInfoIndex = lightmapInfoIndex
        self.lightMultiple = lightMultiple
        self.special = special
    }
}

struct LevelPortal: Codable, Equatable, Sendable {
    let flags: UInt32
    let faceIndex: Int
    let connectedRoom: Int
    let connectedPortal: Int
    let boundaryNodeIndex: Int
    let pathPoint: Vector3
    let combineMaster: Int

    init(
        flags: UInt32 = 0,
        faceIndex: Int,
        connectedRoom: Int,
        connectedPortal: Int,
        boundaryNodeIndex: Int = -1,
        pathPoint: Vector3 = .zero,
        combineMaster: Int = -1
    ) {
        self.flags = flags
        self.faceIndex = faceIndex
        self.connectedRoom = connectedRoom
        self.connectedPortal = connectedPortal
        self.boundaryNodeIndex = boundaryNodeIndex
        self.pathPoint = pathPoint
        self.combineMaster = combineMaster
    }
}

struct RoomDoor: Codable, Equatable, Sendable {
    let flags: UInt8
    let keysNeeded: UInt8
    let definition: SourceResource
    let position: Float
}

struct VolumeLightGrid: Codable, Equatable, Sendable {
    let width: Int
    let height: Int
    let depth: Int
    let values: [UInt8]
}

struct RoomFog: Codable, Equatable, Sendable {
    let depth: Float
    let red: Float
    let green: Float
    let blue: Float
}

struct LevelRoom: Codable, Equatable, Sendable {
    let sourceIndex: Int
    let name: String?
    let pathPoint: Vector3
    let vertices: [Vector3]
    let faces: [LevelFace]
    let portals: [LevelPortal]
    let flags: UInt32
    let pulseTime: UInt8
    let pulseOffset: UInt8
    let mirrorFaceIndex: Int?
    let door: RoomDoor?
    let volumeLights: VolumeLightGrid?
    let fog: RoomFog
    let ambientSoundPattern: String?
    let reverb: UInt8
    let damage: Float
    let damageType: UInt8

    init(
        sourceIndex: Int,
        name: String? = nil,
        pathPoint: Vector3 = .zero,
        vertices: [Vector3],
        faces: [LevelFace],
        portals: [LevelPortal],
        flags: UInt32 = 0,
        pulseTime: UInt8 = 0,
        pulseOffset: UInt8 = 0,
        mirrorFaceIndex: Int? = nil,
        door: RoomDoor? = nil,
        volumeLights: VolumeLightGrid? = nil,
        fog: RoomFog = .init(depth: 0, red: 0, green: 0, blue: 0),
        ambientSoundPattern: String? = nil,
        reverb: UInt8 = 0,
        damage: Float = 0,
        damageType: UInt8 = 0
    ) {
        self.sourceIndex = sourceIndex
        self.name = name
        self.pathPoint = pathPoint
        self.vertices = vertices
        self.faces = faces
        self.portals = portals
        self.flags = flags
        self.pulseTime = pulseTime
        self.pulseOffset = pulseOffset
        self.mirrorFaceIndex = mirrorFaceIndex
        self.door = door
        self.volumeLights = volumeLights
        self.fog = fog
        self.ambientSoundPattern = ambientSoundPattern
        self.reverb = reverb
        self.damage = damage
        self.damageType = damageType
    }
}

struct TerrainTextureCell: Codable, Equatable, Sendable {
    let texture: SourceResource
    let rotationAndTile: UInt8
}

struct TerrainSatellite: Codable, Equatable, Sendable {
    let texture: SourceResource
    let vector: Vector3
    let flags: UInt8
    let size: Float
    let red: Float
    let green: Float
    let blue: Float
}

struct TerrainSky: Codable, Equatable, Sendable {
    let fogScalar: Float
    let damagePerSecond: Float
    let textured: Bool
    let domeTexture: SourceResource
    let skyColor: UInt32
    let horizonColor: UInt32
    let fogColor: UInt32
    let flags: UInt32
    let radius: Float
    let rotationRate: Float
    let satellites: [TerrainSatellite]
}

struct LevelTerrain: Codable, Equatable, Sendable {
    let heights: [UInt8]
    let textureCells: [TerrainTextureCell]
    let flags: [UInt8]
    let light: [UInt8]
    let red: [UInt8]
    let green: [UInt8]
    let blue: [UInt8]
    let dynamicLight: [UInt8]
    let occlusionChecksum: UInt32
    let occlusionMap: [UInt8]
    let sky: TerrainSky?

}

enum SpatialLocation: Codable, Equatable, Sendable {
    case room(Int)
    case terrainCell(Int)
}

struct ObjectSoundSource: Codable, Equatable, Sendable {
    let sourceName: String?
    let volume: Float
}

struct ObjectLightmapFace: Codable, Equatable, Sendable {
    let lightmapInfoIndex: Int
    let right: Vector3
    let up: Vector3
    let uv: [LightmapUV]
}

struct LightmapUV: Codable, Equatable, Sendable {
    let u: Float
    let v: Float
}

struct ObjectLightmapSubmodel: Codable, Equatable, Sendable {
    let faces: [ObjectLightmapFace]
}

struct PlacedObject: Codable, Equatable, Sendable {
    let handle: UInt32
    var slot: Int { Int(handle & 0x7ff) }
    let type: UInt8
    let storedID: Int
    let definition: SourceResource?
    let instanceName: String?
    let flags: UInt32
    let doorShields: Int16?
    let location: SpatialLocation
    let position: Vector3
    let orientation: Matrix3
    let containsType: UInt8
    let containsID: UInt8
    let containsCount: UInt8
    let lifeLeft: Float
    let soundSource: ObjectSoundSource?
    let inertScriptName: String?
    let inertModuleName: String?
    let lightmapSubmodels: [ObjectLightmapSubmodel]
}

struct GamePathNode: Codable, Equatable, Sendable {
    let position: Vector3
    let location: SpatialLocation
    let flags: UInt32
    let forward: Vector3
    let up: Vector3
}

struct GamePath: Codable, Equatable, Sendable {
    let name: String
    let flags: UInt8
    let nodes: [GamePathNode]
}

struct LevelGoalItem: Codable, Equatable, Sendable {
    let type: UInt8
    let sourceHandle: UInt32
    let objectHandle: UInt32?
    let done: Bool
}

struct LevelGoal: Codable, Equatable, Sendable {
    let status: UInt32
    let priority: Int32
    let list: Int8
    let name: String
    let itemName: String
    let description: String
    let completionMessage: String
    let items: [LevelGoalItem]
}

struct LevelTrigger: Codable, Equatable, Sendable {
    let name: String
    let roomIndex: Int
    let faceIndex: Int
    let flags: UInt16
    let activator: UInt16
}

struct LightmapPageMetadata: Codable, Equatable, Sendable {
    let width: Int
    let height: Int
}

struct LightmapInfoRecord: Codable, Equatable, Sendable {
    let pageIndex: Int
    let width: Int
    let height: Int
    let type: UInt8
    let x: Int
    let y: Int
    let xSpacing: UInt8
    let ySpacing: UInt8
    let upperLeft: Vector3
    let normal: Vector3
}

struct LightmapCatalog: Codable, Equatable, Sendable {
    let pages: [LightmapPageMetadata]
    let infos: [LightmapInfoRecord]
}

struct DependencyRecord: Codable, Equatable, Hashable, Sendable {
    let category: String
    let source: SourceResource
    let state: String
    let provenance: String
}

struct EagerDependencyBaseline: Codable, Equatable, Sendable {
    let textureCount: Int
    let soundCount: Int
    let modelCount: Int
    let lightmapInfoCount: Int
}

struct DependencyManifest: Codable, Equatable, Sendable {
    let current: [DependencyRecord]
    let historicalEagerBaseline: EagerDependencyBaseline?
}

struct SourceChunkRecord: Codable, Equatable, Sendable {
    let name: String
    let byteCount: Int
    let sha256: String
    let disposition: String
}

struct Level: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let missionKey: String
    let levelKey: String
    let source: LevelSource
    let metadata: LevelMetadata
    let rooms: [LevelRoom]
    let terrain: LevelTerrain
    let objects: [PlacedObject]
    let retiredObjectHandles: [UInt32]
    let paths: [GamePath]
    let goals: [LevelGoal]
    let goalFlags: UInt32
    let triggers: [LevelTrigger]
    let playerStartFlags: [UInt32]
    let lightmaps: LightmapCatalog
    let dependencyManifest: DependencyManifest
    let sourceChunks: [SourceChunkRecord]

    init(
        schemaVersion: Int = 1,
        missionKey: String,
        levelKey: String,
        source: LevelSource,
        metadata: LevelMetadata,
        rooms: [LevelRoom],
        terrain: LevelTerrain,
        objects: [PlacedObject],
        retiredObjectHandles: [UInt32] = [],
        paths: [GamePath],
        goals: [LevelGoal],
        goalFlags: UInt32 = 0,
        triggers: [LevelTrigger],
        playerStartFlags: [UInt32],
        lightmaps: LightmapCatalog,
        dependencyManifest: DependencyManifest,
        sourceChunks: [SourceChunkRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.missionKey = missionKey
        self.levelKey = levelKey
        self.source = source
        self.metadata = metadata
        self.rooms = rooms
        self.terrain = terrain
        self.objects = objects
        self.retiredObjectHandles = retiredObjectHandles
        self.paths = paths
        self.goals = goals
        self.goalFlags = goalFlags
        self.triggers = triggers
        self.playerStartFlags = playerStartFlags
        self.lightmaps = lightmaps
        self.dependencyManifest = dependencyManifest
        self.sourceChunks = sourceChunks
    }

    func validate() throws {
        guard schemaVersion == 1, source.d3lvVersion == 127,
              !missionKey.isEmpty, !levelKey.isEmpty else {
            throw LevelValidationError.invalidIdentity
        }
        try validateSource(source)
        try validateLightmaps(lightmaps)

        guard rooms.count <= 400,
              rooms.allSatisfy({ (0..<400).contains($0.sourceIndex) }) else {
            throw LevelValidationError.invalidCount("rooms")
        }
        guard Set(rooms.map(\.sourceIndex)).count == rooms.count else {
            throw LevelValidationError.duplicateRoom
        }
        guard objects.count <= 1_500 else {
            throw LevelValidationError.invalidCount("objects")
        }
        guard paths.count <= 300 else {
            throw LevelValidationError.invalidCount("paths")
        }
        guard goals.count <= 32 else {
            throw LevelValidationError.invalidCount("goals")
        }
        guard playerStartFlags.count <= 32 else {
            throw LevelValidationError.invalidCount("player start flags")
        }
        let roomMap = Dictionary(uniqueKeysWithValues: rooms.map { ($0.sourceIndex, $0) })

        for room in rooms {
            guard room.vertices.count <= 10_000, room.faces.count <= 3_000 else {
                throw LevelValidationError.invalidCount("room \(room.sourceIndex)")
            }
            if let mirrorFaceIndex = room.mirrorFaceIndex,
               !room.faces.indices.contains(mirrorFaceIndex) {
                throw LevelValidationError.invalidMirrorFace(room: room.sourceIndex)
            }
            if let volumeLights = room.volumeLights {
                guard (0...Int(Int16.max)).contains(volumeLights.width),
                      (0...Int(Int16.max)).contains(volumeLights.height),
                      (0...Int(Int16.max)).contains(volumeLights.depth) else {
                    throw LevelValidationError.invalidVolumeLights(room: room.sourceIndex)
                }
                let count = volumeLights.width * volumeLights.height * volumeLights.depth
                guard count == volumeLights.values.count else {
                    throw LevelValidationError.invalidVolumeLights(room: room.sourceIndex)
                }
            }
            for (faceIndex, face) in room.faces.enumerated() {
                guard (3...64).contains(face.corners.count),
                      face.corners.allSatisfy({ room.vertices.indices.contains($0.vertexIndex) }) else {
                    throw LevelValidationError.invalidFace(room: room.sourceIndex, face: faceIndex)
                }
                let hasLightmap = face.flags & 0x0001 != 0
                let hasAnyLightmapUV = face.corners.contains {
                    $0.lightmapU != nil || $0.lightmapV != nil
                }
                let hasCompleteLightmapUV = face.corners.allSatisfy {
                    $0.lightmapU != nil && $0.lightmapV != nil
                }
                guard hasLightmap
                    ? (face.lightmapInfoIndex != nil && hasCompleteLightmapUV)
                    : (face.lightmapInfoIndex == nil && !hasAnyLightmapUV) else {
                    throw LevelValidationError.invalidFace(room: room.sourceIndex, face: faceIndex)
                }
                if let special = face.special {
                    guard special.smoothedVertexNormals.isEmpty
                        || special.smoothedVertexNormals.count == face.corners.count else {
                        throw LevelValidationError.invalidSpecialFace(
                            room: room.sourceIndex,
                            face: faceIndex
                        )
                    }
                }
                if let portalIndex = face.portalIndex {
                    guard room.portals.indices.contains(portalIndex),
                          room.portals[portalIndex].faceIndex == faceIndex else {
                        throw LevelValidationError.invalidFacePortal(room: room.sourceIndex, face: faceIndex)
                    }
                }
                if let lightmap = face.lightmapInfoIndex,
                   !lightmaps.infos.indices.contains(lightmap) {
                    throw LevelValidationError.invalidLightmapReference(lightmap)
                }
            }
            for (portalIndex, portal) in room.portals.enumerated() {
                guard room.faces.indices.contains(portal.faceIndex),
                      room.faces[portal.faceIndex].portalIndex == portalIndex,
                      let connected = roomMap[portal.connectedRoom],
                      connected.portals.indices.contains(portal.connectedPortal) else {
                    throw LevelValidationError.invalidPortal(room: room.sourceIndex, portal: portalIndex)
                }
                let inverse = connected.portals[portal.connectedPortal]
                guard inverse.connectedRoom == room.sourceIndex,
                      inverse.connectedPortal == portalIndex else {
                    throw LevelValidationError.nonreciprocalPortal(room: room.sourceIndex, portal: portalIndex)
                }
                if portal.flags & 0x0000_0008 != 0 {
                    guard room.portals.indices.contains(portal.combineMaster) else {
                        throw LevelValidationError.invalidCombinedPortal(
                            room: room.sourceIndex,
                            portal: portalIndex
                        )
                    }
                    let master = room.portals[portal.combineMaster]
                    guard master.flags & 0x0000_0008 != 0,
                          master.combineMaster == portal.combineMaster,
                          master.connectedRoom == portal.connectedRoom,
                          (master.flags & 0x0000_0001) == (portal.flags & 0x0000_0001) else {
                        throw LevelValidationError.invalidCombinedPortal(
                            room: room.sourceIndex,
                            portal: portalIndex
                        )
                    }
                }
            }
        }

        guard terrain.heights.count == 65_536,
              terrain.textureCells.count == 1_024,
              terrain.flags.count == 65_536,
              terrain.light.count == 65_536,
              terrain.red.count == 65_536,
              terrain.green.count == 65_536,
              terrain.blue.count == 65_536,
              terrain.dynamicLight.count == 65_536,
              terrain.occlusionMap.count == 8_192 else {
            throw LevelValidationError.invalidTerrain
        }
        if let sky = terrain.sky {
            guard sky.satellites.count <= 5 else {
                throw LevelValidationError.invalidCount("terrain satellites")
            }
        }

        var handles = Set<UInt32>()
        var objectSlots = Set<Int>()
        var playerIDs = Set<Int>()
        for object in objects {
            guard handles.insert(object.handle).inserted,
                  D3SourceIdentity.isValidHandle(object.handle),
                  objectSlots.insert(object.slot).inserted else {
                throw LevelValidationError.invalidObjectHandle(object.handle)
            }
            guard D3SourceIdentity.isSerializedObjectType(object.type) else {
                throw LevelValidationError.invalidObjectType(object.type)
            }
            guard D3SourceIdentity.isValidStoredID(object.storedID) else {
                throw LevelValidationError.invalidObjectStoredID(
                    handle: object.handle,
                    storedID: object.storedID
                )
            }
            if object.type == D3SourceIdentity.playerObjectType {
                guard (0..<D3SourceIdentity.maximumPlayers).contains(object.storedID) else {
                    throw LevelValidationError.invalidPlayerID(
                        handle: object.handle,
                        playerID: object.storedID
                    )
                }
                guard playerIDs.insert(object.storedID).inserted else {
                    throw LevelValidationError.duplicatePlayerID(
                        handle: object.handle,
                        playerID: object.storedID
                    )
                }
            }
            guard D3SourceIdentity.definitionBearingObjectTypes.contains(object.type)
                    == (object.definition != nil) else {
                throw LevelValidationError.invalidObjectDefinition(object.handle)
            }
            if let definition = object.definition {
                guard definition.storedIndex == object.storedID else {
                    throw LevelValidationError.invalidObjectDefinition(object.handle)
                }
            }
            try validateObjectLocation(object.location, rooms: roomMap)
            guard isOrthonormal(object.orientation) else {
                throw LevelValidationError.invalidObjectOrientation(object.handle)
            }
            for submodel in object.lightmapSubmodels {
                for face in submodel.faces {
                    guard lightmaps.infos.indices.contains(face.lightmapInfoIndex) else {
                        throw LevelValidationError.invalidLightmapReference(face.lightmapInfoIndex)
                    }
                }
            }
        }
        var retiredSlots = Set<Int>()
        for handle in retiredObjectHandles {
            let slot = Int(handle & 0x7ff)
            guard D3SourceIdentity.isValidHandle(handle),
                  !handles.contains(handle),
                  !objectSlots.contains(slot),
                  retiredSlots.insert(slot).inserted else {
                throw LevelValidationError.invalidObjectHandle(handle)
            }
        }
        for path in paths {
            guard path.nodes.count <= 100 else {
                throw LevelValidationError.invalidCount("path nodes")
            }
            for node in path.nodes {
                try validateLocation(node.location, rooms: roomMap)
            }
        }
        for goal in goals {
            guard goal.items.count <= 12 else {
                throw LevelValidationError.invalidCount("goal items")
            }
            for item in goal.items {
                guard item.type == 2,
                      let objectHandle = item.objectHandle,
                      objectHandle == item.sourceHandle,
                      handles.contains(objectHandle) else {
                    throw LevelValidationError.invalidGoalObject(item.sourceHandle)
                }
            }
        }
        guard triggers.count <= 100 else {
            throw LevelValidationError.invalidCount("triggers")
        }
        for trigger in triggers {
            guard let room = roomMap[trigger.roomIndex],
                  room.faces.indices.contains(trigger.faceIndex),
                  room.faces[trigger.faceIndex].flags & 0x0010 != 0 else {
                throw LevelValidationError.invalidTrigger(trigger.name)
            }
        }

        var dependencyNames = Set<String>()
        var dependencyStoredIndices = Set<String>()
        var availableDependencies = Set<DependencyIdentity>()
        for dependency in dependencyManifest.current {
            guard isNonempty(dependency.category),
                  isNonempty(dependency.source.sourceName),
                  isNonempty(dependency.state),
                  isNonempty(dependency.provenance) else {
                throw LevelValidationError.invalidDependency(dependency.category)
            }
            try validateSourceResource(dependency.source, category: dependency.category)
            let category = dependency.category.lowercased()
            let nameIdentity = "\(category):\(dependency.source.sourceName.lowercased())"
            let storedIdentity = "\(category):\(dependency.source.storedIndex)"
            guard dependencyNames.insert(nameIdentity).inserted,
                  dependencyStoredIndices.insert(storedIdentity).inserted else {
                throw LevelValidationError.duplicateDependency
            }
            availableDependencies.insert(.init(category: dependency.category, source: dependency.source))
        }
        if let baseline = dependencyManifest.historicalEagerBaseline {
            guard baseline.textureCount >= 0,
                  baseline.soundCount >= 0,
                  baseline.modelCount >= 0,
                  baseline.lightmapInfoCount >= 0 else {
                throw LevelValidationError.invalidDependency("historical eager baseline")
            }
        }
        try validateDependencyClosure(availableDependencies)

        guard !sourceChunks.isEmpty else {
            throw LevelValidationError.invalidSourceChunk("missing")
        }
        var chunkNames = Set<String>()
        for chunk in sourceChunks {
            guard chunk.name.utf8.count == 4,
                  chunk.name.utf8.allSatisfy({ $0 >= 0x20 && $0 <= 0x7e }),
                  chunk.byteCount >= 0,
                  isSHA256(chunk.sha256),
                  isNonempty(chunk.disposition),
                  chunkNames.insert(chunk.name.lowercased()).inserted else {
                throw LevelValidationError.invalidSourceChunk(chunk.name)
            }
        }
    }
}

enum LevelValidationError: Error, Equatable {
    case invalidIdentity
    case duplicateRoom
    case invalidFace(room: Int, face: Int)
    case invalidFacePortal(room: Int, face: Int)
    case invalidMirrorFace(room: Int)
    case invalidSpecialFace(room: Int, face: Int)
    case invalidPortal(room: Int, portal: Int)
    case invalidCombinedPortal(room: Int, portal: Int)
    case nonreciprocalPortal(room: Int, portal: Int)
    case invalidLightmapReference(Int)
    case invalidLightmapPage(Int)
    case invalidLightmapInfo(Int)
    case invalidVolumeLights(room: Int)
    case invalidTerrain
    case invalidObjectHandle(UInt32)
    case invalidObjectType(UInt8)
    case invalidObjectStoredID(handle: UInt32, storedID: Int)
    case invalidPlayerID(handle: UInt32, playerID: Int)
    case duplicatePlayerID(handle: UInt32, playerID: Int)
    case invalidObjectDefinition(UInt32)
    case invalidObjectOrientation(UInt32)
    case invalidLocation
    case invalidGoalObject(UInt32)
    case invalidTrigger(String)
    case invalidDependency(String)
    case invalidSourceResource(category: String, storedIndex: Int)
    case duplicateDependency
    case invalidSourceChunk(String)
    case invalidCount(String)
}

private struct DependencyIdentity: Hashable {
    let category: String
    let source: SourceResource
}

private func validateSourceResource(_ source: SourceResource, category: String) throws {
    guard D3SourceIdentity.isValidSourceResource(source, category: category) else {
        throw LevelValidationError.invalidSourceResource(
            category: category,
            storedIndex: source.storedIndex
        )
    }
}

private func validateSource(_ source: LevelSource) throws {
    guard isNonempty(source.profileIdentifier),
          !source.profileFiles.isEmpty,
          isSHA256(source.archiveSHA256),
          isSHA256(source.levelSHA256) else {
        throw LevelValidationError.invalidIdentity
    }
    var profilePaths = Set<String>()
    for file in source.profileFiles {
        guard isSafeRelativePath(file.relativePath),
              file.byteCount >= 0,
              isSHA256(file.sha256),
              profilePaths.insert(file.relativePath.lowercased()).inserted else {
            throw LevelValidationError.invalidIdentity
        }
    }
    if source.archiveEntryName != nil
        || source.archiveEntryOffset != nil
        || source.archiveEntryByteCount != nil {
        guard let archiveEntryName = source.archiveEntryName,
              isNonempty(archiveEntryName),
              let archiveEntryOffset = source.archiveEntryOffset,
              archiveEntryOffset >= 0,
              let archiveEntryByteCount = source.archiveEntryByteCount,
              archiveEntryByteCount >= 0 else {
            throw LevelValidationError.invalidIdentity
        }
    }
    if let referenceChecksum = source.referenceChecksum {
        guard isLowercaseHex(referenceChecksum, count: 32),
              source.referenceChecksumBasis
                == "pinned-source-provenance-implied-by-exact-level-sha256" else {
            throw LevelValidationError.invalidIdentity
        }
    } else if source.referenceChecksumBasis != nil {
        throw LevelValidationError.invalidIdentity
    }
}

extension Level {
    fileprivate func validateDependencyClosure(_ available: Set<DependencyIdentity>) throws {
        var required = Set<DependencyIdentity>()
        func require(_ category: String, _ source: SourceResource) {
            required.insert(.init(category: category, source: source))
        }

        for room in rooms {
            for face in room.faces { require("texture", face.texture) }
            if let door = room.door { require("door-definition", door.definition) }
        }
        for cell in terrain.textureCells { require("texture", cell.texture) }
        if let sky = terrain.sky {
            require("texture", sky.domeTexture)
            for satellite in sky.satellites { require("texture", satellite.texture) }
        }
        for object in objects {
            guard let definition = object.definition else { continue }
            require(object.type == 17 ? "door-definition" : "object-definition", definition)
        }
        for index in lightmaps.pages.indices {
            require(
                "lightmap-page",
                .init(storedIndex: index, sourceName: "lightmap-page-\(index)")
            )
        }
        for index in lightmaps.infos.indices {
            require(
                "lightmap-info",
                .init(storedIndex: index, sourceName: "lightmap-info-\(index)")
            )
        }
        let missing = required.filter { !available.contains($0) }.sorted {
            ($0.category, $0.source.storedIndex, $0.source.sourceName)
                < ($1.category, $1.source.storedIndex, $1.source.sourceName)
        }
        if let dependency = missing.first {
            throw LevelValidationError.invalidDependency(
                "missing \(dependency.category):\(dependency.source.sourceName)"
            )
        }
    }
}

private func validateLightmaps(_ lightmaps: LightmapCatalog) throws {
    guard lightmaps.pages.count <= 65_534 else {
        throw LevelValidationError.invalidCount("lightmap pages")
    }
    guard lightmaps.infos.count < 65_534 else {
        throw LevelValidationError.invalidCount("lightmap infos")
    }
    for (pageIndex, page) in lightmaps.pages.enumerated() {
        guard (1...128).contains(page.width), (1...128).contains(page.height) else {
            throw LevelValidationError.invalidLightmapPage(pageIndex)
        }
    }
    for (infoIndex, info) in lightmaps.infos.enumerated() {
        guard lightmaps.pages.indices.contains(info.pageIndex),
              info.width >= 2,
              info.height >= 2,
              info.x >= 0,
              info.y >= 0 else {
            throw LevelValidationError.invalidLightmapInfo(infoIndex)
        }
        let page = lightmaps.pages[info.pageIndex]
        guard info.x <= page.width,
              info.y <= page.height,
              info.width <= page.width - info.x,
              info.height <= page.height - info.y else {
            throw LevelValidationError.invalidLightmapInfo(infoIndex)
        }
    }
}

private func isOrthonormal(_ matrix: Matrix3) -> Bool {
    let tolerance: Float = 0.001
    let right = matrix.right
    let up = matrix.up
    let forward = matrix.forward
    guard abs(dot(right, right) - 1) <= tolerance,
          abs(dot(up, up) - 1) <= tolerance,
          abs(dot(forward, forward) - 1) <= tolerance,
          abs(dot(right, up)) <= tolerance,
          abs(dot(right, forward)) <= tolerance,
          abs(dot(up, forward)) <= tolerance else {
        return false
    }
    let expectedRight = cross(up, forward)
    return abs(expectedRight.x - right.x) <= tolerance
        && abs(expectedRight.y - right.y) <= tolerance
        && abs(expectedRight.z - right.z) <= tolerance
}

private func dot(_ a: Vector3, _ b: Vector3) -> Float {
    a.x * b.x + a.y * b.y + a.z * b.z
}

private func cross(_ a: Vector3, _ b: Vector3) -> Vector3 {
    .init(
        x: a.y * b.z - a.z * b.y,
        y: a.z * b.x - a.x * b.z,
        z: a.x * b.y - a.y * b.x
    )
}

private func validateLocation(_ location: SpatialLocation, rooms: [Int: LevelRoom]) throws {
    switch location {
    case .room(let index):
        guard rooms[index] != nil else { throw LevelValidationError.invalidLocation }
    case .terrainCell(let index):
        guard (0..<65_536).contains(index) else { throw LevelValidationError.invalidLocation }
    }
}

private func validateObjectLocation(_ location: SpatialLocation, rooms: [Int: LevelRoom]) throws {
    try validateLocation(location, rooms: rooms)
    if case .room(let index) = location,
       let room = rooms[index],
       room.flags & 0x0000_0004 != 0 {
        throw LevelValidationError.invalidLocation
    }
}

private func isNonempty(_ value: String) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func isSHA256(_ value: String) -> Bool {
    isLowercaseHex(value, count: 64)
}

private func isLowercaseHex(_ value: String, count: Int) -> Bool {
    value.utf8.count == count && value.utf8.allSatisfy {
        ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x61 && $0 <= 0x66)
    }
}

private func isSafeRelativePath(_ path: String) -> Bool {
    let components = path.split(separator: "/", omittingEmptySubsequences: false)
    return !components.isEmpty
        && components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
}
