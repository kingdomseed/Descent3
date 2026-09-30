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
    /// Game_interface_mode == GAME_BUDDY_INTERFACE: F4 asked for the buddy
    /// menu this frame (GameLoop.cpp:1493). The app opens it after the frame
    /// (BuddyMenu.swift).
    var buddyMenuIsRequested = false
    /// The open buddy menu, while the game is paused for it.
    var buddyMenu: BuddyMenu?
    /// Presentation the Guide-Bot asked for while the game was paused for
    /// the buddy menu. The next frame presents it first.
    var pendingMenuPresentation: [ScriptPresentationRequest] = []

    init(
        level: Level,
        presentationReadyTimestamp: Double,
        authoritativeRandomSeed: UInt32 = 1
    ) {
        precondition(presentationReadyTimestamp.isFinite)
        precondition(level.defaultPlayerBinding != nil)
        let level = level.withLoadedBOATables()
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
        let level = level.withLoadedBOATables()
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
    var playerYellowFlareState: PlayerYellowFlareState? {
        get { world.playerYellowFlareState }
        set { world.playerYellowFlareState = newValue }
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
    var trainingInvulnerabilityPickupState: TrainingInvulnerabilityPickupState? {
        get { world.trainingInvulnerabilityPickupState }
        set { world.trainingInvulnerabilityPickupState = newValue }
    }
    var trainingCloakPickupState: TrainingCloakPickupState? {
        get { world.trainingCloakPickupState }
        set { world.trainingCloakPickupState = newValue }
    }
    var trainingFinalRoomEntryState: TrainingFinalRoomEntryState? {
        get { world.trainingFinalRoomEntryState }
        set { world.trainingFinalRoomEntryState = newValue }
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
        TrainingPostLevelResult(
            title: "Mission Successful",
            levelName: level.metadata.name,
            difficulty: .rookie,
            // Players[0].score and num_kills_level (PlayerScoreAdd,
            // Player.cpp:3853).
            score: Int(world.playerScore),
            elapsedTime: elapsedTime,
            enemyKills: Int(world.playerKillsLevel),
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
    /// frame's presentation list, in request order, after those the
    /// Guide-Bot made while the buddy menu paused the game. A streamed file name
    /// becomes the level's canonical voice key (package schema 12). The
    /// voice path plays each clip at its imported volume, and every
    /// translated call passes volume 1. A 2D sound plays its sound clip at
    /// the clip's import volume times the requested volume.
    func takeScriptPresentation() -> [TrainingOpeningFeedback] {
        let requests = pendingMenuPresentation + world.presentationRequests
        pendingMenuPresentation = []
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
            case let .sound(name):
                TrainingOpeningFeedback(
                    hudMessages: [],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: name
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
