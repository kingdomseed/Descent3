// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct PerspectiveProjection: Codable, Equatable, Sendable {
    let horizontalFieldOfViewRadians: Float
    let aspectRatio: Float

    static let sourceDefault = PerspectiveProjection(
        horizontalFieldOfViewRadians: 3.14 * 72 / 180,
        aspectRatio: 4.0 / 3.0
    )

    static let squareNinetyDegrees = PerspectiveProjection(
        horizontalFieldOfViewRadians: .pi / 2,
        aspectRatio: 1
    )

    func withAspectRatio(_ aspectRatio: Float) -> PerspectiveProjection {
        precondition(aspectRatio.isFinite && aspectRatio > 0)
        let verticalTangent = tan(horizontalFieldOfViewRadians / 2) / self.aspectRatio
        return PerspectiveProjection(
            horizontalFieldOfViewRadians: 2 * atan(verticalTangent * aspectRatio),
            aspectRatio: aspectRatio
        )
    }
}

struct RoomCamera: Codable, Equatable, Sendable {
    let position: Vector3
    let target: Vector3
    let up: Vector3
    let projection: PerspectiveProjection

    init(
        position: Vector3,
        target: Vector3,
        up: Vector3,
        projection: PerspectiveProjection = .sourceDefault
    ) {
        self.position = position
        self.target = target
        self.up = up
        self.projection = projection
    }

    static let trainingRoom3 = RoomCamera(
        position: .init(x: 2_061.7124, y: -220.75536, z: 2_206.3005),
        target: .init(x: 2_061.7124, y: -200, z: 2_206.3005),
        up: .init(x: 0, y: 0, z: 1)
    )
}

struct PlayerView: Equatable, Sendable {
    let playerID: Int
    let objectHandle: UInt32
    let roomSourceIndex: Int
    let camera: RoomCamera
    let collisionRadius: Float
}

struct PlayerSimulationFrame: Equatable, Sendable {
    let systemsFrameDuration: Float
    let systemsGameTime: Float
    let storedFrameDuration: Float
    let gameTime: Float
    let playerView: PlayerView
    let rearViewIsActive: Bool
    let velocity: Vector3
    let angularVelocity: Vector3
    let turnrollFixedAngle: Float
    let wallContact: IndoorWallContact?
    let enabledPlayerControls: PlayerControlMask
    let showsEnabledPlayerControls: Bool
    let trainingOpeningFeedback: [TrainingOpeningFeedback]
    let playerFastHeadlight: PlayerFastHeadlightFrame?
    let shields: Float
    let energy: Float
    let afterburnerFuel: Float
    let trainingDodgeMarkerLightDistance: Float?
    let trainingDodgeTurretAngles: [Float]
    let trainingDodgeProjectiles: [TrainingDodgeProjectileFrame]
    let trainingPrimaryProjectiles: [TrainingBlueLaserProjectileFrame]
    let playerConcussionMissiles: [PlayerConcussionMissileFrame]
    let playerConcussionExplosions: [PlayerConcussionExplosionFrame]
    let playerConcussionSparks: [PlayerConcussionSparkFrame]
    let trainingGuidebotYellowFlares:
        [TrainingGuidebotYellowFlareFrame]
    let trainingGuidebotYellowFlareParticles:
        [TrainingGuidebotYellowFlareParticleFrame]
    let trainingGuidebotYellowFlareTimeoutExplosions:
        [TrainingGuidebotYellowFlareParticleFrame]
    let trainingGuidebotYellowFlareTimeoutSparks:
        [TrainingGuidebotYellowFlareTimeoutSparkFrame]
    let trainingGuidebotYellowFlareTimeoutSparkParticles:
        [TrainingGuidebotYellowFlareParticleFrame]
    let trainingFollowBot: TrainingFollowBotFrame?
    let trainingMovingTarget: TrainingMovingTargetFrame?
    let trainingGalleryMarkerLightDistance: Float?
    let trainingGuidebotReturnMarkerLightDistance: Float?
    let trainingGuidebot: TrainingGuidebotFrame?
    let trainingGuidebotAmbientEngineIsActive: Bool
    let trainingCameraMonitor: TrainingCameraMonitorFrame?
    let trainingInvulnerabilityRemaining: Float?
    let trainingCloak: TrainingCloakFrame?
    let trainingLastRoomMarkerLightDistance: Float?
    let trainingFinalBotsMarkerLightDistance: Float?
    let trainingFinalGoal: TrainingFinalGoalFrame?
}

struct PlayerFastHeadlightFrame: Equatable, Sendable {
    let roomSourceIndex: Int
    let position: Vector3
    let lightDistance: Float
}

enum TrainingFollowBotPathFailure: String, Codable, Equatable, Sendable {
    case invalidPath
    case movementBlocked
}

struct TrainingFollowBotFrame: Equatable, Sendable {
    let isPowered: Bool
    let teamFlags: UInt32
    let roomSourceIndex: Int
    let position: Vector3
    let orientation: Matrix3
    let velocity: Vector3
    let activePathIndex: Int?
    let pathNodeIndex: Int
    let objectTimerRemaining: Float?
    let pathFailure: TrainingFollowBotPathFailure?
    let script021Count: Int
    let script022Count: Int
    let script024Count: Int
    let script023Count: Int
    let script025Count: Int
    let script026Count: Int
}

struct TrainingDodgeProjectileFrame: Equatable, Sendable {
    let position: Vector3
    let velocity: Vector3
    let roomSourceIndex: Int
    let model: SourceResource
}

struct TrainingBlueLaserProjectileFrame: Equatable, Sendable {
    let position: Vector3
    let velocity: Vector3
    let roomSourceIndex: Int
    let model: SourceResource
}

struct PlayerConcussionMissileFrame: Equatable, Sendable {
    let roomSourceIndex: Int
    let position: Vector3
    let orientation: Matrix3
    let velocity: Vector3
    let model: SourceResource
    let lightDistance: Float
    let lightPresentation: TrainingMarkerLightPresentation
}

struct PlayerConcussionExplosionFrame: Equatable, Sendable {
    let roomSourceIndex: Int
    let position: Vector3
    let size: Float
    let texture: SourceResource
}

struct PlayerConcussionSparkFrame: Equatable, Sendable {
    let roomSourceIndex: Int
    let start: Vector3
    let end: Vector3
}

struct TrainingGuidebotYellowFlareFrame: Equatable, Sendable {
    let roomSourceIndex: Int
    let position: Vector3
    let orientation: Matrix3
    let velocity: Vector3
    let model: SourceResource
    let collisionRadius: Float
    let lifeRemaining: Float
    let sourceLightDistance: Float
    let lightDistance: Float
    let lightPresentation: TrainingMarkerLightPresentation
}

struct TrainingGuidebotYellowFlareParticleFrame:
    Equatable, Sendable
{
    let roomSourceIndex: Int
    let position: Vector3
    let size: Float
    let lifeRemaining: Float
    let lifetime: Float
    let sourceSize: Float
    let sourceLifetime: Float
    let texture: SourceResource
    let opacity: Float
}

struct TrainingGuidebotYellowFlareTimeoutSparkFrame:
    Equatable, Sendable
{
    let sourceAttemptIndex: Int
    let sourceObjectSlot: Int
    let receivedControlOnCreationFrame: Bool
    let roomSourceIndex: Int
    let position: Vector3
    let orientation: Matrix3
    let velocity: Vector3
    let collisionRadius: Float
    let lifeRemaining: Float
    let texture: SourceResource
    let sourceLightDistance: Float
    let lightDistance: Float
    let lightPresentation: TrainingMarkerLightPresentation
}

struct TrainingMovingTargetFrame: Equatable, Sendable {
    let objectHandle: UInt32
    let roomSourceIndex: Int
    let activePathIndex: Int
    let pathNodeIndex: Int
    let pathFailure: TrainingFollowBotPathFailure?
}

enum TrainingEndLevelState: String, Codable, Equatable, Sendable {
    case succeeded
}

enum TrainingDifficulty: String, Codable, Equatable, Sendable {
    case rookie = "Rookie"
}

struct TrainingEndLevelPresentation: Equatable, Sendable {
    let title: String
    let levelName: String
    let difficulty: TrainingDifficulty
    let showsHUD: Bool
    let playsGameplayAudio: Bool
    let showsCockpit: Bool
    let showsHeadlightIndicator: Bool
}

struct TrainingPostLevelResult: Equatable, Sendable {
    let title: String
    let levelName: String
    let difficulty: TrainingDifficulty
    let score: Int
    let elapsedTime: Float
    let enemyKills: Int
    let shields: Float
    let energy: Float
    let deaths: Int
    let restores: Int
    let objectives: [String]
}

enum TrainingSessionOutcome: Equatable, Sendable {
    case awaitingResultAcknowledgement
    case completed
}

struct TrainingFinalGoalFrame: Equatable, Sendable {
    let endLevelState: TrainingEndLevelState
    let scriptActionCounter: Int
    let controlsAreSuspended: Bool
    let presentation: TrainingEndLevelPresentation
    let postLevelResult: TrainingPostLevelResult
}

enum TrainingCloakPhase: String, Codable, Equatable, Sendable {
    case fadingOut
    case cloaked
    case fadingIn
}

struct TrainingCloakFrame: Equatable, Sendable {
    let phase: TrainingCloakPhase
    let phaseRemaining: Float
    let phaseDuration: Float

    var objectAlpha: Float {
        switch phase {
        case .fadingOut:
            0.08 + 0.92 * phaseRemaining / phaseDuration
        case .cloaked:
            0.13
        case .fadingIn:
            0.08 + 0.92 * (1 - phaseRemaining / phaseDuration)
        }
    }

    var objectDeformationRange: Float {
        phase == .cloaked ? 0.1 : 0
    }
}

struct TrainingOpeningFeedback: Equatable, Sendable {
    let hudMessages: [String]
    let voiceSourceName: String
    let voicePrecedesHUDMessages: Bool
    let trailingHUDMessages: [String]
    let soundSourceName: String?
    let soundEventVolume: Float?

    init(
        hudMessages: [String],
        voiceSourceName: String,
        voicePrecedesHUDMessages: Bool,
        trailingHUDMessages: [String] = [],
        soundSourceName: String? = nil,
        soundEventVolume: Float? = nil
    ) {
        self.hudMessages = hudMessages
        self.voiceSourceName = voiceSourceName
        self.voicePrecedesHUDMessages = voicePrecedesHUDMessages
        self.trailingHUDMessages = trailingHUDMessages
        self.soundSourceName = soundSourceName
        self.soundEventVolume = soundEventVolume
    }
}

struct TrainingCameraMonitorFrame: Equatable, Sendable {
    let camera: RoomCamera
    let roomSourceIndex: Int
    let remainingDuration: Float
}

enum TrainingGuidebotRouteMode: String, Codable, Equatable, Sendable {
    case direct
    case boundaryNodes
    case roomPortals
}

struct IndoorNavigationNodeReference:
    Codable, Equatable, Hashable, Sendable
{
    let roomSourceIndex: Int
    let nodeIndex: Int
}

struct TrainingGuidebotRoute: Codable, Equatable, Sendable {
    let mode: TrainingGuidebotRouteMode
    let points: [Vector3]
    let roomSourceIndices: [Int]
    let nodeReferences: [IndoorNavigationNodeReference]
}

enum TrainingGuidebotSteeringMode:
    String, Codable, Equatable, Sendable
{
    case direct
    case allocatedRoute
    case stopped
}

struct TrainingGuidebotFrame: Equatable, Sendable {
    let spawnPosition: Vector3
    let roomSourceIndex: Int
    let position: Vector3
    let orientation: Matrix3
    let spawnVelocity: Vector3
    let velocity: Vector3
    let destination: Vector3
    let route: TrainingGuidebotRoute
    let routeFailure: TrainingGuidebotRouteError?
    let activeSteeringMode: TrainingGuidebotSteeringMode
}

enum TrainingGuidebotRouteError:
    String, Error, Codable, Equatable, Sendable
{
    case noBOAPath
    case unverifiedBoundaryNodes
    case noVisibleBoundaryNode
    case noBoundaryNodePath
    case noRoomPortalPath
}

func defaultPlayerView(
    in level: Level,
    projection: PerspectiveProjection = .sourceDefault
) -> PlayerView {
    let binding = level.defaultPlayerBinding!
    let object = level.objects.first { $0.handle == binding.objectHandle }!
    let ship = level.shipDefinitions.first { $0.source == binding.ship }!
    guard case let .room(roomSourceIndex) = object.location else {
        preconditionFailure("The validated default player start is indoor.")
    }
    return PlayerView(
        playerID: binding.playerID,
        objectHandle: object.handle,
        roomSourceIndex: roomSourceIndex,
        camera: RoomCamera(
            position: object.position,
            target: object.position + object.orientation.forward,
            up: object.orientation.up,
            projection: projection
        ),
        collisionRadius: ship.presentationSize * 0.8
    )
}

func rearPlayerView(_ playerView: PlayerView) -> PlayerView {
    let camera = playerView.camera
    return PlayerView(
        playerID: playerView.playerID,
        objectHandle: playerView.objectHandle,
        roomSourceIndex: playerView.roomSourceIndex,
        camera: RoomCamera(
            position: camera.position,
            target: camera.position - (camera.target - camera.position),
            up: camera.up,
            projection: camera.projection
        ),
        collisionRadius: playerView.collisionRadius
    )
}
