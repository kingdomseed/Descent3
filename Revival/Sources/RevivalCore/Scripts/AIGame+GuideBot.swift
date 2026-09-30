// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/AIGame.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): the GuideBot class: its constants
// and memory (:1336-1536, guidebot_data), the command texts (:1433-1459),
// ReInitAmbient (:4517), DoMessage (:4538), SetSubMode (:4559), SetMode
// (:4583), InitExtinguish (:4834), MakeCommandList (:4879),
// AddGetToGoalCommonGoals (:4946), DoExternalCommands (:4952), DoCollide
// (:5496), DoUse (:5548), DoInit (:5579), DoNotify (:5660), DoPowerupCheck
// (:6002), DoFrame (:6044), and CallEvent (:6146).
//
// The engine calls go through the translated Osiris functions
// (OsirisPredefs.swift, Multisafe.swift, SoundSystem.swift). The memory is
// read from the object at each use and written back before each engine
// call, because the engine may re-enter the script (architecture.md
// section 6). Not yet here, with their systems (architecture.md section 9):
// the custom animations (Obj_SetCustomAnim) and the animation frame, which
// reads 0; the burning effect (Obj_Burning, Obj_IsEffect: no object carries
// effect info before M2); and the extinguisher smoke spews and the
// anti-virus lightning bolt, which are drawn effects.

import Foundation

/// The GuideBot instance: `memory` is nil until EVT_AI_INIT allocates it.
struct GuideBotState: Codable, Equatable, Sendable {
    var memory: GuideBotMemory? = nil
}

/// guidebot_data (AIGame.cpp:1476). The original leaves some fields
/// unset until they are first written; they start at zero here.
struct GuideBotMemory: Codable, Equatable, Sendable {
    /// `name` (7 characters).
    var name = ""
    /// `powerups[NUM_GB_USABLE_POWERUPS]`.
    var powerups: [Int8] = Array(repeating: 0, count: 5)
    /// `sounds[NUM_GB_SOUNDS]`: sound handles, -1 for none.
    var sounds: [Int32] = Array(repeating: -1, count: 5)
    var modeTime: Float = 0
    /// `mp_slot`: the owner's player number.
    var playerSlot = 0
    /// `my_player`: the owner's object.
    var player: ObjectHandle = .none
    /// `f_parented`: the parent link keeps the buddy from hitting its
    /// player.
    var isParented = false
    /// `f_pickup`: marked for pickup by the owner.
    var isMarkedForPickup = false
    var mode: Int32 = 0
    var subMode: Int32 = 0
    /// `g_powerup`: the object of the last find command.
    var foundObject: ObjectHandle = .none
    /// `num_pg`, `num_sg`.
    var numberOfPrimaryGoals: Int32 = 0
    var numberOfSecondaryGoals: Int32 = 0
    /// `camera_obj`: the R-type camera.
    var cameraObject: ObjectHandle = .none
    /// `last_command`: -1 for none.
    var lastCommand: Int32 = -1
    var lastAtGoalTime: Float = 0
    var nextAmbientTime: Float = 0
    var lastSoundTime: Float = 0
    /// The GBF_ flags.
    var flags: Int32 = 0
    var lastRetreatTime: Float = 0
    var returnTime: Float = 0
    /// `me`.
    var me: ObjectHandle = .none
    /// `last_anim`.
    var lastAnimationFrame: Float = 0
    var extinguishSpewID: Int32 = 0
    /// `extinguish_obj_list[0..<num_extinguish_objs]` (at most 5).
    var extinguishObjects: [ObjectHandle] = []
    var extinguishObjectTime: Float = 0
    /// `max_acc`, `max_speed`: the page values.
    var maximumAcceleration: Float = 0
    var maximumSpeed: Float = 0
    /// `av_robot_list` and `av_revert_time` (at most MAX_AV_ROBOTS).
    var antivirusRobots: [ObjectHandle] = []
    var antivirusRevertTimes: [Float] = []
    var speedTimeLeft: Float = 0
    var timeUntilNextPlayerVisibilityCheck: Float = 0
    var timeUntilNextFlare: Float = 0
    /// `amb_camera_handle`: the invisible object ReInitAmbient circles.
    var ambientCamera: ObjectHandle = .none
    var nextPowerupCheckTime: Float = 0
    /// `powerup_ids[6]`: the pages of the buddy powerups, -1 for none.
    var powerupPages: [Int] = Array(repeating: -1, count: 6)
}

/// COM_GET_MENU's `gb_menu` (osiris_common.h): the command menu.
struct GuideBotMenu: Equatable, Sendable {
    struct Command: Equatable, Sendable {
        /// `command_id`: a GBC_ command.
        let id: Int32
        let text: String
        /// GBCT_STRING_DIALOG, with its `dialog_text`; otherwise
        /// GBCT_EXIT_IMMEDIATELY.
        let dialogText: String?
    }

    let title: String
    let commands: [Command]
}

enum GuideBotScript {
    // GB_GUID_RETURNED_TO_PLAYER (AIGame.cpp:1346).
    static let returnedToPlayerGUID: Int32 = 0x1001_0002

    // GBM_ modes (AIGame.cpp:1350-1363).
    static let inShipMode: Int32 = 0
    static let ambientMode: Int32 = 1
    static let doingTaskMode: Int32 = 2
    static let onFireMode: Int32 = 6
    static let rTypeMode: Int32 = 8
    static let goWingnutMode: Int32 = 9
    static let extinguishMode: Int32 = 10
    static let birthMode: Int32 = 11
    static let enterShipMode: Int32 = 12
    static let respawnEnterShipMode: Int32 = 13

    // GBSM_ sub-modes (AIGame.cpp:1366-1370).
    static let noSubMode: Int32 = 0
    static let getPowerupSubMode: Int32 = 2

    // GBF_ flags (AIGame.cpp:1372-1382).
    static let veryDamagedFlag: Int32 = 0x0001
    static let noChatterFlag: Int32 = 0x0008
    static let wantToExtinguishFlag: Int32 = 0x0020
    static let extinguishingFlag: Int32 = 0x0040
    static let inCustomAnimationFlag: Int32 = 0x0080
    static let wantingToEnterAfterDeathFlag: Int32 = 0x0400

    // GBC_ commands (AIGame.cpp:1387-1431).
    static let exitShipCommand: Int32 = 0
    static let repairCommand: Int32 = 1
    static let renameCommand: Int32 = 2
    static let findActiveGoal0: Int32 = 3
    static let findActiveGoal7: Int32 = 10
    static let findActiveSecondaryGoal0: Int32 = 11
    static let findActiveSecondaryGoal7: Int32 = 18
    static let findSpewCommand: Int32 = 19
    static let findPowerupCommand: Int32 = 20
    static let findEnergyCenterCommand: Int32 = 21
    static let findRobotCommand: Int32 = 22
    static let findThiefCommand: Int32 = 23
    static let findOutsideCommand: Int32 = 24
    static let findMineCommand: Int32 = 25
    static let findClosestMarkerCommand: Int32 = 26
    static let findMarker0: Int32 = 27
    static let findMarker7: Int32 = 34
    static let escortShipCommand: Int32 = 35
    static let allowChatterCommand: Int32 = 41
    static let noChatterCommand: Int32 = 42
    static let returnToShipCommand: Int32 = 43
    static let renameSilentCommand: Int32 = 44
    /// NUM_GB_COMMANDS.
    static let commandCount: Int32 = 44

    // The Guide-Bot powerups (AIGame.cpp:1446-1466).
    static let usablePowerupCount = 5
    /// GB_POW_STRING_OFFSET (GBC_EXTINGUISH).
    static let powerupCommandOffset: Int32 = 36
    static let firePowerup = 0
    static let wingnutPowerup = 1
    static let rTypePowerup = 3
    static let antivirusPowerup = 4
    static let speedPowerup = 5
    /// MAX_AV_ROBOTS.
    static let maximumAntivirusRobots = 100

    // GBS_ sound slots.
    static let veryDamagedSound = 0
    static let ambientSound = 1

    /// ROBOT_GUIDEBOT's page.
    static let pageName = CanonicalObjectInfo.guideBotPageName

    // TXT() indices (AIGame.cpp:59-203).
    static let enteringShipText = 44
    static let helpText = 45
    static let notLocationText = 46
    static let noNavigationText = 47
    static let onMyWayText = 48
    static let notReachableText = 49
    static let enterShipText = 50
    static let escortText = 51
    static let findRobotText = 52
    static let noRobotText = 53
    static let findPowerupText = 54
    static let noPowerupText = 55
    static let goMarkerText = 56
    static let noMarkerText = 57
    static let noMarkText = 58
    static let findThiefText = 59
    static let foundThiefText = 60
    static let noThiefText = 61
    static let findPowerupsText = 62
    static let noSpewText = 63
    static let chatOffText = 64
    static let chatOnText = 65
    static let findEnergyText = 66
    static let noEnergyText = 67
    static let repairedText = 68
    static let notEnoughShieldsText = 69
    static let newNameText = 70
    static let noWayText = 71
    static let strikeText = 72
    static let menuTitleText = 73
    static let findMarkerMenuText = 74
    static let getToText = 75
    static let shieldAmountText = 76
    static let enterNameText = 77
    static let hit1Text = 78
    static let hit2Text = 79
    static let hit3Text = 80
    static let hit4Text = 81
    static let hit5Text = 82
    static let damagedText = 83
    static let oopsText = 84
    static let shootRobotText = 85
    static let atGoalText = 86
    static let comeOnText = 87
    static let letsGoText = 88
    static let comingBackText = 89
    static let fifteenSecondsText = 141
    static let powerupDepletedText = 142
    static let accelerationAlmostDoneText = 143
    static let noPowerupText2 = 144
    static let foundGuideBotPowerupText = 145

    /// gb_command_text (AIGame.cpp:1433): the TXT index of each command.
    static let commandText: [Int] = [
        2, 1, 0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18,
        19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35,
        36, 37, 38, 39, 40, 41, 42, 43,
    ]
    /// gb_pow_text, gb_pow_not_text, and gb_pow_pickup_text
    /// (AIGame.cpp:1452-1459).
    static let powerupText = [96, 97, 98, 99, 100, 101]
    static let powerupNotText = [102, 103, 104, 105, 106, 107]
    static let powerupPickupText = [108, 109, 110, 111, 112, 113]

    /// The buddy powerup pages DoInit looks up (AIGame.cpp:5635-5640).
    static let powerupPageNames = [
        "Buddyextinguisher", "buddywingnut", "buddycontrol", "buddyassist",
        "buddyantivirus", "buddyspeed",
    ]

    static func isValidSavedState(_ state: GuideBotState) -> Bool {
        guard let memory = state.memory else { return true }
        return memory.powerups.count == usablePowerupCount
            && memory.sounds.count == 5
            && memory.powerupPages.count == 6
            && memory.extinguishObjects.count <= 5
            && memory.antivirusRobots.count <= maximumAntivirusRobots
            && memory.antivirusRobots.count
                == memory.antivirusRevertTimes.count
            && memory.name.count <= 7
    }

    // MARK: Messages and modes

    private static func text(_ index: Int, _ level: Level) -> String {
        AIGame.text(index, level: level)
    }

    /// ReInitAmbient (AIGame.cpp:4517).
    static func reInitAmbient(_ me: ObjectHandle, _ world: inout GameWorld,
                              _ level: Level) {
        guard let memory = world.guideBot(me) else { return }
        let time = world.gameTime
        world.updateGuideBot(me) { $0.nextAmbientTime = time + 1 }
        // In general, turn on friend avoidance.
        if memory.lastCommand != returnToShipCommand {
            world.aiSetFlags(me, ObjectAIFrame.autoAvoidFriendsFlag)
        }
        var direction = Int8(world.aigameRand() % 6)
        if direction == AIGoal.negativeUpSubtype {
            direction = AIGoal.negativeRightSubtype
        } else if direction == AIGoal.upSubtype {
            direction = AIGoal.rightSubtype
        }
        world.aiGoalAdd(
            me,
            type: AIGoal.moveRelativeObjectVectorType,
            level: 0,
            influence: 1,
            guid: -1,
            flags: AIGoal.keepAtCompletionFlag
                | AIGoal.useBlineIfSeesGoalFlag,
            .object(memory.ambientCamera),
            subtype: direction,
            world: level
        )
        world.aiSetGoalCircleDistance(me, 0, 4)
    }

    /// DoMessage (AIGame.cpp:4538). A sound plays only 2.5 seconds after
    /// the last message that could play one. The name and text are colored
    /// in the original; the HUD is one color until M4.
    static func doMessage(
        _ message: String,
        highPriority: Bool,
        sound: String? = nil,
        sound2D: Bool = false,
        _ me: ObjectHandle,
        _ world: inout GameWorld,
        _ level: Level
    ) {
        guard let memory = world.guideBot(me) else { return }
        if memory.flags & noChatterFlag != 0 && !highPriority { return }
        if memory.lastSoundTime + 2.5 < world.gameTime {
            if let sound {
                let soundID = world.soundFindID(sound, level: level)
                if sound2D {
                    world.soundPlay2D(memory.me, soundID, level: level)
                } else {
                    world.soundPlay3D(memory.me, soundID, level: level)
                }
            }
            let time = world.gameTime
            world.updateGuideBot(me) { $0.lastSoundTime = time }
        }
        guard let named = world.guideBot(me) else { return }
        world.playerAddHUDMessage(named.player, "\(named.name): \(message)")
    }

    /// SetSubMode (AIGame.cpp:4559).
    @discardableResult
    static func setSubMode(_ me: ObjectHandle, _ subMode: Int32,
                           it: ObjectHandle = .none,
                           _ world: inout GameWorld, _ level: Level) -> Bool {
        guard let memory = world.guideBot(me) else { return false }
        if subMode == getPowerupSubMode, memory.subMode == noSubMode {
            world.aiGoalAdd(
                me, type: AIGoal.getToObjectType, level: 2, influence: 1,
                guid: -1,
                flags: AIGoal.keepAtCompletionFlag | AIGoal.notifiesFlag,
                .object(it), world: level
            )
            world.aiSetGoalCircleDistance(me, 2, -10_000)
            if world.guideBot(me)?.subMode != getPowerupSubMode {
                doMessage(text(foundGuideBotPowerupText, level),
                          highPriority: true, sound: "GBotExcited1",
                          me, &world, level)
            }
        }
        world.updateGuideBot(me) { $0.subMode = subMode }
        return true
    }

    /// SetMode (AIGame.cpp:4583).
    @discardableResult
    static func setMode(_ me: ObjectHandle, _ newMode: Int32,
                        _ world: inout GameWorld, _ level: Level) -> Bool {
        guard world.guideBot(me) != nil else { return false }
        var mode = newMode
        world.aiSetType(me, ObjectAIFrame.aisType, level: level)
        let flare = 3 + world.aigameRandFraction()
        let visibility = 0.5 + 0.5 * world.aigameRandFraction()
        let time = world.gameTime
        world.updateGuideBot(me) {
            $0.modeTime = 0
            $0.timeUntilNextFlare = flare
            $0.timeUntilNextPlayerVisibilityCheck = visibility
            $0.lastRetreatTime = time
            $0.returnTime = time
        }
        guard let memory = world.guideBot(me) else { return false }
        if memory.mode == rTypeMode {
            world.setAIMaxDeltaSpeed(me, memory.maximumAcceleration)
            world.setAIMaxSpeed(me, memory.maximumSpeed)
        }
        if memory.cameraObject != .none {
            world.objectRemove(memory.cameraObject, playSound: false)
            world.updateGuideBot(me) { $0.cameraObject = .none }
        }
        let aroundSlot = world.aiGoalAdd(
            me, type: AIGoal.getAroundObjectType,
            level: GameWorld.activationBlendLevel, influence: 1, guid: -1,
            flags: AIGoal.objectIsTargetFlag, .object(.none), world: level
        )
        world.aiSetGoalCircleDistance(me, aroundSlot, 4)
        world.aiClearFlags(me, ObjectAIFrame.guideBotMimicPlayerFiringFlag)
        world.objSetWeaponBatteryFlags(
            me, battery: 3, DynamicWeaponBattery.enabledFlag, set: false
        )
        if world.guideBot(me)?.mode == extinguishMode,
           newMode != extinguishMode {
            // MSAFE_OBJECT_STOP_SPEW and Obj_SetCustomAnim(33, 41) end the
            // extinguisher's smoke and animation (drawn effects, M2).
            world.updateGuideBot(me) { $0.flags &= ~extinguishingFlag }
        }

        let player = world.guideBot(me)?.player ?? .none
        switch newMode {
        case enterShipMode, respawnEnterShipMode:
            if newMode == enterShipMode {
                doMessage(text(enteringShipText, level), highPriority: true,
                          me, &world, level)
            } else {
                world.setObjectFlags(
                    me,
                    (world.objects[me]?.flags ?? 0) & ~GameObject.aiDeathFlag
                )
                world.setObjectShields(me, 250)
                world.aiSetFlags(me, ObjectAIFrame.autoAvoidFriendsFlag)
            }
            // Obj_Burning(me, 0, 0) stops a fire; no object burns before M2.
            // Sound_Stop does nothing (osiris_predefs.cpp:2906); the handles
            // are forgotten, and the sound system stops a linked sound when
            // its object is ghosted.
            world.updateGuideBot(me) {
                $0.flags &= ~wantingToEnterAfterDeathFlag
                $0.sounds = Array(repeating: -1, count: $0.sounds.count)
            }
            world.inventoryAddTypeID(
                player,
                type: .robot,
                id: world.objectFindID(pageName, level: level)
            )
            world.objGhost(me, true)
            mode = inShipMode
        case birthMode:
            world.aiClearFlags(me, ObjectAIFrame.autoAvoidFriendsFlag)
            world.updateGuideBot(me) {
                $0.isParented = true
                $0.isMarkedForPickup = false
                $0.lastAnimationFrame = 0
            }
            // Obj_SetCustomAnim(me, 6, 12, ...) plays the birth animation
            // (M2).
            guard let playerObject = world.objects[player],
                  case let .room(room) = playerObject.location
            else {
                break
            }
            var position = playerObject.position
            let orientation = playerObject.orientation
            world.setObjectRoom(me, room)
            world.setObjectPosition(me, position)
            world.setObjectOrientation(me, orientation)
            let velocity = world.objectVelocity(player)
                + orientation.forward * 40
            world.setObjectVelocity(me, velocity)
            world.objGhost(me, false)
            world.inventoryRemove(
                player,
                type: .robot,
                id: world.objectFindID(pageName, level: level)
            )
            let birthTime = world.gameTime
            world.setObjectCreationTime(me, birthTime)
            world.setObjectParent(me, player)
            world.updateGuideBot(me) { $0.nextAmbientTime = birthTime + 1.2 }
            position = position + orientation.forward * 200
            world.aiGoalAdd(
                me, type: AIGoal.getToPositionType, level: 1, influence: 1,
                guid: -1,
                flags: AIGoal.useBlineIfSeesGoalFlag | AIGoal.notifiesFlag,
                .position(position, room: room), world: level
            )
            world.aiSetGoalCircleDistance(me, 1, 1)
            world.soundPlay3D(
                player,
                world.soundFindID("GBExpulsionA", level: level),
                level: level
            )
            world.updateGuideBot(me) { $0.lastCommand = -1 }
        case ambientMode:
            reInitAmbient(me, &world, level)
        case doingTaskMode:
            let time = world.gameTime
            world.updateGuideBot(me) {
                $0.lastRetreatTime = time
                $0.returnTime = time
            }
        case onFireMode:
            world.aiClearFlags(me, ObjectAIFrame.autoAvoidFriendsFlag)
            doMessage(text(helpText, level), highPriority: true,
                      sound: "GBotConcern1", me, &world, level)
            let hurt = world.soundPlay3D(
                me, world.soundFindID("GBotHurt1", level: level), level: level
            )
            world.updateGuideBot(me) { $0.sounds[veryDamagedSound] = hurt }
            world.aiGoalAdd(
                me, type: AIGoal.getToObjectType, level: 1, influence: 1,
                guid: -1,
                flags: AIGoal.keepAtCompletionFlag | AIGoal.notifiesFlag,
                .object(player), world: level
            )
            world.aiSetGoalCircleDistance(me, 1, -1)
            // Obj_Burning(me, 1000000, 1) sets the Guide-Bot on fire (M2).
            world.updateGuideBot(me) {
                $0.flags = veryDamagedFlag
                $0.isMarkedForPickup = true
            }
        case rTypeMode:
            world.aiClearFlags(me, ObjectAIFrame.autoAvoidFriendsFlag)
            guard let memory = world.guideBot(me) else { break }
            world.setAIMaxDeltaSpeed(me, memory.maximumAcceleration * 4)
            world.setAIMaxSpeed(me, memory.maximumSpeed * 1.6)
            guard let playerObject = world.objects[player],
                  case let .room(room) = playerObject.location
            else {
                break
            }
            let orientation = playerObject.orientation
            let position = playerObject.position + orientation.forward * 3
                - orientation.up * 10
            let camera = world.objCreate(
                type: .powerup,
                id: world.objectFindID("Invisiblepowerup", level: level),
                room: room, position: position, orientation: orientation,
                parent: me, level: level
            )
            world.updateGuideBot(me) { $0.cameraObject = camera }
            world.setObjectRendered(camera.rawValue, false)
            world.aiGoalAdd(
                me, type: AIGoal.moveRelativeObjectVectorType, level: 3,
                influence: 1, guid: -1,
                flags: AIGoal.keepAtCompletionFlag | AIGoal.orientScriptedFlag,
                .object(camera), subtype: AIGoal.negativeForwardSubtype,
                world: level
            )
            world.aiSetFlags(me, ObjectAIFrame.guideBotMimicPlayerFiringFlag)
        case goWingnutMode:
            world.aiSetType(me, ObjectAIFrame.evader1Type, level: level)
            world.aiSetGoalFlags(me, 1, AIGoal.orientTargetFlag)
            let time = world.gameTime
            world.updateGuideBot(me) { $0.nextAmbientTime = time + 1 }
            world.aiSetFlags(me, ObjectAIFrame.autoAvoidFriendsFlag)
            let direction = Int8(world.aigameRand() % 6)
            world.aiGoalAdd(
                me, type: AIGoal.moveRelativeObjectVectorType, level: 3,
                influence: 1, guid: -1, flags: AIGoal.keepAtCompletionFlag,
                .object(player), subtype: direction, world: level
            )
            world.goalAddEnabler(
                me, goalIndex: 3,
                type: AIGoalEnabler.greaterLastSeeTargetInterval,
                value: 2, percent: 1, interval: 0
            )
            world.objSetWeaponBatteryFlags(
                me, battery: 3, DynamicWeaponBattery.enabledFlag, set: true
            )
        case extinguishMode:
            let target = world.guideBot(me)?.extinguishObjects.first ?? .none
            world.aiGoalAdd(
                me, type: AIGoal.moveRelativeObjectVectorType, level: 0,
                influence: 1, guid: -1,
                flags: AIGoal.keepAtCompletionFlag
                    | AIGoal.orientGoalObjectFlag,
                .object(target), subtype: 0, world: level
            )
            world.aiSetGoalCircleDistance(me, 0, 20)
            let time = world.gameTime
            world.updateGuideBot(me) {
                $0.extinguishObjectTime = 0
                $0.nextAmbientTime = time + 2
            }
        default:
            break
        }
        world.updateGuideBot(me) {
            $0.mode = mode
            $0.subMode = noSubMode
        }
        return true
    }

    /// InitExtinguish (AIGame.cpp:4834): the burning friends near the
    /// Guide-Bot (and the player, when on fire), then the extinguish mode.
    /// No object burns before M2, so only the player can be listed.
    @discardableResult
    static func initExtinguish(_ me: ObjectHandle, playerOnFire: Bool,
                               _ world: inout GameWorld,
                               _ level: Level) -> Bool {
        guard let memory = world.guideBot(me),
              let object = world.objects[memory.me],
              case let .room(room) = object.location
        else {
            return false
        }
        var list: [ObjectHandle] = []
        let scanned = world.aiGetNearbyObjects(
            position: object.position, room: room, radius: 1_000,
            maximum: 25, lightmapOnly: false, onlyPlayersAndAIs: false,
            includeNonCollideObjects: false, stopAtClosedDoors: true,
            level: level
        )
        if playerOnFire { list.append(memory.player) }
        for candidate in scanned {
            if list.count >= 5 { break }
            if playerOnFire, candidate == memory.player { break }
            if world.objIsNapalmed(candidate), candidate != memory.me,
               !world.aiIsObjectEnemy(memory.me, candidate, level: level) {
                list.append(candidate)
            }
        }
        world.updateGuideBot(me) { $0.extinguishObjects = list }
        if !list.isEmpty {
            setMode(memory.me, extinguishMode, &world, level)
            return true
        }
        return false
    }

    // MARK: Commands

    /// MakeCommandList (AIGame.cpp:4879): the commands the menu offers in
    /// the ship and in the ambient mode.
    static func makeCommandList(_ me: ObjectHandle, _ world: inout GameWorld,
                                _ level: Level) -> [Int32] {
        guard let memory = world.guideBot(me) else { return [] }
        var list: [Int32] = []
        if memory.mode == inShipMode {
            for command in exitShipCommand...renameCommand {
                let damaged = memory.flags & veryDamagedFlag != 0
                if !damaged && command == repairCommand { continue }
                if damaged && command == exitShipCommand { continue }
                list.append(command)
            }
        } else if memory.mode == ambientMode {
            let primaries = Int32(world.levelGoalActiveGoals(secondary: false)
                .count)
            let secondaries = Int32(world.levelGoalActiveGoals(secondary: true)
                .count)
            world.updateGuideBot(me) {
                $0.numberOfPrimaryGoals = primaries
                $0.numberOfSecondaryGoals = secondaries
            }
            let player = memory.player
            for command in findActiveGoal0..<commandCount {
                if (findActiveGoal0...findActiveGoal7).contains(command) {
                    if !(command - findActiveGoal0 < primaries) { continue }
                } else if (findActiveSecondaryGoal0...findActiveSecondaryGoal7)
                    .contains(command) {
                    if !(command - findActiveSecondaryGoal0 < secondaries) {
                        continue
                    }
                } else if (findMarker0...findMarker7).contains(command) {
                    let markers = world.objMakeListOfType(
                        me, type: .marker, id: Int(command - findMarker0),
                        ignoringInitialRoom: false, parent: .none, maximum: 1
                    )
                    if let marker = markers.first {
                        world.updateGuideBot(me) { $0.foundObject = marker }
                    }
                    if markers.isEmpty { continue }
                } else if command == findSpewCommand {
                    if world.objMakeListOfType(
                        me, type: .powerup, id: -1,
                        ignoringInitialRoom: false, parent: player, maximum: 1
                    ).isEmpty { continue }
                } else if command == findPowerupCommand {
                    if world.objMakeListOfType(
                        me, type: .powerup, id: -1,
                        ignoringInitialRoom: false, parent: .none, maximum: 1
                    ).isEmpty { continue }
                } else if command == findRobotCommand {
                    if world.objMakeListOfType(
                        me, type: .robot, id: -1,
                        ignoringInitialRoom: false, parent: .none, maximum: 1
                    ).isEmpty { continue }
                } else if command == findThiefCommand {
                    let thief = world.objectFindID("Thief", level: level)
                    if thief < 0 || world.objMakeListOfType(
                        me, type: .robot, id: thief,
                        ignoringInitialRoom: false, parent: .none, maximum: 1
                    ).isEmpty { continue }
                } else if command == findClosestMarkerCommand {
                    if world.objMakeListOfType(
                        me, type: .marker, id: -1,
                        ignoringInitialRoom: false, parent: player, maximum: 1
                    ).isEmpty { continue }
                } else if command >= powerupCommandOffset,
                          command < powerupCommandOffset
                            + Int32(usablePowerupCount) {
                    if memory.powerups[Int(command - powerupCommandOffset)]
                        <= 0 { continue }
                } else if command == findOutsideCommand {
                    continue
                } else if command == findMineCommand {
                    continue
                } else if command == noChatterCommand,
                          memory.flags & noChatterFlag != 0 {
                    continue
                } else if command == allowChatterCommand,
                          memory.flags & noChatterFlag == 0 {
                    continue
                }
                list.append(command)
            }
        }
        return list
    }

    /// C-style formatting of one `%s` or `%d` argument, as the module's
    /// snprintf calls use it. A table string is data, so no other
    /// conversion is read.
    static func format(_ template: String, _ argument: String) -> String {
        guard let range = template.range(of: "%s")
            ?? template.range(of: "%d")
        else {
            return template
        }
        return template.replacingCharacters(in: range, with: argument)
    }

    /// COM_GET_MENU of DoExternalCommands (AIGame.cpp:5351): the title and
    /// the text and kind of each command MakeCommandList offers.
    static func menu(_ me: ObjectHandle, _ world: inout GameWorld,
                     _ level: Level) -> GuideBotMenu {
        let commands = makeCommandList(me, &world, level)
        var entries: [GuideBotMenu.Command] = []
        for command in commands {
            var line: String
            if (findMarker0...findMarker7).contains(command) {
                let marker = world.aiFindObjectOfType(
                    me, type: .marker, id: Int(command - findMarker0),
                    ignoringInitialRoom: false,
                    parent: world.guideBot(me)?.player ?? .none, level: level
                )
                world.updateGuideBot(me) { $0.foundObject = marker }
                // OBJV_PC_MARKER_MESSAGE: markers arrive with the automap
                // (M4), so no marker has a message yet.
                line = format(text(findMarkerMenuText, level), "")
            } else if (findActiveGoal0...findActiveGoal7).contains(command)
                        || (findActiveSecondaryGoal0...findActiveSecondaryGoal7)
                            .contains(command) {
                let secondary = command >= findActiveSecondaryGoal0
                let index = Int(command - (secondary
                    ? findActiveSecondaryGoal0 : findActiveGoal0))
                let active = world.levelGoalActiveGoals(secondary: secondary)
                let location = active.indices.contains(index)
                    ? world.goals[active[index]].itemName : ""
                line = format(text(getToText, level), location)
            } else {
                line = text(commandText[Int(command)], level)
            }
            if command == repairCommand {
                line += format(
                    text(shieldAmountText, level),
                    String(5 + 5 * Difficulty.level)
                )
            }
            entries.append(.init(
                id: command,
                text: line,
                dialogText: command == renameCommand
                    ? text(enterNameText, level) : nil
            ))
        }
        return GuideBotMenu(title: text(menuTitleText, level),
                            commands: entries)
    }

    /// AddGetToGoalCommonGoals (AIGame.cpp:4946).
    static func addGetToGoalCommonGoals(_ me: ObjectHandle,
                                        _ world: inout GameWorld,
                                        _ level: Level) {
        let player = world.guideBot(me)?.player ?? .none
        world.aiGoalAdd(
            me, type: AIGoal.moveRelativeObjectVectorType, level: 2,
            influence: 1, guid: -1, flags: AIGoal.orientGoalObjectFlag,
            .object(player), subtype: AIGoal.negativeForwardSubtype,
            world: level
        )
        world.aiGoalAdd(
            me, type: AIGoal.getToObjectType, level: 3, influence: 1,
            guid: -1,
            flags: AIGoal.orientVelocityFlag | AIGoal.notifiesFlag,
            .object(player), world: level
        )
        world.aiSetGoalCircleDistance(me, 3, 20)
    }

    /// The GET_TO_OBJ goal a find command gives, with the common goals.
    private static func getTo(_ target: ObjectHandle, circle: Float,
                              _ me: ObjectHandle, _ world: inout GameWorld,
                              _ level: Level) {
        world.aiGoalAdd(
            me, type: AIGoal.getToObjectType, level: 1, influence: 1,
            guid: -1,
            flags: AIGoal.keepAtCompletionFlag | AIGoal.notifiesFlag,
            .object(target), world: level
        )
        world.aiSetGoalCircleDistance(me, 1, circle)
        addGetToGoalCommonGoals(me, &world, level)
    }

    /// The GET_TO_POS goal a goal or energy command gives, with the common
    /// goals.
    private static func getTo(_ position: Vector3, room: Int,
                              _ me: ObjectHandle, _ world: inout GameWorld,
                              _ level: Level) {
        world.aiGoalAdd(
            me, type: AIGoal.getToPositionType, level: 1, influence: 1,
            guid: -1,
            flags: AIGoal.keepAtCompletionFlag | AIGoal.notifiesFlag,
            .position(position, room: room), world: level
        )
        world.aiSetGoalCircleDistance(me, 1, 20)
        addGetToGoalCommonGoals(me, &world, level)
    }

    /// DoExternalCommands (AIGame.cpp:4952).
    @discardableResult
    static func doExternalCommands(_ me: ObjectHandle,
                                   _ command: GuideBotCommand,
                                   it: ObjectHandle,
                                   _ world: inout GameWorld,
                                   _ level: Level) -> Bool {
        guard world.guideBot(me) != nil else { return false }
        // In general, turn on friend avoidance.
        world.aiSetFlags(me, ObjectAIFrame.autoAvoidFriendsFlag)
        switch command.action {
        case GuideBotCommand.reinit:
            return doInit(me, reinit: true, &world, level)
        case GuideBotCommand.doAction:
            doAction(me, Int32(command.index), text: command.text,
                     &world, level)
        case GuideBotCommand.getMenu:
            _ = menu(me, &world, level)
        case GuideBotCommand.powerupNotify:
            setSubMode(me, getPowerupSubMode, it: it, &world, level)
        case GuideBotCommand.powerupPickup:
            pickUpPowerup(me, type: Int(command.index), it: it, &world, level)
        default:
            break
        }
        return true
    }

    /// COM_DO_ACTION of DoExternalCommands (AIGame.cpp:4971-5347).
    private static func doAction(_ me: ObjectHandle, _ command: Int32,
                                 text name: String?,
                                 _ world: inout GameWorld, _ level: Level) {
        world.updateGuideBot(me) { $0.lastCommand = command }
        guard let memory = world.guideBot(me) else { return }
        let player = memory.player
        let accept = "GBotAcceptOrder1"
        let concern = "GBotConcern1"
        if (findActiveGoal0...findActiveGoal7).contains(command)
            || (findActiveSecondaryGoal0...findActiveSecondaryGoal7)
                .contains(command) {
            let secondary = command >= findActiveSecondaryGoal0
            let active = world.levelGoalActiveGoals(secondary: secondary)
            let index = Int(command - (secondary
                ? findActiveSecondaryGoal0 : findActiveGoal0))
            // A stale menu index names no goal.
            guard active.indices.contains(index) else { return }
            let goal = world.goals[active[index]]
            guard let first = goal.items.first else { return }
            var handles = goal.items.indices.filter {
                !goal.items[$0].done
            }.map { world.levelGoalItemHandle(active[index], item: $0) }
            if handles.isEmpty {
                handles = [world.levelGoalItemHandle(active[index], item: 0)]
            }
            if goal.status & LevelGoalFlag.notLocationBased != 0 {
                doMessage(text(notLocationText, level), highPriority: true,
                          sound: concern, me, &world, level)
            } else if goal.status
                        & LevelGoalFlag.guideBotDoesNotKnowLocation != 0 {
                doMessage(text(noNavigationText, level), highPriority: true,
                          sound: concern, me, &world, level)
            } else if first.type == LevelGoalItemType.object {
                var ok = false
                for raw in handles {
                    let handle = ObjectHandle(UInt32(bitPattern: raw))
                    if world.objectType(handle) != nil,
                       world.aiIsObjectReachable(me, handle, level: level) {
                        doMessage(text(onMyWayText, level),
                                  highPriority: false, sound: accept,
                                  me, &world, level)
                        getTo(handle, circle: 20, me, &world, level)
                        ok = true
                        break
                    }
                }
                if !ok {
                    doMessage(text(notReachableText, level),
                              highPriority: true, sound: concern,
                              me, &world, level)
                }
            } else if first.type == LevelGoalItemType.internalRoom {
                let room = Int(handles[0])
                if world.aiIsDestinationReachable(me, room: room,
                                                  level: level) {
                    let point = world.roomPortalPathPoint(room, portal: 0,
                                                          level: level)
                    getTo(point, room: room, me, &world, level)
                    doMessage(text(onMyWayText, level), highPriority: false,
                              sound: accept, me, &world, level)
                } else {
                    doMessage(text(notReachableText, level),
                              highPriority: true, sound: concern,
                              me, &world, level)
                }
            } else if first.type == LevelGoalItemType.trigger {
                let trigger = Int(handles[0])
                guard level.triggers.indices.contains(trigger) else { return }
                let room = level.triggers[trigger].roomIndex
                let face = level.triggers[trigger].faceIndex
                if world.aiIsDestinationReachable(me, room: room,
                                                  level: level) {
                    let point = world.roomFaceCenter(room, face: face,
                                                     level: level)
                        + world.roomFaceNormal(room, face: face,
                                               level: level) * 5
                    getTo(point, room: room, me, &world, level)
                    doMessage(text(onMyWayText, level), highPriority: false,
                              sound: accept, me, &world, level)
                } else {
                    doMessage(text(notReachableText, level),
                              highPriority: true, sound: concern,
                              me, &world, level)
                }
            }
        } else if command == returnToShipCommand {
            // Turn off friend avoidance.
            world.aiClearFlags(me, ObjectAIFrame.autoAvoidFriendsFlag)
            doMessage(text(enterShipText, level), highPriority: false,
                      sound: accept, me, &world, level)
            world.aiGoalAdd(
                me, type: AIGoal.getToObjectType, level: 1, influence: 1,
                guid: -1,
                flags: AIGoal.keepAtCompletionFlag | AIGoal.notifiesFlag,
                .object(player), world: level
            )
            world.aiSetGoalCircleDistance(me, 1, -10)
            world.updateGuideBot(me) { $0.isMarkedForPickup = true }
        } else if command == escortShipCommand {
            doMessage(text(escortText, level), highPriority: false,
                      sound: accept, me, &world, level)
            setMode(me, ambientMode, &world, level)
        } else if command == findRobotCommand {
            let robot = world.aiFindObjectOfType(
                me, type: .robot, id: -1, ignoringInitialRoom: false,
                parent: .none, level: level
            )
            if robot != .none {
                doMessage(text(findRobotText, level), highPriority: false,
                          sound: accept, me, &world, level)
                getTo(robot, circle: 30, me, &world, level)
            } else {
                doMessage(text(noRobotText, level), highPriority: true,
                          sound: concern, me, &world, level)
            }
        } else if command == findPowerupCommand {
            let powerup = world.aiFindObjectOfType(
                me, type: .powerup, id: -1, ignoringInitialRoom: false,
                parent: .none, level: level
            )
            world.updateGuideBot(me) { $0.foundObject = powerup }
            if powerup != .none {
                doMessage(text(findPowerupText, level), highPriority: false,
                          sound: accept, me, &world, level)
                getTo(powerup, circle: 3, me, &world, level)
            } else {
                doMessage(text(noPowerupText, level), highPriority: true,
                          sound: concern, me, &world, level)
            }
        } else if command == findClosestMarkerCommand
                    || (findMarker0...findMarker7).contains(command) {
            let marker = world.aiFindObjectOfType(
                me, type: .marker,
                id: command == findClosestMarkerCommand
                    ? -1 : Int(command - findMarker0),
                ignoringInitialRoom: false, parent: player, level: level
            )
            world.updateGuideBot(me) { $0.foundObject = marker }
            if marker != .none {
                // Markers and their messages arrive with the automap (M4).
                doMessage(format(text(goMarkerText, level), ""),
                          highPriority: false, sound: accept,
                          me, &world, level)
                getTo(marker, circle: 3, me, &world, level)
            } else {
                doMessage(
                    text(command == findClosestMarkerCommand
                         ? noMarkerText : noMarkText, level),
                    highPriority: true, sound: concern, me, &world, level
                )
            }
        } else if command == findThiefCommand {
            let thief = world.aiFindObjectOfType(
                me, type: .robot,
                id: world.objectFindID("Thief", level: level),
                ignoringInitialRoom: false, parent: .none, level: level
            )
            world.updateGuideBot(me) { $0.foundObject = thief }
            if thief != .none {
                let found = world.aigameRand() > AIGame.randMax / 2
                doMessage(text(found ? findThiefText : foundThiefText, level),
                          highPriority: false, sound: accept,
                          me, &world, level)
                getTo(thief, circle: 3, me, &world, level)
            } else {
                doMessage(text(noThiefText, level), highPriority: true,
                          sound: concern, me, &world, level)
            }
        } else if command == findSpewCommand {
            let spew = world.aiFindObjectOfType(
                me, type: .powerup, id: -1, ignoringInitialRoom: false,
                parent: player, level: level
            )
            world.updateGuideBot(me) { $0.foundObject = spew }
            if spew != .none {
                doMessage(text(findPowerupsText, level), highPriority: false,
                          sound: accept, me, &world, level)
                getTo(spew, circle: 3, me, &world, level)
            } else {
                doMessage(text(noSpewText, level), highPriority: true,
                          sound: concern, me, &world, level)
            }
        } else if command == noChatterCommand {
            world.updateGuideBot(me) { $0.flags |= noChatterFlag }
            doMessage(text(chatOffText, level), highPriority: true,
                      sound: concern, me, &world, level)
        } else if command == allowChatterCommand {
            world.updateGuideBot(me) { $0.flags &= ~noChatterFlag }
            doMessage(text(chatOnText, level), highPriority: false,
                      sound: accept, me, &world, level)
        } else if command == findEnergyCenterCommand {
            let room = world.aiFindEnergyCenter(me, level: level)
            // RMV_C_USED: a room number of -1 names no used room.
            if level.rooms.contains(where: { $0.sourceIndex == room }) {
                let point = world.roomPathPoint(room, level: level)
                getTo(point, room: room, me, &world, level)
                doMessage(text(findEnergyText, level), highPriority: false,
                          sound: accept, me, &world, level)
            } else {
                doMessage(text(noEnergyText, level), highPriority: true,
                          sound: concern, me, &world, level)
            }
        } else if command == repairCommand {
            var shields = world.objectShields(player)
            let cost = Float(5 + 5 * Difficulty.level)
            if shields >= cost {
                shields -= cost
                world.updateGuideBot(me) { $0.flags &= ~veryDamagedFlag }
                world.setObjectShields(player, shields)
                doMessage(text(repairedText, level), highPriority: false,
                          sound: accept, sound2D: true, me, &world, level)
                world.setObjectShields(me, 250)
                world.setObjectFlags(
                    me,
                    (world.objects[me]?.flags ?? 0) & ~GameObject.aiDeathFlag
                )
                world.aiSetFlags(me, ObjectAIFrame.autoAvoidFriendsFlag)
                // Obj_Burning(me, 0, 0): no object burns before M2.
            } else {
                doMessage(text(notEnoughShieldsText, level),
                          highPriority: true, sound: concern, sound2D: true,
                          me, &world, level)
            }
        } else if command == exitShipCommand {
            world.callObjectEvent(me, .use(it: .none), level: level)
        } else if command >= powerupCommandOffset,
                  command < powerupCommandOffset + Int32(usablePowerupCount) {
            usePowerup(me, Int(command - powerupCommandOffset), &world, level)
        } else if command == renameCommand {
            let requested = name ?? ""
            if !requested.isEmpty {
                let short = String(requested.prefix(7))
                world.updateGuideBot(me) { $0.name = short }
                world.playerGuideBotName = short
                doMessage(format(text(newNameText, level), requested),
                          highPriority: true, sound: accept,
                          me, &world, level)
            } else {
                doMessage(format(text(noWayText, level), requested),
                          highPriority: true, sound: concern,
                          me, &world, level)
            }
        } else if command == renameSilentCommand {
            let requested = name ?? ""
            if !requested.isEmpty {
                world.updateGuideBot(me) { $0.name = String(requested.prefix(7)) }
            }
        } else {
            // The original names "GBotConern1", which no sound page has.
            doMessage(format(text(strikeText, level), String(command)),
                      highPriority: true, sound: "GBotConern1",
                      sound2D: true, me, &world, level)
        }
    }

    /// The Guide-Bot powerup commands (AIGame.cpp:5173-5323).
    private static func usePowerup(_ me: ObjectHandle, _ kind: Int,
                                   _ world: inout GameWorld,
                                   _ level: Level) {
        guard let memory = world.guideBot(me) else { return }
        guard memory.powerups[kind] > 0 else {
            doMessage(text(noPowerupText2, level), highPriority: false,
                      sound: "GBotConcern1", me, &world, level)
            return
        }
        var done = true
        switch kind {
        case firePowerup:
            guard case let .room(room) =
                    world.objects[memory.player]?.location
            else {
                break
            }
            if world.roomDamage(room, level: level) == 0 {
                done = initExtinguish(me, playerOnFire: false, &world, level)
            } else {
                world.soundPlay2D(
                    memory.player,
                    world.soundFindID("GBotConcern1", level: level),
                    level: level
                )
                return
            }
        case antivirusPowerup:
            guard let object = world.objects[memory.me],
                  case let .room(room) = object.location
            else {
                done = false
                break
            }
            let scanned = world.aiGetNearbyObjects(
                position: object.position, room: room, radius: 500,
                maximum: 25, lightmapOnly: false, onlyPlayersAndAIs: false,
                includeNonCollideObjects: false, stopAtClosedDoors: true,
                level: level
            )
            var converted = 0
            for candidate in scanned {
                if converted > 2 { break }
                if (world.guideBot(me)?.antivirusRobots.count ?? 0)
                    >= maximumAntivirusRobots { break }
                guard candidate != memory.me,
                      world.aiIsObjectEnemy(memory.me, candidate,
                                            level: level)
                else {
                    continue
                }
                let end = world.objectPosition(candidate)
                guard world.rayCastIsClear(from: object.position, to: end,
                                           room: room, radius: 1,
                                           level: level)
                else {
                    continue
                }
                // MSAFE_WEATHER_LIGHTNING_BOLT draws the conversion bolt
                // (a drawn effect, M2).
                world.aiClearFlags(candidate, ObjectAIFrame.teamMask)
                world.aiSetFlags(candidate, ObjectAIFrame.teamRebel)
                world.setAITarget(candidate, .none)
                let revert = world.gameTime + 30
                world.updateGuideBot(me) {
                    $0.antivirusRevertTimes.append(revert)
                    $0.antivirusRobots.append(candidate)
                }
                converted += 1
            }
            done = converted > 0
        case wingnutPowerup:
            setMode(me, goWingnutMode, &world, level)
            done = true
        case rTypePowerup:
            setMode(me, rTypeMode, &world, level)
            done = true
        case speedPowerup:
            done = boostSpeed(me, &world)
        default:
            break
        }
        if done {
            doMessage(text(powerupText[kind], level), highPriority: false,
                      sound: "GBotAcceptOrder1", me, &world, level)
            world.updateGuideBot(me) { $0.powerups[kind] -= 1 }
        } else {
            doMessage(text(powerupNotText[kind], level), highPriority: false,
                      sound: "GBotConcern1", me, &world, level)
        }
    }

    /// The speed powerup (AIGame.cpp:5288, :5379): three times the speed and
    /// six times the acceleration for 30 seconds, unless already boosted.
    private static func boostSpeed(_ me: ObjectHandle,
                                   _ world: inout GameWorld) -> Bool {
        guard let memory = world.guideBot(me) else { return false }
        let acceleration = world.aiMaxDeltaSpeed(me)
        let speed = world.aiMaxSpeed(me)
        guard acceleration == memory.maximumAcceleration,
              speed == memory.maximumSpeed
        else {
            return false
        }
        world.updateGuideBot(me) { $0.speedTimeLeft = 30 }
        world.setAIMaxDeltaSpeed(me, acceleration * 6)
        world.setAIMaxSpeed(me, speed * 3)
        return true
    }

    /// COM_POWERUP_PICKUP of DoExternalCommands (AIGame.cpp:5369).
    static func pickUpPowerup(_ me: ObjectHandle, type: Int,
                                      it: ObjectHandle,
                                      _ world: inout GameWorld,
                                      _ level: Level) {
        guard (0...5).contains(type) else { return }
        world.soundPlay3D(me, world.soundFindID("Powerup pickup", level: level),
                          level: level)
        if type == speedPowerup {
            _ = boostSpeed(me, &world)
        } else {
            // `char powerups[]` (AIGame.cpp:1478): the released MSVC build
            // wraps a signed char at 127.
            world.updateGuideBot(me) { $0.powerups[type] &+= 1 }
        }
        world.objectRemove(it, playSound: false)
        doMessage(text(powerupPickupText[type], level), highPriority: true,
                  sound: "GBotExcited1", me, &world, level)
        setSubMode(me, noSubMode, &world, level)
    }

    // MARK: Events

    /// DoCollide (AIGame.cpp:5496).
    static func doCollide(_ me: ObjectHandle, it: ObjectHandle,
                          _ world: inout GameWorld, _ level: Level) {
        guard let memory = world.guideBot(me) else { return }
        let itType = world.objectType(it)
        let random = world.aigameRandFraction()
        // Add a buddy bot to your inventory.
        if memory.isMarkedForPickup {
            if itType == .player, world.objectID(it) == memory.playerSlot {
                setMode(me, enterShipMode, &world, level)
            }
        } else if itType == .weapon {
            // Run back to the player when hit.
            let parent = world.objects[it]?.parent ?? .none
            if parent == memory.player {
                if random > 0.8 {
                    doMessage(text(hit1Text, level), highPriority: false,
                              sound: "GBotConcern1", me, &world, level)
                } else if Double(random) > 0.6 {
                    doMessage(text(hit2Text, level), highPriority: false,
                              sound: "GBotConcern1", me, &world, level)
                } else if Double(random) > 0.4 {
                    doMessage(text(hit3Text, level), highPriority: false,
                              sound: "GBotConcern1", me, &world, level)
                }
            }
            // The original's retreat test ends in an empty statement
            // (AIGame.cpp:5531), so the block after it runs for every
            // weapon hit.
            if Double(random) > 0.7 {
                world.aiGoalAdd(
                    me, type: AIGoal.getToObjectType, level: 2, influence: 1,
                    guid: -1, flags: 0, .object(memory.player), world: level
                )
                world.aiSetGoalCircleDistance(me, 2, 40)
                let time = world.gameTime
                world.updateGuideBot(me) { $0.lastRetreatTime = time }
                doMessage(text(hit4Text, level), highPriority: true,
                          sound: "GBotConcern1", me, &world, level)
            } else {
                doMessage(text(hit5Text, level), highPriority: true,
                          sound: "GBotConcern1", me, &world, level)
            }
        }
    }

    /// DoUse (AIGame.cpp:5548): the use (of the inventory item or the
    /// Guide-Bot) sends COM_REINIT to the player's buddy.
    static func doUse(_ me: ObjectHandle, _ world: inout GameWorld,
                      _ level: Level) -> Bool {
        var player = world.objects[me]?.parent ?? .none
        if player == .none {
            player = world.guideBot(me)?.player ?? .none
        } else {
            let owner = player
            world.updateGuideBot(me) { $0.player = owner }
        }
        let buddy = world.playerBuddyHandle(player)
        return world.callObjectEvent(
            buddy,
            .aiNotify(
                .userDefined, it: .none,
                info: .command(.init(action: GuideBotCommand.reinit))
            ),
            level: level
        )
    }

    /// DoInit (AIGame.cpp:5579).
    static func doInit(_ me: ObjectHandle, reinit: Bool,
                       _ world: inout GameWorld, _ level: Level) -> Bool {
        if !reinit {
            let player = world.objects[me]?.parent ?? .none
            var memory = GuideBotMemory()
            memory.flags = 0
            memory.maximumAcceleration = world.aiMaxDeltaSpeed(me)
            memory.maximumSpeed = world.aiMaxSpeed(me)
            memory.player = player
            memory.playerSlot = world.objectID(player) ?? 0
            memory.name = world.playerGuideBotName
            world.setGuideBotMemory(me, memory)
            // Sets up the invisible helper.
            guard let playerObject = world.objects[player],
                  case let .room(room) = playerObject.location
            else {
                return finishInit(me, &world, level)
            }
            let camera = world.objCreate(
                type: .powerup,
                id: world.objectFindID("Invisiblepowerup", level: level),
                room: room,
                position: playerObject.position
                    + playerObject.orientation.forward * 10,
                orientation: playerObject.orientation,
                parent: me,
                level: level
            )
            world.updateGuideBot(me) { $0.ambientCamera = camera }
            world.setObjectRendered(camera.rawValue, false)
            return finishInit(me, &world, level)
        }
        // If too damaged to exit.
        if (world.guideBot(me)?.flags ?? 0) & veryDamagedFlag != 0 {
            doMessage(text(damagedText, level), highPriority: true,
                      sound: "GBotConcern1", sound2D: true, me, &world, level)
            return false
        }
        setMode(me, birthMode, &world, level)
        setSubMode(me, noSubMode, &world, level)
        return true
    }

    /// The rest of DoInit's first call (AIGame.cpp:5617-5654).
    private static func finishInit(_ me: ObjectHandle,
                                   _ world: inout GameWorld,
                                   _ level: Level) -> Bool {
        let pages = powerupPageNames.map {
            world.objectFindID($0, level: level)
        }
        let time = world.gameTime
        world.updateGuideBot(me) {
            // Three fire extinguishers per level.
            $0.powerups = [3, 0, 0, 0, 0]
            $0.sounds = Array(repeating: -1, count: 5)
            $0.me = me
            $0.mode = inShipMode
        }
        world.aiSetType(me, ObjectAIFrame.aisType, level: level)
        world.updateGuideBot(me) {
            $0.powerupPages = pages
            $0.antivirusRobots = []
            $0.antivirusRevertTimes = []
            $0.lastSoundTime = time
            $0.lastAtGoalTime = time
            $0.cameraObject = .none
            $0.speedTimeLeft = 0
        }
        return true
    }

    /// DoNotify (AIGame.cpp:5660).
    static func doNotify(_ me: ObjectHandle, _ type: AINotifyType,
                         it: ObjectHandle, info: AINotifyInfo,
                         _ world: inout GameWorld, _ level: Level) -> Bool {
        guard let memory = world.guideBot(me) else { return true }
        if type == .userDefined {
            guard case let .command(command) = info else { return true }
            return doExternalCommands(me, command, it: it, &world, level)
        } else if type == .weaponHitObject {
            let itType = world.objectType(it)
            if itType == .player {
                if it == memory.player {
                    doMessage(text(oopsText, level), highPriority: true,
                              sound: "GBotConcern1", me, &world, level)
                }
            } else if itType == .robot {
                // 35% of the time the buddy says something when he hits a
                // robot.
                if Float(world.aigameRand()) > Float(AIGame.randMax) * 0.65 {
                    doMessage(text(shootRobotText, level),
                              highPriority: false, sound: "GBotAcceptOrder1",
                              me, &world, level)
                }
            }
        } else if AIGame.isGoalFinishedNotify(type) {
            guard case let .goal(index, guid, _) = info else { return true }
            if index == 1 {
                if memory.lastAtGoalTime + 1 > world.gameTime {
                    doExternalCommands(
                        me,
                        .init(action: GuideBotCommand.doAction,
                              index: Int8(escortShipCommand)),
                        it: memory.player, &world, level
                    )
                    return true
                }
                doMessage(text(atGoalText, level), highPriority: false,
                          sound: "GBotAcceptOrder1", me, &world, level)
                let time = world.gameTime
                world.updateGuideBot(me) { $0.lastAtGoalTime = time }
                world.aiGoalAdd(
                    me, type: AIGoal.getToObjectType, level: 2, influence: 1,
                    guid: returnedToPlayerGUID, flags: AIGoal.notifiesFlag,
                    .object(memory.player), world: level
                )
                world.aiSetGoalCircleDistance(me, 2, 30)
            } else if index == 2, guid == returnedToPlayerGUID {
                if world.aiGoalIsUsed(me, 1) {
                    let greeting = world.aigameRand() % 100 > 50
                        ? comeOnText : letsGoText
                    doMessage(text(greeting, level), highPriority: false,
                              sound: "GBotGreetB1", me, &world, level)
                }
                let flare = 3 + world.aigameRandFraction()
                let time = world.gameTime
                world.updateGuideBot(me) {
                    $0.timeUntilNextFlare = flare
                    $0.returnTime = time
                }
            }
        } else if type == .scriptedOrient {
            let orientation = world.objectOrientation(memory.player)
            world.aiTurnTowardsVectors(me, forward: orientation.forward,
                                       up: orientation.up)
        }
        return true
    }

    /// DoPowerupCheck (AIGame.cpp:6002): every 2 to 3 seconds, the nearest
    /// buddy powerup within 200 units starts the get-powerup sub-mode.
    static func doPowerupCheck(_ me: ObjectHandle, _ world: inout GameWorld,
                               _ level: Level) {
        guard let memory = world.guideBot(me),
              memory.nextPowerupCheckTime <= world.gameTime,
              memory.subMode == noSubMode
        else {
            return
        }
        let next = world.gameTime + 2 + world.aigameRandFraction()
        world.updateGuideBot(me) { $0.nextPowerupCheckTime = next }
        guard let object = world.objects[me],
              case let .room(room) = object.location
        else {
            return
        }
        let scanned = world.aiGetNearbyObjects(
            position: object.position, room: room, radius: 200, maximum: 80,
            lightmapOnly: false, onlyPlayersAndAIs: true,
            includeNonCollideObjects: false, stopAtClosedDoors: true,
            level: level
        )
        for candidate in scanned
        where world.objectType(candidate) == .powerup {
            let id = world.objectID(candidate)
            if memory.powerupPages.contains(where: { $0 >= 0 && $0 == id }) {
                doExternalCommands(
                    me, .init(action: GuideBotCommand.powerupNotify),
                    it: candidate, &world, level
                )
                break
            }
        }
    }

    /// DoFrame (AIGame.cpp:6044).
    static func doFrame(_ me: ObjectHandle, _ world: inout GameWorld,
                        _ level: Level) {
        guard let memory = world.guideBot(me) else { return }
        let player = memory.player
        if let playerObject = world.objects[player],
           case let .room(room) = playerObject.location {
            let orientation = playerObject.orientation
            let position = playerObject.position + orientation.forward * 40
                - orientation.up * 10
            world.setObjectRoom(memory.ambientCamera, room)
            world.setObjectPosition(memory.ambientCamera, position)
            world.setObjectOrientation(memory.ambientCamera, orientation)
        }
        if world.guideBot(me)?.mode == ambientMode {
            doPowerupCheck(me, &world, level)
        }
        if (world.guideBot(me)?.flags ?? 0)
            & wantingToEnterAfterDeathFlag != 0 {
            if !world.playerIsDead(player) {
                setMode(me, respawnEnterShipMode, &world, level)
            }
        } else if world.playerIsDead(player) {
            // Obj_Burning(me, 0, 0): no object burns before M2.
            world.updateGuideBot(me) {
                $0.flags |= wantingToEnterAfterDeathFlag
            }
        }
        let frameTime = world.frameDuration
        if let speedLeft = world.guideBot(me)?.speedTimeLeft, speedLeft > 0 {
            if speedLeft > 15, speedLeft - frameTime <= 15 {
                doMessage(text(accelerationAlmostDoneText, level),
                          highPriority: true, sound: "GBotExcited1",
                          me, &world, level)
            }
            world.updateGuideBot(me) { $0.speedTimeLeft -= frameTime }
            if let left = world.guideBot(me)?.speedTimeLeft, left <= 0,
               let reset = world.guideBot(me) {
                world.updateGuideBot(me) { $0.speedTimeLeft = 0 }
                world.setAIMaxSpeed(me, reset.maximumSpeed)
                world.setAIMaxDeltaSpeed(me, reset.maximumAcceleration)
                doMessage(text(powerupDepletedText, level),
                          highPriority: true, sound: "GBotPlayerKillBot1",
                          me, &world, level)
            }
        }
        if world.guideBot(me)?.mode == ambientMode,
           world.objIsNapalmed(player),
           case let .room(room) = world.objects[player]?.location,
           world.roomDamage(room, level: level) == 0 {
            initExtinguish(me, playerOnFire: true, &world, level)
        }
        // OBJV_F_ANIM_FRAME: no object animates before ai_do_animation
        // (M2), so the frame is 0.
        let animation = world.objectAnimationFrame(me)
        world.updateGuideBot(me) {
            if animation < 0 || animation > 12 {
                $0.flags |= inCustomAnimationFlag
            } else {
                $0.flags &= ~inCustomAnimationFlag
            }
        }
        let objectFlags = world.objects[me]?.flags ?? 0
        guard let current = world.guideBot(me) else { return }
        let lastModeTime = current.modeTime
        world.updateGuideBot(me) { $0.modeTime += frameTime }
        let modeTime = lastModeTime + frameTime
        let mode = current.mode
        if mode == onFireMode {
        } else if objectFlags & GameObject.aiDeathFlag != 0 {
            setMode(me, onFireMode, &world, level)
        } else if mode == birthMode {
            if modeTime > 1.2 {
                setMode(me, ambientMode, &world, level)
            }
            return
        } else if mode == extinguishMode {
            extinguishFrame(me, animation: animation,
                            lastModeTime: lastModeTime, modeTime: modeTime,
                            &world, level)
        } else if mode == rTypeMode {
            if let playerObject = world.objects[player],
               case let .room(room) = playerObject.location,
               let camera = world.guideBot(me)?.cameraObject {
                let orientation = playerObject.orientation
                let position = playerObject.position
                    + orientation.forward * 3 - orientation.up * 10
                world.setObjectRoom(camera, room)
                world.setObjectPosition(camera, position)
                world.setObjectOrientation(camera, orientation)
            }
            powerupModeTimeout(me, lastModeTime: lastModeTime,
                               &world, level)
        } else if mode == goWingnutMode {
            if world.gameTime > (world.guideBot(me)?.nextAmbientTime ?? 0) {
                let time = world.gameTime
                world.updateGuideBot(me) { $0.nextAmbientTime = time + 1 }
                world.aiSetFlags(me, ObjectAIFrame.autoAvoidFriendsFlag)
                let direction = Int8(world.aigameRand() % 6)
                world.aiGoalAdd(
                    me, type: AIGoal.moveRelativeObjectVectorType, level: 3,
                    influence: 1, guid: -1,
                    flags: AIGoal.keepAtCompletionFlag,
                    .object(player), subtype: direction, world: level
                )
                world.goalAddEnabler(
                    me, goalIndex: 3,
                    type: AIGoalEnabler.greaterLastSeeTargetInterval,
                    value: 2, percent: 1, interval: 0
                )
                world.aiSetGoalCircleDistance(me, 3, 27)
            }
            powerupModeTimeout(me, lastModeTime: lastModeTime,
                               &world, level)
        } else {
            normalFrame(me, &world, level)
        }
        world.updateGuideBot(me) { $0.lastAnimationFrame = animation }
    }

    /// The fifteen-second warning and the 30-second end of the R-type and
    /// wingnut modes (AIGame.cpp:6195-6203, :6225-6232).
    private static func powerupModeTimeout(_ me: ObjectHandle,
                                           lastModeTime: Float,
                                           _ world: inout GameWorld,
                                           _ level: Level) {
        let frameTime = world.frameDuration
        if lastModeTime + frameTime < 15,
           lastModeTime + frameTime + frameTime >= 15 {
            doMessage(text(fifteenSecondsText, level), highPriority: true,
                      sound: "GBotExcited1", me, &world, level)
        }
        if Double(lastModeTime + frameTime) > 30.0 {
            doMessage(text(powerupDepletedText, level), highPriority: true,
                      sound: "GBotPlayerKillBot1", me, &world, level)
            setMode(me, ambientMode, &world, level)
        }
    }

    /// The extinguish mode's frame (AIGame.cpp:6112-6177). The custom
    /// animations and the smoke spew are drawn effects (M2).
    private static func extinguishFrame(_ me: ObjectHandle, animation: Float,
                                        lastModeTime: Float, modeTime: Float,
                                        _ world: inout GameWorld,
                                        _ level: Level) {
        guard let memory = world.guideBot(me) else { return }
        if world.gameTime > memory.nextAmbientTime {
            let time = world.gameTime
            world.updateGuideBot(me) { $0.nextAmbientTime = time + 0.6 }
            let direction = Int8(world.aigameRand() % 6)
            world.aiGoalAdd(
                me, type: AIGoal.moveRelativeObjectVectorType, level: 0,
                influence: 1, guid: -1,
                flags: AIGoal.orientGoalObjectFlag
                    | AIGoal.keepAtCompletionFlag,
                .object(memory.extinguishObjects.first ?? .none),
                subtype: direction, world: level
            )
            world.aiSetGoalCircleDistance(me, 0, 20)
        }
        guard modeTime < 25 else {
            setMode(me, ambientMode, &world, level)
            return
        }
        if memory.lastAnimationFrame <= 18, animation > 18 {
            world.updateGuideBot(me) { $0.flags |= wantToExtinguishFlag }
        }
        if (world.guideBot(me)?.flags ?? 0) & wantToExtinguishFlag != 0,
           animation >= 23, animation <= 33 {
            world.soundPlay3D(
                me, world.soundFindID("GBotEuphoria1", level: level),
                level: level
            )
            world.updateGuideBot(me) {
                $0.flags &= ~wantToExtinguishFlag
                $0.flags |= extinguishingFlag
            }
        }
        // `memory->flags | GBF_EXTINGUISHING` (AIGame.cpp:6152) is always
        // true.
        let target = world.guideBot(me)?.extinguishObjects.first ?? .none
        let status = world.aiGoalStatusRegister(me, 0)
        var toGoal = world.objectPosition(target) - world.objectPosition(me)
        vmNormalizeVector(&toGoal)
        if status & ObjectAIFrame.circleDistanceStatus != 0,
           dot(toGoal, world.objectOrientation(me).forward) > 0.4717,
           animation >= 23, animation <= 33 {
            let frameTime = world.frameDuration
            world.updateGuideBot(me) { $0.extinguishObjectTime += frameTime }
        }
        if (world.guideBot(me)?.extinguishObjectTime ?? 0) > 1.5 {
            // Obj_Burning(target, 0, 0) puts the fire out (M2).
            let remaining = world.guideBot(me)?.extinguishObjects ?? []
            if remaining.count > 1 {
                world.updateGuideBot(me) {
                    $0.extinguishObjects.removeFirst()
                }
                setMode(me, extinguishMode, &world, level)
            } else {
                setMode(me, ambientMode, &world, level)
            }
        }
    }

    /// DoFrame's last branch (AIGame.cpp:6234-6310): the engine sound, the
    /// ambient goal, the parent link, the player visibility check, the
    /// flares, and the return to the player.
    private static func normalFrame(_ me: ObjectHandle,
                                    _ world: inout GameWorld,
                                    _ level: Level) {
        guard let memory = world.guideBot(me) else { return }
        let player = memory.player
        if memory.sounds[ambientSound] == -1 {
            let engine = world.soundPlay3D(
                me, world.soundFindID("GBotEngineB1", level: level),
                level: level
            )
            world.updateGuideBot(me) { $0.sounds[ambientSound] = engine }
        }
        if world.guideBot(me)?.mode == ambientMode,
           world.gameTime > (world.guideBot(me)?.nextAmbientTime ?? 0) {
            reInitAmbient(me, &world, level)
        }
        // Allow the buddy to collide with his player after 3 seconds.
        if world.guideBot(me)?.isParented == true {
            let created = world.objects[me]?.creationTime ?? 0
            if world.gameTime - created > 3 {
                world.setObjectParent(me, .none)
                world.updateGuideBot(me) { $0.isParented = false }
            }
        }
        let frameTime = world.frameDuration
        world.updateGuideBot(me) {
            $0.timeUntilNextPlayerVisibilityCheck -= frameTime
        }
        if (world.guideBot(me)?.timeUntilNextPlayerVisibilityCheck ?? 1)
            <= 0 {
            let start = world.objectPosition(me)
            let end = world.objectPosition(player)
            let next = 0.5 + 0.5 * world.aigameRandFraction()
            world.updateGuideBot(me) {
                $0.timeUntilNextPlayerVisibilityCheck = next
            }
            if vectorDistance(start, end) < 200,
               case let .room(room) = world.objects[me]?.location,
               world.rayCastIsClear(from: start, to: end, room: room,
                                    radius: 0, level: level) {
                let time = world.gameTime
                world.updateGuideBot(me) { $0.returnTime = time }
            }
        }
        if world.guideBot(me)?.mode == ambientMode {
            world.updateGuideBot(me) { $0.timeUntilNextFlare -= frameTime }
            if (world.guideBot(me)?.timeUntilNextFlare ?? 1) <= 0 {
                let next = 3 + world.aigameRandFraction()
                world.updateGuideBot(me) { $0.timeUntilNextFlare = next }
                if world.aiGoalIsUsed(me, 1), !world.aiGoalIsUsed(me, 2),
                   !world.aiGoalIsUsed(me, 3) {
                    let weapon = world.objectFindID(pageName, level: level)
                        == world.objectID(me)
                        ? world.weaponFindID("Yellow flare", level: level)
                        : world.weaponFindID("GreenFlare", level: level)
                    if weapon != -1 {
                        world.soundPlay3D(
                            me, world.soundFindID("Flare", level: level),
                            level: level
                        )
                        world.objectFireWeapon(me, weapon: weapon,
                                               gunpoint: -1, level: level)
                    }
                }
            }
        }
        // Makes the buddy stay pretty close to his player.
        if let returnTime = world.guideBot(me)?.returnTime,
           Double(returnTime) + 2.5 < Double(world.gameTime) {
            if world.objectDistance(me, player, subtractingSizes: true) > 10,
               world.guideBot(me)?.subMode == noSubMode {
                doMessage(text(comingBackText, level), highPriority: false,
                          sound: "GBotAcceptOrder1", me, &world, level)
                world.aiGoalAdd(
                    me, type: AIGoal.getToObjectType, level: 2, influence: 1,
                    guid: returnedToPlayerGUID, flags: AIGoal.notifiesFlag,
                    .object(player), world: level
                )
                world.aiSetGoalCircleDistance(me, 2, 30)
            }
            let time = world.gameTime
            world.updateGuideBot(me) { $0.returnTime = time }
        }
    }

    /// CallEvent (AIGame.cpp:6146).
    static func callEvent(_ event: ScriptEvent, me: ObjectHandle,
                          world: inout GameWorld, level: Level) -> ChainFlags {
        switch event {
        case .aiInit:
            return doInit(me, reinit: false, &world, level) ? .all : []
        case .interval:
            revertAntivirusRobots(me, &world)
        case .aiFrame:
            doFrame(me, &world, level)
        case let .collide(it):
            doCollide(me, it: it, &world, level)
        case let .aiNotify(type, it, info):
            return doNotify(me, type, it: it, info: info, &world, level)
                ? .all : []
        case .use:
            return doUse(me, &world, level) ? .all : []
        case .destroy:
            if let camera = world.guideBot(me)?.cameraObject, camera != .none {
                world.objectRemove(camera, playSound: false)
                world.updateGuideBot(me) { $0.cameraObject = .none }
            }
        default:
            break
        }
        return .all
    }

    /// EVT_INTERVAL (AIGame.cpp:6150): the robots the anti-virus converted
    /// go back to the PTMC team after 30 seconds.
    private static func revertAntivirusRobots(_ me: ObjectHandle,
                                              _ world: inout GameWorld) {
        while let memory = world.guideBot(me),
              let first = memory.antivirusRobots.first,
              memory.antivirusRevertTimes[0] <= world.gameTime {
            world.aiClearFlags(first, ObjectAIFrame.teamMask)
            world.aiSetFlags(first, ObjectAIFrame.teamPTMC)
            world.setAITarget(first, .none)
            world.updateGuideBot(me) {
                $0.antivirusRobots.removeFirst()
                $0.antivirusRevertTimes.removeFirst()
            }
        }
    }
}

extension GameWorld {
    /// The GuideBot memory of an object, or nil.
    func guideBot(_ me: ObjectHandle) -> GuideBotMemory? {
        guard case let .guideBot(state)? = objects[me]?.scripts?.defaultScript
        else {
            return nil
        }
        return state.memory
    }

    /// Stores new GuideBot memory (DoInit's Scrpt_MemAlloc).
    mutating func setGuideBotMemory(_ me: ObjectHandle,
                                    _ memory: GuideBotMemory) {
        guard var scripts = objects[me]?.scripts,
              case .guideBot = scripts.defaultScript
        else {
            return
        }
        scripts.defaultScript = .guideBot(GuideBotState(memory: memory))
        objects[me]?.scripts = scripts
    }

    /// Changes the GuideBot memory in place. The change makes no engine
    /// call.
    mutating func updateGuideBot(_ me: ObjectHandle,
                                 _ change: (inout GuideBotMemory) -> Void) {
        guard var memory = guideBot(me) else { return }
        change(&memory)
        setGuideBotMemory(me, memory)
    }

    /// The Guide-Bot's command menu (COM_GET_MENU through AINotify, as
    /// BuddyBotDownloadData asks it, Descent3/buddymenu.cpp:370), or nil
    /// when the level has no Guide-Bot.
    mutating func guideBotMenu(level: Level) -> GuideBotMenu? {
        let buddy = buddyHandle
        guard guideBot(buddy) != nil else { return nil }
        aiSetFlags(buddy, ObjectAIFrame.autoAvoidFriendsFlag)
        return GuideBotScript.menu(buddy, &self, level)
    }

    /// BuddyProcessCommand (buddymenu.cpp:452): a menu command goes to the
    /// Guide-Bot as AIN_USER_DEFINED.
    mutating func guideBotCommand(_ command: Int32, text: String? = nil,
                                  level: Level) {
        let buddy = buddyHandle
        guard objects[buddy] != nil else { return }
        aiNotifyUserDefined(
            buddy,
            command: .init(action: GuideBotCommand.doAction,
                           index: Int8(truncatingIfNeeded: command),
                           text: text),
            level: level
        )
    }
}
