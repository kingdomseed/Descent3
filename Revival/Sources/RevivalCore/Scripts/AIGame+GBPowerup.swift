// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from scripts/AIGame.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): the GBPowerup class (:1280) and
// its memory (gbpowerup_data), DoInit (:8228), DoFrame (:8260), and
// CallEvent (:8308). A Guide-Bot powerup looks for the Guide-Bot every 0.2
// to 0.5 seconds and, when it is within 5 units, gives itself to it with
// COM_POWERUP_PICKUP; a player who touches it reads that it is for the
// Guide-Bot.

import Foundation

/// The GBPowerup instance: `memory` is nil until EVT_AI_INIT allocates it.
struct GBPowerupState: Codable, Equatable, Sendable {
    var memory: GBPowerupMemory? = nil
}

/// gbpowerup_data.
struct GBPowerupMemory: Codable, Equatable, Sendable {
    var nextCheckTime: Float = 0
    var timeUntilNextHUDMessage: Float = 0
    /// The GB_POW_ kind (0-5).
    var type = 5
}

enum GBPowerupScript {
    /// TXT_GB_POWERUP (AIGame.cpp:152).
    static let powerupText = 93

    static func isValidSavedState(_ state: GBPowerupState) -> Bool {
        guard let memory = state.memory else { return true }
        return (0...5).contains(memory.type)
    }

    /// DoInit (AIGame.cpp:8228).
    static func doInit(_ me: ObjectHandle, _ world: inout GameWorld,
                       _ level: Level) {
        // Seed the powerups differently.
        let next = world.gameTime + world.aigameRandFraction()
        let pages = GuideBotScript.powerupPageNames.map {
            world.objectFindID($0, level: level)
        }
        let id = world.objectID(me)
        var memory = GBPowerupMemory(nextCheckTime: next,
                                     timeUntilNextHUDMessage: 0)
        // Forced to the speed powerup if it does not know what it is.
        memory.type = 5
        for (index, page) in pages.enumerated() where page >= 0 && id == page {
            memory.type = index
        }
        world.setGBPowerupMemory(me, memory)
    }

    /// DoFrame (AIGame.cpp:8260).
    static func doFrame(_ me: ObjectHandle, _ world: inout GameWorld,
                        _ level: Level) {
        guard let memory = world.gbPowerup(me),
              memory.nextCheckTime <= world.gameTime
        else {
            return
        }
        let next = world.gameTime + 0.2 + world.aigameRandFraction() * 0.3
        world.updateGBPowerup(me) { $0.nextCheckTime = next }
        guard let object = world.objects[me],
              case let .room(room) = object.location
        else {
            return
        }
        let scanned = world.aiGetNearbyObjects(
            position: object.position, room: room, radius: 5, maximum: 25,
            lightmapOnly: false, onlyPlayersAndAIs: true,
            includeNonCollideObjects: false, stopAtClosedDoors: true,
            level: level
        )
        let guideBot = world.objectFindID(GuideBotScript.pageName,
                                          level: level)
        let redGuideBot = world.objectFindID(
            CanonicalObjectInfo.guideBotRedPageName, level: level
        )
        for candidate in scanned {
            let id = world.objectID(candidate)
            guard world.objectType(candidate) == .robot,
                  (guideBot >= 0 && id == guideBot)
                    || (redGuideBot >= 0 && id == redGuideBot)
            else {
                continue
            }
            let distance = vectorDistance(object.position,
                                          world.objectPosition(candidate))
            if distance < 5 {
                world.callObjectEvent(
                    candidate,
                    .aiNotify(
                        .userDefined, it: me,
                        info: .command(.init(
                            action: GuideBotCommand.powerupPickup,
                            index: Int8(memory.type)
                        ))
                    ),
                    level: level
                )
                break
            }
        }
    }

    /// CallEvent (AIGame.cpp:8308).
    static func callEvent(_ event: ScriptEvent, me: ObjectHandle,
                          world: inout GameWorld, level: Level) -> ChainFlags {
        switch event {
        case .interval:
            let frameTime = world.frameDuration
            world.updateGBPowerup(me) {
                $0.timeUntilNextHUDMessage -= frameTime
            }
        case .aiInit:
            doInit(me, &world, level)
        case .aiFrame:
            doFrame(me, &world, level)
        case let .collide(it):
            guard let memory = world.gbPowerup(me),
                  memory.timeUntilNextHUDMessage <= 0
            else {
                break
            }
            world.updateGBPowerup(me) { $0.timeUntilNextHUDMessage = 1 }
            if world.objectType(it) == .player {
                world.playerAddHUDMessage(
                    it,
                    AIGame.text(powerupText, level: level)
                )
            }
        default:
            break
        }
        return .all
    }
}

extension GameWorld {
    /// The GBPowerup memory of an object, or nil.
    func gbPowerup(_ me: ObjectHandle) -> GBPowerupMemory? {
        guard case let .gbPowerup(state)? =
                objects[me]?.scripts?.defaultScript
        else {
            return nil
        }
        return state.memory
    }

    mutating func setGBPowerupMemory(_ me: ObjectHandle,
                                     _ memory: GBPowerupMemory) {
        guard var scripts = objects[me]?.scripts,
              case .gbPowerup = scripts.defaultScript
        else {
            return
        }
        scripts.defaultScript = .gbPowerup(GBPowerupState(memory: memory))
        objects[me]?.scripts = scripts
    }

    mutating func updateGBPowerup(_ me: ObjectHandle,
                                  _ change: (inout GBPowerupMemory) -> Void) {
        guard var memory = gbPowerup(me) else { return }
        change(&memory)
        setGBPowerupMemory(me, memory)
    }
}
