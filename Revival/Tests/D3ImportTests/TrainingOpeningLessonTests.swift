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
        let simulation = GameSession(
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
            simulation.runtimeLevel.rooms.first { $0.sourceIndex == 2 }
        )
        XCTAssertEqual(
            unchangedPortalRoomOne.portals.map(\.flags),
            portalRoomOneFlags
        )
        let openedRoom = try XCTUnwrap(
            simulation.runtimeLevel.rooms.first {
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
                simulation.runtimeLevel.rooms.first {
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

        let restored = try GameSession(
            level: baseLevel,
            world: (try JSONDecoder().decode(
                GameWorld.self,
                from: JSONEncoder().encode(simulation.world)
            )).rebased(onto: baseLevel),
            resumedAtTimestamp: 1
        )
        let restoredFrame = restored.update(at: 1.05, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls.rawValue, 32)

        var compatibleLesson = try XCTUnwrap(
            baseLevel.trainingOpeningLesson
        )
        compatibleLesson.finishCourse = nil
        let compatibleLevel = replacing(
            baseLevel,
            trainingOpeningLesson: compatibleLesson
        )
        XCTAssertNoThrow(try compatibleLevel.validate())

        var laterStartObjects = baseLevel.objects
        let laterStartIndex = try XCTUnwrap(
            laterStartObjects.firstIndex { $0.handle == 6_147 }
        )
        laterStartObjects[laterStartIndex].position =
            simulation.world.playerPosition
        laterStartObjects[laterStartIndex].location =
            simulation.world.playerLocation
        let laterStart = try GameSession(
            level: replacing(baseLevel, objects: laterStartObjects),
            world: simulation.world.rebased(onto: replacing(baseLevel, objects: laterStartObjects)),
            resumedAtTimestamp: 3
        )
        let laterStartFrame = laterStart.update(
            at: 3.05,
            input: .zero
        )
        XCTAssertEqual(laterStartFrame.enabledPlayerControls.rawValue, 63)
        let laterStartPortalRoomTwo = try XCTUnwrap(
            laterStart.runtimeLevel.rooms.first { $0.sourceIndex == 49 }
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
        let normalStart = GameSession(
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
            testWorldObject(normalStart.world)
        )
        highBitContinuationObject["playerControllerBitflags"] = 127
        let highBitContinuation = try decodeTestWorld(highBitContinuationObject)
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
        let normalFinish = try GameSession(
            level: replacing(
                level,
                rooms: normalRooms,
                objects: normalFinishObjects
            ),
            world: highBitContinuation.rebased(onto: replacing(
                level,
                rooms: normalRooms,
                objects: normalFinishObjects
            )),
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
            normalFinish.runtimeLevel.rooms.first { $0.sourceIndex == 2 }
        )
        XCTAssertEqual(normalPortalRoomOne.portals[0].flags & 1, 0)
        XCTAssertNotEqual(normalPortalRoomOne.portals[1].flags & 1, 0)
        let normalPortalRoomTwo = try XCTUnwrap(
            normalFinish.runtimeLevel.rooms.first { $0.sourceIndex == 49 }
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
        let simulation = GameSession(
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
            simulation.runtimeLevel.rooms.first {
                $0.sourceIndex == startCourse.portalRoomSourceIndex
            }
        )
        XCTAssertEqual(
            closedRoom.portals[startCourse.portalIndex].flags & 0x41,
            0x41
        )
        let closedPortal = closedRoom.portals[startCourse.portalIndex]
        let closedReciprocalRoom = try XCTUnwrap(
            simulation.runtimeLevel.rooms.first {
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

        let restored = try GameSession(
            level: baseLevel,
            world: (try JSONDecoder().decode(
                GameWorld.self,
                from: JSONEncoder().encode(simulation.world)
            )).rebased(onto: baseLevel),
            resumedAtTimestamp: 1
        )
        let restoredFrame = restored.update(at: 1.05, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls.rawValue, 63)

        let continuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )

        var preservedObject = continuationObject
        preservedObject["playerControllerBitflags"] = 127
        let preserved = try decodeTestWorld(preservedObject)
        let preservedSimulation = try GameSession(
            level: baseLevel,
            world: preserved.rebased(onto: baseLevel),
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
            _ continuation: GameWorld,
            contacting handle: UInt32,
            at timestamp: Double,
            level resumedLevel: Level? = nil
        ) throws -> GameSession {
            let contactLevel = try contacting(
                handle,
                at: continuation.playerPosition
            )
            return try GameSession(
                level: resumedLevel.map {
                    replacing(
                        contactLevel,
                        trainingOpeningLesson: $0.trainingOpeningLesson
                    )
                } ?? contactLevel,
                world: continuation.rebased(onto: resumedLevel.map {
                    replacing(
                        contactLevel,
                        trainingOpeningLesson: $0.trainingOpeningLesson
                    )
                } ?? contactLevel),
                resumedAtTimestamp: timestamp
            )
        }
        func advance(
            _ continuation: GameWorld,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> GameSession {
            let simulation = try resumed(
                continuation,
                contacting: handle,
                at: timestamp
            )
            _ = simulation.update(at: timestamp + 0.05, input: .zero)
            return simulation
        }

        let firstForward = GameSession(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.05, input: .zero)
        let firstLeftGoal = try advance(
            firstForward.world,
            contacting: 12_299,
            at: 1
        )
        let returnUp = try advance(
            firstLeftGoal.world,
            contacting: 12_300,
            at: 2
        )
        let returnDown = try advance(
            returnUp.world,
            contacting: 18_441,
            at: 3
        )
        let repeatForward = try advance(
            returnDown.world,
            contacting: 12_300,
            at: 4
        )
        let repeatForwardGoal = try advance(
            repeatForward.world,
            contacting: 12_301,
            at: 5
        )
        let repeatReturnLeft = try advance(
            repeatForwardGoal.world,
            contacting: 12_300,
            at: 6
        )
        let repeatReturnRight = try advance(
            repeatReturnLeft.world,
            contacting: 12_299,
            at: 7
        )
        let repeatReturnUp = try advance(
            repeatReturnRight.world,
            contacting: 12_300,
            at: 8
        )
        let repeatReturnDown = try advance(
            repeatReturnUp.world,
            contacting: 18_441,
            at: 9
        )
        let normal = try resumed(
            repeatReturnDown.world,
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
            normal.runtimeLevel.rooms.first {
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
                normal.runtimeLevel.rooms.first {
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
            normal.world.playerPosition
        courseObjects[courseIndex].location =
            normal.world.playerLocation
        let normalCourse = try GameSession(
            level: replacing(
                level,
                rooms: try contacting(
                    startCourse.startCourseObjectHandle,
                    at: normal.world.playerPosition
                ).rooms,
                objects: courseObjects
            ),
            world: normal.world.rebased(onto: replacing(
                level,
                rooms: try contacting(
                    startCourse.startCourseObjectHandle,
                    at: normal.world.playerPosition
                ).rooms,
                objects: courseObjects
            )),
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
            normalCourse.runtimeLevel.rooms.first {
                $0.sourceIndex == startCourse.portalRoomSourceIndex
            }
        )
        XCTAssertEqual(normalCoursePortalRoom.portals[0].flags & 1, 0)
        XCTAssertNotEqual(
            normalCoursePortalRoom.portals[startCourse.portalIndex]
                .flags & 1,
            0
        )
        // Script 014 already closed the start-course portal in the saved
        // world, so the restore needs no replay.
        let restoredNormalCourse = try GameSession(
            level: try contacting(
                12_300,
                at: normal.world.playerPosition
            ),
            world: normalCourse.world.rebased(onto: try contacting(
                12_300,
                at: normal.world.playerPosition
            )),
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
            restoredNormalCourse.runtimeLevel.rooms.first {
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

        let restored = try GameSession(
            level: try contacting(
                12_300,
                at: normal.world.playerPosition
            ),
            world: (try JSONDecoder().decode(
                GameWorld.self,
                from: JSONEncoder().encode(normal.world)
            )).rebased(onto: try contacting(
                12_300,
                at: normal.world.playerPosition
            )),
            resumedAtTimestamp: 11
        )
        let restoredFrame = restored.update(at: 11.05, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.down])
        let restoredRoom = try XCTUnwrap(
            restored.runtimeLevel.rooms.first {
                $0.sourceIndex == continueToCourse.portalRoomSourceIndex
            }
        )
        XCTAssertTrue(
            continueToCourse.orderedPortalIndices.allSatisfy {
                restoredRoom.portals[$0].flags & 1 == 0
            }
        )

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.continueToCourse = nil
        let compatibleLevel = replacing(
            level,
            trainingOpeningLesson: compatibleLesson
        )
        XCTAssertNoThrow(try compatibleLevel.validate())
        let compatibleSimulation = try resumed(
            repeatReturnDown.world,
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
            compatibleSimulation.runtimeLevel.rooms.first {
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
            _ continuation: GameWorld,
            contacting handle: UInt32,
            at timestamp: Double,
            level resumedLevel: Level? = nil
        ) throws -> GameSession {
            let contactLevel = try contacting(
                handle,
                at: continuation.playerPosition
            )
            return try GameSession(
                level: resumedLevel.map {
                    replacing(
                        contactLevel,
                        trainingOpeningLesson: $0.trainingOpeningLesson
                    )
                } ?? contactLevel,
                world: continuation.rebased(onto: resumedLevel.map {
                    replacing(
                        contactLevel,
                        trainingOpeningLesson: $0.trainingOpeningLesson
                    )
                } ?? contactLevel),
                resumedAtTimestamp: timestamp
            )
        }
        func advance(
            _ continuation: GameWorld,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> GameSession {
            let simulation = try resumed(
                continuation,
                contacting: handle,
                at: timestamp
            )
            _ = simulation.update(at: timestamp + 0.05, input: .zero)
            return simulation
        }

        let firstForward = GameSession(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.05, input: .zero)
        let firstLeftGoal = try advance(
            firstForward.world,
            contacting: 12_299,
            at: 1
        )
        let returnUp = try advance(
            firstLeftGoal.world,
            contacting: 12_300,
            at: 2
        )
        let returnDown = try advance(
            returnUp.world,
            contacting: 18_441,
            at: 3
        )
        let repeatForward = try advance(
            returnDown.world,
            contacting: 12_300,
            at: 4
        )
        let repeatForwardGoal = try advance(
            repeatForward.world,
            contacting: 12_301,
            at: 5
        )
        let repeatReturnLeft = try advance(
            repeatForwardGoal.world,
            contacting: 12_300,
            at: 6
        )
        let repeatReturnRight = try advance(
            repeatReturnLeft.world,
            contacting: 12_299,
            at: 7
        )
        let repeatReturnUp = try advance(
            repeatReturnRight.world,
            contacting: 12_300,
            at: 8
        )
        let normalReturn = try resumed(
            repeatReturnUp.world,
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
                GameWorld.self,
                from: JSONEncoder().encode(normalReturn.world)
            ),
            contacting: 18_441,
            at: 10
        )
        let restoredFrame = restored.update(at: 10.05, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.down])

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
        let compatibleSimulation = try resumed(
            repeatReturnUp.world,
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
            _ continuation: GameWorld,
            contacting handle: UInt32,
            at timestamp: Double,
            level resumedLevel: Level? = nil
        ) throws -> GameSession {
            let contactLevel = try contacting(
                handle,
                at: continuation.playerPosition
            )
            return try GameSession(
                level: resumedLevel.map {
                    replacing(
                        contactLevel,
                        trainingOpeningLesson: $0.trainingOpeningLesson
                    )
                } ?? contactLevel,
                world: continuation.rebased(onto: resumedLevel.map {
                    replacing(
                        contactLevel,
                        trainingOpeningLesson: $0.trainingOpeningLesson
                    )
                } ?? contactLevel),
                resumedAtTimestamp: timestamp
            )
        }
        func advance(
            _ continuation: GameWorld,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> GameSession {
            let simulation = try resumed(
                continuation,
                contacting: handle,
                at: timestamp
            )
            _ = simulation.update(at: timestamp + 0.1, input: .zero)
            return simulation
        }

        let firstForward = GameSession(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.1, input: .zero)
        let firstLeftGoal = try advance(
            firstForward.world,
            contacting: 12_299,
            at: 1
        )
        let returnUp = try advance(
            firstLeftGoal.world,
            contacting: 12_300,
            at: 2
        )
        let returnDown = try advance(
            returnUp.world,
            contacting: 18_441,
            at: 3
        )
        let repeatForward = try advance(
            returnDown.world,
            contacting: 12_300,
            at: 4
        )
        let repeatForwardGoal = try advance(
            repeatForward.world,
            contacting: 12_301,
            at: 5
        )
        let repeatReturnLeft = try advance(
            repeatForwardGoal.world,
            contacting: 12_300,
            at: 6
        )
        let repeatReturnRight = try advance(
            repeatReturnLeft.world,
            contacting: 12_299,
            at: 7
        )
        let normalReturn = try resumed(
            repeatReturnRight.world,
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
                GameWorld.self,
                from: JSONEncoder().encode(normalReturn.world)
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

        let earlyDown = GameSession(
            level: try contacting(18_441, at: player.position),
            presentationReadyTimestamp: 10
        )
        _ = earlyDown.update(at: 10.1, input: .zero)
        let earlyRepeat = try advance(
            earlyDown.world,
            contacting: 12_300,
            at: 11
        )
        let earlyForward = try advance(
            earlyRepeat.world,
            contacting: 12_301,
            at: 12
        )
        let earlyReturnLeft = try advance(
            earlyForward.world,
            contacting: 12_300,
            at: 13
        )
        let earlyReturnRight = try advance(
            earlyReturnLeft.world,
            contacting: 12_299,
            at: 14
        )
        let sharedStartGoal = try resumed(
            earlyReturnRight.world,
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
        let compatibleSimulation = try resumed(
            repeatReturnRight.world,
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
            _ continuation: GameWorld,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> GameSession {
            try GameSession(
                level: contacting(handle, at: continuation.playerPosition),
                world: continuation.rebased(onto: contacting(handle, at: continuation.playerPosition)),
                resumedAtTimestamp: timestamp
            )
        }
        func advance(
            _ continuation: GameWorld,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> GameSession {
            let simulation = try resumed(
                continuation,
                contacting: handle,
                at: timestamp
            )
            _ = simulation.update(at: timestamp + 0.1, input: .zero)
            return simulation
        }

        let firstForward = GameSession(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.1, input: .zero)
        let firstLeftGoal = try advance(
            firstForward.world,
            contacting: 12_299,
            at: 1
        )
        let returnUp = try advance(
            firstLeftGoal.world,
            contacting: 12_300,
            at: 2
        )
        let returnDown = try advance(
            returnUp.world,
            contacting: 18_441,
            at: 3
        )
        let repeatForward = try advance(
            returnDown.world,
            contacting: 12_300,
            at: 4
        )
        let repeatForwardGoal = try advance(
            repeatForward.world,
            contacting: 12_301,
            at: 5
        )
        let repeatReturnLeft = try advance(
            repeatForwardGoal.world,
            contacting: 12_300,
            at: 6
        )
        let normalReturn = try resumed(
            repeatReturnLeft.world,
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
                GameWorld.self,
                from: JSONEncoder().encode(normalReturn.world)
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

        let earlyDown = GameSession(
            level: try contacting(18_441, at: player.position),
            presentationReadyTimestamp: 9
        )
        _ = earlyDown.update(at: 9.1, input: .zero)
        let earlyRepeat = try advance(
            earlyDown.world,
            contacting: 12_300,
            at: 10
        )
        let earlyForward = try advance(
            earlyRepeat.world,
            contacting: 12_301,
            at: 11
        )
        let earlyReturnLeft = try advance(
            earlyForward.world,
            contacting: 12_300,
            at: 12
        )
        let sharedLeftGoal = try resumed(
            earlyReturnLeft.world,
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
        let compatibleContactLevel = replacing(
            try contacting(
                12_299,
                at: repeatReturnLeft.world.playerPosition
            ),
            trainingOpeningLesson: compatibleLesson
        )
        let compatibleSimulation = try GameSession(
            level: compatibleContactLevel,
            world: repeatReturnLeft.world.rebased(onto: compatibleContactLevel),
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
