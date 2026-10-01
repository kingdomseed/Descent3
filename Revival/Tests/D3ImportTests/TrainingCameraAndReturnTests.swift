import XCTest

// The Camera Monitor and the Guide-Bot's return in TrainingMission.cpp:
// Script 040 (CustomObjectScript_1817 EVT_COLLIDE, :2057-2072), Script 059
// (its EVT_USE, :2073-2084), Scripts 038 and 041 (the level interval
// :1394-1401 and timer 13 :1585-1591), and Script 058 (:1443-1455), run on
// the generic inventory (Inventory.cpp), level goals (levelgoal.cpp), and
// popup view (SmallViews.cpp).
extension WorldRenderingTests {
    /// The Camera Monitor fixture with the Training module and no
    /// Guide-Bot, so Script 058 follows Script 059 at once.
    private func cameraMonitorSession() throws -> GameSession {
        let level = scriptingTrainingCameraMonitorLevel(
            makeTrainingCameraMonitorLevel(),
            guideBot: false
        )
        try level.validate()
        let session = GameSession(level: level, presentationReadyTimestamp: 0)
        // Script 002's first HUD message has run.
        session.world.trainingMission.script002Count = 1
        return session
    }

    private func restored(_ session: GameSession, at timestamp: Double)
        throws -> GameSession
    {
        try GameSession(
            level: session.level,
            world: JSONDecoder().decode(
                GameWorld.self,
                from: JSONEncoder().encode(session.world)
            ),
            resumedAtTimestamp: timestamp
        )
    }

    /// Script 040: the player touches the Camera Monitor. GuideBotC plays,
    /// PupC1 plays on the monitor, aAddObjectToInventory takes it
    /// (Inventory::AddObject, Inventory.cpp:393: the level goal hears of
    /// the OF_INFORM_DESTROY_TO_LG object and completes, and the monitor is
    /// ghosted in the inventory), and UseCameraMonitor shows. The level
    /// goals' DoFrame then counts no active primary goal
    /// (EVT_ALL_LEVEL_GOALS_COMPLETE, levelgoal.cpp:1129-1135).
    func testCameraMonitorPickupRunsScript040AndCompletesLocateGoal() throws {
        let simulation = try cameraMonitorSession()
        let monitor = simulation.level.findObjectName("CameraMonitor")
        // Level_goals.InitLevel marks the goal's object (levelgoal.cpp:1200).
        XCTAssertNotEqual(
            (simulation.world.objects[monitor]?.flags ?? 0)
                & GameObject.informDestroyToLevelGoalsFlag,
            0
        )
        XCTAssertEqual(simulation.world.goals[0].status, 1_028)

        let frame = simulation.touch("CameraMonitor", at: 0.1)

        XCTAssertEqual(presentationLog(frame), [
            "voice:guidebotc.osf",
            "sound:PupC1",
            "hud:Completed Locate the Camera Monitor",
            "sound:GoalComplete",
            "hud:\(trainingText("UseCameraMonitor"))",
        ])
        XCTAssertEqual(simulation.world.testTrainingMission?.script040Count, 1)
        let held = try XCTUnwrap(simulation.world.objects[monitor])
        XCTAssertEqual(held.type, .dummy)
        XCTAssertEqual(held.dummyType, .powerup)
        XCTAssertNotEqual(held.flags & GameObject.inPlayerInventoryFlag, 0)
        XCTAssertEqual(
            simulation.world.playerInventory.selectedItem?.object,
            monitor
        )
        XCTAssertEqual(simulation.world.goals[0].status, 1_036)
        XCTAssertEqual(simulation.world.goals[0].items.map(\.done), [true])
        XCTAssertNotEqual(
            simulation.world.levelGoalFlags & LevelGoalsFlag.allPrimariesDone,
            0
        )

        // The held monitor and the completed goal survive a save, and the
        // pickup does not run again.
        let resumed = try restored(simulation, at: 100)
        XCTAssertEqual(resumed.world.playerInventory, simulation.world.playerInventory)
        XCTAssertEqual(resumed.world.goals, simulation.world.goals)
        XCTAssertTrue(presentationLog(resumed.update(at: 100.1, input: .zero))
            .isEmpty)
    }

    /// Script 059: the inventory use key uses the selected monitor
    /// (UseInventoryItem, Inventory.cpp:1485). Its custom script plays
    /// GuideBotD, shows GBExtra, opens a 10-second popup view from the
    /// SecurityCamera's gun 0 (aCreatePopupView), and returns
    /// CONTINUE_DEFAULT, so the item leaves the inventory
    /// (Inventory.cpp:819-821). The page's OIF_INVEN_NOREMOVE keeps the
    /// object (a ghost) alive. With no Guide-Bot out, Script 058 runs in
    /// the same frame's level interval, and Script 038 sets level timer 13,
    /// whose Script 041 counts 2 seconds later.
    func testCameraMonitorUseRunsScript059AndTimesThePopupViewAcrossReload()
        throws
    {
        let simulation = try cameraMonitorSession()
        _ = simulation.touch("CameraMonitor", at: 0.1)
        let monitor = simulation.level.findObjectName("CameraMonitor")
        let camera = simulation.level.findObjectName("SecurityCamera")
        let held = try restored(simulation, at: 10)

        let used = held.update(at: 10.1, input: .init(usesInventory: true))

        XCTAssertEqual(presentationLog(used), [
            "voice:guidebotd.osf",
            "hud:\(trainingText("GBExtra"))",
            "voice:proceed6.osf",
            "hud:\(trainingText("GoodJob"))",
        ])
        let mission = try XCTUnwrap(held.world.testTrainingMission)
        XCTAssertEqual(mission.script059Count, 1)
        XCTAssertEqual(mission.script058Count, 1)
        XCTAssertEqual(mission.script038Count, 1)
        XCTAssertTrue(held.world.playerInventory.items.isEmpty)
        XCTAssertNil(held.world.playerInventory.selectedItem)
        let ghost = try XCTUnwrap(held.world.objects[monitor])
        XCTAssertEqual(ghost.type, .dummy)
        XCTAssertEqual(ghost.flags & GameObject.inPlayerInventoryFlag, 0)
        XCTAssertEqual(ghost.flags & GameObject.deadFlag, 0)

        let cameraObject = try XCTUnwrap(held.world.objects[camera])
        let popup = try XCTUnwrap(used.popupView)
        XCTAssertTrue(popup.isPopup)
        XCTAssertEqual(popup.viewerObjectHandle, camera.rawValue)
        XCTAssertEqual(popup.remainingDuration, 10)
        // The fixture camera has no model, so the view is its own.
        XCTAssertEqual(popup.camera.position, cameraObject.position)
        XCTAssertEqual(
            popup.camera.target,
            cameraObject.position + cameraObject.orientation.forward
        )
        // SVF_POPUP | SVF_BIGGER | SVF_TIMED, at D3_DEFAULT_ZOOM / 1; the
        // render step counted the previous Frametime.
        XCTAssertEqual(held.world.smallViews[0].flags, 11)
        XCTAssertEqual(held.world.smallViews[0].zoom, SmallView.defaultZoom)
        XCTAssertEqual(held.world.smallViews[0].timer, 9.9, accuracy: 0.000_1)
        XCTAssertNotNil(held.world.osirisTimers.entries.first {
            $0.isUsed && $0.owner == .level && $0.id == 13
        })

        // The popup and the pending timer 13 survive a save.
        let popupContinuation = try restored(held, at: 200)
        let afterReload = popupContinuation.update(at: 200.1, input: .zero)
        XCTAssertEqual(
            try XCTUnwrap(afterReload.popupView).remainingDuration,
            9.9,
            accuracy: 0.000_1
        )
        var frames = [afterReload]
        var timestamp = 200.1
        for _ in 1...105 {
            timestamp += 0.1
            frames.append(popupContinuation.update(at: timestamp, input: .zero))
        }
        XCTAssertEqual(
            popupContinuation.world.testTrainingMission?.script041Count,
            1
        )
        // The window closes when its timer passes 0 after its last frame,
        // 10 s of 0.1 s frames after the use (Float time).
        let lastOpen = try XCTUnwrap(frames.lastIndex { $0.popupView != nil })
        XCTAssertTrue((98...99).contains(lastOpen))
        XCTAssertLessThan(
            try XCTUnwrap(frames[lastOpen].popupView).remainingDuration,
            0.1 + 0.000_1
        )
        XCTAssertFalse(popupContinuation.world.smallViews[0].isActive)
        XCTAssertTrue(frames.dropFirst().allSatisfy {
            presentationLog($0).isEmpty
        })
    }

    /// aCreatePopupView's gun view (SmallViews.cpp:490-497): the camera is
    /// the gun point looking along the gun's normal, in the room
    /// GetGunRoom traces from the viewer to the gun point.
    func testPopupViewLooksFromTheViewersGunInTheTracedRoom() throws {
        var level = makeTrainingCameraMonitorLevel()
        let model = try XCTUnwrap(level.models.first {
            $0.source.sourceName == "monitor.OOF"
        }).source
        level.objectPresentations.append(.init(
            objectHandle: 6_183,
            primaryModel: model,
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil
        ))
        level = level.settingModelGuns(
            model,
            gunpoints: [.init(
                parent: 0,
                position: .init(x: 0, y: 1, z: 2),
                normal: .init(x: 0, y: 0, z: 1)
            )],
            batteries: []
        )
        var world = GameWorld(level: level)
        let camera = ObjectHandle(6_183)
        world.aCreatePopupView(0, camera, 10, 2)
        let object = try XCTUnwrap(world.objects[camera])
        let gun = world.weaponCalcGun(
            object,
            gunpoint: 0,
            model: try XCTUnwrap(level.placedObjectModel(camera))
        )
        guard case let .room(room) = object.location else {
            return XCTFail("The camera is indoor")
        }

        let frame = try XCTUnwrap(world.smallViewFrames(level: level).first)

        XCTAssertEqual(world.smallViews[0].zoom, SmallView.defaultZoom / 2)
        XCTAssertEqual(frame.camera.position, gun.point)
        XCTAssertEqual(
            frame.camera.target,
            gun.point + sourceVectorNormalized(gun.normal)
        )
        XCTAssertEqual(
            frame.roomSourceIndex,
            traceIndoorMovement(
                in: level,
                roomStates: world.rooms,
                startRoom: room,
                start: object.position,
                end: gun.point,
                radius: 0
            ).containingRoomSourceIndex
        )
        XCTAssertLessThan(
            frame.camera.projection.horizontalFieldOfViewRadians,
            PerspectiveProjection.sourceDefault.horizontalFieldOfViewRadians
        )
        // A gone viewer shows static for STATIC_TIME, then the window
        // closes (DrawSmallViews, :427-438).
        world.objects.delete(camera)
        world.smallViewsRenderFrame(frameTime: 0.1)
        XCTAssertNotEqual(
            world.smallViews[0].flags & SmallView.Flag.staticPicture,
            0
        )
        XCTAssertTrue(world.smallViewFrames(level: level).isEmpty)
        world.smallViewsRenderFrame(frameTime: 0.1)
        world.smallViewsRenderFrame(frameTime: 0.1)
        XCTAssertFalse(world.smallViews[0].isActive)
    }

    /// do_physics_sim checks objects on each move it makes
    /// (physics.cpp:986-1080): after a wall contact the rest of the move
    /// starts at the contact. A pickup that the straight start-to-final
    /// chord passes, but neither actual move segment does, is not touched;
    /// one on the first segment is (GenericScript's pickup, generic.cpp:310).
    func testPickupUsesTheMoveSegmentsAroundAWallContact() throws {
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

        /// A slice-ten session with one runtime Invulnerability powerup of
        /// size 0.01 at `position` in the player's room.
        func session(pickupAt position: Vector3) throws
            -> (GameSession, ObjectHandle)
        {
            var info = fixtureGenericPowerupInfo("Invulnerability")
            info = CanonicalObjectInfo(
                name: info.name,
                type: info.type,
                flags: info.flags,
                size: 0.01,
                hitPoints: info.hitPoints,
                lightDistance: info.lightDistance,
                lighting: info.lighting,
                ai: nil,
                weaponBatteries: []
            )
            var level = contactLevel.addingObjectInfo(info)
            let last = level.objectInfos!.count - 1
            level.objectInfos?[last].moduleName = GenericModule.moduleName
            let session = GameSession(level: level, presentationReadyTimestamp: 0)
            _ = session.update(at: 2, input: .zero)
            let pickup = session.world.objCreate(
                type: .powerup,
                id: level.objectInfos!.count - 1,
                room: baselineFrame.playerView.roomSourceIndex,
                position: position,
                orientation: nil,
                parent: .none,
                level: level
            )
            XCTAssertEqual(
                session.world.objects[pickup]?.scripts?.defaultScript,
                .genericPowerup
            )
            return (session, pickup)
        }

        let (missed, missedPickup) = try session(pickupAt: pickupPosition)
        _ = missed.update(at: 4, input: .init(forward: 1, sideways: 1))
        XCTAssertNil(missed.world.playerInvulnerableTime)
        XCTAssertNotNil(missed.world.objects[missedPickup])
        XCTAssertTrue(missed.world.playerInventory.items.isEmpty)

        // On the first segment, near the wall contact, it is touched.
        let onPath = Vector3(
            x: (start.x + contactCenter.x) / 2,
            y: (start.y + contactCenter.y) / 2,
            z: (start.z + contactCenter.z) / 2
        )
        let (touched, touchedPickup) = try session(pickupAt: onPath)
        _ = touched.update(at: 4, input: .init(forward: 1, sideways: 1))
        XCTAssertNotNil(touched.world.playerInvulnerableTime)
        XCTAssertNil(touched.world.objects[touchedPickup])
    }

    /// The return command (GBC_RETURN_TO_SHIP, AIGame.cpp:5143) sends the
    /// Guide-Bot into the player; the collision enters the ship
    /// (DoCollide :5510, SetMode(GBM_ENTER_SHIP) :4628). Script 058
    /// (TrainingMission.cpp:1443-1455) waits while the Guide-Bot is a robot
    /// and then, in the level EVT_INTERVAL, lights FlashLight-3, opens
    /// PortalRoom5, plays proceed6.osf, and shows GoodJob, once.
    func testGuidebotReturnCollisionRunsScript058OnceAcrossReload() throws {
        let level = scriptingTrainingCameraMonitorLevel(
            makeTrainingCameraMonitorLevel()
        )
        try level.validate()
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        var timestamp = 0.1
        simulation.releaseOrRecallTestGuideBot()
        _ = simulation.update(
            at: timestamp,
            input: .zero
        )
        timestamp += 0.1
        _ = simulation.touch("CameraMonitor", at: timestamp)
        timestamp += 0.1
        _ = simulation.update(at: timestamp, input: .init(usesInventory: true))
        // GBM_BIRTH lasts until mode_time > 1.2 s (AIGame.cpp:5893), and the
        // menu offers the return command only in GBM_AMBIENT (:4892).
        simulation.runFrames(13, from: &timestamp)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode,
            GuideBotScript.ambientMode
        )
        // The Guide-Bot is a robot, so Script 058 waits after the use.
        XCTAssertEqual(simulation.world.testTrainingMission?.script059Count, 1)
        XCTAssertEqual(simulation.world.testTrainingMission?.script058Count, 0)
        XCTAssertEqual(simulation.returnMarkerLightDistance, 0)
        timestamp += 0.1
        simulation.releaseOrRecallTestGuideBot()
        let requested = simulation.update(
            at: timestamp,
            input: .zero
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
            _ = simulation.update(at: timestamp, input: .zero)
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
            if frame.presentationFeedback.contains(where: {
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
        XCTAssertEqual(simulation.returnMarkerLightDistance, 50)
        assertReturnBarrier(simulation.runtimeLevel, rendersFaces: false)
        let postReturnFrame = simulation.update(
            at: timestamp + 0.1,
            input: .zero
        )
        XCTAssertTrue(postReturnFrame.presentationFeedback.isEmpty)

        let restored = try restored(simulation, at: 100)
        let afterReload = restored.update(at: 100.1, input: .zero)
        XCTAssertTrue(afterReload.presentationFeedback.isEmpty)
        XCTAssertTrue(afterReload.objectSoundLoops.isEmpty)
        XCTAssertEqual(restored.returnMarkerLightDistance, 50)
        assertReturnBarrier(restored.runtimeLevel, rendersFaces: false)
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
        level = scriptingTrainingCameraMonitorLevel(level)
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        simulation.releaseOrRecallTestGuideBot()
        _ = simulation.update(
            at: 0.1,
            input: .zero
        )
        _ = simulation.touch("CameraMonitor", at: 0.2)
        _ = simulation.update(at: 0.3, input: .init(usesInventory: true))
        XCTAssertEqual(simulation.world.testTrainingMission?.script059Count, 1)
        // The birth ends after 1.2 s (AIGame.cpp:5893), and the parent link
        // that keeps the Guide-Bot from hitting the player ends 3 s after
        // the birth (:6246).
        var seedTime = 0.3
        simulation.runFrames(31, from: &seedTime)
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
            if frameIndex == 1 {
                restored.releaseOrRecallTestGuideBot()
            }
            let frame = restored.update(
                at: 100 + Double(frameIndex) * 0.1,
                input: .zero
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
            if frame.presentationFeedback.contains(where: {
                $0.voiceSourceName == "proceed6.osf"
            }) {
                completed = frame
                break
            }
        }

        XCTAssertNotNil(completed)
        XCTAssertEqual(
            restored.world.objectType(restored.world.buddyHandle),
            .dummy
        )
        XCTAssertEqual(restored.returnMarkerLightDistance, 50)
        assertReturnBarrier(restored.runtimeLevel, rendersFaces: false)
    }

    /// PortalRoom5's two portals (Room_indexes[4], source room 2 in the
    /// fixture) and their reciprocals.
    private func assertReturnBarrier(
        _ level: Level,
        rendersFaces: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let room = level.rooms.first { $0.sourceIndex == 2 }!
        for portalIndex in [0, 1] {
            let portal = room.portals[portalIndex]
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
}
