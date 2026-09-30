// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/TrainingMission.cpp (Descent 3,
// Copyright (C) 2024 Parallax Software, GPL-3.0-or-later).
//
// Translated so far: the name tables (:826-910), the action counters and
// ClearGlobalActionCtrs (:251-330, only the counters used below),
// InitializeDLL (:916), GetGOScriptID (:1007), GetTriggerScriptID (:1264),
// GetCOScriptList (:1280), the custom block's player functions (:519-640),
// the level script's EVT_INTERVAL (Scripts 018, 025, 031, 030, 034, and
// 035, :1347-1429), EVT_LEVELSTART (Script 000, :1457), and EVT_TIMER
// (Scripts 002, 023, 024, 022, 027, 029, 049, and 056, :1501-1622), and
// the object scripts of
// the opening, return, dodge, maneuver, and robot lessons:
// CustomObjectScript_300D (Scripts 001 and 008, :1633), _300C (003, 005,
// 007, 009, 011, 013, :1662), _300B (004 and 010, :1745), _4809 (006 and
// 012, :1778), _1803 (014, :1811), _1806 (015, :1829), _100A (033 and 016,
// :1851), _300E (019 and 017, :1887), _2007 (020, :1926), _080F (021,
// :1943), _2008 (037 and 026, :1969), _1011 (028, :2008), _1010 (036,
// :2031), _081A, _081B, _081D, and _081E (043-046, :2090-2172), _081C
// and _0819 (047 and 048, :2174-2200), and _101F,
// _0820, _0821, _0822, and _0823 (051-055, :2204-2307). The other scripts
// are still the bespoke Training code; M1 steps 8 and 9 move them here.

/// The Training module's state: the DALLAS globals of the module
/// (ScriptActionCtr_nnn and the DallasFuncs variables).
struct TrainingMissionState: Codable, Equatable, Sendable {
    /// ScriptActionCtr_000 to ScriptActionCtr_015.
    var script000Count: Int = 0
    var script001Count: Int = 0
    var script002Count: Int = 0
    var script003Count: Int = 0
    var script004Count: Int = 0
    var script005Count: Int = 0
    var script006Count: Int = 0
    var script007Count: Int = 0
    var script008Count: Int = 0
    var script009Count: Int = 0
    var script010Count: Int = 0
    var script011Count: Int = 0
    var script012Count: Int = 0
    var script013Count: Int = 0
    var script014Count: Int = 0
    var script015Count: Int = 0
    /// ScriptActionCtr_016 to ScriptActionCtr_026.
    var script016Count: Int = 0
    var script017Count: Int = 0
    var script018Count: Int = 0
    var script019Count: Int = 0
    var script020Count: Int = 0
    var script021Count: Int = 0
    var script022Count: Int = 0
    var script023Count: Int = 0
    var script024Count: Int = 0
    var script025Count: Int = 0
    var script026Count: Int = 0
    /// ScriptActionCtr_033.
    var script033Count: Int = 0
    /// ScriptActionCtr_030.
    var script030Count: Int = 0
    /// ScriptActionCtr_031.
    var script031Count: Int = 0
    /// ScriptActionCtr_027 to ScriptActionCtr_029, _036, and _037: the
    /// robot lesson.
    var script027Count: Int = 0
    var script028Count: Int = 0
    var script029Count: Int = 0
    var script036Count: Int = 0
    var script037Count: Int = 0
    /// ScriptActionCtr_043 to ScriptActionCtr_046: RASBot1 to RASBot4
    /// killed.
    var script043Count: Int = 0
    var script044Count: Int = 0
    var script045Count: Int = 0
    var script046Count: Int = 0
    /// ScriptActionCtr_051 to ScriptActionCtr_055: LastBot1 to LastBot5
    /// killed.
    var script051Count: Int = 0
    var script052Count: Int = 0
    var script053Count: Int = 0
    var script054Count: Int = 0
    var script055Count: Int = 0
    /// ScriptActionCtr_047 and _048: the pickups; _034 and _049: the last
    /// room; _035 and _056: the final bots.
    var script047Count: Int = 0
    var script048Count: Int = 0
    var script034Count: Int = 0
    var script049Count: Int = 0
    var script035Count: Int = 0
    var script056Count: Int = 0
    var dallas = DallasState.dfInit()

    /// Every action counter, for save validation.
    var actionCounters: [Int] {
        [
            script000Count, script001Count, script002Count, script003Count,
            script004Count, script005Count, script006Count, script007Count,
            script008Count, script009Count, script010Count, script011Count,
            script012Count, script013Count, script014Count, script015Count,
            script016Count, script017Count, script018Count, script019Count,
            script020Count, script021Count, script022Count, script023Count,
            script024Count, script025Count, script026Count,
            script033Count, script030Count, script031Count,
            script027Count, script028Count, script029Count,
            script036Count, script037Count, script043Count,
            script044Count, script045Count, script046Count,
            script051Count, script052Count, script053Count,
            script054Count, script055Count,
            script047Count, script048Count, script034Count, script049Count,
            script035Count, script056Count,
        ]
    }
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

    /// Room_names (TrainingMission.cpp:844).
    static let roomNames = [
        "PortalRoom1", "PortalRoom2", "PortalRoom3", "PortalRoom4",
        "PortalRoom5", "PortalRoom6", "PortalRoom7",
    ]

    /// Path_names (TrainingMission.cpp:863).
    static let pathNames = ["FollowLoop1", "GoToDie"]

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
        return state.actionCounters.allSatisfy { (0...maximumActionCounter).contains($0) }
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

    /// Room_indexes[index]: Scrpt_FindRoomName(Room_names[index]).
    static func roomIndex(_ index: Int, level: Level) -> Int {
        level.findRoomName(roomNames[index])
    }

    /// Path_indexes[index]: Scrpt_FindPathName(Path_names[index]).
    static func pathIndex(_ index: Int, level: Level) -> Int {
        level.findPathName(pathNames[index])
    }

    /// Sound_indexes[index]: Scrpt_FindSoundName(Sound_names[index]).
    static func soundIndex(_ index: Int, level: Level) -> Int {
        level.findSoundName(soundNames[index])
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

    /// The custom object scripts' CallEvent. Each DALLAS-generated handler
    /// returns CONTINUE_CHAIN | CONTINUE_DEFAULT (for example
    /// TrainingMission.cpp:1657). The handlers of the later lessons are
    /// still the bespoke Training code, so the events that reach them now
    /// only take that return. An EVT_DESTROY handler runs only for a dying
    /// object; a destroy at level end breaks out (for example :2014).
    static func callCustomObjectEvent(
        id: Int32,
        event: ScriptEvent,
        me: ObjectHandle,
        world: inout GameWorld,
        level: Level
    ) -> ChainFlags {
        switch (id, event) {
        case (0x001, .collide): collideForwardGoal(world: &world, level: level)
        case (0x002, .collide): collideStartGoal(world: &world, level: level)
        case (0x003, .collide): collideLeftGoal(world: &world, level: level)
        case (0x004, .collide): collideUpGoal(world: &world, level: level)
        case (0x005, .collide): collideStartCourse(world: &world, level: level)
        case (0x006, .collide): collideFinishCourse(world: &world, level: level)
        case (0x007, .collide):
            collideStartDodge(me: me, world: &world, level: level)
        case let (0x007, .timer(timerID, _)):
            timerStartDodge(id: timerID, world: &world, level: level)
        case (0x008, .collide):
            collideDoneDodgeingGoal(world: &world, level: level)
        case let (0x008, .timer(timerID, _)):
            timerDoneDodgeingGoal(id: timerID, world: &world, level: level)
        case let (0x009, .timer(timerID, _)):
            timerDodgeTurrett(id: timerID, world: &world, level: level)
        case (0x00a, .collide):
            collideManuverRoomCenter(world: &world, level: level)
        case let (0x00b, .timer(timerID, _)):
            timerFollowBot1(id: timerID, world: &world, level: level)
        case (0x00b, .destroy(isDying: true)):
            destroyFollowBot1(world: &world, level: level)
        case (0x00c, .destroy(isDying: true)):
            destroyDestroyBot1(world: &world, level: level)
        case (0x00d, .destroy(isDying: true)):
            destroyDestroyBot2(world: &world, level: level)
        // Scripts 043-046: RASBot1 to RASBot4 Killed (:2099-2170).
        case (0x00f, .destroy(isDying: true)):
            increment(\.script043Count, world: &world)
        case (0x010, .destroy(isDying: true)):
            increment(\.script044Count, world: &world)
        case (0x011, .destroy(isDying: true)):
            increment(\.script045Count, world: &world)
        case (0x012, .destroy(isDying: true)):
            increment(\.script046Count, world: &world)
        // Script 047: InvulnPowerup2 Picked up (:2174-2186).
        case (0x013, .collide):
            if world.trainingMission.script047Count < 1 {
                increment(\.script047Count, world: &world)
            }
        // Script 048: CloakPowerup2 Picked up (:2188-2200).
        case (0x014, .collide):
            if world.trainingMission.script048Count < 1 {
                increment(\.script048Count, world: &world)
            }
        // Scripts 051-055: Lastbot1 to Lastbot5 Killed (:2213-2305).
        case (0x015, .destroy(isDying: true)):
            increment(\.script051Count, world: &world)
        case (0x016, .destroy(isDying: true)):
            increment(\.script052Count, world: &world)
        case (0x017, .destroy(isDying: true)):
            increment(\.script053Count, world: &world)
        case (0x018, .destroy(isDying: true)):
            increment(\.script054Count, world: &world)
        case (0x019, .destroy(isDying: true)):
            increment(\.script055Count, world: &world)
        default: break
        }
        return .all
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
        case .interval:
            levelInterval(world: &world, level: level)
        case .levelStart:
            levelStart(world: &world, level: level)
        case let .timer(id, _):
            levelTimer(id: id, world: &world, level: level)
        default:
            break
        }
        return .all
    }

    /// EVT_INTERVAL (TrainingMission.cpp:1347-1456). Scripts 018, 025, 031,
    /// 030, 034, and 035 are translated; Scripts 038 and 060 are still
    /// bespoke.
    private static func levelInterval(world: inout GameWorld, level: Level) {
        func object(_ index: Int) -> ObjectHandle {
            objectHandle(index, level: level)
        }

        // Script 018: Player Hit, cancel timer & restart
        if world.qObjShields(world.qGetPlayerObj(0, level: level)) < 100,
           (world.trainingMission.script016Count > 0) == true,
           (world.trainingMission.script017Count > 0) == false {
            world.aCancelTimer(3, level: level)
            world.aCancelTimer(2, level: level)
            world.aSetObjectTimer(object(12), 14, 3)
            world.aSetObjectTimer(object(5), 20, 2)
            world.aShowHUDMessage(message(16, level: level))
            world.aObjSetShields(world.qGetPlayerObj(0, level: level), 100)

            // Increment the script action counter
            increment(\.script018Count, world: &world)
        }

        // Script 025: Follow Test
        if (world.trainingMission.script023Count > 0) == true,
           (world.trainingMission.script026Count > 0) == false {
            if world.qObjCanSeeObj(
                object(13),
                90,
                world.qGetPlayerObj(0, level: level)
            ) == true {
            } else {
                world.aCancelTimer(7, level: level)
                world.aSetObjectTimer(object(13), 20, 7)
            }

            // Increment the script action counter
            increment(\.script025Count, world: &world)
        }

        // Script 031: Keep Energy up
        if (world.trainingMission.script021Count > 0) == true,
           world.qObjEnergy(world.qGetPlayerObj(0, level: level)) < 50 {
            world.aObjSetEnergy(world.qGetPlayerObj(0, level: level), 50)

            // Increment the script action counter
            increment(\.script031Count, world: &world)
        }

        // Script 030: Keep sheilds up
        if (world.trainingMission.script014Count > 0) == true,
           world.qObjShields(world.qGetPlayerObj(0, level: level)) < 50 {
            world.aObjSetShields(world.qGetPlayerObj(0, level: level), 50)

            // Increment the script action counter
            if world.trainingMission.script030Count < maximumActionCounter {
                world.trainingMission.script030Count += 1
            }
        }

        // Script 034: Ready for last room Delay
        let mission = world.trainingMission
        if mission.script034Count < 1,
           (mission.script043Count > 0) == true,
           (mission.script044Count > 0) == true,
           (mission.script045Count > 0) == true,
           (mission.script046Count > 0) == true,
           (mission.script047Count > 0) == true,
           (mission.script048Count > 0) == true {
            world.aPortalRenderSet(0, 1, roomIndex(5, level: level), true, level: level)
            world.aPortalRenderSet(0, 0, roomIndex(5, level: level), true, level: level)
            world.aObjSetLightingDist(object(3), 50)
            world.aSetLevelTimer(2, 9)

            // Increment the script action counter
            increment(\.script034Count, world: &world)
        }

        // Script 035: All Bots killed Delay
        let bots = world.trainingMission
        if bots.script035Count < 1,
           (bots.script051Count > 0) == true,
           (bots.script052Count > 0) == true,
           (bots.script053Count > 0) == true,
           (bots.script054Count > 0) == true,
           (bots.script055Count > 0) == true {
            world.aSetLevelTimer(2, 10)
            world.aObjSetLightingDist(object(4), 50)
            world.aPortalRenderSet(0, 0, roomIndex(6, level: level), true, level: level)
            world.aPortalRenderSet(0, 1, roomIndex(6, level: level), true, level: level)

            // Increment the script action counter
            increment(\.script035Count, world: &world)
        }
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

    /// EVT_TIMER (TrainingMission.cpp:1501-1626). Scripts 002, 023, 024,
    /// 022, 027, and 029 are translated; the later timer scripts are still
    /// bespoke.
    private static func levelTimer(
        id: Int32,
        world: inout GameWorld,
        level: Level
    ) {
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

        func object(_ index: Int) -> ObjectHandle {
            objectHandle(index, level: level)
        }

        // Script 023: Done Bank -- Start Follow
        if world.trainingMission.script023Count < 1,
           (world.trainingMission.script024Count > 0) == true, 4 == id {
            world.aTogglePlayerControl(1, 0, 4032, level: level)
            world.aShowHUDMessage(message(14, level: level))
            world.aShowHUDMessage(message(15, level: level))
            world.aAISetState(1, object(13))
            world.aAISetTeam(65536, object(13))
            world.aSetObjectTimer(object(13), 20, 7)
            world.aSoundPlaySteamingText("follow.osf", 1)
            world.aAIGoalFollowPathSimple(
                object(13),
                pathIndex(0, level: level),
                9_437_444,
                0,
                3,
                level: level
            )

            // Increment the script action counter
            increment(\.script023Count, world: &world)
        }

        // Script 024: Done Pitch -- Start Bank
        if world.trainingMission.script024Count < 1,
           (world.trainingMission.script022Count > 0) == true {
            world.aToggleAllPlayerControls(0, 0, level: level)
            world.aTogglePlayerControl(1, 0, 3072, level: level)
            world.aShowHUDMessage(message(18, level: level))
            world.aSoundPlaySteamingText("bank.osf", 1)
            world.aSetLevelTimer(15, 4)

            // Increment the script action counter
            increment(\.script024Count, world: &world)
        }

        // Script 022: Done Heading -- Start Pitch Time
        if world.trainingMission.script022Count < 1,
           (world.trainingMission.script021Count > 0) == true {
            world.aShowHUDMessage(message(0, level: level))
            world.aToggleAllPlayerControls(0, 0, level: level)
            world.aTogglePlayerControl(1, 0, 192, level: level)
            world.aShowHUDMessage(message(22, level: level))
            world.aSoundPlaySteamingText("pitch.osf", 1)
            world.aSetLevelTimer(12, 4)

            // Increment the script action counter
            increment(\.script022Count, world: &world)
        }

        // Script 027: Follow Bot Destroyed
        if world.trainingMission.script027Count < 1, id == 11 {
            world.aShowHUDMessage(message(0, level: level))
            world.aAISetTeam(65536, object(15))
            world.aAISetTeam(65536, object(16))
            world.aObjGhostSet(0, object(16))
            world.aShowHUDMessage(message(25, level: level))
            world.aSoundPlaySteamingText("kill1.osf", 1)
            world.aAIGoalFollowPathSimple(
                object(16),
                pathIndex(0, level: level),
                8_392_960,
                -1,
                3,
                level: level
            )

            // Increment the script action counter
            increment(\.script027Count, world: &world)
        }

        // Script 029: DestroyBot2 Destroyed
        if id == 12 {
            world.aShowHUDMessage(message(0, level: level))
            world.aShowHUDMessage(message(26, level: level))
            world.aToggleShowPlayerControl(0, 0, level: level)
            world.aSoundPlaySteamingText("proceed5.osf", 1)

            // Increment the script action counter
            increment(\.script029Count, world: &world)
        }

        // Script 049: Ready for last room
        if world.trainingMission.script049Count < 1, id == 9 {
            world.aShowHUDMessage(message(0, level: level))
            world.aShowHUDMessage(message(31, level: level))
            world.aSoundPlaySteamingText("proceed5.osf", 1)

            // Increment the script action counter
            increment(\.script049Count, world: &world)
        }

        // Script 056: All Bots killed
        if world.trainingMission.script056Count < 1, id == 10 {
            world.aShowHUDMessage(message(33, level: level))
            world.aSoundPlaySteamingText("done.osf", 1)

            // Increment the script action counter
            increment(\.script056Count, world: &world)
        }
    }
}

extension TrainingMissionScript {
    /// Increments a ScriptActionCtr up to MAX_ACTION_CTR_VALUE.
    fileprivate static func increment(
        _ counter: WritableKeyPath<TrainingMissionState, Int>,
        world: inout GameWorld
    ) {
        if world.trainingMission[keyPath: counter] < maximumActionCounter {
            world.trainingMission[keyPath: counter] += 1
        }
    }

    /// CustomObjectScript_300D EVT_COLLIDE, ForwardGoal
    /// (TrainingMission.cpp:1633-1660).
    static func collideForwardGoal(world: inout GameWorld, level: Level) {
        // Script 001: FirstGoal
        if world.trainingMission.script001Count < 1 {
            world.aShowHUDMessage(message(0, level: level))
            world.aSoundPlaySteamingText("return1.osf", 1)
            world.aShowHUDMessage(message(1, level: level))
            world.aTogglePlayerControl(0, 0, 1, level: level)
            world.aTogglePlayerControl(1, 0, 2, level: level)
            increment(\.script001Count, world: &world)
        }

        // Script 008: Repeat Forward Goal
        if world.trainingMission.script008Count < 1,
           (world.trainingMission.script007Count > 0) == true {
            world.aSoundPlay2D(soundIndex(0, level: level), 1, level: level)
            world.aTogglePlayerControl(0, 0, 1, level: level)
            world.aTogglePlayerControl(1, 0, 2, level: level)
            world.aShowHUDMessage(message(1, level: level))
            increment(\.script008Count, world: &world)
        }
    }

    /// CustomObjectScript_300C EVT_COLLIDE, StartGoal
    /// (TrainingMission.cpp:1662-1743).
    static func collideStartGoal(world: inout GameWorld, level: Level) {
        // Script 003: Return to Start from Forward Goal
        if world.trainingMission.script003Count < 1,
           (world.trainingMission.script001Count > 0) == true {
            world.aShowHUDMessage(message(4, level: level))
            world.aTogglePlayerControl(0, 0, 2, level: level)
            world.aSoundPlaySteamingText("left1.osf", 1)
            world.aTogglePlayerControl(1, 0, 4, level: level)
            increment(\.script003Count, world: &world)
        }

        // Script 005: Return to Start From Left Goal
        if world.trainingMission.script005Count < 1,
           (world.trainingMission.script004Count > 0) == true {
            world.aTogglePlayerControl(0, 0, 8, level: level)
            world.aTogglePlayerControl(1, 0, 16, level: level)
            world.aShowHUDMessage(message(0, level: level))
            world.aSoundPlaySteamingText("up1.osf", 1)
            world.aShowHUDMessage(message(6, level: level))
            increment(\.script005Count, world: &world)
        }

        // Script 007: Return to Start from Up Goal
        if world.trainingMission.script007Count < 1,
           (world.trainingMission.script006Count > 0) == true {
            world.aShowHUDMessage(message(0, level: level))
            world.aShowHUDMessage(message(8, level: level))
            world.aShowHUDMessage(message(3, level: level))
            world.aSoundPlaySteamingText("repeat.osf", 1)
            world.aTogglePlayerControl(0, 0, 32, level: level)
            world.aTogglePlayerControl(1, 0, 1, level: level)
            increment(\.script007Count, world: &world)
        }

        // Script 009: Return to Start from Repeat Forward Goal
        if world.trainingMission.script009Count < 1,
           (world.trainingMission.script008Count > 0) == true {
            world.aTogglePlayerControl(0, 0, 2, level: level)
            world.aSoundPlaySteamingText("lright.osf", 1)
            world.aTogglePlayerControl(1, 0, 4, level: level)
            world.aShowHUDMessage(message(4, level: level))
            increment(\.script009Count, world: &world)
        }

        // Script 011: Return to Start from Repeat Left Goal
        if world.trainingMission.script011Count < 1,
           (world.trainingMission.script010Count > 0) == true {
            world.aTogglePlayerControl(0, 0, 8, level: level)
            world.aTogglePlayerControl(1, 0, 16, level: level)
            world.aSoundPlaySteamingText("udown.osf", 1)
            world.aShowHUDMessage(message(6, level: level))
            increment(\.script011Count, world: &world)
        }

        // Script 013: Return to start from Repeat Up Goal
        if world.trainingMission.script013Count < 1,
           (world.trainingMission.script012Count > 0) == true {
            world.aPortalRenderSet(0, 0, roomIndex(0, level: level), true, level: level)
            world.aPortalRenderSet(0, 1, roomIndex(0, level: level), true, level: level)
            world.aSoundPlaySteamingText("proceed1.osf", 1)
            world.aShowHUDMessage(message(9, level: level))
            increment(\.script013Count, world: &world)
        }
    }

    /// CustomObjectScript_300B EVT_COLLIDE, LeftGoal
    /// (TrainingMission.cpp:1745-1776).
    static func collideLeftGoal(world: inout GameWorld, level: Level) {
        // Script 004: Left Goal
        if world.trainingMission.script004Count < 1 {
            world.aTogglePlayerControl(0, 0, 4, level: level)
            world.aTogglePlayerControl(1, 0, 8, level: level)
            world.aShowHUDMessage(message(0, level: level))
            world.aSoundPlaySteamingText("return2.osf", 1)
            world.aShowHUDMessage(message(5, level: level))
            increment(\.script004Count, world: &world)
        }

        // Script 010: Repeat Left Goal
        if world.trainingMission.script010Count < 1,
           (world.trainingMission.script009Count > 0) == true {
            world.aSoundPlay2D(soundIndex(0, level: level), 1, level: level)
            world.aTogglePlayerControl(0, 0, 4, level: level)
            world.aTogglePlayerControl(1, 0, 8, level: level)
            world.aShowHUDMessage(message(5, level: level))
            increment(\.script010Count, world: &world)
        }
    }

    /// CustomObjectScript_4809 EVT_COLLIDE, UpGoal
    /// (TrainingMission.cpp:1778-1809).
    static func collideUpGoal(world: inout GameWorld, level: Level) {
        // Script 006: Up Goal
        if world.trainingMission.script006Count < 1 {
            world.aShowHUDMessage(message(0, level: level))
            world.aShowHUDMessage(message(7, level: level))
            world.aTogglePlayerControl(0, 0, 16, level: level)
            world.aSoundPlaySteamingText("return3.osf", 1)
            world.aTogglePlayerControl(1, 0, 32, level: level)
            increment(\.script006Count, world: &world)
        }

        // Script 012: Repeat Up Goal
        if world.trainingMission.script012Count < 1,
           (world.trainingMission.script011Count > 0) == true {
            world.aSoundPlay2D(soundIndex(0, level: level), 1, level: level)
            world.aTogglePlayerControl(0, 0, 16, level: level)
            world.aTogglePlayerControl(1, 0, 32, level: level)
            world.aShowHUDMessage(message(7, level: level))
            increment(\.script012Count, world: &world)
        }
    }

    /// CustomObjectScript_1803 EVT_COLLIDE, StartCourse
    /// (TrainingMission.cpp:1811-1827).
    static func collideStartCourse(world: inout GameWorld, level: Level) {
        // Script 014: Start Course
        if world.trainingMission.script014Count < 1 {
            world.aPortalRenderSet(1, 1, roomIndex(0, level: level), true, level: level)
            world.aShowHUDMessage(message(10, level: level))
            world.aSoundPlaySteamingText("Intro1.osf", 1)
            world.aTogglePlayerControl(1, 0, 63, level: level)
            increment(\.script014Count, world: &world)
        }
    }

    /// CustomObjectScript_1806 EVT_COLLIDE, FinishCourse
    /// (TrainingMission.cpp:1829-1849).
    static func collideFinishCourse(world: inout GameWorld, level: Level) {
        // Script 015: Finish Course
        if world.trainingMission.script015Count < 1 {
            world.aToggleAllPlayerControls(0, 0, level: level)
            world.aTogglePlayerControl(1, 0, 32, level: level)
            world.aPortalRenderSet(0, 0, roomIndex(1, level: level), true, level: level)
            world.aPortalRenderSet(0, 1, roomIndex(1, level: level), true, level: level)
            world.aShowHUDMessage(message(0, level: level))
            world.aSoundPlaySteamingText("proceed2.osf", 1)
            world.aShowHUDMessage(message(9, level: level))
            increment(\.script015Count, world: &world)
        }
    }

    /// CustomObjectScript_100A EVT_TIMER, StartDodge
    /// (TrainingMission.cpp:1865-1882).
    static func timerStartDodge(id: Int32, world: inout GameWorld, level: Level) {
        // Script 016: Start Dodge
        if world.trainingMission.script016Count < 1, id == 8 {
            world.aObjSetShields(world.qGetPlayerObj(0, level: level), 100)
            world.aShowHUDMessage(message(12, level: level))
            world.aSetObjectTimer(objectHandle(5, level: level), 20, 2)
            world.aSetObjectTimer(objectHandle(12, level: level), 14, 3)
            world.aAISetState(1, objectHandle(12, level: level))

            // Increment the script action counter
            increment(\.script016Count, world: &world)
        }
    }

    /// CustomObjectScript_300E EVT_COLLIDE, DoneDodgeingGoal
    /// (TrainingMission.cpp:1887-1902).
    static func collideDoneDodgeingGoal(world: inout GameWorld, level: Level) {
        // Script 019: Leaving Dodging Room
        if world.trainingMission.script019Count < 1 {
            world.aObjSetLightingDist(objectHandle(0, level: level), 50)
            world.aPortalRenderSet(0, 0, roomIndex(2, level: level), true, level: level)
            world.aPortalRenderSet(0, 1, roomIndex(2, level: level), true, level: level)
            world.aTogglePlayerControl(0, 0, 62, level: level)
            world.aSoundPlaySteamingText("proceed4.osf", 1)
            world.aShowHUDMessage(message(17, level: level))

            // Increment the script action counter
            increment(\.script019Count, world: &world)
        }
    }

    /// CustomObjectScript_300E EVT_TIMER, DoneDodgeingGoal
    /// (TrainingMission.cpp:1903-1921).
    static func timerDoneDodgeingGoal(
        id: Int32,
        world: inout GameWorld,
        level: Level
    ) {
        // Script 017: Player Done Dodging
        if world.trainingMission.script017Count < 1,
           (world.trainingMission.script016Count > 0) == true, id == 2 {
            world.aObjSetLightingDist(objectHandle(0, level: level), 50)
            world.aPortalRenderSet(0, 0, roomIndex(2, level: level), true, level: level)
            world.aPortalRenderSet(0, 1, roomIndex(2, level: level), true, level: level)
            world.aAISetState(0, objectHandle(12, level: level))
            world.aTogglePlayerControl(1, 0, 3, level: level)
            world.aSoundPlaySteamingText("proceed3.osf", 1)
            world.aShowHUDMessage(message(0, level: level))
            world.aShowHUDMessage(message(13, level: level))

            // Increment the script action counter
            increment(\.script017Count, world: &world)
        }
    }

    /// CustomObjectScript_2007 EVT_TIMER, DodgeTurrett
    /// (TrainingMission.cpp:1926-1941). It has no counter test, so every
    /// timer 3 runs it.
    static func timerDodgeTurrett(id: Int32, world: inout GameWorld, level: Level) {
        // Script 020: Almost Done dodging
        if id == 3 {
            world.aSoundPlaySteamingText("almost.osf", 1)
            world.aShowHUDMessage(message(19, level: level))

            // Increment the script action counter
            increment(\.script020Count, world: &world)
        }
    }

    /// CustomObjectScript_080F EVT_COLLIDE, ManuverRoomCenter
    /// (TrainingMission.cpp:1943-1966).
    static func collideManuverRoomCenter(world: inout GameWorld, level: Level) {
        // Script 021: Enter Manuver room
        if world.trainingMission.script021Count < 1,
           (world.trainingMission.script020Count > 0) == true {
            world.aToggleShowPlayerControl(1, 0, level: level)
            world.aObjSetLightingDist(objectHandle(0, level: level), 0)
            world.aToggleAllPlayerControls(0, 0, level: level)
            world.aPortalRenderSet(1, 1, roomIndex(2, level: level), true, level: level)
            world.aPortalRenderSet(1, 0, roomIndex(2, level: level), true, level: level)
            world.aShowHUDMessage(message(20, level: level))
            world.aTogglePlayerControl(1, 0, 768, level: level)
            world.aSetLevelTimer(20, 4)
            world.aSoundPlaySteamingText("intro3.osf", 1)
            world.aShowHUDMessage(message(21, level: level))

            // Increment the script action counter
            increment(\.script021Count, world: &world)
        }
    }

    /// CustomObjectScript_2008 EVT_TIMER, FollowBot1
    /// (TrainingMission.cpp:1987-2003). It has no counter test of its own.
    static func timerFollowBot1(id: Int32, world: inout GameWorld, level: Level) {
        // Script 026: Done Following
        if (world.trainingMission.script025Count > 0) == true, id == 7 {
            world.aTogglePlayerControl(1, 0, 12288, level: level)
            world.aAIGoalFollowPathSimple(
                objectHandle(13, level: level),
                pathIndex(1, level: level),
                4352,
                0,
                3,
                level: level
            )
            world.aShowHUDMessage(message(0, level: level))
            world.aShowHUDMessage(message(23, level: level))
            world.aSoundPlaySteamingText("intro4.osf", 1)
            world.aShowHUDMessage(message(24, level: level))

            // Increment the script action counter
            increment(\.script026Count, world: &world)
        }
    }

    /// CustomObjectScript_2008 EVT_DESTROY, FollowBot1
    /// (TrainingMission.cpp:1971-1985).
    static func destroyFollowBot1(world: inout GameWorld, level: Level) {
        // Script 037: Follow Bot Destroyed Delay
        if world.trainingMission.script037Count < 1,
           (world.trainingMission.script026Count > 0) == true {
            world.aSetLevelTimer(2, 11)

            // Increment the script action counter
            increment(\.script037Count, world: &world)
        }
    }

    /// CustomObjectScript_1011 EVT_DESTROY, DestroyBot1
    /// (TrainingMission.cpp:2010-2027).
    static func destroyDestroyBot1(world: inout GameWorld, level: Level) {
        // Script 028: DestroyBot1 Destroyed
        if world.trainingMission.script028Count < 1,
           (world.trainingMission.script027Count > 0) == true {
            world.aObjGhostSet(0, objectHandle(15, level: level))
            world.aAIGoalFollowPathSimple(
                objectHandle(15, level: level),
                pathIndex(0, level: level),
                8_392_960,
                -1,
                3,
                level: level
            )

            // Increment the script action counter
            increment(\.script028Count, world: &world)
        }
    }

    /// CustomObjectScript_1010 EVT_DESTROY, DestroyBot2
    /// (TrainingMission.cpp:2033-2053). It has no counter test.
    static func destroyDestroyBot2(world: inout GameWorld, level: Level) {
        // Script 036: DestroyBot2 Destroyed Delay
        world.aSetLevelTimer(2, 12)
        world.aObjSetLightingDist(objectHandle(1, level: level), 50)
        world.aPortalRenderSet(0, 1, roomIndex(3, level: level), true, level: level)
        world.aPortalRenderSet(0, 0, roomIndex(3, level: level), true, level: level)
        world.aToggleAllPlayerControls(1, 0, level: level)

        // Increment the script action counter
        increment(\.script036Count, world: &world)
    }

    /// CustomObjectScript_100A EVT_COLLIDE, StartDodge
    /// (TrainingMission.cpp:1851-1867).
    static func collideStartDodge(
        me: ObjectHandle,
        world: inout GameWorld,
        level: Level
    ) {
        // Script 033: Start Dodge Timer Delay
        if world.trainingMission.script033Count < 1 {
            world.aTogglePlayerControl(0, 0, 3, level: level)
            world.aTogglePlayerControl(1, 0, 60, level: level)
            world.aPortalRenderSet(1, 0, roomIndex(1, level: level), true, level: level)
            world.aPortalRenderSet(1, 1, roomIndex(1, level: level), true, level: level)
            world.aSoundPlaySteamingText("intro2.osf", 1)
            world.aShowHUDMessage(message(11, level: level))
            world.aSetObjectTimer(me, 10, 8)
            increment(\.script033Count, world: &world)
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
