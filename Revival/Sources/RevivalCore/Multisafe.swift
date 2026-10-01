// SPDX-License-Identifier: GPL-3.0-or-later
//
// Engine functions that level scripts reach through MSafe_CallFunction and
// MSafe_GetValue. Translated from Descent3/multisafe.cpp (Descent 3,
// Copyright (C) 2024 Parallax Software, GPL-3.0-or-later): the
// MSAFE_OBJECT_PLAYER_HANDLE value (:1002), MSAFE_SHOW_ENABLED_CONTROLS
// (:1577), MSAFE_OBJECT_PLAYER_CMASK (:1583), MSAFE_OBJECT_GHOST and
// MSAFE_OBJECT_UNGHOST (:1739, :1752), MSAFE_OBJECT_INVULNERABLE (:1768),
// MSAFE_OBJECT_LIGHT_DIST (:1821), MSAFE_OBJECT_LIGHT_COLOR (:1832),
// MSAFE_SOUND_STREAMING (:1939), MSAFE_SOUND_2D (:1955), and
// MSAFE_MISC_HUD_MESSAGE (:2021), MSAFE_ROOM_PORTAL_RENDER (:1447), and
// MSAFE_OBJECT_SHIELDS (get :851, set :1563), with ObjGhostObject and
// ObjUnGhostObject (Descent3/object.cpp:3463, :3483).
// MSAFE_OBJECT_NO_RENDER is `GameWorld.setObjectRendered`. Multiplayer
// routing is dropped: the only player is slot 0.

/// A presentation request from a script. RevivalCore has no audio or HUD
/// objects; the app presents these.
enum ScriptPresentationRequest: Codable, Equatable, Sendable {
    /// MSAFE_MISC_HUD_MESSAGE for all players, in green.
    case hudMessage(String)
    /// MSAFE_SOUND_STREAMING for all players: StreamPlay(name, volume).
    case streamedAudio(name: String, volume: Float)
    /// MSAFE_SOUND_2D for all players: Play2dSound(index, volume). The
    /// index is a `Level.soundClips` index (`Level.findSoundName`).
    case sound2D(index: Int, volume: Float)
    /// Play3dSound of an engine sound, named by its sound page. RevivalMac
    /// plays it without 3D placement until the 3D audio port (M2).
    case sound(name: String)
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

    /// Sound_system.Play3dSound for an engine sound (a weapon fire or
    /// impact sound). An empty name is SOUND_NONE_INDEX and plays nothing.
    mutating func play3DSound(_ name: String) {
        guard !name.isEmpty else { return }
        presentationRequests.append(.sound(name: name))
    }

    /// MSAFE_SOUND_2D for all players (multisafe.cpp:1955). An invalid
    /// index plays nothing, as Play2dSound returns -1.
    mutating func playSound2D(_ index: Int, volume: Float, level: Level) {
        guard level.soundClips.indices.contains(index) else { return }
        presentationRequests.append(.sound2D(index: index, volume: volume))
    }

    /// MSAFE_ROOM_PORTAL_RENDER (multisafe.cpp:1447): sets or clears
    /// PF_RENDER_FACES on a portal and, when `doubleSided`, on the portal
    /// on its other side. `room` is a room number (a source index). An
    /// invalid room or portal does nothing (VALIDATE_ROOM_PORTAL). The
    /// PF_CHANGED and RCF_PORTAL_RENDER flags only mark render caches, which
    /// Revival does not keep.
    mutating func setPortalRender(
        room: Int,
        portal: Int,
        state: Bool,
        doubleSided: Bool,
        level: Level
    ) {
        guard let roomIndex = level.rooms.firstIndex(where: {
                  $0.sourceIndex == room
              }),
              level.rooms[roomIndex].portals.indices.contains(portal)
        else {
            return
        }
        func set(_ roomIndex: Int, _ portalIndex: Int) {
            if state {
                rooms[roomIndex].portalFlags[portalIndex] |=
                    LevelPortal.renderFacesFlag
            } else {
                rooms[roomIndex].portalFlags[portalIndex] &=
                    ~LevelPortal.renderFacesFlag
            }
        }
        set(roomIndex, portal)
        guard doubleSided else { return }
        let connection = level.rooms[roomIndex].portals[portal]
        let connectedIndex = level.rooms.firstIndex {
            $0.sourceIndex == connection.connectedRoom
        }!
        set(connectedIndex, connection.connectedPortal)
    }

    /// MSAFE_OBJECT_SHIELDS read (multisafe.cpp:851): -1 for a stale
    /// handle. The player's shields are `shields`.
    func objectShields(_ handle: ObjectHandle) -> Float {
        guard let object = objects[handle] else { return -1 }
        return object.type == .player ? shields : object.shields
    }

    /// MSAFE_OBJECT_SHIELDS write (multisafe.cpp:1563): the shields, and
    /// OF_AI_DEATH clears. A stale handle does nothing.
    mutating func setObjectShields(_ handle: ObjectHandle, _ value: Float) {
        guard let object = objects[handle] else { return }
        if object.type == .player {
            shields = value
        } else {
            objects[handle]?.shields = value
        }
        objects[handle]?.flags &= ~GameObject.aiDeathFlag
    }

    /// MSAFE_INVEN_ADD_TYPE_ID (multisafe.cpp:2179) for a non-weapon type:
    /// Inventory::Add on the player the handle names.
    mutating func inventoryAddTypeID(
        _ player: ObjectHandle,
        type: ObjectType,
        id: Int
    ) {
        guard objects[player]?.type == .player else { return }
        playerInventory.add(type: type.rawValue, id: id)
    }

    /// MSAFE_INVEN_REMOVE (multisafe.cpp:2191) for a non-weapon type.
    mutating func inventoryRemove(
        _ player: ObjectHandle,
        type: ObjectType,
        id: Int
    ) {
        guard objects[player]?.type == .player else { return }
        playerInventory.remove(type: type.rawValue, id: id)
    }

    /// MSAFE_OBJECT_REMOVE (multisafe.cpp:1759): SetObjectDeadFlag, and the
    /// powerup pickup sound when asked. The scripts that call it without
    /// setting `playsound` pass no sound here.
    mutating func objectRemove(_ handle: ObjectHandle, playSound: Bool) {
        guard objects[handle] != nil else { return }
        objects[handle]?.flags |= GameObject.deadFlag
        if playSound {
            play3DSound("Powerup pickup")
        }
    }

    /// MSAFE_OBJECT_FIRE_WEAPON (multisafe.cpp:1529): FireWeaponFromObject
    /// for a weapon page the level holds.
    mutating func objectFireWeapon(
        _ handle: ObjectHandle,
        weapon: Int,
        gunpoint: Int,
        level: Level
    ) {
        guard objects[handle] != nil,
              weapon >= 0,
              let weapons = level.weapons,
              weapons.indices.contains(weapon)
        else {
            return
        }
        fireWeaponFromObject(
            handle,
            weaponName: weapons[weapon].name,
            gunpoint: gunpoint,
            forceForward: false,
            forceTarget: false,
            level: level
        )
    }
}
