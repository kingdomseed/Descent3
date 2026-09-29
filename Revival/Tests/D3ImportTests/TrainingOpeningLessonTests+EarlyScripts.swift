import XCTest

extension WorldRenderingTests {
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

        let firstForward = GameSession(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.1, input: .zero)
        let down = try resumed(
            firstForward.world,
            contacting: 18_441,
            at: 1
        )
        _ = down.update(at: 1.1, input: .zero)
        let repeatForward = try resumed(
            down.world,
            contacting: 12_300,
            at: 2
        )
        _ = repeatForward.update(at: 2.1, input: .zero)
        let repeatForwardGoal = try resumed(
            repeatForward.world,
            contacting: 12_301,
            at: 3
        )
        _ = repeatForwardGoal.update(at: 3.1, input: .zero)
        let normalReturn = try resumed(
            repeatForwardGoal.world,
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
                GameWorld.self,
                from: JSONEncoder().encode(normalReturn.world)
            ),
            contacting: 12_300,
            at: 5
        )
        let restoredFrame = restored.update(at: 5.1, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.left])

        let earlyDown = GameSession(
            level: try contacting(18_441, at: player.position),
            presentationReadyTimestamp: 6
        )
        _ = earlyDown.update(at: 6.1, input: .zero)
        let earlyRepeat = try resumed(
            earlyDown.world,
            contacting: 12_300,
            at: 7
        )
        _ = earlyRepeat.update(at: 7.1, input: .zero)
        let earlyForward = try resumed(
            earlyRepeat.world,
            contacting: 12_301,
            at: 8
        )
        _ = earlyForward.update(at: 8.1, input: .zero)
        let sharedStartGoal = try resumed(
            earlyForward.world,
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

        let firstForward = GameSession(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = firstForward.update(at: 0.1, input: .zero)
        let down = try resumed(
            firstForward.world,
            contacting: 18_441,
            at: 1
        )
        _ = down.update(at: 1.1, input: .zero)
        let repeatForward = try resumed(
            down.world,
            contacting: 12_300,
            at: 2
        )
        _ = repeatForward.update(at: 2.1, input: .zero)
        let normalReturn = try resumed(
            repeatForward.world,
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
                GameWorld.self,
                from: JSONEncoder().encode(normalReturn.world)
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

        let earlyDown = GameSession(
            level: try contacting(18_441, at: player.position),
            presentationReadyTimestamp: 5
        )
        _ = earlyDown.update(at: 5.1, input: .zero)
        let earlyRepeat = try resumed(
            earlyDown.world,
            contacting: 12_300,
            at: 6
        )
        _ = earlyRepeat.update(at: 6.1, input: .zero)
        let sharedCallback = try resumed(
            earlyRepeat.world,
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

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.repeatForwardGoal = nil
        compatibleLesson.repeatReturnLeft = nil
        // Scripts 010-013 each require the previous script counter
        // (TrainingMission.cpp:1759, 1715, 1791, 1727), so a package
        // without Scripts 008 and 009 cannot carry them.
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
        XCTAssertNoThrow(
            try JSONDecoder().decode(
                Level.self,
                from: canonicalJSONData(compatibleLevel)
            ).validate()
        )
        var compatibleContinuationObject = try XCTUnwrap(
            testWorldObject(firstForward.world)
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
        let compatibleContinuation = try decodeTestWorld(compatibleContinuationObject)
        XCTAssertNoThrow(
            try GameSession(
                level: contacting(
                    12_301,
                    at: compatibleContinuation.playerPosition
                ),
                world: compatibleContinuation.rebased(onto: contacting(
                    12_301,
                    at: compatibleContinuation.playerPosition
                )),
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

        let earlyDown = GameSession(
            level: try contacting(18_441, at: player.position),
            presentationReadyTimestamp: 0
        )
        _ = earlyDown.update(at: 0.1, input: .zero)
        let earlyRepeat = try resumed(
            earlyDown.world,
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
                GameWorld.self,
                from: JSONEncoder().encode(earlyRepeat.world)
            ),
            contacting: 12_300,
            at: 2
        )
        let restoredFrame = restored.update(at: 2.1, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.forward])

        var unrelatedBitsObject = try XCTUnwrap(
            testWorldObject(earlyDown.world)
        )
        var unrelatedBitsOpening = try XCTUnwrap(
            unrelatedBitsObject["trainingOpeningState"] as? [String: Any]
        )
        unrelatedBitsOpening["forwardGoalWasReached"] = true
        unrelatedBitsOpening["returnGoalWasReached"] = true
        unrelatedBitsOpening["enabledControls"] = 36
        unrelatedBitsObject["trainingOpeningState"] = unrelatedBitsOpening
        let unrelatedBitsContinuation = try decodeTestWorld(unrelatedBitsObject)
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

        let forward = GameSession(
            level: try contacting(12_301, at: player.position),
            presentationReadyTimestamp: 3
        )
        _ = forward.update(at: 3.1, input: .zero)
        let right = try resumed(
            forward.world,
            contacting: 12_299,
            at: 4
        )
        _ = right.update(at: 4.1, input: .zero)
        let down = try resumed(
            right.world,
            contacting: 18_441,
            at: 5
        )
        _ = down.update(at: 5.1, input: .zero)
        let sharedCallback = try resumed(
            down.world,
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

        let compatibleBase = try contacting(0, at: player.position)
        var compatibleLesson = try XCTUnwrap(
            compatibleBase.trainingOpeningLesson
        )
        compatibleLesson.repeatForward = nil
        let compatibleLevel = replacing(
            compatibleBase,
            trainingOpeningLesson: compatibleLesson
        )
        let compatibleContinuation = GameSession(
            level: compatibleLevel,
            presentationReadyTimestamp: 8
        ).world
        XCTAssertNoThrow(
            try GameSession(
                level: compatibleLevel,
                world: (try JSONDecoder().decode(
                    GameWorld.self,
                    from: JSONEncoder().encode(compatibleContinuation)
                )).rebased(onto: compatibleLevel),
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
            _ continuation: GameWorld,
            contacting handle: UInt32,
            at timestamp: Double
        ) throws -> GameSession {
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
            return try GameSession(
                level: resumedLevel,
                world: continuation.rebased(onto: resumedLevel),
                resumedAtTimestamp: timestamp
            )
        }

        let early = GameSession(
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
            early.world,
            contacting: 12_301,
            at: 1
        )
        XCTAssertEqual(
            afterEarlyForward.update(at: 1.1, input: .zero)
                .enabledPlayerControls,
            [.reverse, .down]
        )
        let afterEarlyLeft = try resumed(
            afterEarlyForward.world,
            contacting: 12_300,
            at: 2
        )
        XCTAssertEqual(
            afterEarlyLeft.update(at: 2.1, input: .zero)
                .enabledPlayerControls,
            [.left, .down]
        )
        let afterEarlyRight = try resumed(
            afterEarlyLeft.world,
            contacting: 12_299,
            at: 3
        )
        XCTAssertEqual(
            afterEarlyRight.update(at: 3.1, input: .zero)
                .enabledPlayerControls,
            [.right, .down]
        )
        let afterEarlyUp = try resumed(
            afterEarlyRight.world,
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
                GameWorld.self,
                from: JSONEncoder().encode(afterEarlyUp.world)
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
        let earlyRight = GameSession(
            level: try level(contacting: 12_299),
            presentationReadyTimestamp: 6
        )
        XCTAssertEqual(
            earlyRight.update(at: 6.1, input: .zero)
                .enabledPlayerControls,
            [.forward, .right]
        )
        let earlyRightDown = try resumed(
            earlyRight.world,
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
                GameWorld.self,
                from: JSONEncoder().encode(earlyRightDown.world)
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
            earlyRightDown.world,
            contacting: 12_300,
            at: 8.2
        )
        XCTAssertEqual(
            earlyRightUpDown.update(at: 8.3, input: .zero)
                .enabledPlayerControls,
            [.forward, .up, .down]
        )
        let reverseUpDown = try resumed(
            earlyRightUpDown.world,
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
                GameWorld.self,
                from: JSONEncoder().encode(reverseUpDown.world)
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

        let reverse = GameSession(
            level: try level(contacting: 12_301),
            presentationReadyTimestamp: 9
        )
        XCTAssertEqual(
            reverse.update(at: 9.1, input: .zero)
                .enabledPlayerControls,
            [.reverse]
        )
        let reverseRight = try resumed(
            reverse.world,
            contacting: 12_299,
            at: 10
        )
        XCTAssertEqual(
            reverseRight.update(at: 10.1, input: .zero)
                .enabledPlayerControls,
            [.reverse, .right]
        )
        let reverseRightDown = try resumed(
            reverseRight.world,
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
                GameWorld.self,
                from: JSONEncoder().encode(reverseRightDown.world)
            ),
            contacting: 0,
            at: 12
        )
        XCTAssertEqual(
            restoredReverseRightDown.update(at: 12.1, input: .zero)
                .enabledPlayerControls,
            [.reverse, .right, .down]
        )

        let normal = GameSession(
            level: try level(contacting: 12_301),
            presentationReadyTimestamp: 20
        )
        _ = normal.update(at: 20.1, input: .zero)
        let normalLeft = try resumed(
            normal.world,
            contacting: 12_300,
            at: 21
        )
        _ = normalLeft.update(at: 21.1, input: .zero)
        let normalRight = try resumed(
            normalLeft.world,
            contacting: 12_299,
            at: 22
        )
        _ = normalRight.update(at: 22.1, input: .zero)
        let normalUp = try resumed(
            normalRight.world,
            contacting: 12_300,
            at: 23
        )
        XCTAssertEqual(
            normalUp.update(at: 23.1, input: .zero).enabledPlayerControls,
            [.up]
        )
        let normalDown = try resumed(
            normalUp.world,
            contacting: 18_441,
            at: 24
        )
        let normalDownFrame = normalDown.update(at: 24.1, input: .zero)
        XCTAssertEqual(normalDownFrame.enabledPlayerControls, [.down])
        XCTAssertEqual(
            normalDownFrame.trainingOpeningFeedback.map(\.voiceSourceName),
            ["", "", "return3.osf"]
        )
        let restored = try GameSession(
            level: try level(contacting: 18_441),
            world: (try JSONDecoder().decode(
                GameWorld.self,
                from: JSONEncoder().encode(normalDown.world)
            )).rebased(onto: try level(contacting: 18_441)),
            resumedAtTimestamp: 25
        )
        let restoredFrame = restored.update(at: 25.1, input: .zero)
        XCTAssertTrue(restoredFrame.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredFrame.enabledPlayerControls, [.down])

        let script006Level = try level(contacting: 0)
        var compatibleLesson = try XCTUnwrap(
            script006Level.trainingOpeningLesson
        )
        compatibleLesson.returnDown = nil
        let compatibleLevel = replacing(
            script006Level,
            trainingOpeningLesson: compatibleLesson
        )
        let oldContinuation = GameSession(
            level: compatibleLevel,
            presentationReadyTimestamp: 30
        ).world
        let restoredOld = try GameSession(
            level: script006Level,
            world: (try JSONDecoder().decode(
                GameWorld.self,
                from: JSONEncoder().encode(oldContinuation)
            )).rebased(onto: script006Level),
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
        let unconditionalSimulation = GameSession(
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
            unconditionalSimulation.world
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
            GameWorld.self,
            from: unconditionalContinuationData
        )
        let unconditionalStartLevel = try contacting(
            startGoalHandle,
            at: unconditionalContinuation.playerPosition
        )
        let restoredUnconditionalScript004 = try GameSession(
            level: unconditionalStartLevel,
            world: unconditionalContinuation.rebased(onto: unconditionalStartLevel),
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
            GameWorld.self,
            from: JSONEncoder().encode(
                restoredUnconditionalScript004.world
            )
        )
        let restoredEarlyUpSimulation = try GameSession(
            level: unconditionalStartLevel,
            world: earlyUpContinuation.rebased(onto: unconditionalStartLevel),
            resumedAtTimestamp: 2
        )
        let restoredEarlyUp = restoredEarlyUpSimulation.update(
            at: 2.1,
            input: .zero
        )
        XCTAssertTrue(restoredEarlyUp.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredEarlyUp.enabledPlayerControls, [.forward, .up])

        let earlyForwardStart = restoredEarlyUpSimulation.world
            .playerPosition
        let earlyForwardLevel = try contacting(
            goalHandle,
            at: .init(
                x: earlyForwardStart.x,
                y: earlyForwardStart.y,
                z: earlyForwardStart.z + 50
            )
        )
        let earlyForwardSimulation = try GameSession(
            level: earlyForwardLevel,
            world: restoredEarlyUpSimulation.world.rebased(onto: earlyForwardLevel),
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
            GameWorld.self,
            from: JSONEncoder().encode(
                earlyForwardSimulation.world
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
        let restoredAfterEarlyForward = try GameSession(
            level: earlyReturnLevel,
            world: earlyForwardContinuation.rebased(onto: earlyReturnLevel),
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
            GameWorld.self,
            from: JSONEncoder().encode(
                restoredAfterEarlyForward.world
            )
        )
        let restoredAfterEarlyReturn = try GameSession(
            level: earlyReturnLevel,
            world: earlyReturnContinuation.rebased(onto: earlyReturnLevel),
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
        let sharedCallbackSetup = GameSession(
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
        let sharedCallback = try GameSession(
            level: sharedCallbackLevel,
            world: sharedCallbackSetup.world.rebased(onto: sharedCallbackLevel),
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

        let timerOnly = GameSession(
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

        let simulation = GameSession(
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

        let continuationData = try JSONEncoder().encode(simulation.world)
        let continuation = try JSONDecoder().decode(
            GameWorld.self,
            from: continuationData
        )
        let restored = try GameSession(
            level: level,
            world: continuation.rebased(onto: level),
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
            restored.world
        )
        let returnedContinuation = try JSONDecoder().decode(
            GameWorld.self,
            from: returnedContinuationData
        )
        let restoredAfterReturn = try GameSession(
            level: try contacting(
                leftGoalHandle,
                at: returnedContinuation.playerPosition
            ),
            world: returnedContinuation.rebased(onto: try contacting(
                leftGoalHandle,
                at: returnedContinuation.playerPosition
            )),
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
            restoredAfterReturn.world
        )
        let script004Continuation = try JSONDecoder().decode(
            GameWorld.self,
            from: script004ContinuationData
        )
        var compatibleScript004Lesson = lesson
        compatibleScript004Lesson.returnUp = nil
        let compatibleScript004 = try GameSession(
            level: replacing(
                restoredAfterReturn.level,
                trainingOpeningLesson: compatibleScript004Lesson
            ),
            world: script004Continuation.rebased(onto: replacing(
                restoredAfterReturn.level,
                trainingOpeningLesson: compatibleScript004Lesson
            )),
            resumedAtTimestamp: 300
        ).update(at: 300.1, input: .zero)
        XCTAssertTrue(compatibleScript004.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(compatibleScript004.enabledPlayerControls, [.right])

        let restoredAfterScript004 = try GameSession(
            level: try contacting(
                startGoalHandle,
                at: script004Continuation.playerPosition
            ),
            world: script004Continuation.rebased(onto: try contacting(
                startGoalHandle,
                at: script004Continuation.playerPosition
            )),
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

        let script005Continuation = restoredAfterScript004.world
        let restoredAfterScript005 = try GameSession(
            level: restoredAfterScript004.level,
            world: script005Continuation.rebased(onto: restoredAfterScript004.level),
            resumedAtTimestamp: 400
        ).update(at: 400.1, input: .zero)
        XCTAssertTrue(
            restoredAfterScript005.trainingOpeningFeedback.isEmpty
        )
        XCTAssertEqual(restoredAfterScript005.enabledPlayerControls, [.up])

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
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        let simultaneous = simulation.update(
            at: 0.1,
            input: .init(forward: 1)
        )
        // Script 001 (TrainingMission.cpp:1633-1635) shows "Excellent",
        // streams return1.osf, then shows the reverse instruction as a
        // separate HUD message before the level timer's welcome feedback.
        XCTAssertEqual(
            simultaneous.trainingOpeningFeedback.map(\.voiceSourceName),
            ["return1.osf", "", "welcome.osf"]
        )
        XCTAssertEqual(
            simultaneous.trainingOpeningFeedback.map(\.hudMessages),
            [["Excellent"], ["Reverse"], ["Welcome", "Forward"]]
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

        let frame = GameSession(
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
