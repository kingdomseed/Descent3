// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/gameevent.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): AllocEvent (:102), FreeEvent
// (:125), ProcessNormalEvents (:143), and CreateNewEvent (:206), for the
// normal (non-render) events the translated code makes: DoExplosionEvent
// and DoBlastRingEvent (Descent3/fireball.cpp:2337-2380).
//
// Render events (RENDER_EVENT: the screen flash of a blast ring, the damage
// effect) are presentation and are not made; in the original they share the
// MAX_EVENTS slots (architecture.md section 9).

import Foundation

/// One `game_event` (gameevent.h) of a normal event.
struct GameEvent: Codable, Equatable, Sendable {
    /// MAX_EVENTS (gameevent.h:25).
    static let capacity = 500

    /// The event's subfunction and the data it copied.
    enum Action: Codable, Equatable, Sendable {
        /// DoExplosionEvent (fireball.cpp:2344): `vals[0]` to `vals[6]`.
        case explosion(
            position: Vector3,
            fireballID: UInt8,
            roomSourceIndex: Int,
            size: Float,
            upwardsVelocity: Float
        )
        /// DoBlastRingEvent (fireball.cpp:2337) with the fields of the
        /// copied object that CreateObjectBlastRing reads.
        case blastRing(position: Vector3, size: Float, roomSourceIndex: Int)
    }

    var startTime: Float
    var endTime: Float
    /// `objhandle_detonator`.
    var detonator: ObjectHandle?
    var action: Action
}

extension GameWorld {
    /// CreateNewEvent (gameevent.cpp:206) with AllocEvent's lowest free
    /// slot. Returns nil when all MAX_EVENTS slots are used.
    @discardableResult
    mutating func createNewEvent(
        length: Float,
        action: GameEvent.Action,
        detonator: ObjectHandle? = nil
    ) -> Int? {
        guard let slot = gameEvents.firstIndex(where: { $0 == nil }) else {
            return nil
        }
        gameEvents[slot] = GameEvent(
            startTime: gameTime,
            endTime: gameTime + length,
            detonator: detonator,
            action: action
        )
        return slot
    }

    /// ProcessNormalEvents (gameevent.cpp:143): in slot order, an event
    /// whose detonator died is freed, and an event whose end time has come
    /// runs and is freed. The loop stops once it has seen as many used
    /// slots as are in use, as the original's `count < Num_events` does.
    mutating func processNormalEvents(level: Level) {
        var count = 0
        for slot in 0..<GameEvent.capacity {
            guard count < gameEvents.count(where: { $0 != nil }) else {
                break
            }
            guard let event = gameEvents[slot] else { continue }
            count += 1
            if let detonator = event.detonator {
                let object = objects[detonator]
                if object == nil || object?.type == .ghost
                    || (object?.type == .player && playerDeath != nil) {
                    gameEvents[slot] = nil
                    continue
                }
            }
            guard event.endTime <= gameTime else { continue }
            handleEvent(event.action, level: level)
            gameEvents[slot] = nil
        }
    }

    /// HandleEvent (gameevent.cpp:238).
    private mutating func handleEvent(
        _ action: GameEvent.Action,
        level: Level
    ) {
        switch action {
        case let .explosion(position, id, room, size, upwards):
            // DoExplosionEvent (fireball.cpp:2344).
            guard let index = createFireball(
                position: position,
                id: id,
                roomSourceIndex: room,
                level: level
            ) else {
                return
            }
            // SOUND_ROBOT_EXPLODE_1 or _2: the static sound table arrives in
            // M2; the draw is made.
            _ = psRand() > GameWorld.randMax / 2
            visEffects[index].size = size
            if upwards > 0.001 {
                visEffects[index].usesPhysics = true
                visEffects[index].physicsFlags =
                    WeaponPhysics.fixedVelocityFlag
                visEffects[index].velocity = Vector3(x: 0, y: upwards, z: 0)
            }
        case let .blastRing(position, size, room):
            // DoBlastRingEvent: CreateObjectBlastRing on the copy.
            createBlastRing(
                position: position,
                id: VisEffect.blastRingID,
                lifetime: GameWorld.damageRingTime,
                maximumSize: size,
                roomSourceIndex: room,
                level: level
            )
        }
    }
}
