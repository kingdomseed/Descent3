import XCTest

final class WorldRenderingTests: XCTestCase {
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
            attemptSound: { presentationOrder.append("sound:\($0)") },
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
            attemptSound: {
                normalPresentationOrder.append("sound:\($0)")
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
            attemptSound: {
                sharedPresentationOrder.append("sound:\($0)")
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
            attemptSound: { presentationOrder.append("sound:\($0)") },
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
            attemptSound: { sharedOrder.append("sound:\($0)") },
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
            attemptSound: { presentationOrder.append("sound:\($0)") },
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

        var unconditionalLevel = level
        let unconditionalPlayer = try XCTUnwrap(
            unconditionalLevel.objects.first {
                $0.handle == 2_048
            }
        )
        let unconditionalPlayerRoomIndex = try XCTUnwrap(
            unconditionalLevel.rooms.firstIndex {
                $0.sourceIndex == 1
            }
        )
        unconditionalLevel.rooms[unconditionalPlayerRoomIndex] =
            makeSourceContainmentRoom(
                center: unconditionalPlayer.position,
                texture: unconditionalLevel.surfacePhysics[0].texture,
                sourceIndex: 1,
                halfExtent: 200
            )
        let unconditionalLeftGoalIndex = try XCTUnwrap(
            unconditionalLevel.objects.firstIndex {
                $0.handle == leftGoalHandle
            }
        )
        unconditionalLevel.objects[unconditionalLeftGoalIndex].location =
            unconditionalPlayer.location
        unconditionalLevel.objects[unconditionalLeftGoalIndex].position =
            unconditionalPlayer.position
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
        let restoredUnconditionalScript004 = try PlayerSimulation(
            level: unconditionalLevel,
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
        let restoredEarlyUp = try PlayerSimulation(
            level: unconditionalLevel,
            continuation: earlyUpContinuation,
            resumedAtTimestamp: 2
        ).update(at: 2.1, input: .zero)
        XCTAssertTrue(restoredEarlyUp.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(restoredEarlyUp.enabledPlayerControls, [.forward, .up])

        var earlyForwardGoalFrame: PlayerSimulationFrame?
        var earlyTimestamp = 1.1
        for _ in 0..<80 {
            earlyTimestamp += 0.1
            let frame = restoredUnconditionalScript004.update(
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
                restoredUnconditionalScript004.continuation
            )
        )
        let restoredAfterEarlyForward = try PlayerSimulation(
            level: unconditionalLevel,
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
            level: unconditionalLevel,
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
            [.init(
                hudMessages: [
                    "Excellent!",
                    "Now use the reverse Key to return to where you started!",
                ],
                voiceSourceName: "return1.osf",
                voicePrecedesHUDMessages: false
            )]
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
            level: level,
            continuation: returnedContinuation,
            resumedAtTimestamp: 200
        )
        let resumedAfterReturn = restoredAfterReturn.update(
            at: 200.1,
            input: .init(sideways: -1)
        )
        var leftGoalFrame = resumedAfterReturn.trainingOpeningFeedback
            .contains(where: {
                $0.voiceSourceName == "return2.osf"
            }) ? resumedAfterReturn : nil
        if leftGoalFrame == nil {
            for frameIndex in 2...80 {
                let frame = restoredAfterReturn.update(
                    at: 200 + Double(frameIndex) * 0.1,
                    input: .init(sideways: -1)
                )
                if frame.trainingOpeningFeedback.contains(where: {
                    $0.voiceSourceName == "return2.osf"
                }) {
                    leftGoalFrame = frame
                    break
                }
            }
        }
        let reachedLeftGoal = try XCTUnwrap(leftGoalFrame)
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
            attemptSound: { presentationOrder.append("sound:\($0)") },
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
            input: .init(sideways: -1)
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
                level,
                trainingOpeningLesson: compatibleScript004Lesson
            ),
            continuation: script004Continuation,
            resumedAtTimestamp: 300
        ).update(at: 300.1, input: .zero)
        XCTAssertTrue(compatibleScript004.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(compatibleScript004.enabledPlayerControls, [.right])

        let restoredAfterScript004 = try PlayerSimulation(
            level: level,
            continuation: script004Continuation,
            resumedAtTimestamp: 300
        )
        let resumedAfterScript004 = restoredAfterScript004.update(
            at: 300.1,
            input: .init(sideways: 1)
        )
        var script005Frame = resumedAfterScript004.trainingOpeningFeedback
            .contains(where: {
                $0.voiceSourceName == "up1.osf"
            }) ? resumedAfterScript004 : nil
        if script005Frame == nil {
            for frameIndex in 2...80 {
                let frame = restoredAfterScript004.update(
                    at: 300 + Double(frameIndex) * 0.1,
                    input: .init(sideways: 1)
                )
                if frame.trainingOpeningFeedback.contains(where: {
                    $0.voiceSourceName == "up1.osf"
                }) {
                    script005Frame = frame
                    break
                }
            }
        }
        let returnedFromLeft = try XCTUnwrap(script005Frame)
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
            input: .init(sideways: 1)
        )
        XCTAssertTrue(afterScript005.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(afterScript005.enabledPlayerControls, [.up])

        let script005Continuation = restoredAfterScript004.continuation
        let restoredAfterScript005 = try PlayerSimulation(
            level: level,
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
                    level,
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
                    level,
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

    func testTrainingGalleryTriggerClosesAnimatedBarrierOnceAndRestores() throws {
        let level = makeTrainingGalleryBarrierLevel()
        try level.validate()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var triggerFrame: PlayerSimulationFrame?
        for frameIndex in 1...20 {
            let frame = simulation.update(
                at: Double(frameIndex) * 0.1,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                triggerFrame = frame
                break
            }
        }

        let triggered = try XCTUnwrap(triggerFrame)
        XCTAssertEqual(
            triggered.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Excellent!",
                    "Your ship is equipped with a utility robot called a Guidebot.  Release him now with F4.",
                ],
                voiceSourceName: "guidebota.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        XCTAssertEqual(
            triggered.enabledPlayerControls,
            PlayerControlMask(rawValue: 0)
        )
        XCTAssertEqual(triggered.trainingGalleryMarkerLightDistance, 0)
        XCTAssertEqual(triggered.playerView.roomSourceIndex, 3)
        assertTrainingGalleryBarrier(level: simulation.level, rendersFaces: true)
        let playerStart = level.objects.first { $0.handle == 2_048 }!
        let blockedReturn = traceIndoorMovement(
            in: simulation.level,
            startRoom: triggered.playerView.roomSourceIndex,
            start: triggered.playerView.camera.position,
            end: playerStart.position,
            radius: triggered.playerView.collisionRadius
        )
        guard case .wallHit = blockedReturn.outcome else {
            return XCTFail("The closed force-field barrier must block the player")
        }

        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
        )
        let repeated = simulation.update(
            at: Double(triggered.gameTime) + 0.1,
            input: .init(forward: -1)
        )
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            repeated.enabledPlayerControls,
            PlayerControlMask(rawValue: 0)
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        assertTrainingGalleryBarrier(level: restored.level, rendersFaces: true)
        let afterRestore = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(afterRestore.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            afterRestore.enabledPlayerControls,
            PlayerControlMask(rawValue: 0)
        )
        XCTAssertEqual(afterRestore.trainingGalleryMarkerLightDistance, 0)
    }

    func testTrainingRobotDestructionAndGuidebotDeploymentContinueGalleryOnce() throws {
        let level = makeTrainingRobotGuidebotLevel()
        try level.validate()
        var relocatedRobotLevel = level
        let relocatedRobotIndex = try XCTUnwrap(
            relocatedRobotLevel.objects.firstIndex {
                $0.handle == 4_112
            }
        )
        relocatedRobotLevel.objects[relocatedRobotIndex].location = .room(1)
        XCTAssertThrowsError(try relocatedRobotLevel.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training robot Guidebot chain")
            )
        }
        let chain = try XCTUnwrap(level.trainingRobotGuidebotChain)
        let wrongRobotFlagsLevel = replacing(
            level,
            trainingRobotGuidebotChain: .init(
                destroyRobotObjectHandle: chain.destroyRobotObjectHandle,
                guidebotObjectHandle: chain.guidebotObjectHandle,
                destroyRobotRoomSourceIndex:
                    chain.destroyRobotRoomSourceIndex,
                destroyRobotFlags: 0,
                destructionDelay: chain.destructionDelay,
                destructionMessage: chain.destructionMessage,
                exitInstruction: chain.exitInstruction,
                destructionVoiceSourceName:
                    chain.destructionVoiceSourceName,
                deployedGuidebotObjectType:
                    chain.deployedGuidebotObjectType,
                deployedGuidebotMessage:
                    chain.deployedGuidebotMessage,
                deployedGuidebotVoiceSourceName:
                    chain.deployedGuidebotVoiceSourceName,
                combat: chain.combat,
                guidebot: chain.guidebot
            )
        )
        XCTAssertThrowsError(try wrongRobotFlagsLevel.validate()) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training robot Guidebot chain")
            )
        }
        XCTAssertEqual(
            trainingPlayerControlMask(
                galleryWasTriggered: true,
                controlsWereRestored: true,
                openingControls: [.reverse]
            ),
            .all
        )
        let guidebotSimulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var triggerFrame: PlayerSimulationFrame?
        var triggerTimestamp = 0.0
        for frameIndex in 1...20 {
            triggerTimestamp = Double(frameIndex) * 0.1
            let frame = guidebotSimulation.update(
                at: triggerTimestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                triggerFrame = frame
                break
            }
        }
        let triggered = try XCTUnwrap(triggerFrame)
        XCTAssertEqual(triggered.enabledPlayerControls.rawValue, 0)
        XCTAssertTrue(triggered.showsEnabledPlayerControls)

        let triggeredContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(guidebotSimulation.continuation)
        )
        var hostileContinuation = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(triggeredContinuation)
            ) as? [String: Any]
        )
        var hostileRobotState = try XCTUnwrap(
            hostileContinuation["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        hostileRobotState["controlsWereRestored"] = true
        hostileContinuation["trainingRobotGuidebotState"] =
            hostileRobotState
        let decodedHostile = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileContinuation)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: decodedHostile,
                resumedAtTimestamp: 100
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
        hostileRobotState["guidebotContinuationWasPresented"] = true
        hostileContinuation["trainingRobotGuidebotState"] =
            hostileRobotState
        let consumedGuidebot = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileContinuation)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: consumedGuidebot,
                resumedAtTimestamp: 200
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
        let deployed = guidebotSimulation.update(
            at: triggerTimestamp + 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertEqual(
            deployed.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
                ],
                voiceSourceName: "guidebotb.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        XCTAssertEqual(deployed.enabledPlayerControls, .all)
        XCTAssertTrue(deployed.showsEnabledPlayerControls)
        XCTAssertEqual(deployed.trainingGalleryMarkerLightDistance, 0)
        assertTrainingGalleryBarrier(
            level: guidebotSimulation.level,
            rendersFaces: true
        )
        let deployedContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(guidebotSimulation.continuation)
        )
        var deployedRestorationLevel = level
        let deployedRoomIndex = try XCTUnwrap(
            deployedRestorationLevel.rooms.firstIndex {
                $0.sourceIndex == deployed.playerView.roomSourceIndex
            }
        )
        deployedRestorationLevel.rooms[deployedRoomIndex] =
            addingSourceContainmentShell(
                to: deployedRestorationLevel.rooms[deployedRoomIndex],
                center: deployed.playerView.camera.position,
                texture: deployedRestorationLevel.surfacePhysics[0].texture,
                halfExtent: 500
            )
        XCTAssertNoThrow(
            try PlayerSimulation(
                level: deployedRestorationLevel,
                continuation: deployedContinuation,
                resumedAtTimestamp: 100
            )
        )
        let repeatedGuidebot = guidebotSimulation.update(
            at: triggerTimestamp + 0.2,
            input: .zero
        )
        XCTAssertTrue(repeatedGuidebot.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(repeatedGuidebot.enabledPlayerControls, .all)

        let destructionSimulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        for frameIndex in 1...20 {
            let frame = destructionSimulation.update(
                at: Double(frameIndex) * 0.1,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                break
            }
        }
        destructionSimulation.destroyTrainingRobot(handle: 4_112)
        XCTAssertFalse(destructionSimulation.level.objects.contains {
            $0.handle == 4_112
        })
        assertTrainingGalleryBarrier(
            level: destructionSimulation.level,
            rendersFaces: false
        )

        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(destructionSimulation.continuation)
        )
        var consumedDestructionObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(continuation)
            ) as? [String: Any]
        )
        var consumedDestructionState = try XCTUnwrap(
            consumedDestructionObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        consumedDestructionState.removeValue(
            forKey: "destructionTimerRemaining"
        )
        consumedDestructionState["destructionFeedbackWasPresented"] = true
        consumedDestructionState["enabledControlHUDIsVisible"] = false
        consumedDestructionObject["trainingRobotGuidebotState"] =
            consumedDestructionState
        let consumedDestruction = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: consumedDestructionObject
            )
        )
        let consumedDestructionSimulation = try PlayerSimulation(
            level: level,
            continuation: consumedDestruction,
            resumedAtTimestamp: 300
        )
        let afterDestructionReload = consumedDestructionSimulation.update(
            at: 300.1,
            input: .zero
        )
        XCTAssertTrue(afterDestructionReload.trainingOpeningFeedback.isEmpty)
        XCTAssertFalse(afterDestructionReload.showsEnabledPlayerControls)
        XCTAssertEqual(
            afterDestructionReload.trainingGalleryMarkerLightDistance,
            50
        )
        XCTAssertFalse(consumedDestructionSimulation.level.objects.contains {
            $0.handle == 4_112
        })
        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == 4_112
        })
        let restoredForwardControls = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 150
        )
        let restoredNeutralControls = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 150
        )
        let restoredForwardFrame = restoredForwardControls.update(
            at: 150.1,
            input: .init(forward: 1)
        )
        let restoredNeutralFrame = restoredNeutralControls.update(
            at: 150.1,
            input: .zero
        )
        XCTAssertNotEqual(
            restoredForwardFrame.velocity,
            restoredNeutralFrame.velocity
        )
        let destruction = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(destruction.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(destruction.enabledPlayerControls, .all)
        XCTAssertTrue(destruction.showsEnabledPlayerControls)
        XCTAssertEqual(destruction.trainingGalleryMarkerLightDistance, 50)
        var delayedFrame: PlayerSimulationFrame?
        for frameIndex in 2...21 {
            let frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: .zero
            )
            if !frame.trainingOpeningFeedback.isEmpty {
                delayedFrame = frame
                break
            }
        }
        let delayed = try XCTUnwrap(delayedFrame)
        XCTAssertEqual(
            delayed.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Excellent!",
                    "Now go through the open doorway, and into the next room.",
                ],
                voiceSourceName: "proceed5.osf",
                voicePrecedesHUDMessages: false
            )]
        )
        XCTAssertFalse(delayed.showsEnabledPlayerControls)
        let afterRestore = restored.update(
            at: Double(delayed.gameTime) + 100,
            input: .zero
        )
        XCTAssertTrue(afterRestore.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(afterRestore.enabledPlayerControls, .all)
        XCTAssertFalse(afterRestore.showsEnabledPlayerControls)
        XCTAssertEqual(afterRestore.trainingGalleryMarkerLightDistance, 50)
        assertTrainingGalleryBarrier(
            level: consumedDestructionSimulation.level,
            rendersFaces: false
        )
    }

    func testTrainingGuidebotDeploymentReachesScript060InSameUpdate() throws {
        let simulation = PlayerSimulation(
            level: makeTrainingRobotGuidebotLevel(),
            presentationReadyTimestamp: 0
        )
        var timestamp = 0.0
        for frameIndex in 1...20 {
            timestamp = Double(frameIndex) * 0.1
            let frame = simulation.update(
                at: timestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                break
            }
        }

        let deployed = simulation.update(
            at: timestamp + 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )

        XCTAssertEqual(
            deployed.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
                ],
                voiceSourceName: "guidebotb.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        XCTAssertEqual(deployed.enabledPlayerControls, .all)
    }

    func testCameraMonitorPickupUseAndTimedViewContinueOnceAcrossReload() throws {
        let level = makeTrainingCameraMonitorLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingCameraMonitorChain)
        let securityCamera = try XCTUnwrap(level.objects.first {
            $0.handle == chain.securityCameraObjectHandle
        })
        let securityCameraRoom = try XCTUnwrap({
            if case let .room(room) = securityCamera.location { return room }
            return nil
        }())
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        let pickup = simulation.update(
            at: 0.1,
            input: .init(usesInventory: true)
        )
        XCTAssertEqual(
            pickup.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Excellent.  You now have the Camera Monitor.  Press the Use Inventory key to activate it!",
                ],
                voiceSourceName: "guidebotc.osf",
                voicePrecedesHUDMessages: true,
                soundSourceName: "PupC.wav"
            )]
        )
        XCTAssertNil(pickup.trainingCameraMonitor)
        XCTAssertFalse(
            simulation.level.objectPresentations.contains {
                $0.objectHandle == chain.pickupObjectHandle
                    && $0.isVisible
            }
        )
        XCTAssertTrue(
            simulation.level.objects.contains {
                $0.handle == chain.pickupObjectHandle
            }
        )

        let heldContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: heldContinuation,
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(
            restored.level.objectPresentations.contains {
                $0.objectHandle == chain.pickupObjectHandle
                    && $0.isVisible
            }
        )

        let used = restored.update(
            at: 100.1,
            input: .init(usesInventory: true)
        )
        XCTAssertEqual(
            used.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Now recall the Guidebot by pressing F4 and selecting \"Return to Ship\".  Move to the next area when he returns.",
                ],
                voiceSourceName: "guidebotd.osf",
                voicePrecedesHUDMessages: true
            )]
        )
        let popup = try XCTUnwrap(used.trainingCameraMonitor)
        XCTAssertEqual(popup.remainingDuration, 10, accuracy: 0.000_1)
        XCTAssertEqual(popup.roomSourceIndex, securityCameraRoom)
        XCTAssertEqual(
            popup.camera.position,
            securityCamera.position
        )
        XCTAssertEqual(
            popup.camera.target,
            .init(
                x: securityCamera.position.x
                    - securityCamera.orientation.forward.x,
                y: securityCamera.position.y
                    - securityCamera.orientation.forward.y,
                z: securityCamera.position.z
                    - securityCamera.orientation.forward.z
            )
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.pickupObjectHandle
        })

        let usedContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(restored.continuation)
        )
        let resumedPopup = try PlayerSimulation(
            level: level,
            continuation: usedContinuation,
            resumedAtTimestamp: 200
        )
        let afterReload = resumedPopup.update(at: 200.1, input: .zero)
        XCTAssertTrue(afterReload.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            try XCTUnwrap(afterReload.trainingCameraMonitor)
                .remainingDuration,
            9.9,
            accuracy: 0.000_1
        )

        var lastFrame = afterReload
        for frameIndex in 2...99 {
            lastFrame = resumedPopup.update(
                at: 200 + Double(frameIndex) * 0.1,
                input: .zero
            )
        }
        XCTAssertNotNil(lastFrame.trainingCameraMonitor)
        _ = resumedPopup.update(at: 210, input: .zero)
        let closed = resumedPopup.update(at: 210.1, input: .zero)
        XCTAssertNil(closed.trainingCameraMonitor)
        XCTAssertTrue(closed.trainingOpeningFeedback.isEmpty)
        XCTAssertTrue(
            resumedPopup.update(at: 212.2, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )
    }

    func testGuidebotReturnCollisionRunsScript058OnceAcrossReload() throws {
        let level = makeTrainingCameraMonitorLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingCameraMonitorChain)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = simulation.update(at: 0.2, input: .init(usesInventory: true))
        let requested = simulation.update(
            at: 0.3,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertEqual(requested.trainingOpeningFeedback, [
            .init(
                hudMessages: ["GB: Returning to ship."],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: "GBotAcceptOrder.wav"
            ),
        ])
        var completed: PlayerSimulationFrame?
        for frameIndex in 4...100 {
            let frame = simulation.update(
                at: Double(frameIndex) * 0.1,
                input: .zero
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                completed = frame
                break
            }
        }
        let script058 = try XCTUnwrap(completed)
        XCTAssertEqual(script058.trainingOpeningFeedback, [
            .init(
                hudMessages: ["GB: Entering ship!"],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true
            ),
            .init(
                hudMessages: ["Excellent!"],
                voiceSourceName: "proceed6.osf",
                voicePrecedesHUDMessages: true
            ),
        ])
        XCTAssertNil(script058.trainingGuidebot)
        XCTAssertEqual(
            script058.trainingGuidebotReturnMarkerLightDistance,
            50
        )
        assertTrainingGuidebotReturnBarrier(
            level: simulation.level,
            rendersFaces: false
        )
        XCTAssertFalse(simulation.level.objectPresentations.contains {
            $0.objectHandle
                == level.trainingRobotGuidebotChain?.guidebotObjectHandle
                && $0.isVisible
        })
        let postReturnF4 = simulation.update(
            at: Double(script058.gameTime) + 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertNil(postReturnF4.trainingGuidebot)
        XCTAssertTrue(postReturnF4.trainingOpeningFeedback.isEmpty)

        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        let afterReload = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(afterReload.trainingOpeningFeedback.isEmpty)
        XCTAssertNil(afterReload.trainingGuidebot)
        XCTAssertEqual(
            afterReload.trainingGuidebotReturnMarkerLightDistance,
            chain.returnToShip?.openMarkerLightDistance
        )
        assertTrainingGuidebotReturnBarrier(
            level: restored.level,
            rendersFaces: false
        )
    }

    func testKillbotEntryClosesPortalRoom5AndRunsTimedInstructionAcrossReload()
        throws
    {
        let level = makeTrainingKillbotEntryLevel()
        try level.validate()
        let initialSimulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var initialContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(initialSimulation.continuation)
            ) as? [String: Any]
        )
        var initialGalleryState = try XCTUnwrap(
            initialContinuationObject["trainingGalleryBarrierState"]
                as? [String: Any]
        )
        initialGalleryState["wasTriggered"] = true
        initialGalleryState["markerLightDistance"] = 0
        initialContinuationObject["trainingGalleryBarrierState"] =
            initialGalleryState
        let gallerySimulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: initialContinuationObject
                )
            ),
            resumedAtTimestamp: 0
        )
        gallerySimulation.destroyTrainingRobot(handle: 4_112)
        var destroyedContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(gallerySimulation.continuation)
            ) as? [String: Any]
        )
        var destroyedRobotState = try XCTUnwrap(
            destroyedContinuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        destroyedRobotState.removeValue(
            forKey: "destructionTimerRemaining"
        )
        destroyedRobotState["destructionFeedbackWasPresented"] = true
        destroyedRobotState["enabledControlHUDIsVisible"] = false
        destroyedContinuationObject["trainingRobotGuidebotState"] =
            destroyedRobotState
        let simulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: destroyedContinuationObject
                )
            ),
            resumedAtTimestamp: 0
        )
        var timestamp = 0.1
        _ = simulation.update(
            at: timestamp,
            input: .init(deploysTrainingGuidebot: true)
        )
        timestamp += 0.1
        _ = simulation.update(
            at: timestamp,
            input: .init(usesInventory: true)
        )
        timestamp += 0.1
        _ = simulation.update(
            at: timestamp,
            input: .init(deploysTrainingGuidebot: true)
        )
        var script058: PlayerSimulationFrame?
        for _ in 1...100 {
            timestamp += 0.1
            let frame = simulation.update(
                at: timestamp,
                input: .zero
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                script058 = frame
                break
            }
        }
        let returned = try XCTUnwrap(script058)
        timestamp = Double(returned.gameTime) + 0.1
        XCTAssertTrue(
            simulation.update(at: timestamp, input: .zero)
                .trainingOpeningFeedback.isEmpty
        )
        var entered: PlayerSimulationFrame?
        for frameIndex in 1...40 {
            timestamp += 0.1
            let frame = simulation.update(
                at: timestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "intro6.osf"
            }) {
                XCTAssertEqual(frameIndex, 1)
                entered = frame
                break
            }
        }
        let entry = try XCTUnwrap(entered)
        XCTAssertEqual(entry.trainingOpeningFeedback.last, .init(
            hudMessages: [
                "Now you are on your own in this room. There are 4 robots and 2 powerups. Get the powerups and kill the robots.",
            ],
            voiceSourceName: "intro6.osf",
            voicePrecedesHUDMessages: false
        ))
        XCTAssertEqual(
            entry.trainingGuidebotReturnMarkerLightDistance,
            0
        )
        assertTrainingGuidebotReturnBarrier(
            level: simulation.level,
            rendersFaces: true
        )

        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: continuationData
            ) as? [String: Any]
        )
        XCTAssertEqual(
            containingIndoorRoomSourceIndex(
                in: simulation.level,
                position: entry.playerView.camera.position,
                candidates: [entry.playerView.roomSourceIndex]
            ),
            entry.playerView.roomSourceIndex
        )
        let galleryState = try XCTUnwrap(
            continuationObject["trainingGalleryBarrierState"]
                as? [String: Any]
        )
        XCTAssertEqual(galleryState["wasTriggered"] as? Bool, true)
        XCTAssertEqual(galleryState["markerLightDistance"] as? Double, 50)
        let robotState = try XCTUnwrap(
            continuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(robotState["robotWasDestroyed"] as? Bool, true)
        XCTAssertEqual(robotState["guidebotEnteredShip"] as? Bool, true)
        let cameraState = try XCTUnwrap(
            continuationObject["trainingCameraMonitorState"]
                as? [String: Any]
        )
        XCTAssertEqual(cameraState["script058WasPresented"] as? Bool, true)
        XCTAssertEqual(
            cameraState["returnMarkerLightDistance"] as? Double,
            50
        )
        let killbotEntryState = try XCTUnwrap(
            continuationObject["trainingKillbotEntryState"]
                as? [String: Any]
        )
        XCTAssertEqual(
            try XCTUnwrap(
                killbotEntryState["followupTimerRemaining"] as? Double
            ),
            13,
            accuracy: 0.000_001
        )
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: continuationData
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        assertTrainingGuidebotReturnBarrier(
            level: restored.level,
            rendersFaces: true
        )

        for frameIndex in 1...129 {
            let frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: .zero
            )
            XCTAssertFalse(
                frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebotf.osf"
                })
            )
        }
        let followupTimestamp = 113.0
        let timer14 = restored.update(
            at: followupTimestamp,
            input: .zero
        )
        XCTAssertEqual(timer14.trainingOpeningFeedback.last, .init(
            hudMessages: [
                "Some parts of this area are very dark.  Turn on your headlight or fire flares to see.  Use your guidebot if you need help finding a robot or powerup.",
            ],
            voiceSourceName: "guidebotf.osf",
            voicePrecedesHUDMessages: true
        ))
        XCTAssertTrue(
            restored.update(
                at: followupTimestamp + 0.1,
                input: .zero
            ).trainingOpeningFeedback.allSatisfy {
                $0.voiceSourceName != "guidebotf.osf"
            }
        )
    }

    func testRASBot1DeathUsesPrimaryLaserOnceAndSurvivesReload() throws {
        let level = makeTrainingRASBot1DeathLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingRASBot1DeathChain)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        var timestamp = 0.0
        for _ in 1...3 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )

        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let deathState = try XCTUnwrap(
            continuationObject["trainingRASBot1DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)
        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedContinuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        let repeatedDeathState = try XCTUnwrap(
            repeatedContinuationObject["trainingRASBot1DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(
            repeatedDeathState["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        _ = restored.update(
            at: 100.25,
            input: .init(firesPrimaryWeapon: true)
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
    }

    func testRASBot2DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        let level = makeTrainingRASBot2DeathLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingRASBot2DeathChain)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == 2_074
        })
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let deathState = try XCTUnwrap(
            continuationObject["trainingRASBot2DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            (repeatedObject["trainingRASBot2DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 2_074
        })
    }

    func testRASBot3DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingRASBot3DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(42)
        let chain = try XCTUnwrap(level.trainingRASBot3DeathChain)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == 2_074
        })
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == 2_075
        })
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let deathState = try XCTUnwrap(
            continuationObject["trainingRASBot3DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)
        var hostileObject = continuationObject
        var hostileDeathState = deathState
        hostileDeathState["shields"] = 55
        hostileObject["trainingRASBot3DeathState"] = hostileDeathState
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

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            (repeatedObject["trainingRASBot3DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 2_074
        })
        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 2_075
        })
    }

    func testRASBot4DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingRASBot4DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(0)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_077 }
        )
        level.objects[fartherTargetIndex].location = .room(0)
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingRASBot4DeathChain)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == 2_074
        })
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == 2_075
        })
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == 2_077
        })
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let deathState = try XCTUnwrap(
            continuationObject["trainingRASBot4DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)
        var hostileObject = continuationObject
        var hostileDeathState = deathState
        hostileDeathState["shields"] = 55
        hostileObject["trainingRASBot4DeathState"] = hostileDeathState
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

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            (repeatedObject["trainingRASBot4DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 2_074
        })
        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 2_075
        })
        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 2_077
        })
    }

    func testLastBot1DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingLastBot1DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(14)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_078 }
        )
        level.objects[fartherTargetIndex].location = .room(14)
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingLastBot1DeathChain)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == 2_078
        })
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let deathState = try XCTUnwrap(
            continuationObject["trainingLastBot1DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)
        var hostileObject = continuationObject
        var hostileDeathState = deathState
        hostileDeathState["shields"] = 55
        hostileObject["trainingLastBot1DeathState"] = hostileDeathState
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

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            (repeatedObject["trainingLastBot1DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 2_078
        })

        var priorSchemaObject = continuationObject
        priorSchemaObject.removeValue(
            forKey: "trainingLastBot1DeathState"
        )
        let priorSchemaContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: priorSchemaObject)
        )
        let priorSchemaRestored = try PlayerSimulation(
            level: level,
            continuation: priorSchemaContinuation,
            resumedAtTimestamp: 200
        )
        XCTAssertTrue(priorSchemaRestored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
    }

    func testLastBot1ContinuationRejectsCompatibleLevelWithoutChain()
        throws
    {
        let level = makeTrainingLastBot1DeathLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        let handle = try XCTUnwrap(
            level.trainingLastBot1DeathChain?.robotObjectHandle
        )
        simulation.destroyTrainingLastBot1(handle: handle)

        var priorLevelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(level)
            ) as? [String: Any]
        )
        priorLevelObject.removeValue(
            forKey: "trainingLastBot1DeathChain"
        )
        let priorLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: priorLevelObject
            )
        )
        try priorLevel.validate()

        XCTAssertThrowsError(
            try PlayerSimulation(
                level: priorLevel,
                continuation: simulation.continuation,
                resumedAtTimestamp: 100
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    func testLastBot2DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingLastBot2DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(46)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 4_127 }
        )
        level.objects[fartherTargetIndex].location = .room(46)
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingLastBot2DeathChain)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == 4_127
        })
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let deathState = try XCTUnwrap(
            continuationObject["trainingLastBot2DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        var hostileObject = continuationObject
        var hostileDeathState = deathState
        hostileDeathState["shields"] = 55
        hostileObject["trainingLastBot2DeathState"] = hostileDeathState
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

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            (repeatedObject["trainingLastBot2DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 4_127
        })

        var priorSchemaObject = continuationObject
        priorSchemaObject.removeValue(
            forKey: "trainingLastBot2DeathState"
        )
        let priorSchemaContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: priorSchemaObject)
        )
        let priorSchemaRestored = try PlayerSimulation(
            level: level,
            continuation: priorSchemaContinuation,
            resumedAtTimestamp: 200
        )
        XCTAssertTrue(priorSchemaRestored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
    }

    func testLastBot3DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingLastBot3DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(47)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_080 }
        )
        level.objects[fartherTargetIndex].location = .room(47)
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingLastBot3DeathChain)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == 2_080
        })
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let deathState = try XCTUnwrap(
            continuationObject["trainingLastBot3DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        var hostileObject = continuationObject
        var hostileDeathState = deathState
        hostileDeathState["shields"] = 55
        hostileObject["trainingLastBot3DeathState"] = hostileDeathState
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

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            (repeatedObject["trainingLastBot3DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 2_080
        })

        var priorSchemaObject = continuationObject
        priorSchemaObject.removeValue(
            forKey: "trainingLastBot3DeathState"
        )
        let priorSchemaContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: priorSchemaObject)
        )
        let priorSchemaRestored = try PlayerSimulation(
            level: level,
            continuation: priorSchemaContinuation,
            resumedAtTimestamp: 200
        )
        XCTAssertTrue(priorSchemaRestored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
    }

    func testLastBot4DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingLastBot4DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(47)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_081 }
        )
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingLastBot4DeathChain)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == 2_081
        })
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let deathState = try XCTUnwrap(
            continuationObject["trainingLastBot4DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        var hostileObject = continuationObject
        var hostileDeathState = deathState
        hostileDeathState["shields"] = 55
        hostileObject["trainingLastBot4DeathState"] = hostileDeathState
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

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            (repeatedObject["trainingLastBot4DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 2_081
        })

        var priorSchemaObject = continuationObject
        priorSchemaObject.removeValue(
            forKey: "trainingLastBot4DeathState"
        )
        let priorSchemaContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: priorSchemaObject)
        )
        let priorSchemaRestored = try PlayerSimulation(
            level: level,
            continuation: priorSchemaContinuation,
            resumedAtTimestamp: 200
        )
        XCTAssertTrue(priorSchemaRestored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
    }

    func testLastBot5DeathUsesNearestPrimaryLaserOnceAndSurvivesReload()
        throws
    {
        var level = makeTrainingLastBot5DeathLevel()
        try level.validate()
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(48)
        let fartherTargetIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_082 }
        )
        level.objects[fartherTargetIndex].location = .room(48)
        let playerPosition = level.objects[playerIndex].position
        let playerForward = level.objects[playerIndex].orientation.forward
        level.objects[fartherTargetIndex].position = .init(
            x: playerPosition.x + playerForward.x * 40,
            y: playerPosition.y + playerForward.y * 40,
            z: playerPosition.z + playerForward.z * 40
        )
        let chain = try XCTUnwrap(level.trainingLastBot5DeathChain)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.0
        for _ in 1...4 {
            timestamp += 0.25
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: true)
            )
        }

        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(simulation.level.objects.contains {
            $0.handle == 2_082
        })
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let deathState = try XCTUnwrap(
            continuationObject["trainingLastBot5DeathState"]
                as? [String: Any]
        )
        XCTAssertEqual(deathState["wasDestroyed"] as? Bool, true)

        var hostileObject = continuationObject
        var hostileDeathState = deathState
        hostileDeathState["shields"] = 55
        hostileObject["trainingLastBot5DeathState"] = hostileDeathState
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

        timestamp += 0.25
        _ = simulation.update(
            at: timestamp,
            input: .init(firesPrimaryWeapon: true)
        )
        let repeatedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        XCTAssertEqual(
            (repeatedObject["trainingLastBot5DeathState"]
                as? [String: Any])?["shields"] as? Double,
            deathState["shields"] as? Double
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(restored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 2_082
        })

        var priorSchemaObject = continuationObject
        priorSchemaObject.removeValue(
            forKey: "trainingLastBot5DeathState"
        )
        let priorSchemaContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: priorSchemaObject)
        )
        let priorSchemaRestored = try PlayerSimulation(
            level: level,
            continuation: priorSchemaContinuation,
            resumedAtTimestamp: 200
        )
        XCTAssertTrue(priorSchemaRestored.level.objects.contains {
            $0.handle == chain.robotObjectHandle
        })
    }

    func testScripts035And056OpenPortalRoomSevenThenPresentOnceAfterTimer()
        throws
    {
        let level = makeTrainingFinalBotsCompletionLevel()
        try level.validate()
        let chain = try XCTUnwrap(
            level.trainingFinalBotsCompletionChain
        )
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        simulation.destroyTrainingLastBot1(handle: 4_127)
        simulation.destroyTrainingLastBot2(handle: 2_080)
        simulation.destroyTrainingLastBot3(handle: 2_081)
        simulation.destroyTrainingLastBot4(handle: 2_082)
        simulation.destroyTrainingLastBot5(handle: 2_083)
        var frame = simulation.update(at: 0.1, input: .zero)

        func assertBarrierIsOpen(in level: Level) throws {
            let barrier = try XCTUnwrap(level.rooms.first {
                $0.sourceIndex == chain.barrierRoomSourceIndex
            })
            for portalIndex in chain.orderedPortalIndices {
                let portal = barrier.portals[portalIndex]
                XCTAssertEqual(portal.flags & 1, 0)
                let connected = try XCTUnwrap(level.rooms.first {
                    $0.sourceIndex == portal.connectedRoom
                })
                XCTAssertEqual(
                    connected.portals[portal.connectedPortal].flags & 1,
                    0
                )
            }
        }

        try assertBarrierIsOpen(in: simulation.level)
        XCTAssertEqual(
            frame.trainingFinalBotsMarkerLightDistance,
            50
        )
        XCTAssertFalse(frame.trainingOpeningFeedback.contains {
            $0.voiceSourceName == chain.completionVoiceSourceName
        })
        let pendingData = try JSONEncoder().encode(
            simulation.continuation
        )
        let pendingObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: pendingData)
                as? [String: Any]
        )
        XCTAssertEqual(pendingObject["schemaVersion"] as? Int, 7)
        let pendingState = try XCTUnwrap(
            pendingObject["trainingFinalBotsCompletionState"]
                as? [String: Any]
        )
        XCTAssertEqual(pendingState["wasTriggered"] as? Bool, true)
        XCTAssertEqual(
            try XCTUnwrap(pendingState["timerRemaining"] as? Double),
            2,
            accuracy: 0.000_1
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: pendingData
            ),
            resumedAtTimestamp: 100
        )
        try assertBarrierIsOpen(in: restored.level)
        for frameIndex in 1...20 {
            frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: .zero
            )
        }
        XCTAssertEqual(
            frame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [chain.completionMessage],
                    voiceSourceName: chain.completionVoiceSourceName,
                    voicePrecedesHUDMessages: false
                )
            ]
        )
        XCTAssertTrue(
            restored.update(
                at: 102.1,
                input: .zero
            ).trainingOpeningFeedback.isEmpty
        )

        let completed = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(restored.continuation)
            ),
            resumedAtTimestamp: 200
        )
        try assertBarrierIsOpen(in: completed.level)
        XCTAssertTrue(
            completed.update(
                at: 200.1,
                input: .zero
            ).trainingOpeningFeedback.isEmpty
        )

        var hostileObject = pendingObject
        var hostileState = pendingState
        hostileState["markerLightDistance"] = 0
        hostileObject["trainingFinalBotsCompletionState"] =
            hostileState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: hostileObject
                    )
                ),
                resumedAtTimestamp: 300
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    @MainActor
    func testScript057FinalGoalEndsTrainingInSourceOrderAndSurvivesReload()
        throws
    {
        let level = makeTrainingFinalGoalLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingFinalGoalChain)
        let goal = try XCTUnwrap(level.objects.first {
            $0.handle == chain.goalObjectHandle
        })
        let initial = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        initial.destroyTrainingRobot(handle: 4_112)
        initial.destroyTrainingRASBot1(handle: 2_074)
        initial.destroyTrainingRASBot2(handle: 2_075)
        initial.destroyTrainingRASBot3(handle: 2_077)
        initial.destroyTrainingRASBot4(handle: 2_078)
        initial.destroyTrainingLastBot1(handle: 4_127)
        initial.destroyTrainingLastBot2(handle: 2_080)
        initial.destroyTrainingLastBot3(handle: 2_081)
        initial.destroyTrainingLastBot4(handle: 2_082)
        initial.destroyTrainingLastBot5(handle: 2_083)
        _ = initial.update(at: 0.1, input: .zero)
        var ready = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(initial.continuation)
            ) as? [String: Any]
        )
        ready["playerLocation"] = [
            "room": ["_0": chain.goalRoomSourceIndex]
        ]
        ready["playerPosition"] = [
            "x": goal.position.x,
            "y": goal.position.y,
            "z": goal.position.z,
        ]
        let simulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: ready)
            ),
            resumedAtTimestamp: 0
        )

        let frame = simulation.update(at: 0.2, input: .zero)

        let finalGoal = try XCTUnwrap(frame.trainingFinalGoal)
        XCTAssertEqual(finalGoal.endLevelState, .succeeded)
        XCTAssertEqual(finalGoal.scriptActionCounter, 1)
        XCTAssertTrue(finalGoal.controlsAreSuspended)
        XCTAssertEqual(
            finalGoal.postLevelResult,
            .init(
                title: "Mission Successful",
                levelName: "Training Mission",
                difficulty: .rookie,
                score: 2_000,
                elapsedTime: 0.1,
                enemyKills: 10,
                shields: 100,
                energy: 100,
                deaths: 0,
                restores: 0,
                objectives: []
            )
        )
        XCTAssertEqual(frame.enabledPlayerControls, [])
        XCTAssertFalse(frame.showsEnabledPlayerControls)
        XCTAssertEqual(
            finalGoal.presentation,
            .init(
                title: "Mission Successful",
                levelName: "Training Mission",
                difficulty: .rookie,
                showsHUD: false,
                playsGameplayAudio: false,
                showsCockpit: false,
                showsHeadlightIndicator: false
            )
        )
        XCTAssertEqual(
            RevivalGameplayView.trainingEndLevelText(
                finalGoal.presentation
            ),
            "Mission Successful\nTraining Mission\nDifficulty: Rookie"
        )
        XCTAssertEqual(
            RevivalGameplayView.trainingPostLevelResultText(
                finalGoal.postLevelResult
            ),
            """
            Mission Successful
            Training Mission
            Difficulty: Rookie
            Score: 2000
            Time: 0:00
            Enemies Killed: 10
            Shields: 100
            Energy: 100
            Deaths: 0
            Restores: 0
            """
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                keyCode: 36,
                resultIsPresented: true,
                presentationElapsedTime: 2
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                keyCode: 36,
                resultIsPresented: true,
                presentationElapsedTime: 1.999
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                keyCode: 36,
                resultIsPresented: false,
                presentationElapsedTime: 2
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                keyCode: 49,
                resultIsPresented: true,
                presentationElapsedTime: 2
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                keyCode: 53,
                resultIsPresented: true,
                presentationElapsedTime: 2
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 1.999,
                queuedKey: false,
                mouseButtonIsPressed: true,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 2,
                queuedKey: true,
                mouseButtonIsPressed: false,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 2,
                queuedKey: false,
                mouseButtonIsPressed: true,
                controllerButtonIsPressed: false
            )
        )
        XCTAssertTrue(
            RevivalGameplayView.requestsTrainingResultAcknowledgement(
                resultIsPresented: true,
                presentationElapsedTime: 2,
                queuedKey: false,
                mouseButtonIsPressed: false,
                controllerButtonIsPressed: true
            )
        )
        XCTAssertEqual(
            simulation.trainingSessionOutcome,
            .awaitingResultAcknowledgement
        )
        XCTAssertEqual(
            simulation.acknowledgeTrainingResult(),
            .completed
        )
        XCTAssertEqual(simulation.trainingSessionOutcome, .completed)
        XCTAssertEqual(
            simulation.acknowledgeTrainingResult(),
            .completed
        )

        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let finalGoalState = try XCTUnwrap(
            continuationObject["trainingFinalGoalState"]
                as? [String: Any]
        )
        XCTAssertEqual(
            finalGoalState["endLevelWasRequested"] as? Bool,
            true
        )
        XCTAssertEqual(
            finalGoalState["scriptActionCounter"] as? Int,
            1
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        let restoredFrame = restored.update(at: 100.1, input: .zero)
        XCTAssertEqual(
            restoredFrame.trainingFinalGoal?.endLevelState,
            .succeeded
        )
        XCTAssertEqual(
            restoredFrame.trainingFinalGoal?.scriptActionCounter,
            1
        )

        var hostile = continuationObject
        var hostileFinalGoalState = finalGoalState
        hostileFinalGoalState["scriptActionCounter"] = 2
        hostile["trainingFinalGoalState"] = hostileFinalGoalState
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: hostile
                    )
                ),
                resumedAtTimestamp: 200
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    @MainActor
    func testCompletedTrainingSessionOffersOneDirectRestartAction() throws {
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var restartRequests = 0
        view.trainingRestartRequested = {
            restartRequests += 1
        }

        view.presentTrainingContentReadyState(
            completedLevelName: "Training Mission"
        )

        let contentReadyLabel = try XCTUnwrap(
            view.subviews.compactMap { $0 as? NSTextField }.first {
                $0.stringValue.hasPrefix("Training Mission completed.")
            }
        )
        let restartButton = try XCTUnwrap(
            view.subviews.compactMap { $0 as? NSButton }.first {
                $0.title == "Play Training Again"
            }
        )
        XCTAssertFalse(restartButton.isHidden)
        XCTAssertTrue(restartButton.isEnabled)
        XCTAssertEqual(
            contentReadyLabel.stringValue,
            """
            Training Mission completed.

            Play Training Again, open canonical content, or quit.
            """
        )
        view.requestTrainingRestart()
        XCTAssertEqual(restartRequests, 1)

        view.setTrainingRestartAvailable(false)
        XCTAssertFalse(restartButton.isEnabled)
        view.requestTrainingRestart()
        XCTAssertEqual(restartRequests, 1)

        view.setTrainingRestartAvailable(true)
        XCTAssertTrue(restartButton.isEnabled)
        view.requestTrainingRestart()
        XCTAssertEqual(restartRequests, 2)

        view.prepareForTrainingSession()
        XCTAssertTrue(restartButton.isHidden)
        XCTAssertFalse(restartButton.isEnabled)
    }

    func testPilotProfilesRequireConfirmedSelectionAndSurviveReload() throws {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-pilot-lifecycle-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let library = PilotProfileLibrary(rootURL: rootURL)

        XCTAssertTrue(try library.load().profiles.isEmpty)

        let createdAlice = try library.createProfile(named: "Alice")
        let alice = try XCTUnwrap(createdAlice.profiles.first)
        XCTAssertEqual(alice.name, "Alice")
        XCTAssertNil(createdAlice.defaultProfileID)

        let createdBob = try library.createProfile(named: "Bob")
        let bob = try XCTUnwrap(
            createdBob.profiles.first { $0.name == "Bob" }
        )
        XCTAssertNil(createdBob.defaultProfileID)

        let confirmedBob = try library.confirmProfile(bob.id)
        XCTAssertEqual(confirmedBob.defaultProfileID, bob.id)
        XCTAssertEqual(try library.load().defaultProfileID, bob.id)

        _ = alice.id
        XCTAssertEqual(
            try library.load().defaultProfileID,
            bob.id,
            "Tentative browsing followed by Cancel must not change the default"
        )
    }

    func testSuccessfulTrainingCompletionPersistsBeforeAcknowledgement()
        throws
    {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-training-progress-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let library = PilotProfileLibrary(rootURL: rootURL)
        let created = try library.createProfile(named: "Alice")
        let profileID = try XCTUnwrap(created.profiles.first?.id)
        _ = try library.confirmProfile(profileID)

        let level = makeTrainingFinalGoalLevel()
        let chain = try XCTUnwrap(level.trainingFinalGoalChain)
        let goal = try XCTUnwrap(level.objects.first {
            $0.handle == chain.goalObjectHandle
        })
        let initial = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        initial.destroyTrainingRobot(handle: 4_112)
        initial.destroyTrainingRASBot1(handle: 2_074)
        initial.destroyTrainingRASBot2(handle: 2_075)
        initial.destroyTrainingRASBot3(handle: 2_077)
        initial.destroyTrainingRASBot4(handle: 2_078)
        initial.destroyTrainingLastBot1(handle: 4_127)
        initial.destroyTrainingLastBot2(handle: 2_080)
        initial.destroyTrainingLastBot3(handle: 2_081)
        initial.destroyTrainingLastBot4(handle: 2_082)
        initial.destroyTrainingLastBot5(handle: 2_083)
        _ = initial.update(at: 0.1, input: .zero)
        var ready = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(initial.continuation)
            ) as? [String: Any]
        )
        ready["playerLocation"] = [
            "room": ["_0": chain.goalRoomSourceIndex]
        ]
        ready["playerPosition"] = [
            "x": goal.position.x,
            "y": goal.position.y,
            "z": goal.position.z,
        ]
        let simulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: ready)
            ),
            resumedAtTimestamp: 0
        )

        let completionFrame = simulation.update(at: 0.2, input: .zero)
        XCTAssertEqual(
            completionFrame.trainingFinalGoal?.endLevelState,
            .succeeded
        )
        XCTAssertEqual(
            simulation.trainingSessionOutcome,
            .awaitingResultAcknowledgement
        )

        let package = CanonicalPackageReference(
            identitySHA256: String(repeating: "a", count: 64),
            missionKey: "descent3.mission.pilot-training",
            levelKey: "descent3.level.training-mission"
        )
        let completed = try library.recordTrainingCompletion(
            profileID: profileID,
            package: package
        )
        let progress = try XCTUnwrap(
            completed.profiles.first?.missionProgress.first
        )
        XCTAssertEqual(progress.missionName, "Pilot Training")
        XCTAssertEqual(progress.package, package)
        XCTAssertEqual(progress.highestLevel, 0)
        XCTAssertTrue(progress.finished)
        XCTAssertEqual(progress.restoreCount, 0)
        XCTAssertEqual(progress.saveCount, 0)
        XCTAssertEqual(progress.shipPermissions, 0x01)
        XCTAssertEqual(
            try library.load().profiles.first?.missionProgress,
            [progress]
        )
        XCTAssertEqual(
            simulation.trainingSessionOutcome,
            .awaitingResultAcknowledgement,
            "Released EndLevel writes mission progress before result acknowledgement"
        )

        XCTAssertEqual(simulation.acknowledgeTrainingResult(), .completed)
    }

    func testPilotProfileBoundaryRejectsMalformedAndUnsupportedRecords()
        throws
    {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-pilot-boundary-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        let recordURL = rootURL.appending(path: "profiles.json")
        let library = PilotProfileLibrary(rootURL: rootURL)

        try Data(#"{"schemaVersion":2}"#.utf8).write(to: recordURL)
        XCTAssertThrowsError(try library.load()) {
            XCTAssertEqual(
                $0 as? PilotProfileLibraryError,
                .unsupportedSchema(2)
            )
        }

        try Data(
            #"{"schemaVersion":1,"defaultProfileID":null,"profiles":"bad"}"#
                .utf8
        ).write(to: recordURL)
        XCTAssertThrowsError(try library.load()) {
            XCTAssertEqual(
                $0 as? PilotProfileLibraryError,
                .malformedRecord
            )
        }

        let symlinkContainerURL =
            FileManager.default.temporaryDirectory.appending(
                path: "revival-pilot-root-symlink-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        defer {
            try? FileManager.default.removeItem(at: symlinkContainerURL)
        }
        let ownedRootURL = symlinkContainerURL.appending(
            path: "owned",
            directoryHint: .isDirectory
        )
        let linkedRootURL = symlinkContainerURL.appending(
            path: "linked",
            directoryHint: .isDirectory
        )
        _ = try PilotProfileLibrary(rootURL: ownedRootURL)
            .createProfile(named: "Alice")
        try FileManager.default.createSymbolicLink(
            at: linkedRootURL,
            withDestinationURL: ownedRootURL
        )
        XCTAssertThrowsError(
            try PilotProfileLibrary(rootURL: linkedRootURL).load()
        ) {
            XCTAssertEqual(
                $0 as? PilotProfileLibraryError,
                .malformedRecord
            )
        }
    }

    func testPilotProfileAtomicReplacementPreservesPriorRecordOnWriteFailure()
        throws
    {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-pilot-atomic-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: rootURL.path
            )
            try? FileManager.default.removeItem(at: rootURL)
        }
        let recordURL = rootURL.appending(path: "profiles.json")
        let library = PilotProfileLibrary(rootURL: rootURL)
        let created = try library.createProfile(named: "Alice")
        let profileID = try XCTUnwrap(created.profiles.first?.id)
        _ = try library.confirmProfile(profileID)
        let priorData = try Data(contentsOf: recordURL)
        let priorRecord = try library.load()

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: rootURL.path
        )
        XCTAssertThrowsError(try library.createProfile(named: "Bob")) {
            guard case .writeFailed = $0 as? PilotProfileLibraryError else {
                return XCTFail("Expected actionable profile write failure")
            }
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: rootURL.path
        )

        XCTAssertEqual(try Data(contentsOf: recordURL), priorData)
        XCTAssertEqual(try library.load(), priorRecord)

        let replaced = try library.createProfile(named: "Bob")
        XCTAssertEqual(replaced.profiles.map(\.name), ["Alice", "Bob"])
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: rootURL.path),
            ["profiles.json"]
        )
    }

    @MainActor
    func testPilotProfileSelectionRequiresExplicitConfirmation() throws {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-pilot-selection-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let library = PilotProfileLibrary(rootURL: rootURL)
        let aliceRecord = try library.createProfile(named: "Alice")
        let aliceID = try XCTUnwrap(aliceRecord.profiles.first?.id)
        let bobRecord = try library.createProfile(named: "Bob")
        let bobID = try XCTUnwrap(
            bobRecord.profiles.first { $0.name == "Bob" }?.id
        )
        let record = try library.confirmProfile(aliceID)
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var confirmedProfileID: UUID?
        var cancellationCount = 0
        var createdName: String?
        view.pilotProfileConfirmationRequested = {
            confirmedProfileID = $0
        }
        view.pilotProfileCancellationRequested = {
            cancellationCount += 1
        }
        view.pilotProfileCreationRequested = {
            createdName = $0
        }

        view.presentPilotProfileSelection(
            profiles: record.profiles.map { ($0.id, $0.name) },
            defaultProfileID: record.defaultProfileID,
            selectedProfileID: aliceID
        )
        let controls = view.subviews.flatMap { [$0] + $0.subviews }
        let popup = try XCTUnwrap(
            controls.compactMap { $0 as? NSPopUpButton }.first
        )
        popup.selectItem(withTitle: "Bob")
        XCTAssertNil(confirmedProfileID)
        view.requestPilotProfileConfirmation()
        XCTAssertEqual(confirmedProfileID, bobID)
        XCTAssertEqual(try library.load().defaultProfileID, aliceID)

        view.requestPilotProfileCancellation()
        XCTAssertEqual(cancellationCount, 1)

        view.presentPilotProfileSelection(
            profiles: [],
            defaultProfileID: nil,
            selectedProfileID: nil
        )
        let emptyControls = view.subviews.flatMap { [$0] + $0.subviews }
        let cancelButton = try XCTUnwrap(
            emptyControls.compactMap { $0 as? NSButton }.first {
                $0.title == "Cancel"
            }
        )
        XCTAssertFalse(cancelButton.isEnabled)
        let nameField = try XCTUnwrap(
            emptyControls.compactMap { $0 as? NSTextField }.first {
                $0.placeholderString == "Pilot name"
            }
        )
        nameField.stringValue = "Carol"
        view.requestPilotProfileCreation()
        XCTAssertEqual(createdName, "Carol")
    }

    func testInvulnPowerup2ConsumesOnceAndExpiresAcrossContinuation()
        throws
    {
        let level = makeTrainingInvulnerabilityPickupLevel()
        try level.validate()
        var runtimeLevel = level
        let playerIndex = runtimeLevel.objects.firstIndex {
            $0.handle == 2_048
        }!
        let pickupObject = runtimeLevel.objects.first {
            $0.handle == 2_076
        }!
        let chain = try XCTUnwrap(
            runtimeLevel.trainingInvulnerabilityPickupChain
        )
        let playerRadius = defaultPlayerView(
            in: runtimeLevel
        ).collisionRadius
        let combinedRadius =
            playerRadius + chain.pickupCollisionRadius
        runtimeLevel.objects[playerIndex].location = .room(12)
        runtimeLevel.objects[playerIndex].position = .init(
            x: pickupObject.position.x + combinedRadius + 0.01,
            y: pickupObject.position.y,
            z: pickupObject.position.z
        )
        let outside = PlayerSimulation(
            level: runtimeLevel,
            presentationReadyTimestamp: 0
        )
        let outsideFrame = outside.update(at: 0.1, input: .init())
        XCTAssertNil(outsideFrame.trainingInvulnerabilityRemaining)
        XCTAssertTrue(
            outside.level.objects.contains {
                $0.handle == chain.pickupObjectHandle
            })

        runtimeLevel.objects[playerIndex].position = .init(
            x: pickupObject.position.x + combinedRadius - 0.01,
            y: pickupObject.position.y,
            z: pickupObject.position.z
        )
        let simulation = PlayerSimulation(
            level: runtimeLevel,
            presentationReadyTimestamp: 0
        )

        let pickup = simulation.update(at: 0.1, input: .init())

        XCTAssertEqual(
            try XCTUnwrap(
                pickup.trainingInvulnerabilityRemaining
            ),
            29.9,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            pickup.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Invulnerability On"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "Invon.wav"
                ),
                .init(
                    hudMessages: [],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "Power03.wav"
                ),
            ])
        XCTAssertFalse(
            simulation.level.objects.contains {
                $0.handle == chain.pickupObjectHandle
            })
        XCTAssertEqual(
            RevivalGameplayView.invulnerabilityStatusText(
                remaining: pickup.trainingInvulnerabilityRemaining
            ),
            "INVULNERABLE 29.9"
        )
        let pulseStart = try XCTUnwrap(
            RevivalGameplayView.invulnerabilityMonitorPulse(
                remaining: pickup.trainingInvulnerabilityRemaining,
                gameTime: 12,
                drawableWidth: 1_600,
                drawableHeight: 900
            )
        )
        let pulseQuarter = try XCTUnwrap(
            RevivalGameplayView.invulnerabilityMonitorPulse(
                remaining: pickup.trainingInvulnerabilityRemaining,
                gameTime: 12.25,
                drawableWidth: 1_600,
                drawableHeight: 900
            )
        )
        XCTAssertEqual(pulseStart.frame.width, pulseStart.frame.height)
        XCTAssertEqual(
            pulseQuarter.frame.width,
            pulseQuarter.frame.height
        )
        XCTAssertEqual(
            pulseQuarter.frame.width / pulseStart.frame.width,
            1.03,
            accuracy: 0.000_1
        )
        XCTAssertEqual(pulseStart.alpha, 1, accuracy: 0.000_1)
        XCTAssertEqual(pulseQuarter.alpha, 0.875, accuracy: 0.000_1)
        let portraitPulse = try XCTUnwrap(
            RevivalGameplayView.invulnerabilityMonitorPulse(
                remaining: pickup.trainingInvulnerabilityRemaining,
                gameTime: 12.25,
                drawableWidth: 900,
                drawableHeight: 1_600
            )
        )
        XCTAssertEqual(
            portraitPulse.frame.width,
            portraitPulse.frame.height
        )
        XCTAssertNil(
            RevivalGameplayView.invulnerabilityMonitorPulse(
                remaining: nil,
                gameTime: 12.25,
                drawableWidth: 1_600,
                drawableHeight: 900
            )
        )

        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let invulnerabilityState = try XCTUnwrap(
            continuationObject["trainingInvulnerabilityPickupState"]
                as? [String: Any]
        )
        XCTAssertEqual(invulnerabilityState["wasConsumed"] as? Bool, true)
        XCTAssertEqual(
            try XCTUnwrap(
                invulnerabilityState["remainingDuration"] as? Double
            ),
            29.9,
            accuracy: 0.000_1
        )

        var hostileObject = continuationObject
        var hostileState = invulnerabilityState
        hostileState["remainingDuration"] = 30.1
        hostileObject["trainingInvulnerabilityPickupState"] = hostileState
        let hostileContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostileObject)
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: runtimeLevel,
                continuation: hostileContinuation,
                resumedAtTimestamp: 100
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        var chainlessLevelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(runtimeLevel)
            ) as? [String: Any]
        )
        chainlessLevelObject.removeValue(
            forKey: "trainingInvulnerabilityPickupChain"
        )
        let chainlessLevel = try JSONDecoder().decode(
            Level.self,
            from: JSONSerialization.data(
                withJSONObject: chainlessLevelObject
            )
        )
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: chainlessLevel,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: continuationData
                ),
                resumedAtTimestamp: 100
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }

        let restored = try PlayerSimulation(
            level: runtimeLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        let afterReload = restored.update(at: 100.1, input: .init())
        XCTAssertEqual(
            try XCTUnwrap(
                afterReload.trainingInvulnerabilityRemaining
            ),
            29.8,
            accuracy: 0.000_1
        )
        XCTAssertTrue(afterReload.trainingOpeningFeedback.isEmpty)

        let handoff = restored.update(at: 130.0, input: .init())
        XCTAssertEqual(
            try XCTUnwrap(
                handoff.trainingInvulnerabilityRemaining
            ),
            29.7,
            accuracy: 0.000_1
        )
        XCTAssertTrue(handoff.trainingOpeningFeedback.isEmpty)
        let expired = restored.update(at: 130.1, input: .init())
        XCTAssertNil(expired.trainingInvulnerabilityRemaining)
        XCTAssertEqual(
            expired.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Invulnerability Off"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "Invoff.wav"
                )
            ])
        XCTAssertEqual(
            RevivalGameplayView.invulnerabilityStatusText(
                remaining: expired.trainingInvulnerabilityRemaining
            ),
            ""
        )

        let postExpiry = try PlayerSimulation(
            level: runtimeLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(restored.continuation)
            ),
            resumedAtTimestamp: 200
        )
        let repeated = postExpiry.update(at: 200.1, input: .init())
        XCTAssertNil(repeated.trainingInvulnerabilityRemaining)
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertFalse(
            postExpiry.level.objects.contains {
                $0.handle == chain.pickupObjectHandle
            })
    }

    func testCloakPowerup2FadesAndPersistsItsStockVisibilityEffect()
        throws
    {
        var level = makeTrainingCloakPickupLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingCloakPickupChain)
        let pickup = try XCTUnwrap(level.objects.first {
            $0.handle == chain.pickupObjectHandle
        })
        let playerIndex = level.objects.firstIndex {
            $0.handle == 2_048
        }!
        let combinedRadius =
            defaultPlayerView(in: level).collisionRadius
            + chain.pickupCollisionRadius
        level.objects[playerIndex].location =
            .room(chain.pickupRoomSourceIndex)
        level.objects[playerIndex].position = .init(
            x: pickup.position.x + combinedRadius - 0.01,
            y: pickup.position.y,
            z: pickup.position.z
        )
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var frame = simulation.update(at: 0.1, input: .zero)

        XCTAssertEqual(frame.trainingCloak?.phase, .fadingOut)
        XCTAssertEqual(
            try XCTUnwrap(frame.trainingCloak?.objectAlpha),
            0.908,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Cloak On"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "ShpCloakOn.wav"
                ),
                .init(
                    hudMessages: [],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "Power03.wav"
                ),
            ]
        )
        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == chain.pickupObjectHandle
        })
        for frameIndex in 2...10 {
            frame = simulation.update(
                at: Double(frameIndex) * 0.1,
                input: .zero
            )
        }
        XCTAssertEqual(frame.trainingCloak?.phase, .cloaked)
        XCTAssertEqual(frame.trainingCloak?.objectAlpha, 0.13)
        XCTAssertEqual(
            RevivalGameplayView.cloakStatusPresentation(
                frame.trainingCloak
            ).cloakText,
            "CLK"
        )
        let warningPulse =
            RevivalGameplayView.cloakStatusPresentation(.init(
                phase: .cloaked,
                phaseRemaining: 2.25,
                phaseDuration: 30
            ))
        XCTAssertEqual(warningPulse.cloakText, "CLK")
        XCTAssertEqual(
            warningPulse.shipOpacity,
            128.0 / 255,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            warningPulse.cloakOpacity,
            127.0 / 255,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            warningPulse.shipOpacity + warningPulse.cloakOpacity,
            1,
            accuracy: 0.000_1
        )
        let shipMonitorPath =
            RevivalGameplayView.cloakShipMonitorPath(
                in: CGRect(x: 0, y: 0, width: 96, height: 28)
            )
        XCTAssertFalse(shipMonitorPath.isEmpty)
        XCTAssertGreaterThan(
            shipMonitorPath.boundingBoxOfPath.width,
            shipMonitorPath.boundingBoxOfPath.height
        )
        XCTAssertGreaterThan(
            shipMonitorPath.boundingBoxOfPath.height,
            10
        )
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuationData)
                as? [String: Any]
        )
        XCTAssertEqual(continuationObject["schemaVersion"] as? Int, 7)
        let cloakState = try XCTUnwrap(
            continuationObject["trainingCloakPickupState"]
                as? [String: Any]
        )
        XCTAssertEqual(cloakState["wasConsumed"] as? Bool, true)
        XCTAssertEqual(cloakState["phase"] as? String, "cloaked")

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuationData
            ),
            resumedAtTimestamp: 100
        )
        frame = restored.update(at: 100.1, input: .zero)
        XCTAssertEqual(frame.trainingCloak?.phase, .cloaked)
        XCTAssertTrue(frame.trainingOpeningFeedback.isEmpty)

        var nearExpiryObject = continuationObject
        var nearExpiryState = cloakState
        nearExpiryState["phaseRemaining"] = 0.1
        nearExpiryObject["trainingCloakPickupState"] = nearExpiryState
        let nearExpiry = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: nearExpiryObject
                )
            ),
            resumedAtTimestamp: 200
        )
        let fadeIn = nearExpiry.update(at: 200.1, input: .zero)
        XCTAssertEqual(fadeIn.trainingCloak?.phase, .fadingIn)
        XCTAssertEqual(fadeIn.trainingCloak?.objectAlpha, 0.08)
        XCTAssertEqual(
            fadeIn.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: ["Cloak Off"],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true,
                    soundSourceName: "ShpCloakOffBeep.wav"
                )
            ]
        )
        XCTAssertEqual(
            RevivalGameplayView.cloakStatusPresentation(
                fadeIn.trainingCloak
            ).cloakText,
            ""
        )
        var finalFrame = fadeIn
        for frameIndex in 2...11 {
            finalFrame = nearExpiry.update(
                at: 200 + Double(frameIndex) * 0.1,
                input: .zero
            )
        }
        XCTAssertNil(finalFrame.trainingCloak)
        XCTAssertTrue(finalFrame.trainingOpeningFeedback.isEmpty)

        let postExpiry = try PlayerSimulation(
            level: level,
            continuation: nearExpiry.continuation,
            resumedAtTimestamp: 300
        )
        let repeated = postExpiry.update(at: 300.1, input: .zero)
        XCTAssertNil(repeated.trainingCloak)
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertFalse(postExpiry.level.objects.contains {
            $0.handle == chain.pickupObjectHandle
        })
    }

    func testCloakPowerup2SixthProducerRunsScript034AndTimerNineOnce()
        throws
    {
        let level = makeTrainingCloakPickupLevel()
        let cloak = try XCTUnwrap(level.trainingCloakPickupChain)
        let pickup = try XCTUnwrap(level.objects.first {
            $0.handle == cloak.pickupObjectHandle
        })
        let initial = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var readyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(initial.continuation)
            ) as? [String: Any]
        )
        for key in [
            "trainingRASBot1DeathState",
            "trainingRASBot2DeathState",
            "trainingRASBot3DeathState",
            "trainingRASBot4DeathState",
        ] {
            readyObject[key] = [
                "wasDestroyed": true,
                "shields": -5,
            ]
        }
        readyObject["trainingInvulnerabilityPickupState"] = [
            "scriptWasTriggered": true,
            "wasConsumed": true,
        ]
        readyObject["playerLocation"] = [
            "room": ["_0": cloak.pickupRoomSourceIndex]
        ]
        readyObject["playerPosition"] = [
            "x": pickup.position.x,
            "y": pickup.position.y,
            "z": pickup.position.z,
        ]
        let simulation = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(withJSONObject: readyObject)
            ),
            resumedAtTimestamp: 0
        )

        var frame = simulation.update(at: 0.1, input: .zero)

        let chain = try XCTUnwrap(level.trainingLastRoomChain)
        func assertBarrierIsOpen(in level: Level) throws {
            let barrier = try XCTUnwrap(level.rooms.first {
                $0.sourceIndex == chain.barrierRoomSourceIndex
            })
            for portalIndex in chain.orderedPortalIndices {
                let portal = barrier.portals[portalIndex]
                XCTAssertEqual(portal.flags & 1, 0)
                let connected = try XCTUnwrap(level.rooms.first {
                    $0.sourceIndex == portal.connectedRoom
                })
                XCTAssertEqual(
                    connected.portals[portal.connectedPortal].flags & 1,
                    0
                )
            }
        }
        XCTAssertEqual(chain.orderedPortalIndices, [1, 0])
        try assertBarrierIsOpen(in: simulation.level)
        XCTAssertEqual(frame.trainingLastRoomMarkerLightDistance, 50)
        XCTAssertFalse(frame.trainingOpeningFeedback.contains {
            $0.voiceSourceName == "proceed5.osf"
        })
        let triggeredData = try JSONEncoder().encode(
            simulation.continuation
        )
        let triggeredObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: triggeredData)
                as? [String: Any]
        )
        let triggeredState = try XCTUnwrap(
            triggeredObject["trainingLastRoomState"]
                as? [String: Any]
        )
        XCTAssertEqual(triggeredState["wasTriggered"] as? Bool, true)
        XCTAssertEqual(
            try XCTUnwrap(
                triggeredState["timerRemaining"] as? Double
            ),
            2,
            accuracy: 0.000_1
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: triggeredData
            ),
            resumedAtTimestamp: 100
        )
        try assertBarrierIsOpen(in: restored.level)
        for frameIndex in 1...20 {
            frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: .zero
            )
        }
        XCTAssertEqual(
            frame.trainingOpeningFeedback,
            [
                .init(
                    hudMessages: [
                        "Excellent!",
                        "Now proceed through the doorway that just opened to begin the last stage of your training.",
                    ],
                    voiceSourceName: "proceed5.osf",
                    voicePrecedesHUDMessages: false
                )
            ]
        )
        let repeated = restored.update(at: 102.1, input: .zero)
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(repeated.trainingLastRoomMarkerLightDistance, 50)

        let completed = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONEncoder().encode(restored.continuation)
            ),
            resumedAtTimestamp: 200
        )
        try assertBarrierIsOpen(in: completed.level)
        let resumedCompleted = completed.update(
            at: 200.1,
            input: .zero
        )
        XCTAssertTrue(
            resumedCompleted.trainingOpeningFeedback.isEmpty
        )
        XCTAssertEqual(
            resumedCompleted.trainingLastRoomMarkerLightDistance,
            50
        )
    }

    func testSchemaSevenContinuationDefaultsScript048And050States()
        throws
    {
        let previousLevel = makeTrainingInvulnerabilityPickupLevel()
        let previous = PlayerSimulation(
            level: previousLevel,
            presentationReadyTimestamp: 0
        )
        let previousData = try JSONEncoder().encode(previous.continuation)
        let previousObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: previousData)
                as? [String: Any]
        )
        XCTAssertNil(previousObject["trainingCloakPickupState"])
        XCTAssertNil(previousObject["trainingLastRoomState"])
        XCTAssertNil(previousObject["trainingFinalRoomEntryState"])

        let currentLevel = makeTrainingFinalRoomEntryLevel()
        let restored = try PlayerSimulation(
            level: currentLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: previousData
            ),
            resumedAtTimestamp: 100
        )

        XCTAssertTrue(restored.level.objects.contains {
            $0.handle == 2_073
        })
        let currentObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(restored.continuation)
            ) as? [String: Any]
        )
        XCTAssertNotNil(currentObject["trainingCloakPickupState"])
        XCTAssertNotNil(currentObject["trainingLastRoomState"])
        XCTAssertNotNil(
            currentObject["trainingFinalRoomEntryState"]
        )

        let finalBotsLevel =
            makeTrainingFinalBotsCompletionLevel()
        let finalBotsRestored = try PlayerSimulation(
            level: finalBotsLevel,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: previousData
            ),
            resumedAtTimestamp: 200
        )
        let finalBotsObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    finalBotsRestored.continuation
                )
            ) as? [String: Any]
        )
        XCTAssertNotNil(
            finalBotsObject["trainingFinalBotsCompletionState"]
        )
    }

    func testScript050ClosesPortalRoomSixInSourceOrderAndSurvivesReload()
        throws
    {
        let level = makeTrainingFinalRoomEntryLevel()
        try level.validate()
        let chain = try XCTUnwrap(level.trainingFinalRoomEntryChain)
        let simulation = try PlayerSimulation(
            level: level,
            continuation: script050ReadyContinuation(in: level),
            resumedAtTimestamp: 0
        )

        let frame = simulation.update(at: 0.1, input: .zero)

        XCTAssertEqual(
            frame.trainingOpeningFeedback.suffix(2),
            [
                .init(
                    hudMessages: [chain.successMessage],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true
                ),
                .init(
                    hudMessages: [chain.instructionMessage],
                    voiceSourceName: chain.voiceSourceName,
                    voicePrecedesHUDMessages: true
                ),
            ]
        )
        let closedRoom = try XCTUnwrap(simulation.level.rooms.first {
            $0.sourceIndex
                == level.trainingLastRoomChain?.barrierRoomSourceIndex
        })
        for portalIndex in [1, 0] {
            let portal = closedRoom.portals[portalIndex]
            XCTAssertNotEqual(portal.flags & 1, 0)
            let connected = try XCTUnwrap(
                simulation.level.rooms.first {
                    $0.sourceIndex == portal.connectedRoom
                }
            )
            XCTAssertNotEqual(
                connected.portals[portal.connectedPortal].flags & 1,
                0
            )
        }
        XCTAssertEqual(frame.trainingLastRoomMarkerLightDistance, 0)
        let continuedData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: continuedData)
                as? [String: Any]
        )
        XCTAssertEqual(
            (
                continuedObject["trainingFinalRoomEntryState"]
                    as? [String: Any]
            )?["wasTriggered"] as? Bool,
            true
        )

        let restored = try PlayerSimulation(
            level: level,
            continuation: JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: continuedData
            ),
            resumedAtTimestamp: 100
        )
        let repeated = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(repeated.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(
            repeated.trainingLastRoomMarkerLightDistance,
            0
        )

        let sameFrameTail = try PlayerSimulation(
            level: level,
            continuation: script050ReadyContinuation(
                in: level,
                timerRemaining: 0.1
            ),
            resumedAtTimestamp: 0
        ).update(at: 0.1, input: .zero)
        XCTAssertEqual(
            sameFrameTail.trainingOpeningFeedback.suffix(3),
            [
                .init(
                    hudMessages: [chain.successMessage],
                    voiceSourceName: "",
                    voicePrecedesHUDMessages: true
                ),
                .init(
                    hudMessages: [chain.instructionMessage],
                    voiceSourceName: chain.voiceSourceName,
                    voicePrecedesHUDMessages: true
                ),
                .init(
                    hudMessages:
                        level.trainingLastRoomChain?.completionMessages
                        ?? [],
                    voiceSourceName: "proceed5.osf",
                    voicePrecedesHUDMessages: false
                ),
            ]
        )

        let fresh = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var hostileObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(fresh.continuation)
            ) as? [String: Any]
        )
        hostileObject["trainingFinalRoomEntryState"] = [
            "wasTriggered": true
        ]
        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: JSONDecoder().decode(
                    PlayerSimulationContinuation.self,
                    from: JSONSerialization.data(
                        withJSONObject: hostileObject
                    )
                ),
                resumedAtTimestamp: 200
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    func testGuidebotReturnTracksLivePlayerMovementInSameFrame()
        throws
    {
        let level = makeTrainingCameraMonitorLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = simulation.update(at: 0.2, input: .init(usesInventory: true))
        _ = simulation.update(
            at: 0.3,
            input: .init(deploysTrainingGuidebot: true)
        )

        let followingMovedPlayer = simulation.update(
            at: 0.4,
            input: .init(forward: 1)
        )

        XCTAssertEqual(
            followingMovedPlayer.trainingGuidebot?.destination,
            followingMovedPlayer.playerView.camera.position
        )
    }

    func testGuidebotReturnReallocatesWhenLivePlayerChangesRooms()
        throws
    {
        var level = makeTrainingCameraMonitorLevel()
        let targetPosition = Vector3(
            x: 10_000,
            y: 10_000,
            z: 10_000
        )
        let targetRoom = makeSourceContainmentRoom(
            center: targetPosition,
            texture: level.surfacePhysics[0].texture,
            sourceIndex: 999,
            halfExtent: 100
        )
        level.rooms.append(targetRoom)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = simulation.update(at: 0.2, input: .init(usesInventory: true))
        let requested = simulation.update(
            at: 0.3,
            input: .init(deploysTrainingGuidebot: true)
        )
        let guidebot = try XCTUnwrap(requested.trainingGuidebot)
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        var playerLocation = try XCTUnwrap(
            continuationObject["playerLocation"] as? [String: Any]
        )
        playerLocation["room"] = ["_0": targetRoom.sourceIndex]
        continuationObject["playerLocation"] = playerLocation
        continuationObject["playerPosition"] = [
            "x": targetPosition.x,
            "y": targetPosition.y,
            "z": targetPosition.z,
        ]
        let movedPlayerContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: continuationObject
            )
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: movedPlayerContinuation,
            resumedAtTimestamp: 100
        )

        let reallocated = restored.update(at: 100.1, input: .zero)

        let reallocatedGuidebot = try XCTUnwrap(
            reallocated.trainingGuidebot
        )
        let liveTarget = reallocated.playerView.camera.position
        XCTAssertEqual(reallocatedGuidebot.destination, liveTarget)
        if reallocatedGuidebot.routeFailure == nil {
            XCTAssertEqual(
                reallocatedGuidebot.route.roomSourceIndices.last,
                targetRoom.sourceIndex
            )
        } else {
            XCTAssertEqual(reallocatedGuidebot.route.mode, .direct)
            XCTAssertEqual(
                reallocatedGuidebot.route.points,
                [liveTarget]
            )
            XCTAssertNotEqual(
                reallocatedGuidebot.route,
                guidebot.route
            )
        }
    }

    func testGuidebotCrossRoomReturnReachesScript058() throws {
        var level = makeTrainingCameraMonitorLevel()
        let start = RoomCamera.trainingRoom3.position
        let turn = Vector3(x: start.x, y: start.y + 200, z: start.z)
        let destination = Vector3(
            x: start.x + 400,
            y: start.y + 200,
            z: start.z
        )
        let blockingTexture = try XCTUnwrap(
            level.surfacePhysics.first {
                $0.behavior == .blocking
            }?.texture
        )
        let returnTexture = SourceResource(
            storedIndex: 908,
            sourceName: "Alien Force Field_1"
        )
        func portalFace(
            _ face: LevelFace,
            portalIndex: Int
        ) -> LevelFace {
            .init(
                corners: face.corners,
                flags: face.flags,
                portalIndex: portalIndex,
                texture: returnTexture
            )
        }
        var room3 = makeSourceContainmentRoom(
            center: start,
            texture: blockingTexture,
            sourceIndex: 3,
            halfExtent: 100
        )
        room3 = LevelRoom(
            sourceIndex: 3,
            pathPoint: start,
            vertices: room3.vertices,
            faces: room3.faces.enumerated().map {
                $0.offset == 3
                    ? portalFace($0.element, portalIndex: 0)
                    : $0.element
            },
            portals: [
                .init(
                    faceIndex: 3,
                    connectedRoom: 2,
                    connectedPortal: 0,
                    pathPoint: .init(
                        x: start.x,
                        y: start.y + 100,
                        z: start.z
                    )
                ),
            ]
        )
        var room2 = makeSourceContainmentRoom(
            center: turn,
            texture: blockingTexture,
            sourceIndex: 2,
            halfExtent: 100
        )
        room2 = LevelRoom(
            sourceIndex: 2,
            pathPoint: turn,
            vertices: room2.vertices,
            faces: room2.faces.enumerated().map {
                if $0.offset == 2 {
                    return portalFace($0.element, portalIndex: 0)
                }
                if $0.offset == 1 {
                    return portalFace($0.element, portalIndex: 1)
                }
                return $0.element
            },
            portals: [
                .init(
                    faceIndex: 2,
                    connectedRoom: 3,
                    connectedPortal: 0,
                    pathPoint: .init(
                        x: start.x,
                        y: start.y + 100,
                        z: start.z
                    )
                ),
                .init(
                    faceIndex: 1,
                    connectedRoom: 1,
                    connectedPortal: 0,
                    pathPoint: .init(
                        x: start.x + 100,
                        y: start.y + 200,
                        z: start.z
                    )
                ),
            ]
        )
        var room1 = makeSourceContainmentRoom(
            center: destination,
            texture: blockingTexture,
            sourceIndex: 1,
            halfExtent: 300
        )
        room1 = LevelRoom(
            sourceIndex: 1,
            pathPoint: destination,
            vertices: room1.vertices,
            faces: room1.faces.enumerated().map {
                $0.offset == 0
                    ? portalFace($0.element, portalIndex: 0)
                    : $0.element
            },
            portals: [
                .init(
                    faceIndex: 0,
                    connectedRoom: 2,
                    connectedPortal: 1,
                    pathPoint: .init(
                        x: start.x + 100,
                        y: start.y + 200,
                        z: start.z
                    )
                )
            ]
        )
        var objects = level.objects
        for handle in [UInt32(2_048), 6_167, 6_183, 10_245] {
            let objectIndex = try XCTUnwrap(objects.firstIndex {
                $0.handle == handle
            })
            objects[objectIndex].location = .room(3)
            objects[objectIndex].position = start
        }
        level = replacing(
            level,
            rooms: [room1, room2, room3],
            objects: objects,
            indoorNavigation: .init(
                sourceHighestRoomPlusTerrainRegions: 11,
                sourceWasVerified: true,
                rooms: []
            )
        )
        let guidebotDefinition = try XCTUnwrap(
            level.trainingRobotGuidebotChain?.guidebot
        )
        let allocated = try trainingGuidebotRoute(
            in: level,
            startRoomSourceIndex: 3,
            start: start,
            startForward: .init(x: 1, y: 0, z: 0),
            destinationRoomSourceIndex: 1,
            destination: destination,
            radius: max(0, guidebotDefinition.collisionRadius - 0.1)
        ).get()
        XCTAssertEqual(allocated.mode, .roomPortals)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = simulation.update(at: 0.2, input: .init(usesInventory: true))

        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        continuationObject["playerLocation"] = [
            "room": ["_0": 1],
        ]
        continuationObject["playerPosition"] = [
            "x": destination.x,
            "y": destination.y,
            "z": destination.z,
        ]
        let movedPlayerContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: continuationObject
            )
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: movedPlayerContinuation,
            resumedAtTimestamp: 100
        )

        var completed: PlayerSimulationFrame?
        for frameIndex in 1...200 {
            let frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: frameIndex == 1
                    ? .init(deploysTrainingGuidebot: true)
                    : .zero
            )
            if frameIndex == 1 {
                XCTAssertEqual(
                    frame.trainingGuidebot?.route.mode,
                    .roomPortals
                )
                XCTAssertEqual(
                    frame.trainingGuidebot?.route
                        .roomSourceIndices.last,
                    1
                )
                XCTAssertGreaterThan(
                    frame.trainingGuidebot?.route
                        .roomSourceIndices.count ?? 0,
                    1
                )
            }
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                completed = frame
                break
            }
        }

        let script058 = try XCTUnwrap(completed)
        XCTAssertNil(script058.trainingGuidebot)
        XCTAssertEqual(
            script058.trainingGuidebotReturnMarkerLightDistance,
            50
        )
        assertTrainingGuidebotReturnBarrier(
            level: restored.level,
            rendersFaces: false
        )
    }

    func testContinuationRejectsUnrequestedGuidebotReturnTask() throws {
        let level = makeTrainingCameraMonitorLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        var robotState = try XCTUnwrap(
            continuationObject["trainingRobotGuidebotState"]
                as? [String: Any]
        )
        XCTAssertEqual(robotState["returnWasRequested"] as? Bool, false)
        var guidebot = try XCTUnwrap(
            robotState["guidebot"] as? [String: Any]
        )
        guidebot["task"] = "returnToShip"
        robotState["guidebot"] = guidebot
        continuationObject["trainingRobotGuidebotState"] = robotState
        let hostileContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(
                withJSONObject: continuationObject
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
    }

    func testCameraMonitorPickupCompletesLocateGoalAcrossReload() throws {
        let level = makeTrainingCameraMonitorLevel()
        let locateGoal = try XCTUnwrap(level.goals.first {
            $0.name == "Locate the Camera Monitor"
        })
        XCTAssertEqual(locateGoal.status, 1_028)
        XCTAssertEqual(locateGoal.items, [
            .init(
                type: 2,
                sourceHandle: 6_167,
                objectHandle: 6_167,
                done: false
            ),
        ])
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        _ = simulation.update(at: 0.1, input: .zero)

        let completedGoal = try XCTUnwrap(simulation.level.goals.first {
            $0.name == "Locate the Camera Monitor"
        })
        XCTAssertEqual(completedGoal.status, 1_036)
        XCTAssertEqual(completedGoal.items.map(\.done), [true])
        let restored = try PlayerSimulation(
            level: level,
            continuation: simulation.continuation,
            resumedAtTimestamp: 100
        )
        let restoredGoal = try XCTUnwrap(restored.level.goals.first {
            $0.name == "Locate the Camera Monitor"
        })
        XCTAssertEqual(restoredGoal.status, 1_036)
        XCTAssertEqual(restoredGoal.items.map(\.done), [true])
    }

    func testCameraMonitorPopupStartsInTracedGunpointRoom() throws {
        var level = makeTrainingCameraMonitorLevel()
        let chain = try XCTUnwrap(level.trainingCameraMonitorChain)
        let cameraIndex = try XCTUnwrap(level.objects.firstIndex {
            $0.handle == chain.securityCameraObjectHandle
        })
        var reachedPortal: (
            startRoom: Int,
            connectedRoom: Int,
            cameraCenter: Vector3,
            gunpoint: Vector3
        )?
        for candidateRoom in level.rooms {
            for portal in candidateRoom.portals {
                let face = candidateRoom.faces[portal.faceIndex]
                let vertices = face.corners.map {
                    candidateRoom.vertices[$0.vertexIndex]
                }
                var center = Vector3.zero
                for vertex in vertices {
                    center = .init(
                        x: center.x + vertex.x,
                        y: center.y + vertex.y,
                        z: center.z + vertex.z
                    )
                }
                let count = Float(vertices.count)
                center = .init(
                    x: center.x / count,
                    y: center.y / count,
                    z: center.z / count
                )
                guard let normal = canonicalFaceNormal(
                    room: candidateRoom,
                    face: face
                ) else {
                    continue
                }
                let positive = Vector3(
                    x: center.x + normal.x * 0.01,
                    y: center.y + normal.y * 0.01,
                    z: center.z + normal.z * 0.01
                )
                let negative = Vector3(
                    x: center.x - normal.x * 0.01,
                    y: center.y - normal.y * 0.01,
                    z: center.z - normal.z * 0.01
                )
                let positiveIsInside =
                    containingIndoorRoomSourceIndex(
                        in: level,
                        position: positive,
                        candidates: [candidateRoom.sourceIndex]
                    ) == candidateRoom.sourceIndex
                let candidateCenter =
                    positiveIsInside ? positive : negative
                let candidateGunpoint =
                    positiveIsInside ? negative : positive
                let trace = traceIndoorMovement(
                    in: level,
                    startRoom: candidateRoom.sourceIndex,
                    start: candidateCenter,
                    end: candidateGunpoint,
                    radius: 0
                )
                if trace.containingRoomSourceIndex
                    == portal.connectedRoom {
                    reachedPortal = (
                        candidateRoom.sourceIndex,
                        portal.connectedRoom,
                        candidateCenter,
                        candidateGunpoint
                    )
                    break
                }
            }
            if reachedPortal != nil { break }
        }
        let portalFixture = try XCTUnwrap(reachedPortal)
        let connectedRoomSourceIndex = portalFixture.connectedRoom
        let cameraCenter = portalFixture.cameraCenter
        let gunpoint = portalFixture.gunpoint
        level.objects[cameraIndex].location =
            .room(portalFixture.startRoom)
        level.objects[cameraIndex].position = cameraCenter
        level.objects[cameraIndex].orientation = .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )
        let movedChain = TrainingCameraMonitorChain(
            pickupObjectHandle: chain.pickupObjectHandle,
            securityCameraObjectHandle:
                chain.securityCameraObjectHandle,
            pickupCollisionRadius: chain.pickupCollisionRadius,
            pickupMessage: chain.pickupMessage,
            pickupVoiceSourceName: chain.pickupVoiceSourceName,
            pickupSoundSourceName: chain.pickupSoundSourceName,
            useMessage: chain.useMessage,
            useVoiceSourceName: chain.useVoiceSourceName,
            popupDuration: chain.popupDuration,
            popupZoom: chain.popupZoom,
            cameraGunpointIndex: chain.cameraGunpointIndex,
            cameraLocalPosition: .init(
                x: gunpoint.x - cameraCenter.x,
                y: gunpoint.y - cameraCenter.y,
                z: gunpoint.z - cameraCenter.z
            ),
            cameraLocalForward: .init(x: 0, y: 1, z: 0),
            completionTimerDuration: chain.completionTimerDuration
        )
        level = replacing(
            level,
            objects: level.objects,
            trainingCameraMonitorChain: movedChain
        )
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(at: 0.1, input: .zero)

        let used = simulation.update(
            at: 0.2,
            input: .init(usesInventory: true)
        )

        XCTAssertEqual(
            used.trainingCameraMonitor?.roomSourceIndex,
            connectedRoomSourceIndex
        )
    }

    func testCameraMonitorPickupUsesAcceptedWallResponseSegments() throws {
        func missesSphere(
            start: Vector3,
            end: Vector3,
            center: Vector3,
            radius: Float
        ) -> Bool {
            let movement = Vector3(
                x: end.x - start.x,
                y: end.y - start.y,
                z: end.z - start.z
            )
            let toCenter = Vector3(
                x: center.x - start.x,
                y: center.y - start.y,
                z: center.z - start.z
            )
            let lengthSquared =
                movement.x * movement.x
                + movement.y * movement.y
                + movement.z * movement.z
            let fraction = lengthSquared > 0
                ? max(0, min(
                    1,
                    (
                        toCenter.x * movement.x
                        + toCenter.y * movement.y
                        + toCenter.z * movement.z
                    ) / lengthSquared
                ))
                : 0
            let closest = Vector3(
                x: start.x + movement.x * fraction,
                y: start.y + movement.y * fraction,
                z: start.z + movement.z * fraction
            )
            let distance = Vector3(
                x: center.x - closest.x,
                y: center.y - closest.y,
                z: center.z - closest.z
            )
            return distance.x * distance.x
                + distance.y * distance.y
                + distance.z * distance.z
                > radius * radius
        }
        let contactLevel = makeSliceTenContactLevel(clearance: 20)
        let baseline = PlayerSimulation(
            level: contactLevel,
            presentationReadyTimestamp: 0
        )
        _ = baseline.update(at: 2, input: .zero)
        let start = defaultPlayerView(in: baseline.level).camera.position
        let baselineFrame = baseline.update(
            at: 4,
            input: .init(forward: 1, sideways: 1)
        )
        let contact = try XCTUnwrap(baselineFrame.wallContact)
        let final = baselineFrame.playerView.camera.position
        let contactCenter = Vector3(
            x:
                contact.contactPoint.x
                + contact.normal.x
                    * baselineFrame.playerView.collisionRadius,
            y:
                contact.contactPoint.y
                + contact.normal.y
                    * baselineFrame.playerView.collisionRadius,
            z:
                contact.contactPoint.z
                + contact.normal.z
                    * baselineFrame.playerView.collisionRadius
        )
        let pickupRadius =
            baselineFrame.playerView.collisionRadius + 0.01
        var falseChordPoint: Vector3?
        for tenth in 1..<10 {
            let fraction = Float(tenth) / 10
            let candidate = Vector3(
                x: start.x + (final.x - start.x) * fraction,
                y: start.y + (final.y - start.y) * fraction,
                z: start.z + (final.z - start.z) * fraction
            )
            if missesSphere(
                start: start,
                end: contactCenter,
                center: candidate,
                radius: pickupRadius
            ),
            missesSphere(
                start: contactCenter,
                end: final,
                center: candidate,
                radius: pickupRadius
            ) {
                falseChordPoint = candidate
                break
            }
        }
        let pickupPosition = try XCTUnwrap(falseChordPoint)
        let cameraFixture = makeTrainingCameraMonitorLevel()
        let sourceChain = try XCTUnwrap(
            cameraFixture.trainingCameraMonitorChain
        )
        var pickup = try XCTUnwrap(cameraFixture.objects.first {
            $0.handle == sourceChain.pickupObjectHandle
        })
        pickup.location = .room(
            baselineFrame.playerView.roomSourceIndex
        )
        pickup.position = pickupPosition
        let chain = TrainingCameraMonitorChain(
            pickupObjectHandle: sourceChain.pickupObjectHandle,
            securityCameraObjectHandle:
                sourceChain.securityCameraObjectHandle,
            pickupCollisionRadius: 0.01,
            pickupMessage: sourceChain.pickupMessage,
            pickupVoiceSourceName: sourceChain.pickupVoiceSourceName,
            pickupSoundSourceName: sourceChain.pickupSoundSourceName,
            useMessage: sourceChain.useMessage,
            useVoiceSourceName: sourceChain.useVoiceSourceName,
            popupDuration: sourceChain.popupDuration,
            popupZoom: sourceChain.popupZoom,
            cameraGunpointIndex: sourceChain.cameraGunpointIndex,
            cameraLocalPosition: sourceChain.cameraLocalPosition,
            cameraLocalForward: sourceChain.cameraLocalForward,
            completionTimerDuration:
                sourceChain.completionTimerDuration
        )
        let level = replacing(
            contactLevel,
            schemaVersion: 10,
            objects: contactLevel.objects + [pickup],
            trainingCameraMonitorChain: chain
        )
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(at: 2, input: .zero)

        let frame = simulation.update(
            at: 4,
            input: .init(forward: 1, sideways: 1)
        )

        XCTAssertTrue(frame.trainingOpeningFeedback.isEmpty)
    }

    func testSchemaSevenRejectsTriggeredLastRoomWithoutSixProducers()
        throws
    {
        let level = makeTrainingCloakPickupLevel()
        let initial = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var hostile = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(initial.continuation)
            ) as? [String: Any]
        )
        hostile["trainingLastRoomState"] = [
            "wasTriggered": true,
            "markerLightDistance": 50,
            "timerRemaining": 2,
            "wasPresented": false,
        ]
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: hostile)
        )

        XCTAssertThrowsError(
            try PlayerSimulation(
                level: level,
                continuation: continuation,
                resumedAtTimestamp: 100
            )
        ) {
            XCTAssertEqual(
                $0 as? PlayerSimulationContinuationError,
                .invalidState
            )
        }
    }

    func testTrainingGuidebotUsesVerifiedBoundaryNodesAroundBlockedDirectLine() throws {
        var level = makeSliceTenContactLevel(clearance: 20)
        let player = level.objects.first { $0.handle == 2_048 }!
        guard case let .room(roomSourceIndex) = player.location else {
            return XCTFail("expected indoor player")
        }
        let distractorRoomSourceIndex = try XCTUnwrap(
            level.rooms.first {
                $0.sourceIndex != roomSourceIndex
            }?.sourceIndex
        )
        let wallOffset = Vector3(
            x: player.orientation.right.x * 25,
            y: player.orientation.right.y * 25,
            z: player.orientation.right.z * 25
        )
        let forwardTen = Vector3(
            x: player.orientation.forward.x * 10,
            y: player.orientation.forward.y * 10,
            z: player.orientation.forward.z * 10
        )
        let forwardThirty = Vector3(
            x: player.orientation.forward.x * 30,
            y: player.orientation.forward.y * 30,
            z: player.orientation.forward.z * 30
        )
        let forwardForty = Vector3(
            x: player.orientation.forward.x * 40,
            y: player.orientation.forward.y * 40,
            z: player.orientation.forward.z * 40
        )
        let beforeWall = Vector3(
            x: player.position.x + forwardTen.x + wallOffset.x,
            y: player.position.y + forwardTen.y + wallOffset.y,
            z: player.position.z + forwardTen.z + wallOffset.z
        )
        let beyondWall = Vector3(
            x: player.position.x + forwardThirty.x + wallOffset.x,
            y: player.position.y + forwardThirty.y + wallOffset.y,
            z: player.position.z + forwardThirty.z + wallOffset.z
        )
        let laterVisibleStart = Vector3(
            x: beforeWall.x + player.orientation.forward.x * 2,
            y: beforeWall.y + player.orientation.forward.y * 2,
            z: beforeWall.z + player.orientation.forward.z * 2
        )
        let destination = Vector3(
            x: player.position.x + forwardForty.x,
            y: player.position.y + forwardForty.y,
            z: player.position.z + forwardForty.z
        )
        level = replacing(
            level,
            indoorNavigation: .init(
                sourceHighestRoomPlusTerrainRegions:
                    level.rooms.map(\.sourceIndex).max()! + 8,
                sourceWasVerified: true,
                rooms: [
                    .init(
                        sourceIndex: roomSourceIndex,
                        nodes: [
                            .init(
                                position: beforeWall,
                                edges: [
                                    .init(
                                        destinationRoomSourceIndex:
                                            roomSourceIndex,
                                        destinationNodeIndex: 1,
                                        flags: 0,
                                        cost: 20,
                                        maximumRadius: 6
                                    ),
                                ]
                            ),
                            .init(
                                position: beyondWall,
                                edges: [
                                    .init(
                                        destinationRoomSourceIndex:
                                            roomSourceIndex,
                                        destinationNodeIndex: 0,
                                        flags: 0,
                                        cost: 20,
                                        maximumRadius: 6
                                    ),
                                    .init(
                                        destinationRoomSourceIndex:
                                            roomSourceIndex,
                                        destinationNodeIndex: 2,
                                        flags: 0,
                                        cost: 20,
                                        maximumRadius: 6
                                    ),
                                ]
                            ),
                            .init(
                                position: laterVisibleStart,
                                edges: [
                                    .init(
                                        destinationRoomSourceIndex:
                                            distractorRoomSourceIndex,
                                        destinationNodeIndex: 0,
                                        flags: 0,
                                        cost: 1,
                                        maximumRadius: 6
                                    ),
                                    .init(
                                        destinationRoomSourceIndex:
                                            roomSourceIndex,
                                        destinationNodeIndex: 1,
                                        flags: 0,
                                        cost: 20,
                                        maximumRadius: 6
                                    ),
                                ]
                            ),
                        ]
                    ),
                    .init(
                        sourceIndex: distractorRoomSourceIndex,
                        nodes: [
                            .init(
                                position: laterVisibleStart,
                                edges: [
                                    .init(
                                        destinationRoomSourceIndex:
                                            roomSourceIndex,
                                        destinationNodeIndex: 2,
                                        flags: 0,
                                        cost: 1,
                                        maximumRadius: 6
                                    ),
                                ]
                            ),
                        ]
                    ),
                ]
            )
        )
        XCTAssertNoThrow(try level.validate())

        XCTAssertEqual(
            trainingGuidebotRoute(
                in: level,
                startRoomSourceIndex: roomSourceIndex,
                start: player.position,
                startForward: player.orientation.forward,
                destinationRoomSourceIndex: roomSourceIndex,
                destination: destination,
                radius: 1
            ),
            .success(.init(
                mode: .boundaryNodes,
                points: [laterVisibleStart, beyondWall, destination],
                roomSourceIndices: [roomSourceIndex],
                nodeReferences: [
                    .init(roomSourceIndex: roomSourceIndex, nodeIndex: 2),
                    .init(roomSourceIndex: roomSourceIndex, nodeIndex: 1),
                ]
            ))
        )
    }

    func testTrainingGuidebotMovesThroughAllocatedRouteAndResumesDeterministically() throws {
        let level = makeTrainingGuidebotBlockedMovementLevel()
        let player = try XCTUnwrap(
            level.objects.first { $0.handle == 2_048 }
        )
        guard case let .room(playerRoomSourceIndex) = player.location else {
            return XCTFail("expected indoor player")
        }
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        var timestamp = 0.1
        var frame = simulation.update(
            at: timestamp,
            input: .init(deploysTrainingGuidebot: true)
        )
        var guidebot = try XCTUnwrap(frame.trainingGuidebot)
        XCTAssertEqual(guidebot.route.mode, .boundaryNodes)
        XCTAssertEqual(guidebot.activeSteeringMode, .allocatedRoute)
        XCTAssertGreaterThan(
            guidebot.velocity.x * player.orientation.right.x
                + guidebot.velocity.y * player.orientation.right.y
                + guidebot.velocity.z * player.orientation.right.z,
            0
        )
        XCTAssertEqual(
            try guidebotRoutePointIndex(in: simulation.continuation),
            0
        )

        for _ in 0..<19 {
            guard try guidebotRoutePointIndex(
                in: simulation.continuation
            ) == 0 else {
                break
            }
            timestamp += 0.1
            frame = simulation.update(at: timestamp, input: .zero)
            guidebot = try XCTUnwrap(frame.trainingGuidebot)
            XCTAssertEqual(guidebot.activeSteeringMode, .allocatedRoute)
            XCTAssertEqual(
                simulation.level.objects.first {
                    $0.instanceName == "GuideBotB"
                }?.location,
                .room(playerRoomSourceIndex)
            )
        }
        XCTAssertEqual(
            try guidebotRoutePointIndex(in: simulation.continuation),
            1
        )

        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
        )
        let restored = try PlayerSimulation(
            level: level,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        XCTAssertEqual(restored.continuation, continuation)

        var restoredTimestamp = 100.0
        for _ in 0..<12 {
            timestamp += 0.1
            restoredTimestamp += 0.1
            let originalFrame = simulation.update(
                at: timestamp,
                input: .zero
            )
            let restoredFrame = restored.update(
                at: restoredTimestamp,
                input: .zero
            )
            XCTAssertEqual(
                originalFrame.trainingGuidebot,
                restoredFrame.trainingGuidebot
            )
            XCTAssertEqual(simulation.continuation, restored.continuation)
            XCTAssertEqual(
                restored.level.objects.first {
                    $0.instanceName == "GuideBotB"
                }?.location,
                .room(playerRoomSourceIndex)
            )
        }
        let finalGuidebot = try XCTUnwrap(restored.update(
            at: restoredTimestamp + 0.1,
            input: .zero
        ).trainingGuidebot)
        let finalPosition = finalGuidebot.position
        let finalDelta = Vector3(
            x: finalPosition.x - player.position.x,
            y: finalPosition.y - player.position.y,
            z: finalPosition.z - player.position.z
        )
        let forwardTravel =
            finalDelta.x * player.orientation.forward.x
                + finalDelta.y * player.orientation.forward.y
                + finalDelta.z * player.orientation.forward.z
        XCTAssertGreaterThan(forwardTravel, 30)
        XCTAssertEqual(
            try guidebotRoutePointIndex(in: restored.continuation),
            finalGuidebot.route.points.count - 1
        )
        XCTAssertNotEqual(finalGuidebot.activeSteeringMode, .direct)
    }

    func testContinuationRejectsGuidebotAndProjectileOutsideRecordedRooms() throws {
        let level = makeTrainingGuidebotBlockedMovementLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = simulation.update(at: 0.100_1, input: .zero)
        _ = simulation.update(
            at: 0.100_2,
            input: .init(firesPrimaryWeapon: true)
        )
        let continuationData = try JSONEncoder().encode(
            simulation.continuation
        )
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: continuationData
        )
        XCTAssertNoThrow(
            try PlayerSimulation(
                level: level,
                continuation: continuation,
                resumedAtTimestamp: 100
            )
        )

        for mutation in ["guidebot", "projectile"] {
            var hostileObject = try XCTUnwrap(
                JSONSerialization.jsonObject(with: continuationData)
                    as? [String: Any]
            )
            var hostileState = try XCTUnwrap(
                hostileObject["trainingRobotGuidebotState"]
                    as? [String: Any]
            )
            let outsidePosition: [String: Any] = [
                "x": 1_000_000,
                "y": 1_000_000,
                "z": 1_000_000,
            ]
            if mutation == "guidebot" {
                var guidebot = try XCTUnwrap(
                    hostileState["guidebot"] as? [String: Any]
                )
                guidebot["position"] = outsidePosition
                hostileState["guidebot"] = guidebot
            } else {
                var projectiles = try XCTUnwrap(
                    hostileState["projectiles"] as? [[String: Any]]
                )
                XCTAssertFalse(projectiles.isEmpty)
                projectiles[0]["position"] = outsidePosition
                hostileState["projectiles"] = projectiles
            }
            hostileObject["trainingRobotGuidebotState"] = hostileState
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
                ),
                mutation
            ) {
                XCTAssertEqual(
                    $0 as? PlayerSimulationContinuationError,
                    .invalidState
                )
            }
        }
    }

    func testFourPrimaryLaserVolleysDestroyTrainingRobotThroughNormalPlay() throws {
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
            presentationReadyTimestamp: 0
        )

        for (timestamp, fires) in [
            (0.1, true),
            (0.35, false),
            (0.36, true),
            (0.61, false),
            (0.62, true),
            (0.87, false),
            (0.88, true),
        ] {
            _ = simulation.update(
                at: timestamp,
                input: .init(firesPrimaryWeapon: fires)
            )
        }

        XCTAssertFalse(simulation.level.objects.contains {
            $0.handle == 4_112
        })
        assertTrainingGalleryBarrier(
            level: simulation.level,
            rendersFaces: false
        )
    }

    func testF4BirthCopiesLivePlayerAndMovesGuidebotOnReachedGoal() throws {
        let level = makeTrainingRobotGuidebotLevel()
        let player = try XCTUnwrap(level.objects.first { $0.handle == 2_048 })
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        let guidebot = try XCTUnwrap(frame.trainingGuidebot)

        XCTAssertEqual(guidebot.spawnPosition, player.position)
        XCTAssertEqual(guidebot.orientation, player.orientation)
        XCTAssertEqual(guidebot.spawnVelocity, Vector3(
            x: player.orientation.forward.x * 40,
            y: player.orientation.forward.y * 40,
            z: player.orientation.forward.z * 40
        ))
        XCTAssertEqual(guidebot.destination, Vector3(
            x: player.position.x + player.orientation.forward.x * 200,
            y: player.position.y + player.orientation.forward.y * 200,
            z: player.position.z + player.orientation.forward.z * 200
        ))
        XCTAssertEqual(guidebot.route.mode, .direct)
        XCTAssertEqual(guidebot.activeSteeringMode, .direct)
        XCTAssertNotEqual(guidebot.spawnPosition, guidebot.position)

        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
        )
        XCTAssertEqual(
            continuation,
            simulation.continuation
        )
    }

    func testGuidebotBirthPreservesInheritedSpeedAndGoalCompletionDecelerates() throws {
        var level = makeTrainingRobotGuidebotLevel()
        let safeRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 1 }
        )
        let safeRoom = level.rooms[safeRoomIndex]
        let safeCenter = safeRoom.pathPoint
        level.rooms[safeRoomIndex] = addingSourceContainmentShell(
            to: .init(
                sourceIndex: safeRoom.sourceIndex,
                name: safeRoom.name,
                pathPoint: safeCenter,
                vertices: [],
                faces: [],
                portals: []
            ),
            center: safeCenter,
            texture: level.surfacePhysics[0].texture,
            halfExtent: 500
        )
        let playerIndex = try XCTUnwrap(
            level.objects.firstIndex { $0.handle == 2_048 }
        )
        level.objects[playerIndex].location = .room(1)
        level.objects[playerIndex].position = safeCenter
        let chain = try XCTUnwrap(level.trainingRobotGuidebotChain)
        let inheritedSimulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var inheritedPlayerSpeed: Float = 0
        for frameIndex in 1...20 {
            let frame = inheritedSimulation.update(
                at: Double(frameIndex) * 0.1,
                input: .init(forward: 1)
            )
            inheritedPlayerSpeed = sqrt(
                frame.velocity.x * frame.velocity.x
                    + frame.velocity.y * frame.velocity.y
                    + frame.velocity.z * frame.velocity.z
            )
        }
        XCTAssertGreaterThan(inheritedPlayerSpeed, 20)
        let inheritedFrame = inheritedSimulation.update(
            at: 2.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        let inheritedGuidebot = try XCTUnwrap(
            inheritedFrame.trainingGuidebot
        )
        let inheritedSpeed = sqrt(
            inheritedGuidebot.velocity.x * inheritedGuidebot.velocity.x
                + inheritedGuidebot.velocity.y * inheritedGuidebot.velocity.y
                + inheritedGuidebot.velocity.z * inheritedGuidebot.velocity.z
        )
        XCTAssertEqual(
            inheritedSpeed,
            inheritedPlayerSpeed
                + chain.guidebot.birthForwardVelocity
                - chain.guidebot.maximumDeltaVelocity * 0.1,
            accuracy: Float(0.000_1)
        )

        let shortGoalLevel = replacing(
            level,
            trainingRobotGuidebotChain: .init(
                destroyRobotObjectHandle: chain.destroyRobotObjectHandle,
                guidebotObjectHandle: chain.guidebotObjectHandle,
                destroyRobotRoomSourceIndex:
                    chain.destroyRobotRoomSourceIndex,
                destroyRobotFlags: chain.destroyRobotFlags,
                destructionDelay: chain.destructionDelay,
                destructionMessage: chain.destructionMessage,
                exitInstruction: chain.exitInstruction,
                destructionVoiceSourceName:
                    chain.destructionVoiceSourceName,
                deployedGuidebotObjectType:
                    chain.deployedGuidebotObjectType,
                deployedGuidebotMessage: chain.deployedGuidebotMessage,
                deployedGuidebotVoiceSourceName:
                    chain.deployedGuidebotVoiceSourceName,
                combat: chain.combat,
                guidebot: .init(
                    collisionRadius: chain.guidebot.collisionRadius,
                    maximumVelocity: chain.guidebot.maximumVelocity,
                    maximumDeltaVelocity:
                        chain.guidebot.maximumDeltaVelocity,
                    birthForwardVelocity:
                        chain.guidebot.birthForwardVelocity,
                    goalForwardDistance: 0.5,
                    goalCircleDistance:
                        chain.guidebot.goalCircleDistance
                )
            )
        )
        let completionSimulation = PlayerSimulation(
            level: shortGoalLevel,
            presentationReadyTimestamp: 0
        )
        let completionFrame = completionSimulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        let completionGuidebot = try XCTUnwrap(
            completionFrame.trainingGuidebot
        )
        let completionSpeed = sqrt(
            completionGuidebot.velocity.x * completionGuidebot.velocity.x
                + completionGuidebot.velocity.y
                    * completionGuidebot.velocity.y
                + completionGuidebot.velocity.z
                    * completionGuidebot.velocity.z
        )
        XCTAssertEqual(
            completionSpeed,
            Float(20.000_002),
            accuracy: Float(0.000_1)
        )
        XCTAssertEqual(completionGuidebot.activeSteeringMode, .stopped)
    }

    func testDeployedGuidebotContinuationRestoresPresentationWithoutRepeatingScript060() throws {
        let level = makeTrainingRobotGuidebotLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var galleryTimestamp = 0.0
        for frameIndex in 1...20 {
            galleryTimestamp = Double(frameIndex) * 0.1
            let frame = simulation.update(
                at: galleryTimestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                break
            }
        }
        let deployed = simulation.update(
            at: galleryTimestamp + 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertNotNil(deployed.trainingGuidebot)
        var continuationObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(simulation.continuation)
            ) as? [String: Any]
        )
        let restoredRoomPoint = try XCTUnwrap(
            level.rooms.first { $0.sourceIndex == 3 }
        ).pathPoint
        var restorationLevel = level
        let restoredRoomIndex = try XCTUnwrap(
            restorationLevel.rooms.firstIndex { $0.sourceIndex == 3 }
        )
        restorationLevel.rooms[restoredRoomIndex] =
            addingSourceContainmentShell(
                to: restorationLevel.rooms[restoredRoomIndex],
                center: restoredRoomPoint,
                texture: restorationLevel.surfacePhysics[0].texture,
                halfExtent: 500
            )
        continuationObject["playerPosition"] = [
            "x": restoredRoomPoint.x,
            "y": restoredRoomPoint.y,
            "z": restoredRoomPoint.z,
        ]
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: continuationObject)
        )
        for (field, value) in [
            ("roomSourceIndex", 99_999),
            ("routePointIndex", 99_999),
        ] {
            var hostileObject = try XCTUnwrap(
                JSONSerialization.jsonObject(
                    with: JSONEncoder().encode(continuation)
                ) as? [String: Any]
            )
            var hostileState = try XCTUnwrap(
                hostileObject["trainingRobotGuidebotState"]
                    as? [String: Any]
            )
            var hostileGuidebot = try XCTUnwrap(
                hostileState["guidebot"] as? [String: Any]
            )
            hostileGuidebot[field] = value
            hostileState["guidebot"] = hostileGuidebot
            hostileObject["trainingRobotGuidebotState"] = hostileState
            let hostileContinuation = try JSONDecoder().decode(
                PlayerSimulationContinuation.self,
                from: JSONSerialization.data(
                    withJSONObject: hostileObject
                )
            )
            XCTAssertThrowsError(
                try PlayerSimulation(
                    level: restorationLevel,
                    continuation: hostileContinuation,
                    resumedAtTimestamp: 100
                )
            ) {
                XCTAssertEqual(
                    $0 as? PlayerSimulationContinuationError,
                    .invalidState
                )
            }
        }

        let restored = try PlayerSimulation(
            level: restorationLevel,
            continuation: continuation,
            resumedAtTimestamp: 100
        )
        XCTAssertEqual(restored.continuation, continuation)
        let guidebot = try XCTUnwrap(
            restored.level.objects.first { $0.instanceName == "GuideBotB" }
        )
        XCTAssertTrue(restored.level.objectPresentations.contains {
            $0.objectHandle == guidebot.handle
                && $0.primaryModel.sourceName
                    .caseInsensitiveCompare("Buddybot.oof")
                    == .orderedSame
        })
        let resumed = restored.update(at: 100.1, input: .zero)
        XCTAssertNotNil(resumed.trainingGuidebot)
        XCTAssertTrue(resumed.trainingOpeningFeedback.isEmpty)
        XCTAssertEqual(resumed.enabledPlayerControls, .all)
    }

    func testGuidebotRouteContinuationUsesItsClosedBarrierAllocationState() throws {
        var level = makeTrainingRobotGuidebotLevel()
        let chain = try XCTUnwrap(level.trainingRobotGuidebotChain)
        level = replacing(
            level,
            trainingRobotGuidebotChain: .init(
                destroyRobotObjectHandle: chain.destroyRobotObjectHandle,
                guidebotObjectHandle: chain.guidebotObjectHandle,
                destroyRobotRoomSourceIndex:
                    chain.destroyRobotRoomSourceIndex,
                destroyRobotFlags: chain.destroyRobotFlags,
                destructionDelay: chain.destructionDelay,
                destructionMessage: chain.destructionMessage,
                exitInstruction: chain.exitInstruction,
                destructionVoiceSourceName:
                    chain.destructionVoiceSourceName,
                deployedGuidebotObjectType:
                    chain.deployedGuidebotObjectType,
                deployedGuidebotMessage: chain.deployedGuidebotMessage,
                deployedGuidebotVoiceSourceName:
                    chain.deployedGuidebotVoiceSourceName,
                combat: chain.combat,
                guidebot: .init(
                    collisionRadius: chain.guidebot.collisionRadius,
                    maximumVelocity: chain.guidebot.maximumVelocity,
                    maximumDeltaVelocity:
                        chain.guidebot.maximumDeltaVelocity,
                    birthForwardVelocity:
                        chain.guidebot.birthForwardVelocity,
                    goalForwardDistance: 2,
                    goalCircleDistance:
                        chain.guidebot.goalCircleDistance
                )
            )
        )
        let portalCenter = RoomCamera.trainingRoom3.position
        for roomSourceIndex in [2, 3] {
            let roomIndex = try XCTUnwrap(
                level.rooms.firstIndex {
                    $0.sourceIndex == roomSourceIndex
                }
            )
            for vertexIndex in 0..<4 {
                let vertex =
                    level.rooms[roomIndex].vertices[vertexIndex]
                level.rooms[roomIndex].vertices[vertexIndex] = .init(
                    x: portalCenter.x
                        + (vertexIndex == 0 || vertexIndex == 3 ? 20 : -20),
                    y: vertex.y,
                    z: portalCenter.z
                        + (vertexIndex < 2 ? 20 : -20)
                )
            }
        }
        let room2Index = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 2 }
        )
        for vertexIndex in 4..<8 {
            level.rooms[room2Index].vertices[vertexIndex] = .init(
                x: portalCenter.x
                    + (vertexIndex == 4 || vertexIndex == 7 ? 20 : -20),
                y: portalCenter.y + 20,
                z: portalCenter.z
                    + (vertexIndex < 6 ? 20 : -20)
            )
        }
        let room3Index = try XCTUnwrap(
            level.rooms.firstIndex { $0.sourceIndex == 3 }
        )
        for vertexIndex in 12..<16 {
            level.rooms[room3Index].vertices[vertexIndex] = .init(
                x: portalCenter.x
                    + (vertexIndex == 12 || vertexIndex == 15 ? 20 : -20),
                y: portalCenter.y - 20,
                z: portalCenter.z
                    + (vertexIndex < 14 ? 20 : -20)
            )
        }
        let gallerySimulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        var galleryTimestamp = 0.0
        for frameIndex in 1...20 {
            galleryTimestamp = Double(frameIndex) * 0.1
            let frame = gallerySimulation.update(
                at: galleryTimestamp,
                input: .init(forward: 1)
            )
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                break
            }
        }
        var reversedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(gallerySimulation.continuation)
            ) as? [String: Any]
        )
        reversedObject["playerOrientation"] = [
            "right": ["x": -1, "y": 0, "z": 0],
            "up": ["x": 0, "y": 0, "z": 1],
            "forward": ["x": 0, "y": 1, "z": 0],
        ]
        reversedObject["playerPosition"] = [
            "x": portalCenter.x,
            "y": portalCenter.y + 1.5,
            "z": portalCenter.z,
        ]
        reversedObject["velocity"] = ["x": 0, "y": 0, "z": 0]
        let reversedContinuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONSerialization.data(withJSONObject: reversedObject)
        )
        let simulation = try PlayerSimulation(
            level: level,
            continuation: reversedContinuation,
            resumedAtTimestamp: 100
        )
        let deployed = simulation.update(
            at: 100.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertNotNil(deployed.trainingGuidebot?.routeFailure)
        simulation.destroyTrainingRobot(handle: 4_112)
        let continuation = try JSONDecoder().decode(
            PlayerSimulationContinuation.self,
            from: JSONEncoder().encode(simulation.continuation)
        )

        XCTAssertNoThrow(
            try PlayerSimulation(
                level: level,
                continuation: continuation,
                resumedAtTimestamp: 200
            )
        )
    }

    func testTrainingGalleryTriggerRequiresPlayerCenterPassThrough() {
        let level = makeTrainingGalleryBarrierLevel()
        let barrier = level.trainingGalleryBarrier!
        let room = level.rooms.first {
            $0.sourceIndex == barrier.triggerRoomSourceIndex
        }!
        let face = room.faces[barrier.triggerFaceIndex]
        let faceCenter = face.corners.reduce(Vector3.zero) {
            let vertex = room.vertices[$1.vertexIndex]
            return Vector3(
                x: $0.x + vertex.x,
                y: $0.y + vertex.y,
                z: $0.z + vertex.z
            )
        }
        let divisor = Float(face.corners.count)
        let center = Vector3(
            x: faceCenter.x / divisor,
            y: faceCenter.y / divisor,
            z: faceCenter.z / divisor
        )
        let normal = canonicalFaceNormal(room: room, face: face)!
        let radius: Float = 1
        let start = Vector3(
            x: center.x + normal.x * 2,
            y: center.y + normal.y * 2,
            z: center.z + normal.z * 2
        )
        let sphereOverlap = traceIndoorMovement(
            in: level,
            startRoom: room.sourceIndex,
            start: start,
            end: .init(
                x: center.x + normal.x * 0.5,
                y: center.y + normal.y * 0.5,
                z: center.z + normal.z * 0.5
            ),
            radius: radius
        )
        XCTAssertFalse(sphereOverlap.passedPortalFaces.contains {
            $0.roomSourceIndex == barrier.triggerRoomSourceIndex
                && $0.faceIndex == barrier.triggerFaceIndex
        })

        let centerCrossing = traceIndoorMovement(
            in: level,
            startRoom: room.sourceIndex,
            start: start,
            end: .init(
                x: center.x - normal.x * 0.5,
                y: center.y - normal.y * 0.5,
                z: center.z - normal.z * 0.5
            ),
            radius: radius
        )
        XCTAssertTrue(centerCrossing.passedPortalFaces.contains {
            $0.roomSourceIndex == barrier.triggerRoomSourceIndex
                && $0.faceIndex == barrier.triggerFaceIndex
        })
    }

    @MainActor
    func testTrainingGalleryAudioFailureStillPresentsHUD() {
        var presentedActions: [String] = []
        RevivalGameplayView.presentTrainingFeedback(
            voicePrecedesHUDMessages: true,
            attemptVoice: {
                presentedActions.append("voice")
                throw NSError(domain: "TrainingVoiceTest", code: 1)
            },
            presentHUDMessages: {
                presentedActions.append("hud")
            }
        )
        XCTAssertEqual(presentedActions, ["voice", "hud"])

        let sameFrameReturn: [TrainingOpeningFeedback] = [
            .init(
                hudMessages: ["GB: Returning to ship."],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: "GBotAcceptOrder.wav"
            ),
            .init(
                hudMessages: ["GB: Entering ship!"],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true
            ),
            .init(
                hudMessages: ["Excellent!"],
                voiceSourceName: "proceed6.osf",
                voicePrecedesHUDMessages: true
            ),
        ]
        var orderedPresentation: [String] = []
        RevivalGameplayView.presentTrainingFeedbackSequence(
            sameFrameReturn,
            attemptVoice: {
                orderedPresentation.append("voice:\($0)")
            },
            attemptSound: {
                orderedPresentation.append("sound:\($0)")
            },
            presentHUDMessages: {
                orderedPresentation.append(
                    "hud:\($0.joined(separator: "|"))"
                )
            }
        )
        XCTAssertEqual(orderedPresentation, [
            "sound:GBotAcceptOrder.wav",
            "hud:GB: Returning to ship.",
            "hud:GB: Entering ship!",
            "voice:proceed6.osf",
            "hud:Excellent!",
        ])
    }

    @MainActor
    func testTrainingFeedbackSequenceAttemptsOnlyFinalStreamingVoice() {
        let feedback: [TrainingOpeningFeedback] = [
            .init(
                hudMessages: ["first"],
                voiceSourceName: "return1.osf",
                voicePrecedesHUDMessages: true,
                soundSourceName: "first.wav"
            ),
            .init(
                hudMessages: ["second"],
                voiceSourceName: "welcome.osf",
                voicePrecedesHUDMessages: true,
                soundSourceName: "second.wav"
            ),
            .init(
                hudMessages: ["third"],
                voiceSourceName: "",
                voicePrecedesHUDMessages: true,
                soundSourceName: "third.wav"
            ),
        ]
        var presentation: [String] = []

        RevivalGameplayView.presentTrainingFeedbackSequence(
            feedback,
            attemptVoice: {
                presentation.append("voice:\($0)")
            },
            attemptSound: {
                presentation.append("sound:\($0)")
            },
            presentHUDMessages: {
                presentation.append("hud:\($0.joined(separator: "|"))")
            }
        )

        XCTAssertEqual(presentation, [
            "sound:first.wav",
            "hud:first",
            "voice:welcome.osf",
            "sound:second.wav",
            "hud:second",
            "sound:third.wav",
            "hud:third",
        ])
    }

    func testIndoorTracePreservesPortalIndexTraversalOrder() {
        let base = makeSelectedRoomRenderLevel()
        let texture = base.surfacePhysics[0].texture
        let vertices = [
            Vector3(x: -10, y: 1, z: -10),
            Vector3(x: 10, y: 1, z: -10),
            Vector3(x: 10, y: 1, z: 10),
            Vector3(x: -10, y: 1, z: 10),
            Vector3(x: 1, y: -10, z: -10),
            Vector3(x: 1, y: -10, z: 10),
            Vector3(x: 1, y: 10, z: 10),
            Vector3(x: 1, y: 10, z: -10),
        ]
        func portalFace(
            vertexIndices: [Int],
            portalIndex: Int
        ) -> LevelFace {
            .init(
                corners: vertexIndices.map {
                    .init(vertexIndex: $0, u: 0, v: 0, alpha: 255)
                },
                flags: 0,
                portalIndex: portalIndex,
                texture: texture
            )
        }
        let sourceRoom = LevelRoom(
            sourceIndex: 100,
            vertices: vertices,
            faces: [
                portalFace(vertexIndices: [0, 1, 2, 3], portalIndex: 0),
                portalFace(vertexIndices: [4, 5, 6, 7], portalIndex: 1),
            ],
            portals: [
                .init(
                    faceIndex: 0,
                    connectedRoom: 101,
                    connectedPortal: 0
                ),
                .init(
                    faceIndex: 1,
                    connectedRoom: 102,
                    connectedPortal: 0
                ),
            ]
        )
        let tracedLevel = replacing(
            base,
            rooms: [
                sourceRoom,
                LevelRoom(
                    sourceIndex: 101,
                    vertices: [],
                    faces: [],
                    portals: []
                ),
                LevelRoom(
                    sourceIndex: 102,
                    vertices: [],
                    faces: [],
                    portals: []
                ),
            ]
        )
        let trace = traceIndoorMovement(
            in: tracedLevel,
            startRoom: sourceRoom.sourceIndex,
            start: .zero,
            end: .init(x: 4, y: 2, z: 0),
            radius: 0
        )

        XCTAssertEqual(
            Array(trace.visitedRoomSourceIndices.prefix(3)),
            [100, 101, 102]
        )
    }

    func testAfterburnerInputBypassesRampCombinesCarriersAndClearsInactiveGameplay() {
        var input = PlayerInputState(rampDuration: 0.5)
        input.setHeld(.init(forward: 1, afterburner: 1))
        input.setController(.init(afterburner: 0.75))

        let first = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(first.forward, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(first.afterburner, 1)

        input.setGameplayActive(false, simulation: nil, at: 1)
        XCTAssertEqual(input.snapshot(frameDuration: 0.1), .zero)

        XCTAssertEqual(
            RevivalGameplayView.heldInput(for: [], afterburner: true),
            .init(afterburner: 1)
        )
        XCTAssertEqual(
            RevivalGameplayView.controllerInput(
                leftX: 0,
                leftY: 0,
                rightX: 0,
                rightY: 0,
                leftTrigger: 0,
                rightTrigger: 0,
                leftShoulder: 0,
                rightShoulder: 0,
                afterburner: 0.6
            ),
            .init(afterburner: 0.6)
        )
    }

    func testInputSnapshotRampsHeldAxesAndClearsInactiveGameplay() {
        var ramp = PlayerInputRamp(rampDuration: 0.5)

        let first = ramp.snapshot(
            held: .init(forward: 1, sideways: -1),
            frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(first.forward, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(first.sideways, -0.2, accuracy: 0.000_001)
        XCTAssertEqual(first.vertical, 0)
        XCTAssertEqual(first.pitch, 0)
        XCTAssertEqual(first.yaw, 0)
        XCTAssertEqual(first.roll, 0)

        let second = ramp.snapshot(
            held: .init(forward: 1, sideways: -1),
            frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(second.forward, 0.4, accuracy: 0.000_001)
        XCTAssertEqual(second.sideways, -0.4, accuracy: 0.000_001)

        let released = ramp.snapshot(
            held: .zero,
            frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(released, .zero)
        let restarted = ramp.snapshot(
            held: .init(forward: 1),
            frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(restarted.forward, 0.2, accuracy: 0.000_001)
        let reversed = ramp.snapshot(
            held: .init(forward: -1),
            frameDuration: 0.1,
            gameplayIsActive: true
        )
        XCTAssertEqual(reversed.forward, -0.4, accuracy: 0.000_001)

        XCTAssertEqual(
            ramp.snapshot(
                held: .init(forward: 1, sideways: 1),
                frameDuration: 0.1,
                gameplayIsActive: false
            ),
            .zero
        )
        XCTAssertEqual(
            ramp.snapshot(
                held: .zero,
                frameDuration: 0.1,
                gameplayIsActive: true
            ),
            .zero
        )

        var immediate = PlayerInputRamp(rampDuration: 0)
        XCTAssertEqual(
            immediate.snapshot(
                held: .init(forward: -0.01, sideways: 0.25),
                frameDuration: 0,
                gameplayIsActive: true
            ),
            .init(forward: -1, sideways: 1)
        )
    }

    func testPlayerInputStateCombinesKeyboardControllerAndOneShotMousePerAxis() {
        var input = PlayerInputState(rampDuration: 0.35)
        input.setHeld(
            .init(
                forward: 1,
                sideways: -1,
                vertical: 1,
                pitch: -1,
                yaw: 1,
                roll: -1
            )
        )
        input.setController(
            .init(
                forward: 0.2,
                sideways: 0.1,
                vertical: 0.3,
                pitch: 0.2,
                yaw: 0.4,
                roll: 0.1
            )
        )
        input.accumulateMouseDelta(x: 10, y: -5)

        let first = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(first.forward, 0.485_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.sideways, -0.185_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.vertical, 0.585_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.pitch, -0.080_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.yaw, 0.695_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.roll, -0.185_714_3, accuracy: 0.000_001)
        XCTAssertEqual(first.directLookPitchRadians, 0)
        XCTAssertEqual(first.directLookYawRadians, 0)

        let second = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(second.pitch, -0.371_428_6, accuracy: 0.000_001)
        XCTAssertEqual(second.yaw, 0.971_428_6, accuracy: 0.000_001)

        input.mouseLookEnabled = true
        input.accumulateMouseDelta(x: 10, y: -5)
        let mouseLook = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(mouseLook.pitch, -0.657_142_9, accuracy: 0.000_001)
        XCTAssertEqual(mouseLook.yaw, 1, accuracy: 0.000_001)
        XCTAssertEqual(
            mouseLook.directLookPitchRadians,
            Float.pi / 1_000,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            mouseLook.directLookYawRadians,
            Float.pi / 500,
            accuracy: 0.000_001
        )
        let drained = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(drained.directLookPitchRadians, 0)
        XCTAssertEqual(drained.directLookYawRadians, 0)
    }

    func testPlayerInputStateClearsAndRebasesAcrossFocusChanges() {
        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 10
        )
        var input = PlayerInputState(rampDuration: 0.5)
        input.setHeld(.init(forward: 1))
        input.setController(.init(sideways: 0.75, roll: -0.5))
        input.accumulateMouseDelta(x: 25, y: -10)
        XCTAssertEqual(
            input.snapshot(frameDuration: 0.1).forward,
            0.2,
            accuracy: 0.000_001
        )

        input.setGameplayActive(false, simulation: simulation, at: 10)
        input.setGameplayActive(false, simulation: simulation, at: 15)
        input.setHeld(.init(forward: 1))
        XCTAssertFalse(input.gameplayIsActive)
        XCTAssertEqual(input.snapshot(frameDuration: 0.1), .zero)

        input.setGameplayActive(true, simulation: simulation, at: 20)
        input.setHeld(.init(forward: 1))
        XCTAssertTrue(input.gameplayIsActive)
        let resumed = input.snapshot(frameDuration: 0.1)
        XCTAssertEqual(resumed.forward, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(resumed.sideways, 0)
        XCTAssertEqual(resumed.roll, 0)
        XCTAssertEqual(resumed.pitch, 0)
        XCTAssertEqual(resumed.yaw, 0)
        XCTAssertEqual(
            simulation.update(at: 20.016, input: .zero).storedFrameDuration,
            0.016,
            accuracy: 0.000_001
        )
    }

    func testConcreteAppKitOwnerMapsSixAxesAndSourceControllerDeadzone() {
        XCTAssertEqual(
            RevivalGameplayView.heldInput(
                for: [13, 0, 15, 126, 124, 12]
            ),
            .init(
                forward: 1,
                sideways: -1,
                vertical: 1,
                pitch: -1,
                yaw: 1,
                roll: 1
            )
        )
        XCTAssertEqual(
            RevivalGameplayView.heldInput(
                for: [13, 1, 0, 2, 15, 3, 126, 125, 123, 124, 12, 14]
            ),
            .zero
        )

        let controller = RevivalGameplayView.controllerInput(
            leftX: 0.6,
            leftY: 0.7,
            rightX: 0.4,
            rightY: 0.6,
            leftTrigger: 0.2,
            rightTrigger: 0.6,
            leftShoulder: 1,
            rightShoulder: 0
        )
        XCTAssertEqual(controller.forward, 0.625, accuracy: 0.000_001)
        XCTAssertEqual(controller.sideways, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(controller.vertical, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(controller.pitch, -0.5, accuracy: 0.000_001)
        XCTAssertEqual(controller.yaw, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(controller.roll, 1, accuracy: 0.000_001)
    }

    func testF4RequestsGuidebotDeploymentOnlyDuringGameplay() {
        XCTAssertTrue(
            RevivalGameplayView.requestsGuidebotDeployment(
                keyCode: 118,
                gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsGuidebotDeployment(
                keyCode: 118,
                gameplayIsActive: false
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsGuidebotDeployment(
                keyCode: 117,
                gameplayIsActive: true
            )
        )
        var playerInput = PlayerInputState(rampDuration: 0)
        playerInput.requestGuidebotDeployment()
        XCTAssertTrue(
            playerInput.snapshot(frameDuration: 0.1)
                .deploysTrainingGuidebot
        )
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1)
                .deploysTrainingGuidebot
        )
    }

    func testBackslashRequestsOneInventoryUseOnlyDuringGameplay() {
        XCTAssertTrue(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 42,
                isRepeat: false,
                gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 42,
                isRepeat: true,
                gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 42,
                isRepeat: false,
                gameplayIsActive: false
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsInventoryUse(
                keyCode: 43,
                isRepeat: false,
                gameplayIsActive: true
            )
        )
    }

    func testCameraMonitorPopupBorderAndReachedSoundUseAppKitOwner() throws {
        let frame = RevivalGameplayView.cameraMonitorFrame(
            drawableWidth: 1_200,
            drawableHeight: 900
        )
        XCTAssertEqual(frame.origin.x, 59.375)
        XCTAssertEqual(frame.origin.y, 9.375)
        XCTAssertEqual(frame.width, 281.25)
        XCTAssertEqual(frame.height, 281.25)

        let clip = try XCTUnwrap(
            makeTrainingCameraMonitorLevel().soundClips.first
        )
        let wave = RevivalGameplayView.waveData(for: clip)
        XCTAssertEqual(String(data: wave.prefix(4), encoding: .utf8), "RIFF")
        XCTAssertEqual(wave.count, clip.pcm16LittleEndian.count + 44)
    }

    func testInventoryUseRequestIsOneShotAndClearsWhileGameplayIsInactive() {
        var input = PlayerInputState(rampDuration: 0)
        input.requestInventoryUse()
        XCTAssertTrue(input.snapshot(frameDuration: 0.1).usesInventory)
        XCTAssertFalse(input.snapshot(frameDuration: 0.1).usesInventory)

        input.setGameplayActive(false, simulation: nil, at: 1)
        input.requestInventoryUse()
        XCTAssertFalse(input.snapshot(frameDuration: 0.1).usesInventory)
    }

    func testPrimaryFireRequestIsOneShotAndClearsOutsideGameplay() {
        var playerInput = PlayerInputState(rampDuration: 0)
        playerInput.requestPrimaryFire()
        XCTAssertTrue(
            playerInput.snapshot(frameDuration: 0.1)
                .firesPrimaryWeapon
        )
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1)
                .firesPrimaryWeapon
        )

        playerInput.setGameplayActive(
            false,
            simulation: nil,
            at: 1
        )
        playerInput.requestPrimaryFire()
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1)
                .firesPrimaryWeapon
        )
    }

    func testPlayerSimulationPreservesPriorFrameTimingAndNestedPauseRebasing() {
        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 10
        )

        let first = simulation.update(at: 10.016, input: .zero)
        XCTAssertEqual(first.systemsFrameDuration, 0.1, accuracy: 0.000_001)
        XCTAssertEqual(first.systemsGameTime, 0, accuracy: 0.000_001)
        XCTAssertEqual(first.storedFrameDuration, 0.016, accuracy: 0.000_001)
        XCTAssertEqual(first.gameTime, 0.016, accuracy: 0.000_001)

        let second = simulation.update(at: 10.05, input: .zero)
        XCTAssertEqual(second.systemsFrameDuration, 0.016, accuracy: 0.000_001)
        XCTAssertEqual(second.systemsGameTime, 0.016, accuracy: 0.000_001)
        XCTAssertEqual(second.storedFrameDuration, 0.034, accuracy: 0.000_001)
        XCTAssertEqual(second.gameTime, 0.05, accuracy: 0.000_001)

        simulation.stopTime(at: 10.06)
        simulation.stopTime(at: 10.07)
        simulation.startTime(at: 11)
        simulation.startTime(at: 12)
        let resumed = simulation.update(at: 12.04, input: .zero)
        XCTAssertEqual(resumed.storedFrameDuration, 0.05, accuracy: 0.000_001)
        XCTAssertEqual(resumed.gameTime, 0.1, accuracy: 0.000_001)
    }

    func testVariableDeltaDecisionMatchesBoundedFixedCadenceReferenceTrace() {
        func run(measuredDeltas: [Double]) -> PlayerSimulationFrame {
            let simulation = PlayerSimulation(
                level: makeSliceSixObjectRenderLevel(),
                presentationReadyTimestamp: 0
            )
            var timestamp = 0.0
            var frame: PlayerSimulationFrame?
            for measuredDelta in measuredDeltas {
                timestamp += measuredDelta
                frame = simulation.update(
                    at: timestamp,
                    input: .init(forward: 1)
                )
            }
            return frame!
        }

        // Both traces consume exactly 0.25 seconds of old-delta systems time:
        // the historical 0.1 first duration plus all measured deltas except the
        // final stored duration. The 120 Hz trace is a bounded research
        // comparison, not a second production mode.
        let variable = run(measuredDeltas: [0.018, 0.044, 0.031, 0.057, 0.016])
        let fixed = run(
            measuredDeltas: Array(repeating: 1.0 / 120.0, count: 19)
        )
        XCTAssertEqual(variable.velocity.z, fixed.velocity.z, accuracy: 0.000_01)
        XCTAssertEqual(
            variable.playerView.camera.position.z,
            fixed.playerView.camera.position.z,
            accuracy: 0.000_3
        )
        XCTAssertEqual(variable.playerView.roomSourceIndex, fixed.playerView.roomSourceIndex)
        XCTAssertEqual(variable.wallContact, fixed.wallContact)
    }

    func testSelectedVariableDeltaKeepsReachedCarrierCollisionBoostAndWiggleWithinCadenceTolerances() throws {
        let jitter = [0.018, 0.044, 0.031, 0.057, 0.016]
        let cadence120 = Array(repeating: 1.0 / 120.0, count: 19)

        func runCarrierCollision(
            measuredDeltas: [Double]
        ) -> (
            frame: PlayerSimulationFrame,
            input: InputSnapshot,
            firstContact: IndoorWallContact?
        ) {
            let base = makeSliceSixObjectRenderLevel()
            let clearance = defaultPlayerView(in: base).collisionRadius + 0.5
            let simulation = PlayerSimulation(
                level: makeSliceTenContactLevel(clearance: clearance),
                presentationReadyTimestamp: 0
            )
            var inputState = PlayerInputState()
            inputState.setHeld(.init(forward: 1, sideways: 1))
            var timestamp = 0.0
            var frame: PlayerSimulationFrame?
            var input = InputSnapshot.zero
            var firstContact: IndoorWallContact?
            for measuredDelta in measuredDeltas {
                input = inputState.snapshot(
                    frameDuration: simulation.frameDuration
                )
                timestamp += measuredDelta
                frame = simulation.update(at: timestamp, input: input)
                if firstContact == nil {
                    firstContact = frame?.wallContact
                }
            }
            return (frame!, input, firstContact)
        }

        let variableCarrier = runCarrierCollision(measuredDeltas: jitter)
        let fixedCarrier = runCarrierCollision(measuredDeltas: cadence120)
        XCTAssertEqual(
            variableCarrier.input.forward,
            fixedCarrier.input.forward,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            variableCarrier.input.sideways,
            fixedCarrier.input.sideways,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            variableCarrier.frame.playerView.roomSourceIndex,
            fixedCarrier.frame.playerView.roomSourceIndex
        )
        XCTAssertEqual(
            try XCTUnwrap(variableCarrier.firstContact).roomSourceIndex,
            try XCTUnwrap(fixedCarrier.firstContact).roomSourceIndex
        )
        XCTAssertEqual(
            try XCTUnwrap(variableCarrier.firstContact).faceIndex,
            try XCTUnwrap(fixedCarrier.firstContact).faceIndex
        )
        XCTAssertEqual(
            variableCarrier.frame.velocity.x,
            fixedCarrier.frame.velocity.x,
            accuracy: 2.6
        )
        XCTAssertEqual(
            variableCarrier.frame.playerView.camera.position.x,
            fixedCarrier.frame.playerView.camera.position.x,
            accuracy: 0.24
        )

        func runBoostAndWiggle(
            level: Level,
            measuredDeltas: [Double],
            input: InputSnapshot
        ) -> (frame: PlayerSimulationFrame, fuel: Float, falloff: Float) {
            let simulation = PlayerSimulation(
                level: level,
                presentationReadyTimestamp: 0
            )
            simulation.setIndoorAutoLevelMode(.off)
            var timestamp = 0.0
            var frame: PlayerSimulationFrame?
            for measuredDelta in measuredDeltas {
                timestamp += measuredDelta
                frame = simulation.update(at: timestamp, input: input)
            }
            return (
                frame!,
                simulation.afterburnerFuel,
                simulation.wiggleFalloff
            )
        }

        let variableBoost = runBoostAndWiggle(
            level: makeSliceThirteenWiggleLevel(),
            measuredDeltas: jitter,
            input: .init(afterburner: 1)
        )
        let fixedBoost = runBoostAndWiggle(
            level: makeSliceThirteenWiggleLevel(),
            measuredDeltas: cadence120,
            input: .init(afterburner: 1)
        )
        XCTAssertEqual(variableBoost.fuel, fixedBoost.fuel, accuracy: 0.000_004)
        XCTAssertEqual(variableBoost.falloff, fixedBoost.falloff, accuracy: 0.000_001)
        XCTAssertEqual(
            variableBoost.frame.velocity.z,
            fixedBoost.frame.velocity.z,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            variableBoost.frame.playerView.camera.position.z,
            fixedBoost.frame.playerView.camera.position.z,
            accuracy: 0.001_6
        )

        let variablePortal = runBoostAndWiggle(
            level: makeSliceThirteenPortalWiggleLevel(),
            measuredDeltas: jitter,
            input: .zero
        )
        let fixedPortal = runBoostAndWiggle(
            level: makeSliceThirteenPortalWiggleLevel(),
            measuredDeltas: cadence120,
            input: .zero
        )
        XCTAssertEqual(
            variablePortal.frame.playerView.roomSourceIndex,
            fixedPortal.frame.playerView.roomSourceIndex
        )
        XCTAssertEqual(variablePortal.frame.playerView.roomSourceIndex, 99)
    }

    func testPlayerSimulationUsesPyroAnalyticThrustWithoutDiagonalNormalization() {
        let level = makeSliceSixObjectRenderLevel()
        let start = defaultPlayerView(in: level).camera.position
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016,
            input: .init(forward: 1, sideways: 1)
        )

        let decay = exp(-3.0 * 0.1)
        let expectedVelocity = Float(60 * (1 - decay))
        let expectedDisplacement = Float(60 * 0.1 - 20 * (1 - decay))
        XCTAssertEqual(frame.velocity.x, expectedVelocity, accuracy: 0.000_01)
        XCTAssertEqual(frame.velocity.y, 0, accuracy: 0.000_01)
        XCTAssertEqual(frame.velocity.z, expectedVelocity, accuracy: 0.000_01)
        XCTAssertEqual(
            frame.playerView.camera.position.x,
            start.x + expectedDisplacement,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.playerView.camera.position.z,
            start.z + expectedDisplacement,
            accuracy: 0.000_1
        )
    }

    func testPlayerSimulationUsesSampledBasisThenCommitsRotationalFlight() {
        let level = makeSliceSixObjectRenderLevel()
        let start = defaultPlayerView(in: level).camera.position
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016,
            input: .init(vertical: 1, pitch: 0.75, yaw: 1)
        )

        XCTAssertEqual(
            frame.angularVelocity.x,
            12_065.218,
            accuracy: 0.001
        )
        XCTAssertEqual(
            frame.angularVelocity.y,
            16_086.958,
            accuracy: 0.001
        )
        XCTAssertEqual(frame.angularVelocity.z, 0, accuracy: 0.001)
        XCTAssertEqual(frame.turnrollFixedAngle, -800, accuracy: 0.001)

        let camera = frame.playerView.camera
        XCTAssertEqual(
            camera.target.x - camera.position.x,
            0.152_529_84,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            camera.target.y - camera.position.y,
            -0.115_366_35,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            camera.target.z - camera.position.z,
            0.981_542_3,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.playerView.camera.position.x,
            start.x,
            accuracy: 0.000_1
        )
        XCTAssertGreaterThan(frame.playerView.camera.position.y, start.y)
        XCTAssertEqual(
            frame.playerView.camera.position.z,
            start.z,
            accuracy: 0.000_1
        )
    }

    func testPlayerSimulationAppliesIsolatedRollToAngularVelocityAndCameraUp() {
        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        let start = defaultPlayerView(in: simulation.level)

        let frame = simulation.update(
            at: 0.016,
            input: .init(roll: 1)
        )

        XCTAssertGreaterThan(frame.angularVelocity.z, 0)
        XCTAssertNotEqual(frame.playerView.camera.up, start.camera.up)
        XCTAssertEqual(
            frame.playerView.camera.target.x - frame.playerView.camera.position.x,
            start.camera.target.x - start.camera.position.x,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.playerView.camera.target.y - frame.playerView.camera.position.y,
            start.camera.target.y - start.camera.position.y,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            frame.playerView.camera.target.z - frame.playerView.camera.position.z,
            start.camera.target.z - start.camera.position.z,
            accuracy: 0.000_1
        )
    }

    func testIndoorNewPlayerAutolevelCanBeTurnedOffAfterSourceDelay() {
        let active = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        let disabled = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        disabled.setIndoorAutoLevelMode(.off)

        let initialInput = InputSnapshot(directLookPitchRadians: 0.25)
        _ = active.update(at: 0.016, input: initialInput)
        _ = disabled.update(at: 0.016, input: initialInput)

        var activeFrame: PlayerSimulationFrame!
        var disabledFrame: PlayerSimulationFrame!
        for frameIndex in 2...110 {
            let timestamp = Double(frameIndex) * 0.016
            activeFrame = active.update(at: timestamp, input: .zero)
            disabledFrame = disabled.update(at: timestamp, input: .zero)
        }

        let activePitch = abs(
            activeFrame.playerView.camera.target.y
                - activeFrame.playerView.camera.position.y
        )
        let disabledPitch = abs(
            disabledFrame.playerView.camera.target.y
                - disabledFrame.playerView.camera.position.y
        )
        XCTAssertLessThan(activePitch, disabledPitch)
        XCTAssertEqual(disabledPitch, sin(0.25), accuracy: 0.000_1)
    }

    func testPlayerSimulationCommitsContactResponseToSamePlayerAndRoom() throws {
        let simulation = PlayerSimulation(
            level: makeSliceTenContactLevel(),
            presentationReadyTimestamp: 0
        )
        var timestamp = 0.1
        var contactFrame: PlayerSimulationFrame?
        for _ in 0..<100 {
            let frame = simulation.update(
                at: timestamp,
                input: .init(forward: 1)
            )
            timestamp += 0.1
            if frame.wallContact != nil {
                contactFrame = frame
                break
            }
        }

        let frame = try XCTUnwrap(contactFrame)
        let contact = try XCTUnwrap(frame.wallContact)
        let player = try XCTUnwrap(
            simulation.level.objects.first {
                $0.handle == frame.playerView.objectHandle
            }
        )
        XCTAssertEqual(player.position, frame.playerView.camera.position)
        XCTAssertEqual(
            player.location,
            .room(frame.playerView.roomSourceIndex)
        )
        XCTAssertEqual(contact.roomSourceIndex, frame.playerView.roomSourceIndex)
        XCTAssertGreaterThan(
            contact.normal.x * frame.velocity.x
                + contact.normal.y * frame.velocity.y
                + contact.normal.z * frame.velocity.z,
            0
        )
        XCTAssertLessThan(frame.playerView.camera.position.z, 2_310.928)
    }

    func testBaseAfterburnerUsesReleasedBoostFuelAndProjectionState() {
        let boosted = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        let ordinary = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )

        let boostedFrame = boosted.update(
            at: 0.1,
            input: .init(afterburner: 1)
        )
        let ordinaryFrame = ordinary.update(
            at: 0.1,
            input: .init(forward: 1)
        )

        XCTAssertTrue(boosted.afterburnerIsActive)
        XCTAssertEqual(boosted.afterburnerFuel, 4.9, accuracy: 0.000_001)
        XCTAssertEqual(boosted.energy, 100)
        XCTAssertEqual(boosted.afterburnerMagnitude, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(
            boostedFrame.velocity.z,
            ordinaryFrame.velocity.z * 1.6 * 1.8,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            boostedFrame.playerView.camera.projection.horizontalFieldOfViewRadians,
            PerspectiveProjection.sourceDefault.horizontalFieldOfViewRadians
                * (1 + 0.2 * 0.08),
            accuracy: 0.000_001
        )

        var timestamp = 0.2
        while boosted.afterburnerFuel > 0 {
            _ = boosted.update(at: timestamp, input: .init(afterburner: 1))
            timestamp += 0.1
        }
        XCTAssertTrue(boosted.afterburnerIsActive)
        XCTAssertEqual(boosted.afterburnerFuel, 0)

        _ = boosted.update(at: timestamp, input: .init(afterburner: 1))
        XCTAssertFalse(boosted.afterburnerIsActive)
    }

    func testReleasedAfterburnerPunchKeepsStrictFuelBoundaries() {
        func thrustRatio(
            afterburnerFrames: Int
        ) -> Float {
            let simulations = (0..<3).map { _ in
                PlayerSimulation(
                    level: makeSliceSixObjectRenderLevel(),
                    presentationReadyTimestamp: 0
                )
            }
            var timestamp = 0.125
            for simulation in simulations {
                _ = simulation.update(at: timestamp, input: .zero)
            }
            for _ in 0..<afterburnerFrames {
                timestamp += 0.125
                for simulation in simulations {
                    _ = simulation.update(
                        at: timestamp,
                        input: .init(afterburner: 0.000_001)
                    )
                }
            }
            timestamp += 0.125
            let boosted = simulations[0].update(
                at: timestamp,
                input: .init(afterburner: 1)
            )
            let ordinary = simulations[1].update(
                at: timestamp,
                input: .init(forward: 1)
            )
            let coasting = simulations[2].update(
                at: timestamp,
                input: .zero
            )
            return (boosted.velocity.z - coasting.velocity.z)
                / (ordinary.velocity.z - coasting.velocity.z)
        }

        XCTAssertEqual(thrustRatio(afterburnerFrames: 4), 1.6, accuracy: 0.000_01)
        XCTAssertEqual(
            thrustRatio(afterburnerFrames: 6),
            1.6 * 1.4,
            accuracy: 0.000_01
        )
        XCTAssertEqual(thrustRatio(afterburnerFrames: 8), 1.6, accuracy: 0.000_01)
    }

    func testReleasedAfterburnerLinearPunchPreservesDoublePromotion() {
        XCTAssertEqual(
            sourceAfterburnerForwardControl(
                afterburner: 1,
                fuel: 4.400_000_1
            ).bitPattern,
            0x4027_ef9e
        )
        XCTAssertEqual(
            sourceAfterburnerForwardControl(
                afterburner: 1,
                fuel: Float(bitPattern: 0x408a_0003)
            ).bitPattern,
            0x4019_99a9
        )

        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        for frame in 1...6 {
            _ = simulation.update(
                at: Double(frame) * 0.1,
                input: .init(afterburner: 0.000_001)
            )
        }
        let ship = simulation.level.shipDefinitions.first {
            $0.source == simulation.level.defaultPlayerBinding!.ship
        }!
        let fuel = simulation.afterburnerFuel
        let punch = Float(
            1 + ((Double(fuel) - 4) / 0.5) * 0.8
        )
        let forwardControl = Float(1.6 * Double(punch))
        let force = Float(
            Double(ship.physics.fullThrust) * Double(forwardControl)
        )
        let q = Double(force) / Double(ship.physics.drag)
        let decay = exp(
            -(Double(ship.physics.drag) / Double(ship.physics.mass))
                * Double(simulation.frameDuration)
        )
        let expectedVelocity = Float(
            (Double(simulation.velocity.z) - q) * decay + q
        )

        let frame = simulation.update(
            at: 0.7,
            input: .init(afterburner: 1)
        )

        XCTAssertEqual(frame.velocity.z.bitPattern, expectedVelocity.bitPattern)
    }

    func testReleasedNoCoolerRechargeConsumesEnergyAboveThreshold() {
        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )
        var timestamp = 0.1

        _ = simulation.update(at: timestamp, input: .init(afterburner: 1))
        timestamp += 0.1
        _ = simulation.update(at: timestamp, input: .zero)
        timestamp += 0.1
        XCTAssertEqual(simulation.afterburnerFuel, 5, accuracy: 0.000_001)
        XCTAssertEqual(simulation.energy, 99.9, accuracy: 0.000_01)

        while simulation.energy > 5 {
            _ = simulation.update(
                at: timestamp,
                input: .init(afterburner: 1)
            )
            timestamp += 0.1
            _ = simulation.update(at: timestamp, input: .zero)
            timestamp += 0.1
        }
        _ = simulation.update(at: timestamp, input: .init(afterburner: 1))
        timestamp += 0.1
        let depletedFuel = simulation.afterburnerFuel
        let thresholdEnergy = simulation.energy
        _ = simulation.update(at: timestamp, input: .zero)

        XCTAssertLessThan(depletedFuel, 5)
        XCTAssertEqual(simulation.afterburnerFuel, depletedFuel)
        XCTAssertEqual(simulation.energy, thresholdEnergy)
    }

    func testReleasedRechargeConsumesUntrimmedFrameWhenFuelCaps() {
        let simulation = PlayerSimulation(
            level: makeSliceSixObjectRenderLevel(),
            presentationReadyTimestamp: 0
        )

        _ = simulation.update(at: 0.125, input: .zero)
        _ = simulation.update(at: 0.625, input: .init(afterburner: 1))
        XCTAssertEqual(simulation.afterburnerFuel, 4.875)
        _ = simulation.update(at: 1.125, input: .zero)

        XCTAssertEqual(simulation.afterburnerFuel, 5)
        XCTAssertEqual(simulation.energy, 99.5)
    }

    func testPyroWiggleIsSourceQuantizedAuthoritativeMovementWithFalloff() {
        let stationary = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(),
            presentationReadyTimestamp: 0
        )
        let thrusting = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(),
            presentationReadyTimestamp: 0
        )
        let start = defaultPlayerView(in: stationary.level).camera.position

        let stationaryFrame = stationary.update(at: 0.1, input: .zero)
        let thrustingFrame = thrusting.update(
            at: 0.1,
            input: .init(forward: 1)
        )

        XCTAssertEqual(stationary.wiggleFalloff, 0)
        XCTAssertEqual(thrusting.wiggleFalloff, 0.05, accuracy: 0.000_001)
        XCTAssertEqual(
            stationaryFrame.playerView.camera.position.z - start.z,
            0.091_064_45,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            thrustingFrame.playerView.camera.position.z - start.z,
            0.086_425_78,
            accuracy: 0.000_001
        )
    }

    func testPyroWiggleUsesReleasedFloatSineTableQuantization() {
        var level = makeSliceThirteenWiggleLevel()
        var objects = level.objects
        let playerIndex = objects.firstIndex { $0.handle == 2_048 }!
        objects[playerIndex].position = .zero
        level = replacing(level, objects: objects)
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )

        _ = simulation.update(at: 0.1, input: .zero)
        let frame = simulation.update(at: 0.2, input: .zero)

        XCTAssertEqual(
            frame.playerView.camera.position.z.bitPattern,
            0x3e3a_8b68
        )
    }

    func testPyroWiggleUsesPostMouselookPreRotationUpAxis() {
        let simulation = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(),
            presentationReadyTimestamp: 0
        )
        let start = defaultPlayerView(in: simulation.level).camera.position

        let frame = simulation.update(
            at: 0.1,
            input: .init(directLookPitchRadians: .pi / 2)
        )

        XCTAssertLessThan(frame.playerView.camera.position.y, start.y - 0.09)
        XCTAssertEqual(
            frame.playerView.camera.position.z,
            start.z,
            accuracy: 0.000_01
        )
    }

    func testPyroWiggleRetainsTenPercentMovementAtFullFalloff() {
        let simulation = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(),
            presentationReadyTimestamp: 0
        )
        simulation.setIndoorAutoLevelMode(.off)
        var timestamp = 0.1

        for _ in 0..<20 {
            _ = simulation.update(
                at: timestamp,
                input: .init(afterburner: 0.000_02)
            )
            timestamp += 0.1
        }
        let priorPosition = defaultPlayerView(in: simulation.level).camera.position
        let frame = simulation.update(
            at: timestamp,
            input: .init(afterburner: 0.000_02)
        )

        XCTAssertEqual(simulation.wiggleFalloff, 1)
        XCTAssertGreaterThan(
            abs(frame.playerView.camera.position.z - priorPosition.z),
            0.000_1
        )
    }

    func testPyroWiggleCommitsReturnedRoomAfterPortalCrossing() {
        let simulation = PlayerSimulation(
            level: makeSliceThirteenPortalWiggleLevel(),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(at: 0.1, input: .zero)

        XCTAssertEqual(frame.playerView.roomSourceIndex, 99)
        XCTAssertEqual(
            simulation.level.objects.first { $0.handle == 2_048 }!.location,
            .room(99)
        )
    }

    func testPyroWiggleRefusesMovementOnIndoorContact() {
        let open = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(),
            presentationReadyTimestamp: 0
        )
        let blocked = PlayerSimulation(
            level: makeSliceThirteenWiggleLevel(blocked: true),
            presentationReadyTimestamp: 0
        )
        let blockedStart = defaultPlayerView(in: blocked.level).camera.position

        let openFrame = open.update(at: 0.1, input: .zero)
        let blockedFrame = blocked.update(at: 0.1, input: .zero)

        XCTAssertGreaterThan(openFrame.playerView.camera.position.z, blockedStart.z)
        XCTAssertEqual(blockedFrame.playerView.camera.position, blockedStart)
        XCTAssertNil(blockedFrame.wallContact)
    }

    func testPlayerSimulationSlidesAndRetracesRemainingFrameAfterContact() throws {
        let base = makeSliceSixObjectRenderLevel()
        let clearance = defaultPlayerView(in: base).collisionRadius + 0.5
        let simulation = PlayerSimulation(
            level: makeSliceTenContactLevel(clearance: clearance),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016,
            input: .init(forward: 1, sideways: 1)
        )
        let contact = try XCTUnwrap(frame.wallContact)

        XCTAssertGreaterThan(
            frame.playerView.camera.position.x,
            contact.contactPoint.x + 0.1
        )
        XCTAssertLessThanOrEqual(
            frame.playerView.camera.position.z,
            contact.contactPoint.z
                + contact.normal.z * frame.playerView.collisionRadius
        )
        XCTAssertGreaterThan(frame.velocity.x, 0)
        XCTAssertLessThanOrEqual(frame.velocity.z, 0)
        XCTAssertLessThan(abs(frame.velocity.z), frame.velocity.x * 0.03)

        XCTAssertEqual(frame.velocity.x, 15.360_591, accuracy: 0.000_1)
        XCTAssertEqual(frame.velocity.z, -0.015_361_632, accuracy: 0.000_1)
    }

    func testIndoorTraceCombinesTwoExactNearestWallNormals() throws {
        let level = makeSliceElevenCornerLevel(clearance: 20)
        let view = defaultPlayerView(in: level)
        let trace = traceIndoorMovement(
            in: level,
            startRoom: view.roomSourceIndex,
            start: view.camera.position,
            end: Vector3(
                x: view.camera.position.x + 20,
                y: view.camera.position.y,
                z: view.camera.position.z + 20
            ),
            radius: view.collisionRadius
        )

        guard case let .wallHit(contact) = trace.outcome else {
            return XCTFail("Expected the equal-distance corner contact.")
        }
        let component = -Float(1 / sqrt(2.0))
        XCTAssertEqual(contact.normal.x, component, accuracy: 0.000_001)
        XCTAssertEqual(contact.normal.y, 0, accuracy: 0.000_001)
        XCTAssertEqual(contact.normal.z, component, accuracy: 0.000_001)
    }

    func testPlayerSimulationUsesSourceDefaultForceFieldBounce() throws {
        let simulation = PlayerSimulation(
            level: makeSliceElevenForceFieldLevel(clearance: 20),
            presentationReadyTimestamp: 0
        )
        var timestamp = 0.1
        var contactFrame: PlayerSimulationFrame?
        for _ in 0..<100 {
            let frame = simulation.update(
                at: timestamp,
                input: .init(forward: 1)
            )
            timestamp += 0.1
            if frame.wallContact != nil {
                contactFrame = frame
                break
            }
        }

        let frame = try XCTUnwrap(contactFrame)
        let contact = try XCTUnwrap(frame.wallContact)
        let collisionCenterZ = contact.contactPoint.z
            + contact.normal.z * frame.playerView.collisionRadius
        XCTAssertLessThan(frame.playerView.camera.position.z, collisionCenterZ - 1)
        XCTAssertLessThan(frame.velocity.z, -90)
    }

    func testNearImmediateContactUsesReleasedNormalNudge() throws {
        let base = makeSliceSixObjectRenderLevel()
        let clearance = defaultPlayerView(in: base).collisionRadius - 0.0005
        let simulation = PlayerSimulation(
            level: makeSliceTenContactLevel(clearance: clearance),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.016,
            input: .init(forward: 0.001_351)
        )
        let contact = try XCTUnwrap(frame.wallContact)
        let attemptedDistance = Float(
            60 * 0.1 - 20 * (1 - exp(-3.0 * 0.1))
        )
        let movedTime = frame.systemsFrameDuration
            * contact.distance
            / attemptedDistance

        XCTAssertEqual(movedTime, 0, accuracy: 0.000_001)
        let outwardVelocity = contact.normal.x * frame.velocity.x
            + contact.normal.y * frame.velocity.y
            + contact.normal.z * frame.velocity.z
        XCTAssertGreaterThan(outwardVelocity, 0.3)
    }

    func testPlayerSimulationStopsAtReleasedNineContactLimit() throws {
        let base = makeSliceSixObjectRenderLevel()
        let clearance = defaultPlayerView(in: base).collisionRadius - 0.0005
        let simulation = PlayerSimulation(
            level: makeSliceElevenTrappedLevel(clearance: clearance),
            presentationReadyTimestamp: 0
        )

        let frame = simulation.update(
            at: 0.1,
            input: .init(forward: 1)
        )

        XCTAssertNotNil(frame.wallContact)
        XCTAssertEqual(frame.velocity, .zero)
    }

    func testReciprocalPortalComponentIgnoresPresentationPassabilityAndDisconnectedRooms() {
        let level = makeSelectedRoomRenderLevel()
        let disconnected = LevelRoom(
            sourceIndex: 99,
            vertices: [],
            faces: [],
            portals: []
        )

        XCTAssertEqual(
            reciprocalPortalComponent(
                rooms: level.rooms + [disconnected],
                startRoomSourceIndex: 1
            ),
            Set([1, 2, 3, 4])
        )
    }

    func testDefaultPlayerViewDerivesCanonicalPoseRadiusAndExcludesViewer() throws {
        let level = makeSliceSixObjectRenderLevel()
        let view = defaultPlayerView(in: level)

        XCTAssertEqual(view.playerID, 0)
        XCTAssertEqual(view.objectHandle, 2_048)
        XCTAssertEqual(view.roomSourceIndex, 1)
        XCTAssertEqual(
            view.camera.position,
            .init(x: 2_060.6497, y: -131.22517, z: 2_204.4216)
        )
        XCTAssertEqual(
            view.camera.target,
            .init(x: 2_060.6497, y: -131.22517, z: 2_205.4216)
        )
        XCTAssertEqual(view.camera.up, .init(x: 0, y: 1, z: 0))
        XCTAssertEqual(
            view.collisionRadius,
            level.shipDefinitions[0].presentationSize * 0.8
        )

        let extraction = try extractWorldForRendering(level, playerView: view)
        XCTAssertEqual(extraction.admittedObjectHandles, [12_301, 12_300])
        XCTAssertFalse(extraction.admittedObjectHandles.contains(view.objectHandle))

        let plan = try makeMetalWorldPlan(level: level, playerView: view)
        XCTAssertEqual(plan.camera, view.camera)
        XCTAssertGreaterThan(plan.preparedDraws.count, plan.draws.count)
        XCTAssertEqual(
            plan.activeDrawIndices.map { plan.preparedDraws[$0] },
            plan.draws
        )
        XCTAssertFalse(plan.draws.contains { $0.objectHandle == view.objectHandle })
    }

    func testSourceProjectionPreservesVerticalFramingAcrossFullDrawableAspect() {
        let fourByThree = PerspectiveProjection.sourceDefault
        let wide = fourByThree.withAspectRatio(16.0 / 9.0)
        let fourByThreeVerticalScale =
            (1 / tan(fourByThree.horizontalFieldOfViewRadians / 2))
            * fourByThree.aspectRatio
        let wideVerticalScale =
            (1 / tan(wide.horizontalFieldOfViewRadians / 2))
            * wide.aspectRatio
        XCTAssertEqual(
            fourByThree.horizontalFieldOfViewRadians,
            3.14 * 72 / 180,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            wideVerticalScale,
            fourByThreeVerticalScale,
            accuracy: 0.000_001
        )
        XCTAssertLessThan(
            1 / tan(wide.horizontalFieldOfViewRadians / 2),
            1 / tan(fourByThree.horizontalFieldOfViewRadians / 2)
        )

        let portrait = fullDrawableMetalViewport(
            drawableWidth: 1_170,
            drawableHeight: 2_532
        )
        XCTAssertEqual(portrait.originX, 0)
        XCTAssertEqual(portrait.originY, 0)
        XCTAssertEqual(portrait.width, 1_170)
        XCTAssertEqual(portrait.height, 2_532)

        let landscape = fullDrawableMetalViewport(
            drawableWidth: 2_360,
            drawableHeight: 1_640
        )
        XCTAssertEqual(landscape.originX, 0)
        XCTAssertEqual(landscape.originY, 0)
        XCTAssertEqual(landscape.width, 2_360)
        XCTAssertEqual(landscape.height, 1_640)
    }

    func testRoomThreeConvexShellContainmentAcceptsItsBoundaryAndRejectsPastIt() {
        let center = RoomCamera.trainingRoom3.position
        let room = makeSourceContainmentRoom(
            center: center,
            texture: .init(storedIndex: 0, sourceName: "wall")
        )

        XCTAssertTrue(
            sourceRoomThreeContains(
                .init(x: center.x - 0.5, y: center.y, z: center.z),
                in: room
            )
        )
        XCTAssertTrue(
            sourceRoomThreeContains(
                .init(x: center.x, y: center.y + 1, z: center.z),
                in: room
            )
        )
        XCTAssertFalse(
            sourceRoomThreeContains(
                .init(x: center.x, y: center.y + 1.25, z: center.z),
                in: room
            )
        )
    }

    func testEvaluatesTypedCoronaNearCutoffAndRenderedPortalOcclusion() throws {
        let camera = RoomCamera(
            position: .zero,
            target: .init(x: 0, y: 1, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        let visible = try extractWorldForRendering(
            makeCoronaEvaluationLevel(blocked: false),
            camera: camera,
            startRoomSourceIndex: 3
        )
        let corona = try XCTUnwrap(visible.lightCoronas.only)
        XCTAssertEqual(corona.roomSourceIndex, 3)
        XCTAssertEqual(corona.faceIndex, 0)
        XCTAssertEqual(corona.assetIndex, 0)
        XCTAssertEqual(corona.size, 4, accuracy: 0.000_001)
        XCTAssertEqual(corona.center, .init(x: 0, y: 20.75, z: 0))
        XCTAssertEqual(corona.tint, .init(x: 0.25, y: 0.5, z: 0.75))
        XCTAssertEqual(corona.blend, .additiveSourceAlpha(opacity: 102))
        let plan = try makeMetalWorldPlan(
            level: makeCoronaEvaluationLevel(blocked: false),
            camera: camera,
            startRoomSourceIndex: 3
        )
        XCTAssertEqual(plan.preparedLightCoronaCandidates, [corona])
        XCTAssertEqual(
            plan.draws.count,
            visible.opaqueDrawItems.count
                + visible.modelDrawItems.count
                + visible.translucentDrawItems.count
        )

        let nearCamera = RoomCamera(
            position: .init(x: 0, y: 1, z: 0),
            target: .init(x: 0, y: 2, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )
        XCTAssertTrue(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(blocked: false),
                camera: nearCamera,
                startRoomSourceIndex: 3
            ).lightCoronas.isEmpty
        )
        XCTAssertTrue(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(blocked: true),
                camera: camera,
                startRoomSourceIndex: 3
            ).lightCoronas.isEmpty
        )
        XCTAssertTrue(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(objectBlocked: true),
                camera: camera,
                startRoomSourceIndex: 3
            ).lightCoronas.isEmpty
        )
        XCTAssertEqual(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(objectBlocked: true),
                camera: camera,
                startRoomSourceIndex: 3,
                excludedObjectHandle: 99
            ).lightCoronas.count,
            1
        )
    }

    func testHiddenObjectPresentationDoesNotOccludeTypedCorona() throws {
        let camera = RoomCamera(
            position: .zero,
            target: .init(x: 0, y: 1, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )

        XCTAssertEqual(
            try extractWorldForRendering(
                makeCoronaEvaluationLevel(
                    objectBlocked: true,
                    objectPresentationVisible: false
                ),
                camera: camera,
                startRoomSourceIndex: 3
            ).lightCoronas.count,
            1
        )
    }

    func testEvaluatesTypedWaterOnTheSimulationOwnedSixtyHertzVisualTick() throws {
        var base = Data()
        base.reserveCapacity(128 * 128 * 4)
        for y in 0..<128 {
            for x in 0..<128 {
                base.append(UInt8(x))
                base.append(UInt8(y))
                base.append(UInt8(x ^ y))
                base.append(UInt8((x + y) & 0xff))
            }
        }
        var evaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )

        let frame0 = evaluator.rgba8(visualTick: 0)
        XCTAssertEqual(
            evaluator.rgba8(visualTick: 0),
            frame0
        )
        let frame1 = evaluator.rgba8(visualTick: 1)
        var frame15 = frame1
        for frame in 2...15 {
            frame15 = evaluator.rgba8(visualTick: frame)
        }

        XCTAssertEqual(
            canonicalSHA256(frame0),
            "c93b482fca480de0b038229dc4713132eccaa80565d4de49290ad298fb3ff3d3"
        )
        XCTAssertEqual(
            canonicalSHA256(frame1),
            "d3807e29ea90fef543de25265f4340e6c97154bf0ed09885b4ba967b23d1d25d"
        )
        XCTAssertEqual(
            canonicalSHA256(frame15),
            "a6421e077e293fe63fb6d67f6977fdf575028ff946a0f229e3b21d366afbdeb0"
        )

        var boundedSequentialEvaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )
        var boundedSequentialFrame = boundedSequentialEvaluator.rgba8(visualTick: 0)
        for frame in 1...7 {
            boundedSequentialFrame = boundedSequentialEvaluator.rgba8(visualTick: frame)
        }
        var boundedSkippedEvaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )
        _ = boundedSkippedEvaluator.rgba8(visualTick: 0)
        XCTAssertEqual(
            boundedSkippedEvaluator.rgba8(visualTick: 7),
            boundedSequentialFrame
        )

        var skippedEvaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: alienForceFieldWaterDefinition()
        )
        _ = skippedEvaluator.rgba8(visualTick: 0)
        let directlyDemandedFrame15 = skippedEvaluator.rgba8(visualTick: 15)
        XCTAssertEqual(
            canonicalSHA256(directlyDemandedFrame15),
            "314d89786dd2c0ae2917f3fe44d420a469a9eede2a424d7256e6a87beccb2d49"
        )
    }

    func testPreservesSplitGreenShadeTableSemantics() throws {
        var base = Data()
        base.reserveCapacity(128 * 128 * 4)
        for _ in 0..<(128 * 128) {
            base.append(contentsOf: [0, 90, 0, 255])
        }
        var evaluator = WaterProceduralEvaluator(
            image: .init(width: 128, height: 128, rgba8: base),
            definition: .init(
                evaluationIntervalSeconds: 0,
                lightingShift: 0,
                dampingShift: 6,
                elements: [
                    .init(
                        kind: .heightBlob,
                        frequency: 0,
                        speed: 29,
                        size: 1,
                        x1: 64,
                        y1: 64,
                        x2: 0,
                        y2: 0
                    ),
                ]
            )
        )

        let frame0 = evaluator.rgba8(visualTick: 0)

        let discriminatingPixelOffset = (64 * 128 + 65) * 4
        XCTAssertEqual(
            Array(frame0[discriminatingPixelOffset..<(discriminatingPixelOffset + 4)]),
            [0, 0, 0, 255]
        )
        XCTAssertEqual(
            canonicalSHA256(frame0),
            "e5495353fb1b915327813cc39a74d33aebf4484f023039fb485d77a38c9c678b"
        )
    }

    func testTraversesTheTwoAlignedRenderedPortalsAndStopsAtRoomOne() throws {
        let level = makeSelectedRoomRenderLevel()
        let camera = RoomCamera(
            position: .zero,
            target: .init(x: 0, y: 1, z: 0),
            up: .init(x: 0, y: 0, z: 1)
        )

        let extraction = try extractWorldForRendering(
            level,
            camera: camera,
            startRoomSourceIndex: 3
        )

        XCTAssertEqual(extraction.visibleRoomSourceIndices, [3, 2, 1])
        XCTAssertEqual(
            extraction.translucentDrawItems.map {
                "\($0.roomSourceIndex):\($0.faceIndex)"
            },
            ["2:0", "3:0"]
        )
        XCTAssertEqual(
            extraction.opaqueDrawItems.map {
                "\($0.roomSourceIndex):\($0.faceIndex)"
            },
            ["1:1"]
        )
        XCTAssertFalse(
            extraction.opaqueDrawItems.contains {
                $0.roomSourceIndex == 1 && $0.faceIndex == 2
            }
        )
        XCTAssertFalse(
            extraction.portalEdges.contains(where: { $0.roomSourceIndex == 4 })
        )
    }

    func testAdmitsTheFixedSliceSixObjectsAndSelectsTheSourceLOD() throws {
        let level = makeSliceSixObjectRenderLevel()
        try level.validate()

        let extraction = try extractWorldForRendering(
            level,
            camera: .trainingRoom3,
            startRoomSourceIndex: 3
        )

        XCTAssertEqual(
            extraction.admittedObjectHandles,
            [18_441, 2_048, 12_300, 6_147]
        )
        XCTAssertEqual(
            Set(extraction.modelDrawItems.map(\.objectHandle)),
            Set(extraction.admittedObjectHandles)
        )
        XCTAssertEqual(
            Set(
                extraction.modelDrawItems
                    .filter { $0.objectHandle == 2_048 }
                    .map(\.model)
            ),
            [.init(storedIndex: 1, sourceName: "PyroGLMed.OOF")]
        )
        XCTAssertFalse(extraction.admittedObjectHandles.contains(2_052))
        XCTAssertTrue(
            extraction.modelDrawItems.contains {
                $0.objectHandle == 6_147
                    && $0.material == .sourceColor(red: 32, green: 64, blue: 96)
            }
        )
        XCTAssertFalse(extraction.modelDrawItems.contains { $0.submodelIndex == 2 })
        let facing = try XCTUnwrap(
            extraction.modelDrawItems.first {
                $0.objectHandle == 6_147 && $0.submodelIndex == 3
            }
        )
        XCTAssertEqual(
            facing.material,
            .texture(.init(storedIndex: 50, sourceName: "model-surface"))
        )
        XCTAssertEqual(facing.blend, .sourceAlpha(opacity: 255))
        XCTAssertEqual(facing.triangleIndices, [0, 1, 2, 0, 2, 3])
        XCTAssertEqual(facing.vertices.map(\.u), [0, 1, 1, 0])
        XCTAssertEqual(facing.vertices.map(\.v), [0, 0, 1, 1])
        let expectedFacingPositions = [
            Vector3(x: 2_063.4604, y: -230.09009, z: 2_204.0276),
            Vector3(x: 2_065.4604, y: -230.09009, z: 2_204.0276),
            Vector3(x: 2_065.4604, y: -230.09009, z: 2_202.0276),
            Vector3(x: 2_063.4604, y: -230.09009, z: 2_202.0276),
        ]
        for (actual, expected) in zip(
            facing.vertices.map(\.position),
            expectedFacingPositions
        ) {
            XCTAssertEqual(actual.x, expected.x, accuracy: 0.000_1)
            XCTAssertEqual(actual.y, expected.y, accuracy: 0.000_1)
            XCTAssertEqual(actual.z, expected.z, accuracy: 0.000_1)
        }
        XCTAssertTrue(extraction.modelDrawItems.contains {
            $0.objectHandle == 6_147
                && $0.submodelIndex == 4
                && $0.vertices.count == 3
        })
        let rotating = try extractWorldForRendering(
            level,
            camera: .trainingRoom3,
            startRoomSourceIndex: 3,
            presentationGameTime: 0.25
        )
        let rotated = try XCTUnwrap(
            rotating.modelDrawItems.first {
                $0.objectHandle == 6_147 && $0.submodelIndex == 4
            }
        )
        XCTAssertEqual(
            rotated.vertices[0].position.x,
            2_064.0604,
            accuracy: 0.001
        )
        XCTAssertEqual(
            rotated.vertices[0].position.z,
            2_208.0276,
            accuracy: 0.001
        )
    }
}

private extension Array {
    var only: Element? { count == 1 ? self[0] : nil }
}

func makeCoronaEvaluationLevel(
    blocked: Bool = false,
    objectBlocked: Bool = false,
    objectPresentationVisible: Bool = true
) -> Level {
    let base = makeMinimalCanonicalLevel()
    let light = SourceResource(storedIndex: 1, sourceName: "light")
    let blocker = SourceResource(storedIndex: 2, sourceName: "blocker")
    let candidateVertices = [
        Vector3(x: -1, y: 21, z: -1),
        Vector3(x: 1, y: 21, z: -1),
        Vector3(x: 1, y: 21, z: 1),
        Vector3(x: -1, y: 21, z: 1),
    ]
    let blockerVertices = [
        Vector3(x: -5, y: 10, z: -5),
        Vector3(x: 5, y: 10, z: -5),
        Vector3(x: 5, y: 10, z: 5),
        Vector3(x: -5, y: 10, z: 5),
    ]
    let corners = [
        FaceCorner(vertexIndex: 0, u: 0, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 1, u: 1, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 2, u: 1, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 3, u: 0, v: 1, alpha: 255),
    ]
    var faces = [
        LevelFace(
            corners: corners,
            flags: 0,
            portalIndex: nil,
            texture: light,
            allowsLightCorona: true
        ),
    ]
    var portals: [LevelPortal] = []
    if blocked {
        faces.append(
            LevelFace(
                corners: corners.map {
                    FaceCorner(
                        vertexIndex: $0.vertexIndex + 4,
                        u: $0.u,
                        v: $0.v,
                        alpha: $0.alpha
                    )
                },
                flags: 0,
                portalIndex: 0,
                texture: blocker
            )
        )
        portals.append(
            .init(flags: 1, faceIndex: 1, connectedRoom: 4, connectedPortal: 0)
        )
    }
    let room3 = LevelRoom(
        sourceIndex: 3,
        vertices: candidateVertices + blockerVertices,
        faces: faces,
        portals: portals
    )
    let room4 = LevelRoom(
        sourceIndex: 4,
        vertices: blockerVertices,
        faces: blocked ? [
            .init(
                corners: Array(corners.reversed()),
                flags: 0,
                portalIndex: 0,
                texture: blocker
            ),
        ] : [],
        portals: blocked ? [
            .init(flags: 1, faceIndex: 0, connectedRoom: 3, connectedPortal: 0),
        ] : []
    )
    let blockerModelSource = SourceResource(storedIndex: 3, sourceName: "blocker.oof")
    let blockerObject = PlacedObject(
        handle: 99,
        type: 2,
        storedID: 0,
        definition: nil,
        instanceName: nil,
        flags: 0,
        doorShields: nil,
        location: .room(3),
        position: .init(x: 0, y: 10, z: 0),
        orientation: .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        ),
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    )
    let blockerModel = CanonicalModel(
        source: blockerModelSource,
        collisionRadius: 2,
        submodels: [
            .init(
                sourceIndex: 0,
                parentIndex: nil,
                offset: .zero,
                vertices: [
                    .init(position: .init(x: -2, y: 0, z: -2), alpha: 1),
                    .init(position: .init(x: 2, y: 0, z: -2), alpha: 1),
                    .init(position: .init(x: 0, y: 0, z: 2), alpha: 1),
                ],
                faces: [],
                presentation: .standard
            ),
        ],
        bounds: .init(
            minimum: .init(x: -2, y: 0, z: -2),
            maximum: .init(x: 2, y: 0, z: 2)
        ),
        sourceArchive: "test.hog",
        sourceSHA256: String(repeating: "d", count: 64)
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: blocked ? [room3, room4] : [room3],
        terrain: base.terrain,
        objects: objectBlocked ? [blockerObject] : [],
        paths: [],
        goals: [],
        triggers: [],
        playerStartFlags: [],
        lightmaps: .init(pages: [], infos: []),
        presentationMaterials: [
            .init(
                texture: light,
                bitmapSourceName: "light.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                blend: .opaque,
                lightmapBlend: .none,
                waterProcedural: nil,
                lightCorona: .init(
                    assetIndex: 0,
                    tint: .init(x: 0.25, y: 0.5, z: 0.75),
                    blend: .additiveSourceAlpha(opacity: 102)
                ),
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "a", count: 64)
            ),
            .init(
                texture: blocker,
                bitmapSourceName: "blocker.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                blend: .opaque,
                lightmapBlend: .none,
                waterProcedural: nil,
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "b", count: 64)
            ),
        ],
        presentationCoronaAssets: [
            .init(
                source: .init(storedIndex: 0, sourceName: "flare"),
                bitmapSourceName: "flare.ogf",
                image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 255])),
                sourceArchive: "test.hog",
                sourceSHA256: String(repeating: "c", count: 64)
            ),
        ],
        models: objectBlocked ? [blockerModel] : [],
        objectPresentations: objectBlocked ? [
            .init(
                objectHandle: blockerObject.handle,
                primaryModel: blockerModelSource,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil,
                isVisible: objectPresentationVisible
            ),
        ] : [],
        dependencyManifest: .init(current: [], historicalEagerBaseline: nil),
        sourceChunks: base.sourceChunks
    )
}

func makeSourceContainmentRoom(
    center: Vector3,
    texture: SourceResource,
    sourceIndex: Int = 3,
    halfExtent: Float = 1
) -> LevelRoom {
    let vertices = [
        Vector3(
            x: center.x - halfExtent,
            y: center.y - halfExtent,
            z: center.z - halfExtent
        ),
        Vector3(
            x: center.x + halfExtent,
            y: center.y - halfExtent,
            z: center.z - halfExtent
        ),
        Vector3(
            x: center.x + halfExtent,
            y: center.y + halfExtent,
            z: center.z - halfExtent
        ),
        Vector3(
            x: center.x - halfExtent,
            y: center.y + halfExtent,
            z: center.z - halfExtent
        ),
        Vector3(
            x: center.x - halfExtent,
            y: center.y - halfExtent,
            z: center.z + halfExtent
        ),
        Vector3(
            x: center.x + halfExtent,
            y: center.y - halfExtent,
            z: center.z + halfExtent
        ),
        Vector3(
            x: center.x + halfExtent,
            y: center.y + halfExtent,
            z: center.z + halfExtent
        ),
        Vector3(
            x: center.x - halfExtent,
            y: center.y + halfExtent,
            z: center.z + halfExtent
        ),
    ]
    func face(_ indices: [Int]) -> LevelFace {
        LevelFace(
            corners: indices.enumerated().map { index, vertexIndex in
                FaceCorner(
                    vertexIndex: vertexIndex,
                    u: index == 1 || index == 2 ? 1 : 0,
                    v: index >= 2 ? 1 : 0,
                    alpha: 255
                )
            },
            flags: 0,
            portalIndex: nil,
            texture: texture
        )
    }
    return LevelRoom(
        sourceIndex: sourceIndex,
        vertices: vertices,
        faces: [
            face([0, 3, 7, 4]),
            face([1, 5, 6, 2]),
            face([0, 4, 5, 1]),
            face([3, 2, 6, 7]),
            face([0, 1, 2, 3]),
            face([4, 7, 6, 5]),
        ],
        portals: []
    )
}

func addingSourceContainmentShell(
    to room: LevelRoom,
    center: Vector3,
    texture: SourceResource,
    halfExtent: Float
) -> LevelRoom {
    let shell = makeSourceContainmentRoom(
        center: center,
        texture: texture,
        sourceIndex: room.sourceIndex,
        halfExtent: halfExtent
    )
    let vertexOffset = room.vertices.count
    let shellFaces = shell.faces.map { face in
        LevelFace(
            corners: face.corners.map {
                .init(
                    vertexIndex: $0.vertexIndex + vertexOffset,
                    u: $0.u,
                    v: $0.v,
                    alpha: $0.alpha
                )
            },
            flags: face.flags,
            portalIndex: nil,
            texture: face.texture
        )
    }
    return LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: room.vertices + shell.vertices,
        faces: room.faces + shellFaces,
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
}

private func alienForceFieldWaterDefinition() -> WaterProceduralDefinition {
    let raw: [(WaterProceduralElementKind, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)] = [
        (.heightBlob, 20, 40, 100, 127, 58, 186, 13),
        (.heightBlob, 20, 40, 100, 0, 59, 13, 240),
        (.heightBlob, 20, 40, 100, 0, 58, 240, 173),
        (.heightBlob, 20, 40, 100, 62, 1, 173, 186),
        (.heightBlob, 20, 40, 100, 62, 126, 186, 13),
        (.heightBlob, 20, 40, 100, 62, 3, 13, 240),
        (.noOp, 0, 1, 1, 91, 38, 240, 173),
    ]
    return WaterProceduralDefinition(
        evaluationIntervalSeconds: 0,
        lightingShift: 7,
        dampingShift: 6,
        elements: raw.map {
            WaterProceduralElement(
                kind: $0.0,
                frequency: $0.1,
                speed: $0.2,
                size: $0.3,
                x1: $0.4,
                y1: $0.5,
                x2: $0.6,
                y2: $0.7
            )
        }
    )
}

func makeSelectedRoomRenderLevel() -> Level {
    let base = makeMinimalCanonicalLevel()
    let forceField = SourceResource(storedIndex: 3, sourceName: "force-field")
    let wall = SourceResource(storedIndex: 0, sourceName: "wall")
    let quad = [
        FaceCorner(vertexIndex: 0, u: 1, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 1, u: 0, v: 1, alpha: 255),
        FaceCorner(vertexIndex: 2, u: 0, v: 0, alpha: 255),
        FaceCorner(vertexIndex: 3, u: 1, v: 0, alpha: 255),
    ]
    let reversedQuad = [quad[3], quad[2], quad[1], quad[0]]
    let forwardVertices = [
        Vector3(x: 1, y: 2, z: 1),
        Vector3(x: -1, y: 2, z: 1),
        Vector3(x: -1, y: 2, z: -1),
        Vector3(x: 1, y: 2, z: -1),
        Vector3(x: 0.5, y: 4, z: 0.5),
        Vector3(x: -0.5, y: 4, z: 0.5),
        Vector3(x: -0.5, y: 4, z: -0.5),
        Vector3(x: 0.5, y: 4, z: -0.5),
        Vector3(x: 0.5, y: 6, z: 0.5),
        Vector3(x: -0.5, y: 6, z: 0.5),
        Vector3(x: -0.5, y: 6, z: -0.5),
        Vector3(x: 0.5, y: 6, z: -0.5),
        Vector3(x: 1, y: -2, z: 1),
        Vector3(x: -1, y: -2, z: 1),
        Vector3(x: -1, y: -2, z: -1),
        Vector3(x: 1, y: -2, z: -1),
    ]
    func corners(_ offset: Int, reversed: Bool = false) -> [FaceCorner] {
        let source = reversed ? reversedQuad : quad
        return source.map {
            FaceCorner(
                vertexIndex: $0.vertexIndex + offset,
                u: $0.u,
                v: $0.v,
                alpha: $0.alpha
            )
        }
    }
    let room2 = LevelRoom(
        sourceIndex: 2,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(4), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(0, reversed: true), flags: 0, portalIndex: 1, texture: forceField),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 1, connectedPortal: 0),
            .init(flags: 1, faceIndex: 1, connectedRoom: 3, connectedPortal: 0),
        ]
    )
    let room3 = LevelRoom(
        sourceIndex: 3,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(0), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(12, reversed: true), flags: 0, portalIndex: 1, texture: forceField),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 2, connectedPortal: 1),
            .init(faceIndex: 1, connectedRoom: 4, connectedPortal: 0),
        ]
    )
    let room1 = LevelRoom(
        sourceIndex: 1,
        vertices: forwardVertices + [
            Vector3(x: 12, y: 6, z: 0.5),
            Vector3(x: 10, y: 6, z: 0.5),
            Vector3(x: 10, y: 6, z: -0.5),
            Vector3(x: 12, y: 6, z: -0.5),
        ],
        faces: [
            .init(corners: corners(4, reversed: true), flags: 0, portalIndex: 0, texture: forceField),
            .init(corners: corners(8), flags: 0, portalIndex: nil, texture: wall),
            .init(corners: corners(16), flags: 0, portalIndex: nil, texture: wall),
        ],
        portals: [
            .init(flags: 1, faceIndex: 0, connectedRoom: 2, connectedPortal: 0),
        ]
    )
    let room4 = LevelRoom(
        sourceIndex: 4,
        vertices: forwardVertices,
        faces: [
            .init(corners: corners(12), flags: 0, portalIndex: 0, texture: forceField),
        ],
        portals: [.init(faceIndex: 0, connectedRoom: 3, connectedPortal: 1)]
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: [room1, room2, room3, room4],
        terrain: base.terrain,
        objects: [],
        paths: [],
        goals: [],
        triggers: [],
        playerStartFlags: [],
        lightmaps: .init(pages: [], infos: []),
        surfacePhysics: [
            .init(texture: wall, behavior: .blocking),
            .init(texture: forceField, behavior: .forceField),
        ],
        presentationMaterials: [
            .init(
                texture: forceField,
                bitmapSourceName: "force-field.ogf",
                image: .init(
                    width: 128,
                    height: 128,
                    rgba8: Data(repeating: 255, count: 128 * 128 * 4)
                ),
                blend: .additiveSourceAlpha(opacity: 178),
                lightmapBlend: .none,
                waterProcedural: alienForceFieldWaterDefinition(),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "a", count: 64)
            ),
            .init(
                texture: wall,
                bitmapSourceName: "wall.ogf",
                image: .init(
                    width: 2,
                    height: 2,
                    rgba8: Data(repeating: 255, count: 16)
                ),
                blend: .opaque,
                lightmapBlend: .multiply,
                waterProcedural: nil,
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "b", count: 64)
            ),
        ],
        dependencyManifest: .init(
            current: [
                .init(
                    category: "texture",
                    source: wall,
                    state: "presentation-payload-imported",
                    provenance: "test"
                ),
                .init(category: "texture", source: forceField, state: "presentation-payload-imported", provenance: "test"),
            ],
            historicalEagerBaseline: nil
        ),
        sourceChunks: base.sourceChunks
    )
}

func makeSliceSixObjectRenderLevel() -> Level {
    let base = makeSelectedRoomRenderLevel()
    let cameraOrigin = RoomCamera.trainingRoom3.position
    func translated(_ point: Vector3) -> Vector3 {
        .init(
            x: point.x + cameraOrigin.x,
            y: point.y + cameraOrigin.y,
            z: point.z + cameraOrigin.z
        )
    }
    let rooms = base.rooms.map { room in
        LevelRoom(
            sourceIndex: room.sourceIndex,
            name: room.name,
            pathPoint: translated(room.pathPoint),
            vertices: room.vertices.map(translated),
            faces: room.faces,
            portals: room.portals,
            flags: room.flags,
            pulseTime: room.pulseTime,
            pulseOffset: room.pulseOffset,
            mirrorFaceIndex: room.mirrorFaceIndex,
            door: room.door,
            volumeLights: room.volumeLights,
            fog: room.fog,
            ambientSoundPattern: room.ambientSoundPattern,
            reverb: room.reverb,
            damage: room.damage,
            damageType: room.damageType
        )
    }
    let modelTexture = SourceResource(storedIndex: 50, sourceName: "model-surface")
    let modelSources = [
        SourceResource(storedIndex: 0, sourceName: "PyroGL.OOF"),
        SourceResource(storedIndex: 1, sourceName: "PyroGLMed.OOF"),
        SourceResource(storedIndex: 2, sourceName: "PyroGLLo.OOF"),
        SourceResource(storedIndex: 3, sourceName: "PyroDeath.OOF"),
        SourceResource(storedIndex: 4, sourceName: "invisiblepowerup.OOF"),
    ]
    let shipSource = SourceResource(storedIndex: 0, sourceName: "Pyro-GL")
    let modelVertices = [
        ModelVertex(
            position: .init(x: -5, y: 0, z: -0.4),
            alpha: 1
        ),
        ModelVertex(
            position: .init(x: 5, y: 0, z: -0.4),
            alpha: 1
        ),
        ModelVertex(
            position: .init(x: 0, y: 0, z: 0.4),
            alpha: 1
        ),
    ]
    let modelCorners = [
        ModelFaceCorner(vertexIndex: 0, u: 0, v: 0),
        ModelFaceCorner(vertexIndex: 1, u: 1, v: 0),
        ModelFaceCorner(vertexIndex: 2, u: 0.5, v: 1),
    ]
    let models = modelSources.map { source in
        CanonicalModel(
            source: source,
            collisionRadius: source == modelSources[0]
                ? Float(bitPattern: 0x40d9_5869)
                : 1,
            submodels: [
                .init(
                    sourceIndex: 0,
                    parentIndex: 1,
                    offset: .zero,
                    vertices: modelVertices,
                    faces: [
                        .init(
                            normal: .init(x: 0, y: -1, z: 0),
                            corners: modelCorners,
                            material: .texture(modelTexture)
                        ),
                        .init(
                            normal: .init(x: 0, y: 1, z: 0),
                            corners: Array(modelCorners.reversed()),
                            material: .sourceColor(red: 32, green: 64, blue: 96)
                        ),
                    ],
                    presentation: .standard
                ),
                .init(
                    sourceIndex: 1,
                    parentIndex: nil,
                    offset: .init(x: 3, y: 0, z: 0),
                    vertices: [],
                    faces: [],
                    presentation: .standard
                ),
                .init(
                    sourceIndex: 2,
                    parentIndex: nil,
                    offset: .init(x: 3, y: 0, z: 0),
                    vertices: modelVertices,
                    faces: [
                        .init(
                            normal: .init(x: 0, y: -1, z: 0),
                            corners: modelCorners,
                            material: .sourceColor(red: 255, green: 0, blue: 255)
                        ),
                    ],
                    presentation: .custom
                ),
                .init(
                    sourceIndex: 3,
                    parentIndex: nil,
                    offset: .init(x: 3, y: 0, z: 0),
                    vertices: modelVertices,
                    faces: [
                        .init(
                            normal: .init(x: 0, y: -1, z: 0),
                            corners: modelCorners,
                            material: .texture(modelTexture)
                        ),
                    ],
                    presentation: .facing
                ),
                .init(
                    sourceIndex: 4,
                    parentIndex: nil,
                    offset: .init(x: 3, y: 0, z: 0),
                    vertices: modelVertices,
                    faces: [
                        .init(
                            normal: .init(x: 0, y: 1, z: 0),
                            corners: modelCorners,
                            material: .texture(modelTexture)
                        ),
                    ],
                    presentation: .rotate(
                        rate: 1,
                        axis: .init(x: 0, y: 1, z: 0)
                    )
                ),
            ],
            bounds: .init(
                minimum: .init(x: -2, y: 0, z: -0.4),
                maximum: .init(x: 8, y: 0, z: 0.4)
            ),
            sourceArchive: base.source.profileFiles[0].relativePath,
            sourceSHA256: String(repeating: "e", count: 64)
        )
    }
    let identity = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 1, z: 0),
        forward: .init(x: 0, y: 0, z: 1)
    )
    let invisibleDefinition = SourceResource(
        storedIndex: 67,
        sourceName: "Invisiblepowerup"
    )
    func object(
        handle: UInt32,
        type: UInt8,
        storedID: Int,
        name: String?,
        room: Int,
        position: Vector3
    ) -> PlacedObject {
        PlacedObject(
            handle: handle,
            type: type,
            storedID: storedID,
            definition: type == 7 ? invisibleDefinition : nil,
            instanceName: name,
            flags: 0,
            doorShields: nil,
            location: .room(room),
            position: position,
            orientation: identity,
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
    }
    let objects = [
        object(handle: 2_048, type: 4, storedID: 0, name: nil, room: 1,
               position: .init(x: 2_060.6497, y: -131.22517, z: 2_204.4216)),
        object(handle: 6_147, type: 7, storedID: 67, name: "StartCourse", room: 3,
               position: .init(x: 2_061.4604, y: -230.09009, z: 2_203.0276)),
        object(handle: 2_052, type: 4, storedID: 2, name: nil, room: 1,
               position: .init(x: 1_962.3759, y: -130.63771, z: 2_206.575)),
        object(handle: 18_441, type: 7, storedID: 67, name: "UpGoal", room: 1,
               position: .init(x: 2_060.6682, y: -25.897497, z: 2_204.6843)),
        object(handle: 12_299, type: 7, storedID: 67, name: "LeftGoal", room: 1,
               position: .init(x: 1_958.2805, y: -131.22517, z: 2_205.8071)),
        object(handle: 12_300, type: 7, storedID: 67, name: "StartGoal", room: 1,
               position: .init(x: 2_062.7678, y: -134.19601, z: 2_201.679)),
        object(handle: 12_301, type: 7, storedID: 67, name: "ForwardGoal", room: 1,
               position: .init(x: 2_060.4836, y: -131.22517, z: 2_310.928)),
    ]
    let pyroPresentation = ObjectPresentationReference(
        objectHandle: 2_048,
        primaryModel: modelSources[0],
        mediumModel: modelSources[1],
        lowModel: modelSources[2],
        dyingModel: modelSources[3],
        mediumDistance: 75,
        lowDistance: 100
    )
    let objectPresentations = [pyroPresentation,
        .init(
            objectHandle: 2_052,
            primaryModel: modelSources[0],
            mediumModel: modelSources[1],
            lowModel: modelSources[2],
            dyingModel: modelSources[3],
            mediumDistance: 75,
            lowDistance: 100
        ),
    ] + objects.filter { $0.type == 7 }.map {
        ObjectPresentationReference(
            objectHandle: $0.handle,
            primaryModel: modelSources[4],
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        )
    }
    let modelMaterial = PresentationMaterial(
        texture: modelTexture,
        bitmapSourceName: "model-surface.ogf",
        image: .init(width: 1, height: 1, rgba8: Data([255, 255, 255, 128])),
        blend: .sourceAlpha(opacity: 255),
        lightmapBlend: .none,
        waterProcedural: nil,
        sourceArchive: base.source.profileFiles[0].relativePath,
        sourceSHA256: String(repeating: "f", count: 64)
    )
    let dependencies = base.dependencyManifest.current + [
        DependencyRecord(
            category: "object-definition",
            source: invisibleDefinition,
            state: "identity-recorded",
            provenance: "synthetic Slice 6 fixture"
        ),
        DependencyRecord(
            category: "texture",
            source: modelTexture,
            state: "presentation-payload-imported",
            provenance: "synthetic Slice 6 fixture"
        ),
    ] + modelSources.map {
        DependencyRecord(
            category: "model",
            source: $0,
            state: "presentation-payload-imported",
            provenance: "synthetic Slice 6 fixture"
        )
    } + [
        DependencyRecord(
            category: "ship-definition",
            source: shipSource,
            state: "canonical-typed-definition",
            provenance: "synthetic Slice 9 fixture"
        ),
    ]
    let ship = CanonicalShipDefinition(
        source: shipSource,
        primaryModel: modelSources[0],
        presentationSize: 6.676084041595459,
        physics: .init(
            mass: 30,
            drag: 90,
            fullThrust: 5_400,
            behaviors: [.turnroll, .wiggle, .usesThrust],
            rotationalDrag: 225,
            fullRotationalThrust: 6_860_000,
            numberOfBounces: -1,
            initialForwardVelocity: 0,
            initialAngularVelocity: .zero,
            wiggleAmplitude: 0.17,
            wigglesPerSecond: 0.9,
            coefficientOfRestitution: 1,
            hitDieDot: -1,
            maximumTurnrollRate: 8_000,
            turnrollRatio: 0.13
        )
    )
    return Level(
        missionKey: base.missionKey,
        levelKey: base.levelKey,
        source: base.source,
        metadata: base.metadata,
        rooms: rooms,
        terrain: base.terrain,
        objects: objects,
        paths: base.paths,
        goals: base.goals,
        triggers: base.triggers,
        playerStartFlags: [0, 0],
        lightmaps: base.lightmaps,
        surfacePhysics: base.surfacePhysics,
        presentationMaterials: base.presentationMaterials + [modelMaterial],
        models: models,
        shipDefinitions: [ship],
        defaultPlayerBinding: .init(
            playerID: 0,
            objectHandle: 2_048,
            ship: shipSource
        ),
        objectPresentations: objectPresentations,
        dependencyManifest: .init(
            current: dependencies,
            historicalEagerBaseline: nil
        ),
        sourceChunks: base.sourceChunks
    )
}

func makeTrainingGalleryBarrierLevel() -> Level {
    var level = makeSliceSixObjectRenderLevel()
    let cameraOrigin = RoomCamera.trainingRoom3.position
    let barrierRoomIndex = level.rooms.firstIndex {
        $0.sourceIndex == 2
    }!
    for portalIndex in level.rooms[barrierRoomIndex].portals.indices {
        level.rooms[barrierRoomIndex].portals[portalIndex].flags &= ~UInt32(1)
        let portal = level.rooms[barrierRoomIndex].portals[portalIndex]
        let connectedRoomIndex = level.rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        level.rooms[connectedRoomIndex].portals[portal.connectedPortal].flags
            &= ~UInt32(1)
    }
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    level.objects[playerIndex].location = .room(2)
    level.objects[playerIndex].position = .init(
        x: cameraOrigin.x,
        y: cameraOrigin.y + 2.5,
        z: cameraOrigin.z
    )
    level.objects[playerIndex].orientation = .init(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 0, z: 1),
        forward: .init(x: 0, y: -1, z: 0)
    )
    level.objects.append(.init(
        handle: 6_163,
        type: 11,
        storedID: 67,
        definition: level.objects.first { $0.handle == 12_301 }!.definition,
        instanceName: "FlashLight-2",
        flags: 0,
        doorShields: nil,
        location: .room(2),
        position: cameraOrigin,
        orientation: .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        ),
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    let trigger = LevelTrigger(
        name: "Portal2",
        roomIndex: 2,
        faceIndex: 1,
        flags: 8,
        activator: 1
    )
    let triggerFace = level.rooms[barrierRoomIndex].faces[trigger.faceIndex]
    level.rooms[barrierRoomIndex].faces[trigger.faceIndex] = .init(
        corners: triggerFace.corners,
        flags: triggerFace.flags | 0x0010,
        portalIndex: triggerFace.portalIndex,
        texture: triggerFace.texture,
        lightmapInfoIndex: triggerFace.lightmapInfoIndex,
        allowsLightCorona: triggerFace.allowsLightCorona,
        lightMultiple: triggerFace.lightMultiple,
        special: triggerFace.special
    )
    level = replacing(level, triggers: [trigger])
    return level.addingTrainingGalleryBarrier(
        .init(
            triggerName: trigger.name,
            triggerRoomSourceIndex: trigger.roomIndex,
            triggerFaceIndex: trigger.faceIndex,
            barrierRoomSourceIndex: 2,
            orderedPortalIndices: [1, 0],
            markerLightObjectHandle: 6_163,
            openMarkerLightDistance: 50,
            successMessage: "Excellent!",
            guidebotInstruction:
                "Your ship is equipped with a utility robot called a Guidebot.  Release him now with F4.",
            voiceSourceName: "guidebota.osf"
        ),
        voiceClip: .init(
            sourceName: "guidebota.osf",
            sourceEntryIndex: 0,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: Data(repeating: 0, count: 2),
            pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
            sourceArchive: "missions/training.mn3",
            sourceSHA256: String(repeating: "a", count: 64)
        )
    )
}

func makeTrainingScript003Level() -> Level {
    let level = makeSliceSixObjectRenderLevel()
    let startGoalHandle: UInt32 = 12_300
    let presentation = level.objectPresentations.first {
        $0.objectHandle == startGoalHandle
    }!
    let model = level.models.first {
        $0.source == presentation.primaryModel
    }!
    let leftGoalHandle: UInt32 = 12_299
    let leftPresentation = level.objectPresentations.first {
        $0.objectHandle == leftGoalHandle
    }!
    let leftModel = level.models.first {
        $0.source == leftPresentation.primaryModel
    }!
    let forwardGoalHandle: UInt32 = 12_301
    let forwardPresentation = level.objectPresentations.first {
        $0.objectHandle == forwardGoalHandle
    }!
    let forwardModel = level.models.first {
        $0.source == forwardPresentation.primaryModel
    }!
    let pcm = Data(repeating: 0, count: 2)
    let clips = [
        ("welcome.osf", 38),
        ("return1.osf", 28),
        ("left1.osf", 18),
        ("return2.osf", 29),
        ("up1.osf", 37),
        ("return3.osf", 30),
        ("repeat.osf", 25),
        ("lright.osf", 19),
    ].map { name, index in
        CanonicalVoiceClip(
            sourceName: name,
            sourceEntryIndex: index,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: pcm,
            pcmSHA256: canonicalSHA256(pcm),
            sourceArchive: "missions/training.mn3",
            sourceSHA256: String(repeating: "a", count: 64)
        )
    }
    return level.addingTrainingOpeningLesson(
        .init(
            forwardGoalObjectHandle: 12_301,
            welcomeDelay: 1,
            welcomeMessage: "Welcome to the Descent 3 Training session.",
            forwardInstruction: "Move forward until you stop.",
            welcomeVoiceSourceName: "welcome.osf",
            successMessage: "Excellent!",
            reverseInstruction:
                "Now use the reverse Key to return to where you started!",
            successVoiceSourceName: "return1.osf",
            returnLeft: .init(
                startGoalObjectHandle: startGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: model,
                    objectType: 7
                ),
                instruction: "Now Go Left until you stop.",
                voiceSourceName: "left1.osf"
            ),
            returnRight: .init(
                leftGoalObjectHandle: leftGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: leftModel,
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
                    model: model,
                    objectType: 7
                ),
                successMessage: "Excellent!",
                instruction: "Now Slide up  until you stop.",
                voiceSourceName: "up1.osf"
            ),
            returnDown: .init(
                upGoalObjectHandle: 18_441,
                collisionRadius: sourceObjectPresentationSize(
                    model: model,
                    objectType: 7
                ),
                successMessage: "Excellent!",
                instruction:
                    "Now Slide down until you return to the start position.",
                voiceSourceName: "return3.osf"
            ),
            repeatForward: .init(
                startGoalObjectHandle: startGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: model,
                    objectType: 7
                ),
                successMessage: "Excellent!",
                repeatMessage: "Let's repeat the exercise we just did.",
                forwardInstruction: "Move forward until you stop.",
                voiceSourceName: "repeat.osf"
            ),
            repeatForwardGoal: .init(
                forwardGoalObjectHandle: forwardGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: forwardModel,
                    objectType: 7
                ),
                reverseInstruction:
                    "Now use the reverse Key to return to where you started!",
                soundLogicalName: "MenuBeepEnter"
            ),
            repeatReturnLeft: .init(
                startGoalObjectHandle: startGoalHandle,
                collisionRadius: sourceObjectPresentationSize(
                    model: model,
                    objectType: 7
                ),
                instruction: "Now Go Left until you stop.",
                voiceSourceName: "lright.osf"
            )
        ),
        voiceClips: clips,
        soundClips: [
            .init(
                logicalName: "MenuBeepEnter",
                sourceName: "MenuBeepSelectC.wav",
                sourceEntryIndex: 0,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: pcm,
                pcmSHA256: canonicalSHA256(pcm),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "b", count: 64),
                importVolume: 0.7
            ),
        ]
    )
}

func makeTrainingRobotGuidebotLevel() -> Level {
    var level = makeTrainingGalleryBarrierLevel()
    let buddySource = SourceResource(
        storedIndex: 200,
        sourceName: "Buddybot.oof"
    )
    let gyroSource = SourceResource(
        storedIndex: 201,
        sourceName: "gyro.OOF"
    )
    let modelTemplate = level.models[0]
    level = replacing(
        level,
        models: level.models + [
            .init(
                source: buddySource,
                collisionRadius: 5.659_440_5,
                submodels: modelTemplate.submodels,
                bounds: modelTemplate.bounds,
                sourceArchive: modelTemplate.sourceArchive,
                sourceSHA256: String(repeating: "d", count: 64)
            ),
            .init(
                source: gyroSource,
                collisionRadius: 4.576_441_8,
                submodels: modelTemplate.submodels,
                bounds: modelTemplate.bounds,
                sourceArchive: modelTemplate.sourceArchive,
                sourceSHA256: String(repeating: "e", count: 64)
            ),
        ],
        objectPresentations: level.objectPresentations + [
            .init(
                objectHandle: 4_112,
                primaryModel: gyroSource,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil
            ),
        ],
        dependencyManifest: .init(
            current: level.dependencyManifest.current + [
                .init(
                    category: "model",
                    source: buddySource,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
                .init(
                    category: "model",
                    source: gyroSource,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
            ],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    let template = level.objects.first { $0.handle == 12_301 }!
    level.objects.append(.init(
        handle: 4_112,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "DestroyBot2",
        flags: 5_121,
        doorShields: nil,
        location: .room(2),
        position: template.position,
        orientation: template.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level = replacing(
        level,
        dependencyManifest: .init(
            current: level.dependencyManifest.current + [
                .init(
                    category: "object-definition",
                    source: .init(
                        storedIndex: 106,
                        sourceName: "RAS1 Light Security Flyer"
                    ),
                    state: "identity-recorded",
                    provenance: "synthetic canonical fixture"
                ),
            ],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    return level.addingTrainingRobotGuidebotChain(
        .init(
            destroyRobotObjectHandle: 4_112,
            guidebotObjectHandle: 6_164,
            destroyRobotRoomSourceIndex: 2,
            destroyRobotFlags: 5_121,
            destructionDelay: 2,
            destructionMessage: "Excellent!",
            exitInstruction:
                "Now go through the open doorway, and into the next room.",
            destructionVoiceSourceName: "proceed5.osf",
            deployedGuidebotObjectType: 2,
            deployedGuidebotMessage:
                "Have the Guidebot help you complete a goal.  Press F4 and select item 1.  Fly over the object he leads you to.",
            deployedGuidebotVoiceSourceName: "guidebotb.osf",
            combat: .stockTraining,
            guidebot: .stockTraining
        ),
        voiceClips: [
            .init(
                sourceName: "proceed5.osf",
                sourceEntryIndex: 1,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: Data(repeating: 0, count: 2),
                pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "b", count: 64)
            ),
            .init(
                sourceName: "guidebotb.osf",
                sourceEntryIndex: 2,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: Data(repeating: 0, count: 2),
                pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "c", count: 64)
            ),
        ]
    )
}

func makeTrainingCameraMonitorLevel() -> Level {
    var level = makeTrainingRobotGuidebotLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let returnBarrierRoomIndex = level.rooms.firstIndex {
        $0.sourceIndex == 2
    }!
    let sourceForceField = level.rooms[returnBarrierRoomIndex]
        .faces[
            level.rooms[returnBarrierRoomIndex].portals[0].faceIndex
        ].texture
    let stockReturnForceField = SourceResource(
        storedIndex: 908,
        sourceName: "Alien Force Field_1"
    )
    var rooms = level.rooms
    for portalIndex in [0, 1] {
        let portal = rooms[returnBarrierRoomIndex].portals[portalIndex]
        rooms[returnBarrierRoomIndex].faces[portal.faceIndex].texture =
            stockReturnForceField
        let reciprocalRoomIndex = rooms.firstIndex {
            $0.sourceIndex == portal.connectedRoom
        }!
        let reciprocal = rooms[reciprocalRoomIndex]
            .portals[portal.connectedPortal]
        rooms[reciprocalRoomIndex].faces[reciprocal.faceIndex].texture =
            stockReturnForceField
    }
    let sourceForceFieldMaterial = level.presentationMaterials.first {
        $0.texture == sourceForceField
    }!
    level = replacing(
        level,
        rooms: rooms,
        surfacePhysics: level.surfacePhysics + [
            .init(
                texture: stockReturnForceField,
                behavior: .forceField
            ),
        ],
        presentationMaterials: level.presentationMaterials + [
            .init(
                texture: stockReturnForceField,
                bitmapSourceName: "Alien Force Field_1.ogf",
                image: sourceForceFieldMaterial.image,
                blend: sourceForceFieldMaterial.blend,
                lightmapBlend: sourceForceFieldMaterial.lightmapBlend,
                waterProcedural: sourceForceFieldMaterial.waterProcedural,
                sourceArchive: sourceForceFieldMaterial.sourceArchive,
                sourceSHA256: String(repeating: "8", count: 64)
            ),
        ],
        dependencyManifest: .init(
            current: level.dependencyManifest.current + [
                .init(
                    category: "texture",
                    source: stockReturnForceField,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
            ],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    let cameraMonitorSource = SourceResource(
        storedIndex: 9_000,
        sourceName: "monitor.OOF"
    )
    let modelTemplate = level.models[0]
    let cameraMonitorModels = level.models.contains {
        $0.source == cameraMonitorSource
    }
        ? level.models
        : level.models + [
            .init(
                source: cameraMonitorSource,
                collisionRadius: 2,
                submodels: modelTemplate.submodels,
                bounds: modelTemplate.bounds,
                sourceArchive: modelTemplate.sourceArchive,
                sourceSHA256: String(repeating: "f", count: 64)
            ),
        ]
    level = replacing(
        level,
        models: cameraMonitorModels,
        objectPresentations: level.objectPresentations + [
            .init(
                objectHandle: 6_167,
                primaryModel: cameraMonitorSource,
                mediumModel: nil,
                lowModel: nil,
                dyingModel: nil,
                mediumDistance: nil,
                lowDistance: nil
            ),
        ],
        dependencyManifest: .init(
            current: level.dependencyManifest.current.map { dependency in
                guard dependency.category == "model",
                      dependency.source == cameraMonitorSource else {
                    return dependency
                }
                return .init(
                    category: dependency.category,
                    source: dependency.source,
                    state: "presentation-payload-imported",
                    provenance: dependency.provenance
                )
            } + (level.dependencyManifest.current.contains {
                $0.category == "model"
                    && $0.source == cameraMonitorSource
            } ? [] : [
                .init(
                    category: "model",
                    source: cameraMonitorSource,
                    state: "presentation-payload-imported",
                    provenance: "synthetic canonical fixture"
                ),
            ]),
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    if let pickupIndex = level.objects.firstIndex(where: {
        $0.handle == 6_167
    }) {
        level.objects[pickupIndex].location = player.location
        level.objects[pickupIndex].position = player.position
        level.objects[pickupIndex].orientation = player.orientation
    } else {
        level.objects.append(.init(
            handle: 6_167,
            type: 7,
            storedID: 91,
            definition: .init(
                storedIndex: 91,
                sourceName: "Camera Monitor"
            ),
            instanceName: "CameraMonitor",
            flags: 4_096,
            doorShields: nil,
            location: player.location,
            position: player.position,
            orientation: player.orientation,
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        ))
    }
    if let cameraIndex = level.objects.firstIndex(where: {
        $0.handle == 6_183
    }) {
        level.objects[cameraIndex].location = player.location
        level.objects[cameraIndex].position = player.position
        level.objects[cameraIndex].orientation = player.orientation
    } else {
        level.objects.append(.init(
            handle: 6_183,
            type: 2,
            storedID: 114,
            definition: .init(
                storedIndex: 114,
                sourceName: "new wall cam"
            ),
            instanceName: "SecurityCamera",
            flags: 5_120,
            doorShields: nil,
            location: player.location,
            position: player.position,
            orientation: player.orientation,
            containsType: 0,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        ))
    }
    level.objects.append(.init(
        handle: 10_245,
        type: 11,
        storedID: 205,
        definition: .init(
            storedIndex: 205,
            sourceName: "Blinking Red Light-DM"
        ),
        instanceName: "FlashLight-3",
        flags: 4_096,
        doorShields: nil,
        location: player.location,
        position: player.position,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level = replacing(
        level,
        dependencyManifest: .init(
            current: level.dependencyManifest.current + [
                .init(
                    category: "object-definition",
                    source: .init(
                        storedIndex: 91,
                        sourceName: "Camera Monitor"
                    ),
                    state: "identity-recorded",
                    provenance: "synthetic canonical fixture"
                ),
                .init(
                    category: "object-definition",
                    source: .init(
                        storedIndex: 114,
                        sourceName: "new wall cam"
                    ),
                    state: "identity-recorded",
                    provenance: "synthetic canonical fixture"
                ),
                .init(
                    category: "object-definition",
                    source: .init(
                        storedIndex: 205,
                        sourceName: "Blinking Red Light-DM"
                    ),
                    state: "identity-recorded",
                    provenance: "synthetic canonical fixture"
                ),
            ].filter { candidate in
                !level.dependencyManifest.current.contains {
                    $0.category == candidate.category
                        && $0.source == candidate.source
                }
            },
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    if case let .room(playerRoomSourceIndex) = player.location,
       let playerRoomIndex = level.rooms.firstIndex(where: {
           $0.sourceIndex == playerRoomSourceIndex
       }) {
        level.rooms[playerRoomIndex] = addingSourceContainmentShell(
            to: level.rooms[playerRoomIndex],
            center: player.position,
            texture: level.surfacePhysics[0].texture,
            halfExtent: 500
        )
    }
    level = replacing(
        level,
        goals: level.goals + [
            .init(
                status: 1_028,
                priority: 0,
                list: 0,
                name: "Locate the Camera Monitor",
                itemName: "Camera Monitor",
                description: "Find and pickup the Camera Monitor",
                completionMessage: "",
                items: [
                    .init(
                        type: 2,
                        sourceHandle: 6_167,
                        objectHandle: 6_167,
                        done: false
                    ),
                ]
            ),
        ]
    )
    return level.addingTrainingCameraMonitorChain(
        .init(
            pickupObjectHandle: 6_167,
            securityCameraObjectHandle: 6_183,
            pickupCollisionRadius: 2,
            pickupMessage:
                "Excellent.  You now have the Camera Monitor.  Press the Use Inventory key to activate it!",
            pickupVoiceSourceName: "guidebotc.osf",
            pickupSoundSourceName: "PupC.wav",
            useMessage:
                "Now recall the Guidebot by pressing F4 and selecting \"Return to Ship\".  Move to the next area when he returns.",
            useVoiceSourceName: "guidebotd.osf",
            popupDuration: 10,
            popupZoom: 1,
            cameraGunpointIndex: 0,
            cameraLocalPosition: .zero,
            cameraLocalForward: .init(x: 0, y: 0, z: -1),
            completionTimerDuration: 2,
            returnToShip: .init(
                markerLightObjectHandle: 10_245,
                markerLightPresentation: .init(
                    primaryColor: .init(x: 1, y: 0.25, z: 0),
                    secondaryColor: .zero,
                    timeInterval: 0.5,
                    flickerDistance: 0.2,
                    directionalDot: 0,
                    flags: 4,
                    timebits: .max,
                    angle: 0,
                    lightingRenderType: 2
                ),
                barrierRoomSourceIndex: 2,
                orderedPortalIndices: [0, 1],
                openMarkerLightDistance: 50,
                returnMessage: "GB: Returning to ship.",
                returnSoundSourceName: "GBotAcceptOrder.wav",
                arrivalMessage: "GB: Entering ship!",
                successMessage: "Excellent!",
                successVoiceSourceName: "proceed6.osf"
            )
        ),
        voiceClips: [
            syntheticVoiceClip(
                name: "guidebotc.osf",
                sourceEntryIndex: 6,
                sourceHash: "1"
            ),
            syntheticVoiceClip(
                name: "guidebotd.osf",
                sourceEntryIndex: 7,
                sourceHash: "2"
            ),
            syntheticVoiceClip(
                name: "proceed6.osf",
                sourceEntryIndex: 26,
                sourceHash: "4"
            ),
        ],
        soundClips: [
            .init(
                logicalName: "PupC1",
                sourceName: "PupC.wav",
                sourceEntryIndex: 3,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: Data(repeating: 0, count: 2),
                pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "3", count: 64),
                importVolume: 1
            ),
            .init(
                logicalName: "GBotAcceptOrder1",
                sourceName: "GBotAcceptOrder.wav",
                sourceEntryIndex: 1_257,
                sampleRate: 22_050,
                channelCount: 1,
                frameCount: 1,
                pcm16LittleEndian: Data(repeating: 0, count: 2),
                pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
                sourceArchive: "missions/training.mn3",
                sourceSHA256: String(repeating: "5", count: 64),
                importVolume: 1
            ),
        ]
    )
}

func makeTrainingKillbotEntryLevel(
    followupDelay: Float = 13
) -> Level {
    let level = makeTrainingCameraMonitorLevel()
    let camera = level.trainingCameraMonitorChain!
    let returnChain = camera.returnToShip!
    let addedVoices = [
        syntheticVoiceClip(
            name: "intro6.osf",
            sourceEntryIndex: 25,
            sourceHash: "6"
        ),
        syntheticVoiceClip(
            name: "guidebotf.osf",
            sourceEntryIndex: 27,
            sourceHash: "7"
        ),
    ]
    let killbotEntry = TrainingKillbotEntryChain(
        triggerName: "Portal3",
        triggerRoomSourceIndex: returnChain.barrierRoomSourceIndex,
        triggerFaceIndex: 1,
        orderedPortalIndices: [1, 0],
        closedMarkerLightDistance: 0,
        entryMessage:
            "Now you are on your own in this room. There are 4 robots and 2 powerups. Get the powerups and kill the robots.",
        entryVoiceSourceName: "intro6.osf",
        followupDelay: followupDelay,
        followupMessage:
            "Some parts of this area are very dark.  Turn on your headlight or fire flares to see.  Use your guidebot if you need help finding a robot or powerup.",
        followupVoiceSourceName: "guidebotf.osf"
    )
    let updatedReturn = TrainingGuidebotReturnChain(
        markerLightObjectHandle: returnChain.markerLightObjectHandle,
        markerLightPresentation: returnChain.markerLightPresentation,
        barrierRoomSourceIndex: returnChain.barrierRoomSourceIndex,
        orderedPortalIndices: returnChain.orderedPortalIndices,
        openMarkerLightDistance: returnChain.openMarkerLightDistance,
        returnMessage: returnChain.returnMessage,
        returnSoundSourceName: returnChain.returnSoundSourceName,
        arrivalMessage: returnChain.arrivalMessage,
        successMessage: returnChain.successMessage,
        successVoiceSourceName: returnChain.successVoiceSourceName,
        killbotEntry: killbotEntry
    )
    let updatedCamera = TrainingCameraMonitorChain(
        pickupObjectHandle: camera.pickupObjectHandle,
        securityCameraObjectHandle: camera.securityCameraObjectHandle,
        pickupCollisionRadius: camera.pickupCollisionRadius,
        pickupMessage: camera.pickupMessage,
        pickupVoiceSourceName: camera.pickupVoiceSourceName,
        pickupSoundSourceName: camera.pickupSoundSourceName,
        useMessage: camera.useMessage,
        useVoiceSourceName: camera.useVoiceSourceName,
        popupDuration: camera.popupDuration,
        popupZoom: camera.popupZoom,
        cameraGunpointIndex: camera.cameraGunpointIndex,
        cameraLocalPosition: camera.cameraLocalPosition,
        cameraLocalForward: camera.cameraLocalForward,
        completionTimerDuration: camera.completionTimerDuration,
        returnToShip: updatedReturn
    )
    let trigger = LevelTrigger(
        name: killbotEntry.triggerName,
        roomIndex: killbotEntry.triggerRoomSourceIndex,
        faceIndex: killbotEntry.triggerFaceIndex,
        flags: 8,
        activator: 1
    )
    var rooms = level.rooms
    let triggerRoomIndex = rooms.firstIndex {
        $0.sourceIndex == killbotEntry.triggerRoomSourceIndex
    }!
    for faceIndex in [0, killbotEntry.triggerFaceIndex] {
        let triggerFace = rooms[triggerRoomIndex].faces[faceIndex]
        rooms[triggerRoomIndex].faces[faceIndex] = .init(
            corners: triggerFace.corners,
            flags: triggerFace.flags | 0x0010,
            portalIndex: triggerFace.portalIndex,
            texture: triggerFace.texture,
            lightmapInfoIndex: triggerFace.lightmapInfoIndex,
            allowsLightCorona: triggerFace.allowsLightCorona,
            lightMultiple: triggerFace.lightMultiple,
            special: triggerFace.special
        )
    }
    let gallery = level.trainingGalleryBarrier!
    let syntheticGallery = TrainingGalleryBarrier(
        triggerName: gallery.triggerName,
        triggerRoomSourceIndex: gallery.triggerRoomSourceIndex,
        triggerFaceIndex: 0,
        barrierRoomSourceIndex: gallery.barrierRoomSourceIndex,
        orderedPortalIndices: gallery.orderedPortalIndices,
        markerLightObjectHandle: gallery.markerLightObjectHandle,
        openMarkerLightDistance: gallery.openMarkerLightDistance,
        successMessage: gallery.successMessage,
        guidebotInstruction: gallery.guidebotInstruction,
        voiceSourceName: gallery.voiceSourceName
    )
    let triggers = level.triggers.map { candidate in
        candidate.name == gallery.triggerName
            ? .init(
                name: candidate.name,
                roomIndex: candidate.roomIndex,
                faceIndex: 0,
                flags: candidate.flags,
                activator: candidate.activator
            )
            : candidate
    } + [trigger]
    return replacing(
        level,
        rooms: rooms,
        triggers: triggers,
        surfacePhysics: level.surfacePhysics,
        trainingGalleryBarrier: syntheticGallery,
        trainingCameraMonitorChain: updatedCamera,
        voiceClips: level.voiceClips + addedVoices,
        dependencyManifest: .init(
            current: level.dependencyManifest.current
                + addedVoices.map {
                    .init(
                        category: "voice",
                        source: .init(
                            storedIndex: $0.sourceEntryIndex,
                            sourceName: $0.sourceName
                        ),
                        state: "canonical-pcm-imported",
                        provenance:
                            "\($0.sourceArchive) \($0.sourceSHA256)"
                    )
                },
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
}

func makeTrainingRASBot1DeathLevel() -> Level {
    var level = makeTrainingKillbotEntryLevel()
    let chain = level.trainingRobotGuidebotChain!
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    let robotModel = level.objectPresentations.first {
        $0.objectHandle == chain.destroyRobotObjectHandle
    }!.primaryModel
    let robotPosition = Vector3(
        x: player.position.x + player.orientation.forward.x * 20,
        y: player.position.y + player.orientation.forward.y * 20,
        z: player.position.z + player.orientation.forward.z * 20
    )
    level.objects.append(.init(
        handle: 2_074,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "RASBot1",
        flags: 5_121,
        doorShields: nil,
        location: player.location,
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_074,
        primaryModel: robotModel,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil
    ))
    return level.addingTrainingRASBot1DeathChain(.init(
        robotObjectHandle: 2_074,
        robotRoomSourceIndex: {
            guard case let .room(roomSourceIndex) = player.location else {
                preconditionFailure("Synthetic Training player is indoor")
            }
            return roomSourceIndex
        }(),
        robotFlags: 5_121,
        combat: .stockTraining
    ))
}

func makeTrainingRASBot2DeathLevel() -> Level {
    var level = makeTrainingRASBot1DeathLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let rasBot1Index = level.objects.firstIndex { $0.handle == 2_074 }!
    level.objects[rasBot1Index].position = .init(
        x: player.position.x + player.orientation.right.x * 20,
        y: player.position.y + player.orientation.right.y * 20,
        z: player.position.z + player.orientation.right.z * 20
    )
    let robotModel = level.objectPresentations.first {
        $0.objectHandle == 2_074
    }!.primaryModel
    let robotPosition = Vector3(
        x: player.position.x + player.orientation.forward.x * 20,
        y: player.position.y + player.orientation.forward.y * 20,
        z: player.position.z + player.orientation.forward.z * 20
    )
    level.objects.append(.init(
        handle: 2_075,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "RASBot2",
        flags: 5_121,
        doorShields: nil,
        location: player.location,
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_075,
        primaryModel: robotModel,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil
    ))
    return level.addingTrainingRASBot2DeathChain(.init(
        robotObjectHandle: 2_075,
        robotRoomSourceIndex: {
            guard case let .room(roomSourceIndex) = player.location else {
                preconditionFailure("Synthetic Training player is indoor")
            }
            return roomSourceIndex
        }(),
        robotFlags: 5_121,
        combat: .stockTraining
    ))
}

func makeTrainingRASBot3DeathLevel() -> Level {
    var level = makeTrainingRASBot2DeathLevel()
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    guard case let .room(playerRoomSourceIndex) = player.location,
          let playerRoom = level.rooms.first(where: {
              $0.sourceIndex == playerRoomSourceIndex
          }) else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    if !level.rooms.contains(where: { $0.sourceIndex == 42 }) {
        level.rooms.append(.init(
            sourceIndex: 42,
            name: "RASBot3 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let rasBot2Index = level.objects.firstIndex { $0.handle == 2_075 }!
    level.objects[rasBot2Index].position = .init(
        x: player.position.x - player.orientation.right.x * 20,
        y: player.position.y - player.orientation.right.y * 20,
        z: player.position.z - player.orientation.right.z * 20
    )
    let robotModel = level.objectPresentations.first {
        $0.objectHandle == 2_075
    }!.primaryModel
    let robotPosition = Vector3(
        x: player.position.x + player.orientation.forward.x * 20,
        y: player.position.y + player.orientation.forward.y * 20,
        z: player.position.z + player.orientation.forward.z * 20
    )
    level.objects.append(.init(
        handle: 2_077,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "RASBot3",
        flags: 5_121,
        doorShields: nil,
        location: .room(42),
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_077,
        primaryModel: robotModel,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil
    ))
    return level.addingTrainingRASBot3DeathChain(.init(
        robotObjectHandle: 2_077,
        robotRoomSourceIndex: 42,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
}

func makeTrainingRASBot4DeathLevel() -> Level {
    var level = makeTrainingRASBot3DeathLevel()
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    guard case let .room(playerRoomSourceIndex) = player.location,
          let playerRoom = level.rooms.first(where: {
              $0.sourceIndex == playerRoomSourceIndex
          }) else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    if !level.rooms.contains(where: { $0.sourceIndex == 0 }) {
        level.rooms.append(.init(
            sourceIndex: 0,
            name: "RASBot4 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let robotModel = level.objectPresentations.first {
        $0.objectHandle == 2_077
    }!.primaryModel
    let robotPosition = Vector3(
        x: player.position.x + player.orientation.forward.x * 20,
        y: player.position.y + player.orientation.forward.y * 20,
        z: player.position.z + player.orientation.forward.z * 20
    )
    level.objects.append(.init(
        handle: 2_078,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "RASBot4",
        flags: 5_121,
        doorShields: nil,
        location: .room(0),
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_078,
        primaryModel: robotModel,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil
    ))
    return level.addingTrainingRASBot4DeathChain(.init(
        robotObjectHandle: 2_078,
        robotRoomSourceIndex: 0,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
}

func makeTrainingInvulnerabilityPickupLevel() -> Level {
    var level = makeTrainingRASBot4DeathLevel()
    let playerIndex = level.objects.firstIndex {
        $0.handle == 2_048
    }!
    let originalPlayer = level.objects[playerIndex]
    let originalRoomSourceIndex: Int
    if case .room(let sourceIndex) = originalPlayer.location {
        originalRoomSourceIndex = sourceIndex
    } else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    let originalRoom = level.rooms.first {
        $0.sourceIndex == originalRoomSourceIndex
    }!
    level.rooms.append(
        .init(
            sourceIndex: 12,
            name: "Invuln Room",
            pathPoint: originalRoom.pathPoint,
            vertices: originalRoom.vertices,
            faces: originalRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: originalRoom.flags,
            pulseTime: originalRoom.pulseTime,
            pulseOffset: originalRoom.pulseOffset,
            mirrorFaceIndex: originalRoom.mirrorFaceIndex,
            door: originalRoom.door,
            volumeLights: originalRoom.volumeLights,
            fog: originalRoom.fog,
            ambientSoundPattern: originalRoom.ambientSoundPattern,
            reverb: originalRoom.reverb,
            damage: originalRoom.damage,
            damageType: originalRoom.damageType
        ))
    let pickupRoom = level.rooms.last!
    let player = level.objects[playerIndex]
    let presentation = level.objectPresentations.first {
        $0.objectHandle == 2_078
    }!
    let model = level.models.first {
        $0.source == presentation.primaryModel
    }!
    level.objects.append(
        .init(
            handle: 2_076,
            type: 7,
            storedID: 3,
            definition: .init(
                storedIndex: 3,
                sourceName: "Invulnerability"
            ),
            instanceName: "InvulnPowerup2",
            flags: 5_120,
            doorShields: nil,
            location: .room(12),
            position: pickupRoom.pathPoint,
            orientation: player.orientation,
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        ))
    level.objectPresentations.append(
        .init(
            objectHandle: 2_076,
            primaryModel: model.source,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        ))
    let template = level.soundClips.first!
    let pickup = CanonicalSoundClip(
        logicalName: "Powerup pickup",
        sourceName: "Power03.wav",
        sourceEntryIndex: 499,
        sampleRate: template.sampleRate,
        channelCount: template.channelCount,
        frameCount: template.frameCount,
        pcm16LittleEndian: template.pcm16LittleEndian,
        pcmSHA256: template.pcmSHA256,
        sourceArchive: template.sourceArchive,
        sourceSHA256: template.sourceSHA256,
        importVolume: 1
    )
    let activated = CanonicalSoundClip(
        logicalName: "Invulnerability on",
        sourceName: "Invon.wav",
        sourceEntryIndex: 500,
        sampleRate: template.sampleRate,
        channelCount: template.channelCount,
        frameCount: template.frameCount,
        pcm16LittleEndian: template.pcm16LittleEndian,
        pcmSHA256: template.pcmSHA256,
        sourceArchive: template.sourceArchive,
        sourceSHA256: template.sourceSHA256,
        importVolume: 0.5
    )
    let expired = CanonicalSoundClip(
        logicalName: "Invulnerability off",
        sourceName: "Invoff.wav",
        sourceEntryIndex: 501,
        sampleRate: template.sampleRate,
        channelCount: template.channelCount,
        frameCount: template.frameCount,
        pcm16LittleEndian: template.pcm16LittleEndian,
        pcmSHA256: template.pcmSHA256,
        sourceArchive: template.sourceArchive,
        sourceSHA256: template.sourceSHA256,
        importVolume: 0.5
    )
    return level.addingTrainingInvulnerabilityPickupChain(
        .init(
            pickupObjectHandle: 2_076,
            pickupRoomSourceIndex: 12,
            pickupObjectFlags: 5_120,
            pickupCollisionRadius: model.collisionRadius,
            duration: 30,
            activatedMessage: "Invulnerability On",
            expiredMessage: "Invulnerability Off",
            pickupSoundSourceName: "Power03.wav",
            activatedSoundSourceName: "Invon.wav",
            expiredSoundSourceName: "Invoff.wav"
        ),
        soundClips: [pickup, activated, expired]
    )
}

func makeTrainingCloakPickupLevel() -> Level {
    var level = makeTrainingInvulnerabilityPickupLevel()
    if !level.rooms.contains(where: { $0.sourceIndex == 11 }) {
        let template = level.rooms.first { $0.sourceIndex == 12 }!
        level.rooms.append(.init(
            sourceIndex: 11,
            name: "Cloak Room",
            pathPoint: template.pathPoint,
            vertices: template.vertices,
            faces: template.faces,
            portals: [],
            flags: template.flags,
            pulseTime: template.pulseTime,
            pulseOffset: template.pulseOffset,
            mirrorFaceIndex: template.mirrorFaceIndex,
            door: template.door,
            volumeLights: template.volumeLights,
            fog: template.fog,
            ambientSoundPattern: template.ambientSoundPattern,
            reverb: template.reverb,
            damage: template.damage,
            damageType: template.damageType
        ))
    }
    let pickupRoom = level.rooms.first { $0.sourceIndex == 11 }!
    let player = level.objects.first { $0.handle == 2_048 }!
    let presentation = level.objectPresentations.first {
        $0.objectHandle == 2_076
    }!
    let modelTemplate = level.models.first {
        $0.source == presentation.primaryModel
    }!
    let cloakModelSources = [
        SourceResource(storedIndex: 20, sourceName: "cloak.OOF"),
        SourceResource(storedIndex: 21, sourceName: "CloakMed.OOF"),
        SourceResource(storedIndex: 22, sourceName: "CloakLow.OOF"),
    ]
    let cloakModelHashes = [
        "ccce90c9dbc266c0a22ab00339689059888719b212116191049ef4396ebc5baa",
        "7b6e66b1ad23328b43dc007de7cb2b8806397f69bab95647e350554f479e0c6b",
        "38754663d76df10a7d6d41e241cfe2fc08b9f7fb99addb41cb5ed1fc205f119f",
    ]
    let cloakModels = zip(cloakModelSources, cloakModelHashes).map {
        source, hash in
        CanonicalModel(
            source: source,
            collisionRadius:
                source == cloakModelSources[0]
                    ? 1.223_636_7
                    : modelTemplate.collisionRadius,
            submodels: modelTemplate.submodels,
            bounds: modelTemplate.bounds,
            sourceArchive: "d3.hog",
            sourceSHA256: hash
        )
    }
    level = replacing(
        level,
        source: replacing(
            level.source,
            profileFiles:
                level.source.profileFiles
                + [
                    .init(
                        relativePath: "d3.hog",
                        byteCount: 194_030_423,
                        sha256:
                            "a0f1cb2c1a73da828a5fd4e80d6544b63da04e177dc2b894d9e6418296bc24c6"
                    )
                ]
        ),
        models: level.models + cloakModels,
        dependencyManifest: .init(
            current:
                level.dependencyManifest.current
                + cloakModelSources.map {
                    DependencyRecord(
                        category: "model",
                        source: $0,
                        state: "presentation-payload-imported",
                        provenance: "d3.hog"
                    )
                },
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    level.objects.append(.init(
        handle: 2_073,
        type: 7,
        storedID: 4,
        definition: .init(storedIndex: 4, sourceName: "Cloak"),
        instanceName: "CloakPowerup2",
        flags: 5_120,
        doorShields: nil,
        location: .room(11),
        position: pickupRoom.pathPoint,
        orientation: player.orientation,
        containsType: 255,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_073,
        primaryModel: cloakModelSources[0],
        mediumModel: cloakModelSources[1],
        lowModel: cloakModelSources[2],
        dyingModel: nil,
        mediumDistance: 35,
        lowDistance: 50
    ))
    let pickupPCM = Data(repeating: 0, count: 15_189 * 2)
    let pickup = CanonicalSoundClip(
        logicalName: "Powerup pickup",
        sourceName: "Power03.wav",
        sourceEntryIndex: 2_657,
        sampleRate: 22_050,
        channelCount: 1,
        frameCount: 15_189,
        pcm16LittleEndian: pickupPCM,
        pcmSHA256: canonicalSHA256(pickupPCM),
        sourceArchive: "d3.hog",
        sourceSHA256:
            "1e16aae37b233dd724d4baa001f48b83681fbc33eb16d21269cd52c5b7e8cea3",
        importVolume: 1
    )
    level = replacing(
        level,
        soundClips:
            level.soundClips.filter { $0.sourceName != "Power03.wav" }
            + [pickup],
        dependencyManifest: .init(
            current: level.dependencyManifest.current.filter {
                !(
                    $0.category == "sound"
                        && $0.source.sourceName == "Power03.wav"
                )
            } + [
                .init(
                    category: "sound",
                    source: .init(
                        storedIndex: pickup.sourceEntryIndex,
                        sourceName: pickup.sourceName
                    ),
                    state: "canonical-pcm-imported",
                    provenance:
                        "\(pickup.sourceArchive) \(pickup.sourceSHA256)"
                )
            ],
            historicalEagerBaseline:
                level.dependencyManifest.historicalEagerBaseline
        )
    )
    let cloakOnPCM = Data(repeating: 0, count: 33_046 * 2)
    let cloakOn = CanonicalSoundClip(
        logicalName: "Cloak on",
        sourceName: "ShpCloakOn.wav",
        sourceEntryIndex: 3_247,
        sampleRate: 22_050,
        channelCount: 1,
        frameCount: 33_046,
        pcm16LittleEndian: cloakOnPCM,
        pcmSHA256: canonicalSHA256(cloakOnPCM),
        sourceArchive: "d3.hog",
        sourceSHA256:
            "27d19947e58370b18722fbcbe2fba64bf5094e3752a069bd1d2e1ed76e70c58e",
        importVolume: 0.5
    )
    let cloakOffPCM = Data(repeating: 0, count: 45_609 * 2)
    let cloakOff = CanonicalSoundClip(
        logicalName: "Cloak off",
        sourceName: "ShpCloakOffBeep.wav",
        sourceEntryIndex: 3_246,
        sampleRate: 22_050,
        channelCount: 1,
        frameCount: 45_609,
        pcm16LittleEndian: cloakOffPCM,
        pcmSHA256: canonicalSHA256(cloakOffPCM),
        sourceArchive: "d3.hog",
        sourceSHA256:
            "29c9bb2fe254a9c2e75b8ae0f13b60627088294f075fbd74eae449e76c767154",
        importVolume: 0.5
    )
    let cloakLevel = level.addingTrainingCloakPickupChain(
        .init(
            pickupObjectHandle: 2_073,
            pickupRoomSourceIndex: 11,
            pickupObjectFlags: 5_120,
            pickupCollisionRadius: cloakModels[0].collisionRadius,
            fadeDuration: 1,
            cloakDuration: 30,
            activatedMessage: "Cloak On",
            expiredMessage: "Cloak Off",
            pickupSoundSourceName: "Power03.wav",
            activatedSoundSourceName: "ShpCloakOn.wav",
            expiredSoundSourceName: "ShpCloakOffBeep.wav"
        ),
        soundClips: [cloakOn, cloakOff]
    )
    var lastRoomLevel = cloakLevel
    let lastRoomTemplate = lastRoomLevel.rooms.first {
        $0.sourceIndex == 2
    }!
    precondition(lastRoomTemplate.portals.count == 2)
    var lastRoomPortals: [LevelPortal] = []
    var connectedRooms: [LevelRoom] = []
    for portalIndex in lastRoomTemplate.portals.indices {
        let sourcePortal = lastRoomTemplate.portals[portalIndex]
        let sourceConnectedRoom = lastRoomLevel.rooms.first {
            $0.sourceIndex == sourcePortal.connectedRoom
        }!
        let sourceReciprocal =
            sourceConnectedRoom.portals[sourcePortal.connectedPortal]
        let connectedSourceIndex = portalIndex == 0 ? 41 : 45
        let connectedPortalIndex = portalIndex == 0 ? 3 : 0
        lastRoomPortals.append(.init(
            flags: 1,
            faceIndex: sourcePortal.faceIndex,
            connectedRoom: connectedSourceIndex,
            connectedPortal: connectedPortalIndex,
            boundaryNodeIndex: -1,
            pathPoint: sourcePortal.pathPoint,
            combineMaster: -1
        ))
        var connectedFaces = sourceConnectedRoom.faces.enumerated().map {
            faceIndex, face in
            LevelFace(
                corners: face.corners,
                flags: face.flags,
                portalIndex:
                    faceIndex == sourceReciprocal.faceIndex
                        ? connectedPortalIndex : nil,
                texture: face.texture,
                lightmapInfoIndex: face.lightmapInfoIndex,
                allowsLightCorona: face.allowsLightCorona,
                lightMultiple: face.lightMultiple,
                special: face.special
            )
        }
        var connectedPortals: [LevelPortal] = []
        if portalIndex == 0 {
            for auxiliaryPortalIndex in 0..<3 {
                let faceIndex = connectedFaces.count
                connectedFaces.append(.init(
                    corners: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].corners,
                    flags: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].flags,
                    portalIndex: auxiliaryPortalIndex,
                    texture: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].texture,
                    lightmapInfoIndex: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].lightmapInfoIndex,
                    allowsLightCorona: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].allowsLightCorona,
                    lightMultiple: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].lightMultiple,
                    special: sourceConnectedRoom.faces[
                        sourceReciprocal.faceIndex
                    ].special
                ))
                connectedPortals.append(.init(
                    flags: 1,
                    faceIndex: faceIndex,
                    connectedRoom: 60 + auxiliaryPortalIndex,
                    connectedPortal: 0,
                    boundaryNodeIndex: -1,
                    pathPoint: sourceReciprocal.pathPoint,
                    combineMaster: -1
                ))
                let auxiliaryFace = lastRoomTemplate.faces[
                    sourcePortal.faceIndex
                ]
                connectedRooms.append(.init(
                    sourceIndex: 60 + auxiliaryPortalIndex,
                    name: "P6 auxiliary \(auxiliaryPortalIndex)",
                    pathPoint: lastRoomTemplate.pathPoint,
                    vertices: lastRoomTemplate.vertices,
                    faces: [
                        .init(
                            corners: auxiliaryFace.corners,
                            flags: auxiliaryFace.flags,
                            portalIndex: 0,
                            texture: auxiliaryFace.texture,
                            lightmapInfoIndex:
                                auxiliaryFace.lightmapInfoIndex,
                            allowsLightCorona:
                                auxiliaryFace.allowsLightCorona,
                            lightMultiple: auxiliaryFace.lightMultiple,
                            special: auxiliaryFace.special
                        )
                    ],
                    portals: [
                        .init(
                            flags: 1,
                            faceIndex: 0,
                            connectedRoom: 41,
                            connectedPortal: auxiliaryPortalIndex,
                            boundaryNodeIndex: -1,
                            pathPoint: sourcePortal.pathPoint,
                            combineMaster: -1
                        )
                    ],
                    flags: lastRoomTemplate.flags,
                    pulseTime: lastRoomTemplate.pulseTime,
                    pulseOffset: lastRoomTemplate.pulseOffset,
                    mirrorFaceIndex: lastRoomTemplate.mirrorFaceIndex,
                    door: lastRoomTemplate.door,
                    volumeLights: lastRoomTemplate.volumeLights,
                    fog: lastRoomTemplate.fog,
                    ambientSoundPattern:
                        lastRoomTemplate.ambientSoundPattern,
                    reverb: lastRoomTemplate.reverb,
                    damage: lastRoomTemplate.damage,
                    damageType: lastRoomTemplate.damageType
                ))
            }
        }
        connectedPortals.append(.init(
            flags: 1,
            faceIndex: sourceReciprocal.faceIndex,
            connectedRoom: 44,
            connectedPortal: portalIndex,
            boundaryNodeIndex: -1,
            pathPoint: sourceReciprocal.pathPoint,
            combineMaster: -1
        ))
        connectedRooms.append(.init(
            sourceIndex: connectedSourceIndex,
            name: "P6 neighbor \(portalIndex)",
            pathPoint: sourceConnectedRoom.pathPoint,
            vertices: sourceConnectedRoom.vertices,
            faces: connectedFaces,
            portals: connectedPortals,
            flags: sourceConnectedRoom.flags,
            pulseTime: sourceConnectedRoom.pulseTime,
            pulseOffset: sourceConnectedRoom.pulseOffset,
            mirrorFaceIndex: sourceConnectedRoom.mirrorFaceIndex,
            door: sourceConnectedRoom.door,
            volumeLights: sourceConnectedRoom.volumeLights,
            fog: sourceConnectedRoom.fog,
            ambientSoundPattern:
                sourceConnectedRoom.ambientSoundPattern,
            reverb: sourceConnectedRoom.reverb,
            damage: sourceConnectedRoom.damage,
            damageType: sourceConnectedRoom.damageType
        ))
    }
    let lastRoom = LevelRoom(
        sourceIndex: 44,
        name: "PortalRoom6",
        pathPoint: lastRoomTemplate.pathPoint,
        vertices: lastRoomTemplate.vertices,
        faces: lastRoomTemplate.faces,
        portals: lastRoomPortals,
        flags: lastRoomTemplate.flags,
        pulseTime: lastRoomTemplate.pulseTime,
        pulseOffset: lastRoomTemplate.pulseOffset,
        mirrorFaceIndex: lastRoomTemplate.mirrorFaceIndex,
        door: lastRoomTemplate.door,
        volumeLights: lastRoomTemplate.volumeLights,
        fog: lastRoomTemplate.fog,
        ambientSoundPattern: lastRoomTemplate.ambientSoundPattern,
        reverb: lastRoomTemplate.reverb,
        damage: lastRoomTemplate.damage,
        damageType: lastRoomTemplate.damageType
    )
    lastRoomLevel.rooms.append(contentsOf: [lastRoom] + connectedRooms)
    lastRoomLevel.objects.append(.init(
        handle: 4_117,
        type: 11,
        storedID: 205,
        definition: .init(
            storedIndex: 205,
            sourceName: "Blinking Red Light-DM"
        ),
        instanceName: "FlashLight-4",
        flags: 4_096,
        doorShields: nil,
        location: .room(44),
        position: lastRoom.pathPoint,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    return lastRoomLevel.addingTrainingLastRoomChain(.init(
        barrierRoomSourceIndex: 44,
        orderedPortalIndices: [1, 0],
        markerLightObjectHandle: 4_117,
        markerLightPresentation: .init(
            primaryColor: .init(x: 1, y: 0.25, z: 0),
            secondaryColor: .zero,
            timeInterval: 0.5,
            flickerDistance: 0.2,
            directionalDot: 0,
            flags: 4,
            timebits: .max,
            angle: 0,
            lightingRenderType: 2
        ),
        openMarkerLightDistance: 50,
        timerDuration: 2,
        completionMessages: [
            "Excellent!",
            "Now proceed through the doorway that just opened to begin the last stage of your training.",
        ],
        completionVoiceSourceName: "proceed5.osf"
    ))
}

func makeTrainingFinalRoomEntryLevel() -> Level {
    let level = makeTrainingCloakPickupLevel()
    let chain = TrainingFinalRoomEntryChain(
        triggerName: "Portal4",
        triggerRoomSourceIndex: 44,
        triggerFaceIndex: 1,
        successMessage: "Excellent!",
        instructionMessage:
            "Now for your final and most difficult task. Locate and destroy the last 5 robots.",
        voiceSourceName: "intro7.osf"
    )
    let trigger = LevelTrigger(
        name: chain.triggerName,
        roomIndex: chain.triggerRoomSourceIndex,
        faceIndex: chain.triggerFaceIndex,
        flags: 8,
        activator: 1
    )
    let pcm = Data(repeating: 0, count: 2)
    return replacing(
        level,
        triggers: level.triggers + [trigger]
    ).addingTrainingFinalRoomEntryChain(
        chain,
        voiceClip: .init(
            sourceName: chain.voiceSourceName,
            sourceEntryIndex: 16,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: pcm,
            pcmSHA256: canonicalSHA256(pcm),
            sourceArchive: "missions/training.mn3",
            sourceSHA256:
                "7348ded9ee2c6735ea712b52647f0bfa7478a508c03c10af5f837741a836c67f"
        )
    )
}

func makeTrainingLastBot1DeathLevel() -> Level {
    var level = makeTrainingFinalRoomEntryLevel()
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    guard case let .room(playerRoomSourceIndex) = player.location,
          let playerRoom = level.rooms.first(where: {
              $0.sourceIndex == playerRoomSourceIndex
          }) else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    if !level.rooms.contains(where: { $0.sourceIndex == 14 }) {
        level.rooms.append(.init(
            sourceIndex: 14,
            name: "LastBot1 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let robotModel = level.objectPresentations.first {
        $0.objectHandle == 2_078
    }!.primaryModel
    let robotPosition = Vector3(
        x: player.position.x
            + player.orientation.forward.x * 20,
        y: player.position.y
            + player.orientation.forward.y * 20,
        z: player.position.z
            + player.orientation.forward.z * 20
    )
    level.objects.append(.init(
        handle: 4_127,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "LastBot1",
        flags: 5_121,
        doorShields: nil,
        location: .room(14),
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 4_127,
        primaryModel: robotModel,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil
    ))
    return level.addingTrainingLastBot1DeathChain(.init(
        robotObjectHandle: 4_127,
        robotRoomSourceIndex: 14,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
}

func makeTrainingLastBot2DeathLevel() -> Level {
    var level = makeTrainingLastBot1DeathLevel()
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    guard case let .room(playerRoomSourceIndex) = player.location,
          let playerRoom = level.rooms.first(where: {
              $0.sourceIndex == playerRoomSourceIndex
          }) else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    if !level.rooms.contains(where: { $0.sourceIndex == 46 }) {
        level.rooms.append(.init(
            sourceIndex: 46,
            name: "LastBot2 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let lastBot1Presentation = level.objectPresentations.first {
        $0.objectHandle == 4_127
    }!
    let robotPosition = Vector3(
        x: player.position.x
            + player.orientation.forward.x * 30,
        y: player.position.y
            + player.orientation.forward.y * 30,
        z: player.position.z
            + player.orientation.forward.z * 30
    )
    level.objects.append(.init(
        handle: 2_080,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "LastBot2",
        flags: 5_121,
        doorShields: nil,
        location: .room(46),
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_080,
        primaryModel: lastBot1Presentation.primaryModel,
        mediumModel: lastBot1Presentation.mediumModel,
        lowModel: lastBot1Presentation.lowModel,
        dyingModel: lastBot1Presentation.dyingModel,
        mediumDistance: lastBot1Presentation.mediumDistance,
        lowDistance: lastBot1Presentation.lowDistance
    ))
    return level.addingTrainingLastBot2DeathChain(.init(
        robotObjectHandle: 2_080,
        robotRoomSourceIndex: 46,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
}

func makeTrainingLastBot3DeathLevel() -> Level {
    var level = makeTrainingLastBot2DeathLevel()
    let playerIndex = level.objects.firstIndex { $0.handle == 2_048 }!
    let player = level.objects[playerIndex]
    guard case let .room(playerRoomSourceIndex) = player.location,
          let playerRoom = level.rooms.first(where: {
              $0.sourceIndex == playerRoomSourceIndex
          }) else {
        preconditionFailure("Synthetic Training player is indoor")
    }
    if !level.rooms.contains(where: { $0.sourceIndex == 47 }) {
        level.rooms.append(.init(
            sourceIndex: 47,
            name: "LastBot3 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let lastBot2Presentation = level.objectPresentations.first {
        $0.objectHandle == 2_080
    }!
    let robotPosition = Vector3(
        x: player.position.x
            + player.orientation.forward.x * 30,
        y: player.position.y
            + player.orientation.forward.y * 30,
        z: player.position.z
            + player.orientation.forward.z * 30
    )
    level.objects.append(.init(
        handle: 2_081,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "LastBot3",
        flags: 5_121,
        doorShields: nil,
        location: .room(47),
        position: robotPosition,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_081,
        primaryModel: lastBot2Presentation.primaryModel,
        mediumModel: lastBot2Presentation.mediumModel,
        lowModel: lastBot2Presentation.lowModel,
        dyingModel: lastBot2Presentation.dyingModel,
        mediumDistance: lastBot2Presentation.mediumDistance,
        lowDistance: lastBot2Presentation.lowDistance
    ))
    return level.addingTrainingLastBot3DeathChain(.init(
        robotObjectHandle: 2_081,
        robotRoomSourceIndex: 47,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
}

func makeTrainingLastBot4DeathLevel() -> Level {
    var level = makeTrainingLastBot3DeathLevel()
    let lastBot3 = level.objects.first { $0.handle == 2_081 }!
    let lastBot3Presentation = level.objectPresentations.first {
        $0.objectHandle == 2_081
    }!
    level.objects.append(.init(
        handle: 2_082,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "LastBot4",
        flags: 5_121,
        doorShields: nil,
        location: .room(47),
        position: lastBot3.position,
        orientation: lastBot3.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_082,
        primaryModel: lastBot3Presentation.primaryModel,
        mediumModel: lastBot3Presentation.mediumModel,
        lowModel: lastBot3Presentation.lowModel,
        dyingModel: lastBot3Presentation.dyingModel,
        mediumDistance: lastBot3Presentation.mediumDistance,
        lowDistance: lastBot3Presentation.lowDistance
    ))
    return level.addingTrainingLastBot4DeathChain(.init(
        robotObjectHandle: 2_082,
        robotRoomSourceIndex: 47,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
}

func makeTrainingLastBot5DeathLevel() -> Level {
    var level = makeTrainingLastBot4DeathLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let playerRoomSourceIndex: Int
    switch player.location {
    case let .room(sourceIndex):
        playerRoomSourceIndex = sourceIndex
    case .terrainCell:
        preconditionFailure("Synthetic Training player is indoor")
    }
    let playerRoom = level.rooms.first {
        $0.sourceIndex == playerRoomSourceIndex
    }!
    if !level.rooms.contains(where: { $0.sourceIndex == 48 }) {
        level.rooms.append(.init(
            sourceIndex: 48,
            name: "LastBot5 Room",
            pathPoint: playerRoom.pathPoint,
            vertices: playerRoom.vertices,
            faces: playerRoom.faces.map {
                .init(
                    corners: $0.corners,
                    flags: $0.flags,
                    portalIndex: nil,
                    texture: $0.texture,
                    lightmapInfoIndex: nil,
                    allowsLightCorona: $0.allowsLightCorona,
                    lightMultiple: $0.lightMultiple,
                    special: $0.special
                )
            },
            portals: [],
            flags: playerRoom.flags,
            pulseTime: playerRoom.pulseTime,
            pulseOffset: playerRoom.pulseOffset,
            mirrorFaceIndex: playerRoom.mirrorFaceIndex,
            door: playerRoom.door,
            volumeLights: playerRoom.volumeLights,
            fog: playerRoom.fog,
            ambientSoundPattern: playerRoom.ambientSoundPattern,
            reverb: playerRoom.reverb,
            damage: playerRoom.damage,
            damageType: playerRoom.damageType
        ))
    }
    let lastBot4 = level.objects.first { $0.handle == 2_082 }!
    let lastBot4Presentation = level.objectPresentations.first {
        $0.objectHandle == 2_082
    }!
    level.objects.append(.init(
        handle: 2_083,
        type: 2,
        storedID: 106,
        definition: .init(
            storedIndex: 106,
            sourceName: "RAS1 Light Security Flyer"
        ),
        instanceName: "LastBot5",
        flags: 5_121,
        doorShields: nil,
        location: .room(48),
        position: lastBot4.position,
        orientation: lastBot4.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    level.objectPresentations.append(.init(
        objectHandle: 2_083,
        primaryModel: lastBot4Presentation.primaryModel,
        mediumModel: lastBot4Presentation.mediumModel,
        lowModel: lastBot4Presentation.lowModel,
        dyingModel: lastBot4Presentation.dyingModel,
        mediumDistance: lastBot4Presentation.mediumDistance,
        lowDistance: lastBot4Presentation.lowDistance
    ))
    return level.addingTrainingLastBot5DeathChain(.init(
        robotObjectHandle: 2_083,
        robotRoomSourceIndex: 48,
        robotFlags: 5_121,
        combat: .stockTraining
    ))
}

func makeTrainingFinalBotsCompletionLevel() -> Level {
    var level = makeTrainingLastBot5DeathLevel()
    let template = level.rooms.first {
        $0.sourceIndex == 2
    }!
    precondition(template.portals.count == 2)
    var barrierPortals: [LevelPortal] = []
    var connectedRooms: [LevelRoom] = []
    for portalIndex in template.portals.indices {
        let sourcePortal = template.portals[portalIndex]
        let sourceConnectedRoom = level.rooms.first {
            $0.sourceIndex == sourcePortal.connectedRoom
        }!
        let reciprocal =
            sourceConnectedRoom.portals[sourcePortal.connectedPortal]
        let connectedSourceIndex = 70 + portalIndex
        barrierPortals.append(.init(
            flags: 1,
            faceIndex: sourcePortal.faceIndex,
            connectedRoom: connectedSourceIndex,
            connectedPortal: 0,
            boundaryNodeIndex: -1,
            pathPoint: sourcePortal.pathPoint,
            combineMaster: -1
        ))
        connectedRooms.append(.init(
            sourceIndex: connectedSourceIndex,
            name: "P7 neighbor \(portalIndex)",
            pathPoint: sourceConnectedRoom.pathPoint,
            vertices: sourceConnectedRoom.vertices,
            faces: sourceConnectedRoom.faces.enumerated().map {
                faceIndex, face in
                .init(
                    corners: face.corners,
                    flags: face.flags,
                    portalIndex:
                        faceIndex == reciprocal.faceIndex ? 0 : nil,
                    texture: face.texture,
                    lightmapInfoIndex: face.lightmapInfoIndex,
                    allowsLightCorona: face.allowsLightCorona,
                    lightMultiple: face.lightMultiple,
                    special: face.special
                )
            },
            portals: [
                .init(
                    flags: 1,
                    faceIndex: reciprocal.faceIndex,
                    connectedRoom: 16,
                    connectedPortal: portalIndex,
                    boundaryNodeIndex: -1,
                    pathPoint: reciprocal.pathPoint,
                    combineMaster: -1
                )
            ],
            flags: sourceConnectedRoom.flags,
            pulseTime: sourceConnectedRoom.pulseTime,
            pulseOffset: sourceConnectedRoom.pulseOffset,
            mirrorFaceIndex: sourceConnectedRoom.mirrorFaceIndex,
            door: sourceConnectedRoom.door,
            volumeLights: sourceConnectedRoom.volumeLights,
            fog: sourceConnectedRoom.fog,
            ambientSoundPattern:
                sourceConnectedRoom.ambientSoundPattern,
            reverb: sourceConnectedRoom.reverb,
            damage: sourceConnectedRoom.damage,
            damageType: sourceConnectedRoom.damageType
        ))
    }
    let barrier = LevelRoom(
        sourceIndex: 16,
        name: "PortalRoom7",
        pathPoint: template.pathPoint,
        vertices: template.vertices,
        faces: template.faces,
        portals: barrierPortals,
        flags: template.flags,
        pulseTime: template.pulseTime,
        pulseOffset: template.pulseOffset,
        mirrorFaceIndex: template.mirrorFaceIndex,
        door: template.door,
        volumeLights: template.volumeLights,
        fog: template.fog,
        ambientSoundPattern: template.ambientSoundPattern,
        reverb: template.reverb,
        damage: template.damage,
        damageType: template.damageType
    )
    level.rooms.append(contentsOf: [barrier] + connectedRooms)
    let player = level.objects.first {
        $0.handle == 2_048
    }!
    level.objects.append(.init(
        handle: 4_118,
        type: 11,
        storedID: 205,
        definition: .init(
            storedIndex: 205,
            sourceName: "Blinking Red Light-DM"
        ),
        instanceName: "FlashLight-5",
        flags: 4_096,
        doorShields: nil,
        location: .room(16),
        position: barrier.pathPoint,
        orientation: player.orientation,
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    ))
    let chain = TrainingFinalBotsCompletionChain(
        barrierRoomSourceIndex: 16,
        orderedPortalIndices: [0, 1],
        markerLightObjectHandle: 4_118,
        markerLightPresentation: .init(
            primaryColor: .init(x: 1, y: 0.25, z: 0),
            secondaryColor: .zero,
            timeInterval: 0.5,
            flickerDistance: 0.2,
            directionalDot: 0,
            flags: 4,
            timebits: .max,
            angle: 0,
            lightingRenderType: 2
        ),
        openMarkerLightDistance: 50,
        timerDuration: 2,
        completionMessage:
            "Great Job! Now fly through the opened doorway to end your training. Good job Recruit!",
        completionVoiceSourceName: "done.osf"
    )
    let pcm = Data(repeating: 0, count: 2)
    return level.addingTrainingFinalBotsCompletionChain(
        chain,
        voiceClip: .init(
            sourceName: chain.completionVoiceSourceName,
            sourceEntryIndex: 9,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 1,
            pcm16LittleEndian: pcm,
            pcmSHA256: canonicalSHA256(pcm),
            sourceArchive: "missions/training.mn3",
            sourceSHA256: canonicalSHA256(pcm)
        )
    )
}

func makeTrainingFinalGoalLevel() -> Level {
    var level = makeTrainingFinalBotsCompletionLevel()
    let roomTemplate = level.rooms.first {
        $0.sourceIndex == 1
    }!
    let player = level.objects.first { $0.handle == 2_048 }!
    let room = makeSourceContainmentRoom(
        center: player.position,
        texture: roomTemplate.faces[0].texture,
        sourceIndex: 17,
        halfExtent: 100
    )
    level.rooms.removeAll { $0.sourceIndex == 17 }
    level.rooms.append(room)
    let goal = PlacedObject(
        handle: 6_180,
        type: 7,
        storedID: 67,
        definition: .init(
            storedIndex: 67,
            sourceName: "Invisiblepowerup"
        ),
        instanceName: "FinalGoal",
        flags: 4_096,
        doorShields: nil,
        location: .room(17),
        position: player.position,
        orientation: .init(
            right: .init(x: -1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: -1)
        ),
        containsType: 0,
        containsID: 0,
        containsCount: 0,
        lifeLeft: 0,
        soundSource: nil,
        inertScriptName: nil,
        inertModuleName: nil,
        lightmapSubmodels: []
    )
    level.objects.append(goal)
    let modelSource = SourceResource(
        storedIndex: 4,
        sourceName: "invisiblepowerup.OOF"
    )
    level.objectPresentations.append(.init(
        objectHandle: goal.handle,
        primaryModel: modelSource,
        mediumModel: nil,
        lowModel: nil,
        dyingModel: nil,
        mediumDistance: nil,
        lowDistance: nil,
        isVisible: false
    ))
    var models = level.models
    if let modelIndex = models.firstIndex(where: {
        $0.source == modelSource
    }) {
        let model = models[modelIndex]
        models[modelIndex] = CanonicalModel(
            source: model.source,
            collisionRadius: Float(bitPattern: 0x40a0_84bf),
            submodels: model.submodels,
            bounds: model.bounds,
            sourceArchive: model.sourceArchive,
            sourceSHA256: model.sourceSHA256
        )
    }
    level = replacing(
        level,
        metadata: .init(
            name: "Training Mission",
            designer: level.metadata.designer,
            copyright: level.metadata.copyright,
            notes: level.metadata.notes,
            gravity: level.metadata.gravity,
            alwaysCheckCeiling: level.metadata.alwaysCheckCeiling,
            ceilingHeight: level.metadata.ceilingHeight
        ),
        models: models
    )
    return level.addingTrainingFinalGoalChain(.init(
        goalObjectHandle: goal.handle,
        goalRoomSourceIndex: 17,
        goalObjectFlags: goal.flags,
        goalCollisionRadius: Float(bitPattern: 0x40a0_84bf)
    ))
}

func replacingTrainingRoom(
    _ room: LevelRoom,
    sourceIndex: Int,
    portals: [LevelPortal]
) -> LevelRoom {
    LevelRoom(
        sourceIndex: sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: room.vertices,
        faces: room.faces,
        portals: portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
}

func script050ReadyContinuation(
    in level: Level,
    timerRemaining: Float = 1.5
) throws -> PlayerSimulationContinuation {
    let chain = try XCTUnwrap(level.trainingFinalRoomEntryChain)
    let room = try XCTUnwrap(level.rooms.first {
        $0.sourceIndex == chain.triggerRoomSourceIndex
    })
    let face = room.faces[chain.triggerFaceIndex]
    let centerSum = face.corners.reduce(Vector3.zero) {
        let vertex = room.vertices[$1.vertexIndex]
        return .init(
            x: $0.x + vertex.x,
            y: $0.y + vertex.y,
            z: $0.z + vertex.z
        )
    }
    let divisor = Float(face.corners.count)
    let center = Vector3(
        x: centerSum.x / divisor,
        y: centerSum.y / divisor,
        z: centerSum.z / divisor
    )
    let normal = try XCTUnwrap(
        canonicalFaceNormal(room: room, face: face)
    )
    let playerRadius = defaultPlayerView(in: level).collisionRadius
    let initial = PlayerSimulation(
        level: level,
        presentationReadyTimestamp: 0
    )
    var object = try XCTUnwrap(
        JSONSerialization.jsonObject(
            with: JSONEncoder().encode(initial.continuation)
        ) as? [String: Any]
    )
    for key in [
        "trainingRASBot1DeathState",
        "trainingRASBot2DeathState",
        "trainingRASBot3DeathState",
        "trainingRASBot4DeathState",
    ] {
        object[key] = [
            "wasDestroyed": true,
            "shields": -5,
        ]
    }
    object["trainingInvulnerabilityPickupState"] = [
        "scriptWasTriggered": true,
        "wasConsumed": true,
    ]
    object["trainingCloakPickupState"] = [
        "scriptWasTriggered": true,
        "wasConsumed": true,
    ]
    object["trainingLastRoomState"] = [
        "wasTriggered": true,
        "markerLightDistance": 50,
        "timerRemaining": timerRemaining,
        "wasPresented": false,
    ]
    object["playerLocation"] = [
        "room": ["_0": chain.triggerRoomSourceIndex]
    ]
    object["playerPosition"] = [
        "x": center.x + normal.x * (playerRadius + 1),
        "y": center.y + normal.y * (playerRadius + 1),
        "z": center.z + normal.z * (playerRadius + 1),
    ]
    object["velocity"] = [
        "x": -normal.x * 100,
        "y": -normal.y * 100,
        "z": -normal.z * 100,
    ]
    return try JSONDecoder().decode(
        PlayerSimulationContinuation.self,
        from: JSONSerialization.data(withJSONObject: object)
    )
}

private func assertTrainingGuidebotReturnBarrier(
    level: Level,
    rendersFaces: Bool
) {
    let chain = level.trainingCameraMonitorChain!.returnToShip!
    let room = level.rooms.first {
        $0.sourceIndex == chain.barrierRoomSourceIndex
    }!
    for portalIndex in chain.orderedPortalIndices {
        let portal = room.portals[portalIndex]
        XCTAssertEqual(portal.flags & 1 != 0, rendersFaces)
        let connectedRoom = level.rooms.first {
            $0.sourceIndex == portal.connectedRoom
        }!
        XCTAssertEqual(
            connectedRoom.portals[portal.connectedPortal].flags & 1 != 0,
            rendersFaces
        )
    }
}

private func syntheticVoiceClip(
    name: String,
    sourceEntryIndex: Int,
    sourceHash: Character
) -> CanonicalVoiceClip {
    .init(
        sourceName: name,
        sourceEntryIndex: sourceEntryIndex,
        sampleRate: 22_050,
        channelCount: 1,
        frameCount: 1,
        pcm16LittleEndian: Data(repeating: 0, count: 2),
        pcmSHA256: canonicalSHA256(Data(repeating: 0, count: 2)),
        sourceArchive: "missions/training.mn3",
        sourceSHA256: String(repeating: sourceHash, count: 64)
    )
}

func makeTrainingGuidebotBlockedMovementLevel() -> Level {
    var level = makeTrainingRobotGuidebotLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let chain = level.trainingRobotGuidebotChain!
    level = replacing(
        level,
        trainingRobotGuidebotChain: .init(
            destroyRobotObjectHandle: chain.destroyRobotObjectHandle,
            guidebotObjectHandle: chain.guidebotObjectHandle,
            destroyRobotRoomSourceIndex:
                chain.destroyRobotRoomSourceIndex,
            destroyRobotFlags: chain.destroyRobotFlags,
            destructionDelay: chain.destructionDelay,
            destructionMessage: chain.destructionMessage,
            exitInstruction: chain.exitInstruction,
            destructionVoiceSourceName:
                chain.destructionVoiceSourceName,
            deployedGuidebotObjectType:
                chain.deployedGuidebotObjectType,
            deployedGuidebotMessage: chain.deployedGuidebotMessage,
            deployedGuidebotVoiceSourceName:
                chain.deployedGuidebotVoiceSourceName,
            combat: chain.combat,
            guidebot: .init(
                collisionRadius: chain.guidebot.collisionRadius,
                maximumVelocity: chain.guidebot.maximumVelocity,
                maximumDeltaVelocity:
                    chain.guidebot.maximumDeltaVelocity,
                birthForwardVelocity:
                    chain.guidebot.birthForwardVelocity,
                goalForwardDistance: 40,
                goalCircleDistance:
                    chain.guidebot.goalCircleDistance
            )
        )
    )
    guard case let .room(roomSourceIndex) = player.location else {
        preconditionFailure("expected indoor player")
    }
    let roomIndex = level.rooms.firstIndex {
        $0.sourceIndex == roomSourceIndex
    }!
    func point(forward: Float, right: Float, up: Float = 0) -> Vector3 {
        Vector3(
            x: player.position.x
                + player.orientation.forward.x * forward
                + player.orientation.right.x * right
                + player.orientation.up.x * up,
            y: player.position.y
                + player.orientation.forward.y * forward
                + player.orientation.right.y * right
                + player.orientation.up.y * up,
            z: player.position.z
                + player.orientation.forward.z * forward
                + player.orientation.right.z * right
                + player.orientation.up.z * up
        )
    }
    var room = addingSourceContainmentShell(
        to: level.rooms[roomIndex],
        center: player.position,
        texture: level.surfacePhysics[0].texture,
        halfExtent: 100
    )
    let firstWallVertex = room.vertices.count
    let wallVertices = [
        point(forward: 20, right: -10, up: -20),
        point(forward: 20, right: 10, up: -20),
        point(forward: 20, right: 10, up: 20),
        point(forward: 20, right: -10, up: 20),
    ]
    room = .init(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: room.vertices + wallVertices,
        faces: room.faces + [
            .init(
                corners: (0..<4).reversed().map {
                    .init(
                        vertexIndex: firstWallVertex + $0,
                        u: 0,
                        v: 0,
                        alpha: 255
                    )
                },
                flags: 0,
                portalIndex: nil,
                texture: level.surfacePhysics[0].texture
            ),
        ],
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    level.rooms[roomIndex] = room

    let firstRoutePoint = point(forward: 12, right: 25)
    let secondRoutePoint = point(forward: 30, right: 25)
    level = replacing(
        level,
        indoorNavigation: .init(
            sourceHighestRoomPlusTerrainRegions:
                level.rooms.map(\.sourceIndex).max()! + 8,
            sourceWasVerified: true,
            rooms: [
                .init(
                    sourceIndex: roomSourceIndex,
                    nodes: [
                        .init(
                            position: secondRoutePoint,
                            edges: [
                                .init(
                                    destinationRoomSourceIndex:
                                        roomSourceIndex,
                                    destinationNodeIndex: 1,
                                    flags: 0,
                                    cost: 18,
                                    maximumRadius: 6
                                ),
                            ]
                        ),
                        .init(
                            position: firstRoutePoint,
                            edges: [
                                .init(
                                    destinationRoomSourceIndex:
                                        roomSourceIndex,
                                    destinationNodeIndex: 0,
                                    flags: 0,
                                    cost: 18,
                                    maximumRadius: 6
                                ),
                            ]
                        ),
                    ]
                ),
            ]
        )
    )
    return level
}

private func guidebotRoutePointIndex(
    in continuation: PlayerSimulationContinuation
) throws -> Int {
    let object = try XCTUnwrap(
        JSONSerialization.jsonObject(
            with: JSONEncoder().encode(continuation)
        ) as? [String: Any]
    )
    let state = try XCTUnwrap(
        object["trainingRobotGuidebotState"] as? [String: Any]
    )
    let guidebot = try XCTUnwrap(state["guidebot"] as? [String: Any])
    return try XCTUnwrap(guidebot["routePointIndex"] as? Int)
}

private func assertTrainingGalleryBarrier(
    level: Level,
    rendersFaces: Bool,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let room = level.rooms.first { $0.sourceIndex == 2 }!
    for portal in room.portals {
        XCTAssertEqual(
            portal.flags & 1 != 0,
            rendersFaces,
            file: file,
            line: line
        )
        let connectedRoom = level.rooms.first {
            $0.sourceIndex == portal.connectedRoom
        }!
        XCTAssertEqual(
            connectedRoom.portals[portal.connectedPortal].flags & 1 != 0,
            rendersFaces,
            file: file,
            line: line
        )
    }
}

func makeSliceTenContactLevel(clearance: Float = 20) -> Level {
    let level = makeSliceSixObjectRenderLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z + clearance
    let vertices = room.vertices + [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let contactRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    var rooms = level.rooms
    rooms[roomIndex] = contactRoom
    return replacing(level, rooms: rooms)
}

func makeSliceThirteenWiggleLevel(blocked: Bool = false) -> Level {
    let base = makeSliceSixObjectRenderLevel()
    let radius = defaultPlayerView(in: base).collisionRadius
    let level = blocked
        ? makeSliceTenContactLevel(clearance: radius + 0.01)
        : base
    var objects = level.objects
    let playerIndex = objects.firstIndex { $0.handle == 2_048 }!
    objects[playerIndex].orientation = Matrix3(
        right: .init(x: 1, y: 0, z: 0),
        up: .init(x: 0, y: 0, z: 1),
        forward: .init(x: 0, y: -1, z: 0)
    )
    return replacing(level, objects: objects)
}

func makeSliceThirteenPortalWiggleLevel() -> Level {
    let level = makeSliceThirteenWiggleLevel()
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z + 0.04
    let portalVertices = [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
    ]
    let corners = (0..<4).map {
        FaceCorner(
            vertexIndex: firstVertex + $0,
            u: 0,
            v: 0,
            alpha: 255
        )
    }
    let portalFace = LevelFace(
        corners: corners,
        flags: 0,
        portalIndex: room.portals.count,
        texture: room.faces[0].texture
    )
    let sourceRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: room.vertices + portalVertices,
        faces: room.faces + [portalFace],
        portals: room.portals + [
            .init(
                faceIndex: room.faces.count,
                connectedRoom: 99,
                connectedPortal: 0
            ),
        ],
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    let connectedRoom = LevelRoom(
        sourceIndex: 99,
        vertices: portalVertices,
        faces: [
            .init(
                corners: corners.reversed().map {
                    FaceCorner(
                        vertexIndex: $0.vertexIndex - firstVertex,
                        u: $0.u,
                        v: $0.v,
                        alpha: $0.alpha
                    )
                },
                flags: 0,
                portalIndex: 0,
                texture: room.faces[0].texture
            ),
        ],
        portals: [
            .init(faceIndex: 0, connectedRoom: 1, connectedPortal: room.portals.count),
        ]
    )
    var rooms = level.rooms
    rooms[roomIndex] = sourceRoom
    rooms.append(connectedRoom)
    return replacing(level, rooms: rooms)
}

func makeSliceElevenCornerLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let x = player.position.x + clearance
    let vertices = room.vertices + [
        Vector3(x: x, y: player.position.y - 20, z: player.position.z - 20),
        Vector3(x: x, y: player.position.y - 20, z: player.position.z + 20),
        Vector3(x: x, y: player.position.y + 20, z: player.position.z + 20),
        Vector3(x: x, y: player.position.y + 20, z: player.position.z - 20),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let cornerRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    var rooms = level.rooms
    rooms[roomIndex] = cornerRoom
    return replacing(level, rooms: rooms)
}

func makeSliceElevenForceFieldLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let texture = level.rooms.first { $0.sourceIndex == 1 }!.faces.last!.texture
    return replacing(
        level,
        surfacePhysics: level.surfacePhysics.map {
            $0.texture == texture
                ? .init(texture: $0.texture, behavior: .forceField)
                : $0
        }
    )
}

func makeSliceElevenTrappedLevel(clearance: Float) -> Level {
    let level = makeSliceTenContactLevel(clearance: clearance)
    let player = level.objects.first { $0.handle == 2_048 }!
    let roomIndex = level.rooms.firstIndex { $0.sourceIndex == 1 }!
    let room = level.rooms[roomIndex]
    let firstVertex = room.vertices.count
    let z = player.position.z - clearance
    let vertices = room.vertices + [
        Vector3(x: player.position.x - 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y - 20, z: z),
        Vector3(x: player.position.x + 20, y: player.position.y + 20, z: z),
        Vector3(x: player.position.x - 20, y: player.position.y + 20, z: z),
    ]
    let wall = LevelFace(
        corners: (0..<4).map {
            .init(vertexIndex: firstVertex + $0, u: 0, v: 0, alpha: 255)
        },
        flags: 0,
        portalIndex: nil,
        texture: room.faces[0].texture
    )
    let trappedRoom = LevelRoom(
        sourceIndex: room.sourceIndex,
        name: room.name,
        pathPoint: room.pathPoint,
        vertices: vertices,
        faces: room.faces + [wall],
        portals: room.portals,
        flags: room.flags,
        pulseTime: room.pulseTime,
        pulseOffset: room.pulseOffset,
        mirrorFaceIndex: room.mirrorFaceIndex,
        door: room.door,
        volumeLights: room.volumeLights,
        fog: room.fog,
        ambientSoundPattern: room.ambientSoundPattern,
        reverb: room.reverb,
        damage: room.damage,
        damageType: room.damageType
    )
    var rooms = level.rooms
    rooms[roomIndex] = trappedRoom
    return replacing(level, rooms: rooms)
}
