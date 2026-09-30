// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct TrainingGalleryBarrierState: Codable, Equatable, Sendable {
    var wasTriggered = false
    var markerLightDistance: Float
}

struct TrainingRobotGuidebotState: Codable, Equatable, Sendable {
    var robotWasDestroyed = false
    var robotShields: Float
    var nextPrimaryFireTime: Float = 0
    var projectiles: [TrainingLaserProjectileState] = []
    var guidebotIsDeployed = false
    var guidebot: TrainingGuidebotRuntimeState?
    var guidebotContinuationWasPresented = false
    var activeGoalWasReached: Bool? = nil
    var guidebotMode: TrainingGuidebotMode? = nil
    var guidebotModeTime: Float? = nil
    var nextAmbientTime: Float? = nil
    var timeUntilNextPlayerVisibilityCheck: Float? = nil
    var timeUntilNextFlare: Float? = nil
    var yellowFlareGoalSlots:
        TrainingGuidebotYellowFlareGoalSlots? = nil
    var yellowFlares:
        [TrainingGuidebotYellowFlareState]? = nil
    var yellowFlareParticles:
        [TrainingGuidebotYellowFlareParticleState]? = nil
    var yellowFlareTimeoutExplosions:
        [TrainingGuidebotYellowFlareTimeoutExplosionState]? = nil
    var yellowFlareTimeoutSparks:
        [TrainingGuidebotYellowFlareTimeoutSparkState]? = nil
    var yellowFlareTimeoutSparkParticles:
        [TrainingGuidebotYellowFlareParticleState]? = nil
    var yellowFlareTimeoutReachedFollowingFrame: Bool? = nil
    var nextPowerupCheckTime: Float? = nil
    var lastMessageSoundTime: Float? = nil
    var returnTime: Float? = nil
    var returnGreetingWasPresented: Bool? = nil
    var returnWasRequested = false
    var guidebotEnteredShip = false
    var arrivalFeedbackWasPresented = false
    var controlsWereRestored = false
    var enabledControlHUDIsVisible = true
    var destructionTimerRemaining: Float?
    var destructionFeedbackWasPresented = false
}

struct TrainingGuidebotYellowFlareGoalSlots:
    Codable, Equatable, Sendable
{
    var slot1IsUsed: Bool
    var slot2IsUsed: Bool
    var slot3IsUsed: Bool

    var isEligible: Bool {
        slot1IsUsed && !slot2IsUsed && !slot3IsUsed
    }
}

struct TrainingGuidebotYellowFlareState:
    Codable, Equatable, Sendable
{
    var roomSourceIndex: Int
    var position: Vector3
    var orientation: Matrix3
    var velocity: Vector3
    var lifeRemaining: Float
    var lastParticleDropTime: Float
    var presentedLightDistance: Float
    var stuckObjectHandle: UInt32? = nil
    var stuckObjectOffset: Vector3? = nil
    var stuckObjectOrientation: Matrix3? = nil
    var sourceObjectSlot: Int? = nil
    var creationOrdinal: UInt64? = nil
    var parentObjectHandle: UInt32? = nil
}

enum YellowFlareAdvanceSelection {
    case all
    case none
    case ordinal(UInt64)

    func includes(_ ordinal: UInt64?) -> Bool {
        switch self {
        case .all:
            true
        case .none:
            false
        case .ordinal(let selected):
            ordinal == selected
        }
    }
}

struct TrainingGuidebotYellowFlareParticleState:
    Codable, Equatable, Sendable
{
    let roomSourceIndex: Int
    var position: Vector3
    var velocity: Vector3
    let size: Float
    let lifetime: Float
    var lifeRemaining: Float
    var creationTime: Float? = nil
    var generationOrdinal: UInt64? = nil
    var sourceAttemptIndex: Int? = nil
}

struct TrainingGuidebotYellowFlareTimeoutExplosionState:
    Codable, Equatable, Sendable
{
    let roomSourceIndex: Int
    let position: Vector3
    let size: Float
    let lifetime: Float
    var lifeRemaining: Float
    var creationTime: Float? = nil
    var generationOrdinal: UInt64? = nil
}

struct TrainingGuidebotYellowFlareTimeoutSparkState:
    Codable, Equatable, Sendable
{
    let sourceAttemptIndex: Int
    let sourceObjectSlot: Int
    let receivedControlOnCreationFrame: Bool
    var roomSourceIndex: Int
    var position: Vector3
    let orientation: Matrix3
    var velocity: Vector3
    var lifeRemaining: Float
    var lastParticleDropTime: Float
    var presentedLightDistance: Float
    var generationOrdinal: UInt64? = nil
}

struct PlayerYellowFlareState: Codable, Equatable, Sendable {
    var nextCreationOrdinal: UInt64 = 0
    var nextFireTime: Float = 0
    var parents: [TrainingGuidebotYellowFlareState] = []
    var parentParticles: [TrainingGuidebotYellowFlareParticleState] = []
    var timeoutExplosions:
        [TrainingGuidebotYellowFlareTimeoutExplosionState] = []
    var timeoutSparks: [TrainingGuidebotYellowFlareTimeoutSparkState] = []
    var timeoutSparkParticles:
        [TrainingGuidebotYellowFlareParticleState] = []
}

struct PlayerConcussionMissileState:
    Codable, Equatable, Sendable
{
    let creationOrdinal: UInt64
    var roomSourceIndex: Int
    var position: Vector3
    var orientation: Matrix3
    let velocity: Vector3
    var lifeRemaining: Float
}

struct PlayerConcussionExplosionState:
    Codable, Equatable, Sendable
{
    let creationOrdinal: UInt64
    let roomSourceIndex: Int
    let position: Vector3
    var lifeRemaining: Float
    var shockwaveLifeRemaining: Float
    var damagedObjectHandles: Set<UInt32> = []
    var damagedPlayer = false
    /// False when the visual explosion could not be allocated. The entry
    /// then carries only the shockwave, which DoWeaponExploded creates
    /// before the visual (`WeaponFire.cpp:3066`).
    var isPresented = true
}

struct PlayerConcussionSparkState:
    Codable, Equatable, Sendable
{
    let creationOrdinal: UInt64
    let roomSourceIndex: Int
    var position: Vector3
    var velocity: Vector3
    let size: Float
    let lifetime: Float
    var lifeRemaining: Float
}

struct PlayerConcussionState: Codable, Equatable, Sendable {
    var ammo = 6
    var nextFireTime: Float = 0
    var nextFiringMaskIndex = 0
    var nextCreationOrdinal: UInt64 = 0
    var missiles: [PlayerConcussionMissileState] = []
    var explosions: [PlayerConcussionExplosionState] = []
    var sparks: [PlayerConcussionSparkState] = []
}

let playerConcussionExplosionPresentationCapacity = 6
let playerConcussionSparkPresentationCapacity = 48
let trainingGuidebotYellowFlarePresentationCapacity = 6
let trainingGuidebotYellowFlareParticlePresentationCapacity = 64
let trainingGuidebotYellowFlareTimeoutExplosionPresentationCapacity = 1
let trainingGuidebotYellowFlareTimeoutSparkPresentationCapacity = 9
let trainingGuidebotYellowFlareTimeoutSparkParticlePresentationCapacity = 54
let playerYellowFlarePresentationCapacity = 16
let playerYellowFlareParticlePresentationCapacity = 208
let playerYellowFlareTimeoutExplosionPresentationCapacity = 16
let playerYellowFlareTimeoutSparkPresentationCapacity = 144
let playerYellowFlareTimeoutSparkParticlePresentationCapacity = 864
let combinedYellowFlarePresentationCapacity = 22
let combinedYellowFlareParticlePresentationCapacity = 272
let combinedYellowFlareTimeoutExplosionPresentationCapacity = 17
let combinedYellowFlareTimeoutSparkPresentationCapacity = 153
let combinedYellowFlareTimeoutSparkParticlePresentationCapacity = 918

struct TrainingCameraMonitorState:
    Codable, Equatable, Sendable
{
    var isHeld = false
    var wasUsed = false
    var popupRemaining: Float?
    var completionTimerRemaining: Float?
    var completionTimerWasConsumed = false
    var returnMarkerLightDistance: Float = 0
    var script058WasPresented = false
}

struct TrainingKillbotEntryState:
    Codable, Equatable, Sendable
{
    var wasTriggered = false
    var followupTimerRemaining: Float?
    var followupWasPresented = false
}

struct TrainingRobotDeathState:
    Codable, Equatable, Sendable
{
    var wasDestroyed = false
    var shields: Float
}

typealias TrainingRASBot1DeathState = TrainingRobotDeathState
typealias TrainingRASBot2DeathState = TrainingRobotDeathState
typealias TrainingRASBot3DeathState = TrainingRobotDeathState
typealias TrainingRASBot4DeathState = TrainingRobotDeathState
typealias TrainingLastBot1DeathState = TrainingRobotDeathState
typealias TrainingLastBot2DeathState = TrainingRobotDeathState
typealias TrainingLastBot3DeathState = TrainingRobotDeathState
typealias TrainingLastBot4DeathState = TrainingRobotDeathState
typealias TrainingLastBot5DeathState = TrainingRobotDeathState

struct TrainingInvulnerabilityPickupState:
    Codable, Equatable, Sendable
{
    var scriptWasTriggered = false
    var wasConsumed = false
    var remainingDuration: Float?
}

struct TrainingCloakPickupState:
    Codable, Equatable, Sendable
{
    var scriptWasTriggered = false
    var wasConsumed = false
    var phase: TrainingCloakPhase?
    var phaseRemaining: Float?
}

struct TrainingLastRoomState: Codable, Equatable, Sendable {
    var wasTriggered = false
    var markerLightDistance: Float = 0
    var timerRemaining: Float?
    var wasPresented = false
}

struct TrainingFinalBotsCompletionState:
    Codable, Equatable, Sendable
{
    var wasTriggered = false
    var markerLightDistance: Float = 0
    var timerRemaining: Float?
    var wasPresented = false
}

struct TrainingFinalGoalState:
    Codable, Equatable, Sendable
{
    var endLevelWasRequested = false
    var scriptActionCounter = 0
}

struct TrainingFinalRoomEntryState:
    Codable, Equatable, Sendable
{
    var wasTriggered = false
}

enum TrainingGuidebotTask: String, Codable, Equatable, Sendable {
    case outbound
    case activeGoal
    case returnToPlayer
    case escortPlayer
    case returnToShip
}

enum TrainingGuidebotMode: String, Codable, Equatable, Sendable {
    case birth
    case ambient
}

enum TrainingGuidebotAdvanceEvent: Equatable {
    case reachedActiveGoal
    case returnedToPlayer
    case enteredShip
}

struct TrainingGuidebotRuntimeState:
    Codable, Equatable, Sendable
{
    let spawnPosition: Vector3
    var roomSourceIndex: Int
    var position: Vector3
    let orientation: Matrix3
    let spawnVelocity: Vector3
    var velocity: Vector3
    var destination: Vector3
    var route: TrainingGuidebotRoute
    var routeFailure: TrainingGuidebotRouteError?
    var routePointIndex: Int
    var activeSteeringMode: TrainingGuidebotSteeringMode
    var task: TrainingGuidebotTask
    var allocationStartPosition: Vector3
    var allocationStartForward: Vector3
    var routeDestination: Vector3
    var routeDestinationRoomSourceIndex: Int

    var frame: TrainingGuidebotFrame {
        .init(
            spawnPosition: spawnPosition,
            roomSourceIndex: roomSourceIndex,
            position: position,
            orientation: orientation,
            spawnVelocity: spawnVelocity,
            velocity: velocity,
            destination: destination,
            route: route,
            routeFailure: routeFailure,
            activeSteeringMode: activeSteeringMode
        )
    }
}

struct TrainingLaserProjectileState:
    Codable, Equatable, Sendable
{
    var roomSourceIndex: Int
    var position: Vector3
    let velocity: Vector3
    var lifeRemaining: Float
}

/// The bespoke follow-bot destruction chain (TrainingMission.cpp Scripts
/// 037, 027, and 028), until M1 step 7 translates robot death. The robots
/// move by their AI follow-path goals.
struct TrainingFollowBotDestructionState:
    Codable, Equatable, Sendable
{
    var followBotShields: Float
    var followBotWasDestroyed = false
    var script037Count = 0
    var script027Count = 0
    var levelTimer11Remaining: Float?
    var destroyBot2IsVisible = false
    var destroyBot1IsVisible = false
    var destroyBot1Destruction: TrainingDestroyBot1DestructionState? = nil
}

struct TrainingDestroyBot1DestructionState:
    Codable, Equatable, Sendable
{
    var destroyBot1Shields: Float
    var destroyBot1WasDestroyed = false
    var script028Count = 0
}

struct PlayerRearViewState: Codable, Equatable, Sendable {
    var leaveMode: Bool
    let entryGameTime: Float
}

enum IndoorAutoLevelMode: Int, Codable, Sendable {
    case off = 0
    case standard = 1
    case newPlayer = 2
}

extension GameWorld {
    /// The level-start state of the bespoke Training script types. Later M1
    /// steps replace these with the Training level module.
    mutating func initializeTrainingState(level: Level) {
        trainingFollowBotDestructionState =
            level.trainingFollowBotDestruction.map {
                TrainingFollowBotDestructionState(
                    followBotShields: $0.combat.robotShields
                )
            }
        trainingGalleryBarrierState = level.trainingGalleryBarrier.map {
            TrainingGalleryBarrierState(
                markerLightDistance:
                    trainingGalleryBarrierRendersFaces(
                        in: level,
                        barrier: $0
                    )
                    ? 0
                    : $0.openMarkerLightDistance
            )
        }
        trainingRobotGuidebotState = level.trainingRobotGuidebotChain.map {
            TrainingRobotGuidebotState(
                robotShields: $0.combat.robotShields,
                yellowFlares: $0.yellowFlare == nil ? nil : [],
                yellowFlareParticles:
                    $0.yellowFlare == nil ? nil : [],
                yellowFlareTimeoutExplosions:
                    $0.yellowFlare?.timeout == nil ? nil : [],
                yellowFlareTimeoutSparks:
                    $0.yellowFlare?.timeout == nil ? nil : [],
                yellowFlareTimeoutSparkParticles:
                    $0.yellowFlare?.timeout == nil ? nil : [],
                yellowFlareTimeoutReachedFollowingFrame:
                    $0.yellowFlare?.timeout == nil ? nil : false,
                lastMessageSoundTime: 0
            )
        }
        trainingCameraMonitorState = level.trainingCameraMonitorChain.map {
            _ in TrainingCameraMonitorState()
        }
        trainingKillbotEntryState =
            level.trainingCameraMonitorChain?.returnToShip?.killbotEntry.map {
                _ in TrainingKillbotEntryState()
            }
        trainingRASBot1DeathState = level.trainingRASBot1DeathChain.map {
            TrainingRASBot1DeathState(shields: $0.combat.robotShields)
        }
        trainingRASBot2DeathState = level.trainingRASBot2DeathChain.map {
            TrainingRASBot2DeathState(shields: $0.combat.robotShields)
        }
        trainingRASBot3DeathState = level.trainingRASBot3DeathChain.map {
            TrainingRASBot3DeathState(shields: $0.combat.robotShields)
        }
        trainingRASBot4DeathState = level.trainingRASBot4DeathChain.map {
            TrainingRASBot4DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot1DeathState = level.trainingLastBot1DeathChain.map {
            TrainingLastBot1DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot2DeathState = level.trainingLastBot2DeathChain.map {
            TrainingLastBot2DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot3DeathState = level.trainingLastBot3DeathChain.map {
            TrainingLastBot3DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot4DeathState = level.trainingLastBot4DeathChain.map {
            TrainingLastBot4DeathState(shields: $0.combat.robotShields)
        }
        trainingLastBot5DeathState = level.trainingLastBot5DeathChain.map {
            TrainingLastBot5DeathState(shields: $0.combat.robotShields)
        }
        trainingInvulnerabilityPickupState =
            level.trainingInvulnerabilityPickupChain.map {
                _ in TrainingInvulnerabilityPickupState()
            }
        trainingCloakPickupState = level.trainingCloakPickupChain.map {
            _ in TrainingCloakPickupState()
        }
        trainingLastRoomState = level.trainingLastRoomChain.map {
            _ in TrainingLastRoomState()
        }
        trainingFinalRoomEntryState =
            level.trainingFinalRoomEntryChain.map {
                _ in TrainingFinalRoomEntryState()
            }
        trainingFinalBotsCompletionState =
            level.trainingFinalBotsCompletionChain.map {
                _ in TrainingFinalBotsCompletionState()
            }
        trainingFinalGoalState = level.trainingFinalGoalChain.map {
            _ in TrainingFinalGoalState()
        }
    }
}

func trainingGalleryBarrierRendersFaces(
    in level: Level,
    barrier: TrainingGalleryBarrier
) -> Bool {
    let room = level.rooms.first {
        $0.sourceIndex == barrier.barrierRoomSourceIndex
    }!
    return barrier.orderedPortalIndices.allSatisfy {
        room.portals[$0].flags & 1 != 0
    }
}
