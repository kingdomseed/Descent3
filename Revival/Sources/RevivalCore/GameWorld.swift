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
    /// `Players[0].controller_bitflags`. InitPlayerNewShip enables every
    /// control (Player.cpp:1554).
    var playerControllerBitflags = PlayerControlMask.all
    /// `Players[0].invulnerable_time` while PLAYER_FLAGS_INVULNERABLE is
    /// set; `nil` while it is clear.
    var playerInvulnerableTime: Float?
    /// Hud_show_controls (hud.cpp:503).
    var hudShowControls = false

    /// AI_unique_goal_id (AImain.cpp:1557): the next goal's `goal_uid`.
    var aiUniqueGoalID: Int32 = 0
    /// AI_RenderedList (AImain.cpp:1624): the CT_AI objects the last
    /// frame's render drew (renderobject.cpp:1239), which the next
    /// AIFrameAll reads.
    var aiRenderedList: [ObjectHandle] = []

    // Osiris.
    /// The loaded level module and its state.
    var levelModule = LevelModule.none
    var osirisTimers = OsirisTimers()
    /// HUD messages and streamed sounds that scripts requested during the
    /// current update. The session moves them to the frame's presentation
    /// before the update returns, so a saved world has none.
    var presentationRequests: [ScriptPresentationRequest] = []

    // Training script state. These move into the Training level module in
    // later M1 steps.
    var trainingFollowBotDestructionState: TrainingFollowBotDestructionState?
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
    /// the canonical portal flags and goals, the initial ship and script
    /// state, and then the level start scripts (EVT_LEVELSTART).
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
        objInitPlacedObjects(level: level, playerSize: ship.presentationSize)
        initializeTrainingState(level: level)
        // StartLevel runs AIInitAll before the level script starts
        // (gamesequence.cpp:1482, :1584).
        aiInitAll(level: level)
        startLevelScripts(level: level)
    }

    /// ObjInit for the placed objects (LoadLevel.cpp:1657,
    /// ObjInit.cpp:807): a generic object gets its object_info, size, and
    /// hit points, and, for a CT_AI page, its AI frame and weapon
    /// batteries. The player gets its ship size.
    private mutating func objInitPlacedObjects(level: Level, playerSize: Float) {
        // Every placed polygon object gets its model size (ObjInit's
        // PageInPolymodel, ObjInit.cpp:788); the player gets its ship's.
        for placed in level.objects {
            let handle = ObjectHandle(placed.handle)
            if let size = level.placedObjectSize(handle) {
                objects[handle]?.size = size
            }
        }
        if let binding = level.defaultPlayerBinding {
            objects[ObjectHandle(binding.objectHandle)]?.size = playerSize
        }
        guard let infos = level.objectInfos else { return }
        for placed in level.objects {
            // IS_GENERIC: robot, powerup, clutter, building.
            guard [2, 7, 11, 16].contains(placed.type),
                  let name = placed.definition?.sourceName,
                  let infoIndex = infos.firstIndex(where: {
                      $0.name.caseInsensitiveCompare(name) == .orderedSame
                  }),
                  let object = objects[ObjectHandle(placed.handle)]
            else {
                continue
            }
            objects[object.handle] = Self.initialGenericObject(
                object,
                info: infos[infoIndex],
                infoIndex: infoIndex,
                model: level.placedObjectModel(object.handle)
            )
        }
    }

    /// D3_RAND_MAX (misc/psrand.h).
    static let randMax: Int32 = 0x7fff

    /// ps_rand (misc/psrand.cpp): the released LCG, drawn in source order.
    mutating func psRand() -> Int32 {
        authoritativeRandomState =
            authoritativeRandomState &* 214_013 &+ 2_531_011
        return Int32((authoritativeRandomState >> 16) & 0x7fff)
    }

    /// `MSAFE_OBJECT_NO_RENDER` and its inverse (`multisafe.cpp:1733`).
    /// A stale handle does nothing, as `VALIDATE_OBJECT` returns early.
    mutating func setObjectRendered(_ handle: UInt32, _ isRendered: Bool) {
        objects[ObjectHandle(handle)]?.renderType =
            isRendered ? .polyobj : .none
    }

    /// A double-sided `aPortalRenderSet` (`DallasFuncs.cpp:1098`) on a
    /// portal of the room with this source index.
    mutating func setPortalRenderFaces(
        _ rendersFaces: Bool,
        roomSourceIndex: Int,
        portalIndex: Int,
        level: Level
    ) {
        setPortalRender(
            room: roomSourceIndex,
            portal: portalIndex,
            state: rendersFaces,
            doubleSided: true,
            level: level
        )
    }

}
