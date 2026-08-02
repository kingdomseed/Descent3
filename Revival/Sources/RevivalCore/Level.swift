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

struct TrainingReturnLeftLesson: Codable, Equatable, Sendable {
    let startGoalObjectHandle: UInt32
    let collisionRadius: Float
    let instruction: String
    let voiceSourceName: String
}

struct TrainingReturnRightLesson: Codable, Equatable, Sendable {
    let leftGoalObjectHandle: UInt32
    let collisionRadius: Float
    let successMessage: String
    let instruction: String
    let voiceSourceName: String
}

struct TrainingReturnUpLesson: Codable, Equatable, Sendable {
    let startGoalObjectHandle: UInt32
    let collisionRadius: Float
    let successMessage: String
    let instruction: String
    let voiceSourceName: String
}

struct TrainingReturnDownLesson: Codable, Equatable, Sendable {
    let upGoalObjectHandle: UInt32
    let collisionRadius: Float
    let successMessage: String
    let instruction: String
    let voiceSourceName: String
}

struct TrainingRepeatForwardLesson: Codable, Equatable, Sendable {
    let startGoalObjectHandle: UInt32
    let collisionRadius: Float
    let successMessage: String
    let repeatMessage: String
    let forwardInstruction: String
    let voiceSourceName: String
}

struct TrainingRepeatForwardGoalLesson: Codable, Equatable, Sendable {
    let forwardGoalObjectHandle: UInt32
    let collisionRadius: Float
    let reverseInstruction: String
    let soundLogicalName: String
}

struct TrainingRepeatReturnLeftLesson: Codable, Equatable, Sendable {
    let startGoalObjectHandle: UInt32
    let collisionRadius: Float
    let instruction: String
    let voiceSourceName: String
}

struct TrainingRepeatReturnRightLesson: Codable, Equatable, Sendable {
    let leftGoalObjectHandle: UInt32
    let collisionRadius: Float
    let instruction: String
    let soundLogicalName: String
}

struct TrainingRepeatReturnUpLesson: Codable, Equatable, Sendable {
    let startGoalObjectHandle: UInt32
    let collisionRadius: Float
    let instruction: String
    let voiceSourceName: String
}

struct TrainingRepeatReturnDownLesson: Codable, Equatable, Sendable {
    let upGoalObjectHandle: UInt32
    let collisionRadius: Float
    let instruction: String
    let soundLogicalName: String
}

struct TrainingContinueToCourseLesson: Codable, Equatable, Sendable {
    let startGoalObjectHandle: UInt32
    let collisionRadius: Float
    let portalRoomSourceIndex: Int
    let orderedPortalIndices: [Int]
    let instruction: String
    let voiceSourceName: String
}

struct TrainingStartCourseLesson: Codable, Equatable, Sendable {
    let startCourseObjectHandle: UInt32
    let collisionRadius: Float
    let portalRoomSourceIndex: Int
    let portalIndex: Int
    let instruction: String
    let voiceSourceName: String
    let enabledControlMask: UInt32
}

struct TrainingFinishCourseLesson: Codable, Equatable, Sendable {
    let finishCourseObjectHandle: UInt32
    let collisionRadius: Float
    let portalRoomSourceIndex: Int
    let orderedPortalIndices: [Int]
    let successMessage: String
    let instruction: String
    let voiceSourceName: String
    let enabledControlMask: UInt32
}

struct TrainingDodgeTurretDefinition: Codable, Equatable, Sendable {
    struct Joint: Codable, Equatable, Sendable {
        let submodelIndex: Int
        let parentSubmodelIndex: Int
        let rotationAxis: Vector3
        let fieldOfView: Float
        let rotationsPerSecond: Float
        let thinkInterval: Float
    }

    let model: SourceResource
    let collisionRadius: Float
    let fieldOfViewDot: Float
    let maximumTargetDistance: Float
    let fireAlignmentDot: Float
    let fixedLeadAccuracy: Float
    let fireWait: Float
    let gunpoints: [Vector3]
    let aimingGunpoint: Vector3
    let gunpointForward: Vector3
    let gunpointParentSubmodelIndex: Int
    let joints: [Joint]
    let projectileSourceName: String
    let projectileModel: SourceResource
    let fireSoundSourceName: String
    let impactSoundSourceName: String
    let projectileDamage: Float
    let projectileRadius: Float
    let projectileSpeed: Float
    let projectileLifetime: Float
}

struct TrainingDodgeExitLesson: Codable, Equatable, Sendable {
    let objectHandle: UInt32
    let collisionRadius: Float
    let markerLightObjectHandle: UInt32
    let markerLightDistance: Float
    let portalRoomSourceIndex: Int
    let orderedPortalIndices: [Int]
    let disabledControlMask: UInt32
    let instruction: String
    let voiceSourceName: String
}

struct TrainingFollowBotDefinition: Codable, Equatable, Sendable {
    let model: SourceResource
    let collisionRadius: Float
    let maximumVelocity: Float
    let maximumDeltaVelocity: Float
    let maximumTurnRate: Float
    let maximumDeltaTurnRate: Float
    let circleDistance: Float
}

struct TrainingFollowBotDestructionHandoff:
    Codable, Equatable, Sendable
{
    let followBotObjectHandle: UInt32
    let destroyBot2ObjectHandle: UInt32
    let destroyBot1ObjectHandle: UInt32
    let combat: TrainingRobotCombatDefinition
    let projectileModel: SourceResource
    let destructionDelay: Float
    let levelTimerID: Int
    let movingTeamFlags: UInt32
    let movingPathIndex: Int
    let movingPathGoalFlags: UInt32
    let goalID: Int
    let goalPriority: Int
    let successMessage: String
    let movingInstruction: String
    let voiceSourceName: String
}

struct TrainingManeuverFollowLesson: Codable, Equatable, Sendable {
    let maneuverObjectHandle: UInt32
    let maneuverCollisionRadius: Float
    let flashLightObjectHandle: UInt32
    let portalRoomSourceIndex: Int
    let orderedPortalIndices: [Int]
    let headingControlMask: UInt32
    let pitchControlMask: UInt32
    let bankControlMask: UInt32
    let rotationalControlMask: UInt32
    let weaponControlMask: UInt32
    let headingDuration: Float
    let pitchDuration: Float
    let bankDuration: Float
    let followDuration: Float
    let followBotObjectHandle: UInt32
    let friendlyTeamFlags: UInt32
    let followPathIndex: Int
    let followPathGoalFlags: UInt32
    let destroyPathIndex: Int
    let destroyPathGoalFlags: UInt32
    let goalSlot: Int
    let goalPriority: Int
    let maneuverIntroduction: String
    let headingInstruction: String
    let successMessage: String
    let pitchInstruction: String
    let bankInstruction: String
    let followIntroduction: String
    let followInstruction: String
    let weaponsEnabledInstruction: String
    let destroyInstruction: String
    let headingVoiceSourceName: String
    let pitchVoiceSourceName: String
    let bankVoiceSourceName: String
    let followVoiceSourceName: String
    let weaponVoiceSourceName: String
    let followBot: TrainingFollowBotDefinition
    var destructionHandoff: TrainingFollowBotDestructionHandoff? = nil
}

struct TrainingDodgeAttempt: Codable, Equatable, Sendable {
    let startDodgeObjectHandle: UInt32
    let startDodgeCollisionRadius: Float
    let doneDodgeingGoalObjectHandle: UInt32
    let doneDodgeingGoalCollisionRadius: Float
    let dodgeTurretObjectHandle: UInt32
    let flashLightObjectHandle: UInt32
    let triggerDelay: Float
    let successDelay: Float
    let almostDoneDelay: Float
    let portalRoomTwoSourceIndex: Int
    let portalRoomThreeSourceIndex: Int
    let orderedPortalIndices: [Int]
    let disabledControlMask: UInt32
    let enabledDodgeControlMask: UInt32
    let successControlMask: UInt32
    let introduction: String
    let instruction: String
    let hitInstruction: String
    let almostDoneInstruction: String
    let successMessage: String
    let leaveInstruction: String
    let introductionVoiceSourceName: String
    let almostDoneVoiceSourceName: String
    let successVoiceSourceName: String
    let restoredPlayerShields: Float
    let successMarkerLightDistance: Float
    let markerLightPresentation: TrainingMarkerLightPresentation
    let turret: TrainingDodgeTurretDefinition
    var dodgeExit: TrainingDodgeExitLesson? = nil
    var maneuverFollow: TrainingManeuverFollowLesson? = nil
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
    var returnLeft: TrainingReturnLeftLesson? = nil
    var returnRight: TrainingReturnRightLesson? = nil
    var returnUp: TrainingReturnUpLesson? = nil
    var returnDown: TrainingReturnDownLesson? = nil
    var repeatForward: TrainingRepeatForwardLesson? = nil
    var repeatForwardGoal: TrainingRepeatForwardGoalLesson? = nil
    var repeatReturnLeft: TrainingRepeatReturnLeftLesson? = nil
    var repeatReturnRight: TrainingRepeatReturnRightLesson? = nil
    var repeatReturnUp: TrainingRepeatReturnUpLesson? = nil
    var repeatReturnDown: TrainingRepeatReturnDownLesson? = nil
    var continueToCourse: TrainingContinueToCourseLesson? = nil
    var startCourse: TrainingStartCourseLesson? = nil
    var finishCourse: TrainingFinishCourseLesson? = nil
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
    var releaseSoundSourceName: String? = nil
    var ambientEngineSoundSourceName: String? = nil
    var yellowFlare: TrainingGuidebotYellowFlareDefinition? = nil
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
    let returnToShip: TrainingGuidebotReturnChain?

    init(
        pickupObjectHandle: UInt32,
        securityCameraObjectHandle: UInt32,
        pickupCollisionRadius: Float,
        pickupMessage: String,
        pickupVoiceSourceName: String,
        pickupSoundSourceName: String,
        useMessage: String,
        useVoiceSourceName: String,
        popupDuration: Float,
        popupZoom: Float,
        cameraGunpointIndex: Int,
        cameraLocalPosition: Vector3,
        cameraLocalForward: Vector3,
        completionTimerDuration: Float,
        returnToShip: TrainingGuidebotReturnChain? = nil
    ) {
        self.pickupObjectHandle = pickupObjectHandle
        self.securityCameraObjectHandle = securityCameraObjectHandle
        self.pickupCollisionRadius = pickupCollisionRadius
        self.pickupMessage = pickupMessage
        self.pickupVoiceSourceName = pickupVoiceSourceName
        self.pickupSoundSourceName = pickupSoundSourceName
        self.useMessage = useMessage
        self.useVoiceSourceName = useVoiceSourceName
        self.popupDuration = popupDuration
        self.popupZoom = popupZoom
        self.cameraGunpointIndex = cameraGunpointIndex
        self.cameraLocalPosition = cameraLocalPosition
        self.cameraLocalForward = cameraLocalForward
        self.completionTimerDuration = completionTimerDuration
        self.returnToShip = returnToShip
    }
}

struct TrainingGuidebotReturnChain: Codable, Equatable, Sendable {
    let markerLightObjectHandle: UInt32
    let markerLightPresentation: TrainingMarkerLightPresentation?
    let barrierRoomSourceIndex: Int
    let orderedPortalIndices: [Int]
    let openMarkerLightDistance: Float
    let returnMessage: String
    let returnSoundSourceName: String
    let greetingSoundSourceName: String?
    let arrivalMessage: String
    let successMessage: String
    let successVoiceSourceName: String
    let killbotEntry: TrainingKillbotEntryChain?

    init(
        markerLightObjectHandle: UInt32,
        markerLightPresentation: TrainingMarkerLightPresentation? = nil,
        barrierRoomSourceIndex: Int,
        orderedPortalIndices: [Int],
        openMarkerLightDistance: Float,
        returnMessage: String,
        returnSoundSourceName: String,
        greetingSoundSourceName: String? = nil,
        arrivalMessage: String,
        successMessage: String,
        successVoiceSourceName: String,
        killbotEntry: TrainingKillbotEntryChain? = nil
    ) {
        self.markerLightObjectHandle = markerLightObjectHandle
        self.markerLightPresentation = markerLightPresentation
        self.barrierRoomSourceIndex = barrierRoomSourceIndex
        self.orderedPortalIndices = orderedPortalIndices
        self.openMarkerLightDistance = openMarkerLightDistance
        self.returnMessage = returnMessage
        self.returnSoundSourceName = returnSoundSourceName
        self.greetingSoundSourceName = greetingSoundSourceName
        self.arrivalMessage = arrivalMessage
        self.successMessage = successMessage
        self.successVoiceSourceName = successVoiceSourceName
        self.killbotEntry = killbotEntry
    }
}

struct TrainingKillbotEntryChain: Codable, Equatable, Sendable {
    let triggerName: String
    let triggerRoomSourceIndex: Int
    let triggerFaceIndex: Int
    let orderedPortalIndices: [Int]
    let closedMarkerLightDistance: Float
    let entryMessage: String
    let entryVoiceSourceName: String
    let followupDelay: Float
    let followupMessage: String
    let followupVoiceSourceName: String
}

struct TrainingRobotDeathChain: Codable, Equatable, Sendable {
    let robotObjectHandle: UInt32
    let robotRoomSourceIndex: Int
    let robotFlags: UInt32
    let combat: TrainingRobotCombatDefinition
}

typealias TrainingRASBot1DeathChain = TrainingRobotDeathChain
typealias TrainingRASBot2DeathChain = TrainingRobotDeathChain
typealias TrainingRASBot3DeathChain = TrainingRobotDeathChain
typealias TrainingRASBot4DeathChain = TrainingRobotDeathChain
typealias TrainingLastBot1DeathChain = TrainingRobotDeathChain
typealias TrainingLastBot2DeathChain = TrainingRobotDeathChain
typealias TrainingLastBot3DeathChain = TrainingRobotDeathChain
typealias TrainingLastBot4DeathChain = TrainingRobotDeathChain
typealias TrainingLastBot5DeathChain = TrainingRobotDeathChain

struct TrainingInvulnerabilityPickupChain:
    Codable, Equatable, Sendable
{
    let pickupObjectHandle: UInt32
    let pickupRoomSourceIndex: Int
    let pickupObjectFlags: UInt32
    let pickupCollisionRadius: Float
    let duration: Float
    let activatedMessage: String
    let expiredMessage: String
    let pickupSoundSourceName: String
    let activatedSoundSourceName: String
    let expiredSoundSourceName: String
}

struct TrainingCloakPickupChain: Codable, Equatable, Sendable {
    let pickupObjectHandle: UInt32
    let pickupRoomSourceIndex: Int
    let pickupObjectFlags: UInt32
    let pickupCollisionRadius: Float
    let fadeDuration: Float
    let cloakDuration: Float
    let activatedMessage: String
    let expiredMessage: String
    let pickupSoundSourceName: String
    let activatedSoundSourceName: String
    let expiredSoundSourceName: String
}

struct TrainingLastRoomChain: Codable, Equatable, Sendable {
    let barrierRoomSourceIndex: Int
    let orderedPortalIndices: [Int]
    let markerLightObjectHandle: UInt32
    let markerLightPresentation: TrainingMarkerLightPresentation
    let openMarkerLightDistance: Float
    let timerDuration: Float
    let completionMessages: [String]
    let completionVoiceSourceName: String
}

struct TrainingFinalBotsCompletionChain:
    Codable, Equatable, Sendable
{
    let barrierRoomSourceIndex: Int
    let orderedPortalIndices: [Int]
    let markerLightObjectHandle: UInt32
    let markerLightPresentation: TrainingMarkerLightPresentation
    let openMarkerLightDistance: Float
    let timerDuration: Float
    let completionMessage: String
    let completionVoiceSourceName: String
}

struct TrainingFinalGoalChain: Codable, Equatable, Sendable {
    let goalObjectHandle: UInt32
    let goalRoomSourceIndex: Int
    let goalObjectFlags: UInt32
    let goalCollisionRadius: Float
}

struct TrainingFinalRoomEntryChain: Codable, Equatable, Sendable {
    let triggerName: String
    let triggerRoomSourceIndex: Int
    let triggerFaceIndex: Int
    let successMessage: String
    let instructionMessage: String
    let voiceSourceName: String
}

struct TrainingMarkerLightPresentation:
    Codable, Equatable, Sendable
{
    let primaryColor: Vector3
    let secondaryColor: Vector3
    let timeInterval: Float
    let flickerDistance: Float
    let directionalDot: Float
    let flags: UInt32
    let timebits: UInt32
    let angle: UInt8
    let lightingRenderType: UInt8
}

func validTrainingGuidebotReturnBarrier(
    _ chain: TrainingGuidebotReturnChain,
    in level: Level
) -> Bool {
    let stockSurface = SourceResource(
        storedIndex: 908,
        sourceName: "Alien Force Field_1"
    )
    guard chain.orderedPortalIndices == [0, 1],
          let room = level.rooms.first(where: {
              $0.sourceIndex == chain.barrierRoomSourceIndex
          }),
          let markerLight = level.objects.first(where: {
              $0.handle == chain.markerLightObjectHandle
          }),
          markerLight.type == 11,
          markerLight.instanceName == "FlashLight-3",
          chain.orderedPortalIndices.allSatisfy(
            room.portals.indices.contains
          ) else {
        return false
    }
    let rendersFaces =
        room.portals[chain.orderedPortalIndices[0]].flags & 1
    let portalsAreAtomic =
        chain.orderedPortalIndices.allSatisfy { portalIndex in
            let portal = room.portals[portalIndex]
            guard room.faces.indices.contains(portal.faceIndex),
                  room.faces[portal.faceIndex].portalIndex
                    == portalIndex,
                  room.faces[portal.faceIndex].texture
                    == stockSurface,
                  let physics = level.surfacePhysics.first(where: {
                      $0.texture
                        == room.faces[portal.faceIndex].texture
                  }),
                  physics.behavior == .forceField,
                  level.presentationMaterials.contains(where: {
                      $0.texture
                        == room.faces[portal.faceIndex].texture
                        && $0.waterProcedural != nil
                  }),
                  portal.flags & 1 == rendersFaces,
                  let reciprocalRoom = level.rooms.first(where: {
                      $0.sourceIndex == portal.connectedRoom
                  }),
                  reciprocalRoom.portals.indices.contains(
                    portal.connectedPortal
                  ) else {
                return false
            }
            let reciprocal =
                reciprocalRoom.portals[portal.connectedPortal]
            guard reciprocal.connectedRoom
                    == chain.barrierRoomSourceIndex,
                  reciprocal.connectedPortal == portalIndex,
                  reciprocalRoom.faces.indices.contains(
                    reciprocal.faceIndex
                  ),
                  reciprocalRoom.faces[
                    reciprocal.faceIndex
                  ].portalIndex == portal.connectedPortal,
                  reciprocalRoom.faces[
                    reciprocal.faceIndex
                  ].texture == stockSurface,
                  let reciprocalPhysics =
                    level.surfacePhysics.first(where: {
                        $0.texture
                          == reciprocalRoom.faces[
                            reciprocal.faceIndex
                          ].texture
                    }),
                  reciprocalPhysics.behavior == .forceField,
                  level.presentationMaterials.contains(where: {
                      $0.texture
                        == reciprocalRoom.faces[
                          reciprocal.faceIndex
                        ].texture
                        && $0.waterProcedural != nil
                  }) else {
                return false
            }
            return reciprocal.flags & 1 == rendersFaces
        }
    return chain.openMarkerLightDistance.isFinite
        && chain.openMarkerLightDistance >= 0
        && chain.markerLightPresentation.map { presentation in
            isFinite(presentation.primaryColor)
                && isFinite(presentation.secondaryColor)
                && presentation.primaryColor.x >= 0
                && presentation.primaryColor.y >= 0
                && presentation.primaryColor.z >= 0
                && presentation.secondaryColor.x >= 0
                && presentation.secondaryColor.y >= 0
                && presentation.secondaryColor.z >= 0
                && presentation.timeInterval.isFinite
                && presentation.timeInterval >= 0
                && presentation.flickerDistance.isFinite
                && presentation.flickerDistance >= 0
                && presentation.directionalDot.isFinite
                && presentation.flags & ~UInt32(0x3f) == 0
        } == true
        && portalsAreAtomic
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

struct TrainingGuidebotYellowFlareDefinition:
    Codable, Equatable, Sendable
{
    let source: SourceResource
    let model: SourceResource
    let particleTexture: SourceResource
    let fireSoundSourceName: String
    let weaponFlags: UInt32
    let physicsFlags: UInt32
    let modelPageSize: Float
    let collisionRadius: Float
    let speed: Float
    let lifetime: Float
    let mass: Float
    let drag: Float
    let coefficientOfRestitution: Float
    let lightDistance: Float
    let lightPresentation: TrainingMarkerLightPresentation
    let particleCount: Int
    let particleInterval: Float
    let particleSize: Float
    let particleLifetime: Float
    var timeout: TrainingGuidebotYellowFlareTimeoutDefinition? = nil
}

struct TrainingGuidebotYellowFlareTimeoutDefinition:
    Codable, Equatable, Sendable
{
    let explosionTexture: SourceResource
    let explosionLifetime: Float
    let explosionSize: Float
    let childSource: SourceResource
    let childTexture: SourceResource
    let childCount: Int
    let childWeaponFlags: UInt32
    let childPhysicsFlags: UInt32
    let childCollisionRadius: Float
    let childSpeed: Float
    let childLifetime: Float
    let childMass: Float
    let childDrag: Float
    let childCoefficientOfRestitution: Float
    let childLightDistance: Float
    let childLightPresentation: TrainingMarkerLightPresentation
    let childParticleCount: Int
    let childParticleInterval: Float
    let childParticleSize: Float
    let childParticleLifetime: Float
    var childAnimationFrames: [SourceResource]? = nil
    var childSourceFrameTime: Float? = nil

    var hasCoherentChildAnimationBinding: Bool {
        childAnimationFrames == nil && childSourceFrameTime == nil
            || childAnimationFrames
                == [childTexture]
                    + Array(
                        trainingGuidebotYellowFlareAnimationFrames.dropFirst()
                    )
                && childSourceFrameTime?.bitPattern
                    == trainingGuidebotYellowFlareSourceFrameTime.bitPattern
    }
}

let trainingGuidebotYellowFlareAnimationFrames: [SourceResource] = [
    .init(storedIndex: 878, sourceName: "yellowspark"),
    .init(storedIndex: 878, sourceName: "yellowspark.oaf frame 1"),
    .init(storedIndex: 878, sourceName: "yellowspark.oaf frame 2"),
    .init(storedIndex: 878, sourceName: "yellowspark.oaf frame 3"),
    .init(storedIndex: 878, sourceName: "yellowspark.oaf frame 4"),
    .init(storedIndex: 878, sourceName: "yellowspark.oaf frame 5"),
]
let trainingGuidebotYellowFlareSourceFrameTime: Float = 0.07

extension TrainingRobotCombatDefinition {
    // d3.hog/table.gam generic page "RAS1 Light Security Flyer",
    // version 27 score field. All ten Training combat chains use this page.
    static let stockTrainingScore = 200

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
    proceed5: CanonicalVoiceClip?,
    releaseSound: CanonicalSoundClip? = nil,
    ambientEngineSound: CanonicalSoundClip? = nil,
    flareSound: CanonicalSoundClip? = nil
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
          (
              chain.releaseSoundSourceName == nil
                  || chain.releaseSoundSourceName == "GBExpulsionA.wav"
                    && releaseSound?.logicalName == "GBExpulsionA"
                    && releaseSound?.sourceName == "GBExpulsionA.wav"
                    && releaseSound?.sourceEntryIndex == 1_246
                    && releaseSound?.sampleRate == 22_050
                    && releaseSound?.channelCount == 1
                    && releaseSound?.frameCount == 22_475
                    && releaseSound?.pcm16LittleEndian.count == 44_950
                    && releaseSound?.pcmSHA256
                        == "24a95adeb0b468f3c677007e00f9d8fd73919d60128646bedaa29db5f3f56f6e"
                    && releaseSound?.sourceArchive == "d3.hog"
                    && releaseSound?.sourceSHA256
                        == "ae030e17bd5fc5724b7b3aac6604299005d35adffc0b5d9620430d191e1ef288"
                    && releaseSound?.importVolume == 0.5
          ),
          (
              chain.ambientEngineSoundSourceName == nil
                  || chain.ambientEngineSoundSourceName == "GBotEngineB.wav"
                    && ambientEngineSound?.logicalName == "GBotEngineB1"
                    && ambientEngineSound?.sourceName == "GBotEngineB.wav"
                    && ambientEngineSound?.sourceEntryIndex == 1_262
                    && ambientEngineSound?.sampleRate == 22_050
                    && ambientEngineSound?.channelCount == 1
                    && ambientEngineSound?.frameCount == 8_080
                    && ambientEngineSound?.pcm16LittleEndian.count == 16_160
                    && ambientEngineSound?.pcmSHA256
                        == "2a9c63eb02ea72e256cbaff7e87c575cce415ad11ef1d753123fe8a97b7da528"
                    && ambientEngineSound?.sourceArchive == "d3.hog"
                    && ambientEngineSound?.sourceSHA256
                        == "35eaf843ad66e61a1f5c46f68ced68d5fbec8580dc8e1c8d115e374349f5a96f"
                    && ambientEngineSound?.importVolume == 0.1
          ),
          (
              chain.yellowFlare == nil
                  || chain.yellowFlare.map { flare in
                      flare.source == .init(
                          storedIndex: 3,
                          sourceName: "Yellow flare"
                      )
                          && flare.model.sourceName
                            == "FlareYellowBright.OOF"
                          && flare.particleTexture == .init(
                              storedIndex: 878,
                              sourceName: "yellowspark"
                          )
                          && flare.fireSoundSourceName == "Flare.wav"
                          && flare.weaponFlags == 0x8001_0000
                          && flare.physicsFlags == 0x2000_0810
                          && flare.modelPageSize.bitPattern
                            == 0x405f_d5ea
                          && flare.collisionRadius == 0.1
                          && flare.speed == 100
                          && flare.lifetime == 15
                          && flare.mass == 0.1
                          && flare.drag == 0.0001
                          && flare.coefficientOfRestitution == 1
                          && flare.lightDistance == 35
                          && flare.lightPresentation == .init(
                              primaryColor: .init(x: 1, y: 1, z: 0.8),
                              secondaryColor: .zero,
                              timeInterval: 0.2,
                              flickerDistance: 5,
                              directionalDot: 0,
                              flags: 16,
                              timebits: UInt32.max,
                              angle: 0,
                              lightingRenderType: 0
                          )
                          && flare.particleCount == 25
                          && flare.particleInterval == 0.04
                          && flare.particleSize.bitPattern
                            == Float(0.2).bitPattern
                          && flare.particleLifetime.bitPattern
                            == Float(0.3).bitPattern
                          && (
                              flare.timeout == nil
                                  || flare.timeout.map { timeout in
                                      timeout.explosionTexture == .init(
                                          storedIndex: 900,
                                          sourceName: "FlarePuff"
                                      )
                                          && timeout.explosionLifetime == 0.2
                                          && timeout.explosionSize == 2
                                          && timeout.childSource == .init(
                                              storedIndex: 54,
                                              sourceName: "YellowFlareSparks"
                                          )
                                          && timeout.childTexture == .init(
                                              storedIndex: 878,
                                              sourceName: "yellowspark"
                                          )
                                          && timeout.childCount == 9
                                          && timeout.childWeaponFlags == 1_056
                                          && timeout.childPhysicsFlags
                                            == 2_556_032
                                          && timeout.childCollisionRadius == 0.2
                                          && timeout.childSpeed == 17
                                          && timeout.childLifetime == 0.2
                                          && timeout.childMass == 0.1
                                          && timeout.childDrag == 0.1
                                          && timeout.childCoefficientOfRestitution == 1
                                          && timeout.childLightDistance == 6
                                          && timeout.childLightPresentation == .init(
                                              primaryColor: .init(x: 1, y: 1, z: 0.5),
                                              secondaryColor: .zero,
                                              timeInterval: 0,
                                              flickerDistance: 0,
                                              directionalDot: 0,
                                              flags: 0,
                                              timebits: 0,
                                              angle: 0,
                                              lightingRenderType: 0
                                          )
                                          && timeout.childParticleCount == 25
                                          && timeout.childParticleInterval == 0.04
                                          && timeout.childParticleSize == 0.3
                                          && timeout.childParticleLifetime == 0.3
                                          && timeout
                                            .hasCoherentChildAnimationBinding
                                  } == true
                          )
                  } == true
                  && flareSound?.logicalName == "Flare"
                  && flareSound?.sourceName == "Flare.wav"
                  && flareSound?.sourceEntryIndex == 1_158
                  && flareSound?.sampleRate == 22_050
                  && flareSound?.channelCount == 1
                  && flareSound?.frameCount == 25_086
                  && flareSound?.pcm16LittleEndian.count == 50_172
                  && flareSound?.pcmSHA256
                    == "98aa8dc4652268a3f512c995dcc8cc3f6ef3abe62947f839167bd809f9423452"
                  && flareSound?.sourceArchive == "d3.hog"
                  && flareSound?.sourceSHA256
                    == "79cb319f84c4cfdcdb6ca2ab853767df3f1e128f516ff007dc9febf8f5a988b7"
                  && flareSound?.importVolume.bitPattern
                    == Float(0.300_000_07).bitPattern
          ),
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

func validateStockTrainingRepeatForwardGoalPackage(
    lesson: TrainingRepeatForwardGoalLesson?,
    forwardGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    menuBeep: CanonicalSoundClip?
) throws {
    guard let lesson,
          lesson.forwardGoalObjectHandle == 12_301,
          lesson.collisionRadius == 10.052_409,
          lesson.reverseInstruction
            == "Now use the reverse Key to return to where you started!",
          lesson.soundLogicalName == "MenuBeepEnter",
          forwardGoal?.type == 7,
          forwardGoal?.storedID == 67,
          forwardGoal?.definition?.storedIndex == 67,
          forwardGoal?.definition?.referenceRuntimeIndex == 68,
          forwardGoal?.definition?.sourceName == "Invisiblepowerup",
          forwardGoal?.instanceName == "ForwardGoal",
          forwardGoal?.flags == 36_864,
          forwardGoal?.location == .room(1),
          forwardGoal?.position
            == .init(
                x: 2_060.4836,
                y: -131.22517,
                z: 2_310.928
            ),
          forwardGoal?.orientation
            == .init(
                right: .init(
                    x: -0.997_518_1,
                    y: 0,
                    z: 0.070_410_63
                ),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(
                    x: -0.070_410_63,
                    y: 0,
                    z: -0.997_518_1
                )
            ),
          forwardGoal?.containsType == 255,
          forwardGoal?.containsID == 0,
          forwardGoal?.containsCount == 0,
          forwardGoal?.lifeLeft == 0,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.isVisible == false,
          menuBeep?.sourceName == "MenuBeepSelectC.wav",
          menuBeep?.sourceEntryIndex == 2_079,
          menuBeep?.sampleRate == 22_050,
          menuBeep?.channelCount == 1,
          menuBeep?.frameCount == 2_321,
          menuBeep?.pcmSHA256
            == "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
          menuBeep?.sourceArchive == "d3.hog",
          menuBeep?.sourceSHA256
            == "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
          menuBeep?.importVolume == 0.7
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 008 package"
        )
    }
}

func validateStockTrainingRepeatReturnLeftPackage(
    lesson: TrainingRepeatReturnLeftLesson?,
    startGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    lright: CanonicalVoiceClip?
) throws {
    guard let lesson,
          lesson.startGoalObjectHandle == 12_300,
          lesson.collisionRadius == 10.052_409,
          lesson.instruction == "Now Go Left until you stop.",
          lesson.voiceSourceName == "lright.osf",
          startGoal?.type == 7,
          startGoal?.storedID == 67,
          startGoal?.definition?.storedIndex == 67,
          startGoal?.definition?.referenceRuntimeIndex == 68,
          startGoal?.definition?.sourceName == "Invisiblepowerup",
          startGoal?.instanceName == "StartGoal",
          startGoal?.flags == 36_864,
          startGoal?.location == .room(1),
          startGoal?.position
            == .init(
                x: 2_062.7678,
                y: -134.19601,
                z: 2_201.679
            ),
          startGoal?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          startGoal?.containsType == 255,
          startGoal?.containsID == 0,
          startGoal?.containsCount == 0,
          startGoal?.lifeLeft == 0,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.isVisible == false,
          lright?.sourceName.caseInsensitiveCompare("lright.osf")
            == .orderedSame,
          lright?.sourceEntryIndex == 19,
          lright?.sampleRate == 22_050,
          lright?.channelCount == 1,
          lright?.frameCount == 43_289,
          lright?.pcmSHA256
            == "db92df633fdc0010fe9c5cc89f452ea79107e0abdfd4a1ff1e845220abf8b7b5",
          lright?.sourceArchive == "missions/training.mn3",
          lright?.sourceSHA256
            == "234c82a439232af1072a7cb6aef8e6d14b6432a2c7a642f7a8e4904a01e88294"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 009 package"
        )
    }
}

func validateStockTrainingRepeatReturnRightPackage(
    lesson: TrainingRepeatReturnRightLesson?,
    leftGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    menuBeep: CanonicalSoundClip?
) throws {
    guard let lesson,
          lesson.leftGoalObjectHandle == 12_299,
          lesson.collisionRadius == 10.052_409,
          lesson.instruction
            == "Now Slide right until you return to the start position.",
          lesson.soundLogicalName == "MenuBeepEnter",
          leftGoal?.type == 7,
          leftGoal?.storedID == 67,
          leftGoal?.definition?.storedIndex == 67,
          leftGoal?.definition?.referenceRuntimeIndex == 68,
          leftGoal?.definition?.sourceName == "Invisiblepowerup",
          leftGoal?.instanceName == "LeftGoal",
          leftGoal?.flags == 4_352,
          leftGoal?.location == .room(1),
          leftGoal?.position
            == .init(
                x: 1_958.2805,
                y: -131.22517,
                z: 2_205.8071
            ),
          leftGoal?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: -1)
            ),
          leftGoal?.containsType == 255,
          leftGoal?.containsID == 0,
          leftGoal?.containsCount == 0,
          leftGoal?.lifeLeft == 0,
          leftGoal?.soundSource == nil,
          leftGoal?.inertScriptName == nil,
          leftGoal?.inertModuleName == nil,
          leftGoal?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          menuBeep?.sourceName == "MenuBeepSelectC.wav",
          menuBeep?.sourceEntryIndex == 2_079,
          menuBeep?.sampleRate == 22_050,
          menuBeep?.channelCount == 1,
          menuBeep?.frameCount == 2_321,
          menuBeep?.pcmSHA256
            == "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
          menuBeep?.sourceArchive == "d3.hog",
          menuBeep?.sourceSHA256
            == "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
          menuBeep?.importVolume == 0.7
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 010 package"
        )
    }
}

func validateStockTrainingRepeatReturnUpPackage(
    lesson: TrainingRepeatReturnUpLesson?,
    startGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    udown: CanonicalVoiceClip?
) throws {
    guard let lesson,
          lesson.startGoalObjectHandle == 12_300,
          lesson.collisionRadius == 10.052_409,
          lesson.instruction == "Now Slide up  until you stop.",
          lesson.voiceSourceName == "udown.osf",
          startGoal?.type == 7,
          startGoal?.storedID == 67,
          startGoal?.definition?.storedIndex == 67,
          startGoal?.definition?.referenceRuntimeIndex == 68,
          startGoal?.definition?.sourceName == "Invisiblepowerup",
          startGoal?.instanceName == "StartGoal",
          startGoal?.flags == 36_864,
          startGoal?.location == .room(1),
          startGoal?.position
            == .init(
                x: 2_062.7678,
                y: -134.19601,
                z: 2_201.679
            ),
          startGoal?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          startGoal?.containsType == 255,
          startGoal?.containsID == 0,
          startGoal?.containsCount == 0,
          startGoal?.lifeLeft == 0,
          startGoal?.soundSource == nil,
          startGoal?.inertScriptName == nil,
          startGoal?.inertModuleName == nil,
          startGoal?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          udown?.sourceName.caseInsensitiveCompare("udown.osf")
            == .orderedSame,
          udown?.sourceEntryIndex == 36,
          udown?.sampleRate == 22_050,
          udown?.channelCount == 1,
          udown?.frameCount == 37_257,
          udown?.pcmSHA256
            == "e54d74f7e18603ad90015cef1e7c15cce693e35a394be4a0a45943c07740af2a",
          udown?.sourceArchive == "missions/training.mn3",
          udown?.sourceSHA256
            == "f9596f8edb16be0821bb7b846b81432b27aa95f08ac621f1ac1f15eb1279aa43"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 011 package"
        )
    }
}

func validateStockTrainingRepeatReturnDownPackage(
    lesson: TrainingRepeatReturnDownLesson?,
    upGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    menuBeep: CanonicalSoundClip?
) throws {
    guard let lesson,
          lesson.upGoalObjectHandle == 18_441,
          lesson.collisionRadius == 10.052_409,
          lesson.instruction
            == "Now Slide down until you return to the start position.",
          lesson.soundLogicalName == "MenuBeepEnter",
          upGoal?.type == 7,
          upGoal?.storedID == 67,
          upGoal?.definition?.storedIndex == 67,
          upGoal?.definition?.referenceRuntimeIndex == 68,
          upGoal?.definition?.sourceName == "Invisiblepowerup",
          upGoal?.instanceName == "UpGoal",
          upGoal?.flags == 4_352,
          upGoal?.location == .room(1),
          upGoal?.position
            == .init(
                x: 2_060.6682,
                y: -25.897_497,
                z: 2_204.6843
            ),
          upGoal?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          upGoal?.containsType == 255,
          upGoal?.containsID == 0,
          upGoal?.containsCount == 0,
          upGoal?.lifeLeft == 0,
          upGoal?.soundSource == nil,
          upGoal?.inertScriptName == nil,
          upGoal?.inertModuleName == nil,
          upGoal?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          menuBeep?.sourceName == "MenuBeepSelectC.wav",
          menuBeep?.sourceEntryIndex == 2_079,
          menuBeep?.sampleRate == 22_050,
          menuBeep?.channelCount == 1,
          menuBeep?.frameCount == 2_321,
          menuBeep?.pcmSHA256
            == "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
          menuBeep?.sourceArchive == "d3.hog",
          menuBeep?.sourceSHA256
            == "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
          menuBeep?.importVolume == 0.7
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 012 package"
        )
    }
}

func validateStockTrainingContinueToCoursePackage(
    lesson: TrainingContinueToCourseLesson?,
    startGoal: PlacedObject?,
    presentation: ObjectPresentationReference?,
    portalRoom: LevelRoom?,
    connectedRooms: [Int: LevelRoom],
    proceed1: CanonicalVoiceClip?
) throws {
    guard let lesson,
          lesson.startGoalObjectHandle == 12_300,
          lesson.collisionRadius == 10.052_409,
          lesson.portalRoomSourceIndex == 2,
          lesson.orderedPortalIndices == [0, 1],
          lesson.instruction
            == "Continue Sliding down to start the next step.",
          lesson.voiceSourceName == "proceed1.osf",
          startGoal?.type == 7,
          startGoal?.storedID == 67,
          startGoal?.definition?.storedIndex == 67,
          startGoal?.definition?.referenceRuntimeIndex == 68,
          startGoal?.definition?.sourceName == "Invisiblepowerup",
          startGoal?.instanceName == "StartGoal",
          startGoal?.flags == 36_864,
          startGoal?.location == .room(1),
          startGoal?.position
            == .init(
                x: 2_062.7678,
                y: -134.19601,
                z: 2_201.679
            ),
          startGoal?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          startGoal?.containsType == 255,
          startGoal?.containsID == 0,
          startGoal?.containsCount == 0,
          startGoal?.lifeLeft == 0,
          startGoal?.soundSource == nil,
          startGoal?.inertScriptName == nil,
          startGoal?.inertModuleName == nil,
          startGoal?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          let portalRoom,
          portalRoom.name == "PortalRoom1",
          portalRoom.sourceIndex == 2,
          portalRoom.portals.count == 2,
          portalRoom.faces.indices.contains(0),
          portalRoom.faces.indices.contains(1),
          portalRoom.portals[0].faceIndex == 0,
          portalRoom.portals[0].connectedRoom == 1,
          portalRoom.portals[0].connectedPortal == 0,
          portalRoom.portals[0].flags & 1 != 0,
          portalRoom.faces[0].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          portalRoom.portals[1].faceIndex == 1,
          portalRoom.portals[1].connectedRoom == 3,
          portalRoom.portals[1].connectedPortal == 0,
          portalRoom.portals[1].flags & 1 != 0,
          portalRoom.faces[1].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          let connectedRoomOne = connectedRooms[1],
          connectedRoomOne.portals.indices.contains(0),
          connectedRoomOne.faces.indices.contains(73),
          connectedRoomOne.portals[0].faceIndex == 73,
          connectedRoomOne.portals[0].connectedRoom == 2,
          connectedRoomOne.portals[0].connectedPortal == 0,
          connectedRoomOne.portals[0].flags & 1 != 0,
          connectedRoomOne.faces[73].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          let connectedRoomThree = connectedRooms[3],
          connectedRoomThree.portals.indices.contains(0),
          connectedRoomThree.faces.indices.contains(0),
          connectedRoomThree.portals[0].faceIndex == 0,
          connectedRoomThree.portals[0].connectedRoom == 2,
          connectedRoomThree.portals[0].connectedPortal == 1,
          connectedRoomThree.portals[0].flags & 1 != 0,
          connectedRoomThree.faces[0].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          proceed1?.sourceName.caseInsensitiveCompare("proceed1.osf")
            == .orderedSame,
          proceed1?.sourceEntryIndex == 21,
          proceed1?.sampleRate == 22_050,
          proceed1?.channelCount == 1,
          proceed1?.frameCount == 120_753,
          proceed1?.pcmSHA256
            == "5eba5487d90f946a876eaa500d3a27e496fe280d9fadcd633b8f505c58ccb477",
          proceed1?.sourceArchive == "missions/training.mn3",
          proceed1?.sourceSHA256
            == "9f869718d68d56902ee634b47a1f8cafa83f79036fe39216d190cebf0803081a"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 013 package"
        )
    }
}

func validateStockTrainingStartCoursePackage(
    lesson: TrainingStartCourseLesson?,
    startCourse: PlacedObject?,
    presentation: ObjectPresentationReference?,
    portalRoom: LevelRoom?,
    connectedRoom: LevelRoom?,
    intro1: CanonicalVoiceClip?
) throws {
    guard let lesson,
          lesson.startCourseObjectHandle == 6_147,
          lesson.collisionRadius == 10.052_409,
          lesson.portalRoomSourceIndex == 2,
          lesson.portalIndex == 1,
          lesson.instruction
            == "Now, manuever through this tunnel using the sliding skills you just learned.",
          lesson.voiceSourceName == "intro1.osf",
          lesson.enabledControlMask == 63,
          startCourse?.type == 7,
          startCourse?.storedID == 67,
          startCourse?.definition?.storedIndex == 67,
          startCourse?.definition?.referenceRuntimeIndex == 68,
          startCourse?.definition?.sourceName == "Invisiblepowerup",
          startCourse?.instanceName == "StartCourse",
          startCourse?.flags == 4_096,
          startCourse?.location == .room(3),
          startCourse?.position
            == .init(
                x: 2_061.4604,
                y: -230.09009,
                z: 2_203.0276
            ),
          startCourse?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          startCourse?.containsType == 255,
          startCourse?.containsID == 0,
          startCourse?.containsCount == 0,
          startCourse?.lifeLeft == 0,
          startCourse?.soundSource == nil,
          startCourse?.inertScriptName == nil,
          startCourse?.inertModuleName == nil,
          startCourse?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          let portalRoom,
          portalRoom.name == "PortalRoom1",
          portalRoom.sourceIndex == 2,
          portalRoom.portals.indices.contains(1),
          portalRoom.faces.indices.contains(1),
          portalRoom.portals[1].faceIndex == 1,
          portalRoom.portals[1].connectedRoom == 3,
          portalRoom.portals[1].connectedPortal == 0,
          portalRoom.portals[1].flags & 1 != 0,
          portalRoom.faces[1].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          let connectedRoom,
          connectedRoom.sourceIndex == 3,
          connectedRoom.portals.indices.contains(0),
          connectedRoom.faces.indices.contains(0),
          connectedRoom.portals[0].faceIndex == 0,
          connectedRoom.portals[0].connectedRoom == 2,
          connectedRoom.portals[0].connectedPortal == 1,
          connectedRoom.portals[0].flags & 1 != 0,
          connectedRoom.faces[0].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          intro1?.sourceName == "intro1.osf",
          intro1?.sourceEntryIndex == 10,
          intro1?.sampleRate == 22_050,
          intro1?.channelCount == 1,
          intro1?.frameCount == 475_785,
          intro1?.pcmSHA256
            == "7a91932d2f083bbb498247a0cac427ea5e4fdacb7b7eb7e3d9653b43b6f87c6c",
          intro1?.sourceArchive == "missions/training.mn3",
          intro1?.sourceSHA256
            == "d4f0a217c401899acbbf64e25f0d013542acae82e667bb2330be5770e35d200f"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 014 package"
        )
    }
}

func validateStockTrainingFinishCoursePackage(
    lesson: TrainingFinishCourseLesson?,
    finishCourse: PlacedObject?,
    presentation: ObjectPresentationReference?,
    portalRoom: LevelRoom?,
    connectedRooms: [Int: LevelRoom],
    proceed2: CanonicalVoiceClip?
) throws {
    guard let lesson,
          lesson.finishCourseObjectHandle == 6_150,
          lesson.collisionRadius == 10.052_409,
          lesson.portalRoomSourceIndex == 49,
          lesson.orderedPortalIndices == [0, 1],
          lesson.successMessage == "Excellent!",
          lesson.instruction
            == "Continue Sliding down to start the next step.",
          lesson.voiceSourceName == "proceed2.osf",
          lesson.enabledControlMask == 32,
          finishCourse?.type == 7,
          finishCourse?.storedID == 67,
          finishCourse?.definition?.storedIndex == 67,
          finishCourse?.definition?.referenceRuntimeIndex == 68,
          finishCourse?.definition?.sourceName == "Invisiblepowerup",
          finishCourse?.instanceName == "FinishCourse",
          finishCourse?.flags == 4_096,
          finishCourse?.location == .room(50),
          finishCourse?.position
            == .init(
                x: 2_062.5024,
                y: -650.74756,
                z: 2_206.0369
            ),
          finishCourse?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
          finishCourse?.containsType == 255,
          finishCourse?.containsID == 0,
          finishCourse?.containsCount == 0,
          finishCourse?.lifeLeft == 0,
          finishCourse?.soundSource == nil,
          finishCourse?.inertScriptName == nil,
          finishCourse?.inertModuleName == nil,
          finishCourse?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel
            == .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.mediumDistance == nil,
          presentation?.lowDistance == nil,
          presentation?.isVisible == false,
          let portalRoom,
          portalRoom.name == "PortalRoom2",
          portalRoom.sourceIndex == 49,
          portalRoom.portals.count == 2,
          portalRoom.faces.indices.contains(0),
          portalRoom.faces.indices.contains(1),
          portalRoom.portals[0].faceIndex == 1,
          portalRoom.portals[0].connectedRoom == 35,
          portalRoom.portals[0].connectedPortal == 0,
          portalRoom.portals[0].flags & 1 != 0,
          portalRoom.faces[1].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          portalRoom.portals[1].faceIndex == 0,
          portalRoom.portals[1].connectedRoom == 50,
          portalRoom.portals[1].connectedPortal == 0,
          portalRoom.portals[1].flags & 1 != 0,
          portalRoom.faces[0].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          let connectedRoom35 = connectedRooms[35],
          connectedRoom35.portals.indices.contains(0),
          connectedRoom35.faces.indices.contains(20),
          connectedRoom35.portals[0].faceIndex == 20,
          connectedRoom35.portals[0].connectedRoom == 49,
          connectedRoom35.portals[0].connectedPortal == 0,
          connectedRoom35.portals[0].flags & 1 != 0,
          connectedRoom35.faces[20].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          let connectedRoom50 = connectedRooms[50],
          connectedRoom50.portals.indices.contains(0),
          connectedRoom50.faces.indices.contains(0),
          connectedRoom50.portals[0].faceIndex == 0,
          connectedRoom50.portals[0].connectedRoom == 49,
          connectedRoom50.portals[0].connectedPortal == 1,
          connectedRoom50.portals[0].flags & 1 != 0,
          connectedRoom50.faces[0].texture
            == .init(
                storedIndex: 908,
                sourceName: "Alien Force Field_1"
            ),
          proceed2?.sourceName.caseInsensitiveCompare("proceed2.osf")
            == .orderedSame,
          proceed2?.sourceEntryIndex == 22,
          proceed2?.sampleRate == 22_050,
          proceed2?.channelCount == 1,
          proceed2?.frameCount == 136_901,
          proceed2?.pcmSHA256
            == "78c63a73ed1ddbd12a5974ef74c31bc6bfd10295f96ddf345fb15b2565586fca",
          proceed2?.sourceArchive == "missions/training.mn3",
          proceed2?.sourceSHA256
            == "65c51f7e7bf15091ac59c9c3186a9269bf885311b6aada57f74628d497e87f14"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 015 package"
        )
    }
}

func validateStockTrainingDodgeAttemptPackage(
    _ dodge: TrainingDodgeAttempt?,
    level: Level
) throws {
    let turretModel = dodge.flatMap { definition in
        level.models.first {
            $0.source == definition.turret.model
        }
    }
    let projectileModel = dodge.flatMap { definition in
        level.models.first {
            $0.source == definition.turret.projectileModel
        }
    }
    let intro = level.voiceClips.first {
        $0.sourceName == "intro2.osf"
    }
    let almost = level.voiceClips.first {
        $0.sourceName == "almost.osf"
    }
    let proceed = level.voiceClips.first {
        $0.sourceName == "proceed3.osf"
    }
    let proceed4 = level.voiceClips.first {
        $0.sourceName == "proceed4.osf"
    }
    let fire = level.soundClips.first {
        $0.logicalName == "WpmLaserBlueFire"
    }
    let impact = level.soundClips.first {
        $0.logicalName == "LazorHitshrt"
    }
    guard let dodge,
        level.objects.first(where: {
            $0.handle == dodge.startDodgeObjectHandle
        })?.definition?.referenceRuntimeIndex == 68,
        level.objects.first(where: {
            $0.handle == dodge.doneDodgeingGoalObjectHandle
        })?.definition?.referenceRuntimeIndex == 68,
        dodge.turret.collisionRadius == 5.402_855_4,
        dodge.turret.fieldOfViewDot == -1,
        dodge.turret.maximumTargetDistance == 1_000,
        dodge.turret.fireAlignmentDot == 0.93,
        dodge.turret.fixedLeadAccuracy == 0.81,
        dodge.turret.fireWait == 1,
        dodge.turret.gunpoints == [
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
        dodge.turret.aimingGunpoint
            == .init(
                x: 1.085_584_6,
                y: -2.224_015_2,
                z: 2.190_463_5
            ),
        dodge.turret.gunpointForward
            == .init(x: 0, y: -0.707_105_7, z: 0.707_107_84),
        dodge.turret.gunpointParentSubmodelIndex == 2,
        dodge.turret.joints == [
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
        dodge.turret.projectileSourceName == "Laser Level 1 - Red",
        dodge.turret.projectileDamage == 6.75,
        dodge.turret.projectileRadius == 0.5,
        dodge.turret.projectileSpeed == 200,
        dodge.turret.projectileLifetime == 5,
        dodge.turret.fireSoundSourceName == "WpmLaserBlueFire",
        dodge.turret.impactSoundSourceName == "LazorHitshrt",
        turretModel?.collisionRadius == 5.552_946,
        turretModel?.submodels.count == 3,
        turretModel?.submodels[1].parentIndex == 0,
        turretModel?.submodels[1].offset
            == .init(
                x: -0.079_373_36,
                y: -1.241_355_9,
                z: 0.097_942_59
            ),
        turretModel?.submodels[1].presentation
            == .turret(
                fieldOfView: 0.5,
                rotationsPerSecond: 0.125,
                thinkInterval: 10,
                axis: .init(x: 0, y: -1, z: 0)
            ),
        turretModel?.submodels[2].parentIndex == 1,
        turretModel?.submodels[2].offset
            == .init(
                x: -1.132_905,
                y: -1.353_618_6,
                z: 0.311_014_4
            ),
        turretModel?.submodels[2].presentation
            == .turret(
                fieldOfView: 0.125,
                rotationsPerSecond: 0.125,
                thinkInterval: 10,
                axis: .init(
                    x: 1,
                    y: -3.410_774_8e-16,
                    z: -4.371_139e-8
                )
            ),
        turretModel?.sourceSHA256
            == "41c69958947ddc7673ddfe2ffb6f559c6892eafed8b759a02b47c05b22f137e4",
        projectileModel?.collisionRadius == 4.878_135,
        projectileModel?.sourceSHA256
            == "67e6ff8f84fbcbc60b33a61b222e04be6cfbd4b53ad367ac14f82cca2a76a1ab",
        intro?.sampleRate == 22_050,
        intro?.channelCount == 1,
        intro?.frameCount == 419_497,
        intro?.pcmSHA256
            == "c43858617c694a1c41dbcc2b9b0c31e0b0f73ff7e33423ef3b80bcf501ef9def",
        intro?.sourceArchive == "missions/training.mn3",
        intro?.sourceSHA256
            == "46d1947fad72e9fb33bd6e912bf45fc7f20e5095f27b8a0516f24e2a8077f880",
        almost?.sampleRate == 22_050,
        almost?.channelCount == 1,
        almost?.frameCount == 68_977,
        almost?.pcmSHA256
            == "4d90c15e4c1f9a22fb9b4a3808739d6eecd8590b688b10a84abe7bf641ef8017",
        almost?.sourceArchive == "missions/training.mn3",
        almost?.sourceSHA256
            == "2f40177e347bb942bbacb3a54fc8ba5a91410132fdaf79e69fca862f2c4d8d93",
        proceed?.sampleRate == 22_050,
        proceed?.channelCount == 1,
        proceed?.frameCount == 149_913,
        proceed?.pcmSHA256
            == "abc67c37d716253959d0ec615b364b6ff59b896179fc3f93256be3870ed3dabd",
        proceed?.sourceArchive == "missions/training.mn3",
        proceed?.sourceSHA256
            == "3f7050b78bce76e370847b89e824b11db618f1b2d7c0d35de2f579e8edb67460",
        fire?.sourceName == "LaserAHitB.wav",
        fire?.sampleRate == 22_050,
        fire?.channelCount == 1,
        fire?.frameCount == 22_048,
        fire?.pcmSHA256
            == "150811e7fee88f8ad68a7cff7eb64c1a3cbaa89ba3a5a3330debf2a1f5e0c84a",
        fire?.sourceArchive == "d3.hog",
        fire?.sourceSHA256
            == "c76cb4a9608b4e57613c1b5438dcbd9af4618ad87c57f0c747de61aa7f810208",
        fire?.importVolume == 1,
        impact?.sourceName == "Lazor1Hit.wav",
        impact?.sampleRate == 22_050,
        impact?.channelCount == 1,
        impact?.frameCount == 17_728,
        impact?.pcmSHA256
            == "8b5154fa71e2fded239c6415ba4d77511a90bb4ab72aed8ea2e3bd231cf52b99",
        impact?.sourceArchive == "d3.hog",
        impact?.sourceSHA256
            == "7fe72d116e223068a55af61e6484f3604d6f07e6ae8d3ff3d5ca83016660f470",
        impact?.importVolume == 0.200_000_02
    else {
        throw LevelValidationError.invalidDependency(
            "Training timed dodge stock package"
        )
    }
    if let exit = dodge.dodgeExit {
        guard exit.objectHandle == dodge.doneDodgeingGoalObjectHandle,
            exit.collisionRadius
                == dodge.doneDodgeingGoalCollisionRadius,
            exit.markerLightObjectHandle
                == dodge.flashLightObjectHandle,
            exit.markerLightDistance == 50,
            exit.portalRoomSourceIndex
                == dodge.portalRoomThreeSourceIndex,
            exit.orderedPortalIndices == dodge.orderedPortalIndices,
            exit.disabledControlMask == 62,
            exit.instruction
                == "Now keep moving forward into the next room.",
            exit.voiceSourceName == "proceed4.osf",
            proceed4?.sourceEntryIndex == 24,
            proceed4?.sampleRate == 22_050,
            proceed4?.channelCount == 1,
            proceed4?.frameCount == 99_405,
            proceed4?.pcmSHA256
                == "92228006e3a802cc067a1650f735cc1a04865bf68d35ab3bc94343049e3dadc7",
            proceed4?.sourceArchive == "missions/training.mn3",
            proceed4?.sourceSHA256
                == "d7442b4192e34ed6b7b529f3b3d555be64ef3437c000611ff7fa57d6989550e9"
        else {
            throw LevelValidationError.invalidDependency(
                "Training Script 019 stock package"
            )
        }
    }
    if let lesson = dodge.maneuverFollow {
        try validateStockTrainingManeuverFollowPackage(
            lesson,
            dodge: dodge,
            level: level
        )
    }
}

func validateStockTrainingManeuverFollowPackage(
    _ lesson: TrainingManeuverFollowLesson,
    dodge: TrainingDodgeAttempt,
    level: Level
) throws {
    let maneuver = level.objects.first {
        $0.handle == lesson.maneuverObjectHandle
    }
    let followBot = level.objects.first {
        $0.handle == lesson.followBotObjectHandle
    }
    let presentation = level.objectPresentations.first {
        $0.objectHandle == lesson.followBotObjectHandle
    }
    let model = level.models.first {
        $0.source == lesson.followBot.model
    }
    let pathsSHA256 = canonicalSHA256(
        try canonicalJSONData(level.paths)
    )
    let roomBySourceIndex = Dictionary(
        uniqueKeysWithValues: level.rooms.map {
            ($0.sourceIndex, $0)
        }
    )
    let portalRoom = roomBySourceIndex[
        lesson.portalRoomSourceIndex
    ]
    let reciprocalConnections = lesson.orderedPortalIndices.compactMap {
        portalIndex -> (Int, Int)? in
        guard let portalRoom,
              portalRoom.portals.indices.contains(portalIndex)
        else {
            return nil
        }
        let portal = portalRoom.portals[portalIndex]
        guard let reciprocalRoom =
                roomBySourceIndex[portal.connectedRoom],
              reciprocalRoom.portals.indices.contains(
                  portal.connectedPortal
              ),
              reciprocalRoom.portals[portal.connectedPortal]
                .connectedRoom == lesson.portalRoomSourceIndex,
              reciprocalRoom.portals[portal.connectedPortal]
                .connectedPortal == portalIndex
        else {
            return nil
        }
        return (
            portal.connectedRoom,
            portal.connectedPortal
        )
    }
    let requiredVoices = [
        lesson.headingVoiceSourceName,
        lesson.pitchVoiceSourceName,
        lesson.bankVoiceSourceName,
        lesson.followVoiceSourceName,
        lesson.weaponVoiceSourceName,
    ]
    guard lesson.maneuverObjectHandle == 2_063,
          lesson.maneuverCollisionRadius == 10.052_409,
          lesson.flashLightObjectHandle
            == dodge.flashLightObjectHandle,
          lesson.portalRoomSourceIndex == 36,
          lesson.orderedPortalIndices == [1, 0],
          reciprocalConnections.map(\.0) == [37, 35],
          reciprocalConnections.map(\.1) == [0, 1],
          lesson.headingControlMask == 768,
          lesson.pitchControlMask == 192,
          lesson.bankControlMask == 3_072,
          lesson.rotationalControlMask == 4_032,
          lesson.weaponControlMask == 12_288,
          lesson.headingDuration == 20,
          lesson.pitchDuration == 12,
          lesson.bankDuration == 15,
          lesson.followDuration == 20,
          lesson.followBotObjectHandle == 8_200,
          lesson.friendlyTeamFlags == 65_536,
          lesson.followPathIndex == 0,
          lesson.followPathGoalFlags == 9_437_444,
          lesson.destroyPathIndex == 1,
          lesson.destroyPathGoalFlags == 4_352,
          lesson.goalSlot == 0,
          lesson.goalPriority == 3,
          lesson.maneuverIntroduction
            == "Now you are going to learn the other controls, which are pitch, heading and bank.",
          lesson.headingInstruction
            == "Now your heading controls are enabled. Try them out by rotating to the left and right.",
          lesson.successMessage == "Excellent!",
          lesson.pitchInstruction
            == "Now your pitch controls are enabled. Try them out by pitching up and down.",
          lesson.bankInstruction
            == "Now your bank controls are enabled. Try them out by banking to the left and right.",
          lesson.followIntroduction
            == "Now you will use the rotational skills you just learned to follow one of the two robots that are circling this room",
          lesson.followInstruction
            == "Keep one of the robots on your screen for 20 seconds using only your rotational controls to complete this step.",
          lesson.weaponsEnabledInstruction
            == "Now your weapons have been enabled. There is a primary and a secondary.",
          lesson.destroyInstruction == "Now, destroy the robot.",
          requiredVoices == [
              "intro3.osf",
              "pitch.osf",
              "bank.osf",
              "follow.osf",
              "intro4.osf",
          ],
          requiredVoices.allSatisfy({ sourceName in
              guard let voice = level.voiceClips.first(where: {
                  $0.sourceName == sourceName
              }),
                    voice.sampleRate == 22_050,
                    voice.channelCount == 1,
                    voice.pcm16LittleEndian.count
                        == voice.frameCount * 2,
                    voice.sourceArchive == "missions/training.mn3"
              else {
                  return false
              }
              switch sourceName {
              case "intro3.osf":
                  return voice.sourceEntryIndex == 12
                    && voice.frameCount == 340_641
                    && voice.pcmSHA256
                        == "66aa8390a210046b75a9c60fbdcff9b10acb8ba1e0b5bd650dd8f46e137ba119"
                    && voice.sourceSHA256
                        == "d2632c6e360d1d683c381c86155c7d8280a9880f4a8e6554e1884e82cff35036"
              case "pitch.osf":
                  return voice.sourceEntryIndex == 20
                    && voice.frameCount == 160_393
                    && voice.pcmSHA256
                        == "a717bd60b81636c17980a5ec742b44d60e091e0c768719b2d8bfd0713d29761b"
                    && voice.sourceSHA256
                        == "6b238a3d0301fcf34046c458632bb6fc88efeb26caa79dac5bce01c5c0ce6773"
              case "bank.osf":
                  return voice.sourceEntryIndex == 1
                    && voice.frameCount == 180_229
                    && voice.pcmSHA256
                        == "32d6968a855f0bc5a5e50da9cf57faf40089264d9777f6abb1e2f398b0f317da"
                    && voice.sourceSHA256
                        == "97949ad89610d02f8eb027c06daf8dc388e9d3159cc10fed85d62c6aaf7df703"
              case "follow.osf":
                  return voice.sourceEntryIndex == 3
                    && voice.frameCount == 163_749
                    && voice.pcmSHA256
                        == "92f90622166a1d27858510a2d3d1b0a5f1cf4d2690e204752927ca3bb4ff69a9"
                    && voice.sourceSHA256
                        == "6ec65e7e1aa1a6a5ec6c28b67e2c3f714925deaa4d910a152ec8d6f6ad908b5f"
              case "intro4.osf":
                  return voice.sourceEntryIndex == 13
                    && voice.frameCount == 750_221
                    && voice.pcmSHA256
                        == "2b874c0f3c704f3f029cac8d0ace36578b5141fc93aabc52ae2d9231975670ed"
                    && voice.sourceSHA256
                        == "325b1bcf073a24042836fca4fb6b1e1fcb4975a3cc3c3b3560db86b06af36b9e"
              default:
                  return false
              }
          }),
          maneuver?.type == 7,
          maneuver?.storedID == 67,
          maneuver?.definition?.storedIndex == 67,
          maneuver?.definition?.referenceRuntimeIndex == 68,
          maneuver?.definition?.sourceName == "Invisiblepowerup",
          maneuver?.instanceName == "ManuverRoomCenter",
          maneuver?.flags == 4_096,
          maneuver?.location == .room(37),
          maneuver?.position
            == .init(
                x: 2_061.7336,
                y: -755.4103,
                z: 2_566.1135
            ),
          maneuver?.orientation
            == .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: -1)
            ),
          maneuver?.containsType == 255,
          maneuver?.containsID == 0,
          maneuver?.containsCount == 0,
          maneuver?.lifeLeft == 0,
          maneuver?.soundSource == nil,
          maneuver?.inertScriptName == nil,
          maneuver?.inertModuleName == nil,
          maneuver?.lightmapSubmodels.isEmpty == true,
          followBot?.type == 2,
          followBot?.storedID == 106,
          followBot?.definition?.storedIndex == 106,
          followBot?.definition?.sourceName
            == "RAS1 Light Security Flyer",
          followBot?.instanceName == "FollowBot1",
          followBot?.flags == 5_121,
          followBot?.location == .room(37),
          followBot?.position
            == .init(
                x: 2_059.3496,
                y: -723.2588,
                z: 2_469.1072
            ),
          followBot?.orientation
            == .init(
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
            ),
          followBot?.containsType == 255,
          followBot?.containsID == 0,
          followBot?.containsCount == 0,
          followBot?.lifeLeft == 0,
          followBot?.soundSource == nil,
          followBot?.inertScriptName == nil,
          followBot?.inertModuleName == nil,
          followBot?.lightmapSubmodels.isEmpty == true,
          presentation?.primaryModel == lesson.followBot.model,
          presentation?.mediumModel == nil,
          presentation?.lowModel == nil,
          presentation?.dyingModel == nil,
          presentation?.isVisible == true,
          model?.source.sourceName == "gyro.OOF",
          model?.collisionRadius == 3.841_456_2,
          model?.sourceArchive == "d3.hog",
          model?.sourceSHA256
            == "896cc33ba0c7ec00fd2fd693a0e8f10868a47076eda0b7914cc90a790e87eb61",
          lesson.followBot.collisionRadius == 4.576_441_8,
          lesson.followBot.maximumVelocity == 40,
          lesson.followBot.maximumDeltaVelocity == 80,
          lesson.followBot.maximumTurnRate == 12_000,
          lesson.followBot.maximumDeltaTurnRate == 16_000,
          lesson.followBot.circleDistance == 25,
          level.paths.indices.contains(lesson.followPathIndex),
          level.paths.indices.contains(lesson.destroyPathIndex),
          pathsSHA256
            == "56997a7e05b017a65778bd48badf453f72bdf5f3f34d60fbd1d6cd8b4fdcdbe5"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Scripts 021-026 stock package"
        )
    }
    if let handoff = lesson.destructionHandoff {
        try validateStockTrainingFollowBotDestructionHandoff(
            handoff,
            lesson: lesson,
            level: level
        )
    }
}

func validateStockTrainingFollowBotDestructionHandoff(
    _ handoff: TrainingFollowBotDestructionHandoff,
    lesson: TrainingManeuverFollowLesson,
    level: Level
) throws {
    try validateTrainingFollowBotDestructionHandoff(
        handoff,
        lesson: lesson,
        level: level
    )
    let followBot = level.objects.first {
        $0.handle == handoff.followBotObjectHandle
    }
    let destroyBot2 = level.objects.first {
        $0.handle == handoff.destroyBot2ObjectHandle
    }
    let destroyBot1 = level.objects.first {
        $0.handle == handoff.destroyBot1ObjectHandle
    }
    let destroyBot2Presentation = level.objectPresentations.first {
        $0.objectHandle == handoff.destroyBot2ObjectHandle
    }
    let destroyBot1Presentation = level.objectPresentations.first {
        $0.objectHandle == handoff.destroyBot1ObjectHandle
    }
    let projectileModel = level.models.first {
        $0.source == handoff.projectileModel
    }
    let voice = level.voiceClips.first {
        $0.sourceName == handoff.voiceSourceName
    }
    guard handoff.followBotObjectHandle
            == lesson.followBotObjectHandle,
          handoff.destroyBot2ObjectHandle == 4_112,
          handoff.destroyBot1ObjectHandle == 4_113,
          handoff.combat == .stockTraining,
          handoff.projectileModel.sourceName
            .caseInsensitiveCompare("bluelaser.OOF")
            == .orderedSame,
          handoff.destructionDelay == 2,
          handoff.levelTimerID == 11,
          handoff.movingTeamFlags == 65_536,
          handoff.movingPathIndex == lesson.followPathIndex,
          handoff.movingPathGoalFlags == 8_392_960,
          handoff.goalID == -1,
          handoff.goalPriority == 3,
          handoff.successMessage == "Excellent!",
          handoff.movingInstruction
            == "Now destroy 2 more robots. This time they will be moving.",
          handoff.voiceSourceName == "kill1.osf",
          followBot?.handle == 8_200,
          followBot?.storedID == 106,
          followBot?.location == .room(37),
          destroyBot2?.type == 2,
          destroyBot2?.storedID == 106,
          destroyBot2?.definition?.sourceName
            == "RAS1 Light Security Flyer",
          destroyBot2?.instanceName == "DestroyBot2",
          destroyBot2?.flags == 5_121,
          destroyBot2?.location == .room(37),
          destroyBot2?.position
            == .init(
                x: 2_121.0835,
                y: -787.4891,
                z: 2_556.6667
            ),
          destroyBot2?.orientation
            == .init(
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
          destroyBot1?.type == 2,
          destroyBot1?.storedID == 106,
          destroyBot1?.definition?.sourceName
            == "RAS1 Light Security Flyer",
          destroyBot1?.instanceName == "DestroyBot1",
          destroyBot1?.flags == 5_121,
          destroyBot1?.location == .room(37),
          destroyBot1?.position
            == .init(
                x: 1_998.6289,
                y: -789.663_15,
                z: 2_556.2332
            ),
          destroyBot1?.orientation
            == .init(
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
          destroyBot2Presentation?.primaryModel
            == lesson.followBot.model,
          destroyBot2Presentation?.isVisible == false,
          destroyBot1Presentation?.primaryModel
            == lesson.followBot.model,
          destroyBot1Presentation?.isVisible == false,
          projectileModel?.sourceArchive == "d3.hog",
          projectileModel?.collisionRadius == 4.920_813,
          projectileModel?.sourceSHA256
            == "717a9a2ac254eba76c7992fc834e3a5bc3992f86674af972afd9cf0c2967b31b",
          voice?.sourceEntryIndex == 17,
          voice?.sampleRate == 22_050,
          voice?.channelCount == 1,
          voice?.frameCount == 172_565,
          voice?.pcm16LittleEndian.count
            == (voice?.frameCount ?? -1) * 2,
          voice?.pcmSHA256
            == "0b1eae26d812929a08faa05efde07926dc4a96ac3873320b6f39805f69877b06",
          voice?.sourceArchive == "missions/training.mn3",
          voice?.sourceSHA256
            == "d2ea757ac472b40781ce62a7dbd45649e3abce3f4884edf1303048e3cf36be7e"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Scripts 031,037,027 stock package"
        )
    }
}

func validateTrainingFollowBotDestructionHandoff(
    _ handoff: TrainingFollowBotDestructionHandoff,
    lesson: TrainingManeuverFollowLesson,
    level: Level
) throws {
    let handles = [
        handoff.followBotObjectHandle,
        handoff.destroyBot2ObjectHandle,
        handoff.destroyBot1ObjectHandle,
    ]
    let objectsByHandle = Dictionary(
        uniqueKeysWithValues: level.objects.map {
            ($0.handle, $0)
        }
    )
    let presentationsByHandle = Dictionary(
        uniqueKeysWithValues: level.objectPresentations.map {
            ($0.objectHandle, $0)
        }
    )
    guard Set(handles).count == handles.count,
          handoff.followBotObjectHandle
            == lesson.followBotObjectHandle,
          handles.allSatisfy({ objectsByHandle[$0] != nil }),
          handles.allSatisfy({
              presentationsByHandle[$0]?.primaryModel
                == lesson.followBot.model
          }),
          presentationsByHandle[
            handoff.destroyBot2ObjectHandle
          ]?.isVisible == false,
          presentationsByHandle[
            handoff.destroyBot1ObjectHandle
          ]?.isVisible == false,
          handoff.combat == .stockTraining,
          level.models.contains(where: {
              $0.source == handoff.projectileModel
          }),
          handoff.projectileModel.sourceName
            .caseInsensitiveCompare("bluelaser.OOF")
            == .orderedSame,
          handoff.destructionDelay == 2,
          handoff.levelTimerID == 11,
          handoff.movingTeamFlags == 65_536,
          handoff.movingPathIndex == lesson.followPathIndex,
          level.paths.indices.contains(
            handoff.movingPathIndex
          ),
          handoff.movingPathGoalFlags == 8_392_960,
          handoff.goalID == -1,
          handoff.goalPriority == 3,
          handoff.successMessage == "Excellent!",
          handoff.movingInstruction
            == "Now destroy 2 more robots. This time they will be moving.",
          handoff.voiceSourceName == "kill1.osf",
          level.voiceClips.contains(where: {
              $0.sourceName.caseInsensitiveCompare(
                  handoff.voiceSourceName
              ) == .orderedSame
          })
    else {
        throw LevelValidationError.invalidDependency(
            "Training Scripts 031,037,027 handoff"
        )
    }
}

func validateStockTrainingFinalRoomEntryPackage(
    chain: TrainingFinalRoomEntryChain?,
    intro7: CanonicalVoiceClip?
) throws {
    guard let chain,
        chain.triggerName == "Portal4",
        chain.triggerRoomSourceIndex == 44,
        chain.triggerFaceIndex == 1,
        chain.successMessage == "Excellent!",
        chain.instructionMessage
            == "Now for your final and most difficult task. Locate and destroy the last 5 robots.",
        chain.voiceSourceName == "intro7.osf",
        intro7?.sourceName.caseInsensitiveCompare("intro7.osf")
            == .orderedSame,
        intro7?.sourceEntryIndex == 16,
        intro7?.sampleRate == 22_050,
        intro7?.channelCount == 1,
        intro7?.frameCount == 469_201,
        intro7?.pcmSHA256
            == "381ce960f6a266b1014cdcfdfc2cc3607a053d3c4b062215e5512127e7bd2711",
        intro7?.sourceArchive == "missions/training.mn3",
        intro7?.sourceSHA256
            == "7348ded9ee2c6735ea712b52647f0bfa7478a508c03c10af5f837741a836c67f"
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 050 package"
        )
    }
}

func validateStockTrainingFinalBotsCompletionPackage(
    chain: TrainingFinalBotsCompletionChain?,
    done: CanonicalVoiceClip?,
    level: Level,
    requiresExactVoice: Bool = true
) throws {
    let expectedPresentation = TrainingMarkerLightPresentation(
        primaryColor: .init(x: 1, y: 0.25, z: 0),
        secondaryColor: .zero,
        timeInterval: 0.5,
        flickerDistance: 0.2,
        directionalDot: 0,
        flags: 4,
        timebits: .max,
        angle: 0,
        lightingRenderType: 2
    )
    guard let chain,
          chain.barrierRoomSourceIndex == 16,
          chain.orderedPortalIndices == [0, 1],
          chain.markerLightObjectHandle == 4_118,
          chain.markerLightPresentation == expectedPresentation,
          chain.openMarkerLightDistance == 50,
          chain.timerDuration == 2,
          chain.completionMessage
            == "Great Job! Now fly through the opened doorway to end your training. Good job Recruit!",
          chain.completionVoiceSourceName == "done.osf",
          level.trainingLastBot1DeathChain != nil,
          level.trainingLastBot2DeathChain != nil,
          level.trainingLastBot3DeathChain != nil,
          level.trainingLastBot4DeathChain != nil,
          level.trainingLastBot5DeathChain != nil,
          let room = level.rooms.first(where: {
              $0.sourceIndex == chain.barrierRoomSourceIndex
          }),
          room.name == "PortalRoom7",
          chain.orderedPortalIndices.allSatisfy(
              room.portals.indices.contains
          ),
          let marker = level.objects.first(where: {
              $0.handle == chain.markerLightObjectHandle
          }),
          marker.type == 11,
          marker.storedID == 205,
          marker.definition?.sourceName == "Blinking Red Light-DM",
          marker.instanceName == "FlashLight-5",
          marker.flags == 4_096,
          marker.location == .room(16),
          done?.sourceName.caseInsensitiveCompare("done.osf")
            == .orderedSame,
          done?.sampleRate == 22_050,
          done?.channelCount == 1,
          done?.sourceArchive == "missions/training.mn3",
          !requiresExactVoice || (
              done?.sourceEntryIndex == 2
                  && done?.frameCount == 234_609
                  && done?.pcmSHA256
                    == "87efaee428868cf09d74ae72ded48f91ce6f9db55ee823c82fcbf37c07487953"
                  && done?.sourceSHA256
                    == "a14ce32c2b72fb222c9dfdfdbc277b062ebbb6774e5757c4fe1602b87630383c"
          ),
          chain.orderedPortalIndices.allSatisfy({ portalIndex in
              let portal = room.portals[portalIndex]
              guard portal.flags & 1 != 0,
                    let connected = level.rooms.first(where: {
                        $0.sourceIndex == portal.connectedRoom
                    }),
                    connected.portals.indices.contains(
                        portal.connectedPortal
                    )
              else {
                  return false
              }
              let reciprocal =
                  connected.portals[portal.connectedPortal]
              return reciprocal.connectedRoom == room.sourceIndex
                  && reciprocal.connectedPortal == portalIndex
                  && reciprocal.flags & 1 != 0
          })
    else {
        throw LevelValidationError.invalidDependency(
            "Training Scripts 035/056 completion"
        )
    }
}

func validateStockTrainingFinalGoalPackage(
    chain: TrainingFinalGoalChain?,
    level: Level
) throws {
    guard let chain,
          chain.goalObjectHandle == 6_180,
          chain.goalRoomSourceIndex == 17,
          chain.goalObjectFlags == 4_096,
          chain.goalCollisionRadius.bitPattern == 0x40a0_84bf,
          level.trainingFinalBotsCompletionChain != nil,
          let goal = level.objects.first(where: {
              $0.handle == chain.goalObjectHandle
          }),
          goal.type == 7,
          goal.storedID == 67,
          goal.definition?.storedIndex == 67,
          goal.definition?.sourceName == "Invisiblepowerup",
          goal.definition?.referenceRuntimeIndex == nil
            || goal.definition?.referenceRuntimeIndex == 68,
          goal.instanceName == "FinalGoal",
          goal.flags == chain.goalObjectFlags,
          goal.location == .room(chain.goalRoomSourceIndex),
          let presentation = level.objectPresentations.first(where: {
              $0.objectHandle == chain.goalObjectHandle
          }),
          presentation.primaryModel.sourceName
            .caseInsensitiveCompare("invisiblepowerup.OOF")
                == .orderedSame,
          presentation.mediumModel == nil,
          presentation.lowModel == nil,
          presentation.dyingModel == nil,
          presentation.mediumDistance == nil,
          presentation.lowDistance == nil,
          !presentation.isVisible,
          let model = level.models.first(where: {
              $0.source == presentation.primaryModel
          }),
          model.collisionRadius == chain.goalCollisionRadius,
          level.rooms.contains(where: {
              $0.sourceIndex == chain.goalRoomSourceIndex
          })
    else {
        throw LevelValidationError.invalidDependency(
            "Training Script 057 FinalGoal chain"
        )
    }
}

func validateStockTrainingRobotGuidebotPresentation(
    chain: TrainingRobotGuidebotChain,
    modelSources: [SourceResource],
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference],
    destroyRobotIsInitiallyVisible: Bool = true
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
                    == destroyRobotIsInitiallyVisible
          }) else {
        throw LevelValidationError.invalidDependency(
            "Training robot and Guidebot presentation"
        )
    }
}

func validateTrainingGuidebotYellowFlareAnimationBinding(
    timeout: TrainingGuidebotYellowFlareTimeoutDefinition?,
    materials: [PresentationMaterial],
    dependencies: [DependencyRecord]
) throws {
    guard let timeout else { return }
    let dependencyIdentities = Set(dependencies.map {
        DependencyIdentity(category: $0.category, source: $0.source)
    })
    guard timeout.hasCoherentChildAnimationBinding else {
        throw LevelValidationError.invalidDependency(
            "Training Guidebot Yellow flare animation binding"
        )
    }
    guard let frames = timeout.childAnimationFrames else { return }
    guard frames.allSatisfy({ frame in
        materials.first { $0.texture == frame }.map {
            $0.bitmapSourceName == "yellowspark.oaf"
                && $0.sourceArchive == "d3.hog"
                && $0.sourceSHA256
                    == "eabf95db1e5c17235b65a7b938081d40e44736456112acbc4a1ff99126051194"
        } == true
            && dependencyIdentities.contains(.init(
                category: "texture",
                source: frame
            ))
    }) else {
        throw LevelValidationError.invalidDependency(
            "Training Guidebot Yellow flare animation binding"
        )
    }
}

func validateTrainingGuidebotYellowFlareBinding(
    chain: TrainingRobotGuidebotChain,
    models: [CanonicalModel],
    materials: [PresentationMaterial],
    sounds: [CanonicalSoundClip],
    dependencies: [DependencyRecord]
) throws {
    guard let flare = chain.yellowFlare else { return }
    try validateTrainingGuidebotYellowFlareAnimationBinding(
        timeout: flare.timeout,
        materials: materials,
        dependencies: dependencies
    )
    let exactMaterialHashes = [
        "energy":
            "5c6e2eb6cde4b1592f4ff8bc9540ab858655da77607e07328db8cd12cfd7376f",
        "YellowFlareCorona":
            "4944668e9096eb632ae8716061946c2d558a86da4ffb5fdd493d5ea260c95cbe",
        "FlarePuff":
            "9416910ac344a0e3a9dd35ef596300147b7014972c73974a88546351ca92835c",
        "FlarePuffAlt":
            "8ad50ce9c0f198d49d1131ffd4c0a15df80c01c20105bf89094bc715f57a21f7",
        "yellowspark":
            "eabf95db1e5c17235b65a7b938081d40e44736456112acbc4a1ff99126051194",
    ]
    let materialsByName = Dictionary(
        grouping: materials,
        by: { $0.texture.sourceName }
    )
    let model = models.first { $0.source == flare.model }
    let modelTextures = Set(model?.submodels.flatMap { submodel in
        submodel.faces.compactMap { face -> String? in
            guard case let .texture(texture) = face.material else {
                return nil
            }
            return texture.sourceName
        }
    } ?? [])
    let sound = sounds.first {
        $0.sourceName == flare.fireSoundSourceName
    }
    let soundDependency = sound.map {
        DependencyIdentity(
            category: "sound",
            source: .init(
                storedIndex: $0.sourceEntryIndex,
                sourceName: $0.sourceName
            )
        )
    }
    let dependencyIdentities = Set(dependencies.map {
        DependencyIdentity(category: $0.category, source: $0.source)
    })
    guard model?.source.sourceName == "FlareYellowBright.OOF",
          model?.collisionRadius.bitPattern == 0x405f_d5ea,
          model?.submodels.count == 4,
          model?.submodels.map(\.presentation)
            == [.standard, .facing, .facing, .facing],
          model?.sourceArchive == "d3.hog",
          model?.sourceSHA256
            == "fa0f92ba8d3ea0d348766c2cf56897935a0a1afe211378729b5781d773fb9ed4",
          modelTextures
            == Set(["energy", "YellowFlareCorona", "FlarePuff", "FlarePuffAlt"]),
          exactMaterialHashes.allSatisfy({ name, hash in
              materialsByName[name]?.count == 1
                  && materialsByName[name]?.first?.sourceArchive == "d3.hog"
                  && materialsByName[name]?.first?.sourceSHA256 == hash
          }),
          materialsByName["yellowspark"]?.count == 1,
          materialsByName["yellowspark"]?.first?.texture
            == flare.particleTexture,
          sound?.sourceEntryIndex == 1_158,
          sound?.pcmSHA256
            == "98aa8dc4652268a3f512c995dcc8cc3f6ef3abe62947f839167bd809f9423452",
          dependencyIdentities.contains(.init(
              category: "weapon-definition",
              source: flare.source
          )),
          dependencyIdentities.contains(.init(
              category: "model",
              source: flare.model
          )),
          dependencyIdentities.contains(.init(
              category: "texture",
              source: flare.particleTexture
          )),
          soundDependency.map(dependencyIdentities.contains) == true else {
        throw LevelValidationError.invalidDependency(
            "Training Guidebot Yellow flare binding"
        )
    }
}

private func validateStockTrainingRASBotDeathPackage(
    chain: TrainingRobotDeathChain?,
    expectedHandle: UInt32,
    expectedRoomSourceIndex: Int,
    expectedInstanceName: String,
    dependencyName: String,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    let gyroModels = Set(
        objectPresentations.compactMap { presentation in
            presentation.primaryModel.sourceName.caseInsensitiveCompare(
                "gyro.oof"
            ) == .orderedSame
                ? presentation.primaryModel
                : nil
        }
    )
    guard let chain,
          chain.robotObjectHandle == expectedHandle,
          chain.robotRoomSourceIndex == expectedRoomSourceIndex,
          chain.robotFlags == 5_121,
          chain.combat == .stockTraining,
          gyroModels.count == 1,
          objects.contains(where: {
              $0.handle == chain.robotObjectHandle
                  && $0.type == 2
                  && $0.storedID == 106
                  && $0.definition?.sourceName
                    == "RAS1 Light Security Flyer"
                  && $0.instanceName == expectedInstanceName
                  && $0.flags == chain.robotFlags
                  && $0.location == .room(chain.robotRoomSourceIndex)
          }),
          objectPresentations.contains(where: {
              $0.objectHandle == chain.robotObjectHandle
                  && $0.primaryModel == gyroModels.first
                  && $0.mediumModel == nil
                  && $0.lowModel == nil
                  && $0.dyingModel == nil
                  && $0.mediumDistance == nil
                  && $0.lowDistance == nil
                  && $0.isVisible
          }) else {
        throw LevelValidationError.invalidDependency(dependencyName)
    }
}

func validateStockTrainingRASBot1DeathPackage(
    chain: TrainingRASBot1DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_074,
        expectedRoomSourceIndex: 11,
        expectedInstanceName: "RASBot1",
        dependencyName: "Training RASBot1 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingRASBot2DeathPackage(
    chain: TrainingRASBot2DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_075,
        expectedRoomSourceIndex: 12,
        expectedInstanceName: "RASBot2",
        dependencyName: "Training RASBot2 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingRASBot3DeathPackage(
    chain: TrainingRASBot3DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_077,
        expectedRoomSourceIndex: 42,
        expectedInstanceName: "RASBot3",
        dependencyName: "Training RASBot3 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingRASBot4DeathPackage(
    chain: TrainingRASBot4DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_078,
        expectedRoomSourceIndex: 0,
        expectedInstanceName: "RASBot4",
        dependencyName: "Training RASBot4 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingLastBot1DeathPackage(
    chain: TrainingLastBot1DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 4_127,
        expectedRoomSourceIndex: 14,
        expectedInstanceName: "LastBot1",
        dependencyName: "Training LastBot1 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingLastBot2DeathPackage(
    chain: TrainingLastBot2DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_080,
        expectedRoomSourceIndex: 46,
        expectedInstanceName: "LastBot2",
        dependencyName: "Training LastBot2 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingLastBot3DeathPackage(
    chain: TrainingLastBot3DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_081,
        expectedRoomSourceIndex: 47,
        expectedInstanceName: "LastBot3",
        dependencyName: "Training LastBot3 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingLastBot4DeathPackage(
    chain: TrainingLastBot4DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_082,
        expectedRoomSourceIndex: 47,
        expectedInstanceName: "LastBot4",
        dependencyName: "Training LastBot4 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
}

func validateStockTrainingLastBot5DeathPackage(
    chain: TrainingLastBot5DeathChain?,
    objects: [PlacedObject],
    objectPresentations: [ObjectPresentationReference]
) throws {
    try validateStockTrainingRASBotDeathPackage(
        chain: chain,
        expectedHandle: 2_083,
        expectedRoomSourceIndex: 48,
        expectedInstanceName: "LastBot5",
        dependencyName: "Training LastBot5 package",
        objects: objects,
        objectPresentations: objectPresentations
    )
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
    proceed6: CanonicalVoiceClip? = nil,
    intro6: CanonicalVoiceClip? = nil,
    guidebotF: CanonicalVoiceClip? = nil,
    pickupSound: CanonicalSoundClip?,
    returnSound: CanonicalSoundClip? = nil,
    greetingSound: CanonicalSoundClip? = nil,
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
                barrierRoomSourceIndex: 40,
                orderedPortalIndices: [0, 1],
                openMarkerLightDistance: 50,
                returnMessage: "GB: Returning to ship.",
                returnSoundSourceName: "GBotAcceptOrder.wav",
                greetingSoundSourceName:
                    chain.returnToShip?.greetingSoundSourceName,
                arrivalMessage: "GB: Entering ship!",
                successMessage: "Excellent!",
                successVoiceSourceName: "proceed6.osf",
                killbotEntry: .init(
                    triggerName: "Portal3",
                    triggerRoomSourceIndex: 40,
                    triggerFaceIndex: 1,
                    orderedPortalIndices: [1, 0],
                    closedMarkerLightDistance: 0,
                    entryMessage:
                        "Now you are on your own in this room. There are 4 robots and 2 powerups. Get the powerups and kill the robots.",
                    entryVoiceSourceName: "intro6.osf",
                    followupDelay: 13,
                    followupMessage:
                        "Some parts of this area are very dark.  Turn on your headlight or fire flares to see.  Use your guidebot if you need help finding a robot or powerup.",
                    followupVoiceSourceName: "guidebotf.osf"
                )
            )
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
          proceed6?.sourceEntryIndex == 26,
          proceed6?.sampleRate == 22_050,
          proceed6?.channelCount == 1,
          proceed6?.frameCount == 141_237,
          proceed6?.pcmSHA256
            == "ccc21ee44f4e965806904dfbd4aa95be1510e8cbe633ab43f0808b7f3026b06d",
          proceed6?.sourceArchive == "missions/training.mn3",
          proceed6?.sourceSHA256
            == "b3cd5455401af0f387d8cde20c3c869897aef55070cf8cfadd141c0f291bc403",
          intro6?.sourceName == "intro6.osf",
          intro6?.sourceEntryIndex == 15,
          intro6?.sampleRate == 22_050,
          intro6?.channelCount == 1,
          intro6?.frameCount == 212_125,
          intro6?.pcmSHA256
            == "5ee0e98d12a0648b8ce0e239ff5df36da37b4e9d6634a846d6a91fa849a1cf79",
          intro6?.sourceArchive == "missions/training.mn3",
          intro6?.sourceSHA256
            == "e8e955dd608942543f5442d1c187018286ea060fcc7440a4e180df24e602fc4a",
          guidebotF?.sourceName == "guidebotf.osf",
          guidebotF?.sourceEntryIndex == 9,
          guidebotF?.sampleRate == 22_050,
          guidebotF?.channelCount == 1,
          guidebotF?.frameCount == 91_221,
          guidebotF?.pcmSHA256
            == "244adc2baaeab1ccdf69a676a4b7cb5b81561db53a1fce1f50bd9b899c077c49",
          guidebotF?.sourceArchive == "missions/training.mn3",
          guidebotF?.sourceSHA256
            == "bc15f7be1b1a9203d1fbc264649d9d8b23d24daf522df70c9460e9007904e2f2",
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
          returnSound?.logicalName == "GBotAcceptOrder1",
          returnSound?.sourceName == "GBotAcceptOrder.wav",
          returnSound?.sourceEntryIndex == 1_257,
          returnSound?.sampleRate == 22_050,
          returnSound?.channelCount == 1,
          returnSound?.frameCount == 21_652,
          returnSound?.pcmSHA256
            == "d1d068fbd7950adeaffe5a2cf3c6c56b59d488f9c53b3460f88adfb7178183b1",
          returnSound?.sourceArchive == "d3.hog",
          returnSound?.sourceSHA256
            == "47e38dfcb285be1b8d19d59929fef1b1122c1772a0cca2e6fe2b1721e5876b17",
          returnSound?.importVolume == 0.45,
          (
              chain.returnToShip?.greetingSoundSourceName == nil
                  && greetingSound == nil
              || chain.returnToShip?.greetingSoundSourceName
                    == "GBotGreetB.wav"
                  && greetingSound?.logicalName == "GBotGreetB1"
                  && greetingSound?.sourceName == "GBotGreetB.wav"
                  && greetingSound?.sourceEntryIndex == 1_268
                  && greetingSound?.sampleRate == 22_050
                  && greetingSound?.channelCount == 1
                  && greetingSound?.frameCount == 16_046
                  && greetingSound?.pcmSHA256
                    == "ec585e440bb7cc07550cd9402b6b1dc69831dd00ade8052572a5cb2383fcb2fe"
                  && greetingSound?.sourceArchive == "d3.hog"
                  && greetingSound?.sourceSHA256
                    == "5e2aee56e77e39592295759705671c37259ff8ca8cc9357ebac1bb38d7c004ca"
                  && greetingSound?.importVolume == 1
          ),
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
          objects.contains(where: {
              $0.handle == 10_245
                  && $0.type == 11
                  && $0.storedID == 205
                  && $0.definition?.sourceName == "Blinking Red Light-DM"
                  && $0.instanceName == "FlashLight-3"
                  && $0.location == .room(40)
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
    var trainingDodgeAttempt: TrainingDodgeAttempt? = nil
    let trainingGalleryBarrier: TrainingGalleryBarrier?
    let trainingRobotGuidebotChain: TrainingRobotGuidebotChain?
    let trainingCameraMonitorChain: TrainingCameraMonitorChain?
    let trainingRASBot1DeathChain: TrainingRASBot1DeathChain?
    let trainingRASBot2DeathChain: TrainingRASBot2DeathChain?
    let trainingRASBot3DeathChain: TrainingRASBot3DeathChain?
    let trainingRASBot4DeathChain: TrainingRASBot4DeathChain?
    let trainingLastBot1DeathChain: TrainingLastBot1DeathChain?
    var trainingLastBot2DeathChain: TrainingLastBot2DeathChain? = nil
    var trainingLastBot3DeathChain: TrainingLastBot3DeathChain? = nil
    var trainingLastBot4DeathChain: TrainingLastBot4DeathChain? = nil
    var trainingLastBot5DeathChain: TrainingLastBot5DeathChain? = nil
    var trainingFinalBotsCompletionChain:
        TrainingFinalBotsCompletionChain? = nil
    var trainingFinalGoalChain: TrainingFinalGoalChain? = nil
    let trainingInvulnerabilityPickupChain: TrainingInvulnerabilityPickupChain?
    let trainingCloakPickupChain: TrainingCloakPickupChain?
    let trainingLastRoomChain: TrainingLastRoomChain?
    let trainingFinalRoomEntryChain: TrainingFinalRoomEntryChain?
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
        trainingDodgeAttempt: TrainingDodgeAttempt? = nil,
        trainingGalleryBarrier: TrainingGalleryBarrier? = nil,
        trainingRobotGuidebotChain: TrainingRobotGuidebotChain? = nil,
        trainingCameraMonitorChain: TrainingCameraMonitorChain? = nil,
        trainingRASBot1DeathChain: TrainingRASBot1DeathChain? = nil,
        trainingRASBot2DeathChain: TrainingRASBot2DeathChain? = nil,
        trainingRASBot3DeathChain: TrainingRASBot3DeathChain? = nil,
        trainingRASBot4DeathChain: TrainingRASBot4DeathChain? = nil,
        trainingLastBot1DeathChain: TrainingLastBot1DeathChain? = nil,
        trainingInvulnerabilityPickupChain:
            TrainingInvulnerabilityPickupChain? = nil,
        trainingCloakPickupChain: TrainingCloakPickupChain? = nil,
        trainingLastRoomChain: TrainingLastRoomChain? = nil,
        trainingFinalRoomEntryChain: TrainingFinalRoomEntryChain? = nil,
        trainingFinalBotsCompletionChain:
            TrainingFinalBotsCompletionChain? = nil,
        trainingFinalGoalChain: TrainingFinalGoalChain? = nil,
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
        self.trainingDodgeAttempt = trainingDodgeAttempt
        self.trainingGalleryBarrier = trainingGalleryBarrier
        self.trainingRobotGuidebotChain = trainingRobotGuidebotChain
        self.trainingCameraMonitorChain = trainingCameraMonitorChain
        self.trainingRASBot1DeathChain = trainingRASBot1DeathChain
        self.trainingRASBot2DeathChain = trainingRASBot2DeathChain
        self.trainingRASBot3DeathChain = trainingRASBot3DeathChain
        self.trainingRASBot4DeathChain = trainingRASBot4DeathChain
        self.trainingLastBot1DeathChain = trainingLastBot1DeathChain
        self.trainingInvulnerabilityPickupChain =
            trainingInvulnerabilityPickupChain
        self.trainingCloakPickupChain = trainingCloakPickupChain
        self.trainingLastRoomChain = trainingLastRoomChain
        self.trainingFinalRoomEntryChain = trainingFinalRoomEntryChain
        self.trainingFinalBotsCompletionChain =
            trainingFinalBotsCompletionChain
        self.trainingFinalGoalChain = trainingFinalGoalChain
        self.voiceClips = voiceClips
        self.soundClips = soundClips
        self.dependencyManifest = dependencyManifest
        self.sourceChunks = sourceChunks
    }

    func validate() throws {
        try validate(
            allowImportStagingPresentation: false,
            enforceStockSourceInvariants: true
        )
    }

    func validateForAuthoring() throws {
        try validate(
            allowImportStagingPresentation: false,
            enforceStockSourceInvariants: false
        )
    }

    func validateForImportStaging() throws {
        try validate(
            allowImportStagingPresentation: true,
            enforceStockSourceInvariants: true
        )
    }

    private func validate(
        allowImportStagingPresentation: Bool,
        enforceStockSourceInvariants: Bool
    ) throws {
        guard (
            schemaVersion == 9
                && trainingCameraMonitorChain == nil
                && trainingRASBot1DeathChain == nil
                && trainingRASBot2DeathChain == nil
                && trainingRASBot3DeathChain == nil
                && trainingRASBot4DeathChain == nil
                && trainingLastBot1DeathChain == nil
                && trainingLastBot2DeathChain == nil
                && trainingLastBot3DeathChain == nil
                && trainingLastBot4DeathChain == nil
                && trainingLastBot5DeathChain == nil
                && trainingFinalBotsCompletionChain == nil
            || schemaVersion == 10
                && trainingCameraMonitorChain != nil
                && trainingRASBot1DeathChain == nil
                && trainingRASBot2DeathChain == nil
                && trainingRASBot3DeathChain == nil
                && trainingRASBot4DeathChain == nil
                && trainingLastBot1DeathChain == nil
                && trainingLastBot2DeathChain == nil
                && trainingLastBot3DeathChain == nil
                && trainingLastBot4DeathChain == nil
                && trainingLastBot5DeathChain == nil
                && trainingFinalBotsCompletionChain == nil
                && _soundClips.wasPresent
            || schemaVersion == 11
                && trainingCameraMonitorChain != nil
                && trainingRASBot1DeathChain != nil
                && _soundClips.wasPresent
        ),
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
            dynamicallyPresentedModelNames: (
                trainingRobotGuidebotChain == nil
                    ? []
                    : ["Buddybot.oof"])
                + (trainingDodgeAttempt.map {
                    [$0.turret.projectileModel.sourceName]
                } ?? [])
                + (trainingDodgeAttempt?.maneuverFollow?
                    .destructionHandoff.map {
                        [$0.projectileModel.sourceName]
                    } ?? [])
                + (trainingRobotGuidebotChain?.yellowFlare.map {
                    [$0.model.sourceName]
                } ?? [])
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
            if let returnLeft = lesson.returnLeft {
                guard returnLeft.collisionRadius.isFinite,
                      returnLeft.collisionRadius > 0,
                      isNonempty(returnLeft.instruction),
                      isNonempty(returnLeft.voiceSourceName),
                      let target = objects.first(where: {
                          $0.handle == returnLeft.startGoalObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      returnLeft.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      clipNames.contains(
                          returnLeft.voiceSourceName.lowercased()
                      ) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 003 return-left lesson"
                    )
                }
            }
            if let returnRight = lesson.returnRight {
                guard returnRight.collisionRadius.isFinite,
                      returnRight.collisionRadius > 0,
                      isNonempty(returnRight.successMessage),
                      isNonempty(returnRight.instruction),
                      isNonempty(returnRight.voiceSourceName),
                      lesson.returnLeft != nil,
                      let target = objects.first(where: {
                          $0.handle == returnRight.leftGoalObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      returnRight.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      clipNames.contains(
                          returnRight.voiceSourceName.lowercased()
                      ) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 004 return-right lesson"
                    )
                }
            }
            if let returnUp = lesson.returnUp {
                guard returnUp.collisionRadius.isFinite,
                      returnUp.collisionRadius > 0,
                      isNonempty(returnUp.successMessage),
                      isNonempty(returnUp.instruction),
                      isNonempty(returnUp.voiceSourceName),
                      lesson.returnRight != nil,
                      let target = objects.first(where: {
                          $0.handle == returnUp.startGoalObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      returnUp.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      clipNames.contains(
                          returnUp.voiceSourceName.lowercased()
                      ) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 005 return-up lesson"
                    )
                }
            }
            if let returnDown = lesson.returnDown {
                guard returnDown.collisionRadius.isFinite,
                      returnDown.collisionRadius > 0,
                      isNonempty(returnDown.successMessage),
                      isNonempty(returnDown.instruction),
                      isNonempty(returnDown.voiceSourceName),
                      let target = objects.first(where: {
                          $0.handle == returnDown.upGoalObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      returnDown.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      clipNames.contains(
                          returnDown.voiceSourceName.lowercased()
                      ) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 006 return-down lesson"
                    )
                }
            }
            if let repeatForward = lesson.repeatForward {
                guard repeatForward.collisionRadius.isFinite,
                      repeatForward.collisionRadius > 0,
                      isNonempty(repeatForward.successMessage),
                      isNonempty(repeatForward.repeatMessage),
                      isNonempty(repeatForward.forwardInstruction),
                      isNonempty(repeatForward.voiceSourceName),
                      lesson.returnDown != nil,
                      let target = objects.first(where: {
                          $0.handle == repeatForward.startGoalObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      repeatForward.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      clipNames.contains(
                          repeatForward.voiceSourceName.lowercased()
                      ) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 007 repeat-forward lesson"
                    )
                }
            }
            if let repeatForwardGoal = lesson.repeatForwardGoal {
                let soundNames = Set(soundClips.flatMap {
                    [$0.logicalName.lowercased(), $0.sourceName.lowercased()]
                })
                guard repeatForwardGoal.collisionRadius.isFinite,
                      repeatForwardGoal.collisionRadius > 0,
                      isNonempty(repeatForwardGoal.reverseInstruction),
                      isNonempty(repeatForwardGoal.soundLogicalName),
                      lesson.repeatForward != nil,
                      let target = objects.first(where: {
                          $0.handle
                            == repeatForwardGoal.forwardGoalObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      repeatForwardGoal.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      soundNames.contains(
                          repeatForwardGoal.soundLogicalName.lowercased()
                      ) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 008 repeat-ForwardGoal lesson"
                    )
                }
            }
            if let repeatReturnLeft = lesson.repeatReturnLeft {
                guard repeatReturnLeft.collisionRadius.isFinite,
                      repeatReturnLeft.collisionRadius > 0,
                      isNonempty(repeatReturnLeft.instruction),
                      isNonempty(repeatReturnLeft.voiceSourceName),
                      lesson.repeatForwardGoal != nil,
                      let repeatForward = lesson.repeatForward,
                      repeatReturnLeft.startGoalObjectHandle
                        == repeatForward.startGoalObjectHandle,
                      repeatReturnLeft.collisionRadius
                        == repeatForward.collisionRadius,
                      let target = objects.first(where: {
                          $0.handle
                            == repeatReturnLeft.startGoalObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      repeatReturnLeft.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      clipNames.contains(
                          repeatReturnLeft.voiceSourceName.lowercased()
                      ) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 009 repeat-return-left lesson"
                    )
                }
            }
            if let repeatReturnRight = lesson.repeatReturnRight {
                let soundNames = Set(soundClips.flatMap {
                    [$0.logicalName.lowercased(), $0.sourceName.lowercased()]
                })
                guard repeatReturnRight.collisionRadius.isFinite,
                      repeatReturnRight.collisionRadius > 0,
                      isNonempty(repeatReturnRight.instruction),
                      isNonempty(repeatReturnRight.soundLogicalName),
                      lesson.repeatReturnLeft != nil,
                      let returnRight = lesson.returnRight,
                      repeatReturnRight.leftGoalObjectHandle
                        == returnRight.leftGoalObjectHandle,
                      repeatReturnRight.collisionRadius
                        == returnRight.collisionRadius,
                      let target = objects.first(where: {
                          $0.handle
                            == repeatReturnRight.leftGoalObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      repeatReturnRight.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      soundNames.contains(
                          repeatReturnRight.soundLogicalName.lowercased()
                      ) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 010 repeat-return-right lesson"
                    )
                }
            }
            if let repeatReturnUp = lesson.repeatReturnUp {
                guard repeatReturnUp.collisionRadius.isFinite,
                      repeatReturnUp.collisionRadius > 0,
                      isNonempty(repeatReturnUp.instruction),
                      isNonempty(repeatReturnUp.voiceSourceName),
                      lesson.repeatReturnRight != nil,
                      let returnUp = lesson.returnUp,
                      repeatReturnUp.startGoalObjectHandle
                        == returnUp.startGoalObjectHandle,
                      repeatReturnUp.collisionRadius
                        == returnUp.collisionRadius,
                      let target = objects.first(where: {
                          $0.handle
                            == repeatReturnUp.startGoalObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      repeatReturnUp.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      clipNames.contains(
                          repeatReturnUp.voiceSourceName.lowercased()
                      ) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 011 repeat-return-up lesson"
                    )
                }
            }
            if let repeatReturnDown = lesson.repeatReturnDown {
                let soundNames = Set(soundClips.flatMap {
                    [$0.logicalName.lowercased(), $0.sourceName.lowercased()]
                })
                guard repeatReturnDown.collisionRadius.isFinite,
                      repeatReturnDown.collisionRadius > 0,
                      isNonempty(repeatReturnDown.instruction),
                      isNonempty(repeatReturnDown.soundLogicalName),
                      lesson.repeatReturnUp != nil,
                      let returnDown = lesson.returnDown,
                      repeatReturnDown.upGoalObjectHandle
                        == returnDown.upGoalObjectHandle,
                      repeatReturnDown.collisionRadius
                        == returnDown.collisionRadius,
                      let target = objects.first(where: {
                          $0.handle
                            == repeatReturnDown.upGoalObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      repeatReturnDown.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      soundNames.contains(
                          repeatReturnDown.soundLogicalName.lowercased()
                      ) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 012 repeat-return-down lesson"
                    )
                }
            }
            if let continueToCourse = lesson.continueToCourse {
                guard continueToCourse.collisionRadius.isFinite,
                      continueToCourse.collisionRadius > 0,
                      isNonempty(continueToCourse.instruction),
                      isNonempty(continueToCourse.voiceSourceName),
                      lesson.repeatReturnDown != nil,
                      let returnUp = lesson.returnUp,
                      continueToCourse.startGoalObjectHandle
                        == returnUp.startGoalObjectHandle,
                      continueToCourse.collisionRadius
                        == returnUp.collisionRadius,
                      continueToCourse.portalRoomSourceIndex == 2,
                      continueToCourse.orderedPortalIndices == [0, 1],
                      let target = objects.first(where: {
                          $0.handle
                            == continueToCourse.startGoalObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      continueToCourse.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      clipNames.contains(
                          continueToCourse.voiceSourceName.lowercased()
                      ),
                      let portalRoom = rooms.first(where: {
                          $0.sourceIndex
                            == continueToCourse.portalRoomSourceIndex
                      }),
                      continueToCourse.orderedPortalIndices.allSatisfy({
                          portalRoom.portals.indices.contains($0)
                      }),
                      continueToCourse.orderedPortalIndices.allSatisfy({
                          portalIndex in
                          let portal = portalRoom.portals[portalIndex]
                          guard portalRoom.faces.indices.contains(
                              portal.faceIndex
                          ),
                                let connectedRoom = rooms.first(where: {
                                    $0.sourceIndex == portal.connectedRoom
                                }),
                                connectedRoom.portals.indices.contains(
                                    portal.connectedPortal
                                )
                          else {
                              return false
                          }
                          let reciprocal =
                              connectedRoom.portals[portal.connectedPortal]
                          return reciprocal.connectedRoom
                                == portalRoom.sourceIndex
                              && reciprocal.connectedPortal == portalIndex
                              && connectedRoom.faces.indices.contains(
                                  reciprocal.faceIndex
                              )
                      }) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 013 continue-to-course lesson"
                    )
                }
            }
            if let startCourse = lesson.startCourse {
                guard startCourse.collisionRadius.isFinite,
                      startCourse.collisionRadius > 0,
                      isNonempty(startCourse.instruction),
                      isNonempty(startCourse.voiceSourceName),
                      startCourse.portalRoomSourceIndex == 2,
                      startCourse.portalIndex == 1,
                      startCourse.enabledControlMask == 63,
                      let target = objects.first(where: {
                          $0.handle == startCourse.startCourseObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      startCourse.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      clipNames.contains(
                          startCourse.voiceSourceName.lowercased()
                      ),
                      let portalRoom = rooms.first(where: {
                          $0.sourceIndex
                            == startCourse.portalRoomSourceIndex
                      }),
                      portalRoom.portals.indices.contains(
                          startCourse.portalIndex
                      ),
                      portalRoom.faces.indices.contains(
                          portalRoom.portals[
                              startCourse.portalIndex
                          ].faceIndex
                      ),
                      let connectedRoom = rooms.first(where: {
                          $0.sourceIndex
                            == portalRoom.portals[
                                startCourse.portalIndex
                            ].connectedRoom
                      }),
                      connectedRoom.portals.indices.contains(
                          portalRoom.portals[
                              startCourse.portalIndex
                          ].connectedPortal
                      )
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 014 start-course lesson"
                    )
                }
                let portal =
                    portalRoom.portals[startCourse.portalIndex]
                let reciprocal =
                    connectedRoom.portals[portal.connectedPortal]
                guard reciprocal.connectedRoom == portalRoom.sourceIndex,
                      reciprocal.connectedPortal == startCourse.portalIndex,
                      connectedRoom.faces.indices.contains(
                          reciprocal.faceIndex
                      ) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 014 start-course lesson"
                    )
                }
            }
            if let finishCourse = lesson.finishCourse {
                guard finishCourse.collisionRadius.isFinite,
                      finishCourse.collisionRadius > 0,
                      isNonempty(finishCourse.successMessage),
                      isNonempty(finishCourse.instruction),
                      isNonempty(finishCourse.voiceSourceName),
                      finishCourse.portalRoomSourceIndex == 49,
                      finishCourse.orderedPortalIndices == [0, 1],
                      finishCourse.enabledControlMask == 32,
                      let target = objects.first(where: {
                          $0.handle
                            == finishCourse.finishCourseObjectHandle
                      }),
                      target.type == 7,
                      let presentation = objectPresentations.first(where: {
                          $0.objectHandle == target.handle && !$0.isVisible
                      }),
                      let model = models.first(where: {
                          $0.source == presentation.primaryModel
                      }),
                      finishCourse.collisionRadius
                        == sourceObjectPresentationSize(
                            model: model,
                            objectType: target.type
                        ),
                      clipNames.contains(
                          finishCourse.voiceSourceName.lowercased()
                      ),
                      let portalRoom = rooms.first(where: {
                          $0.sourceIndex
                            == finishCourse.portalRoomSourceIndex
                      }),
                      finishCourse.orderedPortalIndices.allSatisfy({
                          portalRoom.portals.indices.contains($0)
                      }),
                      finishCourse.orderedPortalIndices.allSatisfy({
                          portalIndex in
                          let portal = portalRoom.portals[portalIndex]
                          guard portalRoom.faces.indices.contains(
                              portal.faceIndex
                          ),
                                let connectedRoom = rooms.first(where: {
                                    $0.sourceIndex == portal.connectedRoom
                                }),
                                connectedRoom.portals.indices.contains(
                                    portal.connectedPortal
                                )
                          else {
                              return false
                          }
                          let reciprocal =
                              connectedRoom.portals[portal.connectedPortal]
                          return reciprocal.connectedRoom
                                == portalRoom.sourceIndex
                              && reciprocal.connectedPortal == portalIndex
                              && connectedRoom.faces.indices.contains(
                                  reciprocal.faceIndex
                              )
                      }) else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 015 finish-course lesson"
                    )
                }
            }
        }
        if let dodge = trainingDodgeAttempt {
            let clipNames = Set(
                voiceClips.map {
                    $0.sourceName.lowercased()
                })
            let soundNames = Set(
                soundClips.flatMap {
                    [$0.logicalName.lowercased(), $0.sourceName.lowercased()]
                })
            let requiredClips = [
                dodge.introductionVoiceSourceName,
                dodge.almostDoneVoiceSourceName,
                dodge.successVoiceSourceName,
            ]
            let start = objects.first {
                $0.handle == dodge.startDodgeObjectHandle
            }
            let done = objects.first {
                $0.handle == dodge.doneDodgeingGoalObjectHandle
            }
            let turret = objects.first {
                $0.handle == dodge.dodgeTurretObjectHandle
            }
            let marker = objects.first {
                $0.handle == dodge.flashLightObjectHandle
            }
            let portalRooms = [
                dodge.portalRoomTwoSourceIndex,
                dodge.portalRoomThreeSourceIndex,
            ].compactMap { sourceIndex in
                rooms.first { $0.sourceIndex == sourceIndex }
            }
            let expectedPortalConnections: [Int: [(room: Int, portal: Int)]] = [
                49: [(35, 0), (50, 0)],
                36: [(35, 1), (37, 0)],
            ]
            let portalsAreReciprocal =
                portalRooms.count == 2
                && portalRooms.allSatisfy { room in
                    guard let expectedConnections =
                            expectedPortalConnections[room.sourceIndex]
                    else {
                        return false
                    }
                    return dodge.orderedPortalIndices.allSatisfy { index in
                        guard expectedConnections.indices.contains(index),
                            room.portals.indices.contains(index),
                            room.faces.indices.contains(
                                room.portals[index].faceIndex
                            ),
                            let connected = rooms.first(where: {
                                $0.sourceIndex
                                    == room.portals[index].connectedRoom
                            }),
                            connected.portals.indices.contains(
                                room.portals[index].connectedPortal
                            )
                        else {
                            return false
                        }
                        let reciprocal = connected.portals[
                            room.portals[index].connectedPortal
                        ]
                        let expected = expectedConnections[index]
                        return room.portals[index].connectedRoom
                                == expected.room
                            && room.portals[index].connectedPortal
                                == expected.portal
                            && room.portals[index].flags & 1 == 1
                            && reciprocal.flags & 1 == 1
                            && reciprocal.connectedRoom == room.sourceIndex
                            && reciprocal.connectedPortal == index
                            && connected.faces.indices.contains(
                                reciprocal.faceIndex
                            )
                    }
                }
            let dodgeExitIsValid = dodge.dodgeExit.map { exit in
                exit.objectHandle
                    == dodge.doneDodgeingGoalObjectHandle
                    && exit.collisionRadius
                        == dodge.doneDodgeingGoalCollisionRadius
                    && exit.markerLightObjectHandle
                        == dodge.flashLightObjectHandle
                    && exit.markerLightDistance == 50
                    && exit.portalRoomSourceIndex
                        == dodge.portalRoomThreeSourceIndex
                    && exit.orderedPortalIndices
                        == dodge.orderedPortalIndices
                    && exit.disabledControlMask == 62
                    && exit.instruction
                        == "Now keep moving forward into the next room."
                    && exit.voiceSourceName == "proceed4.osf"
                    && clipNames.contains(
                        exit.voiceSourceName.lowercased()
                    )
            } ?? true
            guard dodge.startDodgeObjectHandle == 4_106,
                dodge.startDodgeCollisionRadius == 10.052_409,
                dodge.doneDodgeingGoalObjectHandle == 12_302,
                dodge.doneDodgeingGoalCollisionRadius == 10.052_409,
                dodge.dodgeTurretObjectHandle == 8_199,
                dodge.flashLightObjectHandle == 4_120,
                dodge.triggerDelay == 10,
                dodge.successDelay == 20,
                dodge.almostDoneDelay == 14,
                dodge.portalRoomTwoSourceIndex == 49,
                dodge.portalRoomThreeSourceIndex == 36,
                dodge.orderedPortalIndices == [0, 1],
                dodge.disabledControlMask == 3,
                dodge.enabledDodgeControlMask == 60,
                dodge.successControlMask == 3,
                dodge.introduction
                    == "Next you are going to practice dodging.",
                dodge.instruction
                    == "To complete this step, dodge the turrett fire for 20 seconds.",
                dodge.hitInstruction
                    == "Oops, you were hit! Keep moving!",
                dodge.almostDoneInstruction
                    == "You are almost done! Keep up the good work!",
                dodge.successMessage == "Excellent!",
                dodge.leaveInstruction
                    == "Now using your sliding skills, proceed forward to the flashing green light.",
                dodge.introductionVoiceSourceName == "intro2.osf",
                dodge.almostDoneVoiceSourceName == "almost.osf",
                dodge.successVoiceSourceName == "proceed3.osf",
                dodge.restoredPlayerShields == 100,
                dodge.successMarkerLightDistance == 50,
                dodge.markerLightPresentation
                    == .init(
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
                requiredClips.allSatisfy({
                    clipNames.contains($0.lowercased())
                }),
                dodgeExitIsValid,
                start?.type == 7,
                start?.storedID == 67,
                start?.definition?.storedIndex == 67,
                start?.definition?.sourceName == "Invisiblepowerup",
                start?.instanceName == "StartDodge",
                start?.flags == 4_096,
                start?.location == .room(35),
                start?.position
                    == .init(
                        x: 2_061.8765,
                        y: -752.8663,
                        z: 2_199.4517
                    ),
                start?.orientation
                    == .init(
                        right: .init(x: -1, y: 0, z: 0),
                        up: .init(x: 0, y: 1, z: 0),
                        forward: .init(x: 0, y: 0, z: -1)
                    ),
                start?.containsType == 255,
                start?.containsID == 0,
                start?.containsCount == 0,
                start?.lifeLeft == 0,
                start?.soundSource == nil,
                start?.inertScriptName == nil,
                start?.inertModuleName == nil,
                done?.type == 7,
                done?.storedID == 67,
                done?.definition == start?.definition,
                done?.instanceName == "DoneDodgeingGoal",
                done?.flags == 4_096,
                done?.location == .room(35),
                done?.position
                    == .init(
                        x: 2_061.31,
                        y: -755.9523,
                        z: 2_421.182
                    ),
                done?.orientation == start?.orientation,
                done?.containsType == 255,
                done?.containsID == 0,
                done?.containsCount == 0,
                done?.lifeLeft == 0,
                done?.soundSource == nil,
                done?.inertScriptName == nil,
                done?.inertModuleName == nil,
                turret?.type == 2,
                turret?.storedID == 115,
                turret?.definition?.storedIndex == 115,
                turret?.definition?.sourceName == "Hangturret",
                turret?.instanceName == "DodgeTurrett",
                turret?.flags == 5_120,
                turret?.location == .room(35),
                turret?.position
                    == .init(
                        x: 2_061.69,
                        y: -701.7448,
                        z: 2_356.2942
                    ),
                turret?.orientation
                    == .init(
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
                turret?.containsType == 255,
                turret?.containsID == 0,
                turret?.containsCount == 0,
                turret?.lifeLeft == 0,
                turret?.soundSource == nil,
                turret?.inertScriptName == nil,
                turret?.inertModuleName == nil,
                marker?.type == 11,
                marker?.storedID == 205,
                marker?.definition?.storedIndex == 205,
                marker?.definition?.sourceName == "Blinking Red Light-DM",
                marker?.instanceName == "FlashLight-1",
                marker?.location == .room(36),
                marker?.position
                    == .init(
                        x: 2_061.6824,
                        y: -745.7475,
                        z: 2_441.2942
                    ),
                marker?.orientation
                    == .init(
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
                marker?.flags == 4_096,
                marker?.containsType == 255,
                marker?.containsID == 0,
                marker?.containsCount == 0,
                marker?.lifeLeft == 0,
                marker?.soundSource == nil,
                marker?.inertScriptName == nil,
                marker?.inertModuleName == nil,
                objectPresentations.contains(where: {
                    $0.objectHandle == dodge.startDodgeObjectHandle
                        && !$0.isVisible
                }),
                objectPresentations.contains(where: {
                    $0.objectHandle
                        == dodge.doneDodgeingGoalObjectHandle
                        && !$0.isVisible
                }),
                objectPresentations.contains(where: {
                    $0.objectHandle == dodge.dodgeTurretObjectHandle
                        && $0.primaryModel == dodge.turret.model
                }),
                models.contains(where: {
                    $0.source == dodge.turret.model
                }),
                models.contains(where: {
                    $0.source == dodge.turret.projectileModel
                }),
                dodge.turret.model.sourceName
                    == "securityturret.OOF",
                dodge.turret.projectileModel.sourceName
                    == "RedLaser.OOF",
                models.first(where: {
                    $0.source == dodge.turret.model
                })?.collisionRadius == 5.552_946,
                models.first(where: {
                    $0.source == dodge.turret.projectileModel
                })?.collisionRadius == 4.878_135,
                soundNames.contains(
                    dodge.turret.fireSoundSourceName.lowercased()
                ),
                soundNames.contains(
                    dodge.turret.impactSoundSourceName.lowercased()
                ),
                dodge.turret.collisionRadius.isFinite,
                dodge.turret.joints.count == 2,
                dodge.turret.gunpointParentSubmodelIndex >= 0,
                dodge.turret.collisionRadius > 0,
                dodge.turret.fieldOfViewDot.isFinite,
                (-1...1).contains(dodge.turret.fieldOfViewDot),
                dodge.turret.maximumTargetDistance.isFinite,
                dodge.turret.maximumTargetDistance > 0,
                dodge.turret.fireAlignmentDot == 0.93,
                dodge.turret.fireWait.isFinite,
                dodge.turret.fireWait > 0,
                dodge.turret.projectileDamage.isFinite,
                dodge.turret.projectileDamage > 0,
                dodge.turret.projectileRadius.isFinite,
                dodge.turret.projectileRadius > 0,
                dodge.turret.projectileSpeed.isFinite,
                dodge.turret.projectileSpeed > 0,
                dodge.turret.projectileLifetime.isFinite,
                dodge.turret.projectileLifetime > 0,
                portalsAreReciprocal
            else {
                throw LevelValidationError.invalidDependency(
                    "Training timed dodge attempt"
                )
            }
            if let lesson = dodge.maneuverFollow,
               let handoff = lesson.destructionHandoff {
                try validateTrainingFollowBotDestructionHandoff(
                    handoff,
                    lesson: lesson,
                    level: self
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
            let soundNames = Set(soundClips.flatMap {
                [$0.logicalName.lowercased(), $0.sourceName.lowercased()]
            })
            let releaseSoundIsResolved =
                chain.releaseSoundSourceName.map {
                    soundNames.contains($0.lowercased())
                } ?? true
            let ambientEngineSoundIsResolved =
                chain.ambientEngineSoundSourceName.map {
                    soundNames.contains($0.lowercased())
                } ?? true
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
                  ),
                  releaseSoundIsResolved,
                  ambientEngineSoundIsResolved else {
                throw LevelValidationError.invalidDependency(
                    "Training robot Guidebot chain"
                )
            }
            try validateTrainingGuidebotYellowFlareBinding(
                chain: chain,
                models: models,
                materials: presentationMaterials,
                sounds: soundClips,
                dependencies: dependencyManifest.current
            )
        }
        if let chain = trainingCameraMonitorChain {
            let clipNames = Set(voiceClips.map {
                $0.sourceName.lowercased()
            })
            let soundNames = Set(soundClips.map {
                $0.sourceName.lowercased()
            })
            let returnToShipIsValid = chain.returnToShip.map({
                returnChain in
                let killbotEntryIsValid =
                    returnChain.killbotEntry.map { entry in
                        guard entry.triggerRoomSourceIndex
                                == returnChain.barrierRoomSourceIndex,
                              returnChain.orderedPortalIndices.contains(
                                where: { portalIndex in
                                    guard let room = rooms.first(where: {
                                        $0.sourceIndex
                                            == entry.triggerRoomSourceIndex
                                    }),
                                    room.portals.indices.contains(
                                        portalIndex
                                    ) else {
                                        return false
                                    }
                                    return room.portals[portalIndex].faceIndex
                                        == entry.triggerFaceIndex
                                }
                              ),
                              Set(entry.orderedPortalIndices)
                                == Set(returnChain.orderedPortalIndices),
                              entry.orderedPortalIndices.count
                                == returnChain.orderedPortalIndices.count,
                              triggers.contains(where: {
                                  $0.name == entry.triggerName
                                      && $0.roomIndex
                                        == entry.triggerRoomSourceIndex
                                      && $0.faceIndex
                                        == entry.triggerFaceIndex
                                      && $0.flags == 8
                                      && $0.activator == 1
                              }),
                              entry.closedMarkerLightDistance.isFinite,
                              entry.closedMarkerLightDistance >= 0,
                              entry.followupDelay.isFinite,
                              entry.followupDelay > 0,
                              isNonempty(entry.entryMessage),
                              isNonempty(entry.followupMessage),
                              clipNames.contains(
                                entry.entryVoiceSourceName.lowercased()
                              ),
                              clipNames.contains(
                                entry.followupVoiceSourceName.lowercased()
                              ) else {
                            return false
                        }
                        return true
                    } ?? true
                return validTrainingGuidebotReturnBarrier(
                    returnChain,
                    in: self
                )
                    && killbotEntryIsValid
                    && clipNames.contains(
                        returnChain.successVoiceSourceName.lowercased()
                    )
                    && soundNames.contains(
                        returnChain.returnSoundSourceName.lowercased()
                    )
                    && (
                        returnChain.greetingSoundSourceName.map {
                            soundNames.contains($0.lowercased())
                        } ?? true
                    )
                    && isNonempty(returnChain.returnMessage)
                    && isNonempty(returnChain.arrivalMessage)
                    && isNonempty(returnChain.successMessage)
            }) ?? true
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
                  returnToShipIsValid,
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.pickupObjectHandle
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training Camera Monitor chain"
                )
            }
        }
        if let chain = trainingRASBot1DeathChain {
            guard trainingCameraMonitorChain?.returnToShip?
                    .killbotEntry != nil,
                  chain.combat == .stockTraining,
                  let robot = objects.first(where: {
                      $0.handle == chain.robotObjectHandle
                  }),
                  robot.type == 2,
                  robot.storedID == 106,
                  robot.definition?.sourceName
                    == "RAS1 Light Security Flyer",
                  robot.instanceName == "RASBot1",
                  robot.location == .room(chain.robotRoomSourceIndex),
                  robot.flags == chain.robotFlags,
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.robotObjectHandle
                          && $0.isVisible
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training RASBot1 death chain"
                )
            }
        }
        if let chain = trainingRASBot2DeathChain {
            guard trainingRASBot1DeathChain != nil,
                  chain.combat == .stockTraining,
                  let robot = objects.first(where: {
                      $0.handle == chain.robotObjectHandle
                  }),
                  robot.type == 2,
                  robot.storedID == 106,
                  robot.definition?.sourceName
                    == "RAS1 Light Security Flyer",
                  robot.instanceName == "RASBot2",
                  robot.location == .room(chain.robotRoomSourceIndex),
                  robot.flags == chain.robotFlags,
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.robotObjectHandle
                          && $0.isVisible
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training RASBot2 death chain"
                )
            }
        }
        if let chain = trainingRASBot3DeathChain {
            guard trainingRASBot2DeathChain != nil,
                  chain.combat == .stockTraining,
                  let robot = objects.first(where: {
                      $0.handle == chain.robotObjectHandle
                  }),
                  robot.type == 2,
                  robot.storedID == 106,
                  robot.definition?.sourceName
                    == "RAS1 Light Security Flyer",
                  robot.instanceName == "RASBot3",
                  robot.location == .room(chain.robotRoomSourceIndex),
                  robot.flags == chain.robotFlags,
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.robotObjectHandle
                          && $0.isVisible
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training RASBot3 death chain"
                )
            }
        }
        if let chain = trainingRASBot4DeathChain {
            guard trainingRASBot3DeathChain != nil,
                  chain.combat == .stockTraining,
                  let robot = objects.first(where: {
                      $0.handle == chain.robotObjectHandle
                  }),
                  robot.type == 2,
                  robot.storedID == 106,
                  robot.definition?.sourceName
                    == "RAS1 Light Security Flyer",
                  robot.instanceName == "RASBot4",
                  robot.location == .room(chain.robotRoomSourceIndex),
                  robot.flags == chain.robotFlags,
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.robotObjectHandle
                          && $0.isVisible
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training RASBot4 death chain"
                )
            }
        }
        if let chain = trainingLastBot1DeathChain {
            guard trainingFinalRoomEntryChain != nil,
                  chain.combat == .stockTraining,
                  let robot = objects.first(where: {
                      $0.handle == chain.robotObjectHandle
                  }),
                  robot.type == 2,
                  robot.storedID == 106,
                  robot.definition?.sourceName
                    == "RAS1 Light Security Flyer",
                  robot.instanceName == "LastBot1",
                  robot.location == .room(chain.robotRoomSourceIndex),
                  robot.flags == chain.robotFlags,
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.robotObjectHandle
                          && $0.isVisible
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training LastBot1 death chain"
                )
            }
        }
        if let chain = trainingLastBot2DeathChain {
            guard trainingLastBot1DeathChain != nil,
                  chain.combat == .stockTraining,
                  let robot = objects.first(where: {
                      $0.handle == chain.robotObjectHandle
                  }),
                  robot.type == 2,
                  robot.storedID == 106,
                  robot.definition?.sourceName
                    == "RAS1 Light Security Flyer",
                  robot.instanceName == "LastBot2",
                  robot.location == .room(chain.robotRoomSourceIndex),
                  robot.flags == chain.robotFlags,
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.robotObjectHandle
                          && $0.isVisible
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training LastBot2 death chain"
                )
            }
        }
        if let chain = trainingLastBot3DeathChain {
            guard trainingLastBot2DeathChain != nil,
                  chain.combat == .stockTraining,
                  let robot = objects.first(where: {
                      $0.handle == chain.robotObjectHandle
                  }),
                  robot.type == 2,
                  robot.storedID == 106,
                  robot.definition?.sourceName
                    == "RAS1 Light Security Flyer",
                  robot.instanceName == "LastBot3",
                  robot.location == .room(chain.robotRoomSourceIndex),
                  robot.flags == chain.robotFlags,
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.robotObjectHandle
                          && $0.isVisible
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training LastBot3 death chain"
                )
            }
        }
        if let chain = trainingLastBot4DeathChain {
            guard trainingLastBot3DeathChain != nil,
                  chain.combat == .stockTraining,
                  let robot = objects.first(where: {
                      $0.handle == chain.robotObjectHandle
                  }),
                  robot.type == 2,
                  robot.storedID == 106,
                  robot.definition?.sourceName
                    == "RAS1 Light Security Flyer",
                  robot.instanceName == "LastBot4",
                  robot.location == .room(chain.robotRoomSourceIndex),
                  robot.flags == chain.robotFlags,
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.robotObjectHandle
                          && $0.isVisible
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training LastBot4 death chain"
                )
            }
        }
        if let chain = trainingLastBot5DeathChain {
            guard trainingLastBot4DeathChain != nil,
                  chain.combat == .stockTraining,
                  let robot = objects.first(where: {
                      $0.handle == chain.robotObjectHandle
                  }),
                  robot.type == 2,
                  robot.storedID == 106,
                  robot.definition?.sourceName
                    == "RAS1 Light Security Flyer",
                  robot.instanceName == "LastBot5",
                  robot.location == .room(chain.robotRoomSourceIndex),
                  robot.flags == chain.robotFlags,
                  objectPresentations.contains(where: {
                      $0.objectHandle == chain.robotObjectHandle
                          && $0.isVisible
                  }) else {
                throw LevelValidationError.invalidDependency(
                    "Training LastBot5 death chain"
                )
            }
        }
        if let chain = trainingInvulnerabilityPickupChain {
            let presentation = objectPresentations.first {
                $0.objectHandle == chain.pickupObjectHandle
                    && $0.isVisible
            }
            let model = presentation.flatMap { presentation in
                models.first {
                    $0.source == presentation.primaryModel
                }
            }
            let reachedSoundNames = Set(soundClips.map(\.sourceName))
            guard trainingRASBot4DeathChain != nil,
                chain.pickupObjectHandle == 2_076,
                chain.pickupRoomSourceIndex == 12,
                chain.pickupObjectFlags == 5_120,
                chain.pickupCollisionRadius.isFinite,
                chain.pickupCollisionRadius > 0,
                chain.duration == 30,
                chain.activatedMessage == "Invulnerability On",
                chain.expiredMessage == "Invulnerability Off",
                chain.pickupSoundSourceName == "Power03.wav",
                chain.activatedSoundSourceName == "Invon.wav",
                chain.expiredSoundSourceName == "Invoff.wav",
                let pickup = objects.first(where: {
                    $0.handle == chain.pickupObjectHandle
                }),
                pickup.type == 7,
                pickup.storedID == 3,
                pickup.definition
                    == .init(
                        storedIndex: 3,
                        sourceName: "Invulnerability"
                    ),
                pickup.instanceName == "InvulnPowerup2",
                pickup.flags == chain.pickupObjectFlags,
                pickup.location == .room(chain.pickupRoomSourceIndex),
                model?.collisionRadius == chain.pickupCollisionRadius,
                reachedSoundNames.contains(
                    chain.pickupSoundSourceName
                ),
                reachedSoundNames.contains(
                    chain.activatedSoundSourceName
                ),
                reachedSoundNames.contains(
                    chain.expiredSoundSourceName
                )
            else {
                throw LevelValidationError.invalidDependency(
                    "Training InvulnPowerup2 pickup chain"
                )
            }
        }
        if let chain = trainingCloakPickupChain {
            let presentation = objectPresentations.first {
                $0.objectHandle == chain.pickupObjectHandle
                    && $0.isVisible
            }
            let model = presentation.flatMap { presentation in
                models.first { $0.source == presentation.primaryModel }
            }
            let mediumModel = presentation?.mediumModel.flatMap {
                source in models.first { $0.source == source }
            }
            let lowModel = presentation?.lowModel.flatMap {
                source in models.first { $0.source == source }
            }
            let reachedSoundNames = Set(soundClips.map(\.sourceName))
            guard trainingInvulnerabilityPickupChain != nil,
                chain.pickupObjectHandle == 2_073,
                chain.pickupRoomSourceIndex == 11,
                chain.pickupObjectFlags == 5_120,
                chain.pickupCollisionRadius.isFinite,
                chain.pickupCollisionRadius > 0,
                chain.fadeDuration == 1,
                chain.cloakDuration == 30,
                chain.activatedMessage == "Cloak On",
                chain.expiredMessage == "Cloak Off",
                chain.pickupSoundSourceName == "Power03.wav",
                chain.activatedSoundSourceName == "ShpCloakOn.wav",
                chain.expiredSoundSourceName == "ShpCloakOffBeep.wav",
                let pickup = objects.first(where: {
                    $0.handle == chain.pickupObjectHandle
                }),
                pickup.type == 7,
                pickup.storedID == 4,
                pickup.definition
                    == .init(storedIndex: 4, sourceName: "Cloak"),
                pickup.instanceName == "CloakPowerup2",
                pickup.flags == chain.pickupObjectFlags,
                pickup.location == .room(chain.pickupRoomSourceIndex),
                presentation?.primaryModel.sourceName == "cloak.OOF",
                presentation?.mediumModel?.sourceName
                    == "CloakMed.OOF",
                presentation?.lowModel?.sourceName
                    == "CloakLow.OOF",
                presentation?.dyingModel == nil,
                presentation?.mediumDistance == 35,
                presentation?.lowDistance == 50,
                model?.sourceArchive == "d3.hog",
                model?.sourceSHA256
                    == "ccce90c9dbc266c0a22ab00339689059888719b212116191049ef4396ebc5baa",
                mediumModel?.sourceArchive == "d3.hog",
                mediumModel?.sourceSHA256
                    == "7b6e66b1ad23328b43dc007de7cb2b8806397f69bab95647e350554f479e0c6b",
                lowModel?.sourceArchive == "d3.hog",
                lowModel?.sourceSHA256
                    == "38754663d76df10a7d6d41e241cfe2fc08b9f7fb99addb41cb5ed1fc205f119f",
                model?.collisionRadius == chain.pickupCollisionRadius,
                reachedSoundNames.contains(chain.pickupSoundSourceName),
                reachedSoundNames.contains(chain.activatedSoundSourceName),
                reachedSoundNames.contains(chain.expiredSoundSourceName)
            else {
                throw LevelValidationError.invalidDependency(
                    "Training CloakPowerup2 pickup chain"
                )
            }
        }
        if let chain = trainingLastRoomChain {
            let room = rooms.first {
                $0.sourceIndex == chain.barrierRoomSourceIndex
            }
            let marker = objects.first {
                $0.handle == chain.markerLightObjectHandle
            }
            guard trainingCloakPickupChain != nil,
                chain.barrierRoomSourceIndex == 44,
                chain.orderedPortalIndices == [1, 0],
                chain.markerLightObjectHandle == 4_117,
                chain.openMarkerLightDistance == 50,
                chain.timerDuration == 2,
                chain.completionMessages == [
                    "Excellent!",
                    "Now proceed through the doorway that just opened to begin the last stage of your training.",
                ],
                chain.completionVoiceSourceName == "proceed5.osf",
                let room,
                chain.orderedPortalIndices.allSatisfy(
                    room.portals.indices.contains
                ),
                marker?.type == 11,
                marker?.storedID == 205,
                marker?.definition == .init(
                    storedIndex: 205,
                    sourceName: "Blinking Red Light-DM"
                ),
                marker?.instanceName == "FlashLight-4",
                marker?.flags == 4_096,
                marker?.location
                    == .room(chain.barrierRoomSourceIndex),
                chain.markerLightPresentation == .init(
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
                chain.orderedPortalIndices.allSatisfy({ portalIndex in
                    let portal = room.portals[portalIndex]
                    guard portal.flags & 1 != 0,
                        let connectedRoom = rooms.first(where: {
                            $0.sourceIndex == portal.connectedRoom
                        }),
                        connectedRoom.portals.indices.contains(
                            portal.connectedPortal
                        )
                    else {
                        return false
                    }
                    let reciprocal =
                        connectedRoom.portals[portal.connectedPortal]
                    return reciprocal.connectedRoom == room.sourceIndex
                        && reciprocal.connectedPortal == portalIndex
                        && reciprocal.flags & 1 != 0
                }),
                voiceClips.contains(where: {
                    $0.sourceName.caseInsensitiveCompare(
                        chain.completionVoiceSourceName
                    ) == .orderedSame
                })
            else {
                throw LevelValidationError.invalidDependency(
                    "Training Script 034 / 049 last-room chain"
                )
            }
        }
        if let chain = trainingFinalRoomEntryChain {
            let trigger = triggers.first {
                $0.name == chain.triggerName
            }
            let triggerRoom = rooms.first {
                $0.sourceIndex == chain.triggerRoomSourceIndex
            }
            let barrierPortals = trainingLastRoomChain.flatMap { lastRoom in
                rooms.first {
                    $0.sourceIndex == lastRoom.barrierRoomSourceIndex
                }.map { room in
                    lastRoom.orderedPortalIndices.map {
                        room.portals[$0]
                    }
                }
            }
            let voice = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare(
                    chain.voiceSourceName
                ) == .orderedSame
            }
            guard trainingLastRoomChain != nil,
                chain.triggerName == "Portal4",
                chain.triggerRoomSourceIndex == 44,
                chain.triggerFaceIndex == 1,
                chain.successMessage == "Excellent!",
                chain.instructionMessage
                    == "Now for your final and most difficult task. Locate and destroy the last 5 robots.",
                chain.voiceSourceName == "intro7.osf",
                trigger?.roomIndex == chain.triggerRoomSourceIndex,
                trigger?.faceIndex == chain.triggerFaceIndex,
                trigger?.flags == 8,
                trigger?.activator == 1,
                triggerRoom?.faces.indices.contains(
                    chain.triggerFaceIndex
                ) == true,
                triggerRoom?.faces[chain.triggerFaceIndex].portalIndex
                    == 1,
                barrierPortals?.count == 2,
                barrierPortals?[0].connectedRoom == 45,
                barrierPortals?[0].connectedPortal == 0,
                barrierPortals?[1].connectedRoom == 41,
                barrierPortals?[1].connectedPortal == 3,
                voice?.sourceEntryIndex == 16,
                voice?.sourceArchive == "missions/training.mn3",
                voice?.sourceSHA256
                    == "7348ded9ee2c6735ea712b52647f0bfa7478a508c03c10af5f837741a836c67f"
            else {
                throw LevelValidationError.invalidDependency(
                    "Training Script 050 final-room entry"
                )
            }
        }
        if trainingFinalBotsCompletionChain != nil {
            try validateStockTrainingFinalBotsCompletionPackage(
                chain: trainingFinalBotsCompletionChain,
                done: voiceClips.first {
                    $0.sourceName.caseInsensitiveCompare("done.osf")
                        == .orderedSame
                },
                level: self,
                requiresExactVoice: false
            )
        }
        if trainingFinalGoalChain != nil {
            try validateStockTrainingFinalGoalPackage(
                chain: trainingFinalGoalChain,
                level: self
            )
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
            if clip.logicalName.caseInsensitiveCompare("Headlight1")
                == .orderedSame
                || clip.sourceName.caseInsensitiveCompare("Headlight.wav")
                    == .orderedSame
            {
                guard clip.logicalName == "Headlight1",
                      clip.sourceName == "Headlight.wav",
                      clip.sourceEntryIndex == 1_407,
                      clip.sampleRate == 22_050,
                      clip.channelCount == 1,
                      clip.frameCount == 10_623,
                      clip.pcm16LittleEndian.count == 21_246,
                      clip.pcmSHA256
                        == "7886b286bf1897c59c04bc5b80460d975ee5979ba21dae8e8f3596c5f0b23417",
                      clip.sourceArchive == "d3.hog",
                      clip.sourceSHA256
                        == "cc05bbed03cf33ef705613d5a237d5c1879c83df49dc03bca01960cf5a20384a",
                      clip.importVolume == 1
                else {
                    throw LevelValidationError.invalidDependency(
                        "Headlight1 canonical sound binding"
                    )
                }
            }
        }
        let hasStockTrainingSource =
            source.archiveSHA256
                == "fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54"
            && source.levelSHA256
                == "915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41"
        if enforceStockSourceInvariants,
           hasStockTrainingSource,
           !allowImportStagingPresentation {
            let welcome = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("welcome.osf")
                    == .orderedSame
            }
            let return1 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("return1.osf")
                    == .orderedSame
            }
            let left1 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("left1.osf")
                    == .orderedSame
            }
            let return2 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("return2.osf")
                    == .orderedSame
            }
            let up1 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("up1.osf")
                    == .orderedSame
            }
            let return3 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("return3.osf")
                    == .orderedSame
            }
            let repeatVoice = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("repeat.osf")
                    == .orderedSame
            }
            let lright = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("lright.osf")
                    == .orderedSame
            }
            let udown = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("udown.osf")
                    == .orderedSame
            }
            let proceed1 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("proceed1.osf")
                    == .orderedSame
            }
            let intro1 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("intro1.osf")
                    == .orderedSame
            }
            let proceed2 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("proceed2.osf")
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
            let proceed6 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("proceed6.osf")
                    == .orderedSame
            }
            let intro6 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("intro6.osf")
                    == .orderedSame
            }
            let guidebotF = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("guidebotf.osf")
                    == .orderedSame
            }
            let intro7 = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("intro7.osf")
                    == .orderedSame
            }
            let done = voiceClips.first {
                $0.sourceName.caseInsensitiveCompare("done.osf")
                    == .orderedSame
            }
            if let repeatForwardGoal =
                    trainingOpeningLesson?.repeatForwardGoal {
                let forwardGoal = objects.first {
                    $0.handle == repeatForwardGoal.forwardGoalObjectHandle
                }
                let forwardGoalPresentation = objectPresentations.first {
                    $0.objectHandle
                        == repeatForwardGoal.forwardGoalObjectHandle
                }
                let menuBeep = soundClips.first {
                    $0.logicalName.caseInsensitiveCompare("MenuBeepEnter")
                        == .orderedSame
                }
                try validateStockTrainingRepeatForwardGoalPackage(
                    lesson: repeatForwardGoal,
                    forwardGoal: forwardGoal,
                    presentation: forwardGoalPresentation,
                    menuBeep: menuBeep
                )
            }
            if let repeatReturnLeft =
                    trainingOpeningLesson?.repeatReturnLeft {
                let startGoal = objects.first {
                    $0.handle == repeatReturnLeft.startGoalObjectHandle
                }
                let startGoalPresentation = objectPresentations.first {
                    $0.objectHandle
                        == repeatReturnLeft.startGoalObjectHandle
                }
                try validateStockTrainingRepeatReturnLeftPackage(
                    lesson: repeatReturnLeft,
                    startGoal: startGoal,
                    presentation: startGoalPresentation,
                    lright: lright
                )
            }
            if let repeatReturnRight =
                    trainingOpeningLesson?.repeatReturnRight {
                let leftGoal = objects.first {
                    $0.handle == repeatReturnRight.leftGoalObjectHandle
                }
                let leftGoalPresentation = objectPresentations.first {
                    $0.objectHandle
                        == repeatReturnRight.leftGoalObjectHandle
                }
                let menuBeep = soundClips.first {
                    $0.logicalName.caseInsensitiveCompare("MenuBeepEnter")
                        == .orderedSame
                }
                try validateStockTrainingRepeatReturnRightPackage(
                    lesson: repeatReturnRight,
                    leftGoal: leftGoal,
                    presentation: leftGoalPresentation,
                    menuBeep: menuBeep
                )
            }
            if let repeatReturnUp =
                    trainingOpeningLesson?.repeatReturnUp {
                let startGoal = objects.first {
                    $0.handle == repeatReturnUp.startGoalObjectHandle
                }
                let startGoalPresentation = objectPresentations.first {
                    $0.objectHandle
                        == repeatReturnUp.startGoalObjectHandle
                }
                try validateStockTrainingRepeatReturnUpPackage(
                    lesson: repeatReturnUp,
                    startGoal: startGoal,
                    presentation: startGoalPresentation,
                    udown: udown
                )
            }
            if let repeatReturnDown =
                    trainingOpeningLesson?.repeatReturnDown {
                let upGoal = objects.first {
                    $0.handle == repeatReturnDown.upGoalObjectHandle
                }
                let upGoalPresentation = objectPresentations.first {
                    $0.objectHandle
                        == repeatReturnDown.upGoalObjectHandle
                }
                let menuBeep = soundClips.first {
                    $0.logicalName.caseInsensitiveCompare("MenuBeepEnter")
                        == .orderedSame
                }
                try validateStockTrainingRepeatReturnDownPackage(
                    lesson: repeatReturnDown,
                    upGoal: upGoal,
                    presentation: upGoalPresentation,
                    menuBeep: menuBeep
                )
            }
            if let continueToCourse =
                    trainingOpeningLesson?.continueToCourse {
                let startGoal = objects.first {
                    $0.handle == continueToCourse.startGoalObjectHandle
                }
                let startGoalPresentation = objectPresentations.first {
                    $0.objectHandle
                        == continueToCourse.startGoalObjectHandle
                }
                let portalRoom = rooms.first {
                    $0.sourceIndex
                        == continueToCourse.portalRoomSourceIndex
                }
                try validateStockTrainingContinueToCoursePackage(
                    lesson: continueToCourse,
                    startGoal: startGoal,
                    presentation: startGoalPresentation,
                    portalRoom: portalRoom,
                    connectedRooms: Dictionary(
                        uniqueKeysWithValues: rooms.map {
                            ($0.sourceIndex, $0)
                        }
                    ),
                    proceed1: proceed1
                )
            }
            if let startCourse =
                    trainingOpeningLesson?.startCourse {
                let target = objects.first {
                    $0.handle == startCourse.startCourseObjectHandle
                }
                let presentation = objectPresentations.first {
                    $0.objectHandle
                        == startCourse.startCourseObjectHandle
                }
                let portalRoom = rooms.first {
                    $0.sourceIndex == startCourse.portalRoomSourceIndex
                }
                let connectedRoom = portalRoom.flatMap {
                    room -> LevelRoom? in
                    guard room.portals.indices.contains(
                        startCourse.portalIndex
                    ) else {
                        return nil
                    }
                    let sourceIndex =
                        room.portals[startCourse.portalIndex]
                            .connectedRoom
                    return rooms.first {
                        $0.sourceIndex == sourceIndex
                    }
                }
                try validateStockTrainingStartCoursePackage(
                    lesson: startCourse,
                    startCourse: target,
                    presentation: presentation,
                    portalRoom: portalRoom,
                    connectedRoom: connectedRoom,
                    intro1: intro1
                )
            }
            if let finishCourse =
                    trainingOpeningLesson?.finishCourse {
                let target = objects.first {
                    $0.handle == finishCourse.finishCourseObjectHandle
                }
                let presentation = objectPresentations.first {
                    $0.objectHandle
                        == finishCourse.finishCourseObjectHandle
                }
                let portalRoom = rooms.first {
                    $0.sourceIndex == finishCourse.portalRoomSourceIndex
                }
                try validateStockTrainingFinishCoursePackage(
                    lesson: finishCourse,
                    finishCourse: target,
                    presentation: presentation,
                    portalRoom: portalRoom,
                    connectedRooms: Dictionary(
                        uniqueKeysWithValues: rooms.map {
                            ($0.sourceIndex, $0)
                        }
                    ),
                    proceed2: proceed2
                )
            }
            if trainingDodgeAttempt != nil {
                try validateStockTrainingDodgeAttemptPackage(
                    trainingDodgeAttempt,
                    level: self
                )
            }
            if let repeatForward =
                    trainingOpeningLesson?.repeatForward {
                let startGoal = objects.first {
                    $0.handle == repeatForward.startGoalObjectHandle
                }
                let startGoalPresentation = objectPresentations.first {
                    $0.objectHandle == repeatForward.startGoalObjectHandle
                }
                guard repeatForward.startGoalObjectHandle == 12_300,
                      repeatForward.collisionRadius == 10.052_409,
                      repeatForward.successMessage == "Excellent!",
                      repeatForward.repeatMessage
                        == "Let's repeat the exercise we just did.",
                      repeatForward.forwardInstruction
                        == "Move forward until you stop.",
                      repeatForward.voiceSourceName == "repeat.osf",
                      startGoal?.type == 7,
                      startGoal?.storedID == 67,
                      startGoal?.definition?.storedIndex == 67,
                      startGoal?.definition?.referenceRuntimeIndex == 68,
                      startGoal?.definition?.sourceName
                        == "Invisiblepowerup",
                      startGoal?.instanceName == "StartGoal",
                      startGoal?.flags == 36_864,
                      startGoal?.location == .room(1),
                      startGoal?.position
                        == .init(
                            x: 2_062.7678,
                            y: -134.19601,
                            z: 2_201.679
                        ),
                      startGoal?.orientation
                        == .init(
                            right: .init(x: -1, y: 0, z: 0),
                            up: .init(x: 0, y: 1, z: -0),
                            forward: .init(x: -0, y: -0, z: -1)
                        ),
                      startGoalPresentation?.primaryModel
                        == .init(
                            storedIndex: 6,
                            sourceName: "invisiblepowerup.OOF"
                        ),
                      startGoalPresentation?.isVisible == false,
                      repeatVoice?.sourceEntryIndex == 27,
                      repeatVoice?.sampleRate == 22_050,
                      repeatVoice?.channelCount == 1,
                      repeatVoice?.frameCount == 109_469,
                      repeatVoice?.pcmSHA256
                        == "d9253f693ae288ad1b38d32094a8fc4ee3b3949fa4364f31a5faa2def2c780ce",
                      repeatVoice?.sourceArchive == "missions/training.mn3",
                      repeatVoice?.sourceSHA256
                        == "d85d9aa316ee5c16018c838ed5f930c48af2e67d78071ad574926f8ef15e1b0e"
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 007 package"
                    )
                }
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
            if let returnLeft = lesson.returnLeft {
                let startGoal = objects.first {
                    $0.handle == returnLeft.startGoalObjectHandle
                }
                let startGoalPresentation = objectPresentations.first {
                    $0.objectHandle == returnLeft.startGoalObjectHandle
                }
                guard returnLeft.startGoalObjectHandle == 12_300,
                      returnLeft.collisionRadius == 10.052_409,
                      returnLeft.instruction == "Now Go Left until you stop.",
                      returnLeft.voiceSourceName == "left1.osf",
                      startGoal?.type == 7,
                      startGoal?.storedID == 67,
                      startGoal?.definition?.storedIndex == 67,
                      startGoal?.definition?.referenceRuntimeIndex == 68,
                      startGoal?.definition?.sourceName
                        == "Invisiblepowerup",
                      startGoal?.instanceName == "StartGoal",
                      startGoal?.flags == 36_864,
                      startGoal?.location == .room(1),
                      startGoal?.position
                        == .init(
                            x: 2_062.7678,
                            y: -134.19601,
                            z: 2_201.679
                        ),
                      startGoalPresentation?.primaryModel
                        == .init(
                            storedIndex: 6,
                            sourceName: "invisiblepowerup.OOF"
                        ),
                      startGoalPresentation?.isVisible == false,
                      left1?.sourceEntryIndex == 18,
                      left1?.sampleRate == 22_050,
                      left1?.channelCount == 1,
                      left1?.frameCount == 74_769,
                      left1?.pcmSHA256
                        == "db6650fffc08561176c8080c516734e6d0338ab99e64e1cfd93f69c42f4ac690",
                      left1?.sourceArchive == "missions/training.mn3",
                      left1?.sourceSHA256
                        == "cf7ac0a29b8055d1f11d22ffd33b565cf219251a781808a664ac48118849ca29"
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 003 package"
                    )
                }
            }
            if let returnRight = lesson.returnRight {
                let leftGoal = objects.first {
                    $0.handle == returnRight.leftGoalObjectHandle
                }
                let leftGoalPresentation = objectPresentations.first {
                    $0.objectHandle == returnRight.leftGoalObjectHandle
                }
                guard returnRight.leftGoalObjectHandle == 12_299,
                      returnRight.collisionRadius == 10.052_409,
                      returnRight.successMessage == "Excellent!",
                      returnRight.instruction
                        == "Now Slide right until you return to the start position.",
                      returnRight.voiceSourceName == "return2.osf",
                      leftGoal?.type == 7,
                      leftGoal?.storedID == 67,
                      leftGoal?.definition?.storedIndex == 67,
                      leftGoal?.definition?.referenceRuntimeIndex == 68,
                      leftGoal?.definition?.sourceName
                        == "Invisiblepowerup",
                      leftGoal?.instanceName == "LeftGoal",
                      leftGoal?.flags == 4_352,
                      leftGoal?.location == .room(1),
                      leftGoal?.position
                        == .init(
                            x: 1_958.2805,
                            y: -131.22517,
                            z: 2_205.8071
                        ),
                      leftGoal?.orientation
                        == .init(
                            right: .init(x: -1, y: 0, z: 0),
                            up: .init(x: 0, y: 1, z: -0),
                            forward: .init(x: -0, y: -0, z: -1)
                        ),
                      leftGoalPresentation?.primaryModel
                        == .init(
                            storedIndex: 6,
                            sourceName: "invisiblepowerup.OOF"
                        ),
                      leftGoalPresentation?.isVisible == false,
                      return2?.sourceEntryIndex == 29,
                      return2?.sampleRate == 22_050,
                      return2?.channelCount == 1,
                      return2?.frameCount == 68_621,
                      return2?.pcmSHA256
                        == "ff071aa8d667e067092809982a62d1c2d93f4e2ac23c494921d5d9a77e579962",
                      return2?.sourceArchive == "missions/training.mn3",
                      return2?.sourceSHA256
                        == "095478ec99ea94f1ca2f0ac0c710f2c74b940f5cfd7b791a8af16a4c154eb547"
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 004 package"
                    )
                }
            }
            if let returnUp = lesson.returnUp {
                let startGoal = objects.first {
                    $0.handle == returnUp.startGoalObjectHandle
                }
                let startGoalPresentation = objectPresentations.first {
                    $0.objectHandle == returnUp.startGoalObjectHandle
                }
                guard returnUp.startGoalObjectHandle == 12_300,
                      returnUp.collisionRadius == 10.052_409,
                      returnUp.successMessage == "Excellent!",
                      returnUp.instruction == "Now Slide up  until you stop.",
                      returnUp.voiceSourceName == "up1.osf",
                      startGoal?.type == 7,
                      startGoal?.storedID == 67,
                      startGoal?.definition?.storedIndex == 67,
                      startGoal?.definition?.referenceRuntimeIndex == 68,
                      startGoal?.definition?.sourceName
                        == "Invisiblepowerup",
                      startGoal?.instanceName == "StartGoal",
                      startGoal?.flags == 36_864,
                      startGoal?.location == .room(1),
                      startGoal?.position
                        == .init(
                            x: 2_062.7678,
                            y: -134.19601,
                            z: 2_201.679
                        ),
                      startGoalPresentation?.primaryModel
                        == .init(
                            storedIndex: 6,
                            sourceName: "invisiblepowerup.OOF"
                        ),
                      startGoalPresentation?.isVisible == false,
                      up1?.sourceEntryIndex == 37,
                      up1?.sampleRate == 22_050,
                      up1?.channelCount == 1,
                      up1?.frameCount == 77_797,
                      up1?.sourceArchive == "missions/training.mn3",
                      up1?.sourceSHA256
                        == "ce2f2c94ca3a2b000924e1ffde8d75e1faa590188dd2d991c3fb0082f6e32876",
                      up1?.pcmSHA256
                        == "9f65aa9804b9c8819e335c6733c05db265bf7dc72dabd43c28387e3e9bc67adb"
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 005 package"
                    )
                }
            }
            if let returnDown = lesson.returnDown {
                let upGoal = objects.first {
                    $0.handle == returnDown.upGoalObjectHandle
                }
                let upGoalPresentation = objectPresentations.first {
                    $0.objectHandle == returnDown.upGoalObjectHandle
                }
                guard returnDown.upGoalObjectHandle == 18_441,
                      returnDown.collisionRadius == 10.052_409,
                      returnDown.successMessage == "Excellent!",
                      returnDown.instruction
                        == "Now Slide down until you return to the start position.",
                      returnDown.voiceSourceName == "return3.osf",
                      upGoal?.type == 7,
                      upGoal?.storedID == 67,
                      upGoal?.definition?.storedIndex == 67,
                      upGoal?.definition?.referenceRuntimeIndex == 68,
                      upGoal?.definition?.sourceName == "Invisiblepowerup",
                      upGoal?.instanceName == "UpGoal",
                      upGoal?.flags == 4_352,
                      upGoal?.location == .room(1),
                      upGoal?.position
                        == .init(
                            x: 2_060.6682,
                            y: -25.897497,
                            z: 2_204.6843
                        ),
                      upGoal?.orientation
                        == .init(
                            right: .init(x: -1, y: 0, z: 0),
                            up: .init(x: 0, y: 1, z: -0),
                            forward: .init(x: -0, y: -0, z: -1)
                        ),
                      upGoalPresentation?.primaryModel
                        == .init(
                            storedIndex: 6,
                            sourceName: "invisiblepowerup.OOF"
                        ),
                      upGoalPresentation?.isVisible == false,
                      return3?.sourceEntryIndex == 30,
                      return3?.sampleRate == 22_050,
                      return3?.channelCount == 1,
                      return3?.frameCount == 109_709,
                      return3?.pcmSHA256
                        == "6adba1f7b3881732f208938676a8c1fac3ccf7f74bc332f10868e498fecbd482",
                      return3?.sourceArchive == "missions/training.mn3",
                      return3?.sourceSHA256
                        == "be5df14b5a410e52888404e09c01cb7c6084ec8389b4cb04a1090fbae31652ea"
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 006 package"
                    )
                }
            }
            let dodgeVoiceCount = trainingDodgeAttempt.map {
                ($0.dodgeExit == nil ? 3 : 4)
                    + ($0.maneuverFollow == nil ? 0 : 5)
                    + (
                        $0.maneuverFollow?
                            .destructionHandoff == nil
                            ? 0 : 1
                    )
            } ?? 0
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
                  voiceClips.count == (
                    trainingFinalBotsCompletionChain != nil
                        ? 12
                            + (lesson.returnLeft == nil ? 0 : 1)
                            + (lesson.returnRight == nil ? 0 : 1)
                            + (lesson.returnUp == nil ? 0 : 1)
                            + (lesson.returnDown == nil ? 0 : 1)
                            + (lesson.repeatForward == nil ? 0 : 1)
                            + (lesson.repeatReturnLeft == nil ? 0 : 1)
                            + (lesson.repeatReturnUp == nil ? 0 : 1)
                            + (lesson.continueToCourse == nil ? 0 : 1)
                            + (lesson.startCourse == nil ? 0 : 1)
                            + (lesson.finishCourse == nil ? 0 : 1)
                        : trainingFinalRoomEntryChain != nil
                            ? 11
                                + (lesson.returnLeft == nil ? 0 : 1)
                                + (lesson.returnRight == nil ? 0 : 1)
                                + (lesson.returnUp == nil ? 0 : 1)
                                + (lesson.returnDown == nil ? 0 : 1)
                                + (lesson.repeatForward == nil ? 0 : 1)
                                + (lesson.repeatReturnLeft == nil ? 0 : 1)
                                + (lesson.repeatReturnUp == nil ? 0 : 1)
                                + (lesson.continueToCourse == nil ? 0 : 1)
                                + (lesson.startCourse == nil ? 0 : 1)
                                + (lesson.finishCourse == nil ? 0 : 1)
                        : (
                            trainingCameraMonitorChain == nil ? 5 : 10
                        )
                            + (lesson.returnLeft == nil ? 0 : 1)
                            + (lesson.returnRight == nil ? 0 : 1)
                            + (lesson.returnUp == nil ? 0 : 1)
                            + (lesson.returnDown == nil ? 0 : 1)
                            + (lesson.repeatForward == nil ? 0 : 1)
                            + (lesson.repeatReturnLeft == nil ? 0 : 1)
                            + (lesson.repeatReturnUp == nil ? 0 : 1)
                            + (lesson.continueToCourse == nil ? 0 : 1)
                            + (lesson.startCourse == nil ? 0 : 1)
                            + (lesson.finishCourse == nil ? 0 : 1)
                    )
                    + dodgeVoiceCount,
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
                proceed5: proceed5,
                releaseSound: soundClips.first {
                    $0.logicalName == "GBExpulsionA"
                },
                ambientEngineSound: soundClips.first {
                    $0.logicalName == "GBotEngineB1"
                },
                flareSound: soundClips.first {
                    $0.logicalName == "Flare"
                }
            )
            try validateStockTrainingRobotGuidebotPresentation(
                chain: trainingRobotGuidebotChain!,
                modelSources: models.map(\.source),
                objects: objects,
                objectPresentations: objectPresentations,
                destroyRobotIsInitiallyVisible:
                    trainingDodgeAttempt?.maneuverFollow?
                        .destructionHandoff == nil
            )
            if trainingCameraMonitorChain != nil {
                try validateStockTrainingCameraMonitorPackage(
                    chain: trainingCameraMonitorChain,
                    guidebotC: guidebotC,
                    guidebotD: guidebotD,
                    proceed6: proceed6,
                    intro6: intro6,
                    guidebotF: guidebotF,
                    pickupSound: soundClips.first {
                        $0.logicalName == "PupC1"
                    },
                    returnSound: soundClips.first {
                        $0.logicalName == "GBotAcceptOrder1"
                    },
                    greetingSound: soundClips.first {
                        $0.logicalName == "GBotGreetB1"
                    },
                    objects: objects,
                    objectPresentations: objectPresentations
                )
            }
            if trainingRASBot1DeathChain != nil {
                try validateStockTrainingRASBot1DeathPackage(
                    chain: trainingRASBot1DeathChain,
                    objects: objects,
                    objectPresentations: objectPresentations
                )
            }
            if trainingFinalRoomEntryChain != nil {
                try validateStockTrainingFinalRoomEntryPackage(
                    chain: trainingFinalRoomEntryChain,
                    intro7: intro7
                )
            }
            if trainingRASBot2DeathChain != nil {
                try validateStockTrainingRASBot2DeathPackage(
                    chain: trainingRASBot2DeathChain,
                    objects: objects,
                    objectPresentations: objectPresentations
                )
            }
            if trainingRASBot3DeathChain != nil {
                try validateStockTrainingRASBot3DeathPackage(
                    chain: trainingRASBot3DeathChain,
                    objects: objects,
                    objectPresentations: objectPresentations
                )
            }
            if trainingRASBot4DeathChain != nil {
                try validateStockTrainingRASBot4DeathPackage(
                    chain: trainingRASBot4DeathChain,
                    objects: objects,
                    objectPresentations: objectPresentations
                )
            }
            if trainingLastBot1DeathChain != nil {
                try validateStockTrainingLastBot1DeathPackage(
                    chain: trainingLastBot1DeathChain,
                    objects: objects,
                    objectPresentations: objectPresentations
                )
            }
            if trainingLastBot2DeathChain != nil {
                try validateStockTrainingLastBot2DeathPackage(
                    chain: trainingLastBot2DeathChain,
                    objects: objects,
                    objectPresentations: objectPresentations
                )
            }
            if trainingLastBot3DeathChain != nil {
                try validateStockTrainingLastBot3DeathPackage(
                    chain: trainingLastBot3DeathChain,
                    objects: objects,
                    objectPresentations: objectPresentations
                )
            }
            if trainingLastBot4DeathChain != nil {
                try validateStockTrainingLastBot4DeathPackage(
                    chain: trainingLastBot4DeathChain,
                    objects: objects,
                    objectPresentations: objectPresentations
                )
            }
            if trainingLastBot5DeathChain != nil {
                try validateStockTrainingLastBot5DeathPackage(
                    chain: trainingLastBot5DeathChain,
                    objects: objects,
                    objectPresentations: objectPresentations
                )
            }
            if trainingFinalBotsCompletionChain != nil {
                guard let room = rooms.first(where: {
                    $0.sourceIndex == 16
                }),
                      room.portals.count == 2,
                      room.portals[0].faceIndex == 0,
                      room.portals[0].connectedRoom == 45,
                      room.portals[0].connectedPortal == 9,
                      room.portals[1].faceIndex == 1,
                      room.portals[1].connectedRoom == 17,
                      room.portals[1].connectedPortal == 1,
                      let marker = objects.first(where: {
                          $0.handle == 4_118
                      }),
                      marker.position == .init(
                          x: 2_061.565_4,
                          y: -745.747_4,
                          z: 3_661.294_2
                      )
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training Scripts 035/056 stock topology"
                    )
                }
                try validateStockTrainingFinalBotsCompletionPackage(
                    chain: trainingFinalBotsCompletionChain,
                    done: done,
                    level: self
                )
            }
            if trainingFinalGoalChain != nil {
                guard let room = rooms.first(where: {
                    $0.sourceIndex == 17
                }),
                      let goal = objects.first(where: {
                          $0.handle == 6_180
                      }),
                      goal.definition?.referenceRuntimeIndex == 68,
                      goal.containsType == 255,
                      goal.containsID == 0,
                      goal.containsCount == 0,
                      goal.position == .init(
                          x: 2_061.773_4,
                          y: -756.230_65,
                          z: 3_681.408_2
                      ),
                      goal.orientation == .init(
                          right: .init(x: -1, y: 0, z: 0),
                          up: .init(x: 0, y: 1, z: 0),
                          forward: .init(x: 0, y: 0, z: -1)
                      ),
                      room.portals.count == 2,
                      room.portals[0].connectedRoom == 18,
                      room.portals[0].connectedPortal == 0,
                      room.portals[1].connectedRoom == 16,
                      room.portals[1].connectedPortal == 1
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training Script 057 stock topology"
                    )
                }
                try validateStockTrainingFinalGoalPackage(
                    chain: trainingFinalGoalChain,
                    level: self
                )
            }
            if trainingInvulnerabilityPickupChain != nil {
                let pickupSound = soundClips.first {
                    $0.logicalName == "Powerup pickup"
                }
                let activatedSound = soundClips.first {
                    $0.logicalName == "Invulnerability on"
                }
                let expiredSound = soundClips.first {
                    $0.logicalName == "Invulnerability off"
                }
                guard pickupSound?.sourceName == "Power03.wav",
                    activatedSound?.sourceName == "Invon.wav",
                    activatedSound?.importVolume == 0.5,
                    expiredSound?.sourceName == "Invoff.wav",
                    expiredSound?.importVolume == 0.5
                else {
                    throw LevelValidationError.invalidDependency(
                        "Training InvulnPowerup2 package"
                    )
                }
            }
            if trainingCloakPickupChain != nil {
                try validateStockTrainingCloakSoundPackage(
                    soundClips
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
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
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
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
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
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
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
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
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
        voiceClips: [CanonicalVoiceClip],
        soundClips addedSoundClips: [CanonicalSoundClip] = []
    ) -> Level {
        let lessonPresentations = objectPresentations.map { presentation in
            let hiddenHandles = [
                lesson.forwardGoalObjectHandle,
                lesson.returnLeft?.startGoalObjectHandle,
                lesson.returnRight?.leftGoalObjectHandle,
                lesson.returnUp?.startGoalObjectHandle,
                lesson.returnDown?.upGoalObjectHandle,
                lesson.repeatForwardGoal?.forwardGoalObjectHandle,
                lesson.repeatReturnLeft?.startGoalObjectHandle,
                lesson.repeatReturnRight?.leftGoalObjectHandle,
                lesson.repeatReturnUp?.startGoalObjectHandle,
                lesson.repeatReturnDown?.upGoalObjectHandle,
                lesson.startCourse?.startCourseObjectHandle,
                lesson.finishCourse?.finishCourseObjectHandle,
            ]
            guard hiddenHandles.contains(presentation.objectHandle) else {
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
        for clip in addedSoundClips {
            dependencies.append(
                .init(
                    category: "sound",
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
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips + addedSoundClips,
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
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
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
        voiceClips addedVoiceClips: [CanonicalVoiceClip],
        soundClips addedSoundClips: [CanonicalSoundClip] = []
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
        dependencies += addedSoundClips.map { clip in
            DependencyRecord(
                category: "sound",
                source: .init(
                    storedIndex: clip.sourceEntryIndex,
                    sourceName: clip.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance:
                    "\(clip.sourceArchive) \(clip.sourceSHA256)"
            )
        }
        if let flare = chain.yellowFlare {
            dependencies.append(.init(
                category: "weapon-definition",
                source: flare.source,
                state: "canonical-page-bound",
                provenance:
                    "manage/weaponpage.cpp:653-901; scripts/AIGame.cpp:6086-6115"
            ))
            if !dependencyManifest.current.contains(where: {
                $0.category == "texture"
                    && $0.source == flare.particleTexture
            }) {
                dependencies.append(.init(
                    category: "texture",
                    source: flare.particleTexture,
                    state: "presentation-payload-imported",
                    provenance:
                        "manage/weaponpage.cpp:653-901; viseffect.cpp:899-933"
                ))
            }
            if let timeout = flare.timeout {
                dependencies.append(.init(
                    category: "weapon-definition",
                    source: timeout.childSource,
                    state: "canonical-page-bound",
                    provenance:
                        "manage/weaponpage.cpp:653-901; Descent3/WeaponFire.cpp:3162-3201"
                ))
                for texture in [timeout.explosionTexture]
                    + (timeout.childAnimationFrames
                        ?? [timeout.childTexture])
                where !dependencyManifest.current.contains(where: {
                    $0.category == "texture" && $0.source == texture
                }) && !dependencies.contains(where: {
                    $0.category == "texture" && $0.source == texture
                }) {
                    dependencies.append(.init(
                        category: "texture",
                        source: texture,
                        state: "presentation-payload-imported",
                        provenance:
                            "manage/weaponpage.cpp:653-901; Descent3/WeaponFire.cpp:3058-3201"
                    ))
                }
            }
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
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips + addedVoiceClips,
            soundClips: soundClips + addedSoundClips,
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
        soundClips addedSoundClips: [CanonicalSoundClip]
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
        } + addedSoundClips.map { soundClip in DependencyRecord(
            category: "sound",
            source: .init(
                storedIndex: soundClip.sourceEntryIndex,
                sourceName: soundClip.sourceName
            ),
            state: "canonical-pcm-imported",
            provenance:
                "\(soundClip.sourceArchive) \(soundClip.sourceSHA256)"
        )}
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
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips + addedVoiceClips,
            soundClips: soundClips + addedSoundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingRASBot1DeathChain(
        _ chain: TrainingRASBot1DeathChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: chain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingRASBot2DeathChain(
        _ chain: TrainingRASBot2DeathChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: chain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingRASBot3DeathChain(
        _ chain: TrainingRASBot3DeathChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: chain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingRASBot4DeathChain(
        _ chain: TrainingRASBot4DeathChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: chain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingLastBot1DeathChain(
        _ chain: TrainingLastBot1DeathChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: chain,
            trainingInvulnerabilityPickupChain:
                trainingInvulnerabilityPickupChain,
            trainingCloakPickupChain: trainingCloakPickupChain,
            trainingLastRoomChain: trainingLastRoomChain,
            trainingFinalRoomEntryChain: trainingFinalRoomEntryChain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingLastBot2DeathChain(
        _ chain: TrainingLastBot2DeathChain
    ) -> Level {
        var level = self
        level.trainingLastBot2DeathChain = chain
        return level
    }

    func addingTrainingLastBot3DeathChain(
        _ chain: TrainingLastBot3DeathChain
    ) -> Level {
        var level = self
        level.trainingLastBot3DeathChain = chain
        return level
    }

    func addingTrainingLastBot4DeathChain(
        _ chain: TrainingLastBot4DeathChain
    ) -> Level {
        var level = self
        level.trainingLastBot4DeathChain = chain
        return level
    }

    func addingTrainingLastBot5DeathChain(
        _ chain: TrainingLastBot5DeathChain
    ) -> Level {
        var level = self
        level.trainingLastBot5DeathChain = chain
        return level
    }

    func addingTrainingFinalBotsCompletionChain(
        _ chain: TrainingFinalBotsCompletionChain,
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
        var level = Level(
            schemaVersion: 11,
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
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            trainingInvulnerabilityPickupChain:
                trainingInvulnerabilityPickupChain,
            trainingCloakPickupChain: trainingCloakPickupChain,
            trainingLastRoomChain: trainingLastRoomChain,
            trainingFinalRoomEntryChain: trainingFinalRoomEntryChain,
            trainingFinalBotsCompletionChain: chain,
            voiceClips: voiceClips + [voiceClip],
            soundClips: soundClips,
            dependencyManifest: .init(
                current: dependencyManifest.current + [dependency],
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
        level.trainingLastBot2DeathChain =
            trainingLastBot2DeathChain
        level.trainingLastBot3DeathChain =
            trainingLastBot3DeathChain
        level.trainingLastBot4DeathChain =
            trainingLastBot4DeathChain
        level.trainingLastBot5DeathChain =
            trainingLastBot5DeathChain
        return level
    }

    func addingTrainingFinalGoalChain(
        _ chain: TrainingFinalGoalChain
    ) -> Level {
        var level = self
        level.trainingFinalGoalChain = chain
        return level
    }

    func addingTrainingInvulnerabilityPickupChain(
        _ chain: TrainingInvulnerabilityPickupChain,
        soundClips addedSoundClips: [CanonicalSoundClip]
    ) -> Level {
        var dependencies = dependencyManifest.current
        let objectDefinition = DependencyRecord(
            category: "object-definition",
            source: .init(
                storedIndex: 3,
                sourceName: "Invulnerability"
            ),
            state: "canonical-object-definition",
            provenance:
                "training.mn3/TrainingMission.d3l handle 2076"
        )
        if !dependencies.contains(where: {
            $0.category == objectDefinition.category
                && $0.source == objectDefinition.source
        }) {
            dependencies.append(objectDefinition)
        }
        for clip in addedSoundClips {
            let reached = DependencyRecord(
                category: "sound",
                source: .init(
                    storedIndex: clip.sourceEntryIndex,
                    sourceName: clip.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance:
                    "\(clip.sourceArchive) \(clip.sourceSHA256)"
            )
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
            schemaVersion: 11,
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
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            trainingInvulnerabilityPickupChain: chain,
            voiceClips: voiceClips,
            soundClips: soundClips + addedSoundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingCloakPickupChain(
        _ chain: TrainingCloakPickupChain,
        soundClips addedSoundClips: [CanonicalSoundClip]
    ) -> Level {
        var dependencies = dependencyManifest.current
        let objectDefinition = DependencyRecord(
            category: "object-definition",
            source: .init(storedIndex: 4, sourceName: "Cloak"),
            state: "canonical-object-definition",
            provenance:
                "training.mn3/TrainingMission.d3l handle 2073"
        )
        if !dependencies.contains(where: {
            $0.category == objectDefinition.category
                && $0.source == objectDefinition.source
        }) {
            dependencies.append(objectDefinition)
        }
        for clip in addedSoundClips {
            let reached = DependencyRecord(
                category: "sound",
                source: .init(
                    storedIndex: clip.sourceEntryIndex,
                    sourceName: clip.sourceName
                ),
                state: "canonical-pcm-imported",
                provenance:
                    "\(clip.sourceArchive) \(clip.sourceSHA256)"
            )
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
            schemaVersion: 11,
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
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            trainingInvulnerabilityPickupChain:
                trainingInvulnerabilityPickupChain,
            trainingCloakPickupChain: chain,
            voiceClips: voiceClips,
            soundClips: soundClips + addedSoundClips,
            dependencyManifest: .init(
                current: dependencies,
                historicalEagerBaseline:
                    dependencyManifest.historicalEagerBaseline
            ),
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingLastRoomChain(
        _ chain: TrainingLastRoomChain
    ) -> Level {
        Level(
            schemaVersion: 11,
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
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            trainingInvulnerabilityPickupChain:
                trainingInvulnerabilityPickupChain,
            trainingCloakPickupChain: trainingCloakPickupChain,
            trainingLastRoomChain: chain,
            voiceClips: voiceClips,
            soundClips: soundClips,
            dependencyManifest: dependencyManifest,
            sourceChunks: sourceChunks
        )
    }

    func addingTrainingFinalRoomEntryChain(
        _ chain: TrainingFinalRoomEntryChain,
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
            schemaVersion: 11,
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
            trainingCameraMonitorChain: trainingCameraMonitorChain,
            trainingRASBot1DeathChain: trainingRASBot1DeathChain,
            trainingRASBot2DeathChain: trainingRASBot2DeathChain,
            trainingRASBot3DeathChain: trainingRASBot3DeathChain,
            trainingRASBot4DeathChain: trainingRASBot4DeathChain,
            trainingLastBot1DeathChain: trainingLastBot1DeathChain,
            trainingInvulnerabilityPickupChain:
                trainingInvulnerabilityPickupChain,
            trainingCloakPickupChain: trainingCloakPickupChain,
            trainingLastRoomChain: trainingLastRoomChain,
            trainingFinalRoomEntryChain: chain,
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
        let requiredTextures = requiredRoomTextures
            .union(requiredModelTextures)
            .union(
                trainingRobotGuidebotChain?.yellowFlare.map {
                    [$0.particleTexture]
                        + ($0.timeout.map {
                            [$0.explosionTexture]
                                + ($0.childAnimationFrames
                                    ?? [$0.childTexture])
                        } ?? [])
                } ?? []
            )
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

func validateStockTrainingCloakSoundPackage(
    _ soundClips: [CanonicalSoundClip]
) throws {
    let pickupSound = soundClips.first {
        $0.logicalName == "Powerup pickup"
    }
    let activatedSound = soundClips.first {
        $0.logicalName == "Cloak on"
    }
    let expiredSound = soundClips.first {
        $0.logicalName == "Cloak off"
    }
    guard pickupSound?.sourceName == "Power03.wav",
        pickupSound?.sourceEntryIndex == 2_657,
        pickupSound?.sampleRate == 22_050,
        pickupSound?.channelCount == 1,
        pickupSound?.frameCount == 15_189,
        pickupSound?.sourceArchive == "d3.hog",
        pickupSound?.sourceSHA256
            == "1e16aae37b233dd724d4baa001f48b83681fbc33eb16d21269cd52c5b7e8cea3",
        pickupSound?.pcmSHA256
            == "48908714345e648ce9e713d24b9aa66bfe763a82d961a83ca9543852bca8aadc",
        pickupSound?.importVolume == 1,
        activatedSound?.sourceName == "ShpCloakOn.wav",
        activatedSound?.sourceEntryIndex == 3_247,
        activatedSound?.sampleRate == 22_050,
        activatedSound?.channelCount == 1,
        activatedSound?.frameCount == 33_046,
        activatedSound?.sourceArchive == "d3.hog",
        activatedSound?.sourceSHA256
            == "27d19947e58370b18722fbcbe2fba64bf5094e3752a069bd1d2e1ed76e70c58e",
        activatedSound?.pcmSHA256
            == "61b52e468bfbe6bf5bd96ac158ef3ab7fd0d048fa375896c80de83df2129cdb2",
        activatedSound?.importVolume == 0.5,
        expiredSound?.sourceName == "ShpCloakOffBeep.wav",
        expiredSound?.sourceEntryIndex == 3_246,
        expiredSound?.sampleRate == 22_050,
        expiredSound?.channelCount == 1,
        expiredSound?.frameCount == 45_609,
        expiredSound?.sourceArchive == "d3.hog",
        expiredSound?.sourceSHA256
            == "29c9bb2fe254a9c2e75b8ae0f13b60627088294f075fbd74eae449e76c767154",
        expiredSound?.pcmSHA256
            == "8ca941f9d4a30f4b3431af4b86ff153b955885a23c686fa56fb7a8d0bfa0e87d",
        expiredSound?.importVolume == 0.5
    else {
        throw LevelValidationError.invalidDependency(
            "Training CloakPowerup2 package"
        )
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
            case .turret(
                let
                    fieldOfView,
                let
                    rotationsPerSecond,
                let
                    thinkInterval,
                let
                    axis
            ):
                let magnitudeSquared = dot(axis, axis)
                guard fieldOfView.isFinite,
                    (0...0.5).contains(fieldOfView),
                    rotationsPerSecond.isFinite,
                    rotationsPerSecond > 0,
                    thinkInterval.isFinite,
                    (0...10).contains(thinkInterval),
                    magnitudeSquared.isFinite,
                    abs(magnitudeSquared - 1) <= 0.000_1
                else {
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
