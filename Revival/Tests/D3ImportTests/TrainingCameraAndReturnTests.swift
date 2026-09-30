import XCTest

extension WorldRenderingTests {
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
        let simulation = GameSession(
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
            simulation.runtimeLevel.objectPresentations.contains {
                $0.objectHandle == chain.pickupObjectHandle
                    && $0.isVisible
            }
        )
        XCTAssertTrue(
            simulation.runtimeLevel.objects.contains {
                $0.handle == chain.pickupObjectHandle
            }
        )

        let heldContinuation = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(simulation.world)
        )
        let restored = try GameSession(
            level: level,
            world: heldContinuation.rebased(onto: level),
            resumedAtTimestamp: 100
        )
        XCTAssertFalse(
            restored.runtimeLevel.objectPresentations.contains {
                $0.objectHandle == chain.pickupObjectHandle
                    && $0.isVisible
            }
        )

        let used = restored.update(
            at: 100.1,
            input: .init(usesInventory: true)
        )
        // This level has no Guide-Bot (qGetBuddyObj is not a robot), so
        // Script 058 (TrainingMission.cpp:1444) follows the use in the
        // same frame's level EVT_INTERVAL.
        XCTAssertEqual(
            used.trainingOpeningFeedback,
            [.init(
                hudMessages: [
                    "Now recall the Guidebot by pressing F4 and selecting \"Return to Ship\".  Move to the next area when he returns.",
                ],
                voiceSourceName: "guidebotd.osf",
                voicePrecedesHUDMessages: true
            ), .init(
                hudMessages: ["Excellent!"],
                voiceSourceName: "proceed6.osf",
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
        XCTAssertFalse(restored.runtimeLevel.objects.contains {
            $0.handle == chain.pickupObjectHandle
        })

        let usedContinuation = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(restored.world)
        )
        let resumedPopup = try GameSession(
            level: level,
            world: usedContinuation.rebased(onto: level),
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

    /// The return command (GBC_RETURN_TO_SHIP, AIGame.cpp:5143) sends the
    /// Guide-Bot into the player; the collision enters the ship
    /// (DoCollide :5510, SetMode(GBM_ENTER_SHIP) :4628), and the bespoke
    /// Script 058 bridge sees it back in the ship once (TrainingMission.cpp:1443).
    func testGuidebotReturnCollisionRunsScript058OnceAcrossReload() throws {
        let level = withTrainingGuideBot(makeTrainingCameraMonitorLevel())
        try level.validate()
        let chain = try XCTUnwrap(level.trainingCameraMonitorChain)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        var timestamp = 0.1
        _ = simulation.update(
            at: timestamp,
            input: .init(deploysTrainingGuidebot: true)
        )
        timestamp += 0.1
        _ = simulation.update(at: timestamp, input: .init(usesInventory: true))
        // GBM_BIRTH lasts until mode_time > 1.2 s (AIGame.cpp:5893), and the
        // menu offers the return command only in GBM_AMBIENT (:4892).
        simulation.runFrames(14, from: &timestamp)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode,
            GuideBotScript.ambientMode
        )
        timestamp += 0.1
        let requested = simulation.update(
            at: timestamp,
            input: .init(deploysTrainingGuidebot: true)
        )
        XCTAssertEqual(hudMessages([requested]), ["GB: Returning to ship."])
        // DoInit set last_sound_time at level start (AIGame.cpp:5683), so
        // DoMessage plays no sound before 2.5 s (:4542).
        XCTAssertFalse(soundNames([requested]).contains("GBotAcceptOrder1"))
        XCTAssertEqual(simulation.world.testGuideBot?.isMarkedForPickup, true)

        // The fixture's Buddybot model is flat, so its move never touches
        // the ship's sphere (RESULT_CHECK_POLY_SPHERE); once the parent link
        // is gone (AIGame.cpp:6045) and it is at the player, the test gives
        // the pair's contact (collide_two_objects).
        for _ in 1...100 {
            timestamp += 0.1
            simulation.update(at: timestamp, input: .zero)
            if let guideBot = simulation.world.testGuideBotObject,
               guideBot.parent == .none,
               simulation.world.objectDistance(
                   guideBot.handle,
                   simulation.world.testPlayerObject.handle,
                   subtractingSizes: true
               ) < 0 {
                break
            }
        }
        XCTAssertEqual(simulation.world.testGuideBotObject?.parent, ObjectHandle.none)
        simulation.world.collideTwoObjects(
            simulation.world.buddyHandle,
            simulation.world.testPlayerObject.handle,
            level: simulation.level
        )
        var completed: PlayerSimulationFrame?
        for _ in 1...300 {
            timestamp += 0.1
            let frame = simulation.update(at: timestamp, input: .zero)
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                completed = frame
                break
            }
        }
        let script058 = try XCTUnwrap(completed)
        XCTAssertEqual(
            Set(hudMessages([script058])),
            ["GB: Entering ship!", "Excellent!"]
        )
        XCTAssertEqual(
            simulation.world.objectType(simulation.world.buddyHandle),
            .dummy
        )
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode,
            GuideBotScript.inShipMode
        )
        XCTAssertTrue(script058.objectSoundLoops.isEmpty)
        XCTAssertEqual(
            script058.trainingGuidebotReturnMarkerLightDistance,
            50
        )
        assertTrainingGuidebotReturnBarrier(
            level: simulation.runtimeLevel,
            rendersFaces: false
        )
        let postReturnFrame = simulation.update(
            at: timestamp + 0.1,
            input: .zero
        )
        XCTAssertTrue(postReturnFrame.trainingOpeningFeedback.isEmpty)

        let continuation = try JSONDecoder().decode(
            GameWorld.self,
            from: JSONEncoder().encode(simulation.world)
        )
        let restored = try GameSession(
            level: level,
            world: continuation.rebased(onto: level),
            resumedAtTimestamp: 100
        )
        let afterReload = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(afterReload.trainingOpeningFeedback.isEmpty)
        XCTAssertTrue(afterReload.objectSoundLoops.isEmpty)
        XCTAssertEqual(
            afterReload.trainingGuidebotReturnMarkerLightDistance,
            chain.returnToShip?.openMarkerLightDistance
        )
        assertTrainingGuidebotReturnBarrier(
            level: restored.runtimeLevel,
            rendersFaces: false
        )
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
        level = withTrainingGuideBot(level)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        _ = simulation.update(at: 0.2, input: .init(usesInventory: true))
        // The birth ends after 1.2 s (AIGame.cpp:5893), and the parent link
        // that keeps the Guide-Bot from hitting the player ends 3 s after
        // the birth (:6246).
        var seedTime = 0.2
        simulation.runFrames(32, from: &seedTime)
        XCTAssertEqual(
            simulation.world.boaRoomRoute(from: 3, to: 1, level: level),
            [3, 2, 1]
        )

        var continuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        continuationObject["playerLocation"] = [
            "room": ["_0": 1],
        ]
        continuationObject["playerPosition"] = [
            "x": destination.x,
            "y": destination.y,
            "z": destination.z,
        ]
        let movedPlayerContinuation = try decodeTestWorld(continuationObject)
        let restored = try GameSession(
            level: level,
            world: movedPlayerContinuation.rebased(onto: level),
            resumedAtTimestamp: 100
        )

        var completed: PlayerSimulationFrame?
        for frameIndex in 1...400 {
            let frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: frameIndex == 1
                    ? .init(deploysTrainingGuidebot: true)
                    : .zero
            )
            if frameIndex == 1 {
                XCTAssertEqual(hudMessages([frame]), ["GB: Returning to ship."])
            }
            if frameIndex == 2 {
                // The return goal paths through the portal rooms
                // (AIPathAllocPath, aipath.cpp:977).
                let path = try XCTUnwrap(
                    restored.world.testGuideBotObject?.ai?.path
                )
                XCTAssertEqual(path.dynamicNodes.last?.roomSourceIndex, 1)
                XCTAssertGreaterThan(path.dynamicNodes.count, 1)
            }
            if frame.trainingOpeningFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                completed = frame
                break
            }
        }

        let script058 = try XCTUnwrap(completed)
        XCTAssertEqual(
            restored.world.objectType(restored.world.buddyHandle),
            .dummy
        )
        XCTAssertEqual(
            script058.trainingGuidebotReturnMarkerLightDistance,
            50
        )
        assertTrainingGuidebotReturnBarrier(
            level: restored.runtimeLevel,
            rendersFaces: false
        )
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
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )

        _ = simulation.update(at: 0.1, input: .zero)

        let completedGoal = try XCTUnwrap(simulation.runtimeLevel.goals.first {
            $0.name == "Locate the Camera Monitor"
        })
        XCTAssertEqual(completedGoal.status, 1_036)
        XCTAssertEqual(completedGoal.items.map(\.done), [true])
        let restored = try GameSession(
            level: level,
            world: simulation.world.rebased(onto: level),
            resumedAtTimestamp: 100
        )
        let restoredGoal = try XCTUnwrap(restored.runtimeLevel.goals.first {
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
        let simulation = GameSession(
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
        let baseline = GameSession(
            level: contactLevel,
            presentationReadyTimestamp: 0
        )
        _ = baseline.update(at: 2, input: .zero)
        let start = defaultPlayerView(in: baseline.runtimeLevel).camera.position
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
        let simulation = GameSession(
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
}