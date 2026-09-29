// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/TrainingMission.cpp (Descent 3,
// Copyright (C) 2024 Parallax Software, GPL-3.0-or-later).
//
// Translated so far: the name tables (:826-910), the action counters and
// ClearGlobalActionCtrs (:251-330, only the counters used below),
// InitializeDLL (:916), GetGOScriptID (:1007), GetTriggerScriptID (:1264),
// GetCOScriptList (:1280), the custom block's player functions (:519-640),
// and the level script's EVT_LEVELSTART (Script 000, :1457) and EVT_TIMER
// (Script 002, :1501). The other scripts are still the bespoke Training
// code; M1 steps 5-9 move them here.

/// The Training module's state: the DALLAS globals of the module
/// (ScriptActionCtr_nnn and the DallasFuncs variables).
struct TrainingMissionState: Codable, Equatable, Sendable {
    /// ScriptActionCtr_000.
    var script000Count: Int = 0
    /// ScriptActionCtr_002.
    var script002Count: Int = 0
    var dallas = DallasState.dfInit()
}

enum TrainingMissionScript {
    /// MAX_ACTION_CTR_VALUE (TrainingMission.cpp:251).
    static let maximumActionCounter = 100_000

    /// Object_names (TrainingMission.cpp:833).
    static let objectNames = [
        "FlashLight-1", "FlashLight-2", "FlashLight-3", "FlashLight-4",
        "FlashLight-5", "DoneDodgeingGoal", "StartCourse", "StartDodge",
        "FinishCourse", "UpGoal", "LeftGoal", "StartGoal", "DodgeTurrett",
        "FollowBot1", "ManuverRoomCenter", "DestroyBot2", "DestroyBot1",
        "GalleryEntered", "LastRoomGoal", "KillBotGoal", "FinalGoal",
        "ForwardGoal", "CameraMonitor", "RASBot1", "RASBot2", "RASBot3",
        "RASBot4", "InvulnPowerup2", "CloakPowerup2", "LastBot1",
        "LastBot2", "LastBot3", "LastBot4", "LastBot5", "SecurityCamera",
    ]

    /// Trigger_names (TrainingMission.cpp:849).
    static let triggerNames = ["Portal2", "Portal3", "Portal4"]

    /// Message_names (TrainingMission.cpp:875).
    static let messageNames = [
        "GoodJob", "GoBackwards", "Welcome", "GoForward", "GoLeft",
        "GoRight", "GoUp", "GoDown", "Repeat", "ContinueToCourse",
        "CourseInstructions", "DodgeIntro", "Dodge30", "LeaveDodge",
        "FollowIntro", "FollowInstructions", "KeepDodging",
        "KeepMovingOutofDodging", "BankIntro", "AlmostDoneDodge",
        "ManuverIntro", "HeadingIntro", "PitchIntro", "WeaponsEnabled",
        "DestroyFollowbot", "Movingbotintro", "ExitManuveur", "GBIntro",
        "UseCameraMonitor", "KillBotIntro", "KillBot2", "ProceedtoLastRoom",
        "FinalSessionIntro", "AllDone", "GBExtra", "GetCameraMonitor",
    ]

    /// TrainingMission.cpp:853 Sound_names (resolved by Scrpt_FindSoundName).
    static let soundNames = ["MenuBeepEnter", "PupC1"]

    /// The file names passed to aSoundPlaySteamingText, in first-use source
    /// order (TrainingMission.cpp:1434 to :2377). Spelling kept as written.
    static let streamedAudioNames = [
        "GuideBotB.osf", "proceed6.osf", "welcome.osf", "follow.osf",
        "bank.osf", "pitch.osf", "kill1.osf", "proceed5.osf",
        "GuidebotF.osf", "done.osf", "return1.osf", "left1.osf",
        "up1.osf", "repeat.osf", "lright.osf", "udown.osf",
        "proceed1.osf", "return2.osf", "return3.osf", "Intro1.osf",
        "proceed2.osf", "intro2.osf", "proceed4.osf", "proceed3.osf",
        "almost.osf", "intro3.osf", "intro4.osf", "GuideBotC.osf",
        "GuideBotD.osf", "GuideBotA.osf", "intro6.osf", "intro7.osf",
    ]

    static let references = LevelScriptReferences(
        soundNames: soundNames,
        streamedAudioNames: streamedAudioNames
    )

    /// GetCOScriptList (TrainingMission.cpp:1280): the Object_names index
    /// of each custom object script, with its script id
    /// (ID_CUSTOM_OBJECT_300D = 0x001 to ID_CUSTOM_OBJECT_1824 = 0x01a,
    /// TrainingMission.cpp:56-81).
    static let customScripts: [(objectName: Int, id: Int32)] = [
        (21, 0x001), (11, 0x002), (10, 0x003), (9, 0x004), (6, 0x005),
        (8, 0x006), (7, 0x007), (5, 0x008), (12, 0x009), (14, 0x00a),
        (13, 0x00b), (16, 0x00c), (15, 0x00d), (22, 0x00e), (23, 0x00f),
        (24, 0x010), (25, 0x011), (26, 0x012), (27, 0x013), (28, 0x014),
        (29, 0x015), (30, 0x016), (31, 0x017), (32, 0x018), (33, 0x019),
        (20, 0x01a),
    ]

    /// InitializeDLL (TrainingMission.cpp:916): ClearGlobalActionCtrs and
    /// dfInit. The name lookups are `objectHandle(_:level:)` and
    /// `message(_:level:)`, which read the immutable level each time and so
    /// give the handles and strings the DLL resolved once.
    static func initializeDLL() -> TrainingMissionState {
        TrainingMissionState()
    }

    /// Save validation: the counters stay in their range, and the DALLAS
    /// arrays keep their fixed sizes.
    static func isValidSavedState(_ state: TrainingMissionState) -> Bool {
        let counters = [state.script000Count, state.script002Count]
        return counters.allSatisfy { (0...maximumActionCounter).contains($0) }
            && state.dallas.spewHandles.count
                == DallasState.maximumSpewHandles
            && state.dallas.soundHandles.count
                == DallasState.maximumSoundHandles
            && state.dallas.userVars.count == DallasState.maximumUserVars
            && state.dallas.savedObjectHandles.count
                == DallasState.maximumSavedObjectHandles
    }

    /// Object_handles[index]: Scrpt_FindObjectName(Object_names[index]).
    static func objectHandle(_ index: Int, level: Level) -> ObjectHandle {
        level.findObjectName(objectNames[index])
    }

    /// Message_strings[index]: GetMessage(Message_names[index])
    /// (TrainingMission.cpp:811).
    static func message(_ index: Int, level: Level) -> String {
        level.scripting?.message(named: messageNames[index])
            ?? "*Message Not Found*"
    }

    /// GetGOScriptID (TrainingMission.cpp:1007): this module has no generic
    /// object scripts.
    static func genericScriptID(pageName: String, isDoor: Bool) -> Int32? {
        nil
    }

    /// The handles GetCOScriptList returns, with their script ids.
    static func customScriptList(
        level: Level
    ) -> [(handle: ObjectHandle, id: Int32)] {
        customScripts.map { (objectHandle($0.objectName, level: level), $0.id) }
    }

    /// GetTriggerScriptID (TrainingMission.cpp:1264) for the room and face
    /// of trigger `triggerIndex`: ID_TRIGGER_0000 (0x01b) to
    /// ID_TRIGGER_0002 (0x01d), matched through Trigger_rooms and
    /// Trigger_faces.
    static func triggerScriptID(triggerIndex: Int, level: Level) -> Int32? {
        let trigger = level.triggers[triggerIndex]
        for (index, name) in triggerNames.enumerated() {
            guard let named = level.triggers.first(where: {
                $0.name.caseInsensitiveCompare(name) == .orderedSame
            }) else {
                continue
            }
            if named.roomIndex == trigger.roomIndex,
               named.faceIndex == trigger.faceIndex {
                return 0x01b + Int32(index)
            }
        }
        return nil
    }

    /// The custom object and trigger scripts. The events they handle
    /// (EVT_COLLIDE, EVT_DESTROY, EVT_USE, EVT_TIMER) are still produced by
    /// the bespoke Training code, so every event that reaches them now takes
    /// their `CONTINUE_CHAIN | CONTINUE_DEFAULT` return
    /// (for example TrainingMission.cpp:1657).
    static func callCustomObjectEvent(
        id: Int32,
        event: ScriptEvent,
        me: ObjectHandle,
        world: inout GameWorld,
        level: Level
    ) -> ChainFlags {
        .all
    }

    static func callTriggerEvent(
        id: Int32,
        event: ScriptEvent,
        world: inout GameWorld,
        level: Level
    ) -> ChainFlags {
        .all
    }

    /// LevelScript_0000::CallEvent (TrainingMission.cpp:1333).
    static func callLevelEvent(
        _ event: ScriptEvent,
        world: inout GameWorld,
        level: Level
    ) -> ChainFlags {
        switch event {
        case .levelStart:
            levelStart(world: &world, level: level)
        case .timer:
            levelTimer(world: &world, level: level)
        default:
            break
        }
        return .all
    }

    /// EVT_LEVELSTART (TrainingMission.cpp:1457-1500).
    private static func levelStart(world: inout GameWorld, level: Level) {
        // ClearGlobalActionCtrs and dfInit.
        world.trainingMission = TrainingMissionState()

        func object(_ index: Int) -> ObjectHandle {
            objectHandle(index, level: level)
        }
        // Script 000: Level Start
        world.aObjSetLightingDist(object(0), 0)
        world.aObjSetLightingDist(object(1), 0)
        world.aObjSetLightingDist(object(2), 0)
        world.aObjSetLightingDist(object(3), 0)
        world.aObjSetLightingDist(object(4), 0)
        world.aObjSetLightingColor(object(4), 0.2, 1, 0.2)
        world.aObjSetLightingColor(object(3), 0.2, 1, 0.2)
        world.aObjSetLightingColor(object(2), 0.2, 1, 0.2)
        world.aObjSetLightingColor(object(1), 0.2, 1, 0.2)
        world.aObjSetLightingColor(object(0), 0.2, 1, 0.2)
        world.aObjMakeInvuln(world.qGetPlayerObj(0, level: level), 0)
        world.aToggleAllPlayerControls(0, 0, level: level)
        world.aTogglePlayerControl(1, 0, 1, level: level)
        world.aObjHide(object(5))
        world.aObjHide(object(6))
        world.aObjHide(object(7))
        world.aSetLevelTimer(1, 0)
        world.aObjHide(object(8))
        world.aObjHide(object(9))
        world.aObjHide(object(10))
        world.aObjHide(object(11))
        world.aAISetState(0, object(12))
        world.aAISetState(0, object(13))
        world.aObjHide(object(14))
        world.aObjGhostSet(1, object(15))
        world.aObjGhostSet(1, object(16))
        world.aObjHide(object(17))
        world.aObjHide(object(18))
        world.aObjHide(object(19))
        world.aObjHide(object(20))
        world.aObjHide(object(21))
        world.aToggleShowPlayerControl(1, 0, level: level)

        // Increment the script action counter
        if world.trainingMission.script000Count < maximumActionCounter {
            world.trainingMission.script000Count += 1
        }
    }

    /// EVT_TIMER (TrainingMission.cpp:1501-1626). Only Script 002 is
    /// translated; the other timer scripts are still bespoke.
    private static func levelTimer(world: inout GameWorld, level: Level) {
        // Script 002: First Hud Mesage Timer
        let script002Count = world.trainingMission.script002Count
        if script002Count < 1, (script002Count > 0) == false {
            world.aShowHUDMessage(message(2, level: level))
            world.aSoundPlaySteamingText("welcome.osf", 1)
            world.aShowHUDMessage(message(3, level: level))

            // Increment the script action counter
            if world.trainingMission.script002Count < maximumActionCounter {
                world.trainingMission.script002Count += 1
            }
        }
    }
}

extension GameWorld {
    /// The Training module's state. Handlers read it from the world at each
    /// use (architecture.md section 6, reentrancy rule).
    var trainingMission: TrainingMissionState {
        get {
            guard case let .trainingMission(state) = levelModule else {
                preconditionFailure("The Training module is not loaded.")
            }
            return state
        }
        set {
            levelModule = .trainingMission(newValue)
        }
    }

    // The custom block's player functions (TrainingMission.cpp:519-640).

    /// qGetPlayerObj (TrainingMission.cpp:558).
    func qGetPlayerObj(_ playerNum: Int, level: Level) -> ObjectHandle {
        playerObjectHandle(slot: playerNum, level: level)
    }

    /// aToggleShowPlayerControl (TrainingMission.cpp:578).
    mutating func aToggleShowPlayerControl(
        _ enable: Int32,
        _ playerNum: Int,
        level: Level
    ) {
        setShowEnabledControls(
            playerObjectHandle(slot: playerNum, level: level),
            enable != 0
        )
    }

    /// aTogglePlayerControl (TrainingMission.cpp:603).
    mutating func aTogglePlayerControl(
        _ enable: Int32,
        _ playerNum: Int,
        _ controlMask: UInt32,
        level: Level
    ) {
        setPlayerControlMask(
            playerObjectHandle(slot: playerNum, level: level),
            mask: controlMask,
            enabled: enable != 0
        )
    }

    /// aToggleAllPlayerControls (TrainingMission.cpp:628).
    mutating func aToggleAllPlayerControls(
        _ enable: Int32,
        _ playerNum: Int,
        level: Level
    ) {
        setPlayerControlMask(
            playerObjectHandle(slot: playerNum, level: level),
            mask: 0xffff_ffff,
            enabled: enable != 0
        )
    }
}
