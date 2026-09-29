// SPDX-License-Identifier: GPL-3.0-or-later
//
// All mutable authoritative game state. It replaces the legacy globals that
// GameFrame (Descent3/GameLoop.cpp:2869) mutates: Gametime and Frametime,
// the ps_rand state, the Objects array (object.cpp), Rooms[].portals[].flags,
// and Level_goals. A Codable value of it is the save (architecture.md
// section 7).

import Foundation

/// The mutable part of one room. `Rooms[r].portals[p].flags` changes at
/// runtime (for example `aPortalRenderSet`). The rest of the room is
/// immutable canonical content in `Level.rooms`.
struct RoomState: Codable, Equatable, Sendable {
    var portalFlags: [UInt32]

    /// The level-start state of every room, indexed like `Level.rooms`.
    static func canonical(_ level: Level) -> [RoomState] {
        level.rooms.map { RoomState(portalFlags: $0.portals.map(\.flags)) }
    }
}

struct GameWorld: Codable, Equatable, Sendable {
    /// Frametime. The static/InitGame value is 0.1 s.
    var frameDuration: Float = 0.1
    /// Gametime.
    var gameTime: Float = 0
    /// The `ps_rand` LCG state.
    var authoritativeRandomState: UInt32

    var objects: ObjectTable
    /// Indexed like `Level.rooms`.
    var rooms: [RoomState]
    /// Level_goals, indexed like `Level.goals`.
    var goals: [LevelGoal]

    // Player ship.
    var velocity = Vector3.zero
    var angularVelocity: Vector3
    var turnrollFixedAngle: Float = 0
    var indoorAutoLevelMode = IndoorAutoLevelMode.newPlayer
    var afterburnerFuel: Float = 5
    var afterburnerIsActive = false
    var energy: Float = 100
    var shields: Float = 100
    var afterburnerMagnitude: Float = 0
    var wiggleFalloff: Float = 0
    var lastThrustTime: Float = 0
    var playerHeadlightIsOn = false
    var playerRearViewState: PlayerRearViewState?
    var playerConcussionState: PlayerConcussionState?
    var playerYellowFlareState: PlayerYellowFlareState?

    // Training script state. These move into the Training level module in
    // later M1 steps.
    var trainingOpeningState: TrainingOpeningState?
    var trainingDodgeAttemptState: TrainingDodgeAttemptState?
    var trainingManeuverFollowState: TrainingManeuverFollowState?
    var trainingGalleryBarrierState: TrainingGalleryBarrierState?
    var trainingRobotGuidebotState: TrainingRobotGuidebotState?
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
    var trainingInvulnerabilityPickupState:
        TrainingInvulnerabilityPickupState?
    var trainingCloakPickupState: TrainingCloakPickupState?
    var trainingLastRoomState: TrainingLastRoomState?
    var trainingFinalRoomEntryState: TrainingFinalRoomEntryState?
    var trainingFinalBotsCompletionState: TrainingFinalBotsCompletionState?
    var trainingFinalGoalState: TrainingFinalGoalState?
    var trainingPostLevelResult: TrainingPostLevelResult?
    var trainingSessionOutcome: TrainingSessionOutcome?

    /// The world at level start: the placed objects in their stored slots,
    /// the canonical portal flags and goals, and the initial ship and script
    /// state.
    init(level: Level, authoritativeRandomSeed: UInt32 = 1) {
        precondition(level.defaultPlayerBinding != nil)
        let binding = level.defaultPlayerBinding!
        let ship = level.shipDefinitions.first { $0.source == binding.ship }!
        authoritativeRandomState = authoritativeRandomSeed
        objects = ObjectTable(level: level)
        rooms = RoomState.canonical(level)
        goals = level.goals
        angularVelocity = ship.physics.initialAngularVelocity
        playerConcussionState = ship.playerConcussion == nil ? nil : .init()
        playerYellowFlareState = level.shipDefinitions.first?
            .playerYellowFlare == nil ? nil : .init()
        initializeTrainingState(level: level)
    }

    /// `MSAFE_OBJECT_NO_RENDER` and its inverse (`multisafe.cpp:1733`).
    /// A stale handle does nothing, as `VALIDATE_OBJECT` returns early.
    mutating func setObjectRendered(_ handle: UInt32, _ isRendered: Bool) {
        objects[ObjectHandle(handle)]?.renderType =
            isRendered ? .polyobj : .none
    }

    /// Sets or clears PF_RENDER_FACES on a portal and on its reciprocal
    /// portal, as a double-sided `aPortalRenderSet` does
    /// (`DallasFuncs.cpp:1098`, `MSAFE_ROOM_PORTAL_RENDER` in
    /// `multisafe.cpp:1447`).
    mutating func setPortalRenderFaces(
        _ rendersFaces: Bool,
        roomSourceIndex: Int,
        portalIndex: Int,
        level: Level
    ) {
        let roomIndex = level.rooms.firstIndex {
            $0.sourceIndex == roomSourceIndex
        }!
        let portal = level.rooms[roomIndex].portals[portalIndex]
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        if rendersFaces {
            rooms[roomIndex].portalFlags[portalIndex] |= 1
            rooms[connectedRoomIndex].portalFlags[portal.connectedPortal] |= 1
        } else {
            rooms[roomIndex].portalFlags[portalIndex] &= ~UInt32(1)
            rooms[connectedRoomIndex].portalFlags[portal.connectedPortal]
                &= ~UInt32(1)
        }
    }

}
