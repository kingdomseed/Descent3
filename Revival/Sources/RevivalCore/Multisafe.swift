// SPDX-License-Identifier: GPL-3.0-or-later
//
// Engine functions that level scripts reach through MSafe_CallFunction and
// MSafe_GetValue. Translated from Descent3/multisafe.cpp (Descent 3,
// Copyright (C) 2024 Parallax Software, GPL-3.0-or-later): the
// MSAFE_OBJECT_PLAYER_HANDLE value (:1002), MSAFE_SHOW_ENABLED_CONTROLS
// (:1577), MSAFE_OBJECT_PLAYER_CMASK (:1583), MSAFE_OBJECT_GHOST and
// MSAFE_OBJECT_UNGHOST (:1739, :1752), MSAFE_OBJECT_INVULNERABLE (:1768),
// MSAFE_OBJECT_LIGHT_DIST (:1821), MSAFE_OBJECT_LIGHT_COLOR (:1832),
// MSAFE_SOUND_STREAMING (:1939), and MSAFE_MISC_HUD_MESSAGE (:2021), with
// ObjGhostObject and ObjUnGhostObject (Descent3/object.cpp:3463, :3483).
// MSAFE_OBJECT_NO_RENDER is `GameWorld.setObjectRendered`. Multiplayer
// routing is dropped: the only player is slot 0.

/// A presentation request from a script. RevivalCore has no audio or HUD
/// objects; the app presents these.
enum ScriptPresentationRequest: Codable, Equatable, Sendable {
    /// MSAFE_MISC_HUD_MESSAGE for all players, in green.
    case hudMessage(String)
    /// MSAFE_SOUND_STREAMING for all players: StreamPlay(name, volume).
    case streamedAudio(name: String, volume: Float)
}

extension GameWorld {
    /// MSAFE_OBJECT_PLAYER_HANDLE (multisafe.cpp:1002): the object of player
    /// `slot`, or OBJECT_HANDLE_NONE. Single player has only slot 0.
    func playerObjectHandle(slot: Int, level: Level) -> ObjectHandle {
        guard slot == 0, let binding = level.defaultPlayerBinding else {
            return .none
        }
        return ObjectHandle(binding.objectHandle)
    }

    /// MSAFE_SHOW_ENABLED_CONTROLS (multisafe.cpp:1577).
    mutating func setShowEnabledControls(_ handle: ObjectHandle, _ show: Bool) {
        guard objects[handle]?.type == .player else { return }
        hudShowControls = show
    }

    /// MSAFE_OBJECT_PLAYER_CMASK (multisafe.cpp:1583).
    mutating func setPlayerControlMask(
        _ handle: ObjectHandle,
        mask: UInt32,
        enabled: Bool
    ) {
        guard objects[handle]?.type == .player else { return }
        let mask = PlayerControlMask(rawValue: mask)
        if enabled {
            playerControllerBitflags.formUnion(mask)
        } else {
            playerControllerBitflags.subtract(mask)
        }
    }

    /// MSAFE_OBJECT_GHOST (multisafe.cpp:1739) and ObjGhostObject
    /// (object.cpp:3463): the object keeps its type in `dummyType` and
    /// becomes OBJ_DUMMY.
    mutating func ghostObject(_ handle: ObjectHandle) {
        guard var object = objects[handle],
              object.type != .dummy,
              object.type != .player,
              object.type != .ghost
        else {
            return
        }
        object.dummyType = object.type
        object.type = .dummy
        objects[handle] = object
    }

    /// MSAFE_OBJECT_UNGHOST (multisafe.cpp:1752) and ObjUnGhostObject
    /// (object.cpp:3483).
    mutating func unghostObject(_ handle: ObjectHandle) {
        guard var object = objects[handle],
              object.type == .dummy,
              let realType = object.dummyType
        else {
            return
        }
        object.type = realType
        object.dummyType = nil
        objects[handle] = object
    }

    /// MSAFE_OBJECT_INVULNERABLE (multisafe.cpp:1768). A player gets
    /// MakePlayerInvulnerable or MakePlayerVulnerable. Another object loses
    /// or gets OF_DESTROYABLE.
    mutating func setObjectInvulnerable(
        _ handle: ObjectHandle,
        _ invulnerable: Bool,
        lifetime: Float
    ) {
        guard var object = objects[handle] else { return }
        if object.type == .player {
            if invulnerable {
                makePlayerInvulnerable(time: lifetime)
            } else {
                makePlayerVulnerable()
            }
        } else {
            if invulnerable {
                object.flags &= ~GameObject.destroyableFlag
            } else {
                object.flags |= GameObject.destroyableFlag
            }
            objects[handle] = object
        }
    }

    /// MSAFE_OBJECT_LIGHT_DIST (multisafe.cpp:1821). A negative distance
    /// becomes 0.
    mutating func setObjectLightDistance(
        _ handle: ObjectHandle,
        _ distance: Float
    ) {
        guard var object = objects[handle] else { return }
        var lighting = object.localLighting ?? ObjectLocalLighting()
        lighting.lightDistance = distance < 0 ? 0 : distance
        object.localLighting = lighting
        objects[handle] = object
    }

    /// MSAFE_OBJECT_LIGHT_COLOR (multisafe.cpp:1832).
    mutating func setObjectLightColor(
        _ handle: ObjectHandle,
        red: Float,
        green: Float,
        blue: Float
    ) {
        guard var object = objects[handle] else { return }
        var lighting = object.localLighting ?? ObjectLocalLighting()
        lighting.color = Vector3(x: red, y: green, z: blue)
        object.localLighting = lighting
        objects[handle] = object
    }

    /// MSAFE_SOUND_STREAMING for all players (multisafe.cpp:1939).
    mutating func playStreamedAudio(_ name: String, volume: Float) {
        presentationRequests.append(
            .streamedAudio(name: name, volume: volume)
        )
    }

    /// MSAFE_MISC_HUD_MESSAGE for all players (multisafe.cpp:2021).
    /// XlateGBMessage (multisafe.cpp:1276) changes only messages that start
    /// with the Guide-Bot token; the Guide-Bot scripts bring that in M1
    /// step 8.
    mutating func addHUDMessage(_ message: String) {
        presentationRequests.append(.hudMessage(message))
    }
}
