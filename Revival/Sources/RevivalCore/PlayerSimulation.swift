// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

private func initialTrainingManeuverFollowState(
    level: Level,
    lesson: TrainingManeuverFollowLesson
) -> TrainingManeuverFollowState? {
    guard let followBot = level.objects.first(where: {
        $0.handle == lesson.followBotObjectHandle
    }),
          case let .room(roomSourceIndex) = followBot.location
    else {
        return nil
    }
    var state = TrainingManeuverFollowState(
        roomSourceIndex: roomSourceIndex,
        position: followBot.position,
        orientation: followBot.orientation
    )
    if let handoff = lesson.destructionHandoff,
       let destroyBot1 = level.objects.first(where: {
           $0.handle == handoff.destroyBot1ObjectHandle
       }),
       case let .room(destroyBot1Room) = destroyBot1.location {
        state.destruction = .init(
            followBotShields: handoff.combat.robotShields,
            destroyBot1Motion: .init(
                roomSourceIndex: destroyBot1Room,
                position: destroyBot1.position,
                orientation: destroyBot1.orientation
            )
        )
    }
    return state
}

func initialTrainingDestroyBot1DestructionState(
    level: Level,
    handoff: TrainingFollowBotDestructionHandoff
) -> TrainingDestroyBot1DestructionState? {
    guard let destroyBot2 = level.objects.first(where: {
        $0.handle == handoff.destroyBot2ObjectHandle
    }),
          case let .room(roomSourceIndex) = destroyBot2.location
    else {
        return nil
    }
    return .init(
        destroyBot1Shields: handoff.combat.robotShields,
        destroyBot2Motion: .init(
            roomSourceIndex: roomSourceIndex,
            position: destroyBot2.position,
            orientation: destroyBot2.orientation
        )
    )
}
private func playerSimulationContinuationSchema(for level: Level) -> Int {
    if level.trainingRASBot1DeathChain != nil {
        return 7
    }
    if level.trainingCameraMonitorChain?.returnToShip?
        .killbotEntry != nil {
        return 6
    }
    if level.trainingCameraMonitorChain?.returnToShip != nil {
        return 5
    }
    return level.trainingCameraMonitorChain == nil ? 3 : 4
}
final class PlayerSimulation {
    var level: Level
    var frameDuration: Float = 0.1
    var gameTime: Float = 0
    var velocity = Vector3.zero
    var angularVelocity: Vector3
    var turnrollFixedAngle: Float = 0
    private(set) var indoorAutoLevelMode = IndoorAutoLevelMode.newPlayer
    var afterburnerFuel: Float = 5
    var afterburnerIsActive = false
    var energy: Float = 100
    var shields: Float = 100
    var trainingSessionOutcome: TrainingSessionOutcome?
    var afterburnerMagnitude: Float = 0
    var wiggleFalloff: Float = 0

    var lastTimestamp: Double
    var lastThrustTime: Float = 0
    var authoritativeRandomState: UInt32
    var playerHeadlightIsOn = false
    var playerRearViewState: PlayerRearViewState?
    var pauseDepth = 0
    private var pauseTimestamp: Double?
    var trainingOpeningState: TrainingOpeningState?
    var trainingDodgeAttemptState: TrainingDodgeAttemptState?
    var trainingManeuverFollowState:
        TrainingManeuverFollowState?
    var trainingGalleryBarrierState: TrainingGalleryBarrierState?
    var trainingRobotGuidebotState: TrainingRobotGuidebotState?
    var playerConcussionState: PlayerConcussionState?
    var playerYellowFlareState: PlayerYellowFlareState?
    var trainingCameraMonitorState: TrainingCameraMonitorState?
    var trainingKillbotEntryState: TrainingKillbotEntryState?
    var trainingRASBot1DeathState: TrainingRASBot1DeathState?
    var trainingRASBot2DeathState: TrainingRASBot2DeathState?
    var trainingRASBot3DeathState: TrainingRASBot3DeathState?
    var trainingRASBot4DeathState: TrainingRASBot4DeathState?
    var trainingLastBot1DeathState: TrainingLastBot1DeathState?
    var trainingLastBot2DeathState: TrainingLastBot2DeathState?
    var trainingLastBot3DeathState: TrainingLastBot3DeathState?
    var trainingLastBot4DeathState: TrainingLastBot4DeathState?
    var trainingLastBot5DeathState: TrainingLastBot5DeathState?
    var trainingInvulnerabilityPickupState: TrainingInvulnerabilityPickupState?
    var trainingCloakPickupState: TrainingCloakPickupState?
    var trainingLastRoomState: TrainingLastRoomState?
    var trainingFinalRoomEntryState:
        TrainingFinalRoomEntryState?
    var trainingFinalBotsCompletionState:
        TrainingFinalBotsCompletionState?
    var trainingFinalGoalState: TrainingFinalGoalState?
    var trainingPostLevelResult: TrainingPostLevelResult?

    init(
        level: Level,
        presentationReadyTimestamp: Double,
        authoritativeRandomSeed: UInt32 = 1
    ) {
        precondition(presentationReadyTimestamp.isFinite)
        precondition(level.defaultPlayerBinding != nil)
        self.level = level
        authoritativeRandomState = authoritativeRandomSeed
        let binding = level.defaultPlayerBinding!
        let ship = level.shipDefinitions.first { $0.source == binding.ship }!
        angularVelocity = ship.physics.initialAngularVelocity
        lastTimestamp = presentationReadyTimestamp
        trainingOpeningState = level.trainingOpeningLesson.map {
            TrainingOpeningState(timerRemaining: $0.welcomeDelay)
        }
        trainingDodgeAttemptState = level.trainingDodgeAttempt.map {
            _ in TrainingDodgeAttemptState()
        }
        trainingManeuverFollowState =
            level.trainingDodgeAttempt?.maneuverFollow.flatMap {
                initialTrainingManeuverFollowState(
                    level: level,
                    lesson: $0
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
        playerConcussionState = ship.playerConcussion == nil ? nil : .init()
        playerYellowFlareState = level.shipDefinitions.first?
            .playerYellowFlare == nil ? nil : .init()
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

    init(
        level: Level,
        continuation: PlayerSimulationContinuation,
        resumedAtTimestamp: Double
    ) throws {
        let expectedSchema = playerSimulationContinuationSchema(for: level)
        guard continuation.schemaVersion == expectedSchema else {
            throw PlayerSimulationContinuationError.unsupportedSchema
        }
        guard continuation.levelKey == level.levelKey,
              continuation.levelSHA256 == level.source.levelSHA256 else {
            throw PlayerSimulationContinuationError.levelIdentityMismatch
        }
        let hasPersistedAuthoritativeRandomState =
            continuation.authoritativeRandomState != nil
        authoritativeRandomState =
            continuation.authoritativeRandomState ?? 1
        var restoredRobotGuidebotState =
            continuation.trainingRobotGuidebotState
        var restoredPlayerConcussionState = continuation.playerConcussionState
        if level.shipDefinitions.first?.playerConcussion != nil,
           restoredPlayerConcussionState == nil {
            restoredPlayerConcussionState = .init()
        }
        var restoredPlayerYellowFlareState =
            continuation.playerYellowFlareState
        if level.shipDefinitions.first?.playerYellowFlare != nil,
           restoredPlayerYellowFlareState == nil {
            restoredPlayerYellowFlareState = .init()
            if var guidebotState = restoredRobotGuidebotState {
                let hasLegacyYellowFamily =
                    guidebotState.yellowFlares?.isEmpty == false
                    || guidebotState.yellowFlareParticles?.isEmpty == false
                    || guidebotState.yellowFlareTimeoutExplosions?.isEmpty
                        == false
                    || guidebotState.yellowFlareTimeoutSparks?.isEmpty
                        == false
                    || guidebotState.yellowFlareTimeoutSparkParticles?.isEmpty
                        == false
                if hasLegacyYellowFamily {
                    guidebotState.yellowFlares =
                        guidebotState.yellowFlares?.map { flare in
                        var flare = flare
                        flare.creationOrdinal = 0
                        flare.parentObjectHandle = level
                            .trainingRobotGuidebotChain?
                            .guidebotObjectHandle
                        return flare
                    }
                    guidebotState.yellowFlareParticles =
                        guidebotState.yellowFlareParticles?.map { particle in
                            var particle = particle
                            particle.generationOrdinal = 0
                            return particle
                        }
                    guidebotState.yellowFlareTimeoutExplosions =
                        guidebotState.yellowFlareTimeoutExplosions?.map {
                            explosion in
                            var explosion = explosion
                            explosion.generationOrdinal = 0
                            return explosion
                        }
                    guidebotState.yellowFlareTimeoutSparks =
                        guidebotState.yellowFlareTimeoutSparks?.map { spark in
                            var spark = spark
                            spark.generationOrdinal = 0
                            return spark
                        }
                    guidebotState.yellowFlareTimeoutSparkParticles =
                        guidebotState.yellowFlareTimeoutSparkParticles?.map {
                            particle in
                            var particle = particle
                            particle.generationOrdinal = 0
                            return particle
                        }
                    restoredPlayerYellowFlareState?.nextCreationOrdinal = 1
                    restoredRobotGuidebotState = guidebotState
                }
            }
        }
        if var state = restoredRobotGuidebotState {
            let hasReachedTimingState =
                state.guidebotMode != nil
                || state.guidebotModeTime != nil
                || state.nextAmbientTime != nil
                || state.timeUntilNextPlayerVisibilityCheck != nil
                || state.timeUntilNextFlare != nil
                || state.nextPowerupCheckTime != nil
                || state.lastMessageSoundTime != nil
                || state.returnTime != nil
                || state.returnGreetingWasPresented != nil
            if hasReachedTimingState
                && !hasPersistedAuthoritativeRandomState
            {
                throw PlayerSimulationContinuationError.invalidState
            }
            if (state.guidebot != nil || state.guidebotEnteredShip),
               state.guidebotMode == nil {
                guard !hasPersistedAuthoritativeRandomState,
                      !hasReachedTimingState,
                      state.guidebot?.task != .escortPlayer
                else {
                    throw PlayerSimulationContinuationError.invalidState
                }
                state.guidebotMode = .ambient
                state.guidebotModeTime = 0
                state.nextAmbientTime = continuation.gameTime + 1
                state.timeUntilNextPlayerVisibilityCheck = 0.5
                state.timeUntilNextFlare = 3
                state.nextPowerupCheckTime = continuation.gameTime + 2
                state.lastMessageSoundTime = continuation.gameTime
                state.returnTime = continuation.gameTime
                state.returnGreetingWasPresented = false
                restoredRobotGuidebotState = state
            }
        }
        let restoredCloakPickupState =
            continuation.trainingCloakPickupState
            ?? level.trainingCloakPickupChain.map {
                _ in TrainingCloakPickupState()
            }
        let restoredLastRoomState =
            continuation.trainingLastRoomState
            ?? level.trainingLastRoomChain.map {
                _ in TrainingLastRoomState()
            }
        let restoredFinalRoomEntryState =
            continuation.trainingFinalRoomEntryState
            ?? level.trainingFinalRoomEntryChain.map {
                _ in TrainingFinalRoomEntryState()
            }
        let restoredFinalBotsCompletionState =
            continuation.trainingFinalBotsCompletionState
            ?? level.trainingFinalBotsCompletionChain.map {
                _ in TrainingFinalBotsCompletionState()
            }
        let restoredFinalGoalState =
            continuation.trainingFinalGoalState
            ?? level.trainingFinalGoalChain.map {
                _ in TrainingFinalGoalState()
            }
        let restoredDodgeAttemptState =
            continuation.trainingDodgeAttemptState
            ?? level.trainingDodgeAttempt.map {
                _ in TrainingDodgeAttemptState()
            }
        var restoredManeuverFollowState =
            continuation.trainingManeuverFollowState
            ?? level.trainingDodgeAttempt?.maneuverFollow.flatMap {
                initialTrainingManeuverFollowState(
                    level: level,
                    lesson: $0
                )
            }
        if restoredManeuverFollowState?.destruction == nil,
           let lesson =
               level.trainingDodgeAttempt?.maneuverFollow,
           let initial = initialTrainingManeuverFollowState(
               level: level,
               lesson: lesson
           )?.destruction {
            restoredManeuverFollowState?.destruction = initial
        }
        let dodgeAttemptIsActive =
            restoredDodgeAttemptState?.script033Count == 1
            && restoredDodgeAttemptState?.script017Count == 0
        let dodgeAttemptHasSucceeded =
            restoredDodgeAttemptState?.script017Count == 1
        let dodgeExitWasReached =
            restoredDodgeAttemptState?.script019Count == 1
        let restoredLastBot1DeathState =
            continuation.trainingLastBot1DeathState
            ?? level.trainingLastBot1DeathChain.map {
                TrainingLastBot1DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot2DeathState =
            continuation.trainingLastBot2DeathState
            ?? level.trainingLastBot2DeathChain.map {
                TrainingLastBot2DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot3DeathState =
            continuation.trainingLastBot3DeathState
            ?? level.trainingLastBot3DeathChain.map {
                TrainingLastBot3DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot4DeathState =
            continuation.trainingLastBot4DeathState
            ?? level.trainingLastBot4DeathChain.map {
                TrainingLastBot4DeathState(
                    shields: $0.combat.robotShields
                )
            }
        let restoredLastBot5DeathState =
            continuation.trainingLastBot5DeathState
            ?? level.trainingLastBot5DeathChain.map {
                TrainingLastBot5DeathState(
                    shields: $0.combat.robotShields
                )
            }
        var routeAllocationLevel = level
        if continuation.trainingGalleryBarrierState?.wasTriggered == true {
            closeTrainingGalleryBarrier(in: &routeAllocationLevel)
        }
        var continuationLevel = routeAllocationLevel
        if continuation.trainingOpeningState?
            .continueToCourseWasPresented == true
        {
            guard let continueToCourse =
                    continuationLevel.trainingOpeningLesson?
                        .continueToCourse,
                  trainingContinueToCoursePortalsHaveRenderState(
                      in: continuationLevel,
                      lesson: continueToCourse,
                      rendersFaces: true
                  )
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            openTrainingContinueToCoursePortals(in: &continuationLevel)
        }
        if continuation.trainingOpeningState?
            .finishCourseWasPresented == true
        {
            guard let finishCourse =
                    continuationLevel.trainingOpeningLesson?.finishCourse,
                  trainingFinishCoursePortalsHaveRenderState(
                      in: continuationLevel,
                      lesson: finishCourse,
                      rendersFaces: true
                  )
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            openTrainingFinishCoursePortals(in: &continuationLevel)
        }
        if let cameraState = continuation.trainingCameraMonitorState,
           let chain = continuationLevel.trainingCameraMonitorChain {
            if cameraState.isHeld || cameraState.wasUsed {
                completeTrainingCameraMonitorLocateGoal(
                    in: &continuationLevel,
                    pickupObjectHandle: chain.pickupObjectHandle
                )
            }
            if cameraState.script058WasPresented {
                openTrainingGuidebotReturnBarrier(in: &continuationLevel)
            }
            if cameraState.wasUsed {
                continuationLevel.objects.removeAll {
                    $0.handle == chain.pickupObjectHandle
                }
            }
            if cameraState.isHeld || cameraState.wasUsed {
                setObjectPresentationVisibility(
                    in: &continuationLevel,
                    handle: chain.pickupObjectHandle,
                    isVisible: false
                )
            }
        }
        if continuation.trainingKillbotEntryState?.wasTriggered == true {
            closeTrainingKillbotEntryBarrier(in: &continuationLevel)
        }
        if continuation.trainingRASBot1DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot1DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingRASBot2DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot2DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingRASBot3DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot3DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingRASBot4DeathState?.wasDestroyed == true {
            let chain = continuationLevel.trainingRASBot4DeathChain!
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot1DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot1DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot2DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot2DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot3DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot3DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot4DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot4DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if restoredLastBot5DeathState?.wasDestroyed == true {
            guard let chain =
                continuationLevel.trainingLastBot5DeathChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.robotObjectHandle
            }
        }
        if continuation.trainingInvulnerabilityPickupState?
            .wasConsumed == true
        {
            guard
                let chain =
                    continuationLevel.trainingInvulnerabilityPickupChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.pickupObjectHandle
            }
            setObjectPresentationVisibility(
                in: &continuationLevel,
                handle: chain.pickupObjectHandle,
                isVisible: false
            )
        }
        if restoredCloakPickupState?.wasConsumed == true {
            guard let chain = continuationLevel.trainingCloakPickupChain
            else {
                throw PlayerSimulationContinuationError.invalidState
            }
            continuationLevel.objects.removeAll {
                $0.handle == chain.pickupObjectHandle
            }
            setObjectPresentationVisibility(
                in: &continuationLevel,
                handle: chain.pickupObjectHandle,
                isVisible: false
            )
        }
        if restoredLastRoomState?.wasTriggered == true {
            openTrainingLastRoomBarrier(in: &continuationLevel)
        }
        if restoredFinalRoomEntryState?.wasTriggered == true {
            closeTrainingLastRoomBarrier(in: &continuationLevel)
        }
        if restoredFinalBotsCompletionState?.wasTriggered == true {
            openTrainingFinalBotsBarrier(in: &continuationLevel)
        }
        guard
            validTrainingCameraMonitorContinuation(
                continuation.trainingCameraMonitorState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingKillbotEntryContinuation(
                continuation.trainingKillbotEntryState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot1DeathContinuation(
                continuation.trainingRASBot1DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot2DeathContinuation(
                continuation.trainingRASBot2DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot3DeathContinuation(
                continuation.trainingRASBot3DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingRASBot4DeathContinuation(
                continuation.trainingRASBot4DeathState,
            level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot1DeathContinuation(
                restoredLastBot1DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot2DeathContinuation(
                restoredLastBot2DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot3DeathContinuation(
                restoredLastBot3DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot4DeathContinuation(
                restoredLastBot4DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastBot5DeathContinuation(
                restoredLastBot5DeathState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingInvulnerabilityPickupContinuation(
                continuation.trainingInvulnerabilityPickupState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingCloakPickupContinuation(
                restoredCloakPickupState,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard
            validTrainingLastRoomContinuation(
                restoredLastRoomState,
                finalRoomEntryWasTriggered:
                    restoredFinalRoomEntryState?.wasTriggered == true,
                allProducersWereTriggered:
                    continuation.trainingRASBot1DeathState?
                        .wasDestroyed == true
                    && continuation.trainingRASBot2DeathState?
                        .wasDestroyed == true
                    && continuation.trainingRASBot3DeathState?
                        .wasDestroyed == true
                    && continuation.trainingRASBot4DeathState?
                        .wasDestroyed == true
                    && continuation.trainingInvulnerabilityPickupState?
                        .scriptWasTriggered == true
                    && restoredCloakPickupState?
                        .scriptWasTriggered == true,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard validTrainingFinalRoomEntryContinuation(
            restoredFinalRoomEntryState,
            lastRoomState: restoredLastRoomState,
            level: continuationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard validTrainingFinalBotsCompletionContinuation(
            restoredFinalBotsCompletionState,
            allProducersWereDestroyed:
                restoredLastBot1DeathState?.wasDestroyed == true
                && restoredLastBot2DeathState?.wasDestroyed == true
                && restoredLastBot3DeathState?.wasDestroyed == true
                && restoredLastBot4DeathState?.wasDestroyed == true
                && restoredLastBot5DeathState?.wasDestroyed == true,
            level: continuationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard validTrainingFinalGoalContinuation(
            restoredFinalGoalState,
            finalBotsState: restoredFinalBotsCompletionState,
            level: continuationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        var restoredGuidebotRouteLevel =
            continuation.trainingCameraMonitorState?
                .script058WasPresented == true
                && restoredRobotGuidebotState?.guidebot?.task == .outbound
            ? continuationLevel
            : routeAllocationLevel
        if let binding = restoredGuidebotRouteLevel.defaultPlayerBinding,
           let playerIndex = restoredGuidebotRouteLevel.objects.firstIndex(
               where: { $0.handle == binding.objectHandle }
           ) {
            restoredGuidebotRouteLevel.objects[playerIndex].location =
                continuation.playerLocation
            restoredGuidebotRouteLevel.objects[playerIndex].position =
                continuation.playerPosition
            restoredGuidebotRouteLevel.objects[playerIndex].orientation =
                continuation.playerOrientation
        }
        if let guidebot = restoredRobotGuidebotState?.guidebot,
           let handle = restoredGuidebotRouteLevel
            .trainingRobotGuidebotChain?.guidebotObjectHandle,
           let guidebotIndex = restoredGuidebotRouteLevel.objects.firstIndex(
               where: { $0.handle == handle }
           ) {
            restoredGuidebotRouteLevel.objects[guidebotIndex].location =
                .room(guidebot.roomSourceIndex)
            restoredGuidebotRouteLevel.objects[guidebotIndex].position =
                guidebot.position
            restoredGuidebotRouteLevel.objects[guidebotIndex].orientation =
                guidebot.orientation
        }
        let guidebotContinuationIsValid =
            validTrainingRobotGuidebotContinuation(
                restoredRobotGuidebotState,
                galleryState: continuation.trainingGalleryBarrierState,
                cameraState: continuation.trainingCameraMonitorState,
                playerLocation: continuation.playerLocation,
                playerPosition: continuation.playerPosition,
                gameTime: continuation.gameTime,
                level: restoredGuidebotRouteLevel
            )
        let playerYellowContinuationIsValid =
            validPlayerYellowFlareContinuation(
                restoredPlayerYellowFlareState,
                guidebotState: restoredRobotGuidebotState,
                gameTime: continuation.gameTime,
                level: restoredGuidebotRouteLevel
            )
        let playerConcussionContinuationIsValid =
            validPlayerConcussionContinuation(
                restoredPlayerConcussionState,
                gameTime: continuation.gameTime,
                level: restoredGuidebotRouteLevel
            )
        guard
            validTrainingGalleryBarrierContinuation(
                continuation.trainingGalleryBarrierState,
            robotGuidebotState:
                restoredRobotGuidebotState,
            level: continuationLevel
        ),
        guidebotContinuationIsValid,
        playerConcussionContinuationIsValid,
        playerYellowContinuationIsValid else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard case .room(let restoredRoomSourceIndex)
                = continuation.playerLocation,
              level.rooms.contains(where: {
                  $0.sourceIndex == restoredRoomSourceIndex
              }),
              containingIndoorRoomSourceIndex(
                  in: level,
                  position: continuation.playerPosition,
                  candidates: [restoredRoomSourceIndex]
              ) == restoredRoomSourceIndex else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard resumedAtTimestamp.isFinite,
              continuation.frameDuration.isFinite,
              continuation.frameDuration >= 0,
              continuation.gameTime.isFinite,
              continuation.gameTime >= 0,
              continuation.playerRearViewState.map({ state in
                  continuation.schemaVersion == 7
                      && state.entryGameTime.isFinite
                      && state.entryGameTime >= 0
                      && state.entryGameTime <= continuation.gameTime
              }) ?? true,
              isCanonicalRigidTransform(
                  position: continuation.playerPosition,
                  orientation: continuation.playerOrientation
              ),
              continuation.velocity.x.isFinite,
              continuation.velocity.y.isFinite,
              continuation.velocity.z.isFinite,
              continuation.angularVelocity.x.isFinite,
              continuation.angularVelocity.y.isFinite,
              continuation.angularVelocity.z.isFinite,
              continuation.turnrollFixedAngle.isFinite,
              continuation.afterburnerFuel.isFinite,
              (0...5).contains(continuation.afterburnerFuel),
              continuation.energy.isFinite,
              continuation.energy >= 0,
              continuation.afterburnerMagnitude.isFinite,
              (0...1).contains(continuation.afterburnerMagnitude),
              continuation.wiggleFalloff.isFinite,
              (0...1).contains(continuation.wiggleFalloff),
              continuation.lastThrustTime.isFinite,
              continuation.trainingOpeningState.map({ state in
                  var expectedControls: [PlayerControlMask]
                  if state.upGoalWasReached == true {
                      if state.returnGoalWasReached == true {
                          guard state.forwardGoalWasReached else {
                              return false
                          }
                          expectedControls = [
                              [.up],
                              [.left, .up],
                          ]
                      } else if state.forwardGoalWasReached {
                          expectedControls = [[.reverse, .up]]
                      } else {
                          expectedControls = [[.forward, .up]]
                      }
                  } else if state.rightGoalWasReached == true {
                      if state.returnGoalWasReached == true {
                          guard state.forwardGoalWasReached else {
                              return false
                          }
                          expectedControls = [
                              [.right],
                              [.left, .right],
                          ]
                      } else if state.forwardGoalWasReached {
                          expectedControls = [[.reverse, .right]]
                      } else {
                          expectedControls = [[.forward, .right]]
                      }
                  } else if state.returnGoalWasReached == true {
                      guard state.forwardGoalWasReached else {
                          return false
                      }
                      expectedControls = [[.left]]
                  } else if state.forwardGoalWasReached {
                      expectedControls = [[.reverse]]
                  } else {
                      expectedControls = [[.forward]]
                  }
                  if state.downGoalWasReached == true {
                      let controlsBeforeReturnDown = expectedControls
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.up)
                          controls.insert(.down)
                          return controls
                      }
                      if state.upGoalWasReached == true {
                          expectedControls += controlsBeforeReturnDown.map {
                              controls in
                              var controls = controls
                              controls.insert(.down)
                              return controls
                          }
                      }
                  }
                  if state.repeatForwardWasPresented == true {
                      guard state.downGoalWasReached == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.down)
                          controls.insert(.forward)
                          return controls
                      }
                  }
                  if state.repeatForwardGoalWasPresented == true {
                      guard state.repeatForwardWasPresented == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.forward)
                          controls.insert(.reverse)
                          return controls
                      }
                  }
                  if state.repeatReturnLeftWasPresented == true {
                      guard state.repeatForwardGoalWasPresented == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.reverse)
                          controls.insert(.left)
                          return controls
                      }
                  }
                  if state.repeatReturnRightWasPresented == true {
                      guard state.repeatReturnLeftWasPresented == true,
                            state.rightGoalWasReached == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.left)
                          controls.insert(.right)
                          return controls
                      }
                  }
                  if state.repeatReturnUpWasPresented == true {
                      guard state.repeatReturnRightWasPresented == true,
                            state.rightGoalWasReached == true,
                            state.upGoalWasReached == true,
                            state.downGoalWasReached == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.right)
                          controls.insert(.up)
                          return controls
                      }
                  }
                  if state.repeatReturnDownWasPresented == true {
                      guard state.repeatReturnUpWasPresented == true,
                            state.downGoalWasReached == true else {
                          return false
                      }
                      expectedControls = expectedControls.map { controls in
                          var controls = controls
                          controls.remove(.up)
                          controls.insert(.down)
                          return controls
                      }
                  }
                  if state.continueToCourseWasPresented == true {
                      guard state.repeatReturnDownWasPresented == true else {
                          return false
                      }
                  }
                  let dodgeExitControlMaskIsReachable: Bool = {
                      guard dodgeExitWasReached else {
                          return false
                      }
                      let lowBits =
                          state.enabledControls.rawValue & 63
                      if lowBits == 0 || lowBits == 1 {
                          return true
                      }
                      if dodgeAttemptIsActive && lowBits == 60 {
                          return true
                      }
                      return dodgeAttemptHasSucceeded
                          && (lowBits == 3 || lowBits == 63)
                  }()
                  let maneuverControlMaskIsReachable: Bool = {
                      guard let followState =
                              restoredManeuverFollowState,
                            followState.script021Count > 0,
                            let lesson =
                              level.trainingDodgeAttempt?
                                .maneuverFollow
                      else {
                          return false
                      }
                      let expected: UInt32
                      if followState.script026Count > 0 {
                          expected =
                              lesson.rotationalControlMask
                              | lesson.weaponControlMask
                      } else if followState.script023Count > 0 {
                          expected = lesson.rotationalControlMask
                      } else if followState.script024Count > 0 {
                          expected = lesson.bankControlMask
                      } else if followState.script022Count > 0 {
                          expected = lesson.pitchControlMask
                      } else {
                          expected = lesson.headingControlMask
                      }
                      return state.enabledControls.rawValue == expected
                  }()
                  if state.startCourseWasPresented == true {
                      guard let startCourse =
                              level.trainingOpeningLesson?.startCourse
                      else {
                          return false
                      }
                      if state.finishCourseWasPresented == true {
                          guard state.enabledControls.rawValue
                                  == startCourse.enabledControlMask
                              || state.enabledControls.rawValue == 32
                                  || (
                                  dodgeAttemptHasSucceeded
                                    && state.enabledControls.rawValue == 63
                              )
                              || dodgeExitControlMaskIsReachable
                              || maneuverControlMaskIsReachable
                          else {
                              return false
                          }
                      } else {
                          guard state.enabledControls.rawValue
                                  & startCourse.enabledControlMask
                                    == startCourse.enabledControlMask
                                  || (
                                      dodgeAttemptIsActive
                                        && state.enabledControls.rawValue == 60
                                  )
                                  || dodgeExitControlMaskIsReachable
                                  || maneuverControlMaskIsReachable
                          else {
                              return false
                          }
                      }
                  }
                  if state.finishCourseWasPresented == true {
                      guard let finishCourse =
                              level.trainingOpeningLesson?.finishCourse
                      else {
                          return false
                      }
                      if state.startCourseWasPresented == true {
                          guard state.enabledControls.rawValue
                                  == finishCourse.enabledControlMask
                              || state.enabledControls.rawValue == 63
                                  || (
                                  dodgeAttemptHasSucceeded
                                    && state.enabledControls.rawValue == 63
                              )
                              || dodgeExitControlMaskIsReachable
                              || maneuverControlMaskIsReachable
                          else {
                              return false
                          }
                      } else {
                          guard state.enabledControls.rawValue
                                  == finishCourse.enabledControlMask
                                  || (
                                  dodgeAttemptHasSucceeded
                                    && state.enabledControls.rawValue == 63
                              )
                              || dodgeExitControlMaskIsReachable
                              || maneuverControlMaskIsReachable
                          else {
                              return false
                          }
                      }
                  }
                  return state.timerRemaining.isFinite
                      && (
                          state.welcomeWasPresented
                            || state.timerRemaining > 0
                      )
                      && (state.returnGoalWasReached != true
                          || level.trainingOpeningLesson?.returnLeft != nil)
                      && (state.rightGoalWasReached != true
                          || level.trainingOpeningLesson?.returnRight != nil)
                      && (state.upGoalWasReached != true
                          || (
                              state.rightGoalWasReached == true
                                && level.trainingOpeningLesson?.returnUp != nil
                          ))
                      && (state.downGoalWasReached != true
                          || level.trainingOpeningLesson?.returnDown != nil)
                      && (state.repeatForwardWasPresented != true
                          || level.trainingOpeningLesson?.repeatForward != nil)
                      && (state.repeatForwardGoalWasPresented != true
                          || level.trainingOpeningLesson?.repeatForwardGoal
                            != nil)
                      && (state.repeatReturnLeftWasPresented != true
                          || level.trainingOpeningLesson?.repeatReturnLeft
                            != nil)
                      && (state.repeatReturnRightWasPresented != true
                          || level.trainingOpeningLesson?.repeatReturnRight
                            != nil)
                      && (state.repeatReturnUpWasPresented != true
                          || level.trainingOpeningLesson?.repeatReturnUp
                            != nil)
                      && (state.repeatReturnDownWasPresented != true
                          || level.trainingOpeningLesson?.repeatReturnDown
                            != nil)
                      && (state.continueToCourseWasPresented != true
                          || level.trainingOpeningLesson?.continueToCourse
                            != nil)
                      && (state.startCourseWasPresented != true
                          || level.trainingOpeningLesson?.startCourse != nil)
                      && (state.finishCourseWasPresented != true
                          || level.trainingOpeningLesson?.finishCourse != nil)
                      && (
                          state.startCourseWasPresented == true
                            || state.finishCourseWasPresented == true
                            || (dodgeAttemptIsActive
                                && state.enabledControls.rawValue == 60)
                            || (dodgeAttemptHasSucceeded
                                && state.enabledControls.rawValue == 63)
                            || dodgeExitControlMaskIsReachable
                            || maneuverControlMaskIsReachable
                            || expectedControls.contains(
                                state.enabledControls
                            )
                        )
              }) ?? true,
              (level.trainingOpeningLesson == nil)
                == (continuation.trainingOpeningState == nil) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        if continuation.trainingOpeningState?
            .startCourseWasPresented == true
        {
            guard continuationLevel.trainingOpeningLesson?.startCourse
                    != nil else {
                throw PlayerSimulationContinuationError.invalidState
            }
            closeTrainingStartCoursePortal(in: &continuationLevel)
        }
        if let continueToCourse =
                continuationLevel.trainingOpeningLesson?.continueToCourse,
           continuation.trainingOpeningState?
            .continueToCourseWasPresented == true {
            let startCourseWasPresented =
                continuation.trainingOpeningState?
                    .startCourseWasPresented == true
            let startCoursePortalIndex =
                continuationLevel.trainingOpeningLesson?
                    .startCourse?.portalIndex
            guard continueToCourse.orderedPortalIndices.allSatisfy({
                portalIndex in
                trainingPortalPairHasRenderState(
                    in: continuationLevel,
                    roomSourceIndex:
                        continueToCourse.portalRoomSourceIndex,
                    portalIndex: portalIndex,
                    rendersFaces:
                        startCourseWasPresented
                            && portalIndex == startCoursePortalIndex
                )
            }) else {
                throw PlayerSimulationContinuationError.invalidState
            }
        }
        if let startCourse =
                continuationLevel.trainingOpeningLesson?.startCourse,
           continuation.trainingOpeningState?
            .startCourseWasPresented == true {
            guard trainingStartCoursePortalHasRenderState(
                in: continuationLevel,
                lesson: startCourse,
                rendersFaces: true
            ) else {
                throw PlayerSimulationContinuationError.invalidState
            }
        }
        if let finishCourse =
                continuationLevel.trainingOpeningLesson?.finishCourse,
           continuation.trainingOpeningState?
            .finishCourseWasPresented == true {
            guard trainingFinishCoursePortalsHaveRenderState(
                in: continuationLevel,
                lesson: finishCourse,
                rendersFaces: false
            ) else {
                throw PlayerSimulationContinuationError.invalidState
            }
        }
        var restoredOpeningState = continuation.trainingOpeningState
        if restoredOpeningState?.startCourseWasPresented == true,
           !dodgeAttemptIsActive,
           !dodgeExitWasReached,
           restoredManeuverFollowState?.script021Count ?? 0 == 0,
           !(restoredOpeningState?.finishCourseWasPresented == true
                && restoredOpeningState?.enabledControls.rawValue == 32),
           let startCourse =
                continuationLevel.trainingOpeningLesson?.startCourse {
            restoredOpeningState?.enabledControls.formUnion(
                PlayerControlMask(
                    rawValue: startCourse.enabledControlMask
                )
            )
        }
        guard
            validTrainingDodgeAttemptContinuation(
                restoredDodgeAttemptState,
                maneuverState: restoredManeuverFollowState,
                shields: continuation.shields ?? 100,
                level: continuationLevel
            )
        else {
            throw PlayerSimulationContinuationError.invalidState
        }
        guard validTrainingManeuverFollowContinuation(
            restoredManeuverFollowState,
            robotGuidebotState:
                restoredRobotGuidebotState,
            level: continuationLevel
        ) else {
            throw PlayerSimulationContinuationError.invalidState
        }
        if (
            restoredManeuverFollowState?.destruction?
                .script027Count ?? 0
        ) > 0,
           restoredManeuverFollowState?.destruction?
            .destroyBot1Destruction == nil,
           let handoff =
                continuationLevel.trainingDodgeAttempt?
                    .maneuverFollow?.destructionHandoff
        {
            restoredManeuverFollowState?.destruction?
                .destroyBot1Destruction =
                    initialTrainingDestroyBot1DestructionState(
                        level: continuationLevel,
                        handoff: handoff
                    )
        }
        var restoredLevel = continuationLevel
        if restoredDodgeAttemptState?.script033Count == 1 {
            setTrainingDodgePortalRenderState(
                in: &restoredLevel,
                roomSourceIndex:
                    restoredLevel.trainingDodgeAttempt!
                    .portalRoomTwoSourceIndex,
                portalIndices:
                    restoredLevel.trainingDodgeAttempt!
                    .orderedPortalIndices,
                rendersFaces: true
            )
        }
        if restoredDodgeAttemptState?.script017Count == 1 {
            setTrainingDodgePortalRenderState(
                in: &restoredLevel,
                roomSourceIndex:
                    restoredLevel.trainingDodgeAttempt!
                    .portalRoomThreeSourceIndex,
                portalIndices:
                    restoredLevel.trainingDodgeAttempt!
                    .orderedPortalIndices,
                rendersFaces: false
            )
        }
        if restoredDodgeAttemptState?.script019Count == 1,
            let exit = restoredLevel.trainingDodgeAttempt?.dodgeExit
        {
            setTrainingDodgePortalRenderState(
                in: &restoredLevel,
                roomSourceIndex: exit.portalRoomSourceIndex,
                portalIndices: exit.orderedPortalIndices,
                rendersFaces: false
            )
        }
        if restoredManeuverFollowState?.script021Count ?? 0 > 0,
           let lesson =
                restoredLevel.trainingDodgeAttempt?.maneuverFollow
        {
            setTrainingDodgePortalRenderState(
                in: &restoredLevel,
                roomSourceIndex: lesson.portalRoomSourceIndex,
                portalIndices: lesson.orderedPortalIndices,
                rendersFaces: true
            )
        }
        if let state = restoredManeuverFollowState,
           let lesson =
                restoredLevel.trainingDodgeAttempt?.maneuverFollow {
            if state.destruction?.followBotWasDestroyed == true {
                restoredLevel.objects.removeAll {
                    $0.handle == lesson.followBotObjectHandle
                }
                setObjectPresentationVisibility(
                    in: &restoredLevel,
                    handle: lesson.followBotObjectHandle,
                    isVisible: false
                )
            } else if let objectIndex =
                        restoredLevel.objects.firstIndex(where: {
                            $0.handle
                                == lesson.followBotObjectHandle
                        }) {
                restoredLevel.objects[objectIndex].location =
                    .room(state.roomSourceIndex)
                restoredLevel.objects[objectIndex].position =
                    state.position
                restoredLevel.objects[objectIndex].orientation =
                    state.orientation
            }
            if let handoff = lesson.destructionHandoff,
               let destruction = state.destruction {
                setObjectPresentationVisibility(
                    in: &restoredLevel,
                    handle: handoff.destroyBot2ObjectHandle,
                    isVisible: destruction.destroyBot2IsVisible
                )
                setObjectPresentationVisibility(
                    in: &restoredLevel,
                    handle: handoff.destroyBot1ObjectHandle,
                    isVisible: destruction.destroyBot1IsVisible
                )
                if destruction.destroyBot1Destruction?
                    .destroyBot1WasDestroyed == true
                {
                    restoredLevel.objects.removeAll {
                        $0.handle == handoff.destroyBot1ObjectHandle
                    }
                } else if let objectIndex =
                    restoredLevel.objects.firstIndex(where: {
                        $0.handle
                            == handoff.destroyBot1ObjectHandle
                    }) {
                    restoredLevel.objects[objectIndex].location =
                        .room(
                            destruction.destroyBot1Motion
                                .roomSourceIndex
                        )
                    restoredLevel.objects[objectIndex].position =
                        destruction.destroyBot1Motion.position
                    restoredLevel.objects[objectIndex].orientation =
                        destruction.destroyBot1Motion.orientation
                }
                if let destroyBot2Motion =
                    destruction.destroyBot1Destruction?
                        .destroyBot2Motion,
                   let objectIndex =
                    restoredLevel.objects.firstIndex(where: {
                        $0.handle
                            == handoff.destroyBot2ObjectHandle
                    })
                {
                    restoredLevel.objects[objectIndex].location =
                        .room(destroyBot2Motion.roomSourceIndex)
                    restoredLevel.objects[objectIndex].position =
                        destroyBot2Motion.position
                    restoredLevel.objects[objectIndex].orientation =
                        destroyBot2Motion.orientation
                }
            }
        }
        if continuation.trainingRobotGuidebotState?
            .robotWasDestroyed == true
        {
            let chain = restoredLevel.trainingRobotGuidebotChain!
            restoredLevel.objects.removeAll {
                $0.handle == chain.destroyRobotObjectHandle
            }
            setObjectPresentationVisibility(
                in: &restoredLevel,
                handle: chain.destroyRobotObjectHandle,
                isVisible: false
            )
            if continuation.trainingGalleryBarrierState?
                .wasTriggered == true,
               continuation.trainingGalleryBarrierState?
                .markerLightDistance == 0
            {
                closeTrainingGalleryBarrier(in: &restoredLevel)
            } else {
                openTrainingGalleryBarrier(in: &restoredLevel)
            }
        }
        let binding = restoredLevel.defaultPlayerBinding!
        let objectIndex = restoredLevel.objects.firstIndex {
            $0.handle == binding.objectHandle
        }!
        restoredLevel.objects[objectIndex].location = continuation.playerLocation
        restoredLevel.objects[objectIndex].position = continuation.playerPosition
        restoredLevel.objects[objectIndex].orientation = continuation.playerOrientation
        self.level = restoredLevel
        frameDuration = continuation.frameDuration
        gameTime = continuation.gameTime
        velocity = continuation.velocity
        angularVelocity = continuation.angularVelocity
        turnrollFixedAngle = continuation.turnrollFixedAngle
        indoorAutoLevelMode = continuation.indoorAutoLevelMode
        afterburnerFuel = continuation.afterburnerFuel
        afterburnerIsActive = continuation.afterburnerIsActive
        energy = continuation.energy
        shields = continuation.shields ?? 100
        playerHeadlightIsOn = continuation.playerHeadlightIsOn ?? false
        playerRearViewState = continuation.playerRearViewState
        afterburnerMagnitude = continuation.afterburnerMagnitude
        wiggleFalloff = continuation.wiggleFalloff
        lastThrustTime = continuation.lastThrustTime
        lastTimestamp = resumedAtTimestamp
        trainingOpeningState = restoredOpeningState
        trainingDodgeAttemptState = restoredDodgeAttemptState
        trainingManeuverFollowState = restoredManeuverFollowState
        trainingGalleryBarrierState =
            continuation.trainingGalleryBarrierState
        trainingRobotGuidebotState =
            restoredRobotGuidebotState
        playerConcussionState = restoredPlayerConcussionState
        playerYellowFlareState = restoredPlayerYellowFlareState
        trainingCameraMonitorState =
            continuation.trainingCameraMonitorState
        trainingKillbotEntryState =
            continuation.trainingKillbotEntryState
        trainingRASBot1DeathState =
            continuation.trainingRASBot1DeathState
        trainingRASBot2DeathState =
            continuation.trainingRASBot2DeathState
        trainingRASBot3DeathState =
            continuation.trainingRASBot3DeathState
        trainingRASBot4DeathState =
            continuation.trainingRASBot4DeathState
        trainingLastBot1DeathState = restoredLastBot1DeathState
        trainingLastBot2DeathState = restoredLastBot2DeathState
        trainingLastBot3DeathState = restoredLastBot3DeathState
        trainingLastBot4DeathState = restoredLastBot4DeathState
        trainingLastBot5DeathState = restoredLastBot5DeathState
        trainingInvulnerabilityPickupState =
            continuation.trainingInvulnerabilityPickupState
        trainingCloakPickupState = restoredCloakPickupState
        trainingLastRoomState = restoredLastRoomState
        trainingFinalRoomEntryState = restoredFinalRoomEntryState
        trainingFinalBotsCompletionState =
            restoredFinalBotsCompletionState
        trainingFinalGoalState = restoredFinalGoalState
        if restoredFinalGoalState?.endLevelWasRequested == true {
            trainingPostLevelResult = makeTrainingPostLevelResult(
                elapsedTime: gameTime
            )
            trainingSessionOutcome = .awaitingResultAcknowledgement
        }
        restoreTrainingGuidebotPresentation()
        if trainingRobotGuidebotState?.guidebotEnteredShip == true,
           let handle =
            level.trainingRobotGuidebotChain?.guidebotObjectHandle {
            setObjectPresentationVisibility(
                in: &self.level,
                handle: handle,
                isVisible: false
            )
        }
    }

    var continuation: PlayerSimulationContinuation {
        let binding = level.defaultPlayerBinding!
        let player = level.objects.first { $0.handle == binding.objectHandle }!
        let schemaVersion = playerSimulationContinuationSchema(for: level)
        return PlayerSimulationContinuation(
            schemaVersion: schemaVersion,
            levelKey: level.levelKey,
            levelSHA256: level.source.levelSHA256,
            playerLocation: player.location,
            playerPosition: player.position,
            playerOrientation: player.orientation,
            frameDuration: frameDuration,
            gameTime: gameTime,
            velocity: velocity,
            angularVelocity: angularVelocity,
            turnrollFixedAngle: turnrollFixedAngle,
            indoorAutoLevelMode: indoorAutoLevelMode,
            afterburnerFuel: afterburnerFuel,
            afterburnerIsActive: afterburnerIsActive,
            energy: energy,
            afterburnerMagnitude: afterburnerMagnitude,
            wiggleFalloff: wiggleFalloff,
            lastThrustTime: lastThrustTime,
            authoritativeRandomState: authoritativeRandomState,
            shields: shields,
            playerHeadlightIsOn: playerHeadlightIsOn,
            playerRearViewState:
                schemaVersion == 7 ? playerRearViewState : nil,
            trainingOpeningState: trainingOpeningState,
            trainingDodgeAttemptState: trainingDodgeAttemptState,
            trainingManeuverFollowState:
                trainingManeuverFollowState,
            trainingGalleryBarrierState:
                trainingGalleryBarrierState,
            trainingRobotGuidebotState:
                trainingRobotGuidebotState,
            playerConcussionState: playerConcussionState,
            playerYellowFlareState: playerYellowFlareState,
            trainingCameraMonitorState:
                trainingCameraMonitorState,
            trainingKillbotEntryState:
                trainingKillbotEntryState,
            trainingRASBot1DeathState:
                trainingRASBot1DeathState,
            trainingRASBot2DeathState:
                trainingRASBot2DeathState,
            trainingRASBot3DeathState:
                trainingRASBot3DeathState,
            trainingRASBot4DeathState:
                trainingRASBot4DeathState,
            trainingLastBot1DeathState:
                trainingLastBot1DeathState,
            trainingLastBot2DeathState:
                trainingLastBot2DeathState,
            trainingLastBot3DeathState:
                trainingLastBot3DeathState,
            trainingLastBot4DeathState:
                trainingLastBot4DeathState,
            trainingLastBot5DeathState:
                trainingLastBot5DeathState,
            trainingInvulnerabilityPickupState:
                trainingInvulnerabilityPickupState,
            trainingCloakPickupState: trainingCloakPickupState,
            trainingLastRoomState: trainingLastRoomState,
            trainingFinalRoomEntryState:
                trainingFinalRoomEntryState,
            trainingFinalBotsCompletionState:
                trainingFinalBotsCompletionState,
            trainingFinalGoalState: trainingFinalGoalState
        )
    }
    func destroyTrainingRobot(handle: UInt32) {
        guard let chain = level.trainingRobotGuidebotChain,
              handle == chain.destroyRobotObjectHandle,
              var state = trainingRobotGuidebotState,
              !state.robotWasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        state.destructionTimerRemaining = chain.destructionDelay
        if var galleryState = trainingGalleryBarrierState {
            galleryState.markerLightDistance =
                level.trainingGalleryBarrier!.openMarkerLightDistance
            trainingGalleryBarrierState = galleryState
        }
        openTrainingGalleryBarrier(in: &level)
        state.controlsWereRestored = true
        state.robotShields = min(state.robotShields, -0.000_001)
        state.robotWasDestroyed = true
        trainingRobotGuidebotState = state

        if let handoff =
                level.trainingDodgeAttempt?.maneuverFollow?
                    .destructionHandoff,
           handle == handoff.destroyBot2ObjectHandle,
           var maneuverState = trainingManeuverFollowState,
           var destruction = maneuverState.destruction,
           var destroyBot1Destruction =
                destruction.destroyBot1Destruction
        {
            destruction.destroyBot2IsVisible = false
            destroyBot1Destruction.destroyBot2Motion.velocity = .zero
            destroyBot1Destruction.destroyBot2Motion.activePathIndex =
                nil
            destroyBot1Destruction.destroyBot2Motion.pathNodeIndex = 0
            destroyBot1Destruction.destroyBot2Motion.pathFailure = nil
            destruction.destroyBot1Destruction =
                destroyBot1Destruction
            maneuverState.destruction = destruction
            trainingManeuverFollowState = maneuverState
        }
        setObjectPresentationVisibility(
            in: &level,
            handle: handle,
            isVisible: false
        )
        level.objects.removeAll { $0.handle == handle }
    }

    func destroyTrainingRASBot1(handle: UInt32) {
        guard let chain = level.trainingRASBot1DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot1DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot1DeathState = state
    }

    func destroyTrainingRASBot2(handle: UInt32) {
        guard let chain = level.trainingRASBot2DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot2DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot2DeathState = state
    }

    func destroyTrainingRASBot3(handle: UInt32) {
        guard let chain = level.trainingRASBot3DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot3DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot3DeathState = state
    }

    func destroyTrainingRASBot4(handle: UInt32) {
        guard let chain = level.trainingRASBot4DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot4DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot4DeathState = state
    }

    func destroyTrainingLastBot1(handle: UInt32) {
        guard let chain = level.trainingLastBot1DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot1DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot1DeathState = state
    }

    func destroyTrainingLastBot2(handle: UInt32) {
        guard let chain = level.trainingLastBot2DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot2DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot2DeathState = state
    }

    func destroyTrainingLastBot3(handle: UInt32) {
        guard let chain = level.trainingLastBot3DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot3DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot3DeathState = state
    }

    func destroyTrainingLastBot4(handle: UInt32) {
        guard let chain = level.trainingLastBot4DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot4DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot4DeathState = state
    }

    func destroyTrainingLastBot5(handle: UInt32) {
        guard let chain = level.trainingLastBot5DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot5DeathState,
              !state.wasDestroyed,
              level.objects.contains(where: { $0.handle == handle })
        else {
            return
        }
        level.objects.removeAll { $0.handle == handle }
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot5DeathState = state
    }

    func destroyTrainingFollowBot(isDying: Bool) {
        guard isDying,
              let lesson =
                  level.trainingDodgeAttempt?.maneuverFollow,
              let handoff = lesson.destructionHandoff,
              var maneuverState = trainingManeuverFollowState,
              var destruction = maneuverState.destruction,
              !destruction.followBotWasDestroyed,
              level.objects.contains(where: {
                  $0.handle == handoff.followBotObjectHandle
              })
        else {
            return
        }
        level.objects.removeAll {
            $0.handle == handoff.followBotObjectHandle
        }
        setObjectPresentationVisibility(
            in: &level,
            handle: handoff.followBotObjectHandle,
            isVisible: false
        )
        destruction.followBotWasDestroyed = true
        destruction.followBotShields = min(
            destruction.followBotShields,
            -0.000_001
        )
        if destruction.script037Count < 1,
           maneuverState.script026Count > 0 {
            destruction.levelTimer11Remaining =
                handoff.destructionDelay
            destruction.script037Count = min(
                destruction.script037Count + 1,
                trainingScriptActionCounterMaximum
            )
        }
        maneuverState.destruction = destruction
        trainingManeuverFollowState = maneuverState
    }

    func destroyTrainingDestroyBot1(isDying: Bool) {
        guard isDying,
              let lesson =
                level.trainingDodgeAttempt?.maneuverFollow,
              let handoff = lesson.destructionHandoff,
              var maneuverState = trainingManeuverFollowState,
              var destruction = maneuverState.destruction,
              destruction.script027Count > 0,
              var destroyBot1Destruction =
                destruction.destroyBot1Destruction,
              !destroyBot1Destruction.destroyBot1WasDestroyed,
              level.objects.contains(where: {
                  $0.handle == handoff.destroyBot1ObjectHandle
              })
        else {
            return
        }
        level.objects.removeAll {
            $0.handle == handoff.destroyBot1ObjectHandle
        }
        setObjectPresentationVisibility(
            in: &level,
            handle: handoff.destroyBot1ObjectHandle,
            isVisible: false
        )
        destroyBot1Destruction.destroyBot1WasDestroyed = true
        destroyBot1Destruction.destroyBot1Shields = min(
            destroyBot1Destruction.destroyBot1Shields,
            -0.000_001
        )
        if destroyBot1Destruction.script028Count < 1 {
            destruction.destroyBot1IsVisible = false
            destruction.destroyBot2IsVisible = true
            setObjectPresentationVisibility(
                in: &level,
                handle: handoff.destroyBot2ObjectHandle,
                isVisible: true
            )
            assignTrainingAuthoredPath(
                handoff.movingPathIndex,
                motion: &destroyBot1Destruction.destroyBot2Motion
            )
            destroyBot1Destruction.script028Count = min(
                destroyBot1Destruction.script028Count + 1,
                trainingScriptActionCounterMaximum
            )
        }
        destruction.destroyBot1Destruction =
            destroyBot1Destruction
        maneuverState.destruction = destruction
        trainingManeuverFollowState = maneuverState
    }

    func fastPlayerHeadlight(
        from player: PlacedObject
    ) -> PlayerFastHeadlightFrame {
        guard case let .room(startRoomSourceIndex) = player.location else {
            preconditionFailure("The validated default player is indoor.")
        }
        let start = player.position
        let forward = player.orientation.forward
        let end = start + forward * 300
        let wallTrace = traceIndoorMovement(
            in: level,
            startRoom: startRoomSourceIndex,
            start: start,
            end: end,
            radius: 0
        )
        var selectedPosition = wallTrace.finalPosition
        var selectedRoomSourceIndex =
            wallTrace.containingRoomSourceIndex
        var selectedFraction = vectorDistance(start, selectedPosition) / 300
        let visitedRooms = Set(wallTrace.visitedRoomSourceIndices)
        let presentationByHandle = Dictionary(
            uniqueKeysWithValues: level.objectPresentations.map {
                ($0.objectHandle, $0)
            }
        )
        let modelBySource = Dictionary(
            uniqueKeysWithValues: level.models.map { ($0.source, $0) }
        )
        for object in level.objects {
            guard object.handle != player.handle,
                  case let .room(roomSourceIndex) = object.location,
                  visitedRooms.contains(roomSourceIndex),
                  let presentation = presentationByHandle[object.handle],
                  presentation.isVisible,
                  let model = modelBySource[presentation.primaryModel]
            else {
                continue
            }
            let radius = sourceObjectPresentationSize(
                model: model,
                objectType: object.type
            )
            guard let fraction = segmentSphereHitFraction(
                start: start,
                end: end,
                center: object.position,
                radius: radius
            ), fraction < selectedFraction else {
                continue
            }
            selectedFraction = fraction
            selectedPosition = start + (end - start) * fraction
            selectedRoomSourceIndex = roomSourceIndex
        }
        return PlayerFastHeadlightFrame(
            roomSourceIndex: selectedRoomSourceIndex,
            position: selectedPosition - forward / 4,
            lightDistance: 20
        )
    }

    func updatePlayerRearView(
        input: InputSnapshot,
        systemsGameTime: Float
    ) {
        if input.rearViewPressed {
            if playerRearViewState != nil {
                playerRearViewState = nil
            } else {
                playerRearViewState = PlayerRearViewState(
                    leaveMode: false,
                    entryGameTime: systemsGameTime
                )
            }
            return
        }
        guard var state = playerRearViewState else { return }
        if state.leaveMode && !input.rearViewHeld {
            playerRearViewState = nil
        } else if input.rearViewHeld,
                  systemsGameTime - state.entryGameTime > 1.0 / 16.0 {
            state.leaveMode = true
            playerRearViewState = state
        }
    }
    func acknowledgeTrainingResult() -> TrainingSessionOutcome? {
        guard trainingPostLevelResult != nil else { return nil }
        trainingSessionOutcome = .completed
        return trainingSessionOutcome
    }

    func makeTrainingPostLevelResult(
        elapsedTime: Float
    ) -> TrainingPostLevelResult {
        let enemyKills = [
            trainingRobotGuidebotState?.robotWasDestroyed == true,
            trainingRASBot1DeathState?.wasDestroyed == true,
            trainingRASBot2DeathState?.wasDestroyed == true,
            trainingRASBot3DeathState?.wasDestroyed == true,
            trainingRASBot4DeathState?.wasDestroyed == true,
            trainingLastBot1DeathState?.wasDestroyed == true,
            trainingLastBot2DeathState?.wasDestroyed == true,
            trainingLastBot3DeathState?.wasDestroyed == true,
            trainingLastBot4DeathState?.wasDestroyed == true,
            trainingLastBot5DeathState?.wasDestroyed == true,
        ].count(where: { $0 })
        return TrainingPostLevelResult(
            title: "Mission Successful",
            levelName: level.metadata.name,
            difficulty: .rookie,
            score:
                enemyKills
                * TrainingRobotCombatDefinition.stockTrainingScore,
            elapsedTime: elapsedTime,
            enemyKills: enemyKills,
            // Player damage, death, and restore ownership are later Phase 5
            // islands. The current normal Training path retains its source
            // initial ratings and has no admitted death or restore transition.
            shields: shields,
            energy: energy,
            deaths: 0,
            restores: 0,
            // Training's two camera goals do not carry LGF_TELCOM_LISTS, so
            // SinglePlayerPostLevelResults presents no objective rows.
            objectives: []
        )
    }

    func stopTime(at timestamp: Double) {
        precondition(timestamp.isFinite && timestamp >= lastTimestamp)
        if pauseDepth == 0 {
            pauseTimestamp = timestamp
        }
        pauseDepth += 1
    }

    func setIndoorAutoLevelMode(_ mode: IndoorAutoLevelMode) {
        indoorAutoLevelMode = mode
    }

    func startTime(at timestamp: Double) {
        precondition(timestamp.isFinite)
        guard pauseDepth > 0 else { return }
        pauseDepth -= 1
        if pauseDepth == 0 {
            let pausedAt = pauseTimestamp!
            precondition(timestamp >= pausedAt)
            lastTimestamp += timestamp - pausedAt
            pauseTimestamp = nil
        }
    }
}
