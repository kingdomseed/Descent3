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
    /// `last_render_time`: the Gametime of the last frame that rendered the
    /// room (render.cpp:2930), 0 at level start (room.cpp:556).
    var lastRenderTime: Float = 0

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
    /// The C library `rand()` state of the game module DLL (AIGame.dll):
    /// separate from `ps_rand` (misc/psrand.cpp:39). The CRT starts it at 1;
    /// the module seeds it only in its thief code (AIGame.cpp:1851, :6213,
    /// :7493).
    var gameModuleRandomState: UInt32 = 1

    var objects: ObjectTable
    /// Indexed like `Level.rooms`.
    var rooms: [RoomState]
    /// Level_goals, indexed like `Level.goals`.
    var goals: [LevelGoal]
    /// `Triggers[].flags` (trigger.h:113), indexed like `Level.triggers`
    /// (Trigger.swift).
    var triggerFlags: [UInt16]

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
    /// `Players[0].weapon[PW_PRIMARY]` and `[PW_SECONDARY]`: the selected
    /// battery and how long the fire control has been held.
    var playerWeapons = [
        PlayerWeaponState(index: PlayerWeaponState.laserIndex),
        PlayerWeaponState(index: PlayerWeaponState.concussionIndex),
    ]
    /// `Players[0].weapon_ammo`, one per ship battery.
    var playerWeaponAmmo = Array(
        repeating: 0,
        count: PlayerWeaponState.maximumPlayerWeapons
    )
    /// `Players[0].score`, `num_kills_level`, and `friendly_kills_level`
    /// (PlayerScoreAdd, Player.cpp:3853).
    var playerScore: Int32 = 0
    var playerKillsLevel: Int16 = 0
    var playerFriendlyKillsLevel: Int16 = 0
    /// VisEffects (viseffect.cpp): the live visual effects.
    var visEffects: [VisEffect] = []
    /// GameEvent[MAX_EVENTS] (gameevent.cpp:35): the pending normal events.
    var gameEvents: [GameEvent?] = Array(
        repeating: nil,
        count: GameEvent.capacity
    )
    /// `Players[0].controller_bitflags`. InitPlayerNewShip enables every
    /// control (Player.cpp:1554).
    var playerControllerBitflags = PlayerControlMask.all
    /// `Players[0].invulnerable_time` while PLAYER_FLAGS_INVULNERABLE is
    /// set; `nil` while it is clear.
    var playerInvulnerableTime: Float?
    /// PLAYER_FLAGS_DYING or PLAYER_FLAGS_DEAD with the death values
    /// StartPlayerDeath keeps; `nil` while the player is alive.
    var playerDeath: PlayerDeathState?
    /// `Players[0].num_deaths_level`.
    var playerDeathsLevel: Int16 = 0
    /// Hud_show_controls (hud.cpp:503).
    var hudShowControls = false
    /// `Players[0].inventory` (Inventory.swift).
    var playerInventory = PlayerInventory()
    /// The pilot's Guide-Bot name (pilot::guidebot_name, pilot_class.cpp:202),
    /// which MSAFE_MISC_GUIDEBOT_NAME reads.
    var playerGuideBotName = "GB"
    /// Buddy_handle[0] (AImain.cpp:1628): the Guide-Bot AIInitAll makes.
    var buddyHandle: ObjectHandle = .none
    /// The sound handles and the looping object sounds (SoundSystem.swift).
    var soundSystem = SoundSystemState()

    /// AI_unique_goal_id (AImain.cpp:1557): the next goal's `goal_uid`.
    var aiUniqueGoalID: Int32 = 0
    /// AI_RenderedList (AImain.cpp:1624): the CT_AI objects the last
    /// frame's render drew (renderobject.cpp:1239), which the next
    /// AIFrameAll reads.
    var aiRenderedList: [ObjectHandle] = []
    /// The view the last frame rendered (the g3 view state that
    /// IsPointVisible reads, renderobject.cpp:1779), or `nil` before the
    /// first render.
    var lastRenderCamera: RoomCamera?
    /// PhysicsLinkList (object.cpp:2830): the MT_OBJ_LINKED objects the
    /// ObjDoFrameAll loop listed, which its tail moves. Empty between
    /// frames, so a saved world has none.
    var physicsLinkList: [ObjectHandle] = []
    /// The lights DoObjectLight cast this frame (ObjectLighting.swift). The
    /// session moves them to the frame's presentation before the update
    /// returns, so a saved world has none.
    var objectLights: [ObjectLightRequest] = []

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
    var trainingCameraMonitorState: TrainingCameraMonitorState?
    var trainingKillbotEntryState: TrainingKillbotEntryState?
    var trainingInvulnerabilityPickupState:
        TrainingInvulnerabilityPickupState?
    var trainingCloakPickupState: TrainingCloakPickupState?
    var trainingFinalRoomEntryState: TrainingFinalRoomEntryState?
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
        triggerFlags = Self.initialTriggerFlags(level)
        angularVelocity = ship.physics.initialAngularVelocity
        objInitPlacedObjects(level: level, playerSize: ship.presentationSize)
        // ObjLink's BigObjAdd (object.cpp:1438): an indoor object of at
        // least MIN_BIG_OBJ_RAD (16) is OF_BIG_OBJECT.
        for slot in 0..<ObjectTable.capacity {
            guard let object = objects.slots[slot],
                  case .room = object.location,
                  object.size >= 16
            else {
                continue
            }
            objects[object.handle]?.flags |= GameObject.bigObjectFlag
        }
        // DeleteMultiplayerObjects (Player.cpp:1365), from StartLevel in
        // single player (gamesequence.cpp:1572): every other player object
        // is deleted, in slot order, before the level script and AI start.
        for slot in 0..<ObjectTable.capacity {
            guard let object = objects.slots[slot], object.type == .player,
                  object.handle.rawValue != binding.objectHandle
            else {
                continue
            }
            objects.delete(object.handle)
        }
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
            // ObjSetRenderPolyobj (ObjInit.cpp:633) for the generic objects
            // (:779) and doors (ObjInitDoor, :1064).
            if [2, 7, 11, 16, 17].contains(placed.type),
               level.placedObjectModel(handle) != nil {
                objects[handle]?.flags |= GameObject.polygonObjectFlag
            }
        }
        if let binding = level.defaultPlayerBinding {
            // InitPlayerNewShip (Player.cpp:1500-1505, :2507): the ship's
            // size and flags, MAX_WBS_PER_OBJ cleared batteries, and
            // 2 + MAX_DIFFICULTY_LEVELS - DIFF_LEVEL concussion missiles.
            let player = ObjectHandle(binding.objectHandle)
            objects[player]?.size = playerSize
            objects[player]?.flags = GameObject.polygonObjectFlag
                | GameObject.destroyableFlag
            objects[player]?.weaponBatteries = Self.clearedWeaponBatteries(
                count: PlayerWeaponState.maximumPlayerWeapons
            )
            playerWeaponAmmo[PlayerWeaponState.concussionIndex] =
                2 + Difficulty.levelCount - Difficulty.level
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
