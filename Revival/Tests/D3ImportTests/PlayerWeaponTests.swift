import XCTest

extension WorldRenderingTests {
    @MainActor
    func testHeldSecondaryFirePublishesUntilReleaseAndClearsWhenGameplayStops()
        throws
    {
        var input = PlayerInputState(rampDuration: 0)
        input.setSecondaryFireHeld(true)
        XCTAssertTrue(input.snapshot(frameDuration: 0.1).firesSecondaryWeapon)
        XCTAssertTrue(input.snapshot(frameDuration: 0.1).firesSecondaryWeapon)
        input.setSecondaryFireHeld(false)
        XCTAssertFalse(input.snapshot(frameDuration: 0.1).firesSecondaryWeapon)

        input.setSecondaryFireHeld(true)
        input.setGameplayActive(false, simulation: nil, at: 1)
        XCTAssertFalse(input.snapshot(frameDuration: 0.1).firesSecondaryWeapon)

        let view = RevivalGameplayView(frame: .zero, device: nil)
        var heldChanges: [Bool] = []
        view.secondaryFireHeldChanged = { heldChanges.append($0) }
        view.setGameplayActive(true)
        let spaceDown = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: 49
        ))
        let spaceUp = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0.01,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: 49
        ))
        let rightDown = try XCTUnwrap(NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0.02,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        let rightUp = try XCTUnwrap(NSEvent.mouseEvent(
            with: .rightMouseUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0.03,
            windowNumber: 0,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 0
        ))
        view.keyDown(with: spaceDown)
        view.keyUp(with: spaceUp)
        view.rightMouseDown(with: rightDown)
        view.rightMouseUp(with: rightUp)
        view.keyDown(with: spaceDown)
        view.clearInput()
        view.rightMouseDown(with: rightDown)
        view.setGameplayActive(false)
        XCTAssertEqual(
            heldChanges,
            [true, false, true, false, true, false, true, false]
        )
    }

    /// FireWeaponFromPlayer through GameSession.update (WeaponFire.cpp:2830
    /// with 3MASTERED dbd611e4, bd896ac, c47df2d; sources.md section 2).
    /// Frames of 0.01, 0.247, and 0.01 s: the first shot fires at Gametime
    /// 0; the held button's next shot is due at 0.25 and fires in the frame
    /// whose Gametime is 0.257, keeping the 0.007 s overshoot
    /// (last_fire_time 0.25). A release and a new press start a new burst
    /// anchored at that frame's Gametime.
    func testHeldPrimaryFireKeepsItsScheduledCadenceAcrossFrames() throws {
        let level = makeTrainingRobotGuidebotLevel()
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        func battery() -> DynamicWeaponBattery {
            simulation.world.testPlayerObject.weaponBatteries[0]
        }
        func bolts() -> Int {
            simulation.world.objects.filter { $0.type == .weapon }.count
        }
        _ = simulation.update(at: 0.01, input: .init(firesPrimaryWeapon: true))
        XCTAssertEqual(simulation.energy, 99.85, accuracy: 0.000_01)
        XCTAssertEqual(bolts(), 2)
        XCTAssertEqual(battery().lastFireTime, 0, accuracy: 0.000_01)

        _ = simulation.update(at: 0.257, input: .init(firesPrimaryWeapon: true))
        XCTAssertEqual(simulation.energy, 99.85, accuracy: 0.000_01)
        XCTAssertEqual(bolts(), 2)
        _ = simulation.update(at: 0.267, input: .init(firesPrimaryWeapon: true))
        XCTAssertEqual(simulation.energy, 99.7, accuracy: 0.000_01)
        XCTAssertEqual(bolts(), 4)
        XCTAssertEqual(battery().lastFireTime, 0.25, accuracy: 0.000_01)
        // Firing draws no random numbers.
        XCTAssertEqual(
            simulation.world.authoritativeRandomState,
            0x1234_5678
        )

        _ = simulation.update(at: 9, input: .zero)
        XCTAssertEqual(
            simulation.world.playerWeapons[PlayerWeaponState.primary]
                .firingTime,
            0
        )
        _ = simulation.update(at: 9.016, input: .zero)
        _ = simulation.update(at: 9.032, input: .init(firesPrimaryWeapon: true))
        XCTAssertEqual(simulation.energy, 99.55, accuracy: 0.000_01)
        XCTAssertEqual(battery().lastFireTime, 9.016, accuracy: 0.000_01)
    }

    /// The Concussion battery alternates gun points 1 and 2 (fire masks 2
    /// and 4), each shot taking one missile and waiting 0.5 s.
    func testConcussionAlternatesItsGunpointsThroughTheFrame() throws {
        let level = try makePlayerConcussionLevel()
        let simulation = GameSession(level: level, presentationReadyTimestamp: 0)
        simulation.world.playerWeapons[PlayerWeaponState.secondary].index =
            PlayerWeaponState.concussionIndex
        let player = simulation.world.testPlayerObject
        func rightOffsets() -> [Float] {
            simulation.world.objects.filter { $0.type == .weapon }
                .sorted { $0.creationTime < $1.creationTime }
                .map { dot($0.position - player.position,
                           player.orientation.right) }
        }
        _ = simulation.update(at: 0.1, input: .init(firesSecondaryWeapon: true))
        XCTAssertEqual(
            simulation.world.playerWeaponAmmo[PlayerWeaponState.concussionIndex],
            5
        )
        XCTAssertEqual(rightOffsets().count, 1)
        let first = rightOffsets()[0]
        _ = simulation.update(at: 0.4, input: .init(firesSecondaryWeapon: true))
        XCTAssertEqual(rightOffsets().count, 1)
        _ = simulation.update(at: 0.6, input: .init(firesSecondaryWeapon: true))
        XCTAssertEqual(rightOffsets().count, 1)
        _ = simulation.update(at: 0.7, input: .init(firesSecondaryWeapon: true))
        XCTAssertEqual(
            simulation.world.playerWeaponAmmo[PlayerWeaponState.concussionIndex],
            4
        )
        let offsets = rightOffsets()
        XCTAssertEqual(offsets.count, 2)
        // Gun point 1 is 2.792 right of the model's center, gun point 2
        // 2.804 left of it.
        XCTAssertEqual(first - (offsets.last ?? 0), 5.596_459, accuracy: 0.05)
    }

    /// A shockwave that reaches the pilot during the object frames lowers
    /// the shields; Script 030 runs later in the same frame's level
    /// EVT_INTERVAL (GameLoop.cpp:3013, TrainingMission.cpp:1385-1392) and
    /// restores 50.
    func testScript030RestoresShieldsAfterASameFrameShockwave() throws {
        let level = addingTrainingMissionScripting(
            try makePlayerConcussionLevel()
        )
        let simulation = GameSession(level: level, presentationReadyTimestamp: 0)
        simulation.world.trainingMission.script014Count = 1
        simulation.world.shields = 30
        simulation.world.playerWeapons[PlayerWeaponState.secondary].index =
            PlayerWeaponState.concussionIndex
        let player = simulation.world.testPlayerObject
        simulation.world.fireWeaponFromPlayer(
            player.handle,
            weaponType: PlayerWeaponState.secondary,
            isDown: true,
            downTime: 0.1,
            level: level
        )
        let missile = try XCTUnwrap(
            simulation.world.objects.first { $0.type == .weapon }
        )
        simulation.world.objects[missile.handle]?.position = player.position
        simulation.world.objects[missile.handle]?.location = player.location
        simulation.world.doWeaponExploded(missile.handle, level: level)
        simulation.world.objects[missile.handle]?.flags |= GameObject.deadFlag
        XCTAssertNotNil(simulation.world.objects.first { $0.type == .shockwave })

        _ = simulation.update(at: 0.1, input: .zero)
        XCTAssertEqual(simulation.world.shields, 50)
        XCTAssertEqual(simulation.world.testTrainingMission?.script030Count, 1)
        XCTAssertNil(simulation.world.playerDeath)
        _ = simulation.update(at: 0.2, input: .zero)
        XCTAssertEqual(simulation.world.testTrainingMission?.script030Count, 1)
    }

    /// A real Concussion missile kills DestroyBot2 through the generic
    /// weapon, damage, and death path; its EVT_DESTROY runs Script 036
    /// (TrainingMission.cpp:2039-2050), which opens the gallery portals and
    /// their reciprocals (aPortalRenderSet, DallasFuncs.cpp:1098) and lights
    /// FlashLight-2, and level timer 12 then runs Script 029.
    func testConcussionKillOfDestroyBot2RunsItsScriptChain() throws {
        var base = try makePlayerConcussionLevel()
        let barrier = try XCTUnwrap(base.trainingGalleryBarrier)
        let barrierRoom = try XCTUnwrap(base.rooms.firstIndex {
            $0.sourceIndex == barrier.barrierRoomSourceIndex
        })
        base.rooms[barrierRoom].name = "PortalRoom4"
        let player = try XCTUnwrap(base.objects.first {
            $0.handle == base.defaultPlayerBinding?.objectHandle
        })
        let robotIndex = try XCTUnwrap(base.objects.firstIndex {
            $0.handle == 4_112
        })
        base.objects[robotIndex].position = player.position
            + player.orientation.forward * 15
        base.objects[robotIndex].location = player.location
        let level = addingTrainingMissionScripting(
            base,
            messages: fixtureTrainingMessages + [
                .init(
                    name: "ExitManuveur",
                    text:
                        "Now go through the open doorway, and into the next room."
                ),
            ]
        )
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        simulation.world.playerWeapons[PlayerWeaponState.secondary].index =
            PlayerWeaponState.concussionIndex
        // Script 000 turned the controls off; the lessons turned them all
        // back on. Script 028 unghosted DestroyBot2; one direct hit
        // (6 x 1.5) kills it.
        simulation.world.playerControllerBitflags = .all
        simulation.world.unghostObject(ObjectHandle(4_112))
        simulation.world.objects[ObjectHandle(4_112)]?.shields = 5

        var time: Double = 0
        while simulation.world.objects[ObjectHandle(4_112)] != nil, time < 10 {
            time += 0.1
            _ = simulation.update(
                at: time,
                input: .init(firesSecondaryWeapon: true)
            )
        }
        XCTAssertNil(simulation.world.objects[ObjectHandle(4_112)])
        XCTAssertEqual(simulation.world.playerScore, 200)
        XCTAssertEqual(simulation.world.testTrainingMission?.script036Count, 1)
        XCTAssertEqual(simulation.galleryMarkerLightDistance, 50)
        for portalIndex in barrier.orderedPortalIndices {
            XCTAssertEqual(
                simulation.world.rooms[barrierRoom].portalFlags[portalIndex]
                    & LevelPortal.renderFacesFlag,
                0
            )
            let portal = level.rooms[barrierRoom].portals[portalIndex]
            let connected = try XCTUnwrap(level.rooms.firstIndex {
                $0.sourceIndex == portal.connectedRoom
            })
            XCTAssertEqual(
                simulation.world.rooms[connected]
                    .portalFlags[portal.connectedPortal]
                    & LevelPortal.renderFacesFlag,
                0
            )
        }
        for _ in 0..<30 {
            time += 0.1
            _ = simulation.update(at: time, input: .zero)
        }
        XCTAssertEqual(simulation.world.testTrainingMission?.script029Count, 1)
        XCTAssertNoThrow(try simulation.world.validate(against: level))
    }

    @MainActor
    func testHeldPrimaryFirePublishesUntilRelease()
        throws
    {
        var playerInput = PlayerInputState(rampDuration: 0)
        playerInput.setPrimaryFireHeld(true)
        XCTAssertTrue(
            playerInput.snapshot(frameDuration: 0.1)
                .firesPrimaryWeapon
        )
        XCTAssertTrue(
            playerInput.snapshot(frameDuration: 0.1)
                .firesPrimaryWeapon
        )
        playerInput.setPrimaryFireHeld(false)
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1)
                .firesPrimaryWeapon
        )

        playerInput.setPrimaryFireHeld(true)
        playerInput.setGameplayActive(
            false,
            simulation: nil,
            at: 1
        )
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1)
                .firesPrimaryWeapon
        )

        let view = RevivalGameplayView(frame: .zero, device: nil)
        var heldChanges: [Bool] = []
        view.primaryFireHeldChanged = { heldChanges.append($0) }
        view.setGameplayActive(true)
        let mouseDown = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 1,
                clickCount: 1,
                pressure: 1
            )
        )
        let mouseUp = try XCTUnwrap(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: .zero,
                modifierFlags: [],
                timestamp: 0.01,
                windowNumber: 0,
                context: nil,
                eventNumber: 2,
                clickCount: 1,
                pressure: 0
            )
        )
        view.mouseDown(with: mouseDown)
        view.mouseUp(with: mouseUp)
        view.mouseDown(with: mouseDown)
        view.clearInput()
        view.mouseDown(with: mouseDown)
        view.setGameplayActive(false)
        XCTAssertEqual(
            heldChanges,
            [true, false, true, false, true, false]
        )

        // Script 032's aToggleAllPlayerControls(0, 0) clears every control
        // bit, the primary weapon's too (TrainingMission.cpp:2336).
        XCTAssertEqual(
            InputSnapshot(firesPrimaryWeapon: true)
                .applying(PlayerControlMask(rawValue: 0))
                .firesPrimaryWeapon,
            false
        )
    }

    @MainActor
    func testPlayerYellowFlareRequestIsNonrepeatAndUsesThePreMovementGunpoint()
        throws
    {
        XCTAssertTrue(
            RevivalGameplayView.requestsPlayerFlare(
                keyCode: 5,
                isRepeat: false,
                gameplayIsActive: true
            )
        )
        XCTAssertFalse(
            RevivalGameplayView.requestsPlayerFlare(
                keyCode: 5,
                isRepeat: true,
                gameplayIsActive: true
            )
        )
        XCTAssertEqual(
            RevivalGameplayView.heldInput(for: [3]).vertical,
            -1,
            "F remains downward thrust"
        )

        var playerInput = PlayerInputState(rampDuration: 0)
        playerInput.requestPlayerFlare()
        XCTAssertTrue(
            playerInput.snapshot(frameDuration: 0.1).firesPlayerFlare
        )
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1).firesPlayerFlare
        )
        playerInput.requestPlayerFlare()
        playerInput.cancelPlayerFlareRequest()
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1).firesPlayerFlare,
            "capture teardown clears an unsnapshotted one-shot"
        )
        playerInput.requestPlayerFlare()
        playerInput.setGameplayActive(false, simulation: nil, at: 1)
        XCTAssertFalse(
            playerInput.snapshot(frameDuration: 0.1).firesPlayerFlare
        )

        let level = try makePlayerYellowFlareLevel()
        let player = try XCTUnwrap(level.objects.first {
            $0.handle == level.defaultPlayerBinding?.objectHandle
        })
        let binding = try XCTUnwrap(
            level.shipDefinitions.only?.playerYellowFlare
        )
        func transformed(_ value: Vector3, by matrix: Matrix3) -> Vector3 {
            .init(
                x: matrix.right.x * value.x + matrix.up.x * value.y
                    + matrix.forward.x * value.z,
                y: matrix.right.y * value.x + matrix.up.y * value.y
                    + matrix.forward.y * value.z,
                z: matrix.right.z * value.x + matrix.up.z * value.y
                    + matrix.forward.z * value.z
            )
        }
        let transformedForward = transformed(
            binding.gunpointLocalForward,
            by: player.orientation
        )
        let forwardMagnitude = sqrt(
            transformedForward.x * transformedForward.x
                + transformedForward.y * transformedForward.y
                + transformedForward.z * transformedForward.z
        )
        let transformedPosition = transformed(
            binding.gunpointLocalPosition,
            by: player.orientation
        )
        let expectedPosition = Vector3(
            x: player.position.x + transformedPosition.x,
            y: player.position.y + transformedPosition.y,
            z: player.position.z + transformedPosition.z
        )
        let expectedForward = Vector3(
            x: transformedForward.x / forwardMagnitude,
            y: transformedForward.y / forwardMagnitude,
            z: transformedForward.z / forwardMagnitude
        )
        let seed: UInt32 = 0x1234_5678
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
        let frame = simulation.update(
            at: 0.1,
            input: .init(yaw: 1, firesPlayerFlare: true)
        )
        let carrier = try XCTUnwrap(
            frame.trainingGuidebotYellowFlares.only
        )
        XCTAssertEqual(
            carrier.position,
            .init(
                x: expectedPosition.x + expectedForward.x * 10,
                y: expectedPosition.y + expectedForward.y * 10,
                z: expectedPosition.z + expectedForward.z * 10
            )
        )
        XCTAssertEqual(carrier.orientation.forward, expectedForward)
        XCTAssertEqual(
            frame.trainingOpeningFeedback.filter {
                $0.soundSourceName == "Flare.wav"
            }.count,
            1
        )
        XCTAssertEqual(
            frame.trainingGuidebotYellowFlareParticles.count,
            1
        )
        let retainedPlan = try updateMetalWorldPlan(
            try makeMetalWorldPlan(
                level: simulation.runtimeLevel,
                playerView: frame.playerView
            ),
            level: simulation.level,
            objects: simulation.world.objects,
            roomStates: simulation.world.rooms,
            playerView: frame.playerView,
            trainingGuidebotYellowFlares:
                frame.trainingGuidebotYellowFlares,
            trainingGuidebotYellowFlareParticles:
                frame.trainingGuidebotYellowFlareParticles
        )
        XCTAssertTrue(retainedPlan.draws.contains {
            $0.model == carrier.model
                && $0.objectHandle == UInt32.max - 1_000
        })
        XCTAssertTrue(retainedPlan.draws.contains {
            $0.objectHandle == UInt32.max - 2_000
        })
        var expectedState = seed
        for _ in 0..<7 {
            expectedState = expectedState &* 214_013 &+ 2_531_011
        }
        let continuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        XCTAssertEqual(
            (continuationObject["authoritativeRandomState"] as? NSNumber)?
                .uint32Value,
            expectedState
        )
        let playerFlareState = try XCTUnwrap(
            continuationObject["playerYellowFlareState"] as? [String: Any]
        )
        XCTAssertEqual(
            try XCTUnwrap(
                (playerFlareState["nextFireTime"] as? NSNumber)?.floatValue
            ),
            1,
            accuracy: 0.000_001
        )
    }

    func testPlayerYellowFlareFailureCadenceAndContinuationAreDeterministic()
        throws
    {
        let level = try makePlayerYellowFlareLevel()
        let seed: UInt32 = 0x2468_ace0
        var blockedShip = level.shipDefinitions[0]
        let stockBinding = try XCTUnwrap(blockedShip.playerYellowFlare)
        blockedShip.playerYellowFlare = .init(
            batteryIndex: stockBinding.batteryIndex,
            firingMask: stockBinding.firingMask,
            weapon: stockBinding.weapon,
            fireSoundLogicalName: stockBinding.fireSoundLogicalName,
            fireSoundSourceName: stockBinding.fireSoundSourceName,
            fireWait: stockBinding.fireWait,
            energyUsage: stockBinding.energyUsage,
            ammoUsage: stockBinding.ammoUsage,
            fireFlags: stockBinding.fireFlags,
            weaponFlags: stockBinding.weaponFlags,
            gunpointIndex: stockBinding.gunpointIndex,
            gunpointParentSubmodelIndex:
                stockBinding.gunpointParentSubmodelIndex,
            gunpointLocalPosition: .init(x: 0, y: 0, z: 600),
            gunpointLocalForward: stockBinding.gunpointLocalForward
        )
        let blocked = GameSession(
            level: replacing(level, shipDefinitions: [blockedShip]),
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
        let blockedFrame = blocked.update(
            at: 0.1,
            input: .init(firesPlayerFlare: true)
        )
        XCTAssertTrue(blockedFrame.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertFalse(blockedFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
        let blockedObject = try XCTUnwrap(
            testWorldObject(blocked.world)
        )
        XCTAssertEqual(
            (blockedObject["authoritativeRandomState"] as? NSNumber)?
                .uint32Value,
            seed
        )
        let blockedState = try XCTUnwrap(
            blockedObject["playerYellowFlareState"] as? [String: Any]
        )
        XCTAssertEqual(
            (blockedState["nextFireTime"] as? NSNumber)?.floatValue,
            1
        )

        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(firesPlayerFlare: true)
        )
        _ = simulation.update(
            at: 1,
            input: .init(firesPlayerFlare: true)
        )
        let due = simulation.update(
            at: 2,
            input: .init(firesPlayerFlare: true)
        )
        XCTAssertEqual(due.trainingGuidebotYellowFlares.count, 2)
        XCTAssertEqual(
            due.trainingOpeningFeedback.filter {
                $0.soundSourceName == "Flare.wav"
            }.count,
            1
        )
        let continuation = simulation.world
        let restored = try GameSession(
            level: level,
            world: continuation.rebased(onto: level),
            resumedAtTimestamp: 2
        )
        let originalNext = simulation.update(at: 2.25, input: .zero)
        let restoredNext = restored.update(at: 2.25, input: .zero)
        XCTAssertEqual(originalNext, restoredNext)
        XCTAssertEqual(simulation.world, restored.world)

        var capacityObject = try XCTUnwrap(
            testWorldObject(continuation)
        )
        capacityObject["authoritativeRandomState"] = NSNumber(value: seed)
        var capacityState = try XCTUnwrap(
            capacityObject["playerYellowFlareState"] as? [String: Any]
        )
        let parentPrototype = try XCTUnwrap(
            (capacityState["parents"] as? [[String: Any]])?.first
        )
        capacityState["parents"] = (0..<16).map { ordinal in
            var parent = parentPrototype
            parent["creationOrdinal"] = ordinal
            parent["lifeRemaining"] = 15
            parent["lastParticleDropTime"] = continuation.gameTime
            parent["velocity"] = ["x": 0, "y": 0, "z": 0]
            return parent
        }
        capacityState["parentParticles"] = []
        capacityState["nextCreationOrdinal"] = 16
        capacityState["nextFireTime"] = 0
        capacityObject["playerYellowFlareState"] = capacityState
        let capacity = try GameSession(
            level: level,
            world: (decodeTestWorld(capacityObject)).rebased(onto: level),
            resumedAtTimestamp: 3
        )
        let capacityFrame = capacity.update(
            at: 3.1,
            input: .init(firesPlayerFlare: true)
        )
        XCTAssertEqual(capacityFrame.trainingGuidebotYellowFlares.count, 16)
        XCTAssertFalse(capacityFrame.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })
        var expectedCapacityState = seed
        for _ in 0..<16 {
            expectedCapacityState =
                expectedCapacityState &* 214_013 &+ 2_531_011
        }
        let capacityAfter = try XCTUnwrap(
            testWorldObject(capacity.world)
        )
        XCTAssertEqual(
            (capacityAfter["authoritativeRandomState"] as? NSNumber)?
                .uint32Value,
            expectedCapacityState,
            "capacity failure adds no sound, carrier, or random draw"
        )

        let oldPackage = withTrainingGuideBot(
            makeTrainingGuidebotYellowFlareLevel()
        )
        let silent = GameSession(
            level: oldPackage,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        ).update(at: 0.1, input: .init(firesPlayerFlare: true))
        XCTAssertTrue(silent.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertFalse(silent.trainingOpeningFeedback.contains {
            $0.soundSourceName == "Flare.wav"
        })

        let legacyGuidebot = GameSession(
            level: oldPackage,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
        legacyGuidebot.runToTestGuideBotAmbient()
        var legacyWorld = legacyGuidebot.world
        legacyWorld.prepareTestGuideBotFlare(
            helperSlotsAreUsed: false,
            level: oldPackage
        )
        let restoredLegacyGuidebot = try GameSession(
            level: oldPackage,
            world: legacyWorld.rebased(onto: oldPackage),
            resumedAtTimestamp: 1
        )
        let legacyGuidebotFrame = restoredLegacyGuidebot.update(
            at: 1.1,
            input: .zero
        )
        XCTAssertEqual(
            legacyGuidebotFrame.trainingGuidebotYellowFlares.count,
            1,
            "an older schema-11 package keeps its landed Guidebot Yellow path"
        )
    }

    func testPlayerAndGuidebotYellowFamiliesAdvanceBySharedCreationOrdinal()
        throws
    {
        let level = withTrainingGuideBot(try makePlayerYellowFlareLevel())
        let seed: UInt32 = 0x3141_5926
        let initial = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
        initial.runToTestGuideBotAmbient()
        var dueWorld = initial.world
        dueWorld.prepareTestGuideBotFlare(
            helperSlotsAreUsed: false,
            level: level
        )
        let due = try GameSession(
            level: level,
            world: dueWorld.rebased(onto: level),
            resumedAtTimestamp: 1
        )
        _ = due.update(at: 1.1, input: .zero)
        do {
            _ = try GameSession(
                level: level,
                world: due.world.rebased(onto: level),
                resumedAtTimestamp: 1.15
            )
        } catch {
            XCTFail("Guidebot-only ordinal continuation rejected: \(error)")
            return
        }

        let playerPrototypeSimulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: seed
        )
        _ = playerPrototypeSimulation.update(
            at: 0.1,
            input: .init(firesPlayerFlare: true)
        )
        let playerPrototypeObject = try XCTUnwrap(
            testWorldObject(playerPrototypeSimulation.world)
        )
        let playerPrototypeState = try XCTUnwrap(
            playerPrototypeObject["playerYellowFlareState"]
                as? [String: Any]
        )
        var playerPrototype = try XCTUnwrap(
            (playerPrototypeState["parents"] as? [[String: Any]])?.only
        )

        // With the Guide-Bot in the ship, the frame's only draws are the
        // three flares' (7 each).
        var dueFlaresOnly = due.world
        dueFlaresOnly.parkTestGuideBotInShip()
        var mixedObject = try XCTUnwrap(
            testWorldObject(dueFlaresOnly)
        )
        mixedObject["authoritativeRandomState"] = NSNumber(value: seed)
        mixedObject["frameDuration"] = 0.1
        var mixedPlayer = try XCTUnwrap(
            mixedObject["playerYellowFlareState"] as? [String: Any]
        )
        let playerParents = try XCTUnwrap(
            mixedPlayer["parents"] as? [[String: Any]]
        )
        XCTAssertTrue(playerParents.isEmpty)
        playerPrototype["creationOrdinal"] = 0
        playerPrototype["lastParticleDropTime"] = 0
        mixedPlayer["nextFireTime"] = 0
        mixedPlayer["nextCreationOrdinal"] = 2
        mixedPlayer["parents"] = [playerPrototype]
        mixedPlayer["parentParticles"] = []
        mixedObject["playerYellowFlareState"] = mixedPlayer
        var mixedGuidebot = try XCTUnwrap(
            mixedObject["trainingRobotGuidebotState"] as? [String: Any]
        )
        var guidebotParents = try XCTUnwrap(
            mixedGuidebot["yellowFlares"] as? [[String: Any]]
        )
        guidebotParents[0]["creationOrdinal"] = 1
        guidebotParents[0]["lastParticleDropTime"] = 0
        mixedGuidebot["yellowFlares"] = guidebotParents
        mixedGuidebot["yellowFlareParticles"] = []
        mixedObject["trainingRobotGuidebotState"] = mixedGuidebot
        let mixedContinuation = try decodeTestWorld(mixedObject)
        let mixed: GameSession
        do {
            mixed = try GameSession(
                level: level,
                world: mixedContinuation.rebased(onto: level),
                resumedAtTimestamp: 3
            )
        } catch {
            XCTFail("mixed ordinal setup rejected: \(error)")
            return
        }
        _ = mixed.update(
            at: 3.1,
            input: .init(firesPlayerFlare: true)
        )

        var expectedState = seed
        let draws = (0..<21).map { _ -> UInt32 in
            expectedState = expectedState &* 214_013 &+ 2_531_011
            return (expectedState >> 16) & 0x7fff
        }
        let resultObject = try XCTUnwrap(
            testWorldObject(mixed.world)
        )
        XCTAssertEqual(
            (resultObject["authoritativeRandomState"] as? NSNumber)?
                .uint32Value,
            expectedState
        )
        let resultPlayer = try XCTUnwrap(
            resultObject["playerYellowFlareState"] as? [String: Any]
        )
        let resultGuidebot = try XCTUnwrap(
            resultObject["trainingRobotGuidebotState"] as? [String: Any]
        )
        let playerParticles = try XCTUnwrap(
            resultPlayer["parentParticles"] as? [[String: Any]]
        )
        let guidebotParticles = try XCTUnwrap(
            resultGuidebot["yellowFlareParticles"] as? [[String: Any]]
        )
        func expectedSize(for ordinal: Int) -> Float {
            0.2 + Float(Int(draws[ordinal * 7 + 4] % 11) - 5) * 0.02
        }
        func particleSize(
            ordinal: Int,
            in particles: [[String: Any]]
        ) throws -> Float {
            let particle = try XCTUnwrap(particles.first {
                ($0["generationOrdinal"] as? NSNumber)?.intValue == ordinal
            })
            return try XCTUnwrap(
                (particle["size"] as? NSNumber)?.floatValue
            )
        }
        XCTAssertEqual(
            try particleSize(ordinal: 0, in: playerParticles),
            expectedSize(for: 0),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try particleSize(ordinal: 1, in: guidebotParticles),
            expectedSize(for: 1),
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            try particleSize(ordinal: 2, in: playerParticles),
            expectedSize(for: 2),
            accuracy: 0.000_001
        )

    }

    func testPlayerYellowFlareStrictLifetimeTimeoutFamilyAndBindingShape()
        throws
    {
        let level = try makePlayerYellowFlareLevel()
        var levelObject = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(level)
            ) as? [String: Any]
        )
        var ships = try XCTUnwrap(
            levelObject["shipDefinitions"] as? [[String: Any]]
        )
        ships[0].removeValue(forKey: "playerYellowFlare")
        levelObject["shipDefinitions"] = ships
        XCTAssertNoThrow(
            try JSONDecoder().decode(
                Level.self,
                from: JSONSerialization.data(withJSONObject: levelObject)
            )
        )
        ships[0]["playerYellowFlare"] = ["batteryIndex": 20]
        levelObject["shipDefinitions"] = ships
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                Level.self,
                from: JSONSerialization.data(withJSONObject: levelObject)
            )
        )

        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 7
        )
        _ = simulation.update(
            at: 0.1,
            input: .init(firesPlayerFlare: true)
        )
        var continuationObject = try XCTUnwrap(
            testWorldObject(simulation.world)
        )
        var state = try XCTUnwrap(
            continuationObject["playerYellowFlareState"]
                as? [String: Any]
        )
        var parents = try XCTUnwrap(
            state["parents"] as? [[String: Any]]
        )
        parents[0]["lifeRemaining"] = 0.1
        state["parents"] = parents
        continuationObject["playerYellowFlareState"] = state
        let nearTimeout = try decodeTestWorld(continuationObject)
        let restored = try GameSession(
            level: level,
            world: nearTimeout.rebased(onto: level),
            resumedAtTimestamp: 0.1
        )
        let exactZero = restored.update(at: 0.2, input: .zero)
        XCTAssertEqual(exactZero.trainingGuidebotYellowFlares.count, 1)
        XCTAssertTrue(
            exactZero.trainingGuidebotYellowFlareTimeoutExplosions.isEmpty
        )
        let expired = restored.update(at: 0.3, input: .zero)
        XCTAssertTrue(expired.trainingGuidebotYellowFlares.isEmpty)
        XCTAssertEqual(
            expired.trainingGuidebotYellowFlareTimeoutExplosions.count,
            1
        )
        XCTAssertEqual(
            expired.trainingGuidebotYellowFlareTimeoutSparks.count,
            9
        )
        XCTAssertEqual(
            Set(expired.trainingGuidebotYellowFlareTimeoutSparks.map {
                $0.sourceAttemptIndex
            }),
            Set(0..<9)
        )
        XCTAssertTrue(
            expired.trainingGuidebotYellowFlareTimeoutSparks.allSatisfy {
                $0.receivedControlOnCreationFrame
            }
        )
        XCTAssertEqual(
            expired.trainingGuidebotYellowFlareTimeoutSparkParticles.count,
            9
        )

        XCTAssertEqual(combinedYellowFlarePresentationCapacity, 22)
        XCTAssertEqual(combinedYellowFlareParticlePresentationCapacity, 272)
        XCTAssertEqual(
            combinedYellowFlareTimeoutExplosionPresentationCapacity,
            17
        )
        XCTAssertEqual(
            combinedYellowFlareTimeoutSparkPresentationCapacity,
            153
        )
        XCTAssertEqual(
            combinedYellowFlareTimeoutSparkParticlePresentationCapacity,
            918
        )
        let capacitySparks =
            (0..<combinedYellowFlareTimeoutSparkPresentationCapacity).map {
            expired.trainingGuidebotYellowFlareTimeoutSparks[
                $0 % expired.trainingGuidebotYellowFlareTimeoutSparks.count
            ]
        }
        let capacityPlan = try updateMetalWorldPlan(
            try makeMetalWorldPlan(
                level: restored.runtimeLevel,
                playerView: exactZero.playerView
            ),
            level: restored.level,
            objects: restored.world.objects,
            roomStates: restored.world.rooms,
            playerView: exactZero.playerView,
            trainingGuidebotYellowFlares: Array(
                repeating: try XCTUnwrap(
                    exactZero.trainingGuidebotYellowFlares.only
                ),
                count: combinedYellowFlarePresentationCapacity
            ),
            trainingGuidebotYellowFlareParticles: Array(
                repeating: try XCTUnwrap(
                    expired.trainingGuidebotYellowFlareParticles.first
                ),
                count: combinedYellowFlareParticlePresentationCapacity
            ),
            trainingGuidebotYellowFlareTimeoutExplosions: Array(
                repeating: try XCTUnwrap(
                    expired.trainingGuidebotYellowFlareTimeoutExplosions.only
                ),
                count:
                    combinedYellowFlareTimeoutExplosionPresentationCapacity
            ),
            trainingGuidebotYellowFlareTimeoutSparks: capacitySparks,
            trainingGuidebotYellowFlareTimeoutSparkParticles: Array(
                repeating: try XCTUnwrap(
                    expired.trainingGuidebotYellowFlareTimeoutSparkParticles
                        .first
                ),
                count:
                    combinedYellowFlareTimeoutSparkParticlePresentationCapacity
            )
        )
        XCTAssertFalse(capacityPlan.draws.isEmpty)
    }

}
