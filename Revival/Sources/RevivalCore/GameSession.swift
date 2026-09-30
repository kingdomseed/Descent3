// SPDX-License-Identifier: GPL-3.0-or-later
//
// The per-app owner of one running level. It holds the immutable canonical
// level, the authoritative `GameWorld`, and only non-authoritative
// wall-clock and pause state (architecture.md section 2).

import Foundation

enum GameSessionRestoreError: Error, Equatable {
    case invalidWorld(GameWorldValidationError)
}

final class GameSession {
    let level: Level
    var world: GameWorld

    var lastTimestamp: Double
    var pauseDepth = 0
    private var pauseTimestamp: Double?

    init(
        level: Level,
        presentationReadyTimestamp: Double,
        authoritativeRandomSeed: UInt32 = 1
    ) {
        precondition(presentationReadyTimestamp.isFinite)
        precondition(level.defaultPlayerBinding != nil)
        self.level = level
        world = GameWorld(
            level: level,
            authoritativeRandomSeed: authoritativeRandomSeed
        )
        lastTimestamp = presentationReadyTimestamp
    }

    /// Resumes a saved world. The world is validated structurally once, at
    /// this boundary (architecture.md section 7).
    init(
        level: Level,
        world: GameWorld,
        resumedAtTimestamp: Double
    ) throws {
        precondition(resumedAtTimestamp.isFinite)
        do {
            try world.validate(against: level)
        } catch {
            throw GameSessionRestoreError.invalidWorld(error)
        }
        self.level = level
        self.world = world
        lastTimestamp = resumedAtTimestamp
    }

    // Forwarding accessors. The Training extension code reads and writes
    // these names directly; the storage is `world`. Later M1 steps move that
    // code onto `GameWorld` methods and delete these.
    var frameDuration: Float {
        get { world.frameDuration }
        set { world.frameDuration = newValue }
    }
    var gameTime: Float {
        get { world.gameTime }
        set { world.gameTime = newValue }
    }
    var authoritativeRandomState: UInt32 {
        get { world.authoritativeRandomState }
        set { world.authoritativeRandomState = newValue }
    }
    var velocity: Vector3 {
        get { world.velocity }
        set { world.velocity = newValue }
    }
    var angularVelocity: Vector3 {
        get { world.angularVelocity }
        set { world.angularVelocity = newValue }
    }
    var turnrollFixedAngle: Float {
        get { world.turnrollFixedAngle }
        set { world.turnrollFixedAngle = newValue }
    }
    var indoorAutoLevelMode: IndoorAutoLevelMode {
        get { world.indoorAutoLevelMode }
        set { world.indoorAutoLevelMode = newValue }
    }
    var afterburnerFuel: Float {
        get { world.afterburnerFuel }
        set { world.afterburnerFuel = newValue }
    }
    var afterburnerIsActive: Bool {
        get { world.afterburnerIsActive }
        set { world.afterburnerIsActive = newValue }
    }
    var energy: Float {
        get { world.energy }
        set { world.energy = newValue }
    }
    var shields: Float {
        get { world.shields }
        set { world.shields = newValue }
    }
    var afterburnerMagnitude: Float {
        get { world.afterburnerMagnitude }
        set { world.afterburnerMagnitude = newValue }
    }
    var wiggleFalloff: Float {
        get { world.wiggleFalloff }
        set { world.wiggleFalloff = newValue }
    }
    var lastThrustTime: Float {
        get { world.lastThrustTime }
        set { world.lastThrustTime = newValue }
    }
    var playerHeadlightIsOn: Bool {
        get { world.playerHeadlightIsOn }
        set { world.playerHeadlightIsOn = newValue }
    }
    var playerRearViewState: PlayerRearViewState? {
        get { world.playerRearViewState }
        set { world.playerRearViewState = newValue }
    }
    var playerConcussionState: PlayerConcussionState? {
        get { world.playerConcussionState }
        set { world.playerConcussionState = newValue }
    }
    var playerYellowFlareState: PlayerYellowFlareState? {
        get { world.playerYellowFlareState }
        set { world.playerYellowFlareState = newValue }
    }
    var trainingDodgeAttemptState: TrainingDodgeAttemptState? {
        get { world.trainingDodgeAttemptState }
        set { world.trainingDodgeAttemptState = newValue }
    }
    var trainingManeuverFollowState: TrainingManeuverFollowState? {
        get { world.trainingManeuverFollowState }
        set { world.trainingManeuverFollowState = newValue }
    }
    var trainingGalleryBarrierState: TrainingGalleryBarrierState? {
        get { world.trainingGalleryBarrierState }
        set { world.trainingGalleryBarrierState = newValue }
    }
    var trainingRobotGuidebotState: TrainingRobotGuidebotState? {
        get { world.trainingRobotGuidebotState }
        set { world.trainingRobotGuidebotState = newValue }
    }
    var trainingCameraMonitorState: TrainingCameraMonitorState? {
        get { world.trainingCameraMonitorState }
        set { world.trainingCameraMonitorState = newValue }
    }
    var trainingKillbotEntryState: TrainingKillbotEntryState? {
        get { world.trainingKillbotEntryState }
        set { world.trainingKillbotEntryState = newValue }
    }
    var trainingRASBot1DeathState: TrainingRASBot1DeathState? {
        get { world.trainingRASBot1DeathState }
        set { world.trainingRASBot1DeathState = newValue }
    }
    var trainingRASBot2DeathState: TrainingRASBot2DeathState? {
        get { world.trainingRASBot2DeathState }
        set { world.trainingRASBot2DeathState = newValue }
    }
    var trainingRASBot3DeathState: TrainingRASBot3DeathState? {
        get { world.trainingRASBot3DeathState }
        set { world.trainingRASBot3DeathState = newValue }
    }
    var trainingRASBot4DeathState: TrainingRASBot4DeathState? {
        get { world.trainingRASBot4DeathState }
        set { world.trainingRASBot4DeathState = newValue }
    }
    var trainingLastBot1DeathState: TrainingLastBot1DeathState? {
        get { world.trainingLastBot1DeathState }
        set { world.trainingLastBot1DeathState = newValue }
    }
    var trainingLastBot2DeathState: TrainingLastBot2DeathState? {
        get { world.trainingLastBot2DeathState }
        set { world.trainingLastBot2DeathState = newValue }
    }
    var trainingLastBot3DeathState: TrainingLastBot3DeathState? {
        get { world.trainingLastBot3DeathState }
        set { world.trainingLastBot3DeathState = newValue }
    }
    var trainingLastBot4DeathState: TrainingLastBot4DeathState? {
        get { world.trainingLastBot4DeathState }
        set { world.trainingLastBot4DeathState = newValue }
    }
    var trainingLastBot5DeathState: TrainingLastBot5DeathState? {
        get { world.trainingLastBot5DeathState }
        set { world.trainingLastBot5DeathState = newValue }
    }
    var trainingInvulnerabilityPickupState: TrainingInvulnerabilityPickupState? {
        get { world.trainingInvulnerabilityPickupState }
        set { world.trainingInvulnerabilityPickupState = newValue }
    }
    var trainingCloakPickupState: TrainingCloakPickupState? {
        get { world.trainingCloakPickupState }
        set { world.trainingCloakPickupState = newValue }
    }
    var trainingLastRoomState: TrainingLastRoomState? {
        get { world.trainingLastRoomState }
        set { world.trainingLastRoomState = newValue }
    }
    var trainingFinalRoomEntryState: TrainingFinalRoomEntryState? {
        get { world.trainingFinalRoomEntryState }
        set { world.trainingFinalRoomEntryState = newValue }
    }
    var trainingFinalBotsCompletionState: TrainingFinalBotsCompletionState? {
        get { world.trainingFinalBotsCompletionState }
        set { world.trainingFinalBotsCompletionState = newValue }
    }
    var trainingFinalGoalState: TrainingFinalGoalState? {
        get { world.trainingFinalGoalState }
        set { world.trainingFinalGoalState = newValue }
    }
    var trainingPostLevelResult: TrainingPostLevelResult? {
        get { world.trainingPostLevelResult }
        set { world.trainingPostLevelResult = newValue }
    }
    var trainingSessionOutcome: TrainingSessionOutcome? {
        get { world.trainingSessionOutcome }
        set { world.trainingSessionOutcome = newValue }
    }

    func destroyTrainingRobot(handle: UInt32) {
        guard let chain = level.trainingRobotGuidebotChain,
              handle == chain.destroyRobotObjectHandle,
              var state = trainingRobotGuidebotState,
              !state.robotWasDestroyed,
              world.objects[ObjectHandle(handle)] != nil
        else {
            return
        }
        state.destructionTimerRemaining = chain.destructionDelay
        if var galleryState = trainingGalleryBarrierState {
            galleryState.markerLightDistance =
                level.trainingGalleryBarrier!.openMarkerLightDistance
            trainingGalleryBarrierState = galleryState
        }
        openTrainingGalleryBarrier(in: &world, level: level)
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
        world.objects.delete(ObjectHandle(handle))
    }

    func destroyTrainingRASBot1(handle: UInt32) {
        guard let chain = level.trainingRASBot1DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot1DeathState,
              !state.wasDestroyed,
              world.objects[ObjectHandle(handle)] != nil
        else {
            return
        }
        world.objects.delete(ObjectHandle(handle))
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot1DeathState = state
    }

    func destroyTrainingRASBot2(handle: UInt32) {
        guard let chain = level.trainingRASBot2DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot2DeathState,
              !state.wasDestroyed,
              world.objects[ObjectHandle(handle)] != nil
        else {
            return
        }
        world.objects.delete(ObjectHandle(handle))
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot2DeathState = state
    }

    func destroyTrainingRASBot3(handle: UInt32) {
        guard let chain = level.trainingRASBot3DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot3DeathState,
              !state.wasDestroyed,
              world.objects[ObjectHandle(handle)] != nil
        else {
            return
        }
        world.objects.delete(ObjectHandle(handle))
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot3DeathState = state
    }

    func destroyTrainingRASBot4(handle: UInt32) {
        guard let chain = level.trainingRASBot4DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingRASBot4DeathState,
              !state.wasDestroyed,
              world.objects[ObjectHandle(handle)] != nil
        else {
            return
        }
        world.objects.delete(ObjectHandle(handle))
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingRASBot4DeathState = state
    }

    func destroyTrainingLastBot1(handle: UInt32) {
        guard let chain = level.trainingLastBot1DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot1DeathState,
              !state.wasDestroyed,
              world.objects[ObjectHandle(handle)] != nil
        else {
            return
        }
        world.objects.delete(ObjectHandle(handle))
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot1DeathState = state
    }

    func destroyTrainingLastBot2(handle: UInt32) {
        guard let chain = level.trainingLastBot2DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot2DeathState,
              !state.wasDestroyed,
              world.objects[ObjectHandle(handle)] != nil
        else {
            return
        }
        world.objects.delete(ObjectHandle(handle))
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot2DeathState = state
    }

    func destroyTrainingLastBot3(handle: UInt32) {
        guard let chain = level.trainingLastBot3DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot3DeathState,
              !state.wasDestroyed,
              world.objects[ObjectHandle(handle)] != nil
        else {
            return
        }
        world.objects.delete(ObjectHandle(handle))
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot3DeathState = state
    }

    func destroyTrainingLastBot4(handle: UInt32) {
        guard let chain = level.trainingLastBot4DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot4DeathState,
              !state.wasDestroyed,
              world.objects[ObjectHandle(handle)] != nil
        else {
            return
        }
        world.objects.delete(ObjectHandle(handle))
        state.wasDestroyed = true
        state.shields = min(state.shields, -0.000_001)
        trainingLastBot4DeathState = state
    }

    func destroyTrainingLastBot5(handle: UInt32) {
        guard let chain = level.trainingLastBot5DeathChain,
              handle == chain.robotObjectHandle,
              var state = trainingLastBot5DeathState,
              !state.wasDestroyed,
              world.objects[ObjectHandle(handle)] != nil
        else {
            return
        }
        world.objects.delete(ObjectHandle(handle))
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
              world.objects[ObjectHandle(handoff.followBotObjectHandle)] != nil
        else {
            return
        }
        world.objects.delete(ObjectHandle(handoff.followBotObjectHandle))
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
              world.objects[ObjectHandle(handoff.destroyBot1ObjectHandle)] != nil
        else {
            return
        }
        world.objects.delete(ObjectHandle(handoff.destroyBot1ObjectHandle))
        destroyBot1Destruction.destroyBot1WasDestroyed = true
        destroyBot1Destruction.destroyBot1Shields = min(
            destroyBot1Destruction.destroyBot1Shields,
            -0.000_001
        )
        if destroyBot1Destruction.script028Count < 1 {
            destruction.destroyBot1IsVisible = false
            destruction.destroyBot2IsVisible = true
            // Script 028 unghosts DestroyBot2, which Script 000 ghosted
            // (TrainingMission.cpp:2019).
            world.aObjGhostSet(0, ObjectHandle(handoff.destroyBot2ObjectHandle))
            world.setObjectRendered(handoff.destroyBot2ObjectHandle, true)
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
        from player: GameObject
    ) -> PlayerFastHeadlightFrame {
        guard case let .room(startRoomSourceIndex) = player.location else {
            preconditionFailure("The validated default player is indoor.")
        }
        let start = player.position
        let forward = player.orientation.forward
        let end = start + forward * 300
        let wallTrace = traceIndoorMovement(
            in: level,
            roomStates: world.rooms,
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
        for object in world.objects {
            guard object.handle != player.handle,
                  case let .room(roomSourceIndex) = object.location,
                  visitedRooms.contains(roomSourceIndex),
                  let presentation =
                    presentationByHandle[object.handle.rawValue],
                  object.renderType == .polyobj,
                  let model = modelBySource[presentation.primaryModel]
            else {
                continue
            }
            let radius = sourceObjectPresentationSize(
                model: model,
                objectType: object.type.rawValue
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

    /// Moves the script presentation requests of this update into the
    /// frame's presentation list, in request order. A streamed file name
    /// becomes the level's canonical voice key (package schema 12). The
    /// voice path plays each clip at its imported volume, and every
    /// translated call passes volume 1. A 2D sound plays its sound clip at
    /// the clip's import volume times the requested volume.
    func takeScriptPresentation() -> [TrainingOpeningFeedback] {
        let requests = world.presentationRequests
        world.presentationRequests = []
        return requests.map { request in
            switch request {
            case let .hudMessage(message):
                TrainingOpeningFeedback(
                    hudMessages: [message],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                )
            case let .streamedAudio(name, _):
                TrainingOpeningFeedback(
                    hudMessages: [],
                    voiceSourceName: level.scripting?.streamedAudio
                        .first { $0.name == name }?.key ?? name,
                    voicePrecedesHUDMessages: false
                )
            case let .sound2D(index, volume):
                TrainingOpeningFeedback(
                    hudMessages: [],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: level.soundClips[index].logicalName,
                    soundEventVolume: volume
                )
            }
        }
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
