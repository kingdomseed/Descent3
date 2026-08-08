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
        case "weapon-definition": return 256
        case "model": return 10_000
        case "ship-definition": return 60
        case "door-definition": return 60
        case "lightmap-page", "lightmap-info": return 65_534
        case "presentation-effect": return 256
        case "voice", "sound": return 65_534
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
    var texture: SourceResource
    let lightmapInfoIndex: Int?
    let allowsLightCorona: Bool
    let lightMultiple: UInt8
    let special: SpecialFace?

    init(
        corners: [FaceCorner],
        flags: UInt16,
        portalIndex: Int?,
        texture: SourceResource,
        lightmapInfoIndex: Int? = nil,
        allowsLightCorona: Bool = false,
        lightMultiple: UInt8 = 4,
        special: SpecialFace? = nil
    ) {
        self.corners = corners
        self.flags = flags
        self.portalIndex = portalIndex
        self.texture = texture
        self.lightmapInfoIndex = lightmapInfoIndex
        self.allowsLightCorona = allowsLightCorona
        self.lightMultiple = lightMultiple
        self.special = special
    }
}

struct LevelPortal: Codable, Equatable, Sendable {
    var flags: UInt32
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

struct IndoorNavigationEdge: Codable, Equatable, Sendable {
    let destinationRoomSourceIndex: Int
    let destinationNodeIndex: Int
    let flags: Int
    let cost: Int
    let maximumRadius: Float
}

struct IndoorNavigationNode: Codable, Equatable, Sendable {
    let position: Vector3
    let edges: [IndoorNavigationEdge]
}

struct IndoorNavigationRoom: Codable, Equatable, Sendable {
    let sourceIndex: Int
    let nodes: [IndoorNavigationNode]
}

struct IndoorNavigationGraph: Codable, Equatable, Sendable {
    let sourceHighestRoomPlusTerrainRegions: Int
    let sourceWasVerified: Bool
    let rooms: [IndoorNavigationRoom]
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
    var name: String?
    let pathPoint: Vector3
    var vertices: [Vector3]
    var faces: [LevelFace]
    var portals: [LevelPortal]
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
    var location: SpatialLocation
    var position: Vector3
    var orientation: Matrix3
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
    let rgba8: Data?

    init(width: Int, height: Int, rgba8: Data? = nil) {
        self.width = width
        self.height = height
        self.rgba8 = rgba8
    }
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

struct CanonicalRGBA8Image: Codable, Equatable, Sendable {
    let width: Int
    let height: Int
    let rgba8: Data
}

enum PresentationBlend: Codable, Equatable, Sendable {
    case opaque
    case sourceAlpha(opacity: UInt8)
    case additiveSourceAlpha(opacity: UInt8)
}

enum PresentationLightmapBlend: String, Codable, Equatable, Sendable {
    case multiply
    case none
}

enum WaterProceduralElementKind: String, Codable, Equatable, Sendable {
    case noOp
    case heightBlob
}

struct WaterProceduralElement: Codable, Equatable, Sendable {
    let kind: WaterProceduralElementKind
    let frequency: UInt8
    let speed: UInt8
    let size: UInt8
    let x1: UInt8
    let y1: UInt8
    let x2: UInt8
    let y2: UInt8
}

struct WaterProceduralDefinition: Codable, Equatable, Sendable {
    let evaluationIntervalSeconds: Float
    let lightingShift: UInt8
    let dampingShift: UInt8
    let elements: [WaterProceduralElement]
}

struct PresentationLightCorona: Codable, Equatable, Sendable {
    let assetIndex: Int
    let tint: Vector3
    let blend: PresentationBlend
}

struct PresentationCoronaAsset: Codable, Equatable, Sendable {
    let source: SourceResource
    let bitmapSourceName: String
    let image: CanonicalRGBA8Image
    let sourceArchive: String
    let sourceSHA256: String
}

struct PresentationMaterial: Codable, Equatable, Sendable {
    let texture: SourceResource
    let bitmapSourceName: String
    let image: CanonicalRGBA8Image
    let blend: PresentationBlend
    let lightmapBlend: PresentationLightmapBlend
    let waterProcedural: WaterProceduralDefinition?
    let lightCorona: PresentationLightCorona?
    let sourceArchive: String
    let sourceSHA256: String

    init(
        texture: SourceResource,
        bitmapSourceName: String,
        image: CanonicalRGBA8Image,
        blend: PresentationBlend,
        lightmapBlend: PresentationLightmapBlend,
        waterProcedural: WaterProceduralDefinition?,
        lightCorona: PresentationLightCorona? = nil,
        sourceArchive: String,
        sourceSHA256: String
    ) {
        self.texture = texture
        self.bitmapSourceName = bitmapSourceName
        self.image = image
        self.blend = blend
        self.lightmapBlend = lightmapBlend
        self.waterProcedural = waterProcedural
        self.lightCorona = lightCorona
        self.sourceArchive = sourceArchive
        self.sourceSHA256 = sourceSHA256
    }
}

enum SurfacePhysicsBehavior: String, Codable, Equatable, Sendable {
    case blocking
    case forceField
    case passThrough
}

struct SurfacePhysicsEntry: Codable, Equatable, Sendable {
    let texture: SourceResource
    let behavior: SurfacePhysicsBehavior
}

struct ModelBounds: Codable, Equatable, Sendable {
    let minimum: Vector3
    let maximum: Vector3
}

struct ModelVertex: Codable, Equatable, Sendable {
    let position: Vector3
    let alpha: Float
}

struct ModelFaceCorner: Codable, Equatable, Sendable {
    let vertexIndex: Int
    let u: Float
    let v: Float
}

enum ModelFaceMaterial: Codable, Equatable, Sendable {
    case texture(SourceResource)
    case sourceColor(red: UInt8, green: UInt8, blue: UInt8)
}

struct ModelFace: Codable, Equatable, Sendable {
    let normal: Vector3
    let corners: [ModelFaceCorner]
    let material: ModelFaceMaterial
}

enum ModelSubmodelPresentation: Codable, Equatable, Sendable {
    case standard
    case custom
    case facing
    case rotate(rate: Float, axis: Vector3)
    case turret(
        fieldOfView: Float,
        rotationsPerSecond: Float,
        thinkInterval: Float,
        axis: Vector3
    )
    case glow(color: Vector3, size: Float)
}

struct ModelSubmodel: Codable, Equatable, Sendable {
    let sourceIndex: Int
    let parentIndex: Int?
    let offset: Vector3
    let vertices: [ModelVertex]
    let faces: [ModelFace]
    let presentation: ModelSubmodelPresentation
}

struct CanonicalModel: Codable, Equatable, Sendable {
    let source: SourceResource
    let collisionRadius: Float
    let submodels: [ModelSubmodel]
    let bounds: ModelBounds
    let sourceArchive: String
    let sourceSHA256: String
}

enum ShipPhysicsBehavior: String, Codable, Equatable, Hashable, Sendable {
    case turnroll
    case wiggle
    case usesThrust
}

struct CanonicalShipPhysics: Codable, Equatable, Sendable {
    let mass: Float
    let drag: Float
    let fullThrust: Float
    let behaviors: [ShipPhysicsBehavior]
    let rotationalDrag: Float
    let fullRotationalThrust: Float
    let numberOfBounces: Int32
    let initialForwardVelocity: Float
    let initialAngularVelocity: Vector3
    let wiggleAmplitude: Float
    let wigglesPerSecond: Float
    let coefficientOfRestitution: Float
    let hitDieDot: Float
    let maximumTurnrollRate: Float
    let turnrollRatio: Float
}

struct CanonicalShipDefinition: Codable, Equatable, Sendable {
    let source: SourceResource
    let primaryModel: SourceResource
    let presentationSize: Float
    let physics: CanonicalShipPhysics
    var playerConcussion: PlayerConcussionBinding? = nil
    var playerYellowFlare: PlayerYellowFlareBinding? = nil
}

struct PlayerConcussionGunpoint: Codable, Equatable, Sendable {
    let index: Int
    let parentSubmodelIndex: Int
    let localPosition: Vector3
    let localForward: Vector3
}

struct PlayerConcussionBinding: Codable, Equatable, Sendable {
    let batteryIndex: Int
    let firingMasks: [UInt8]
    let weapon: SourceResource
    let model: SourceResource
    let fireSoundLogicalNames: [String]
    let fireSoundSourceName: String
    let impactSoundLogicalName: String
    let impactSoundSourceName: String
    let fireWaits: [Float]
    let energyUsage: Float
    let ammoUsage: Float
    let fireFlags: UInt8
    let weaponFlags: UInt16
    let gunpoints: [PlayerConcussionGunpoint]
    let collisionRadius: Float
    let speed: Float
    let lifetime: Float
    let rotationalVelocity: Float
    let lightDistance: Float
    let lightPresentation: TrainingMarkerLightPresentation
    let explosionFrames: [SourceResource]
    let explosionSourceFrameTime: Float
    let explosionSize: Float
    let explosionLifetime: Float
    let directRobotDamage: Float
    let shockwaveDuration: Float
    let shockwaveRadius: Float
    let shockwaveDamage: Float
    let shockwaveForce: Float
}

struct PlayerYellowFlareBinding: Codable, Equatable, Sendable {
    let batteryIndex: Int
    let firingMask: UInt8
    let weapon: SourceResource
    let fireSoundLogicalName: String
    let fireSoundSourceName: String
    let fireWait: Float
    let energyUsage: Float
    let ammoUsage: Float
    let fireFlags: UInt8
    let weaponFlags: UInt16
    let gunpointIndex: Int
    let gunpointParentSubmodelIndex: Int
    let gunpointLocalPosition: Vector3
    let gunpointLocalForward: Vector3
}

struct DefaultPlayerBinding: Codable, Equatable, Sendable {
    let playerID: Int
    let objectHandle: UInt32
    let ship: SourceResource
}

struct ObjectPresentationReference: Codable, Equatable, Sendable {
    let objectHandle: UInt32
    let primaryModel: SourceResource
    let mediumModel: SourceResource?
    let lowModel: SourceResource?
    let dyingModel: SourceResource?
    let mediumDistance: Float?
    let lowDistance: Float?
    let isVisible: Bool

    init(
        objectHandle: UInt32,
        primaryModel: SourceResource,
        mediumModel: SourceResource?,
        lowModel: SourceResource?,
        dyingModel: SourceResource?,
        mediumDistance: Float?,
        lowDistance: Float?,
        isVisible: Bool = true
    ) {
        self.objectHandle = objectHandle
        self.primaryModel = primaryModel
        self.mediumModel = mediumModel
        self.lowModel = lowModel
        self.dyingModel = dyingModel
        self.mediumDistance = mediumDistance
        self.lowDistance = lowDistance
        self.isVisible = isVisible
    }
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
