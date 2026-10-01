// SPDX-License-Identifier: GPL-3.0-or-later
//
// The logical part of the high-level sound system that game state depends
// on. Translated from sndlib/hlsoundlib.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): hlsSystem::Play3dSound for an object
// (:1033-1120: the checks that refuse a sound, and the link of a sound
// whose page has SPF_LISTENER_UPDATE and SPF_OBJ_UPDATE to its object), and
// the sound frame's stop of a linked sound whose object is gone or ghosted
// (:722-750). The playback itself (buffers, 3D mixing, priorities, and
// playback positions) belongs to RevivalMac (architecture.md section 7).
//
// A 3D sound gets a handle from a counter; the original returns its sound
// object slot and unique id. Only a looping linked sound is kept: the app
// plays it while the world lists it. Every other 3D sound is a one-shot
// presentation request.

import Foundation

/// The sound handles the world has given, and the looping sounds that
/// follow an object.
struct SoundSystemState: Codable, Equatable, Sendable {
    /// The handle of the next 3D sound. -1 is "no sound".
    var nextHandle: Int32 = 0
    /// The playing looping sounds linked to an object, in start order.
    var objectLoops: [ObjectSoundLoop] = []
}

/// A looping sound linked to an object (SIF_OBJ_UPDATE with SPF_LOOPED).
struct ObjectSoundLoop: Codable, Equatable, Sendable {
    let handle: Int32
    /// The index of the sound in `Level.soundClips` (the sound table).
    let soundIndex: Int
    let object: ObjectHandle
}

extension Level {
    /// The SPF_ flags of a sound page, as far as the package records them:
    /// the game modules' sound pages carry their flags. Other sounds have
    /// none.
    func soundPageFlags(_ soundIndex: Int) -> Int32 {
        guard soundClips.indices.contains(soundIndex) else { return 0 }
        let key = soundClips[soundIndex].logicalName
        for module in gameModules ?? [] {
            if let sound = module.sounds.first(where: { $0.key == key }) {
                return sound.flags
            }
        }
        return 0
    }
}

extension GameWorld {
    /// hlsSystem::Play3dSound for an object (hlsoundlib.cpp:1033): a sound
    /// that does not exist, or an object that does not, gives no sound
    /// (-1). A looping page linked to its object keeps playing until the
    /// object is gone or ghosted; any other sound plays once. Returns the
    /// sound handle.
    mutating func playObjectSound3D(
        _ soundIndex: Int,
        object handle: ObjectHandle,
        level: Level
    ) -> Int32 {
        guard soundIndex >= 0,
              level.soundClips.indices.contains(soundIndex),
              objects[handle] != nil
        else {
            return -1
        }
        let soundHandle = soundSystem.nextHandle
        soundSystem.nextHandle = soundHandle == Int32.max ? 0 : soundHandle + 1
        let flags = level.soundPageFlags(soundIndex)
        let linked = GameModuleSoundReference.objectUpdateFlag
            | GameModuleSoundReference.listenerUpdateFlag
        if flags & GameModuleSoundReference.loopedFlag != 0,
           flags & linked == linked {
            soundSystem.objectLoops.append(.init(
                handle: soundHandle,
                soundIndex: soundIndex,
                object: handle
            ))
        } else {
            play3DSound(level.soundClips[soundIndex].logicalName)
        }
        return soundHandle
    }

    /// The sound frame's check of the linked sounds (hlsoundlib.cpp:722,
    /// :748): a sound whose object is gone or is OBJ_DUMMY stops.
    mutating func stopSoundsOfGoneObjects() {
        soundSystem.objectLoops.removeAll {
            objects[$0.object].map { $0.type == .dummy } ?? true
        }
    }
}

/// The sound pages the translated engine plays by name: static sounds of
/// Static_sound_names (sndlib/soundload.cpp:253) and the pages the engine
/// finds with FindSoundName. D3Import adds every one to each level, as
/// PageInAllData pages the static sounds in (gamesequence.cpp:2481).
enum EngineSound {
    /// SOUND_POWERUP_PICKUP (sounds.h:116).
    static let powerupPickup = "Powerup pickup"
    /// SOUND_GOAL_COMPLETE (sounds.h:146).
    static let goalComplete = "GoalComplete"
    /// MakePlayerInvulnerable and MakePlayerVulnerable (Player.cpp:1585,
    /// :1606).
    static let invulnerabilityOn = "Invulnerability on"
    static let invulnerabilityOff = "Invulnerability off"
    /// MakeObjectInvisible and MakeObjectVisible (object_lighting.cpp:581,
    /// :609).
    static let cloakOn = "Cloak on"
    static let cloakOff = "Cloak off"

    /// Every engine sound, in a fixed order for the import.
    static let names = [
        powerupPickup, goalComplete, invulnerabilityOn, invulnerabilityOff,
        cloakOn, cloakOff,
    ]
}
