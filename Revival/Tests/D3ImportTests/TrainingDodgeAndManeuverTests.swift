import XCTest

extension WorldRenderingTests {
    @MainActor
    func testScripts021Through026PreserveReleasedOrderVisibilityAndMotion()
        throws
    {
        var level = makeTrainingManeuverFollowLevel()
        let lesson = try XCTUnwrap(
            level.trainingDodgeAttempt?.maneuverFollow
        )
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == level.defaultPlayerBinding?.objectHandle
            }
        )
        let maneuver = try XCTUnwrap(
            level.objects.first {
                $0.handle == lesson.maneuverObjectHandle
            }
        )
        level.objects[playerIndex].location = maneuver.location
        level.objects[playerIndex].position = maneuver.position
        level.objects[playerIndex].orientation = maneuver.orientation
        let roomIndex = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 37 }
        )
        let originalRoom = level.rooms[roomIndex]
        let containmentRoom = makeSourceContainmentRoom(
            center: maneuver.position,
            texture: level.surfacePhysics[0].texture,
            sourceIndex: originalRoom.sourceIndex,
            halfExtent: 500
        )
        var containmentFaces = containmentRoom.faces
        let containmentPortals = originalRoom.portals.enumerated().map {
            portalIndex,
            portal in
            let face = containmentFaces[portalIndex]
            containmentFaces[portalIndex] = .init(
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
            vertices: containmentRoom.vertices,
            faces: containmentFaces,
            portals: containmentPortals
        )
        let followBotObject = try XCTUnwrap(
            level.objects.first {
                $0.handle == lesson.followBotObjectHandle
            }
        )
        XCTAssertTrue(
            isCanonicalRigidTransform(
                position: followBotObject.position,
                orientation: followBotObject.orientation
            )
        )
        XCTAssertTrue(
            sourceConvexRoomContains(
                followBotObject.position,
                in: level.rooms[roomIndex]
            )
        )

        let seed = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(seed.continuation)
            ) as? [String: Any]
        )
        var dodgeState = try XCTUnwrap(
            continuationObject["trainingDodgeAttemptState"]
                as? [String: Any]
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
        continuationObject["trainingDodgeAttemptState"] = dodgeState
        var openingState = try XCTUnwrap(
            continuationObject["trainingOpeningState"]
                as? [String: Any]
        )
        openingState["enabledControls"] = 63
        openingState["timerRemaining"] = Float(1_000)
        openingState["welcomeWasPresented"] = false
        continuationObject["trainingOpeningState"] = openingState
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: continuationObject
            )
        )
        let simulation = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 0
        )

        let heading = simulation.update(at: 0.1, input: .zero)
        XCTAssertEqual(heading.enabledPlayerControls.rawValue, 768)
        XCTAssertEqual(heading.trainingDodgeMarkerLightDistance, 0)
        XCTAssertEqual(
            heading.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [lesson.maneuverIntroduction],
                    voiceSourceName:
                        lesson.headingVoiceSourceName,
                    voicePrecedesHUDMessages: false,
                    trailingHUDMessages: [
                        lesson.headingInstruction,
                    ]
                ),
            ]
        )
        var headingPresentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            heading.trainingOpeningFeedback,
            attemptVoice: {
                headingPresentationOrder.append("voice:\($0)")
            },
            attemptSound: { _, _ in
                XCTFail("Script 021 does not play a sound event")
            },
            presentHUDMessages: {
                headingPresentationOrder.append(
                    contentsOf: $0.map { "hud:\($0)" }
                )
            }
        )
        XCTAssertEqual(
            headingPresentationOrder,
            [
                "hud:\(lesson.maneuverIntroduction)",
                "voice:\(lesson.headingVoiceSourceName)",
                "hud:\(lesson.headingInstruction)",
            ]
        )
        XCTAssertEqual(heading.trainingFollowBot?.script021Count, 1)
        let closedPortalRoom = try XCTUnwrap(
            simulation.level.rooms.first {
                $0.sourceIndex == lesson.portalRoomSourceIndex
            }
        )
        for portalIndex in lesson.orderedPortalIndices {
            let portal = closedPortalRoom.portals[portalIndex]
            XCTAssertEqual(portal.flags & 1, 1)
            let reciprocal = try XCTUnwrap(
                simulation.level.rooms.first {
                    $0.sourceIndex == portal.connectedRoom
                }
            ).portals[portal.connectedPortal]
            XCTAssertEqual(reciprocal.flags & 1, 1)
        }

        var earlyManeuverObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        var earlyManeuverOpening = try XCTUnwrap(
            earlyManeuverObject["trainingOpeningState"]
                as? [String: Any]
        )
        earlyManeuverOpening["startCourseWasPresented"] = true
        earlyManeuverOpening["finishCourseWasPresented"] = true
        earlyManeuverObject["trainingOpeningState"] =
            earlyManeuverOpening
        let earlyManeuverRestore = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: earlyManeuverObject
                )
            ),
            resumedAtTimestamp: 0.1
        ).update(at: 0.1, input: .zero)
        XCTAssertEqual(
            earlyManeuverRestore.enabledPlayerControls.rawValue,
            lesson.headingControlMask,
            "Script 021 remains exact when source-valid history skips Script 019"
        )

        let headingContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        var stalledHeadingObject = headingContinuationObject
        var stalledHeadingState = try XCTUnwrap(
            stalledHeadingObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        stalledHeadingState.removeValue(
            forKey: "levelTimerRemaining"
        )
        stalledHeadingObject["trainingManeuverFollowState"] =
            stalledHeadingState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: stalledHeadingObject
                    )
                ),
                resumedAtTimestamp: 0.1
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
        var missingPredecessorObject = headingContinuationObject
        var missingPredecessorDodge = try XCTUnwrap(
            missingPredecessorObject["trainingDodgeAttemptState"]
                as? [String: Any]
        )
        missingPredecessorDodge["script020Count"] = 0
        missingPredecessorObject["trainingDodgeAttemptState"] =
            missingPredecessorDodge
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: missingPredecessorObject
                    )
                ),
                resumedAtTimestamp: 0.1
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var wrongRoomObject = headingContinuationObject
        var wrongRoomState = try XCTUnwrap(
            wrongRoomObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        wrongRoomState["roomSourceIndex"] = 35
        wrongRoomObject["trainingManeuverFollowState"] =
            wrongRoomState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: wrongRoomObject
                    )
                ),
                resumedAtTimestamp: 0.1
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var outsideRoomObject = headingContinuationObject
        var outsideRoomState = try XCTUnwrap(
            outsideRoomObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        outsideRoomState["position"] = [
            "x": maneuver.position.x + 1_000,
            "y": maneuver.position.y,
            "z": maneuver.position.z,
        ]
        outsideRoomObject["trainingManeuverFollowState"] =
            outsideRoomState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: outsideRoomObject
                    )
                ),
                resumedAtTimestamp: 0.1
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var excessiveVelocityObject = headingContinuationObject
        var excessiveVelocityState = try XCTUnwrap(
            excessiveVelocityObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        excessiveVelocityState["velocity"] = [
            "x": lesson.followBot.maximumVelocity + 1,
            "y": Float.zero,
            "z": Float.zero,
        ]
        excessiveVelocityObject["trainingManeuverFollowState"] =
            excessiveVelocityState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: excessiveVelocityObject
                    )
                ),
                resumedAtTimestamp: 0.1
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        _ = simulation.update(at: 20.1, input: .zero)
        let pitch = simulation.update(at: 20.2, input: .zero)
        XCTAssertEqual(pitch.enabledPlayerControls.rawValue, 192)
        XCTAssertEqual(
            pitch.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [
                        lesson.successMessage,
                        lesson.pitchInstruction,
                    ],
                    voiceSourceName: lesson.pitchVoiceSourceName,
                    voicePrecedesHUDMessages: false
                ),
            ]
        )
        XCTAssertEqual(pitch.trainingFollowBot?.script022Count, 1)

        _ = simulation.update(at: 32.2, input: .zero)
        let bank = simulation.update(at: 32.3, input: .zero)
        XCTAssertEqual(bank.enabledPlayerControls.rawValue, 3_072)
        XCTAssertEqual(
            bank.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [lesson.bankInstruction],
                    voiceSourceName: lesson.bankVoiceSourceName,
                    voicePrecedesHUDMessages: false
                ),
            ]
        )
        XCTAssertEqual(bank.trainingFollowBot?.script024Count, 1)

        _ = simulation.update(at: 47.3, input: .zero)
        let follow = simulation.update(at: 47.4, input: .zero)
        XCTAssertEqual(follow.enabledPlayerControls.rawValue, 4_032)
        XCTAssertEqual(
            follow.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [
                        lesson.followIntroduction,
                        lesson.followInstruction,
                    ],
                    voiceSourceName: lesson.followVoiceSourceName,
                    voicePrecedesHUDMessages: false
                ),
            ]
        )
        XCTAssertEqual(follow.trainingFollowBot?.script023Count, 1)
        XCTAssertEqual(
            follow.trainingFollowBot?.teamFlags,
            lesson.friendlyTeamFlags
        )
        XCTAssertEqual(
            follow.trainingFollowBot?.activePathIndex,
            lesson.followPathIndex
        )
        XCTAssertEqual(
            follow.trainingFollowBot?.objectTimerRemaining,
            lesson.followDuration
        )

        let followPath = level.paths[lesson.followPathIndex]
        let firstNode = followPath.nodes[0]
        let secondNode = followPath.nodes[1]
        let firstSegmentDelta = Vector3(
            x: secondNode.position.x - firstNode.position.x,
            y: secondNode.position.y - firstNode.position.y,
            z: secondNode.position.z - firstNode.position.z
        )
        let firstSegmentLengthSquared =
            firstSegmentDelta.x * firstSegmentDelta.x
            + firstSegmentDelta.y * firstSegmentDelta.y
            + firstSegmentDelta.z * firstSegmentDelta.z
        let firstSegmentLength = sqrt(firstSegmentLengthSquared)
        let firstSegment = Vector3(
            x: firstSegmentDelta.x / firstSegmentLength,
            y: firstSegmentDelta.y / firstSegmentLength,
            z: firstSegmentDelta.z / firstSegmentLength
        )
        func testMagnitude(_ value: Vector3) -> Float {
            sqrt(
                value.x * value.x
                    + value.y * value.y
                    + value.z * value.z
            )
        }
        func testNormalized(_ value: Vector3) -> Vector3 {
            let magnitude = testMagnitude(value)
            return .init(
                x: value.x / magnitude,
                y: value.y / magnitude,
                z: value.z / magnitude
            )
        }
        func testCross(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
            .init(
                x: lhs.y * rhs.z - lhs.z * rhs.y,
                y: lhs.z * rhs.x - lhs.x * rhs.z,
                z: lhs.x * rhs.y - lhs.y * rhs.x
            )
        }
        func testDot(_ lhs: Vector3, _ rhs: Vector3) -> Float {
            lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
        }
        let firstNodeForward = testNormalized(firstNode.forward)
        let firstNodeRight = testNormalized(
            testCross(firstNode.up, firstNodeForward)
        )
        let firstNodeUp = testNormalized(
            testCross(firstNodeForward, firstNodeRight)
        )
        var loopTransitionObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        loopTransitionObject["frameDuration"] = 0.1
        var loopTransitionState = try XCTUnwrap(
            loopTransitionObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        let loopTransitionStart = Vector3(
            x: firstNode.position.x + firstSegment.x * 0.1,
            y: firstNode.position.y + firstSegment.y * 0.1,
            z: firstNode.position.z + firstSegment.z * 0.1
        )
        loopTransitionState["position"] = [
            "x": loopTransitionStart.x,
            "y": loopTransitionStart.y,
            "z": loopTransitionStart.z,
        ]
        loopTransitionState["velocity"] = [
            "x": Float.zero,
            "y": Float.zero,
            "z": Float.zero,
        ]
        loopTransitionState["orientation"] = [
            "right": [
                "x": firstNodeRight.x,
                "y": firstNodeRight.y,
                "z": firstNodeRight.z,
            ],
            "up": [
                "x": firstNodeUp.x,
                "y": firstNodeUp.y,
                "z": firstNodeUp.z,
            ],
            "forward": [
                "x": firstNodeForward.x,
                "y": firstNodeForward.y,
                "z": firstNodeForward.z,
            ],
        ]
        loopTransitionState["turnRate"] =
            lesson.followBot.maximumTurnRate
        loopTransitionObject["trainingManeuverFollowState"] =
            loopTransitionState
        let loopTransitionSimulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: loopTransitionObject
                )
            ),
            resumedAtTimestamp: 47.4
        )
        let loopTransition = loopTransitionSimulation.update(
            at: 47.4,
            input: .zero
        )
        let loopTransitionEnd = try XCTUnwrap(
            loopTransition.trainingFollowBot?.position
        )
        XCTAssertEqual(
            loopTransition.trainingFollowBot?.pathNodeIndex,
            1
        )
        let loopTransitionDisplacement = Vector3(
            x: loopTransitionEnd.x - loopTransitionStart.x,
            y: loopTransitionEnd.y - loopTransitionStart.y,
            z: loopTransitionEnd.z - loopTransitionStart.z
        )
        let loopTransitionProjectionX =
            loopTransitionDisplacement.x * firstSegment.x
        let loopTransitionProjectionY =
            loopTransitionDisplacement.y * firstSegment.y
        let loopTransitionProjectionZ =
            loopTransitionDisplacement.z * firstSegment.z
        let loopTransitionProjection =
            loopTransitionProjectionX
            + loopTransitionProjectionY
            + loopTransitionProjectionZ
        XCTAssertLessThan(
            loopTransitionProjection,
            0,
            "the crossing frame retains movement toward the released current node"
        )
        XCTAssertGreaterThan(
            testDot(
                try XCTUnwrap(
                    loopTransition.trainingFollowBot?
                        .orientation.forward
                ),
                firstNodeForward
            ),
            0.999_9,
            "path-node orientation interpolates from the prior authored basis"
        )
        _ = loopTransitionSimulation.update(
            at: 47.5,
            input: .zero
        )
        _ = loopTransitionSimulation.update(
            at: 47.6,
            input: .zero
        )
        let nextNodeMotion = loopTransitionSimulation.update(
            at: 47.7,
            input: .zero
        )
        let nextNodePosition = try XCTUnwrap(
            nextNodeMotion.trainingFollowBot?.position
        )
        let nextNodeDisplacement = Vector3(
            x: nextNodePosition.x - loopTransitionEnd.x,
            y: nextNodePosition.y - loopTransitionEnd.y,
            z: nextNodePosition.z - loopTransitionEnd.z
        )
        XCTAssertGreaterThan(
            testDot(nextNodeDisplacement, firstSegment),
            0,
            "the frame after transition steers toward the released next node"
        )

        var strictBoundaryObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        strictBoundaryObject["frameDuration"] = 0
        let strictPlayerPosition = try XCTUnwrap(
            strictBoundaryObject["playerPosition"] as? [String: Any]
        )
        var strictManeuverState = try XCTUnwrap(
            strictBoundaryObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        strictManeuverState["position"] = [
            "x": try XCTUnwrap(strictPlayerPosition["x"] as? NSNumber)
                .floatValue + 10,
            "y": try XCTUnwrap(strictPlayerPosition["y"] as? NSNumber)
                .floatValue,
            "z": try XCTUnwrap(strictPlayerPosition["z"] as? NSNumber)
                .floatValue - 10,
        ]
        strictManeuverState["velocity"] = [
            "x": Float.zero,
            "y": Float.zero,
            "z": Float.zero,
        ]
        strictManeuverState["objectTimerRemaining"] = 1
        strictBoundaryObject["trainingManeuverFollowState"] =
            strictManeuverState
        let strictBoundary = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: strictBoundaryObject
                )
            ),
            resumedAtTimestamp: 47.4
        ).update(at: 47.4, input: .zero)
        XCTAssertEqual(
            strictBoundary.trainingFollowBot?.objectTimerRemaining,
            lesson.followDuration,
            "exactly 45 degrees is outside the released strict 90-degree cone"
        )
        XCTAssertEqual(
            strictBoundary.trainingFollowBot?.script025Count,
            1
        )

        let beforeMotion = try XCTUnwrap(
            follow.trainingFollowBot?.position
        )
        let moved = simulation.update(at: 47.5, input: .zero)
        XCTAssertNotEqual(
            moved.trainingFollowBot?.position,
            beforeMotion
        )
        XCTAssertEqual(
            moved.trainingFollowBot?.script025Count,
            1
        )
        var expiryObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        expiryObject["frameDuration"] = 0
        let expiryPlayerPosition = try XCTUnwrap(
            expiryObject["playerPosition"] as? [String: Any]
        )
        var expiryManeuverState = try XCTUnwrap(
            expiryObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        expiryManeuverState["position"] = [
            "x": try XCTUnwrap(expiryPlayerPosition["x"] as? NSNumber)
                .floatValue,
            "y": try XCTUnwrap(expiryPlayerPosition["y"] as? NSNumber)
                .floatValue,
            "z": try XCTUnwrap(expiryPlayerPosition["z"] as? NSNumber)
                .floatValue - 10,
        ]
        expiryManeuverState["velocity"] = [
            "x": Float.zero,
            "y": Float.zero,
            "z": Float.zero,
        ]
        expiryManeuverState["script025Count"] = 0
        expiryManeuverState["objectTimerRemaining"] = 0.000_001
        expiryObject["trainingManeuverFollowState"] =
            expiryManeuverState
        let weaponsSimulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: expiryObject
                )
            ),
            resumedAtTimestamp: 47.5
        )
        let weapons = weaponsSimulation.update(
            at: 47.5,
            input: .zero
        )
        XCTAssertEqual(
            weapons.enabledPlayerControls.rawValue,
            4_032 | 12_288
        )
        XCTAssertEqual(
            weapons.trainingFollowBot?.activePathIndex,
            lesson.destroyPathIndex
        )
        XCTAssertEqual(
            weapons.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [
                        lesson.successMessage,
                        lesson.weaponsEnabledInstruction,
                    ],
                    voiceSourceName:
                        lesson.weaponVoiceSourceName,
                    voicePrecedesHUDMessages: false,
                    trailingHUDMessages: [
                        lesson.destroyInstruction,
                    ]
                ),
            ]
        )
        var weaponsPresentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            weapons.trainingOpeningFeedback,
            attemptVoice: {
                weaponsPresentationOrder.append("voice:\($0)")
            },
            attemptSound: { _, _ in
                XCTFail("Script 026 does not play a sound event")
            },
            presentHUDMessages: {
                weaponsPresentationOrder.append(
                    contentsOf: $0.map { "hud:\($0)" }
                )
            }
        )
        XCTAssertEqual(
            weaponsPresentationOrder,
            [
                "hud:\(lesson.successMessage)",
                "hud:\(lesson.weaponsEnabledInstruction)",
                "voice:\(lesson.weaponVoiceSourceName)",
                "hud:\(lesson.destroyInstruction)",
            ]
        )
        XCTAssertEqual(weapons.trainingFollowBot?.script026Count, 1)
        XCTAssertEqual(weapons.trainingFollowBot?.script025Count, 1)

        let restored = try PlayerSimulation(
            level: level,
            continuation: weaponsSimulation.continuation,
            resumedAtTimestamp: 100
        )
        let silent = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(silent.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            silent.trainingFollowBot?.activePathIndex,
            lesson.destroyPathIndex
        )

        let destroyNode =
            level.paths[lesson.destroyPathIndex].nodes[0]
        var completionObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    weaponsSimulation.continuation
                )
            ) as? [String: Any]
        )
        completionObject["frameDuration"] = 0.1
        var completionState = try XCTUnwrap(
            completionObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        completionState["position"] = [
            "x": destroyNode.position.x - 1,
            "y": destroyNode.position.y,
            "z": destroyNode.position.z,
        ]
        completionState["velocity"] = [
            "x": Float(lesson.followBot.maximumVelocity),
            "y": Float.zero,
            "z": Float.zero,
        ]
        completionObject["trainingManeuverFollowState"] =
            completionState
        let completedPath = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: completionObject
                )
            ),
            resumedAtTimestamp: 100
        ).update(at: 100, input: .zero)
        XCTAssertNil(
            completedPath.trainingFollowBot?.activePathIndex
        )
        XCTAssertGreaterThanOrEqual(
            try XCTUnwrap(
                completedPath.trainingFollowBot?.position.x
            ),
            destroyNode.position.x
        )

        var destroyTurnObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    weaponsSimulation.continuation
                )
            ) as? [String: Any]
        )
        destroyTurnObject["frameDuration"] = 0.1
        var destroyTurnState = try XCTUnwrap(
            destroyTurnObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        destroyTurnState["position"] = [
            "x": destroyNode.position.x - 10,
            "y": destroyNode.position.y,
            "z": destroyNode.position.z,
        ]
        destroyTurnState["orientation"] = [
            "right": [
                "x": Float(1),
                "y": Float.zero,
                "z": Float.zero,
            ],
            "up": [
                "x": Float.zero,
                "y": Float(1),
                "z": Float.zero,
            ],
            "forward": [
                "x": Float.zero,
                "y": Float.zero,
                "z": Float(1),
            ],
        ]
        destroyTurnState["velocity"] = [
            "x": Float.zero,
            "y": Float.zero,
            "z": Float.zero,
        ]
        destroyTurnState["turnRate"] = Float.zero
        destroyTurnObject["trainingManeuverFollowState"] =
            destroyTurnState
        let destroyTurn = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: destroyTurnObject
                )
            ),
            resumedAtTimestamp: 100
        ).update(at: 100, input: .zero)
        XCTAssertGreaterThan(
            try XCTUnwrap(
                destroyTurn.trainingFollowBot?
                    .orientation.forward.x
            ),
            0.1,
            "GoToDie uses the released direct maximum-turn-rate cap without a delta-rate ramp"
        )

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    weaponsSimulation.continuation
                )
            ) as? [String: Any]
        )
        var hostileManeuverState = try XCTUnwrap(
            hostileObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        hostileManeuverState["objectTimerRemaining"] = 1
        hostileObject["trainingManeuverFollowState"] =
            hostileManeuverState
        let hostileContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: hostileObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostileContinuation,
                resumedAtTimestamp: 100
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var impossibleOrderObject = continuationObject
        var impossibleOrderState = try XCTUnwrap(
            impossibleOrderObject["trainingManeuverFollowState"]
                as? [String: Any]
        )
        impossibleOrderState["script025Count"] = 1
        impossibleOrderObject["trainingManeuverFollowState"] =
            impossibleOrderState
        let impossibleOrder = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: impossibleOrderObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: impossibleOrder,
                resumedAtTimestamp: 100
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

    }

    @MainActor
    func testScript019EarlyContactOpensExitOnceAndRestoresSilently()
        throws
    {
        func expandingDodgeRoom(_ source: Level) -> Level {
            var level = source
            let roomIndex = level.rooms.firstIndex {
                $0.sourceIndex == 35
            }!
            let vertices = level.rooms[roomIndex].vertices
            let center = Vector3(
                x: vertices.map(\.x).reduce(0, +)
                    / Float(vertices.count),
                y: vertices.map(\.y).reduce(0, +)
                    / Float(vertices.count),
                z: vertices.map(\.z).reduce(0, +)
                    / Float(vertices.count)
            )
            level.rooms[roomIndex].vertices = vertices.map {
                .init(
                    x: center.x + ($0.x - center.x) * 100,
                    y: center.y + ($0.y - center.y) * 100,
                    z: center.z + ($0.z - center.z) * 100
                )
            }
            return level
        }

        var level = expandingDodgeRoom(
            makeTrainingDodgeAttemptLevel()
        )
        let dodge = try XCTUnwrap(level.trainingDodgeAttempt)
        let exit = try XCTUnwrap(dodge.dodgeExit)
        let done = try XCTUnwrap(
            level.objects.first {
                $0.handle == exit.objectHandle
            }
        )
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == level.defaultPlayerBinding?.objectHandle
            }
        )
        level.objects[playerIndex].location = done.location
        level.objects[playerIndex].position = done.position

        let portalRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == exit.portalRoomSourceIndex
            }
        )
        for (offset, portalIndex) in
            exit.orderedPortalIndices.enumerated()
        {
            level.rooms[portalRoomIndex].portals[portalIndex].flags
                |= UInt32(1 << (offset + 3))
            let portal =
                level.rooms[portalRoomIndex].portals[portalIndex]
            let reciprocalRoomIndex = try XCTUnwrap(
                level.rooms.firstIndex {
                    $0.sourceIndex == portal.connectedRoom
                }
            )
            level.rooms[reciprocalRoomIndex]
                .portals[portal.connectedPortal].flags
                |= UInt32(1 << (offset + 5))
        }

        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        let frame = simulation.update(at: 0.1, input: .zero)
        XCTAssertEqual(frame.enabledPlayerControls.rawValue, 1)
        XCTAssertEqual(
            frame.trainingDodgeMarkerLightDistance,
            exit.markerLightDistance
        )
        XCTAssertEqual(
            frame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [exit.instruction],
                    voiceSourceName: exit.voiceSourceName,
                    voicePrecedesHUDMessages: true
                )
            ]
        )
        let openedRoom = try XCTUnwrap(
            simulation.level.rooms.first {
                $0.sourceIndex == exit.portalRoomSourceIndex
            }
        )
        for (offset, portalIndex) in
            exit.orderedPortalIndices.enumerated()
        {
            let portal = openedRoom.portals[portalIndex]
            XCTAssertEqual(
                portal.flags,
                UInt32(1 << (offset + 3))
            )
            let reciprocal = try XCTUnwrap(
                simulation.level.rooms.first {
                    $0.sourceIndex == portal.connectedRoom
                }
            ).portals[portal.connectedPortal]
            XCTAssertEqual(
                reciprocal.flags,
                UInt32(1 << (offset + 5))
            )
        }
        XCTAssertTrue(
            simulation.update(at: 0.2, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )

        var restoreLevel = expandingDodgeRoom(
            makeTrainingDodgeAttemptLevel()
        )
        let restorePlayerIndex = try XCTUnwrap(
            restoreLevel.objects.firstIndex {
                $0.handle
                    == restoreLevel.defaultPlayerBinding?.objectHandle
            }
        )
        restoreLevel.objects[restorePlayerIndex].location =
            done.location
        restoreLevel.objects[restorePlayerIndex].position =
            done.position
        let restorableEarlySimulation = PlayerSimulation(
            level: restoreLevel,
            presentationReadyTimestamp: 0
        )
        let earlyFrame = restorableEarlySimulation.update(
            at: 0.1,
            input: .zero
        )
        XCTAssertEqual(
            earlyFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [exit.instruction],
                    voiceSourceName: exit.voiceSourceName,
                    voicePrecedesHUDMessages: true
                )
            ]
        )
        XCTAssertEqual(earlyFrame.enabledPlayerControls.rawValue, 1)
        let earlyContinuation =
            restorableEarlySimulation.continuation
        let earlyState = try encodedDodgeState(earlyContinuation)
        XCTAssertEqual(earlyState["script019Count"] as? Int, 1)

        var reachedHighBitObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(earlyContinuation)
            ) as? [String: Any]
        )
        var reachedHighBitOpening = try XCTUnwrap(
            reachedHighBitObject["trainingOpeningState"]
                as? [String: Any]
        )
        reachedHighBitOpening["enabledControls"] = 65
        reachedHighBitObject["trainingOpeningState"] =
            reachedHighBitOpening
        let reachedHighBitContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: reachedHighBitObject
            )
        )
        let restoredEarly = try PlayerSimulation(
            level: restoreLevel,
            continuation: reachedHighBitContinuation,
            resumedAtTimestamp: 1
        )
        let restoredEarlyFrame = restoredEarly.update(
            at: 1.1,
            input: .zero
        )
        XCTAssertTrue(
            restoredEarlyFrame.trainingOpeningFeedback.isEmpty
        )
        XCTAssertEqual(
            restoredEarlyFrame.enabledPlayerControls.rawValue,
            65
        )

        var earlyThenSuccessObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(earlyContinuation)
            ) as? [String: Any]
        )
        var earlyThenSuccessOpening = try XCTUnwrap(
            earlyThenSuccessObject["trainingOpeningState"]
                as? [String: Any]
        )
        earlyThenSuccessOpening["enabledControls"] = 67
        earlyThenSuccessObject["trainingOpeningState"] =
            earlyThenSuccessOpening
        var earlyThenSuccessState = try XCTUnwrap(
            earlyThenSuccessObject["trainingDodgeAttemptState"]
                as? [String: Any]
        )
        earlyThenSuccessState["script033Count"] = 1
        earlyThenSuccessState["script016Count"] = 1
        earlyThenSuccessState["script017Count"] = 1
        earlyThenSuccessState["script019Count"] = 1
        earlyThenSuccessState["markerLightDistance"] = 50
        earlyThenSuccessState["turretIsPowered"] = false
        earlyThenSuccessState.removeValue(
            forKey: "triggerTimerRemaining"
        )
        earlyThenSuccessState.removeValue(
            forKey: "successTimerRemaining"
        )
        earlyThenSuccessState.removeValue(
            forKey: "almostDoneTimerRemaining"
        )
        earlyThenSuccessObject["trainingDodgeAttemptState"] =
            earlyThenSuccessState
        let earlyThenSuccess = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: earlyThenSuccessObject
            )
        )
        let restoredEarlyThenSuccess = try PlayerSimulation(
            level: restoreLevel,
            continuation: earlyThenSuccess,
            resumedAtTimestamp: 1.5
        )
        let earlyThenSuccessFrame = restoredEarlyThenSuccess.update(
            at: 1.6,
            input: .zero
        )
        XCTAssertTrue(
            earlyThenSuccessFrame.trainingOpeningFeedback.isEmpty
        )
        XCTAssertEqual(
            earlyThenSuccessFrame.enabledPlayerControls.rawValue,
            67
        )

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(earlyContinuation)
            ) as? [String: Any]
        )
        var hostileState = try XCTUnwrap(
            hostileObject["trainingDodgeAttemptState"]
                as? [String: Any]
        )
        hostileState["script019Count"] = 2
        hostileObject["trainingDodgeAttemptState"] = hostileState
        let hostile = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: hostileObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: restoreLevel,
                continuation: hostile,
                resumedAtTimestamp: 2
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var oldLevel = expandingDodgeRoom(
            makeTrainingDodgeAttemptLevel()
        )
        let oldPlayerIndex = try XCTUnwrap(
            oldLevel.objects.firstIndex {
                $0.handle == oldLevel.defaultPlayerBinding?.objectHandle
            }
        )
        oldLevel.objects[oldPlayerIndex].location = done.location
        oldLevel.objects[oldPlayerIndex].position = done.position
        let oldSimulation = PlayerSimulation(
            level: oldLevel,
            presentationReadyTimestamp: 0
        )
        var oldObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(oldSimulation.continuation)
            ) as? [String: Any]
        )
        var oldState = try XCTUnwrap(
            oldObject["trainingDodgeAttemptState"]
                as? [String: Any]
        )
        oldState.removeValue(forKey: "script019Count")
        oldObject["trainingDodgeAttemptState"] = oldState
        let oldContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: oldObject)
        )
        let restoredOld = try PlayerSimulation(
            level: oldLevel,
            continuation: oldContinuation,
            resumedAtTimestamp: 2.5
        )
        let oldContactFrame = restoredOld.update(
            at: 2.6,
            input: .zero
        )
        XCTAssertEqual(
            oldContactFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [exit.instruction],
                    voiceSourceName: exit.voiceSourceName,
                    voicePrecedesHUDMessages: true
                )
            ]
        )
        XCTAssertTrue(
            restoredOld.update(at: 2.7, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )

        var unreachedHighBitObject = oldObject
        var unreachedHighBitOpening = try XCTUnwrap(
            unreachedHighBitObject["trainingOpeningState"]
                as? [String: Any]
        )
        unreachedHighBitOpening["enabledControls"] = 65
        unreachedHighBitObject["trainingOpeningState"] =
            unreachedHighBitOpening
        let unreachedHighBit = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: unreachedHighBitObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: oldLevel,
                continuation: unreachedHighBit,
                resumedAtTimestamp: 3
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var unreachedActiveObject = oldObject
        var unreachedActiveOpening = try XCTUnwrap(
            unreachedActiveObject["trainingOpeningState"]
                as? [String: Any]
        )
        unreachedActiveOpening["enabledControls"] = 124
        unreachedActiveObject["trainingOpeningState"] =
            unreachedActiveOpening
        var unreachedActiveState = try XCTUnwrap(
            unreachedActiveObject["trainingDodgeAttemptState"]
                as? [String: Any]
        )
        unreachedActiveState["script033Count"] = 1
        unreachedActiveState["triggerTimerRemaining"] = 5
        unreachedActiveObject["trainingDodgeAttemptState"] =
            unreachedActiveState
        let unreachedActive = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: unreachedActiveObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: oldLevel,
                continuation: unreachedActive,
                resumedAtTimestamp: 3.5
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var unreachedSuccessObject = oldObject
        var unreachedSuccessOpening = try XCTUnwrap(
            unreachedSuccessObject["trainingOpeningState"]
                as? [String: Any]
        )
        unreachedSuccessOpening["enabledControls"] = 127
        unreachedSuccessObject["trainingOpeningState"] =
            unreachedSuccessOpening
        var unreachedSuccessState = try XCTUnwrap(
            unreachedSuccessObject["trainingDodgeAttemptState"]
                as? [String: Any]
        )
        unreachedSuccessState["script033Count"] = 1
        unreachedSuccessState["script016Count"] = 1
        unreachedSuccessState["script017Count"] = 1
        unreachedSuccessState["markerLightDistance"] = 50
        unreachedSuccessState["turretIsPowered"] = false
        unreachedSuccessState.removeValue(
            forKey: "triggerTimerRemaining"
        )
        unreachedSuccessState.removeValue(
            forKey: "successTimerRemaining"
        )
        unreachedSuccessState.removeValue(
            forKey: "almostDoneTimerRemaining"
        )
        unreachedSuccessObject["trainingDodgeAttemptState"] =
            unreachedSuccessState
        let unreachedSuccess = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: unreachedSuccessObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: oldLevel,
                continuation: unreachedSuccess,
                resumedAtTimestamp: 4
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

    }

    @MainActor
    func testTimedDodgeUsesReleasedRookieDifficultyAndRandomOrder()
        throws
    {
        func continuationObject(
            _ simulation: PlayerSimulation
        ) throws -> [String: Any] {
            try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(simulation.continuation)
                ) as? [String: Any]
            )
        }
        func dodgeState(
            _ simulation: PlayerSimulation
        ) throws -> [String: Any] {
            try XCTUnwrap(
                try continuationObject(simulation)[
                    "trainingDodgeAttemptState"
                ] as? [String: Any]
            )
        }
        func randomState(
            _ simulation: PlayerSimulation
        ) throws -> UInt32 {
            try XCTUnwrap(
                try continuationObject(simulation)[
                    "authoritativeRandomState"
                ] as? NSNumber
            ).uint32Value
        }
        func vector(
            _ value: Any?,
            file: StaticString = #filePath,
            line: UInt = #line
        ) throws -> Vector3 {
            let object = try XCTUnwrap(
                value as? [String: Any],
                file: file,
                line: line
            )
            return .init(
                x: Float(try XCTUnwrap(object["x"] as? Double)),
                y: Float(try XCTUnwrap(object["y"] as? Double)),
                z: Float(try XCTUnwrap(object["z"] as? Double))
            )
        }
        func magnitude(_ value: Vector3) -> Float {
            sqrt(
                value.x * value.x
                    + value.y * value.y
                    + value.z * value.z
            )
        }
        func scaled(
            _ value: Vector3,
            to targetMagnitude: Float
        ) -> Vector3 {
            let sourceMagnitude = magnitude(value)
            return .init(
                x: value.x * targetMagnitude / sourceMagnitude,
                y: value.y * targetMagnitude / sourceMagnitude,
                z: value.z * targetMagnitude / sourceMagnitude
            )
        }
        func assertVector(
            _ actual: Vector3,
            _ expected: Vector3,
            accuracy: Float = 0.000_01,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            XCTAssertEqual(actual.x, expected.x, accuracy: accuracy, file: file, line: line)
            XCTAssertEqual(actual.y, expected.y, accuracy: accuracy, file: file, line: line)
            XCTAssertEqual(actual.z, expected.z, accuracy: accuracy, file: file, line: line)
        }

        var level = makeTrainingDodgeAttemptLevel()
        let dodge = try XCTUnwrap(level.trainingDodgeAttempt)
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == level.defaultPlayerBinding?.objectHandle
            }
        )
        let startDodge = try XCTUnwrap(
            level.objects.first {
                $0.handle == dodge.startDodgeObjectHandle
            }
        )
        let turret = try XCTUnwrap(
            level.objects.first {
                $0.handle == dodge.dodgeTurretObjectHandle
            }
        )
        level.objects[playerIndex].location = startDodge.location
        level.objects[playerIndex].position = startDodge.position

        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 1
        )
        var timestamp = 0.1
        let contact = simulation.update(at: timestamp, input: .zero)
        XCTAssertEqual(contact.enabledPlayerControls.rawValue, 60)
        XCTAssertEqual(try randomState(simulation), 1)
        XCTAssertEqual(
            try XCTUnwrap(
                try dodgeState(simulation)["triggerTimerRemaining"]
                    as? Double
            ),
            10,
            accuracy: 0.000_001
        )

        var capturedInstructionFrame: PlayerSimulationFrame?
        for _ in 0..<110 {
            timestamp += 0.1
            let frame = simulation.update(at: timestamp, input: .zero)
            XCTAssertEqual(
                try randomState(simulation),
                1,
                "StartDodge and the real Script-016 timer consume no random draw"
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.hudMessages == [dodge.instruction]
            }) {
                capturedInstructionFrame = frame
                break
            }
        }
        let instructionFrame = try XCTUnwrap(capturedInstructionFrame)

        timestamp += 0.1
        let firstAttempt = simulation.update(
            at: timestamp,
            input: .init(sideways: 1)
        )
        let firstState = try dodgeState(simulation)
        XCTAssertEqual(try randomState(simulation), 0x0029_e2c0)
        let visibilityFraction = Float(41) / Float(32_767)
        let expectedVisibilityTime = Float(
            (Double(firstAttempt.systemsGameTime) + 0.9 * Double(0.15))
                + (0.2 * Double(0.15)) * Double(visibilityFraction)
        )
        XCTAssertEqual(
            Float(try XCTUnwrap(firstState["nextVisibilityCheckTime"] as? Double)),
            expectedVisibilityTime
        )
        XCTAssertEqual(
            expectedVisibilityTime - firstAttempt.systemsGameTime,
            0.135_037_541_389_465_33,
            accuracy: 0.000_001
        )
        let jointStep = Float(0.1) * (Float(0.125) * Float(0.7))
        XCTAssertEqual(jointStep, 0.008_75)
        XCTAssertEqual(firstAttempt.trainingDodgeTurretAngles[0], 0)
        XCTAssertEqual(
            min(
                abs(firstAttempt.trainingDodgeTurretAngles[1]),
                abs(1 - firstAttempt.trainingDodgeTurretAngles[1])
            ),
            jointStep,
            accuracy: 0.000_001
        )
        assertVector(
            try vector(firstState["retainedTargetPosition"]),
            firstAttempt.playerView.camera.position
        )
        XCTAssertEqual(firstState["weaponSpeed"] as? Double, 0)
        XCTAssertEqual(firstState["firingMaskIndex"] as? Int, 0)
        XCTAssertTrue(firstAttempt.trainingDodgeProjectiles.isEmpty)

        var capturedFireFrame: PlayerSimulationFrame?
        for _ in 0..<20 {
            timestamp += 0.01
            let candidate = simulation.update(at: timestamp, input: .zero)
            let candidateState = try dodgeState(simulation)
            if try randomState(simulation) == 0x0029_e2c0 {
                XCTAssertEqual(candidateState["weaponSpeed"] as? Double, 0)
                XCTAssertEqual(candidateState["firingMaskIndex"] as? Int, 0)
                XCTAssertEqual(
                    Float(try XCTUnwrap(
                        candidateState["nextFireTime"] as? Double
                    )),
                    instructionFrame.systemsGameTime
                )
                XCTAssertEqual(
                    Float(try XCTUnwrap(
                        candidateState["nextVisibilityCheckTime"] as? Double
                    )),
                    expectedVisibilityTime
                )
                XCTAssertTrue(candidate.trainingDodgeProjectiles.isEmpty)
                continue
            }
            capturedFireFrame = candidate
            break
        }
        let fireFrame = try XCTUnwrap(capturedFireFrame)
        let fireState = try dodgeState(simulation)
        let firstRandomState = try randomState(simulation)
        XCTAssertEqual(firstRandomState, 0xe784_7115)
        XCTAssertEqual(fireState["weaponSpeed"] as? Double, 200)
        XCTAssertEqual(fireState["firingMaskIndex"] as? Int, 1)
        XCTAssertEqual(
            Float(try XCTUnwrap(fireState["nextFireTime"] as? Double)),
            instructionFrame.systemsGameTime + dodge.turret.fireWait
        )

        let spread = 2_515
        let halfSpread = 1_257
        let pitch = Int(18_467 % UInt32(spread)) - halfSpread
        let heading = Int(6_334 % UInt32(spread)) - halfSpread
        let bank = Int(26_500 % UInt32(spread)) - halfSpread
        XCTAssertEqual((pitch, heading, bank).0, -395)
        XCTAssertEqual((pitch, heading, bank).1, 47)
        XCTAssertEqual((pitch, heading, bank).2, 93)

        let projectile = try XCTUnwrap(
            fireFrame.trainingDodgeProjectiles.first
        )
        XCTAssertEqual(magnitude(projectile.velocity), 150, accuracy: 0.001)
        let expectedFirstDirection = Vector3(
            x: 0.002_732_447,
            y: -0.586_422_86,
            z: -0.810_000_5
        )
        assertVector(
            scaled(projectile.velocity, to: 1),
            expectedFirstDirection,
            accuracy: 0.000_01
        )
        let encodedProjectile = try XCTUnwrap(
            try XCTUnwrap(fireState["projectiles"] as? [[String: Any]]).first
        )
        XCTAssertEqual(
            Set(encodedProjectile.keys),
            Set(["roomSourceIndex", "position", "velocity", "lifeRemaining"])
        )
        assertVector(
            projectile.position,
            .init(
                x: 2_061.215_3,
                y: -707.162_9,
                z: 2_352.224
            ),
            accuracy: 0.001
        )

        let newContinuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let newContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: newContinuationData
        )
        let restoredNew = try PlayerSimulation(
            level: level,
            continuation: newContinuation,
            resumedAtTimestamp: timestamp + 1
        )
        let restoredNewState = try dodgeState(restoredNew)
        let restoredNewProjectile = try XCTUnwrap(
            try XCTUnwrap(
                restoredNewState["projectiles"] as? [[String: Any]]
            ).first
        )
        XCTAssertEqual(
            magnitude(try vector(restoredNewProjectile["velocity"])),
            150,
            accuracy: 0.001
        )

        var legacyObject = try continuationObject(simulation)
        var legacyState = try XCTUnwrap(
            legacyObject["trainingDodgeAttemptState"] as? [String: Any]
        )
        var legacyProjectiles = try XCTUnwrap(
            legacyState["projectiles"] as? [[String: Any]]
        )
        let liveVelocity = try vector(legacyProjectiles[0]["velocity"])
        let legacyVelocity = scaled(liveVelocity, to: 200)
        legacyProjectiles[0]["velocity"] = [
            "x": legacyVelocity.x,
            "y": legacyVelocity.y,
            "z": legacyVelocity.z,
        ]
        legacyState["projectiles"] = legacyProjectiles
        legacyObject["trainingDodgeAttemptState"] = legacyState
        let legacyContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )
        let restoredLegacy = try PlayerSimulation(
            level: level,
            continuation: legacyContinuation,
            resumedAtTimestamp: timestamp + 2
        )
        let restoredLegacyProjectile = try XCTUnwrap(
            try XCTUnwrap(
                try dodgeState(restoredLegacy)["projectiles"]
                    as? [[String: Any]]
            ).first
        )
        XCTAssertEqual(
            magnitude(try vector(restoredLegacyProjectile["velocity"])),
            200,
            accuracy: 0.001
        )

        var hostileObject = legacyObject
        var hostileState = legacyState
        var hostileProjectiles = legacyProjectiles
        let hostileVelocity = scaled(liveVelocity, to: 175)
        hostileProjectiles[0]["velocity"] = [
            "x": hostileVelocity.x,
            "y": hostileVelocity.y,
            "z": hostileVelocity.z,
        ]
        hostileState["projectiles"] = hostileProjectiles
        hostileObject["trainingDodgeAttemptState"] = hostileState
        let hostileContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostileContinuation,
                resumedAtTimestamp: timestamp + 3
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var leadFrame: PlayerSimulationFrame?
        var leadState: [String: Any]?
        for _ in 0..<4 {
            timestamp += 0.1
            let frame = simulation.update(
                at: timestamp,
                input: .init(sideways: 1)
            )
            if try randomState(simulation) != firstRandomState {
                leadFrame = frame
                leadState = try dodgeState(simulation)
                break
            }
        }
        let laterFrame = try XCTUnwrap(leadFrame)
        let laterState = try XCTUnwrap(leadState)
        XCTAssertEqual(try randomState(simulation), 0xcae1_df84)
        let playerPosition = laterFrame.playerView.camera.position
        let toTarget = Vector3(
            x: playerPosition.x - turret.position.x,
            y: playerPosition.y - turret.position.y,
            z: playerPosition.z - turret.position.z
        )
        let targetDistance = magnitude(toTarget)
        let targetDirection = scaled(toTarget, to: 1)
        let closingSpeed = 200
            - (targetDirection.x * laterFrame.velocity.x
                + targetDirection.y * laterFrame.velocity.y
                + targetDirection.z * laterFrame.velocity.z)
        let leadDuration = targetDistance / closingSpeed
            * dodge.turret.fixedLeadAccuracy
        let expectedLead = Vector3(
            x: playerPosition.x + laterFrame.velocity.x * leadDuration,
            y: playerPosition.y + laterFrame.velocity.y * leadDuration,
            z: playerPosition.z + laterFrame.velocity.z * leadDuration
        )
        assertVector(
            try vector(laterState["retainedTargetPosition"]),
            expectedLead,
            accuracy: 0.000_1
        )
        XCTAssertEqual(laterState["weaponSpeed"] as? Double, 200)
    }

    @MainActor
    func testTimedDodgeUsesRealTurretHitAndReleasedTimerOrder() throws {
        var level = makeTrainingDodgeAttemptLevel()
        let dodge = try XCTUnwrap(level.trainingDodgeAttempt)
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == level.defaultPlayerBinding?.objectHandle
            })
        let start = try XCTUnwrap(
            level.objects.first {
                $0.handle == dodge.startDodgeObjectHandle
            })
        level.objects[playerIndex].location = start.location
        level.objects[playerIndex].position = start.position

        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var frame = simulation.update(at: 0.1, input: .zero)
        XCTAssertEqual(frame.enabledPlayerControls.rawValue, 60)
        XCTAssertEqual(
            frame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [dodge.introduction],
                    voiceSourceName:
                        dodge.introductionVoiceSourceName,
                    voicePrecedesHUDMessages: true
                )
            ]
        )
        let closedPortalRoomTwo = try XCTUnwrap(
            simulation.level.rooms.first {
                $0.sourceIndex == dodge.portalRoomTwoSourceIndex
            }
        )
        XCTAssertTrue(
            dodge.orderedPortalIndices.allSatisfy {
                closedPortalRoomTwo.portals[$0].flags & 1 != 0
            }
        )

        var timestamp = 0.1
        var sawInstruction = false
        var capturedFirstHitFrame: PlayerSimulationFrame?
        var hitCount = 0
        for _ in 0..<280 {
            timestamp += 0.1
            frame = simulation.update(at: timestamp, input: .zero)
            sawInstruction =
                sawInstruction
                || frame.trainingOpeningFeedback.contains {
                    $0.hudMessages == [dodge.instruction]
                }
            let frameHitCount = frame.trainingOpeningFeedback.count {
                $0.hudMessages == [dodge.hitInstruction]
            }
            if frameHitCount > 0 {
                if capturedFirstHitFrame == nil {
                    capturedFirstHitFrame = frame
                }
                hitCount += frameHitCount
                if hitCount >= 2 { break }
            }
        }
        XCTAssertTrue(sawInstruction)
        XCTAssertEqual(hitCount, 2)
        let firstHitFrame = try XCTUnwrap(capturedFirstHitFrame)
        XCTAssertEqual(firstHitFrame.shields, 100)
        let impactIndex = try XCTUnwrap(
            firstHitFrame.trainingOpeningFeedback.firstIndex {
                $0.soundSourceName == dodge.turret.impactSoundSourceName
            }
        )
        let resetIndex = try XCTUnwrap(
            firstHitFrame.trainingOpeningFeedback.firstIndex {
                $0.hudMessages == [dodge.hitInstruction]
            }
        )
        XCTAssertLessThan(impactIndex, resetIndex)
        XCTAssertEqual(frame.shields, 100)

        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        let dodgeState = try XCTUnwrap(
            continuationObject["trainingDodgeAttemptState"]
                as? [String: Any]
        )
        XCTAssertEqual(dodgeState["script033Count"] as? Int, 1)
        XCTAssertEqual(dodgeState["script016Count"] as? Int, 1)
        XCTAssertEqual(dodgeState["script017Count"] as? Int, 0)
        XCTAssertEqual(dodgeState["script018Count"] as? Int, 2)
        XCTAssertEqual(
            try XCTUnwrap(
                dodgeState["almostDoneTimerRemaining"] as? Double
            ),
            Double(dodge.almostDoneDelay),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                dodgeState["successTimerRemaining"] as? Double
            ),
            Double(dodge.successDelay),
            accuracy: 0.000_001
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: simulation.continuation,
            resumedAtTimestamp: timestamp + 1
        )
        let restoredFrame = restored.update(
            at: timestamp + 1.1,
            input: .zero
        )
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.shields, 100)

        var hostileContinuationObject = continuationObject
        var hostileDodgeState = dodgeState
        hostileDodgeState["turretAngles"] = [2, 0]
        hostileContinuationObject["trainingDodgeAttemptState"] =
            hostileDodgeState
        let hostileContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: hostileContinuationObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostileContinuation,
                resumedAtTimestamp: timestamp + 2
            )
        )

        hostileDodgeState = dodgeState
        hostileDodgeState["projectiles"] = [
            [
                "roomSourceIndex": 35,
                "position": [
                    "x": 2_061.69,
                    "y": -701.7448,
                    "z": 2_356.2942,
                ],
                "velocity": ["x": 0, "y": 0, "z": 0],
                "lifeRemaining": 1,
            ]
        ]
        hostileContinuationObject["trainingDodgeAttemptState"] =
            hostileDodgeState
        let hostileProjectileContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: hostileContinuationObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostileProjectileContinuation,
                resumedAtTimestamp: timestamp + 2
            )
        )
    }

    @MainActor
    func testTimedDodgeMovementReachesAlmostDoneAndSuccess() throws {
        var level = makeTrainingDodgeAttemptLevel()
        let dodge = try XCTUnwrap(level.trainingDodgeAttempt)
        let dodgeRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == 35
            })
        let dodgeRoomVertices = level.rooms[dodgeRoomIndex].vertices
        let dodgeRoomCenter = Vector3(
            x: dodgeRoomVertices.map(\.x).reduce(0, +)
                / Float(dodgeRoomVertices.count),
            y: dodgeRoomVertices.map(\.y).reduce(0, +)
                / Float(dodgeRoomVertices.count),
            z: dodgeRoomVertices.map(\.z).reduce(0, +)
                / Float(dodgeRoomVertices.count)
        )
        level.rooms[dodgeRoomIndex].vertices =
            level.rooms[dodgeRoomIndex].vertices.map {
                .init(
                    x: dodgeRoomCenter.x
                        + ($0.x - dodgeRoomCenter.x) * 100,
                    y: dodgeRoomCenter.y
                        + ($0.y - dodgeRoomCenter.y) * 100,
                    z: dodgeRoomCenter.z
                        + ($0.z - dodgeRoomCenter.z) * 100
                )
            }
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == level.defaultPlayerBinding?.objectHandle
            })
        let start = try XCTUnwrap(
            level.objects.first {
                $0.handle == dodge.startDodgeObjectHandle
            })
        level.objects[playerIndex].location = start.location
        level.objects[playerIndex].position = start.position
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        var fireCount = 0
        var sawInstruction = false
        var sawAlmostDone = false
        var sawSuccess = false
        var successFrame: PlayerSimulationFrame?
        for _ in 0..<500 {
            timestamp += 0.1
            let input: InputSnapshot =
                sawInstruction ? .init(sideways: 1) : .zero
            let frame = simulation.update(at: timestamp, input: input)
            sawInstruction =
                sawInstruction
                || frame.trainingOpeningFeedback.contains {
                    $0.hudMessages == [dodge.instruction]
                }
            fireCount += frame.trainingOpeningFeedback.count {
                $0.soundSourceName
                    == dodge.turret.fireSoundSourceName
            }
            sawAlmostDone =
                sawAlmostDone
                || frame.trainingOpeningFeedback.contains {
                    $0.hudMessages == [dodge.almostDoneInstruction]
                        && $0.voiceSourceName
                            == dodge.almostDoneVoiceSourceName
                }
            if frame.trainingOpeningFeedback.contains(where: {
                $0.hudMessages
                    == [dodge.successMessage, dodge.leaveInstruction]
                    && $0.voiceSourceName
                        == dodge.successVoiceSourceName
            }) {
                sawSuccess = true
                successFrame = frame
                break
            }
        }

        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        let dodgeState = try XCTUnwrap(
            continuationObject["trainingDodgeAttemptState"]
                as? [String: Any]
        )
        XCTAssertGreaterThan(fireCount, 0)
        XCTAssertTrue(sawInstruction)
        XCTAssertTrue(sawAlmostDone)
        XCTAssertTrue(sawSuccess, "final dodge state: \(dodgeState)")
        XCTAssertEqual(
            successFrame?.trainingDodgeMarkerLightDistance,
            50
        )
        XCTAssertEqual(successFrame?.enabledPlayerControls.rawValue, 63)
        let portalRoomThree = try XCTUnwrap(
            simulation.level.rooms.first {
                $0.sourceIndex == dodge.portalRoomThreeSourceIndex
            }
        )
        XCTAssertTrue(
            dodge.orderedPortalIndices.allSatisfy {
                portalRoomThree.portals[$0].flags & 1 == 0
            }
        )
        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        var hostileDodgeState = try XCTUnwrap(
            hostileObject["trainingDodgeAttemptState"] as? [String: Any]
        )
        hostileObject["playerLocation"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(start.location)
        )
        hostileObject["playerPosition"] = [
            "x": dodgeRoomCenter.x,
            "y": dodgeRoomCenter.y,
            "z": dodgeRoomCenter.z,
        ]
        hostileObject["playerOrientation"] =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(start.orientation)
            )
        let restorableContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertNoThrow(
            try PlayerSimulation(
                level: level,
                continuation: restorableContinuation,
                resumedAtTimestamp: timestamp + 1
            )
        )

        let done = try XCTUnwrap(
            level.objects.first {
                $0.handle == dodge.doneDodgeingGoalObjectHandle
            }
        )
        hostileObject["playerLocation"] =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(done.location)
            )
        hostileObject["playerPosition"] =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(done.position)
            )
        let normalExitContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        let normalExitSimulation = try PlayerSimulation(
            level: level,
            continuation: normalExitContinuation,
            resumedAtTimestamp: timestamp + 2
        )
        let normalExitFrame = normalExitSimulation.update(
            at: timestamp + 2.1,
            input: .zero
        )
        let exit = try XCTUnwrap(dodge.dodgeExit)
        XCTAssertEqual(
            normalExitFrame.enabledPlayerControls.rawValue,
            1
        )
        XCTAssertEqual(
            normalExitFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [exit.instruction],
                    voiceSourceName: exit.voiceSourceName,
                    voicePrecedesHUDMessages: true
                )
            ]
        )
        let normalExitState = try encodedDodgeState(
            normalExitSimulation.continuation
        )
        XCTAssertEqual(normalExitState["script017Count"] as? Int, 1)
        XCTAssertEqual(normalExitState["script019Count"] as? Int, 1)
        let restoredNormalExit = try PlayerSimulation(
            level: level,
            continuation: normalExitSimulation.continuation,
            resumedAtTimestamp: timestamp + 3
        )
        let restoredNormalExitFrame = restoredNormalExit.update(
            at: timestamp + 3.1,
            input: .zero
        )
        XCTAssertTrue(
            restoredNormalExitFrame.trainingOpeningFeedback.isEmpty
        )
        XCTAssertEqual(
            restoredNormalExitFrame.enabledPlayerControls.rawValue,
            1
        )

        hostileDodgeState["script033Count"] = 0
        hostileObject["trainingDodgeAttemptState"] = hostileDodgeState
        let hostileContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostileContinuation,
                resumedAtTimestamp: timestamp + 1
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    @MainActor
    func testTimedDodgeContinuationRejectsCounterAboveReleasedMaximum()
        throws
    {
        var level = makeTrainingDodgeAttemptLevel()
        let dodge = try XCTUnwrap(level.trainingDodgeAttempt)
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == level.defaultPlayerBinding?.objectHandle
            }
        )
        let start = try XCTUnwrap(
            level.objects.first {
                $0.handle == dodge.startDodgeObjectHandle
            }
        )
        level.objects[playerIndex].location = start.location
        level.objects[playerIndex].position = start.position
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var timestamp: TimeInterval = 0.1
        _ = simulation.update(at: timestamp, input: .zero)
        var sawInstruction = false
        for _ in 0..<110 {
            timestamp += 0.1
            let frame = simulation.update(at: timestamp, input: .zero)
            if frame.trainingOpeningFeedback.contains(where: {
                $0.hudMessages == [dodge.instruction]
            }) {
                sawInstruction = true
                break
            }
        }
        XCTAssertTrue(sawInstruction)
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        var dodgeState = try XCTUnwrap(
            continuationObject["trainingDodgeAttemptState"]
                as? [String: Any]
        )
        dodgeState["script018Count"] = 100_001
        continuationObject["trainingDodgeAttemptState"] = dodgeState
        let hostile = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: continuationObject
            )
        )

        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostile,
                resumedAtTimestamp: timestamp + 1
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    @MainActor
    func testTimedDodgeRestoreKeepsForwardAndReverseDisabled()
        throws
    {
        var level = makeTrainingDodgeAttemptLevel()
        let dodge = try XCTUnwrap(level.trainingDodgeAttempt)
        let startCourse = try XCTUnwrap(
            level.trainingOpeningLesson?.startCourse
        )
        let startDodgeIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == dodge.startDodgeObjectHandle
            }
        )
        let startCourseIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == startCourse.startCourseObjectHandle
            }
        )
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == level.defaultPlayerBinding?.objectHandle
            }
        )
        level.objects[playerIndex].location =
            level.objects[startCourseIndex].location
        level.objects[playerIndex].position =
            level.objects[startCourseIndex].position
        let startCourseRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 3 }
        )
        level.rooms[startCourseRoomIndex] = addingSourceContainmentShell(
            to: level.rooms[startCourseRoomIndex],
            center: level.objects[startCourseIndex].position,
            texture: level.surfacePhysics[0].texture,
            halfExtent: 200
        )

        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        let startCourseFrame = simulation.update(at: 0.1, input: .zero)
        XCTAssertEqual(
            startCourseFrame.enabledPlayerControls.rawValue & 63,
            63
        )
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        continuationObject["playerLocation"] =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    level.objects[startDodgeIndex].location
                )
            )
        continuationObject["playerPosition"] =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    level.objects[startDodgeIndex].position
                )
            )
        let movedToDodge = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: continuationObject
            )
        )
        let atDodge = try PlayerSimulation(
            level: level,
            continuation: movedToDodge,
            resumedAtTimestamp: 1
        )
        let contactFrame = atDodge.update(at: 1.1, input: .zero)
        XCTAssertEqual(contactFrame.enabledPlayerControls.rawValue & 63, 60)

        let restored = try PlayerSimulation(
            level: level,
            continuation: atDodge.continuation,
            resumedAtTimestamp: 2
        )
        let restoredFrame = restored.update(at: 2.1, input: .zero)
        XCTAssertEqual(
            restoredFrame.enabledPlayerControls.rawValue & 63,
            60
        )
    }

    @MainActor
    func testTimedDodgeTimersStartWithTheirFullDurations() throws {
        var level = makeTrainingDodgeAttemptLevel()
        let dodge = try XCTUnwrap(level.trainingDodgeAttempt)
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == level.defaultPlayerBinding?.objectHandle
            }
        )
        let start = try XCTUnwrap(
            level.objects.first {
                $0.handle == dodge.startDodgeObjectHandle
            }
        )
        level.objects[playerIndex].location = start.location
        level.objects[playerIndex].position = start.position
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp: TimeInterval = 0.1
        _ = simulation.update(at: timestamp, input: .zero)
        var dodgeState = try encodedDodgeState(simulation.continuation)
        XCTAssertEqual(
            try XCTUnwrap(dodgeState["triggerTimerRemaining"] as? Double),
            Double(dodge.triggerDelay),
            accuracy: 0.000_001
        )

        var sawInstruction = false
        for _ in 0..<110 {
            timestamp += 0.1
            let frame = simulation.update(at: timestamp, input: .zero)
            if frame.trainingOpeningFeedback.contains(where: {
                $0.hudMessages == [dodge.instruction]
            }) {
                sawInstruction = true
                dodgeState = try encodedDodgeState(
                    simulation.continuation
                )
                XCTAssertEqual(
                    try XCTUnwrap(
                        dodgeState["almostDoneTimerRemaining"]
                            as? Double
                    ),
                    Double(dodge.almostDoneDelay),
                    accuracy: 0.000_001
                )
                XCTAssertEqual(
                    try XCTUnwrap(
                        dodgeState["successTimerRemaining"] as? Double
                    ),
                    Double(dodge.successDelay),
                    accuracy: 0.000_001
                )
                break
            }
        }
        XCTAssertTrue(sawInstruction)

        var sawRealHit = false
        for _ in 0..<160 {
            timestamp += 0.1
            let frame = simulation.update(at: timestamp, input: .zero)
            if frame.trainingOpeningFeedback.contains(where: {
                $0.hudMessages == [dodge.hitInstruction]
            }) {
                sawRealHit = true
                dodgeState = try encodedDodgeState(
                    simulation.continuation
                )
                XCTAssertEqual(
                    try XCTUnwrap(
                        dodgeState["almostDoneTimerRemaining"]
                            as? Double
                    ),
                    Double(dodge.almostDoneDelay),
                    accuracy: 0.000_001
                )
                XCTAssertEqual(
                    try XCTUnwrap(
                        dodgeState["successTimerRemaining"] as? Double
                    ),
                    Double(dodge.successDelay),
                    accuracy: 0.000_001
                )
                break
            }
        }
        XCTAssertTrue(sawRealHit)
    }

private func encodedDodgeState(
    _ continuation: PlayerSimulationContinuation
) throws -> [String: Any] {
    let continuationObject = try XCTUnwrap(
        JSONSerialization.jsonObject(
            with: JSONEncoder().encode(continuation)
        ) as? [String: Any]
    )
    return try XCTUnwrap(
        continuationObject["trainingDodgeAttemptState"]
            as? [String: Any]
    )
}
}
