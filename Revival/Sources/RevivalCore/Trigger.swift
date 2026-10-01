// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/trigger.cpp and Descent3/trigger.h (Descent 3,
// Copyright (C) 2024 Parallax Software, GPL-3.0-or-later): the trigger
// flags and activators (trigger.h:93-104), FindTrigger (:170), and
// CheckTrigger (:185); and ObjCheckTriggers (Descent3/object.cpp:2584).
// The level holds the immutable trigger (name, room, face, activator);
// the world holds the flags that change at run time, which SGSTriggers
// saves (gamesave.cpp:951).

/// The `trigger` flags (trigger.h:93-97).
enum TriggerFlag {
    static let disabled: UInt16 = 0x0002
    static let dead: UInt16 = 0x0004
    static let oneShot: UInt16 = 0x0008
    static let informActivateToLevelGoals: UInt16 = 0x0010
}

/// The activator flags (trigger.h:100-104).
enum TriggerActivator {
    static let player: UInt16 = 0x0001
    static let playerWeapon: UInt16 = 0x0002
    static let robot: UInt16 = 0x0004
    static let robotWeapon: UInt16 = 0x0008
    static let clutter: UInt16 = 0x0010
}

/// TT_PASS_THROUGH and TT_COLLIDE (trigger.h:143-144).
enum TriggerEventType: Equatable, Sendable {
    /// An object's move went through the trigger face (ObjCheckTriggers).
    case passThrough
    /// An object hit the trigger face (collide_player_and_wall,
    /// collide.cpp:1295).
    case collide
}

extension LevelFace {
    /// FF_HAS_TRIGGER (room_external.h:116).
    static let hasTriggerFlag: UInt16 = 0x0010
}

extension GameWorld {
    /// The flags of every trigger at level start, indexed like
    /// `Level.triggers`.
    static func initialTriggerFlags(_ level: Level) -> [UInt16] {
        level.triggers.map(\.flags)
    }

    /// FindTrigger (trigger.cpp:170): the first trigger on the room's face.
    func findTrigger(room: Int, face: Int, level: Level) -> Int? {
        level.triggers.firstIndex {
            $0.roomIndex == room && $0.faceIndex == face
        }
    }

    /// CheckTrigger (trigger.cpp:185): an object passed through or hit a
    /// face. When the face has a live trigger that the object can
    /// activate, the trigger's script gets EVT_COLLIDE with the object as
    /// `it`, and a one-shot trigger dies.
    mutating func checkTrigger(
        room: Int,
        face: Int,
        object handle: ObjectHandle,
        eventType: TriggerEventType,
        level: Level
    ) {
        guard let roomInfo = level.rooms.first(where: {
                  $0.sourceIndex == room
              }),
              roomInfo.faces.indices.contains(face)
        else {
            return
        }
        let faceInfo = roomInfo.faces[face]
        guard faceInfo.flags & LevelFace.hasTriggerFlag != 0,
              let trigger = findTrigger(room: room, face: face, level: level),
              let object = objects[handle]
        else {
            return
        }
        // A dead or disabled trigger does nothing.
        guard triggerFlags[trigger]
                & (TriggerFlag.disabled | TriggerFlag.dead) == 0
        else {
            return
        }
        // A portal trigger fires only on a pass-through.
        if faceInfo.portalIndex != nil, eventType != .passThrough {
            return
        }
        // The activator type of the object that hit the trigger.
        let type: UInt16
        switch object.type {
        case .player:
            type = TriggerActivator.player
        case .building, .robot:
            type = TriggerActivator.robot
        case .clutter:
            type = TriggerActivator.clutter
        case .weapon:
            switch objects[objectUltimateParent(handle)]?.type {
            case .player:
                type = TriggerActivator.playerWeapon
            case .robot, .building:
                type = TriggerActivator.robotWeapon
            default:
                // Unknown parent for weapon.
                return
            }
        default:
            return
        }
        guard level.triggers[trigger].activator & type != 0 else { return }
        osirisCallTriggerEvent(trigger, .collide(it: handle), level: level)
        // A one-shot trigger dies. Its face would also be marked
        // FF_DESTROYED when it is not a portal face; breakable faces arrive
        // with M2 (architecture.md section 9).
        if triggerFlags[trigger] & TriggerFlag.oneShot != 0 {
            triggerFlags[trigger] |= TriggerFlag.dead
        }
        if triggerFlags[trigger] & TriggerFlag.informActivateToLevelGoals
            != 0 {
            levelGoalsInform(
                type: LevelGoalItemType.trigger,
                completion: LevelGoalFlag.completeActivate,
                handle: Int32(trigger),
                level: level
            )
        }
    }

    /// ObjCheckTriggers (object.cpp:2584): after an object's move, each face
    /// its move recorded (Fvi_recorded_faces) is a pass-through.
    mutating func objCheckTriggers(
        _ handle: ObjectHandle,
        recordedFaces: [IndoorPortalCrossing],
        level: Level
    ) {
        for face in recordedFaces {
            checkTrigger(
                room: face.roomSourceIndex,
                face: face.faceIndex,
                object: handle,
                eventType: .passThrough,
                level: level
            )
        }
    }
}
