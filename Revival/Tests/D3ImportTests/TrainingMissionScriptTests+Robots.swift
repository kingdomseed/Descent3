import AppKit
import XCTest

// The robot deaths of TrainingMission.cpp on the Osiris runtime: a robot
// dies through the generic KillObject and ObjDeleteDead path, its custom
// script hears EVT_DESTROY (dying), and Scripts 027-029, 036, 037,
// 043-046, and 051-055 run in source order; Scripts 047 and 048 run on
// the pickup contacts.
extension TrainingMissionScriptTests {
    private var followBot1: ObjectHandle { ObjectHandle(8_200) }
    private var destroyBot2: ObjectHandle { ObjectHandle(4_112) }
    private var destroyBot1: ObjectHandle { ObjectHandle(4_113) }

    /// Script 037 (TrainingMission.cpp:1977-1984) sets level timer 11 two
    /// seconds after FollowBot1 dies; Script 027 (:1558-1571) then turns
    /// both destroy bots to the rebel team, unghosts DestroyBot1, and sends
    /// it along FollowLoop1.
    func testFollowBot1DeathRunsScript037ThenScript027() throws {
        let session = try movingTargetSession()
        session.world.trainingMission.script026Count = 1
        killNow(session, followBot1)
        var timestamp = 0.1
        _ = session.update(at: timestamp, input: .zero)
        XCTAssertNil(session.world.objects[followBot1])
        XCTAssertEqual(session.world.testTrainingMission?.script037Count, 1)
        let timer = try XCTUnwrap(levelTimer(session, 11))
        XCTAssertEqual(timer.end, session.world.gameTime + 2, accuracy: 0.11)
        XCTAssertEqual(session.world.testTrainingMission?.script027Count, 0)

        var log: [String] = []
        for _ in 0..<30
        where session.world.testTrainingMission?.script027Count == 0 {
            timestamp += 0.1
            log = presentationLog(session.update(at: timestamp, input: .zero))
        }
        XCTAssertEqual(session.world.testTrainingMission?.script027Count, 1)
        XCTAssertEqual(
            log.filter { $0.hasPrefix("hud:") },
            [
                "hud:\(TrainingMissionScript.message(0, level: session.level))",
                "hud:\(TrainingMissionScript.message(25, level: session.level))",
            ]
        )
        XCTAssertTrue(log.contains("voice:kill1.osf"))
        XCTAssertFalse(log.contains { $0.contains("Message Not Found") })
        for handle in [destroyBot1, destroyBot2] {
            let ai = try XCTUnwrap(session.world.objects[handle]?.ai)
            XCTAssertEqual(ai.flags & ObjectAIFrame.teamMask, 65_536)
        }

        let bot1 = try XCTUnwrap(session.world.objects[destroyBot1])
        XCTAssertNotEqual(bot1.type, .dummy)
        XCTAssertEqual(bot1.ai?.goals[3].type, AIGoal.followPathType)
        XCTAssertEqual(
            bot1.ai?.goals[3].pathID, session.level.findPathName("FollowLoop1")
        )
        // DestroyBot2 stays a ghost until DestroyBot1 dies.
        XCTAssertEqual(session.world.objects[destroyBot2]?.type, .dummy)
    }

    /// Script 037 needs Script 026 (the end of the follow lesson).
    func testFollowBot1DeathBeforeScript026SetsNoTimer() throws {
        let session = try movingTargetSession()
        killNow(session, followBot1)
        _ = session.update(at: 0.1, input: .zero)
        XCTAssertEqual(session.world.testTrainingMission?.script037Count, 0)
        XCTAssertNil(levelTimer(session, 11))
    }

    /// ObjDeleteDead (object.cpp:2004-2045) in slot order, through the
    /// real handlers: each dead object's scripts hear EVT_DESTROY (dying)
    /// after it is unattached (an attached polygon object's attach parent
    /// hears EVT_CHILD_DIED first, which no Training script handles), and
    /// each is then deleted. FollowBot1's death runs Script 037 and
    /// DestroyBot1's runs Script 028.
    func testObjDeleteDeadRunsEachDeadObjectsDestroyHandlerInSlotOrder()
        throws
    {
        let session = try movingTargetSession()
        session.world.trainingMission.script026Count = 1
        session.world.trainingMission.script027Count = 1
        session.world.unghostObject(destroyBot1)
        // DestroyBot1 rides on FollowBot1.
        session.world.objects[destroyBot1]?.flags |= GameObject.attachedFlag
        session.world.objects[destroyBot1]?.attachUltimateHandle = followBot1
        for handle in [followBot1, destroyBot1] {
            session.world.objects[handle]?.flags |= GameObject.deadFlag
        }
        session.world.objDeleteDead(level: session.level)
        XCTAssertNil(session.world.objects[followBot1])
        XCTAssertNil(session.world.objects[destroyBot1])
        XCTAssertEqual(session.world.testTrainingMission?.script037Count, 1)
        XCTAssertNotNil(levelTimer(session, 11))
        XCTAssertEqual(session.world.testTrainingMission?.script028Count, 1)
        XCTAssertNotEqual(session.world.objects[destroyBot2]?.type, .dummy)
    }

    /// ObjDeleteDead (object.cpp:2004) sends a dead attached polygon
    /// object's ultimate attach parent EVT_CHILD_DIED, not EVT_DESTROY:
    /// FollowBot1 attached to DestroyBot1 dies, and DestroyBot1's destroy
    /// handler (Script 028) does not run.
    func testADeadAttachedObjectsParentHearsChildDied() throws {
        let session = try movingTargetSession()
        session.world.aObjGhostSet(0, destroyBot1)
        // Script 028 needs Script 027 (TrainingMission.cpp:2016).
        session.world.trainingMission.script027Count = 1
        session.world.objects[followBot1]?.flags |= GameObject.attachedFlag
        session.world.objects[followBot1]?.attachUltimateHandle = destroyBot1
        killNow(session, followBot1)
        _ = session.update(at: 0.1, input: .zero)
        XCTAssertNil(session.world.objects[followBot1])
        XCTAssertNotNil(session.world.objects[destroyBot1])
        XCTAssertEqual(session.world.testTrainingMission?.script028Count, 0)
    }

    /// Script 028 (TrainingMission.cpp:2016-2024): after Script 027,
    /// DestroyBot1's death unghosts DestroyBot2 and sends it along
    /// FollowLoop1.
    func testDestroyBot1DeathRunsScript028() throws {
        let session = try movingTargetSession()
        session.world.trainingMission.script027Count = 1
        killNow(session, destroyBot1)
        _ = session.update(at: 0.1, input: .zero)
        XCTAssertEqual(session.world.testTrainingMission?.script028Count, 1)
        let bot2 = try XCTUnwrap(session.world.objects[destroyBot2])
        XCTAssertNotEqual(bot2.type, .dummy)
        XCTAssertEqual(bot2.ai?.goals[3].type, AIGoal.followPathType)
        XCTAssertEqual(bot2.ai?.goals[3].flags, 8_392_960)
    }

    /// A destroy that is not a death (the level ending) runs no script
    /// (TrainingMission.cpp:2015).
    func testDestroyAtLevelEndRunsNoScript() throws {
        let session = try movingTargetSession()
        session.world.trainingMission.script027Count = 1
        session.world.osirisCallEvent(
            destroyBot1, .destroy(isDying: false), level: session.level
        )
        XCTAssertEqual(session.world.testTrainingMission?.script028Count, 0)
        XCTAssertEqual(session.world.objects[destroyBot2]?.type, .dummy)
    }

    /// Script 036 (TrainingMission.cpp:2039-2050) on DestroyBot2's death:
    /// level timer 12, FlashLight-2 lit to 50, PortalRoom4's portals
    /// opened, every control on; Script 029 (:1573-1582) then hides the
    /// enabled controls and plays proceed5.osf.
    func testDestroyBot2DeathRunsScript036ThenScript029() throws {
        // The gallery level, with its barrier room named PortalRoom4 as in
        // the retail level; FlashLight-2 is the gallery marker light.
        var gallery = makeTrainingRobotGuidebotLevel()
        let barrier = try XCTUnwrap(gallery.trainingGalleryBarrier)
        let barrierRoom = try XCTUnwrap(gallery.rooms.firstIndex {
            $0.sourceIndex == barrier.barrierRoomSourceIndex
        })
        gallery.rooms[barrierRoom].name = "PortalRoom4"
        let level = addingTrainingMissionScripting(
            gallery,
            messages: fixtureTrainingMessages + [
                .init(
                    name: "ExitManuveur",
                    text:
                        "Now go through the open doorway, and into the next room."
                ),
            ]
        )
        try level.validate()
        XCTAssertEqual(
            level.findObjectName("FlashLight-2").rawValue,
            barrier.markerLightObjectHandle
        )
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        XCTAssertEqual(session.level.findObjectName("DestroyBot2"), destroyBot2)
        session.world.hudShowControls = true
        killNow(session, destroyBot2)
        var timestamp = 0.1
        // Afterburner held on the death frame is filtered: its control is
        // off until Script 036 turns every control on.
        let deathFrame = session.update(
            at: timestamp, input: .init(afterburner: 1)
        )
        XCTAssertEqual(session.world.testTrainingMission?.script036Count, 1)
        XCTAssertEqual(session.afterburnerFuel, 5, accuracy: 1e-6)
        XCTAssertEqual(deathFrame.enabledPlayerControls, .all)
        XCTAssertTrue(deathFrame.showsEnabledPlayerControls)
        XCTAssertNotNil(levelTimer(session, 12))
        XCTAssertEqual(session.galleryMarkerLightDistance, 50)
        // Room numbers are source indices (osipf_FindRoomName).
        XCTAssertEqual(
            session.level.findRoomName("PortalRoom4"),
            barrier.barrierRoomSourceIndex
        )
        assertTrainingGalleryBarrier(
            level: session.runtimeLevel, rendersFaces: false
        )
        XCTAssertEqual(session.world.playerControllerBitflags, .all)
        // The next update drains it (5 to 4.9 in 0.1 s).
        timestamp += 0.1
        _ = session.update(at: timestamp, input: .init(afterburner: 1))
        XCTAssertEqual(session.afterburnerFuel, 4.9, accuracy: 1e-6)

        var log: [String] = []
        for _ in 0..<30
        where session.world.testTrainingMission?.script029Count == 0 {
            timestamp += 0.1
            log = presentationLog(session.update(at: timestamp, input: .zero))
        }
        XCTAssertEqual(session.world.testTrainingMission?.script029Count, 1)
        XCTAssertFalse(session.world.hudShowControls)
        XCTAssertEqual(
            log.filter { $0.hasPrefix("hud:") },
            [
                "hud:\(TrainingMissionScript.message(0, level: session.level))",
                "hud:\(TrainingMissionScript.message(26, level: session.level))",
            ]
        )
        XCTAssertTrue(log.contains("voice:proceed5.osf"))
        XCTAssertFalse(log.contains { $0.contains("Message Not Found") })
    }

    /// Scripts 047 and 048 (TrainingMission.cpp:2174-2200) count the
    /// first EVT_COLLIDE on InvulnPowerup2 and CloakPowerup2.
    func testPickupContactsRunScripts047And048Once() throws {
        let level = addingTrainingMissionScripting(
            makeTrainingCloakPickupLevel()
        )
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        for _ in 0..<2 {
            session.collidePlayer(with: "InvulnPowerup2")
        }
        XCTAssertEqual(session.world.testTrainingMission?.script047Count, 1)
        XCTAssertEqual(session.world.testTrainingMission?.script048Count, 0)
        session.collidePlayer(with: "CloakPowerup2")
        XCTAssertEqual(session.world.testTrainingMission?.script048Count, 1)
    }

    /// Scripts 043-046 (TrainingMission.cpp:2099-2170) and 051-055
    /// (:2213-2305) count the RAS bots and the last bots as they die.
    func testRASBotAndLastBotDeathsRunTheirCounters() throws {
        let level = addingTrainingMissionScripting(
            makeTrainingFinalBotsCompletionLevel()
        )
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        let counters: [(String, WritableKeyPath<TrainingMissionState, Int>)] = [
            ("RASBot1", \.script043Count), ("RASBot2", \.script044Count),
            ("RASBot3", \.script045Count), ("RASBot4", \.script046Count),
            ("LastBot1", \.script051Count), ("LastBot2", \.script052Count),
            ("LastBot3", \.script053Count), ("LastBot4", \.script054Count),
            ("LastBot5", \.script055Count),
        ]
        var timestamp = 0.0
        for (name, counter) in counters {
            let handle = level.findObjectName(name)
            XCTAssertNotEqual(handle, .none, name)
            XCTAssertEqual(session.world.trainingMission[keyPath: counter], 0)
            killNow(session, handle)
            timestamp += 0.1
            _ = session.update(at: timestamp, input: .zero)
            XCTAssertEqual(
                session.world.trainingMission[keyPath: counter], 1, name
            )
        }
    }

    // MARK: - Helpers

    /// The moving-target lesson with the Training module: FollowBot1,
    /// DestroyBot1, and DestroyBot2 (ghosts until Scripts 027 and 028).
    private func movingTargetSession() throws -> GameSession {
        let level = addingTrainingMissionScripting(
            makeTrainingMovingTargetHandoffLevel()
        )
        try level.validate()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        XCTAssertNotNil(session.world.testTrainingMission)
        for handle in [destroyBot1, destroyBot2] {
            session.world.ghostObject(handle)
        }
        return session
    }

    /// KillObject with no delay (a death type of DF_FIREBALL and
    /// DF_BREAKS_APART): the object is dead now, and ObjDeleteDead sends
    /// EVT_DESTROY at the end of the next object frame.
    private func killNow(_ session: GameSession, _ handle: ObjectHandle) {
        session.world.killObject(
            handle, killer: session.world.testPlayerObject.handle, damage: 10,
            deathFlags: DeathFlags.fireball | DeathFlags.breaksApart,
            delayTime: 0, level: session.level
        )
        XCTAssertNotEqual(
            (session.world.objects[handle]?.flags ?? 0) & GameObject.deadFlag, 0
        )
    }

    private func levelTimer(_ session: GameSession, _ id: Int32) -> OsirisTimer? {
        session.world.osirisTimers.entries.first {
            $0.isUsed && $0.owner == .level && $0.id == id
        }
    }

    /// A real Concussion missile kills DestroyBot2 through the generic
    /// weapon, damage, and death path; its EVT_DESTROY runs Script 036
    /// (TrainingMission.cpp:2039-2050), which opens the gallery portals and
    /// their reciprocals (aPortalRenderSet, DallasFuncs.cpp:1098) and lights
    /// FlashLight-2, and level timer 12 then runs Script 029.
    func testConcussionKillOfDestroyBot2RunsItsScriptChain() throws {
        var base = try makePlayerConcussionLevel()
        let barrier = try XCTUnwrap(base.trainingGalleryBarrier)
        let barrierRoom = try XCTUnwrap(base.rooms.firstIndex {
            $0.sourceIndex == barrier.barrierRoomSourceIndex
        })
        base.rooms[barrierRoom].name = "PortalRoom4"
        let player = try XCTUnwrap(base.objects.first {
            $0.handle == base.defaultPlayerBinding?.objectHandle
        })
        let robotIndex = try XCTUnwrap(base.objects.firstIndex {
            $0.handle == 4_112
        })
        base.objects[robotIndex].position = player.position
            + player.orientation.forward * 15
        base.objects[robotIndex].location = player.location
        let level = addingTrainingMissionScripting(
            base,
            messages: fixtureTrainingMessages + [
                .init(
                    name: "ExitManuveur",
                    text:
                        "Now go through the open doorway, and into the next room."
                ),
            ]
        )
        let simulation = GameSession(
            level: level, presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        simulation.world.playerWeapons[PlayerWeaponState.secondary].index =
            PlayerWeaponState.concussionIndex
        // Script 000 turned the controls off; the lessons turned them all
        // back on. Script 028 unghosted DestroyBot2; one direct hit
        // (6 x 1.5) kills it.
        simulation.world.playerControllerBitflags = .all
        simulation.world.unghostObject(ObjectHandle(4_112))
        simulation.world.objects[ObjectHandle(4_112)]?.shields = 5

        var time: Double = 0
        while simulation.world.objects[ObjectHandle(4_112)] != nil, time < 10 {
            time += 0.1
            _ = simulation.update(
                at: time, input: .init(firesSecondaryWeapon: true)
            )
        }
        XCTAssertNil(simulation.world.objects[ObjectHandle(4_112)])
        XCTAssertEqual(simulation.world.playerScore, 200)
        XCTAssertEqual(simulation.world.testTrainingMission?.script036Count, 1)
        XCTAssertEqual(simulation.galleryMarkerLightDistance, 50)
        for portalIndex in barrier.orderedPortalIndices {
            XCTAssertEqual(
                simulation.world.rooms[barrierRoom].portalFlags[portalIndex]
                    & LevelPortal.renderFacesFlag,
                0
            )
            let portal = level.rooms[barrierRoom].portals[portalIndex]
            let connected = try XCTUnwrap(level.rooms.firstIndex {
                $0.sourceIndex == portal.connectedRoom
            })
            XCTAssertEqual(
                simulation.world.rooms[connected]
                    .portalFlags[portal.connectedPortal]
                    & LevelPortal.renderFacesFlag,
                0
            )
        }
        for _ in 0..<30 {
            time += 0.1
            _ = simulation.update(at: time, input: .zero)
        }
        XCTAssertEqual(simulation.world.testTrainingMission?.script029Count, 1)
        XCTAssertNoThrow(try simulation.world.validate(against: level))
    }

    /// One world from the maneuver lesson to DestroyBot2's death, with no
    /// injected event: Script 021's contact, level timer 4 (Scripts 022, 024,
    /// 023), timer 7 expiring through ordinary updates (Scripts 025, 026),
    /// then real two-bolt volleys at FollowBot1 (2 x 7.5 x 1.5 = 22.5 each,
    /// damage.cpp:1311), DestroyBot1, and DestroyBot2 (Scripts 037, 027,
    /// 028, 036). The Script 036 frame goes to the view: its enabled
    /// controls name Afterburner, and the next update drains the fuel.
    @MainActor
    func testManeuverLessonToDestroyBot2ThroughOrdinaryUpdatesAndRealVolleys() throws {
        func textField(
            accessibilityLabel: String,
            in view: RevivalGameplayView
        ) throws -> NSTextField {
            try XCTUnwrap(
                view.subviews.compactMap { $0 as? NSTextField }.first {
                    $0.accessibilityLabel() == accessibilityLabel
                }
            )
        }

        func keyEvent(
            type: NSEvent.EventType,
            modifiers: NSEvent.ModifierFlags,
            timestamp: TimeInterval,
            characters: String,
            keyCode: UInt16
        ) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(
                with: type,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: timestamp,
                windowNumber: 0,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: characters,
                isARepeat: false,
                keyCode: keyCode
            ))
        }

        func continuationObject(
            _ simulation: GameSession
        ) throws -> [String: Any] {
            try XCTUnwrap(
                testWorldObject(simulation.world)
            )
        }

        func aiming(
            _ source: GameSession,
            at targetHandle: UInt32,
            timestamp: Double,
            level: Level
        ) throws -> GameSession {
            let target = try XCTUnwrap(
                source.runtimeLevel.objects.first { $0.handle == targetHandle }
            )
            var object = try continuationObject(source)
            object["playerLocation"] = ["room": ["_0": 37]]
            object["playerPosition"] = [
                "x": target.position.x - target.orientation.forward.x * 10,
                "y": target.position.y - target.orientation.forward.y * 10,
                "z": target.position.z - target.orientation.forward.z * 10,
            ]
            object["playerOrientation"] = [
                "right": [
                    "x": target.orientation.right.x,
                    "y": target.orientation.right.y,
                    "z": target.orientation.right.z,
                ],
                "up": [
                    "x": target.orientation.up.x,
                    "y": target.orientation.up.y,
                    "z": target.orientation.up.z,
                ],
                "forward": [
                    "x": target.orientation.forward.x,
                    "y": target.orientation.forward.y,
                    "z": target.orientation.forward.z,
                ],
            ]
            object["velocity"] = ["x": 0, "y": 0, "z": 0]
            object["angularVelocity"] = ["x": 0, "y": 0, "z": 0]
            return try GameSession(
                level: level,
                world: (decodeTestWorld(object)).rebased(onto: level),
                resumedAtTimestamp: timestamp
            )
        }

        // FollowBot1, DestroyBot1, and DestroyBot2 of the moving-target
        // lesson, and the player's laser (WeaponFixtures.swift).
        let followBot: UInt32 = 8_200
        let destroyBot1: UInt32 = 4_113
        let destroyBot2: UInt32 = 4_112
        var level = makeTrainingMovingTargetHandoffLevel()
        let playerIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        let maneuver = try XCTUnwrap(level.objects.first {
            $0.handle == level.findObjectName("ManuverRoomCenter").rawValue
        })
        level.objects[playerIndex].location = maneuver.location
        level.objects[playerIndex].position = maneuver.position
        level.objects[playerIndex].orientation = maneuver.orientation

        let roomIndex = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 37 }
        )
        let originalRoom = level.rooms[roomIndex]
        let containment = makeSourceContainmentRoom(
            center: maneuver.position,
            texture: level.surfacePhysics[0].texture,
            sourceIndex: 37,
            halfExtent: 500
        )
        var faces = containment.faces
        let portals = originalRoom.portals.enumerated().map {
            portalIndex, portal in
            let face = faces[portalIndex]
            faces[portalIndex] = .init(
                corners: face.corners,
                flags: face.flags,
                portalIndex: portalIndex,
                texture: face.texture,
                lightmapInfoIndex: face.lightmapInfoIndex,
                allowsLightCorona: face.allowsLightCorona,
                lightMultiple: face.lightMultiple,
                special: face.special
            )
            return LevelPortal(
                flags: portal.flags,
                faceIndex: portalIndex,
                connectedRoom: portal.connectedRoom,
                connectedPortal: portal.connectedPortal,
                boundaryNodeIndex: portal.boundaryNodeIndex,
                pathPoint: portal.pathPoint,
                combineMaster: portal.combineMaster
            )
        }
        level.rooms[roomIndex] = replacing(
            originalRoom,
            vertices: containment.vertices,
            faces: faces,
            portals: portals
        )

        let galleryRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 2 }
        )
        for portalIndex in [1, 0] {
            level.rooms[galleryRoomIndex].portals[portalIndex].flags |= 1
            let portal = level.rooms[galleryRoomIndex].portals[portalIndex]
            let reciprocalRoomIndex = try XCTUnwrap(
                level.rooms.firstIndex {
                    $0.sourceIndex == portal.connectedRoom
                }
            )
            level.rooms[reciprocalRoomIndex]
                .portals[portal.connectedPortal].flags |= 1
        }
        let seed = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        var preScript021 = try continuationObject(seed)
        for name in ["script033Count", "script016Count", "script017Count",
                     "script020Count"] {
            try setTrainingCounter(&preScript021, name, 1)
        }
        preScript021["playerControllerBitflags"] = 63
        try deferringOsirisTimers(&preScript021, to: 1_000)
        var simulation = try GameSession(
            level: level,
            world: (decodeTestWorld(preScript021)).rebased(onto: level),
            resumedAtTimestamp: 0
        )

        // The player flies into ManuverRoomCenter (Script 021's
        // EVT_COLLIDE, TrainingMission.cpp:1943).
        var timestamp = 0.1
        var frame = simulation.touch("ManuverRoomCenter", at: timestamp)
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script021Count,
            1
        )
        timestamp = 20.1
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp = 20.2
        frame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script022Count,
            1
        )
        timestamp = 32.2
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp = 32.3
        frame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script024Count,
            1
        )
        timestamp = 47.3
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp = 47.4
        frame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script023Count,
            1
        )

        for _ in 0..<210 where simulation.world.testTrainingMission?.script026Count == 0 {
            simulation = try aiming(
                simulation,
                at: followBot,
                timestamp: timestamp,
                level: level
            )
            timestamp += 0.1
            frame = simulation.update(at: timestamp, input: .zero)
        }
        XCTAssertGreaterThan(
            try XCTUnwrap(simulation.world.testTrainingMission?.script025Count),
            0
        )
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script026Count,
            1
        )
        XCTAssertEqual(
            frame.enabledPlayerControls.rawValue,
            4_032 | 12_288
        )
        XCTAssertFalse(
            frame.enabledPlayerControls.contains(.afterburner)
        )

        // Each two-bolt volley does 2 x 7.5 x Diff_robot_damage[Rookie]
        // (1.5) = 22.5 (damage.cpp:1311), so a 55-shield robot dies in the
        // third volley.
        func shoot(
            _ target: UInt32,
            volleys: Int,
            input: InputSnapshot = .init(firesPrimaryWeapon: true)
        ) throws {
            for _ in 0..<volleys {
                simulation = try aiming(
                    simulation,
                    at: target,
                    timestamp: timestamp,
                    level: level
                )
                timestamp += 0.25
                frame = simulation.update(at: timestamp, input: input)
            }
        }
        try shoot(followBot, volleys: 2)
        XCTAssertEqual(
            simulation.world.objects[ObjectHandle(followBot)]?.shields ?? 0,
            10,
            accuracy: 0.001
        )
        try shoot(followBot, volleys: 1)
        XCTAssertNil(
            simulation.world.objects[ObjectHandle(followBot)]
        )
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script037Count,
            1
        )

        for _ in 0..<12 where activeFollowPath(
            simulation.world,
            destroyBot1
        ) == nil {
            timestamp += 0.25
            frame = simulation.update(at: timestamp, input: .zero)
        }
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script027Count,
            1
        )
        XCTAssertEqual(
            activeFollowPath(simulation.world, destroyBot1),
            0
        )

        // The moving bots can be out of range of the first volley: the
        // bolts fly on and hit later, so shoot until the bot dies.
        for _ in 0..<8
        where simulation.world.objects[ObjectHandle(destroyBot1)] != nil {
            try shoot(destroyBot1, volleys: 1)
        }
        XCTAssertNil(
            simulation.world.objects[ObjectHandle(destroyBot1)]
        )
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script028Count,
            1
        )
        XCTAssertEqual(
            activeFollowPath(simulation.world, destroyBot2),
            0
        )

        // Afterburner is held on every frame, and filtered while its
        // control is off, up to the frame that kills DestroyBot2.
        // DestroyBot2 avoids its friends (AIF_AUTO_AVOID_FRIENDS, ai_move
        // AImain.cpp:4670), so its path wanders and some volleys miss.
        var script036Frame = frame
        for _ in 0..<80
        where simulation.world.objects[ObjectHandle(destroyBot2)] != nil {
            simulation = try aiming(
                simulation,
                at: destroyBot2,
                timestamp: timestamp,
                level: level
            )
            timestamp += 0.1
            script036Frame = simulation.update(
                at: timestamp,
                input: .init(afterburner: 1, firesPrimaryWeapon: true)
            )
        }
        XCTAssertNil(
            simulation.world.objects[ObjectHandle(destroyBot2)]
        )
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script036Count,
            1
        )
        XCTAssertEqual(
            script036Frame.enabledPlayerControls,
            .all
        )
        XCTAssertTrue(
            script036Frame.showsEnabledPlayerControls
        )
        XCTAssertEqual(
            simulation.afterburnerFuel,
            5,
            accuracy: 0.000_001
        )

        var playerInput = PlayerInputState(rampDuration: 0)
        let view = RevivalGameplayView(
            frame: NSRect(x: 0, y: 0, width: 1_280, height: 720),
            device: nil
        )
        view.heldInputChanged = { playerInput.setHeld($0) }
        view.setGameplayActive(true)
        try view.presentGameplayFrame(
            frame: script036Frame,
            voiceClips: simulation.level.voiceClips
        )
        let afterburner = try textField(
            accessibilityLabel: "Afterburner",
            in: view
        )
        let controlSummary = try textField(
            accessibilityLabel: "Enabled controls",
            in: view
        )
        XCTAssertEqual(
            afterburner.stringValue,
            "Afterburner: 100%"
        )
        XCTAssertTrue(
            controlSummary.stringValue.contains("Afterburner")
        )

        view.keyDown(with: try keyEvent(
            type: .keyDown,
            modifiers: [],
            timestamp: timestamp + 0.01,
            characters: "w",
            keyCode: 13
        ))
        view.flagsChanged(with: try keyEvent(
            type: .flagsChanged,
            modifiers: [.shift],
            timestamp: timestamp + 0.02,
            characters: "",
            keyCode: 56
        ))
        timestamp += 0.1
        let drainInput = playerInput.snapshot(frameDuration: 0.1)
        XCTAssertEqual(
            drainInput.forward,
            1
        )
        XCTAssertEqual(
            drainInput.afterburner,
            1
        )
        let drainFrame = simulation.update(
            at: timestamp,
            input: drainInput
        )
        XCTAssertEqual(
            simulation.afterburnerFuel,
            4.9,
            accuracy: 0.000_001
        )
        try view.presentGameplayFrame(
            frame: drainFrame,
            voiceClips: simulation.level.voiceClips
        )
        XCTAssertEqual(
            afterburner.stringValue,
            "Afterburner: 98%"
        )

        view.flagsChanged(with: try keyEvent(
            type: .flagsChanged,
            modifiers: [],
            timestamp: timestamp + 0.01,
            characters: "",
            keyCode: 56
        ))
        timestamp += 0.1
        let rechargeFrame = simulation.update(
            at: timestamp,
            input: playerInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(
            simulation.afterburnerFuel,
            5,
            accuracy: 0.000_001
        )
        try view.presentGameplayFrame(
            frame: rechargeFrame,
            voiceClips: simulation.level.voiceClips
        )
        XCTAssertEqual(
            afterburner.stringValue,
            "Afterburner: 100%"
        )
    }
}
