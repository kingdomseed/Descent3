// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/DallasFuncs.cpp and scripts/DallasFuncs.h
// (Descent 3, Copyright (C) 2024 Parallax Software, GPL-3.0-or-later): the
// DALLAS variables (DallasFuncs.cpp:916-926, DallasFuncs.h:6-40), dfInit
// (:961), aPortalRenderSet (:1098), aShowHUDMessage (:1227),
// aSetLevelTimer (:2477), aSoundPlay2D (:2748), and aSoundPlaySteaming
// (:2795, which aSoundPlaySteamingText names, DallasFuncs.h:137). The DALLAS names are kept so each call can be checked
// against the C++ line by line.

/// A DALLAS user variable (`user_var`, DallasFuncs.h:6).
enum DallasUserVar: Codable, Equatable, Sendable {
    case float(Float)
    case int(Int32)
}

/// The DALLAS globals that each level module holds (DallasFuncs.cpp:916-926).
/// dfSave and dfRestore are dropped: this value is saved with the world.
struct DallasState: Codable, Equatable, Sendable {
    /// MAX_SPEW_HANDLES (DallasFuncs.h:37).
    static let maximumSpewHandles = 50
    /// MAX_SOUND_HANDLES (DallasFuncs.cpp:922).
    static let maximumSoundHandles = 10
    /// MAX_USER_VARS (DallasFuncs.h:34).
    static let maximumUserVars = 25
    /// MAX_SAVED_OBJECT_HANDLES (DallasFuncs.h:40).
    static let maximumSavedObjectHandles = 20

    var spewHandles: [Int32]
    var soundHandles: [Int32]
    var userVars: [DallasUserVar]
    var savedObjectHandles: [ObjectHandle]
    var userFlags: Int32

    /// dfInit (DallasFuncs.cpp:961). `intUserVars` lists the user variables
    /// that the level declares as integers.
    static func dfInit(intUserVars: [Int] = []) -> DallasState {
        var userVars = Array(
            repeating: DallasUserVar.float(0),
            count: maximumUserVars
        )
        for index in intUserVars {
            userVars[index] = .int(0)
        }
        return DallasState(
            // SPEW_INVALID_HANDLE and SOUND_INVALID_HANDLE are -1.
            spewHandles: Array(repeating: -1, count: maximumSpewHandles),
            soundHandles: Array(repeating: -1, count: maximumSoundHandles),
            userVars: userVars,
            savedObjectHandles: Array(
                repeating: .none,
                count: maximumSavedObjectHandles
            ),
            userFlags: 0
        )
    }
}

extension GameWorld {
    /// aShowHUDMessage (DallasFuncs.cpp:1227): a green HUD message for all
    /// players. The generated scripts pass message strings with no format
    /// arguments.
    mutating func aShowHUDMessage(_ message: String) {
        addHUDMessage(message)
    }

    /// aSoundPlaySteaming, called as aSoundPlaySteamingText
    /// (DallasFuncs.cpp:2795).
    mutating func aSoundPlaySteamingText(_ soundName: String, _ volume: Float) {
        playStreamedAudio(soundName, volume: volume)
    }

    /// aSetLevelTimer (DallasFuncs.cpp:2477): a one-shot level timer.
    /// The C++ also copies OTF_LEVEL into repeat_count, which Osiris ignores
    /// without OTF_REPEATER.
    mutating func aSetLevelTimer(_ time: Float, _ id: Int32) {
        osirisCreateTimer(.init(target: .level, id: id, interval: time))
    }

    /// aSoundPlay2D (DallasFuncs.cpp:2748): MSAFE_SOUND_2D for all players.
    /// `soundnum` is a Sound_indexes value (`Level.findSoundName`).
    mutating func aSoundPlay2D(_ soundnum: Int, _ volume: Float, level: Level) {
        playSound2D(soundnum, volume: volume, level: level)
    }

    /// aPortalRenderSet (DallasFuncs.cpp:1098): MSAFE_ROOM_PORTAL_RENDER.
    /// `roomnum` is a Room_indexes value (`Level.findRoomName`).
    mutating func aPortalRenderSet(
        _ state: Int32,
        _ portalnum: Int,
        _ roomnum: Int,
        _ doublesided: Bool,
        level: Level
    ) {
        setPortalRender(
            room: roomnum,
            portal: portalnum,
            state: state != 0,
            doubleSided: doublesided,
            level: level
        )
    }
}
