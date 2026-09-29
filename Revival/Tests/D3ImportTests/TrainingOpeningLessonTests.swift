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
}
