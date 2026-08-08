import Foundation

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

