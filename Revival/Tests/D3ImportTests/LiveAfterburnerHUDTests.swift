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
            in simulation: PlayerSimulation,
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
        let simulation = PlayerSimulation(
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
        XCTAssertFalse(simulation.level.objects.contains {
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

        let truncationSimulation = PlayerSimulation(
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

        let finalLevel = makeTrainingFinalGoalLevel()
        let finalChain = try XCTUnwrap(finalLevel.trainingFinalGoalChain)
        let goal = try XCTUnwrap(finalLevel.objects.first {
            $0.handle == finalChain.goalObjectHandle
        })
        let initialFinalSimulation = PlayerSimulation(
            level: finalLevel,
            presentationReadyTimestamp: 0
        )
        initialFinalSimulation.destroyTrainingRobot(handle: 4_112)
        initialFinalSimulation.destroyTrainingRASBot1(handle: 2_074)
        initialFinalSimulation.destroyTrainingRASBot2(handle: 2_075)
        initialFinalSimulation.destroyTrainingRASBot3(handle: 2_077)
        initialFinalSimulation.destroyTrainingRASBot4(handle: 2_078)
        initialFinalSimulation.destroyTrainingLastBot1(handle: 4_127)
        initialFinalSimulation.destroyTrainingLastBot2(handle: 2_080)
        initialFinalSimulation.destroyTrainingLastBot3(handle: 2_081)
        initialFinalSimulation.destroyTrainingLastBot4(handle: 2_082)
        initialFinalSimulation.destroyTrainingLastBot5(handle: 2_083)
        _ = initialFinalSimulation.update(at: 0.1, input: .zero)
        var ready = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    initialFinalSimulation.continuation
                )
            ) as? [String: Any]
        )
        ready["playerLocation"] = [
            "room": ["_0": finalChain.goalRoomSourceIndex],
        ]
        ready["playerPosition"] = [
            "x": goal.position.x,
            "y": goal.position.y,
            "z": goal.position.z,
        ]
        let finalSimulation = try PlayerSimulation(
            level: finalLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: ready)
            ),
            resumedAtTimestamp: 0
        )
        let finalFrame = finalSimulation.update(at: 0.2, input: .zero)
        XCTAssertNotNil(finalFrame.trainingFinalGoal)

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

        try view.presentTrainingOpening(frame: freshFrame, voiceClips: [])
        view.layoutSubtreeIfNeeded()
        let item = try afterburnerItem(in: view)
        XCTAssertEqual(item.stringValue, "Afterburner: 100%")
        XCTAssertEqual(item.accessibilityLabel(), "Afterburner")
        XCTAssertFalse(item.isHidden)
        XCTAssertGreaterThanOrEqual(item.frame.minX, 160 + 24)
        XCTAssertLessThanOrEqual(item.frame.maxX, 1_120 - 24)

        XCTAssertEqual(try frameFuel(shiftedFrame), 4.9, accuracy: 0.000_001)
        try view.presentTrainingOpening(frame: shiftedFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 98%")
        XCTAssertEqual(item.accessibilityLabel(), "Afterburner")

        try view.presentTrainingOpening(frame: rechargedFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 100%")

        try view.presentTrainingOpening(frame: truncationFrame, voiceClips: [])
        XCTAssertEqual(item.stringValue, "Afterburner: 98%")

        try view.presentTrainingOpening(frame: warningFrame, voiceClips: [])
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

        try view.presentTrainingOpening(frame: rearFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        try view.presentTrainingOpening(frame: warningFrame, voiceClips: [])
        XCTAssertFalse(item.isHidden)
        try view.presentTrainingOpening(frame: finalFrame, voiceClips: [])
        XCTAssertTrue(item.isHidden)

        try editorView.presentTrainingOpening(
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
            _ simulation: PlayerSimulation
        ) throws -> [String: Any] {
            try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(simulation.continuation)
                ) as? [String: Any]
            )
        }

        func aiming(
            _ source: PlayerSimulation,
            at targetHandle: UInt32,
            timestamp: Double,
            level: Level
        ) throws -> PlayerSimulation {
            let target = try XCTUnwrap(
                source.level.objects.first { $0.handle == targetHandle },
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
            return try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(withJSONObject: object)
                ),
                resumedAtTimestamp: timestamp
            )
        }

        func destructionState(
            _ simulation: PlayerSimulation
        ) throws -> [String: Any] {
            let object = try continuationObject(simulation)
            let maneuver = try XCTUnwrap(
                object["trainingManeuverFollowState"] as? [String: Any]
            )
            return try XCTUnwrap(
                maneuver["destruction"] as? [String: Any]
            )
        }

        var level = makeTrainingMovingTargetHandoffLevel()
        let lesson = try XCTUnwrap(level.trainingDodgeAttempt?.maneuverFollow)
        let handoff = try XCTUnwrap(lesson.destructionHandoff)
        level = replacing(
            level,
            trainingRobotGuidebotChain: .init(
                destroyRobotObjectHandle: handoff.destroyBot2ObjectHandle,
                guidebotObjectHandle: 12_288,
                destroyRobotRoomSourceIndex: 37,
                destroyRobotFlags: 5_121,
                destructionDelay: 2,
                destructionMessage: "Excellent!",
                exitInstruction:
                    "Now go through the open doorway, and into the next room.",
                destructionVoiceSourceName: "proceed5.osf",
                deployedGuidebotObjectType: 2,
                deployedGuidebotMessage: "",
                deployedGuidebotVoiceSourceName: "",
                combat: .stockTraining,
                guidebot: .stockTraining
            )
        )

        let playerIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        let maneuver = try XCTUnwrap(level.objects.first {
            $0.handle == lesson.maneuverObjectHandle
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
        level = replacing(
            level,
            trainingGalleryBarrier: .init(
                triggerName: "Portal2",
                triggerRoomSourceIndex: 37,
                triggerFaceIndex: 0,
                barrierRoomSourceIndex: 2,
                orderedPortalIndices: [1, 0],
                markerLightObjectHandle: 6_163,
                openMarkerLightDistance: 50,
                successMessage: "Excellent!",
                guidebotInstruction: "",
                voiceSourceName: ""
            )
        )

        let seed = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        var preScript021 = try continuationObject(seed)
        var dodgeState = try XCTUnwrap(
            preScript021["trainingDodgeAttemptState"] as? [String: Any]
        )
        dodgeState["script033Count"] = 1
        dodgeState["script016Count"] = 1
        dodgeState["script017Count"] = 1
        dodgeState["script018Count"] = 0
        dodgeState["script020Count"] = 1
        dodgeState["triggerTimerRemaining"] = nil
        dodgeState["successTimerRemaining"] = nil
        dodgeState["almostDoneTimerRemaining"] = nil
        dodgeState["turretIsPowered"] = false
        dodgeState["markerLightDistance"] = 50
        preScript021["trainingDodgeAttemptState"] = dodgeState
        var openingState = try XCTUnwrap(
            preScript021["trainingOpeningState"] as? [String: Any]
        )
        openingState["enabledControls"] = 63
        openingState["timerRemaining"] = Float(1_000)
        openingState["welcomeWasPresented"] = false
        preScript021["trainingOpeningState"] = openingState
        var simulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: preScript021)
            ),
            resumedAtTimestamp: 0
        )

        var timestamp = 0.1
        var frame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(
            frame.trainingFollowBot?.script021Count,
            1,
            "released Script 021 must start the normal maneuver lesson"
        )
        timestamp = 20.1
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp = 20.2
        frame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(
            frame.trainingFollowBot?.script022Count,
            1,
            "released Script 022 must follow Script 021"
        )
        timestamp = 32.2
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp = 32.3
        frame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(
            frame.trainingFollowBot?.script024Count,
            1,
            "released Script 024 must follow Script 022"
        )
        timestamp = 47.3
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp = 47.4
        frame = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(
            frame.trainingFollowBot?.script023Count,
            1,
            "released Script 023 must follow Script 024"
        )

        for _ in 0..<210 where frame.trainingFollowBot?.script026Count == 0 {
            simulation = try aiming(
                simulation,
                at: handoff.followBotObjectHandle,
                timestamp: timestamp,
                level: level
            )
            timestamp += 0.1
            frame = simulation.update(at: timestamp, input: .zero)
        }
        XCTAssertGreaterThan(
            try XCTUnwrap(frame.trainingFollowBot?.script025Count),
            0,
            "released Script 025 must run during the normal follow interval"
        )
        XCTAssertEqual(
            frame.trainingFollowBot?.script026Count,
            1,
            "released timer 7 must reach Script 026 through normal updates"
        )
        XCTAssertEqual(
            frame.enabledPlayerControls.rawValue,
            lesson.rotationalControlMask | lesson.weaponControlMask,
            "Script 026 must enable only its released rotation and weapon masks"
        )
        XCTAssertFalse(
            frame.enabledPlayerControls.contains(.afterburner),
            "Script 026 weapon mask 12_288 must not enable Afterburner bit 16_384"
        )
        print(
            "AFTERBURNER_STAGE Script026 controls=\(frame.enabledPlayerControls.rawValue) afterburner=false"
        )

        for volley in 1...4 {
            simulation = try aiming(
                simulation,
                at: handoff.followBotObjectHandle,
                timestamp: timestamp,
                level: level
            )
            timestamp += 0.25
            frame = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
            if volley == 3 {
                XCTAssertTrue(
                    simulation.level.objects.contains {
                        $0.handle == handoff.followBotObjectHandle
                    },
                    "FollowBot1 must survive three real two-bolt volleys at 10 shields"
                )
            }
        }
        var destruction = try destructionState(simulation)
        XCTAssertEqual(
            destruction["followBotShields"] as? Double,
            -5,
            "FollowBot1 must die only after real projectile damage is strictly negative"
        )
        XCTAssertEqual(
            destruction["script037Count"] as? Int,
            1,
            "FollowBot1 real dying must start timer 11 through Script 037"
        )
        XCTAssertFalse(
            simulation.level.objects.contains {
                $0.handle == handoff.followBotObjectHandle
            },
            "FollowBot1 real dying must remove the target"
        )
        print("AFTERBURNER_STAGE FollowBot1 death shields=-5 Script037=1")

        for _ in 0..<12 where frame.trainingMovingTarget?.objectHandle
            != handoff.destroyBot1ObjectHandle
        {
            timestamp += 0.25
            frame = simulation.update(at: timestamp, input: .zero)
        }
        destruction = try destructionState(simulation)
        XCTAssertEqual(
            destruction["script027Count"] as? Int,
            1,
            "timer 11 must reach Script 027 through ordinary updates"
        )
        XCTAssertEqual(
            frame.trainingMovingTarget?.objectHandle,
            handoff.destroyBot1ObjectHandle,
            "Script 027 must publish DestroyBot1 as the first real moving target"
        )
        print("AFTERBURNER_STAGE Script027 timer11 target=DestroyBot1")

        for volley in 1...4 {
            simulation = try aiming(
                simulation,
                at: handoff.destroyBot1ObjectHandle,
                timestamp: timestamp,
                level: level
            )
            timestamp += 0.25
            frame = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
            if volley == 3 {
                XCTAssertTrue(
                    simulation.level.objects.contains {
                        $0.handle == handoff.destroyBot1ObjectHandle
                    },
                    "DestroyBot1 must survive three real two-bolt volleys at 10 shields"
                )
            }
        }
        destruction = try destructionState(simulation)
        let destroyBot1State = try XCTUnwrap(
            destruction["destroyBot1Destruction"] as? [String: Any]
        )
        XCTAssertEqual(
            destroyBot1State["destroyBot1Shields"] as? Double,
            -5,
            "DestroyBot1 must die only after real projectile damage is strictly negative"
        )
        XCTAssertEqual(
            destroyBot1State["script028Count"] as? Int,
            1,
            "DestroyBot1 real dying must execute Script 028"
        )
        XCTAssertEqual(
            frame.trainingMovingTarget?.objectHandle,
            handoff.destroyBot2ObjectHandle,
            "Script 028 must publish DestroyBot2 as the next real moving target"
        )
        print("AFTERBURNER_STAGE DestroyBot1 death shields=-5 Script028=1")

        timestamp += 0.25
        frame = simulation.update(at: timestamp, input: .zero)
        for volley in 1...3 {
            simulation = try aiming(
                simulation,
                at: handoff.destroyBot2ObjectHandle,
                timestamp: timestamp,
                level: level
            )
            timestamp += 0.25
            frame = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
            XCTAssertTrue(
                simulation.level.objects.contains {
                    $0.handle == handoff.destroyBot2ObjectHandle
                },
                "DestroyBot2 must survive real volley \(volley) before strict-negative death"
            )
        }
        timestamp += 0.15
        _ = simulation.update(at: timestamp, input: .zero)
        simulation = try aiming(
            simulation,
            at: handoff.destroyBot2ObjectHandle,
            timestamp: timestamp,
            level: level
        )
        timestamp += 0.1
        let script036Frame = simulation.update(
            at: timestamp,
            input: .init(afterburner: 1, firesPrimaryWeapon: true)
        )
        XCTAssertFalse(
            simulation.level.objects.contains {
                $0.handle == handoff.destroyBot2ObjectHandle
            },
            "DestroyBot2 real strict-negative death must remove the target in Script 036"
        )
        let robotState = try XCTUnwrap(
            try continuationObject(simulation)["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(
            robotState["robotShields"] as? Double,
            -5,
            "DestroyBot2 must reach Script 036 only after real shields are strictly negative"
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
            "AFTERBURNER_STAGE DestroyBot2 death shields=-5 Script036 controls=all fuel=5.0"
        )

        var playerInput = PlayerInputState(rampDuration: 0)
        let view = RevivalGameplayView(
            frame: NSRect(x: 0, y: 0, width: 1_280, height: 720),
            device: nil
        )
        view.heldInputChanged = { playerInput.setHeld($0) }
        view.setGameplayActive(true)
        try view.presentTrainingOpening(
            frame: script036Frame,
            voiceClips: simulation.level.voiceClips
        )
        let afterburner = try textField(
            accessibilityLabel: "Afterburner",
            in: view
        )
        let controlSummary = try textField(
            accessibilityLabel: "Enabled Training controls",
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
        try view.presentTrainingOpening(
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
        try view.presentTrainingOpening(
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
