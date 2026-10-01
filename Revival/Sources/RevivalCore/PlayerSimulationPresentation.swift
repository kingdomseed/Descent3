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
    /// The custom weapon explosions and the particles among the visual
    /// effects.
    let visEffectBillboards: [BillboardFrame]
    /// The fading line sparks among the visual effects.
    let visEffectLineSparks: [VisEffectLineSparkFrame]
    /// The bitmap and vclip weapons (DrawWeaponObject).
    let weaponBillboards: [BillboardFrame]
    /// The lights DoObjectLight cast this frame (ObjectLighting.swift).
    let objectLights: [ObjectLightRequest]
    /// The playing looping sounds linked to an object (SoundSystem.swift),
    /// at the object's place this frame.
    let objectSoundLoops: [ObjectSoundLoopFrame]
    let trainingCameraMonitor: TrainingCameraMonitorFrame?
    let trainingInvulnerabilityRemaining: Float?
    let trainingCloak: TrainingCloakFrame?
    let trainingFinalGoal: TrainingFinalGoalFrame?
}

struct PlayerFastHeadlightFrame: Equatable, Sendable {
    let roomSourceIndex: Int
    let position: Vector3
    let lightDistance: Float
}

/// A camera-facing bitmap at its current frame: a custom explosion or a
/// particle (DrawVisEffect, viseffect.cpp:1900), or a bitmap or vclip
/// weapon (DrawWeaponObject, WeaponFire.cpp:2589). `opacity` scales the
/// texture's own alpha.
struct BillboardFrame: Equatable, Sendable {
    let roomSourceIndex: Int
    let position: Vector3
    let size: Float
    let texture: SourceResource
    let opacity: Float
}

/// A fading line spark (FADING_LINE_INDEX), drawn from its position back
/// along its velocity by its size.
struct VisEffectLineSparkFrame: Equatable, Sendable {
    let roomSourceIndex: Int
    let start: Vector3
    let end: Vector3
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

struct TrainingPostLevelResult: Codable, Equatable, Sendable {
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

enum TrainingSessionOutcome: Codable, Equatable, Sendable {
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

/// A looping object sound for the app to play at the object's place.
struct ObjectSoundLoopFrame: Equatable, Sendable {
    /// The sound handle.
    let handle: Int32
    /// The sound clip's logical name.
    let soundName: String
    let roomSourceIndex: Int
    let position: Vector3
}

/// The player view at the level's initial placement.
func defaultPlayerView(
    in level: Level,
    projection: PerspectiveProjection = .sourceDefault
) -> PlayerView {
    defaultPlayerView(
        in: level,
        objects: ObjectTable(level: level),
        projection: projection
    )
}

/// The player view at the player's current object in `objects`.
func defaultPlayerView(
    in level: Level,
    objects: ObjectTable,
    projection: PerspectiveProjection = .sourceDefault
) -> PlayerView {
    let binding = level.defaultPlayerBinding!
    let object = objects[ObjectHandle(binding.objectHandle)]!
    let ship = level.shipDefinitions.first { $0.source == binding.ship }!
    guard case let .room(roomSourceIndex) = object.location else {
        preconditionFailure("The validated default player start is indoor.")
    }
    return PlayerView(
        playerID: binding.playerID,
        objectHandle: object.handle.rawValue,
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
