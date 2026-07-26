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

struct TrainingOpeningLesson: Codable, Equatable, Sendable {
    var forwardGoalObjectHandle: UInt32
    let welcomeDelay: Float
    let welcomeMessage: String
    let forwardInstruction: String
    let welcomeVoiceSourceName: String
    let successMessage: String
    let reverseInstruction: String
    let successVoiceSourceName: String
}

struct TrainingGalleryBarrier: Codable, Equatable, Sendable {
    let triggerName: String
    let triggerRoomSourceIndex: Int
    let triggerFaceIndex: Int
    let barrierRoomSourceIndex: Int
    let orderedPortalIndices: [Int]
    let markerLightObjectHandle: UInt32
    let openMarkerLightDistance: Float
    let successMessage: String
    let guidebotInstruction: String
    let voiceSourceName: String
}

struct TrainingRobotGuidebotChain: Codable, Equatable, Sendable {
    let destroyRobotObjectHandle: UInt32
    let guidebotObjectHandle: UInt32
    let destroyRobotRoomSourceIndex: Int
    let destroyRobotFlags: UInt32
    let destructionDelay: Float
    let destructionMessage: String
    let exitInstruction: String
    let destructionVoiceSourceName: String
    let deployedGuidebotObjectType: UInt8
    let deployedGuidebotMessage: String
    let deployedGuidebotVoiceSourceName: String
    let combat: TrainingRobotCombatDefinition
    let guidebot: TrainingGuidebotDefinition
}

struct TrainingCameraMonitorChain: Codable, Equatable, Sendable {
    let pickupObjectHandle: UInt32
    let securityCameraObjectHandle: UInt32
    let pickupCollisionRadius: Float
    let pickupMessage: String
    let pickupVoiceSourceName: String
    let pickupSoundSourceName: String
    let useMessage: String
    let useVoiceSourceName: String
    let popupDuration: Float
    let popupZoom: Float
    let cameraGunpointIndex: Int
    let cameraLocalPosition: Vector3
    let cameraLocalForward: Vector3
    let completionTimerDuration: Float
}

struct TrainingRobotCombatDefinition: Codable, Equatable, Sendable {
    let robotShields: Float
    let robotCollisionRadius: Float
    let batteryEnergyCost: Float
    let batteryFireWait: Float
    let gunpoints: [Vector3]
    let projectileSourceName: String
    let projectileDamage: Float
    let projectileRadius: Float
    let projectileSpeed: Float
    let projectileLifetime: Float
}

struct TrainingGuidebotDefinition: Codable, Equatable, Sendable {
    let collisionRadius: Float
    let maximumVelocity: Float
    let maximumDeltaVelocity: Float
    let birthForwardVelocity: Float
    let goalForwardDistance: Float
    let goalCircleDistance: Float
}

extension TrainingRobotCombatDefinition {
    static let stockTraining = Self(
        robotShields: 55,
        robotCollisionRadius: 4.576_441_8,
        batteryEnergyCost: 0.15,
        batteryFireWait: 0.25,
        gunpoints: [
            .init(
                x: 2.792_412_5,
                y: -1.186_958_9,
                z: 2.687_090_9
            ),
            .init(
                x: -2.804_046_4,
                y: -1.186_885,
                z: 2.687_135_2
            ),
        ],
        projectileSourceName: "Laser Level 2 - Blue",
        projectileDamage: 7.5,
        projectileRadius: 1.25,
        projectileSpeed: 225,
        projectileLifetime: 5
    )
}

extension TrainingGuidebotDefinition {
    static let stockTraining = Self(
        collisionRadius: 5.659_440_5,
        maximumVelocity: 60,
        maximumDeltaVelocity: 199.999_98,
        birthForwardVelocity: 40,
        goalForwardDistance: 200,
        goalCircleDistance: 1
    )
}

struct CanonicalVoiceClip: Codable, Equatable, Sendable {
    let sourceName: String
    let sourceEntryIndex: Int
    let sampleRate: Int
    let channelCount: Int
    let frameCount: Int
    let pcm16LittleEndian: Data
    let pcmSHA256: String
    let sourceArchive: String
    let sourceSHA256: String
}

struct CanonicalSoundClip: Codable, Equatable, Sendable {
    let logicalName: String
    let sourceName: String
    let sourceEntryIndex: Int
    let sampleRate: Int
    let channelCount: Int
    let frameCount: Int
    let pcm16LittleEndian: Data
    let pcmSHA256: String
    let sourceArchive: String
    let sourceSHA256: String
    let importVolume: Float
}

@propertyWrapper
struct SchemaCompatibleSoundClips:
    Codable, Equatable, Sendable
{
    var wrappedValue: [CanonicalSoundClip]
    let wasPresent: Bool

    init(wrappedValue: [CanonicalSoundClip]) {
        self.wrappedValue = wrappedValue
        wasPresent = true
    }

    fileprivate init(missing: Void) {
        wrappedValue = []
        wasPresent = false
    }

    init(from decoder: Decoder) throws {
        wrappedValue = try decoder.singleValueContainer()
            .decode([CanonicalSoundClip].self)
        wasPresent = true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    func decode(
        _ type: SchemaCompatibleSoundClips.Type,
        forKey key: Key
    ) throws -> SchemaCompatibleSoundClips {
        try decodeIfPresent(type, forKey: key)
            ?? SchemaCompatibleSoundClips(missing: ())
    }
}

func validateStockTrainingRobotGuidebotPackage(
    chain: TrainingRobotGuidebotChain?,
    guidebotB: CanonicalVoiceClip?,
    proceed5: CanonicalVoiceClip?
) throws {
    guard let chain,
          chain.destroyRobotObjectHandle == 4_112,
          chain.guidebotObjectHandle == 6_164,
          chain.destroyRobotRoomSourceIndex == 37,
          chain.destroyRobotFlags == 5_121,
          chain.destructionDelay == 2,
          chain.destructionMessage == "Excellent!",
          chain.exitInstruction
            == "Now go through the open doorway, and into the next room.",
          chain.destructionVoiceSourceName == "proceed5.osf",
          chain.deployedGuidebotObjectType == 2,
          chain.deployedGuidebotMessage
            == "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
          chain.deployedGuidebotVoiceSourceName == "guidebotb.osf",
          chain.combat == .stockTraining,
          chain.guidebot == .stockTraining,
          guidebotB?.sourceName.caseInsensitiveCompare("guidebotb.osf")
            == .orderedSame,
          guidebotB?.sourceEntryIndex == 5,
          guidebotB?.sampleRate == 22_050,
          guidebotB?.channelCount == 1,
          guidebotB?.frameCount == 299_701,
          guidebotB?.pcmSHA256
            == "11ac67df4f4fe234104ca32b97299539e590a6e6d7a826e85d3c1a10ccc52fe4",
          guidebotB?.sourceArchive == "missions/training.mn3",
          guidebotB?.sourceSHA256
            == "0238e793083d875d233d18eaf018aa4526d34cf0c6bed0e659e4725ff8c7ffda",
          proceed5?.sourceName.caseInsensitiveCompare("proceed5.osf")
            == .orderedSame,
          proceed5?.sourceEntryIndex == 25,
          proceed5?.sampleRate == 22_050,
          proceed5?.channelCount == 1,
          proceed5?.frameCount == 136_341,
          proceed5?.pcmSHA256
            == "3ec85db25577616344f6289a319ad01b8fa6406e49f4452ef39f268ddf830490",
          proceed5?.sourceArchive == "missions/training.mn3",
          proceed5?.sourceSHA256
            == "4bbb54d28b38ae48d665e16493c67a82c59ec213c23527a100aa67db671c477c"
    else {
        throw LevelValidationError.invalidDependency(
            "Training robot and Guidebot package"
        )
    }
}

func validateStockTrainingRobotGuidebotPresentation(
    chain: TrainingRobotGuidebotChain,
    modelSources: [SourceResource],
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    let buddybotModels = modelSources.filter {
        $0.sourceName.caseInsensitiveCompare("Buddybot.oof") == .orderedSame
    }
    let gyroModels = modelSources.filter {
        $0.sourceName.caseInsensitiveCompare("gyro.oof") == .orderedSame
    }
    guard buddybotModels.count == 1,
          gyroModels.count == 1,
          objects.contains(where: {
              $0.handle == chain.guidebotObjectHandle
                  && $0.type == 2
                  && $0.storedID == 0
                  && $0.definition?.sourceName == "GuideBot"
                  && $0.instanceName == "GuideBotB"
                  && $0.flags == 0x110f
          }),
          objectPresentations.contains(where: {
              $0.objectHandle == chain.guidebotObjectHandle
                  && $0.primaryModel == buddybotModels[0]
                  && !$0.isVisible
          }),
          objectPresentations.contains(where: {
              $0.objectHandle == 4_112
                  && $0.primaryModel == gyroModels[0]
                  && $0.mediumModel == nil
                  && $0.lowModel == nil
                  && $0.dyingModel == nil
                  && $0.mediumDistance == nil
                  && $0.lowDistance == nil
                  && $0.isVisible
          }) else {
        throw LevelValidationError.invalidDependency(
            "Training robot and Guidebot presentation"
        )
    }
}

private func canonicalPCM16ByteCount(
    frameCount: Int,
    channelCount: Int
) -> Int? {
    let (sampleCount, sampleOverflow) =
        frameCount.multipliedReportingOverflow(by: channelCount)
    guard !sampleOverflow else { return nil }
    let (byteCount, byteOverflow) =
        sampleCount.multipliedReportingOverflow(by: 2)
    return byteOverflow ? nil : byteCount
}

func validateStockTrainingCameraMonitorPackage(
    chain: TrainingCameraMonitorChain?,
    guidebotC: CanonicalVoiceClip?,
    guidebotD: CanonicalVoiceClip?,
    pickupSound: CanonicalSoundClip?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    guard let chain,
          chain == .init(
            pickupObjectHandle: 6_167,
            securityCameraObjectHandle: 6_183,
            pickupCollisionRadius: 3.682_004,
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
            cameraLocalPosition: .init(
                x: -0.092_777_25,
                y: 0.791_976,
                z: 5.571_280_5
            ),
            cameraLocalForward: .init(
                x: -2.880_202e-7,
                y: -0.017_452_003,
                z: 0.999_847_7
            ),
            completionTimerDuration: 2
          ),
          guidebotC?.sourceEntryIndex == 6,
          guidebotC?.sampleRate == 22_050,
          guidebotC?.channelCount == 1,
          guidebotC?.frameCount == 273_181,
          guidebotC?.pcmSHA256
            == "b5d968ac310d7d95780f2abd58933e7fdce20d284a9ef614e18e9f8eea3e18de",
          guidebotC?.sourceArchive == "missions/training.mn3",
          guidebotC?.sourceSHA256
            == "20d0d1e82f56c7c4d326788ac9caa1dc39ec81d4a022be52967776ec5fa85dc1",
          guidebotD?.sourceEntryIndex == 7,
          guidebotD?.sampleRate == 22_050,
          guidebotD?.channelCount == 1,
          guidebotD?.frameCount == 149_653,
          guidebotD?.pcmSHA256
            == "d97e6efaa106fbe9c4dff0affe155e04db18938e842be494292d0008b10f2a71",
          guidebotD?.sourceArchive == "missions/training.mn3",
          guidebotD?.sourceSHA256
            == "afffa8e1a39b1c6e8956105c52db8fa372a33b763aa44e18980f2e22884795d1",
          pickupSound?.logicalName == "PupC1",
          pickupSound?.sourceName == "PupC.wav",
          pickupSound?.sourceEntryIndex == 130,
          pickupSound?.sampleRate == 22_050,
          pickupSound?.channelCount == 1,
          pickupSound?.frameCount == 16_759,
          pickupSound?.pcmSHA256
            == "6cc9a2c4853f3575838d8ef16f51847e4c990140d5206158a582abddf130f099",
          pickupSound?.sourceArchive == "d3.hog",
          pickupSound?.sourceSHA256
            == "d3e8e7515facfd6c1b540e70cf7f1019c3d1f13f24140bee76337e5bb37de7d0",
          pickupSound?.importVolume == 1,
          objects.contains(where: {
              $0.handle == 6_167
                  && $0.type == 7
                  && $0.storedID == 91
                  && $0.definition?.sourceName == "Camera Monitor"
                  && $0.instanceName == "CameraMonitor"
                  && $0.flags == 4_096
          }),
          objects.contains(where: {
              $0.handle == 6_183
                  && $0.type == 2
                  && $0.storedID == 114
                  && $0.definition?.sourceName == "new wall cam"
                  && $0.instanceName == "SecurityCamera"
                  && $0.flags == 5_120
          }),
          objectPresentations.contains(where: {
              $0.objectHandle == 6_167
                  && $0.primaryModel.sourceName
                    .caseInsensitiveCompare("camerapowerup.OOF")
                    == .orderedSame
                  && $0.isVisible
          }) else {
        throw LevelValidationError.invalidDependency(
            "Training Camera Monitor package"
        )
    }
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

struct Level: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let missionKey: String
    let levelKey: String
    let source: LevelSource
    let metadata: LevelMetadata
    var rooms: [LevelRoom]
    let terrain: LevelTerrain
    var objects: [PlacedObject]
    let retiredObjectHandles: [UInt32]
    let paths: [GamePath]
    var goals: [LevelGoal]
    let goalFlags: UInt32
    let triggers: [LevelTrigger]
    let playerStartFlags: [UInt32]
    let indoorNavigation: IndoorNavigationGraph?
    let lightmaps: LightmapCatalog
    let surfacePhysics: [SurfacePhysicsEntry]
    let presentationMaterials: [PresentationMaterial]
    let presentationCoronaAssets: [PresentationCoronaAsset]
    let models: [CanonicalModel]
    let shipDefinitions: [CanonicalShipDefinition]
    let defaultPlayerBinding: DefaultPlayerBinding?
    var objectPresentations: [ObjectPresentationReference]
    var trainingOpeningLesson: TrainingOpeningLesson?
    let trainingGalleryBarrier: TrainingGalleryBarrier?
    let trainingRobotGuidebotChain: TrainingRobotGuidebotChain?
    let trainingCameraMonitorChain: TrainingCameraMonitorChain?
    let voiceClips: [CanonicalVoiceClip]
    @SchemaCompatibleSoundClips
    private(set) var soundClips: [CanonicalSoundClip]
    let dependencyManifest: DependencyManifest
    let sourceChunks: [SourceChunkRecord]

    init(
        schemaVersion: Int = 9,
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
        indoorNavigation: IndoorNavigationGraph? = nil,
        lightmaps: LightmapCatalog,
        surfacePhysics: [SurfacePhysicsEntry]? = nil,
        presentationMaterials: [PresentationMaterial] = [],
        presentationCoronaAssets: [PresentationCoronaAsset] = [],
        models: [CanonicalModel] = [],
        shipDefinitions: [CanonicalShipDefinition] = [],
        defaultPlayerBinding: DefaultPlayerBinding? = nil,
        objectPresentations: [ObjectPresentationReference] = [],
        trainingOpeningLesson: TrainingOpeningLesson? = nil,
        trainingGalleryBarrier: TrainingGalleryBarrier? = nil,
        trainingRobotGuidebotChain: TrainingRobotGuidebotChain? = nil,
        trainingCameraMonitorChain: TrainingCameraMonitorChain? = nil,
        voiceClips: [CanonicalVoiceClip] = [],
        soundClips: [CanonicalSoundClip] = [],
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
        self.indoorNavigation = indoorNavigation
        self.lightmaps = lightmaps
        self.surfacePhysics = surfacePhysics ?? Self.defaultSurfacePhysics(for: rooms)
        self.presentationMaterials = presentationMaterials
        self.presentationCoronaAssets = presentationCoronaAssets
        self.models = models
        self.shipDefinitions = shipDefinitions
        self.defaultPlayerBinding = defaultPlayerBinding
        self.objectPresentations = objectPresentations
        self.trainingOpeningLesson = trainingOpeningLesson
        self.trainingGalleryBarrier = trainingGalleryBarrier
        self.trainingRobotGuidebotChain = trainingRobotGuidebotChain
        self.trainingCameraMonitorChain = trainingCameraMonitorChain
        self.voiceClips = voiceClips
        self.soundClips = soundClips
        self.dependencyManifest = dependencyManifest
        self.sourceChunks = sourceChunks
    }

    func validate() throws {
        try validate(allowImportStagingPresentation: false)
    }

    func validateForImportStaging() throws {
        try validate(allowImportStagingPresentation: true)
    }

    private func validate(allowImportStagingPresentation: Bool) throws {
        guard (schemaVersion == 9 && trainingCameraMonitorChain == nil
                || schemaVersion == 10
                    && trainingCameraMonitorChain != nil
                    && _soundClips.wasPresent),
              source.d3lvVersion == 127,
              !missionKey.isEmpty, !levelKey.isEmpty else {
            throw LevelValidationError.invalidIdentity
        }
        try validateSource(source)
        try validateLightmaps(lightmaps)
        try validatePresentation(
            materials: presentationMaterials,
            coronaAssets: presentationCoronaAssets,
            source: source
        )
        try validateModels(
            models,
            objectPresentations: objectPresentations,
            materials: presentationMaterials,
            objects: objects,
            source: source,
            dynamicallyPresentedModelNames:
                trainingRobotGuidebotChain == nil
                    ? []
                    : ["Buddybot.oof"]
        )
        guard rooms.count <= 400,
              rooms.allSatisfy({ (0..<400).contains($0.sourceIndex) }) else {
            throw LevelValidationError.invalidCount("rooms")
        }
        guard Set(rooms.map(\.sourceIndex)).count == rooms.count else {
            throw LevelValidationError.duplicateRoom
        }
        try validateSurfacePhysics(
            surfacePhysics,
            rooms: rooms,
            allowIncomplete: allowImportStagingPresentation
        )
        try validatePlayerShipBinding()
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
        try validateIndoorNavigation(indoorNavigation, rooms: roomMap)

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
                let cornerIndices = face.corners.map(\.vertexIndex)
                guard Set(cornerIndices).count == cornerIndices.count else {
                    throw LevelValidationError.degenerateFace(
                        room: room.sourceIndex,
                        face: faceIndex
                    )
                }
                guard let normal = canonicalFaceNormal(room: room, face: face) else {
                    throw LevelValidationError.invalidFace(room: room.sourceIndex, face: faceIndex)
                }
                guard faceIsPlanar(room: room, face: face, normal: normal) else {
                    throw LevelValidationError.nonplanarFace(
                        room: room.sourceIndex,
                        face: faceIndex
                    )
                }
                guard !faceIsConcave(room: room, face: face, normal: normal) else {
                    throw LevelValidationError.concaveFace(
                        room: room.sourceIndex,
                        face: faceIndex
                    )
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

        for room in rooms {
            for (portalIndex, portal) in room.portals.enumerated() {
                let connected = roomMap[portal.connectedRoom]!
                let inverse = connected.portals[portal.connectedPortal]
                guard reciprocalPortalGeometryMatches(
                    room: room,
                    portal: portal,
                    connectedRoom: connected,
                    connectedPortal: inverse
                ) else {
                    throw LevelValidationError.mismatchedPortalGeometry(
                        room: room.sourceIndex,
                        portal: portalIndex
                    )
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
            guard isFinite(object.position) else {
                throw LevelValidationError.invalidObjectPosition(object.handle)
            }
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
        if let lesson = trainingOpeningLesson {
            let clipNames = Set(voiceClips.map { $0.sourceName.lowercased() })
            guard lesson.welcomeDelay.isFinite,
                  lesson.welcomeDelay > 0,
                  isNonempty(lesson.welcomeMessage),
                  isNonempty(lesson.forwardInstruction),
                  isNonempty(lesson.welcomeVoiceSourceName),
                  isNonempty(lesson.successMessage),
                  isNonempty(lesson.reverseInstruction),
                  isNonempty(lesson.successVoiceSourceName),
                  let target = objects.first(where: {
                      $0.handle == lesson.forwardGoalObjectHandle
                  }),
                  target.type == 7,
                  objectPresentations.contains(where: {
                      $0.objectHandle == target.handle && !$0.isVisible
                  }),
                  clipNames.contains(lesson.welcomeVoiceSourceName.lowercased()),
                  clipNames.contains(lesson.successVoiceSourceName.lowercased()) else {
                throw LevelValidationError.invalidDependency(
                    "Training opening lesson"
                )
            }
        }
        if let barrier = trainingGalleryBarrier {
            let oneShotFlag: UInt16 = 8
            let playerActivator: UInt16 = 1
            let rendersFaces: UInt32 = 1
            let clipNames = Set(voiceClips.map {
                $0.sourceName.lowercased()
            })
            guard isNonempty(barrier.triggerName),
                  isNonempty(barrier.successMessage),
                  isNonempty(barrier.guidebotInstruction),
                  isNonempty(barrier.voiceSourceName),
                  barrier.openMarkerLightDistance.isFinite,
                  barrier.openMarkerLightDistance > 0,
                  barrier.orderedPortalIndices.count == 2,
                  Set(barrier.orderedPortalIndices).count == 2,
                  let markerLight = objects.first(where: {
                      $0.handle == barrier.markerLightObjectHandle
                  }),
                  markerLight.type == 11,
                  markerLight.instanceName == "FlashLight-2",
                  clipNames.contains(barrier.voiceSourceName.lowercased()),
                  triggers.contains(where: {
                      $0.name == barrier.triggerName
                          && $0.roomIndex
                              == barrier.triggerRoomSourceIndex
                          && $0.faceIndex == barrier.triggerFaceIndex
                          && $0.flags == oneShotFlag
                          && $0.activator == playerActivator
                  }),
                  let triggerRoom =
                    roomMap[barrier.triggerRoomSourceIndex],
                  triggerRoom.faces.indices.contains(
                      barrier.triggerFaceIndex
                  ),
                  let barrierRoom =
                    roomMap[barrier.barrierRoomSourceIndex]
            else {
                throw LevelValidationError.invalidDependency(
                    "Training gallery barrier"
                )
            }
            var portalRenderingStates: [Bool] = []
            for portalIndex in barrier.orderedPortalIndices {
                guard barrierRoom.portals.indices.contains(portalIndex)
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training gallery barrier"
                    )
                }
                let portal = barrierRoom.portals[portalIndex]
                guard barrierRoom.faces.indices.contains(portal.faceIndex),
                      barrierRoom.faces[portal.faceIndex].portalIndex
                          == portalIndex,
                      let physics = surfacePhysics.first(where: {
                          $0.texture
                              == barrierRoom.faces[portal.faceIndex].texture
                      }),
                      physics.behavior == .forceField,
                      presentationMaterials.contains(where: {
                          $0.texture
                              == barrierRoom.faces[portal.faceIndex].texture
                              && $0.waterProcedural != nil
                      }),
                      let connectedRoom = roomMap[portal.connectedRoom],
                      connectedRoom.portals.indices.contains(
                          portal.connectedPortal
                      )
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training gallery barrier"
                    )
                }
                let reciprocal =
                    connectedRoom.portals[portal.connectedPortal]
                guard reciprocal.connectedRoom
                        == barrier.barrierRoomSourceIndex,
                      reciprocal.connectedPortal == portalIndex,
                      connectedRoom.faces.indices.contains(
                          reciprocal.faceIndex
                      ),
                      connectedRoom.faces[reciprocal.faceIndex].portalIndex
                          == portal.connectedPortal,
                      let reciprocalPhysics =
                        surfacePhysics.first(where: {
                            $0.texture
                                == connectedRoom.faces[
                                    reciprocal.faceIndex
                                ].texture
                        }),
                      reciprocalPhysics.behavior == .forceField,
                      presentationMaterials.contains(where: {
                          $0.texture
                              == connectedRoom.faces[
                                  reciprocal.faceIndex
                              ].texture
                              && $0.waterProcedural != nil
                      })
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training gallery barrier"
                    )
                }
                portalRenderingStates.append(
                    barrierRoom.portals[portalIndex].flags
                        & rendersFaces != 0
                )
                portalRenderingStates.append(
                    reciprocal.flags & rendersFaces != 0
                )
            }
            guard Set(portalRenderingStates).count == 1 else {
                throw LevelValidationError.invalidDependency(
                    "Training gallery barrier"
                )
            }
        }
        if let chain = trainingRobotGuidebotChain {
            let clipNames = Set(voiceClips.map {
                $0.sourceName.lowercased()
            })
            guard trainingGalleryBarrier != nil,
                  chain.destructionDelay.isFinite,
                  chain.destructionDelay > 0,
                  isNonempty(chain.destructionMessage),
                  isNonempty(chain.exitInstruction),
                  isNonempty(chain.destructionVoiceSourceName),
                  isNonempty(chain.deployedGuidebotMessage),
                  isNonempty(chain.deployedGuidebotVoiceSourceName),
                  chain.deployedGuidebotObjectType == 2,
                  chain.combat == .stockTraining,
                  chain.guidebot == .stockTraining,
                  let robot = objects.first(where: {
                      $0.handle == chain.destroyRobotObjectHandle
                  }),
                  robot.type == 2,
                  robot.storedID == 106,
                  robot.definition?.sourceName
                    == "RAS1 Light Security Flyer",
                  robot.instanceName == "DestroyBot2",
                  robot.location
                    == .room(chain.destroyRobotRoomSourceIndex),
                  robot.flags == chain.destroyRobotFlags,
                  clipNames.contains(
                    chain.destructionVoiceSourceName.lowercased()
                  ),
                  clipNames.contains(
                    chain.deployedGuidebotVoiceSourceName.lowercased()
                  ) else {
                throw LevelValidationError.invalidDependency(
                    "Training robot Guidebot chain"
                )
            }
        }
        if let chain = trainingCameraMonitorChain {
            let clipNames = Set(voiceClips.map {
                $0.sourceName.lowercased()
            })
            let soundNames = Set(soundClips.map {
                $0.sourceName.lowercased()
            })
            guard trainingRobotGuidebotChain != nil,
                  chain.pickupObjectHandle
                    != chain.securityCameraObjectHandle,
                  chain.pickupCollisionRadius.isFinite,
                  chain.pickupCollisionRadius > 0,
                  chain.popupDuration.isFinite,
                  chain.popupDuration > 0,
                  chain.popupZoom.isFinite,
                  chain.popupZoom > 0,
                  chain.cameraGunpointIndex >= 0,
                  isFinite(chain.cameraLocalPosition),
                  abs(
                    dot(
                        chain.cameraLocalForward,
                        chain.cameraLocalForward
                    ) - 1
                  ) < 0.000_1,
                  chain.completionTimerDuration.isFinite,
                  chain.completionTimerDuration > 0,
                  isNonempty(chain.pickupMessage),
                  isNonempty(chain.useMessage),
                  let pickup = objects.first(where: {
                      $0.handle == chain.pickupObjectHandle
                  }),
                  pickup.type == 7,
                  pickup.storedID == 91,
                  pickup.definition?.sourceName == "Camera Monitor",
                  pickup.instanceName == "CameraMonitor",
                  pickup.flags == 4_096,
                  let camera = objects.first(where: {
                      $0.handle == chain.securityCameraObjectHandle
                  }),
                  camera.type == 2,
                  camera.storedID == 114,
                  camera.definition?.sourceName == "new wall cam",
                  camera.instanceName == "SecurityCamera",
                  camera.flags == 5_120,
                  clipNames.contains(
                    chain.pickupVoiceSourceName.lowercased()
                  ),
                  clipNames.contains(
                    chain.useVoiceSourceName.lowercased()
                  ),
                  soundNames.contains(
                    chain.pickupSoundSourceName.lowercased()
                  ),
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.pickupObjectHandle
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training Camera Monitor chain"
                )
            }
        }
        var voiceNames = Set<String>()
        for clip in voiceClips {
            let voiceSource = SourceResource(
                storedIndex: clip.sourceEntryIndex,
                sourceName: clip.sourceName
            )
            guard D3SourceIdentity.isValidSourceResource(
                    voiceSource,
                    category: "voice"
                  ),
                  voiceNames.insert(clip.sourceName.lowercased()).inserted,
                  (4_096...192_000).contains(clip.sampleRate),
                  (1...2).contains(clip.channelCount),
                  clip.frameCount > 0,
                  canonicalPCM16ByteCount(
                    frameCount: clip.frameCount,
                    channelCount: clip.channelCount
                  ) == clip.pcm16LittleEndian.count,
                  isSHA256(clip.pcmSHA256),
                  canonicalSHA256(clip.pcm16LittleEndian)
                    == clip.pcmSHA256,
                  isSafeRelativePath(clip.sourceArchive),
                  source.profileFiles.contains(where: {
                      $0.relativePath == clip.sourceArchive
                  }),
                  isSHA256(clip.sourceSHA256),
                  dependencyManifest.current.contains(where: {
                      $0.category == "voice" && $0.source == voiceSource
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Canonical voice clip"
                )
            }
        }
        var soundNames = Set<String>()
        for clip in soundClips {
            let soundSource = SourceResource(
                storedIndex: clip.sourceEntryIndex,
                sourceName: clip.sourceName
            )
            guard D3SourceIdentity.isValidSourceResource(
                    soundSource,
                    category: "sound"
                  ),
                  soundNames.insert(clip.sourceName.lowercased()).inserted,
                  isNonempty(clip.logicalName),
                  (4_096...192_000).contains(clip.sampleRate),
                  (1...2).contains(clip.channelCount),
                  clip.frameCount > 0,
                  canonicalPCM16ByteCount(
                    frameCount: clip.frameCount,
                    channelCount: clip.channelCount
                  ) == clip.pcm16LittleEndian.count,
                  isSHA256(clip.pcmSHA256),
                  canonicalSHA256(clip.pcm16LittleEndian)
                    == clip.pcmSHA256,
                  isSafeRelativePath(clip.sourceArchive),
                  source.profileFiles.contains(where: {
                      $0.relativePath == clip.sourceArchive
                  }),
                  isSHA256(clip.sourceSHA256),
                  clip.importVolume.isFinite,
                  clip.importVolume >= 0,
                  dependencyManifest.current.contains(where: {
                      $0.category == "sound" && $0.source == soundSource
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Canonical sound clip"
                )
            }
        }
        let hasStockTrainingSource =
            source.archiveSHA256
                == "fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54"
            && source.levelSHA256
                == "915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41"
        if hasStockTrainingSource && !allowImportStagingPresentation {
            let welcome = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("welcome.osf")
                    == .orderedSame
            }
            let return1 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("return1.osf")
                    == .orderedSame
            }
            let guidebotA = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("guidebota.osf")
                    == .orderedSame
            }
            let guidebotB = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("guidebotb.osf")
                    == .orderedSame
            }
            let proceed5 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("proceed5.osf")
                    == .orderedSame
            }
            let guidebotC = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("guidebotc.osf")
                    == .orderedSame
            }
            let guidebotD = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("guidebotd.osf")
                    == .orderedSame
            }
            guard let lesson = trainingOpeningLesson,
                  missionKey == "descent3.mission.pilot-training",
                  levelKey == "descent3.level.training-mission",
                  lesson.forwardGoalObjectHandle == 12_301,
                  lesson.welcomeDelay == 1,
                  welcome?.sourceEntryIndex == 38,
                  welcome?.sampleRate == 22_050,
                  welcome?.channelCount == 1,
                  welcome?.frameCount == 417_957,
                  welcome?.pcmSHA256
                    == "116eda34ab4af47c9a59e514af6ba111ef41e344fadeadb8120ad76728b81fe9",
                  welcome?.sourceArchive == "missions/training.mn3",
                  welcome?.sourceSHA256
                    == "35e31517adb824f3637b877d500e12625b99d1a7044a2ce743087505c88ece36",
                  return1?.sourceEntryIndex == 28,
                  return1?.sampleRate == 22_050,
                  return1?.channelCount == 1,
                  return1?.frameCount == 83_929,
                  return1?.pcmSHA256
                    == "95ffd4396b10462438ed10fb9ed9f7e5ff01a37ff1ad93481c989b047dae9dc3",
                  return1?.sourceArchive == "missions/training.mn3",
                  return1?.sourceSHA256
                    == "048067398846141f61a2d503f6ec582f0dbbc5f3bf3feead48047eab808e540f"
            else {
                throw LevelValidationError.invalidDependency(
                    "Training opening package"
                )
            }
            guard let barrier = trainingGalleryBarrier,
                  barrier.triggerName == "Portal2",
                  barrier.triggerRoomSourceIndex == 38,
                  barrier.triggerFaceIndex == 1,
                  barrier.barrierRoomSourceIndex == 38,
                  barrier.orderedPortalIndices == [1, 0],
                  barrier.markerLightObjectHandle == 6_163,
                  barrier.openMarkerLightDistance == 50,
                  barrier.successMessage == "Excellent!",
                  barrier.guidebotInstruction
                    == "Your ship is equipped with a utility robot called a Guidebot.  Release him now with F4.",
                  barrier.voiceSourceName == "guidebota.osf",
                  voiceClips.count
                    == (trainingCameraMonitorChain == nil ? 5 : 7),
                  guidebotA?.sourceEntryIndex == 4,
                  guidebotA?.sampleRate == 22_050,
                  guidebotA?.channelCount == 1,
                  guidebotA?.frameCount == 354_793,
                  guidebotA?.pcmSHA256
                    == "c806147adb0ceb7c2bd8eac0853ba107da49012f5de8685f915d3e3a80f51b4f",
                  guidebotA?.sourceArchive == "missions/training.mn3",
                  guidebotA?.sourceSHA256
                    == "dde58be4bd488cc7a009068afd15ddb18f8cf64dd1ff44fd5a3f8ae816277cad"
            else {
                throw LevelValidationError.invalidDependency(
                    "Training gallery package"
                )
            }
            try validateStockTrainingRobotGuidebotPackage(
                chain: trainingRobotGuidebotChain,
                guidebotB: guidebotB,
                proceed5: proceed5
            )
            try validateStockTrainingRobotGuidebotPresentation(
                chain: trainingRobotGuidebotChain!,
                modelSources: models.map(\.source),
                objects: objects,
                objectPresentations: objectPresentations
            )
            if trainingCameraMonitorChain != nil {
                try validateStockTrainingCameraMonitorPackage(
                    chain: trainingCameraMonitorChain,
                    guidebotC: guidebotC,
                    guidebotD: guidebotD,
                    pickupSound: soundClips.first {
                        $0.logicalName == "PupC1"
                    },
                    objects: objects,
                    objectPresentations: objectPresentations
                )
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
        try validatePlayerPresentationClosure(
            allowIncomplete: allowImportStagingPresentation
        )

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

    func addingPresentationMaterials(
        _ materials: [PresentationMaterial],
        retainingLightmapPages retainedPageIndices: Set<Int>,
        coronaAssets: [PresentationCoronaAsset] = []
    ) -> Level {
        let retainedLightmaps = LightmapCatalog(
            pages: lightmaps.pages.enumerated().map { index, page in
                LightmapPageMetadata(
                    width: page.width,
                    height: page.height,
                    rgba8: retainedPageIndices.contains(index) ? page.rgba8 : nil
                )
            },
            infos: lightmaps.infos
        )
        let materialSources = Set(materials.map(\.texture))
        let coronaSources = Set(coronaAssets.map(\.source))
        var dependencies = dependencyManifest.current.map { dependency in
            let preparedTexture = dependency.category == "texture"
                && materialSources.contains(dependency.source)
            let preparedLightmapPage = dependency.category == "lightmap-page"
                && retainedPageIndices.contains(dependency.source.storedIndex)
            let preparedCorona = dependency.category == "presentation-effect"
                && coronaSources.contains(dependency.source)
            guard preparedTexture || preparedLightmapPage || preparedCorona else {
                if dependency.state == "presentation-payload-imported" {
                    return DependencyRecord(
                        category: dependency.category,
                        source: dependency.source,
                        state: "payload-validated-preparation-deferred",
                        provenance: dependency.provenance
                    )
                }
                return dependency
            }
            return DependencyRecord(
                category: dependency.category,
                source: dependency.source,
                state: "presentation-payload-imported",
                provenance: dependency.provenance
            )
        }
        let existingDependencies = Set(dependencies.map {
            DependencyIdentity(category: $0.category, source: $0.source)
        })
        for asset in coronaAssets where !existingDependencies.contains(
            DependencyIdentity(category: "presentation-effect", source: asset.source)
        ) {
            dependencies.append(
                DependencyRecord(
                    category: "presentation-effect",
                    source: asset.source,
                    state: "presentation-payload-imported",
                    provenance: "D3Import-resolved face-light corona"
                )
            )
        }
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: retainedLightmaps,
            surfacePhysics: surfacePhysics,
            presentationMaterials: materials,
            presentationCoronaAssets: coronaAssets,
            models: models,
            shipDefinitions: shipDefinitions,
            defaultPlayerBinding: defaultPlayerBinding,
            objectPresentations: objectPresentations,
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingObjectPresentation(
        models newModels: [CanonicalModel],
        objectPresentations newObjectPresentations: [ObjectPresentationReference],
        materials newMaterials: [PresentationMaterial]
    ) -> Level {
        let combinedMaterials = presentationMaterials + newMaterials.filter { candidate in
            !presentationMaterials.contains(where: { $0.texture == candidate.texture })
        }
        let reachedModelSources = Set(newModels.map(\.source))
        let reachedTextureSources = referencedModelTextures(in: newModels)
        var dependencies = dependencyManifest.current.map { dependency in
            let reached = dependency.category == "model"
                ? reachedModelSources.contains(dependency.source)
                : dependency.category == "texture"
                    && reachedTextureSources.contains(dependency.source)
            guard reached else { return dependency }
            return DependencyRecord(
                category: dependency.category,
                source: dependency.source,
                state: "presentation-payload-imported",
                provenance: dependency.provenance
            )
        }
        var identities = Set(dependencies.map {
            DependencyIdentity(category: $0.category, source: $0.source)
        })
        for model in newModels where identities.insert(
            .init(category: "model", source: model.source)
        ).inserted {
            dependencies.append(
                .init(
                    category: "model",
                    source: model.source,
                    state: "presentation-payload-imported",
                    provenance: "D3Import-resolved reached object model"
                )
            )
        }
        for texture in reachedTextureSources.sorted(by: sourceResourceIsOrdered)
        where identities.insert(.init(category: "texture", source: texture)).inserted {
            dependencies.append(
                .init(
                    category: "texture",
                    source: texture,
                    state: "presentation-payload-imported",
                    provenance: "D3Import-resolved reached model material"
                )
            )
        }
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: lightmaps,
            surfacePhysics: surfacePhysics,
            presentationMaterials: combinedMaterials,
            presentationCoronaAssets: presentationCoronaAssets,
            models: newModels,
            shipDefinitions: shipDefinitions,
            defaultPlayerBinding: defaultPlayerBinding,
            objectPresentations: newObjectPresentations,
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    var hasPlayerPresentation: Bool {
        !presentationMaterials.isEmpty
            && defaultPlayerBinding != nil
    }

    func addingSurfacePhysics(_ entries: [SurfacePhysicsEntry]) -> Level {
        Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: lightmaps,
            surfacePhysics: entries,
            presentationMaterials: presentationMaterials,
            presentationCoronaAssets: presentationCoronaAssets,
            models: models,
            shipDefinitions: shipDefinitions,
            defaultPlayerBinding: defaultPlayerBinding,
            objectPresentations: objectPresentations,
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingDefaultPlayerShip(
        _ ship: CanonicalShipDefinition,
        binding: DefaultPlayerBinding
    ) -> Level {
        var dependencies = dependencyManifest.current
        let identity = DependencyIdentity(category: "ship-definition", source: ship.source)
        if !dependencies.contains(where: {
            DependencyIdentity(category: $0.category, source: $0.source) == identity
        }) {
            dependencies.append(
                .init(
                    category: "ship-definition",
                    source: ship.source,
                    state: "canonical-typed-definition",
                    provenance: "D3Import-resolved default player ship"
                )
            )
        }
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: lightmaps,
            surfacePhysics: surfacePhysics,
            presentationMaterials: presentationMaterials,
            presentationCoronaAssets: presentationCoronaAssets,
            models: models,
            shipDefinitions: [ship],
            defaultPlayerBinding: binding,
            objectPresentations: objectPresentations,
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingOpeningLesson(
        _ lesson: TrainingOpeningLesson,
        voiceClips: [CanonicalVoiceClip]
    ) -> Level {
        let lessonPresentations = objectPresentations.map { presentation in
            guard presentation.objectHandle == lesson.forwardGoalObjectHandle else {
                return presentation
            }
            return ObjectPresentationReference(
                objectHandle: presentation.objectHandle,
                primaryModel: presentation.primaryModel,
                mediumModel: presentation.mediumModel,
                lowModel: presentation.lowModel,
                dyingModel: presentation.dyingModel,
                mediumDistance: presentation.mediumDistance,
                lowDistance: presentation.lowDistance,
                isVisible: false
            )
        }
        var dependencies = dependencyManifest.current
        for clip in voiceClips {
            dependencies.append(
                .init(
                    category: "voice",
                    source: .init(
                        storedIndex: clip.sourceEntryIndex,
                        sourceName: clip.sourceName
                    ),
                    state: "canonical-pcm-imported",
                    provenance: "\(clip.sourceArchive) \(clip.sourceSHA256)"
                )
            )
        }
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: lightmaps,
            surfacePhysics: surfacePhysics,
            presentationMaterials: presentationMaterials,
            presentationCoronaAssets: presentationCoronaAssets,
            models: models,
            shipDefinitions: shipDefinitions,
            defaultPlayerBinding: defaultPlayerBinding,
            objectPresentations: lessonPresentations,
            trainingOpeningLesson: lesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline: dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingGalleryBarrier(
        _ barrier: TrainingGalleryBarrier,
        voiceClip: CanonicalVoiceClip
    ) -> Level {
        let dependency = DependencyRecord(
            category: "voice",
            source: .init(
                storedIndex: voiceClip.sourceEntryIndex,
                sourceName: voiceClip.sourceName
            ),
            state: "canonical-pcm-imported",
            provenance:
                "\(voiceClip.sourceArchive) \(voiceClip.sourceSHA256)"
        )
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: lightmaps,
            surfacePhysics: surfacePhysics,
            presentationMaterials: presentationMaterials,
            presentationCoronaAssets: presentationCoronaAssets,
            models: models,
            shipDefinitions: shipDefinitions,
            defaultPlayerBinding: defaultPlayerBinding,
            objectPresentations: objectPresentations,
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: barrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            voiceClips: voiceClips + [voiceClip],
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencyManifest.current + [dependency],
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingRobotGuidebotChain(
        _ chain: TrainingRobotGuidebotChain,
        voiceClips addedVoiceClips: [CanonicalVoiceClip]
    ) -> Level {
        var dependencies = addedVoiceClips.map { clip in
            DependencyRecord(
                category: "voice",
                source: .init(
                    storedIndex: clip.sourceEntryIndex,
                    sourceName: clip.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance:
                    "\(clip.sourceArchive) \(clip.sourceSHA256)"
            )
        }
        if !dependencyManifest.current.contains(where: {
            $0.category.caseInsensitiveCompare("object-definition")
                == .orderedSame
                && $0.source.sourceName.caseInsensitiveCompare("GuideBot")
                    == .orderedSame
        }) {
            dependencies.append(.init(
                category: "object-definition",
                source: .init(storedIndex: 0, sourceName: "GuideBot"),
                state: "canonical-reserved-object",
                provenance: "scripts/AIGame.cpp:4668-4728"
            ))
        }
        let player = objects.first {
            $0.handle == defaultPlayerBinding?.objectHandle
        }!
        let guidebotModel = models.first {
            $0.source.sourceName.caseInsensitiveCompare("Buddybot.oof")
                == .orderedSame
        }!
        let guidebotObject = PlacedObject(
            handle: chain.guidebotObjectHandle,
            type: 2,
            storedID: 0,
            definition: .init(storedIndex: 0, sourceName: "GuideBot"),
            instanceName: "GuideBotB",
            flags: 0x110f,
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
        )
        let guidebotPresentation = ObjectPresentationReference(
            objectHandle: chain.guidebotObjectHandle,
            primaryModel: guidebotModel.source,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        return Level(
            schemaVersion: schemaVersion,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects + [guidebotObject],
            retiredObjectHandles: retiredObjectHandles.filter {
                $0 != chain.guidebotObjectHandle
            },
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: lightmaps,
            surfacePhysics: surfacePhysics,
            presentationMaterials: presentationMaterials,
            presentationCoronaAssets: presentationCoronaAssets,
            models: models,
            shipDefinitions: shipDefinitions,
            defaultPlayerBinding: defaultPlayerBinding,
            objectPresentations:
                objectPresentations + [guidebotPresentation],
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: chain,
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            voiceClips: voiceClips + addedVoiceClips,
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencyManifest.current + dependencies,
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingCameraMonitorChain(
        _ chain: TrainingCameraMonitorChain,
        voiceClips addedVoiceClips: [CanonicalVoiceClip],
        soundClip: CanonicalSoundClip
    ) -> Level {
        var dependencies = dependencyManifest.current
        let reachedDependencies = addedVoiceClips.map { clip in
            DependencyRecord(
                category: "voice",
                source: .init(
                    storedIndex: clip.sourceEntryIndex,
                    sourceName: clip.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance:
                    "\(clip.sourceArchive) \(clip.sourceSHA256)"
            )
        } + [DependencyRecord(
            category: "sound",
            source: .init(
                storedIndex: soundClip.sourceEntryIndex,
                sourceName: soundClip.sourceName
            ),
            state: "canonical-pcm-imported",
            provenance:
                "\(soundClip.sourceArchive) \(soundClip.sourceSHA256)"
        )]
        for reached in reachedDependencies {
            if let index = dependencies.firstIndex(where: {
                $0.category == reached.category
                    && $0.source == reached.source
            }) {
                dependencies[index] = reached
            } else {
                dependencies.append(reached)
            }
        }
        return Level(
            schemaVersion: 10,
            missionKey: missionKey,
            levelKey: levelKey,
            source: source,
            metadata: metadata,
            rooms: rooms,
            terrain: terrain,
            objects: objects,
            retiredObjectHandles: retiredObjectHandles,
            paths: paths,
            goals: goals,
            goalFlags: goalFlags,
            triggers: triggers,
            playerStartFlags: playerStartFlags,
            indoorNavigation: indoorNavigation,
            lightmaps: lightmaps,
            surfacePhysics: surfacePhysics,
            presentationMaterials: presentationMaterials,
            presentationCoronaAssets: presentationCoronaAssets,
            models: models,
            shipDefinitions: shipDefinitions,
            defaultPlayerBinding: defaultPlayerBinding,
            objectPresentations: objectPresentations,
            trainingOpeningLesson: trainingOpeningLesson,
            trainingGalleryBarrier: trainingGalleryBarrier,
            trainingRobotGuidebotChain: trainingRobotGuidebotChain,
            trainingCameraMonitorChain: chain,
            voiceClips: voiceClips + addedVoiceClips,
            soundClips: soundClips + [soundClip],
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    private static func defaultSurfacePhysics(for rooms: [LevelRoom]) -> [SurfacePhysicsEntry] {
        let textures = Set(rooms.flatMap { $0.faces.map(\.texture) })
        return textures.sorted(by: sourceResourceIsOrdered).map {
            .init(texture: $0, behavior: .blocking)
        }
    }

    private func validatePlayerShipBinding() throws {
        let playerZero = objects.first {
            $0.type == D3SourceIdentity.playerObjectType && $0.storedID == 0
        }
        if shipDefinitions.isEmpty && defaultPlayerBinding == nil {
            return
        }
        guard let playerZero,
              shipDefinitions.count == 1,
              let binding = defaultPlayerBinding,
              binding.playerID == 0,
              binding.objectHandle == playerZero.handle,
              binding.ship == shipDefinitions[0].source,
              case .room = playerZero.location else {
            throw LevelValidationError.invalidDependency("default player ship binding")
        }
        let ship = shipDefinitions[0]
        guard D3SourceIdentity.isValidSourceResource(
            ship.source,
            category: "ship-definition"
        ),
              models.contains(where: { $0.source == ship.primaryModel }),
              objectPresentations.contains(where: {
                  $0.objectHandle == binding.objectHandle
                      && $0.primaryModel == ship.primaryModel
              }),
              ship.presentationSize.isFinite,
              ship.presentationSize > 0,
              Set(ship.physics.behaviors).count == ship.physics.behaviors.count,
              ship.physics.behaviors == [.turnroll, .wiggle, .usesThrust] else {
            throw LevelValidationError.invalidDependency("default player ship definition")
        }
        let values = [
            ship.physics.mass,
            ship.physics.drag,
            ship.physics.fullThrust,
            ship.physics.rotationalDrag,
            ship.physics.fullRotationalThrust,
            ship.physics.initialForwardVelocity,
            ship.physics.initialAngularVelocity.x,
            ship.physics.initialAngularVelocity.y,
            ship.physics.initialAngularVelocity.z,
            ship.physics.wiggleAmplitude,
            ship.physics.wigglesPerSecond,
            ship.physics.coefficientOfRestitution,
            ship.physics.hitDieDot,
            ship.physics.maximumTurnrollRate,
            ship.physics.turnrollRatio,
        ]
        guard values.allSatisfy(\.isFinite),
              ship.physics.mass > 0,
              ship.physics.drag > 0,
              ship.physics.fullThrust >= 0,
              ship.physics.rotationalDrag >= 0,
              ship.physics.fullRotationalThrust >= 0 else {
            throw LevelValidationError.invalidDependency("default player ship physics")
        }
    }

    private func validatePlayerPresentationClosure(allowIncomplete: Bool) throws {
        if allowIncomplete && presentationMaterials.isEmpty && presentationCoronaAssets.isEmpty {
            return
        }

        let roomBySourceIndex = Dictionary(
            uniqueKeysWithValues: rooms.map { ($0.sourceIndex, $0) }
        )
        let presentationFaces: [SourceVisibleFace]
        if let binding = defaultPlayerBinding,
           let player = objects.first(where: { $0.handle == binding.objectHandle }),
           case .room(let playerRoomSourceIndex) = player.location {
            let presentationRoomIndices = reciprocalPortalComponent(
                rooms: rooms,
                startRoomSourceIndex: playerRoomSourceIndex
            )
            presentationFaces = rooms
                .filter { presentationRoomIndices.contains($0.sourceIndex) }
                .flatMap { room in
                    room.faces.indices.map {
                        SourceVisibleFace(roomSourceIndex: room.sourceIndex, faceIndex: $0)
                    }
                }
        } else if rooms.contains(where: { $0.sourceIndex == 3 }) {
            do {
                presentationFaces = try extractSourceVisibleWorld(
                    self,
                    camera: .trainingRoom3,
                    startRoomSourceIndex: 3,
                    portalBlends: Dictionary(
                        uniqueKeysWithValues: presentationMaterials.map {
                            ($0.texture, $0.blend)
                        }
                    )
                ).faces
            } catch {
                throw LevelValidationError.invalidDependency("reference presentation view")
            }
        } else {
            guard presentationMaterials.isEmpty,
                  presentationCoronaAssets.isEmpty,
                  lightmaps.pages.allSatisfy({ $0.rgba8 == nil }),
                  dependencyManifest.current.allSatisfy({
                      $0.state != "presentation-payload-imported"
                  }) else {
                throw LevelValidationError.invalidDependency("orphan presentation payload")
            }
            return
        }
        let requiredRoomTextures = Set(presentationFaces.map {
            roomBySourceIndex[$0.roomSourceIndex]!.faces[$0.faceIndex].texture
        })
        let requiredModelTextures = referencedModelTextures(in: models)
        let requiredTextures = requiredRoomTextures.union(requiredModelTextures)
        guard Set(presentationMaterials.map(\.texture)) == requiredTextures else {
            throw LevelValidationError.invalidDependency("player-component textures")
        }
        let materialByTexture = Dictionary(
            uniqueKeysWithValues: presentationMaterials.map { ($0.texture, $0) }
        )
        var requiredCoronaAssetIndices: Set<Int> = []
        for reference in presentationFaces {
            let face = roomBySourceIndex[reference.roomSourceIndex]!.faces[reference.faceIndex]
            guard face.allowsLightCorona,
                  let corona = materialByTexture[face.texture]?.lightCorona else { continue }
            requiredCoronaAssetIndices.insert(corona.assetIndex)
        }
        guard requiredCoronaAssetIndices == Set(presentationCoronaAssets.indices) else {
            throw LevelValidationError.invalidDependency("player-component corona assets")
        }

        let requiredLightmapPages = Set(presentationFaces.compactMap { reference -> Int? in
            let face = roomBySourceIndex[reference.roomSourceIndex]!.faces[reference.faceIndex]
            return face.lightmapInfoIndex.map { lightmaps.infos[$0].pageIndex }
        })
        let importedLightmapPages = Set(lightmaps.pages.indices.filter { index in
            lightmaps.pages[index].rgba8 != nil
        })
        guard importedLightmapPages == requiredLightmapPages else {
            throw LevelValidationError.invalidDependency("player-component lightmaps")
        }

        let importedDependencies = Set(dependencyManifest.current.compactMap {
            $0.state == "presentation-payload-imported"
                ? DependencyIdentity(category: $0.category, source: $0.source)
                : nil
        })
        let requiredDependencies = Set(requiredTextures.map {
            DependencyIdentity(category: "texture", source: $0)
        }).union(models.map {
            DependencyIdentity(category: "model", source: $0.source)
        }).union(requiredLightmapPages.map {
            DependencyIdentity(
                category: "lightmap-page",
                source: .init(storedIndex: $0, sourceName: "lightmap-page-\($0)")
            )
        }).union(requiredCoronaAssetIndices.map {
            DependencyIdentity(
                category: "presentation-effect",
                source: presentationCoronaAssets[$0].source
            )
        })
        guard importedDependencies == requiredDependencies else {
            throw LevelValidationError.invalidDependency("player-component presentation state")
        }

        if defaultPlayerBinding != nil {
            do {
                _ = try extractWorldForRendering(self, playerView: defaultPlayerView(in: self))
            } catch {
                throw LevelValidationError.invalidDependency("player initial view")
            }
        }
    }
}

func canonicalFaceNormal(room: LevelRoom, face: LevelFace) -> Vector3? {
    var best = Vector3.zero
    var bestMagnitudeSquared: Float = 0
    for index in face.corners.indices {
        let a = room.vertices[face.corners[index].vertexIndex]
        let b = room.vertices[face.corners[(index + 1) % face.corners.count].vertexIndex]
        let c = room.vertices[face.corners[(index + 2) % face.corners.count].vertexIndex]
        let candidate = cross(
            .init(x: b.x - a.x, y: b.y - a.y, z: b.z - a.z),
            .init(x: c.x - b.x, y: c.y - b.y, z: c.z - b.z)
        )
        let magnitudeSquared = dot(candidate, candidate)
        guard magnitudeSquared.isFinite else { return nil }
        if magnitudeSquared > bestMagnitudeSquared {
            best = candidate
            bestMagnitudeSquared = magnitudeSquared
        }
    }
    let magnitude = sqrt(bestMagnitudeSquared)
    guard magnitude >= 0.035 else { return nil }
    let normal = Vector3(
        x: best.x / magnitude,
        y: best.y / magnitude,
        z: best.z / magnitude
    )
    guard normal.x.isFinite, normal.y.isFinite, normal.z.isFinite else { return nil }
    return normal
}

struct IndoorWallContact: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
    let contactPoint: Vector3
    let normal: Vector3
    let distance: Float
}

enum IndoorMovementTraceOutcome: Equatable, Sendable {
    case noHit
    case wallHit(IndoorWallContact)
}

struct IndoorPortalCrossing: Equatable, Sendable {
    let roomSourceIndex: Int
    let faceIndex: Int
}

struct IndoorMovementTrace: Equatable, Sendable {
    let outcome: IndoorMovementTraceOutcome
    let finalPosition: Vector3
    let containingRoomSourceIndex: Int
    let visitedRoomSourceIndices: [Int]
    let passedPortalFaces: [IndoorPortalCrossing]
}

func traceIndoorMovement(
    in level: Level,
    startRoom: Int,
    start: Vector3,
    end: Vector3,
    radius: Float
) -> IndoorMovementTrace {
    precondition(radius.isFinite && radius >= 0)
    precondition(isFinite(start) && isFinite(end))

    let rooms = Dictionary(uniqueKeysWithValues: level.rooms.map { ($0.sourceIndex, $0) })
    let surfacePhysics = Dictionary(
        uniqueKeysWithValues: level.surfacePhysics.map { ($0.texture, $0.behavior) }
    )
    precondition(rooms[startRoom] != nil)

    let movement = subtract(end, start)
    let movementLength = sqrt(dot(movement, movement))
    var visited: [Int] = []
    var visitedSet: Set<Int> = []
    var passedPortalFaces: [IndoorPortalCrossing] = []
    var nearest: IndoorWallContact?
    var nearestNormalCount = 0

    func visit(_ roomIndex: Int) {
        guard visitedSet.insert(roomIndex).inserted else { return }
        let room = rooms[roomIndex]!
        visited.append(roomIndex)

        var reachedPortals: [Int: Float] = [:]
        for (faceIndex, face) in room.faces.enumerated() {
            guard let hit = sweptSphereFaceHit(
                room: room,
                face: face,
                start: start,
                movement: movement,
                radius: radius
            ) else {
                continue
            }

            let portalIndex = face.portalIndex
            let portal = portalIndex.map { room.portals[$0] }
            if indoorFaceIsPassable(
                portal: portal,
                face: face,
                surfacePhysics: surfacePhysics
            ) {
                if let portalIndex {
                    reachedPortals[portalIndex] = min(
                        reachedPortals[portalIndex] ?? 1,
                        hit.fraction
                    )
                }
                continue
            }

            let candidate = IndoorWallContact(
                roomSourceIndex: roomIndex,
                faceIndex: faceIndex,
                contactPoint: hit.contactPoint,
                normal: hit.normal,
                distance: movementLength * hit.fraction
            )
            if nearest == nil || candidate.distance < nearest!.distance {
                nearest = candidate
                nearestNormalCount = 1
            } else if candidate.distance == nearest!.distance,
                      nearestNormalCount < 2 {
                nearest = IndoorWallContact(
                    roomSourceIndex: nearest!.roomSourceIndex,
                    faceIndex: nearest!.faceIndex,
                    contactPoint: nearest!.contactPoint,
                    normal: normalized(add(nearest!.normal, candidate.normal))!,
                    distance: nearest!.distance
                )
                nearestNormalCount += 1
            }
        }

        for (portalIndex, portal) in room.portals.enumerated() {
            guard let fraction = reachedPortals[portalIndex],
                  movementLength * fraction
                    <= (nearest?.distance ?? movementLength)
            else {
                continue
            }
            if let centerHit = sweptSphereFaceHit(
                room: room,
                face: room.faces[portal.faceIndex],
                start: start,
                movement: movement,
                radius: 0
            ), movementLength * centerHit.fraction
                <= (nearest?.distance ?? movementLength) {
                passedPortalFaces.append(.init(
                    roomSourceIndex: roomIndex,
                    faceIndex: portal.faceIndex
                ))
            }
            visit(portal.connectedRoom)
        }
    }

    visit(startRoom)

    if let nearest {
        let fraction = movementLength > 0 ? nearest.distance / movementLength : 0
        let finalPosition = add(start, scaled(movement, fraction))
        let containingRoom = radius == 0
            ? nearest.roomSourceIndex
            : visited.first {
                indoorRoomContains(finalPosition, room: rooms[$0]!)
            } ?? startRoom
        return IndoorMovementTrace(
            outcome: .wallHit(nearest),
            finalPosition: finalPosition,
            containingRoomSourceIndex: containingRoom,
            visitedRoomSourceIndices: visited,
            passedPortalFaces: passedPortalFaces
        )
    }

    let containingRoom = visited.first {
        indoorRoomContains(end, room: rooms[$0]!)
    } ?? startRoom
    return IndoorMovementTrace(
        outcome: .noHit,
        finalPosition: end,
        containingRoomSourceIndex: containingRoom,
        visitedRoomSourceIndices: visited,
        passedPortalFaces: passedPortalFaces
    )
}

func containingIndoorRoomSourceIndex(
    in level: Level,
    position: Vector3,
    candidates: [Int]? = nil
) -> Int? {
    guard isFinite(position) else { return nil }
    let rooms = Dictionary(uniqueKeysWithValues: level.rooms.map {
        ($0.sourceIndex, $0)
    })
    let sourceIndices = candidates ?? level.rooms.map(\.sourceIndex).sorted()
    return sourceIndices.first {
        rooms[$0].map { indoorRoomContains(position, room: $0) } == true
    }
}

private func indoorFaceIsPassable(
    portal: LevelPortal?,
    face: LevelFace,
    surfacePhysics: [SourceResource: SurfacePhysicsBehavior]
) -> Bool {
    if surfacePhysics[face.texture]! == .passThrough {
        return true
    }
    guard let portal else { return false }
    let rendersFaces: UInt32 = 0x0000_0001
    let renderedFlythrough: UInt32 = 0x0000_0002
    return portal.flags & rendersFaces == 0
        || portal.flags & renderedFlythrough != 0
}

private struct IndoorFaceHit {
    let fraction: Float
    let contactPoint: Vector3
    let normal: Vector3
}

private func sweptSphereFaceHit(
    room: LevelRoom,
    face: LevelFace,
    start: Vector3,
    movement: Vector3,
    radius: Float
) -> IndoorFaceHit? {
    let normal = canonicalFaceNormal(room: room, face: face)!
    let planeVertexIndex = face.corners.map(\.vertexIndex).min()!
    let planePoint = room.vertices[planeVertexIndex]
    let projectedMovement = dot(movement, normal)
    guard projectedMovement < 0 else { return nil }

    let startDistance = dot(subtract(planePoint, start), normal)
    guard startDistance <= 0 else { return nil }
    let shiftedDistance = startDistance + radius
    let planeFraction: Float
    if shiftedDistance > 0 {
        planeFraction = 0
    } else {
        guard shiftedDistance > projectedMovement else { return nil }
        planeFraction = shiftedDistance / projectedMovement
    }

    var nearest: IndoorFaceHit?
    let centerAtPlane = add(start, scaled(movement, planeFraction))
    let planeContact = subtract(centerAtPlane, scaled(normal, radius))
    if pointIsInsideFace(planeContact, room: room, face: face, normal: normal) {
        nearest = .init(
            fraction: planeFraction,
            contactPoint: planeContact,
            normal: normal
        )
    }

    guard radius > 0 else { return nearest }
    for cornerIndex in face.corners.indices {
        let a = room.vertices[face.corners[cornerIndex].vertexIndex]
        let b = room.vertices[
            face.corners[(cornerIndex + 1) % face.corners.count].vertexIndex
        ]
        guard let edgeHit = sweptSphereSegmentHit(
            start: start,
            movement: movement,
            radius: radius,
            a: a,
            b: b
        ) else {
            continue
        }
        if nearest == nil || edgeHit.fraction < nearest!.fraction {
            nearest = edgeHit
        }
    }
    return nearest
}

private func sweptSphereSegmentHit(
    start: Vector3,
    movement: Vector3,
    radius: Float,
    a: Vector3,
    b: Vector3
) -> IndoorFaceHit? {
    let edge = subtract(b, a)
    let edgeLengthSquared = dot(edge, edge)
    precondition(edgeLengthSquared > 0)

    let fromA = subtract(start, a)
    let startAlong = dot(fromA, edge) / edgeLengthSquared
    let movementAlong = dot(movement, edge) / edgeLengthSquared
    let perpendicularStart = subtract(fromA, scaled(edge, startAlong))
    let perpendicularMovement = subtract(movement, scaled(edge, movementAlong))
    let quadraticA = dot(perpendicularMovement, perpendicularMovement)
    let quadraticB = 2 * dot(perpendicularStart, perpendicularMovement)
    let quadraticC = dot(perpendicularStart, perpendicularStart) - radius * radius

    var candidates: [IndoorFaceHit] = []
    if let fraction = firstUnitIntervalRoot(
        a: quadraticA,
        b: quadraticB,
        c: quadraticC
    ) {
        let along = startAlong + movementAlong * fraction
        if (0...1).contains(along) {
            let center = add(start, scaled(movement, fraction))
            let contactPoint = add(a, scaled(edge, along))
            if let normal = normalized(subtract(center, contactPoint)) {
                candidates.append(
                    .init(
                        fraction: fraction,
                        contactPoint: contactPoint,
                        normal: normal
                    )
                )
            }
        }
    }
    if let aHit = sweptSpherePointHit(
        start: start,
        movement: movement,
        radius: radius,
        point: a
    ) {
        candidates.append(aHit)
    }
    if let bHit = sweptSpherePointHit(
        start: start,
        movement: movement,
        radius: radius,
        point: b
    ) {
        candidates.append(bHit)
    }
    return candidates.min { $0.fraction < $1.fraction }
}

private func sweptSpherePointHit(
    start: Vector3,
    movement: Vector3,
    radius: Float,
    point: Vector3
) -> IndoorFaceHit? {
    let relative = subtract(start, point)
    guard let fraction = firstUnitIntervalRoot(
        a: dot(movement, movement),
        b: 2 * dot(relative, movement),
        c: dot(relative, relative) - radius * radius
    ) else {
        return nil
    }
    let center = add(start, scaled(movement, fraction))
    guard let normal = normalized(subtract(center, point)) else { return nil }
    return .init(fraction: fraction, contactPoint: point, normal: normal)
}

private func firstUnitIntervalRoot(a: Float, b: Float, c: Float) -> Float? {
    if c <= 0 {
        return b < 0 ? 0 : nil
    }
    guard a > 0 else { return nil }
    let discriminant = b * b - 4 * a * c
    guard discriminant >= 0 else { return nil }
    let root = (-b - sqrt(discriminant)) / (2 * a)
    return (0...1).contains(root) ? root : nil
}

private func pointIsInsideFace(
    _ point: Vector3,
    room: LevelRoom,
    face: LevelFace,
    normal: Vector3
) -> Bool {
    let tolerance: Float = 0.0001
    for cornerIndex in face.corners.indices {
        let a = room.vertices[face.corners[cornerIndex].vertexIndex]
        let b = room.vertices[
            face.corners[(cornerIndex + 1) % face.corners.count].vertexIndex
        ]
        let edge = subtract(b, a)
        let fromEdge = subtract(point, a)
        if dot(cross(edge, fromEdge), normal) < -tolerance {
            return false
        }
    }
    return true
}

private func indoorRoomContains(_ point: Vector3, room: LevelRoom) -> Bool {
    let directions = [
        Vector3(x: 0.811_107, y: 0.324_443, z: 0.486_664),
        Vector3(x: -0.811_107, y: -0.324_443, z: -0.486_664),
    ]
    for direction in directions {
        var nearest: (fraction: Float, frontFacing: Bool)?
        for face in room.faces {
            let normal = canonicalFaceNormal(room: room, face: face)!
            let planeVertexIndex = face.corners.map(\.vertexIndex).min()!
            let denominator = dot(direction, normal)
            guard abs(denominator) > 0.000_001 else { continue }
            let planePoint = room.vertices[planeVertexIndex]
            let fraction = dot(subtract(planePoint, point), normal) / denominator
            guard fraction >= 0 else { continue }
            let intersection = add(point, scaled(direction, fraction))
            guard pointIsInsideFace(
                intersection,
                room: room,
                face: face,
                normal: normal
            ) else {
                continue
            }
            if nearest == nil || fraction < nearest!.fraction {
                nearest = (fraction, denominator < 0)
            }
        }
        if let nearest {
            return nearest.frontFacing
        }
    }
    return false
}

private func add(_ a: Vector3, _ b: Vector3) -> Vector3 {
    .init(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z)
}

private func scaled(_ vector: Vector3, _ scalar: Float) -> Vector3 {
    .init(x: vector.x * scalar, y: vector.y * scalar, z: vector.z * scalar)
}

private func normalized(_ vector: Vector3) -> Vector3? {
    let magnitude = sqrt(dot(vector, vector))
    guard magnitude > 0 else { return nil }
    return scaled(vector, 1 / magnitude)
}

private func validateIndoorNavigation(
    _ graph: IndoorNavigationGraph?,
    rooms: [Int: LevelRoom]
) throws {
    guard let graph else { return }
    guard let highestRoomSourceIndex = rooms.keys.max(),
          graph.sourceHighestRoomPlusTerrainRegions
            == highestRoomSourceIndex + 8,
          Set(graph.rooms.map(\.sourceIndex)).count == graph.rooms.count
    else {
        throw LevelValidationError.invalidDependency(
            "Indoor navigation graph"
        )
    }
    let navigationByRoom = Dictionary(
        uniqueKeysWithValues: graph.rooms.map { ($0.sourceIndex, $0) }
    )
    for navigationRoom in graph.rooms {
        if navigationRoom.sourceIndex > highestRoomSourceIndex {
            guard navigationRoom.nodes.isEmpty else {
                throw LevelValidationError.invalidDependency(
                    "Indoor navigation graph"
                )
            }
            continue
        }
        guard let room = rooms[navigationRoom.sourceIndex],
              room.flags & 0x0000_0004 == 0,
              navigationRoom.nodes.count <= 127
        else {
            throw LevelValidationError.invalidDependency(
                "Indoor navigation graph"
            )
        }
        for (nodeIndex, node) in navigationRoom.nodes.enumerated() {
            guard isFinite(node.position), node.edges.count <= 127 else {
                throw LevelValidationError.invalidDependency(
                    "Indoor navigation graph"
                )
            }
            for edge in node.edges {
                guard edge.cost >= 1,
                      edge.maximumRadius.isFinite,
                      edge.maximumRadius >= 0,
                      let destinationRoom =
                        navigationByRoom[
                            edge.destinationRoomSourceIndex
                        ],
                      destinationRoom.nodes.indices.contains(
                          edge.destinationNodeIndex
                      ),
                      destinationRoom.nodes[
                          edge.destinationNodeIndex
                      ].edges.contains(where: {
                          $0.destinationRoomSourceIndex
                                == navigationRoom.sourceIndex
                              && $0.destinationNodeIndex == nodeIndex
                      })
                else {
                    throw LevelValidationError.invalidDependency(
                        "Indoor navigation graph"
                    )
                }
            }
        }
        for portal in room.portals where portal.boundaryNodeIndex >= 0 {
            guard navigationRoom.nodes.indices.contains(
                portal.boundaryNodeIndex
            ) else {
                throw LevelValidationError.invalidDependency(
                    "Indoor navigation graph"
                )
            }
        }
    }
}

enum LevelValidationError: Error, Equatable {
    case invalidIdentity
    case duplicateRoom
    case invalidFace(room: Int, face: Int)
    case degenerateFace(room: Int, face: Int)
    case nonplanarFace(room: Int, face: Int)
    case concaveFace(room: Int, face: Int)
    case invalidFacePortal(room: Int, face: Int)
    case invalidMirrorFace(room: Int)
    case invalidSpecialFace(room: Int, face: Int)
    case invalidPortal(room: Int, portal: Int)
    case invalidCombinedPortal(room: Int, portal: Int)
    case nonreciprocalPortal(room: Int, portal: Int)
    case mismatchedPortalGeometry(room: Int, portal: Int)
    case invalidLightmapReference(Int)
    case invalidSurfacePhysics
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
    case invalidObjectPosition(UInt32)
    case invalidObjectOrientation(UInt32)
    case invalidObjectPresentation(UInt32)
    case invalidModel(String)
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

private func reciprocalPortalGeometryMatches(
    room: LevelRoom,
    portal: LevelPortal,
    connectedRoom: LevelRoom,
    connectedPortal: LevelPortal
) -> Bool {
    let face = room.faces[portal.faceIndex]
    let connectedFace = connectedRoom.faces[connectedPortal.faceIndex]
    guard face.corners.count == connectedFace.corners.count else { return false }
    let points = face.corners.map { room.vertices[$0.vertexIndex] }
    let connectedPoints = connectedFace.corners.map {
        connectedRoom.vertices[$0.vertexIndex]
    }
    for start in connectedPoints.indices where pointsMatch(points[0], connectedPoints[start]) {
        if points.indices.dropFirst().allSatisfy({ offset in
            pointsMatch(
                points[offset],
                connectedPoints[(start - offset + connectedPoints.count) % connectedPoints.count]
            )
        }) {
            return true
        }
    }
    return false
}

private func pointsMatch(_ lhs: Vector3, _ rhs: Vector3) -> Bool {
    let x = lhs.x - rhs.x
    let y = lhs.y - rhs.y
    let z = lhs.z - rhs.z
    return x * x + y * y + z * z < 0.01
}

private func faceIsPlanar(
    room: LevelRoom,
    face: LevelFace,
    normal: Vector3
) -> Bool {
    guard face.corners.count > 3 else { return true }
    let distances = face.corners.map {
        dot(room.vertices[$0.vertexIndex], normal)
    }
    let average = distances.reduce(0, +) / Float(distances.count)
    return distances.allSatisfy { abs($0 - average) <= 0.1 }
}

private func faceIsConcave(
    room: LevelRoom,
    face: LevelFace,
    normal: Vector3
) -> Bool {
    let points = face.corners.map { room.vertices[$0.vertexIndex] }
    let (i, j) = faceProjectionAxes(normal)
    var previousEdge = subtract(points[0], points[points.count - 1])
    for index in points.indices {
        let current = points[index]
        let next = points[(index + 1) % points.count]
        let nextEdge = subtract(next, current)
        let previousI = component(previousEdge, at: i)
        let previousJ = component(previousEdge, at: j)
        let nextI = component(nextEdge, at: i)
        let nextJ = component(nextEdge, at: j)
        let denominator = sqrt(previousI * previousI + previousJ * previousJ)
            * sqrt(nextI * nextI + nextJ * nextJ)
        guard denominator > 0 else { return true }
        let turn = (-previousJ * nextI + previousI * nextJ) / denominator
        if turn > 0.05 { return true }
        previousEdge = nextEdge
    }
    return false
}

private func faceProjectionAxes(_ normal: Vector3) -> (Int, Int) {
    if abs(normal.x) > abs(normal.y) {
        if abs(normal.x) > abs(normal.z) {
            return normal.x > 0 ? (2, 1) : (1, 2)
        }
        return normal.z > 0 ? (1, 0) : (0, 1)
    }
    if abs(normal.y) > abs(normal.z) {
        return normal.y > 0 ? (0, 2) : (2, 0)
    }
    return normal.z > 0 ? (1, 0) : (0, 1)
}

private func component(_ vector: Vector3, at index: Int) -> Float {
    switch index {
    case 0: vector.x
    case 1: vector.y
    default: vector.z
    }
}

private func subtract(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

private func validateSourceResource(_ source: SourceResource, category: String) throws {
    guard D3SourceIdentity.isValidSourceResource(source, category: category) else {
        throw LevelValidationError.invalidSourceResource(
            category: category,
            storedIndex: source.storedIndex
        )
    }
}

private func validateSurfacePhysics(
    _ entries: [SurfacePhysicsEntry],
    rooms: [LevelRoom],
    allowIncomplete: Bool
) throws {
    if allowIncomplete && entries.isEmpty {
        return
    }
    let residentTextures = Set(rooms.flatMap { $0.faces.map(\.texture) })
    let entryTextures = entries.map(\.texture)
    guard entries.count == residentTextures.count,
          Set(entryTextures).count == entries.count,
          Set(entryTextures) == residentTextures,
          entries.map(\.texture) == entryTextures.sorted(by: sourceResourceIsOrdered) else {
        throw LevelValidationError.invalidSurfacePhysics
    }
    for entry in entries {
        try validateSourceResource(entry.texture, category: "texture")
    }
}

private func sourceResourceIsOrdered(_ lhs: SourceResource, _ rhs: SourceResource) -> Bool {
    if lhs.storedIndex != rhs.storedIndex {
        return lhs.storedIndex < rhs.storedIndex
    }
    if lhs.sourceName != rhs.sourceName {
        return lhs.sourceName < rhs.sourceName
    }
    return (lhs.referenceRuntimeIndex ?? -1) < (rhs.referenceRuntimeIndex ?? -1)
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
        for model in models {
            require("model", model.source)
        }
        for texture in referencedModelTextures(in: models) {
            require("texture", texture)
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

private func validateModels(
    _ models: [CanonicalModel],
    objectPresentations: [ObjectPresentationReference],
    materials: [PresentationMaterial],
    objects: [PlacedObject],
    source: LevelSource,
    dynamicallyPresentedModelNames: [String]
) throws {
    let acceptedSourcePaths = Set(source.profileFiles.map(\.relativePath))
    guard models.count <= 256,
          Set(models.map(\.source)).count == models.count,
          Set(objectPresentations.map(\.objectHandle)).count == objectPresentations.count else {
        throw LevelValidationError.invalidCount("models")
    }
    let materialSources = Set(materials.map(\.texture))
    var modelBySource: [SourceResource: CanonicalModel] = [:]
    for model in models {
        guard D3SourceIdentity.isValidSourceResource(model.source, category: "model"),
              model.collisionRadius.isFinite,
              model.collisionRadius > 0,
              isSafeRelativePath(model.sourceArchive),
              acceptedSourcePaths.contains(model.sourceArchive),
              isSHA256(model.sourceSHA256),
              !model.submodels.isEmpty,
              model.submodels.count <= 1_000 else {
            throw LevelValidationError.invalidModel("\(model.source.sourceName): identity")
        }
        let faceTextures = Set(model.submodels.flatMap { submodel in
            submodel.faces.compactMap { face -> SourceResource? in
                if case .texture(let texture) = face.material { return texture }
                return nil
            }
        })
        for texture in faceTextures {
            guard D3SourceIdentity.isValidSourceResource(texture, category: "texture"),
                  materialSources.contains(texture) else {
                throw LevelValidationError.invalidDependency(
                    "missing texture:\(texture.sourceName)"
                )
            }
        }
        let indices = Set(model.submodels.map(\.sourceIndex))
        guard indices == Set(model.submodels.indices) else {
            throw LevelValidationError.invalidModel("\(model.source.sourceName): submodel indices")
        }
        var transformedBounds: ModelBounds?
        var accumulatedOffsets = [Vector3?](repeating: nil, count: model.submodels.count)
        func resolvedOffset(_ index: Int, visiting: inout Set<Int>) throws -> Vector3 {
            if let resolved = accumulatedOffsets[index] { return resolved }
            guard visiting.insert(index).inserted else {
                throw LevelValidationError.invalidModel("\(model.source.sourceName): cyclic hierarchy")
            }
            let submodel = model.submodels[index]
            let parentOffset: Vector3
            if let parent = submodel.parentIndex {
                guard model.submodels.indices.contains(parent) else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): invalid parent")
                }
                parentOffset = try resolvedOffset(parent, visiting: &visiting)
            } else {
                parentOffset = .zero
            }
            visiting.remove(index)
            let resolved = adding(parentOffset, submodel.offset)
            accumulatedOffsets[index] = resolved
            return resolved
        }
        for submodel in model.submodels.sorted(by: { $0.sourceIndex < $1.sourceIndex }) {
            var visiting: Set<Int> = []
            let accumulatedOffset = try resolvedOffset(submodel.sourceIndex, visiting: &visiting)
            guard submodel.vertices.count <= 100_000,
                  submodel.faces.count <= 100_000 else {
                throw LevelValidationError.invalidModel("\(model.source.sourceName): geometry count")
            }
            for vertex in submodel.vertices {
                guard isFinite(vertex.position) else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): vertex position")
                }
                guard vertex.alpha.isFinite, (0...1).contains(vertex.alpha) else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): vertex alpha")
                }
                let transformed = adding(
                    accumulatedOffset,
                    vertex.position
                )
                transformedBounds = expanding(transformedBounds, toInclude: transformed)
            }
            for face in submodel.faces {
                guard isFinite(face.normal),
                      face.corners.count >= 3,
                      face.corners.count <= 100_000 else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): face")
                }
                for corner in face.corners {
                    guard submodel.vertices.indices.contains(corner.vertexIndex),
                          corner.u.isFinite, corner.v.isFinite else {
                        throw LevelValidationError.invalidModel("\(model.source.sourceName): face corner")
                    }
                }
            }
            switch submodel.presentation {
            case .glow(let color, let size):
                guard isFinite(color), size.isFinite, size > 0 else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): presentation")
                }
            case .rotate(let rate, let axis):
                let magnitudeSquared = dot(axis, axis)
                guard rate.isFinite,
                      rate > 0,
                      magnitudeSquared.isFinite,
                      abs(magnitudeSquared - 1) <= 0.000_1 else {
                    throw LevelValidationError.invalidModel("\(model.source.sourceName): presentation")
                }
            case .standard, .custom, .facing:
                break
            }
        }
        guard let transformedBounds,
              approximatelyEqual(model.bounds.minimum, transformedBounds.minimum),
              approximatelyEqual(model.bounds.maximum, transformedBounds.maximum) else {
            throw LevelValidationError.invalidModel("\(model.source.sourceName): bounds")
        }
        modelBySource[model.source] = model
    }

    let objectHandles = Set(objects.map(\.handle))
    var referencedModels = Set<SourceResource>()
    for presentation in objectPresentations {
        guard objectHandles.contains(presentation.objectHandle) else {
            throw LevelValidationError.invalidObjectPresentation(presentation.objectHandle)
        }
        let choices = [
            presentation.primaryModel,
            presentation.mediumModel,
            presentation.lowModel,
            presentation.dyingModel,
        ].compactMap { $0 }
        guard choices.allSatisfy({ modelBySource[$0] != nil }) else {
            throw LevelValidationError.invalidObjectPresentation(presentation.objectHandle)
        }
        referencedModels.formUnion(choices)
        let hasMedium = presentation.mediumModel != nil
        let hasLow = presentation.lowModel != nil
        guard hasMedium == (presentation.mediumDistance != nil),
              hasLow == (presentation.lowDistance != nil) else {
            throw LevelValidationError.invalidObjectPresentation(presentation.objectHandle)
        }
        if let medium = presentation.mediumDistance {
            guard medium.isFinite, medium > 0 else {
                throw LevelValidationError.invalidObjectPresentation(presentation.objectHandle)
            }
        }
        if let low = presentation.lowDistance {
            guard low.isFinite,
                  low > (presentation.mediumDistance ?? 0) else {
                throw LevelValidationError.invalidObjectPresentation(presentation.objectHandle)
            }
        }
    }
    for name in dynamicallyPresentedModelNames {
        if let source = models.first(where: {
            $0.source.sourceName.caseInsensitiveCompare(name)
                == .orderedSame
        })?.source {
            referencedModels.insert(source)
        }
    }
    guard referencedModels == Set(models.map(\.source)) else {
        throw LevelValidationError.invalidDependency("orphan model")
    }
}

private func referencedModelTextures(in models: [CanonicalModel]) -> Set<SourceResource> {
    Set(models.flatMap { model in
        model.submodels.flatMap { submodel in
            submodel.faces.compactMap { face -> SourceResource? in
                if case .texture(let texture) = face.material { return texture }
                return nil
            }
        }
    })
}

private func adding(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
    .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

private func expanding(_ bounds: ModelBounds?, toInclude point: Vector3) -> ModelBounds {
    guard let bounds else { return .init(minimum: point, maximum: point) }
    return .init(
        minimum: .init(
            x: min(bounds.minimum.x, point.x),
            y: min(bounds.minimum.y, point.y),
            z: min(bounds.minimum.z, point.z)
        ),
        maximum: .init(
            x: max(bounds.maximum.x, point.x),
            y: max(bounds.maximum.y, point.y),
            z: max(bounds.maximum.z, point.z)
        )
    )
}

private func isFinite(_ value: Vector3) -> Bool {
    value.x.isFinite && value.y.isFinite && value.z.isFinite
}

private func approximatelyEqual(_ lhs: Vector3, _ rhs: Vector3) -> Bool {
    abs(lhs.x - rhs.x) <= 0.0001
        && abs(lhs.y - rhs.y) <= 0.0001
        && abs(lhs.z - rhs.z) <= 0.0001
}

private func validateLightmaps(_ lightmaps: LightmapCatalog) throws {
    guard lightmaps.pages.count <= 65_534 else {
        throw LevelValidationError.invalidCount("lightmap pages")
    }
    guard lightmaps.infos.count < 65_534 else {
        throw LevelValidationError.invalidCount("lightmap infos")
    }
    for (pageIndex, page) in lightmaps.pages.enumerated() {
        guard (1...128).contains(page.width),
              (1...128).contains(page.height),
              page.rgba8 == nil || page.rgba8?.count == page.width * page.height * 4 else {
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

private func validatePresentation(
    materials: [PresentationMaterial],
    coronaAssets: [PresentationCoronaAsset],
    source: LevelSource
) throws {
    let acceptedSourcePaths = Set(source.profileFiles.map(\.relativePath))
    guard Set(materials.map(\.texture)).count == materials.count,
          Set(coronaAssets.map(\.source)).count == coronaAssets.count else {
        throw LevelValidationError.invalidCount("presentation materials")
    }
    for (index, asset) in coronaAssets.enumerated() {
        guard asset.source.storedIndex == index,
              D3SourceIdentity.isValidSourceResource(
                asset.source,
                category: "presentation-effect"
              ),
              asset.source.sourceName == asset.bitmapSourceName,
              !asset.bitmapSourceName.isEmpty,
              asset.bitmapSourceName.utf8.allSatisfy({ $0 < 0x80 }),
              (1...256).contains(asset.image.width),
              (1...256).contains(asset.image.height),
              asset.image.rgba8.count == asset.image.width * asset.image.height * 4,
              isSafeRelativePath(asset.sourceArchive),
              acceptedSourcePaths.contains(asset.sourceArchive),
              isSHA256(asset.sourceSHA256) else {
            throw LevelValidationError.invalidCount("presentation corona asset")
        }
    }
    for material in materials {
        guard D3SourceIdentity.isValidSourceResource(material.texture, category: "texture"),
              !material.bitmapSourceName.isEmpty,
              material.bitmapSourceName.utf8.allSatisfy({ $0 < 0x80 }),
              (1...256).contains(material.image.width),
              (1...256).contains(material.image.height),
              material.image.rgba8.count == material.image.width * material.image.height * 4,
              isSafeRelativePath(material.sourceArchive),
              acceptedSourcePaths.contains(material.sourceArchive),
              isSHA256(material.sourceSHA256) else {
            throw LevelValidationError.invalidCount("presentation material")
        }
        if case .additiveSourceAlpha = material.blend {
            guard material.lightmapBlend == .none else {
                throw LevelValidationError.invalidCount("presentation material")
            }
        }
        if let water = material.waterProcedural {
            guard material.image.width == 128,
                  material.image.height == 128,
                  water.lightingShift < 16,
                  water.dampingShift < 16,
                  water.elements.count <= 64,
                  water.evaluationIntervalSeconds.isFinite,
                  water.evaluationIntervalSeconds >= 0 else {
                throw LevelValidationError.invalidCount("water procedural")
            }
        }
        if let corona = material.lightCorona {
            guard coronaAssets.indices.contains(corona.assetIndex),
                  corona.tint.x.isFinite,
                  corona.tint.y.isFinite,
                  corona.tint.z.isFinite,
                  corona.tint.x >= 0,
                  corona.tint.y >= 0,
                  corona.tint.z >= 0,
                  corona.blend == .additiveSourceAlpha(opacity: 102) else {
                throw LevelValidationError.invalidCount("presentation light corona")
            }
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

func isCanonicalRigidTransform(
    position: Vector3,
    orientation: Matrix3
) -> Bool {
    isFinite(position) && isOrthonormal(orientation)
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
