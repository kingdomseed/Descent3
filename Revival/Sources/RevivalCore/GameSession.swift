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
    /// The results of the level after a script ended it.
    var postLevelResult: PostLevelResult?
    var levelOutcome: LevelSessionOutcome?

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

    // Forwarding accessors. The session's player frame reads and writes
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
        let presentations = ObjectPresentationLookup(level)
        let modelBySource = Dictionary(
            uniqueKeysWithValues: level.models.map { ($0.source, $0) }
        )
        for object in world.objects {
            guard object.handle != player.handle,
                  case let .room(roomSourceIndex) = object.location,
                  visitedRooms.contains(roomSourceIndex),
                  let presentation = presentations.presentation(of: object),
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
    /// The player closed the results of the ended level.
    func acknowledgeLevelResult() -> LevelSessionOutcome? {
        guard postLevelResult != nil else { return nil }
        levelOutcome = .completed
        return levelOutcome
    }

    /// GameSequencer's GAMESTATE_LVLEND and GAMESTATE_LVLFAILED
    /// (gamesequence.cpp:1240-1262), after the frame in which a script
    /// asked for them: SuspendControls, then EndLevel (:1844): the results
    /// (PostLevelResults, :1891), and FreeThisLevel's FreeLevelScript,
    /// which sends the level EVT_LEVELEND (Mission.cpp:1706). The next
    /// level, or the restart of a failed one, belongs to the mission flow
    /// (M3); the session stops at the results (architecture.md section 9).
    func sequenceLevelEnd(elapsedTime: Float) -> LevelEndFrame? {
        guard let request = world.gameStateRequest else { return nil }
        if postLevelResult == nil {
            postLevelResult = makePostLevelResult(
                succeeded: request == .levelEnd,
                elapsedTime: elapsedTime
            )
            levelOutcome = .awaitingResultAcknowledgement
            world.osirisCallLevelEvent(.levelEnd, level: level)
            // The level's script requests end with the level.
            world.presentationRequests = []
        }
        guard let postLevelResult else { return nil }
        return LevelEndFrame(
            endLevelState: request == .levelEnd ? .succeeded : .failed,
            controlsAreSuspended: true,
            presentation: .init(
                title: postLevelResult.title,
                levelName: level.metadata.name,
                difficulty: .rookie,
                showsHUD: false,
                playsGameplayAudio: false,
                showsCockpit: false,
                showsHeadlightIndicator: false
            ),
            postLevelResult: postLevelResult
        )
    }

    func makePostLevelResult(
        succeeded: Bool,
        elapsedTime: Float
    ) -> PostLevelResult {
        PostLevelResult(
            title: succeeded ? "Mission Successful" : "Mission Failed",
            levelName: level.metadata.name,
            difficulty: .rookie,
            // Players[0].score and num_kills_level (PlayerScoreAdd,
            // Player.cpp:3853).
            score: Int(world.playerScore),
            elapsedTime: elapsedTime,
            enemyKills: Int(world.playerKillsLevel),
            // The deaths and restores arrive with player death and respawn
            // (M2) and save counts (M4).
            shields: shields,
            energy: energy,
            deaths: 0,
            restores: 0,
            // The objective rows list the goals with LGF_TELCOM_LISTS
            // (SinglePlayerPostLevelResults), which arrive with TelCom (M4).
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
    func takeScriptPresentation() -> [PresentationFeedback] {
        let requests = pendingMenuPresentation + world.presentationRequests
        pendingMenuPresentation = []
        world.presentationRequests = []
        return requests.map { request in
            switch request {
            case let .hudMessage(message):
                PresentationFeedback(
                    hudMessages: [message],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                )
            case let .streamedAudio(name, _):
                PresentationFeedback(
                    hudMessages: [],
                    voiceSourceName: level.scripting?.streamedAudio
                        .first { $0.name == name }?.key ?? name,
                    voicePrecedesHUDMessages: false
                )
            case let .sound2D(index, volume):
                PresentationFeedback(
                    hudMessages: [],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: level.soundClips[index].logicalName,
                    soundEventVolume: volume
                )
            case let .sound(name, volume):
                PresentationFeedback(
                    hudMessages: [],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: name,
                    soundEventVolume: volume == 1 ? nil : volume
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
