import XCTest

extension WorldRenderingTests {
    func testDeployedGuidebotContinuationRestoresPresentationWithoutRepeatingScript060() throws {
        let level = makeScriptedTrainingGalleryLevel()
        let simulation = GameSession(
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
            if frame.presentationFeedback.contains(where: {
                $0.voiceSourceName == "guidebota.osf"
            }) {
                break
            }
        }
        simulation.releaseOrRecallTestGuideBot()
        let deployed = simulation.update(
            at: galleryTimestamp + 0.1,
            input: .zero
        )
        // Script 060 runs once the Guide-Bot is out (TrainingMission.cpp:1431).
        XCTAssertTrue(deployed.presentationFeedback.contains {
            $0.voiceSourceName == "guidebotb.osf"
        })
        XCTAssertEqual(
            simulation.world.objectType(simulation.world.buddyHandle),
            .robot
        )
        var continuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
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
        let continuation = try decodeTestWorld(continuationObject)
        let restored = try GameSession(
            level: restorationLevel,
            world: continuation.rebased(onto: restorationLevel),
            resumedAtTimestamp: 100
        )
        XCTAssertEqual(restored.world, continuation)
        // The Guide-Bot AIInitAll made shows its page's model.
        let guidebot = try XCTUnwrap(
            restored.world.objects[restored.world.buddyHandle]
        )
        XCTAssertEqual(
            restored.runtimeLevel.objectPresentation(of: guidebot)?
                .primaryModel.sourceName,
            "Buddybot.oof"
        )
        let resumed = restored.update(at: 100.1, input: .zero)
        XCTAssertEqual(
            restored.world.objectType(restored.world.buddyHandle),
            .robot
        )
        XCTAssertTrue(resumed.presentationFeedback.isEmpty)
        XCTAssertEqual(resumed.enabledPlayerControls, .all)
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
        RevivalGameplayView.presentFeedback(
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

        let sameFrameReturn: [PresentationFeedback] = [
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
            )
        ]
        var orderedPresentation: [String] = []
        RevivalGameplayView.presentFeedbackSequence(
            sameFrameReturn,
            attemptVoice: {
                orderedPresentation.append("voice:\($0)")
            },
            attemptSound: { name, _ in
                orderedPresentation.append("sound:\(name)")
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
        let feedback: [PresentationFeedback] = [
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

        RevivalGameplayView.presentFeedbackSequence(
            feedback,
            attemptVoice: {
                presentation.append("voice:\($0)")
            },
            attemptSound: { name, _ in
                presentation.append("sound:\(name)")
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

}
