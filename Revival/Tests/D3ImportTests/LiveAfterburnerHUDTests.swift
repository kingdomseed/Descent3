import AppKit
import XCTest

extension WorldRenderingTests {
    @MainActor
    func testNormalShiftUpdatesTheLiveTextAfterburnerHUD() throws {
        func afterburnerItem(in view: RevivalGameplayView) throws -> NSTextField {
            try XCTUnwrap(
                view.subviews.compactMap { $0 as? NSTextField }.first {
                    $0.accessibilityIdentifier() == "Live Afterburner HUD"
                },
                "ordinary Training play must expose one identified Afterburner item"
            )
        }

        func frameFuel(_ frame: PlayerSimulationFrame) throws -> Float {
            try XCTUnwrap(
                Mirror(reflecting: frame).children.first {
                    $0.label == "afterburnerFuel"
                }?.value as? Float,
                "the final frame must carry the sole post-update Afterburner fuel"
            )
        }

        func shiftEvent(
            modifiers: NSEvent.ModifierFlags,
            timestamp: TimeInterval
        ) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(
                with: .flagsChanged,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: timestamp,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: 56
            ))
        }

        func restoreControlsThroughNormalTraining(
            in simulation: GameSession,
            startingAt timestamp: inout Double
        ) -> PlayerSimulationFrame {
            var frame = simulation.update(at: timestamp, input: .zero)
            for fires in [true, false, true, false, true, false, true] {
                timestamp += fires ? 0.01 : 0.25
                frame = simulation.update(
                    at: timestamp,
                    input: .init(firesPrimaryWeapon: fires)
                )
            }
            return frame
        }

        var level = makeTrainingRobotGuidebotLevel()
        let player = try XCTUnwrap(level.objects.first { $0.handle == 2_048 })
        let robotIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 4_112 }
        )
        level.objects[robotIndex].position = Vector3(
            x: player.position.x + player.orientation.forward.x * 20,
            y: player.position.y + player.orientation.forward.y * 20,
            z: player.position.z + player.orientation.forward.z * 20
        )
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        var timestamp = 0.1
        let controlsRestored = restoreControlsThroughNormalTraining(
            in: simulation,
            startingAt: &timestamp
        )
        XCTAssertEqual(controlsRestored.enabledPlayerControls, .all)
        XCTAssertFalse(simulation.runtimeLevel.objects.contains {
            $0.handle == 4_112
        })

        timestamp += 0.1
        let freshFrame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(simulation.afterburnerFuel, 5)

        var playerInput = PlayerInputState(rampDuration: 0)
        let view = RevivalGameplayView(
            frame: NSRect(x: 0, y: 0, width: 1_280, height: 720),
            device: nil
        )
        view.heldInputChanged = { playerInput.setHeld($0) }
        view.setGameplayActive(true)
        view.flagsChanged(with: try shiftEvent(
            modifiers: [.shift],
            timestamp: timestamp + 0.01
        ))
        timestamp += 0.1
        let shiftedFrame = simulation.update(
            at: timestamp,
            input: playerInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(simulation.afterburnerFuel, 4.9, accuracy: 0.000_001)

        view.flagsChanged(with: try shiftEvent(
            modifiers: [],
            timestamp: timestamp + 0.01
        ))
        timestamp += 0.1
        let rechargedFrame = simulation.update(
            at: timestamp,
            input: playerInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(simulation.afterburnerFuel, 5, accuracy: 0.000_001)
        XCTAssertEqual(simulation.energy, 99.3, accuracy: 0.000_01)

        let truncationSimulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        var truncationTimestamp = 0.1
        let truncationControls = restoreControlsThroughNormalTraining(
            in: truncationSimulation,
            startingAt: &truncationTimestamp
        )
        XCTAssertEqual(truncationControls.enabledPlayerControls, .all)
        truncationTimestamp += 0.1
        _ = truncationSimulation.update(
            at: truncationTimestamp,
            input: .zero
        )
        truncationTimestamp += 0.06
        _ = truncationSimulation.update(
            at: truncationTimestamp,
            input: .zero
        )
        var truncationInput = PlayerInputState(rampDuration: 0)
        let truncationView = RevivalGameplayView(frame: view.frame, device: nil)
        truncationView.heldInputChanged = { truncationInput.setHeld($0) }
        truncationView.setGameplayActive(true)
        truncationView.flagsChanged(with: try shiftEvent(
            modifiers: [.shift],
            timestamp: truncationTimestamp + 0.01
        ))
        truncationTimestamp += 0.1
        let truncationFrame = truncationSimulation.update(
            at: truncationTimestamp,
            input: truncationInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(
            truncationSimulation.afterburnerFuel,
            4.94,
            accuracy: 0.000_001
        )

        simulation.afterburnerFuel = 1.5
        simulation.energy = 5
        timestamp += 0.1
        let warningFrame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(simulation.afterburnerFuel, 1.5)

        timestamp += 0.1
        let rearFrame = simulation.update(
            at: timestamp,
            input: .init(rearViewPressed: true, rearViewHeld: true)
        )
        XCTAssertTrue(rearFrame.rearViewIsActive)

        // Script 057 ends the level (TrainingMission.cpp:2309).
        let finalFrame = try trainingLevelEndFrame().frame
        XCTAssertNotNil(finalFrame.levelEnd)

        let project = try makeProject(importedBase: level)
        let editorSimulation = project.makePlayerPlaySession()
            .makePlayerSimulation(presentationReadyTimestamp: 0)
        _ = editorSimulation.update(at: 0.1, input: .zero)
        var editorInput = PlayerInputState(rampDuration: 0)
        let editorView = RevivalGameplayView(frame: view.frame, device: nil)
        editorView.heldInputChanged = { editorInput.setHeld($0) }
        editorView.setGameplayActive(true)
        editorView.flagsChanged(with: try shiftEvent(
            modifiers: [.shift],
            timestamp: 0.11
        ))
        let editorFrame = editorSimulation.update(
            at: 0.2,
            input: editorInput.snapshot(frameDuration: 0.1)
        )
        XCTAssertEqual(
            editorSimulation.afterburnerFuel,
            4.9,
            accuracy: 0.000_001
        )

        try view.presentGameplayFrame(frame: freshFrame, voiceClips: [])
        view.layoutSubtreeIfNeeded()
        let item = try afterburnerItem(in: view)
        XCTAssertEqual(item.stringValue, "Afterburner: 100%")
        XCTAssertEqual(item.accessibilityLabel(), "Afterburner")
        XCTAssertFalse(item.isHidden)
        XCTAssertGreaterThanOrEqual(item.frame.minX, 160 + 24)
        XCTAssertLessThanOrEqual(item.frame.maxX, 1_120 - 24)

        XCTAssertEqual(try frameFuel(shiftedFrame), 4.9, accuracy: 0.000_001)
        try view.presentGameplayFrame(frame: shiftedFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 98%")
        XCTAssertEqual(item.accessibilityLabel(), "Afterburner")

        try view.presentGameplayFrame(frame: rechargedFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 100%")

        try view.presentGameplayFrame(frame: truncationFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 98%")

        try view.presentGameplayFrame(frame: warningFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 30%")
        XCTAssertEqual(
            item.accessibilityLabel(),
            "Afterburner, low fuel warning"
        )
        XCTAssertEqual(item.textColor, .systemRed)
        XCTAssertEqual(
            item.font,
            .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        )

        try view.presentGameplayFrame(frame: rearFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        try view.presentGameplayFrame(frame: warningFrame, voiceClips: [])
        XCTAssertFalse(item.isHidden)
        try view.presentGameplayFrame(frame: finalFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        try editorView.presentGameplayFrame(
            frame: editorFrame,
            voiceClips: []
        )
        let editorItem = try afterburnerItem(in: editorView)
        XCTAssertEqual(editorItem.stringValue, "Afterburner: 98%")
    }

    @MainActor
    func testNormalTrainingScript036UnlocksAfterburnerOnNextUpdate() throws {
        func textField(
            accessibilityLabel: String,
            in view: RevivalGameplayView
        ) throws -> NSTextField {
            try XCTUnwrap(
                view.subviews.compactMap { $0 as? NSTextField }.first {
                    $0.accessibilityLabel() == accessibilityLabel
                },
                "Script 036 must publish the \(accessibilityLabel) field"
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
                source.runtimeLevel.objects.first { $0.handle == targetHandle },
                "the current real projectile target must remain present"
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
            1,
            "released Script 021 must start the normal maneuver lesson"
        )
        timestamp = 20.1
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp = 20.2
        frame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script022Count,
            1,
            "released Script 022 must follow Script 021"
        )
        timestamp = 32.2
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp = 32.3
        frame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script024Count,
            1,
            "released Script 024 must follow Script 022"
        )
        timestamp = 47.3
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp = 47.4
        frame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script023Count,
            1,
            "released Script 023 must follow Script 024"
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
            0,
            "released Script 025 must run during the normal follow interval"
        )
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script026Count,
            1,
            "released timer 7 must reach Script 026 through normal updates"
        )
        XCTAssertEqual(
            frame.enabledPlayerControls.rawValue,
            4_032 | 12_288,
            "Script 026 must enable only its released rotation and weapon masks"
        )
        XCTAssertFalse(
            frame.enabledPlayerControls.contains(.afterburner),
            "Script 026 weapon mask 12_288 must not enable Afterburner bit 16_384"
        )
        print(
            "AFTERBURNER_STAGE Script026 controls=\(frame.enabledPlayerControls.rawValue) afterburner=false"
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
            accuracy: 0.001,
            "FollowBot1 must take 22.5 shields per real two-bolt volley"
        )
        try shoot(followBot, volleys: 1)
        XCTAssertNil(
            simulation.world.objects[ObjectHandle(followBot)],
            "FollowBot1 must die in the third real volley"
        )
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script037Count,
            1,
            "FollowBot1's EVT_DESTROY must start timer 11 through Script 037"
        )
        print("AFTERBURNER_STAGE FollowBot1 death Script037=1")

        for _ in 0..<12 where activeFollowPath(
            simulation.world,
            destroyBot1
        ) == nil {
            timestamp += 0.25
            frame = simulation.update(at: timestamp, input: .zero)
        }
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script027Count,
            1,
            "timer 11 must reach Script 027 through ordinary updates"
        )
        XCTAssertEqual(
            activeFollowPath(simulation.world, destroyBot1),
            0,
            "Script 027 must give DestroyBot1 its follow-path goal"
        )
        print("AFTERBURNER_STAGE Script027 timer11 target=DestroyBot1")

        // The moving bots can be out of range of the first volley: the
        // bolts fly on and hit later, so shoot until the bot dies.
        for _ in 0..<8
        where simulation.world.objects[ObjectHandle(destroyBot1)] != nil {
            try shoot(destroyBot1, volleys: 1)
        }
        XCTAssertNil(
            simulation.world.objects[ObjectHandle(destroyBot1)],
            "DestroyBot1 must die to real volleys"
        )
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script028Count,
            1,
            "DestroyBot1's EVT_DESTROY must execute Script 028"
        )
        XCTAssertEqual(
            activeFollowPath(simulation.world, destroyBot2),
            0,
            "Script 028 must give DestroyBot2 its follow-path goal"
        )
        print("AFTERBURNER_STAGE DestroyBot1 death Script028=1")

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
            simulation.world.objects[ObjectHandle(destroyBot2)],
            "DestroyBot2's real death must remove the target"
        )
        XCTAssertEqual(
            simulation.world.testTrainingMission?.script036Count,
            1,
            "DestroyBot2's EVT_DESTROY must execute Script 036"
        )
        XCTAssertEqual(
            script036Frame.enabledPlayerControls,
            .all,
            "Script 036 must publish all controls on the real DestroyBot2 death frame"
        )
        XCTAssertTrue(
            script036Frame.showsEnabledPlayerControls,
            "Script 036 must show the enabled-control summary on the death frame"
        )
        XCTAssertEqual(
            simulation.afterburnerFuel,
            5,
            accuracy: 0.000_001,
            "death-frame Afterburner input must be filtered before Script 036 restores controls"
        )
        print(
            "AFTERBURNER_STAGE DestroyBot2 death Script036 controls=all fuel=5.0"
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
            "Afterburner: 100%",
            "Script 036 death frame must show the live full-fuel HUD"
        )
        XCTAssertTrue(
            controlSummary.stringValue.contains("Afterburner"),
            "Script 036 enabled-control summary must name Afterburner"
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
            1,
            "the first post-Script-036 update must keep Forward held"
        )
        XCTAssertEqual(
            drainInput.afterburner,
            1,
            "the first post-Script-036 update must receive real AppKit Shift"
        )
        let drainFrame = simulation.update(
            at: timestamp,
            input: drainInput
        )
        XCTAssertEqual(
            simulation.afterburnerFuel,
            4.9,
            accuracy: 0.000_001,
            "the first normal update after Script 036 must drain authoritative fuel 5.0 to 4.9"
        )
        try view.presentGameplayFrame(
            frame: drainFrame,
            voiceClips: simulation.level.voiceClips
        )
        XCTAssertEqual(
            afterburner.stringValue,
            "Afterburner: 98%",
            "the first normal update after Script 036 must show live HUD 100% to 98%"
        )
        print("AFTERBURNER_STAGE fuel drain authoritative=4.9 hud=98%")

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
            accuracy: 0.000_001,
            "releasing AppKit Shift must recharge authoritative fuel"
        )
        try view.presentGameplayFrame(
            frame: rechargeFrame,
            voiceClips: simulation.level.voiceClips
        )
        XCTAssertEqual(
            afterburner.stringValue,
            "Afterburner: 100%",
            "releasing AppKit Shift must restore the live HUD to 100%"
        )
    }
}
