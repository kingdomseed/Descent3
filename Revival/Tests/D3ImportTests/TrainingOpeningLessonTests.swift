import XCTest

extension WorldRenderingTests {
    @MainActor
    func testTrainingScript015FinishesCourseIndependentlyAndRestoresSilently()
        throws
    {
        let level = makeTrainingScript015Level()
        let finishCourse = try XCTUnwrap(
            level.trainingOpeningLesson?.finishCourse
        )

        XCTAssertEqual(finishCourse.finishCourseObjectHandle, 6_150)
        XCTAssertEqual(finishCourse.portalRoomSourceIndex, 49)
        XCTAssertEqual(finishCourse.orderedPortalIndices, [0, 1])
        XCTAssertEqual(finishCourse.enabledControlMask, 32)
        XCTAssertEqual(finishCourse.successMessage, "Excellent!")
        XCTAssertEqual(
            finishCourse.instruction,
            "Continue Sliding down to start the next step."
        )
        XCTAssertEqual(finishCourse.voiceSourceName, "proceed2.osf")

        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        let finishIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == finishCourse.finishCourseObjectHandle
            }
        )
        var objects = level.objects
        objects[playerIndex].position = objects[finishIndex].position
        objects[playerIndex].location = objects[finishIndex].location
        var rooms = level.rooms
        let portalRoomIndex = try XCTUnwrap(
            rooms.firstIndex {
                $0.sourceIndex == finishCourse.portalRoomSourceIndex
            }
        )
        let portalRoomOneIndex = try XCTUnwrap(
            rooms.firstIndex { $0.sourceIndex == 2 }
        )
        let portalRoomOneFlags = rooms[portalRoomOneIndex].portals.map(\.flags)
        var originalPortalFlags: [UInt32] = []
        var originalReciprocalFlags: [UInt32] = []
        for (offset, portalIndex) in
            finishCourse.orderedPortalIndices.enumerated()
        {
            let unrelated = UInt32(1) << UInt32(offset + 6)
            rooms[portalRoomIndex].portals[portalIndex].flags |= unrelated
            let portal = rooms[portalRoomIndex].portals[portalIndex]
            let connectedIndex = try XCTUnwrap(
                rooms.firstIndex { $0.sourceIndex == portal.connectedRoom }
            )
            rooms[connectedIndex]
                .portals[portal.connectedPortal].flags |= unrelated << 2
            originalPortalFlags.append(
                rooms[portalRoomIndex].portals[portalIndex].flags
            )
            originalReciprocalFlags.append(
                rooms[connectedIndex]
                    .portals[portal.connectedPortal].flags
            )
        }
        let baseLevel = replacing(level, rooms: rooms)
        let contactLevel = replacing(
            baseLevel,
            rooms: rooms,
            objects: objects
        )
        let simulation = PlayerSimulation(
            level: contactLevel,
            presentationReadyTimestamp: 0
        )
        let frame = simulation.update(at: 0.05, input: .zero)

        XCTAssertEqual(
            frame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Excellent!"],
                    voiceSourceName: "proceed2.osf",
                    voicePrecedesHUDMessages: false,
                    trailingHUDMessages: [
                        "Continue Sliding down to start the next step.",
                    ]
                ),
            ]
        )
        XCTAssertEqual(frame.enabledPlayerControls, [.down])
        XCTAssertEqual(frame.enabledPlayerControls.rawValue, 32)
        let unchangedPortalRoomOne = try XCTUnwrap(
            simulation.level.rooms.first { $0.sourceIndex == 2 }
        )
        XCTAssertEqual(
            unchangedPortalRoomOne.portals.map(\.flags),
            portalRoomOneFlags
        )
        let openedRoom = try XCTUnwrap(
            simulation.level.rooms.first {
                $0.sourceIndex == finishCourse.portalRoomSourceIndex
            }
        )
        for (offset, portalIndex) in
            finishCourse.orderedPortalIndices.enumerated()
        {
            let portal = openedRoom.portals[portalIndex]
            XCTAssertEqual(
                portal.flags,
                originalPortalFlags[offset] & ~UInt32(1)
            )
            let connected = try XCTUnwrap(
                simulation.level.rooms.first {
                    $0.sourceIndex == portal.connectedRoom
                }
            )
            XCTAssertEqual(
                connected.portals[portal.connectedPortal].flags,
                originalReciprocalFlags[offset] & ~UInt32(1)
            )
        }

        var presentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            frame.trainingOpeningFeedback,
            attemptVoice: {
                presentationOrder.append("voice:\($0)")
            },
            attemptSound: { _, _ in
                XCTFail("Script 015 does not play a sound")
            },
            presentHUDMessages: {
                presentationOrder.append(
                    contentsOf: $0.map { "hud:\($0)" }
                )
            }
        )
        XCTAssertEqual(
            presentationOrder,
            [
                "hud:Excellent!",
                "voice:proceed2.osf",
                "hud:Continue Sliding down to start the next step.",
            ]
        )

        let restored = try PlayerSimulation(
            level: baseLevel,
            continuation: try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(simulation.continuation)
            ),
            resumedAtTimestamp: 1
        )
        let restoredFrame = restored.update(at: 1.05, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls.rawValue, 32)

        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        var hostileOpening = try XCTUnwrap(
            continuationObject["trainingOpeningState"] as? [String: Any]
        )
        hostileOpening["enabledControls"] = 33
        continuationObject["trainingOpeningState"] = hostileOpening
        let hostile = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: continuationObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: baseLevel,
                continuation: hostile,
                resumedAtTimestamp: 2
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var compatibleLesson = try XCTUnwrap(
            baseLevel.trainingOpeningLesson
        )
        compatibleLesson.finishCourse = nil
        let compatibleLevel = replacing(
            baseLevel,
            trainingOpeningLesson: compatibleLesson
        )
        XCTAssertNoThrow(try compatibleLevel.validate())
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: compatibleLevel,
                continuation: simulation.continuation,
                resumedAtTimestamp: 2.5
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var laterStartObjects = baseLevel.objects
        let laterStartIndex = try XCTUnwrap(
            laterStartObjects.firstIndex { $0.handle == 6_147 }
        )
        laterStartObjects[laterStartIndex].position =
            simulation.continuation.playerPosition
        laterStartObjects[laterStartIndex].location =
            simulation.continuation.playerLocation
        let laterStart = try PlayerSimulation(
            level: replacing(baseLevel, objects: laterStartObjects),
            continuation: simulation.continuation,
            resumedAtTimestamp: 3
        )
        let laterStartFrame = laterStart.update(
            at: 3.05,
            input: .zero
        )
        XCTAssertEqual(laterStartFrame.enabledPlayerControls.rawValue, 63)
        let laterStartPortalRoomTwo = try XCTUnwrap(
            laterStart.level.rooms.first { $0.sourceIndex == 49 }
        )
        XCTAssertTrue(
            laterStartPortalRoomTwo.portals.allSatisfy { $0.flags & 1 == 0 }
        )

        var normalRooms = level.rooms
        let normalPortalRoomOneIndex = try XCTUnwrap(
            normalRooms.firstIndex { $0.sourceIndex == 2 }
        )
        let normalPortalZero =
            normalRooms[normalPortalRoomOneIndex].portals[0]
        normalRooms[normalPortalRoomOneIndex].portals[0].flags &= ~UInt32(1)
        let normalPortalZeroConnectedIndex = try XCTUnwrap(
            normalRooms.firstIndex {
                $0.sourceIndex == normalPortalZero.connectedRoom
            }
        )
        normalRooms[normalPortalZeroConnectedIndex]
            .portals[normalPortalZero.connectedPortal].flags &= ~UInt32(1)
        let startCourse = try XCTUnwrap(
            level.trainingOpeningLesson?.startCourse
        )
        var normalObjects = level.objects
        let normalPlayerIndex = try XCTUnwrap(
            normalObjects.firstIndex { $0.handle == 2_048 }
        )
        let normalStartIndex = try XCTUnwrap(
            normalObjects.firstIndex {
                $0.handle == startCourse.startCourseObjectHandle
            }
        )
        normalObjects[normalPlayerIndex].position =
            normalObjects[normalStartIndex].position
        normalObjects[normalPlayerIndex].location =
            normalObjects[normalStartIndex].location
        let roomThreeIndex = try XCTUnwrap(
            normalRooms.firstIndex { $0.sourceIndex == 3 }
        )
        normalRooms[roomThreeIndex] = addingSourceContainmentShell(
            to: normalRooms[roomThreeIndex],
            center: normalObjects[normalStartIndex].position,
            texture: level.surfacePhysics[0].texture,
            halfExtent: 200
        )
        let normalStart = PlayerSimulation(
            level: replacing(
                level,
                rooms: normalRooms,
                objects: normalObjects
            ),
            presentationReadyTimestamp: 4
        )
        let normalStartFrame = normalStart.update(at: 4.05, input: .zero)
        XCTAssertEqual(
            normalStartFrame.enabledPlayerControls.rawValue,
            63
        )
        var highBitContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(normalStart.continuation)
            ) as? [String: Any]
        )
        var highBitOpening = try XCTUnwrap(
            highBitContinuationObject["trainingOpeningState"]
                as? [String: Any]
        )
        highBitOpening["enabledControls"] = 127
        highBitContinuationObject["trainingOpeningState"] = highBitOpening
        let highBitContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: highBitContinuationObject
            )
        )
        var normalFinishObjects = level.objects
        let normalFinishIndex = try XCTUnwrap(
            normalFinishObjects.firstIndex {
                $0.handle == finishCourse.finishCourseObjectHandle
            }
        )
        normalFinishObjects[normalFinishIndex].position =
            highBitContinuation.playerPosition
        normalFinishObjects[normalFinishIndex].location =
            highBitContinuation.playerLocation
        let normalFinish = try PlayerSimulation(
            level: replacing(
                level,
                rooms: normalRooms,
                objects: normalFinishObjects
            ),
            continuation: highBitContinuation,
            resumedAtTimestamp: 5
        )
        let normalFinishFrame = normalFinish.update(
            at: 5.05,
            input: .zero
        )
        XCTAssertEqual(
            normalFinishFrame.enabledPlayerControls.rawValue,
            32
        )
        let normalPortalRoomOne = try XCTUnwrap(
            normalFinish.level.rooms.first { $0.sourceIndex == 2 }
        )
        XCTAssertEqual(normalPortalRoomOne.portals[0].flags & 1, 0)
        XCTAssertNotEqual(normalPortalRoomOne.portals[1].flags & 1, 0)
        let normalPortalRoomTwo = try XCTUnwrap(
            normalFinish.level.rooms.first { $0.sourceIndex == 49 }
        )
        XCTAssertTrue(
            normalPortalRoomTwo.portals.allSatisfy { $0.flags & 1 == 0 }
        )
    }

    @MainActor
    func testTrainingScript014StartsCourseWithoutScript013AndRestoresSilently()
        throws
    {
        let level = makeTrainingScript003Level()
        let startCourse = try XCTUnwrap(
            level.trainingOpeningLesson?.startCourse
        )
        XCTAssertEqual(startCourse.startCourseObjectHandle, 6_147)
        XCTAssertEqual(startCourse.portalRoomSourceIndex, 2)
        XCTAssertEqual(startCourse.portalIndex, 1)
        XCTAssertEqual(
            startCourse.instruction,
            "Now, manuever through this tunnel using the sliding skills you just learned."
        )
        XCTAssertEqual(startCourse.voiceSourceName, "intro1.osf")

        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        let startCourseIndex = try XCTUnwrap(
            level.objects.firstIndex {
                $0.handle == startCourse.startCourseObjectHandle
            }
        )
        var objects = level.objects
        objects[playerIndex].position = objects[startCourseIndex].position
        objects[playerIndex].location = objects[startCourseIndex].location

        let portalRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == startCourse.portalRoomSourceIndex
            }
        )
        var rooms = level.rooms
        let portal = rooms[portalRoomIndex].portals[startCourse.portalIndex]
        let reciprocalRoomIndex = try XCTUnwrap(
            rooms.firstIndex { $0.sourceIndex == portal.connectedRoom }
        )
        rooms[portalRoomIndex].portals[startCourse.portalIndex].flags |= 0x40
        rooms[reciprocalRoomIndex]
            .portals[portal.connectedPortal].flags |= 0x80
        let startCourseRoomIndex = try XCTUnwrap(
            rooms.firstIndex { $0.sourceIndex == 3 }
        )
        rooms[startCourseRoomIndex] = addingSourceContainmentShell(
            to: rooms[startCourseRoomIndex],
            center: objects[startCourseIndex].position,
            texture: level.surfacePhysics[0].texture,
            halfExtent: 200
        )
        let baseLevel = replacing(level, rooms: rooms)
        let contactLevel = replacing(
            baseLevel,
            rooms: rooms,
            objects: objects
        )
        let simulation = PlayerSimulation(
            level: contactLevel,
            presentationReadyTimestamp: 0
        )
        let frame = simulation.update(at: 0.05, input: .zero)

        XCTAssertEqual(
            frame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [startCourse.instruction],
                    voiceSourceName: startCourse.voiceSourceName,
                    voicePrecedesHUDMessages: false
                ),
            ]
        )
        XCTAssertEqual(
            frame.enabledPlayerControls.rawValue,
            UInt32(63)
        )
        let closedRoom = try XCTUnwrap(
            simulation.level.rooms.first {
                $0.sourceIndex == startCourse.portalRoomSourceIndex
            }
        )
        XCTAssertEqual(
            closedRoom.portals[startCourse.portalIndex].flags & 0x41,
            0x41
        )
        let closedPortal = closedRoom.portals[startCourse.portalIndex]
        let closedReciprocalRoom = try XCTUnwrap(
            simulation.level.rooms.first {
                $0.sourceIndex == closedPortal.connectedRoom
            }
        )
        XCTAssertEqual(
            closedReciprocalRoom
                .portals[closedPortal.connectedPortal].flags & 0x81,
            0x81
        )
        XCTAssertNotEqual(closedRoom.portals[0].flags & 1, 0)

        var presentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            frame.trainingOpeningFeedback,
            attemptVoice: {
                presentationOrder.append("voice:\($0)")
            },
            attemptSound: { _, _ in
                XCTFail("Script 014 does not play a sound")
            },
            presentHUDMessages: {
                presentationOrder.append(
                    contentsOf: $0.map { "hud:\($0)" }
                )
            }
        )
        XCTAssertEqual(
            presentationOrder,
            [
                "hud:\(startCourse.instruction)",
                "voice:intro1.osf",
            ]
        )

        let restored = try PlayerSimulation(
            level: baseLevel,
            continuation: try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(simulation.continuation)
            ),
            resumedAtTimestamp: 1
        )
        let restoredFrame = restored.update(at: 1.05, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls.rawValue, 63)

        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        var hostileObject = continuationObject
        var hostileOpening = try XCTUnwrap(
            hostileObject["trainingOpeningState"] as? [String: Any]
        )
        hostileOpening["enabledControls"] = 62
        hostileObject["trainingOpeningState"] = hostileOpening
        let hostile = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: baseLevel,
                continuation: hostile,
                resumedAtTimestamp: 2
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var preservedObject = continuationObject
        var preservedOpening = try XCTUnwrap(
            preservedObject["trainingOpeningState"]
                as? [String: Any]
        )
        preservedOpening["enabledControls"] = 127
        preservedObject["trainingOpeningState"] = preservedOpening
        let preserved = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: preservedObject
            )
        )
        let preservedSimulation = try PlayerSimulation(
            level: baseLevel,
            continuation: preserved,
            resumedAtTimestamp: 2.5
        )
        XCTAssertEqual(
            preservedSimulation.update(
                at: 2.55,
                input: .zero
            ).enabledPlayerControls.rawValue,
            127
        )

        var compatibleLesson = try XCTUnwrap(
            baseLevel.trainingOpeningLesson
        )
        compatibleLesson.startCourse = nil
        let compatibleLevel = replacing(
            baseLevel,
            trainingOpeningLesson: compatibleLesson
        )
        XCTAssertNoThrow(try compatibleLevel.validate())
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: compatibleLevel,
                continuation: simulation.continuation,
                resumedAtTimestamp: 3
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    @MainActor
    func testTrainingScript013OpensPortalRoomOneThenRestoresSilently()
        throws
    {
        let level = makeTrainingScript003Level()
        let continueToCourse = try XCTUnwrap(
            level.trainingOpeningLesson?.continueToCourse
        )
        XCTAssertEqual(continueToCourse.startGoalObjectHandle, 12_300)
        XCTAssertEqual(continueToCourse.portalRoomSourceIndex, 2)
        XCTAssertEqual(continueToCourse.orderedPortalIndices, [0, 1])
        XCTAssertEqual(
            continueToCourse.instruction,
            "Continue Sliding down to start the next step."
        )
        XCTAssertEqual(continueToCourse.voiceSourceName, "proceed1.osf")

        let portalRoom = try XCTUnwrap(
            level.rooms.first {
                $0.sourceIndex == continueToCourse.portalRoomSourceIndex
            }
        )
        let originalPortalFlags = continueToCourse.orderedPortalIndices.map {
            portalRoom.portals[$0].flags
        }
        let originalReciprocalFlags = continueToCourse.orderedPortalIndices.map {
            let portal = portalRoom.portals[$0]
            return level.rooms.first {
                $0.sourceIndex == portal.connectedRoom
            }!.portals[portal.connectedPortal].flags
        }
        XCTAssertTrue(originalPortalFlags.allSatisfy { $0 & 1 != 0 })
        XCTAssertTrue(originalReciprocalFlags.allSatisfy { $0 & 1 != 0 })

        let player = try XCTUnwrap(
            level.objects.first { $0.handle == 2_048 }
        )
        let goalHandles: [UInt32] = [
            12_301,
            12_300,
            12_299,
            18_441,
        ]
        func contacting(
            _ handle: UInt32,
            at position: Vector3
        ) throws -> Level {
            var objects = level.objects
            for goalHandle in goalHandles {
                let index = try XCTUnwrap(
                    objects.firstIndex { $0.handle == goalHandle }
                )
                objects[index].position = goalHandle == handle
                    ? position
                    : .init(
                        x: position.x + 100,
                        y: position.y,
                        z: position.z
                    )
                objects[index].location = .room(1)
            }
            let roomIndex = try XCTUnwrap(
                level.rooms.firstIndex { $0.sourceIndex == 1 }
            )
            var rooms = level.rooms
            rooms[roomIndex] = addingSourceContainmentShell(
                to: rooms[roomIndex],
                center: position,
                texture: level.surfacePhysics[0].texture,
                halfExtent: 200
            )
            return replacing(level, rooms: rooms, objects: objects)
        }
        func resumed(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double,
            level resumedLevel: Level? = nil
        ) throws -> PlayerSimulation {
            let contactLevel = try contacting(
                handle,
                at: continuation.playerPosition
            )
            return try PlayerSimulation(
                level: resumedLevel.map {
                    replacing(
                        contactLevel,
                        trainingOpeningLesson: $0.trainingOpeningLesson
                    )
                } ?? contactLevel,
                continuation: continuation,
                resumedAtTimestamp: timestamp
            )
        }
        func advance(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> PlayerSimulation {
            let simulation = try resumed(
                continuation,
                contacting: handle,
                at: timestamp
            )
            _ = simulation.update(at: timestamp + 0.05, input: .zero)
            return simulation
        }

        let firstForward = PlayerSimulation(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.05, input: .zero)
        let firstLeftGoal = try advance(
            firstForward.continuation,
            contacting: 12_299,
            at: 1
        )
        let returnUp = try advance(
            firstLeftGoal.continuation,
            contacting: 12_300,
            at: 2
        )
        let returnDown = try advance(
            returnUp.continuation,
            contacting: 18_441,
            at: 3
        )
        let repeatForward = try advance(
            returnDown.continuation,
            contacting: 12_300,
            at: 4
        )
        let repeatForwardGoal = try advance(
            repeatForward.continuation,
            contacting: 12_301,
            at: 5
        )
        let repeatReturnLeft = try advance(
            repeatForwardGoal.continuation,
            contacting: 12_300,
            at: 6
        )
        let repeatReturnRight = try advance(
            repeatReturnLeft.continuation,
            contacting: 12_299,
            at: 7
        )
        let repeatReturnUp = try advance(
            repeatReturnRight.continuation,
            contacting: 12_300,
            at: 8
        )
        let repeatReturnDown = try advance(
            repeatReturnUp.continuation,
            contacting: 18_441,
            at: 9
        )
        let normal = try resumed(
            repeatReturnDown.continuation,
            contacting: 12_300,
            at: 10
        )
        let normalFrame = normal.update(at: 10.05, input: .zero)
        XCTAssertEqual(
            normalFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [
                        "Continue Sliding down to start the next step.",
                    ],
                    voiceSourceName: "proceed1.osf",
                    voicePrecedesHUDMessages: true
                ),
            ]
        )
        XCTAssertEqual(normalFrame.enabledPlayerControls, [.down])
        var presentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            normalFrame.trainingOpeningFeedback,
            attemptVoice: {
                presentationOrder.append("voice:\($0)")
            },
            attemptSound: { _, _ in
                XCTFail("Script 013 does not play a sound")
            },
            presentHUDMessages: {
                presentationOrder.append(
                    contentsOf: $0.map { "hud:\($0)" }
                )
            }
        )
        XCTAssertEqual(
            presentationOrder,
            [
                "voice:proceed1.osf",
                "hud:Continue Sliding down to start the next step.",
            ]
        )

        let openedRoom = try XCTUnwrap(
            normal.level.rooms.first {
                $0.sourceIndex == continueToCourse.portalRoomSourceIndex
            }
        )
        for (offset, portalIndex) in
            continueToCourse.orderedPortalIndices.enumerated()
        {
            let portal = openedRoom.portals[portalIndex]
            XCTAssertEqual(
                portal.flags,
                originalPortalFlags[offset] & ~UInt32(1)
            )
            let connected = try XCTUnwrap(
                normal.level.rooms.first {
                    $0.sourceIndex == portal.connectedRoom
                }
            )
            XCTAssertEqual(
                connected.portals[portal.connectedPortal].flags,
                originalReciprocalFlags[offset] & ~UInt32(1)
            )
        }

        let startCourse = try XCTUnwrap(
            level.trainingOpeningLesson?.startCourse
        )
        var courseObjects = level.objects
        let courseIndex = try XCTUnwrap(
            courseObjects.firstIndex {
                $0.handle == startCourse.startCourseObjectHandle
            }
        )
        courseObjects[courseIndex].position =
            normal.continuation.playerPosition
        courseObjects[courseIndex].location =
            normal.continuation.playerLocation
        let normalCourse = try PlayerSimulation(
            level: replacing(
                level,
                rooms: try contacting(
                    startCourse.startCourseObjectHandle,
                    at: normal.continuation.playerPosition
                ).rooms,
                objects: courseObjects
            ),
            continuation: normal.continuation,
            resumedAtTimestamp: 10.5
        )
        let normalCourseFrame = normalCourse.update(
            at: 10.55,
            input: .zero
        )
        XCTAssertEqual(
            normalCourseFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [startCourse.instruction],
                    voiceSourceName: startCourse.voiceSourceName,
                    voicePrecedesHUDMessages: false
                ),
            ]
        )
        XCTAssertEqual(
            normalCourseFrame.enabledPlayerControls.rawValue,
            63
        )
        let normalCoursePortalRoom = try XCTUnwrap(
            normalCourse.level.rooms.first {
                $0.sourceIndex == startCourse.portalRoomSourceIndex
            }
        )
        XCTAssertEqual(normalCoursePortalRoom.portals[0].flags & 1, 0)
        XCTAssertNotEqual(
            normalCoursePortalRoom.portals[startCourse.portalIndex]
                .flags & 1,
            0
        )
        var normalCourseContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(normal.continuation)
            ) as? [String: Any]
        )
        var normalCourseOpening = try XCTUnwrap(
            normalCourseContinuationObject["trainingOpeningState"]
                as? [String: Any]
        )
        normalCourseOpening["startCourseWasPresented"] = true
        normalCourseOpening["enabledControls"] = 63
        normalCourseContinuationObject["trainingOpeningState"] =
            normalCourseOpening
        let restoredNormalCourse = try PlayerSimulation(
            level: try contacting(
                12_300,
                at: normal.continuation.playerPosition
            ),
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: normalCourseContinuationObject
                )
            ),
            resumedAtTimestamp: 10.75
        )
        let restoredNormalCourseFrame = restoredNormalCourse.update(
            at: 10.8,
            input: .zero
        )
        XCTAssertTrue(
            restoredNormalCourseFrame.trainingOpeningFeedback.isEmpty
        )
        XCTAssertEqual(
            restoredNormalCourseFrame.enabledPlayerControls.rawValue,
            63
        )
        let restoredNormalCoursePortalRoom = try XCTUnwrap(
            restoredNormalCourse.level.rooms.first {
                $0.sourceIndex == startCourse.portalRoomSourceIndex
            }
        )
        XCTAssertEqual(
            restoredNormalCoursePortalRoom.portals[0].flags & 1,
            0
        )
        XCTAssertNotEqual(
            restoredNormalCoursePortalRoom
                .portals[startCourse.portalIndex].flags & 1,
            0
        )

        let restored = try PlayerSimulation(
            level: try contacting(
                12_300,
                at: normal.continuation.playerPosition
            ),
            continuation: try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(normal.continuation)
            ),
            resumedAtTimestamp: 11
        )
        let restoredFrame = restored.update(at: 11.05, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.down])
        let restoredRoom = try XCTUnwrap(
            restored.level.rooms.first {
                $0.sourceIndex == continueToCourse.portalRoomSourceIndex
            }
        )
        XCTAssertTrue(
            continueToCourse.orderedPortalIndices.allSatisfy {
                restoredRoom.portals[$0].flags & 1 == 0
            }
        )

        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(normal.continuation)
            ) as? [String: Any]
        )
        for (key, value) in [
            ("repeatReturnDownWasPresented", false),
            ("enabledControls", 16),
        ] as [(String, Any)] {
            var hostileObject = continuationObject
            var hostileOpening = try XCTUnwrap(
                hostileObject["trainingOpeningState"] as? [String: Any]
            )
            hostileOpening[key] = value
            hostileObject["trainingOpeningState"] = hostileOpening
            let hostile = try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: hostileObject
                )
            )
            XCTAssertThrowsError(
                try PlayerSimulation(
                    level: level,
                    continuation: hostile,
                    resumedAtTimestamp: 12
                )
            ) {
                XCTAssertEqual(
                    $0 as? PlayerSimulationContinuationError,
                    .invalidState
                )
            }
        }

        var hostilePortalRooms = level.rooms
        let hostilePortalRoomIndex = try XCTUnwrap(
            hostilePortalRooms.firstIndex {
                $0.sourceIndex == continueToCourse.portalRoomSourceIndex
            }
        )
        for portalIndex in continueToCourse.orderedPortalIndices {
            let portal =
                hostilePortalRooms[hostilePortalRoomIndex]
                    .portals[portalIndex]
            hostilePortalRooms[hostilePortalRoomIndex]
                .portals[portalIndex].flags &= ~UInt32(1)
            let connectedRoomIndex = try XCTUnwrap(
                hostilePortalRooms.firstIndex {
                    $0.sourceIndex == portal.connectedRoom
                }
            )
            hostilePortalRooms[connectedRoomIndex]
                .portals[portal.connectedPortal].flags &= ~UInt32(1)
        }
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: replacing(level, rooms: hostilePortalRooms),
                continuation: normal.continuation,
                resumedAtTimestamp: 12.5
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.continueToCourse = nil
        let compatibleLevel = replacing(
            level,
            trainingOpeningLesson: compatibleLesson
        )
        XCTAssertNoThrow(try compatibleLevel.validate())
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: compatibleLevel,
                continuation: normal.continuation,
                resumedAtTimestamp: 13
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
        let compatibleSimulation = try resumed(
            repeatReturnDown.continuation,
            contacting: 12_300,
            at: 14,
            level: compatibleLevel
        )
        let compatibleFrame = compatibleSimulation.update(
            at: 14.05,
            input: .zero
        )
        XCTAssertTrue(compatibleFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(compatibleFrame.enabledPlayerControls, [.down])
        let compatibleRoom = try XCTUnwrap(
            compatibleSimulation.level.rooms.first {
                $0.sourceIndex == continueToCourse.portalRoomSourceIndex
            }
        )
        XCTAssertEqual(
            continueToCourse.orderedPortalIndices.map {
                compatibleRoom.portals[$0].flags
            },
            originalPortalFlags
        )
    }

    @MainActor
    func testTrainingScript012RepeatsReturnDownInReleasedOrderAndRestores()
        throws
    {
        let level = makeTrainingScript003Level()
        let repeatReturnDown = try XCTUnwrap(
            level.trainingOpeningLesson?.repeatReturnDown
        )
        XCTAssertEqual(repeatReturnDown.upGoalObjectHandle, 18_441)
        XCTAssertEqual(
            repeatReturnDown.instruction,
            "Now Slide down until you return to the start position."
        )
        XCTAssertEqual(
            repeatReturnDown.soundLogicalName,
            "MenuBeepEnter"
        )
        let upGoalPresentation = try XCTUnwrap(
            level.objectPresentations.first {
                $0.objectHandle == repeatReturnDown.upGoalObjectHandle
            }
        )
        let upGoalModel = try XCTUnwrap(
            level.models.first {
                $0.source == upGoalPresentation.primaryModel
            }
        )
        XCTAssertEqual(
            repeatReturnDown.collisionRadius,
            sourceObjectPresentationSize(
                model: upGoalModel,
                objectType: 7
            )
        )
        let menuBeep = try XCTUnwrap(level.soundClips.first {
            $0.logicalName == repeatReturnDown.soundLogicalName
        })
        XCTAssertEqual(menuBeep.sourceName, "MenuBeepSelectC.wav")
        XCTAssertEqual(menuBeep.importVolume, 0.7)

        let player = try XCTUnwrap(
            level.objects.first { $0.handle == 2_048 }
        )
        let goalHandles: [UInt32] = [
            12_301,
            12_300,
            12_299,
            18_441,
        ]
        func contacting(
            _ handle: UInt32,
            at position: Vector3
        ) throws -> Level {
            var objects = level.objects
            for goalHandle in goalHandles {
                let index = try XCTUnwrap(
                    objects.firstIndex { $0.handle == goalHandle }
                )
                objects[index].position = goalHandle == handle
                    ? position
                    : .init(
                        x: position.x + 100,
                        y: position.y,
                        z: position.z
                    )
                objects[index].location = .room(1)
            }
            let roomIndex = try XCTUnwrap(
                level.rooms.firstIndex { $0.sourceIndex == 1 }
            )
            var rooms = level.rooms
            rooms[roomIndex] = makeSourceContainmentRoom(
                center: position,
                texture: level.surfacePhysics[0].texture,
                sourceIndex: 1,
                halfExtent: 200
            )
            return replacing(level, rooms: rooms, objects: objects)
        }
        func resumed(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double,
            level resumedLevel: Level? = nil
        ) throws -> PlayerSimulation {
            let contactLevel = try contacting(
                handle,
                at: continuation.playerPosition
            )
            return try PlayerSimulation(
                level: resumedLevel.map {
                    replacing(
                        contactLevel,
                        trainingOpeningLesson: $0.trainingOpeningLesson
                    )
                } ?? contactLevel,
                continuation: continuation,
                resumedAtTimestamp: timestamp
            )
        }
        func advance(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> PlayerSimulation {
            let simulation = try resumed(
                continuation,
                contacting: handle,
                at: timestamp
            )
            _ = simulation.update(at: timestamp + 0.05, input: .zero)
            return simulation
        }

        let firstForward = PlayerSimulation(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.05, input: .zero)
        let firstLeftGoal = try advance(
            firstForward.continuation,
            contacting: 12_299,
            at: 1
        )
        let returnUp = try advance(
            firstLeftGoal.continuation,
            contacting: 12_300,
            at: 2
        )
        let returnDown = try advance(
            returnUp.continuation,
            contacting: 18_441,
            at: 3
        )
        let repeatForward = try advance(
            returnDown.continuation,
            contacting: 12_300,
            at: 4
        )
        let repeatForwardGoal = try advance(
            repeatForward.continuation,
            contacting: 12_301,
            at: 5
        )
        let repeatReturnLeft = try advance(
            repeatForwardGoal.continuation,
            contacting: 12_300,
            at: 6
        )
        let repeatReturnRight = try advance(
            repeatReturnLeft.continuation,
            contacting: 12_299,
            at: 7
        )
        let repeatReturnUp = try advance(
            repeatReturnRight.continuation,
            contacting: 12_300,
            at: 8
        )
        let normalReturn = try resumed(
            repeatReturnUp.continuation,
            contacting: 18_441,
            at: 9
        )
        let normalFrame = normalReturn.update(at: 9.05, input: .zero)
        XCTAssertEqual(
            normalFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [
                        "Now Slide down until you return to the start position.",
                    ],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: "MenuBeepEnter",
                    soundEventVolume: 1
                ),
            ]
        )
        XCTAssertEqual(normalFrame.enabledPlayerControls, [.down])
        var presentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            normalFrame.trainingOpeningFeedback,
            attemptVoice: {
                presentationOrder.append("voice:\($0)")
            },
            attemptSound: { name, eventVolume in
                presentationOrder.append(
                    "sound:\(name)@\(eventVolume ?? -1)"
                )
            },
            presentHUDMessages: {
                presentationOrder.append(
                    contentsOf: $0.map { "hud:\($0)" }
                )
            }
        )
        XCTAssertEqual(
            presentationOrder,
            [
                "sound:MenuBeepEnter@1.0",
                "hud:Now Slide down until you return to the start position.",
            ]
        )
        XCTAssertTrue(
            normalReturn.update(at: 9.1, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )

        let restored = try resumed(
            try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(normalReturn.continuation)
            ),
            contacting: 18_441,
            at: 10
        )
        let restoredFrame = restored.update(at: 10.05, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.down])

        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(normalReturn.continuation)
            ) as? [String: Any]
        )
        for (key, value) in [
            ("repeatReturnUpWasPresented", false),
            ("downGoalWasReached", false),
            ("upGoalWasReached", false),
            ("enabledControls", 16),
        ] as [(String, Any)] {
            var hostileObject = continuationObject
            var hostileOpening = try XCTUnwrap(
                hostileObject["trainingOpeningState"] as? [String: Any]
            )
            hostileOpening[key] = value
            hostileObject["trainingOpeningState"] = hostileOpening
            let hostile = try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: hostileObject
                )
            )
            XCTAssertThrowsError(
                try PlayerSimulation(
                    level: level,
                    continuation: hostile,
                    resumedAtTimestamp: 11
                )
            ) {
                XCTAssertEqual(
                    $0 as? PlayerSimulationContinuationError,
                    .invalidState
                )
            }
        }

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.repeatReturnDown = nil
        compatibleLesson.continueToCourse = nil
        let compatibleLevel = replacing(
            level,
            trainingOpeningLesson: compatibleLesson
        )
        XCTAssertNoThrow(try compatibleLevel.validate())
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: compatibleLevel,
                continuation: normalReturn.continuation,
                resumedAtTimestamp: 11.5
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
        let compatibleSimulation = try resumed(
            repeatReturnUp.continuation,
            contacting: 18_441,
            at: 12,
            level: compatibleLevel
        )
        let compatibleFrame = compatibleSimulation.update(
            at: 12.05,
            input: .zero
        )
        XCTAssertTrue(compatibleFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(compatibleFrame.enabledPlayerControls, [.up])
    }

    @MainActor
    func testTrainingScript011RepeatsReturnUpInReleasedOrderAndRestores()
        throws
    {
        let level = makeTrainingScript003Level()
        let repeatReturnUp = try XCTUnwrap(
            level.trainingOpeningLesson?.repeatReturnUp
        )
        XCTAssertEqual(repeatReturnUp.startGoalObjectHandle, 12_300)
        XCTAssertEqual(
            repeatReturnUp.instruction,
            "Now Slide up  until you stop."
        )
        XCTAssertEqual(repeatReturnUp.voiceSourceName, "udown.osf")
        let startGoalPresentation = try XCTUnwrap(
            level.objectPresentations.first {
                $0.objectHandle == repeatReturnUp.startGoalObjectHandle
            }
        )
        let startGoalModel = try XCTUnwrap(
            level.models.first {
                $0.source == startGoalPresentation.primaryModel
            }
        )
        XCTAssertEqual(
            repeatReturnUp.collisionRadius,
            sourceObjectPresentationSize(
                model: startGoalModel,
                objectType: 7
            )
        )

        let player = try XCTUnwrap(
            level.objects.first { $0.handle == 2_048 }
        )
        let goalHandles: [UInt32] = [
            12_301,
            12_300,
            12_299,
            18_441,
        ]
        func contacting(
            _ handle: UInt32,
            at position: Vector3
        ) throws -> Level {
            var objects = level.objects
            for goalHandle in goalHandles {
                let index = try XCTUnwrap(
                    objects.firstIndex { $0.handle == goalHandle }
                )
                objects[index].position = goalHandle == handle
                    ? position
                    : .init(
                        x: position.x + 100,
                        y: position.y,
                        z: position.z
                    )
                objects[index].location = .room(1)
            }
            let roomIndex = try XCTUnwrap(
                level.rooms.firstIndex { $0.sourceIndex == 1 }
            )
            var rooms = level.rooms
            rooms[roomIndex] = makeSourceContainmentRoom(
                center: position,
                texture: level.surfacePhysics[0].texture,
                sourceIndex: 1,
                halfExtent: 200
            )
            return replacing(level, rooms: rooms, objects: objects)
        }
        func resumed(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double,
            level resumedLevel: Level? = nil
        ) throws -> PlayerSimulation {
            let contactLevel = try contacting(
                handle,
                at: continuation.playerPosition
            )
            return try PlayerSimulation(
                level: resumedLevel.map {
                    replacing(
                        contactLevel,
                        trainingOpeningLesson: $0.trainingOpeningLesson
                    )
                } ?? contactLevel,
                continuation: continuation,
                resumedAtTimestamp: timestamp
            )
        }
        func advance(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> PlayerSimulation {
            let simulation = try resumed(
                continuation,
                contacting: handle,
                at: timestamp
            )
            _ = simulation.update(at: timestamp + 0.1, input: .zero)
            return simulation
        }

        let firstForward = PlayerSimulation(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.1, input: .zero)
        let firstLeftGoal = try advance(
            firstForward.continuation,
            contacting: 12_299,
            at: 1
        )
        let returnUp = try advance(
            firstLeftGoal.continuation,
            contacting: 12_300,
            at: 2
        )
        let returnDown = try advance(
            returnUp.continuation,
            contacting: 18_441,
            at: 3
        )
        let repeatForward = try advance(
            returnDown.continuation,
            contacting: 12_300,
            at: 4
        )
        let repeatForwardGoal = try advance(
            repeatForward.continuation,
            contacting: 12_301,
            at: 5
        )
        let repeatReturnLeft = try advance(
            repeatForwardGoal.continuation,
            contacting: 12_300,
            at: 6
        )
        let repeatReturnRight = try advance(
            repeatReturnLeft.continuation,
            contacting: 12_299,
            at: 7
        )
        let normalReturn = try resumed(
            repeatReturnRight.continuation,
            contacting: 12_300,
            at: 8
        )
        let normalFrame = normalReturn.update(at: 8.1, input: .zero)
        XCTAssertEqual(
            normalFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Now Slide up  until you stop."],
                    voiceSourceName: "udown.osf",
                    voicePrecedesHUDMessages: true
                ),
            ]
        )
        XCTAssertEqual(normalFrame.enabledPlayerControls, [.up])
        XCTAssertFalse(
            normalReturn.update(at: 8.2, input: .zero)
                .trainingOpeningFeedback.contains {
                    $0.voiceSourceName == "udown.osf"
                }
        )

        let restored = try resumed(
            try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(normalReturn.continuation)
            ),
            contacting: 12_300,
            at: 9
        )
        let restoredFrame = restored.update(at: 9.1, input: .zero)
        XCTAssertFalse(
            restoredFrame.trainingOpeningFeedback.contains {
                $0.voiceSourceName == "udown.osf"
                    || $0.hudMessages.contains(
                        "Now Slide up  until you stop."
                    )
            }
        )
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.up])

        let earlyDown = PlayerSimulation(
            level: try contacting(18_441, at: player.position),
            presentationReadyTimestamp: 10
        )
        _ = earlyDown.update(at: 10.1, input: .zero)
        let earlyRepeat = try advance(
            earlyDown.continuation,
            contacting: 12_300,
            at: 11
        )
        let earlyForward = try advance(
            earlyRepeat.continuation,
            contacting: 12_301,
            at: 12
        )
        let earlyReturnLeft = try advance(
            earlyForward.continuation,
            contacting: 12_300,
            at: 13
        )
        let earlyReturnRight = try advance(
            earlyReturnLeft.continuation,
            contacting: 12_299,
            at: 14
        )
        let sharedStartGoal = try resumed(
            earlyReturnRight.continuation,
            contacting: 12_300,
            at: 15
        )
        let sharedFrame = sharedStartGoal.update(at: 15.1, input: .zero)
        XCTAssertEqual(
            sharedFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Excellent!"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: ["Now Slide up  until you stop."],
                    voiceSourceName: "up1.osf",
                    voicePrecedesHUDMessages: true
                ),
                .init(
                    hudMessages: ["Now Slide up  until you stop."],
                    voiceSourceName: "udown.osf",
                    voicePrecedesHUDMessages: true
                ),
            ]
        )
        XCTAssertEqual(sharedFrame.enabledPlayerControls, [.up])
        var presentationOrder: [String] = []
        var retainedVoice: String?
        RevivalGameplayView.presentTrainingFeedbackSequence(
            sharedFrame.trainingOpeningFeedback,
            attemptVoice: {
                retainedVoice = $0
                presentationOrder.append("voice:\($0)")
            },
            attemptSound: { name, _ in
                presentationOrder.append("sound:\(name)")
            },
            presentHUDMessages: {
                presentationOrder.append(contentsOf: $0.map { "hud:\($0)" })
            }
        )
        XCTAssertEqual(
            presentationOrder,
            [
                "hud:Excellent!",
                "hud:Now Slide up  until you stop.",
                "voice:udown.osf",
                "hud:Now Slide up  until you stop.",
            ]
        )
        XCTAssertEqual(retainedVoice, "udown.osf")

        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(normalReturn.continuation)
            ) as? [String: Any]
        )
        for (key, value) in [
            ("repeatReturnRightWasPresented", false),
            ("rightGoalWasReached", false),
            ("upGoalWasReached", false),
            ("enabledControls", 8),
        ] as [(String, Any)] {
            var hostileObject = continuationObject
            var hostileOpening = try XCTUnwrap(
                hostileObject["trainingOpeningState"] as? [String: Any]
            )
            hostileOpening[key] = value
            hostileObject["trainingOpeningState"] = hostileOpening
            let hostile = try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: hostileObject
                )
            )
            XCTAssertThrowsError(
                try PlayerSimulation(
                    level: level,
                    continuation: hostile,
                    resumedAtTimestamp: 16
                )
            ) {
                XCTAssertEqual(
                    $0 as? PlayerSimulationContinuationError,
                    .invalidState
                )
            }
        }

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.repeatReturnUp = nil
        compatibleLesson.repeatReturnDown = nil
        compatibleLesson.continueToCourse = nil
        let compatibleLevel = replacing(
            level,
            trainingOpeningLesson: compatibleLesson
        )
        XCTAssertNoThrow(try compatibleLevel.validate())
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: compatibleLevel,
                continuation: normalReturn.continuation,
                resumedAtTimestamp: 16.5
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
        let compatibleSimulation = try resumed(
            repeatReturnRight.continuation,
            contacting: 12_300,
            at: 17,
            level: compatibleLevel
        )
        let compatibleFrame = compatibleSimulation.update(
            at: 17.1,
            input: .zero
        )
        XCTAssertFalse(
            compatibleFrame.trainingOpeningFeedback.contains {
                $0.voiceSourceName == "udown.osf"
            }
        )
        XCTAssertEqual(compatibleFrame.enabledPlayerControls, [.right])
    }

    @MainActor
    func testTrainingScript010RepeatsReturnRightInReleasedOrderAndRestores()
        throws
    {
        let level = makeTrainingScript003Level()
        let repeatReturnRight = try XCTUnwrap(
            level.trainingOpeningLesson?.repeatReturnRight
        )
        XCTAssertEqual(repeatReturnRight.leftGoalObjectHandle, 12_299)
        let leftGoalPresentation = try XCTUnwrap(
            level.objectPresentations.first {
                $0.objectHandle == repeatReturnRight.leftGoalObjectHandle
            }
        )
        let leftGoalModel = try XCTUnwrap(
            level.models.first {
                $0.source == leftGoalPresentation.primaryModel
            }
        )
        XCTAssertEqual(
            repeatReturnRight.collisionRadius,
            sourceObjectPresentationSize(
                model: leftGoalModel,
                objectType: 7
            )
        )
        XCTAssertEqual(
            repeatReturnRight.instruction,
            "Now Slide right until you return to the start position."
        )
        XCTAssertEqual(repeatReturnRight.soundLogicalName, "MenuBeepEnter")

        let player = try XCTUnwrap(
            level.objects.first { $0.handle == 2_048 }
        )
        let goalHandles: [UInt32] = [
            12_301,
            12_300,
            12_299,
            18_441,
        ]
        func contacting(
            _ handle: UInt32,
            at position: Vector3
        ) throws -> Level {
            var objects = level.objects
            for goalHandle in goalHandles {
                let index = try XCTUnwrap(
                    objects.firstIndex { $0.handle == goalHandle }
                )
                objects[index].position = goalHandle == handle
                    ? position
                    : .init(
                        x: position.x + 100,
                        y: position.y,
                        z: position.z
                    )
                objects[index].location = .room(1)
            }
            let roomIndex = try XCTUnwrap(
                level.rooms.firstIndex { $0.sourceIndex == 1 }
            )
            var rooms = level.rooms
            rooms[roomIndex] = makeSourceContainmentRoom(
                center: position,
                texture: level.surfacePhysics[0].texture,
                sourceIndex: 1,
                halfExtent: 200
            )
            return replacing(level, rooms: rooms, objects: objects)
        }
        func resumed(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> PlayerSimulation {
            try PlayerSimulation(
                level: contacting(handle, at: continuation.playerPosition),
                continuation: continuation,
                resumedAtTimestamp: timestamp
            )
        }
        func advance(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> PlayerSimulation {
            let simulation = try resumed(
                continuation,
                contacting: handle,
                at: timestamp
            )
            _ = simulation.update(at: timestamp + 0.1, input: .zero)
            return simulation
        }

        let firstForward = PlayerSimulation(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.1, input: .zero)
        let firstLeftGoal = try advance(
            firstForward.continuation,
            contacting: 12_299,
            at: 1
        )
        let returnUp = try advance(
            firstLeftGoal.continuation,
            contacting: 12_300,
            at: 2
        )
        let returnDown = try advance(
            returnUp.continuation,
            contacting: 18_441,
            at: 3
        )
        let repeatForward = try advance(
            returnDown.continuation,
            contacting: 12_300,
            at: 4
        )
        let repeatForwardGoal = try advance(
            repeatForward.continuation,
            contacting: 12_301,
            at: 5
        )
        let repeatReturnLeft = try advance(
            repeatForwardGoal.continuation,
            contacting: 12_300,
            at: 6
        )
        let normalReturn = try resumed(
            repeatReturnLeft.continuation,
            contacting: 12_299,
            at: 7
        )
        let normalFrame = normalReturn.update(at: 7.1, input: .zero)
        XCTAssertEqual(
            normalFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [
                        "Now Slide right until you return to the start position.",
                    ],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: "MenuBeepEnter"
                ),
            ]
        )
        XCTAssertEqual(normalFrame.enabledPlayerControls, [.right])
        XCTAssertTrue(
            normalReturn.update(at: 7.2, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )

        let restored = try resumed(
            try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(normalReturn.continuation)
            ),
            contacting: 12_299,
            at: 8
        )
        let restoredFrame = restored.update(at: 8.1, input: .zero)
        XCTAssertFalse(
            restoredFrame.trainingOpeningFeedback.contains {
                $0.soundSourceName == "MenuBeepEnter"
                    || $0.hudMessages.contains(
                        "Now Slide right until you return to the start position."
                    )
            }
        )
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.right])

        let earlyDown = PlayerSimulation(
            level: try contacting(18_441, at: player.position),
            presentationReadyTimestamp: 9
        )
        _ = earlyDown.update(at: 9.1, input: .zero)
        let earlyRepeat = try advance(
            earlyDown.continuation,
            contacting: 12_300,
            at: 10
        )
        let earlyForward = try advance(
            earlyRepeat.continuation,
            contacting: 12_301,
            at: 11
        )
        let earlyReturnLeft = try advance(
            earlyForward.continuation,
            contacting: 12_300,
            at: 12
        )
        let sharedLeftGoal = try resumed(
            earlyReturnLeft.continuation,
            contacting: 12_299,
            at: 13
        )
        let sharedFrame = sharedLeftGoal.update(at: 13.1, input: .zero)
        XCTAssertEqual(
            sharedFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Excellent!"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: [
                        "Now Slide right until you return to the start position.",
                    ],
                    voiceSourceName: "return2.osf",
                    voicePrecedesHUDMessages: true
                ),
                .init(
                    hudMessages: [
                        "Now Slide right until you return to the start position.",
                    ],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: "MenuBeepEnter"
                ),
            ]
        )
        XCTAssertEqual(sharedFrame.enabledPlayerControls, [.right])
        var presentationOrder: [String] = []
        var retainedVoice: String?
        RevivalGameplayView.presentTrainingFeedbackSequence(
            sharedFrame.trainingOpeningFeedback,
            attemptVoice: {
                retainedVoice = $0
                presentationOrder.append("voice:\($0)")
            },
            attemptSound: { name, _ in
                presentationOrder.append("sound:\(name)")
            },
            presentHUDMessages: {
                presentationOrder.append(contentsOf: $0.map { "hud:\($0)" })
            }
        )
        XCTAssertEqual(
            presentationOrder,
            [
                "hud:Excellent!",
                "voice:return2.osf",
                "hud:Now Slide right until you return to the start position.",
                "sound:MenuBeepEnter",
                "hud:Now Slide right until you return to the start position.",
            ]
        )
        XCTAssertEqual(retainedVoice, "return2.osf")

        var hostileOrderingObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(sharedLeftGoal.continuation)
            ) as? [String: Any]
        )
        var hostileOrderingOpening = try XCTUnwrap(
            hostileOrderingObject["trainingOpeningState"] as? [String: Any]
        )
        hostileOrderingOpening["rightGoalWasReached"] = false
        hostileOrderingObject["trainingOpeningState"] = hostileOrderingOpening
        let hostileOrdering = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: hostileOrderingObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: contacting(
                    12_299,
                    at: hostileOrdering.playerPosition
                ),
                continuation: hostileOrdering,
                resumedAtTimestamp: 13.5
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(normalReturn.continuation)
            ) as? [String: Any]
        )
        var hostileOpening = try XCTUnwrap(
            hostileObject["trainingOpeningState"] as? [String: Any]
        )
        hostileOpening["repeatReturnLeftWasPresented"] = false
        hostileObject["trainingOpeningState"] = hostileOpening
        let hostile = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostile,
                resumedAtTimestamp: 14
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var hostileMaskObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(normalReturn.continuation)
            ) as? [String: Any]
        )
        var hostileMaskOpening = try XCTUnwrap(
            hostileMaskObject["trainingOpeningState"] as? [String: Any]
        )
        hostileMaskOpening["enabledControls"] = 4
        hostileMaskObject["trainingOpeningState"] = hostileMaskOpening
        let hostileMask = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: hostileMaskObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostileMask,
                resumedAtTimestamp: 14.5
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.repeatReturnRight = nil
        compatibleLesson.repeatReturnUp = nil
        compatibleLesson.repeatReturnDown = nil
        compatibleLesson.continueToCourse = nil
        let compatibleLevel = replacing(
            level,
            trainingOpeningLesson: compatibleLesson
        )
        XCTAssertNoThrow(try compatibleLevel.validate())
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: compatibleLevel,
                continuation: normalReturn.continuation,
                resumedAtTimestamp: 14.75
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
        let compatibleContactLevel = replacing(
            try contacting(
                12_299,
                at: repeatReturnLeft.continuation.playerPosition
            ),
            trainingOpeningLesson: compatibleLesson
        )
        let compatibleSimulation = try PlayerSimulation(
            level: compatibleContactLevel,
            continuation: repeatReturnLeft.continuation,
            resumedAtTimestamp: 15
        )
        let compatibleFrame = compatibleSimulation.update(
            at: 15.1,
            input: .zero
        )
        XCTAssertFalse(
            compatibleFrame.trainingOpeningFeedback.contains {
                $0.soundSourceName == "MenuBeepEnter"
                    || $0.hudMessages.contains(
                        "Now Slide right until you return to the start position."
                    )
            }
        )
        XCTAssertEqual(compatibleFrame.enabledPlayerControls, [.left])
    }

    @MainActor
    func testTrainingScript009RepeatsReturnLeftInReleasedOrderAndRestores()
        throws
    {
        let level = makeTrainingScript003Level()
        let repeatReturnLeft = try XCTUnwrap(
            level.trainingOpeningLesson?.repeatReturnLeft
        )
        XCTAssertEqual(repeatReturnLeft.startGoalObjectHandle, 12_300)
        XCTAssertEqual(
            repeatReturnLeft.instruction,
            "Now Go Left until you stop."
        )
        XCTAssertEqual(repeatReturnLeft.voiceSourceName, "lright.osf")

        let player = try XCTUnwrap(
            level.objects.first { $0.handle == 2_048 }
        )
        let goalHandles: [UInt32] = [
            12_301,
            12_300,
            12_299,
            18_441,
        ]
        func contacting(
            _ handle: UInt32,
            at position: Vector3
        ) throws -> Level {
            var objects = level.objects
            for goalHandle in goalHandles {
                let index = try XCTUnwrap(
                    objects.firstIndex { $0.handle == goalHandle }
                )
                objects[index].position = goalHandle == handle
                    ? position
                    : .init(
                        x: position.x + 100,
                        y: position.y,
                        z: position.z
                    )
                objects[index].location = .room(1)
            }
            let roomIndex = try XCTUnwrap(
                level.rooms.firstIndex { $0.sourceIndex == 1 }
            )
            var rooms = level.rooms
            rooms[roomIndex] = makeSourceContainmentRoom(
                center: position,
                texture: level.surfacePhysics[0].texture,
                sourceIndex: 1,
                halfExtent: 200
            )
            return replacing(level, rooms: rooms, objects: objects)
        }
        func resumed(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> PlayerSimulation {
            try PlayerSimulation(
                level: contacting(handle, at: continuation.playerPosition),
                continuation: continuation,
                resumedAtTimestamp: timestamp
            )
        }

        let firstForward = PlayerSimulation(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.1, input: .zero)
        let down = try resumed(
            firstForward.continuation,
            contacting: 18_441,
            at: 1
        )
        _ = down.update(at: 1.1, input: .zero)
        let repeatForward = try resumed(
            down.continuation,
            contacting: 12_300,
            at: 2
        )
        _ = repeatForward.update(at: 2.1, input: .zero)
        let repeatForwardGoal = try resumed(
            repeatForward.continuation,
            contacting: 12_301,
            at: 3
        )
        _ = repeatForwardGoal.update(at: 3.1, input: .zero)
        let normalReturn = try resumed(
            repeatForwardGoal.continuation,
            contacting: 12_300,
            at: 4
        )
        let normalFrame = normalReturn.update(at: 4.1, input: .zero)
        XCTAssertEqual(
            normalFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Now Go Left until you stop."],
                    voiceSourceName: "lright.osf",
                    voicePrecedesHUDMessages: true
                ),
            ]
        )
        XCTAssertEqual(normalFrame.enabledPlayerControls, [.left])
        XCTAssertTrue(
            normalReturn.update(at: 4.2, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )

        let restored = try resumed(
            try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(normalReturn.continuation)
            ),
            contacting: 12_300,
            at: 5
        )
        let restoredFrame = restored.update(at: 5.1, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.left])

        let earlyDown = PlayerSimulation(
            level: try contacting(18_441, at: player.position),
            presentationReadyTimestamp: 6
        )
        _ = earlyDown.update(at: 6.1, input: .zero)
        let earlyRepeat = try resumed(
            earlyDown.continuation,
            contacting: 12_300,
            at: 7
        )
        _ = earlyRepeat.update(at: 7.1, input: .zero)
        let earlyForward = try resumed(
            earlyRepeat.continuation,
            contacting: 12_301,
            at: 8
        )
        _ = earlyForward.update(at: 8.1, input: .zero)
        let sharedStartGoal = try resumed(
            earlyForward.continuation,
            contacting: 12_300,
            at: 9
        )
        let sharedFrame = sharedStartGoal.update(at: 9.1, input: .zero)
        XCTAssertEqual(
            sharedFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Now Go Left until you stop."],
                    voiceSourceName: "left1.osf",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: ["Now Go Left until you stop."],
                    voiceSourceName: "lright.osf",
                    voicePrecedesHUDMessages: true
                ),
            ]
        )
        XCTAssertEqual(sharedFrame.enabledPlayerControls, [.left])
        var presentationOrder: [String] = []
        var retainedVoice: String?
        RevivalGameplayView.presentTrainingFeedbackSequence(
            sharedFrame.trainingOpeningFeedback,
            attemptVoice: {
                retainedVoice = $0
                presentationOrder.append("voice:\($0)")
            },
            attemptSound: { name, _ in
                presentationOrder.append("sound:\(name)")
            },
            presentHUDMessages: {
                presentationOrder.append(contentsOf: $0.map { "hud:\($0)" })
            }
        )
        XCTAssertEqual(
            presentationOrder,
            [
                "hud:Now Go Left until you stop.",
                "voice:lright.osf",
                "hud:Now Go Left until you stop.",
            ]
        )
        XCTAssertEqual(retainedVoice, "lright.osf")

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(normalReturn.continuation)
            ) as? [String: Any]
        )
        var hostileOpening = try XCTUnwrap(
            hostileObject["trainingOpeningState"] as? [String: Any]
        )
        hostileOpening["repeatForwardGoalWasPresented"] = false
        hostileObject["trainingOpeningState"] = hostileOpening
        let hostile = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostile,
                resumedAtTimestamp: 10
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.repeatReturnLeft = nil
        compatibleLesson.repeatReturnRight = nil
        compatibleLesson.repeatReturnUp = nil
        compatibleLesson.repeatReturnDown = nil
        compatibleLesson.continueToCourse = nil
        let compatibleLevel = replacing(
            level,
            trainingOpeningLesson: compatibleLesson,
            voiceClips: level.voiceClips.filter {
                $0.sourceName != "lright.osf"
            }
        )
        XCTAssertNoThrow(try compatibleLevel.validate())
    }

    @MainActor
    func testTrainingScript008RepeatsForwardGoalReturnInReleasedOrderAndRestores()
        throws
    {
        let level = makeTrainingScript003Level()
        let repeatForwardGoal = try XCTUnwrap(
            level.trainingOpeningLesson?.repeatForwardGoal
        )
        XCTAssertEqual(repeatForwardGoal.forwardGoalObjectHandle, 12_301)
        let forwardGoalPresentation = try XCTUnwrap(
            level.objectPresentations.first {
                $0.objectHandle
                    == repeatForwardGoal.forwardGoalObjectHandle
            }
        )
        let forwardGoalModel = try XCTUnwrap(level.models.first {
            $0.source == forwardGoalPresentation.primaryModel
        })
        XCTAssertEqual(
            repeatForwardGoal.collisionRadius,
            sourceObjectPresentationSize(
                model: forwardGoalModel,
                objectType: 7
            )
        )
        XCTAssertEqual(
            repeatForwardGoal.reverseInstruction,
            "Now use the reverse Key to return to where you started!"
        )
        XCTAssertEqual(
            repeatForwardGoal.soundLogicalName,
            "MenuBeepEnter"
        )
        let menuBeep = try XCTUnwrap(level.soundClips.first {
            $0.logicalName == repeatForwardGoal.soundLogicalName
        })
        XCTAssertEqual(menuBeep.sourceName, "MenuBeepSelectC.wav")
        XCTAssertEqual(menuBeep.importVolume, 0.7)

        let player = try XCTUnwrap(
            level.objects.first { $0.handle == 2_048 }
        )
        let goalHandles: [UInt32] = [
            12_301,
            12_300,
            12_299,
            18_441,
        ]
        func contacting(
            _ handle: UInt32,
            at position: Vector3
        ) throws -> Level {
            var objects = level.objects
            for goalHandle in goalHandles {
                let index = try XCTUnwrap(
                    objects.firstIndex { $0.handle == goalHandle }
                )
                objects[index].position = goalHandle == handle
                    ? position
                    : .init(
                        x: position.x + 100,
                        y: position.y,
                        z: position.z
                    )
                objects[index].location = .room(1)
            }
            let roomIndex = try XCTUnwrap(
                level.rooms.firstIndex { $0.sourceIndex == 1 }
            )
            var rooms = level.rooms
            rooms[roomIndex] = makeSourceContainmentRoom(
                center: position,
                texture: level.surfacePhysics[0].texture,
                sourceIndex: 1,
                halfExtent: 200
            )
            return replacing(level, rooms: rooms, objects: objects)
        }
        func resumed(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> PlayerSimulation {
            try PlayerSimulation(
                level: contacting(handle, at: continuation.playerPosition),
                continuation: continuation,
                resumedAtTimestamp: timestamp
            )
        }

        let firstForward = PlayerSimulation(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.1, input: .zero)
        let down = try resumed(
            firstForward.continuation,
            contacting: 18_441,
            at: 1
        )
        _ = down.update(at: 1.1, input: .zero)
        let repeatForward = try resumed(
            down.continuation,
            contacting: 12_300,
            at: 2
        )
        _ = repeatForward.update(at: 2.1, input: .zero)
        let normalReturn = try resumed(
            repeatForward.continuation,
            contacting: 12_301,
            at: 3
        )
        let normalFrame = normalReturn.update(at: 3.1, input: .zero)
        XCTAssertEqual(
            normalFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [
                        "Now use the reverse Key to return to where you started!",
                    ],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: "MenuBeepEnter"
                ),
            ]
        )
        XCTAssertEqual(
            normalFrame.enabledPlayerControls,
            [.reverse, .left]
        )
        var normalPresentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            normalFrame.trainingOpeningFeedback,
            attemptVoice: {
                normalPresentationOrder.append("voice:\($0)")
            },
            attemptSound: { name, _ in
                normalPresentationOrder.append("sound:\(name)")
            },
            presentHUDMessages: {
                normalPresentationOrder.append(
                    contentsOf: $0.map { "hud:\($0)" }
                )
            }
        )
        XCTAssertEqual(
            normalPresentationOrder,
            [
                "sound:MenuBeepEnter",
                "hud:Now use the reverse Key to return to where you started!",
            ]
        )
        XCTAssertTrue(
            normalReturn.update(at: 3.2, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )

        let restored = try resumed(
            try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(normalReturn.continuation)
            ),
            contacting: 12_301,
            at: 4
        )
        let restoredFrame = restored.update(at: 4.1, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            restoredFrame.enabledPlayerControls,
            [.reverse, .left]
        )

        let earlyDown = PlayerSimulation(
            level: try contacting(18_441, at: player.position),
            presentationReadyTimestamp: 5
        )
        _ = earlyDown.update(at: 5.1, input: .zero)
        let earlyRepeat = try resumed(
            earlyDown.continuation,
            contacting: 12_300,
            at: 6
        )
        _ = earlyRepeat.update(at: 6.1, input: .zero)
        let sharedCallback = try resumed(
            earlyRepeat.continuation,
            contacting: 12_301,
            at: 7
        )
        let sharedFrame = sharedCallback.update(at: 7.1, input: .zero)
        XCTAssertEqual(
            sharedFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Excellent!"],
                    voiceSourceName: "return1.osf",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: [
                        "Now use the reverse Key to return to where you started!",
                    ],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: [
                        "Now use the reverse Key to return to where you started!",
                    ],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false,
                    soundSourceName: "MenuBeepEnter"
                ),
            ]
        )
        XCTAssertEqual(sharedFrame.enabledPlayerControls, [.reverse])
        var sharedPresentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            sharedFrame.trainingOpeningFeedback,
            attemptVoice: {
                sharedPresentationOrder.append("voice:\($0)")
            },
            attemptSound: { name, _ in
                sharedPresentationOrder.append("sound:\(name)")
            },
            presentHUDMessages: {
                sharedPresentationOrder.append(
                    contentsOf: $0.map { "hud:\($0)" }
                )
            }
        )
        XCTAssertEqual(
            sharedPresentationOrder,
            [
                "hud:Excellent!",
                "voice:return1.osf",
                "hud:Now use the reverse Key to return to where you started!",
                "sound:MenuBeepEnter",
                "hud:Now use the reverse Key to return to where you started!",
            ]
        )

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(normalReturn.continuation)
            ) as? [String: Any]
        )
        var hostileOpening = try XCTUnwrap(
            hostileObject["trainingOpeningState"] as? [String: Any]
        )
        hostileOpening["repeatForwardWasPresented"] = false
        hostileObject["trainingOpeningState"] = hostileOpening
        let hostile = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostile,
                resumedAtTimestamp: 8
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.repeatForwardGoal = nil
        compatibleLesson.repeatReturnLeft = nil
        let compatibleLevel = replacing(
            level,
            trainingOpeningLesson: compatibleLesson,
            voiceClips: level.voiceClips.filter {
                $0.sourceName != "lright.osf"
            }
        )
        XCTAssertNoThrow(try compatibleLevel.validate())
        XCTAssertNoThrow(
            try JSONDecoder().decode(
                Level.self,
                from: canonicalJSONData(compatibleLevel)
            ).validate()
        )
        var compatibleContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    firstForward.continuation
                )
            ) as? [String: Any]
        )
        var compatibleOpening = try XCTUnwrap(
            compatibleContinuationObject["trainingOpeningState"]
                as? [String: Any]
        )
        compatibleOpening.removeValue(
            forKey: "repeatForwardGoalWasPresented"
        )
        compatibleContinuationObject["trainingOpeningState"] =
            compatibleOpening
        let compatibleContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: compatibleContinuationObject
            )
        )
        XCTAssertNoThrow(
            try PlayerSimulation(
                level: contacting(
                    12_301,
                    at: compatibleContinuation.playerPosition
                ),
                continuation: compatibleContinuation,
                resumedAtTimestamp: 10
            )
        )
    }

    @MainActor
    func testTrainingScript007RepeatsForwardInReleasedOrderAndRestores()
        throws
    {
        let level = makeTrainingScript003Level()
        let repeatForward = try XCTUnwrap(
            level.trainingOpeningLesson?.repeatForward
        )
        XCTAssertEqual(repeatForward.startGoalObjectHandle, 12_300)
        XCTAssertEqual(repeatForward.successMessage, "Excellent!")
        XCTAssertEqual(
            repeatForward.repeatMessage,
            "Let's repeat the exercise we just did."
        )
        XCTAssertEqual(
            repeatForward.forwardInstruction,
            "Move forward until you stop."
        )
        XCTAssertEqual(repeatForward.voiceSourceName, "repeat.osf")

        let player = try XCTUnwrap(
            level.objects.first { $0.handle == 2_048 }
        )
        let goalHandles: [UInt32] = [
            12_301,
            12_300,
            12_299,
            18_441,
        ]
        func contacting(
            _ handle: UInt32,
            at position: Vector3
        ) throws -> Level {
            var objects = level.objects
            for goalHandle in goalHandles {
                let index = try XCTUnwrap(
                    objects.firstIndex { $0.handle == goalHandle }
                )
                objects[index].position = goalHandle == handle
                    ? position
                    : .init(
                        x: position.x + 100,
                        y: position.y,
                        z: position.z
                    )
                objects[index].location = .room(1)
            }
            let roomIndex = try XCTUnwrap(
                level.rooms.firstIndex { $0.sourceIndex == 1 }
            )
            var rooms = level.rooms
            rooms[roomIndex] = makeSourceContainmentRoom(
                center: position,
                texture: level.surfacePhysics[0].texture,
                sourceIndex: 1,
                halfExtent: 200
            )
            return replacing(level, rooms: rooms, objects: objects)
        }
        func resumed(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> PlayerSimulation {
            try PlayerSimulation(
                level: contacting(handle, at: continuation.playerPosition),
                continuation: continuation,
                resumedAtTimestamp: timestamp
            )
        }

        let earlyDown = PlayerSimulation(
            level: try contacting(18_441, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = earlyDown.update(at: 0.1, input: .zero)
        let earlyRepeat = try resumed(
            earlyDown.continuation,
            contacting: 12_300,
            at: 1
        )
        let earlyRepeatFrame = earlyRepeat.update(at: 1.1, input: .zero)
        XCTAssertEqual(
            earlyRepeatFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Excellent!"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: [
                        "Let's repeat the exercise we just did.",
                    ],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: ["Move forward until you stop."],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: [],
                    voiceSourceName: "repeat.osf",
                    voicePrecedesHUDMessages: false
                ),
            ]
        )
        XCTAssertEqual(earlyRepeatFrame.enabledPlayerControls, [.forward])

        var presentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            earlyRepeatFrame.trainingOpeningFeedback,
            attemptVoice: { presentationOrder.append("voice:\($0)") },
            attemptSound: { name, _ in
                presentationOrder.append("sound:\(name)")
            },
            presentHUDMessages: {
                presentationOrder.append(contentsOf: $0.map { "hud:\($0)" })
            }
        )
        XCTAssertEqual(
            presentationOrder,
            [
                "hud:Excellent!",
                "hud:Let's repeat the exercise we just did.",
                "hud:Move forward until you stop.",
                "voice:repeat.osf",
            ]
        )

        XCTAssertTrue(
            earlyRepeat.update(at: 1.2, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )
        let restored = try resumed(
            try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(earlyRepeat.continuation)
            ),
            contacting: 12_300,
            at: 2
        )
        let restoredFrame = restored.update(at: 2.1, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.forward])

        var unrelatedBitsObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(earlyDown.continuation)
            ) as? [String: Any]
        )
        var unrelatedBitsOpening = try XCTUnwrap(
            unrelatedBitsObject["trainingOpeningState"] as? [String: Any]
        )
        unrelatedBitsOpening["forwardGoalWasReached"] = true
        unrelatedBitsOpening["returnGoalWasReached"] = true
        unrelatedBitsOpening["enabledControls"] = 36
        unrelatedBitsObject["trainingOpeningState"] = unrelatedBitsOpening
        let unrelatedBitsContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: unrelatedBitsObject)
        )
        let unrelatedBitsRepeat = try resumed(
            unrelatedBitsContinuation,
            contacting: 12_300,
            at: 2.2
        )
        XCTAssertEqual(
            unrelatedBitsRepeat.update(
                at: 2.3,
                input: .zero
            ).enabledPlayerControls,
            [.forward, .left]
        )

        let forward = PlayerSimulation(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 3
        )
        _ = forward.update(at: 3.1, input: .zero)
        let right = try resumed(
            forward.continuation,
            contacting: 12_299,
            at: 4
        )
        _ = right.update(at: 4.1, input: .zero)
        let down = try resumed(
            right.continuation,
            contacting: 18_441,
            at: 5
        )
        _ = down.update(at: 5.1, input: .zero)
        let sharedCallback = try resumed(
            down.continuation,
            contacting: 12_300,
            at: 6
        )
        let sharedFrame = sharedCallback.update(at: 6.1, input: .zero)
        XCTAssertEqual(
            sharedFrame.enabledPlayerControls,
            [.forward, .left, .up]
        )
        var sharedOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            sharedFrame.trainingOpeningFeedback,
            attemptVoice: { sharedOrder.append("voice:\($0)") },
            attemptSound: { name, _ in
                sharedOrder.append("sound:\(name)")
            },
            presentHUDMessages: {
                sharedOrder.append(contentsOf: $0.map { "hud:\($0)" })
            }
        )
        XCTAssertEqual(
            sharedOrder,
            [
                "hud:Now Go Left until you stop.",
                "hud:Excellent!",
                "hud:Now Slide up  until you stop.",
                "hud:Excellent!",
                "hud:Let's repeat the exercise we just did.",
                "hud:Move forward until you stop.",
                "voice:repeat.osf",
            ]
        )

        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(earlyRepeat.continuation)
            ) as? [String: Any]
        )
        var hostileOpening = try XCTUnwrap(
            hostileObject["trainingOpeningState"] as? [String: Any]
        )
        hostileOpening["downGoalWasReached"] = false
        hostileObject["trainingOpeningState"] = hostileOpening
        let hostile = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostile,
                resumedAtTimestamp: 7
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        let compatibleBase = try contacting(0, at: player.position)
        var compatibleLesson = try XCTUnwrap(
            compatibleBase.trainingOpeningLesson
        )
        compatibleLesson.repeatForward = nil
        let compatibleLevel = replacing(
            compatibleBase,
            trainingOpeningLesson: compatibleLesson
        )
        let compatibleContinuation = PlayerSimulation(
            level: compatibleLevel,
            presentationReadyTimestamp: 8
        ).continuation
        XCTAssertNoThrow(
            try PlayerSimulation(
                level: compatibleLevel,
                continuation: try JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONEncoder().encode(compatibleContinuation)
                ),
                resumedAtTimestamp: 9
            )
        )
    }

    @MainActor
    func testTrainingScript006IsUnconditionalOrderedOneShotAndRestores()
        throws
    {
        var base = makeTrainingScript003Level()
        var script006Lesson = try XCTUnwrap(base.trainingOpeningLesson)
        script006Lesson.repeatForward = nil
        base = replacing(base, trainingOpeningLesson: script006Lesson)
        let player = try XCTUnwrap(
            base.objects.first { $0.handle == 2_048 }
        )
        let goalHandles: [UInt32] = [
            12_301,
            12_300,
            12_299,
            18_441,
        ]
        func level(
            contacting handle: UInt32,
            at position: Vector3? = nil
        ) throws -> Level {
            let contactPosition = position ?? player.position
            var objects = base.objects
            for goalHandle in goalHandles {
                let index = try XCTUnwrap(
                    objects.firstIndex { $0.handle == goalHandle }
                )
                objects[index].position = goalHandle == handle
                    ? contactPosition
                    : .init(
                        x: contactPosition.x + 100,
                        y: contactPosition.y,
                        z: contactPosition.z
                    )
                objects[index].location = .room(1)
            }
            let roomIndex = try XCTUnwrap(
                base.rooms.firstIndex { $0.sourceIndex == 1 }
            )
            var rooms = base.rooms
            rooms[roomIndex] = makeSourceContainmentRoom(
                center: contactPosition,
                texture: base.surfacePhysics[0].texture,
                sourceIndex: 1,
                halfExtent: 200
            )
            return replacing(base, rooms: rooms, objects: objects)
        }
        func resumed(
            _ continuation: PlayerSimulationContinuation,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> PlayerSimulation {
            let resumedLevel = try level(
                contacting: handle,
                at: continuation.playerPosition
            )
            XCTAssertEqual(
                containingIndoorRoomSourceIndex(
                    in: resumedLevel,
                    position: continuation.playerPosition,
                    candidates: [1]
                ),
                1,
                "resume at \(timestamp)"
            )
            return try PlayerSimulation(
                level: resumedLevel,
                continuation: continuation,
                resumedAtTimestamp: timestamp
            )
        }

        let early = PlayerSimulation(
            level: try level(contacting: 18_441),
            presentationReadyTimestamp: 0
        )
        let earlyFrame = early.update(at: 0.1, input: .zero)
        XCTAssertEqual(
            earlyFrame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Excellent!"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: [
                        "Now Slide down until you return to the start position.",
                    ],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: [],
                    voiceSourceName: "return3.osf",
                    voicePrecedesHUDMessages: false
                ),
            ]
        )
        XCTAssertEqual(earlyFrame.enabledPlayerControls, [.forward, .down])
        var presentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            earlyFrame.trainingOpeningFeedback,
            attemptVoice: { presentationOrder.append("voice:\($0)") },
            attemptSound: { name, _ in
                presentationOrder.append("sound:\(name)")
            },
            presentHUDMessages: {
                presentationOrder.append(contentsOf: $0.map { "hud:\($0)" })
            }
        )
        XCTAssertEqual(
            presentationOrder,
            [
                "hud:Excellent!",
                "hud:Now Slide down until you return to the start position.",
                "voice:return3.osf",
            ]
        )

        let afterEarlyForward = try resumed(
            early.continuation,
            contacting: 12_301,
            at: 1
        )
        XCTAssertEqual(
            afterEarlyForward.update(at: 1.1, input: .zero)
                .enabledPlayerControls,
            [.reverse, .down]
        )
        let afterEarlyLeft = try resumed(
            afterEarlyForward.continuation,
            contacting: 12_300,
            at: 2
        )
        XCTAssertEqual(
            afterEarlyLeft.update(at: 2.1, input: .zero)
                .enabledPlayerControls,
            [.left, .down]
        )
        let afterEarlyRight = try resumed(
            afterEarlyLeft.continuation,
            contacting: 12_299,
            at: 3
        )
        XCTAssertEqual(
            afterEarlyRight.update(at: 3.1, input: .zero)
                .enabledPlayerControls,
            [.right, .down]
        )
        let afterEarlyUp = try resumed(
            afterEarlyRight.continuation,
            contacting: 12_300,
            at: 4
        )
        XCTAssertEqual(
            afterEarlyUp.update(at: 4.1, input: .zero)
                .enabledPlayerControls,
            [.up, .down]
        )
        let restoredAfterEarlyUp = try resumed(
            try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(afterEarlyUp.continuation)
            ),
            contacting: 0,
            at: 5
        )
        let restoredAfterEarlyUpFrame = restoredAfterEarlyUp.update(
            at: 5.1,
            input: .zero
        )
        XCTAssertEqual(
            restoredAfterEarlyUpFrame.enabledPlayerControls,
            [.up, .down]
        )
        XCTAssertTrue(
            restoredAfterEarlyUpFrame.trainingOpeningFeedback.isEmpty
        )
        let earlyRight = PlayerSimulation(
            level: try level(contacting: 12_299),
            presentationReadyTimestamp: 6
        )
        XCTAssertEqual(
            earlyRight.update(at: 6.1, input: .zero)
                .enabledPlayerControls,
            [.forward, .right]
        )
        let earlyRightDown = try resumed(
            earlyRight.continuation,
            contacting: 18_441,
            at: 7
        )
        XCTAssertEqual(
            earlyRightDown.update(at: 7.1, input: .zero)
                .enabledPlayerControls,
            [.forward, .right, .down]
        )
        let restoredEarlyRightDown = try resumed(
            try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(earlyRightDown.continuation)
            ),
            contacting: 0,
            at: 8
        )
        XCTAssertEqual(
            restoredEarlyRightDown.update(at: 8.1, input: .zero)
                .enabledPlayerControls,
            [.forward, .right, .down]
        )
        let earlyRightUpDown = try resumed(
            earlyRightDown.continuation,
            contacting: 12_300,
            at: 8.2
        )
        XCTAssertEqual(
            earlyRightUpDown.update(at: 8.3, input: .zero)
                .enabledPlayerControls,
            [.forward, .up, .down]
        )
        let reverseUpDown = try resumed(
            earlyRightUpDown.continuation,
            contacting: 12_301,
            at: 8.4
        )
        XCTAssertEqual(
            reverseUpDown.update(at: 8.5, input: .zero)
                .enabledPlayerControls,
            [.reverse, .up, .down]
        )
        let restoredReverseUpDown = try resumed(
            try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(reverseUpDown.continuation)
            ),
            contacting: 0,
            at: 8.6
        )
        let restoredReverseUpDownFrame = restoredReverseUpDown.update(
            at: 8.7,
            input: .zero
        )
        XCTAssertEqual(
            restoredReverseUpDownFrame.enabledPlayerControls,
            [.reverse, .up, .down]
        )
        XCTAssertTrue(
            restoredReverseUpDownFrame.trainingOpeningFeedback.isEmpty
        )

        let reverse = PlayerSimulation(
            level: try level(contacting: 12_301),
            presentationReadyTimestamp: 9
        )
        XCTAssertEqual(
            reverse.update(at: 9.1, input: .zero)
                .enabledPlayerControls,
            [.reverse]
        )
        let reverseRight = try resumed(
            reverse.continuation,
            contacting: 12_299,
            at: 10
        )
        XCTAssertEqual(
            reverseRight.update(at: 10.1, input: .zero)
                .enabledPlayerControls,
            [.reverse, .right]
        )
        let reverseRightDown = try resumed(
            reverseRight.continuation,
            contacting: 18_441,
            at: 11
        )
        XCTAssertEqual(
            reverseRightDown.update(at: 11.1, input: .zero)
                .enabledPlayerControls,
            [.reverse, .right, .down]
        )
        let restoredReverseRightDown = try resumed(
            try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(reverseRightDown.continuation)
            ),
            contacting: 0,
            at: 12
        )
        XCTAssertEqual(
            restoredReverseRightDown.update(at: 12.1, input: .zero)
                .enabledPlayerControls,
            [.reverse, .right, .down]
        )

        let normal = PlayerSimulation(
            level: try level(contacting: 12_301),
            presentationReadyTimestamp: 20
        )
        _ = normal.update(at: 20.1, input: .zero)
        let normalLeft = try resumed(
            normal.continuation,
            contacting: 12_300,
            at: 21
        )
        _ = normalLeft.update(at: 21.1, input: .zero)
        let normalRight = try resumed(
            normalLeft.continuation,
            contacting: 12_299,
            at: 22
        )
        _ = normalRight.update(at: 22.1, input: .zero)
        let normalUp = try resumed(
            normalRight.continuation,
            contacting: 12_300,
            at: 23
        )
        XCTAssertEqual(
            normalUp.update(at: 23.1, input: .zero).enabledPlayerControls,
            [.up]
        )
        let normalDown = try resumed(
            normalUp.continuation,
            contacting: 18_441,
            at: 24
        )
        let normalDownFrame = normalDown.update(at: 24.1, input: .zero)
        XCTAssertEqual(normalDownFrame.enabledPlayerControls, [.down])
        XCTAssertEqual(
            normalDownFrame.trainingOpeningFeedback.map(\.voiceSourceName),
            ["", "", "return3.osf"]
        )
        let restored = try PlayerSimulation(
            level: try level(contacting: 18_441),
            continuation: try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(normalDown.continuation)
            ),
            resumedAtTimestamp: 25
        )
        let restoredFrame = restored.update(at: 25.1, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.down])

        var missingLesson = try XCTUnwrap(
            normalDown.level.trainingOpeningLesson
        )
        missingLesson.returnDown = nil
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: replacing(
                    normalDown.level,
                    trainingOpeningLesson: missingLesson
                ),
                continuation: normalDown.continuation,
                resumedAtTimestamp: 26
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(normalDown.continuation)
            ) as? [String: Any]
        )
        var hostileOpening = try XCTUnwrap(
            hostileObject["trainingOpeningState"] as? [String: Any]
        )
        hostileOpening["enabledControls"] = 33
        hostileObject["trainingOpeningState"] = hostileOpening
        let hostileContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: normalDown.level,
                continuation: hostileContinuation,
                resumedAtTimestamp: 27
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        let script006Level = try level(contacting: 0)
        var compatibleLesson = try XCTUnwrap(
            script006Level.trainingOpeningLesson
        )
        compatibleLesson.returnDown = nil
        let compatibleLevel = replacing(
            script006Level,
            trainingOpeningLesson: compatibleLesson
        )
        let oldContinuation = PlayerSimulation(
            level: compatibleLevel,
            presentationReadyTimestamp: 30
        ).continuation
        let restoredOld = try PlayerSimulation(
            level: script006Level,
            continuation: try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(oldContinuation)
            ),
            resumedAtTimestamp: 31
        ).update(at: 31.1, input: .zero)
        XCTAssertEqual(restoredOld.enabledPlayerControls, [.forward])
    }

    @MainActor
    func testTrainingOpeningUsesPriorFrameTimerThenScript004OnceAndRestores() throws {
        var level = makeSliceSixObjectRenderLevel()
        let goalHandle: UInt32 = 12_301
        let startGoalHandle: UInt32 = 12_300
        let leftGoalHandle: UInt32 = 12_299
        let startGoalPresentation = try XCTUnwrap(
            level.objectPresentations.first {
                $0.objectHandle == startGoalHandle
            }
        )
        let startGoalModel = try XCTUnwrap(
            level.models.first {
                $0.source == startGoalPresentation.primaryModel
            }
        )
        let leftGoalPresentation = try XCTUnwrap(
            level.objectPresentations.first {
                $0.objectHandle == leftGoalHandle
            }
        )
        let leftGoalModel = try XCTUnwrap(
            level.models.first {
                $0.source == leftGoalPresentation.primaryModel
            }
        )
        let lesson = TrainingOpeningLesson(
            forwardGoalObjectHandle: goalHandle,
            welcomeDelay: 1,
            welcomeMessage: "Welcome to the Descent 3 Training session.",
            forwardInstruction: "Move forward until you stop.",
            welcomeVoiceSourceName: "welcome.osf",
            successMessage: "Excellent!",
            reverseInstruction: "Now use the reverse Key to return to where you started!",
            successVoiceSourceName: "return1.osf",
            returnLeft: .init(
                startGoalObjectHandle: startGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: startGoalModel,
                    objectType: 7
                ),
                instruction: "Now Go Left until you stop.",
                voiceSourceName: "left1.osf"
            ),
            returnRight: .init(
                leftGoalObjectHandle: leftGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: leftGoalModel,
                    objectType: 7
                ),
                successMessage: "Excellent!",
                instruction:
                    "Now Slide right until you return to the start position.",
                voiceSourceName: "return2.osf"
            ),
            returnUp: .init(
                startGoalObjectHandle: startGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: startGoalModel,
                    objectType: 7
                ),
                successMessage: "Excellent!",
                instruction: "Now Slide up  until you stop.",
                voiceSourceName: "up1.osf"
            )
        )
        level = level.addingTrainingOpeningLesson(lesson, voiceClips: [])

        let unconditionalPlayer = try XCTUnwrap(
            level.objects.first {
                $0.handle == 2_048
            }
        )
        let openingGoalHandles: [UInt32] = [
            goalHandle,
            startGoalHandle,
            leftGoalHandle,
            18_441,
        ]
        let isolatedOpeningLevel = level
        func contacting(
            _ handle: UInt32,
            at position: Vector3
        ) throws -> Level {
            var objects = isolatedOpeningLevel.objects
            for openingGoalHandle in openingGoalHandles {
                let index = try XCTUnwrap(
                    objects.firstIndex {
                        $0.handle == openingGoalHandle
                    }
                )
                objects[index].position = openingGoalHandle == handle
                    ? position
                    : .init(
                        x: position.x + 100,
                        y: position.y,
                        z: position.z
                    )
                objects[index].location = .room(1)
            }
            let roomIndex = try XCTUnwrap(
                isolatedOpeningLevel.rooms.firstIndex {
                    $0.sourceIndex == 1
                }
            )
            var rooms = isolatedOpeningLevel.rooms
            rooms[roomIndex] = makeSourceContainmentRoom(
                center: position,
                texture: isolatedOpeningLevel.surfacePhysics[0].texture,
                sourceIndex: 1,
                halfExtent: 200
            )
            return replacing(
                isolatedOpeningLevel,
                rooms: rooms,
                objects: objects
            )
        }
        let unconditionalLevel = try contacting(
            leftGoalHandle,
            at: unconditionalPlayer.position
        )
        let unconditionalSimulation = PlayerSimulation(
            level: unconditionalLevel,
            presentationReadyTimestamp: 0
        )
        let unconditionalScript004 = unconditionalSimulation.update(
            at: 0.1,
            input: .zero
        )
        XCTAssertTrue(
            unconditionalScript004.trainingOpeningFeedback.contains {
                $0.voiceSourceName == "return2.osf"
            }
        )
        XCTAssertEqual(
            unconditionalScript004.enabledPlayerControls,
            [.forward, .right]
        )
        let unconditionalContinuationData = try JSONEncoder().encode(
            unconditionalSimulation.continuation
        )
        XCTAssertEqual(
            containingIndoorRoomSourceIndex(
                in: unconditionalLevel,
                position: unconditionalScript004.playerView.camera.position,
                candidates: [1]
            ),
            1
        )
        let unconditionalContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: unconditionalContinuationData
        )
        let unconditionalStartLevel = try contacting(
            startGoalHandle,
            at: unconditionalContinuation.playerPosition
        )
        let restoredUnconditionalScript004 = try PlayerSimulation(
            level: unconditionalStartLevel,
            continuation: unconditionalContinuation,
            resumedAtTimestamp: 1
        )
        let resumedUnconditionalScript004 = restoredUnconditionalScript004
            .update(at: 1.1, input: .zero)
        XCTAssertEqual(
            resumedUnconditionalScript004.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Excellent!"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: ["Now Slide up  until you stop."],
                    voiceSourceName: "up1.osf",
                    voicePrecedesHUDMessages: true
                ),
            ]
        )
        XCTAssertEqual(
            resumedUnconditionalScript004.enabledPlayerControls,
            [.forward, .up]
        )
        let earlyUpContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(
                restoredUnconditionalScript004.continuation
            )
        )
        let restoredEarlyUpSimulation = try PlayerSimulation(
            level: unconditionalStartLevel,
            continuation: earlyUpContinuation,
            resumedAtTimestamp: 2
        )
        let restoredEarlyUp = restoredEarlyUpSimulation.update(
            at: 2.1,
            input: .zero
        )
        XCTAssertTrue(restoredEarlyUp.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredEarlyUp.enabledPlayerControls, [.forward, .up])

        let earlyForwardStart = restoredEarlyUpSimulation.continuation
            .playerPosition
        let earlyForwardLevel = try contacting(
            goalHandle,
            at: .init(
                x: earlyForwardStart.x,
                y: earlyForwardStart.y,
                z: earlyForwardStart.z + 50
            )
        )
        let earlyForwardSimulation = try PlayerSimulation(
            level: earlyForwardLevel,
            continuation: restoredEarlyUpSimulation.continuation,
            resumedAtTimestamp: 3
        )
        var earlyForwardGoalFrame: PlayerSimulationFrame?
        var earlyTimestamp = 3.0
        for _ in 0..<80 {
            earlyTimestamp += 0.1
            let frame = earlyForwardSimulation.update(
                at: earlyTimestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "return1.osf"
            }) {
                earlyForwardGoalFrame = frame
                break
            }
        }
        XCTAssertEqual(
            try XCTUnwrap(earlyForwardGoalFrame).enabledPlayerControls,
            [.reverse, .up]
        )
        let earlyForwardContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(
                earlyForwardSimulation.continuation
            )
        )
        let earlyReturnStart = earlyForwardContinuation.playerPosition
        let earlyReturnLevel = try contacting(
            startGoalHandle,
            at: .init(
                x: earlyReturnStart.x,
                y: earlyReturnStart.y,
                z: earlyReturnStart.z - 50
            )
        )
        let restoredAfterEarlyForward = try PlayerSimulation(
            level: earlyReturnLevel,
            continuation: earlyForwardContinuation,
            resumedAtTimestamp: 100
        )
        let resumedAfterEarlyForward = restoredAfterEarlyForward.update(
            at: 100.1,
            input: .zero
        )
        XCTAssertEqual(
            resumedAfterEarlyForward.enabledPlayerControls,
            [.reverse, .up]
        )
        var earlyReturnGoalFrame: PlayerSimulationFrame?
        var earlyReturnTimestamp = 100.1
        for _ in 0..<40 {
            earlyReturnTimestamp += 0.1
            let frame = restoredAfterEarlyForward.update(
                at: earlyReturnTimestamp,
                input: .init(forward: -1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "left1.osf"
            }) {
                earlyReturnGoalFrame = frame
                break
            }
        }
        XCTAssertEqual(
            try XCTUnwrap(earlyReturnGoalFrame).enabledPlayerControls,
            [.left, .up]
        )
        let earlyReturnContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(
                restoredAfterEarlyForward.continuation
            )
        )
        let restoredAfterEarlyReturn = try PlayerSimulation(
            level: earlyReturnLevel,
            continuation: earlyReturnContinuation,
            resumedAtTimestamp: 200
        )
        XCTAssertEqual(
            restoredAfterEarlyReturn.update(
                at: 200.1,
                input: .zero
            ).enabledPlayerControls,
            [.left, .up]
        )

        let timerLevel = level
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        let playerRoomSourceIndex = try XCTUnwrap({
            if case let .room(roomSourceIndex) =
                level.objects[playerIndex].location {
                return roomSourceIndex
            }
            return nil
        }())
        let containedPlayerStart = level.objects[playerIndex].position
        let playerRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == playerRoomSourceIndex
            }
        )
        level.rooms[playerRoomIndex] = makeSourceContainmentRoom(
            center: containedPlayerStart,
            texture: level.surfacePhysics[0].texture,
            sourceIndex: playerRoomSourceIndex,
            halfExtent: 200
        )
        XCTAssertEqual(
            containingIndoorRoomSourceIndex(
                in: level,
                position: containedPlayerStart,
                candidates: [playerRoomSourceIndex]
            ),
            playerRoomSourceIndex
        )
        level.objects[playerIndex].position = containedPlayerStart
        let goalIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == goalHandle }
        )
        level.objects[goalIndex].position = Vector3(
            x: level.objects[playerIndex].position.x,
            y: level.objects[playerIndex].position.y,
            z: level.objects[playerIndex].position.z + 50
        )
        level.objects[goalIndex].location = level.objects[playerIndex].location
        level.objects[playerIndex].orientation = Matrix3(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )
        let hiddenGoalExtraction = try extractWorldForRendering(
            level,
            playerView: defaultPlayerView(in: level)
        )
        XCTAssertFalse(
            hiddenGoalExtraction.admittedObjectHandles.contains(goalHandle)
        )
        XCTAssertFalse(
            hiddenGoalExtraction.admittedObjectHandles.contains(startGoalHandle)
        )

        var sharedCallbackLevel = level
        let sharedPlayerIndex = try XCTUnwrap(
            sharedCallbackLevel.objects.firstIndex { $0.handle == 2_048 }
        )
        let sharedForwardIndex = try XCTUnwrap(
            sharedCallbackLevel.objects.firstIndex { $0.handle == goalHandle }
        )
        let sharedLeftIndex = try XCTUnwrap(
            sharedCallbackLevel.objects.firstIndex { $0.handle == 12_299 }
        )
        let sharedStartIndex = try XCTUnwrap(
            sharedCallbackLevel.objects.firstIndex {
                $0.handle == startGoalHandle
            }
        )
        let sharedPlayerPosition =
            sharedCallbackLevel.objects[sharedPlayerIndex].position
        let sharedPlayerLocation =
            sharedCallbackLevel.objects[sharedPlayerIndex].location
        sharedCallbackLevel.objects[sharedForwardIndex].position =
            sharedPlayerPosition
        sharedCallbackLevel.objects[sharedForwardIndex].location =
            sharedPlayerLocation
        sharedCallbackLevel.objects[sharedLeftIndex].position =
            sharedPlayerPosition
        sharedCallbackLevel.objects[sharedLeftIndex].location =
            sharedPlayerLocation
        sharedCallbackLevel.objects[sharedStartIndex].position = .init(
            x: sharedPlayerPosition.x,
            y: sharedPlayerPosition.y,
            z: sharedPlayerPosition.z + 50
        )
        let sharedCallbackSetup = PlayerSimulation(
            level: sharedCallbackLevel,
            presentationReadyTimestamp: 0
        )
        let sharedSetupFrame = sharedCallbackSetup.update(
            at: 0.1,
            input: .zero
        )
        XCTAssertEqual(
            sharedSetupFrame.enabledPlayerControls,
            [.reverse, .right]
        )
        sharedCallbackLevel.objects[sharedForwardIndex].position = .init(
            x: sharedPlayerPosition.x,
            y: sharedPlayerPosition.y,
            z: sharedPlayerPosition.z + 50
        )
        sharedCallbackLevel.objects[sharedLeftIndex].position = .init(
            x: sharedPlayerPosition.x,
            y: sharedPlayerPosition.y,
            z: sharedPlayerPosition.z + 50
        )
        sharedCallbackLevel.objects[sharedStartIndex].position =
            sharedPlayerPosition
        sharedCallbackLevel.objects[sharedStartIndex].location =
            sharedPlayerLocation
        let sharedCallback = try PlayerSimulation(
            level: sharedCallbackLevel,
            continuation: sharedCallbackSetup.continuation,
            resumedAtTimestamp: 10
        ).update(at: 10.1, input: .zero)
        XCTAssertEqual(
            sharedCallback.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Now Go Left until you stop."],
                    voiceSourceName: "left1.osf",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: ["Excellent!"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: ["Now Slide up  until you stop."],
                    voiceSourceName: "up1.osf",
                    voicePrecedesHUDMessages: true
                ),
            ]
        )
        XCTAssertEqual(sharedCallback.enabledPlayerControls, [.left, .up])

        let timerOnly = PlayerSimulation(
            level: timerLevel,
            presentationReadyTimestamp: 0
        )
        for frameIndex in 1...9 {
            let frame = timerOnly.update(
                at: Double(frameIndex) * 0.1,
                input: .zero
            )
            XCTAssertTrue(frame.trainingOpeningFeedback.isEmpty)
        }
        let welcome = timerOnly.update(at: 1, input: .zero)
        XCTAssertEqual(
            welcome.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Welcome to the Descent 3 Training session.",
                    "Move forward until you stop.",
                ],
                voiceSourceName: "welcome.osf",
                voicePrecedesHUDMessages: false
            )]
        )
        XCTAssertEqual(welcome.enabledPlayerControls, [.forward])

        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var collisionFrame: PlayerSimulationFrame?
        for frameIndex in 1...20 {
            let frame = simulation.update(
                at: Double(frameIndex) * 0.1,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "return1.osf"
            }) {
                collisionFrame = frame
                break
            }
        }
        let firstGoal = try XCTUnwrap(collisionFrame)
        XCTAssertEqual(
            firstGoal.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Excellent!"],
                    voiceSourceName: "return1.osf",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: [
                        "Now use the reverse Key to return to where you started!",
                    ],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
            ]
        )
        XCTAssertEqual(firstGoal.enabledPlayerControls, [.reverse])

        let continuationData = try JSONEncoder().encode(simulation.continuation)
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: continuationData
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        let afterRestore = restored.update(
            at: 100.1,
            input: .init(forward: 1)
        )
        XCTAssertTrue(afterRestore.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(afterRestore.enabledPlayerControls, [.reverse])

        var returnFrame: PlayerSimulationFrame?
        for frameIndex in 2...40 {
            let frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: .init(forward: -1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "left1.osf"
            }) {
                returnFrame = frame
                break
            }
        }
        let returnedToStart = try XCTUnwrap(returnFrame)
        XCTAssertEqual(
            returnedToStart.trainingOpeningFeedback,
            [.init(
                hudMessages: ["Now Go Left until you stop."],
                voiceSourceName: "left1.osf",
                voicePrecedesHUDMessages: false
            )]
        )
        XCTAssertEqual(returnedToStart.enabledPlayerControls, [.left])
        let afterReturn = restored.update(
            at: 104.1,
            input: .init(forward: -1)
        )
        XCTAssertTrue(afterReturn.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(afterReturn.enabledPlayerControls, [.left])

        let returnedContinuationData = try JSONEncoder().encode(
            restored.continuation
        )
        let returnedContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: returnedContinuationData
        )
        let restoredAfterReturn = try PlayerSimulation(
            level: try contacting(
                leftGoalHandle,
                at: returnedContinuation.playerPosition
            ),
            continuation: returnedContinuation,
            resumedAtTimestamp: 200
        )
        let reachedLeftGoal = restoredAfterReturn.update(
            at: 200.1,
            input: .zero
        )
        XCTAssertEqual(
            reachedLeftGoal.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Excellent!"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: [
                        "Now Slide right until you return to the start position.",
                    ],
                    voiceSourceName: "return2.osf",
                    voicePrecedesHUDMessages: true
                ),
            ]
        )
        XCTAssertEqual(reachedLeftGoal.enabledPlayerControls, [.right])
        var presentationOrder: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            reachedLeftGoal.trainingOpeningFeedback,
            attemptVoice: { presentationOrder.append("voice:\($0)") },
            attemptSound: { name, _ in
                presentationOrder.append("sound:\(name)")
            },
            presentHUDMessages: {
                presentationOrder.append(contentsOf: $0.map { "hud:\($0)" })
            }
        )
        XCTAssertEqual(
            presentationOrder,
            [
                "hud:Excellent!",
                "voice:return2.osf",
                "hud:Now Slide right until you return to the start position.",
            ]
        )
        let afterLeftGoal = restoredAfterReturn.update(
            at: 208.1,
            input: .zero
        )
        XCTAssertTrue(afterLeftGoal.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(afterLeftGoal.enabledPlayerControls, [.right])

        let script004ContinuationData = try JSONEncoder().encode(
            restoredAfterReturn.continuation
        )
        let script004Continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: script004ContinuationData
        )
        var compatibleScript004Lesson = lesson
        compatibleScript004Lesson.returnUp = nil
        let compatibleScript004 = try PlayerSimulation(
            level: replacing(
                restoredAfterReturn.level,
                trainingOpeningLesson: compatibleScript004Lesson
            ),
            continuation: script004Continuation,
            resumedAtTimestamp: 300
        ).update(at: 300.1, input: .zero)
        XCTAssertTrue(compatibleScript004.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(compatibleScript004.enabledPlayerControls, [.right])

        let restoredAfterScript004 = try PlayerSimulation(
            level: try contacting(
                startGoalHandle,
                at: script004Continuation.playerPosition
            ),
            continuation: script004Continuation,
            resumedAtTimestamp: 300
        )
        let returnedFromLeft = restoredAfterScript004.update(
            at: 300.1,
            input: .zero
        )
        XCTAssertEqual(
            returnedFromLeft.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Excellent!"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: false
                ),
                .init(
                    hudMessages: ["Now Slide up  until you stop."],
                    voiceSourceName: "up1.osf",
                    voicePrecedesHUDMessages: true
                ),
            ]
        )
        XCTAssertEqual(returnedFromLeft.enabledPlayerControls, [.up])
        let afterScript005 = restoredAfterScript004.update(
            at: 308.1,
            input: .zero
        )
        XCTAssertTrue(afterScript005.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(afterScript005.enabledPlayerControls, [.up])

        let script005Continuation = restoredAfterScript004.continuation
        let restoredAfterScript005 = try PlayerSimulation(
            level: restoredAfterScript004.level,
            continuation: script005Continuation,
            resumedAtTimestamp: 400
        ).update(at: 400.1, input: .zero)
        XCTAssertTrue(
            restoredAfterScript005.trainingOpeningFeedback.isEmpty
        )
        XCTAssertEqual(restoredAfterScript005.enabledPlayerControls, [.up])

        var missingUpLesson = lesson
        missingUpLesson.returnUp = nil
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: replacing(
                    restoredAfterScript004.level,
                    trainingOpeningLesson: missingUpLesson
                ),
                continuation: script005Continuation,
                resumedAtTimestamp: 400
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var missingRightLesson = lesson
        missingRightLesson.returnRight = nil
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: replacing(
                    restoredAfterReturn.level,
                    trainingOpeningLesson: missingRightLesson
                ),
                continuation: script004Continuation,
                resumedAtTimestamp: 300
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var compatibleLesson = lesson
        compatibleLesson.returnLeft = nil
        let compatibleLevel = replacing(
            level,
            trainingOpeningLesson: compatibleLesson
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: compatibleLevel,
                continuation: returnedContinuation,
                resumedAtTimestamp: 300
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        var hostileObject = continuationObject
        var hostileLocation = try XCTUnwrap(
            hostileObject["playerLocation"] as? [String: Any]
        )
        hostileLocation["room"] = ["_0": 999_999]
        hostileObject["playerLocation"] = hostileLocation
        let hostileContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
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

        let wrongExistingRoom = try XCTUnwrap(
            level.rooms.first {
                $0.sourceIndex != firstGoal.playerView.roomSourceIndex
                    && containingIndoorRoomSourceIndex(
                        in: level,
                        position: firstGoal.playerView.camera.position,
                        candidates: [$0.sourceIndex]
                    ) == nil
            }?.sourceIndex
        )
        var hostileOwner = continuationObject
        var hostileOwnerLocation = try XCTUnwrap(
            hostileOwner["playerLocation"] as? [String: Any]
        )
        hostileOwnerLocation["room"] = ["_0": wrongExistingRoom]
        hostileOwner["playerLocation"] = hostileOwnerLocation
        let hostileOwnerContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileOwner)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostileOwnerContinuation,
                resumedAtTimestamp: 100
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var hostileOpening = hostileObject
        hostileOpening["playerLocation"] = try XCTUnwrap(
            continuationObject["playerLocation"]
        )
        var openingState = try XCTUnwrap(
            hostileOpening["trainingOpeningState"] as? [String: Any]
        )
        openingState["timerRemaining"] = -1
        openingState["welcomeWasPresented"] = false
        hostileOpening["trainingOpeningState"] = openingState
        let hostileOpeningContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileOpening)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: hostileOpeningContinuation,
                resumedAtTimestamp: 100
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    func testTrainingOpeningPreservesGoalThenTimerFeedbackOnTheSameFrame() throws {
        var level = makeSliceSixObjectRenderLevel()
        let goalHandle: UInt32 = 12_301
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        let goalIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == goalHandle }
        )
        level.objects[goalIndex].position = .init(
            x: level.objects[playerIndex].position.x,
            y: level.objects[playerIndex].position.y,
            z: level.objects[playerIndex].position.z + 0.5
        )
        level.objects[goalIndex].location = level.objects[playerIndex].location
        level = level.addingTrainingOpeningLesson(
            .init(
                forwardGoalObjectHandle: goalHandle,
                welcomeDelay: 0.1,
                welcomeMessage: "Welcome",
                forwardInstruction: "Forward",
                welcomeVoiceSourceName: "welcome.osf",
                successMessage: "Excellent",
                reverseInstruction: "Reverse",
                successVoiceSourceName: "return1.osf"
            ),
            voiceClips: []
        )
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        let simultaneous = simulation.update(
            at: 0.1,
            input: .init(forward: 1)
        )
        XCTAssertEqual(
            simultaneous.trainingOpeningFeedback.map(\.voiceSourceName),
            ["return1.osf", "welcome.osf"]
        )
        XCTAssertEqual(
            RevivalGameplayView.trainingMessageLineCount(
                for: simultaneous.trainingOpeningFeedback
            ),
            4
        )
    }

    func testTrainingOpeningGoalContactStaysOnReachedIndoorTrace() throws {
        var level = makeSliceSixObjectRenderLevel()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        let goalHandle: UInt32 = 12_301
        let goalIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == goalHandle }
        )
        let playerRoom = try XCTUnwrap(
            level.rooms.first { $0.sourceIndex == 1 }
        )
        let disconnectedRoom = LevelRoom(
            sourceIndex: 99,
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                LevelFace(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: $0.lightmapInfoIndex,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: []
        )
        level.rooms.append(disconnectedRoom)
        level.objects[goalIndex].position = level.objects[playerIndex].position
        level.objects[goalIndex].location = .room(disconnectedRoom.sourceIndex)
        level = level.addingTrainingOpeningLesson(
            .init(
                forwardGoalObjectHandle: goalHandle,
                welcomeDelay: 1,
                welcomeMessage: "Welcome",
                forwardInstruction: "Forward",
                welcomeVoiceSourceName: "welcome.osf",
                successMessage: "Excellent",
                reverseInstruction: "Reverse",
                successVoiceSourceName: "return1.osf"
            ),
            voiceClips: []
        )

        let frame = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        ).update(at: 0.1, input: .zero)

        XCTAssertEqual(frame.enabledPlayerControls, [.forward])
        XCTAssertFalse(
            frame.trainingOpeningFeedback.contains {
                $0.voiceSourceName == "return1.osf"
            }
        )
    }
}
